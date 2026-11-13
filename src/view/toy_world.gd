class_name ToyWorld
extends Node3D
## Mundo 3D del juguete: mesa, luz, entorno, cámara, lámina y la simulación asociada.
## Lo comparten main.tscn y benchmark.tscn.

signal sheet_replaced

var db: DataDB = DataDB.new()
var sheet: SheetModel
var grid: HexGrid
var tool_model: ToolModel
var sheet_view: SheetView
var camera_rig: CameraRig
var table: MeshInstance3D
var light: DirectionalLight3D
var environment: WorldEnvironment

var _reload_timer: float = -1.0


func _ready() -> void:
	if not db.load_all():
		push_error("ToyWorld: data inválida: %s" % "; ".join(db.errors))
		return
	_build_environment()
	_build_light()
	_build_table()
	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	camera_rig.shake_cfg = db.juice
	add_child(camera_rig)
	sheet_view = SheetView.new()
	sheet_view.name = "SheetView"
	add_child(sheet_view)
	set_sheet_size(Cfg.integer(db.sheet, "default_width"), Cfg.integer(db.sheet, "default_height"))


func _process(delta: float) -> void:
	if _reload_timer >= 0.0:
		_reload_timer -= delta
		if _reload_timer < 0.0:
			_reload_sheet()


## Crea una lámina nueva de w x h y la conecta con la vista y la herramienta.
func set_sheet_size(w: int, h: int) -> void:
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
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.72, 0.40, 0.22)
	m.roughness = 0.65
	pm.material = m
	table = MeshInstance3D.new()
	table.name = "Table"
	table.mesh = pm
	table.position = Vector3(0.0, -0.05, 0.0)
	add_child(table)
