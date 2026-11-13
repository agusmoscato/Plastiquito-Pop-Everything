class_name NextBar
extends Control
## Siempre visible: la mejora más barata que todavía no se puede pagar, con su barra de progreso.
## Si todas se pueden pagar, avisa que hay algo listo para sellar.

var sim: GameSim
var upgrade_id: String = ""
var ratio: float = 0.0
var has_ready: bool = false

var _pulse: float = 0.0


func setup(p_sim: GameSim) -> void:
	sim = p_sim
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(520.0, 54.0)
	size = custom_minimum_size
	material = UiKit.paper_material()


func refresh() -> void:
	var best: String = ""
	var best_cost: float = INF
	var any_ready: bool = false
	for id: String in sim.upgrades.order:
		if sim.upgrades.is_perm(id) or not sim.upgrades.is_available(sim.state, id):
			continue
		var level: int = sim.state.level(id)
		if level >= sim.upgrades.max_level(id):
			continue
		var cost: float = sim.upgrades.next_cost(id, level)
		if cost <= sim.state.pops:
			any_ready = true
		elif cost < best_cost:
			best_cost = cost
			best = id
	has_ready = any_ready
	upgrade_id = best
	ratio = clampf(sim.state.pops / best_cost, 0.0, 1.0) if best != "" else 1.0


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2(4.0, 4.0), Vector2(size.x - 10.0, size.y - 10.0))
	UiKit.draw_sheet(self, rect, UiKit.PAPER, "next_bar", 0.5, 1.2)
	UiKit.draw_tape(self, rect.position + Vector2(6.0, 4.0), -0.6, 36.0, 13.0)
	var lang: String = Settings.language
	var head: String = Tx.t("next_order")
	UiKit.draw_text(self, Vector2(24.0, 22.0), head, UiKit.font_mono_bold(), 10, UiKit.INK_SOFT)
	var label: String = sim.upgrades.name_of(upgrade_id, lang) if upgrade_id != "" else "-"
	UiKit.draw_text(self, Vector2(24.0, 40.0), label.to_upper(), UiKit.font_title(), 14, UiKit.INK)
	UiKit.draw_ink_bar(self, Rect2(Vector2(size.x - 232.0, 22.0), Vector2(190.0, 14.0)), ratio, UiKit.STAMP_RED if has_ready else UiKit.INK)
	if has_ready:
		var a: float = 0.7 + 0.3 * sin(_pulse * 6.0)
		UiKit.draw_text(self, Vector2(size.x - 232.0, 47.0), Tx.t("ready"), UiKit.font_mono_bold(), 10, Color(UiKit.STAMP_RED.r, UiKit.STAMP_RED.g, UiKit.STAMP_RED.b, a))
	else:
		UiKit.draw_text(self, Vector2(size.x - 232.0, 47.0), "%d%%" % int(ratio * 100.0), UiKit.font_mono_bold(), 10, UiKit.INK)
