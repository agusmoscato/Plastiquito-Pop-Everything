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
leather = lib.material("leather", lib.hex_color("#6B4A2E"), rough=0.6)
rubber = lib.material("sole", lib.hex_color("#1E1B18"), rough=0.8)
lace = lib.material("lace", lib.hex_color("#F4EFE6"), rough=0.7)
steel = lib.material("steel_toe", lib.hex_color("#9AA3AA"), rough=0.35, metal=0.7)

# Suela: contorno de pie (ancha en el antepié, angosta en el arco), extruida y con bisel.
outline = []
for i in range(36):
    a = 2 * math.pi * i / 36
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
# Dibujo de la suela: tacos en filas alternadas.
for row in range(9):
    for col in range(5):
        x = (col - 2) * 0.026 + (0.013 if row % 2 else 0.0)
        y = -0.12 + row * 0.03
        if abs(x) < 0.058 - 0.0 and abs(y) < 0.14:
            lug = lib.box("lug", (0.022, 0.020, 0.020), (x, y, -0.008))
            lug.data.materials.append(rubber)
            parts.append(lug)
# Pie: tubo de sección achatada desde el talón hasta la puntera, con la punta redondeada.
foot_pts = [(0, -0.150, 0.060), (0, -0.138, 0.070), (0, -0.07, 0.07), (0, 0.0, 0.062), (0, 0.075, 0.055), (0, 0.130, 0.045), (0, 0.160, 0.036), (0, 0.168, 0.033)]
foot_r = [0.014, 0.046, 0.057, 0.059, 0.058, 0.050, 0.030, 0.012]
foot = lib.tube_along("foot", foot_pts, foot_r, sides=18, squash=0.88)
lib.subsurf(foot, 1)
foot.data.materials.append(leather)
parts.append(foot)
# Puntera de acero (semiesfera achatada).
toe = lib.sphere("toecap", 0.055, (0.0, 0.118, 0.052), 20, 12, (1.0, 1.25, 0.8))
toe.data.materials.append(steel)
parts.append(toe)
# Caña: tubo vertical que sube desde el tobillo, con un reborde acolchado arriba.
shaft_pts = [(0, -0.080, 0.070), (0, -0.082, 0.150), (0, -0.084, 0.230), (0, -0.085, 0.296), (0, -0.085, 0.318), (0, -0.085, 0.324)]
shaft_r = [0.040, 0.052, 0.048, 0.054, 0.060, 0.050]
shaft = lib.tube_along("shaft", shaft_pts, shaft_r, sides=20, squash=0.95)
lib.subsurf(shaft, 1)
shaft.data.materials.append(leather)
parts.append(shaft)
# Lengüeta y cordones: cinco cruces sobre el empeine.
for k in range(5):
    y = -0.045 + k * 0.032
    z = 0.098 - k * 0.006
    cross = lib.box("lace", (0.060, 0.007, 0.006), (0.0, y, z + 0.004), (0.0, 0.0, 0.0))
    cross.data.materials.append(lace)
    parts.append(cross)
    for sx in (-0.026, 0.026):
        eyelet = lib.sphere("eye", 0.0055, (sx, y, z), 8, 6)
        eyelet.data.materials.append(steel)
        parts.append(eyelet)
lib.finish(parts, "boot", A)
