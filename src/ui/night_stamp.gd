class_name NightStamp
extends Control
## "TURNO NOCHE": sello de tinta que aparece cuando las Manitos trabajan solas (8 s sin tocar,
## DESIGN 3.5). Golpea al entrar y se borra suave al volver a tocar.

const SIZE: Vector2 = Vector2(250.0, 54.0)

var active: bool = false
var _alpha: float = 0.0
var _punch: float = 0.0


func setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	material = UiKit.paper_material()


func set_active(on: bool) -> void:
	if on and not active:
		_punch = 1.0
	active = on


func _process(delta: float) -> void:
	var target: float = 1.0 if active else 0.0
	_alpha = move_toward(_alpha, target, delta * (3.0 if active else 1.6)) # se borra más lento de lo que entra
	_punch = maxf(0.0, _punch - delta * 3.5)
	if _alpha > 0.0 or _punch > 0.0:
		queue_redraw()


func _draw() -> void:
	if _alpha <= 0.01:
		return
	var s: float = 1.0 + _punch * 0.22
	var r: Rect2 = Rect2(SIZE * 0.5 - SIZE * 0.5 * s, SIZE * s)
	UiKit.draw_stamp(self, r, Tx.t("night_shift"), UiKit.INK, 22, 0.05, _alpha * 0.9)
	UiKit.audit_box(self, Rect2(position + r.position, r.size), Tx.t("night_shift"), ChainStamp.AUDIT_LAYER) # en coordenadas del HUD
