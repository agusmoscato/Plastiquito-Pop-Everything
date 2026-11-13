class_name ClipBase
extends Node3D
## Base de las escenas de clips para marketing (scenes/clips/): mundo 3D sin interfaz, lámina
## precargada de tensas, cámara y herramienta automáticas con movimiento suave. Las escenas
## concretas redefinen setup() y script_step(); la base resuelve la lámina, las cadenas, el audio
## y las partículas. Se graban con tools/record_clip.sh (Movie Maker de Godot).

const GRID_RADIUS_KEY: String = "bubble_radius"

var duration: float = 12.0
var world: ToyWorld
var sheet: SheetModel
var grid: HexGrid
var chain: ChainSolver
var tool_model: ToolModel
var tool_view: ToolView
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var t: float = 0.0

var _prev_pos: Vector2 = Vector2.ZERO
var _first_step: bool = true
var _shot_dir: String = ""
var _shots_taken: int = 0


func _ready() -> void:
	rng.seed = 7
	world = ToyWorld.new()
	world.name = "World"
	world.deferred_sheet = true
	add_child(world)
	world.camera_rig.min_zoom = 2.0
	world.camera_rig.max_zoom = 8000.0
	tool_view = ToolView.new()
	tool_view.name = "Tool"
	add_child(tool_view)
	tool_view.configure(world.db.juice)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--clip-seconds="):
			duration = float(arg.trim_prefix("--clip-seconds="))
		elif arg.begins_with("--clip-shots="):
			_shot_dir = arg.trim_prefix("--clip-shots=")
			DirAccess.make_dir_recursive_absolute(_shot_dir)
	setup()


## A redefinir: arma la lámina, la cámara y el guion inicial.
func setup() -> void:
	pass


## A redefinir: guion cuadro a cuadro (t en segundos desde el inicio del clip).
func script_step(_time: float, _delta: float) -> void:
	pass


## Crea una lámina nueva de w x h y la conecta con la vista (cerca/lejos y especiales).
func make_sheet(w: int, h: int, phase: int) -> void:
	sheet = SheetModel.new(w, h)
	sheet.reload_threshold = 2.0 # los clips no recargan
	grid = HexGrid.new(w, h, Cfg.num(world.db.sheet, GRID_RADIUS_KEY))
	chain = ChainSolver.new(sheet, grid)
	chain.k = Cfg.num(world.db.sheet, "chain_k")
	chain.budget_per_frame = 90
	tool_model = ToolModel.new(sheet, grid)
	tool_model.resistance = 1.0
	tool_model.recovery_per_second = 1.5
	world.sheet = sheet
	world.grid = grid
	world.tool_model = tool_model
	world.sheet_view.bind(sheet, grid, world.db.juice, 1.0)
	world.specials_view.bind(sheet, grid)
	world.specials_view.visible = true
	world.camera_rig.fit_to(world.sheet_view.center(), world.sheet_view.extents())
	world.apply_phase(phase)


## Pone presiones al azar entre `lo` y `hi`, y una zona caliente (más tensa) alrededor de `hot`.
func precharge(lo: float, hi: float, hot: Vector2, hot_radius: float, hot_value: float) -> void:
	for idx: int in sheet.cell_count():
		sheet.pressure[idx] = rng.randf_range(lo, hi)
	for idx: int in grid.cells_in_circle(hot, hot_radius):
		sheet.pressure[idx] = clampf(hot_value + rng.randf_range(-0.08, 0.04), 0.5, sheet.max_pressure - 0.01)
	for idx: int in sheet.cell_count():
		sheet.refresh_state(idx)


## Esparce especiales (golosas para el plano): dorada, bomba y línea.
func scatter_specials(chance: float) -> void:
	for idx: int in sheet.cell_count():
		if rng.randf() < chance:
			sheet.type[idx] = 1 + rng.randi() % 3
	world.specials_view.bind(sheet, grid)


func center() -> Vector2:
	return world.sheet_view.center()


## Cámara cinematográfica: apunta a `look` (plano XZ) a `distance` unidades, sin interpolación del rig.
func cam(look: Vector2, distance: float) -> void:
	world.camera_rig.focus(look, distance)


static func ease_io(x: float) -> float:
	var k: float = clampf(x, 0.0, 1.0)
	return k * k * k * (k * (k * 6.0 - 15.0) + 10.0)


## Distancia de cámara que encuadra toda la lámina (la calcula el rig).
func fit_distance() -> float:
	world.camera_rig.fit_to(world.sheet_view.center(), world.sheet_view.extents())
	return world.camera_rig.zoom_distance()


## Mueve la herramienta automática a `pos` apretando o no, y revienta lo que corresponda.
func drive_tool(pos: Vector2, pressing: bool, delta: float) -> void:
	if _first_step:
		_prev_pos = pos
		_first_step = false
	var cells: PackedInt32Array = PackedInt32Array()
	var dir: Vector2 = pos - _prev_pos
	if pressing:
		cells = tool_model.cells_for(_prev_pos, pos)
	var popped: PackedInt32Array = tool_model.step(cells, delta, tool_model.last_weights, dir)
	for idx: int in popped:
		chain.pop_now(idx)
	_prev_pos = pos
	tool_view.set_cursor(pos)
	tool_view.set_pressing(pressing)
	tool_view.set_drag_direction(dir)
	if not popped.is_empty():
		tool_view.bounce(minf(float(popped.size()), 4.0) * 0.5)


func _process(delta: float) -> void:
	t += delta
	if chain != null:
		chain.clear_events()
	script_step(t, delta)
	if chain != null:
		chain.step()
		_effects(delta)
	_maybe_shot()
	if t >= duration:
		get_tree().quit()


## Con --clip-shots=<carpeta> guarda 4 cuadros repartidos en el clip (para revisarlo sin grabar).
func _maybe_shot() -> void:
	if _shot_dir.is_empty() or _shots_taken >= 4:
		return
	var at: float = duration * (0.18 + 0.22 * float(_shots_taken))
	if t >= at:
		var img: Image = get_viewport().get_texture().get_image()
		if img != null:
			img.save_png("%s/%s_%d.png" % [_shot_dir, scene_file_path.get_file().get_basename(), _shots_taken])
		_shots_taken += 1


func _effects(delta: float) -> void:
	var n: int = chain.events_idx.size()
	var max_p: float = 1.0
	for p: float in chain.events_pressure:
		max_p = maxf(max_p, p)
	PopAudio.report_frame(n, max_p, delta)
	if n == 0:
		return
	var positions: PackedVector3Array = PackedVector3Array()
	@warning_ignore("integer_division")
	var stride: int = maxi(1, n / 30)
	for i: int in range(0, n, stride):
		var p: Vector2 = grid.cell_to_world(chain.events_idx[i])
		var kind: int = chain.events_type[i]
		if kind != 0:
			Juice.special_at(Vector3(p.x, 0.4, p.y), kind)
			PopAudio.play_special(kind)
		else:
			positions.append(Vector3(p.x, 0.25, p.y))
	Juice.pops_at(positions)
	Juice.add_pop_trauma(mini(n, 40))
