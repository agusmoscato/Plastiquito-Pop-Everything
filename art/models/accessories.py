"""Accesorios de la mano (sección 3 de la 0.7.0): anillos, pulseras, relojes y puños de guante.

Cada accesorio es un objeto con el nombre de su id (data/accessories.json). Se modela ya en el marco de un
hueso de la mano de hand.glb: eje del dedo/antebrazo = +Y de Godot, dorso = +Z de Godot, ancho = X.
En Blender (Z arriba) eso es: eje = +Z, dorso = -Y. Quedan centrados en el origen del accesorio:
en el juego un BoneAttachment3D los pone en el dedo (anillos) o en la muñeca (pulsera, reloj, guante).

Uso: art/run.sh accessories
"""
import json
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
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = json.load(open(os.path.join(ROOT, "data", "accessories.json"), encoding="utf-8"))["accessories"]

FINGER_R = 0.0118  # radio exterior de un dedo con guante (m)
WRIST_RX = 0.0310  # semieje del antebrazo (ancho) con holgura
WRIST_RY = 0.0235  # semieje del antebrazo (dorso)


def col(hexstr, k=1.0):
    c = lib.hex_color(hexstr)
    return (min(c[0] * k, 1.0), min(c[1] * k, 1.0), min(c[2] * k, 1.0))


def torus(name, major, minor, loc=(0, 0, 0), scale=(1, 1, 1), segs=28, ring_segs=10):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=segs, minor_segments=ring_segs, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return o


def cylinder(name, radius, depth, loc=(0, 0, 0), segs=28, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, vertices=segs, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return o


def ball(name, r, loc, scale=(1, 1, 1)):
    o = lib.sphere(name, r, loc=loc, segs=14, rings=8, scale=scale)
    return o


def paint(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return obj


def dorsal(d):
    """Distancia hacia el dorso (+Z de Godot) -> posición en Blender (-Y)."""
    return -d


def ring(a, parts):
    look = a["look"]
    metal = lib.material(a["id"] + "_band", col(look["color"]), rough=0.28, metal=0.9)
    band = torus(a["id"] + "_b", FINGER_R, 0.0027, scale=(1, 1, 1.35))
    parts.append(paint(band, metal))
    stone = look["stone"]
    if stone == "flat":  # sello: placa plana sobre el dorso del dedo
        plate = cylinder(a["id"] + "_p", 0.0085, 0.0035, loc=(0, dorsal(FINGER_R + 0.0018), 0), segs=24, scale=(1, 1, 1.0))
        plate.rotation_euler = (math.radians(90), 0, 0)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
        parts.append(paint(plate, metal))
    elif stone.startswith("#"):
        gem = lib.material(a["id"] + "_g", col(stone), rough=0.15, metal=0.0, clearcoat=0.8, emission=col(stone, 0.5))
        parts.append(paint(ball(a["id"] + "_s", 0.0052, (0, dorsal(FINGER_R + 0.0025), 0)), gem))


def wrist_loop(name, mat, minor, z=0.0, h=1.0, rx=WRIST_RX, ry=WRIST_RY):
    return paint(torus(name, 1.0, minor, loc=(0, 0, z), scale=(rx, ry, h), segs=40, ring_segs=10), mat)


def bracelet(a, parts):
    look = a["look"]
    base = lib.material(a["id"] + "_m", col(look["color"]), rough=0.7)
    if a["id"] == "bracelet_hilo":
        parts.append(wrist_loop(a["id"] + "_t1", base, 0.0016, z=-0.004))
        parts.append(wrist_loop(a["id"] + "_t2", base, 0.0016, z=0.0, rx=WRIST_RX + 0.001, ry=WRIST_RY + 0.001))
        parts.append(wrist_loop(a["id"] + "_t3", base, 0.0016, z=0.004))
        knot = ball(a["id"] + "_k", 0.0042, (0.0, dorsal(WRIST_RY + 0.002), 0.0))
        parts.append(paint(knot, base))
        for sgn in (-1, 1):  # las puntas del nudo
            tail = cylinder(a["id"] + "_tail%d" % sgn, 0.0011, 0.016, loc=(sgn * 0.004, dorsal(WRIST_RY + 0.004), 0.007), segs=8)
            tail.rotation_euler = (0, math.radians(sgn * 20), 0)
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
            parts.append(paint(tail, base))
    elif a["id"] == "bracelet_cuero":
        for k, z in enumerate((-0.006, 0.0, 0.006)):  # trenza: tres hebras
            parts.append(wrist_loop(a["id"] + "_s%d" % k, base, 0.0034, z=z, h=0.9))
        parts.append(paint(cylinder(a["id"] + "_buckle", 0.0045, 0.002, loc=(0, dorsal(WRIST_RY + 0.0035), 0), segs=6), lib.material("buckle", col("#B9BCC0"), rough=0.3, metal=0.9)))
    else:  # abalorios: cuentas alternadas alrededor de la muñeca
        beads = 22
        stone = lib.material(a["id"] + "_s", col(look["stone"]), rough=0.25)
        for i in range(beads):
            ang = 2 * math.pi * i / beads
            p = (math.cos(ang) * (WRIST_RX + 0.001), math.sin(ang) * (WRIST_RY + 0.001), 0.0)
            parts.append(paint(ball("%s_b%d" % (a["id"], i), 0.0042, p), base if i % 2 == 0 else stone))
        parts.append(wrist_loop(a["id"] + "_str", lib.material("str", col("#3A2A1C"), rough=0.8), 0.0009))


def watch(a, parts):
    look = a["look"]
    case = lib.material(a["id"] + "_c", col(look["color"]), rough=0.3, metal=0.8)
    strap_c = "#6B4226" if a["id"] == "watch_abuela" else "#2B2A33"
    strap = lib.material(a["id"] + "_strap", col(strap_c), rough=0.65)
    parts.append(wrist_loop(a["id"] + "_strap", strap, 0.0032, h=3.2))
    face_c = lib.material(a["id"] + "_f", col(look["stone"]), rough=0.3, emission=col(look["stone"], 0.15))
    top = dorsal(WRIST_RY + 0.0045)
    if a["id"] == "watch_abuela":  # reloj redondo clásico de cuerda
        parts.append(paint(cylinder(a["id"] + "_case", 0.0135, 0.0075, loc=(0, top, 0), segs=32, scale=(1, 1, 1)), case))
        face = cylinder(a["id"] + "_face", 0.0112, 0.0012, loc=(0, top + dorsal(0.0042), 0), segs=32)
        parts.append(paint(face, face_c))
        crown = cylinder(a["id"] + "_crown", 0.0023, 0.004, loc=(0.0, top, 0.0148), segs=10)
        parts.append(paint(crown, case))
        for hx, hz, hrot in ((0.0, 0.0045, 0.0), (0.0035, 0.0, math.radians(90))):  # agujas
            hand = lib.box(a["id"] + "_h", (0.0014, 0.0011, 0.009), loc=(hx * 0.0, top + dorsal(0.0052), hz * 0.5))
            hand.rotation_euler = (0, hrot, 0)
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
            parts.append(paint(hand, lib.material("hand", col("#2B2A33"), rough=0.5)))
    else:  # digital de feria: caja rectangular con pantallita verde
        parts.append(paint(lib.box(a["id"] + "_case", (0.027, 0.0075, 0.023), loc=(0, top, 0)), case))
        scr = lib.box(a["id"] + "_scr", (0.021, 0.0012, 0.015), loc=(0, top + dorsal(0.0042), 0))
        parts.append(paint(scr, face_c))
        for sx in (-1, 1):
            parts.append(paint(lib.box(a["id"] + "_btn%d" % sx, (0.0025, 0.0035, 0.004), loc=(sx * 0.0143, top, 0.006)), case))


def glove(a, parts):
    look = a["look"]
    cloth = lib.material(a["id"] + "_c", col(look["color"]), rough=0.85)
    trim = lib.material(a["id"] + "_t", col(look["stone"] if look["stone"].startswith("#") else look["color"], 0.8), rough=0.85)
    # Puño del guante: un tubo ovalado que envuelve la muñeca, con franjas de otro color.
    parts.append(paint(cylinder(a["id"] + "_cuff", 1.0, 0.040, segs=40, scale=(WRIST_RX + 0.0035, WRIST_RY + 0.0035, 1.0)), cloth))
    for k, z in enumerate((-0.013, 0.0, 0.013)):
        parts.append(wrist_loop(a["id"] + "_stripe%d" % k, trim, 0.0016, z=z, rx=WRIST_RX + 0.0043, ry=WRIST_RY + 0.0043))
    if a["id"] == "glove_cocina":  # cuadros: franjas verticales
        for k in range(-3, 4):
            ang = k * math.radians(28)
            p = (math.sin(ang) * (WRIST_RX + 0.0042), -math.cos(ang) * (WRIST_RY + 0.0042), 0.0)
            parts.append(paint(lib.box(a["id"] + "_chk%d" % k, (0.0045, 0.0012, 0.038), loc=p), trim))
    if a["id"] == "glove_lana":  # puño de punto: costillas
        for k in range(-8, 9):
            ang = k * math.radians(18)
            p = (math.sin(ang) * (WRIST_RX + 0.0042), -math.cos(ang) * (WRIST_RY + 0.0042), 0.0)
            parts.append(paint(lib.box(a["id"] + "_rib%d" % k, (0.003, 0.0012, 0.034), loc=p), trim))


BUILDERS = {"ring": ring, "bracelet": bracelet, "watch": watch, "glove": glove}
objs = []
for a in DATA:
    parts = []
    BUILDERS[a["slot"]](a, parts)
    for p in parts:
        lib.apply_modifiers(p)
    o = lib.join(parts, a["id"])
    lib.triangulate(o)
    lib.smooth(o, 50.0)
    lib.unwrap(o)
    o.location = (0, 0, 0)
    objs.append(o)
    print("TRIS", a["id"], lib.triangles(o))

if A["out"]:
    lib.export_glb(A["out"], objs)
