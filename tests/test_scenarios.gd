extends GutTest


func test_each_phase_has_props_and_settings() -> void:
	assert_eq(ScenarioDirector.SETTINGS.size(), 4)
	assert_eq(ScenarioDirector.CAMERA_FACTOR.size(), 4)
	for phase: int in range(1, 5):
		var props: Node3D = ScenarioProps.build(phase, Vector2(10.0, 8.0), Vector2(20.0, 20.0))
		assert_gt(props.get_child_count(), 2, "fase %d tiene objetos" % phase)
		props.free()


func test_camera_moves_away_with_each_phase() -> void:
	for i: int in range(1, 4):
		assert_gt(ScenarioDirector.CAMERA_FACTOR[i], ScenarioDirector.CAMERA_FACTOR[i - 1])


func test_props_scale_with_sheet() -> void:
	assert_eq(ScenarioProps.unit(Vector2(8.0, 8.0)), 1.0)
	assert_almost_eq(ScenarioProps.unit(Vector2(150.0, 130.0)), 7.5, 0.001)


func test_lighting_differs_between_scenarios() -> void:
	var seen: Dictionary = {}
	for s: Dictionary in ScenarioDirector.SETTINGS:
		var c: Color = s["color"]
		seen[c.to_html()] = true
	assert_eq(seen.size(), 4, "cada escenario tiene su propia luz")


func test_work_camera_zoom_and_whole_sheet_on_transition() -> void:
	var rig: CameraRig = CameraRig.new()
	rig.work_mode = true
	rig.min_bubble_px = 10.0
	var work: float = CameraRig.work_distance(10.0)
	var view_h: float = 2.0 * work * tan(deg_to_rad(CameraRig.FOV) * 0.5)
	assert_almost_eq(900.0 / view_h, 10.0, 0.01, "en el zoom de trabajo la burbuja mide 10 px")
	rig.fit_to(Vector2(75, 65), Vector2(150, 130))
	assert_almost_eq(rig.zoom_distance(), work, 0.01, "sin transición: zoom de trabajo")
	var whole: float = CameraRig.fit_distance(Vector2(150, 130), 16.0 / 9.0)
	assert_gte(rig.max_zoom, whole, "con la rueda se puede ver la lámina entera")
	rig.fit_to(Vector2(75, 65), Vector2(150, 130), 3.5)
	rig._zoom = whole
	assert_almost_eq(rig._target_zoom, whole, 0.01, "la transición muestra la lámina entera")
	for i: int in 400:
		rig._process(1.0 / 60.0)
	assert_almost_eq(rig._target_zoom, work, 0.01, "después vuelve al zoom de trabajo")
	rig.free()


func test_clip_camera_still_fits_whole_sheet() -> void:
	var rig: CameraRig = CameraRig.new()
	rig.fit_to(Vector2(75, 65), Vector2(150, 130))
	assert_almost_eq(rig.zoom_distance(), CameraRig.fit_distance(Vector2(150, 130), 16.0 / 9.0), 0.01)
	rig.free()


## Jornada B3: ningún objeto del escenario pisa la lámina ni se mete entre la cámara y la lámina
## (la cámara mira desde +Z, así que nada puede quedar del lado +Z de la lámina por encima del piso).
func test_props_never_touch_or_cover_the_sheet() -> void:
	var sizes: Dictionary = {1: Vector2(8, 7), 2: Vector2(40, 35), 3: Vector2(80, 70), 4: Vector2(150, 130)}
	for phase: int in sizes:
		var e: Vector2 = sizes[phase]
		var c: Vector2 = e * 0.5
		var sheet: Rect2 = Rect2(c - e * 0.5, e).grow(0.5)
		var props: Node3D = ScenarioProps.build(phase, c, e)
		for n: Node in props.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n as MeshInstance3D
			var box: AABB = _global_aabb(mi)
			var foot: Rect2 = Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))
			var flat: bool = box.size.y < 0.2 # pintura y líneas del piso
			assert_false(foot.intersects(sheet) and not flat, "fase %d: %s pisa la lámina" % [phase, mi.name])
			assert_false(box.position.z > sheet.end.y and box.end.y > 1.0, "fase %d: %s queda entre la cámara y la lámina" % [phase, mi.name])
		props.free()


func _global_aabb(mi: MeshInstance3D) -> AABB:
	var xf: Transform3D = mi.transform
	var p: Node = mi.get_parent()
	while p is Node3D:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf * mi.get_aabb()



func test_work_camera_small_sheet_fills_play_area() -> void:
	var plan: Vector2 = CameraRig.work_plan(Vector2(8, 7), 16.0 / 9.0, 0.71, 0.68, 10.0)
	assert_eq(plan.y, 0.0, "la lámina de la Mesa entra entera: no sigue a la herramienta")
	var tan_half: float = tan(deg_to_rad(CameraRig.FOV) * 0.5)
	var visible_w: float = 2.0 * plan.x * tan_half * 16.0 / 9.0
	var fill: float = 8.0 / (visible_w * 0.71)
	assert_almost_eq(fill, 0.68, 0.01, "llena el 68 % del ancho del área de juego")
	assert_gte(CameraRig.bubble_px_at(plan.x), 10.0)
	var big: Vector2 = CameraRig.work_plan(Vector2(150, 130), 16.0 / 9.0, 0.71, 0.68, 10.0)
	assert_eq(big.y, 1.0, "la lámina grande no entra a 10 px: sigue a la herramienta")
	assert_almost_eq(CameraRig.bubble_px_at(big.x), 10.0, 0.01)


func test_tool_keeps_its_screen_fraction() -> void:
	for zoom: float in [12.0, 40.0, 120.0]:
		var k: float = ToolView.screen_scale_for(5.0, zoom, 0.16)
		var view_h: float = 2.0 * zoom * tan(deg_to_rad(CameraRig.FOV) * 0.5)
		assert_almost_eq(5.0 * k / view_h, 0.16, 0.0001, "la herramienta ocupa el 16 % del alto a cualquier distancia")
