"""Burbujas especiales: gem (dorada facetada), bomb (con mecha trenzada) y line (alargada con bandas).
Uso: art/models/specials.py -- --out assets/models/special.glb --which gem|bomb|line"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
import bpy
import bmesh
from art import lib

A = lib.args()
which = "gem"
if "--which" in sys.argv:
    which = sys.argv[sys.argv.index("--which") + 1]
lib.reset()
gold = lib.material("gold", lib.hex_color("#F2C94C"), rough=0.2, metal=0.95, emission=lib.hex_color("#F2B531"))
parts = []
if which == "gem":
    # Joya: una pirámide doble facetada (corona + pabellón) con tabla plana, ligeramente irregular.
    bm = bmesh.new()
    ring_top = []
    ring_mid = []
    n = 8
    for i in range(n):
        a = 2 * math.pi * i / n
        j = 1.0 + 0.04 * math.sin(3 * a)
        ring_top.append(bm.verts.new((0.16 * math.cos(a) * j, 0.16 * math.sin(a) * j, 0.28)))
        ring_mid.append(bm.verts.new((0.30 * math.cos(a + 0.2) * j, 0.30 * math.sin(a + 0.2) * j, 0.20)))
    apex = bm.verts.new((0.0, 0.0, 0.0))
    table = bm.verts.new((0.0, 0.0, 0.30))
    for i in range(n):
        k = (i + 1) % n
        bm.faces.new((ring_top[i], ring_top[k], table))
        bm.faces.new((ring_mid[i], ring_mid[k], ring_top[k], ring_top[i]))
        bm.faces.new((ring_mid[k], ring_mid[i], apex))
    me = bpy.data.meshes.new("gem")
    bm.to_mesh(me)
    bm.free()
    g = bpy.data.objects.new("gem", me)
    bpy.context.scene.collection.objects.link(g)
    g.data.materials.append(gold)
    parts.append(g)
elif which == "bomb":
    iron = lib.material("bomb_iron", lib.hex_color("#2B2A33"), rough=0.35, metal=0.5)
    redm = lib.material("bomb_red", lib.hex_color("#C8322B"), rough=0.5)
    ball = lib.sphere("ball", 0.30, (0, 0, 0.30), 28, 18, (1.0, 1.0, 0.96))
    ball.data.materials.append(iron)
    band = lib.sphere("band", 0.304, (0, 0, 0.30), 28, 6, (1.0, 1.0, 0.18))
    band.data.materials.append(redm)
    neck = lib.revolve_profile("neck", [(0.0, 0.0), (0.085, 0.0), (0.09, 0.05), (0.07, 0.085), (0.0, 0.09)], 18)
    neck.location = (0, 0, 0.57)
    neck.data.materials.append(iron)
    # Mecha trenzada: tres hebras que se enroscan alrededor de un eje curvo.
    for s in range(3):
        pts = []
        for i in range(14):
            t = i / 13.0
            ang = 2 * math.pi * s / 3 + t * 9.0
            cx = 0.10 * t + 0.0
            cz = 0.64 + 0.22 * t - 0.03 * t * t
            pts.append((cx + 0.016 * math.cos(ang), 0.016 * math.sin(ang), cz))
        strand = lib.tube_along("strand%d" % s, pts, [0.012] * 14, sides=6)
        strand.data.materials.append(lib.material("fuse", lib.hex_color("#C8A27A"), rough=0.9))
        parts.append(strand)
    spark = lib.sphere("spark", 0.035, (0.105, 0, 0.865), 10, 6)
    spark.data.materials.append(lib.material("spark", lib.hex_color("#FF8A2A"), rough=0.3, emission=lib.hex_color("#FF6A1A")))
    parts += [ball, band, neck, spark]
else:
    teal = lib.material("line_teal", lib.hex_color("#2FB8CC"), rough=0.3)
    white = lib.material("line_white", lib.hex_color("#F4EFE6"), rough=0.4)
    body = lib.tube_along("capsule", [(-0.45, 0, 0.2), (-0.40, 0, 0.2), (-0.2, 0, 0.2), (0.2, 0, 0.2), (0.40, 0, 0.2), (0.45, 0, 0.2)],
                          [0.03, 0.17, 0.2, 0.2, 0.17, 0.03], sides=22, squash=0.92)
    lib.subsurf(body, 1)
    body.data.materials.append(teal)
    parts.append(body)
    for x in (-0.22, 0.0, 0.22):
        stripe = lib.revolve_profile("band", [(0.2, -0.03), (0.212, -0.02), (0.212, 0.02), (0.2, 0.03)], 22)
        stripe.rotation_euler = (0.0, math.radians(90.0), 0.0)
        stripe.location = (x, 0, 0.2)
        stripe.data.materials.append(white)
        parts.append(stripe)
lib.finish(parts, "special_" + which, A)
