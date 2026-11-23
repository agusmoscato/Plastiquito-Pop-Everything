# Regenera todos los .glb y renders de control. $env:BLENDER para otro ejecutable (hoy 4.5.10 LTS).
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$bl = if ($env:BLENDER) { $env:BLENDER } else { "C:\Program Files\Blender Foundation\Blender 4.5\blender.exe" }
$out = Join-Path $root "assets\models"
$ren = Join-Path $root "art\renders"
New-Item -ItemType Directory -Force $out, $ren | Out-Null
function Run($script, $name, $extra) {
    Write-Host "== $name"
    & $bl -b --factory-startup -P "art/models/$script.py" -- --out "$out\$name.glb" --render $ren @extra |
        Select-String -Pattern "TRIS|Error|Traceback"
}
# Mano y manitos: base MakeHuman/MPFB (CC0). Requiere tools/get_mpfb.sh una vez.
Run "hand_mpfb" "hand_ghost" @("--no-arm")
Run "hand_mpfb" "hand" @()
foreach ($m in "pin", "iron", "boot", "roller") { Run $m $m @() }
foreach ($w in "gem", "bomb", "line") { Run "specials" "special_$w" @("--which", $w) }
foreach ($w in "cup", "pencil", "chair_leg", "shelf", "cone") { Run "props" "prop_$w" @("--which", $w) }
# Utilería argentina (mesa, living, depósito, el club y la mesa del asado de la 0.7.3).
foreach ($w in "mate", "termo", "yerba", "pelota", "alpargatas", "sifon", "garrafa", "cajon", "chulengo", "conservadora", "lampara", "silla", "paredon", "cola", "control", "bizcochos", "pizarra", "bolsa", "tablon") { Run "argentina" "prop_$w" @("--which", $w) }
