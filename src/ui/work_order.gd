class_name WorkOrder
extends Control
## "Orden de trabajo": la próxima meta grande y PARA QUÉ sirve, con su progreso, en una hoja
## pinchada con una chinche. Va guiando el arranque: mantener apretado, recarga automática, palma,
## primer reciclado (que abre el Piso) y después cada herramienta nueva.

var sim: GameSim
var title: String = ""
var ratio: float = 0.0
var detail: String = ""
var why: String = "" ## para qué sirve la meta (una línea)


func setup(p_sim: GameSim) -> void:
	sim = p_sim
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(318.0, 142.0)
	size = custom_minimum_size
	rotation = deg_to_rad(-1.2)
	pivot_offset = size * 0.5
	material = UiKit.paper_material()


func refresh() -> void:
	var s: GameState = sim.state
	var up: Upgrades = sim.upgrades
	var lang: String = Settings.language
	var goal: String = current_goal(sim)
	match goal:
		"hold", "reload", "palm", "pin", "iron", "hands", "boot":
			var id: String = GOAL_UPGRADE[goal]
			_set_goal(up.name_of(id, lang), s.pops, up.next_cost(id, up.level_of(s, id)), lang)
		"recycle":
			var need: float = Prestige.pops_needed(1, Cfg.num(sim.eco, "pellet_divisor"), Cfg.num(sim.eco, "pellet_exponent"))
			_set_goal(Tx.t("goal_recycle"), s.pops_run, need, lang)
		_:
			var gain: int = sim.recycle_gain()
			var need2: float = Prestige.pops_needed(gain + 1, Cfg.num(sim.eco, "pellet_divisor"), Cfg.num(sim.eco, "pellet_exponent"))
			_set_goal(Tx.t("goal_next_pellet"), s.pops_run, need2, lang)
	why = Tx.t("why_" + goal)
	queue_redraw()


const GOAL_UPGRADE: Dictionary = {"hold": "global_hold", "reload": "global_reload", "palm": "unlock_palm",
	"pin": "unlock_pin", "iron": "unlock_iron", "hands": "unlock_hands", "boot": "unlock_boot"}


## La meta que toca ahora, en orden: lo básico de la Mesa, el primer reciclado y luego la
## herramienta nueva de cada fase. Al final, juntar Pellets.
static func current_goal(p_sim: GameSim) -> String:
	var s: GameState = p_sim.state
	var up: Upgrades = p_sim.upgrades
	for goal: String in ["hold", "reload", "palm"]:
		var id: String = GOAL_UPGRADE[goal]
		if up.level_with_bonus(s, id) < 1 and not (goal == "reload" and p_sim.auto_reload()):
			return goal
	if up.phase_of(s) == 1:
		return "recycle"
	for goal: String in ["pin", "iron", "hands", "boot"]:
		var id: String = GOAL_UPGRADE[goal]
		if up.is_available(s, id) and up.level_with_bonus(s, id) < 1:
			return goal
	return "pellet"


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
	UiKit.draw_text(self, Vector2(20.0, 68.0), title.to_upper(), UiKit.font_title(), 16, UiKit.INK)
	UiKit.draw_text(self, Vector2(20.0, 88.0), why, UiKit.font_text(), 12, UiKit.INK_SOFT)
	UiKit.draw_ink_bar(self, Rect2(Vector2(20.0, 102.0), Vector2(size.x - 48.0, 12.0)), ratio, UiKit.STAMP_RED if ratio >= 1.0 else UiKit.INK)
	UiKit.draw_text(self, Vector2(20.0, 132.0), detail, UiKit.font_mono(), 12, UiKit.INK)
	UiKit.draw_text(self, Vector2(size.x - 80.0, 132.0), "%d%%" % int(ratio * 100.0), UiKit.font_mono_bold(), 12, UiKit.STAMP_RED, HORIZONTAL_ALIGNMENT_RIGHT, 52.0)
