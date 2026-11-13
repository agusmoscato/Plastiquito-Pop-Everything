class_name PermCard
extends Control
## Una mejora permanente como ficha de papel clavada en el tablero de corcho con una chinche.
## Se paga con Pellets. Clic para comprar.

signal bought(id: String, count: int)

const W: float = 220.0
const H: float = 108.0

var sim: GameSim
var id: String = ""

var _hover: bool = false
var _stamp: float = 0.0


func setup(p_sim: GameSim, p_id: String) -> void:
	sim = p_sim
	id = p_id
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	pivot_offset = size * 0.5
	rotation = UiKit.tilt(id) * 1.6
	mouse_filter = Control.MOUSE_FILTER_STOP
	material = UiKit.paper_material()
	mouse_entered.connect(func() -> void: _hover = true)
	mouse_exited.connect(func() -> void: _hover = false)


func _process(delta: float) -> void:
	_stamp = maxf(0.0, _stamp - delta * 3.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if sim.can_afford_next(id):
				var r: Dictionary = sim.buy(id, 1)
				var n: int = r["bought"]
				if n > 0:
					_stamp = 1.0
					bought.emit(id, n)
			accept_event()


func pin_point() -> Vector2:
	return global_position + Vector2(W * 0.5, 8.0)


func _draw() -> void:
	var lang: String = Settings.language
	var lvl: int = sim.upgrades.level_of(sim.state, id)
	var mx: int = sim.upgrades.max_level(id)
	var avail: bool = sim.upgrades.is_available(sim.state, id)
	var afford: bool = sim.can_afford_next(id)
	var lift: float = 2.0 if (_hover and avail) else 0.0
	var rect: Rect2 = Rect2(Vector2(4.0, 10.0 - lift), Vector2(W - 8.0, H - 14.0))
	var paper: Color = UiKit.PAPER if avail else UiKit.PAPER_SHADE
	UiKit.draw_sheet(self, rect, paper, id, lift, 1.2)
	UiKit.draw_text(self, rect.position + Vector2(12.0, 28.0), sim.upgrades.name_of(id, lang).to_upper(), UiKit.font_title(), 12, UiKit.INK if avail else UiKit.INK_SOFT)
	draw_multiline_string(UiKit.font_text(), rect.position + Vector2(12.0, 44.0), sim.upgrades.desc_of(id, lang), HORIZONTAL_ALIGNMENT_LEFT, W - 34.0, 10, 2, UiKit.INK_SOFT)
	var line: String = "NIV %d/%d  %s" % [lvl, mx, sim.upgrades.effect_text(id, lvl, lang).left(12)]
	UiKit.draw_text(self, rect.position + Vector2(12.0, H - 28.0), line, UiKit.font_mono(), 10, UiKit.INK)
	if lvl >= mx:
		UiKit.draw_stamp(self, Rect2(rect.position + Vector2(W - 88.0, H - 52.0), Vector2(66.0, 24.0)), "MAX", UiKit.INK_SOFT, 13, -0.05)
	elif not avail:
		UiKit.draw_text(self, rect.position + Vector2(W - 104.0, H - 28.0), "RESERVADO" if lang == "es" else "LOCKED", UiKit.font_mono(), 9, UiKit.INK_SOFT)
	else:
		var color: Color = UiKit.STAMP_RED if afford else UiKit.INK_SOFT
		var box: Rect2 = Rect2(rect.position + Vector2(W - 90.0, H - 52.0), Vector2(72.0, 24.0))
		draw_rect(box, color, false, 2.0)
		UiKit.draw_text(self, box.position + Vector2(0.0, 17.0), "%s P" % NumberFormat.pops(sim.upgrades.next_cost(id, lvl), lang), UiKit.font_mono_bold(), 12, color, HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
	# Chinche roja.
	draw_circle(Vector2(W * 0.5 + 1.0, 14.0), 6.5, Color(0, 0, 0, 0.3))
	draw_circle(Vector2(W * 0.5, 12.0), 6.5, UiKit.STAMP_RED)
	draw_circle(Vector2(W * 0.5 - 2.0, 10.0), 1.8, Color(1, 1, 1, 0.65))
	if _stamp > 0.0:
		UiKit.draw_stamp(self, Rect2(rect.position + Vector2(22.0, 30.0), Vector2(150.0, 34.0)), "SELLADO" if lang == "es" else "STAMPED", UiKit.STAMP_RED, 17, -0.1, clampf(_stamp * 1.3, 0.0, 1.0))
