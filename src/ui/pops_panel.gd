class_name PopsPanel
extends Control
## Arriba a la izquierda: el contador de Pops (odómetro) sobre una chapa de cartón.

var sim: GameSim
var odometer: Odometer
var rate_text: String = ""

var _flash: float = 0.0


func setup(p_sim: GameSim) -> void:
	sim = p_sim
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(380.0, 128.0)
	size = custom_minimum_size
	material = UiKit.paper_material(0.05)
	odometer = Odometer.new()
	odometer.position = Vector2(22.0, 52.0)
	add_child(odometer)


func odometer_center() -> Vector2:
	return global_position + odometer.position + odometer.size * 0.5


func pulse() -> void:
	_flash = 1.0


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 4.0)
	queue_redraw()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2(4.0, 4.0), Vector2(size.x - 10.0, size.y - 10.0))
	UiKit.draw_sheet(self, rect, UiKit.KRAFT, "pops_panel", 1.0 + _flash * 3.0, 2.0)
	UiKit.draw_tape(self, rect.position + Vector2(18.0, 4.0), -0.45)
	UiKit.draw_tape(self, Vector2(rect.end.x - 18.0, rect.position.y + 4.0), 0.5)
	UiKit.draw_text(self, Vector2(22.0, 38.0), Tx.t("dept"), UiKit.font_mono_bold(), 12, UiKit.CARDBOARD_DARK)
	UiKit.draw_text(self, Vector2(22.0, 114.0), Tx.t("pops"), UiKit.font_title(), 14, UiKit.INK)
	UiKit.draw_text(self, Vector2(88.0, 114.0), rate_text, UiKit.font_mono(), 12, UiKit.INK)
	if sim != null and sim.state.pellets > 0.0:
		var p: String = "%s %s" % [Tx.t("pellets"), NumberFormat.pops(sim.state.pellets, Settings.language)]
		UiKit.draw_text(self, Vector2(size.x - 188.0, 114.0), p, UiKit.font_mono_bold(), 12, UiKit.INK, HORIZONTAL_ALIGNMENT_RIGHT, 160.0)
