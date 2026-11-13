extends GutTest
## Solo informa tiempos; no falla por lentitud.


func test_circle_queries_on_1000x1000() -> void:
	var t0: int = Time.get_ticks_msec()
	var sheet: SheetModel = SheetModel.new(1000, 1000)
	var grid: HexGrid = HexGrid.new(1000, 1000, 0.5)
	var t_build: int = Time.get_ticks_msec() - t0

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	var max_x: float = grid.spacing * 999.0
	var max_z: float = grid.row_step * 999.0
	var total_cells: int = 0
	var t1: int = Time.get_ticks_usec()
	for k: int in 10000:
		var c: Vector2 = Vector2(rng.randf_range(0.0, max_x), rng.randf_range(0.0, max_z))
		var cells: PackedInt32Array = grid.cells_in_circle(c, 3.0)
		total_cells += cells.size()
		sheet.pop_many(cells)
	var t_query_ms: float = float(Time.get_ticks_usec() - t1) / 1000.0

	print("[PERF] crear lámina 1000x1000: %d ms" % t_build)
	print("[PERF] 10000 x (cells_in_circle r=3 + pop_many): %.1f ms (%.2f us/consulta, %d celdas)" % [
		t_query_ms, t_query_ms * 1000.0 / 10000.0, total_cells])
	assert_eq(sheet.cell_count(), 1000000)
	assert_gt(total_cells, 0)
