class_name WorkOrder
extends Control
## "Orden de trabajo": la próxima meta grande (siguiente herramienta o primer reciclado) y su
## progreso, en una hoja pinchada con una chinche.

var sim: GameSim
var title: String = ""
var ratio: float = 0.0
var detail: String = ""


func setup(p_sim: GameSim) -> void:
	sim = p_sim
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(300.0, 118.0)
	size = custom_minimum_size
	rotation = deg_to_rad(-1.2)
	pivot_offset = size * 0.5
	material = UiKit.paper_material()


func refresh() -> void:
	var s: GameState = sim.state
	var up: Upgrades = sim.upgrades
	var lang: String = Settings.language
	if up.phase_of(s) == 1 and s.level("unlock_palm") < 1:
		_set_goal(Tx.t("goal_palm"), s.pops, up.next_cost("unlock_palm", 0), lang)
	elif up.phase_of(s) == 1 and s.recycles == 0:
		var need: float = Prestige.pops_needed(1, Cfg.num(sim.eco, "pellet_divisor"), Cfg.num(sim.eco, "pellet_exponent"))
		_set_goal(Tx.t("goal_recycle"), s.pops_run, need, lang)
	elif up.phase_of(s) >= 2 and s.level("unlock_pin") < 1:
		_set_goal(Tx.t("goal_pin"), s.pops, up.next_cost("unlock_pin", 0), lang)
	else:
		var gain: int = sim.recycle_gain()
		var need2: float = Prestige.pops_needed(gain + 1, Cfg.num(sim.eco, "pellet_divisor"), Cfg.num(sim.eco, "pellet_exponent"))
		_set_goal(Tx.t("goal_next_pellet"), s.pops_run, need2, lang)
	queue_redraw()


func _set_goal(p_title: String, have: float, need: float, lang: String) -> void:
	title = p_title
	ratio = clampf(have / maxf(need, 1.0), 0.0, 1.0)
	detail = "%s / %s" % [NumberFormat.pops(have, lang), NumberFormat.pops(need, lang)]


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2(4.0, 8.0), Vector2(size.x - 10.0, size.y - 14.0))
	UiKit.draw_sheet(self, rect, UiKit.PAPER, "work_order", 0.5)
	# Chinche roja.
	draw_circle(Vector2(size.x * 0.5, 12.0), 7.0, Color(0, 0, 0, 0.25))
	draw_circle(Vector2(size.x * 0.5 - 1.0, 10.0), 7.0, UiKit.STAMP_RED)
	draw_circle(Vector2(size.x * 0.5 - 3.0, 8.0), 2.0, Color(1, 1, 1, 0.6))
	UiKit.draw_text(self, Vector2(20.0, 44.0), Tx.t("work_order"), UiKit.font_mono_bold(), 11, UiKit.INK_SOFT)
	UiKit.draw_text(self, Vector2(20.0, 68.0), title, UiKit.font_title(), 16, UiKit.INK)
	UiKit.draw_ink_bar(self, Rect2(Vector2(20.0, 82.0), Vector2(size.x - 48.0, 12.0)), ratio, UiKit.INK)
	UiKit.draw_text(self, Vector2(20.0, 112.0), detail, UiKit.font_mono(), 12, UiKit.INK)
	UiKit.draw_text(self, Vector2(size.x - 80.0, 112.0), "%d%%" % int(ratio * 100.0), UiKit.font_mono_bold(), 12, UiKit.STAMP_RED, HORIZONTAL_ALIGNMENT_RIGHT, 52.0)
