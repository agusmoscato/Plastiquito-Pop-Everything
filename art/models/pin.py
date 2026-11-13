"""Palo de amasar: madera torneada con perfil de revolución, mangos con cuello y desgaste en los bordes.
Largo 0,62 m a lo largo de X; el origen está en el punto de contacto con la lámina (centro, abajo)."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
import bpy
from art import lib

A = lib.args()
lib.reset()

# Perfil (radio, posición a lo largo del eje) de media pieza; después se espeja. Los mangos tienen
# un cuello fino y una perilla con curvatura; el cuerpo es levemente abarrilado.
half = [(0.0, 0.310), (0.011, 0.309), (0.019, 0.300), (0.0235, 0.284), (0.0245, 0.266), (0.0215, 0.248),
        (0.0165, 0.232), (0.0135, 0.215), (0.0130, 0.198), (0.0150, 0.184), (0.0245, 0.176),
        (0.0385, 0.168), (0.0408, 0.140), (0.0420, 0.080), (0.0425, 0.0), ]
full = [(r, -z) for (r, z) in reversed(half[1:])] + half
full = [(r, z) for (r, z) in full]
profile = [(r, z) for (r, z) in sorted(full, key=lambda t: t[1])]
profile = [(max(r, 0.0), z) for (r, z) in profile]
profile[0] = (0.0, profile[0][1])
profile[-1] = (0.0, profile[-1][1])
obj = lib.revolve_profile("rolling_pin", profile, segments=28)
lib.bevel(obj, 0.0015, 2)
wood = lib.material("wood_turned", lib.hex_color("#B98552"), rough=0.55)
obj.data.materials.append(wood)
lib.apply_modifiers(obj)
lib.triangulate(obj)
lib.smooth(obj, 55.0)
# De eje Z a eje X y apoyado: el punto más bajo (radio 0,0425) toca la lámina en el origen.
obj.rotation_euler = (0.0, math.radians(90.0), 0.0)
obj.location = (0.0, 0.0, 0.0425)
lib.select_only(obj)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=False)
lib.unwrap(obj)
print("TRIS", lib.triangles(obj))
if A["out"]:
    lib.export_glb(A["out"])
if A["render"]:
    lib.render_set(A["render"], "pin")
