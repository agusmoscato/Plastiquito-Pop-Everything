# Build de playtest para Windows (equivalente a tools/build.sh).
# Usa $env:GODOT si está definido; si no, "godot" del PATH. Requiere Python para los zips.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$godot = if ($env:GODOT) { $env:GODOT } else { "godot" }

$m = Select-String -Path project.godot -Pattern '^config/version="(.*)"'
if (-not $m) { throw "build: no se encontró config/version en project.godot" }
$version = $m.Matches[0].Groups[1].Value
$out = "builds/$version"
Write-Host "== Plastiquito $version"

Write-Host "== 1/5 Lint y tests"
$bash = (Get-Command bash -ErrorAction SilentlyContinue)
if (-not $bash) { throw "build: hace falta bash (Git Bash) para correr tools/run_tests.sh" }
$env:GODOT = $godot
& bash ./tools/run_tests.sh *> $null
if ($LASTEXITCODE -ne 0) { throw "build: los tests fallaron, abortando" }

Write-Host "== 2/5 Exportar"
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory -Force "$out/windows", "$out/linux" | Out-Null
& $godot --headless --import *> $null
& $godot --headless --path . --export-release "Windows" "$out/windows/Plastiquito.exe" *> "$out/export_windows.log"
& $godot --headless --path . --export-release "Linux" "$out/linux/Plastiquito.x86_64" *> "$out/export_linux.log"
if (-not (Test-Path "$out/windows/Plastiquito.exe")) { throw "build: falló la exportación de Windows" }
if (-not (Test-Path "$out/linux/Plastiquito.x86_64")) { throw "build: falló la exportación de Linux" }

Write-Host "== 3/5 Zips portables"
foreach ($os in "windows", "linux") {
  $stage = "$out/_stage/$os"
  New-Item -ItemType Directory -Force $stage | Out-Null
  Copy-Item "$out/$os/Plastiquito.*" $stage
  if ($os -eq "windows") { $data = '%APPDATA%\Plastiquito\playtest'; $run = 'Hacé doble clic en Plastiquito.exe.' }
  else { $data = '~/.local/share/Plastiquito/playtest'; $run = 'Abrí una terminal en esta carpeta y corré: ./Plastiquito.x86_64' }
  @"
Plastiquito: Pop Everything  v$version  (versión de prueba)

COMO JUGAR
- $run
- Mantené apretado el botón izquierdo del mouse y arrastrá sobre el plástico.
- Rueda del mouse: acercar o alejar.
- Alt+Enter: pantalla completa / ventana.
- Esc: menú (volumen, sacudida, abrir carpeta de datos, salir).
- F12: guarda una captura de pantalla.

REGISTRO DE SESION
El juego guarda en tu disco (no envía nada por internet) un archivo CSV por sesión en:
  $data
También podés abrir esa carpeta desde el menú Esc, botón "Abrir carpeta de datos".
Mandá el archivo más reciente a quien te pasó el juego.
"@ | Set-Content -Encoding UTF8 "$stage/LEEME.txt"
  & python tools/zip_dir.py $stage "$out/Plastiquito_${version}_$os.zip" "Plastiquito_${version}_$os" | Out-Null
}
Remove-Item -Recurse -Force "$out/_stage"

Write-Host "== 4/5 Instalador de Windows"
$iscc = @((Get-Command iscc -ErrorAction SilentlyContinue).Source,
  "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "$env:ProgramFiles\Inno Setup 6\ISCC.exe") | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if ($iscc) {
  $w = (Resolve-Path $root).Path
  & $iscc "/DAppVersion=$version" "/DRepoDir=$w" "/DBuildDir=$w\builds\$version\windows" "/DOutDir=$w\builds\$version" installer\plastiquito.iss *> "$out/inno.log"
  if ($LASTEXITCODE -ne 0) { throw "build: falló Inno Setup (ver $out/inno.log)" }
} else {
  Write-Host "   Inno Setup no está disponible: solo se generaron los zips."
}

Write-Host "== 5/5 Resultado"
Get-ChildItem "$out/Plastiquito_*" | ForEach-Object { "   {0}  ({1:N1} MB)" -f $_.FullName, ($_.Length / 1MB) }
