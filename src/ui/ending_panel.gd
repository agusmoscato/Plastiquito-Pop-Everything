class_name EndingPanel
extends Control
## El final (sección 7 de la 0.7.0): reventaste todo el plástico de burbujas del mundo y la empresa se quedó sin
## mercadería. Llega un TELEGRAMA DE DESPIDO a tu nombre, la foto del cuadro de empleado del mes recibe un
## sello rojo "EX" y los créditos pasan sobre una lámina que se sigue reventando sola. Después se desbloquea el
## modo zen "AHORA SOS MONOTRIBUTISTA". Un clic adelanta cada paso.

signal finished

enum Step { TELEGRAM, STAMP, CREDITS, FREELANCE }

const TELEGRAM_SIZE: Vector2 = Vector2(640.0, 430.0)

var sim: GameSim
var step: Step = Step.TELEGRAM
var t: float = 0.0
var _photo: ImageTexture
var _button: StampButton
var _credit_y: float = 0.0


func setup(p_sim: GameSim) -> void:
	sim = p_sim
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_button = StampButton.new()
	_button.setup(Tx.t("ending_continue"), Vector2(220.0, 54.0), UiKit.STAMP_RED)
	_button.font_size = 17
	_button.filled = true
	_button.visible = false
	_button.pressed.connect(_finish)
	add_child(_button)


func start() -> void:
	visible = true
	step = Step.TELEGRAM
	t = 0.0
	_credit_y = 0.0
	_photo = PlayerIdentity.id_texture(128)
	_button.visible = false
	PopAudio.play_ui("milestone", 0.7, -2.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_advance()
			accept_event()


func _advance() -> void:
	if step == Step.TELEGRAM and t < 3.0:
		t = 3.0 # termina de tipear
	elif step == Step.TELEGRAM:
		step = Step.STAMP
		t = 0.0
	elif step == Step.STAMP:
		step = Step.CREDITS
		t = 0.0
		_credit_y = 0.0


func _finish() -> void:
	visible = false
	sim.ending_pending = false
	finished.emit()


func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	if step == Step.STAMP and t > 1.8 and int(t * 10.0) % 10 == 0 and t < 1.9:
		PopAudio.play_ui("fail", 1.0, -2.0)
	if step == Step.STAMP and t > 4.5:
		step = Step.CREDITS
		t = 0.0
	if step == Step.CREDITS:
		_credit_y += delta * 46.0
		var lines: int = sim.story.credits(Settings.language).size()
		if _credit_y > float(lines) * 56.0 + 380.0:
			step = Step.FREELANCE
			t = 0.0
	_button.visible = step == Step.FREELANCE
	if _button.visible:
		_button.position = get_viewport_rect().size * 0.5 + Vector2(-110.0, 80.0)
	queue_redraw()


func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var lang: String = Settings.language
	match step:
		Step.TELEGRAM, Step.STAMP:
			draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.03, 0.02, 0.78))
			_draw_telegram(vp, lang)
			_draw_frame(vp)
		Step.CREDITS:
			draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.03, 0.02, 0.35)) # la lámina se sigue reventando atrás
			_draw_credits(vp, lang)
		Step.FREELANCE:
			draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.03, 0.02, 0.35))
			var title: String = str(sim.db.story["freelance_title_" + lang])
			UiKit.draw_stamp(self, Rect2(vp * 0.5 + Vector2(-330.0, -80.0), Vector2(660.0, 92.0)), title, UiKit.STAMP_RED, 36, -0.04)
			UiKit.draw_text(self, vp * 0.5 + Vector2(-330.0, 30.0), Tx.t("ending_freelance_sub"), UiKit.font_text_bold(), 14, UiKit.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 660.0)


## Telegrama argentino: papel amarillento, cinta de texto pegada en renglones y encabezado en mayúsculas.
func _draw_telegram(vp: Vector2, lang: String) -> void:
	var slide: float = clampf(t / 0.8, 0.0, 1.0) if step == Step.TELEGRAM else 1.0
	var r: Rect2 = Rect2(Vector2(vp.x * 0.5 - TELEGRAM_SIZE.x * 0.5 + 120.0, vp.y * 0.5 - TELEGRAM_SIZE.y * 0.5 + (1.0 - slide) * 400.0), TELEGRAM_SIZE)
	UiKit.draw_sheet(self, r, Color("#F0E3B6"), "telegram", 1.5, 1.6)
	draw_rect(Rect2(r.position + Vector2(24.0, 24.0), Vector2(r.size.x - 48.0, 46.0)), Color("#2B3F7A"))
	UiKit.draw_text(self, r.position + Vector2(0.0, 56.0), sim.story.telegram_header(lang), UiKit.font_title(), 22, Color("#F4EFE6"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	UiKit.draw_text(self, r.position + Vector2(30.0, 100.0), "%s: %s" % [Tx.t("ending_to"), sim.player_name(lang).to_upper()], UiKit.font_mono_bold(), 14, UiKit.INK)
	var body: String = sim.story.telegram_body(lang)
	var shown: String = body.left(int(t * 60.0)) if step == Step.TELEGRAM else body
	# Cinta pegada: el texto va en una franja más clara, como un telegrama de verdad.
	draw_rect(Rect2(r.position + Vector2(26.0, 118.0), Vector2(r.size.x - 52.0, 240.0)), Color("#F7EFD2"))
	UiKit.draw_text(self, r.position + Vector2(36.0, 146.0), shown, UiKit.font_mono_bold(), 15, UiKit.INK, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 72.0)
	UiKit.draw_text(self, r.position + Vector2(30.0, r.size.y - 20.0), "PLASTIQUITO S.R.L. · " + Tx.t("ending_no_reply"), UiKit.font_mono(), 10, UiKit.INK_SOFT)


## El cuadro de "EMPLEADO DEL MES" con tu foto: recibe el sello rojo "EX".
func _draw_frame(vp: Vector2) -> void:
	var at: Vector2 = Vector2(vp.x * 0.5 - TELEGRAM_SIZE.x * 0.5 - 220.0, vp.y * 0.5 - 130.0)
	draw_rect(Rect2(at + Vector2(-8.0, -8.0), Vector2(196.0, 252.0)), Color("#5A3A1E"))
	draw_rect(Rect2(at, Vector2(180.0, 236.0)), Color("#F4EFE6"))
	UiKit.draw_text(self, at + Vector2(0.0, 28.0), Tx.t("employee_month"), UiKit.font_title(), 14, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, 180.0)
	if _photo != null:
		draw_texture_rect(_photo, Rect2(at + Vector2(24.0, 44.0), Vector2(132.0, 132.0)), false)
	UiKit.draw_text(self, at + Vector2(0.0, 206.0), sim.player_name(Settings.language), UiKit.font_text_bold(), 13, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, 180.0)
	if step == Step.STAMP:
		var k: float = clampf((t - 1.2) / 0.35, 0.0, 1.0)
		if k > 0.0:
			var punch: float = 1.0 + (1.0 - k) * 1.6
			UiKit.draw_stamp(self, Rect2(at + Vector2(28.0 - 16.0 * punch, 66.0 - 16.0 * punch), Vector2(124.0, 80.0) * punch), _stamp_text(), UiKit.STAMP_RED, int(54.0 * punch), -0.3, k)


func _stamp_text() -> String:
	var tg: Dictionary = sim.db.story["telegram"]
	return str(tg["stamp_" + Settings.language])


func _draw_credits(vp: Vector2, lang: String) -> void:
	var lines: Array = sim.story.credits(lang)
	for i: int in lines.size():
		var y: float = vp.y - _credit_y + float(i) * 56.0
		if y < -40.0 or y > vp.y + 40.0:
			continue
		var big: bool = i == 0
		UiKit.draw_text(self, Vector2(0.0, y), str(lines[i]), UiKit.font_title() if big else UiKit.font_text_bold(), 34 if big else 20, UiKit.PAPER, HORIZONTAL_ALIGNMENT_CENTER, vp.x)
