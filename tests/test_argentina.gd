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
