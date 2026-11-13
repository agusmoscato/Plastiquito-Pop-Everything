class_name SheetView
extends Node3D
## Dibuja la lámina con MultiMeshInstance3D en bloques de 64x64 celdas.
## Solo lee el estado de SheetModel. Datos por instancia (INSTANCE_CUSTOM):
## r = presión - 1, g = aplastamiento 0..1, b = progreso de reventón, a = tipo.

const CHUNK: int = 64
const FLOATS_PER_INSTANCE: int = 16 ## 12 de transform + 4 de custom data
const FAR_AWAY: float = 1.0e9

var sheet: SheetModel
var grid: HexGrid
var material: ShaderMaterial

var _resistance: float = 1.0
var _chunks_x: int = 0
var _chunks_y: int = 0
var _multimeshes: Array[MultiMesh] = []
var _nodes: Array[MultiMeshInstance3D] = []
var _plane: MeshInstance3D
var _mesh: ArrayMesh

var _dirty: Dictionary = {} ## idx -> true
var _anims: Dictionary = {} ## idx -> Vector2(segundos, aplastamiento al reventar)
var _popped_shown: PackedByteArray = PackedByteArray()
var _squash_shown: PackedFloat32Array = PackedFloat32Array()

var _anim_seconds: float = 0.19
var _roll_t: float = -1.0
var _roll_seconds: float = 0.8
var _roll_end_z: float = 0.0


func _init() -> void:
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/bubble.gdshader") as Shader


## Conecta la vista con una lámina. `juice` es data/juice.json["juice"].
func bind(p_sheet: SheetModel, p_grid: HexGrid, juice: Dictionary, resistance: float) -> void:
	if sheet != null and sheet.cells_changed.is_connected(_on_cells_changed):
		sheet.cells_changed.disconnect(_on_cells_changed)
	sheet = p_sheet
	grid = p_grid
	_resistance = resistance
	var inflate_ms: float = float(Cfg.integer(juice, "pop_anim_inflate_ms"))
	var collapse_ms: float = float(Cfg.integer(juice, "pop_anim_collapse_ms"))
	_anim_seconds = (inflate_ms + collapse_ms) / 1000.0
	material.set_shader_parameter("pop_split", inflate_ms / (inflate_ms + collapse_ms))
	material.set_shader_parameter("pop_inflate", Cfg.num(juice, "pop_anim_inflate_amount"))
	material.set_shader_parameter("popped_height", Cfg.num(juice, "popped_height"))
	_roll_seconds = Cfg.num(juice, "roll_in_seconds")
	sheet.cells_changed.connect(_on_cells_changed)
	rebuild()


func chunk_count() -> int:
	return _multimeshes.size()


func pending_updates() -> int:
	return _dirty.size() + _anims.size()


## Centro de la lámina en el plano XZ.
func center() -> Vector2:
	return Vector2(grid.spacing * (float(grid.width) - 0.5) * 0.5, grid.row_step * float(grid.height - 1) * 0.5)


func extents() -> Vector2:
	return Vector2(grid.spacing * float(grid.width), grid.row_step * float(grid.height) + grid.hex_size)


func rebuild() -> void:
	for n: MultiMeshInstance3D in _nodes:
		n.queue_free()
	_nodes.clear()
	_multimeshes.clear()
	_dirty.clear()
	_anims.clear()
	_popped_shown = PackedByteArray()
	_popped_shown.resize(sheet.cell_count())
	_squash_shown = PackedFloat32Array()
	_squash_shown.resize(sheet.cell_count())
	_mesh = BubbleMesh.build(grid.bubble_radius * 0.94)
	_chunks_x = ceili(float(grid.width) / float(CHUNK))
	_chunks_y = ceili(float(grid.height) / float(CHUNK))
	for cy: int in _chunks_y:
		for cx: int in _chunks_x:
			_build_chunk(cx, cy)
	_build_plane()
	material.set_shader_parameter("reveal_z", FAR_AWAY)
	_roll_t = -1.0


## Vuelve a pintar toda la lámina (después de sheet.reset) y arranca el rollo.
func refresh_all(roll_in: bool) -> void:
	_anims.clear()
	_dirty.clear()
	_popped_shown.fill(0)
	_squash_shown.fill(0.0)
	for idx: int in sheet.cell_count():
		_write_cell(idx)
	if roll_in:
		begin_roll_in()


func begin_roll_in() -> void:
	_roll_t = 0.0
	_roll_end_z = grid.row_step * float(grid.height) + 4.0
	material.set_shader_parameter("reveal_z", -2.0)


func _process(delta: float) -> void:
	if sheet == null:
		return
	_advance_roll(delta)
	_advance_anims(delta)
	_flush_dirty()


func _on_cells_changed(indices: PackedInt32Array) -> void:
	for idx: int in indices:
		_dirty[idx] = true
		if sheet.state[idx] == SheetModel.STATE_POPPED and _popped_shown[idx] == 0:
			_popped_shown[idx] = 1
			_anims[idx] = Vector2(0.0, _squash_shown[idx])


func _advance_roll(delta: float) -> void:
	if _roll_t < 0.0:
		return
	_roll_t += delta
	var k: float = clampf(_roll_t / _roll_seconds, 0.0, 1.0)
	var eased: float = k * k * (3.0 - 2.0 * k)
	material.set_shader_parameter("reveal_z", lerpf(-2.0, _roll_end_z, eased))
	if k >= 1.0:
		_roll_t = -1.0
		material.set_shader_parameter("reveal_z", FAR_AWAY)


func _advance_anims(delta: float) -> void:
	var finished: Array[int] = []
	for key: Variant in _anims:
		var idx: int = key
		var a: Vector2 = _anims[idx]
		a.x += delta
		_dirty[idx] = true
		if a.x >= _anim_seconds:
			finished.append(idx)
		else:
			_anims[idx] = a
	for idx: int in finished:
		_anims.erase(idx)


func _flush_dirty() -> void:
	if _dirty.is_empty():
		return
	for key: Variant in _dirty:
		var idx: int = key
		_write_cell(idx)
	_dirty.clear()


func _write_cell(idx: int) -> void:
	var squash: float = clampf(sheet.press[idx] / _resistance, 0.0, 1.0)
	var pop: float = 0.0
	if _popped_shown[idx] == 1:
		pop = 1.0
		squash = 0.0
		if _anims.has(idx):
			var a: Vector2 = _anims[idx]
			pop = clampf(a.x / _anim_seconds, 0.001, 1.0)
			squash = a.y * (1.0 - pop)
	else:
		_squash_shown[idx] = squash
	var color: Color = Color(sheet.pressure[idx] - 1.0, squash, pop, float(sheet.type[idx]))
	var loc: Vector2i = _locate(idx)
	_multimeshes[loc.x].set_instance_custom_data(loc.y, color)


## (índice de bloque, índice de instancia dentro del bloque) de una celda.
func _locate(idx: int) -> Vector2i:
	var c: Vector2i = grid.coords(idx)
	@warning_ignore("integer_division")
	var cx: int = c.x / CHUNK
	@warning_ignore("integer_division")
	var cy: int = c.y / CHUNK
	var chunk_w: int = mini(CHUNK, grid.width - cx * CHUNK)
	return Vector2i(cy * _chunks_x + cx, (c.y - cy * CHUNK) * chunk_w + (c.x - cx * CHUNK))


func _build_chunk(cx: int, cy: int) -> void:
	var q0: int = cx * CHUNK
	var r0: int = cy * CHUNK
	var w: int = mini(CHUNK, grid.width - q0)
	var h: int = mini(CHUNK, grid.height - r0)
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(w * h * FLOATS_PER_INSTANCE)
	var spacing: float = grid.spacing
	var row_step: float = grid.row_step
	var base: int = 0
	for lr: int in h:
		var r: int = r0 + lr
		var shift: float = 0.5 * float(r & 1)
		var z: float = row_step * float(r)
		for lq: int in w:
			buf[base] = 1.0
			buf[base + 3] = spacing * (float(q0 + lq) + shift)
			buf[base + 5] = 1.0
			buf[base + 10] = 1.0
			buf[base + 11] = z
			base += FLOATS_PER_INSTANCE
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _mesh
	mm.instance_count = w * h
	mm.buffer = buf
	var margin: float = spacing
	mm.custom_aabb = AABB(
		Vector3(spacing * float(q0) - margin, -0.2, row_step * float(r0) - margin),
		Vector3(spacing * float(w) + 2.0 * margin, 2.0, row_step * float(h) + 2.0 * margin))
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.name = "Chunk_%d_%d" % [cx, cy]
	node.multimesh = mm
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	_nodes.append(node)
	_multimeshes.append(mm)


func _build_plane() -> void:
	if _plane != null:
		_plane.queue_free()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = extents() + Vector2(grid.spacing, grid.spacing)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.55, 0.8, 1.0, 0.16)
	m.roughness = 0.08
	m.metallic_specular = 1.0
	m.render_priority = -1
	pm.material = m
	_plane = MeshInstance3D.new()
	_plane.name = "BasePlane"
	_plane.mesh = pm
	_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var c: Vector2 = center()
	_plane.position = Vector3(c.x, -0.01, c.y)
	add_child(_plane)
