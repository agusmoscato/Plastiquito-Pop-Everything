"""Utilidades comunes de los modelos 3D de Plastiquito (se corren dentro de Blender, sin interfaz).

Uso desde un modelo:
    import sys, os
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from art import lib
"""
import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector


def args():
    """Argumentos después de `--`: --out ruta.glb --render carpeta."""
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    out = {"out": None, "render": None}
    for i, a in enumerate(argv):
        if a == "--out" and i + 1 < len(argv):
            out["out"] = argv[i + 1]
        if a == "--render" and i + 1 < len(argv):
            out["render"] = argv[i + 1]
    return out


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)


def material(name, color, rough=0.5, metal=0.0, clearcoat=0.0, emission=None, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if "Coat Weight" in b.inputs:
        b.inputs["Coat Weight"].default_value = clearcoat
    if emission is not None:
        b.inputs["Emission Color"].default_value = (emission[0], emission[1], emission[2], 1.0)
        b.inputs["Emission Strength"].default_value = 1.5
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
    return m


def hex_color(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def new_object(name, verts, faces, edges=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in verts], edges or [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def select_only(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def smooth(obj, angle=40.0):
    """Sombreado suave con auto-smooth por ángulo (Blender 4.1+ usa 'Smooth by Angle')."""
    select_only(obj)
    bpy.ops.object.shade_smooth()
    try:
        bpy.ops.object.shade_auto_smooth(angle=math.radians(angle))
    except Exception:
        try:
            bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle))
        except Exception:
            pass


def subsurf(obj, levels=2, render_levels=None):
    mod = obj.modifiers.new("Subsurf", "SUBSURF")
    mod.levels = levels
    mod.render_levels = render_levels if render_levels is not None else levels
    return mod


def bevel(obj, width=0.004, segments=2, angle=35.0):
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(angle)
    return mod


def apply_modifiers(obj):
    select_only(obj)
    for m in list(obj.modifiers):
        try:
            bpy.ops.object.modifier_apply(modifier=m.name)
        except Exception as e:
            print("no se pudo aplicar", m.name, e)


def triangulate(obj):
    """Triangula (las tangentes del glTF solo se calculan sobre tris y quads)."""
    select_only(obj)
    mod = obj.modifiers.new("Tri", "TRIANGULATE")
    mod.quad_method = "BEAUTY"
    mod.min_vertices = 5
    bpy.ops.object.modifier_apply(modifier=mod.name)


def unwrap(obj, margin=0.02):
    select_only(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=margin)
    bpy.ops.object.mode_set(mode="OBJECT")


def revolve_profile(name, profile, segments=32, axis="Z"):
    """Sólido de revolución a partir de un perfil [(radio, altura), ...] alrededor del eje Z."""
    bm = bmesh.new()
    rings = []
    for (r, z) in profile:
        ring = []
        for i in range(segments):
            a = 2 * math.pi * i / segments
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), z)))
        rings.append(ring)
    for k in range(len(rings) - 1):
        for i in range(segments):
            j = (i + 1) % segments
            bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
    if profile[0][0] < 1e-6:
        pass
    else:
        bm.faces.new(list(reversed(rings[0])))
    if profile[-1][0] >= 1e-6:
        bm.faces.new(rings[-1])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def tube_along(name, points, radii, sides=12, squash=1.0):
    """Tubo que sigue una polilínea con radio variable (cada punto con su radio)."""
    bm = bmesh.new()
    rings = []
    for idx, p in enumerate(points):
        p = Vector(p)
        if idx == 0:
            t = (Vector(points[1]) - p).normalized()
        elif idx == len(points) - 1:
            t = (p - Vector(points[idx - 1])).normalized()
        else:
            t = (Vector(points[idx + 1]) - Vector(points[idx - 1])).normalized()
        up = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
        n = t.cross(up).normalized()
        b = t.cross(n).normalized()
        ring = []
        for i in range(sides):
            a = 2 * math.pi * i / sides
            off = n * math.cos(a) * radii[idx] + b * math.sin(a) * radii[idx] * squash
            ring.append(bm.verts.new(p + off))
        rings.append(ring)
    for k in range(len(rings) - 1):
        for i in range(sides):
            j = (i + 1) % sides
            bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def join(objs, name):
    select_only(objs[0])
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].name = name
    return objs[0]


def triangles(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = ev.to_mesh()
    me.calc_loop_triangles()
    n = len(me.loop_triangles)
    ev.to_mesh_clear()
    return n


def export_glb(path, objs=None):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    select_all = objs is None
    bpy.ops.object.select_all(action="SELECT" if select_all else "DESELECT")
    if objs:
        for o in objs:
            o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                              export_tangents=True, export_apply=True, export_yup=True,
                              export_skins=True, export_animations=False)


def render_set(folder, name, target=(0, 0, 0.1), dist=0.6, size=1024, elev=0.45):
    """Render de control en Eevee: 4 ángulos (1024 px como máximo) y una vista a 64 px, en JPG.
    Archivos: <name>_frente, _lado, _tres_cuartos, _atras y _64 en `folder`; <name>.jpg es el de tres cuartos."""
    folder = os.path.abspath(folder)
    os.makedirs(folder, exist_ok=True)
    scene = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    scene.render.image_settings.file_format = "JPEG"
    scene.render.image_settings.quality = 85
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.78, 0.84, 0.9, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.45
    scene.world = world
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 1.5
    so = bpy.data.objects.new("sun", sun)
    so.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
    scene.collection.objects.link(so)
    fill = bpy.data.lights.new("fill", "AREA")
    fill.energy = 40
    fill.size = 3
    fo = bpy.data.objects.new("fill", fill)
    fo.location = (-1.0, -0.6, 0.8)
    scene.collection.objects.link(fo)
    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = 70
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    # Encuadre automático: centro y tamaño del conjunto de mallas.
    pts = []
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
    if pts:
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        target = (lo + hi) * 0.5
        dist = max((hi - lo).length, 0.05) * 1.9
    tgt = Vector(target)

    def shoot(az, px, path):
        a = math.radians(az)
        cam.location = tgt + Vector((math.sin(a) * dist, -math.cos(a) * dist, dist * elev))
        cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.resolution_x = px
        scene.render.resolution_y = px
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)

    for label, az in (("frente", 0), ("lado", 90), ("tres_cuartos", 40), ("atras", 180)):
        shoot(az, size // 2, os.path.join(folder, "%s_%s.jpg" % (name, label)))
    shoot(40, size, os.path.join(folder, "%s.jpg" % name))
    shoot(40, 64, os.path.join(folder, "%s_64.jpg" % name))


def box(name, size, loc=(0, 0, 0), rot=(0, 0, 0)):
    """Caja con bisel (la usan los detalles duros)."""
    sx, sy, sz = size
    v = []
    for x in (-sx / 2, sx / 2):
        for y in (-sy / 2, sy / 2):
            for z in (-sz / 2, sz / 2):
                v.append((x, y, z))
    f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    o = new_object(name, v, f)
    o.location = loc
    o.rotation_euler = rot
    return o


def sphere(name, radius, loc=(0, 0, 0), segs=16, rings=10, scale=(1, 1, 1)):
    prof = []
    for i in range(rings + 1):
        a = math.pi * i / rings
        prof.append((radius * math.sin(a), -radius * math.cos(a)))
    o = revolve_profile(name, prof, segs)
    o.location = loc
    o.scale = scale
    return o


def finish(parts, name, A, mats=None, render_args=None, angle=50.0):
    """Aplica modificadores, une, triangula, suaviza, desenvuelve UV, exporta y renderiza."""
    for p in parts:
        apply_modifiers(p)
    obj = join(parts, name)
    triangulate(obj)
    smooth(obj, angle)
    unwrap(obj)
    print("TRIS", triangles(obj))
    if A["out"]:
        export_glb(A["out"])
    if A["render"]:
        render_set(A["render"], name, **(render_args or {}))
    return obj
