"""Íconos de los objetos protagonistas de cada escenario (mate, pelota, garrafa, chulengo) para la hoja de RUTA.
Importa el .glb del juego, lo encuadra con cámara ortográfica y tres luces de estudio y renderiza 256 px con fondo
transparente. Uso: blender -b --factory-startup -P art/prop_icons.py"""
import math
import os
import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROPS = {"route_mate": "prop_mate", "route_pelota": "prop_pelota", "route_garrafa": "prop_garrafa", "route_chulengo": "prop_chulengo"}

for name, glb in PROPS.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets", "models", glb + ".glb"))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in meshes:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    center = (lo + hi) * 0.5
    size = max((hi - lo).x, (hi - lo).y, (hi - lo).z)
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = size * 1.25
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    d = Vector((0.55, -0.8, 0.6)).normalized()
    cam.location = center + d * size * 3.0
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    for loc, energy in (((2, -3, 4), 3.0), ((-3, -1, 2), 1.4), ((0, 3, 2), 1.0)):
        ld = bpy.data.lights.new("l", "SUN")
        ld.energy = energy
        lo_ = bpy.data.objects.new("l", ld)
        lo_.rotation_euler = (math.radians(50), 0, math.radians(30 + loc[0] * 20))
        bpy.context.scene.collection.objects.link(lo_)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT"
    sc.render.resolution_x = sc.render.resolution_y = 256
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.use_freestyle = True
    sc.view_layers[0].freestyle_settings.linesets.new("l") if not sc.view_layers[0].freestyle_settings.linesets else None
    sc.render.line_thickness = 1.6
    sc.render.filepath = os.path.join(ROOT, "assets", "icons", name + ".png")
    bpy.ops.render.render(write_still=True)
    print("ICON", name)
