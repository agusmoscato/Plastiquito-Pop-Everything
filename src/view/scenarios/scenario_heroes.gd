class_name ScenarioHeroes
extends RefCounted
## La utilería argentina de cada escenario, ubicada donde se ve (sesión 0.6.2). Cada escenario tiene una
## pareja protagonista (Mesa: mate y termo; Piso: pelota y sifón; Galpón: garrafa y cajón de naranjas;
## Estacionamiento: chulengo con humo) que va en la franja de pantalla que el HUD deja libre con la cámara
## de trabajo de esa fase: a la derecha de la lámina (antes de la hoja de pedidos) o abajo a la izquierda.
## Se proyecta con las cuentas de CameraRig (sin nodos) y se escala para que entre; la misma escala se usa
## en toda la utilería argentina del escenario, así el mate y la yerba guardan proporción.
## Los números (franjas, márgenes) salen de lo que mide Hud.layout_rects.

const META_ARG: String = "arg_prop" ## marca los objetos argentinos (el plano de presentación los encuadra)
const META_HERO: String = "hero_prop"
const SCREEN: Vector2 = Vector2(1600.0, 900.0) ## pantalla de referencia (la del juego y las capturas)

## Cámara de trabajo (las fija ToyWorld con data/juice.json; los valores por defecto son los del juego).
static var fill_by_phase: Array = [0.46, 0.5, 0.58, 0.72]
static var play_area: float = 0.71
static var min_bubble_px: float = 10.0
static var screen_shift: float = 0.144
static var phase_starts: Array = [8, 20, 56, 80]
static var _scale_cache: Dictionary = {}

## Pareja protagonista de cada fase: [archivo, desplazamiento en cm a escala 1, giro].
const HEROES: Dictionary = {
	1: [["prop_mate", Vector3(0.0, 0.0, 0.0), 200.0], ["prop_termo", Vector3(2.0, 0.0, -17.0), -25.0]],
	2: [["prop_pelota", Vector3(0.0, 0.0, 0.0), 30.0], ["prop_sifon", Vector3(4.0, 0.0, -26.0), -20.0]],
	3: [["prop_cajon", Vector3(0.0, 0.0, 0.0), 90.0], ["prop_garrafa", Vector3(4.0, 0.0, -48.0), 30.0]],
	4: [["prop_chulengo", Vector3(0.0, 0.0, 0.0), -100.0]],
}


## Arma la pareja protagonista de `phase` en su franja y la agrega a `root`. Devuelve el nodo.
static func place(root: Node3D, phase: int, c: Vector2, e: Vector2) -> Node3D:
	var hero: Node3D = _build_group(phase)
	hero.name = "Hero"
	hero.set_meta(META_HERO, true)
	var s: float = scale_for(phase, e)
	var cam: Transform3D = _work_cam(phase, c, e)
	var zone: Rect2 = free_zone(phase, c, e)
	hero.transform = _placement(hero, cam, zone, s, c, e)
	root.add_child(hero)
	if phase == 4: # el humo del chulengo sale siempre de la parrilla
		var smoke: GPUParticles3D = ScenarioProps.smoke(hero.position + Vector3(0.0, 95.0 * s, 0.0), s)
		smoke.set_meta(META_ARG, true)
		root.add_child(smoke)
	return hero


## Escala de la utilería argentina: la que hace entrar la pareja protagonista en su franja con la cámara
## de trabajo de esa lámina (`e`; sin dar, la inicial de la fase). Así el protagonista mantiene su tamaño
## en pantalla cuando la lámina crece y la cámara se aleja.
static func scale_for(phase: int, e: Vector2 = Vector2.ZERO) -> float:
	var e0: Vector2 = e
	if e0 == Vector2.ZERO:
		var start: float = phase_starts[clampi(phase, 1, phase_starts.size()) - 1]
		e0 = Vector2(start, start * 0.866)
	var key: String = "%d_%d" % [phase, roundi(e0.x * 10.0)]
	if _scale_cache.has(key):
		var cached: float = _scale_cache[key]
		return cached
	var c0: Vector2 = e0 * 0.5
	var group: Node3D = _build_group(phase)
	var cam: Transform3D = _work_cam(phase, c0, e0)
	var zone: Rect2 = free_zone(phase, c0, e0)
	var s: float = 1.0
	var hud: Array[Rect2] = Hud.layout_rects(SCREEN)
	for i: int in 50: # la escala más grande con la que cada protagonista queda a la vista (>= MIN_SEEN)
		var xf: Transform3D = _placement(group, cam, zone, s, c0, e0)
		if _all_seen(group, xf, cam, hud):
			break
		s *= 0.92
	group.free()
	_scale_cache[key] = s
	return s


const MIN_SEEN: float = 0.78 ## fracción de cada protagonista que tiene que quedar a la vista (el test pide 0,6)


static func _all_seen(group: Node3D, xf: Transform3D, cam: Transform3D, hud: Array[Rect2]) -> bool:
	var box: Rect2 = screen_box(group, xf, cam)
	if box.position.y < 0.0 or box.end.y > SCREEN.y: # entero a lo alto (cortado de costado, sí)
		return false
	for obj: Node in group.get_children():
		var o: Node3D = obj as Node3D
		if visible_fraction(o, xf * o.transform, cam, hud) < MIN_SEEN:
			return false
	return true


static func clear_cache() -> void:
	_scale_cache.clear()


static func _work_cam(phase: int, c: Vector2, e: Vector2) -> Transform3D:
	var fill: float = fill_by_phase[clampi(phase, 1, fill_by_phase.size()) - 1]
	return CameraRig.work_view(c, e, SCREEN, play_area, fill, min_bubble_px, screen_shift)


## La franja que el HUD deja libre, al lado de la lámina: la de la derecha (entre la lámina y la hoja de
## pedidos) o la de abajo a la izquierda (debajo del encargo, antes de la barra de herramientas).
static func free_zone(phase: int, c: Vector2, e: Vector2) -> Rect2:
	var cam: Transform3D = _work_cam(phase, c, e)
	var sheet_px: Rect2 = _sheet_screen(cam, c, e)
	var hud: Array[Rect2] = Hud.layout_rects(SCREEN)
	var shop_left: float = hud[3].position.x
	var right: Rect2 = Rect2(Vector2(sheet_px.end.x + 16.0, 150.0), Vector2(shop_left - 10.0 - (sheet_px.end.x + 16.0), 620.0))
	var left: Rect2 = Rect2(Vector2(12.0, 440.0), Vector2(sheet_px.position.x - 18.0 - 12.0, 335.0))
	if right.size.x >= left.size.x or right.size.x >= 160.0:
		return right
	return left


static func _sheet_screen(cam: Transform3D, c: Vector2, e: Vector2) -> Rect2:
	var pts: PackedVector2Array = PackedVector2Array()
	for sx: float in [-0.5, 0.5]:
		for sz: float in [-0.5, 0.5]:
			var p: Vector3 = CameraRig.project(cam, Vector3(c.x + e.x * sx, 0.0, c.y + e.y * sz), SCREEN)
			pts.append(Vector2(p.x, p.y))
	return _rect_of(pts)


static func _rect_of(pts: PackedVector2Array) -> Rect2:
	var lo: Vector2 = pts[0]
	var hi: Vector2 = pts[0]
	for p: Vector2 in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	return Rect2(lo, hi - lo)


static func _build_group(phase: int) -> Node3D:
	var group: Node3D = Node3D.new()
	var defs: Array = HEROES[clampi(phase, 1, 4)]
	for d: Array in defs:
		var file: String = d[0]
		var off: Vector3 = d[1]
		var yaw: float = d[2]
		var m: Node3D = ScenarioProps.glb_node(file, off, yaw)
		m.set_meta(META_ARG, true)
		group.add_child(m)
	return group


## Caja (en coordenadas del nodo) de todas sus mallas.
static func local_aabb(node: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for mi: MeshInstance3D in _meshes(node):
		var box: AABB = _relative(mi, node) * mi.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


static func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n: Node in node.find_children("*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out


static func _relative(mi: Node3D, top: Node3D) -> Transform3D:
	var xf: Transform3D = mi.transform
	var p: Node = mi.get_parent()
	while p != null and p != top and p is Node3D:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## Rectángulo de pantalla que ocupa `node` puesto con `xf` (sus 8 esquinas proyectadas).
static func screen_box(node: Node3D, xf: Transform3D, cam: Transform3D) -> Rect2:
	var box: AABB = local_aabb(node)
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 8:
		var p: Vector3 = CameraRig.project(cam, xf * box.get_endpoint(i), SCREEN)
		if p.z <= 0.0: # detrás de la cámara: no entra en ningún lado
			return Rect2(Vector2(-1.0e5, -1.0e5), Vector2(2.0e5, 2.0e5))
		pts.append(Vector2(p.x, p.y))
	return _rect_of(pts)


## Escala `s` y posición para que la caja en pantalla quede centrada en `zone`.
static func _fit(node: Node3D, cam: Transform3D, zone: Rect2, s: float) -> Transform3D:
	var box: AABB = local_aabb(node)
	var mid: Vector3 = box.get_center()
	var anchor: Vector2 = zone.get_center()
	var xf: Transform3D = Transform3D.IDENTITY
	for i: int in 5:
		var w: Vector2 = CameraRig.unproject_to_plane(cam, anchor, SCREEN)
		xf = Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3(w.x - mid.x * s, ScenarioProps.GROUND_Y, w.y - mid.z * s))
		var r: Rect2 = screen_box(node, xf, cam)
		if r.size.x > 1.0e4:
			break
		anchor += zone.get_center() - r.get_center()
	return xf


## Centrada en la franja y, si la caja en el piso llegara a tocar la lámina, corrida hacia afuera.
static func _placement(node: Node3D, cam: Transform3D, zone: Rect2, s: float, c: Vector2, e: Vector2) -> Transform3D:
	var xf: Transform3D = _fit(node, cam, zone, s)
	var box: AABB = xf * local_aabb(node)
	var sheet: Rect2 = Rect2(c - e * 0.5, e).grow(1.0)
	var foot: Rect2 = Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))
	if foot.intersects(sheet):
		if foot.get_center().x >= c.x:
			xf.origin.x += sheet.end.x - foot.position.x
		else:
			xf.origin.x -= foot.end.x - sheet.position.x
	return xf


## Qué fracción de la caja de `node` (puesto con `xf`) se ve con `cam`: dentro de la pantalla y fuera de
## los rectángulos del HUD. Muestrea una grilla de puntos sobre la caja proyectada.
static func visible_fraction(node: Node3D, xf: Transform3D, cam: Transform3D, hud: Array[Rect2]) -> float:
	var r: Rect2 = screen_box(node, xf, cam)
	var screen: Rect2 = Rect2(Vector2.ZERO, SCREEN)
	var seen: int = 0
	var total: int = 0
	for iy: int in 24:
		for ix: int in 24:
			var p: Vector2 = r.position + r.size * Vector2((float(ix) + 0.5) / 24.0, (float(iy) + 0.5) / 24.0)
			total += 1
			if not screen.has_point(p):
				continue
			var covered: bool = false
			for h: Rect2 in hud:
				if h.has_point(p):
					covered = true
					break
			if not covered:
				seen += 1
	return float(seen) / float(maxi(total, 1))
