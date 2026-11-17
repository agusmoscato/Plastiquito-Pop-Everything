"""Mano derecha con guante a partir de MakeHuman/MPFB (assets CC0, ver assets/models/LICENSES.md).
1 unidad = 1 m. Dedos hacia +Y, palma hacia -Z, pulgar del lado -X; origen en la yema del índice.

Pasos: humano adulto promedio de MPFB con el esqueleto "default" -> se aíslan la mano derecha y
10 cm de antebrazo con los pesos reales -> se orienta a la convención del juego -> esqueleto propio
con los nombres que usa HandRig (forearm, wrist, <dedo>_meta, <dedo>_1..3, thumb_1..3) conservando
los pesos de MakeHuman -> guante: subdivisión, engrosamiento de 1,5 mm, arrugas en las articulaciones
y puño enrollado en la muñeca. Empties contact_point (yema del índice) y contact_palm.
Uso: blender -b --factory-startup -P art/models/hand_mpfb.py -- --out assets/models/hand.glb --render art/renders [--no-arm]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
import bpy
import bmesh
from mathutils import Matrix, Vector
from art import lib, mpfb_load

A = lib.args()
NO_ARM = "--no-arm" in sys.argv  # manitos: sin antebrazo ni puño
ARM_LEN = 0.058  # antebrazo corto (revisión: pesaba tanto como la mano en la vista de juego)
CUFF_AT = 0.018  # el puño enrollado, pegado a la muñeca
FINGER_STRETCH = 1.10

mpfb_load.load()
from mpfb.services.humanservice import HumanService  # noqa: E402

bpy.ops.wm.read_factory_settings(use_empty=True)
body = HumanService.create_human(scale=0.1)  # con ayudantes: el esqueleto se ajusta con los JointCubes
rig = HumanService.add_builtin_rig(body, "default")
bpy.context.view_layer.update()

# --- Huesos de MPFB (mundo) -> nombres del juego -------------------------------------------------
MAP = {"wrist.R": "wrist", "lowerarm01.R": "forearm", "lowerarm02.R": "forearm",
       "finger1-1.R": "thumb_1", "finger1-2.R": "thumb_2", "finger1-3.R": "thumb_3"}
for i, name in enumerate(["index", "middle", "ring", "pinky"]):
    MAP["metacarpal%d.R" % (i + 1)] = name + "_meta"
    for k in range(1, 4):
        MAP["finger%d-%d.R" % (i + 2, k)] = "%s_%d" % (name, k)
mw = rig.matrix_world
B = {b.name: (mw @ b.head_local, mw @ b.tail_local) for b in rig.data.bones}

wrist_h = B["wrist.R"][0]
elbow = B["lowerarm01.R"][0]
forward = (B["finger3-1.R"][0] - wrist_h).normalized()            # hacia los dedos
across = B["finger5-1.R"][0] - B["finger2-1.R"][0]                 # del índice al meñique
across = (across - forward * across.dot(forward)).normalized()
up = across.cross(forward).normalized()                            # dorso (+Z)
R = Matrix((across, forward, up))                                  # mundo -> local de la mano
arm_axis = (elbow - wrist_h).normalized()


def closed_ring(name, loop, axis, r, sides):
    """Toro cerrado (sin tapas ni costura) que sigue el lazo `loop` alrededor de `axis`: el puño enrollado."""
    bm2 = bmesh.new()
    n = len(loop)
    c = sum(loop, Vector()) / n
    rings = []
    for i in range(n):
        p = loop[i]
        tdir = (loop[(i + 1) % n] - loop[i - 1]).normalized()
        out = (p - c)
        out = (out - axis * out.dot(axis)).normalized()
        ring = []
        for k in range(sides):
            a = 2.0 * math.pi * k / sides
            ring.append(bm2.verts.new(p + out * (math.cos(a) * r) + axis * (math.sin(a) * r * 1.15)))
        rings.append(ring)
    for i in range(n):
        ra, rb = rings[i], rings[(i + 1) % n]
        for k in range(sides):
            k2 = (k + 1) % sides
            bm2.faces.new((ra[k], ra[k2], rb[k2], rb[k]))
    me = bpy.data.meshes.new(name)
    bm2.to_mesh(me)
    bm2.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def bake_glove_tint(o):
    """Color de vértice del guante (COLOR_0): oclusión en los pliegues (concavidad contra los vecinos)
    y la palma algo más oscura. En Godot se multiplica por el color del guante."""
    bm4 = bmesh.new()
    bm4.from_mesh(o.data)
    bm4.normal_update()
    shade = {}
    for v in bm4.verts:
        nb = [e.other_vert(v).co for e in v.link_edges]
        if not nb:
            shade[v.index] = 1.0
            continue
        mean = sum(nb, Vector()) / len(nb)
        edge = sum((q - v.co).length for q in nb) / len(nb)
        concave = (mean - v.co).dot(v.normal) / max(edge, 1e-6)
        ao = max(0.55, 1.0 - 1.6 * max(concave, 0.0))
        palm = 0.86 if (v.normal.z < -0.45 and v.co.y > 0.0) else 1.0
        shade[v.index] = ao * palm
    bm4.free()
    me = o.data
    attr = me.color_attributes.get("tint") or me.color_attributes.new("tint", "BYTE_COLOR", "CORNER")
    for loop in me.loops:
        k = shade.get(loop.vertex_index, 1.0)
        attr.data[loop.index].color = (k, k, k, 1.0)


def to_local(p):
    return R @ (p - wrist_h)


# --- Malla: formas aplicadas, sin modificadores; quedan solo la mano y el antebrazo -------------
lib.select_only(body)
for m in list(body.modifiers):
    body.modifiers.remove(m)
if body.data.shape_keys:
    bpy.ops.object.shape_key_remove(all=True, apply_mix=True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
groups = {g.index: g.name for g in body.vertex_groups}
keep_len = -0.008 if NO_ARM else ARM_LEN  # manitos: corte en el pliegue de la muñeca
bm = bmesh.new()
bm.from_mesh(body.data)
deform = bm.verts.layers.deform.active
dead = []
for v in bm.verts:
    w_hand = 0.0
    w_body = 0.0
    in_body = False
    for gi, w in v[deform].items():
        name = groups.get(gi, "")
        if name == "body":
            in_body = True
        if name in MAP:
            w_hand += w
        elif name.endswith(".R") or name.endswith(".L") or name in ("spine01", "spine02", "spine03", "neck01", "head", "pelvis.L"):
            w_body += w
    t = -(R @ (v.co - wrist_h)).y  # distancia hacia el codo, sobre el eje de la mano
    if (not in_body and "body" in groups.values()) or w_hand < 0.5 or t > keep_len:
        dead.append(v)
bmesh.ops.delete(bm, geom=dead, context="VERTS")
bmesh.ops.holes_fill(bm, edges=bm.edges[:], sides=0)  # tapa el corte del antebrazo (o de la muñeca)
# La tapa plana dejaba una estrella con picos: se redondea en domo (cara interior más chica y adelantada).
for cap in [f for f in bm.faces if len(f.verts) > 8]:
    res = bmesh.ops.inset_region(bm, faces=[cap], thickness=0.007, depth=0.0)
    inner_c = cap.calc_center_median()
    for v in cap.verts:
        v.co = inner_c + (v.co - inner_c) * 0.55 + arm_axis * 0.004
    bmesh.ops.poke(bm, faces=[cap])
for v in bm.verts:
    v.co = to_local(v.co)
bm.to_mesh(body.data)
bm.free()
body.data.update()

# Grupos de vértices: los de MPFB pasan a los nombres del juego (se suman los de forearm).
for vg in list(body.vertex_groups):
    if vg.name not in MAP:
        body.vertex_groups.remove(vg)
new_groups = {}
for name in sorted(set(MAP.values())):
    new_groups[name] = body.vertex_groups.new(name=name)
old = {vg.index: vg.name for vg in body.vertex_groups if vg.name in MAP}
for v in body.data.vertices:
    acc = {}
    for g in v.groups:
        if g.group in old:
            acc[MAP[old[g.group]]] = acc.get(MAP[old[g.group]], 0.0) + g.weight
    for name, w in acc.items():
        new_groups[name].add([v.index], min(w, 1.0), "REPLACE")
for vg in list(body.vertex_groups):
    if vg.name in MAP:
        body.vertex_groups.remove(vg)
body.name = "hand_glove"
body.data.name = "hand_glove"

# --- Esqueleto propio con los nombres de HandRig -------------------------------------------------
bpy.ops.object.armature_add(enter_editmode=True)
arm_obj = bpy.context.object
arm_obj.name = "HandRig"
arm_obj.data.name = "HandRig"
eb_all = arm_obj.data.edit_bones
for b in list(eb_all):
    eb_all.remove(b)


def bone(name, head, tail, parent=None):
    eb = eb_all.new(name)
    eb.head = head
    eb.tail = tail
    eb.align_roll(Vector((0.0, 0.0, 1.0)))  # Z hacia el dorso: X local = eje de flexión (como el modelo anterior)
    if parent:
        eb.parent = eb_all[parent]
        eb.use_connect = False
    return eb


bone("forearm", to_local(wrist_h + arm_axis * ARM_LEN), Vector((0.0, 0.0, 0.0)))
bone("wrist", Vector((0.0, 0.0, 0.0)), to_local(B["wrist.R"][1]) if (to_local(B["wrist.R"][1]).length > 0.01) else Vector((0.0, 0.04, 0.0)), "forearm")
for mp, gm in MAP.items():
    if gm.endswith("_meta"):
        h, t = B[mp]
        bone(gm, to_local(h), to_local(t), "wrist")
for prefix, src in (("index", 2), ("middle", 3), ("ring", 4), ("pinky", 5), ("thumb", 1)):
    parent = "wrist" if prefix == "thumb" else prefix + "_meta"
    for k in range(1, 4):
        h, t = B["finger%d-%d.R" % (src, k)]
        nm = "%s_%d" % (prefix, k)
        bone(nm, to_local(h), to_local(t), parent)
        parent = nm
bpy.ops.object.mode_set(mode="OBJECT")
bpy.data.objects.remove(rig, do_unlink=True)


# --- Reposo = mano plana y abierta -------------------------------------------------------------------
# MakeHuman deja los dedos relajados (curvados hacia la palma). La pose "palma" del juego es la de
# reposo (todos los ángulos en 0), así que se enderezan muñeca y dedos y esa pose pasa a ser el reposo,
# con la malla deformada por los pesos reales.
def flatten_rest():
    tmp = body.modifiers.new("Flatten", "ARMATURE")
    tmp.object = arm_obj
    body.parent = None
    lib.select_only(arm_obj)
    bpy.ops.object.mode_set(mode="POSE")
    FAN = {"index": -5.0, "middle": -1.0, "ring": 3.0, "pinky": 8.0, "thumb": -44.0}
    order = ["thumb_1"] + ["%s_%d" % (f, k) for f in ("index", "middle", "ring", "pinky") for k in (1, 2, 3)] + ["thumb_2", "thumb_3"]
    for name in order:
        pb = arm_obj.pose.bones[name]
        bpy.context.view_layer.update()
        head, tail = pb.head.copy(), pb.tail.copy()
        cur = tail - head
        finger = name.split("_")[0]
        a = math.radians(FAN[finger])
        dip = -0.06 if finger == "thumb" else -0.03
        # Mano plana relajada estándar: cada dedo recto, con su abanico, apenas por debajo de la palma.
        want = Vector((math.sin(a), math.cos(a), dip)).normalized() * cur.length
        q = cur.rotation_difference(want)
        pb.matrix = Matrix.Translation(head) @ q.to_matrix().to_4x4() @ Matrix.Translation(-head) @ pb.matrix
    # Dedos un 10 % más largos (la primera falange escala y las otras lo heredan): en MakeHuman la palma
    # es algo larga y los dedos algo cortos contra los promedios antropométricos del plano.
    bpy.context.view_layer.update()
    for f in ("index", "middle", "ring", "pinky"):
        # El dedo del guante es un poco más ancho que el dedo desnudo (+8 %); las falanges lo heredan.
        arm_obj.pose.bones[f + "_1"].scale = (1.08, FINGER_STRETCH, 1.08)
    arm_obj.pose.bones["thumb_2"].scale = (1.08, 1.08, 1.08)
    bpy.context.view_layer.update()
    bpy.ops.object.mode_set(mode="OBJECT")
    lib.select_only(body)
    bpy.ops.object.modifier_apply(modifier=tmp.name)  # primero la malla toma la pose...
    lib.select_only(arm_obj)
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.armature_apply(selected=False)  # ...y después esa pose pasa a ser el reposo
    bpy.ops.object.mode_set(mode="OBJECT")


flatten_rest()

# Escala real: largo de mano (muñeca a punta del medio) de 18,7 cm, el promedio de adultos que usa el
# plano de referencia (art/blueprints/blueprint.py). MPFB da ~17,9 cm para su adulto promedio de 1,66 m.
HAND_LEN = 0.187 + 0.010  # el hueso wrist de MakeHuman arranca ~1 cm antes del pliegue de la muñeca
mid_g = body.vertex_groups["middle_3"].index
tip_y = max(v.co.y for v in body.data.vertices if any(g.group == mid_g and g.weight > 0.5 for g in v.groups))
cur_len = tip_y - arm_obj.data.bones["wrist"].head_local.y  # hasta la punta REAL de la malla del medio
k_scale = HAND_LEN / cur_len
print("HAND_LEN", round(cur_len, 4), "x%.3f" % k_scale)
for o in (body, arm_obj):
    o.scale = (k_scale, k_scale, k_scale)
    lib.select_only(o)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

# --- Caña del guante: el nitrilo queda flojo sobre el antebrazo (hasta +28 % hacia el puño) ---------
wrist_y = arm_obj.data.bones["wrist"].head_local.y
fore = [v for v in body.data.vertices if v.co.y < wrist_y - 0.005]
if fore:
    cx = sum(v.co.x for v in fore) / len(fore)
    cz = sum(v.co.z for v in fore) / len(fore)
    for v in fore:
        f = min(max((wrist_y - v.co.y - 0.005) / 0.035, 0.0), 1.0)
        v.co.x = cx + (v.co.x - cx) * (1.0 + 0.18 * f)  # se afina hacia la muñeca
        v.co.z = cz + (v.co.z - cz) * (1.0 + 0.08 * f)

# --- Guante: subdivisión, engrosamiento, arrugas en las articulaciones --------------------------
lib.subsurf(body, 1)  # también las manitos (Godot les genera LOD al importar)
lib.apply_modifiers(body)
joints = bpy.data.objects["HandRig"].data.bones
joint_pts = [b.head_local.copy() for b in joints if b.name.endswith(("_1", "_2", "_3"))]
wr = body.vertex_groups.new(name="glove_wrinkles")
for v in body.data.vertices:
    d = min((v.co - p).length for p in joint_pts)
    w = math.exp(-(d / 0.008) ** 2)
    if w > 0.02:
        wr.add([v.index], w, "REPLACE")
thick = body.modifiers.new("Glove", "DISPLACE")
thick.strength = 0.0015
thick.mid_level = 0.0
noise = bpy.data.textures.new("glove_noise", "STUCCI")
noise.noise_scale = 0.004
wrinkle = body.modifiers.new("Wrinkles", "DISPLACE")
wrinkle.texture = noise
wrinkle.strength = 0.0012
wrinkle.vertex_group = "glove_wrinkles"
lib.apply_modifiers(body)
body.vertex_groups.remove(body.vertex_groups["glove_wrinkles"])

parts = [body]
if not NO_ARM:
    # Puño enrollado: aro de tubo que sigue la sección del antebrazo a 3,5 cm de la muñeca.
    axis_l = (R @ arm_axis).normalized()
    pts_sec = [v.co.copy() for v in body.data.vertices if abs(v.co.dot(axis_l) - CUFF_AT) < 0.005]
    c = sum(pts_sec, Vector()) / max(len(pts_sec), 1)
    ref = Vector((1.0, 0.0, 0.0))
    ref = (ref - axis_l * ref.dot(axis_l)).normalized()
    ref2 = axis_l.cross(ref).normalized()
    loop = []
    for i in range(28):
        a = 2.0 * math.pi * i / 28
        d = ref * math.cos(a) + ref2 * math.sin(a)
        best = max((((p - c) - axis_l * (p - c).dot(axis_l)).length for p in pts_sec
                    if ((p - c) - axis_l * (p - c).dot(axis_l)).normalized().dot(d) > 0.93), default=0.03)
        loop.append(tuple(c + d * (best + 0.0006)))  # borde enrollado fino, pegado a la muñeca
    cuff = closed_ring("cuff", [Vector(p) for p in loop], axis_l, 0.0034, 10)
    lib.subsurf(cuff, 1)
    lib.apply_modifiers(cuff)
    fg = cuff.vertex_groups.new(name="forearm")
    fg.add([v.index for v in cuff.data.vertices], 1.0, "REPLACE")
    parts.append(cuff)

mat = lib.vertex_tint_material("glove_nitrile", lib.hex_color("#3D6FD6"), rough=0.64, clearcoat=0.15)
for p in parts:
    p.data.materials.clear()
    p.data.materials.append(mat)
body = lib.join(parts, "hand_glove") if len(parts) > 1 else body
bake_glove_tint(body)
lib.triangulate(body)
lib.smooth(body, 70.0)
lib.unwrap(body)
mod = body.modifiers.new("Armature", "ARMATURE")
mod.object = arm_obj
body.parent = arm_obj

# --- Contactos: yema del índice y centro de la palma (abajo) ------------------------------------
for vg in body.vertex_groups:
    n = sum(1 for v in body.data.vertices for g in v.groups if g.group == vg.index and g.weight > 0.5)
    print("GROUP", vg.name, n)
print("VERTS", len(body.data.vertices), "BONE index_3", tuple(arm_obj.data.bones["index_3"].head_local), tuple(arm_obj.data.bones["index_3"].tail_local))
idx_g = body.vertex_groups["index_3"].index
tip_bone = arm_obj.data.bones["index_3"]
tip_dir = (tip_bone.tail_local - tip_bone.head_local).normalized()
cands = [v.co for v in body.data.vertices if any(g.group == idx_g and g.weight > 0.5 for g in v.groups)
         and (v.co - tip_bone.head_local).dot(tip_dir) > 0.6 * tip_bone.length]
pad = min(cands, key=lambda p: p.z)
meta_ids = {body.vertex_groups[n].index for n in ("index_meta", "middle_meta", "ring_meta", "pinky_meta")}
palm_pts = [v.co for v in body.data.vertices if any(g.group in meta_ids and g.weight > 0.6 for g in v.groups)]
palm_pts.sort(key=lambda p: p.z)
low = palm_pts[: max(1, len(palm_pts) // 5)]
palm = sum(low, Vector()) / len(low)


def empty(name, loc):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.01
    e.location = loc
    bpy.context.scene.collection.objects.link(e)
    return e


e_point = empty("contact_point", pad.copy())
e_palm = empty("contact_palm", palm.copy())
offset = -pad.copy()
for o in (arm_obj, e_point, e_palm):
    o.location = o.location + offset
bpy.context.view_layer.update()
# Fuera todo lo que no es la mano: MPFB deja objetos auxiliares (por ejemplo, una icoesfera de 2 m).
keep = {body.name, arm_obj.name, e_point.name, e_palm.name}
for o in list(bpy.data.objects):
    if o.name not in keep:
        bpy.data.objects.remove(o, do_unlink=True)
print("TRIS", lib.triangles(body))
print("DIM", tuple(round(x, 4) for x in body.dimensions))


if A["out"]:
    lib.export_glb(A["out"])

if A["render"]:
    name = "hand_ghost" if NO_ARM else "hand"
    lib.select_only(arm_obj)
    bpy.ops.object.mode_set(mode="POSE")
    pose = {"middle": (40, 72, 30), "ring": (42, 74, 30), "pinky": (44, 76, 30), "thumb": (8, 14, 10), "index": (2, 4, 2)}
    for fname, angs in pose.items():
        for k, deg in enumerate(angs):
            pb = arm_obj.pose.bones.get("%s_%d" % (fname, k + 1))
            if pb:
                pb.rotation_mode = "XYZ"
                spread = 38.0 if (fname == "thumb" and k == 0) else 0.0  # = HandRig.THUMB_TUCK
                pb.rotation_euler = (math.radians(-deg), 0.0, math.radians(-spread))  # -X cierra hacia la palma
    bpy.ops.object.mode_set(mode="OBJECT")
    lib.render_set(A["render"], name, elev=0.7)
    lib.render_game_view(A["render"], name, yaw_deg=55.0, tilt_deg=-14.0)
