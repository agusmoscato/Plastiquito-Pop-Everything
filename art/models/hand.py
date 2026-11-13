"""Mano derecha con guante de nitrilo, puño enrollado y antebrazo. 1 unidad = 1 m.
Origen en la punta del índice extendido (donde toca la lámina). Dedos hacia +Y, palma hacia -Z.
Medidas de referencia (mano adulta): largo de mano 18,5 cm (muñeca a punta del medio), ancho de palma
8,5 cm, índice 8,3 cm en 3 falanges (4,0 / 2,4 / 1,9 cm), medio 9,1, anular 8,5, meñique 6,7, pulgar 7 cm.
Diámetro de dedo ~1,7 cm en la base y 1,4 cm en la punta (más 1 mm de guante).
Uso: blender -b --factory-startup -P art/models/hand.py -- --out assets/models/hand.glb --render art/renders
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
import bpy
from mathutils import Vector
from art import lib

A = lib.args()
lib.reset()

# --- Esqueleto de piel: (nombre, posición, radio_x, radio_z) -----------------------------------
# Los dedos arrancan en la articulación MCP y se afinan hacia la punta; los nudillos abultan.
FINGERS = {
    "index":  {"x": -0.0265, "y0": 0.082, "len": (0.040, 0.024, 0.019), "r": (0.0088, 0.0080, 0.0073, 0.0064)},
    "middle": {"x": -0.0090, "y0": 0.086, "len": (0.044, 0.027, 0.020), "r": (0.0090, 0.0082, 0.0075, 0.0066)},
    "ring":   {"x": 0.0090,  "y0": 0.082, "len": (0.040, 0.025, 0.019), "r": (0.0086, 0.0078, 0.0071, 0.0062)},
    "pinky":  {"x": 0.0255,  "y0": 0.072, "len": (0.031, 0.019, 0.017), "r": (0.0075, 0.0068, 0.0062, 0.0054)},
}

verts = []      # (x, y, z)
radii = []      # (rx, rz)
edges = []
names = []


def add(name, p, r):
    verts.append(p)
    radii.append(r)
    names.append(name)
    return len(verts) - 1


wrist = add("wrist", (0.0, -0.025, 0.0), (0.033, 0.0215))
palm = add("palm", (0.0, 0.030, 0.0), (0.020, 0.0085))
edges.append((wrist, palm))
# Nudillos: la fila de MCP, unida a la palma.
bone_joints = {}
for name, f in FINGERS.items():
    mcp = add(name + "_mcp", (f["x"], f["y0"], 0.0), (f["r"][0] * 1.08, f["r"][0] * 1.05))
    edges.append((palm, mcp))
    y = f["y0"]
    prev = mcp
    chain = [mcp]
    for k, L in enumerate(f["len"]):
        y += L
        r = f["r"][k + 1]
        # Abultamiento leve en las articulaciones (nudillo) y afinado de la punta.
        joint = add(name + "_j%d" % (k + 1), (f["x"], y, 0.0), (r * 1.06, r * 1.02))
        edges.append((prev, joint))
        prev = joint
        chain.append(joint)
    bone_joints[name] = chain
# Pulgar: sale de la base de la palma hacia afuera y adelante (para una mano derecha, -X).
th0 = add("thumb_cmc", (-0.028, 0.008, -0.003), (0.0175, 0.0140))
th1 = add("thumb_mcp", (-0.047, 0.030, 0.003), (0.0140, 0.0120))
th2 = add("thumb_ip", (-0.058, 0.048, 0.007), (0.0120, 0.0105))
th3 = add("thumb_tip", (-0.063, 0.063, 0.010), (0.0100, 0.0090))
edges += [(palm, th0), (th0, th1), (th1, th2), (th2, th3)]
bone_joints["thumb"] = [th0, th1, th2, th3]

mesh = bpy.data.meshes.new("hand_skel")
mesh.from_pydata(verts, edges, [])
hand = bpy.data.objects.new("hand_glove", mesh)
bpy.context.scene.collection.objects.link(hand)
lib.select_only(hand)
skin = hand.modifiers.new("Skin", "SKIN")
skin.branch_smoothing = 0.8
skin.use_smooth_shade = True
bpy.ops.object.mode_set(mode="OBJECT")
for i, v in enumerate(mesh.skin_vertices[0].data):
    v.radius = radii[i]
    v.use_root = (i == wrist)
sub = lib.subsurf(hand, 2)

# Cuff enrollado y antebrazo (tubos con perfil: el borde del puño es un reborde grueso).
cuff_pts = [(0.0, -0.100, 0.0), (0.0, -0.080, 0.0), (0.0, -0.062, 0.0), (0.0, -0.050, 0.0), (0.0, -0.042, 0.0), (0.0, -0.036, 0.0), (0.0, -0.026, 0.0), (0.0, -0.016, 0.0)]
cuff_r = [0.0330, 0.0338, 0.0372, 0.0420, 0.0395, 0.0320, 0.0300, 0.0290]
cuff = lib.tube_along("cuff", cuff_pts, cuff_r, sides=24, squash=0.62)
lib.subsurf(cuff, 1)
arm_pts = [(0.0, -0.26, -0.003), (0.0, -0.20, -0.002), (0.0, -0.14, -0.001), (0.0, -0.10, 0.0), (0.0, -0.075, 0.0)]
arm_r = [0.036, 0.0335, 0.031, 0.0295, 0.0285]
arm = lib.tube_along("forearm", arm_pts, arm_r, sides=20, squash=0.7)
lib.subsurf(arm, 1)

# Palma: una caja con cantos redondeados (subsurf) que da la placa de la mano; el dorso es más alto.
cage_v = []
for (y, hw, zt, zb) in ((-0.022, 0.0345, 0.0140, -0.0120), (0.030, 0.0420, 0.0150, -0.0105), (0.084, 0.0415, 0.0125, -0.0085)):
    cage_v += [(-hw, y, zb), (hw, y, zb), (hw, y, zt), (-hw, y, zt)]
cage_f = [(0, 1, 2, 3), (11, 10, 9, 8), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0), (4, 8, 9, 5), (5, 9, 10, 6), (6, 10, 11, 7), (7, 11, 8, 4)]
palm_obj = lib.new_object("palm_plate", cage_v, cage_f)
lib.subsurf(palm_obj, 2)
mat_glove = lib.material("glove_nitrile", lib.hex_color("#3D6FD6"), rough=0.45, clearcoat=0.25)
for o in (hand, cuff, arm, palm_obj):
    o.data.materials.append(mat_glove)

# Aplicar modificadores y unir.
lib.apply_modifiers(hand)
lib.apply_modifiers(cuff)
lib.apply_modifiers(arm)
lib.apply_modifiers(palm_obj)
NO_ARM = "--no-arm" in sys.argv  # variante para las manitos fantasma: sin antebrazo
body = lib.join([hand, cuff, palm_obj] if NO_ARM else [hand, cuff, arm, palm_obj], "hand_glove")
lib.smooth(body, 50.0)
lib.unwrap(body)

# --- Armature: un hueso por falange, más palma, muñeca y antebrazo -----------------------------
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
    if parent:
        eb.parent = ab.edit_bones[parent]
        eb.use_connect = False
    return eb


bone("forearm", (0, -0.26, 0), (0, -0.045, 0))
bone("wrist", (0, -0.045, 0), (0, 0.030, 0), "forearm")
for name, chain in bone_joints.items():
    pts = [Vector(verts[i]) for i in chain]
    if name != "thumb":
        base = Vector((verts[chain[0]][0], 0.030, 0.0))
        bone(name + "_meta", (base.x * 0.7, 0.030, 0.0), tuple(pts[0]), "wrist")
        parent = name + "_meta"
    else:
        parent = "wrist"
    for k in range(len(pts) - 1):
        nm = "%s_%d" % (name, k + 1)
        bone(nm, tuple(pts[k]), tuple(pts[k + 1]), parent)
        parent = nm
bpy.ops.object.mode_set(mode="OBJECT")
lib.select_only(body)
body.select_set(True)
arm_obj.select_set(True)
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.parent_set(type="ARMATURE_AUTO")

# Origen: la punta del índice extendido (donde toca la lámina).
tip = Vector(verts[bone_joints["index"][-1]])
offset = -tip
for o in (body, arm_obj):
    o.location = offset
lib.select_only(body)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
print("TRIS", lib.triangles(body))

if A["out"]:
    lib.export_glb(A["out"])
if A["render"] and not NO_ARM:
    lib.render_set(A["render"], "hand", target=(0.0, -0.06, 0.0), dist=0.5, elev=0.7)
