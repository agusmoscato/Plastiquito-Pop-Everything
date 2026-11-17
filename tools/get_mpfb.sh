#!/usr/bin/env bash
# Baja MPFB 2.0.18 (MakeHuman Plugin For Blender) de la tienda oficial de extensiones de Blender y lo
# descomprime en tools/bin/ext/pkg/mpfb (ignorado por git). No lo instala en Blender: los scripts de
# art/ lo cargan con art/mpfb_load.py. Código GPL-3; assets y modelos generados CC0 (ver
# assets/models/LICENSES.md). Verifica el sha256 publicado por extensions.blender.org.
set -eu
cd "$(dirname "$0")/.."
SHA=c075b3e9b94b8e5556a5f03f4653602d02ea306de08126e8f55ed6dee28a2dad
D=tools/bin/ext
mkdir -p "$D/mpfb_zip" "$D/pkg/mpfb"
ZIP="$D/mpfb_zip/add-on-mpfb-v2.0.18.zip"
[ -f "$ZIP" ] || curl -sL -o "$ZIP" "https://extensions.blender.org/download/sha256:$SHA/add-on-mpfb-v2.0.18.zip?repository=%2Fapi%2Fv1%2Fextensions%2F&blender_version_min=4.2.0"
echo "$SHA  $ZIP" | sha256sum -c -
python -I -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$ZIP" "$D/pkg/mpfb"
echo "MPFB listo en $D/pkg/mpfb"
