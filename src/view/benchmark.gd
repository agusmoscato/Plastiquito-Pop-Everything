extends Node3D
## Benchmark de dibujo (Fase 3). Variantes:
##   a) 500x500 con la cámara cerca recorriendo la lámina, círculos al azar de radio 3 a 10 por frame.
##   b) 1000x1000 con la cámara lejos y cadenas masivas (círculos de radio 10 a 24 por frame).
##   c) 1000x1000 con zoom de cerca a lejos en 5 s (y de vuelta), círculos de radio 3 a 10.
## Argumentos de usuario (después de "--"): --variant=a|b|c|all  --seconds=N  --auto-quit
## La resolución se elige con el argumento de Godot --resolution WxH (Steam Deck: 1280x800).
## Resultados en user://benchmark.csv (una fila por frame) y un resumen en consola.

const NEAR_SIZE: Vector2i = Vector2i(500, 500)
const FAR_SIZE: Vector2i = Vector2i(1000, 1000)
const ZOOM_NEAR: float = 14.0

var world: ToyWorld
var duration: float = 20.0
var auto_quit: bool = false
var variants: PackedStringArray = PackedStringArray(["a", "b", "c"])
var _label: Label
var _shot_dir: String = ""
var _shots_done: int = 0
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
		elif arg.begins_with("--shots="):
			_shot_dir = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(_shot_dir)
		elif arg.begins_with("--variant="):
			var v: String = arg.trim_prefix("--variant=")
			if v != "all":
				variants = PackedStringArray([v])
	var layer: CanvasLayer = CanvasLayer.new()
	_label = Label.new()
	_label.position = Vector2(12.0, 12.0)
	layer.add_child(_label)
	add_child(layer)
	world = ToyWorld.new()
	add_child(world)
	await get_tree().process_frame
	var win: Vector2i = DisplayServer.window_get_size()
	_csv = FileAccess.open("user://benchmark.csv", FileAccess.WRITE)
	_csv.store_line("variant,window,frame,ms,draw_calls")
	var results: PackedStringArray = PackedStringArray()
	for v: String in variants:
		results.append(await _run(v, "%dx%d" % [win.x, win.y]))
	_csv.close()
	var text: String = "\n".join(results)
	_label.text = text
	print(text)
	print("CSV: ", ProjectSettings.globalize_path("user://benchmark.csv"))
	if auto_quit:
		get_tree().quit()


func _run(variant: String, res_text: String) -> String:
	var size: Vector2i = NEAR_SIZE if variant == "a" else FAR_SIZE
	var t_build: int = Time.get_ticks_msec()
	world.set_sheet_size(size.x, size.y)
	world.sheet.reload_threshold = 2.0 # que no recargue en medio de la medición
	var build_ms: int = Time.get_ticks_msec() - t_build
	await get_tree().process_frame
	await get_tree().process_frame
	var center: Vector2 = world.sheet_view.center()
	var ext: Vector2 = world.sheet_view.extents()
	var run_seconds: float = 15.0 if variant == "c" else duration
	var times: PackedFloat64Array = PackedFloat64Array()
	var draws: PackedFloat64Array = PackedFloat64Array()
	var view_us: float = 0.0
	var sim_us: float = 0.0
	_shots_done = 0
	var warm: float = 0.0
	while warm < 2.0: # calentamiento: compilación de shaders y primeras subidas de texturas
		await get_tree().process_frame
		_move_camera(variant, center, ext, 0.0, run_seconds)
		_pop_random(variant)
		warm += 1.0 / 60.0
	var start: int = Time.get_ticks_usec()
	var last: int = start
	var elapsed: float = 0.0
	while elapsed < run_seconds:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		var ms: float = float(now - last) / 1000.0
		last = now
		elapsed = float(now - start) / 1000000.0
		_move_camera(variant, center, ext, elapsed, run_seconds)
		var tp: int = Time.get_ticks_usec()
		_pop_random(variant)
		sim_us += float(Time.get_ticks_usec() - tp)
		view_us += float(world.sheet_view.last_process_us)
		var dc: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		times.append(ms)
		draws.append(float(dc))
		_csv.store_line("%s,%s,%d,%.3f,%d" % [variant, res_text, times.size(), ms, dc])
		_label.text = "%s: %.0f / %.0f s" % [variant, elapsed, run_seconds]
		if _shot_dir != "" and elapsed > float(_shots_done + 1) * run_seconds / 8.0 and _shots_done < 7:
			_shots_done += 1
			get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [_shot_dir, variant, _shots_done])
	var extra: String = " | pop sim %.2f ms | vista %.2f ms" % [sim_us / 1000.0 / float(times.size()), view_us / 1000.0 / float(times.size())]
	return _summary(variant, res_text, size, build_ms, times, draws) + extra


func _move_camera(variant: String, center: Vector2, ext: Vector2, t: float, total: float) -> void:
	var cam: CameraRig = world.camera_rig
	cam.min_zoom = 3.0
	cam.max_zoom = 4000.0
	if variant == "a":
		var k: float = t / total
		var x: float = lerpf(ext.x * 0.1, ext.x * 0.9, k)
		var z: float = center.y + sin(k * TAU * 2.0) * ext.y * 0.3
		cam.focus(Vector2(x, z), ZOOM_NEAR)
	elif variant == "b":
		cam.focus(center, ext.x * 0.9)
	else:
		# Zoom de cerca a lejos en 5 s, y de vuelta en otros 5 s (ida y vuelta, 15 s en total).
		var phase: float = fmod(t, 10.0)
		var k2: float = phase / 5.0 if phase < 5.0 else 2.0 - phase / 5.0
		var eased: float = k2 * k2 * (3.0 - 2.0 * k2)
		var dist: float = exp(lerpf(log(ZOOM_NEAR), log(ext.x * 0.9), eased))
		cam.focus(center, dist)


func _pop_random(variant: String) -> void:
	var g: HexGrid = world.grid
	var c: Vector2 = Vector2(_rng.randf_range(0.0, g.spacing * float(g.width)), _rng.randf_range(0.0, g.row_step * float(g.height)))
	var r: float = _rng.randf_range(10.0, 24.0) if variant == "b" else _rng.randf_range(3.0, 10.0)
	world.tool_model.pop_cells(g.cells_in_circle(c, r))


func _summary(variant: String, res_text: String, size: Vector2i, build_ms: int, times: PackedFloat64Array, draws: PackedFloat64Array) -> String:
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
	return "[%s %s %dx%d] build %d ms | fps prom %.1f | p1 low %.1f fps | frame prom %.2f ms | p95 %.2f ms | draw calls prom %.0f | frames %d" % [
		variant, res_text, size.x, size.y, build_ms, 1000.0 / avg_ms, 1000.0 / p99, avg_ms, p95, dsum / float(n), n]
