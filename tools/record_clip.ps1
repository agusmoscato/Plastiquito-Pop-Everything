# Graba una escena de scenes/clips/ con el Movie Maker de Godot (60 fps, con audio).
# Uso: .\tools\record_clip.ps1 -Clip 1 [-Format vertical|horizontal]
#   Clip: 1, 2, 3, 4 (o el nombre completo, por ejemplo clip_1_zoom_out)
#   vertical (por defecto) = 1080x1920 para shorts; horizontal = 1920x1080.
# Deja el archivo en builds\clips\<clip>_<formato>.avi. Usa $env:GODOT o "godot" del PATH.
param(
  [Parameter(Mandatory = $true)][string]$Clip,
  [ValidateSet("vertical", "horizontal")][string]$Format = "vertical"
)
$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)
$godot = if ($env:GODOT) { $env:GODOT } else { "godot" }
$names = @{ "1" = "clip_1_zoom_out"; "2" = "clip_2_pin_wave"; "3" = "clip_3_iron_bomb"; "4" = "clip_4_transition" }
$name = if ($names.ContainsKey($Clip)) { $names[$Clip] } else { $Clip }
if (-not (Test-Path "scenes/clips/$name.tscn")) { throw "no existe scenes/clips/$name.tscn" }
$res = if ($Format -eq "horizontal") { "1920x1080" } else { "1080x1920" }
New-Item -ItemType Directory -Force builds/clips | Out-Null
$out = "builds/clips/${name}_$Format.avi"
& $godot --path . --write-movie $out --fixed-fps 60 --resolution $res "scenes/clips/$name.tscn"
$size = [math]::Round((Get-Item $out).Length / 1MB, 1)
"listo: $out ($size MB)"
