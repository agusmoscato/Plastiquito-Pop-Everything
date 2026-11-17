"""Verificación objetiva de proporciones: silueta del modelo contra el plano de referencia (IoU).
Rasteriza los triángulos del .glb (pose de reposo) en celdas de 1 mm en dos vistas y compara con
art/blueprints/blueprint.py. Escribe art/blueprints/<modelo>_<vista>.png (plano en rojo, modelo en
verde, coincidencia en amarillo) y sale con código 1 si alguna vista tiene IoU < 0,85.
Uso: blender -b --factory-startup -P art/check_iou.py -- --model hand|hand_ghost|boot --glb <ruta>
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import bpy
from mathutils import Vector
from art.blueprints import blueprint as bp

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
MODEL = ARGS[ARGS.index("--model") + 1]
GLB = ARGS[ARGS.index("--glb") + 1]
CELL = 0.1  # cm
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "blueprints")
PASS = 0.85

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
bpy.context.view_layer.update()

# Origen del plano: la muñeca (mano) o el origen del modelo (bota, ya está en la suela).
origin = Vector((0.0, 0.0, 0.0))
for o in bpy.context.scene.objects:
    if o.type == "ARMATURE" and "wrist" in o.data.bones:
        origin = o.matrix_world @ o.data.bones["wrist"].head_local
tris = []
dg = bpy.context.evaluated_depsgraph_get()
for o in bpy.context.scene.objects:
    if o.type != "MESH" or o.name.startswith("Icosphere"):  # el importador glTF crea una icoesfera como forma de los huesos
        continue
    ev = o.evaluated_get(dg)
    me = ev.to_mesh()
    me.calc_loop_triangles()
    mw = o.matrix_world
    pts = [(mw @ v.co - origin) * 100.0 for v in me.vertices]
    for t in me.loop_triangles:
        tris.append([pts[i] for i in t.vertices])
    ev.to_mesh_clear()


def raster_model(axes, rot=0.0, shift=(0.0, 0.0), center=(0.0, 0.0)):
    """Rasteriza la proyección; con `rot` (radianes) y `shift` (cm) transforma ANTES de rasterizar
    (girar celdas ya rasterizadas deja agujeros)."""
    a, b = axes
    c, s_ = math.cos(rot), math.sin(rot)
    cells = set()
    for tri in tris:
        p = []
        for v in tri:
            x, y = v[a] - center[0], v[b] - center[1]
            p.append((center[0] + x * c - y * s_ + shift[0], center[1] + x * s_ + y * c + shift[1]))
        x0 = math.floor(min(q[0] for q in p) / CELL)
        x1 = math.ceil(max(q[0] for q in p) / CELL)
        y0 = math.floor(min(q[1] for q in p) / CELL)
        y1 = math.ceil(max(q[1] for q in p) / CELL)
        (ax, ay), (bx, by), (cx, cy) = p
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-12:
            continue
        for i in range(x0, x1 + 1):
            px = (i + 0.5) * CELL
            for j in range(y0, y1 + 1):
                py = (j + 0.5) * CELL
                l1 = ((by - cy) * (px - cx) + (cx - bx) * (py - cy)) / den
                l2 = ((cy - ay) * (px - cx) + (ax - cx) * (py - cy)) / den
                if l1 >= 0 and l2 >= 0 and l1 + l2 <= 1:
                    cells.add((i, j))
    return cells


def _moments(cells):
    n = len(cells)
    cx = sum(c[0] for c in cells) / n
    cy = sum(c[1] for c in cells) / n
    sxx = sum((c[0] - cx) ** 2 for c in cells) / n
    syy = sum((c[1] - cy) ** 2 for c in cells) / n
    sxy = sum((c[0] - cx) * (c[1] - cy) for c in cells) / n
    return cx, cy, 0.5 * math.atan2(2.0 * sxy, sxx - syy)


def _transform(cells, cx, cy, rot, dx, dy):
    c, s_ = math.cos(rot), math.sin(rot)
    return {(int(round(cx + (i - cx) * c - (j - cy) * s_ + dx)), int(round(cy + (i - cx) * s_ + (j - cy) * c + dy))) for (i, j) in cells}


def register(model, plan):
    """Registro rígido chico: giro de ±10° y corrimiento de ±3 cm que maximizan el IoU (SIN escala:
    el tamaño y las proporciones siguen contando). Búsqueda gruesa en celdas de 3 mm y fina al final."""
    cx = sum(c[0] for c in model) / len(model)
    cy = sum(c[1] for c in model) / len(model)
    k = 3
    coarse_m = {(i // k, j // k) for (i, j) in model}
    coarse_p = {(i // k, j // k) for (i, j) in plan}
    best = (-1.0, 0.0, 0, 0)
    for deg in range(-10, 11, 2):
        rot = math.radians(deg)
        base = _transform(coarse_m, cx / k, cy / k, rot, 0, 0)
        for dx in range(-10, 11):
            for dy in range(-10, 11):
                moved = {(i + dx, j + dy) for (i, j) in base}
                score = len(moved & coarse_p) / max(len(moved | coarse_p), 1)
                if score > best[0]:
                    best = (score, rot, dx * k, dy * k)
    # Pasada fina alrededor del mejor: giros de 0,5° y corrimientos de 1 mm, re-rasterizando.
    _, rot0, dx0, dy0 = best
    best_f = None
    for drot in (-1.0, -0.5, 0.0, 0.5, 1.0):
        for ddx in (-2, 0, 2):
            for ddy in (-2, 0, 2):
                rot = rot0 + math.radians(drot)
                moved = raster_model(AXES, rot, ((dx0 + ddx) * CELL, (dy0 + ddy) * CELL), (cx * CELL, cy * CELL))
                score = len(moved & plan) / max(len(moved | plan), 1)
                if best_f is None or score > best_f[0]:
                    best_f = (score, moved, math.degrees(rot))
    return best_f


def raster_blueprint(fn, bounds):
    (i0, i1, j0, j1) = bounds
    return {(i, j) for i in range(i0, i1 + 1) for j in range(j0, j1 + 1) if fn((i + 0.5) * CELL, (j + 0.5) * CELL)}


def save_overlay(name, a, b, bounds):
    i0, i1, j0, j1 = bounds
    w, h = i1 - i0 + 1, j1 - j0 + 1
    img = bpy.data.images.new(name, w, h)
    px = [0.12] * (w * h * 4)
    for k in range(w * h):
        px[k * 4 + 3] = 1.0
    for (i, j) in a | b:
        if not (i0 <= i <= i1 and j0 <= j <= j1):
            continue
        k = ((j - j0) * w + (i - i0)) * 4
        px[k] = 0.95 if (i, j) in a else 0.12
        px[k + 1] = 0.85 if (i, j) in b else 0.12
        px[k + 2] = 0.12
    img.pixels = px
    img.filepath_raw = os.path.join(OUT, name + ".png")
    img.file_format = "PNG"
    img.save()


arm = MODEL != "hand_ghost"
views = {
    "hand": [("superior", (0, 1), lambda u, v: bp.hand_top(u, v, True)), ("lateral", (1, 2), lambda u, v: bp.hand_side(u, v, True))],
    "hand_ghost": [("superior", (0, 1), lambda u, v: bp.hand_top(u, v, False)), ("lateral", (1, 2), lambda u, v: bp.hand_side(u, v, False))],
    "boot": [("superior", (0, 1), bp.boot_top), ("lateral", (1, 2), bp.boot_side)],
}[MODEL]
ok = True
for view, axes, fn in views:
    AXES = axes
    model = raster_model(axes)
    ii = [c[0] for c in model]
    jj = [c[1] for c in model]
    bounds = (min(ii) - 40, max(ii) + 40, min(jj) - 40, max(jj) + 40)
    plan = raster_blueprint(fn, bounds)
    raw = len(model & plan) / max(len(model | plan), 1)
    iou, model, rot = register(model, plan)
    print("   %s: sin alinear %.3f, alineado con giro de %.1f°" % (view, raw, rot))
    if "--widths" in ARGS:
        for v_cm in range(-9, 20, 2):
            j = int(v_cm / CELL)
            wm = sum(1 for (i, jj) in model if jj == j) * CELL
            wp = sum(1 for (i, jj) in plan if jj == j) * CELL
            print("      v=%3d cm  modelo %5.1f  plano %5.1f" % (v_cm, wm, wp))
    ok = ok and iou >= PASS
    print("IOU %s %s %.3f (modelo %.1f cm2, plano %.1f cm2)  %s" % (MODEL, view, iou, len(model) * CELL * CELL, len(plan) * CELL * CELL, "APROBADO" if iou >= PASS else "FALLÓ"))
    save_overlay("%s_%s" % (MODEL, view), plan, model, bounds)
sys.exit(0 if ok else 1)
