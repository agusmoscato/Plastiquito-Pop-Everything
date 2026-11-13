extends GutTest

var grid: HexGrid


func before_each() -> void:
	grid = HexGrid.new(10, 8, 0.5)


func _sorted(arr: PackedInt32Array) -> Array[int]:
	var out: Array[int] = []
	for v: int in arr:
		out.append(v)
	out.sort()
	return out


func _brute(pred: Callable) -> Array[int]:
	var out: Array[int] = []
	for i: int in grid.cell_count():
		if pred.call(grid.cell_to_world(i)):
			out.append(i)
	return out


func test_index_coords_roundtrip() -> void:
	for i: int in grid.cell_count():
		var c: Vector2i = grid.coords(i)
		assert_true(grid.in_bounds(c.x, c.y))
		assert_eq(grid.index(c.x, c.y), i)


func test_in_bounds() -> void:
	assert_true(grid.in_bounds(0, 0))
	assert_true(grid.in_bounds(9, 7))
	assert_false(grid.in_bounds(-1, 0))
	assert_false(grid.in_bounds(0, -1))
	assert_false(grid.in_bounds(10, 0))
	assert_false(grid.in_bounds(0, 8))


func test_neighbors_center_even_row() -> void:
	var n: Array[int] = _sorted(grid.neighbors(grid.index(4, 4)))
	var expected: Array[int] = [
		grid.index(3, 3), grid.index(4, 3), grid.index(3, 4),
		grid.index(5, 4), grid.index(3, 5), grid.index(4, 5),
	]
	expected.sort()
	assert_eq(n, expected)


func test_neighbors_center_odd_row() -> void:
	var n: Array[int] = _sorted(grid.neighbors(grid.index(4, 3)))
	var expected: Array[int] = [
		grid.index(4, 2), grid.index(5, 2), grid.index(3, 3),
		grid.index(5, 3), grid.index(4, 4), grid.index(5, 4),
	]
	expected.sort()
	assert_eq(n, expected)


func test_neighbors_corners_and_edges() -> void:
	# odd-r: las filas impares van corridas a la derecha.
	# Fila 0 (par): esquina izquierda 2 vecinos, derecha 3.
	assert_eq(grid.neighbors(grid.index(0, 0)).size(), 2)
	assert_eq(grid.neighbors(grid.index(9, 0)).size(), 3)
	# Fila 7 (impar, última): izquierda 3, derecha 2.
	assert_eq(grid.neighbors(grid.index(0, 7)).size(), 3)
	assert_eq(grid.neighbors(grid.index(9, 7)).size(), 2)
	# Bordes laterales en filas par e impar.
	assert_eq(grid.neighbors(grid.index(0, 2)).size(), 3)
	assert_eq(grid.neighbors(grid.index(0, 3)).size(), 5)
	assert_eq(grid.neighbors(grid.index(9, 2)).size(), 5)
	assert_eq(grid.neighbors(grid.index(9, 3)).size(), 3)
	# Bordes superior/inferior.
	assert_eq(grid.neighbors(grid.index(5, 0)).size(), 4)
	assert_eq(grid.neighbors(grid.index(5, 7)).size(), 4)


func test_neighbors_symmetric_and_adjacent() -> void:
	for i: int in grid.cell_count():
		for n: int in grid.neighbors(i):
			assert_true(grid.neighbors(n).has(i), "vecino asimétrico %d-%d" % [i, n])
			var d: float = grid.cell_to_world(i).distance_to(grid.cell_to_world(n))
			assert_almost_eq(d, grid.spacing, 0.0001)


func test_world_to_cell_roundtrip_50x50() -> void:
	var big: HexGrid = HexGrid.new(50, 50, 0.5)
	for i: int in big.cell_count():
		assert_eq(big.world_to_cell(big.cell_to_world(i)), i)


func test_world_to_cell_out_of_bounds() -> void:
	assert_eq(grid.world_to_cell(Vector2(-5.0, 0.0)), -1)
	assert_eq(grid.world_to_cell(Vector2(0.0, -5.0)), -1)
	assert_eq(grid.world_to_cell(Vector2(500.0, 1.0)), -1)
	assert_eq(grid.world_to_cell(Vector2(1.0, 500.0)), -1)


func test_world_to_cell_nearest_center() -> void:
	var big: HexGrid = HexGrid.new(30, 30, 0.5)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for k: int in 500:
		var p: Vector2 = Vector2(rng.randf_range(1.0, 28.0), rng.randf_range(1.0, 40.0))
		var idx: int = big.world_to_cell(p)
		if idx < 0:
			continue
		var best: float = big.cell_to_world(idx).distance_to(p)
		for n: int in big.neighbors(idx):
			assert_true(best <= big.cell_to_world(n).distance_to(p) + 0.0001)


func test_circle_single_cell_and_neighbors() -> void:
	var c: int = grid.index(4, 4)
	var center: Vector2 = grid.cell_to_world(c)
	assert_eq(_sorted(grid.cells_in_circle(center, 0.1)), [c] as Array[int])
	var ring: Array[int] = _sorted(grid.cells_in_circle(center, grid.spacing + 0.001))
	var expected: Array[int] = _sorted(grid.neighbors(c))
	expected.append(c)
	expected.sort()
	assert_eq(ring, expected)


func test_circle_matches_brute_force() -> void:
	var center: Vector2 = Vector2(2.3, 3.1)
	for radius: float in [0.4, 1.0, 2.5, 4.0]:
		var expected: Array[int] = _brute(func(p: Vector2) -> bool: return p.distance_to(center) <= radius)
		assert_eq(_sorted(grid.cells_in_circle(center, radius)), expected, "radio %s" % radius)


func test_circle_clipped_at_borders() -> void:
	var res: PackedInt32Array = grid.cells_in_circle(Vector2(-1.0, -1.0), 3.0)
	for i: int in res:
		assert_true(i >= 0 and i < grid.cell_count())
	var huge: PackedInt32Array = grid.cells_in_circle(Vector2(3.0, 3.0), 1000.0)
	assert_eq(huge.size(), grid.cell_count())


func test_segment_matches_brute_force() -> void:
	var a: Vector2 = Vector2(0.5, 1.0)
	var b: Vector2 = Vector2(8.0, 5.5)
	var hw: float = 0.9
	var expected: Array[int] = _brute(func(p: Vector2) -> bool: return _dist_to_segment(p, a, b) <= hw)
	assert_eq(_sorted(grid.cells_in_segment(a, b, hw)), expected)


func test_segment_horizontal_strip() -> void:
	var r: int = 3
	var a: Vector2 = grid.cell_to_world(grid.index(1, r))
	var b: Vector2 = grid.cell_to_world(grid.index(6, r))
	var res: Array[int] = _sorted(grid.cells_in_segment(a, b, 0.1))
	var expected: Array[int] = []
	for q: int in range(1, 7):
		expected.append(grid.index(q, r))
	assert_eq(res, expected)


func test_segment_degenerate_is_circle() -> void:
	var p: Vector2 = Vector2(3.0, 2.0)
	assert_eq(_sorted(grid.cells_in_segment(p, p, 1.2)), _sorted(grid.cells_in_circle(p, 1.2)))


func test_rect_matches_brute_force() -> void:
	var center: Vector2 = Vector2(4.013, 3.517)
	var size: Vector2 = Vector2(5.03, 2.07)
	for rot: float in [0.0, 0.4, PI / 2.0, 2.0]:
		var expected: Array[int] = _brute(func(p: Vector2) -> bool: return _in_rect(p, center, size, rot))
		assert_eq(_sorted(grid.cells_in_rect(center, size, rot)), expected, "rot %s" % rot)


func test_rect_simple_axis_aligned() -> void:
	var c: int = grid.index(4, 4)
	var res: Array[int] = _sorted(grid.cells_in_rect(grid.cell_to_world(c), Vector2(0.2, 0.2), 0.0))
	assert_eq(res, [c] as Array[int])


func test_shapes_never_out_of_range() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	for k: int in 200:
		var p: Vector2 = Vector2(rng.randf_range(-20.0, 30.0), rng.randf_range(-20.0, 30.0))
		var q: Vector2 = Vector2(rng.randf_range(-20.0, 30.0), rng.randf_range(-20.0, 30.0))
		var all: Array[PackedInt32Array] = [
			grid.cells_in_circle(p, rng.randf_range(0.0, 8.0)),
			grid.cells_in_segment(p, q, rng.randf_range(0.0, 3.0)),
			grid.cells_in_rect(p, Vector2(rng.randf_range(0.0, 9.0), rng.randf_range(0.0, 9.0)), rng.randf_range(-3.2, 3.2)),
		]
		for res: PackedInt32Array in all:
			var seen: Dictionary = {}
			for i: int in res:
				assert_true(i >= 0 and i < grid.cell_count())
				assert_false(seen.has(i), "índice repetido")
				seen[i] = true


func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _in_rect(p: Vector2, center: Vector2, size: Vector2, rot: float) -> bool:
	var local: Vector2 = (p - center).rotated(-rot)
	return absf(local.x) <= size.x * 0.5 and absf(local.y) <= size.y * 0.5
