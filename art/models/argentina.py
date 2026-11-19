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
    """Material cuyo color base se multiplica por el atributo de vértice "tint" (manchas, vetas y la
    oclusión horneada). Godot lo importa como color de vértice en el albedo."""
    c = hx(color) if isinstance(color, str) else color
    m = lib.material(name, c, rough=rough, metal=metal, emission=emission, alpha=alpha)
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "tint"
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    # El nodo Mix tiene entradas "A"/"B" para número, vector y color: hay que usar las de color.
    a_in = [i for i in mix.inputs if i.name == "A" and i.type == "RGBA"][0]
    b_in = [i for i in mix.inputs if i.name == "B" and i.type == "RGBA"][0]
    out = [o for o in mix.outputs if o.name == "Result" and o.type == "RGBA"][0]
    mix.inputs[0].default_value = 1.0
    a_in.default_value = (c[0], c[1], c[2], 1.0)
    nt.links.new(attr.outputs["Color"], b_in)
    nt.links.new(out, bsdf.inputs["Base Color"])
    return m


def tinted(name, color, rough=0.5):
    return mat(name, color, rough=rough)


def paint_rgb(o, fn):
    """Color de vértice completo: fn(posición) -> (r, g, b) en 0..1 (con material blanco, es el color)."""
    me = o.data
    attr = me.color_attributes.get("tint") or me.color_attributes.new("tint", "BYTE_COLOR", "CORNER")
    for loop in me.loops:
        r, g, b = fn(me.vertices[loop.vertex_index].co)
        attr.data[loop.index].color = (r, g, b, 1.0)
    return o


def noise3(p, f=1.0):
    """Ruido barato y determinista (suma de senos) en -1..1."""
    x, y, z = p.x * f, p.y * f, p.z * f
    return (math.sin(x * 1.7 + y * 3.1) * math.sin(y * 2.3 + z * 1.3) + math.sin(z * 2.9 + x * 0.7) * 0.5) / 1.5


def bake_ao(obj, samples=14, reach=0.3, strength=0.55):
    """Oclusión ambiental horneada en el atributo "tint" (como la mano): rayos en el hemisferio de cada
    vértice contra la propia malla y contra el piso (z = 0)."""
    from mathutils.bvhtree import BVHTree
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bvh = BVHTree.FromBMesh(bm)
    size = max(obj.dimensions) if max(obj.dimensions) > 0 else 1.0
    maxd = size * reach
    golden = math.pi * (3.0 - math.sqrt(5.0))
    dirs = []
    for i in range(samples):
        zc = (i + 0.5) / samples
        r = math.sqrt(1.0 - zc * zc)
        a = golden * i
        dirs.append(Vector((r * math.cos(a), r * math.sin(a), zc)))
    ao = []
    for v in bm.verts:
        n = v.normal if v.normal.length > 0.0 else Vector((0, 0, 1))
        t = n.orthogonal().normalized()
        b = n.cross(t)
        occl = 0.0
        origin = v.co + n * (size * 0.002)
        for d in dirs:
            w = t * d.x + b * d.y + n * d.z
            hit = bvh.ray_cast(origin, w, maxd)
            if hit[0] is not None:
                occl += 1.0
            elif w.z < -0.05 and origin.z / -w.z < maxd:
                occl += 1.0 # el piso
        ao.append(1.0 - strength * occl / samples)
    bm.free()
    attr = me.color_attributes.get("tint") or me.color_attributes.new("tint", "BYTE_COLOR", "CORNER")
    for loop in me.loops:
        c = attr.data[loop.index].color
        k = ao[loop.vertex_index]
        attr.data[loop.index].color = (c[0] * k, c[1] * k, c[2] * k, 1.0)


def finish(parts, name, angle=40.0):
    """Une, aplica, suaviza, hornea la oclusión, exporta y renderiza (como lib.finish, más la oclusión)."""
    for p in parts:
        if p.data.color_attributes.get("tint") is None:
            lib.paint(p) # blanco: el material queda con su color
    for p in parts:
        lib.apply_modifiers(p)
    obj = lib.join(parts, name)
    lib.select_only(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    lib.triangulate(obj)
    lib.smooth(obj, angle)
    bake_ao(obj)
    lib.unwrap(obj)
    print("TRIS", lib.triangles(obj))
    if A["out"]:
        lib.export_glb(A["out"])
    if A["render"]:
        lib.render_set(A["render"], name)
    return obj


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
    # Calabaza con vetas y tono quemado, virola de alpaca angosta, montañita de yerba granulada y bombilla
    # inclinada ~30 grados con el pico aplanado y el filtro (la "cuchara") asomando en la yerba.
    leather = tinted("mate_calabaza", "#8A5530", rough=0.55)
    outer = [(0.0, 0.0), (0.013, 0.0), (0.019, 0.002), (0.028, 0.008), (0.035, 0.019), (0.0385, 0.033),
             (0.0375, 0.047), (0.0335, 0.059), (0.029, 0.067), (0.0272, 0.0715)]
    body = revolve("calabaza", outer, 64, cap_end=False)
    lib.subsurf(body, 1)
    give(body, leather)

    def calabaza(c):
        ang = math.atan2(c.y, c.x)
        veta = 0.5 + 0.5 * math.sin(ang * 13.0 + math.sin(c.z * 140.0) * 1.2 + noise3(c, 260.0) * 0.8)
        quemado = 0.55 + 0.45 * min(1.0, max(0.0, (c.z - 0.002) / 0.03)) # la base, más oscura
        cuello = 1.0 - 0.3 * max(0.0, (c.z - 0.058) / 0.014) # el borde de arriba quemado
        return (0.72 + 0.28 * veta) * quemado * cuello
    paint(body, calabaza)
    alpaca = mat("alpaca", "#D2D5D9", rough=0.28, metal=0.9)
    virola = revolve("virola", [(0.0265, 0.0705), (0.0290, 0.0705), (0.0294, 0.0730), (0.0287, 0.0748),
                                (0.0262, 0.0746), (0.0257, 0.0725)], 64, closed=True)
    lib.subsurf(virola, 1)
    give(virola, alpaca)
    # Yerba: montañita contra un costado, con el granulado (ruido fino de altura y motas de color).
    yerba = tinted("yerba", "#6E8A30", rough=0.95)
    bm = bmesh.new()
    rings = 12
    segs = 56
    center = bm.verts.new((0.0, 0.0, 0.0715))
    prev = None
    for r in range(1, rings + 1):
        rr = 0.0262 * r / rings
        ring = []
        for i in range(segs):
            a = 2.0 * math.pi * i / segs
            x, y = rr * math.cos(a), rr * math.sin(a)
            mound = 0.011 * max(0.0, 1.0 - ((x + 0.010) ** 2 + y ** 2) / 0.00032)
            grain = 0.0007 * math.sin(i * 2.7 + r * 3.1) * math.sin(i * 1.3 - r * 2.2)
            ring.append(bm.verts.new((x, y, 0.0705 + mound + grain)))
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
    paint(yo, lambda c: 0.62 + 0.38 * (0.5 + 0.5 * math.sin(c.x * 2300.0) * math.sin(c.y * 2100.0 + c.z * 900.0)))
    objs = [body, virola, yo]
    random.seed(11)
    for k in range(46): # granos sueltos de yerba sobre la montañita
        a = random.uniform(0.0, 2.0 * math.pi)
        rr = random.uniform(0.0, 0.022)
        x, y = rr * math.cos(a) - 0.004, rr * math.sin(a)
        z = 0.0705 + 0.011 * max(0.0, 1.0 - ((x + 0.010) ** 2 + y ** 2) / 0.00032) + 0.0006
        g = lib.sphere("grano", random.uniform(0.0007, 0.0012), (x, y, z), 6, 4, (1.4, 1.0, 0.6))
        give(g, yerba)
        tone = random.uniform(0.55, 1.15)
        paint(g, lambda c, t=tone: t)
        objs.append(g)
    # Bombilla: caño recto inclinado 30 grados, con la boca doblada y aplanada al final.
    tilt = math.radians(30.0)
    base = Vector((-0.006, 0.0, 0.069))
    up = Vector((math.sin(tilt), 0.0, math.cos(tilt)))
    top = base + up * 0.105
    mouth_dir = Vector((math.sin(math.radians(62.0)), 0.0, math.cos(math.radians(62.0))))
    pts = [base + up * (0.105 * i / 10.0) for i in range(11)]
    bomb = tube("bombilla", [tuple(p) for p in pts], [0.0027] * 11, sides=16)
    give(bomb, alpaca)
    bend = [top + mouth_dir * (0.004 * i) for i in range(5)]
    tip = tube("pico", [tuple(p) for p in bend], [0.0027, 0.0028, 0.003, 0.0031, 0.0031], sides=16, squash=0.42)
    give(tip, alpaca)
    ring = tube("anillo", [tuple(base + up * 0.083), tuple(base + up * 0.089)], [0.0038, 0.0038], sides=18)
    give(ring, mat("bronce", "#C89B4A", rough=0.3, metal=0.9))
    filt = lib.sphere("filtro", 0.0062, tuple(base + Vector((0.0, 0.0, 0.0005))), 16, 8, (1.25, 0.9, 0.55)) # la cuchara, asomando
    give(filt, alpaca)
    return objs + [bomb, tip, ring, filt]


def termo():
    # Termo de acero pintado de rojo, con el pico cebador arriba (boca con tapón vertedor: lo que lo hace
    # argentino), asa de goma negra y la tapa-vaso apoyada al lado, boca abajo. Sin marca ni color de marca.
    red = tinted("termo_rojo", "#B5302A", rough=0.42)
    steel = mat("termo_acero", "#BFC4C9", rough=0.26, metal=0.9)
    dark = mat("termo_negro", "#232428", rough=0.6)
    body = revolve("cuerpo", [(0.0, 0.012), (0.040, 0.012), (0.0428, 0.017), (0.0435, 0.030), (0.0435, 0.212),
                              (0.0420, 0.226), (0.034, 0.240), (0.0, 0.240)], 64)
    lib.subsurf(body, 1)
    give(body, red)
    paint(body, lambda c: 0.86 + 0.14 * (0.5 + 0.5 * math.cos(c.z * 50.0)) * (0.8 + 0.2 * noise3(c, 300.0)))
    base = revolve("base", [(0.0, 0.0), (0.039, 0.0), (0.0445, 0.004), (0.0450, 0.016), (0.0420, 0.019), (0.0, 0.019)], 64)
    lib.subsurf(base, 1)
    give(base, steel)
    shoulder = revolve("hombro", [(0.0, 0.236), (0.035, 0.236), (0.026, 0.250), (0.022, 0.255), (0.0, 0.255)], 48)
    lib.subsurf(shoulder, 1)
    give(shoulder, steel)
    # Pico cebador: cuerpo negro con la boquita que sale de costado y el tapón vertedor arriba.
    cebador = revolve("cebador", [(0.0, 0.253), (0.0215, 0.253), (0.0225, 0.262), (0.0205, 0.282), (0.017, 0.287), (0.0, 0.288)], 40)
    lib.subsurf(cebador, 1)
    give(cebador, dark)
    spout = tube("boquita", [(0.012, 0.0, 0.276), (0.024, 0.0, 0.281), (0.031, 0.0, 0.286)], [0.0055, 0.0048, 0.0042], sides=14)
    lib.subsurf(spout, 1)
    give(spout, dark)
    plug = revolve("tapon", [(0.0, 0.287), (0.012, 0.287), (0.013, 0.292), (0.010, 0.297), (0.0, 0.298)], 28)
    give(plug, mat("tapon", "#3A3B40", rough=0.5))
    lever = rbox("gatillo", (0.020, 0.008, 0.004), (0.006, 0.0, 0.299), 0.0015)
    give(lever, dark)
    # Asa de goma negra con sus anclajes.
    hp = [(-0.043, 0.0, 0.200), (-0.061, 0.0, 0.194), (-0.072, 0.0, 0.172), (-0.075, 0.0, 0.135), (-0.072, 0.0, 0.098), (-0.061, 0.0, 0.074), (-0.043, 0.0, 0.068)]
    handle = tube("asa", hp, [0.0075] * len(hp), sides=16)
    lib.subsurf(handle, 1)
    give(handle, dark)
    anchors = []
    for z in (0.200, 0.068):
        a = revolve("anclaje", [(0.0, -0.005), (0.009, -0.005), (0.009, 0.005), (0.0, 0.005)], 20)
        a.rotation_euler = (0.0, math.radians(90.0), 0.0)
        a.location = (-0.042, 0.0, z)
        give(a, steel)
        anchors.append(a)
    # Tapa-vaso boca abajo, al lado.
    cup = revolve("vaso", [(0.0, 0.0), (0.036, 0.0), (0.0385, 0.004), (0.0395, 0.040), (0.0375, 0.046), (0.0, 0.046)], 56)
    lib.subsurf(cup, 1)
    cup.location = (0.085, 0.020, 0.0)
    give(cup, steel)
    grip = revolve("goma_vaso", [(0.0398, 0.012), (0.0408, 0.014), (0.0408, 0.030), (0.0398, 0.032), (0.0392, 0.022)], 56, closed=True)
    grip.location = cup.location
    give(grip, dark)
    return [body, base, shoulder, cebador, spout, plug, lever, handle, cup, grip] + anchors


def yerba_pack():
    # Paquete blando de yerba de papel (no una caja): más ancho que profundo, los costados abombados y
    # arrugados, el borde de arriba doblado y pegado; etiqueta crema con dos hojas verdes (sin texto ni
    # marca) y un montoncito de yerba volcada al lado.
    kraft = tinted("papel_yerba", "#D2AE72", rough=0.85)
    w, d, h = 0.120, 0.070, 0.165
    bm = bmesh.new()
    nx, ny, nz = 10, 6, 12
    verts = {}

    def bulge(u, v):  # el papel se infla en el medio de cada cara
        return 1.0 + 0.10 * math.sin(math.pi * u) * math.sin(math.pi * v)
    pts = []
    for k in range(nz + 1):
        z = h * k / nz
        ring = []
        for i in range(nx):
            ring.append((-w / 2 + w * i / nx, -d / 2))
        for j in range(ny):
            ring.append((w / 2, -d / 2 + d * j / ny))
        for i in range(nx):
            ring.append((w / 2 - w * i / nx, d / 2))
        for j in range(ny):
            ring.append((-w / 2, d / 2 - d * j / ny))
        vz = k / nz
        row = []
        for (x, y) in ring:
            ux = (x + w / 2) / w
            uy = (y + d / 2) / d
            bx = x * (1.0 + 0.05 * math.sin(math.pi * vz) * math.sin(math.pi * uy))
            by = y * bulge(ux, vz)
            wrinkle = 0.0012 * math.sin(x * 260.0 + z * 190.0) * math.sin(z * 150.0 - y * 80.0)
            row.append(bm.verts.new((bx + wrinkle, by + wrinkle * 0.6, z)))
        pts.append(row)
    m = len(pts[0])
    for k in range(nz):
        for i in range(m):
            a, b = pts[k][i], pts[k][(i + 1) % m]
            c, dd = pts[k + 1][(i + 1) % m], pts[k + 1][i]
            bm.faces.new((a, b, c, dd))
    bm.faces.new(list(reversed(pts[0])))
    bm.faces.new(pts[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("paquete")
    bm.to_mesh(me)
    bm.free()
    bag = bpy.data.objects.new("paquete", me)
    bpy.context.scene.collection.objects.link(bag)
    lib.subsurf(bag, 1)
    give(bag, kraft)
    paint(bag, lambda c: 0.80 + 0.20 * (0.5 + 0.5 * math.sin(c.z * 230.0 + c.x * 120.0)))
    # El cierre: el borde de arriba plegado dos veces y pegado (una lengüeta chata y ancha).
    fold = rbox("doblez", (w * 0.96, d * 0.55, 0.016), (0.0, 0.0, h + 0.006), 0.004)
    give(fold, kraft)
    paint(fold, lambda c: 0.72)
    fold2 = rbox("pliegue", (w * 0.94, 0.006, 0.026), (0.0, -d * 0.30, h - 0.004), 0.002, (math.radians(-18.0), 0.0, 0.0))
    give(fold2, kraft)
    # Etiqueta crema con dos hojas de yerba mate verdes.
    label = rbox("etiqueta", (w * 0.62, 0.003, 0.070), (0.0, -d / 2 * 1.10 - 0.001, 0.080), 0.0015)
    give(label, mat("etiqueta", "#EFE6CC", rough=0.6))
    leaf_m = mat("hoja_dibujo", "#3F7F35", rough=0.6)
    leaves = []
    for (lx, lz, rot) in ((-0.012, 0.084, 35.0), (0.012, 0.080, -35.0)):
        leaf = lib.sphere("hoja", 1.0, (lx, -d / 2 * 1.10 - 0.004, lz), 14, 8, (0.012, 0.0016, 0.024))
        leaf.rotation_euler = (0.0, math.radians(rot), 0.0)
        give(leaf, leaf_m)
        leaves.append(leaf)
    band = rbox("franja", (w * 0.62, 0.0032, 0.010), (0.0, -d / 2 * 1.10 - 0.0012, 0.050), 0.001)
    give(band, leaf_m)
    # Montoncito de yerba volcada al lado, con granos.
    yerba = tinted("yerba_suelta", "#6A8730", rough=0.95)
    pile = lib.sphere("montoncito", 1.0, (w / 2 + 0.035, -0.010, 0.0), 24, 10, (0.030, 0.024, 0.011))
    give(pile, yerba)
    paint(pile, lambda c: 0.65 + 0.35 * (0.5 + 0.5 * math.sin(c.x * 2400.0) * math.sin(c.y * 2100.0)))
    objs = [bag, fold, fold2, label, band, pile] + leaves
    random.seed(21)
    for k in range(30):
        a = random.uniform(0.0, 2.0 * math.pi)
        r = random.uniform(0.0, 0.034)
        g = lib.sphere("grano", random.uniform(0.0008, 0.0014), (w / 2 + 0.035 + r * math.cos(a), -0.010 + r * math.sin(a) * 0.8, 0.0008), 6, 4, (1.4, 1.0, 0.6))
        give(g, yerba)
        tone = random.uniform(0.55, 1.1)
        paint(g, lambda c, t=tone: t)
        objs.append(g)
    return objs


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


def _foot(t, W):
    """Medio ancho del pie (t = 0 talón, 1 punta)."""
    w = W / 2 * (0.70 + 0.30 * math.sin(math.pi * min(1.0, t * 1.2)) ** 0.6)
    if t > 0.82:
        k = (t - 0.82) / 0.18
        w *= math.sqrt(max(0.0, 1.0 - k * k)) * 0.9 + 0.1 * (1.0 - k)
    return w


def _alpargata(dx, dy, yaw):
    # Suela de yute trenzado (la cuerda que da la vuelta, con la trenza pintada), capellada de lona negra
    # cerrada adelante y abierta atrás, y la puntera de goma. Se lee como zapatilla de tela, no como mano.
    jute = tinted("yute", "#D4B47C", rough=0.95)
    canvas = tinted("lona", "#1F2B47", rough=0.85) # azul marino
    thread = mat("hilo", "#EDE6D2", rough=0.7)
    L, W, T = 0.255, 0.094, 0.024
    n = 36
    outline = [(-L / 2 + L * i / n, _foot(i / n, W) * (0.35 if i in (0, n) else 1.0)) for i in range(n + 1)]
    outline += [(-L / 2 + L * i / n, -_foot(i / n, W)) for i in range(n - 1, 0, -1)]
    sole = extrude_outline("suela", outline, 0.0, T)
    lib.bevel(sole, 0.005, 2, 40.0)
    give(sole, jute)
    paint(sole, lambda c: 0.55 + 0.45 * (0.5 + 0.5 * math.sin(c.z * 1100.0 + abs(math.sin(c.x * 260.0)) * 4.0))) # espiga del yute
    # La cuerda trenzada alrededor, a media altura: rayas en diagonal que giran (trenza).
    # La trenza de yute: dos cordones que giran en espiral alrededor de la suela (relieve de soga).
    ring = [Vector((x * 1.0, y * 1.04, 0.0)) for (x, y) in outline]
    dense = []
    for i in range(len(ring)):
        p, q = ring[i], ring[(i + 1) % len(ring)]
        for k in range(4):
            dense.append(p.lerp(q, k / 4.0))
    dense.append(dense[0])
    strands = []
    for strand in range(2):
        pts = []
        for i, p in enumerate(dense):
            out = Vector((p.x, p.y, 0.0)).normalized()
            th = i * 0.55 + strand * math.pi
            off = out * math.cos(th) * T * 0.16 + Vector((0.0, 0.0, 1.0)) * math.sin(th) * T * 0.22
            pts.append(tuple(p + out * T * 0.10 + Vector((0.0, 0.0, T * 0.5)) + off))
        cord = tube("cordon", pts, [T * 0.2] * len(pts), sides=8)
        give(cord, jute)
        paint(cord, lambda c, k=strand: 0.82 if k == 0 else 0.66)
        strands.append(cord)
    rope = lib.join(strands, "trenza")
    # Capellada: arco de lona sobre el pie; adelante cerrado, atrás solo los costados (la boca).
    bm = bmesh.new()
    cols, rows = 30, 12
    grid = []
    for r in range(rows + 1):
        u = r / rows
        row = []
        for cidx in range(cols + 1):
            t = 0.05 + 0.93 * cidx / cols
            half = _foot(t, W) * 1.03
            hmax = 0.050 * (0.55 + 0.45 * math.sin(math.pi * min(1.0, (t - 0.05) / 0.75))) * (1.0 - 0.8 * max(0.0, (t - 0.8) / 0.2) ** 2)
            if t < 0.45: # el talón pisado: la lona baja casi plana hacia atrás (sin aletas paradas)
                hmax *= 0.12 + 0.88 * ((t - 0.05) / 0.40) ** 2
            ang = math.pi * u
            row.append(bm.verts.new((-L / 2 + L * t, half * math.cos(ang), T + hmax * math.sin(ang))))
        grid.append(row)
    for r in range(rows):
        for cidx in range(cols):
            t = 0.05 + 0.93 * (cidx + 0.5) / cols
            u = (r + 0.5) / rows
            if 0.16 < t < 0.46 and 0.30 < u < 0.70: # la boca del pie
                continue
            bm.faces.new((grid[r][cidx], grid[r][cidx + 1], grid[r + 1][cidx + 1], grid[r + 1][cidx]))
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
    paint(upper, lambda c: 0.84 + 0.16 * (0.5 + 0.5 * math.sin(c.x * 1800.0) * math.sin(c.y * 1800.0)))
    # Puntera de goma: un casquete apenas más grande sobre la punta.
    # Costura en zigzag donde la lona se une con la suela (hilo crudo).
    seam = []
    for i in range(0, 2 * n + 1):
        t = 0.05 + 0.93 * (i / (2.0 * n))
        side = 1.0 if i <= n else -1.0
        tt = t if side > 0 else 0.05 + 0.93 * ((2 * n - i) / (2.0 * n))
        zz = T + 0.0015 + (0.0028 if i % 2 == 0 else 0.0)
        seam.append((-L / 2 + L * tt, side * (_foot(tt, W) * 1.03 + 0.0035), zz)) # por fuera de la lona
    toe = tube("costura", seam, [0.0011] * len(seam), sides=5)
    give(toe, thread)
    insole = extrude_outline("plantilla", [(x * 0.92, y * 0.88) for (x, y) in outline], T - 0.001, T + 0.0015)
    give(insole, mat("plantilla", "#B99A68", rough=0.9))
    objs = [sole, rope, upper, toe, insole]
    for o in objs:
        o.location.x += dx
        o.location.y += dy
        o.rotation_euler.z += math.radians(yaw)
    return objs


def alpargatas():
    # El par, apoyado en el piso uno al lado del otro (una un poco adelantada).
    return _alpargata(0.0, 0.058, 4.0) + _alpargata(0.022, -0.058, -3.0)


def sifon():
    # Sifón de soda clásico: botella alta de vidrio verde botella tallado en rombos (facetas hundidas que
    # agarran la luz), cabezal de metal grande que abraza el cuello (pollera), cuerpo cilíndrico, palanca
    # larga arriba que baja hacia adelante, pico que sale hacia adelante y abajo, y el tubo adentro.
    glass = mat("vidrio_verde", (0.05, 0.30, 0.30), rough=0.05, alpha=0.8)
    metal = mat("cromo", "#D3D7DC", rough=0.18, metal=0.95)
    segs, rows = 12, 16
    bm = bmesh.new()
    ring_verts = []
    for k in range(rows + 1):
        z = 0.008 + 0.185 * k / rows
        off = (math.pi / segs) * (k % 2) # filas corridas medio paso: rombos
        r = 0.047 if k % 2 == 0 else 0.0425 # vértices hundidos en las filas impares: estrías talladas
        if k == 0 or k == rows:
            r = 0.038
        ring_verts.append([bm.verts.new((r * math.cos(off + 2 * math.pi * i / segs), r * math.sin(off + 2 * math.pi * i / segs), z)) for i in range(segs)])
    for k in range(rows):
        a, b = ring_verts[k], ring_verts[k + 1]
        for i in range(segs):
            j = (i + 1) % segs
            if k % 2 == 0:
                bm.faces.new((a[i], a[j], b[i]))
                bm.faces.new((a[j], b[j], b[i]))
            else:
                bm.faces.new((a[i], a[j], b[j]))
                bm.faces.new((a[i], b[j], b[i]))
    bot = bm.verts.new((0.0, 0.0, 0.0))
    for i in range(segs):
        bm.faces.new((bot, ring_verts[0][(i + 1) % segs], ring_verts[0][i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("botella")
    bm.to_mesh(me)
    bm.free()
    bottle = bpy.data.objects.new("botella", me)
    bpy.context.scene.collection.objects.link(bottle)
    give(bottle, glass)
    paint(bottle, lambda c: 0.75 + 0.25 * (0.5 + 0.5 * math.sin(math.atan2(c.y, c.x) * 12.0 + c.z * 150.0)))
    neck = revolve("cuello", [(0.044, 0.193), (0.034, 0.210), (0.022, 0.222), (0.0, 0.222)], 24)
    give(neck, glass)
    straw = revolve("tubo", [(0.0, 0.008), (0.0035, 0.008), (0.0035, 0.240), (0.0, 0.240)], 12)
    give(straw, mat("tubo", "#EEF2F3", rough=0.3))
    # Cabezal de campana: pollera ancha que abraza el cuello, cuerpo que se angosta y corona arriba.
    skirt = revolve("pollera", [(0.0, 0.200), (0.046, 0.200), (0.048, 0.208), (0.040, 0.226), (0.029, 0.240), (0.0, 0.241)], 40)
    lib.subsurf(skirt, 1)
    give(skirt, metal)
    head = revolve("cabezal", [(0.0, 0.238), (0.0255, 0.238), (0.0215, 0.272), (0.0235, 0.286), (0.0185, 0.294), (0.0, 0.295)], 40)
    lib.subsurf(head, 1)
    give(head, metal)
    # Pico recto y grueso que sale de adelante en diagonal hacia abajo (45 grados).
    spout = tube("pico", [(0.012, 0.0, 0.266), (0.032, 0.0, 0.256), (0.050, 0.0, 0.240), (0.058, 0.0, 0.232)],
                 [0.0082, 0.0076, 0.007, 0.0066], sides=16)
    give(spout, metal)
    nozzle = tube("boquilla", [(0.056, 0.0, 0.234), (0.062, 0.0, 0.228)], [0.0076, 0.0076], sides=16)
    give(nozzle, metal)
    # Palanca chata arriba: nace atrás en la bisagra, va casi horizontal y sobresale por delante del pico.
    lever = tube("palanca", [(-0.024, 0.0, 0.298), (0.010, 0.0, 0.300), (0.040, 0.0, 0.286), (0.068, 0.0, 0.262)],
                 [0.0058, 0.0078, 0.0074, 0.0064], sides=12, squash=0.38) # paralela al pico
    lib.subsurf(lever, 1)
    give(lever, metal)
    hinge = revolve("bisagra", [(0.0, -0.011), (0.0065, -0.011), (0.0065, 0.011), (0.0, 0.011)], 14)
    hinge.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    hinge.location = (-0.020, 0.0, 0.295)
    give(hinge, metal)
    spout = lib.join([spout, nozzle], "pico")
    # La malla de alambre de los sifones de antes: hilos en diagonal cruzados alrededor del vidrio.
    wire = mat("malla", "#AEB4BA", rough=0.35, metal=0.85)
    strands = []
    turns = 1.15
    for k in range(10):
        for sgn in (-1.0, 1.0):
            pts = []
            for i in range(25):
                t = i / 24.0
                a0 = 2.0 * math.pi * (k / 10.0 + sgn * turns * t * 0.5)
                z = 0.02 + 0.165 * t
                pts.append((0.0478 * math.cos(a0), 0.0478 * math.sin(a0), z))
            w = tube("hilo", pts, [0.0011] * len(pts), sides=5)
            give(w, wire)
            strands.append(w)
    for z in (0.020, 0.186): # aros de arriba y abajo que sujetan la malla
        ring = revolve("aro_malla", [(0.0472, z - 0.003), (0.0494, z - 0.003), (0.0494, z + 0.003), (0.0472, z + 0.003)], 32, closed=True)
        give(ring, wire)
        strands.append(ring)
    mesh_obj = lib.join(strands, "malla")
    fizz = mat("burbujitas", (0.85, 0.95, 0.95), rough=0.1, alpha=0.75) # la soda: burbujitas adentro
    random.seed(9)
    bubbles = []
    for k in range(26):
        a = random.uniform(0.0, 2.0 * math.pi)
        r = random.uniform(0.008, 0.034)
        b = lib.sphere("burbujita", random.uniform(0.0018, 0.0032), (r * math.cos(a), r * math.sin(a), random.uniform(0.03, 0.18)), 8, 5)
        give(b, fizz)
        bubbles.append(b)
    strands_b = lib.join(bubbles, "burbujitas")
    return [bottle, neck, straw, skirt, head, spout, lever, hinge, mesh_obj, strands_b]


def garrafa():
    # Garrafa de 10 kg: cuerpo con dos casquetes, zócalo, cuello con válvula y el aro protector con manijas.
    red = tinted("garrafa_pintura", "#3E6F8E", rough=0.45) # azul acero genérico
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
    # Chulengo: medio tambor de 200 l con pintura negra gastada y óxido, tapa abierta con chimenea y manija,
    # parrilla con chorizos y morcillas grandes (para que se lean de lejos), brasas que brillan (en Godot
    # laten) y la pinza apoyada al costado.
    white = mat("chulengo_chapa", (1.0, 1.0, 1.0), rough=0.8)
    steel = mat("parrilla", "#5A5E64", rough=0.45, metal=0.7)
    R, Lg, legh = 0.29, 0.86, 0.62
    objs = []

    def chapa(c):
        rust = max(0.0, noise3(c, 31.0) * 0.7 + noise3(c, 77.0) * 0.5 - 0.35) # manchas chicas de óxido
        worn = 0.5 + 0.5 * noise3(c, 120.0)
        base = (0.11 + 0.04 * worn, 0.105 + 0.035 * worn, 0.10 + 0.03 * worn)
        r = min(1.0, rust * 1.6)
        return (base[0] * (1 - r) + 0.46 * r, base[1] * (1 - r) + 0.21 * r, base[2] * (1 - r) + 0.08 * r)
    hinge = Vector((0.0, -R, legh + R))
    tub = _half_drum("batea", R, Lg, legh + R, upper=False)
    give(tub, white)
    paint_rgb(tub, chapa)
    objs.append(tub)
    for x in (-Lg / 2 + 0.18, Lg / 2 - 0.18):
        hoop = tube("aro", [(x, R * 1.01 * math.cos(math.pi + math.pi * i / 20), legh + R + R * 1.01 * math.sin(math.pi + math.pi * i / 20)) for i in range(21)], [0.008] * 21, sides=8)
        give(hoop, white)
        paint_rgb(hoop, chapa)
        objs.append(hoop)
    open_m = Matrix.Translation(hinge) @ Matrix.Rotation(math.radians(110.0), 4, "X") @ Matrix.Translation(-hinge)
    lid = _half_drum("tapa", R, Lg, legh + R, upper=True)
    give(lid, white)
    paint_rgb(lid, chapa)
    lid.matrix_world = open_m
    objs.append(lid)
    knob = tube("manija_tapa", [tuple(open_m @ Vector((-0.12, R * 0.45, legh + R + R * 0.95))), tuple(open_m @ Vector((0.12, R * 0.45, legh + R + R * 0.95)))], [0.013, 0.013], sides=12)
    give(knob, mat("madera_manija", "#8A5A34", rough=0.6))
    objs.append(knob)
    chim = tube("chimenea", [tuple(open_m @ Vector((0.28, 0.0, legh + 2.0 * R - 0.01))), tuple(open_m @ Vector((0.28, 0.0, legh + 2.0 * R + 0.22)))], [0.04, 0.04], sides=16)
    give(chim, white)
    paint_rgb(chim, chapa)
    objs.append(chim)
    for x in (-Lg / 2 + 0.12, Lg / 2 - 0.12):
        for sgn in (-1, 1):
            leg = tube("pata", [(x, sgn * 0.30, 0.0), (x, sgn * 0.10, legh + 0.06)], [0.013, 0.013], sides=8)
            give(leg, steel)
            objs.append(leg)
        bar = tube("travesano", [(x, -0.21, 0.25), (x, 0.21, 0.25)], [0.009, 0.009], sides=8)
        give(bar, steel)
        objs.append(bar)
    gz = legh + R - 0.05
    for i in range(11):
        y = -R * 0.85 + i * (R * 1.7 / 10)
        rod = tube("varilla", [(-Lg / 2 + 0.03, y, gz), (Lg / 2 - 0.03, y, gz)], [0.004, 0.004], sides=6)
        give(rod, steel)
        objs.append(rod)
    # Brasas: carbones con emisión naranja, a la vista en la mitad de atrás y entre la carne.
    ember = mat("brasa", (0.95, 0.30, 0.05), rough=0.9, emission=(1.0, 0.38, 0.06))
    coal = mat("carbon", "#1E1B19", rough=0.95)
    random.seed(5)
    for i in range(70):
        x = random.uniform(-Lg / 2 + 0.06, Lg / 2 - 0.06)
        y = random.uniform(-R * 0.6, R * 0.6)
        z = gz - 0.035 + random.uniform(-0.01, 0.012)
        cobj = lib.sphere("carbon", random.uniform(0.020, 0.032), (x, y, z), 8, 6, (1.0, random.uniform(0.7, 1.2), 0.7))
        give(cobj, ember if random.random() < 0.55 else coal)
        objs.append(cobj)
    # Chorizos y morcillas en la mitad de adelante de la parrilla, en diagonal, gordos y con marcas.
    chori = tinted("chorizo", "#B8432A", rough=0.4) # rojo ladrillo
    morci = tinted("morcilla", "#241010", rough=0.45) # casi negro
    rows = [(-0.32, 0.17, chori, 0.030), (-0.32, 0.07, chori, 0.030), (-0.32, -0.04, morci, 0.036),
            (0.06, 0.17, morci, 0.036), (0.06, 0.07, chori, 0.030), (0.06, -0.04, chori, 0.030)]
    for (x0, y, mt, r) in rows:
        pts = [(x0 + 0.24 * t / 6, y + 0.012 * math.sin(t * 1.1), gz + r * 0.9) for t in range(7)]
        ch = tube("embutido", pts, [r * 0.55, r * 0.9, r, r, r, r * 0.9, r * 0.55], sides=14)
        lib.subsurf(ch, 1)
        give(ch, mt)
        paint(ch, lambda c: 0.6 + 0.4 * (0.5 + 0.5 * math.cos(c.y * 0.0 + c.x * 300.0))) # marcas de la parrilla
        objs.append(ch)
    # Pinza apoyada contra el costado.
    for dy in (-0.012, 0.012):
        arm = tube("pinza", [(Lg / 2 + 0.01, dy, legh + R + 0.02), (Lg / 2 + 0.05, dy * 2.5, legh + 0.25), (Lg / 2 + 0.07, dy * 3.2, legh - 0.05)], [0.006, 0.006, 0.006], sides=8)
        give(arm, steel)
        objs.append(arm)
    return objs


def conservadora():
    # Conservadora de telgopor forrada: cuerpo azul, tapa blanca con manija y traba.
    blue = tinted("conserv_cuerpo", "#2F8A78", rough=0.5) # verde agua genérico
    white = mat("conserv_tapa", "#EFE7D2", rough=0.45)
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
finish(parts, "prop_" + which, angle=15.0 if which == "sifon" else 40.0)
