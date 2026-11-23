class_name RoutePanel
extends Control
## "RUTA": los 7 escenarios en fila como una hoja de ruta de la empresa (sección 5 de la 0.7.0). Cada uno
## muestra el cliente, la herramienta, los especiales, la automatización que trae y los requisitos para
## abrir el siguiente, y marca en cuál estás. Los lejanos aparecen como "???" con su silueta.

signal closed

const W: float = 1180.0
const H: float = 620.0
const CARD_W: float = 156.0
const CARD_GAP: float = 10.0

var sim: GameSim
var _close_button: StampButton
var _icons: Dictionary = {} ## nombre -> Texture2D, cargadas en setup (cargadas dentro de _draw salen blancas)


func setup(p_sim: GameSim) -> void:
	sim = p_sim
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_close_button = StampButton.new()
	_close_button.setup(Tx.t("close"), Vector2(130.0, 44.0), UiKit.CARDBOARD_DARK)
	_close_button.font_size = 14
	_close_button.pressed.connect(close_panel)
	add_child(_close_button)
	for n: int in ROUTE_ICONS:
		var pair: Array = ROUTE_ICONS[n]
		for icon: Variant in pair:
			_icons[str(icon)] = load("res://assets/icons/%s.png" % str(icon)) as Texture2D


func open_panel() -> void:
	visible = true


func close_panel() -> void:
	visible = false
	closed.emit()


func _origin() -> Vector2:
	var vp: Vector2 = get_viewport_rect().size
	return Vector2((vp.x - W) * 0.5, (vp.y - H) * 0.5)


func _process(_delta: float) -> void:
	if not visible:
		return
	_close_button.position = _origin() + Vector2(W - 160.0, H - 56.0)
	queue_redraw()


func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.07, 0.04, 0.02, 0.66))
	var o: Vector2 = _origin()
	var lang: String = Settings.language
	UiKit.draw_sheet(self, Rect2(o, Vector2(W, H)), UiKit.PAPER, "route_sheet", 1.5, 1.4)
	UiKit.draw_text(self, o + Vector2(28.0, 44.0), Tx.t("route_title"), UiKit.font_title(), 24, UiKit.INK)
	UiKit.draw_text(self, o + Vector2(28.0, 66.0), Tx.t("route_sub"), UiKit.font_mono(), 11, UiKit.INK_SOFT)
	var current: int = sim.phase()
	for i: int in sim.db.phases.size():
		_draw_card(o + Vector2(24.0 + float(i) * (CARD_W + CARD_GAP), 86.0), sim.db.phases[i], current, lang)


func _draw_card(at: Vector2, p: Dictionary, current: int, lang: String) -> void:
	var n: int = Cfg.integer(p, "number")
	var far: bool = n > current + 1 # los muy lejanos son un misterio
	var reached: bool = n <= current
	var route: Dictionary = p["route"]
	var r: Rect2 = Rect2(at, Vector2(CARD_W, 456.0))
	var base: Color = Color("#FFF6D8") if reached else UiKit.PAPER_SHADE
	UiKit.draw_sheet(self, r, base, "route_%d" % n, 1.0 if n == current else 0.0, 1.0)
	if n == current:
		draw_rect(r.grow(3.0), UiKit.STAMP_RED, false, 3.0)
		UiKit.draw_stamp(self, Rect2(at + Vector2(14.0, -10.0), Vector2(128.0, 26.0)), Tx.t("route_here"), UiKit.STAMP_RED, 13, -0.05)
	UiKit.draw_text(self, at + Vector2(12.0, 40.0), "%d" % n, UiKit.font_title(), 26, UiKit.INK if reached else UiKit.INK_SOFT)
	var name_text: String = "???" if far else str(p["name_" + lang]).to_upper()
	UiKit.draw_text(self, at + Vector2(44.0, 38.0), name_text, UiKit.font_title(), UiKit.fit_size(UiKit.font_title(), name_text, 15, CARD_W - 54.0), UiKit.INK)
	_draw_silhouette(at + Vector2(12.0, 52.0), n, not far)
	var lines: Array[Array] = [["route_client", "client"], ["route_tool", "tool"], ["route_specials", "specials"], ["route_auto", "auto"]]
	var y: float = at.y + 152.0
	for pair: Array in lines:
		var label: String = Tx.t(str(pair[0]))
		var value: String = "???" if far else str(route[str(pair[1]) + "_" + lang])
		UiKit.draw_text(self, Vector2(at.x + 12.0, y), label, UiKit.font_mono_bold(), 9, UiKit.STAMP_RED)
		UiKit.draw_text(self, Vector2(at.x + 12.0, y + 14.0), value, UiKit.font_text(), UiKit.fit_size(UiKit.font_text(), value, 12, CARD_W - 24.0), UiKit.INK)
		y += 40.0
	_draw_requirements(at, n, current, far, lang)


## Los requisitos para salir de ese escenario (los del actual con check o cruz; los demás, la lista).
func _draw_requirements(at: Vector2, n: int, current: int, far: bool, lang: String) -> void:
	var y: float = at.y + 316.0
	UiKit.draw_text(self, Vector2(at.x + 12.0, y), Tx.t("route_requires"), UiKit.font_mono_bold(), 9, UiKit.STAMP_RED)
	if far or n > 3:
		UiKit.draw_text(self, Vector2(at.x + 12.0, y + 16.0), "???", UiKit.font_text(), 12, UiKit.INK_SOFT)
		return
	var latched: Dictionary = sim.state.latched
	var items: Array[Dictionary] = PhaseGate.list(sim.db, n, sim.state.big_done.has(str(n)), latched)
	for i: int in items.size():
		var ok: bool = items[i]["ok"] == true or n < current
		var c: Vector2 = Vector2(at.x + 18.0, y + 20.0 + 30.0 * float(i))
		if ok:
			draw_polyline(PackedVector2Array([c + Vector2(-4.0, 0.0), c + Vector2(-1.0, 3.0), c + Vector2(5.0, -4.0)]), Color("#2F7A4C"), 2.0)
		elif n == current:
			draw_line(c + Vector2(-3.0, -3.0), c + Vector2(3.0, 3.0), UiKit.STAMP_RED, 2.0)
			draw_line(c + Vector2(-3.0, 3.0), c + Vector2(3.0, -3.0), UiKit.STAMP_RED, 2.0)
		var line: String = str(items[i][lang])
		UiKit.draw_paragraph(self, Vector2(at.x + 30.0, c.y + 3.0), line, UiKit.font_text(), 11, UiKit.INK if not ok else UiKit.INK_SOFT, CARD_W - 40.0, 12.0)


const ROUTE_ICONS: Dictionary = {1: ["finger", "route_mate"], 2: ["rolling_pin", "route_pelota"], 3: ["iron", "route_garrafa"], 4: ["boot", "route_chulengo"]}


## Íconos pre-renderizados de Blender: la herramienta del escenario y su objeto protagonista (mate, pelota, garrafa,
## chulengo). Los escenarios que todavía no se conocen muestran un signo de pregunta.
func _draw_silhouette(at: Vector2, n: int, known: bool) -> void:
	var box: Rect2 = Rect2(at, Vector2(CARD_W - 24.0, 80.0))
	draw_rect(box, Color(0.0, 0.0, 0.0, 0.06))
	if not known or not ROUTE_ICONS.has(n):
		UiKit.draw_text(self, box.position + Vector2(0.0, 58.0), "?", UiKit.font_title(), 52, Color(0.2, 0.18, 0.16, 0.55), HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
		return
	var names: Array = ROUTE_ICONS[n]
	for k: int in 2:
		var key: String = str(names[k])
		var tex: Texture2D = null
		if _icons.has(key):
			tex = _icons[key]
		if tex != null:
			draw_texture_rect(tex, Rect2(box.position + Vector2(4.0 + float(k) * 64.0, 6.0), Vector2(64.0, 68.0)), false)
