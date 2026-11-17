extends ClipBase
## Clip 5: la bota en el Estacionamiento. Tres pisotones sobre una lámina cargada de tensas: cada uno
## abre un cráter con onda expansiva, polvo radial y burbujas que saltan, y la cadena sigue sola.
## Usa el pisotón real del ToolModel (forma "stomp", onda pagada con el aire de lo pisado).

const STOMPS: Array[float] = [1.6, 5.2, 8.8]
const BOOT_RADIUS: float = 3.0

var _done: int = 0
var _targets: Array[Vector2] = []


func _init() -> void:
	duration = 13.0


func setup() -> void:
	make_sheet(60, 40, 4)
	precharge(1.36, 1.62, center(), 0.0, 1.0)
	var eco: Dictionary = world.db.economy
	tool_model.shape = ToolModel.SHAPE_STOMP
	tool_model.radius = BOOT_RADIUS
	tool_model.cooldown = 0.5
	tool_model.wave_k = Cfg.num(eco, "boot_wave_k")
	tool_model.wave_reach = Cfg.num(eco, "boot_wave_reach")
	var c: Vector2 = center()
	_targets = [c + Vector2(-14.0, -3.0), c + Vector2(0.0, 4.0), c + Vector2(14.0, -2.0)]
	tool_view.set_tool("boot", BOOT_RADIUS, 0, 1.0, 2.0)
	tool_view.snap_to(_targets[0] + Vector2(-6.0, 0.0))
	cam(c, 34.0)


func script_step(time: float, delta: float) -> void:
	tool_model.tick_cooldown(delta)
	var i: int = mini(_done, _targets.size() - 1)
	var target: Vector2 = _targets[i]
	tool_view.set_cursor(target)
	if _done < STOMPS.size() and time >= STOMPS[_done]:
		var popped: PackedInt32Array = tool_model.stomp(target, chain.k)
		for idx: int in popped:
			chain.pop_now(idx)
		for idx: int in tool_model.last_wave_cells:
			if sheet.pressure[idx] >= 2.0 and sheet.state[idx] != SheetModel.STATE_POPPED:
				chain.pop_now(idx)
		tool_view.set_pressing(true)
		tool_view.bounce(2.0)
		Juice.add_pop_trauma(popped.size() * 3)
		if Juice.fx != null:
			Juice.fx.stomp_at(Vector3(target.x, 0.2, target.y), BOOT_RADIUS)
		_done += 1
	elif _done > 0 and time >= STOMPS[_done - 1] + 0.25:
		tool_view.set_pressing(false)
	var k: float = ease_io(time / duration)
	cam(center() + Vector2(lerpf(-6.0, 6.0, k), 0.0), lerpf(30.0, 40.0, k))
