class_name ToyWorld
extends Node3D
## Mundo 3D del juguete: mesa, luz, entorno, cámara, lámina y la simulación asociada.
## Lo comparten main.tscn y benchmark.tscn.

signal sheet_replaced
signal sheet_reloaded ## la lámina se recargó sola (llegó al umbral)

var db: DataDB = DataDB.new()
var sheet: SheetModel
var grid: HexGrid
var tool_model: ToolModel
var sheet_view: SheetView
var camera_rig: CameraRig
var game: GameSim ## modo juego: la lámina y las herramientas son de GameSim
var specials_view: SpecialsView
var table: MeshInstance3D
var ground_material: ShaderMaterial
var scenario: ScenarioDirector ## escenario de la fase actual (piso, objetos, luz y ambiente)
var light: DirectionalLight3D
var environment: WorldEnvironment

var _reload_timer: float = -1.0
var deferred_sheet: bool = false ## true: no crea la lámina de prueba (lo hace attach)


func _ready() -> void:
	if not db.load_all():
		push_error("ToyWorld: data inválida: %s" % "; ".join(db.errors))
		return
	_build_environment()
	_build_light()
	_build_table()
	scenario = ScenarioDirector.new()
	scenario.name = "Scenario"
	add_child(scenario)
	scenario.setup(light, environment.environment, ground_material)
	scenario.apply(1, Vector2(10.0, 8.0), Vector2(20.0, 20.0))
	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	camera_rig.shake_cfg = db.juice
	add_child(camera_rig)
	sheet_view = SheetView.new()
	sheet_view.name = "SheetView"
	add_child(sheet_view)
	specials_view = SpecialsView.new()
	specials_view.name = "Specials"
	add_child(specials_view)
	if not deferred_sheet:
		set_sheet_size(Cfg.integer(db.sheet, "default_width"), Cfg.integer(db.sheet, "default_height"))


## Modo juego: usa la lámina de GameSim. Llamar después de agregar el nodo al árbol.
func attach(sim: GameSim) -> void:
	game = sim
	camera_rig.screen_shift = 0.144
	rebind_game_sheet(false)


## Vuelve a conectar la vista con la lámina actual de GameSim (lámina nueva o reciclado).
func rebind_game_sheet(roll_in: bool, animate_camera: float = 0.0, scenario_seconds: float = 0.0) -> void:
	sheet = game.sheet
	grid = game.grid
	tool_model = game.selected_tool()
	sheet_view.bind(sheet, grid, db.juice, tool_model.resistance)
	specials_view.bind(sheet, grid)
	specials_view.visible = true
	camera_rig.fit_to(sheet_view.center(), sheet_view.extents(), animate_camera)
	if scenario_seconds > 0.0 and not scenario.matches(game.phase(), sheet_view.extents()):
		transition_to_phase(game.phase(), scenario_seconds)
	else:
		apply_phase(game.phase())
	if roll_in:
		sheet_view.begin_roll_in()
	sheet_replaced.emit()


## Escenario según la fase (1 Mesa, 2 Piso, 3 Galpón, 4 Estacionamiento), de golpe.
func apply_phase(phase: int) -> void:
	if sheet_view != null and sheet_view.grid != null:
		if scenario.matches(phase, sheet_view.extents()):
			return
		scenario.apply(phase, sheet_view.center(), sheet_view.extents())
	else:
		scenario.apply(phase, Vector2(10.0, 8.0), Vector2(20.0, 20.0))


## Cambio de escenario suave (3-4 s): piso, luz, objetos y cámara cambian juntos, sin cortes.
## La cámara se aleja más con cada fase.
func transition_to_phase(phase: int, seconds: float = 3.5) -> void:
	var c: Vector2 = sheet_view.center()
	var e: Vector2 = sheet_view.extents()
	scenario.transition(phase, seconds, c, e)
	camera_rig.fit_to(c, e * scenario.camera_factor(), seconds)


func _process(delta: float) -> void:
	if _reload_timer >= 0.0:
		_reload_timer -= delta
		if _reload_timer < 0.0:
			_reload_sheet()


## Crea una lámina nueva de w x h y la conecta con la vista y la herramienta.
func set_sheet_size(w: int, h: int) -> void:
	if game != null:
		return
	if sheet != null and sheet.reload_requested.is_connected(_on_reload_requested):
		sheet.reload_requested.disconnect(_on_reload_requested)
	sheet = SheetModel.new(w, h)
	sheet.reload_threshold = Cfg.num(db.sheet, "reload_threshold")
	grid = HexGrid.new(w, h, Cfg.num(db.sheet, "bubble_radius"))
	tool_model = ToolModel.new(sheet, grid)
	tool_model.configure(_finger_balance(), db.sheet)
	sheet.reload_requested.connect(_on_reload_requested)
	sheet_view.bind(sheet, grid, db.juice, tool_model.resistance)
	camera_rig.fit_to(sheet_view.center(), sheet_view.extents())
	_reload_timer = -1.0
	sheet_replaced.emit()


func _finger_balance() -> Dictionary:
	var finger: Dictionary = db.get_tool("finger")
	var balance: Dictionary = finger["balance"]
	return balance


func _on_reload_requested() -> void:
	_reload_timer = Cfg.num(db.sheet, "reload_delay_seconds")


func _reload_sheet() -> void:
	sheet.reset(sheet.width, sheet.height)
	tool_model = ToolModel.new(sheet, grid)
	tool_model.configure(_finger_balance(), db.sheet)
	sheet_view.refresh_all(true)
	PopAudio.play_crinkle()
	sheet_replaced.emit()
	sheet_reloaded.emit()


func _build_environment() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.78, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.9, 1.0)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 1.6 # solo brilla lo que lo pida más adelante (doradas, arcoíris)
	environment = WorldEnvironment.new()
	environment.environment = env
	add_child(environment)


func _build_light() -> void:
	light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52.0, -30.0, 0.0)
	light.light_energy = 0.85
	light.shadow_enabled = true
	light.shadow_blur = 2.5
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	light.directional_shadow_max_distance = 80.0
	add_child(light)


func _build_table() -> void:
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(4000.0, 4000.0)
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load("res://shaders/scenario_ground.gdshader") as Shader
	pm.material = m
	ground_material = m
	table = MeshInstance3D.new()
	table.name = "Table"
	table.mesh = pm
	table.position = Vector3(0.0, -0.05, 0.0)
	add_child(table)
