extends Node3D
## Benchmark de dibujo: revienta círculos al azar (radio 3 a 10) cada frame durante 30 s.
## Variante "near": lámina 500x500 con la cámara cerca recorriéndola.
## Variante "far": lámina 1000x1000 con la cámara lejos (solo como dato).
## Resultados en user://benchmark.csv. Argumentos de usuario: --auto-quit  --seconds=N

const NEAR_SIZE: Vector2i = Vector2i(500, 500)
const FAR_SIZE: Vector2i = Vector2i(1000, 1000)

var world: ToyWorld
var duration: float = 30.0
var auto_quit: bool = false
var _label: Label
var _csv: FileAccess
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 5
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED) # medir sin tope de 60 fps
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--auto-quit":
			auto_quit = true
		elif arg.begins_with("--seconds="):
			duration = float(arg.trim_prefix("--seconds="))
	var layer: CanvasLayer = CanvasLayer.new()
	_label = Label.new()
	_label.position = Vector2(12.0, 12.0)
	layer.add_child(_label)
	add_child(layer)
	world = ToyWorld.new()
	add_child(world)
	await get_tree().process_frame
	_csv = FileAccess.open("user://benchmark.csv", FileAccess.WRITE)
	_csv.store_line("variant,frame,ms,draw_calls")
	var results: PackedStringArray = PackedStringArray()
	results.append(await _run("near", NEAR_SIZE, true))
	results.append(await _run("far", FAR_SIZE, false))
	_csv.close()
	var text: String = "\n".join(results)
	_label.text = text
	print(text)
	print("CSV: ", ProjectSettings.globalize_path("user://benchmark.csv"))
	if auto_quit:
		get_tree().quit()


func _run(variant: String, size: Vector2i, near: bool) -> String:
	var t_build: int = Time.get_ticks_msec()
	world.set_sheet_size(size.x, size.y)
	world.sheet.reload_threshold = 2.0 # que no recargue en medio de la medición
	var build_ms: int = Time.get_ticks_msec() - t_build
	await get_tree().process_frame
	await get_tree().process_frame
	var center: Vector2 = world.sheet_view.center()
	var ext: Vector2 = world.sheet_view.extents()
	var times: PackedFloat64Array = PackedFloat64Array()
	var draws: PackedFloat64Array = PackedFloat64Array()
	var start: int = Time.get_ticks_msec()
	var last: int = start
	var elapsed: float = 0.0
	while elapsed < duration:
		await get_tree().process_frame
		var now: int = Time.get_ticks_msec()
		var ms: float = float(now - last)
		last = now
		elapsed = float(now - start) / 1000.0
		_move_camera(near, center, ext, elapsed)
		_pop_random()
		var dc: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		times.append(ms)
		draws.append(float(dc))
		_csv.store_line("%s,%d,%.3f,%d" % [variant, times.size(), ms, dc])
		_label.text = "%s: %.0f / %.0f s" % [variant, elapsed, duration]
	return _summary(variant, size, build_ms, times, draws)


func _move_camera(near: bool, center: Vector2, ext: Vector2, t: float) -> void:
	if near:
		var k: float = t / duration
		var x: float = lerpf(ext.x * 0.1, ext.x * 0.9, k)
		var z: float = center.y + sin(k * TAU * 2.0) * ext.y * 0.3
		world.camera_rig.min_zoom = 3.0
		world.camera_rig.max_zoom = 4000.0
		world.camera_rig.focus(Vector2(x, z), 14.0)
	else:
		world.camera_rig.max_zoom = 4000.0
		world.camera_rig.focus(center, ext.x * 0.9)


func _pop_random() -> void:
	var g: HexGrid = world.grid
	var c: Vector2 = Vector2(_rng.randf_range(0.0, g.spacing * float(g.width)), _rng.randf_range(0.0, g.row_step * float(g.height)))
	world.tool_model.pop_cells(g.cells_in_circle(c, _rng.randf_range(3.0, 10.0)))


func _summary(variant: String, size: Vector2i, build_ms: int, times: PackedFloat64Array, draws: PackedFloat64Array) -> String:
	var sorted: PackedFloat64Array = times.duplicate()
	sorted.sort()
	var n: int = sorted.size()
	var total: float = 0.0
	for t: float in times:
		total += t
	var avg_ms: float = total / float(n)
	var p95: float = sorted[mini(n - 1, int(float(n) * 0.95))]
	var p99: float = sorted[mini(n - 1, int(float(n) * 0.99))]
	var dsum: float = 0.0
	for d: float in draws:
		dsum += d
	return "[%s %dx%d] build %d ms | fps prom %.1f | p1 low %.1f fps | frame prom %.2f ms | p95 %.2f ms | draw calls prom %.0f | frames %d" % [
		variant, size.x, size.y, build_ms, 1000.0 / avg_ms, 1000.0 / p99, avg_ms, p95, dsum / float(n), n]
