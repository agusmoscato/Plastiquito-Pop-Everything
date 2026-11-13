extends GutTest

var sheet: SheetModel
var grid: HexGrid
var tool_model: ToolModel
var _reloads: int = 0


func before_each() -> void:
	sheet = SheetModel.new(20, 20)
	grid = HexGrid.new(20, 20, 0.5)
	tool_model = ToolModel.new(sheet, grid)
	tool_model.force_per_second = 4.0
	tool_model.resistance = 1.0
	tool_model.recovery_per_second = 2.0
	tool_model.drag_entry_fraction = 1.0
	_reloads = 0


func _on_reload() -> void:
	_reloads += 1


func _one(idx: int) -> PackedInt32Array:
	return PackedInt32Array([idx])


func test_press_accumulates_without_popping() -> void:
	var c: int = grid.index(5, 5)
	tool_model.step(_one(c), 0.1)
	assert_almost_eq(sheet.get_press(c), 0.4, 0.0001)
	tool_model.step(_one(c), 0.1)
	assert_almost_eq(sheet.get_press(c), 0.8, 0.0001)
	assert_eq(sheet.get_state(c), SheetModel.STATE_INTACT)


func test_pops_exactly_at_threshold() -> void:
	var c: int = grid.index(5, 5)
	tool_model.step(_one(c), 0.1)
	tool_model.step(_one(c), 0.1)
	var popped: PackedInt32Array = tool_model.step(_one(c), 0.0499)
	assert_eq(popped.size(), 0, "justo debajo del umbral no revienta")
	popped = tool_model.step(_one(c), 0.0001 + 0.0002)
	assert_eq(popped, _one(c))
	assert_eq(sheet.get_state(c), SheetModel.STATE_POPPED)


func test_pops_when_force_equals_resistance_in_one_step() -> void:
	var c: int = grid.index(1, 1)
	var popped: PackedInt32Array = tool_model.step(_one(c), 0.25)
	assert_eq(popped, _one(c), "4.0 * 0.25 == 1.0 == resistencia")


func test_recovers_when_released() -> void:
	var c: int = grid.index(5, 5)
	tool_model.step(_one(c), 0.2)
	assert_almost_eq(sheet.get_press(c), 0.8, 0.0001)
	tool_model.step(PackedInt32Array(), 0.1)
	assert_almost_eq(sheet.get_press(c), 0.6, 0.0001)
	for k: int in 10:
		tool_model.step(PackedInt32Array(), 0.1)
	assert_eq(sheet.get_press(c), 0.0)
	assert_eq(tool_model.active_count(), 0)
	assert_eq(sheet.get_state(c), SheetModel.STATE_INTACT)


func test_drag_pops_every_cell_passed() -> void:
	var a: Vector2 = grid.cell_to_world(grid.index(2, 4))
	var b: Vector2 = grid.cell_to_world(grid.index(12, 4))
	tool_model.step(tool_model.cells_along(a, a), 0.016) # empieza apretando
	var path: PackedInt32Array = tool_model.cells_along(a, b)
	assert_eq(path.size(), 11)
	tool_model.step(path, 0.016)
	for q: int in range(3, 13):
		assert_eq(sheet.get_state(grid.index(q, 4)), SheetModel.STATE_POPPED, "q=%d" % q)


func test_drag_diagonal_leaves_no_gaps() -> void:
	var a: Vector2 = grid.cell_to_world(grid.index(1, 1))
	var b: Vector2 = grid.cell_to_world(grid.index(15, 14))
	var path: PackedInt32Array = tool_model.cells_along(a, b)
	for i: int in range(1, path.size()):
		assert_true(grid.neighbors(path[i - 1]).has(path[i]), "salto entre %d y %d" % [path[i - 1], path[i]])


func test_never_pops_same_bubble_twice() -> void:
	var c: int = grid.index(3, 3)
	var total: int = 0
	for k: int in 10:
		total += tool_model.step(_one(c), 0.5).size()
	assert_eq(total, 1)
	assert_eq(sheet.count_popped(), 1)
	assert_eq(tool_model.pop_cells(_one(c)).size(), 0)


func test_pop_cells_mass() -> void:
	var cells: PackedInt32Array = grid.cells_in_circle(Vector2(5.0, 5.0), 2.0)
	var out: PackedInt32Array = tool_model.pop_cells(cells)
	assert_eq(out.size(), cells.size())
	assert_eq(sheet.count_popped(), cells.size())
	assert_eq(tool_model.pop_cells(cells).size(), 0)


func test_reload_fires_at_threshold_once() -> void:
	sheet.reload_requested.connect(_on_reload)
	sheet.reload_threshold = 0.9
	for i: int in 359:
		sheet.pop(i)
	assert_eq(_reloads, 0, "359/400 = 0.8975")
	sheet.pop(359)
	assert_eq(_reloads, 1, "360/400 = 0.9 exacto")
	sheet.pop(360)
	assert_eq(_reloads, 1, "no se repite")
	sheet.reset(20, 20)
	for i: int in 360:
		sheet.pop(i)
	assert_eq(_reloads, 2, "tras reset vuelve a avisar")


func test_changed_signal_reports_pressed_cells() -> void:
	var got: Array[PackedInt32Array] = []
	sheet.cells_changed.connect(func(idx: PackedInt32Array) -> void: got.append(idx))
	var c: int = grid.index(4, 4)
	tool_model.step(_one(c), 0.1)
	assert_eq(got.size(), 1)
	assert_eq(got[0], _one(c))


func test_new_pressed_counts_squish_start() -> void:
	var c: int = grid.index(4, 4)
	tool_model.step(_one(c), 0.05)
	assert_eq(tool_model.new_pressed, 1)
	tool_model.step(_one(c), 0.05)
	assert_eq(tool_model.new_pressed, 0)
