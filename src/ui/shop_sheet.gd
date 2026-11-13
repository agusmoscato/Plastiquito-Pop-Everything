class_name ShopSheet
extends Control
## La tienda: una "hoja de pedidos" sujeta con un clip. Pestañas por herramienta (con el modelo
## 3D real girando) más las mejoras globales. Cada mejora es una UpgradeTag.

signal tag_bought(id: String, count: int, milestone: bool)
signal tag_affordable(id: String)

const W: float = 452.0
const H: float = 790.0
const TABS: Array[String] = ["finger", "palm", "rolling_pin", "iron", "boot", "hands", "auto_roller", "global"]

var sim: GameSim
var buy_mode_value: int = 1

var _tabs: Dictionary = {} ## tab id -> StampButton
var _pages: Dictionary = {} ## tab id -> VBoxContainer
var _tags: Dictionary = {} ## upgrade id -> UpgradeTag
var _current: String = "finger"
var _mode_buttons: Array[StampButton] = []
var _scroll: ScrollContainer
var _clip_shake: float = 0.0


func setup(p_sim: GameSim) -> void:
	sim = p_sim
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	material = UiKit.paper_material(0.04)
	_build_tabs()
	_build_mode_buttons()
	_build_pages()
	select_tab("finger")


## El clip de la hoja de pedidos tiembla (se usa la primera vez que algo se puede pagar).
func shake_clip(seconds: float) -> void:
	_clip_shake = seconds


func _process(delta: float) -> void:
	if _clip_shake > 0.0:
		_clip_shake = maxf(0.0, _clip_shake - delta)
		queue_redraw()


func buy_mode() -> int:
	return buy_mode_value


func select_tab(tab: String) -> void:
	_current = tab
	for t: String in _tabs:
		var b: StampButton = _tabs[t]
		b.toggled_on = t == tab
	for t: String in _pages:
		var page: VBoxContainer = _pages[t]
		page.visible = t == tab
	_scroll.scroll_vertical = 0


func _build_tabs() -> void:
	for i: int in TABS.size():
		var t: String = TABS[i]
		var b: StampButton = StampButton.new()
		b.setup(Tx.t("tool_" + t), Vector2(96.0, 62.0), UiKit.CARDBOARD_DARK)
		b.font_size = 11
		b.text_bottom = true
		@warning_ignore("integer_division")
		b.position = Vector2(24.0 + float(i % 4) * 100.0, 128.0 + float(i / 4) * 66.0)
		b.pressed.connect(select_tab.bind(t))
		add_child(b)
		var icon: ToolIcon = ToolIcon.new()
		icon.setup(t if t != "global" else "bubble", 38, 0)
		icon.position = Vector2(29.0, 4.0)
		b.add_child(icon)
		_tabs[t] = b


## Muestra solo las pestañas de lo que ya está al alcance (la plancha y las manitos desde el Galpón,
## la bota y el rodillo desde el Estacionamiento).
func refresh_tabs() -> void:
	var phase: int = sim.phase()
	var need: Dictionary = {"iron": 3, "hands": 3, "boot": 4, "auto_roller": 4}
	for t: String in _tabs:
		var b: StampButton = _tabs[t]
		var min_phase: int = need.get(t, 1)
		b.visible = phase >= min_phase


func _build_mode_buttons() -> void:
	var modes: Array[int] = [1, 10, -1]
	var x: float = 236.0
	for m: int in modes:
		var b: StampButton = StampButton.new()
		b.setup("x%d" % m if m > 0 else "MAX", Vector2(62.0, 34.0), UiKit.STAMP_RED)
		b.font_size = 14
		b.position = Vector2(x, 72.0)
		b.pressed.connect(_set_mode.bind(m))
		b.toggled_on = m == 1
		add_child(b)
		_mode_buttons.append(b)
		x += 64.0


func _set_mode(m: int) -> void:
	buy_mode_value = m
	var modes: Array[int] = [1, 10, -1]
	for i: int in _mode_buttons.size():
		_mode_buttons[i].toggled_on = modes[i] == m


func _build_pages() -> void:
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(20.0, 266.0)
	_scroll.size = Vector2(W - 40.0, H - 290.0)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_scroll)
	for t: String in TABS:
		var page: VBoxContainer = VBoxContainer.new()
		page.add_theme_constant_override("separation", 6)
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.mouse_filter = Control.MOUSE_FILTER_PASS
		_scroll.add_child(page)
		_pages[t] = page
		var ids: Array[String] = sim.upgrades.ids_for_scope("global") if t == "global" else sim.upgrades.ids_for_tool(t)
		for id: String in ids:
			var tag: UpgradeTag = UpgradeTag.new()
			tag.setup(sim, id, buy_mode)
			tag.bought.connect(func(i: String, n: int, ms: bool) -> void: tag_bought.emit(i, n, ms))
			tag.became_affordable.connect(func(i: String) -> void: tag_affordable.emit(i))
			page.add_child(tag)
			_tags[id] = tag


## Id de la mejora más barata que todavía no se puede pagar (para la barra "siguiente pedido").
func tag_for(id: String) -> UpgradeTag:
	var t: UpgradeTag = _tags.get(id)
	return t


func tag_ids() -> Array:
	return _tags.keys()


func tab_of(id: String) -> String:
	var d: Dictionary = sim.upgrades.def(id)
	var tool_id: String = str(d["tool"])
	return tool_id if tool_id != "" else "global"


func _draw() -> void:
	# Tablero de cartón oscuro con el clip arriba.
	var board: Rect2 = Rect2(Vector2(4.0, 22.0), Vector2(W - 8.0, H - 28.0))
	UiKit.draw_sheet(self, board, UiKit.CARDBOARD_DARK, "shop_board", 2.0, 2.0)
	var paper: Rect2 = Rect2(Vector2(16.0, 52.0), Vector2(W - 32.0, H - 72.0))
	UiKit.draw_sheet(self, paper, UiKit.PAPER, "shop_paper", 0.0, 1.8)
	# Renglones de cuaderno muy tenues.
	var y: float = paper.position.y + 60.0
	while y < paper.end.y - 10.0:
		draw_line(Vector2(paper.position.x + 8.0, y), Vector2(paper.end.x - 8.0, y), Color(0.5, 0.65, 0.8, 0.12), 1.0)
		y += 26.0
	# Clip metálico.
	var jitter: Vector2 = Vector2(sin(Time.get_ticks_msec() * 0.09) * 3.0, 0.0) * minf(_clip_shake, 1.0)
	var clip: Rect2 = Rect2(Vector2(W * 0.5 - 62.0, 2.0) + jitter, Vector2(124.0, 50.0))
	draw_rect(Rect2(clip.position + Vector2(3.0, 4.0), clip.size), Color(0, 0, 0, 0.3))
	draw_rect(clip, Color("#9AA0A6"))
	draw_rect(Rect2(clip.position + Vector2(6.0, 6.0), clip.size - Vector2(12.0, 22.0)), Color("#C9CED3"))
	draw_rect(Rect2(clip.position + Vector2(10.0, 10.0), Vector2(clip.size.x - 20.0, 4.0)), Color(1, 1, 1, 0.55))
	draw_rect(clip, Color("#6E747A"), false, 2.0)
	var lang: String = Settings.language
	UiKit.draw_text(self, Vector2(34.0, 98.0), "HOJA DE PEDIDOS" if lang == "es" else "ORDER SHEET", UiKit.font_title(), 20, UiKit.INK)
	UiKit.draw_text(self, Vector2(34.0, 118.0), "N.° %04d  -  DEPTO. DE REVENTONES" % (sim.state.sheets_done + 1), UiKit.font_mono(), 11, UiKit.INK_SOFT)
