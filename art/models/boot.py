"""Bota de trabajo: puntera, suela con dibujo profundo, cordones y caña. Largo 0,30 m hacia +Y;
el origen está en el centro de la suela, en el suelo."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
import bpy
import bmesh
from art import lib

A = lib.args()
lib.reset()
leather = lib.material("leather", lib.hex_color("#5A3519"), rough=0.6)
rubber = lib.material("sole", lib.hex_color("#1E1B18"), rough=0.8)
lace = lib.material("lace", lib.hex_color("#F4EFE6"), rough=0.7)
steel = lib.material("steel_toe", lib.hex_color("#9AA3AA"), rough=0.35, metal=0.7)

# Suela: contorno de pie (ancha en el antepié, angosta en el arco), extruida y con bisel.
outline = []
for i in range(28):
    a = 2 * math.pi * i / 28
    c, s = math.cos(a), math.sin(a)
    w = 0.062 * (1.0 + 0.10 * s if s > 0 else 1.0 - 0.18 * math.exp(-((s + 0.2) ** 2) * 8))
    outline.append((c * w, s * 0.150 - 0.0))
bm = bmesh.new()
bot = [bm.verts.new((x, y, 0.0)) for x, y in outline]
top = [bm.verts.new((x * 1.0, y * 1.0, 0.028)) for x, y in outline]
n = len(outline)
for i in range(n):
    j = (i + 1) % n
    bm.faces.new((bot[i], bot[j], top[j], top[i]))
bm.faces.new(list(reversed(bot)))
bm.faces.new(top)
me = bpy.data.meshes.new("sole")
bm.to_mesh(me)
bm.free()
sole = bpy.data.objects.new("sole", me)
bpy.context.scene.collection.objects.link(sole)
lib.bevel(sole, 0.004, 2)
sole.data.materials.append(rubber)
parts = [sole]
# Dibujo de la suela: chevrones biselados (dos tacos inclinados por fila) y bloque de talón marcado.
heel = lib.box("heel", (0.098, 0.062, 0.016), (0.0, -0.108, -0.006))
lib.bevel(heel, 0.005, 1)
heel.data.materials.append(rubber)
parts.append(heel)
for row in range(7):
    y = -0.040 + row * 0.027
    wd = 0.056 - 0.0012 * abs(row - 2) ** 2 * (1 if y > 0.07 else 0.4)
    for sgn in (-1, 1):
        x = sgn * 0.024 * (0.9 if y > 0.09 else 1.0)
        if y > 0.11:
            continue
        lug = lib.box("lug", (0.030, 0.012, 0.012), (x, y, -0.003), (0.0, 0.0, math.radians(-24.0 * sgn)))
        lib.bevel(lug, 0.0035, 1)
        lug.data.materials.append(rubber)
        parts.append(lug)
for y in (0.125, 0.150):
    lug = lib.box("lug", (0.060 if y < 0.14 else 0.040, 0.012, 0.012), (0.0, y, -0.003))
    lib.bevel(lug, 0.0035, 1)
    lug.data.materials.append(rubber)
    parts.append(lug)
# Pie: tubo de sección achatada desde el talón hasta la puntera, con la punta redondeada.
foot_pts = [(0, -0.150, 0.060), (0, -0.138, 0.070), (0, -0.07, 0.07), (0, 0.0, 0.062), (0, 0.075, 0.055), (0, 0.130, 0.045), (0, 0.160, 0.036), (0, 0.168, 0.033)]
foot_r = [0.014, 0.046, 0.057, 0.059, 0.058, 0.050, 0.030, 0.012]
foot = lib.tube_along("foot", foot_pts, foot_r, sides=14, squash=0.88)
lib.subsurf(foot, 1)
foot.data.materials.append(leather)
parts.append(foot)
# Puntera de acero (semiesfera achatada).
toe_m = lib.material("toe_leather", lib.hex_color("#33200F"), rough=0.5)
toe = lib.sphere("toecap", 0.054, (0.0, 0.116, 0.047), 16, 10, (1.0, 1.22, 0.74))
toe.data.materials.append(toe_m)
parts.append(toe)
# Caña: tubo vertical que sube desde el tobillo, con un reborde acolchado arriba.
shaft_pts = [(0, -0.080, 0.070), (0, -0.082, 0.120), (0, -0.084, 0.170), (0, -0.086, 0.205), (0, -0.087, 0.222), (0, -0.087, 0.228)]
shaft_r = [0.040, 0.044, 0.039, 0.043, 0.049, 0.043]
shaft = lib.tube_along("shaft", shaft_pts, shaft_r, sides=14, squash=0.95)
lib.subsurf(shaft, 1)
shaft.data.materials.append(leather)
parts.append(shaft)
tongue = lib.box("tongue", (0.050, 0.150, 0.008), (0.0, 0.0, 0.112), (math.radians(-6.0), 0.0, 0.0))
lib.bevel(tongue, 0.003, 1)
tongue.data.materials.append(leather)
parts.append(tongue)
# Lengüeta y cordones: cinco cruces sobre el empeine.
for k in range(5):
    y = -0.045 + k * 0.032
    z = 0.128 - k * 0.009
    cross = lib.box("lace", (0.056, 0.007, 0.006), (0.0, y, z + 0.004), (math.radians(-6.0), 0.0, 0.0))
    cross.data.materials.append(lace)
    parts.append(cross)
    for sx in (-0.030, 0.030):
        eyelet = lib.sphere("eye", 0.0055, (sx, y, z), 8, 6)
        eyelet.data.materials.append(steel)
        parts.append(eyelet)
mouth = lib.sphere("mouth", 0.040, (0.0, -0.087, 0.226), 14, 6, (1.0, 1.0, 0.18))
mouth.data.materials.append(rubber)
parts.append(mouth)
lib.finish(parts, "boot", A)
