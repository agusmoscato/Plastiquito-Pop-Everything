"""Plancha: base con forma de gota, suela metálica con agujeros de vapor, manija curva, dial de
temperatura y cable. Largo 0,30 m a lo largo de +Y (la punta hacia +Y); origen en el centro de la suela."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
import bpy
import bmesh
from mathutils import Vector
from art import lib

A = lib.args()
lib.reset()


def teardrop(n=40, length=0.30, width=0.13, tail=0.55):
    """Contorno en gota: redondo atrás, afinado hacia la punta (+Y)."""
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        x = math.cos(a)
        y = math.sin(a)
        # y>0 es la punta: se afina; y<0 es el talón redondo.
        k = 1.0 - tail * max(0.0, y) ** 1.6
        pts.append((x * width * 0.5 * k, y * length * 0.5 + (0.0)))
    return pts


def extrude_shape(name, outline, z0, z1, taper=1.0):
    bm = bmesh.new()
    bot = [bm.verts.new((x, y, z0)) for (x, y) in outline]
    top = [bm.verts.new((x * taper, y * taper, z1)) for (x, y) in outline]
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((bot[i], bot[j], top[j], top[i]))
    bm.faces.new(list(reversed(bot)))
    bm.faces.new(top)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


steel = lib.material("steel", lib.hex_color("#C9CDD1"), rough=0.28, metal=0.9)
body_mat = lib.material("iron_body", lib.hex_color("#E8E4DA"), rough=0.35)
red = lib.material("iron_red", lib.hex_color("#C8322B"), rough=0.4)
dark = lib.material("iron_dark", lib.hex_color("#2B2A33"), rough=0.5)

sole = extrude_shape("sole", teardrop(), 0.0, 0.012, 1.0)
lib.bevel(sole, 0.003, 2)
sole.data.materials.append(steel)
shell = extrude_shape("shell", teardrop(36, 0.28, 0.115, 0.5), 0.012, 0.062, 0.78)
lib.bevel(shell, 0.004, 1)
shell.data.materials.append(body_mat)
band = extrude_shape("band", teardrop(36, 0.265, 0.10, 0.45), 0.055, 0.074, 0.7)
band.data.materials.append(red)

# Manija curva: un arco de tubo sobre el cuerpo.
arch_pts = []
for i in range(11):
    t = i / 10.0
    y = -0.07 + 0.15 * t
    z = 0.07 + 0.075 * math.sin(math.pi * t) ** 0.8
    arch_pts.append((0.0, y, z))
arch_r = [0.012, 0.0125, 0.0145, 0.0155, 0.0160, 0.0160, 0.0155, 0.0145, 0.0130, 0.0125, 0.012]
handle = lib.tube_along("handle", arch_pts, arch_r, sides=14, squash=0.8)
lib.subsurf(handle, 1)
handle.data.materials.append(red)

# Dial de temperatura en la punta del cuerpo.
dial = lib.revolve_profile("dial", [(0.0, 0.0), (0.014, 0.0), (0.015, 0.006), (0.012, 0.012), (0.0, 0.013)], 24)
dial.location = (0.0, 0.092, 0.060)
dial.data.materials.append(dark)

# Agujeros de vapor en la suela (se ven como círculos oscuros sobre el borde de la suela).
holes = []
for i, (x, y) in enumerate([(-0.026, 0.02), (0.026, 0.02), (-0.032, 0.06), (0.032, 0.06), (0.0, 0.085), (-0.02, -0.04), (0.02, -0.04), (0.0, 0.0)]):
    h = lib.revolve_profile("vent%d" % i, [(0.0, 0.0), (0.0065, 0.0), (0.0065, 0.0014), (0.0, 0.0014)], 12)
    h.location = (x, y, 0.0125 if False else 0.0)
    h.data.materials.append(dark)
    holes.append(h)

# Cable: tubo ondulado que sale por atrás.
cable_pts = [(0.0, -0.14, 0.045), (0.0, -0.18, 0.035), (0.02, -0.23, 0.02), (-0.02, -0.28, 0.012), (0.0, -0.33, 0.01)]
cable = lib.tube_along("cable", cable_pts, [0.007] * 5, sides=8)
cable.data.materials.append(dark)

parts = [sole, shell, band, handle, dial, cable] + holes
for p in parts:
    lib.apply_modifiers(p)
obj = lib.join(parts, "iron")
lib.triangulate(obj)
lib.smooth(obj, 50.0)
lib.unwrap(obj)
print("TRIS", lib.triangles(obj))
if A["out"]:
    lib.export_glb(A["out"])
if A["render"]:
    lib.render_set(A["render"], "iron")
