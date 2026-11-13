#!/usr/bin/env bash
# Build de playtest: lint + tests, exporta Windows y Linux (release), crea zips portables
# y, si Inno Setup está disponible, el instalador de Windows.
# Usa $GODOT si está definido; si no, "godot" del PATH.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
GODOT_BIN="${GODOT:-godot}"

VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)"
[ -n "$VERSION" ] || { echo "build: no se encontró config/version en project.godot" >&2; exit 1; }
OUT="builds/$VERSION"
echo "== Plastiquito $VERSION"

echo "== 1/5 Lint y tests"
GODOT="$GODOT_BIN" ./tools/run_tests.sh > /dev/null || { echo "build: los tests fallaron, abortando" >&2; exit 1; }

echo "== 2/5 Exportar"
rm -rf "$OUT"
mkdir -p "$OUT/windows" "$OUT/linux"
"$GODOT_BIN" --headless --import > /dev/null 2>&1 || true
"$GODOT_BIN" --headless --path . --export-release "Windows" "$OUT/windows/Plastiquito.exe" > "$OUT/export_windows.log" 2>&1
"$GODOT_BIN" --headless --path . --export-release "Linux" "$OUT/linux/Plastiquito.x86_64" > "$OUT/export_linux.log" 2>&1
[ -f "$OUT/windows/Plastiquito.exe" ] || { echo "build: falló la exportación de Windows (ver $OUT/export_windows.log)" >&2; exit 1; }
[ -f "$OUT/linux/Plastiquito.x86_64" ] || { echo "build: falló la exportación de Linux (ver $OUT/export_linux.log)" >&2; exit 1; }

echo "== 3/5 Zips portables"
STAGE="$OUT/_stage"
rm -rf "$STAGE"
for OS in windows linux; do
  mkdir -p "$STAGE/$OS"
  cp "$OUT/$OS"/Plastiquito.* "$STAGE/$OS/"
  if [ "$OS" = "windows" ]; then
    DATA='%APPDATA%\Plastiquito\playtest'
    RUN='Hacé doble clic en Plastiquito.exe.'
  else
    DATA='~/.local/share/Plastiquito/playtest'
    RUN='Abrí una terminal en esta carpeta y corré: ./Plastiquito.x86_64'
  fi
  cat > "$STAGE/$OS/LEEME.txt" <<TXT
Plastiquito: Pop Everything  v$VERSION  (versión de prueba)

COMO JUGAR
- $RUN
- Mantené apretado el botón izquierdo del mouse y arrastrá sobre el plástico.
- Rueda del mouse: acercar o alejar.
- Alt+Enter: pantalla completa / ventana.
- Esc: menú (volumen, sacudida, abrir carpeta de datos, salir).
- F12: guarda una captura de pantalla.

REGISTRO DE SESION
El juego guarda en tu disco (no envía nada por internet) un archivo CSV por sesión en:
  $DATA
También podés abrir esa carpeta desde el menú Esc, botón "Abrir carpeta de datos".
Mandá el archivo más reciente a quien te pasó el juego.
TXT
  python3 tools/zip_dir.py "$STAGE/$OS" "$OUT/Plastiquito_${VERSION}_${OS}.zip" "Plastiquito_${VERSION}_${OS}" > /dev/null 2>&1 \
    || python tools/zip_dir.py "$STAGE/$OS" "$OUT/Plastiquito_${VERSION}_${OS}.zip" "Plastiquito_${VERSION}_${OS}" > /dev/null
done
rm -rf "$STAGE"

echo "== 4/5 Instalador de Windows"
ISCC=""
for c in "$(command -v iscc || true)" "${LOCALAPPDATA:-}/Programs/Inno Setup 6/ISCC.exe" \
         "/c/Program Files (x86)/Inno Setup 6/ISCC.exe" "/c/Program Files/Inno Setup 6/ISCC.exe"; do
  if [ -n "$c" ] && [ -f "$c" ]; then ISCC="$c"; break; fi
done
if [ -n "$ISCC" ]; then
  WROOT="$ROOT"; command -v cygpath > /dev/null && WROOT="$(cygpath -w "$ROOT")"
  BS='\'
  WOUT="${WROOT}${BS}${OUT//\//$BS}"
  MSYS2_ARG_CONV_EXCL="*" "$ISCC" "/DAppVersion=$VERSION" "/DRepoDir=$WROOT" "/DBuildDir=${WOUT}${BS}windows" \
          "/DOutDir=$WOUT" "installer/plastiquito.iss" > "$OUT/inno.log" 2>&1 \
    || { echo "build: falló Inno Setup (ver $OUT/inno.log)" >&2; exit 1; }
else
  echo "   Inno Setup no está disponible: solo se generaron los zips (el .iss está en installer/)."
fi

echo "== 5/5 Resultado"
for f in "$OUT"/Plastiquito_*; do
  printf '   %s  (%s MB)\n' "$ROOT/$f" "$(( ($(stat -c %s "$f") + 524288) / 1048576 ))"
done
