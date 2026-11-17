#!/usr/bin/env bash
# Junta lo que generaron los trabajos de render: PNG -> JPG (1600 px máx., calidad 85), logs, MP4,
# reportes de audio y un RESUMEN.md. Uso: tools/ci/publish_prepare.sh <entrada> <salida> <mensaje>
set -u
IN="$1"
OUT="$2"
MSG="$3"
mkdir -p "$OUT"
cd "$IN"
find . -type f | while read -r f; do
  rel="${f#./}"
  dest="$OLDPWD/$OUT/$rel"
  mkdir -p "$(dirname "$dest")"
  case "$f" in
    *.png) convert "$f" -resize '1600x1600>' -quality 85 "${dest%.png}.jpg" ;;
    *) cp "$f" "$dest" ;;
  esac
done
cd "$OLDPWD"
{
  echo "# Render $(basename "$OUT")"
  echo
  echo "Commit: $(echo "$MSG" | head -n1)"
  echo
  echo "## Logs"
  for c in $(find "$OUT" -name 'check_*.txt' | sort); do echo; echo '```'; cat "$c"; echo '```'; done
  echo
  echo "## Audio"
  for a in $(find "$OUT" -name '*_audio.txt' | sort); do echo; echo '```'; cat "$a"; echo '```'; done
  echo
  echo "## Archivos"
  (cd "$OUT" && find . -type f | sort | sed 's/^\.\//- /')
} > "$OUT/RESUMEN.md"
du -sh "$OUT"
