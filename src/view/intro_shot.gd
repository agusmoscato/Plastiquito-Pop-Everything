class_name IntroShot
extends RefCounted
## Plano de presentación de cada escenario (sesión 0.6.2): al entrar, la cámara arranca abierta mostrando
## la lámina y TODA la utilería argentina del escenario entera, y después baja con una curva suave a la
## cámara de trabajo (CameraRig.play_intro). Acá solo se calcula el encuadre, sin nodos de cámara.

const MARGIN: float = 0.05 ## fracción de la pantalla que queda libre en cada borde


## Los objetos argentinos (con mallas) que hay que mostrar enteros.
static func arg_nodes(props: Node3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n: Node in props.find_children("*", "Node3D", true, false):
		if n.has_meta(ScenarioHeroes.META_ARG) and not n.find_children("*", "MeshInstance3D", true, false).is_empty():
			out.append(n as Node3D)
	return out


## Transformación de `node` relativa a `root` (no hace falta que estén en el árbol).
static func global_xf(node: Node3D, root: Node3D) -> Transform3D:
	var xf: Transform3D = node.transform
	var p: Node = node.get_parent()
	while p != null and p != root and p is Node3D:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return root.transform * xf


## Cámara que muestra la lámina y toda la utilería argentina entera, centrada, con margen.
static func camera_for(props: Node3D, c: Vector2, e: Vector2, screen: Vector2) -> Transform3D:
	var nodes: Array[Node3D] = arg_nodes(props)
	var lo: Vector2 = c - e * 0.5
	var hi: Vector2 = c + e * 0.5
	for n: Node3D in nodes:
		var box: AABB = global_xf(n, props) * ScenarioHeroes.local_aabb(n)
		lo = lo.min(Vector2(box.position.x, box.position.z))
		hi = hi.max(Vector2(box.end.x, box.end.z))
	var target: Vector3 = Vector3((lo.x + hi.x) * 0.5, 0.0, (lo.y + hi.y) * 0.5)
	var dist: float = CameraRig.fit_distance(hi - lo, screen.x / screen.y) * 0.7
	var safe: Rect2 = Rect2(screen * MARGIN, screen * (1.0 - 2.0 * MARGIN))
	var cam: Transform3D = CameraRig.view_transform(target, dist)
	for i: int in 80:
		cam = CameraRig.view_transform(target, dist)
		var r: Rect2 = _union(nodes, props, cam, c, e)
		# Recentra: lo que se corre en pantalla, llevado al piso.
		var w0: Vector2 = CameraRig.unproject_to_plane(cam, screen * 0.5, screen)
		var w1: Vector2 = CameraRig.unproject_to_plane(cam, screen * 0.5 + (r.get_center() - screen * 0.5), screen)
		target += Vector3(w1.x - w0.x, 0.0, w1.y - w0.y) * 0.8
		if safe.encloses(r):
			break
		dist *= 1.05
	return CameraRig.view_transform(target, dist)


static func _union(nodes: Array[Node3D], props: Node3D, cam: Transform3D, c: Vector2, e: Vector2) -> Rect2:
	var pts: PackedVector2Array = PackedVector2Array()
	for sx: float in [-0.5, 0.5]:
		for sz: float in [-0.5, 0.5]:
			var p: Vector3 = CameraRig.project(cam, Vector3(c.x + e.x * sx, 0.0, c.y + e.y * sz), ScenarioHeroes.SCREEN)
			pts.append(Vector2(p.x, p.y))
	var r: Rect2 = ScenarioHeroes._rect_of(pts)
	for n: Node3D in nodes:
		r = r.merge(ScenarioHeroes.screen_box(n, global_xf(n, props), cam))
	return r


## Objetivo y distancia de una transformación hecha con CameraRig.view_transform.
static func target_and_zoom(cam: Transform3D) -> Vector4:
	var back: Vector3 = cam.basis.z # la cámara mira hacia -Z local: el objetivo está a `zoom` por delante
	var o: Vector3 = cam.origin
	var t: float = -o.y / -back.y # distancia hasta el piso a lo largo del eje de mirada
	var target: Vector3 = o - back * t
	return Vector4(target.x, target.y, target.z, t)
