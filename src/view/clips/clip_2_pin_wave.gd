extends ClipBase
## Clip 2: ola del palo de amasar. Tres pasadas a lo largo de la lámina; el aire corre por
## delante y arma una ola de tensas.

var _pass: int = 0


func _init() -> void:
	duration = 13.0


func setup() -> void:
	make_sheet(70, 40, 2)
	precharge(1.38, 1.6, center(), 0.0, 1.0)
	tool_model.shape = "segment"
	tool_model.radius = 4.0
	tool_model.force_per_second = 6.0
	tool_model.air_share = 0.6
	tool_model.direction_bias = 2.5
	tool_model.drag_entry_fraction = 1.0
	tool_view.set_tool("rolling_pin", 4.0, 1, 1.0, 1.4)
	tool_view.snap_to(Vector2(2.0, 8.0))
	cam(Vector2(12.0, 14.0), 26.0)


## Posición del palo en el tiempo: tres pasadas rectas, de izquierda a derecha.
func _pin_position(time: float) -> Vector2:
	var span: float = 66.0
	var per_pass: float = 3.6
	var local: float = fmod(maxf(time - 0.8, 0.0), per_pass) / per_pass
	_pass = mini(int((time - 0.8) / per_pass), 2)
	var z: float = 7.0 + float(_pass) * 11.0
	return Vector2(2.0 + span * ease_io(local), z)


func script_step(time: float, delta: float) -> void:
	var pos: Vector2 = _pin_position(time)
	var active: bool = time > 0.8 and time < 0.8 + 3.0 * 3.6
	drive_tool(pos, active, delta)
	var look: Vector2 = Vector2(clampf(pos.x + 8.0, 14.0, 56.0), 15.0 + float(_pass) * 3.0)
	cam(look, lerpf(24.0, 32.0, ease_io(time / duration)))
