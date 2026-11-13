class_name UpgradeTag
extends Control
## Una mejora como etiqueta de papel impresa: nombre, línea graciosa, nivel, efecto actual -> próximo
## y precio. Se compra con clic o manteniendo apretado (repite acelerando). Dibujada por código.

signal bought(id: String, count: int, milestone: bool)
signal became_affordable(id: String)

const W: float = 392.0
const H: float = 106.0

var sim: GameSim
var id: String = ""
var buy_mode: Callable ## devuelve 1, 10 o -1 (máximo)

var _icon: ToolIcon
var _lift: float = 0.0
var _was_affordable: bool = false
var _stamp_t: float = 0.0
var _reprint_t: float = 1.0
var _golden_t: float = 0.0
var _holding: bool = false
var _hold_time: float = 0.0
var _next_buy: float = 0.0
var _hover: bool = false
var discovery: bool = false ## la primera vez que se puede pagar: se despega más


func setup(p_sim: GameSim, p_id: String, p_buy_mode: Callable) -> void:
	sim = p_sim
	id = p_id
	buy_mode = p_buy_mode
	custom_minimum_size = Vector2(W + 8.0, H + 10.0)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	rotation = UiKit.tilt(id)
	mouse_filter = Control.MOUSE_FILTER_STOP
	material = UiKit.paper_material()
	var d: Dictionary = sim.upgrades.def(id)
	_icon = ToolIcon.new()
	var tool_id: String = str(d["tool"])
	_icon.setup(tool_id if tool_id != "" else "bubble", 64, 0)
	_icon.position = Vector2(14.0, 20.0)
	_icon.set_variant(str(d["kind"]))
	add_child(_icon)
	_was_affordable = sim.can_afford_next(id)
	mouse_entered.connect(func() -> void: _hover = true; queue_redraw())
	mouse_exited.connect(func() -> void: _hover = false; _holding = false; queue_redraw())


func level() -> int:
	return sim.upgrades.level_of(sim.state, id)


func _count_for_mode() -> int:
	var m: int = 1
	if buy_mode.is_valid():
		var v: int = buy_mode.call()
		m = v
	return m


func _process(delta: float) -> void:
	if sim == null:
		return
	var afford: bool = sim.can_afford_next(id)
	if afford and not _was_affordable:
		became_affordable.emit(id)
	_was_affordable = afford
	var target: float = 1.0 if afford else 0.0
	_lift = lerpf(_lift, target, 1.0 - exp(-12.0 * delta))
	_stamp_t = maxf(0.0, _stamp_t - delta * 3.2)
	_reprint_t = minf(1.0, _reprint_t + delta * 5.0)
	_golden_t = maxf(0.0, _golden_t - delta * 0.35)
	if _holding:
		_hold_time += delta
		_next_buy -= delta
		if _next_buy <= 0.0 and _hold_time > 0.4:
			var accel: float = clampf((_hold_time - 0.4) / 2.0, 0.0, 1.0)
			_next_buy = lerpf(0.22, 0.04, accel)
			_try_buy()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_holding = true
				_hold_time = 0.0
				_next_buy = 0.0
				_try_buy()
			else:
				_holding = false
			accept_event()


func _try_buy() -> void:
	if not sim.can_afford_next(id):
		return
	var r: Dictionary = sim.buy(id, _count_for_mode())
	var n: int = r["bought"]
	if n > 0:
		var ms: bool = r["milestone"]
		_stamp_t = 1.0
		_reprint_t = 0.0
		if ms:
			_golden_t = 1.0
		bought.emit(id, n, ms)


func _draw() -> void:
	if sim == null:
		return
	var d: Dictionary = sim.upgrades.def(id)
	var lang: String = Settings.language
	var lvl: int = level()
	var max_lvl: int = sim.upgrades.max_level(id)
	var maxed: bool = lvl >= max_lvl
	var available: bool = sim.upgrades.is_available(sim.state, id)
	var afford: bool = sim.can_afford_next(id)
	var lift: float = _lift * 2.0 + (1.0 if _hover and available else 0.0) + (5.0 + sin(Time.get_ticks_msec() * 0.01) * 1.5 if discovery else 0.0)
	var dx: float = (UiKit.hash01(id, 3) - 0.5) * 16.0 # cada etiqueta se pegó un poco corrida
	var origin: Vector2 = Vector2(4.0 + dx, 5.0 - lift)
	var is_gold: bool = lvl > 0 and lvl % Cfg.integer(sim.eco, "milestone_every") == 0
	var paper: Color = UiKit.PAPER if available else UiKit.PAPER_SHADE
	if is_gold or _golden_t > 0.0:
		paper = paper.lerp(Color("#F2D77A"), 0.55 if is_gold else _golden_t * 0.6)
	var rect: Rect2 = Rect2(origin, Vector2(W, H))
	UiKit.draw_sheet(self, rect, paper, id, lift)
	# Cinta en dos esquinas.
	UiKit.draw_tape(self, origin + Vector2(10.0, 4.0), -0.5, 40.0, 14.0)
	UiKit.draw_tape(self, origin + Vector2(W - 12.0, H - 4.0), -0.35, 40.0, 14.0)
	# Ícono (si no está disponible, se ve apagado).
	_icon.modulate = Color(1, 1, 1, 1) if available else Color(1, 1, 1, 0.35)
	_icon.position = origin + Vector2(10.0, 22.0)
	var name_text: String = sim.upgrades.name_of(id, lang)
	var title_color: Color = UiKit.INK if available else UiKit.INK_SOFT
	UiKit.draw_text(self, origin + Vector2(86.0, 28.0), name_text.to_upper(), UiKit.font_title(), 15, title_color)
	var desc: String = sim.upgrades.desc_of(id, lang)
	draw_multiline_string(UiKit.font_text(), origin + Vector2(86.0, 46.0), desc, HORIZONTAL_ALIGNMENT_LEFT, 292.0, 12, 2, UiKit.INK_SOFT)
	# Línea de nivel y efecto (como impresa por etiquetadora, letra a letra al comprar).
	var cur: String = sim.upgrades.effect_text(id, lvl, lang)
	var nxt: String = sim.upgrades.effect_text(id, mini(lvl + 1, max_lvl), lang)
	var line: String = "NIV %d/%d  %s > %s" % [lvl, max_lvl, cur, nxt] if not maxed else "NIV %d/%d  %s" % [lvl, max_lvl, cur]
	if str(d["kind"]) == "unlock":
		line = "NIV %d/%d" % [lvl, max_lvl]
	var shown_chars: int = int(float(line.length()) * _reprint_t)
	UiKit.draw_text(self, origin + Vector2(86.0, 88.0), line.substr(0, shown_chars), UiKit.font_mono(), 11, UiKit.INK)
	_draw_price(origin, maxed, available, afford, lvl)
	if _stamp_t > 0.0:
		var s: float = 1.0 + _stamp_t * 0.5
		var r: Rect2 = Rect2(origin + Vector2(W * 0.5 - 70.0 * s, H * 0.5 - 18.0 * s), Vector2(140.0 * s, 36.0 * s))
		UiKit.draw_stamp(self, r, "SELLADO" if lang == "es" else "STAMPED", UiKit.STAMP_RED, int(18.0 * s), -0.12, clampf(_stamp_t * 1.4, 0.0, 1.0))


func _draw_price(origin: Vector2, maxed: bool, available: bool, afford: bool, lvl: int) -> void:
	var box: Rect2 = Rect2(origin + Vector2(W - 108.0, 62.0), Vector2(94.0, 30.0))
	var lang: String = Settings.language
	if maxed:
		UiKit.draw_stamp(self, box, "MAX" if lang == "es" else "MAX", UiKit.INK_SOFT, 16, -0.05)
		return
	if not available:
		var req: String = "RESERVADO" if lang == "es" else "RESERVED"
		UiKit.draw_text(self, box.position + Vector2(0.0, 20.0), req, UiKit.font_mono(), 10, UiKit.INK_SOFT)
		return
	var n: int = _count_for_mode()
	var count: int = 1
	if n == -1:
		count = maxi(1, sim.upgrades.affordable_count(id, lvl, _budget()))
	else:
		count = mini(n, sim.upgrades.max_level(id) - lvl)
	var cost: float = sim.upgrades.cost_for(id, lvl, count)
	var color: Color = UiKit.STAMP_RED if afford else UiKit.INK_SOFT
	draw_rect(box, color, false, 2.0)
	var label: String = NumberFormat.pops(cost, lang)
	var perm: bool = sim.upgrades.is_perm(id)
	if perm:
		label += " P"
	UiKit.draw_text(self, box.position + Vector2(0.0, 20.0), label, UiKit.font_mono_bold(), 14, color, HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
	if count > 1:
		UiKit.draw_text(self, box.position + Vector2(2.0, -4.0), "x%d" % count, UiKit.font_mono(), 10, UiKit.INK)
	# Barra de "cuánto falta".
	var ratio: float = clampf(_budget() / maxf(cost, 1.0), 0.0, 1.0)
	UiKit.draw_ink_bar(self, Rect2(origin + Vector2(86.0, H - 10.0), Vector2(200.0, 5.0)), ratio, UiKit.STAMP_RED if afford else UiKit.INK)


func _budget() -> float:
	return sim.state.pellets if sim.upgrades.is_perm(id) else sim.state.pops
