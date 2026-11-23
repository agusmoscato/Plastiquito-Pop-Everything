extends GutTest
## La utilería argentina se ve (sesión 0.6.2): la pareja protagonista de cada escenario queda al
## menos 60 % a la vista con la cámara de trabajo de su fase (dentro de la pantalla y fuera del HUD), y
## el plano de presentación muestra entera toda la utilería argentina del escenario.

const STARTS: Array[int] = [8, 20, 56, 80]
## Láminas a probar por fase: la inicial (llegada al escenario) y, en la Mesa y el Piso, la más grande
## (ahí la lámina siempre entra entera en cámara; en el Galpón y el Estacionamiento las grandes se
## recorren con la cámara que sigue a la herramienta y la utilería se ve al llegar al borde).
const SIZES: Dictionary = {1: [8, 20], 2: [20, 40], 3: [56], 4: [80]}


static func sheet_of(n: int) -> Array[Vector2]:
	var g: HexGrid = HexGrid.new(n, n, 0.5)
	var c: Vector2 = Vector2(g.spacing * (float(n) - 0.5) * 0.5, g.row_step * float(n - 1) * 0.5)
	var e: Vector2 = Vector2(g.spacing * float(n), g.row_step * float(n) + g.hex_size)
	return [c, e]


func test_hero_props_are_visible_with_the_work_camera() -> void:
	for phase: int in range(1, 5):
		var sizes: Array = SIZES[phase]
		for n: int in sizes:
			var ce: Array[Vector2] = sheet_of(n)
			var props: Node3D = ScenarioProps.build(phase, ce[0], ce[1])
			var hero: Node3D = props.get_node("Hero") as Node3D
			var fill: float = ScenarioHeroes.fill_by_phase[phase - 1]
			var cam: Transform3D = CameraRig.work_view(ce[0], ce[1], ScenarioHeroes.SCREEN, ScenarioHeroes.play_area, fill, ScenarioHeroes.min_bubble_px, ScenarioHeroes.screen_shift)
			for obj: Node in hero.get_children(): # cada objeto protagonista por separado
				var o: Node3D = obj as Node3D
				var xf: Transform3D = hero.transform * o.transform
				var frac: float = ScenarioHeroes.visible_fraction(o, xf, cam, Hud.layout_rects(ScenarioHeroes.SCREEN))
				var box: Rect2 = ScenarioHeroes.screen_box(o, xf, cam)
				gut.p("fase %d lámina %d: %s escala %.2f, a la vista %d %%, en pantalla %d x %d px" % [phase, n, o.name, ScenarioHeroes.scale_for(phase), roundi(frac * 100.0), roundi(box.size.x), roundi(box.size.y)])
				assert_gte(frac, 0.6, "fase %d (lámina %d): %s se ve" % [phase, n, o.name])
			props.free()


func test_intro_shot_shows_every_argentine_prop_whole() -> void:
	for phase: int in range(1, 5):
		var ce: Array[Vector2] = sheet_of(STARTS[phase - 1])
		var props: Node3D = ScenarioProps.build(phase, ce[0], ce[1])
		var cam: Transform3D = IntroShot.camera_for(props, ce[0], ce[1], ScenarioHeroes.SCREEN)
		var screen: Rect2 = Rect2(Vector2.ZERO, ScenarioHeroes.SCREEN)
		var count: int = 0
		for node: Node3D in IntroShot.arg_nodes(props):
			count += 1
			var r: Rect2 = ScenarioHeroes.screen_box(node, IntroShot.global_xf(node, props), cam)
			assert_true(screen.encloses(r), "fase %d: %s entero en el plano de presentación" % [phase, node.name])
		assert_gt(count, 1, "fase %d tiene utilería argentina" % phase)
		props.free()


## El cuadro de EMPLEADO DEL MES del Depósito no queda detrás de RECICLAR ni de otro panel, ni sobre la lámina, ni
## en el renglón del título de los créditos (0.7.3: el revisor lo veía cortado por RECICLAR).
func test_employee_frame_is_clear_of_the_hud() -> void:
	var screen: Vector2 = ScenarioHeroes.SCREEN
	var hud: Array[Rect2] = Hud.layout_rects(screen)
	var free_w: float = screen.x - Hud.SHOP_W - 16.0
	hud.append(Rect2(free_w - 170.0, 76.0, 150.0, 136.0)) # burbujario, mi mano, ruta
	hud.append(Rect2(380.0, 820.0, 840.0, 80.0)) # título de los créditos
	for start: float in [56.0, 64.0, 72.0]:
		var e: Vector2 = Vector2(start, start * 0.866)
		var c: Vector2 = e * 0.5
		var cam: Transform3D = ScenarioHeroes._work_cam(3, c, e)
		var group: Node3D = ScenarioHeroes._build_group(3)
		var hxf: Transform3D = ScenarioHeroes._placement(group, cam, ScenarioHeroes.free_zone(3, c, e), ScenarioHeroes.scale_for(3, e), c, e)
		group.free()
		var fr: Rect2 = ScenarioHeroes.frame_screen_rect(hxf, cam)
		assert_true(Rect2(Vector2.ZERO, screen).encloses(fr), "cuadro dentro de la pantalla (lámina %d): %s" % [int(start), str(fr)])
		assert_false(fr.intersects(ScenarioHeroes._sheet_screen(cam, c, e)), "cuadro fuera de la lámina (%d)" % int(start))
		for h: Rect2 in hud:
			assert_false(fr.intersects(h), "cuadro %s contra panel %s (lámina %d)" % [str(fr), str(h), int(start)])


## La botella de cola puede ir más grande que la real para leerse, pero nunca más del doble (0.7.3).
func test_cola_is_at_most_twice_real_size() -> void:
	assert_between(ScenarioHeroes.COLA_SIZE, 1.0, 2.0)
