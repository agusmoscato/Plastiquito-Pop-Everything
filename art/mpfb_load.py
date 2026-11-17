"""Carga MPFB (MakeHuman Plugin For Blender; sus assets son CC0) como paquete de Python dentro de
Blender -b, SIN instalarlo como extensión ni tocar las preferencias del usuario. El paquete
descomprimido vive en tools/bin/ext/pkg/mpfb (lo baja tools/get_mpfb.sh) y sus datos de usuario en
tools/bin/ext/mpfb_user (todo ignorado por git).
Uso desde un script de Blender: `from art import mpfb_load; mpfb_load.load()`.
"""
import importlib
import os
import sys

import bpy

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PKG_DIR = os.path.join(ROOT, "tools", "bin", "ext", "pkg")
USER_DIR = os.path.join(ROOT, "tools", "bin", "ext", "mpfb_user")


def load():
    os.makedirs(USER_DIR, exist_ok=True)
    original = bpy.utils.extension_path_user

    def local_user_path(package, *, path="", create=False):
        # MPFB espera vivir en bl_ext.<repo>.mpfb: se le da una carpeta propia dentro del repo.
        if package.split(".")[-1] == "mpfb":
            target = os.path.join(USER_DIR, path) if path else USER_DIR
            if create:
                os.makedirs(target, exist_ok=True)
            return target
        return original(package, path=path, create=create)

    bpy.utils.extension_path_user = local_user_path
    # MPFB lee sus preferencias de preferences.addons["mpfb"]: se agrega la entrada SOLO en memoria
    # (con --factory-startup y sin guardado automático, nada se escribe en las preferencias del usuario).
    prefs = bpy.context.preferences
    prefs.use_preferences_save = False
    if "mpfb" not in prefs.addons:
        prefs.addons.new().module = "mpfb"
    if PKG_DIR not in sys.path:
        sys.path.insert(0, PKG_DIR)
    mpfb = importlib.import_module("mpfb")
    try:
        mpfb.register()
    except Exception as e:  # la interfaz puede fallar sin ventana: los servicios igual andan
        print("mpfb.register:", e)
    return mpfb
