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
leather = lib.material("leather", lib.hex_color("#7A4A24"), rough=0.55, clearcoat=0.15)
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


def half_width(y, z):
    """Ancho de la planta según el largo (talón angosto, antepié ancho) y la altura."""
    u = (y + 0.150) / 0.300
    plan = 0.036 + 0.018 * math.sin(min(max(u, 0.0), 1.0) * math.pi * 0.9) - 0.006 * max(0.0, u - 0.82) / 0.18
    if z > 0.09:  # la caña es más redonda y un poco más angosta
        k = min((z - 0.09) / 0.05, 1.0)
        plan = plan * (1.0 - k) + 0.043 * k
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
        y = yc + a * u * scale
        x = half_width(y, z) * math.copysign(abs(su) ** 0.85, su) * scale
        pts.append(Vector((x, y, z + z_tilt * (yc - y))))
    return pts


N = 20
levels = [SOLE_TOP, 0.032, 0.046, 0.062, 0.078, 0.095, 0.112, 0.130, 0.150, 0.170, 0.190, 0.205]
bm = bmesh.new()
rings = []
for k, z in enumerate(levels):
    tilt = 0.18 * max(0.0, (z - 0.15) / 0.055)  # las secciones de arriba suben hacia atrás
    rings.append([bm.verts.new(p) for p in ring(z, N, tilt)])
# Borde del cuello: se enrolla hacia adentro (abierto) y baja un poco (el pie entra por ahí).
top = ring(levels[-1], N, 0.18)
inner = [bm.verts.new(Vector((p.x * 0.80, p.y * 0.92 - 0.006, p.z - 0.004))) for p in top]
deep = [bm.verts.new(Vector((p.x * 0.74, p.y * 0.88 - 0.008, p.z - 0.050))) for p in top]
rings += [inner, deep]
for k in range(len(rings) - 1):
    for i in range(N):
        j = (i + 1) % N
        bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
bm.faces.new(list(reversed(rings[0])))
bm.faces.new(rings[-1])
# Puntera reforzada y contrafuerte: zonas de la misma malla, un poco infladas y más oscuras.
bm.faces.ensure_lookup_table()
for v in bm.verts:
    toe = v.co.y > 0.088 and v.co.z < 0.074
    heel = v.co.y < -0.098 and v.co.z < 0.094
    if toe or heel:
        c = Vector((0.0, v.co.y, v.co.z))
        v.co = c + (v.co - c) * 1.035
for f in bm.faces:
    m = f.calc_center_median()
    if (m.y > 0.088 and m.z < 0.074) or (m.y < -0.098 and m.z < 0.094):
        f.material_index = 1
me = bpy.data.meshes.new("upper")
bm.to_mesh(me)
bm.free()
upper = bpy.data.objects.new("upper", me)
bpy.context.scene.collection.objects.link(upper)
upper.data.materials.append(leather)
upper.data.materials.append(leather_dark)
lib.subsurf(upper, 1)
lib.apply_modifiers(upper)
parts = [upper]


def on_surface(x, z, out=0.0015):
    """Punto de la superficie (ya subdividida) del frente de la bota a la altura z y lado x."""
    ok, loc, nrm, _ = upper.ray_cast(Vector((x, 0.40, z)), Vector((0.0, -1.0, 0.0)))
    if not ok:
        return Vector((x, y_front(z), z)), Vector((0.0, 1.0, 0.0))
    return loc + nrm * out, nrm

# --- Cuello acolchado: un rollo alrededor de la boca ------------------------------------------
collar_pts = [((p.x * 0.93), p.y * 0.97 - 0.002, p.z + 0.002) for p in top]
collar_pts.append(collar_pts[0])
collar = lib.tube_along("collar", collar_pts, [0.0085] * len(collar_pts), sides=8)
collar.data.materials.append(leather_dark)
parts.append(collar)

# --- Lengüeta: sale de la boca, sigue el empeine y asoma arriba --------------------------------
tongue_pts = []
for z in (0.100, 0.130, 0.160, 0.190):
    tongue_pts.append(tuple(on_surface(0.0, z, -0.002)[0]))
tongue_pts.append((0.0, tongue_pts[-1][1] - 0.004, 0.216))
tongue = lib.tube_along("tongue", tongue_pts, [0.017, 0.020, 0.021, 0.021, 0.019], sides=10, squash=0.32)
tongue.data.materials.append(leather_dark)
parts.append(tongue)

# --- Suela: sigue el contorno, entresuela + taco + tacos de dibujo -----------------------------
def sole_slab(name, z0, z1, scale, y_lo=-1.0, y_hi=1.0, n=24):
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
parts.append(sole_slab("heel_block", -0.010, 0.010, 1.05, -0.2, -0.070))   # taco
parts.append(sole_slab("fore_sole", -0.004, 0.010, 1.05, -0.030, 0.2))     # planta delantera
for row in range(6):  # tacos de dibujo en chevrón bajo la planta
    y = -0.012 + row * 0.027
    w = half_width(y, 0.0) * 0.78
    for sgn in (-1, 1):
        lug = lib.box("lug", (w * 0.95, 0.010, 0.007), (sgn * w * 0.48, y, -0.0065),
                      (0.0, 0.0, math.radians(-22.0 * sgn)))
        lug.data.materials.append(rubber)
        parts.append(lug)
for row in range(2):  # tacos transversales del taco
    lug = lib.box("lug", (0.060, 0.012, 0.007), (0.0, -0.125 + row * 0.030, -0.0125))
    lug.data.materials.append(rubber)
    parts.append(lug)

# --- Ojales y cordones cruzados sobre el empeine y la caña -------------------------------------
eyelets = []
for k in range(5):
    z = 0.098 + k * 0.022
    x = half_width(y_front(z), z) * 0.40
    for sx in (-1, 1):
        p, _n = on_surface(sx * x, z, 0.002)
        eyelets.append(p)
        e = lib.sphere("eyelet", 0.0050, tuple(p), 8, 4)
        e.data.materials.append(metal)
        parts.append(e)
for k in range(4):  # cada tramo va del ojal izquierdo k al derecho k+1 y al revés: X
    a_l, a_r = eyelets[2 * k], eyelets[2 * k + 1]
    b_l, b_r = eyelets[2 * k + 2], eyelets[2 * k + 3]
    for p0, p1 in ((a_l, b_r), (a_r, b_l)):
        mid = (p0 + p1) * 0.5 + Vector((0.0, 0.006, 0.0))
        seg = lib.tube_along("lace", [tuple(p0), tuple(mid), tuple(p1)], [0.0034, 0.0038, 0.0034], sides=6)
        seg.data.materials.append(lace)
        parts.append(seg)
bow = lib.tube_along("bow", [tuple(eyelets[-2] + Vector((0, 0.004, 0.006))), (0.0, eyelets[-1].y + 0.012, eyelets[-1].z + 0.016),
                             tuple(eyelets[-1] + Vector((0, 0.004, 0.006)))], [0.0034, 0.0042, 0.0034], sides=6)
bow.data.materials.append(lace)
parts.append(bow)

lib.finish(parts, "boot", A, render_args={"elev": 0.35}, angle=48.0)
if A["render"]:
    # En el juego la bota se ve de 3/4 de costado (la punta hacia la derecha y hacia adelante).
    lib.render_game_view(A["render"], "boot", yaw_deg=-65.0, tilt_deg=0.0, fill=0.55)
