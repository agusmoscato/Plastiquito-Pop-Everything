"""Utilería argentina de los escenarios, modelada en Blender (sin interfaz), a escala real en metros
(el juego la usa x100: 1 unidad = 1 cm). Origen en la base, apoyada en z = 0. Todo propio, sin marcas.

  Mesa:            mate (calabaza con virola, yerba y bombilla), termo, yerba (paquete sin marca)
  Piso:            pelota (cuero de 32 gajos), alpargatas (par), sifon (soda con cabezal de metal)
  Galpón:          garrafa (10 kg), cajon (de naranjas)
  Estacionamiento: chulengo (parrilla de tambor con chorizos y brasas), conservadora

Uso: argentina.py -- --out x.glb --render carpeta --which mate|termo|yerba|pelota|alpargatas|sifon|garrafa|cajon|chulengo|conservadora
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
import bmesh
import bpy
from mathutils import Matrix, Vector
from art import lib

A = lib.args()
which = sys.argv[sys.argv.index("--which") + 1] if "--which" in sys.argv else "mate"
lib.reset()
random.seed(7)
parts = []


def hx(h):
    return lib.hex_color(h)


def revolve(name, profile, segs=48, cap_start=True, cap_end=True, closed=False):
    """Sólido de revolución [(radio, z)...] alrededor de Z. `closed`: el perfil es un lazo (aros, virolas)."""
    bm = bmesh.new()
    rings = []
    for (r, z) in profile:
        ring = []
        for i in range(segs):
            a = 2.0 * math.pi * i / segs
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), z)))
        rings.append(ring)
    n = len(rings)
    last = n if closed else n - 1
    for k in range(last):
        ra = rings[k]
        rb = rings[(k + 1) % n]
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((ra[i], ra[j], rb[j], rb[i]))
    if not closed:
        if cap_start and profile[0][0] > 1e-6:
            bm.faces.new(list(reversed(rings[0])))
        if cap_end and profile[-1][0] > 1e-6:
            bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def tube(name, points, radii, sides=12, squash=1.0):
    """Tubo por una polilínea con marco de transporte paralelo: no se retuerce en las curvas
    (lib.tube_along cambia de vector de referencia y deja un quiebre)."""
    pts = [Vector(p) for p in points]
    tans = []
    for i in range(len(pts)):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, len(pts) - 1)]
        tans.append((b - a).normalized())
    ref = Vector((0, 1, 0)) if abs(tans[0].y) < 0.9 else Vector((1, 0, 0))
    n = tans[0].cross(ref).normalized()
    bm = bmesh.new()
    rings = []
    for i, p in enumerate(pts):
        t = tans[i]
        if i > 0:
            n = (n - t * n.dot(t)).normalized() # transporte paralelo
        b = t.cross(n).normalized()
        ring = []
        for k in range(sides):
            ang = 2.0 * math.pi * k / sides
            ring.append(bm.verts.new(p + n * math.cos(ang) * radii[i] + b * math.sin(ang) * radii[i] * squash))
        rings.append(ring)
    for k in range(len(rings) - 1):
        for i in range(sides):
            j = (i + 1) % sides
            bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def mat(name, color, rough=0.5, metal=0.0, alpha=1.0, emission=None):
    m = lib.material(name, hx(color) if isinstance(color, str) else color, rough=rough, metal=metal, emission=emission, alpha=alpha)
    if alpha < 1.0:
        m.blend_method = "BLEND" if hasattr(m, "blend_method") else m.blend_method
    return m


def tinted(name, color, rough=0.5):
    return lib.vertex_tint_material(name, hx(color), rough=rough)


def give(o, m):
    o.data.materials.append(m)
    return o


def paint(o, fn):
    lib.paint(o, fn)
    return o


def rounded_rect(w, d, r, n=6):
    """Contorno de rectángulo redondeado (x, y), sentido antihorario."""
    pts = []
    cs = [(w / 2 - r, d / 2 - r, 0), (-w / 2 + r, d / 2 - r, 90), (-w / 2 + r, -d / 2 + r, 180), (w / 2 - r, -d / 2 + r, 270)]
    for (cx, cy, a0) in cs:
        for i in range(n + 1):
            a = math.radians(a0 + 90.0 * i / n)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def extrude_outline(name, outline, z0, z1):
    bm = bmesh.new()
    lo = [bm.verts.new((x, y, z0)) for (x, y) in outline]
    hi = [bm.verts.new((x, y, z1)) for (x, y) in outline]
    m = len(outline)
    for i in range(m):
        j = (i + 1) % m
        bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    bm.faces.new(list(reversed(lo)))
    bm.faces.new(hi)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def rbox(name, size, loc, bev=0.003, rot=(0, 0, 0)):
    b = lib.box(name, size, loc, rot)
    lib.bevel(b, bev, 2, 30.0)
    return b


# --- Mesa ----------------------------------------------------------------------------------------

def mate():
    # Calabaza: panza ancha, cuello angosto y boca con virola de alpaca. Cuero curtido oscuro abajo.
    leather = tinted("mate_cuero", "#6B4426", rough=0.55)
    outer = [(0.0, 0.0), (0.013, 0.0), (0.019, 0.002), (0.028, 0.008), (0.035, 0.019), (0.0385, 0.033),
             (0.0375, 0.047), (0.0335, 0.059), (0.029, 0.067), (0.0272, 0.072)]
    body = revolve("calabaza", outer, 56, cap_end=False)
    lib.subsurf(body, 1)
    give(body, leather)
    paint(body, lambda c: 0.62 + 0.38 * min(1.0, c.z / 0.05))
    # Costura de cuero alrededor de la panza.
    seam = revolve("costura", [(0.03855, 0.0322), (0.03895, 0.033), (0.03855, 0.0338), (0.0382, 0.033)], 56, closed=True)
    give(seam, mat("mate_costura", "#3A2414", rough=0.8))
    # Virola: aro de metal con borde redondeado y una línea grabada.
    alpaca = mat("alpaca", "#C9CCD0", rough=0.3, metal=0.9)
    virola = revolve("virola", [(0.0262, 0.0700), (0.0292, 0.0700), (0.0298, 0.0745), (0.0296, 0.0790),
                                (0.0283, 0.0805), (0.0258, 0.0800), (0.0252, 0.0760)], 56, closed=True)
    lib.subsurf(virola, 1)
    give(virola, alpaca)
    # Yerba: la "montañita" contra un costado, con el hueco de la bombilla.
    yerba = tinted("yerba", "#61792C", rough=0.95)
    bm = bmesh.new()
    rings = 10
    segs = 48
    center = bm.verts.new((0.0, 0.0, 0.0740))
    prev = None
    for r in range(1, rings + 1):
        rr = 0.0262 * r / rings
        ring = []
        for i in range(segs):
            a = 2.0 * math.pi * i / segs
            x, y = rr * math.cos(a), rr * math.sin(a)
            mound = 0.010 * max(0.0, 1.0 - ((x + 0.010) ** 2 + y ** 2) / 0.00030) # montañita a un costado
            z = 0.0705 + mound + 0.0008 * math.sin(i * 1.7 + r * 2.3)
            ring.append(bm.verts.new((x, y, z)))
        if prev is None:
            for i in range(segs):
                bm.faces.new((center, ring[i], ring[(i + 1) % segs]))
        else:
            for i in range(segs):
                j = (i + 1) % segs
                bm.faces.new((prev[i], prev[j], ring[j], ring[i]))
        prev = ring
    me = bpy.data.meshes.new("yerba")
    bm.to_mesh(me)
    bm.free()
    yo = bpy.data.objects.new("yerba", me)
    bpy.context.scene.collection.objects.link(yo)
    give(yo, yerba)
    paint(yo, lambda c: 0.75 + 0.25 * min(1.0, (c.z - 0.070) / 0.009) + 0.06 * math.sin(c.x * 900.0) * math.sin(c.y * 800.0))
    # Bombilla: caño de alpaca inclinado, curva arriba, boquilla aplastada y anillo de bronce.
    pts = []
    p0, p1, p2 = Vector((0.005, -0.004, 0.060)), Vector((0.016, -0.004, 0.150)), Vector((0.038, -0.004, 0.160))
    for i in range(14): # curva suave: recta casi todo el largo y se dobla arriba hacia la boca
        t = (i / 13.0) ** 0.6
        q = p0 * (1 - t) ** 2 + p1 * 2 * t * (1 - t) + p2 * t * t
        pts.append((q.x, q.y, q.z))
    bomb = tube("bombilla", pts, [0.0026] * 13 + [0.0024], sides=14, squash=1.0)
    give(bomb, alpaca)
    tip_dir = (Vector(pts[-1]) - Vector(pts[-2])).normalized()
    tip = tube("boquilla", [pts[-1], tuple(Vector(pts[-1]) + tip_dir * 0.010)], [0.0026, 0.0022], sides=14, squash=0.45)
    give(tip, alpaca)
    ring_p = Vector(pts[9])
    ring = tube("anillo", [tuple(ring_p - tip_dir * 0.0025), tuple(ring_p + tip_dir * 0.0025)], [0.0036, 0.0036], sides=16)
    give(ring, mat("bronce", "#C89B4A", rough=0.3, metal=0.9))
    return [body, seam, virola, yo, bomb, tip, ring]


def termo():
    # Termo de acero pintado verde, con vaso-tapón, cebador y manija; aros de acero arriba y abajo.
    paint_green = tinted("termo_verde", "#2F6B4B", rough=0.45)
    steel = mat("termo_acero", "#B9BEC3", rough=0.28, metal=0.9)
    dark = mat("termo_negro", "#26282C", rough=0.6)
    body = revolve("cuerpo", [(0.0, 0.012), (0.041, 0.012), (0.0435, 0.016), (0.0445, 0.030), (0.0445, 0.215),
                              (0.043, 0.228), (0.037, 0.240), (0.0, 0.240)], 56)
    lib.subsurf(body, 1)
    give(body, paint_green)
    paint(body, lambda c: 0.82 + 0.18 * math.cos(c.z * 60.0) ** 2)
    base = revolve("base", [(0.0, 0.0), (0.040, 0.0), (0.0455, 0.004), (0.0460, 0.016), (0.0430, 0.019), (0.0, 0.019)], 56)
    lib.subsurf(base, 1)
    give(base, steel)
    collar = revolve("cuello", [(0.0, 0.238), (0.034, 0.238), (0.0345, 0.252), (0.030, 0.256), (0.0, 0.256)], 48)
    give(collar, steel)
    cap = revolve("vaso", [(0.0, 0.254), (0.0395, 0.254), (0.0405, 0.258), (0.0400, 0.290), (0.0385, 0.297), (0.0, 0.298)], 56)
    lib.subsurf(cap, 1)
    give(cap, steel)
    grip = revolve("goma", [(0.0408, 0.262), (0.0418, 0.264), (0.0418, 0.284), (0.0408, 0.286), (0.0402, 0.274)], 56, closed=True)
    give(grip, dark)
    # Manija: arco grueso de goma negra con sus dos anclajes de acero.
    hp = [(0.044, 0.0, 0.205), (0.062, 0.0, 0.200), (0.074, 0.0, 0.180), (0.078, 0.0, 0.140), (0.075, 0.0, 0.095), (0.064, 0.0, 0.068), (0.044, 0.0, 0.064)]
    handle = tube("manija", hp, [0.0072] * len(hp), sides=14, squash=1.0)
    lib.subsurf(handle, 1)
    give(handle, dark)
    anchors = []
    for z in (0.205, 0.066):
        a = revolve("anclaje", [(0.0, -0.005), (0.009, -0.005), (0.009, 0.005), (0.0, 0.005)], 20)
        a.rotation_euler = (0.0, math.radians(90.0), 0.0)
        a.location = (0.043, 0.0, z)
        give(a, steel)
        anchors.append(a)
    return [body, base, collar, cap, grip, handle] + anchors


def yerba_pack():
    # Paquete de yerba de papel madera: sin marca, con una franja verde y la "ventanita" de la hoja.
    kraft = tinted("kraft", "#C9A36A", rough=0.85)
    w, d, h = 0.085, 0.055, 0.17
    o = extrude_outline("paquete", rounded_rect(w, d, 0.006, 3), 0.0, h)
    give(o, kraft)
    # Cierre: la bolsa doblada en plano arriba, con el doblez que cae sobre el frente.
    top = rbox("cierre", (w - 0.002, d - 0.002, 0.010), (0.0, 0.0, h + 0.004), 0.003)
    give(top, kraft)
    flap = rbox("doblez", (w - 0.004, 0.0035, 0.030), (0.0, -d / 2 - 0.0008, h - 0.012), 0.0012)
    give(flap, kraft)
    band = rbox("franja", (w + 0.0008, d + 0.0008, 0.040), (0.0, 0.0, 0.075), 0.0006)
    give(band, mat("franja_verde", "#3E7A3A", rough=0.6))
    leaf = rbox("hoja", (0.030, 0.002, 0.018), (0.0, -d / 2 - 0.0012, 0.075), 0.0008)
    give(leaf, mat("hoja", "#E8E2C8", rough=0.6))
    paint(o, lambda c: 0.85 + 0.15 * math.sin(c.z * 220.0 + c.x * 90.0) ** 2) # papel arrugado
    return [o, top, flap, band, leaf]


# --- Piso -----------------------------------------------------------------------------------------

def pelota():
    # Pelota de cuero de 32 gajos: un icosaedro truncado de verdad (12 pentágonos negros y 20 hexágonos
    # blancos como caras), con la costura hundida entre gajos, subdividido y llevado a la esfera.
    R = 0.110
    phi = (1.0 + math.sqrt(5.0)) / 2.0
    ico = []
    for a in (-1.0, 1.0):
        for b in (-phi, phi):
            ico += [Vector((0, a, b)), Vector((a, b, 0)), Vector((b, 0, a))]
    ico = [v.normalized() for v in ico]
    edge_len = min((ico[0] - ico[j]).length for j in range(1, 12))
    near = lambda i, j: abs((ico[i] - ico[j]).length - edge_len) < 1e-4
    bm = bmesh.new()
    cut = {}

    def pt(i, j):  # punto del tercio de la arista (i, j) del lado de i
        if (i, j) not in cut:
            cut[(i, j)] = bm.verts.new(ico[i] + (ico[j] - ico[i]) / 3.0)
        return cut[(i, j)]

    def ordered(vs, normal):
        c = sum((v.co for v in vs), Vector()) / len(vs)
        u = (vs[0].co - c).normalized()
        w = normal.cross(u)
        return sorted(vs, key=lambda v: math.atan2((v.co - c).dot(w), (v.co - c).dot(u)))

    for i in range(12):
        ring = [pt(i, j) for j in range(12) if j != i and near(i, j)]
        f = bm.faces.new(ordered(ring, ico[i]))
        f.material_index = 0
    for i in range(12):
        for j in range(i + 1, 12):
            for k in range(j + 1, 12):
                if near(i, j) and near(j, k) and near(i, k):
                    ring = [pt(i, j), pt(j, i), pt(j, k), pt(k, j), pt(k, i), pt(i, k)]
                    nrm = (ico[i] + ico[j] + ico[k]).normalized()
                    f = bm.faces.new(ordered(ring, nrm))
                    f.material_index = 1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    panels = list(bm.faces)
    res = bmesh.ops.inset_individual(bm, faces=panels, thickness=0.013, depth=0.0)
    for f in res["faces"]:
        f.material_index = 2 # costura
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=6, use_grid_fill=True)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    for v in bm.verts:
        seam_only = all(f.material_index == 2 for f in v.link_faces)
        v.co = v.co.normalized() * R * (0.991 if seam_only else 1.0)
    me = bpy.data.meshes.new("pelota")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("pelota", me)
    bpy.context.scene.collection.objects.link(o)
    me.materials.append(mat("cuero_negro", "#202024", rough=0.5))
    me.materials.append(mat("cuero_blanco", "#F2EEE4", rough=0.5))
    me.materials.append(mat("costura", "#5E5A53", rough=0.7))
    o.location = (0.0, 0.0, R)
    return [o]


def _alpargata(side):
    # Suela de yute trenzado (franjas en espiral), capellada de lona azul y ribete.
    jute = tinted("yute", "#C8A874", rough=0.95)
    canvas = tinted("lona", "#2B3E66", rough=0.85)
    L, W = 0.255, 0.092

    def foot(t):  # medio ancho del pie a lo largo (t = 0 talón, 1 punta)
        return W / 2 * (0.72 + 0.28 * math.sin(math.pi * min(1.0, t * 1.25)) ** 0.7) * (1.0 - 0.6 * max(0.0, t - 0.85) / 0.15 * max(0.0, t - 0.85) / 0.15)

    outline = []
    n = 28
    for i in range(n + 1):
        t = i / n
        outline.append((-L / 2 + L * t, foot(t) * (0.2 if i in (0, n) else 1.0)))
    for i in range(n - 1, 0, -1):
        t = i / n
        outline.append((-L / 2 + L * t, -foot(t)))
    sole = extrude_outline("suela", outline, 0.0, 0.021)
    lib.bevel(sole, 0.004, 2, 40.0)
    give(sole, jute)
    paint(sole, lambda c: 0.78 + 0.22 * math.sin(c.z * 900.0 + math.atan2(c.y, c.x) * 6.0) ** 2)
    # Capellada: un domo estirado sobre los dos tercios delanteros, abierto atrás (la boca).
    bm = bmesh.new()
    cols = 22
    rows = 9
    grid = []
    for r in range(rows + 1):
        u = r / rows  # 0 base .. 1 arriba
        row = []
        for c in range(cols + 1):
            t = 0.42 + 0.58 * c / cols
            ang = math.pi * u
            half = foot(t) * 1.02
            y = half * math.cos(ang)
            hgt = 0.048 * math.sin(ang) * (1.0 - 0.75 * ((t - 0.42) / 0.58) ** 2.2)
            row.append(bm.verts.new((-L / 2 + L * t, y, 0.020 + hgt)))
        grid.append(row)
    for r in range(rows):
        for c in range(cols):
            bm.faces.new((grid[r][c], grid[r][c + 1], grid[r + 1][c + 1], grid[r + 1][c]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("capellada")
    bm.to_mesh(me)
    bm.free()
    upper = bpy.data.objects.new("capellada", me)
    bpy.context.scene.collection.objects.link(upper)
    sol = upper.modifiers.new("Grosor", "SOLIDIFY")
    sol.thickness = 0.003
    lib.subsurf(upper, 1)
    give(upper, canvas)
    paint(upper, lambda c: 0.85 + 0.15 * math.sin(c.x * 700.0) * math.sin(c.y * 700.0))
    back = tube("talon", [(-L / 2 + 0.115, -W / 2 * 0.74, 0.030), (-L / 2 + 0.03, -W / 2 * 0.55, 0.034),
                                    (-L / 2 + 0.006, 0.0, 0.036), (-L / 2 + 0.03, W / 2 * 0.55, 0.034), (-L / 2 + 0.115, W / 2 * 0.74, 0.030)],
                          [0.007] * 5, sides=10, squash=0.45)
    lib.subsurf(back, 2)
    give(back, canvas)
    trim = tube("ribete", [(-L / 2 + L * (0.42 + 0.58 * c / 16), foot(0.42 + 0.58 * c / 16) * 1.02 * math.cos(0.0), 0.021) for c in range(17)], [0.0022] * 17, sides=8)
    give(trim, mat("ribete", "#1C2640", rough=0.8))
    objs = [sole, upper, back, trim]
    for o in objs:
        o.location.y += side * 0.06
        o.rotation_euler.z += math.radians(8.0 * side)
    return objs


def alpargatas():
    return _alpargata(1) + _alpargata(-1)


def sifon():
    # Sifón de soda: vidrio azulado con estrías, cabezal de metal con palanca y pico.
    glass = mat("vidrio", (0.35, 0.62, 0.72), rough=0.08, alpha=0.55)
    metal = mat("cromo", "#C7CBD0", rough=0.22, metal=0.95)
    prof = [(0.0, 0.0), (0.042, 0.0), (0.0455, 0.006)]
    for i in range(1, 12):
        z = 0.006 + 0.17 * i / 11
        prof.append((0.0455, z))
    prof += [(0.044, 0.188), (0.036, 0.205), (0.024, 0.215), (0.021, 0.222), (0.0, 0.222)]
    bottle = revolve("botella", prof, 48)
    # Estrías verticales del vidrio.
    for v in bottle.data.vertices:
        r = math.hypot(v.co.x, v.co.y)
        if r > 0.03 and 0.01 < v.co.z < 0.18:
            a = math.atan2(v.co.y, v.co.x)
            k = 1.0 + 0.035 * math.cos(a * 16.0)
            v.co.x *= k
            v.co.y *= k
    lib.subsurf(bottle, 1)
    give(bottle, glass)
    head = revolve("cabezal", [(0.0, 0.218), (0.024, 0.218), (0.026, 0.232), (0.022, 0.262), (0.024, 0.272), (0.018, 0.282), (0.0, 0.284)], 32)
    lib.subsurf(head, 1)
    give(head, metal)
    spout = tube("pico", [(0.012, 0.0, 0.262), (0.040, 0.0, 0.264), (0.062, 0.0, 0.256), (0.072, 0.0, 0.244)], [0.006, 0.0055, 0.005, 0.0045], sides=14)
    lib.subsurf(spout, 2)
    give(spout, metal)
    lever = tube("palanca", [(-0.004, 0.0, 0.284), (0.020, 0.0, 0.296), (0.050, 0.0, 0.300), (0.064, 0.0, 0.296)], [0.0045, 0.006, 0.006, 0.005], sides=10, squash=0.5)
    lib.subsurf(lever, 2)
    give(lever, metal)
    straw = revolve("tubo", [(0.0, 0.012), (0.004, 0.012), (0.004, 0.22), (0.0, 0.22)], 12)
    give(straw, mat("tubo", "#DDE6EA", rough=0.3))
    return [bottle, head, spout, lever, straw]


# --- Galpón ---------------------------------------------------------------------------------------

def garrafa():
    # Garrafa de 10 kg: cuerpo con dos casquetes, zócalo, cuello con válvula y el aro protector con manijas.
    red = tinted("garrafa_pintura", "#D24E2A", rough=0.45)
    steel = mat("garrafa_acero", "#8C9096", rough=0.4, metal=0.7)
    brass = mat("valvula", "#C9A24E", rough=0.3, metal=0.9)
    prof = [(0.0, 0.035), (0.10, 0.035), (0.135, 0.050), (0.152, 0.080), (0.158, 0.12), (0.158, 0.40),
            (0.152, 0.44), (0.135, 0.47), (0.10, 0.49), (0.05, 0.50), (0.0, 0.50)]
    body = revolve("garrafa", prof, 56)
    lib.subsurf(body, 1)
    give(body, red)
    paint(body, lambda c: 0.88 + 0.12 * math.sin(c.z * 40.0 + math.atan2(c.y, c.x) * 3.0) ** 2) # pintura gastada
    weld = revolve("soldadura", [(0.1585, 0.268), (0.1610, 0.272), (0.1585, 0.276), (0.1570, 0.272)], 56, closed=True)
    give(weld, red)
    foot = revolve("zocalo", [(0.115, 0.0), (0.140, 0.0), (0.140, 0.055), (0.130, 0.062), (0.122, 0.055), (0.122, 0.006)], 48, closed=True)
    lib.bevel(foot, 0.002, 1)
    give(foot, steel)
    collar = revolve("aro", [(0.085, 0.485), (0.094, 0.485), (0.094, 0.61), (0.086, 0.61)], 40, closed=True)
    give(collar, steel)
    holes = []
    for s in (-1, 1):
        h = rbox("agarre", (0.070, 0.010, 0.035), (0.0, s * 0.0905, 0.575), 0.003)
        give(h, mat("hueco", "#1B1C1F", rough=0.8))
        holes.append(h)
    valve = revolve("valvula", [(0.0, 0.50), (0.020, 0.50), (0.020, 0.53), (0.014, 0.535), (0.014, 0.56), (0.020, 0.565), (0.020, 0.575), (0.0, 0.575)], 24)
    give(valve, brass)
    knob = revolve("perilla", [(0.0, 0.575), (0.026, 0.575), (0.028, 0.585), (0.024, 0.592), (0.0, 0.592)], 20)
    give(knob, mat("perilla", "#2C2E33", rough=0.5))
    return [body, weld, foot, collar, valve, knob] + holes


def cajon():
    # Cajón de fruta de madera de álamo: listones con luz entre ellos, esquineros y naranjas encima.
    wood = tinted("alamo", "#D2B07A", rough=0.85)
    W, D, H = 0.50, 0.32, 0.24
    objs = []
    for (x, y) in ((-W / 2 + 0.012, -D / 2 + 0.012), (W / 2 - 0.012, -D / 2 + 0.012), (-W / 2 + 0.012, D / 2 - 0.012), (W / 2 - 0.012, D / 2 - 0.012)):
        objs.append(rbox("esquinero", (0.024, 0.024, H), (x, y, H / 2), 0.002))
    for k in range(3):
        z = 0.02 + k * 0.08 + 0.03
        for s in (-1, 1):
            objs.append(rbox("liston", (W, 0.008, 0.055), (0.0, s * (D / 2 - 0.004), z), 0.0015, (0, 0, math.radians(random.uniform(-0.8, 0.8)))))
            objs.append(rbox("liston", (0.008, D - 0.016, 0.055), (s * (W / 2 - 0.004), 0.0, z), 0.0015))
    for k in range(5):
        objs.append(rbox("fondo", (W - 0.02, 0.055, 0.008), (0.0, -D / 2 + 0.035 + k * 0.0625, 0.006), 0.0015))
    for o in objs:
        give(o, wood)
        paint(o, lambda c: 0.80 + 0.20 * math.sin(c.x * 140.0 + c.z * 30.0) ** 2) # veta
    orange = tinted("naranja", "#F08A1C", rough=0.55)
    leaf = mat("hojita", "#3F7A2A", rough=0.6)
    r = 0.042
    for i in range(5):
        for j in range(3):
            for layer in range(2):
                x = -W / 2 + 0.07 + i * 0.09 + (0.045 if layer else 0.0) + random.uniform(-0.006, 0.006)
                y = -D / 2 + 0.075 + j * 0.085 + (0.04 if layer else 0.0) + random.uniform(-0.006, 0.006)
                if layer and (i == 4 or j == 2):
                    continue
                z = 0.012 + r + (0.16 if layer == 0 else 0.22) + random.uniform(-0.004, 0.004)
                o = lib.sphere("naranja", r * random.uniform(0.93, 1.05), (x, y, z), 18, 12, (1.0, 1.0, 0.94))
                give(o, orange)
                paint(o, lambda c: 0.85 + 0.15 * math.sin(c.x * 900.0) * math.sin(c.y * 900.0)) # cáscara
                objs.append(o)
                if random.random() < 0.3:
                    lf = lib.sphere("hojita", 0.012, (x + 0.01, y, z + r * 0.95), 8, 4, (1.6, 0.6, 0.25))
                    give(lf, leaf)
                    objs.append(lf)
    return objs


# --- Estacionamiento -------------------------------------------------------------------------------

def _half_drum(name, R, Lg, cz, upper):
    """Medio tambor (eje X) con sus dos tapas laterales; `upper` la mitad de arriba. Con grosor de chapa."""
    bm = bmesh.new()
    segs = 28
    a0 = 0.0 if upper else math.pi
    rows = []
    for k in range(2):
        x = -Lg / 2 + Lg * k
        rows.append([bm.verts.new((x, R * math.cos(a0 + math.pi * i / segs), cz + R * math.sin(a0 + math.pi * i / segs))) for i in range(segs + 1)])
    for i in range(segs):
        bm.faces.new((rows[0][i], rows[0][i + 1], rows[1][i + 1], rows[1][i]))
    bm.faces.new(list(reversed(rows[0])))
    bm.faces.new(rows[1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    s = o.modifiers.new("Grosor", "SOLIDIFY")
    s.thickness = 0.006
    return o


def chulengo():
    # Chulengo: medio tambor de 200 l acostado sobre patas, tapa abierta con chimenea, parrilla con
    # chorizos y brasas encendidas abajo.
    black = tinted("chapa_negra", "#2A2826", rough=0.75)
    steel = mat("parrilla", "#55595F", rough=0.45, metal=0.7)
    R, Lg, legh = 0.29, 0.86, 0.62
    objs = []
    hinge = Vector((0.0, -R, legh + R))
    tub = _half_drum("batea", R, Lg, legh + R, upper=False)
    give(tub, black)
    paint(tub, lambda c: 0.75 + 0.25 * math.sin(c.x * 30.0 + c.y * 20.0) ** 2) # óxido y hollín
    objs.append(tub)
    # Aros del tambor.
    for x in (-Lg / 2 + 0.18, Lg / 2 - 0.18):
        hoop = tube("aro", [(x, R * 1.01 * math.cos(math.pi + math.pi * i / 20), legh + R + R * 1.01 * math.sin(math.pi + math.pi * i / 20)) for i in range(21)], [0.008] * 21, sides=8)
        give(hoop, black)
        objs.append(hoop)
    # Tapa: la otra mitad del tambor, abierta 110 grados sobre la bisagra de atrás, con su chimenea.
    open_m = Matrix.Translation(hinge) @ Matrix.Rotation(math.radians(110.0), 4, "X") @ Matrix.Translation(-hinge)
    lid = _half_drum("tapa", R, Lg, legh + R, upper=True)
    give(lid, black)
    paint(lid, lambda c: 0.75 + 0.25 * math.sin(c.x * 30.0 + c.z * 20.0) ** 2)
    lid.matrix_world = open_m
    objs.append(lid)
    knob = tube("manija_tapa", [tuple(open_m @ Vector((-0.12, R * 0.45, legh + R + R * 0.95))), tuple(open_m @ Vector((0.12, R * 0.45, legh + R + R * 0.95)))], [0.012, 0.012], sides=10)
    give(knob, mat("madera_manija", "#8A5A34", rough=0.6))
    objs.append(knob)
    chim = tube("chimenea", [tuple(open_m @ Vector((0.28, 0.0, legh + 2.0 * R - 0.01))), tuple(open_m @ Vector((0.28, 0.0, legh + 2.0 * R + 0.22)))], [0.04, 0.04], sides=16)
    give(chim, black)
    objs.append(chim)
    # Patas en tijera y travesaños.
    for x in (-Lg / 2 + 0.12, Lg / 2 - 0.12):
        for sgn in (-1, 1):
            leg = tube("pata", [(x, sgn * 0.30, 0.0), (x, sgn * 0.10, legh + 0.06)], [0.012, 0.012], sides=8)
            give(leg, steel)
            objs.append(leg)
        bar = tube("travesano", [(x, -0.21, 0.25), (x, 0.21, 0.25)], [0.008, 0.008], sides=8)
        give(bar, steel)
        objs.append(bar)
    # Parrilla: varillas a lo largo del tambor, a la altura del corte.
    gz = legh + R - 0.05
    for i in range(13):
        y = -R * 0.85 + i * (R * 1.7 / 12)
        rod = tube("varilla", [(-Lg / 2 + 0.03, y, gz), (Lg / 2 - 0.03, y, gz)], [0.0035, 0.0035], sides=6)
        give(rod, steel)
        objs.append(rod)
    # Brasas: carbones redondeados encendidos.
    ember = mat("brasa", (0.9, 0.25, 0.05), rough=0.9, emission=(1.0, 0.35, 0.05))
    coal = mat("carbon", "#1E1B19", rough=0.95)
    for i in range(40):
        x = random.uniform(-Lg / 2 + 0.08, Lg / 2 - 0.08)
        y = random.uniform(-R * 0.55, R * 0.55)
        z = legh + R - R * math.sqrt(max(0.0, 1.0 - (y / R) ** 2)) + 0.03 + random.uniform(0.0, 0.03)
        c = lib.sphere("carbon", random.uniform(0.022, 0.034), (x, y, z), 8, 6, (1.0, random.uniform(0.7, 1.2), 0.7))
        give(c, ember if random.random() < 0.45 else coal)
        objs.append(c)
    # Chorizos sobre la parrilla, con las marcas de la parrilla.
    chori = tinted("chorizo", "#9A3B22", rough=0.45)
    for i in range(5):
        y = -0.16 + i * 0.08
        x0 = -0.28 + random.uniform(-0.02, 0.02)
        pts = [(x0 + 0.56 * t / 6, y + 0.012 * math.sin(t * 0.9), gz + 0.020) for t in range(7)]
        ch = tube("chorizo", pts, [0.012, 0.017, 0.018, 0.018, 0.018, 0.017, 0.012], sides=12)
        lib.subsurf(ch, 1)
        give(ch, chori)
        paint(ch, lambda c: 0.65 + 0.35 * (0.5 + 0.5 * math.cos(c.y * 260.0)))
        objs.append(ch)
    return objs


def conservadora():
    # Conservadora de telgopor forrada: cuerpo azul, tapa blanca con manija y traba.
    blue = tinted("conserv_azul", "#2F69A8", rough=0.5)
    white = mat("conserv_blanco", "#EDEFF0", rough=0.45)
    W, D, H = 0.50, 0.32, 0.32
    body = extrude_outline("cuerpo", rounded_rect(W, D, 0.03, 4), 0.0, H)
    lib.bevel(body, 0.006, 2, 40.0)
    give(body, blue)
    paint(body, lambda c: 0.85 + 0.15 * min(1.0, c.z / 0.15))
    lid = extrude_outline("tapa", rounded_rect(W + 0.01, D + 0.01, 0.034, 4), H, H + 0.05)
    lib.bevel(lid, 0.008, 2, 40.0)
    give(lid, white)
    handle = tube("manija", [(-0.13, 0.0, H + 0.05), (-0.11, 0.0, H + 0.09), (0.11, 0.0, H + 0.09), (0.13, 0.0, H + 0.05)], [0.012] * 4, sides=10)
    lib.subsurf(handle, 1)
    give(handle, white)
    latch = rbox("traba", (0.06, 0.012, 0.05), (0.0, -D / 2 - 0.004, H - 0.01), 0.003)
    give(latch, white)
    stripe = rbox("franja", (W + 0.004, D + 0.004, 0.025), (0.0, 0.0, 0.07), 0.004)
    give(stripe, white)
    return [body, lid, handle, latch, stripe]


BUILD = {"mate": mate, "termo": termo, "yerba": yerba_pack, "pelota": pelota, "alpargatas": alpargatas,
         "sifon": sifon, "garrafa": garrafa, "cajon": cajon, "chulengo": chulengo, "conservadora": conservadora}
parts = BUILD[which]()
lib.finish(parts, "prop_" + which, A, angle=40.0)
