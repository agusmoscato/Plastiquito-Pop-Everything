extends GutTest

const W: int = 12
const H: int = 10

var sheet: SheetModel
var grid: HexGrid
var chain: ChainSolver
var tool_model: ToolModel


func _make(seed_value: int, lo: float, hi: float, k: float, budget: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	sheet = SheetModel.new(W, H)
	grid = HexGrid.new(W, H, 0.5)
	for i: int in sheet.cell_count():
		sheet.pressure[i] = rng.randf_range(lo, hi)
		sheet.refresh_state(i)
	chain = ChainSolver.new(sheet, grid)
	chain.k = k
	chain.budget_per_frame = budget
	tool_model = ToolModel.new(sheet, grid)
	tool_model.resistance = 1.0


func test_chain_never_creates_air_fuzz() -> void:
	for seed_value: int in 1000:
		_make(seed_value, 0.5, 1.95, 0.9, 7)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value + 99999
		chain.enqueue(rng.randi() % sheet.cell_count())
		var total: float = sheet.total_pressure()
		var guard: int = 0
		while not chain.is_idle() and guard < 500:
			chain.step()
			var now: float = sheet.total_pressure()
			assert_true(now <= total + 0.0001, "seed %d: el aire subió %f -> %f" % [seed_value, total, now])
			total = now
			guard += 1
		if seed_value % 250 == 0:
			assert_true(chain.is_idle())


func test_direct_pop_never_creates_air_fuzz() -> void:
	for seed_value: int in 1000:
		_make(seed_value, 0.4, 2.0, 0.9, 40)
		var before: float = sheet.total_pressure()
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value
		for n: int in 5:
			chain.pop_now(rng.randi() % sheet.cell_count())
		assert_true(sheet.total_pressure() <= before + 0.0001)


func test_every_chain_terminates_even_with_max_k() -> void:
	for seed_value: int in 200:
		_make(seed_value, 1.9, 2.0, 1.0, 5)
		chain.enqueue(seed_value % sheet.cell_count())
		var frames: int = 0
		while not chain.is_idle():
			chain.step()
			frames += 1
			assert_true(frames <= sheet.cell_count(), "no terminó")
		assert_true(sheet.count_popped() <= sheet.cell_count())


func test_budget_per_frame_is_respected() -> void:
	_make(3, 1.99, 2.0, 0.9, 6)
	for i: int in sheet.cell_count():
		chain.enqueue(i)
	var frames: int = 0
	while not chain.is_idle():
		chain.clear_events()
		var done: int = chain.step()
		assert_true(done <= 6)
		assert_eq(chain.events_idx.size(), done)
		frames += 1
	assert_eq(frames, ceili(float(W * H) / 6.0), "la cadena se reparte en varios frames")
	assert_eq(sheet.count_popped(), W * H)


func test_never_pops_twice() -> void:
	_make(5, 1.9, 2.0, 0.9, 4)
	chain.enqueue(10)
	chain.enqueue(10)
	var seen: Dictionary = {}
	while not chain.is_idle():
		chain.step()
	for idx: int in chain.events_idx:
		assert_false(seen.has(idx), "reventó dos veces %d" % idx)
		seen[idx] = true
	assert_false(chain.pop_now(10), "ya reventada")


func test_chain_is_deterministic() -> void:
	var runs: Array[PackedInt32Array] = []
	for r: int in 2:
		_make(77, 1.5, 2.0, 0.8, 5)
		chain.enqueue(30)
		while not chain.is_idle():
			chain.step()
		runs.append(chain.events_idx.duplicate())
	assert_gt(runs[0].size(), 1)
	assert_eq(runs[0], runs[1])


func test_pop_releases_k_times_pressure_to_neighbors() -> void:
	_make(1, 1.0, 1.0, 0.6, 40)
	var c: int = grid.index(5, 5)
	var neighbors: PackedInt32Array = grid.neighbors(c)
	chain.pop_now(c)
	for n: int in neighbors:
		assert_almost_eq(sheet.pressure[n], 1.0 + 0.6 / 6.0, 0.0001)
	assert_eq(chain.events_idx.size(), 1)


func test_neighbor_reaching_max_is_queued_and_pops() -> void:
	_make(1, 1.0, 1.0, 0.9, 40)
	var c: int = grid.index(5, 5)
	var n: int = grid.neighbors(c)[0]
	sheet.pressure[n] = 1.99
	chain.pop_now(c)
	assert_false(chain.is_idle())
	chain.step()
	assert_eq(sheet.state[n], SheetModel.STATE_POPPED)


func test_tense_state_follows_pressure() -> void:
	_make(1, 1.0, 1.0, 0.5, 40)
	sheet.add_pressure_quiet(3, 0.6)
	assert_eq(sheet.state[3], SheetModel.STATE_TENSE)
	sheet.add_pressure_quiet(3, -0.3)
	assert_eq(sheet.state[3], SheetModel.STATE_INTACT)
	assert_eq(sheet.count_tense(), 0)
	sheet.add_pressure_quiet(3, 5.0)
	assert_eq(sheet.pressure[3], sheet.max_pressure)


func test_bomb_queues_radius_3() -> void:
	_make(1, 1.0, 1.0, 0.0, 1000)
	var c: int = grid.index(6, 5)
	sheet.type[c] = ChainSolver.TYPE_BOMB
	chain.pop_now(c)
	while not chain.is_idle():
		chain.step()
	var expected: PackedInt32Array = grid.cells_in_circle(grid.cell_to_world(c), 3.0 * grid.spacing + 0.01)
	for idx: int in expected:
		assert_eq(sheet.state[idx], SheetModel.STATE_POPPED)
	assert_eq(sheet.count_popped(), expected.size())


func test_line_pops_whole_row_outward() -> void:
	_make(1, 1.0, 1.0, 0.0, 3)
	var c: int = grid.index(5, 4)
	sheet.type[c] = ChainSolver.TYPE_LINE
	chain.pop_now(c)
	chain.clear_events()
	var first: int = chain.step()
	assert_eq(first, 3)
	var cols: Array[int] = []
	for idx: int in chain.events_idx:
		cols.append(grid.coords(idx).x)
	assert_true(cols.has(6) and cols.has(4), "sale en las dos direcciones")
	while not chain.is_idle():
		chain.step()
	for q: int in W:
		assert_eq(sheet.state[grid.index(q, 4)], SheetModel.STATE_POPPED)
	assert_eq(sheet.count_popped(), W)


func test_squeeze_moves_air_to_free_neighbors_and_conserves() -> void:
	_make(1, 1.0, 1.0, 0.5, 40)
	tool_model.air_share = 0.5
	var c: int = grid.index(5, 5)
	var before: float = sheet.total_pressure()
	tool_model.step(PackedInt32Array([c]), 0.05) # fuerza 8 * 0.05 = 0.4 de aplastamiento
	assert_lt(sheet.pressure[c], 1.0)
	for n: int in grid.neighbors(c):
		assert_gt(sheet.pressure[n], 1.0)
	assert_almost_eq(sheet.total_pressure(), before, 0.0001)


func test_squeeze_conserves_with_each_tool_fuzz() -> void:
	for seed_value: int in 200:
		_make(seed_value, 0.6, 1.8, 0.5, 40)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value
		tool_model.air_share = 0.6
		tool_model.direction_bias = 2.0
		tool_model.force_per_second = 4.0
		var shapes: Array[String] = ["single", "circle", "segment"]
		tool_model.shape = shapes[seed_value % 3]
		tool_model.radius = 1.5
		var before: float = sheet.total_pressure()
		var pos: Vector2 = Vector2(3.0, 2.0)
		for f: int in 6:
			var nxt: Vector2 = pos + Vector2(rng.randf_range(-0.8, 1.2), rng.randf_range(-0.5, 0.8))
			var cells: PackedInt32Array = tool_model.cells_for(pos, nxt)
			var popped: PackedInt32Array = tool_model.step(cells, 0.05, tool_model.last_weights, nxt - pos)
			assert_true(sheet.total_pressure() <= before + 0.0001)
			sheet.pop_many(popped)
			before = sheet.total_pressure()
			pos = nxt


func test_air_bias_pushes_ahead() -> void:
	_make(1, 1.0, 1.0, 0.5, 40)
	var c: int = grid.index(5, 5)
	var changed: PackedInt32Array = PackedInt32Array()
	AirModel.spread(sheet, grid, c, 0.6, Vector2(1.0, 0.0), 3.0, {}, changed)
	var ahead: int = grid.index(6, 5)
	var behind: int = grid.index(4, 5)
	assert_gt(sheet.pressure[ahead], sheet.pressure[behind])
	assert_almost_eq(sheet.total_pressure(), float(W * H) + 0.6, 0.0001)


func test_palm_center_cedes_first() -> void:
	_make(1, 1.0, 1.0, 0.5, 40)
	tool_model.shape = "circle"
	tool_model.radius = 1.6
	tool_model.center_falloff = 1.5
	var center: Vector2 = grid.cell_to_world(grid.index(5, 5))
	var cells: PackedInt32Array = tool_model.cells_for(center, center)
	assert_gt(cells.size(), 5)
	var center_idx: int = cells.find(grid.index(5, 5))
	var edge_w: float = tool_model.last_weights.size()
	assert_gt(tool_model.last_weights[center_idx], 2.0)
	var min_w: float = 99.0
	for w: float in tool_model.last_weights:
		min_w = minf(min_w, w)
	assert_lt(min_w, tool_model.last_weights[center_idx])
	assert_gt(edge_w, 0.0)


func test_roller_covers_strip_perpendicular_to_drag() -> void:
	_make(1, 1.0, 1.0, 0.5, 40)
	tool_model.shape = "segment"
	tool_model.radius = 2.0
	var a: Vector2 = grid.cell_to_world(grid.index(2, 3))
	var b: Vector2 = grid.cell_to_world(grid.index(8, 3))
	var cells: PackedInt32Array = tool_model.cells_for(a, b)
	var rows: Dictionary = {}
	for idx: int in cells:
		rows[grid.coords(idx).y] = true
	assert_gt(rows.size(), 2, "la franja abarca varias filas porque arrastra en horizontal")
	assert_almost_eq(tool_model.roller_direction().x, 1.0, 0.01)
