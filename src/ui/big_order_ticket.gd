class_name BigOrderTicket
extends Control
## El pedido grande del escenario (sección 4 de la 0.7.0) como un ticket largo de la etiquetadora: el
## cliente, qué pide, cuánto falta y el plazo con un reloj de arena. Al cumplirlo cae el sello
## "CUMPLIDO"; si vence, "VENCIDO" y la multa. Sonidos propios (ph_done / ph_fail).

var sim: GameSim
var _stamp_t: float = 0.0
var _stamp_ok: bool = true
var _note: String = ""
var _appear_t: float = 0.0
var _hold_state: Dictionary = {}


func setup(p_sim: GameSim) -> void:
	sim = p_sim
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(318.0, 176.0)
	size = custom_minimum_size
	rotation = deg_to_rad(-0.7)
	pivot_offset = size * 0.5
	material = UiKit.paper_material()
	visible = false


## Lo llama el HUD después de cada paso de la sim.
func on_sim_step() -> void:
	if sim.ev_big_started:
		_appear_t = 1.0
		PopAudio.play_ui("stamp", 0.8)
	if sim.ev_big_done:
		_stamp_t = 4.0
		_stamp_ok = true
		var d: Dictionary = sim.big.def_for(sim.phase())
		_note = "+%d %s  ·  x%s" % [Cfg.integer(d, "reward_pellets"), Tx.t("pellets"), NumberFormat.decimal(1.0 + Cfg.num(d, "reward_mult"), 2, Settings.language)]
		PopAudio.play_ui("done")
	if sim.ev_big_failed:
		_stamp_t = 4.0
		_stamp_ok = false
		_note = "-" + NumberFormat.pops(sim.ev_big_fine, Settings.language)
		PopAudio.play_ui("fail")
	if sim.big.is_active(sim.state.big):
		_hold_state = sim.state.big


func _process(delta: float) -> void:
	_stamp_t = maxf(0.0, _stamp_t - delta)
	_appear_t = maxf(0.0, _appear_t - delta * 2.0)
	visible = sim != null and (sim.big.is_active(sim.state.big) or _stamp_t > 0.0)
	if visible:
		queue_redraw()


func _draw() -> void:
	var lang: String = Settings.language
	var ph: int = sim.phase()
	var d: Dictionary = sim.big.def_for(ph)
	if d.is_empty():
		return
	var st: Dictionary = sim.state.big if sim.big.is_active(sim.state.big) else _hold_state
	var rect: Rect2 = Rect2(Vector2(4.0 - 40.0 * _appear_t, 6.0), Vector2(size.x - 10.0, size.y - 12.0))
	UiKit.draw_sheet(self, rect, Color("#F7E9B8"), "bigorder", 0.7)
	for x: float in [rect.position.x + 40.0, rect.end.x - 40.0]:
		draw_rect(Rect2(Vector2(x - 9.0, rect.position.y + 2.0), Vector2(18.0, 4.0)), Color("#8E949A"))
	var ox: float = rect.position.x + 14.0
	UiKit.draw_text(self, Vector2(ox, 30.0), "%s  ·  %s" % [Tx.t("big_title"), str(d["client_" + lang])], UiKit.font_mono_bold(), 11, UiKit.STAMP_RED)
	UiKit.draw_text(self, Vector2(ox, 52.0), str(d["title_" + lang]).to_upper(), UiKit.font_title(), UiKit.fit_size(UiKit.font_title(), str(d["title_" + lang]).to_upper(), 16, rect.size.x - 28.0), UiKit.INK)
	var target: int = sim.big.target(st) if not st.is_empty() else Cfg.integer(d, "n")
	UiKit.draw_paragraph(self, Vector2(ox, 69.0), str(d["text_" + lang]) % target, UiKit.font_text(), 11, UiKit.INK_SOFT, rect.size.x - 32.0, 13.0)
	var progress: float = Cfg.num(st, "progress") if not st.is_empty() else 0.0
	var ratio: float = clampf(progress / float(maxi(target, 1)), 0.0, 1.0)
	UiKit.draw_ink_bar(self, Rect2(Vector2(ox, 100.0), Vector2(rect.size.x - 100.0, 10.0)), ratio, UiKit.STAMP_RED if ratio >= 1.0 else UiKit.INK)
	UiKit.draw_text(self, Vector2(ox, 128.0), "%d / %d" % [int(progress), target], UiKit.font_mono(), 12, UiKit.INK)
	var left: float = maxf(Cfg.num(st, "left"), 0.0) if not st.is_empty() else 0.0
	var total: float = maxf(sim.big.seconds(st, sim.big_order_time_mult()), 1.0) if not st.is_empty() else 1.0
	var urgent: bool = left < 15.0 and _stamp_t <= 0.0
	var clock_col: Color = UiKit.STAMP_RED if urgent and int(Time.get_ticks_msec() / 300) % 2 == 0 else UiKit.INK
	UiKit.draw_text(self, Vector2(rect.end.x - 118.0, 128.0), "%d:%02d" % [int(left) / 60, int(left) % 60], UiKit.font_mono_bold(), 16, clock_col, HORIZONTAL_ALIGNMENT_RIGHT, 80.0)
	_draw_hourglass(Vector2(rect.end.x - 26.0, 112.0), clampf(left / total, 0.0, 1.0), clock_col)
	var tries: int = st.get("tries", 0)
	if tries > 0:
		UiKit.draw_text(self, Vector2(ox, 150.0), Tx.t("big_retry") % tries, UiKit.font_mono(), 10, UiKit.INK_SOFT)
	if _stamp_t > 0.0:
		var t: float = clampf(_stamp_t, 0.0, 4.0)
		var punch: float = 1.0 + maxf(0.0, t - 3.6) * 3.0
		var r: Rect2 = Rect2(Vector2(rect.position.x + 54.0 - 8.0 * punch, 78.0 - 8.0 * punch), Vector2(210.0, 46.0) * punch)
		UiKit.draw_stamp(self, r, Tx.t("enc_done") if _stamp_ok else Tx.t("big_failed"), UiKit.STAMP_RED if not _stamp_ok else Color("#2F7A4C"), int(22.0 * punch), -0.12, clampf(t, 0.0, 1.0))
		UiKit.draw_text(self, Vector2(ox, 150.0), _note, UiKit.font_mono_bold(), 12, UiKit.STAMP_RED if not _stamp_ok else Color("#2F7A4C"))


## Reloj de arena: dos triángulos y la arena que baja con el plazo.
func _draw_hourglass(c: Vector2, sand: float, col: Color) -> void:
	var w: float = 10.0
	var h: float = 15.0
	draw_polyline(PackedVector2Array([c + Vector2(-w, -h), c + Vector2(w, -h), c, c + Vector2(-w, h), c + Vector2(w, h), c, c + Vector2(-w, -h)]), col, 1.6)
	var top: float = h * sand
	draw_colored_polygon(PackedVector2Array([c + Vector2(-w * sand, -top), c + Vector2(w * sand, -top), c + Vector2(0.0, 0.0)]), Color(col.r, col.g, col.b, 0.55))
	var bot: float = h * (1.0 - sand)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-w * (1.0 - sand), h), c + Vector2(w * (1.0 - sand), h), c + Vector2(0.0, h - bot)]), Color(col.r, col.g, col.b, 0.55))
