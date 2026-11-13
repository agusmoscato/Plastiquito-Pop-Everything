extends ClipBase
## Clip 1: una burbuja de cerca; el dedo la aprieta y revienta; la cámara se aleja hasta mostrar
## la lámina de 150x150 reventando en cadena.

var _target_cell: Vector2 = Vector2.ZERO
var _far: float = 100.0


func _init() -> void:
	duration = 15.0


func setup() -> void:
	make_sheet(150, 150, 2)
	_target_cell = center()
	precharge(1.22, 1.62, _target_cell, 22.0, 1.82)
	scatter_specials(0.004)
	_far = fit_distance()
	tool_model.shape = "single"
	tool_model.force_per_second = 6.0
	tool_model.air_share = 0.5
	tool_model.drag_entry_fraction = 1.0
	tool_view.set_tool("finger", 0.0, 0, 0.5)
	tool_view.snap_to(_target_cell)
	cam(_target_cell, 5.5)


func script_step(time: float, delta: float) -> void:
	# 0-0.8 s: planos de cerca; 0.8-1.6 s: el dedo aprieta la burbuja del centro.
	var pressing: bool = time > 0.8 and time < 2.4
	drive_tool(_target_cell, pressing, delta)
	var k: float = ease_io((time - 1.8) / 9.0)
	var dist: float = lerpf(5.5, _far * 1.02, k)
	var drift: Vector2 = Vector2(sin(time * 0.35) * 0.6, 0.0) * (1.0 - k)
	cam(_target_cell + drift + Vector2(0.0, lerpf(0.0, 1.0, k) * -8.0), dist)
