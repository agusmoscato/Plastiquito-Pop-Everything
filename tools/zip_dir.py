"""Crea un zip portable: zip_dir.py <carpeta> <salida.zip> <carpeta_raiz_dentro_del_zip>.
Marca como ejecutable (0755) los archivos sin extensión o .x86_64 (binario de Linux)."""
import os
import sys
import zipfile

src, out, root = sys.argv[1], sys.argv[2], sys.argv[3]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for base, _, files in os.walk(src):
        for name in sorted(files):
            path = os.path.join(base, name)
            arc = os.path.join(root, os.path.relpath(path, src)).replace("\\", "/")
            info = zipfile.ZipInfo.from_file(path, arc)
            info.compress_type = zipfile.ZIP_DEFLATED
            mode = 0o755 if name.endswith(".x86_64") else 0o644
            info.external_attr = (mode | 0o100000) << 16
            with open(path, "rb") as f:
                z.writestr(info, f.read())
print(out)
