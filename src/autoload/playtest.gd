extends Node
## Modo playtest: pantalla completa, Alt+Enter, registro local de sesión (solo en disco).
## El registro se escribe en user://playtest/sesion_<fecha>.csv cada 10 s y al salir.

const FLUSH_SECONDS: float = 10.0

var enabled: bool = false ## true en builds playtest/release
var log: SessionLog = SessionLog.new()

var _start_ms: int = 0
var _since_flush: float = 0.0
var _path: String = ""
var _pending_volume: float = -1.0
var _volume_quiet: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)
	enabled = PlaytestMode.is_playtest(PlaytestMode.current_tags())
	if not enabled:
		return
	_start_ms = Time.get_ticks_msec()
	var stamp: String = Time.get_datetime_string_from_system()
	log.version = AppInfo.version()
	log.started_at = stamp
	DirAccess.make_dir_recursive_absolute("user://playtest")
	_path = "user://playtest/sesion_%s.csv" % stamp.replace(":", "-")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	Settings.volume_changed.connect(_on_volume_changed)
	write_now()


func now_s() -> float:
	return float(Time.get_ticks_msec() - _start_ms) / 1000.0


func _process(delta: float) -> void:
	if not enabled:
		return
	if _pending_volume >= 0.0:
		_volume_quiet += delta
		if _volume_quiet >= 1.0: # registra el valor final cuando deja de mover el control
			log.volume_changed(_pending_volume, now_s() - _volume_quiet)
			_pending_volume = -1.0
	_since_flush += delta
	if _since_flush >= FLUSH_SECONDS:
		write_now()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key: InputEventKey = event
		if key.pressed and not key.echo and key.alt_pressed and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER):
			toggle_fullscreen()
			get_viewport().set_input_as_handled()


func toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1600, 900))
		var screen: Vector2i = DisplayServer.screen_get_size()
		DisplayServer.window_set_position((screen - Vector2i(1600, 900)) / 2)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func write_now() -> void:
	_since_flush = 0.0
	if not enabled or _path.is_empty():
		return
	if _pending_volume >= 0.0:
		log.volume_changed(_pending_volume, now_s())
		_pending_volume = -1.0
	var f: FileAccess = FileAccess.open(_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(log.to_csv(now_s()))
	f.close()


func _on_volume_changed(_bus: String, value: float) -> void:
	_pending_volume = value
	_volume_quiet = 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		write_now()
		get_tree().quit()
