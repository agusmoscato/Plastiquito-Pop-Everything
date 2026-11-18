"""Íconos pre-renderizados de herramientas y mejoras (256 px, fondo transparente, luz de estudio,
contorno oscuro con Freestyle y encuadre cerrado). Reemplazan a los íconos en vivo (SubViewport).

Uso (Blender sin interfaz):
  blender -b --factory-startup -P art/models/hand_mpfb.py -- --icon-poses art/icons_src   (manos posadas)
  blender -b --factory-startup -P art/icons.py -- --src art/icons_src --out assets/icons --sheet docs/screens/iconos.jpg

Escribe assets/icons/<id>.png y una hoja de contactos con cada ícono a 256 px y a 48 px (la prueba de
lectura: a 48 px tiene que reconocerse).
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from art import lib  # noqa: E402

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return ARGV[ARGV.index(name) + 1] if name in ARGV else default


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.abspath(arg("--src", os.path.join(ROOT, "art", "icons_src")))
OUT = os.path.abspath(arg("--out", os.path.join(ROOT, "assets", "icons")))
SHEET = arg("--sheet", None)
MODELS = os.path.join(ROOT, "assets", "models")
PX = 256
INK = (0.12, 0.10, 0.09)
GHOST_LINE = (0.16, 0.44, 0.66)
YELLOW = lib.hex_color("#F2C94C")
BUBBLE = (0.62, 0.82, 0.95)


# --- Escena --------------------------------------------------------------------------------------

def new_scene(line_color=INK):
    lib.reset()
    scene = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    scene.render.film_transparent = True
    scene.render.resolution_x = PX
    scene.render.resolution_y = PX
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    if hasattr(scene, "eevee"):
        scene.eevee.taa_render_samples = 32
    world = bpy.data.worlds.new("studio")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.85, 0.88, 0.92, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.55
    scene.world = world
    # Contorno: Freestyle (silueta, bordes y contorno exterior), grosor fijo en píxeles.
    scene.render.use_freestyle = True
    scene.render.line_thickness_mode = "ABSOLUTE"
    scene.render.line_thickness = 1.0
    vl = scene.view_layers[0]
    vl.use_freestyle = True
    fs = vl.freestyle_settings
    ls = fs.linesets[0] if len(fs.linesets) else fs.linesets.new("outline")
    ls.select_by_visibility = True
    ls.select_silhouette = True
    ls.select_border = True
    ls.select_external_contour = True
    ls.select_crease = False
    if ls.linestyle is None:
        ls.linestyle = bpy.data.linestyles.new("outline")
    ls.linestyle.color = line_color
    ls.linestyle.thickness = 4.0
    return scene


def sun(direction_from, energy, color=(1.0, 1.0, 1.0)):
    data = bpy.data.lights.new("sun", "SUN")
    data.energy = energy
    data.color = color
    data.angle = math.radians(8.0)
    o = bpy.data.objects.new("sun", data)
    o.rotation_euler = (-Vector(direction_from)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(o)


def mesh_points(objs, keep=None):
    pts = []
    for o in objs:
        if o.type != "MESH":
            continue
        for v in o.data.vertices:
            p = o.matrix_world @ v.co
            if keep is None or keep(p):
                pts.append(p)
    return pts


def frame(points, toward_camera, fill=0.86, roll_up=(0.0, 0.0, 1.0)):
    """Cámara ortográfica que mira desde `toward_camera` y encierra los puntos con margen; luces de
    estudio relativas a la cámara (principal arriba a la izquierda, relleno a la derecha, borde atrás)."""
    d = Vector(toward_camera).normalized()
    up_hint = Vector(roll_up)
    if abs(d.dot(up_hint.normalized())) > 0.97:
        up_hint = Vector((0.0, 1.0, 0.0))
    right = up_hint.cross(d).normalized()
    up = d.cross(right).normalized()
    rot = Matrix((right, up, d)).transposed()
    xs = [p.dot(right) for p in points]
    ys = [p.dot(up) for p in points]
    zs = [p.dot(d) for p in points]
    span = max(max(xs) - min(xs), max(ys) - min(ys), 0.01)
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = span / fill
    cam_data.clip_start = 0.001
    cam_data.clip_end = 100.0
    cam = bpy.data.objects.new("cam", cam_data)
    cam.location = right * (min(xs) + max(xs)) * 0.5 + up * (min(ys) + max(ys)) * 0.5 + d * (max(zs) + span * 2.0 + 0.05)
    cam.rotation_euler = rot.to_euler()
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    sun(d + up * 0.9 - right * 0.6, 3.2)
    sun(d + right * 0.9 - up * 0.2, 0.9, (0.92, 0.95, 1.0))
    sun(-d + up * 0.7, 2.6, (1.0, 0.97, 0.9))


def base_of(src):
    """(color base, usa color de vértice) de un material importado de glTF: el factor de color va
    solo, o multiplicado por el color de vértice (Mix), o directo desde el nodo Color Attribute."""
    if not src.use_nodes:
        return (0.8, 0.8, 0.8, 1.0), False, 1.0
    bsdf = next((n for n in src.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        return (0.8, 0.8, 0.8, 1.0), False, 1.0
    alpha = bsdf.inputs["Alpha"].default_value
    sock = bsdf.inputs["Base Color"]
    if not sock.is_linked:
        return tuple(sock.default_value), False, alpha
    node = sock.links[0].from_node
    if node.type == "VERTEX_COLOR":
        return (1.0, 1.0, 1.0, 1.0), True, alpha
    if node.type == "MIX":
        colors = [i for i in node.inputs if i.type == "RGBA" and not i.is_linked]
        factor = tuple(colors[0].default_value) if colors else (1.0, 1.0, 1.0, 1.0)
        return factor, True, alpha
    return (0.8, 0.8, 0.8, 1.0), False, alpha


def toon_material(src, vcol_layer=None):
    """Copia del material con el sombreado del juego (ToyStyle): difuso en tres bandas planas que
    multiplican el color base (o el color de vértice, en la mano). Sin brillos PBR."""
    m = bpy.data.materials.new(src.name + "_toon")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    diffuse = nt.nodes.new("ShaderNodeBsdfDiffuse")
    to_rgb = nt.nodes.new("ShaderNodeShaderToRGB")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (0.58, 0.58, 0.62, 1.0)
    ramp.color_ramp.elements[1].position = 0.22
    ramp.color_ramp.elements[1].color = (0.84, 0.84, 0.86, 1.0)
    top = ramp.color_ramp.elements.new(0.5)
    top.color = (1.0, 1.0, 1.0, 1.0)
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    emit = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(diffuse.outputs[0], to_rgb.inputs[0])
    nt.links.new(to_rgb.outputs["Color"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], mix.inputs["A"])
    base, _uses, alpha = base_of(src)
    if vcol_layer:
        vc = nt.nodes.new("ShaderNodeVertexColor")
        vc.layer_name = vcol_layer
        tint = nt.nodes.new("ShaderNodeMix")
        tint.data_type = "RGBA"
        tint.blend_type = "MULTIPLY"
        tint.inputs["Factor"].default_value = 1.0
        nt.links.new(vc.outputs["Color"], tint.inputs["A"])
        tint.inputs["B"].default_value = base
        nt.links.new(tint.outputs["Result"], mix.inputs["B"])
    else:
        mix.inputs["B"].default_value = base
    nt.links.new(mix.outputs["Result"], emit.inputs["Color"])
    nt.links.new(emit.outputs[0], out.inputs["Surface"])
    if alpha < 0.99:
        transp = nt.nodes.new("ShaderNodeBsdfTransparent")
        mixs = nt.nodes.new("ShaderNodeMixShader")
        mixs.inputs["Fac"].default_value = alpha
        nt.links.new(transp.outputs[0], mixs.inputs[1])
        nt.links.new(emit.outputs[0], mixs.inputs[2])
        nt.links.new(mixs.outputs[0], out.inputs["Surface"])
        if hasattr(m, "surface_render_method"):
            m.surface_render_method = "BLENDED"
    return m


def toonify_scene():
    cache = {}
    for o in bpy.context.scene.objects:
        if o.type != "MESH":
            continue
        layer = o.data.color_attributes[0].name if len(o.data.color_attributes) else None
        for slot in o.material_slots:
            src = slot.material
            if src is None or src.name.endswith("_toon"):
                continue
            _base, uses_v, _a = base_of(src)
            use_v = layer if (layer and uses_v) else None  # la mano: el color está en los vértices
            key = (src.name, use_v)
            if key not in cache:
                cache[key] = toon_material(src, use_v)
            slot.material = cache[key]


def shoot(name):
    toonify_scene()
    os.makedirs(OUT, exist_ok=True)
    bpy.context.scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("ICON", name)


# --- Piezas ---------------------------------------------------------------------------------------

def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    for o in list(new):
        if o.name.startswith("Icosphere"):  # forma de hueso que agrega el importador
            new.remove(o)
            bpy.data.objects.remove(o, do_unlink=True)
    return new


def group(objs, name):
    pivot = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(pivot)
    for o in objs:
        if o.parent is None:
            o.parent = pivot
    return pivot


def find(objs, name):
    for o in objs:
        if o.name.startswith(name):
            return o
    return None


def hand(pose):
    objs = import_glb(os.path.join(SRC, "hand_%s.glb" % pose))
    return objs, group(objs, "hand_" + pose)


def contact(objs, name):
    bpy.context.view_layer.update()
    e = find(objs, name)
    return e.matrix_world.translation.copy() if e else Vector()


def bubble(radius, loc, squash=1.0, mat=None):
    prof = [(radius * math.sin(math.pi * 0.5 * i / 8), radius * 0.78 * squash * math.cos(math.pi * 0.5 * i / 8)) for i in range(9)]
    prof = [(0.0, radius * 0.78 * squash)] + prof[1:]
    o = lib.revolve_profile("bubble", prof, 24)
    o.location = loc
    lib.smooth(o)
    o.data.materials.append(mat or lib.material("bubble", BUBBLE, rough=0.08, clearcoat=0.6))
    return o


def bubble_patch(center, radius, rings, squash_at=None):
    mat = lib.material("bubble", BUBBLE, rough=0.08, clearcoat=0.6)
    sheet_mat = lib.material("sheet", (0.80, 0.89, 0.95), rough=0.3)
    objs = []
    step = radius * 2.15
    for r in range(-rings, rings + 1):
        for c in range(-rings, rings + 1):
            x = c * step + (step * 0.5 if r % 2 else 0.0)
            y = r * step * 0.866
            if math.hypot(x, y) > (rings + 0.3) * step:
                continue
            p = Vector((center.x + x, center.y + y, center.z))
            sq = 0.35 if (squash_at is not None and (p.xy - squash_at.xy).length < step * 0.5) else 1.0
            objs.append(bubble(radius, p, sq, mat))
    sheet = lib.box("sheet", ((2 * rings + 2) * step, (2 * rings + 2) * step * 0.9, 0.0008), (center.x, center.y, center.z - 0.0004))
    sheet.data.materials.append(sheet_mat)
    objs.append(sheet)
    return objs


def ghost_material():
    m = lib.material("ghost", (0.30, 0.62, 0.90), rough=0.35)
    if hasattr(m, "surface_render_method"):
        m.surface_render_method = "BLENDED"
    return m


def cut_far(objs, center, radius):
    for o in objs:
        if o.type != "MESH":
            continue
        import bmesh
        bm = bmesh.new()
        bm.from_mesh(o.data)
        doomed = [v for v in bm.verts if ((o.matrix_world @ v.co) - center).length > radius]
        bmesh.ops.delete(bm, geom=doomed, context="VERTS")
        bm.to_mesh(o.data)
        bm.free()


def set_material(objs, mat):
    for o in objs:
        if o.type == "MESH":
            o.data.materials.clear()
            o.data.materials.append(mat)


# --- Íconos de herramienta ------------------------------------------------------------------------

def icon_finger():
    new_scene()
    objs, piv = hand("point")
    tip = contact(objs, "contact_point")
    piv.location = -tip
    piv.rotation_euler = (math.radians(-32.0), 0.0, 0.0)
    bpy.context.view_layer.update()
    tip = contact(objs, "contact_point")
    patch = bubble_patch(Vector((tip.x, tip.y, tip.z - 0.0045)), 0.0060, 2, squash_at=tip)
    pts = mesh_points(objs, lambda p: (p - tip).length < 0.075) + mesh_points(patch)
    frame(pts, (-1.0, 0.55, 0.65), fill=0.92)
    shoot("finger")


def icon_palm():
    new_scene()
    objs, piv = hand("palm")
    bpy.context.view_layer.update()
    ymax = max(p.y for p in mesh_points(objs))
    frame(mesh_points(objs, lambda p: p.y > ymax - 0.205), (0.0, -0.18, 1.0), fill=0.9, roll_up=(0.0, 1.0, 0.0))
    shoot("palm")


def tool_with_grip(model, hand_scale, palm_at, toward, name, reach=10.0):
    new_scene()
    tool = import_glb(os.path.join(MODELS, model + ".glb"))
    objs, piv = hand("grab")
    bpy.context.view_layer.update()
    c = contact(objs, "contact_palm")
    piv.scale = (hand_scale, hand_scale, hand_scale)
    piv.location = Vector(palm_at) - c * hand_scale
    bpy.context.view_layer.update()
    near = Vector(palm_at)
    frame(mesh_points(tool, lambda p: (p - near).length < reach) + mesh_points(objs, lambda p: p.y > -0.12 * hand_scale), toward, fill=0.9)
    shoot(name)


def icon_rolling_pin():
    # = ToolMeshes "rolling_pin": la mano (x1,25) con la palma en (0,222; 0,056) del palo (Godot x, y).
    tool_with_grip("pin", 1.25, (0.222, 0.0, 0.056), (0.35, -1.0, 0.9), "rolling_pin", reach=0.2)


def icon_iron():
    tool_with_grip("iron", 1.1, (0.0, 0.005, 0.158), (0.75, -1.0, 0.65), "iron")


def icon_model(model, toward, name, fill=0.9):
    new_scene()
    objs = import_glb(os.path.join(MODELS, model + ".glb"))
    frame(mesh_points(objs), toward, fill=fill)
    shoot(name)


def manito(scale=1.0, at=Vector(), yaw=0.0):
    objs, piv = hand("point")
    bpy.context.view_layer.update()
    tip = contact(objs, "contact_point")
    cut_far(objs, tip, 0.165)  # sin antebrazo, como las manitos del juego
    set_material(objs, ghost_material())
    piv.location = -tip
    pre = Matrix.Translation(at) @ Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Rotation(math.radians(-28.0), 4, "X") @ Matrix.Scale(scale, 4)
    piv.matrix_world = pre @ piv.matrix_world
    bpy.context.view_layer.update()
    return objs


def icon_hands():
    new_scene(GHOST_LINE)
    objs = manito()
    patch = bubble_patch(Vector((0.0, 0.0, -0.0045)), 0.0060, 2, squash_at=Vector())
    frame(mesh_points(objs) + mesh_points(patch), (-1.0, -0.35, 0.75), fill=0.9)
    shoot("hands")


def icon_bubble():
    new_scene()
    patch = bubble_patch(Vector(), 0.010, 1)
    big = bubble(0.016, Vector((0.0, 0.0, 0.0)))
    for o in patch:
        if o.name.startswith("bubble") and (o.location.xy.length < 0.005):
            bpy.data.objects.remove(o, do_unlink=True)
    patch = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    frame(mesh_points(patch + [big]), (0.0, -1.0, 1.1), fill=0.92)
    shoot("bubble")


# --- Íconos de mejora (uno por categoría) --------------------------------------------------------

def icon_up_size():
    new_scene()
    mat = lib.material("ruler", YELLOW, rough=0.55)
    ink = lib.material("ink", INK, rough=0.8)
    parts = [lib.box("ruler", (0.30, 0.055, 0.008), (0, 0, 0.004))]
    parts[0].data.materials.append(mat)
    for i in range(16):
        long_tick = i % 5 == 0
        t = lib.box("tick", (0.0035, 0.026 if long_tick else 0.014, 0.0012), (-0.135 + i * 0.018, 0.0275 - (0.013 if long_tick else 0.007), 0.0085))
        t.data.materials.append(ink)
        parts.append(t)
    piv = group(parts, "ruler")
    piv.rotation_euler = (0.0, 0.0, math.radians(32.0))
    bpy.context.view_layer.update()
    frame(mesh_points(parts), (0.0, -0.55, 1.0), fill=0.94)
    shoot("up_size")


def icon_up_force():
    new_scene()
    popped = bubble(0.03, Vector(), squash=0.32)
    ring = []
    for k in range(10):  # astillas del reventón alrededor
        a = math.radians(k * 36.0 + 8.0)
        r0, r1 = 0.040, 0.066 if k % 2 == 0 else 0.056
        p0 = Vector((math.cos(a) * r0, math.sin(a) * r0, 0.012))
        p1 = Vector((math.cos(a) * r1, math.sin(a) * r1, 0.030 if k % 2 == 0 else 0.022))
        s = lib.tube_along("spark", [tuple(p0), tuple(p1)], [0.0045, 0.0015], sides=6)
        s.data.materials.append(lib.material("spark", YELLOW, rough=0.4, emission=YELLOW))
        ring.append(s)
    frame(mesh_points([popped] + ring), (0.0, -0.8, 1.0), fill=0.92)
    shoot("up_force")


def icon_up_speed():
    new_scene()
    ball = bubble(0.024, Vector((0.05, 0.0, 0.0)))
    trail = []
    for k, (dz, r) in enumerate(((0.006, 0.0075), (0.020, 0.0060), (-0.008, 0.0055))):
        pts = [(0.030, 0.0, dz + 0.004), (-0.020, 0.0, dz + 0.004), (-0.075 + k * 0.012, 0.0, dz + 0.004)]
        t = lib.tube_along("streak", pts, [r, r * 0.6, 0.0008], sides=8)
        t.data.materials.append(lib.material("streak", (0.80, 0.92, 0.98), rough=0.4))
        trail.append(t)
    frame(mesh_points([ball] + trail), (0.0, -1.0, 0.55), fill=0.94)
    shoot("up_speed")


def icon_up_auto():
    new_scene(GHOST_LINE)
    a = manito(1.0, Vector((-0.018, 0.012, 0.0)), 8.0)
    b = manito(0.8, Vector((0.040, -0.020, 0.0)), -14.0)
    patch = bubble_patch(Vector((0.010, -0.004, -0.0045)), 0.0060, 3)
    frame(mesh_points(a + b) + mesh_points(patch), (-0.9, -0.6, 0.8), fill=0.9)
    shoot("up_auto")


def icon_up_value():
    new_scene()
    gold = lib.material("coin", lib.hex_color("#E0A93B"), rough=0.4)
    rim = lib.material("coin_rim", lib.hex_color("#B9802A"), rough=0.5)
    parts = []
    for k in range(6):  # pila de monedas finas, alternadas
        prof = [(0.0, 0.0024), (0.024, 0.0024), (0.025, 0.0016), (0.025, -0.0016), (0.024, -0.0024), (0.0, -0.0024)]
        c = lib.revolve_profile("coin", prof, 40)
        c.location = (0.003 * (k % 2) - 0.0015, 0.002 * k, 0.0024 + k * 0.005)
        c.data.materials.append(gold if k % 2 == 0 else rim)
        parts.append(c)
    bpy.context.view_layer.update()
    frame(mesh_points(parts), (0.3, -1.0, 0.8), fill=0.86)
    shoot("up_value")


def icon_up_special():
    new_scene()
    gold = lib.material("golden", lib.hex_color("#F2B632"), rough=0.3)
    b = bubble(0.03, Vector(), mat=gold)
    patch = [bubble(0.018, Vector((dx, dy, 0.0))) for dx, dy in ((-0.045, 0.02), (0.046, 0.016), (0.0, 0.05))]
    sparks = []
    for k in range(6):
        a = math.radians(k * 60.0 + 15.0)
        p0 = Vector((math.cos(a) * 0.036, math.sin(a) * 0.036, 0.03))
        p1 = Vector((math.cos(a) * 0.05, math.sin(a) * 0.05, 0.036))
        sp = lib.tube_along("spark", [tuple(p0), tuple(p1)], [0.003, 0.001], sides=6)
        sp.data.materials.append(lib.material("spark", lib.hex_color("#FFF3B0"), rough=0.4))
        sparks.append(sp)
    frame(mesh_points([b] + patch + sparks), (0.0, -0.9, 1.0), fill=0.9)
    shoot("up_special")


def icon_up_tense():
    new_scene()
    body = lib.material("gauge", lib.hex_color("#D9D4C7"), rough=0.5)
    face = lib.material("face", lib.hex_color("#FBF7EC"), rough=0.6)
    red = lib.material("needle", lib.hex_color("#D8432E"), rough=0.5)
    ink = lib.material("ink", INK, rough=0.8)
    ring = lib.revolve_profile("gauge", [(0.0, 0.012), (0.04, 0.012), (0.044, 0.008), (0.044, 0.0), (0.0, 0.0)], 48)
    ring.data.materials.append(body)
    disc = lib.revolve_profile("face", [(0.0, 0.0125), (0.037, 0.0125), (0.037, 0.011), (0.0, 0.011)], 48)
    disc.data.materials.append(face)
    parts = [ring, disc]
    for k in range(7):  # marcas de 210° a -30°
        a = math.radians(210.0 - k * 40.0)
        t = lib.box("tick", (0.0025, 0.009, 0.001), (math.cos(a) * 0.029, math.sin(a) * 0.029, 0.0132), (0.0, 0.0, a - math.pi / 2))
        t.data.materials.append(red if k >= 5 else ink)
        parts.append(t)
    a = math.radians(-5.0)  # aguja casi al máximo
    needle = lib.tube_along("needle", [(0.0, 0.0, 0.0138), (math.cos(a) * 0.03, math.sin(a) * 0.03, 0.0138)], [0.0028, 0.0008], sides=6)
    needle.data.materials.append(red)
    hub = lib.sphere("hub", 0.004, (0.0, 0.0, 0.0138), 12, 6)
    hub.data.materials.append(ink)
    parts += [needle, hub]
    frame(mesh_points(parts), (0.0, -0.45, 1.0), fill=0.9)
    shoot("up_tense")


def icon_up_chain():
    new_scene()
    parts = []
    for k in range(4):  # una fila que revienta en cadena: las de la izquierda ya aplastadas
        sq = 0.3 if k < 2 else 1.0
        parts.append(bubble(0.014, Vector((-0.045 + k * 0.03, 0.0, 0.0)), squash=sq))
    zap = lib.material("spark", YELLOW, rough=0.4)
    for k in range(3):
        x = -0.03 + k * 0.03
        pts = [(x - 0.008, 0.0, 0.022), (x - 0.002, 0.0, 0.03), (x + 0.002, 0.0, 0.022), (x + 0.008, 0.0, 0.03)]
        z = lib.tube_along("zap", pts, [0.0018, 0.0022, 0.0022, 0.0016], sides=6)
        z.data.materials.append(zap)
        parts.append(z)
    frame(mesh_points(parts), (0.0, -1.0, 0.6), fill=0.94)
    shoot("up_chain")


def icon_up_memory():
    new_scene()
    paper = lib.material("paper", lib.hex_color("#F4EEDC"), rough=0.7)
    cover = lib.material("cover", lib.hex_color("#C24D3A"), rough=0.6)
    ink = lib.material("ink", INK, rough=0.8)
    book = lib.box("cover", (0.06, 0.08, 0.008), (0.0, 0.0, 0.004))
    book.data.materials.append(cover)
    page = lib.box("page", (0.054, 0.074, 0.003), (0.002, 0.0, 0.0095))
    page.data.materials.append(paper)
    parts = [book, page]
    for k in range(5):
        ln = lib.box("line", (0.038, 0.0016, 0.0008), (0.006, 0.026 - k * 0.012, 0.0112))
        ln.data.materials.append(ink)
        parts.append(ln)
    for k in range(5):  # espiral
        sp = lib.revolve_profile("ring", [(0.0035, 0.0), (0.0045, 0.0015), (0.0035, 0.003), (0.0025, 0.0015)], 16)
        sp.location = (-0.03, 0.03 - k * 0.015, 0.008)
        sp.rotation_euler = (0.0, math.radians(90.0), 0.0)
        sp.data.materials.append(ink)
        parts.append(sp)
    piv = group(parts, "book")
    piv.rotation_euler = (0.0, 0.0, math.radians(-12.0))
    bpy.context.view_layer.update()
    frame(mesh_points(parts), (0.0, -0.5, 1.0), fill=0.9)
    shoot("up_memory")


ICONS = {
    "finger": icon_finger,
    "palm": icon_palm,
    "rolling_pin": icon_rolling_pin,
    "iron": icon_iron,
    "boot": lambda: icon_model("boot", (1.0, -0.25, 0.32), "boot"),
    "hands": icon_hands,
    "auto_roller": lambda: icon_model("roller", (0.6, -1.0, 0.7), "auto_roller"),
    "bubble": icon_bubble,
    "up_size": icon_up_size,
    "up_force": icon_up_force,
    "up_speed": icon_up_speed,
    "up_auto": icon_up_auto,
    "up_value": icon_up_value,
    "up_special": icon_up_special,
    "up_tense": icon_up_tense,
    "up_chain": icon_up_chain,
    "up_memory": icon_up_memory,
}


# --- Hoja de contactos ---------------------------------------------------------------------------

def contact_sheet(path, names):
    """Cada ícono a 256 px sobre papel y, abajo, a 48 px (la prueba de lectura) sobre papel y oscuro."""
    import numpy as np
    cols = 6
    cell = PX + 16
    small = 48
    rows = (len(names) + cols - 1) // cols
    row_h = cell + small * 2 + 24
    w, h = cols * cell + 16, rows * row_h + 16
    paper = np.array([0.95, 0.92, 0.86, 1.0])
    dark = np.array([0.20, 0.19, 0.18, 1.0])
    canvas = np.ones((h, w, 4)) * paper

    def paste(px, x, y, bg):
        rgb, a = px[:, :, :3], px[:, :, 3:4]
        n = px.shape[0]
        y0 = h - y - n  # las imágenes de Blender van de abajo hacia arriba
        region = canvas[y0:y0 + n, x:x + n]
        region[:, :, :3] = rgb * a + (region[:, :, :3] if bg is None else bg[:3]) * (1 - a)

    for i, nm in enumerate(names):
        img = bpy.data.images.load(os.path.join(OUT, nm + ".png"))
        img.colorspace_settings.name = "sRGB"
        px = np.array(img.pixels[:]).reshape(PX, PX, 4)
        x, y = 16 + (i % cols) * cell, 16 + (i // cols) * row_h
        paste(px, x, y, None)
        small_img = img.copy()
        small_img.scale(small, small)
        spx = np.array(small_img.pixels[:]).reshape(small, small, 4)
        canvas[h - (y + cell + small + 4):h - (y + cell + 4), x:x + small] = dark
        paste(spx, x, y + cell + 4, dark)
        paste(spx, x + small + 8, y + cell + 4, paper)
    out = bpy.data.images.new("sheet", w, h, alpha=False)
    out.pixels.foreach_set(canvas.astype(np.float32).flatten())
    out.filepath_raw = os.path.abspath(path)
    out.file_format = "JPEG"
    out.save()


if __name__ == "__main__":
    only = arg("--only", "")
    names = [n for n in ICONS if not only or n in only.split(",")]
    for nm in ([] if "--sheet-only" in ARGV else names):
        ICONS[nm]()
    if SHEET:
        contact_sheet(SHEET, list(ICONS))
