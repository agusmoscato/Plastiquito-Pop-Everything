"""Bota de trabajo (ronda 3). Largo ~0,30 m hacia +Y, origen en el centro de la suela, en el suelo.

La caña y el pie salen de UNA silueta lateral (curvas de frente y talón en función de la altura)
extruida como un loft de secciones horizontales con forma de planta de pie (talón angosto, antepié
ancho, punta redonda) y subdividida. Encima: cuello acolchado abierto, lengüeta, contrafuerte,
puntera reforzada, suela que sigue el contorno con taco y tacos de dibujo, y cordones cruzados.
Presupuesto: hasta 4.000 triángulos.
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
lib.reset()
leather = lib.vertex_tint_material("leather", lib.hex_color("#7A4A24"), rough=0.55, clearcoat=0.15)
leather_dark = lib.material("leather_dark", lib.hex_color("#4A2C14"), rough=0.5, clearcoat=0.2)
rubber = lib.material("sole", lib.hex_color("#2A2522"), rough=0.85)
lace = lib.material("lace", lib.hex_color("#E9C46A"), rough=0.7)
metal = lib.material("eyelet", lib.hex_color("#B8BEC4"), rough=0.3, metal=0.8)

SOLE_TOP = 0.022   # el cuero arranca sobre la entresuela
COLLAR_BACK = 0.215
COLLAR_FRONT = 0.185


# --- Silueta lateral: borde de adelante y de atrás en función de la altura ---------------------
def y_front(z):
    if z <= 0.030:
        return 0.150
    if z <= 0.070:  # punta redonda
        t = (z - 0.030) / 0.040
        return 0.150 - 0.030 * (1.0 - math.sqrt(max(0.0, 1.0 - t * t)))
    if z <= 0.125:  # empeine
        t = (z - 0.070) / 0.055
        return 0.120 - 0.115 * (t ** 0.85)
    t = (z - 0.125) / (COLLAR_FRONT - 0.125)  # frente de la caña, apenas inclinada hacia adelante
    return 0.005 - 0.020 * min(t, 1.0)


def y_back(z):
    if z <= 0.060:  # talón redondo con contrafuerte
        t = (z - 0.030) / 0.040
        return -0.138 - 0.010 * math.sqrt(max(0.0, 1.0 - t * t))
    t = (z - 0.060) / (COLLAR_BACK - 0.060)  # tendón: entra y vuelve a salir en el cuello
    return -0.140 + 0.020 * math.sin(min(t, 1.0) * math.pi * 0.85)


def lean(z):
    """La caña se inclina hacia atrás por encima del tobillo."""
    return -0.10 * max(0.0, z - 0.085)


def half_width(y, z):
    """Ancho de la planta según el largo (talón angosto, antepié ancho) y la altura."""
    u = (y + 0.150) / 0.300
    plan = 0.036 + 0.018 * math.sin(min(max(u, 0.0), 1.0) * math.pi * 0.9) - 0.006 * max(0.0, u - 0.82) / 0.18
    if z > 0.09:  # la caña es más redonda; se angosta en el tobillo y se abre un poco arriba
        k = min((z - 0.09) / 0.05, 1.0)
        ankle = 0.038 + 0.006 * max(0.0, (z - 0.13) / 0.08)
        plan = plan * (1.0 - k) + ankle * k
    return plan * (1.0 - 0.10 * max(0.0, z - 0.06) / 0.16)


def ring(z, n, z_tilt=0.0, scale=1.0):
    """Sección horizontal con forma de planta. z_tilt inclina la sección (el cuello sube atrás)."""
    yb, yf = y_back(z), y_front(z)
    yc, a = (yb + yf) * 0.5, (yf - yb) * 0.5
    pts = []
    for i in range(n):
        th = 2.0 * math.pi * i / n
        cu, su = math.cos(th), math.sin(th)
        u = math.copysign(abs(cu) ** 0.8, cu)  # un poco más cuadrada que una elipse
        y = yc + a * u * scale + lean(z)
        x = half_width(y, z) * math.copysign(abs(su) ** 0.85, su) * scale
        pts.append(Vector((x, y, z + z_tilt * (yc - y))))
    return pts


N = 18
levels = [SOLE_TOP, 0.032, 0.046, 0.062, 0.078, 0.095, 0.112, 0.124]  # el pie; la caña es un Skin aparte
bm = bmesh.new()
rings = []
TUCK = {0.112: 0.88, 0.124: 0.72}  # el borde de arriba del pie se mete adentro de la caña (sin escalón)
for k, z in enumerate(levels):
    tilt = 0.18 * max(0.0, (z - 0.15) / 0.055)  # las secciones de arriba suben hacia atrás
    sc = TUCK.get(z, 1.0)
    pts = ring(z, N, tilt)
    cy = sum(q.y for q in pts) / len(pts)
    rings.append([bm.verts.new(Vector((q.x * sc, cy + (q.y - cy) * sc, q.z))) for q in pts])
for k in range(len(rings) - 1):
    for i in range(N):
        j = (i + 1) % N
        bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
bm.faces.new(list(reversed(rings[0])))
bm.faces.new(rings[-1])
# Puntera reforzada y contrafuerte: zonas de la misma malla, un poco infladas y más oscuras.
def reinforced_raw(c):
    return (c.z < 0.074 and c.y > 0.080 + 0.45 * (c.z - 0.022)) or (c.y < -0.080 and c.z < 0.098 - 0.75 * max(0.0, c.y + 0.112))


bm.faces.ensure_lookup_table()
for v in bm.verts:
    if reinforced_raw(v.co):
        c = Vector((0.0, v.co.y, v.co.z))
        v.co = c + (v.co - c) * 1.035
me = bpy.data.meshes.new("upper")
bm.to_mesh(me)
bm.free()
upper = bpy.data.objects.new("upper", me)
bpy.context.scene.collection.objects.link(upper)
upper.data.materials.append(leather)
lib.subsurf(upper, 1)
lib.apply_modifiers(upper)


def reinforced(c):
    """Puntera (borde inclinado) y contrafuerte (borde que baja hacia adelante), con curvas suaves."""
    toe = c.z < 0.074 and c.y > 0.080 + 0.45 * (c.z - 0.022) + 0.004 * math.cos(c.x * 60.0)
    heel_top = 0.098 - 0.75 * max(0.0, c.y + 0.112)
    heel = c.y < -0.080 and c.z < heel_top
    return toe or heel


def reinforce_shade(c):
    """1 = cuero claro, 0,55 = reforzado; transición de ~3 mm (borde limpio, sin escalones)."""
    toe_edge = 0.080 + 0.45 * (c.z - 0.022)
    t_toe = min(max((c.y - toe_edge) / 0.003, 0.0), 1.0) * min(max((0.074 - c.z) / 0.003, 0.0), 1.0)
    heel_top = 0.098 - 0.75 * max(0.0, c.y + 0.112)
    t_heel = min(max((heel_top - c.z) / 0.003, 0.0), 1.0) * min(max((-0.080 - c.y) / 0.003, 0.0), 1.0)
    return 1.0 - 0.52 * max(t_toe, t_heel)


# --- Caña: Skin Modifier sobre una cadena de vértices (tobillo -> cuello), con quiebre en el tobillo ---
SKIN_COMP = 1.05  # el Skin arma secciones cuadradas y la subdivisión las redondea y achica
SHAFT = [  # (z, y de atrás, y de adelante, medio ancho): frente alto (como una bota de 15 cm de caña)
    (0.072, -0.132, 0.040, 0.041),
    (0.100, -0.128, 0.022, 0.039),
    (0.128, -0.122, 0.014, 0.0365),  # tobillo: lo más angosto, el tendón entra
    (0.160, -0.126, 0.012, 0.0385),
    (0.190, -0.130, 0.012, 0.0410),
    (0.212, -0.133, 0.010, 0.0425),
]


def shaft_skin():
    verts = []
    radii = []
    for (z, yb, yf, hw) in SHAFT:
        back_lean = -0.05 * max(0.0, z - 0.10)  # la caña se inclina apenas hacia atrás
        verts.append((0.0, (yb + yf) * 0.5 + back_lean, z))
        radii.append((hw * SKIN_COMP, (yf - yb) * 0.5 * SKIN_COMP))
    me2 = bpy.data.meshes.new("shaft")
    me2.from_pydata(verts, [(i, i + 1) for i in range(len(verts) - 1)], [])
    o = bpy.data.objects.new("shaft", me2)
    bpy.context.scene.collection.objects.link(o)
    lib.select_only(o)
    o.modifiers.new("Skin", "SKIN")
    for i, v in enumerate(me2.skin_vertices[0].data):
        v.radius = radii[i]
        v.use_root = i == 0
    lib.subsurf(o, 2)
    lib.apply_modifiers(o)
    o.data.materials.append(leather)
    return o


def open_mouth(o):
    """Boca abierta: se sacan las caras de la tapa de arriba de la caña (el pie entra por ahí)."""
    bm3 = bmesh.new()
    bm3.from_mesh(o.data)
    top_z = max(v.co.z for v in bm3.verts)
    cap = [f for f in bm3.faces if f.calc_center_median().z > top_z - 0.012 and f.normal.z > 0.55]
    bmesh.ops.delete(bm3, geom=cap, context="FACES")
    bm3.to_mesh(o.data)
    bm3.free()


def fuse(parts_in, name, voxel=0.003, target_tris=2100):
    """Pie y caña en UN volumen: remallado por vóxeles (sin la costura dentada donde se cruzaban),
    suavizado y decimado al presupuesto de triángulos."""
    o = lib.join(parts_in, name)
    rm = o.modifiers.new("Remesh", "REMESH")
    rm.mode = "VOXEL"
    rm.voxel_size = voxel
    sm = o.modifiers.new("Smooth", "SMOOTH")
    sm.factor = 0.6
    sm.iterations = 6
    lib.apply_modifiers(o)
    tris = lib.triangles(o)
    dec = o.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = min(1.0, target_tris / max(tris, 1))
    lib.apply_modifiers(o)
    return o


shaft = shaft_skin()
upper = fuse([upper, shaft], "upper")
open_mouth(upper)
upper.data.materials.clear()
upper.data.materials.append(leather)
lib.paint(upper, reinforce_shade)
shaft = upper  # los rayos (lengüeta, ojales, ribetes) van contra el volumen fundido


def _ray(origin, d):
    """Rayo contra el pie y la caña; devuelve el impacto más cercano al origen."""
    best = None
    for obj in (upper, shaft):
        ok, loc, nrm, _ = obj.ray_cast(origin, d)
        if ok and (best is None or (loc - origin).length < (best[0] - origin).length):
            best = (loc, nrm)
    return best


def hit_from(center, d):
    h = _ray(center + d * 0.25, -d)
    return (h[0] + h[1] * 0.0012) if h else None


def welt_toe():
    """Ribete del borde de la puntera: corta el frente con el plano inclinado y lo proyecta."""
    pts = []
    for i in range(15):
        t = -1.0 + 2.0 * i / 14
        z = 0.024 + 0.050 * math.cos(t * math.pi * 0.5)
        y = 0.080 + 0.45 * (z - 0.022)
        d = Vector((math.sin(t * math.pi * 0.5), 0.0, math.cos(t * math.pi * 0.5))).normalized()
        h = hit_from(Vector((0.0, y, 0.024)), d)
        if h is not None:
            pts.append(tuple(h))
    return pts


def welt_heel():
    """Ribete del contrafuerte: rodea el talón a la altura del borde (que baja hacia adelante)."""
    pts = []
    for i in range(17):
        ang = math.radians(-115.0 + 230.0 * i / 16)
        d = Vector((math.sin(ang), -math.cos(ang), 0.0))
        y_est = -0.120
        h = None
        for _ in range(4):
            z = 0.098 - 0.75 * max(0.0, y_est + 0.112)
            h = hit_from(Vector((0.0, -0.095, z)), d)
            if h is None:
                break
            y_est = h.y
        if h is not None and y_est < -0.078:
            pts.append(tuple(h))
    return pts


for nm, pts in (("welt_toe", welt_toe()), ("welt_heel", welt_heel())):
    if len(pts) >= 3:
        w = lib.tube_along(nm, pts, [0.0019] * len(pts), sides=5)
        w.data.materials.append(leather_dark)
        parts_welts = globals().setdefault("parts_welts", [])
        parts_welts.append(w)
parts = [upper] + globals().get("parts_welts", [])


def on_surface(x, z, out=0.0015):
    """Punto de la superficie (ya subdividida) del frente de la bota a la altura z y lado x."""
    h = _ray(Vector((x, 0.40, z)), Vector((0.0, -1.0, 0.0)))
    if h is None:
        return Vector((x, y_front(z), z)), Vector((0.0, 1.0, 0.0))
    return h[0] + h[1] * out, h[1]

# --- Cuello acolchado: un rollo alrededor de la boca ------------------------------------------
# Acolchado del cuello: arco bajo que rodea talón y costados y queda abierto adelante (lengüeta).
rim = [shaft.data.vertices[i].co.copy() for e in shaft.data.edges if len([f for f in shaft.data.polygons if e.key in f.edge_keys]) == 1 for i in e.vertices]
rim_c = sum(rim, Vector()) / max(len(rim), 1)
# El borde recortado tiene varias alturas: se toma el punto más alto en cada uno de 22 ángulos y se
# suaviza, así el acolchado sigue una curva limpia (sin zigzag).
def _ang(p):
    return math.atan2(p.x, -(p.y - rim_c.y))


samples = []
for k in range(22):
    a0 = -math.pi + 2.0 * math.pi * k / 22
    near = [p for p in rim if abs(math.atan2(math.sin(_ang(p) - a0), math.cos(_ang(p) - a0))) < math.pi / 22]
    if near:
        samples.append((a0, max(near, key=lambda p: p.z)))
pts_s = [p for (_, p) in samples]
smooth_pts = [(pts_s[i - 1] + pts_s[i] * 2.0 + pts_s[(i + 1) % len(pts_s)]) / 4.0 for i in range(len(pts_s))]
arc = [p for (a, _), p in zip(samples, smooth_pts) if abs(a) > 0.55]  # abierto adelante (lengüeta)
arc.sort(key=_ang)
collar_pts = [(p.x, p.y, p.z + 0.002) for p in arc]
rad = [0.0075 + 0.0045 * math.sin(math.pi * i / (len(collar_pts) - 1)) for i in range(len(collar_pts))]  # cubre el borde recortado
collar = lib.tube_along("collar", collar_pts, rad, sides=7, squash=0.7)
collar.data.materials.append(leather_dark)
parts.append(collar)

# --- Lengüeta: sale de la boca, sigue el empeine y asoma arriba --------------------------------
tongue_pts = []
for z in (0.092, 0.115, 0.138, 0.161, 0.184, 0.200, 0.212):
    tongue_pts.append(tuple(on_surface(0.0, z, 0.0004)[0]))
tongue = lib.tube_along("tongue", tongue_pts, [0.010, 0.013, 0.014, 0.0145, 0.0145, 0.014, 0.012], sides=12, squash=0.18)
tongue.data.materials.append(leather)  # cuero claro: oscura se leía como un agujero
parts.append(tongue)

# --- Suela: sigue el contorno, entresuela + taco + tacos de dibujo -----------------------------
def sole_slab(name, z0, z1, scale, y_lo=-1.0, y_hi=1.0, n=20):
    base = [p for p in ring(SOLE_TOP + 0.001, n, 0.0, scale)]
    base = [Vector((p.x, min(max(p.y, y_lo), y_hi), 0.0)) for p in base]
    bm3 = bmesh.new()
    b = [bm3.verts.new((p.x, p.y, z0)) for p in base]
    t = [bm3.verts.new((p.x, p.y, z1)) for p in base]
    for i in range(n):
        j = (i + 1) % n
        bm3.faces.new((b[i], b[j], t[j], t[i]))
    bm3.faces.new(list(reversed(b)))
    bm3.faces.new(t)
    me3 = bpy.data.meshes.new(name)
    bm3.to_mesh(me3)
    bm3.free()
    o = bpy.data.objects.new(name, me3)
    bpy.context.scene.collection.objects.link(o)
    lib.bevel(o, 0.003, 1, 50.0)
    o.data.materials.append(rubber)
    return o


parts.append(sole_slab("midsole", 0.008, SOLE_TOP + 0.002, 1.07))
parts.append(sole_slab("heel_block", -0.010, 0.036, 1.06, -0.2, -0.070))   # taco alto: sube sobre el cuero y se lee de perfil
parts.append(sole_slab("fore_sole", -0.004, 0.010, 1.05, -0.030, 0.2))     # planta delantera
for row in range(6):  # tacos de dibujo en chevrón bajo la planta
    y = -0.012 + row * 0.027
    w = half_width(y, 0.0) * 0.80
    for sgn in (-1, 1):
        lug = lib.box("lug", (w * 0.70, 0.009, 0.004), (sgn * w * 0.40, y, -0.0050),
                      (0.0, 0.0, math.radians(-20.0 * sgn)))
        lug.data.materials.append(rubber)
        parts.append(lug)
for row in range(2):  # tacos transversales del taco
    lug = lib.box("lug", (0.050, 0.010, 0.004), (0.0, -0.122 + row * 0.026, -0.0110))
    lug.data.materials.append(rubber)
    parts.append(lug)

# --- Ojales y cordones cruzados sobre el empeine y la caña -------------------------------------
eyelets = []
for k in range(6):
    z = 0.092 + k * 0.0205
    x = half_width(y_front(z), z) * 0.40
    for sx in (-1, 1):
        p, _n = on_surface(sx * x, z, 0.002)
        eyelets.append(p)
        e = lib.sphere("eyelet", 0.0050, tuple(p), 6, 3)
        e.data.materials.append(metal)
        parts.append(e)
for k in range(5):  # cada tramo va del ojal izquierdo k al derecho k+1 y al revés: X
    a_l, a_r = eyelets[2 * k], eyelets[2 * k + 1]
    b_l, b_r = eyelets[2 * k + 2], eyelets[2 * k + 3]
    for p0, p1 in ((a_l, b_r), (a_r, b_l)):
        mid = (p0 + p1) * 0.5 + Vector((0.0, 0.003, 0.0))
        seg = lib.tube_along("lace", [tuple(p0), tuple(mid), tuple(p1)], [0.0042, 0.0048, 0.0042], sides=6)
        seg.data.materials.append(lace)
        parts.append(seg)
top_l, top_r = eyelets[-2], eyelets[-1]
knot = (top_l + top_r) * 0.5 + Vector((0.0, 0.008, -0.004))
for sx in (-1, 1):  # moño: dos lazos y dos puntas largas que cuelgan por el costado
    loop_pts = [tuple(knot), tuple(knot + Vector((sx * 0.018, 0.010, 0.003))), tuple(knot + Vector((sx * 0.034, 0.006, -0.006))),
                tuple(knot + Vector((sx * 0.016, 0.006, -0.010))), tuple(knot)]
    bow = lib.tube_along("bow", loop_pts, [0.0042, 0.0046, 0.0046, 0.0046, 0.0042], sides=6)
    bow.data.materials.append(lace)
    parts.append(bow)
    end_pts = [tuple(knot), tuple(knot + Vector((sx * 0.012, 0.010, -0.012))), tuple(knot + Vector((sx * 0.020, 0.008, -0.034))),
               tuple(knot + Vector((sx * 0.024, 0.004, -0.052)))]
    end = lib.tube_along("lace_end", end_pts, [0.0042, 0.0042, 0.0040, 0.0036], sides=6)
    end.data.materials.append(lace)
    parts.append(end)

for part in parts[1:]:
    lib.paint(part)  # el resto, blanco: Godot multiplica el albedo por el color de vértice
bpy.context.view_layer.update()
floor_z = min((o.matrix_world @ v.co).z for o in parts for v in o.data.vertices)
for o in parts:  # origen en el suelo: la base de los tacos queda en z = 0
    o.location.z -= floor_z
lib.finish(parts, "boot", A, render_args={"elev": 0.35}, angle=48.0)
if A["render"]:
    # En el juego la bota se ve de 3/4 de costado (la punta hacia la derecha y hacia adelante).
    lib.render_game_view(A["render"], "boot", yaw_deg=-65.0, tilt_deg=0.0, fill=0.55)
