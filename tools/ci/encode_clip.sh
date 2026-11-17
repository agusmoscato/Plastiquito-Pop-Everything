#!/usr/bin/env bash
# Convierte <ruta>.avi (Movie Maker) a MP4 (H.264 veryfast CRF 20, AAC) y escribe <ruta>_audio.txt
# con volumedetect y astats. Si pasa de 15 MB, vuelve a codificar con CRF 26.
# Uso: tools/ci/encode_clip.sh out/clips/clip_1_zoom_out
set -u
BASE="$1"
[ -f "$BASE.avi" ] || { echo "falta $BASE.avi"; exit 0; }
enc() { ffmpeg -y -loglevel error -i "$BASE.avi" -c:v libx264 -preset veryfast -crf "$1" -pix_fmt yuv420p \
  -c:a aac -b:a 160k -movflags +faststart "$BASE.mp4"; }
enc 20
if [ "$(stat -c %s "$BASE.mp4")" -gt 15000000 ]; then enc 26; fi
{
  echo "archivo: $(basename "$BASE").mp4  $(( $(stat -c %s "$BASE.mp4") / 1024 )) KB"
  ffprobe -v error -show_entries format=duration -of default=nw=1 "$BASE.mp4"
  echo "--- volumedetect"
  ffmpeg -hide_banner -nostats -i "$BASE.avi" -af volumedetect -vn -f null - 2>&1 | grep -E "mean_volume|max_volume|histogram"
  echo "--- astats (general)"
  ffmpeg -hide_banner -nostats -i "$BASE.avi" -af astats=measure_overall=Peak_level+RMS_level+RMS_peak+Flat_factor+Peak_count:measure_perchannel=none -vn -f null - 2>&1 \
    | grep -E "Overall|Peak level|RMS level|RMS peak|Flat factor|Peak count" | sed 's/^\[[^]]*\] //'
  echo "--- RMS por segundo (dB), para ver picos del crepitar"
  ffmpeg -hide_banner -nostats -i "$BASE.avi" -af "asetnsamples=44100,astats=metadata=1:reset=1,ametadata=print:key=lavfi.astats.Overall.RMS_level" -vn -f null - 2>&1 \
    | grep -oE "RMS_level=-?[0-9.inf]+" | cut -d= -f2 | tr '\n' ' '
  echo
} > "${BASE}_audio.txt" 2>&1
# Cuatro cuadros de control
for s in 2 5 8 11; do ffmpeg -y -loglevel error -ss "$s" -i "$BASE.mp4" -frames:v 1 "${BASE}_f${s}s.png" || true; done
