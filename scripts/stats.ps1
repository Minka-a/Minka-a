param(
  [string]$User = 'Minka-a',
  [string]$Out = 'profile.svg',
  [string]$Discord = '.minka',
  [switch]$Demo,
  [int]$ForceStreak = -1
)
# Generates stats.svg (manga-ink style, light/dark, animated) from the GitHub contribution calendar.
# Runs on Windows PowerShell 5.1 and PowerShell 7 (GitHub Actions ubuntu runners).
# Real data needs $env:GITHUB_TOKEN. -Demo uses deterministic sample data for previews.
# Kept ASCII-only on purpose: accents are written as XML entities.
$ErrorActionPreference = 'Stop'
$inv = [System.Globalization.CultureInfo]::InvariantCulture
function F([double]$v) { return $v.ToString('0.##', $inv) }
function X([string]$s) { return [System.Security.SecurityElement]::Escape($s) }
# French-style thousands grouping with a narrow no-break space: 1 047
# French style: no grouping under 10 000; above, a 6px gap via tspan (no U+202F, which the fonts lack).
function N([int]$v) {
  $s = $v.ToString($inv)
  if ($s.Length -le 4) { return $s }
  return $s.Substring(0, $s.Length - 3) + "<tspan dx=`"6`">" + $s.Substring($s.Length - 3) + '</tspan>'
}
# Space Grotesk's "1" has a flag that makes a leading 1 look indented: pull it back.
function Lead1([int]$v, [double]$fs) { return '' }
$Out = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)
. (Join-Path $PSScriptRoot 'deco.ps1')
. (Join-Path $PSScriptRoot 'rc-stages.ps1')
$icons = [System.IO.File]::ReadAllText((Join-Path (Join-Path $PSScriptRoot '..') 'assets/icons.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$issues = 0; $reviews = 0; $calTotal = -1
$levelMap = @{ NONE = 0; FIRST_QUARTILE = 1; SECOND_QUARTILE = 2; THIRD_QUARTILE = 3; FOURTH_QUARTILE = 4 }

# ------------------------------------------------------------------ data
$days = New-Object System.Collections.Generic.List[object]
$commits = 0; $prs = 0
if ($Demo) {
  $end = [datetime]::UtcNow.Date
  $start = $end.AddDays(-(52 * 7 + [int]$end.DayOfWeek))
  $n = ($end - $start).Days + 1
  [long]$seed = 1306
  for ($k = 0; $k -lt $n; $k++) {
    $seed = ($seed * [long]1103515245 + 12345) % [long]2147483648
    $r = $seed / 2147483648.0
    $c = 0
    if ($r -ge 0.45) { $c = [int][Math]::Floor(($r - 0.45) / 0.55 * 9) + 1 }
    $back = $n - 1 - $k
    if ($back -lt 7 -and $c -eq 0) { $c = 2 }
    if ($back -eq 7) { $c = 0 }
    $lv = 0; if ($c -gt 0) { $lv = [Math]::Min(4, [int][Math]::Ceiling($c / 2.5)) }
    $days.Add([pscustomobject]@{ Date = $start.AddDays($k); Count = $c; Level = $lv })
  }
  $commits = [int](($days | Measure-Object -Property Count -Sum).Sum * 0.8)
  $prs = 12; $issues = 3; $reviews = 9
} else {
  if (-not $env:GITHUB_TOKEN) { throw 'GITHUB_TOKEN is not set (use -Demo for sample data).' }
  $q = 'query($login:String!){user(login:$login){contributionsCollection{totalCommitContributions totalPullRequestContributions totalIssueContributions totalPullRequestReviewContributions restrictedContributionsCount totalRepositoryContributions contributionCalendar{totalContributions weeks{contributionDays{date contributionCount contributionLevel}}}}}}'
  $body = @{ query = $q; variables = @{ login = $User } } | ConvertTo-Json -Depth 5 -Compress
  $headers = @{ Authorization = "bearer $env:GITHUB_TOKEN"; 'User-Agent' = 'profile-stats' }
  if ($PSVersionTable.PSVersion.Major -lt 6) { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 }
  $res = Invoke-RestMethod -Uri 'https://api.github.com/graphql' -Method Post -Headers $headers -Body $body -ContentType 'application/json'
  if ($res.errors) { throw ($res.errors | ConvertTo-Json -Depth 5) }
  $cc = $res.data.user.contributionsCollection
  foreach ($w in $cc.contributionCalendar.weeks) {
    foreach ($d in $w.contributionDays) {
      $lv = $levelMap[[string]$d.contributionLevel]; if ($null -eq $lv) { $lv = 0 }
      $days.Add([pscustomobject]@{ Date = [datetime]::ParseExact([string]$d.date, 'yyyy-MM-dd', $inv); Count = [int]$d.contributionCount; Level = $lv })
    }
  }
  $commits = [int]$cc.totalCommitContributions
  $prs = [int]$cc.totalPullRequestContributions
  $issues = [int]$cc.totalIssueContributions
  $reviews = [int]$cc.totalPullRequestReviewContributions
  # the exact number GitHub prints above its own calendar ("N contributions in the last year")
  $calTotal = [int]$cc.contributionCalendar.totalContributions
}
$days = @($days | Sort-Object Date)
if ($days.Count -eq 0) { throw "No contribution calendar returned for $User" }

$total = 0; $active = 0; $longest = 0; $run = 0; $max = 0
foreach ($d in $days) {
  $total += $d.Count
  if ($d.Count -gt $max) { $max = $d.Count }
  if ($d.Count -gt 0) { $active++; $run++; if ($run -gt $longest) { $longest = $run } } else { $run = 0 }
}
if ($calTotal -ge 0) { $total = $calTotal }
# Current streak: today not done yet does not break it.
$i = $days.Count - 1
if ($i -ge 0 -and $days[$i].Count -eq 0) { $i-- }
$current = 0
while ($i -ge 0 -and $days[$i].Count -gt 0) { $current++; $i-- }
if ($ForceStreak -ge 0) { $current = $ForceStreak; if ($longest -lt $current) { $longest = $current } }  # previews of each stage

# ------------------------------------------------------------------ helpers
$css = New-Object System.Text.StringBuilder
$svg = New-Object System.Text.StringBuilder
function Add-Css([string]$s) { [void]$css.AppendLine('    ' + $s) }
function Add-Svg([string]$s) { [void]$svg.AppendLine('  ' + $s) }

# Panel: paper fill now, ink edge drawn later (returned) so it sits above the dots.
$edges = New-Object System.Text.StringBuilder
function Add-Panel([string]$id, [double[]]$p, [double]$delay, [double]$dots = 0) {
  $pts = @(); for ($k = 0; $k -lt $p.Length; $k += 2) { $pts += "$(F $p[$k]),$(F $p[$k+1])" }
  Add-Svg (Get-DecoShadow $p ($delay + .5))
  Add-Svg "<polygon class=`"fill`" points=`"$($pts -join ' ')`"/>"
  Add-Svg (Get-DecoDots $p $dots ($delay + .4))
  Add-Svg (Get-DecoHair $p ($delay + .7))
  $mx = ($p[0] + $p[2]) / 2; $my = ($p[1] + $p[3]) / 2
  $d = "M$(F $mx),$(F $my)"; $len = 0; $px = $mx; $py = $my
  $order = @(2, 4, 6, 0)
  foreach ($k in $order) { $len += [Math]::Sqrt([Math]::Pow($p[$k] - $px, 2) + [Math]::Pow($p[$k+1] - $py, 2)); $px = $p[$k]; $py = $p[$k+1]; $d += " L$(F $px),$(F $py)" }
  $len += [Math]::Sqrt([Math]::Pow($mx - $px, 2) + [Math]::Pow($my - $py, 2)); $d += " L$(F $mx),$(F $my)"
  $L = [Math]::Ceiling($len)
  Add-Css ".e$id{stroke-dasharray:$L;animation:k$id .8s cubic-bezier(.6,0,.3,1) $(F $delay)s both}@keyframes k$id{from{stroke-dashoffset:$L}}"
  [void]$edges.AppendLine("  <path class=`"edge e$id`" d=`"$d`"/>")
}
# Section label: slanted ink marker (gutter slope) + spaced caps + short hairline. $w is unused (kept for call sites).
function Add-Tab([double]$x, [double]$y, [double]$w, [string]$label, [double]$delay) {
  $y = $y + 4
  $chars = ($label -replace '&#x[0-9A-Fa-f]+;', 'x').Length
  $tx = $x + 22; $rx1 = $tx + $chars * 13.8 + 10; $rx2 = $rx1 + 36
  Add-Svg "<polygon class=`"tabm`" points=`"$(F ($x+4)),$(F $y) $(F ($x+11)),$(F $y) $(F ($x+7)),$(F ($y+20)) $(F $x),$(F ($y+20))`" style=`"transform-origin:$(F $x)px $(F ($y+20))px;animation-delay:$(F $delay)s`"/>"
  Add-Svg "<text class=`"mono tabl`" x=`"$(F $tx)`" y=`"$(F ($y+15))`" style=`"animation-delay:$(F ($delay+.1))s`">$label</text>"
  Add-Svg "<line class=`"tabr`" x1=`"$(F $rx1)`" y1=`"$(F ($y+10))`" x2=`"$(F $rx2)`" y2=`"$(F ($y+10))`" style=`"transform-origin:$(F $rx1)px $(F ($y+10))px;animation-delay:$(F ($delay+.2))s`"/>"
}
function Add-SoftDots([double]$cx, [double]$cy, [double]$radius, $inside, [double]$x0, [double]$x1, [double]$y0, [double]$y1, [double]$base) {
  for ($y = $y0; $y -le $y1; $y += 16) { for ($x = $x0; $x -le $x1; $x += 16) {
    if (-not (& $inside $x $y)) { continue }
    $t = 1 - [Math]::Sqrt([Math]::Pow($cx - $x, 2) + [Math]::Pow($cy - $y, 2)) / $radius
    if ($t -lt 0.04) { continue }
    $r = 0.7 + 1.5 * [Math]::Pow($t, 1.3); $o = 0.4 + 0.6 * $t
    Add-Svg "<circle class=`"sd`" cx=`"$(F $x)`" cy=`"$(F $y)`" r=`"$(F $r)`" opacity=`"$(F $o)`" style=`"transform-origin:$(F $x)px $(F $y)px;animation-delay:$(F ($base + (1 - $t) * .6))s`"/>"
  } }
}

# ------------------------------------------------------------------ layout (divider slope 0.1875 like banner/about)
Add-Svg (Get-DecoDefs)
[void]$css.AppendLine($script:DecoCss.TrimEnd())
[void]$css.AppendLine($script:RcCss.TrimEnd())
Add-Panel 'a' @(10,10, 410,10, 366.9,240, 10,240) 0 0
Add-Panel 'b' @(430,10, 1190,10, 1190,240, 386.9,240) .1 0
Add-Panel 'c' @(10,260, 960,260, 922.5,460, 10,460) .2 0
Add-Panel 'd' @(980,260, 1190,260, 1190,460, 942.5,460) .3 150

# soft dot fields (behind content)
# (no dot field in the STATS panel: it competed with the numbers)
# Add-SoftDots 1190 10 170 { param($x, $y) $x -le 1182 -and $y -ge 18 -and $x -ge 1000 } 1000 1186 18 200 .5
# (contact corner dots now come from Get-DecoDots via Add-Panel)

# --- panel A: streak
Add-Tab 40 34 110 'STREAK' .4
$cx = 262; $cy = 140
Add-Svg "<text class=`"mono k1 in`" x=`"40`" y=`"112`" style=`"animation-delay:.6s`">jours</text>"
Add-Svg "<text class=`"mono k1 in`" x=`"40`" y=`"134`" style=`"animation-delay:.65s`">d'affil&#xE9;e</text>"
Add-Svg "<text class=`"mono k3 in`" x=`"40`" y=`"193`" style=`"animation-delay:.75s`">meilleure s&#xE9;rie</text>"
$jl = if ($longest -le 1) { 'jour' } else { 'jours' }
Add-Svg "<g class=`"rec`" transform=`"translate(40 202) scale(1.1)`"><path class=`"rec-flame`" d=`"$($icons.'oc-flame'.d)`"/></g>"
Add-Svg "<defs><linearGradient id=`"recShine`" gradientUnits=`"userSpaceOnUse`" x1=`"-160`" y1=`"0`" x2=`"-40`" y2=`"0`"><stop offset=`"0`" style=`"stop-color:var(--ink)`"/><stop offset=`".5`" style=`"stop-color:var(--accent)`"/><stop offset=`"1`" style=`"stop-color:var(--ink)`"/><animate attributeName=`"x1`" values=`"-160;200`" dur=`"1.6s`" begin=`"2.2s`" repeatCount=`"3`" fill=`"freeze`"/><animate attributeName=`"x2`" values=`"-40;320`" dur=`"1.6s`" begin=`"2.2s`" repeatCount=`"3`" fill=`"freeze`"/></linearGradient></defs>"
Add-Svg "<text class=`"sans k4 in rec-t`" x=`"64`" y=`"218`" style=`"animation-delay:.8s`">$longest $jl</text>"
Add-Css ".rec-flame { fill: var(--accent); transform-box: fill-box; transform-origin: 50% 100%; animation: flick 1.1s ease-in-out infinite; } @keyframes flick { 0%,100% { transform: scale(1); } 30% { transform: scale(.92,1.12); } 60% { transform: scale(1.06,.95); } } .rec-t { fill: url(#recShine); }"
Add-Svg "<text class=`"sans m-only m-rec`" x=`"40`" y=`"212`">record $longest j</text>"
Add-Svg "<text class=`"mono m-only m-l1`" x=`"40`" y=`"146`">jours</text>"
$zero = ''; if ($current -eq 0) { $zero = ' zero' }
$cx = 286; $cy = 138
$stage = Get-RcStage $current
Add-Svg "<text class=`"mono stage`" x=`"40`" y=`"156`">$($script:RcStageNames[$stage])</text>"
# progress toward the next stage (real streak data) + a one-off burst the day a new stage is reached
$stageStarts = @(0, 1, 7, 30, 100)
$milestone = $current -in @(1, 7, 30, 100)
if ($stage -lt 4) { $nxt = $script:RcNext[$stage]; $prog = ($current - $stageStarts[$stage]) / ($nxt - $stageStarts[$stage]); $glbl = "encore $($nxt - $current) j" } else { $prog = 1; $glbl = 'stade max' }
if ($milestone) { $glbl = 'nouveau stade !' }
Add-Svg "<text class=`"mono gauge-t`" x=`"106`" y=`"169`">$glbl</text>"
Add-Svg "<rect class=`"gauge-bg`" x=`"40`" y=`"164`" width=`"58`" height=`"4`" rx=`"2`"/><rect class=`"gauge`" x=`"40`" y=`"164`" width=`"$(F ([Math]::Max(4, 58 * $prog)))`" height=`"4`" rx=`"2`"/>"
Add-Css '.gauge-bg { fill: var(--grid); opacity: .6; } .gauge { fill: var(--accent); transform-origin: 40px 166px; animation: gaugeIn 1s cubic-bezier(.2,.7,.2,1) 1.5s both; } @keyframes gaugeIn { from { transform: scaleX(0); } }'
Add-Css '.gauge-t { fill: var(--soft); font-size: 12px; font-weight: 400; letter-spacing: 0; animation: fade .5s ease 1.6s both; } @media (max-width: 520px) { .gauge-t, .gauge, .gauge-bg { display: none; } }'
if ($milestone) {
  $rays = (0..15 | ForEach-Object { $a = $_ * [Math]::PI / 8; "<line x1=`"$(F ($cx + [Math]::Cos($a) * 96))`" y1=`"$(F ($cy + [Math]::Sin($a) * 88))`" x2=`"$(F ($cx + [Math]::Cos($a) * 114))`" y2=`"$(F ($cy + [Math]::Sin($a) * 104))`"/>" }) -join ''
  Add-Svg "<g class=`"burst`" style=`"transform-origin:$($cx)px $($cy)px`">$rays</g>"
  Add-Css '.gauge-t { fill: var(--accent); } .burst { opacity: 0; animation: burst 1.3s ease-out 1.6s 3 both; } .burst line { stroke: var(--accent); stroke-width: 2.5; stroke-linecap: round; } @keyframes burst { from { opacity: 1; transform: scale(.75); } to { opacity: 0; transform: scale(1.25); } }'
}
# "RC cell" membrane, all vector (no blur filter):
#  - outline = smooth noisy curve + 3 pseudopods that reach out and retract (SMIL <animate d>, 6 frames, 12s)
#  - heartbeat: the whole ring pulses lub-dub every 2.8s (CSS)
#  - cells flow around inside the band (SMIL <animateMotion> on a hidden ellipse)
#  - nuclei and satellites wobble on their own rhythm (CSS)
# Every value of an <animate d> has the same command structure (M + 48 C + Z per contour).
$pods = @(
  @{ a = -100; h = @(0, .14, .20, .08, 0, 0) },
  @{ a = -35;  h = @(.06, 0, 0, .14, .25, .12) },
  @{ a = 105;  h = @(0, 0, .09, .14, .05, 0) }
)
function Get-Contour([double]$rx, [double]$ry, [double]$amp, [double[]]$ph, [int]$frame, [double]$podScale) {
  $pts = @(); $N = 48
  for ($i = 0; $i -lt $N; $i++) {
    $t = 2 * [Math]::PI * $i / $N
    $f = 1 + $amp * (0.5 * [Math]::Sin(3 * $t + $ph[0]) + 0.3 * [Math]::Sin(5 * $t + $ph[1]) + 0.2 * [Math]::Sin(8 * $t + $ph[2]))
    if ($podScale -gt 0) {
      foreach ($p in $pods) {
        $pa = $p.a * [Math]::PI / 180
        $dd = [Math]::Atan2([Math]::Sin($t - $pa), [Math]::Cos($t - $pa))
        $f += $podScale * $p.h[$frame] * [Math]::Exp(-($dd * $dd) / (2 * 0.16 * 0.16))
      }
    }
    $pts += , @(($cx + [Math]::Cos($t) * $rx * $f), ($cy + [Math]::Sin($t) * $ry * $f))
  }
  # closed Catmull-Rom spline -> cubic Beziers
  $d = "M$(F $pts[0][0]) $(F $pts[0][1])"
  for ($i = 0; $i -lt $N; $i++) {
    $p0 = $pts[($i - 1 + $N) % $N]; $p1 = $pts[$i]; $p2 = $pts[($i + 1) % $N]; $p3 = $pts[($i + 2) % $N]
    $c1x = $p1[0] + ($p2[0] - $p0[0]) / 6; $c1y = $p1[1] + ($p2[1] - $p0[1]) / 6
    $c2x = $p2[0] - ($p3[0] - $p1[0]) / 6; $c2y = $p2[1] - ($p3[1] - $p1[1]) / 6
    $d += " C$(F $c1x) $(F $c1y) $(F $c2x) $(F $c2y) $(F $p2[0]) $(F $p2[1])"
  }
  return $d + 'Z'
}
$nF = 6
$frames = @(0..($nF - 1) | ForEach-Object { , @(($_ * 1.05), ($_ * 1.9 + 1), ($_ * 0.7 + 2), $_) })
function Add-Morph([string]$cls, [scriptblock]$shape) {
  $ds = @($frames | ForEach-Object { & $shape $_ })
  $anim = ''
  if ($current -gt 0) {
    $vals = ($ds + $ds[0]) -join ';'
    $kt = (0..$nF | ForEach-Object { F ($_ / $nF) }) -join ';'
    $ks = ((1..$nF) | ForEach-Object { '.45 0 .55 1' }) -join ';'
    $anim = "<animate attributeName=`"d`" dur=`"12s`" repeatCount=`"indefinite`" calcMode=`"spline`" keyTimes=`"$kt`" keySplines=`"$ks`" values=`"$vals`"/>"
  }
  return "<path class=`"$cls`" fill-rule=`"evenodd`" d=`"$($ds[0])`">$anim</path>"
}
$halo = Add-Morph 'rcHalo' { param($p) (Get-Contour 99 89 .08 $p[0..2] $p[3] 1.15) + ' ' + (Get-Contour 63 55 .05 $p[0..2] $p[3] 0) }
$band = Add-Morph 'rcBand' { param($p) (Get-Contour 90 80 .07 $p[0..2] $p[3] 1) + ' ' + (Get-Contour 70 61 .05 $p[0..2] $p[3] 0) }
$rim  = Add-Morph 'rcRim'  { param($p) (Get-Contour 75 65.5 .05 $p[0..2] $p[3] 0) + ' ' + (Get-Contour 70 61 .05 $p[0..2] $p[3] 0) }
$mem  = Add-Morph 'rcMem'  { param($p) (Get-Contour 90 80 .07 $p[0..2] $p[3] 1) }

$bits = New-Object System.Text.StringBuilder
# cells flowing around the band
if ($current -gt 0) {
  [void]$bits.Append("<path id=`"flow`" d=`"M$($cx + 80.5) $cy A80.5 71 0 1 1 $($cx - 80.5) $cy A80.5 71 0 1 1 $($cx + 80.5) $cy`" fill=`"none`"/>")
  for ($i = 0; $i -lt 9; $i++) {
    $r = 1.8 + 1.4 * (0.5 + 0.5 * [Math]::Sin($i * 2.3))
    $begin = -14 * $i / 9 - 0.6 * [Math]::Sin($i * 1.3)
    [void]$bits.Append("<circle class=`"rcFlow`" r=`"$(F $r)`"><animateMotion dur=`"14s`" repeatCount=`"indefinite`" begin=`"$(F $begin)s`"><mpath href=`"#flow`" xlink:href=`"#flow`"/></animateMotion></circle>")
  }
}
for ($i = 0; $i -lt 7; $i++) {
  $a = 2 * [Math]::PI * ($i + 0.3) / 7 - [Math]::PI / 2
  $x = $cx + [Math]::Cos($a) * 80.5; $y = $cy + [Math]::Sin($a) * 71
  $r = 2.6 + 1.6 * (0.5 + 0.5 * [Math]::Sin($i * 3.3))
  $dur = 2.6 + 1.8 * (0.5 + 0.5 * [Math]::Sin($i * 4.1)); $ph = 3 * (0.5 + 0.5 * [Math]::Sin($i * 1.7))
  [void]$bits.Append("<g class=`"cell`" style=`"transform-origin:$(F $x)px $(F $y)px;animation-delay:$(F (.9 + $i * .06))s`"><circle class=`"rcNuc w$($i % 3)`" cx=`"$(F $x)`" cy=`"$(F $y)`" r=`"$(F $r)`" style=`"transform-origin:$(F $x)px $(F $y)px;animation-duration:$(F $dur)s;animation-delay:-$(F $ph)s`"/></g>")
}
$sat = @(@(-62, 6), @(140, 5), @(-140, 4.5), @(60, 4))
for ($j = 0; $j -lt $sat.Count; $j++) {
  $a = $sat[$j][0] * [Math]::PI / 180
  $x = $cx + [Math]::Cos($a) * 108; $y = $cy + [Math]::Sin($a) * 96
  [void]$bits.Append("<g class=`"cell`" style=`"transform-origin:$(F $x)px $(F $y)px;animation-delay:$(F (1.2 + $j * .08))s`"><circle class=`"rcSat w$($j % 3)`" cx=`"$(F $x)`" cy=`"$(F $y)`" r=`"$($sat[$j][1])`" style=`"transform-origin:$(F $x)px $(F $y)px;animation-duration:$(F (3 + $j * .7))s`"/></g>")
}
# ring drawn at full size then scaled down around its centre (a static transform on an outer group, so the CSS animations inside keep their own origins)
$ringScale = 0.8
switch ($stage) {
  0 { Add-Svg (Get-RcDormant) }
  1 { Add-Svg (Get-RcNoyau) }
  2 { Add-Svg (Get-RcGrappe) }
  3 { Add-Svg "<g transform=`"translate($cx $cy) scale($ringScale) translate(-$cx -$cy)`"><g class=`"rcg$zero`" style=`"transform-origin:$($cx)px $($cy)px`"><g class=`"beat`" style=`"transform-origin:$($cx)px $($cy)px`">$(Get-RcMembraneUnder)$halo$band$rim$mem$(Get-RcVeins)$($bits.ToString())$(Get-RcMembraneOver)</g></g></g>" }
  default { Add-Svg (Get-RcKagune) }
}

$digits = "$current".Length
$fs = switch ($digits) { 1 { 70 } 2 { 58 } 3 { 44 } default { 32 } }
if ($stage -ne 3) { $fs = switch ($digits) { 1 { 50 } 2 { 40 } 3 { 30 } default { 24 } } }
Add-Svg "<text class=`"heavy num$zero`" x=`"$cx`" y=`"$(F ($cy + $fs * 0.36))`" text-anchor=`"middle`"$(Lead1 $current $fs) style=`"font-size:$($fs)px`">$current</text>"

# Odometer: each digit is a 0-9 strip clipped to one cell, scrolled to its value on load.
# The strip's resting transform is its final position (inline), the keyframes only start it from 0,
# so with animations off the right number simply shows.
function Get-Odometer([double]$x, [double]$y, [int]$v, [double]$fs, [double]$delay, [int]$id) {
  $str = "$v"; $cw = $fs * 0.64; $lh = $fs * 1.05
  $clip = "<clipPath id=`"odo$id`"><rect x=`"$(F ($x - 2))`" y=`"$(F ($y - $fs * 0.82))`" width=`"$(F ($cw * $str.Length + 6))`" height=`"$(F ($fs * 1.0))`"/></clipPath>"
  $strips = New-Object System.Text.StringBuilder
  for ($i = 0; $i -lt $str.Length; $i++) {
    $dg = [int]::Parse([string]$str[$i]); $off = -$dg * $lh; $dx = $x + $cw * $i + $cw / 2
    $name = "od$($id)x$i"
    Add-Css "@keyframes $name { from { transform: translateY(0px); } }"
    $t = (0..9 | ForEach-Object { "<text x=`"$(F $dx)`" y=`"$(F ($y + $_ * $lh))`" text-anchor=`"middle`">$_</text>" }) -join ''
    [void]$strips.Append("<g class=`"heavy big odo`" style=`"font-size:$($fs)px;transform:translateY($(F $off)px);animation:$name 1.5s cubic-bezier(.15,.85,.25,1) $(F ($delay + .2 + $i * .1))s both`">$t</g>")
  }
  return "<defs>$clip</defs><g clip-path=`"url(#odo$id)`">$($strips.ToString())</g>"
}
# --- panel B: numbers, each with an Octicon, then a commits / PR / issues / other split bar
Add-Tab 468 34 176 'STATS &#xB7; 12 MOIS' .5
$cols = @(
  @{ v = $total;   l1 = 'contributions'; m = 'contribs'; i = 'oc-graph';    c = 'ic-acc' },
  @{ v = $commits; l1 = 'commits';       m = 'commits';  i = 'oc-commit';   c = 'ic-com' },
  @{ v = $prs;     l1 = 'pull requests'; m = 'PR';       i = 'oc-pr';       c = 'ic-pr' },
  @{ v = $active;  l1 = 'jours actifs';  m = 'jours';    i = 'oc-calendar'; c = 'ic-day' }
)
for ($k = 0; $k -lt 4; $k++) {
  $x = 468 + $k * 176; $dl = .6 + $k * .1
  $len = "$($cols[$k].v)".Length
  $bfs = 52; if ($len -eq 5) { $bfs = 42 } elseif ($len -gt 5) { $bfs = 34 }
  if ($k -gt 0) { Add-Svg "<line class=`"rule in`" x1=`"$($x - 16)`" y1=`"92`" x2=`"$($x - 16)`" y2=`"182`" style=`"animation-delay:$(F $dl)s`"/>" }
  $icon = "<path class=`"$($cols[$k].c)`" transform=`"translate($x 163)`" d=`"$($icons.($cols[$k].i).d)`"/>"
  Add-Svg "<g class=`"col`" style=`"animation-delay:$(F $dl)s`">$(Get-Odometer $x 146 $cols[$k].v $bfs $dl $k)$icon<text class=`"mono l1`" x=`"$($x + 24)`" y=`"176`">$($cols[$k].l1)</text><text class=`"mono m-only m-l1`" x=`"$x`" y=`"190`">$($cols[$k].m)</text></g>"
}
# same four categories as GitHub's "Activity overview"
$parts = @(@{ n = 'commits'; v = $commits; c = 'seg-com' }, @{ n = 'PR'; v = $prs; c = 'seg-pr' }, @{ n = 'issues'; v = $issues; c = 'seg-is' }, @{ n = 'revues'; v = $reviews; c = 'seg-rv' }, @{ n = 'priv&#xE9; / autres'; v = [Math]::Max(0, $total - $commits - $prs - $issues - $reviews); c = 'seg-ot' })
$sum = 0; foreach ($p in $parts) { $sum += $p.v }
if ($sum -gt 0) {
  $bx = 468; $bw = 690; $lx2 = 468
  $legend = New-Object System.Text.StringBuilder
  $legW = @(); foreach ($q in $parts) { $pq = [Math]::Round(100 * $q.v / $sum); $tq = "$($q.n) $pq %"; if ($q.v -gt 0 -and $pq -eq 0) { $tq = "$($q.n) <1 %" }; $legW += 16 + ($tq -replace '&#x[0-9A-Fa-f]+;', 'x').Length * 8.4 }
  $legGap = [Math]::Max(10, (690 - ($legW | Measure-Object -Sum).Sum) / [Math]::Max(1, $parts.Count - 1)); $legI = 0
  foreach ($p in $parts) {
    $w = $bw * $p.v / $sum
    if ($w -gt 0) {
      Add-Svg "<rect class=`"$($p.c) seg`" x=`"$(F $bx)`" y=`"194`" width=`"$(F ([Math]::Max(4, $w - 2)))`" height=`"7`" rx=`"2`" style=`"transform-origin:$(F $bx)px 197px;animation-delay:$(F (1.0 + $bx / 2000))s`"/>"
    }
    $bx += $w
    $pct = [Math]::Round(100 * $p.v / $sum); $pctTxt = "$pct&#xA0;%"; if ($p.v -gt 0 -and $pct -eq 0) { $pctTxt = "&lt;1&#xA0;%" }
    $lab = "$($p.n) $pctTxt"
    [void]$legend.Append("<rect class=`"$($p.c)`" x=`"$lx2`" y=`"210`" width=`"10`" height=`"10`" rx=`"2`"/><text class=`"mono bl`" x=`"$($lx2 + 16)`" y=`"219`">$lab</text>")
    $lx2 += $legW[$legI] + $legGap; $legI++
  }
  Add-Svg "<g class=`"barleg in`" style=`"animation-delay:1.3s`">$($legend.ToString())</g>"
}
if ($true) {
# weekly rhythm sparkline (real weekly totals) in the band under the STATS tab, drawn left to right
$wk = @{}; $first0 = $days[0].Date.AddDays(-[int]$days[0].Date.DayOfWeek)
foreach ($d in $days) { $c0 = [int][Math]::Floor(($d.Date - $first0).Days / 7); if (-not $wk.ContainsKey($c0)) { $wk[$c0] = 0 }; $wk[$c0] += $d.Count }
$nW = ($wk.Keys | Measure-Object -Maximum).Maximum + 1; $wMax = [Math]::Max(1, ($wk.Values | Measure-Object -Maximum).Maximum)
$sx0 = 790; $sx1 = 1160; $sy0 = 62; $sy1 = 86
$pts = @(); $peak = $null
for ($k = 0; $k -lt $nW; $k++) { $v = 0; if ($wk.ContainsKey($k)) { $v = $wk[$k] }; $px = $sx0 + ($sx1 - $sx0) * $k / [Math]::Max(1, $nW - 1); $py = $sy1 - ($sy1 - $sy0) * $v / $wMax; $pts += , @($px, $py); if ($v -eq $wMax -and -not $peak) { $peak = @($px, $py) } }
$line = 'M' + (($pts | ForEach-Object { "$(F $_[0]),$(F $_[1])" }) -join ' L')
$area = $line + " L$(F $sx1),$(F $sy1) L$(F $sx0),$(F $sy1) Z"
Add-Svg "<defs><linearGradient id=`"spkG`" x1=`"0`" y1=`"0`" x2=`"0`" y2=`"1`"><stop offset=`"0`" style=`"stop-color:var(--soft);stop-opacity:.15`"/><stop offset=`"1`" style=`"stop-color:var(--accent);stop-opacity:0`"/></linearGradient><clipPath id=`"spkC`"><rect class=`"spk-wipe`" x=`"$($sx0 - 4)`" y=`"$($sy0 - 8)`" width=`"$($sx1 - $sx0 + 12)`" height=`"$($sy1 - $sy0 + 12)`"/></clipPath></defs>"
Add-Svg "<g clip-path=`"url(#spkC)`"><path class=`"spk-area`" d=`"$area`"/><path class=`"spk-line`" d=`"$line`"/></g>"
if ($peak) { Add-Svg "<circle class=`"spk-peak`" cx=`"$(F $peak[0])`" cy=`"$(F $peak[1])`" r=`"3.2`"/><circle class=`"spk-ring`" cx=`"$(F $peak[0])`" cy=`"$(F $peak[1])`" r=`"3.2`" style=`"transform-origin:$(F $peak[0])px $(F $peak[1])px`"/>" }
Add-Svg "<text class=`"mono spk-t`" x=`"$sx1`" y=`"$($sy0 - 10)`" text-anchor=`"end`">rythme / semaine &#xB7; pic $wMax</text>"
Add-Css ".spk-wipe { animation: spkWipe 1.8s cubic-bezier(.4,0,.2,1) 1.1s both; } @keyframes spkWipe { from { width: 0px; } } .spk-area { fill: url(#spkG); } .spk-line { fill: none; stroke: var(--soft); stroke-width: 1.8; stroke-linejoin: round; } .spk-peak { fill: var(--accent); animation: fade .4s ease 2.8s both; } .spk-ring { fill: none; stroke: var(--accent); stroke-width: 1.5; animation: spkRing 1.8s ease-out 3s infinite; opacity: 0; } @keyframes spkRing { from { opacity: .9; transform: scale(1); } to { opacity: 0; transform: scale(3.2); } } .spk-t { fill: var(--soft); font-size: 11px; letter-spacing: 1px; animation: fade .5s ease 2.6s both; } @media (max-width: 520px) { .spk-t, .spk-line, .spk-area, .spk-peak, .spk-ring { display: none; } }"
# active-days ring next to the 4th number
$ratio = $active / [Math]::Max(1, $days.Count); $circ = 2 * [Math]::PI * 20
$dx = 468 + 3 * 176 + 136; $dy = 124
Add-Svg "<circle class=`"don-bg`" cx=`"$dx`" cy=`"$dy`" r=`"20`"/><circle class=`"don`" cx=`"$dx`" cy=`"$dy`" r=`"20`" style=`"stroke-dasharray:$(F ($circ * $ratio)) $(F $circ);transform-origin:$($dx)px $($dy)px`"/><text class=`"mono don-t`" x=`"$dx`" y=`"$($dy + 4)`" text-anchor=`"middle`">$([Math]::Round($ratio * 100))%</text>"
Add-Css ".don-bg { fill: none; stroke: var(--grid); stroke-width: 5; opacity: .6; } .don { fill: none; stroke: var(--g3); stroke-width: 5; stroke-linecap: round; transform: rotate(-90deg); animation: donIn 1.4s cubic-bezier(.3,0,.2,1) 1.6s both; } @keyframes donIn { from { stroke-dasharray: 0 $(F $circ); } } .don-t { fill: var(--ink); font-size: 12px; font-weight: 700; animation: fade .4s ease 2.6s both; } @media (max-width: 520px) { .don, .don-bg, .don-t { display: none; } }"
# light glint travelling along the split bar once it has filled
Add-Svg "<defs><linearGradient id=`"barShG`" x1=`"0`" x2=`"1`"><stop offset=`"0`" stop-color=`"#FFFFFF`" stop-opacity=`"0`"/><stop offset=`".5`" stop-color=`"#FFFFFF`" stop-opacity=`".75`"/><stop offset=`"1`" stop-color=`"#FFFFFF`" stop-opacity=`"0`"/></linearGradient><clipPath id=`"barClip`"><rect x=`"468`" y=`"194`" width=`"690`" height=`"7`" rx=`"2`"/></clipPath></defs><g clip-path=`"url(#barClip)`"><rect class=`"bar-glint`" x=`"408`" y=`"192`" width=`"60`" height=`"11`" fill=`"url(#barShG)`"/></g>"
Add-Css ".bar-glint { opacity: 0; animation: barGlint 1.4s ease-in-out 2.4s 2 both; } @keyframes barGlint { 0% { opacity: 1; transform: translateX(0px); } 100% { opacity: 1; transform: translateX(760px); } }"
}
# --- panel C: contribution calendar as screentone
Add-Tab 40 280 124 'CALENDRIER' .6
$best = ''; if ($max -gt 0) { $best = "meilleur jour : $(N $max) contribution$(if ($max -gt 1) { 's' })" }
Add-Svg "<text class=`"mono l2 in`" x=`"272`" y=`"299`" style=`"animation-delay:.8s`">$best</text>"
$bestXY = $null; $todayXY = $null
$first = $days[0].Date.AddDays(-[int]$days[0].Date.DayOfWeek)
$gridRight = 46 + [int][Math]::Floor(($days[$days.Count - 1].Date - $first).Days / 7) * 16 + 6
# Legend right-aligned to the grid: "moins [] [] [] [] [] plus"
$lx = $gridRight - 130
Add-Svg "<text class=`"mono l2 in`" x=`"$lx`" y=`"299`" text-anchor=`"end`" style=`"animation-delay:.9s`">moins</text>"
for ($k = 0; $k -le 4; $k++) { Add-Svg "<rect class=`"v$k in leg`" x=`"$($lx + 8 + $k * 16)`" y=`"289`" width=`"12`" height=`"12`" rx=`"2.5`" style=`"animation-delay:.9s`"/>" }
Add-Svg "<text class=`"mono l2 in`" x=`"$($gridRight)`" y=`"299`" text-anchor=`"end`" style=`"animation-delay:.9s`">plus</text>"
$months = @('jan', 'f&#xE9;v', 'mars', 'avr', 'mai', 'juin', 'juil', 'ao&#xFB;t', 'sept', 'oct', 'nov', 'd&#xE9;c')
$lastCol = -10; $lastMonth = -1
foreach ($d in $days) {
  $col = [int][Math]::Floor(($d.Date - $first).Days / 7); $row = [int]$d.Date.DayOfWeek
  $x = 46 + $col * 16; $y = 328 + $row * 16
  $lvl = [int]$d.Level
  if ($d.Count -eq $max -and $null -eq $bestXY) { $bestXY = @($x, $y) }
  $todayXY = @($x, $y)
  Add-Svg "<rect class=`"h v$lvl`" x=`"$($x - 6)`" y=`"$($y - 6)`" width=`"12`" height=`"12`" rx=`"2.5`" style=`"transform-origin:$($x)px $($y)px;animation-delay:$(F (1.0 + ($col + $row) * .016))s`"/>"
  if ($row -eq 0 -and $d.Date.Month -ne $lastMonth) {
    if ($col - $lastCol -ge 3 -and $col -gt 0) { Add-Svg "<text class=`"mono mo in`" x=`"$($x - 4)`" y=`"447`" style=`"animation-delay:1.6s`">$($months[$d.Date.Month - 1])</text>"; $lastCol = $col }
    $lastMonth = $d.Date.Month
  }
}

# calendar markers: best day framed in accent, today's cell pulsing
if ($bestXY) { Add-Svg "<rect class=`"best`" x=`"$($bestXY[0] - 9)`" y=`"$($bestXY[1] - 9)`" width=`"18`" height=`"18`" rx=`"4`"/>" }
if ($todayXY) { Add-Svg "<rect class=`"today`" x=`"$($todayXY[0] - 7)`" y=`"$($todayXY[1] - 7)`" width=`"14`" height=`"14`" rx=`"3`" style=`"transform-origin:$($todayXY[0])px $($todayXY[1])px`"/>" }
Add-Css '.best { fill: none; stroke: var(--accent); stroke-width: 1.8; animation: fade .5s ease 2.2s both; }'
Add-Css '.today { fill: none; stroke: var(--ink); stroke-width: 1.6; animation: todayPulse 1.8s ease-in-out 2.4s infinite; } @keyframes todayPulse { 50% { transform: scale(1.6); opacity: .15; } }'
Add-Css '.float { transform-origin: 1076px 349px; animation: floatY 3s ease-in-out 1.6s infinite; } @keyframes floatY { 50% { transform: translateY(-4px); } }'
Add-Css '.bubble rect { fill: var(--grid); opacity: .55; } .bubble { animation: fade .4s ease 1.8s both; } .bd { fill: var(--ink); animation: typing 1.2s ease-in-out infinite; } @keyframes typing { 0%, 60%, 100% { opacity: .25; transform: translateY(0); } 30% { opacity: 1; transform: translateY(-2px); } }'
Add-Css '@media (max-width: 520px) { .bubble, .best, .rec { display: none; } }'
# --- panel D: contact
Add-Tab 1004 280 112 'CONTACT' .7
Add-Svg "<g class=`"stampg`" style=`"transform-origin:1076px 349px;animation-delay:1.1s`"><g class=`"float`"><path class=`"ic-dc`" transform=`"translate(1057 330) scale(1.6)`" d=`"M20 4.4A19 19 0 0 0 15.4 3l-.6 1.2a17.6 17.6 0 0 0-5.6 0L8.6 3A19 19 0 0 0 4 4.4C1.1 8.8.3 13 .7 17.2a19 19 0 0 0 5.8 2.9l1.2-2-1.9-.9.5-.4a13.6 13.6 0 0 0 11.4 0l.5.4-1.9.9 1.2 2a19 19 0 0 0 5.8-2.9c.5-4.9-.8-9.1-3.3-12.8ZM8.5 14.6c-1.1 0-2-1-2-2.3s.9-2.3 2-2.3 2 1 2 2.3-.9 2.3-2 2.3Zm7 0c-1.1 0-2-1-2-2.3s.9-2.3 2-2.3 2 1 2 2.3-.9 2.3-2 2.3Z`"/></g></g>"
Add-Svg "<g class=`"bubble`"><rect x=`"1098`" y=`"318`" width=`"40`" height=`"22`" rx=`"11`"/><circle class=`"bd`" cx=`"1110`" cy=`"329`" r=`"2.6`"/><circle class=`"bd`" cx=`"1118`" cy=`"329`" r=`"2.6`" style=`"animation-delay:.2s`"/><circle class=`"bd`" cx=`"1126`" cy=`"329`" r=`"2.6`" style=`"animation-delay:.4s`"/></g>"
Add-Svg "<text class=`"mono k3 in`" x=`"1076`" y=`"400`" text-anchor=`"middle`" style=`"animation-delay:1.2s`">sur discord</text>"
Add-Svg "<text class=`"mono handle in`" x=`"1076`" y=`"432`" text-anchor=`"middle`" style=`"animation-delay:1.25s`">$(X $Discord)</text>"

# ------------------------------------------------------------------ document
$label = X "Stats GitHub de $User : streak actuel $current $(if ($current -le 1) { 'jour' } else { 'jours' }), record sur 12 mois $longest $jl, $total contributions sur 12 mois, $commits commits, $prs pull requests, $active jours actifs. Discord : $Discord."
$doc = @'
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 1200 470" width="1200" height="470" role="img" aria-label="__LABEL__">
  <title>__LABEL__</title>
  <style>
__FONTS__
    :root { --paper:#FFFFFF; --ink:#0A0A0A; --soft:#595959; --grid:#C4C8CE;
      --g0:#E1E4E8; --g1:#9BE9A8; --g2:#40C463; --g3:#30A14E; --g4:#216E39; --rc2:#116329; --cellline:rgba(27,31,35,.06); --haloOp:.55; --rimOp:.35;
      --accent:#DC3E42; --rcHalo:#FFD1D2; --rcBand:#E5484D; --rcEdge:#A3171D; --rcFlow:#FFB3B5; --pr:#8250DF; --is:#BC4C00; --dc:#5865F2; --rv:#0969DA; --segot:#8C959F; }
    @media (prefers-color-scheme: dark) { :root { --paper:#0D1117; --ink:#E8E8E6; --soft:#9A9A9A; --grid:#3A414B;
      --g0:#161B22; --g1:#0E4429; --g2:#006D32; --g3:#26A641; --g4:#39D353; --rc2:#0E4429; --cellline:rgba(255,255,255,.05); --haloOp:.9; --rimOp:.55;
      --accent:#F2555A; --rcHalo:#4A1418; --rcBand:#E5484D; --rcEdge:#FF8A8D; --rcFlow:#7A1E24; --pr:#A371F7; --is:#DB6D28; --dc:#8A92F7; --rv:#4493F8; --segot:#4A525C; } }
    .fill { fill: var(--paper); }
    .edge { fill: none; stroke: var(--ink); stroke-width: 5; stroke-linejoin: miter; stroke-linecap: butt; }
    .ink { fill: var(--ink); } .paper { fill: var(--paper); }
    .heavy { font-family: 'SG', "Segoe UI", -apple-system, "Helvetica Neue", Arial, sans-serif; font-weight: 700; }
    .sans { font-family: 'SG', "Segoe UI", -apple-system, "Helvetica Neue", Arial, sans-serif; font-weight: 700; }
    .mono { font-family: 'JB', ui-monospace, "Cascadia Code", "SF Mono", Menlo, Consolas, monospace; }
    .tabm { fill: var(--accent); animation: tabm .35s cubic-bezier(.7,0,.2,1) both; }
    text.tabl { fill: var(--ink); font-family: 'SG', "Segoe UI", Arial, sans-serif; font-size: 16px; font-weight: 700; letter-spacing: 3.5px; animation: tabl .45s cubic-bezier(.2,.7,.2,1) both; }
    .tabr { stroke: var(--grid); stroke-width: 1.5; animation: tabr .6s cubic-bezier(.2,.7,.2,1) both; }
    @keyframes tabm { from { transform: scaleY(0); } }
    @keyframes tabl { from { opacity: 0; transform: translateX(-10px); } }
    @keyframes tabr { from { transform: scaleX(0); } }
    .rcHalo { fill: var(--rcHalo); opacity: var(--haloOp); } .rcBand { fill: var(--rcBand); } .rcRim { fill: var(--rcEdge); opacity: var(--rimOp); }
    .rcMem { fill: none; stroke: var(--rcEdge); stroke-width: 1.5; opacity: .8; }
    .rcNuc { fill: var(--rcEdge); } .rcSat { fill: var(--rcBand); }
    .rcg { animation: grow .8s cubic-bezier(.3,1.4,.5,1) .35s both; }
    @keyframes grow { from { opacity: 0; transform: scale(.6); } }
    .beat { animation: beat 2.8s ease-in-out 1.6s infinite; }
    .rcg.zero .beat { animation: none; }
    @keyframes beat { 0%, 40%, 100% { transform: scale(1); } 10% { transform: scale(1.035); } 20% { transform: scale(.995); } 28% { transform: scale(1.02); } }
    .rcFlow { fill: var(--rcFlow); opacity: .9; }
    .ic-acc { fill: var(--soft); } .ic-com { fill: var(--g3); } .ic-pr { fill: var(--pr); } .ic-day { fill: var(--soft); } .ic-dc { fill: var(--dc); }
    .seg-com { fill: var(--g3); } .seg-pr { fill: var(--pr); } .seg-is { fill: var(--is); } .seg-rv { fill: var(--rv); } .seg-ot { fill: var(--segot); }
    .seg { animation: segIn .6s cubic-bezier(.2,.7,.2,1) both; } @keyframes segIn { from { transform: scaleX(0); } }
    .bl { fill: var(--soft); font-size: 13px; }
    .m-only { display: none; }
    .m-l1 { fill: var(--ink); font-size: 28px; letter-spacing: 0; }
    .m-rec { fill: var(--ink); font-size: 28px; }
    /* phones: the 1200-wide image is shown ~0.3x, so drop small detail and enlarge what matters */
    @media (max-width: 520px) {
      .sd, .tabr, .k1, .k3, .k4, .l1, .l2, .leg, .mo, .barleg, .seg, .ic-acc, .ic-com, .ic-pr, .ic-day { display: none; }
      text.tabl { font-size: 24px; letter-spacing: 2px; }
      .handle { font-size: 44px; }
      .m-only { display: inline; }
    }
    @media (prefers-reduced-motion: reduce) { .rcFlow { display: none; } }
    .rcg.zero .rcHalo, .rcg.zero .rcBand, .rcg.zero .rcRim, .rcg.zero .rcNuc, .rcg.zero .rcSat { fill: var(--grid); }
    .rcg.zero .rcMem { stroke: var(--grid); }
    .label { font-size: 14px; font-weight: 700; letter-spacing: 2.5px; }
    .k1 { fill: var(--soft); font-size: 15px; font-weight: 400; letter-spacing: 0; }
    .k2 { fill: var(--soft); font-size: 14px; letter-spacing: 1.5px; }
    .k3 { fill: var(--soft); font-size: 14px; letter-spacing: 0; }
    .k4 { fill: var(--ink); font-size: 22px; }
    .num { fill: var(--ink); letter-spacing: -2px; }
    .big { fill: var(--ink); font-size: 52px; letter-spacing: -1.5px; }
    .l1 { fill: var(--soft); font-size: 14px; font-weight: 400; letter-spacing: .4px; }
    .l2 { fill: var(--soft); font-size: 14px; }
    .mo { fill: var(--soft); font-size: 14px; letter-spacing: 1px; }
    .handle { fill: var(--ink); font-size: 30px; font-weight: 700; }
    .num.zero { fill: var(--soft); }
    .rcg.zero .cell circle { animation: none; }
    .v0 { stroke: var(--cellline); stroke-width: 1; }
    .cell { animation: pop .5s cubic-bezier(.3,1.6,.5,1) both; }
    .w0, .w1, .w2 { animation: w0 3s ease-in-out infinite alternate; }
    .w1 { animation-name: w1; } .w2 { animation-name: w2; }
    @keyframes w0 { to { transform: translate(3px, -3px) scale(1.12); } }
    @keyframes w1 { to { transform: translate(-3px, 2px) scale(.88); } }
    @keyframes w2 { to { transform: translate(2px, 3px) scale(1.06); } }
    .rule { stroke: var(--grid); stroke-width: 1.5; }
    .v0 { fill: var(--g0); } .v1 { fill: var(--g1); } .v2 { fill: var(--g2); } .v3 { fill: var(--g3); } .v4 { fill: var(--g4); }
    .sd { fill: var(--grid); animation: pop .5s ease-out both; }
    .h { animation: sq .55s cubic-bezier(.3,1.3,.5,1) both; }
    @keyframes sq { 0% { opacity: 0; transform: translateY(-12px) scale(.3); } 60% { opacity: 1; transform: translateY(1px) scale(1.18); } 100% { transform: none; } }
    .tab { animation: tab .4s cubic-bezier(.7,0,.2,1) both; }
    .tabt, .in { animation: fade .4s ease both; }
    .col { animation: rise .6s cubic-bezier(.2,.7,.2,1) both; }
    .num { transform-origin: 286px 138px; animation: stampS .45s cubic-bezier(.3,1.5,.5,1) 1.15s both; }
    .stampg { animation: stampS .45s cubic-bezier(.3,1.5,.5,1) both; }
    @keyframes pop { from { opacity: 0; transform: scale(0); } }
    @keyframes tab { from { transform: scaleX(0); } }
    @keyframes fade { from { opacity: 0; } }
    @keyframes rise { from { opacity: 0; transform: translateY(18px); } }
    @keyframes stampS { from { opacity: 0; transform: scale(1.4) rotate(-6deg); } }
__CSS__
    @media (prefers-reduced-motion: reduce) { * { animation: none !important; } }
  </style>
__BODY__
__EDGES__
</svg>
'@
# Embedded fonts (assets/fonts.css next to scripts/); falls back to system fonts if missing.
$fontsCss = ''
$fontsPath = Join-Path (Join-Path $PSScriptRoot '..') 'assets/fonts.css'
if ($PSScriptRoot -and (Test-Path $fontsPath)) { $fontsCss = [System.IO.File]::ReadAllText((Resolve-Path $fontsPath).Path, [System.Text.Encoding]::UTF8) }
$doc = $doc.Replace('__FONTS__', $fontsCss)
$doc = $doc.Replace('__LABEL__', $label).Replace('__CSS__', $css.ToString().TrimEnd()).Replace('__BODY__', $svg.ToString().TrimEnd()).Replace('__EDGES__', $edges.ToString().TrimEnd())
# ------------------------------------------------------------------ one manga "page": banner + about (static parts) + stats
# Parts are stacked as nested <svg> viewports so every px transform-origin stays relative to its own part.
function Split-Svg([string]$text) {
  $a = $text.IndexOf('<style>') + 7; $b = $text.IndexOf('</style>')
  $style = $text.Substring($a, $b - $a)
  $style = (($style -split "`n") | Where-Object { $_ -notmatch '^\s*@font-face' -and $_ -notmatch '^\s*/\* Space Grotesk' }) -join "`n"
  $body = $text.Substring($b + 8, $text.LastIndexOf('</svg>') - $b - 8).Replace((Get-DecoDefs), '')
  return @{ style = $style; body = $body }
}
$partsDir = Join-Path (Join-Path $PSScriptRoot '..') 'parts'
$pB = Split-Svg ([System.IO.File]::ReadAllText((Join-Path $partsDir 'banner.svg'), [System.Text.Encoding]::UTF8))
$pA = Split-Svg ([System.IO.File]::ReadAllText((Join-Path $partsDir 'about.svg'), [System.Text.Encoding]::UTF8))
$pS = Split-Svg $doc
$W = 1260; $H = 1226
$updated = [datetime]::UtcNow.ToString('dd/MM/yyyy', $inv)
$pageLabel = X "Minka : d&#xE9;veloppeur Roblox, Garry's Mod et bots Discord, admin syst&#xE8;me, h&#xE9;berg&#xE9; chez SafeHost (Arkaia). En ce moment : gamemode Demon Slayer, projets Roblox, bots Discord en Python, formation TSSR (syst&#xE8;mes et r&#xE9;seaux, Linux, Debian). Streak actuel $current $(if ($current -le 1) { 'jour' } else { 'jours' }), $total contributions sur 12 mois, $active jours actifs."
$pageLabel = $pageLabel.Replace('&amp;#x', '&#x')
$page = @'
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 __W__ __H__" width="__W__" height="__H__" role="img" aria-label="__LABEL__">
  <title>__LABEL__</title>
  <style>
__FONTS__
__STYLE_B__
__STYLE_A__
__STYLE_S__
    /* page frame */
    .pg-out { fill: none; stroke: var(--ink); stroke-width: 2; stroke-dasharray: 4924; animation: pgDraw 1.4s cubic-bezier(.6,0,.3,1) both; }
    .pg-in { fill: none; stroke: var(--grid); stroke-width: 1; animation: fade .8s ease .9s both; }
    .pg-foot { fill: var(--soft); font-family: 'JB', ui-monospace, Consolas, monospace; font-size: 14px; letter-spacing: 0; animation: fade .8s ease 1.5s both; }
    @keyframes pgDraw { from { stroke-dashoffset: 4924; } }
    @media (max-width: 520px) { .pg-foot { display: none; } }
  </style>
  <rect class="pg-out" x="6" y="6" width="1248" height="1214"/>
  <rect class="pg-in" x="16" y="16" width="1228" height="1194"/>
 __DEFS__
  <svg x="30" y="30" width="1200" height="340" viewBox="0 0 1200 340" overflow="visible">__BODY_B__</svg>
  <svg x="30" y="370" width="1200" height="340" viewBox="0 0 1200 340" overflow="visible">__BODY_A__</svg>
  <svg x="30" y="710" width="1200" height="470" viewBox="0 0 1200 470" overflow="visible">__BODY_S__</svg>

  <text class="pg-foot" x="40" y="1200">github.com/Minka-a</text>
  <text class="pg-foot" x="1220" y="1200" text-anchor="end">mis &#xE0; jour le __DATE__</text>
</svg>
'@
$page = $page.Replace('__W__', "$W").Replace('__H__', "$H").Replace('__LABEL__', $pageLabel).Replace('__DATE__', $updated).Replace('__DEFS__', (Get-DecoDefs))
$page = $page.Replace('__STYLE_B__', $pB.style).Replace('__STYLE_A__', $pA.style).Replace('__STYLE_S__', $pS.style)
$lastIdx = -1; for ($k = $days.Count - 1; $k -ge 0; $k--) { if ($days[$k].Count -gt 0) { $lastIdx = $k; break } }
if ($lastIdx -lt 0) { $actTxt = "pas d'activit&#xE9; r&#xE9;cente" } else { $actTxt = "derni&#xE8;re contribution le $($days[$lastIdx].Date.ToString('dd/MM'))" }
$pB.body = $pB.body.Replace('__LASTACT__', "<circle class=`"act-dot`" cx=`"152`" cy=`"59`" r=`"4`"/><text class=`"mono act-t`" x=`"164`" y=`"64`">$actTxt</text>")
$page = $page.Replace('__BODY_B__', $pB.body).Replace('__BODY_A__', $pA.body).Replace('__BODY_S__', $pS.body)
$page = $page.Replace('__FONTS__', $fontsCss)
[System.IO.File]::WriteAllText($Out, $page, (New-Object System.Text.UTF8Encoding($false)))
$base = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($Out), [System.IO.Path]::GetFileNameWithoutExtension($Out))
[System.IO.File]::WriteAllText("$base-dark.svg", $page.Replace('@media (prefers-color-scheme: dark)', '@media all'), (New-Object System.Text.UTF8Encoding($false)))
[System.IO.File]::WriteAllText("$base-light.svg", $page.Replace('@media (prefers-color-scheme: dark)', '@media not all'), (New-Object System.Text.UTF8Encoding($false)))
"profile.svg: streak $current, record $longest, total $total, commits $commits, prs $prs, issues $issues, revues $reviews, active $active"
