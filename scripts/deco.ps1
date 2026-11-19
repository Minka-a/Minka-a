# Shared panel decoration: screentone drop shadow + inner hairline (manga "double frame").
# Dot-sourced by scripts/stats.ps1 and gen/build.ps1. ASCII only.
$script:decoInv = [System.Globalization.CultureInfo]::InvariantCulture
function Format-Deco([double]$v) { return $v.ToString('0.##', $script:decoInv) }

# Inset a convex polygon (points in screen order: TL, TR, BR, BL) by $d px.
function Get-InsetPoints([double[]]$p, [double]$d) {
  $n = $p.Length / 2; $lines = @()
  for ($i = 0; $i -lt $n; $i++) {
    $x1 = $p[2 * $i]; $y1 = $p[2 * $i + 1]; $j = ($i + 1) % $n
    $dx = $p[2 * $j] - $x1; $dy = $p[2 * $j + 1] - $y1; $L = [Math]::Sqrt($dx * $dx + $dy * $dy)
    $nx = -$dy / $L; $ny = $dx / $L
    $lines += , @(($x1 + $nx * $d), ($y1 + $ny * $d), $dx, $dy)
  }
  $out = @()
  for ($i = 0; $i -lt $n; $i++) {
    $a = $lines[($i - 1 + $n) % $n]; $b = $lines[$i]
    $cross = $a[2] * $b[3] - $a[3] * $b[2]
    $t = (($b[0] - $a[0]) * $b[3] - ($b[1] - $a[1]) * $b[2]) / $cross
    $out += "$(Format-Deco ($a[0] + $t * $a[2])),$(Format-Deco ($a[1] + $t * $a[3]))"
  }
  return $out -join ' '
}
function Get-ShiftPoints([double[]]$p, [double]$dx, [double]$dy) {
  $out = @(); for ($k = 0; $k -lt $p.Length; $k += 2) { $out += "$(Format-Deco ($p[$k] + $dx)),$(Format-Deco ($p[$k+1] + $dy))" }
  return $out -join ' '
}
function Get-DecoDefs {
  return '<defs><pattern id="shTone" width="5" height="5" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><circle class="shDot" cx="2.5" cy="2.5" r="1.15"/></pattern></defs>'
}
function Get-DecoShadow([double[]]$p, [double]$delay) {
  return "<polygon class=`"shadow`" points=`"$(Get-ShiftPoints $p 7 7)`" style=`"animation-delay:$(Format-Deco $delay)s`"/>"
}
function Get-DecoHair([double[]]$p, [double]$delay) {
  # inner hairline + an accent corner tab in the top-left corner, following both edges (slanted ones too)
  $in = (Get-InsetPoints $p 2.5).Split(' ') | ForEach-Object { $xy = $_.Split(','); , @([double]::Parse($xy[0], $script:decoInv), [double]::Parse($xy[1], $script:decoInv)) }
  $c = $in[0]; $nx = $in[1]; $pv = $in[$in.Count - 1]
  $ax = $nx[0] - $c[0]; $ay = $nx[1] - $c[1]; $al = [Math]::Sqrt($ax * $ax + $ay * $ay)
  $bx = $pv[0] - $c[0]; $by = $pv[1] - $c[1]; $bl = [Math]::Sqrt($bx * $bx + $by * $by)
  $k = 15
  $tri = "$(Format-Deco $c[0]),$(Format-Deco $c[1]) $(Format-Deco ($c[0] + $ax / $al * $k)),$(Format-Deco ($c[1] + $ay / $al * $k)) $(Format-Deco ($c[0] + $bx / $bl * $k)),$(Format-Deco ($c[1] + $by / $bl * $k))"
  return "<polygon class=`"hair`" points=`"$(Get-InsetPoints $p 8)`" style=`"animation-delay:$(Format-Deco $delay)s`"/>" +
         "<polygon class=`"corner`" points=`"$tri`" style=`"transform-origin:$(Format-Deco $c[0])px $(Format-Deco $c[1])px;animation-delay:$(Format-Deco ($delay + .1))s`"/>"
}
# Soft screentone in the bottom-right corner of a panel: regular 11px grid, dots grow and darken toward
# the corner, clipped to the panel's inner hairline so nothing touches the border. $radius 0 = no dots.
function Get-DecoDots([double[]]$p, [double]$radius, [double]$delay) {
  if ($radius -le 0) { return '' }
  $in = (Get-InsetPoints $p 14).Split(' ') | ForEach-Object { $xy = $_.Split(','); , @([double]::Parse($xy[0], $script:decoInv), [double]::Parse($xy[1], $script:decoInv)) }
  $cx = $p[4]; $cy = $p[5]
  $sb = New-Object System.Text.StringBuilder
  $s = 11
  $x0 = [Math]::Floor(($cx - $radius) / $s) * $s; $y0 = [Math]::Floor(($cy - $radius) / $s) * $s
  for ($y = $y0; $y -le $cy; $y += $s) {
    for ($x = $x0; $x -le $cx; $x += $s) {
      $d = [Math]::Sqrt(($cx - $x) * ($cx - $x) + ($cy - $y) * ($cy - $y))
      $t = 1 - $d / $radius
      if ($t -le 0.03) { continue }
      # inside the inset polygon (convex, clockwise on screen): every edge cross product >= 0
      $ok = $true
      for ($k = 0; $k -lt $in.Count; $k++) {
        $a = $in[$k]; $b = $in[($k + 1) % $in.Count]
        if ((($b[0] - $a[0]) * ($y - $a[1]) - ($b[1] - $a[1]) * ($x - $a[0])) -lt 0) { $ok = $false; break }
      }
      if (-not $ok) { continue }
      $r = 0.6 + 1.5 * [Math]::Pow($t, 1.15)
      [void]$sb.Append("<circle cx=`"$(Format-Deco $x)`" cy=`"$(Format-Deco $y)`" r=`"$(Format-Deco $r)`" opacity=`"$(Format-Deco (0.3 + 0.7 * $t))`"/>")
    }
  }
  return "<g class=`"ddots`" style=`"animation-delay:$(Format-Deco $delay)s`">$($sb.ToString())</g>"
}
$script:DecoCss = @'
    .ddots { fill: var(--grid); animation: fade 1s ease both; }
    .shadow { fill: url(#shTone); animation: shIn .6s ease-out both; }
    .shDot { fill: var(--soft); opacity: .55; }
    @media (prefers-color-scheme: dark) { .shDot { opacity: .35; } }
    .hair { fill: none; stroke: var(--grid); stroke-width: 1.2; animation: fade .6s ease both; }
    @keyframes shIn { from { opacity: 0; transform: translate(-7px, -7px); } }
    .corner { fill: var(--ink); animation: cornerIn .45s cubic-bezier(.3,1.5,.5,1) both; }
    @keyframes cornerIn { from { transform: scale(0); } }
'@
