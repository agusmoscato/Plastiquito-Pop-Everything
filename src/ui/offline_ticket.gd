class_name OfflineTicket
extends Control
## Pantalla de bienvenida: un ticket impreso de la etiquetadora con lo que produjeron las Manitos
## y el rodillo mientras el juego estuvo cerrado. "Cobrar" suma el monto al contador (que rueda).

signal collected

var result: Dictionary = {}

var _button: StampButton
var _t: float = 0.0


func setup() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_button = StampButton.new()
	_button.setup(Tx.t("welcome_collect"), Vector2(200.0, 56.0), UiKit.STAMP_RED)
	_button.font_size = 20
	_button.pressed.connect(func() -> void: visible = false; collected.emit())
	add_child(_button)


func show_result(r: Dictionary) -> void:
	result = r
	_t = 0.0
	visible = true


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.07, 0.04, 0.02, 0.66))
	var w: float = 400.0
	var full_h: float = 440.0
	# El ticket sale de la etiquetadora: se imprime hacia abajo en 1,2 s.
	var h: float = full_h * clampf(_t / 1.2, 0.0, 1.0)
	var rect: Rect2 = Rect2(Vector2((vp.x - w) * 0.5, 70.0), Vector2(w, h))
	var slot: Rect2 = Rect2(Vector2(rect.position.x - 30.0, 50.0), Vector2(w + 60.0, 26.0))
	draw_rect(Rect2(rect.position + Vector2(6.0, 6.0), rect.size), Color(0, 0, 0, 0.3))
	UiKit.draw_sheet(self, rect, UiKit.PAPER, "ticket", 1.0, 1.0)
	draw_rect(slot, UiKit.CARDBOARD_DARK)
	draw_rect(slot, Color(0, 0, 0, 0.4), false, 2.0)
	var lang: String = Settings.language
	var mono: Font = UiKit.font_mono()
	var bold: Font = UiKit.font_mono_bold()
	var x: float = rect.position.x + 28.0
	var y: float = rect.position.y + 40.0
	if h > 50.0:
		UiKit.draw_text(self, Vector2(x, y), Tx.t("welcome_title"), UiKit.font_title(), 24, UiKit.INK)
	var bubbles: float = Cfg.num(result, "hands_pops") + Cfg.num(result, "roller_pops")
	var lines: Array[String] = []
	if lang == "es":
		lines.append("Mientras no estabas, el turno noche")
		lines.append("reventó %s burbujas." % _thousands(bubbles))
	else:
		lines.append("While you were away, the night shift")
		lines.append("popped %s bubbles." % _thousands(bubbles))
	var shown: float = clampf((_t - 0.5) / 1.4, 0.0, 1.0)
	y += 36.0
	for line: String in lines:
		if y < rect.end.y - 20.0:
			UiKit.draw_text(self, Vector2(x, y), line.substr(0, int(float(line.length()) * shown)), mono, 13, UiKit.INK)
		y += 20.0
	y += 14.0
	var rows: Array = [
		[Tx.t("welcome_hands"), NumberFormat.pops(Cfg.num(result, "hands_pops"), lang)],
		[Tx.t("welcome_roller"), NumberFormat.pops(Cfg.num(result, "roller_pops"), lang)],
		[Tx.t("welcome_time"), NumberFormat.duration(Cfg.num(result, "seconds"))],
		[Tx.t("welcome_eff"), "%d%%" % int(Cfg.num(result, "efficiency") * 100.0)],
	]
	for row: Array in rows:
		if y < rect.end.y - 20.0:
			UiKit.draw_text(self, Vector2(x, y), str(row[0]), mono, 12, UiKit.INK_SOFT)
			UiKit.draw_text(self, Vector2(x, y), str(row[1]), bold, 12, UiKit.INK, HORIZONTAL_ALIGNMENT_RIGHT, w - 56.0)
			# Línea punteada de la etiquetadora.
			for i: int in 20:
				draw_rect(Rect2(Vector2(x + float(i) * 17.0, y + 6.0), Vector2(8.0, 1.0)), Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.25))
		y += 26.0
	if h > full_h - 130.0:
		UiKit.draw_stamp(self, Rect2(Vector2(x, y + 14.0), Vector2(w - 56.0, 52.0)), "%s  %s" % [Tx.t("welcome_total"), NumberFormat.pops(Cfg.num(result, "pops"), lang)], UiKit.STAMP_RED, 20, -0.04)
	_button.position = Vector2((vp.x - 200.0) * 0.5, rect.end.y + 20.0)
	_button.visible = h >= full_h - 1.0


func _thousands(v: float) -> String:
	var s: String = str(int(v))
	var out: String = ""
	var n: int = s.length()
	for i: int in n:
		out += s[i]
		var left: int = n - 1 - i
		if left > 0 and left % 3 == 0:
			out += "." if Settings.language == "es" else ","
	return out
