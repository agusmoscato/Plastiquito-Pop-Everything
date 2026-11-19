class_name EncargoTicket
extends Control
## El encargo de la lámina como un ticket de pedido abrochado: qué pide, cuánto falta, el premio y la
## racha. Al cumplirlo cae un sello "¡CUMPLIDO!"; si la lámina termina sin cumplirlo, avisa que se
## cortó la racha.

var sim: GameSim
var _stamp_t: float = 0.0
var _fail_t: float = 0.0
var _bonus_text: String = ""


func setup(p_sim: GameSim) -> void:
	sim = p_sim
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(318.0, 124.0)
	size = custom_minimum_size
	rotation = deg_to_rad(0.8)
	pivot_offset = size * 0.5
	material = UiKit.paper_material()


## Lo llama el HUD después de cada paso de la sim.
func on_sim_step() -> void:
	if sim.ev_encargo_done:
		_stamp_t = 2.2
		_bonus_text = "+" + NumberFormat.pops(sim.ev_encargo_bonus, Settings.language)
	if sim.ev_encargo_failed:
		_fail_t = 2.5


func _process(delta: float) -> void:
	_stamp_t = maxf(0.0, _stamp_t - delta)
	_fail_t = maxf(0.0, _fail_t - delta)
	visible = sim != null and sim.encargo != null
	if visible:
		queue_redraw()


## Texto del pedido ("Hacé una cadena de 12").
static func goal_text(e: Encargo, multipliers: Array) -> String:
	if e.kind == "combo":
		var m: float = multipliers[clampi(e.target, 0, multipliers.size() - 1)]
		return Tx.t("enc_combo") % NumberFormat.decimal(m, 1 if m != floorf(m) else 0, Settings.language)
	return Tx.t(e.text_key()) % e.target


func _draw() -> void:
	var e: Encargo = sim.encargo
	var rect: Rect2 = Rect2(Vector2(4.0, 6.0), Vector2(size.x - 10.0, size.y - 12.0))
	UiKit.draw_sheet(self, rect, Color("#FFF6D8"), "encargo", 0.5)
	# Abrochadora: dos ganchitos de metal arriba.
	for x: float in [rect.position.x + 40.0, rect.end.x - 40.0]:
		draw_rect(Rect2(Vector2(x - 9.0, rect.position.y + 2.0), Vector2(18.0, 4.0)), Color("#8E949A"))
	UiKit.draw_text(self, Vector2(18.0, 30.0), Tx.t("enc_title"), UiKit.font_mono_bold(), 11, UiKit.INK_SOFT)
	var mults: Array = sim.eco["combo_multipliers"]
	UiKit.draw_text(self, Vector2(18.0, 54.0), goal_text(e, mults), UiKit.font_title(), 15, UiKit.INK)
	var shown: int = e.progress
	var bar: Rect2 = Rect2(Vector2(18.0, 66.0), Vector2(size.x - 46.0, 10.0))
	UiKit.draw_ink_bar(self, bar, e.ratio(), UiKit.STAMP_RED if e.done else UiKit.INK)
	var prog: String = "%d / %d" % [shown, e.target]
	if e.kind == "combo":
		var m: float = mults[clampi(shown, 0, mults.size() - 1)]
		prog = "x" + NumberFormat.decimal(m, 1, Settings.language)
	UiKit.draw_text(self, Vector2(18.0, 94.0), prog, UiKit.font_mono(), 12, UiKit.INK)
	var streak_txt: String = Tx.t("enc_streak") % [sim.streak, roundi((sim.streak_mult() - 1.0) * 100.0)]
	UiKit.draw_text(self, Vector2(size.x - 190.0, 110.0), streak_txt, UiKit.font_mono_bold(), 11, UiKit.STAMP_RED if sim.streak > 0 else UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_RIGHT, 162.0)
	if _fail_t > 0.0:
		var a: float = clampf(_fail_t, 0.0, 1.0)
		UiKit.draw_text(self, Vector2(18.0, 110.0), Tx.t("enc_failed"), UiKit.font_text_bold(), 11, Color(UiKit.STAMP_RED.r, UiKit.STAMP_RED.g, UiKit.STAMP_RED.b, a))
	if _stamp_t > 0.0 or e.done:
		# El sello cae sobre la barra, a la derecha: el pedido se sigue leyendo.
		var t: float = clampf(_stamp_t, 0.0, 2.2)
		var punch: float = 1.0 + maxf(0.0, t - 1.9) * 2.0
		var r: Rect2 = Rect2(Vector2(size.x - 172.0 - 10.0 * punch, 62.0 - 6.0 * punch), Vector2(150.0, 34.0) * punch)
		UiKit.draw_stamp(self, r, Tx.t("enc_done"), UiKit.STAMP_RED, int(16.0 * punch), -0.12, 0.9 if e.done else clampf(t, 0.0, 1.0))
		if _stamp_t > 0.0:
			UiKit.draw_text(self, Vector2(18.0, 110.0), _bonus_text, UiKit.font_mono_bold(), 12, UiKit.STAMP_RED)
