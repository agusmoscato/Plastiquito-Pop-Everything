"""Mano derecha con guante de nitrilo, puño enrollado y un tramo corto de antebrazo. 1 unidad = 1 m.
Dedos hacia +Y, palma hacia -Z, pulgar del lado -X. El origen queda en la yema del índice.

Proporciones (ronda 3, jornada 2026-11-17):
- Palma de 8,5 cm de ancho y ~3 cm de espesor (placa acolchada); muñeca = 80 % de la palma.
- Antebrazo: solo 9 cm visibles después del puño del guante.
- Dedos de 2,1 cm de diámetro (1/4 de la palma), nudillos y yemas abultadas, punta redonda,
  abanico leve y curva natural hacia la palma. Largos: medio 9,0 cm, índice y anular 8,4 (93 %),
  meñique 6,75 (75 %).
- Pulgar que sale del costado a ~45° con eminencia tenar, metacarpo y 2 falanges.
Construcción: cada dedo es un tubo propio (anillos con radio variable) y los pesos se asignan por
anillo, con mezcla corta en cada articulación. (El modificador Skin unía los dedos en un casco común
y los pesos automáticos dejaban membranas y dedos estirados al cerrar la mano.)
Empties "contact_point" (yema del índice) y "contact_palm" (centro de la palma, abajo): HandRig los
usa para apoyar la mano en la lámina sin coordenadas fijas en el código.
Uso: blender -b --factory-startup -P art/models/hand.py -- --out assets/models/hand.glb --render art/renders [--no-arm]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
import bpy
import bmesh
from mathutils import Vector
from art import lib

A = lib.args()
NO_ARM = "--no-arm" in sys.argv  # manitos fantasma: sin antebrazo, puño mínimo
lib.reset()

PALM_W = 0.085
FINGER_R = PALM_W / 8.0  # radio: diámetro = 1/4 del ancho de la palma
MIDDLE_LEN = 0.090
SIDES = 14
# x e y de la base (MCP), largo relativo, abanico (grados, + hacia +X), fracción de cada falange, grosor.
FINGERS = {
    "index":  {"x": -0.0295, "y0": 0.078, "rel": 0.93, "fan": -5.0, "split": (0.46, 0.30, 0.24), "thick": 1.00},
    "middle": {"x": -0.0098, "y0": 0.083, "rel": 1.00, "fan": -1.0, "split": (0.47, 0.29, 0.24), "thick": 1.03},
    "ring":   {"x": 0.0098,  "y0": 0.080, "rel": 0.93, "fan": 3.0,  "split": (0.46, 0.30, 0.24), "thick": 0.97},
    "pinky":  {"x": 0.0285,  "y0": 0.071, "rel": 0.75, "fan": 8.0,  "split": (0.44, 0.31, 0.25), "thick": 0.84},
}
CURL = (4.0, 7.0, 6.0)  # flexión de reposo por articulación (grados, hacia la palma)

glove = lib.material("glove_nitrile", lib.hex_color("#3D6FD6"), rough=0.45, clearcoat=0.25)


def finger_tube(name, joints, radius, base_back=0.012):
    """Tubo por los puntos `joints` (MCP, j1, j2, punta). Devuelve (objeto, [(s, fila)], largos)."""
    j = [Vector(p) for p in joints]
    d0 = (j[1] - j[0]).normalized()
    start = j[0] - d0 * base_back
    seg_len = [(j[k + 1] - j[k]).length for k in range(3)]
    # Muestras (punto, radio, s): s = distancia desde el MCP (negativa dentro de la palma).
    samples = [(start, radius * 1.02, -base_back)]
    s_acc = 0.0
    prof = [(0.0, 1.10), (0.5, 0.90), (1.0, 1.00)]  # nudillo, centro fino, articulación
    for k in range(3):
        a, b = j[k], j[k + 1]
        taper = (1.0, 0.94, 0.88)[k]
        last = k == 2
        steps = (0.0, 0.25, 0.5, 0.75) if not last else (0.0, 0.3, 0.55, 0.72)
        for t in steps:
            if k > 0 and t == 0.0:
                f = 1.06  # articulación abultada
            elif t == 0.0:
                f = 1.10
            elif last:
                f = 0.90 + 0.10 * math.sin(t * math.pi)  # la yema se ensancha antes de la punta
            else:
                f = 0.88 + 0.06 * abs(t - 0.5) * 2.0
            samples.append((a.lerp(b, t), radius * taper * f, s_acc + seg_len[k] * t))
        s_acc += seg_len[k]
    # Punta redonda: casquete de 4 anillos más el vértice final.
    tip_dir = (j[3] - j[2]).normalized()
    r_tip = radius * 0.88 * 0.97
    base_tip = j[2].lerp(j[3], 0.80)
    for i in range(1, 5):
        a = (math.pi * 0.5) * i / 5.0
        samples.append((base_tip + tip_dir * (r_tip * math.sin(a)), r_tip * math.cos(a), s_acc - 0.002))
    end = base_tip + tip_dir * r_tip
    bm = bmesh.new()
    rows = []
    prev_n = None
    for idx, (p, r, s) in enumerate(samples):
        if idx < len(samples) - 1:
            t = (samples[idx + 1][0] - p).normalized()
        else:
            t = (end - p).normalized()
        up = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
        n = t.cross(up).normalized() if prev_n is None else (prev_n - t * prev_n.dot(t)).normalized()
        prev_n = n
        b = t.cross(n).normalized()
        ring = []
        for i in range(SIDES):
            ang = 2 * math.pi * i / SIDES
            # Sección un poco achatada (dorso más plano que la yema).
            off = n * math.cos(ang) * r + b * math.sin(ang) * r * 0.90
            ring.append(bm.verts.new(p + off))
        rows.append((s, ring))
    tip_v = bm.verts.new(end)
    for k in range(len(rows) - 1):
        ra, rb = rows[k][1], rows[k + 1][1]
        for i in range(SIDES):
            i2 = (i + 1) % SIDES
            bm.faces.new((ra[i], ra[i2], rb[i2], rb[i]))
    last_ring = rows[-1][1]
    for i in range(SIDES):
        bm.faces.new((last_ring[i], last_ring[(i + 1) % SIDES], tip_v))
    bm.faces.new(list(reversed(rows[0][1])))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    ring_s = [s for (s, _) in rows] + [s_acc + 0.01]
    return o, ring_s, seg_len


# --- Dedos ----------------------------------------------------------------------------------------
pieces = []  # (objeto, función índice_de_vértice -> {hueso: peso})
bone_joints = {}


def chain_weights(prefix, ring_s, seg_len, sides, base_bone):
    """Pesos por anillo: antes del MCP, el hueso de la base; después, la falange que corresponde,
    con una mezcla de ±4 mm alrededor de cada articulación."""
    j1 = seg_len[0]
    j2 = j1 + seg_len[1]
    blend = 0.004

    def mix(s, edge, lo_bone, hi_bone):
        t = max(0.0, min(1.0, (s - (edge - blend)) / (2 * blend)))
        return {lo_bone: 1.0 - t, hi_bone: t}

    def weights(vi):
        row = min(vi // sides, len(ring_s) - 1)
        s = ring_s[row]
        if s < j1 * 0.5:
            return mix(s, 0.0, base_bone, prefix + "_1")
        if s < (j1 + j2) * 0.5:
            return mix(s, j1, prefix + "_1", prefix + "_2")
        return mix(s, j2, prefix + "_2", prefix + "_3")
    return weights


for name, f in FINGERS.items():
    r0 = FINGER_R * f["thick"]
    base = Vector((f["x"], f["y0"], 0.0))
    a = math.radians(f["fan"])
    total = MIDDLE_LEN * f["rel"]
    pts = [base]
    pitch = 0.0
    p = base.copy()
    for k, frac in enumerate(f["split"]):
        pitch += math.radians(CURL[k])
        d = Vector((math.sin(a) * math.cos(pitch), math.cos(a) * math.cos(pitch), -math.sin(pitch)))
        p = p + d * (total * frac)
        pts.append(p.copy())
    obj, ring_s, seg_len = finger_tube(name, pts, r0)
    pieces.append((obj, chain_weights(name, ring_s, seg_len, SIDES, name + "_meta")))
    bone_joints[name] = pts

# --- Pulgar: metacarpo y 2 falanges, a ~45° del costado -------------------------------------------
t_dir = Vector((-math.sin(math.radians(45.0)), math.cos(math.radians(45.0)), -0.20)).normalized()
th_pts = [Vector((-0.028, 0.012, -0.006))]
for k, L in enumerate((0.028, 0.024, 0.021)):
    # Cada falange gira ~24° hacia adentro (hacia la base del índice) y baja un poco.
    ang = math.radians(-24.0 * k)
    d = Vector((t_dir.x * math.cos(ang) - t_dir.y * math.sin(ang),
                t_dir.x * math.sin(ang) + t_dir.y * math.cos(ang), t_dir.z - 0.10 * k)).normalized()
    th_pts.append(th_pts[-1] + d * L)
th_obj, th_s, th_len = finger_tube("thumb", th_pts, FINGER_R * 1.12, base_back=0.006)
pieces.append((th_obj, chain_weights("thumb", th_s, th_len, SIDES, "wrist")))
bone_joints["thumb"] = th_pts


def const(bone_name):
    return lambda vi: {bone_name: 1.0}


# --- Palma: placa acolchada con espesor; eminencia tenar del lado del pulgar --------------------
cage_v = []
rows = ((-0.020, 0.0340, 0.0150, -0.0125), (0.030, 0.0425, 0.0170, -0.0140), (0.080, 0.0420, 0.0135, -0.0110))
for (y, hw, zt, zb) in rows:
    cage_v += [(-hw, y, zb), (hw, y, zb), (hw, y, zt), (-hw, y, zt)]
cage_f = [(0, 1, 2, 3), (11, 10, 9, 8), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0),
          (4, 8, 9, 5), (5, 9, 10, 6), (6, 10, 11, 7), (7, 11, 8, 4)]
palm_obj = lib.new_object("palm", cage_v, cage_f)
lib.subsurf(palm_obj, 2)
lib.apply_modifiers(palm_obj)
pieces.append((palm_obj, const("wrist")))
thenar = lib.sphere("thenar", 0.020, (-0.024, 0.016, -0.008), 14, 8, (0.95, 1.35, 0.72))
thenar.rotation_euler = (0.0, 0.0, math.radians(-28.0))
pieces.append((thenar, const("wrist")))

# --- Puño del guante (reborde enrollado) y antebrazo corto ----------------------------------------
if NO_ARM:
    cuff_pts = [(0.0, -0.036, 0.0), (0.0, -0.030, 0.0), (0.0, -0.022, 0.0), (0.0, -0.010, 0.0)]
    cuff_r = [0.0290, 0.0335, 0.0325, 0.0305]
else:
    cuff_pts = [(0.0, -0.062, 0.0), (0.0, -0.054, 0.0), (0.0, -0.046, 0.0), (0.0, -0.040, 0.0),
                (0.0, -0.030, 0.0), (0.0, -0.018, 0.0), (0.0, -0.008, 0.0)]
    cuff_r = [0.0300, 0.0340, 0.0345, 0.0330, 0.0318, 0.0310, 0.0300]  # puño ~6,9 cm: apenas más que la muñeca
    arm_pts = [(0.0, -0.148, -0.002), (0.0, -0.120, -0.001), (0.0, -0.090, 0.0), (0.0, -0.060, 0.0)]
    arm = lib.tube_along("forearm", arm_pts, [0.0275, 0.0275, 0.0278, 0.0282], sides=20, squash=0.72)
    lib.subsurf(arm, 1)
    lib.apply_modifiers(arm)
    pieces.append((arm, const("forearm")))
cuff = lib.tube_along("cuff", cuff_pts, cuff_r, sides=24, squash=0.64)
lib.subsurf(cuff, 1)
lib.apply_modifiers(cuff)
pieces.append((cuff, const("forearm")))

# --- Armature: un hueso por falange, más palma (metacarpos), muñeca y antebrazo ------------------
bpy.ops.object.armature_add(enter_editmode=True)
arm_obj = bpy.context.object
arm_obj.name = "HandRig"
ab = arm_obj.data
ab.name = "HandRig"
for b in list(ab.edit_bones):
    ab.edit_bones.remove(b)


def bone(name, head, tail, parent=None):
    eb = ab.edit_bones.new(name)
    eb.head = Vector(head)
    eb.tail = Vector(tail)
    eb.roll = 0.0
    if parent:
        eb.parent = ab.edit_bones[parent]
        eb.use_connect = False
    return eb


bone("forearm", (0, -0.148, 0), (0, -0.030, 0))
bone("wrist", (0, -0.030, 0), (0, 0.040, 0), "forearm")
for name, pts in bone_joints.items():
    if name != "thumb":
        bone(name + "_meta", (pts[0].x * 0.6, 0.040, 0.0), tuple(pts[0]), "wrist")
        parent = name + "_meta"
    else:
        parent = "wrist"
    for k in range(3):
        nm = "%s_%d" % (name, k + 1)
        bone(nm, tuple(pts[k]), tuple(pts[k + 1]), parent)
        parent = nm
bpy.ops.object.mode_set(mode="OBJECT")

# --- Unir las piezas con sus pesos ----------------------------------------------------------------
all_bones = [b.name for b in ab.bones]
for obj, wfun in pieces:
    obj.data.materials.append(glove)
    for bn in all_bones:
        obj.vertex_groups.new(name=bn)
    for v in obj.data.vertices:
        for bn, w in wfun(v.index).items():
            if w > 0.0:
                obj.vertex_groups[bn].add([v.index], w, "REPLACE")
body = lib.join([p[0] for p in pieces], "hand_glove")
lib.triangulate(body)
lib.smooth(body, 60.0)
lib.unwrap(body)
mod = body.modifiers.new("Armature", "ARMATURE")
mod.object = arm_obj
body.parent = arm_obj

# --- Puntos de contacto ---------------------------------------------------------------------------
index_tip = bone_joints["index"][3]
contact_point = index_tip + Vector((0.0, -0.004, -FINGER_R * 0.85))  # la yema, abajo
contact_palm = Vector((-0.002, 0.034, -0.0145))


def empty(name, loc):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.01
    e.location = loc
    bpy.context.scene.collection.objects.link(e)
    return e


e_point = empty("contact_point", contact_point)
e_palm = empty("contact_palm", contact_palm)
offset = -contact_point
for o in (arm_obj, e_point, e_palm):
    o.location = o.location + offset
bpy.context.view_layer.update()
print("TRIS", lib.triangles(body))

if A["out"]:
    lib.export_glb(A["out"])

if A["render"]:
    name = "hand_ghost" if NO_ARM else "hand"
    # Pose "señalar" como en el juego (HandRig.pose_data) para los renders de control.
    lib.select_only(arm_obj)
    bpy.ops.object.mode_set(mode="POSE")
    pose = {"middle": (50, 62, 28), "ring": (52, 64, 28), "pinky": (54, 66, 28), "thumb": (8, 16, 10), "index": (2, 4, 2)}
    for fname, angs in pose.items():
        for k, deg in enumerate(angs):
            pb = arm_obj.pose.bones.get("%s_%d" % (fname, k + 1))
            if pb:
                pb.rotation_mode = "XYZ"
                pb.rotation_euler = (math.radians(-deg), 0.0, 0.0)  # en Blender -X cierra hacia la palma (-Z)
    bpy.ops.object.mode_set(mode="OBJECT")
    lib.render_set(A["render"], name, elev=0.7)
    lib.render_game_view(A["render"], name, yaw_deg=55.0, tilt_deg=-14.0)  # igual que ToolMeshes
