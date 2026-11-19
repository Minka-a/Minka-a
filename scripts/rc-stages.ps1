# Streak creature: the RC-cell visual evolves with the current streak.
#   0        dormant  : petrified grey nucleus, still
#   1-6      I  NOYAU    : one organic cell + small cells orbiting with trails
#   7-29     II GRAPPE   : cluster of inked cells joined by bridges, one dividing
#   30-99    III MEMBRANE: morphing membrane ring (built in stats.ps1) + veins + hooks below/above
#   100+     IV KAGUNE   : inked tentacles with scales and a glowing vein, cracks, shock ring
# Manga look: thick ink outlines under the coloured shapes, halftone on the shaded half,
# specular highlights, soft drop shadows, glow. Every SMIL-animated shape also has a still copy
# shown when the viewer asks for reduced motion (.rcLive / .rcStill).
# Dot-sourced by stats.ps1; uses its F function and $cx/$cy. ASCII only.
function Get-RcStage([int]$n) {
  if ($n -le 0) { return 0 } elseif ($n -lt 7) { return 1 } elseif ($n -lt 30) { return 2 } elseif ($n -lt 100) { return 3 } else { return 4 }
}
$script:RcStageNames = @('en sommeil', 'stade I &#xB7; noyau', 'stade II &#xB7; grappe', 'stade III &#xB7; membrane', 'stade IV &#xB7; kagune')
$script:RcNext = @(1, 7, 30, 100, 0)

$script:RcCss = @'
    :root { --rcInk: #0A0A0A; --rcHi: #FFFFFF; --rcSpecOp: .5; --rcD1: #C2C7CE; --rcD2: #A6ACB4; --rcD3: #7E858E; }
    @media (prefers-color-scheme: dark) { :root { --rcInk: #050505; --rcSpecOp: .24; --rcD1: #4A525C; --rcD2: #262C35; --rcD3: #14181E; } }
    .rcStill { display: none; }
    @media (prefers-reduced-motion: reduce) { .rcLive { display: none; } .rcStill { display: inline; } }
    .rcToneDot { fill: var(--rcInk); opacity: .5; }
    .rcInkS { fill: none; stroke: var(--rcInk); stroke-width: 7; stroke-linejoin: round; }
    .rcCyt { fill: url(#rcCyto); stroke: var(--rcEdge); stroke-width: 2; }
    .rcToneF { fill: url(#rcTone); }
    .rcSpec { fill: var(--rcHi); opacity: var(--rcSpecOp); }
    .rcSpecArc { fill: none; stroke: var(--rcHi); stroke-width: 3.2; stroke-linecap: round; opacity: var(--rcSpecOp); }
    .rcNuclInk { fill: var(--paper); stroke: var(--rcInk); stroke-width: 3.5; } .rcNuclRim { fill: none; stroke: var(--rcEdge); stroke-width: 1.4; }
    .rcOrg { fill: #5C0F14; stroke: var(--rcInk); stroke-width: .8; }
    .rcShadowE { fill: url(#rcShadowG); }
    .rcHaloC { fill: var(--rcHalo); opacity: var(--haloOp); }
    .rcGlowR { fill: none; stroke: var(--rcBand); opacity: .45; }
    .rcOrbit { fill: none; stroke: var(--rcEdge); stroke-width: 1; stroke-dasharray: 2 6; opacity: .45; }
    .rcOrbCell { fill: url(#rcCyto); stroke: var(--rcInk); stroke-width: 1.8; }
    .rcTrail { fill: none; stroke: var(--rcEdge); stroke-width: 2.6; stroke-linecap: round; opacity: .55; }
    .rcFocus { stroke: var(--grid); stroke-width: 1.3; stroke-linecap: round; opacity: .4; }
    .rcSat { fill: url(#rcCyto); stroke: var(--rcEdge); stroke-width: 1.5; }
    .rcSatInk { fill: none; stroke: var(--rcInk); stroke-width: 4.5; stroke-linejoin: round; }
    .rcSatN { fill: #5C0F14; }
    .rcPinch { fill: none; stroke: var(--rcHi); stroke-width: 1.4; stroke-linecap: round; opacity: .7; }
    .rcBridgeInk { stroke: var(--rcInk); stroke-width: 5.5; stroke-linecap: round; }
    .rcBridge { stroke: var(--rcBand); stroke-width: 2.6; stroke-linecap: round; stroke-dasharray: 4 5; animation: rcBridgeFlow 1.4s linear infinite; }
    @keyframes rcBridgeFlow { to { stroke-dashoffset: -18; } }
    .rcVein { fill: none; stroke: var(--rcHi); stroke-width: 1.8; stroke-linecap: round; stroke-dasharray: 5 7; opacity: .75; animation: veinFlow 1.6s linear infinite; }
    @keyframes veinFlow { to { stroke-dashoffset: -24; } }
    .rcPart { fill: var(--rcEdge); opacity: 0; animation: rcPart 3.2s ease-out infinite; }
    @keyframes rcPart { 0% { transform: translate(0px, 0px); opacity: 0; } 20% { opacity: .95; } 100% { transform: translate(var(--dx), var(--dy)); opacity: 0; } }
    .rcCrack { fill: none; stroke: var(--accent); stroke-width: 1.4; stroke-linecap: round; animation: rcCrack 2.4s ease-in-out infinite; }
    @keyframes rcCrack { 0%, 100% { opacity: .3; } 50% { opacity: .95; } }
    .rcShock { fill: none; stroke: var(--accent); stroke-width: 2; opacity: 0; transform-box: fill-box; transform-origin: center; animation: rcShock 3s ease-out 1.6s infinite; }
    @keyframes rcShock { 0% { opacity: .8; transform: scale(1); } 100% { opacity: 0; transform: scale(2); } }
    .rcTentB { fill: url(#rcCyto); stroke: var(--rcInk); stroke-width: 4.5; stroke-linejoin: round; paint-order: stroke; }
    .rcScale { fill: none; stroke: var(--rcInk); stroke-width: 4.5; stroke-dasharray: 2.5 6; opacity: .85; }
    .rcGlowV { fill: none; stroke: var(--rcHi); stroke-width: 1.4; stroke-linecap: round; opacity: .75; stroke-dasharray: 6 6; animation: veinFlow 1.1s linear infinite; }
    .rcDormS { fill: url(#rcDormG); stroke: var(--rcD1); stroke-width: 1.6; }
    .rcCrackD { fill: none; stroke: var(--rcD3); stroke-width: 1.4; stroke-linecap: round; }
    .rcDormN { fill: var(--paper); stroke: var(--rcInk); stroke-width: 3; } .rcDormRim { fill: none; stroke: var(--rcD1); stroke-width: 1.2; }
    .rcSleep { animation: rcSleep 6s ease-in-out infinite; } @keyframes rcSleep { 50% { transform: scale(1.015); } }
    .stage { fill: var(--accent); font-size: 13px; font-weight: 700; letter-spacing: 0; animation: fade .5s ease 1.3s both; }
    .stage-n { fill: var(--soft); font-size: 11px; letter-spacing: 1px; animation: fade .5s ease 1.4s both; }
    @media (max-width: 520px) { .stage, .stage-n, .rcFocus, .rcPart { display: none; } }
'@

# ---------------------------------------------------------------- shared pieces
function Get-RcDefs {
  $p = "$(F ($cx - 170)),$(F ($cy + 6)) $(F ($cx + 170)),$(F ($cy - 56)) $(F ($cx + 170)),$(F ($cy + 170)) $(F ($cx - 170)),$(F ($cy + 170))"
  return '<defs>' +
    '<filter id="rcGlow" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur stdDeviation="5" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>' +
    '<pattern id="rcTone" width="5" height="5" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><circle class="rcToneDot" cx="2.5" cy="2.5" r="1.05"/></pattern>' +
    '<radialGradient id="rcCyto" cx="35%" cy="30%" r="75%"><stop offset="0" stop-color="#FF7A7E"/><stop offset=".5" stop-color="#EE2A3A"/><stop offset="1" stop-color="#7E0C16"/></radialGradient>' +
    '<radialGradient id="rcShadowG" r="50%"><stop offset="0" stop-color="#000000" stop-opacity=".45"/><stop offset="1" stop-color="#000000" stop-opacity="0"/></radialGradient>' +
    '<radialGradient id="rcDormG" cx="34%" cy="28%" r="80%"><stop offset="0" style="stop-color:var(--rcD1)"/><stop offset=".6" style="stop-color:var(--rcD2)"/><stop offset="1" style="stop-color:var(--rcD3)"/></radialGradient>' +
    "<clipPath id=`"rcShadeC`"><polygon points=`"$p`"/></clipPath>" +
    '</defs>'
}
function Live-Still([string]$live, [string]$still) { return "<g class=`"rcLive`">$live</g><g class=`"rcStill`">$still</g>" }

# smooth organic blob around (cx+ox, cy+oy): 10 points, closed Catmull-Rom -> cubic Beziers
function Get-BlobD([double]$r, [double]$ph, [double]$amp, [double]$ox = 0, [double]$oy = 0) {
  $N = 10; $pts = @()
  for ($i = 0; $i -lt $N; $i++) {
    $t = 2 * [Math]::PI * $i / $N
    $f = 1 + $amp * (0.6 * [Math]::Sin(2 * $t + $ph) + 0.4 * [Math]::Sin(3 * $t + 1.7 * $ph))
    $pts += , @(($cx + $ox + [Math]::Cos($t) * $r * $f), ($cy + $oy + [Math]::Sin($t) * $r * $f))
  }
  $d = "M$(F $pts[0][0]) $(F $pts[0][1])"
  for ($i = 0; $i -lt $N; $i++) {
    $p0 = $pts[($i - 1 + $N) % $N]; $p1 = $pts[$i]; $p2 = $pts[($i + 1) % $N]; $p3 = $pts[($i + 2) % $N]
    $d += " C$(F ($p1[0] + ($p2[0] - $p0[0]) / 6)) $(F ($p1[1] + ($p2[1] - $p0[1]) / 6)) $(F ($p2[0] - ($p3[0] - $p1[0]) / 6)) $(F ($p2[1] - ($p3[1] - $p1[1]) / 6)) $(F $p2[0]) $(F $p2[1])"
  }
  return $d + 'Z'
}
# blob morphing between 3 variants (same command structure) -> @{ live; still }
function Get-MorphBlob([string]$cls, [double]$r, [double]$amp, [double]$dur, [double]$ox = 0, [double]$oy = 0, [double]$seed = 0) {
  $f = @(0, 2.1, 4.2) | ForEach-Object { Get-BlobD $r ($_ + $seed) $amp $ox $oy }
  $vals = ($f + $f[0]) -join ';'
  $live = "<path class=`"$cls`" d=`"$($f[0])`"><animate attributeName=`"d`" dur=`"$($dur)s`" repeatCount=`"indefinite`" calcMode=`"spline`" keyTimes=`"0;.33;.66;1`" keySplines=`".45 0 .55 1;.45 0 .55 1;.45 0 .55 1`" values=`"$vals`"/></path>"
  return @{ live = $live; still = "<path class=`"$cls`" d=`"$($f[0])`"/>"; d = $f[0] }
}

function Get-RcCore([double]$r) {
  # inked organic cell, halftone shade, organelles, specular, and a paper nucleus so the number stays readable
  $ink = Get-MorphBlob 'rcInkS' $r .06 7
  $cyt = Get-MorphBlob 'rcCyt' $r .06 7
  $out = "<ellipse class=`"rcShadowE`" cx=`"$cx`" cy=`"$(F ($cy + $r + 14))`" rx=`"$(F ($r * 1.25))`" ry=`"7`"/>"
  $out += "<circle class=`"rcHaloC`" cx=`"$cx`" cy=`"$cy`" r=`"$(F ($r + 10))`"/>"
  $out += Live-Still ($ink.live + $cyt.live) ($ink.still + $cyt.still)
  $out += "<path class=`"rcToneF`" clip-path=`"url(#rcShadeC)`" d=`"$($cyt.d)`"/>"
  foreach ($o in @(@(-.62, -.28, -30), @(.58, -.5, 35), @(.66, .36, -50), @(-.5, .56, 20))) {
    $ex = $cx + $o[0] * $r; $ey = $cy + $o[1] * $r
    $out += "<ellipse class=`"rcOrg`" cx=`"$(F $ex)`" cy=`"$(F $ey)`" rx=`"$(F ($r * .13))`" ry=`"$(F ($r * .055))`" transform=`"rotate($($o[2]) $(F $ex) $(F $ey))`"/>"
  }
  $sx = $cx - $r * .4; $sy = $cy - $r * .55
  $out += "<ellipse class=`"rcSpec`" cx=`"$(F $sx)`" cy=`"$(F $sy)`" rx=`"$(F ($r * .3))`" ry=`"$(F ($r * .11))`" transform=`"rotate(-28 $(F $sx) $(F $sy))`"/>"
  $out += "<circle class=`"rcNuclInk`" cx=`"$cx`" cy=`"$cy`" r=`"$(F ($r * .74))`"/><circle class=`"rcNuclRim`" cx=`"$cx`" cy=`"$cy`" r=`"$(F ($r * .74 - 3))`"/>"
  return $out
}
function Wrap-Rc([string]$inner) {
  return "<g class=`"rcg`" style=`"transform-origin:$($cx)px $($cy)px`"><g class=`"beat`" style=`"transform-origin:$($cx)px $($cy)px`">$inner</g></g>"
}
# manga focus lines behind the creature, kept inside the panel and off the text on the left
function Get-RcFocus([double]$r1, [double]$r2) {
  $sb = New-Object System.Text.StringBuilder
  for ($deg = 0; $deg -lt 360; $deg += 18) {
    $a = $deg * [Math]::PI / 180; $k = 1 + .12 * [Math]::Sin($deg)
    $x1 = $cx + [Math]::Cos($a) * $r1; $y1 = $cy + [Math]::Sin($a) * $r1
    $x2 = $cx + [Math]::Cos($a) * $r2 * $k; $y2 = $cy + [Math]::Sin($a) * $r2 * $k
    if ($x2 -lt 192 -or $x2 -gt 368 -or $y2 -lt 24 -or $y2 -gt 226 -or $x1 -lt 192) { continue }
    [void]$sb.Append("<line class=`"rcFocus`" x1=`"$(F $x1)`" y1=`"$(F $y1)`" x2=`"$(F $x2)`" y2=`"$(F $y2)`"/>")
  }
  return $sb.ToString()
}
# particles drifting away (CSS), toward the right half only
function Get-RcParticles([int]$n, [double]$base) {
  $sb = New-Object System.Text.StringBuilder
  for ($i = 0; $i -lt $n; $i++) {
    $a = (-80 + 160 * $i / [Math]::Max(1, $n - 1)) * [Math]::PI / 180
    $d = 34 + 12 * (0.5 + 0.5 * [Math]::Sin($i * 2.3))
    $x = $cx + [Math]::Cos($a) * ($base); $y = $cy + [Math]::Sin($a) * ($base * .9)
    $r = 1.3 + .9 * (0.5 + 0.5 * [Math]::Sin($i * 1.7))
    [void]$sb.Append("<circle class=`"rcPart`" cx=`"$(F $x)`" cy=`"$(F $y)`" r=`"$(F $r)`" style=`"--dx:$(F ([Math]::Cos($a) * $d))px;--dy:$(F ([Math]::Sin($a) * $d))px;animation-delay:-$(F ($i * .45))s`"/>")
  }
  return $sb.ToString()
}

# ---------------------------------------------------------------- 0 · dormant
function Get-RcDormant {
  $body = Get-BlobD 46 .8 .05
  $nuc = Get-BlobD 31 2.2 .04
  $out = Get-RcDefs
  $out += "<ellipse class=`"rcShadowE`" cx=`"$cx`" cy=`"$(F ($cy + 60))`" rx=`"58`" ry=`"6`"/>"
  $out += "<g class=`"rcg`" style=`"transform-origin:$($cx)px $($cy)px`"><g class=`"rcSleep`" style=`"transform-origin:$($cx)px $($cy)px`">"
  $out += "<path class=`"rcInkS`" d=`"$body`"/><path class=`"rcDormS`" d=`"$body`"/><path class=`"rcToneF`" clip-path=`"url(#rcShadeC)`" d=`"$body`"/>"
  $out += "<path class=`"rcCrackD`" d=`"M$(F ($cx - 30)) $(F ($cy - 28)) l8 6 l-4 10 M$(F ($cx + 28)) $(F ($cy + 18)) l8 6 l-4 10 M$(F ($cx - 12)) $(F ($cy + 36)) l8 4`"/>"
  $out += "<ellipse class=`"rcSpec`" cx=`"$(F ($cx - 18))`" cy=`"$(F ($cy - 28))`" rx=`"12`" ry=`"5`" transform=`"rotate(-28 $(F ($cx - 18)) $(F ($cy - 28)))`" style=`"opacity:.18`"/>"
  $out += "<path class=`"rcDormN`" d=`"$nuc`"/><path class=`"rcDormRim`" d=`"$nuc`" transform=`"translate($cx $cy) scale(.92) translate(-$cx -$cy)`"/>"
  $out += '</g></g>'
  return $out
}

# ---------------------------------------------------------------- I · noyau
function Get-RcNoyau {
  $live = New-Object System.Text.StringBuilder; $still = New-Object System.Text.StringBuilder
  $orbits = New-Object System.Text.StringBuilder
  foreach ($o in @(@(62, 10, 0, 6.5, 1), @(76, 16, 140, 5, -1), @(56, 7, 250, 4.5, 1))) {
    $rr = $o[0]; $dur = $o[1]; $a = $o[2] * [Math]::PI / 180; $sz = $o[3]; $dir = $o[4]
    $ry = $rr * .9
    [void]$orbits.Append("<ellipse class=`"rcOrbit`" cx=`"$cx`" cy=`"$cy`" rx=`"$rr`" ry=`"$(F $ry)`"/>")
    $x = $cx + [Math]::Cos($a) * $rr; $y = $cy + [Math]::Sin($a) * $ry
    $tb = $a - $dir * .75; $tx = $cx + [Math]::Cos($tb) * $rr; $ty = $cy + [Math]::Sin($tb) * $ry
    $sweep = 1; if ($dir -lt 0) { $sweep = 0 }
    $shape = "<path class=`"rcTrail`" d=`"M$(F $tx) $(F $ty) A$rr $(F $ry) 0 0 $sweep $(F $x) $(F $y)`"/><circle class=`"rcOrbCell`" cx=`"$(F $x)`" cy=`"$(F $y)`" r=`"$sz`"/><circle class=`"rcSatN`" cx=`"$(F ($x + $sz * .25))`" cy=`"$(F ($y - $sz * .2))`" r=`"$(F ($sz * .36))`"/>"
    $from = 0; $to = 360; if ($dir -lt 0) { $from = 360; $to = 0 }
    [void]$live.Append("<g><animateTransform attributeName=`"transform`" type=`"rotate`" from=`"$from $cx $cy`" to=`"$to $cx $cy`" dur=`"$($dur)s`" repeatCount=`"indefinite`"/>$shape</g>")
    [void]$still.Append("<g>$shape</g>")
  }
  $inner = (Get-RcFocus 92 112) + $orbits.ToString() + (Live-Still $live.ToString() $still.ToString()) + (Get-RcCore 42) + (Get-RcParticles 5 58)
  return (Get-RcDefs) + (Wrap-Rc $inner)
}

# ---------------------------------------------------------------- II · grappe
function Get-RcGrappe {
  $n = 7; $cells = @()
  for ($i = 0; $i -lt $n; $i++) {
    $a = 2 * [Math]::PI * $i / $n + 0.2 * [Math]::Sin($i * 2.1) - [Math]::PI / 2
    $rr = 62 + 4 * [Math]::Sin($i * 1.7)
    $r = 15 + 6 * (0.5 + 0.5 * [Math]::Sin($i * 2.9))
    $cells += , @(($cx + [Math]::Cos($a) * $rr), ($cy + [Math]::Sin($a) * $rr * .9), $r, $a)
  }
  $sb = New-Object System.Text.StringBuilder
  # bridges first (ink under, flowing red on top): ring of neighbours + spokes to the core
  for ($i = 0; $i -lt $n; $i++) {
    $p = $cells[$i]; $q = $cells[($i + 1) % $n]
    foreach ($seg in @(@($p[0], $p[1], $q[0], $q[1]), @($p[0], $p[1], $cx, $cy))) {
      $l = "x1=`"$(F $seg[0])`" y1=`"$(F $seg[1])`" x2=`"$(F $seg[2])`" y2=`"$(F $seg[3])`""
      [void]$sb.Append("<line class=`"rcBridgeInk`" $l/><line class=`"rcBridge`" $l/>")
    }
  }
  for ($i = 0; $i -lt $n; $i++) {
    $x = $cells[$i][0]; $y = $cells[$i][1]; $r = $cells[$i][2]; $a = $cells[$i][3]
    $o = "$(F $x)px $(F $y)px"
    $dur = 2.8 + 1.6 * (0.5 + 0.5 * [Math]::Sin($i * 4.1)); $ph = 3 * (0.5 + 0.5 * [Math]::Sin($i * 1.7))
    $g = ''
    if ($i -eq 1) {
      # dividing cell: two daughters pinched together
      $tx = -[Math]::Sin($a) * $r * .45; $ty = [Math]::Cos($a) * $r * .45
      foreach ($sgn in 1, -1) {
        $d = Get-BlobD ($r * .72) ($i + $sgn) .08 ($x - $cx + $sgn * $tx) ($y - $cy + $sgn * $ty)
        $g += "<path class=`"rcSatInk`" d=`"$d`"/><path class=`"rcSat`" d=`"$d`"/><circle class=`"rcSatN`" cx=`"$(F ($x + $sgn * $tx))`" cy=`"$(F ($y + $sgn * $ty))`" r=`"$(F ($r * .22))`"/>"
      }
      $g += "<path class=`"rcPinch`" d=`"M$(F ($x - $ty * .5)) $(F ($y + $tx * .5)) Q$(F $x) $(F $y) $(F ($x + $ty * .5)) $(F ($y - $tx * .5))`"/>"
    } else {
      $d = Get-BlobD $r ($i * 1.3) .09 ($x - $cx) ($y - $cy)
      $nx = $x + [Math]::Cos($a + 1) * $r * .3; $ny = $y + [Math]::Sin($a + 1) * $r * .3
      $g += "<path class=`"rcSatInk`" d=`"$d`"/><path class=`"rcSat`" d=`"$d`"/><circle class=`"rcSatN`" cx=`"$(F $nx)`" cy=`"$(F $ny)`" r=`"$(F ($r * .3))`"/>"
      $g += "<ellipse class=`"rcSpec`" cx=`"$(F ($x - $r * .35))`" cy=`"$(F ($y - $r * .45))`" rx=`"$(F ($r * .3))`" ry=`"$(F ($r * .12))`" transform=`"rotate(-28 $(F ($x - $r * .35)) $(F ($y - $r * .45)))`"/>"
    }
    [void]$sb.Append("<g class=`"cell`" style=`"transform-origin:$o;animation-delay:$(F (.5 + $i * .06))s`"><g class=`"w$($i % 3)`" style=`"transform-origin:$o;animation-duration:$(F $dur)s;animation-delay:-$(F $ph)s`">$g</g></g>")
  }
  $inner = (Get-RcFocus 98 114) + $sb.ToString() + (Get-RcCore 40) + (Get-RcParticles 4 84)
  return (Get-RcDefs) + (Wrap-Rc $inner)
}

# ---------------------------------------------------------------- III · membrane (ring coordinates, scaled by stats.ps1)
function Get-RcVeins {
  # pulses travelling along short branching veins inside the membrane band
  $sb = New-Object System.Text.StringBuilder
  for ($i = 0; $i -lt 12; $i++) {
    $a = 2 * [Math]::PI * $i / 12 + 0.2
    $p = { param($r, $da) "$(F ($cx + [Math]::Cos($a + $da) * $r)) $(F ($cy + [Math]::Sin($a + $da) * $r * .89))" }
    $d = "M$(& $p 72 0) Q$(& $p 79 .07) $(& $p 86 .16) M$(& $p 78 .06) L$(& $p 75 .18) M$(& $p 82 .1) L$(& $p 88 .05)"
    [void]$sb.Append("<path class=`"rcVein`" d=`"$d`" style=`"animation-delay:-$(F ($i * .13))s`"/>")
  }
  return $sb.ToString()
}
function Get-RcMembraneUnder {
  $out = Get-RcDefs
  $out += "<ellipse class=`"rcShadowE`" cx=`"$cx`" cy=`"$(F ($cy + 106))`" rx=`"104`" ry=`"10`"/>"
  $out += "<ellipse class=`"rcGlowR`" cx=`"$cx`" cy=`"$cy`" rx=`"80`" ry=`"71`" stroke-width=`"20`" filter=`"url(#rcGlow)`"/>"
  $out += "<ellipse class=`"rcInkS`" cx=`"$cx`" cy=`"$cy`" rx=`"92`" ry=`"82`" style=`"stroke-width:7`"/>"
  $out += "<ellipse class=`"rcInkS`" cx=`"$cx`" cy=`"$cy`" rx=`"68`" ry=`"60`" style=`"stroke-width:5`"/>"
  return $out
}
function Get-RcMembraneOver {
  $out = "<ellipse cx=`"$cx`" cy=`"$cy`" rx=`"80`" ry=`"71`" fill=`"none`" stroke=`"url(#rcTone)`" stroke-width=`"20`" clip-path=`"url(#rcShadeC)`"/>"
  $a1 = 205 * [Math]::PI / 180; $a2 = 248 * [Math]::PI / 180
  $out += "<path class=`"rcSpecArc`" d=`"M$(F ($cx + [Math]::Cos($a1) * 86)) $(F ($cy + [Math]::Sin($a1) * 76.5)) A86 76.5 0 0 1 $(F ($cx + [Math]::Cos($a2) * 86)) $(F ($cy + [Math]::Sin($a2) * 76.5))`"/>"
  $out += Get-RcParticles 6 96
  return $out
}

# ---------------------------------------------------------------- IV · kagune
function Get-TentaclePath([double]$a0, [double]$len, [double]$curl, [double]$w0) {
  $N = 12; $left = @(); $right = @(); $spine = @()
  for ($k = 0; $k -le $N; $k++) {
    $s = $k / $N
    $a = $a0 + $curl * $s * $s
    $r = 36 + $len * $s
    $x = $cx + [Math]::Cos($a) * $r; $y = $cy + [Math]::Sin($a) * $r
    $nxv = -[Math]::Sin($a + $curl * $s * .8); $nyv = [Math]::Cos($a + $curl * $s * .8)
    $w = $w0 * [Math]::Pow(1 - $s, .8) + 1
    $left += "$(F ($x + $nxv * $w / 2)),$(F ($y + $nyv * $w / 2))"
    $right = @("$(F ($x - $nxv * $w / 2)),$(F ($y - $nyv * $w / 2))") + $right
    if ($k -ge 1) { $spine += "$(F $x),$(F $y)" }
  }
  return @{ body = "M" + (($left + $right) -join ' L') + ' Z'; spine = "M" + ($spine -join ' L') }
}
function Get-RcKagune {
  $tents = @(@(-112, 50, 13, .32), @(-62, 56, 14, .36), @(-16, 54, 14, -.3), @(32, 52, 14, -.34), @(78, 42, 12, -.3))
  $live = New-Object System.Text.StringBuilder; $still = New-Object System.Text.StringBuilder
  $ks = '.45 0 .55 1;.45 0 .55 1;.45 0 .55 1;.45 0 .55 1'
  $j = 0
  foreach ($t in $tents) {
    $a0 = $t[0] * [Math]::PI / 180
    $frames = @(0, 1, 2, 3) | ForEach-Object { Get-TentaclePath $a0 $t[1] ($t[3] * (1 + .45 * [Math]::Sin($_ * [Math]::PI / 2 + $j))) $t[2] }
    $bodies = @($frames | ForEach-Object { $_.body }); $spines = @($frames | ForEach-Object { $_.spine })
    $dur = 5 + $j * .7
    $anim = { param($vals) "<animate attributeName=`"d`" dur=`"$($dur)s`" repeatCount=`"indefinite`" calcMode=`"spline`" keyTimes=`"0;.25;.5;.75;1`" keySplines=`"$ks`" values=`"$(($vals + $vals[0]) -join ';')`"/>" }
    $o = "transform-origin:$($cx)px $($cy)px;animation-delay:$(F (.5 + $j * .1))s"
    [void]$live.Append("<g class=`"cell`" style=`"$o`"><path class=`"rcTentB`" d=`"$($bodies[0])`">$(& $anim $bodies)</path><path class=`"rcScale`" d=`"$($spines[0])`">$(& $anim $spines)</path><path class=`"rcGlowV`" d=`"$($spines[0])`">$(& $anim $spines)</path></g>")
    [void]$still.Append("<g><path class=`"rcTentB`" d=`"$($bodies[0])`"/><path class=`"rcScale`" d=`"$($spines[0])`"/><path class=`"rcGlowV`" d=`"$($spines[0])`"/></g>")
    $j++
  }
  # glowing cracks around the core, toward the right half
  $cr = New-Object System.Text.StringBuilder
  foreach ($deg in -95, -40, 10, 55, 100) {
    $a = $deg * [Math]::PI / 180
    $pts = @(); for ($k = 0; $k -lt 4; $k++) { $rr = 46 + $k * 9; $jit = ($k % 2) * .09 - .045; $pts += "$(F ($cx + [Math]::Cos($a + $jit) * $rr)) $(F ($cy + [Math]::Sin($a + $jit) * $rr))" }
    [void]$cr.Append("<path class=`"rcCrack`" filter=`"url(#rcGlow)`" d=`"M$($pts -join ' L')`" style=`"animation-delay:-$(F (($deg + 95) / 80))s`"/>")
  }
  $shock = "<circle class=`"rcShock`" cx=`"$cx`" cy=`"$cy`" r=`"46`"/>"
  $inner = (Get-RcFocus 104 116) + $shock + (Live-Still $live.ToString() $still.ToString()) + $cr.ToString() + (Get-RcCore 42) + (Get-RcParticles 7 70)
  return (Get-RcDefs) + (Wrap-Rc $inner)
}
