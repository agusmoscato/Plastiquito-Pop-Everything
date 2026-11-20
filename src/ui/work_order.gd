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
var reqs: Array[Dictionary] = [] ## requisitos para abrir el escenario siguiente, con check o cruz


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
		"phase":
			var cost: float = sim.next_phase_cost()
			title = Tx.t("goal_phase") % Tx.t("phase_%d" % (up.phase_of(s) + 1))
			var have: float = s.pellets + float(sim.recycle_gain())
			ratio = clampf(have / maxf(cost, 1.0), 0.0, 1.0)
			detail = "%d / %d %s" % [int(have), int(cost), Tx.t("pellets")]
		_:
			var gain: int = sim.recycle_gain()
			var need2: float = Prestige.pops_needed(gain + 1, Cfg.num(sim.eco, "pellet_divisor"), Cfg.num(sim.eco, "pellet_exponent"))
			_set_goal(Tx.t("goal_next_pellet"), s.pops_run, need2, lang)
	why = Tx.t("why_" + goal)
	if goal == "phase" and sim.next_phase_ready():
		why = Tx.t("why_phase_ready")
	reqs = [] if goal in ["hold", "reload", "palm"] else sim.phase_requirements()
	if not (goal in ["hold", "reload", "palm"]) and sim.nothing_left_to_buy():
		why = Tx.t("nothing_left") % Tx.t("client_%d" % sim.phase())
	elif goal == "phase" and not reqs.is_empty() and not sim.phase_gate_ok():
		why = Tx.t("why_requirements")
	size.y = 142.0 + 17.0 * float(reqs.size()) + (6.0 if not reqs.is_empty() else 0.0)
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
		return "recycle" if s.recycles == 0 else "phase"
	for goal: String in ["pin", "iron", "hands", "boot"]:
		var id: String = GOAL_UPGRADE[goal]
		if up.is_available(s, id) and up.level_with_bonus(s, id) < 1:
			return goal
	if p_sim.next_phase_cost() > 0.0:
		return "phase"
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
	var lang: String = Settings.language
	for i: int in reqs.size():
		var ok: bool = reqs[i]["ok"] == true
		var y: float = 152.0 + 17.0 * float(i)
		var mark: Vector2 = Vector2(28.0, y - 4.0)
		if ok:
			draw_polyline(PackedVector2Array([mark + Vector2(-5.0, 0.0), mark + Vector2(-1.0, 4.0), mark + Vector2(6.0, -5.0)]), Color("#2F7A4C"), 2.2)
		else:
			draw_line(mark + Vector2(-4.0, -4.0), mark + Vector2(4.0, 4.0), UiKit.STAMP_RED, 2.2)
			draw_line(mark + Vector2(-4.0, 4.0), mark + Vector2(4.0, -4.0), UiKit.STAMP_RED, 2.2)
		var line: String = str(reqs[i][lang])
		UiKit.draw_text(self, Vector2(42.0, y), line, UiKit.font_text(), UiKit.fit_size(UiKit.font_text(), line, 12, size.x - 62.0), UiKit.INK if not ok else UiKit.INK_SOFT)
