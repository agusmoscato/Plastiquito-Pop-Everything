class_name FutureTag
extends Control
## Mejora de un escenario futuro, grisada al final de la hoja de pedidos: "Próximamente en: <escenario>".

var sim: GameSim
var upgrade_id: String = ""
var phase: int = 2


func setup(p_sim: GameSim, id: String, p_phase: int) -> void:
	sim = p_sim
	upgrade_id = id
	phase = p_phase
	custom_minimum_size = Vector2(300.0, 36.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _draw() -> void:
	var lang: String = Settings.language
	var r: Rect2 = Rect2(Vector2(2.0, 2.0), size - Vector2(6.0, 4.0))
	UiKit.draw_sheet(self, r, UiKit.PAPER_SHADE, "future_" + upgrade_id, 0.0, 1.0)
	var title: String = sim.upgrades.name_of(upgrade_id, lang)
	UiKit.draw_text(self, Vector2(12.0, 18.0), title, UiKit.font_title(), UiKit.fit_size(UiKit.font_title(), title, 12, size.x - 28.0), UiKit.INK_SOFT)
	var where: String = Tx.t("future_in") % Tx.t("short_%d" % phase)
	UiKit.draw_text(self, Vector2(12.0, 31.0), where, UiKit.font_mono(), 9, UiKit.INK_SOFT)
