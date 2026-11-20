class_name MemoCard
extends Control
## Memo escrito a máquina que llega sujeto a la hoja de pedidos (sección 7 de la 0.7.0): el jefe NUNCA aparece
## en pantalla, solo firma con un garabato ilegible y el sello de la empresa. 2-3 líneas; un clic lo cierra.
## Con la bienvenida y los ascensos también muestra la credencial de empleado (foto carnet estilizada, nombre
## y cargo).

signal dismissed

const W: float = 360.0

var sim: GameSim
var suppressed: bool = false ## capturas de CI y demos: sin memos encima
var _shown_id: String = ""
var _typed: float = 0.0
var _text: String = ""
var _photo: ImageTexture


func setup(p_sim: GameSim) -> void:
	sim = p_sim
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(W, 170.0)
	size = custom_minimum_size
	rotation = deg_to_rad(1.4)
	pivot_offset = size * 0.5
	material = UiKit.paper_material()
	visible = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if _typed < float(_text.length()): # el primer clic termina de tipear; el segundo lo cierra
				_typed = float(_text.length())
			else:
				sim.dismiss_memo()
				PopAudio.play_ui("stamp", 1.3, -6.0)
				dismissed.emit()
			accept_event()


func _text_x() -> float:
	return 22.0 + (118.0 if _with_credential() else 0.0)


func _with_credential() -> bool:
	return _shown_id == "welcome" or _shown_id == "promotion"


func _process(delta: float) -> void:
	var id: String = sim.current_memo() if sim != null else ""
	visible = id != "" and not sim.ending_pending and not suppressed
	if not visible:
		_shown_id = ""
		return
	if id != _shown_id:
		_shown_id = id
		_typed = 0.0
		_text = sim.memo_text_now(Settings.language)
		_photo = PlayerIdentity.id_texture(112)
		var tw: float = size.x - _text_x() - 22.0
		var n_lines: int = UiKit.wrap_text(UiKit.font_mono(), _text, 12, tw).size()
		size.y = maxf(196.0 if _with_credential() else 150.0, 112.0 + 16.0 * float(n_lines))
		pivot_offset = size * 0.5
		PopAudio.play_ui("tic", 0.8, -8.0)
	var before: int = int(_typed)
	_typed = minf(float(_text.length()), _typed + delta * 55.0)
	if floori(_typed / 3.0) != floori(float(before) / 3.0) and int(_typed) < _text.length():
		PopAudio.play_ui("tic", 1.6, -16.0) # tecla de la máquina de escribir
	queue_redraw()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2(4.0, 6.0), Vector2(size.x - 10.0, size.y - 12.0))
	UiKit.draw_sheet(self, rect, Color("#F3EEDC"), "memo", 1.0)
	# Broche y membrete.
	draw_rect(Rect2(Vector2(rect.position.x + rect.size.x * 0.5 - 22.0, 0.0), Vector2(44.0, 14.0)), Color("#8E949A"))
	UiKit.draw_text(self, Vector2(20.0, 34.0), "MEMO · " + Tx.t("memo_company"), UiKit.font_mono_bold(), 11, UiKit.INK_SOFT)
	draw_line(Vector2(18.0, 42.0), Vector2(size.x - 24.0, 42.0), UiKit.INK_SOFT, 1.0)
	var shown: String = _text.left(int(_typed))
	var tx: float = _text_x()
	var full: PackedStringArray = UiKit.wrap_text(UiKit.font_mono(), _text, 12, size.x - tx - 22.0)
	var left: int = int(_typed)
	for i: int in full.size():
		if left <= 0:
			break
		UiKit.draw_text(self, Vector2(tx, 66.0 + 16.0 * float(i)), full[i].left(left), UiKit.font_mono(), 12, UiKit.INK)
		left -= full[i].length() + 1
	if _with_credential():
		_draw_credential(Vector2(18.0, 54.0))
	# Firma ilegible (garabato) y sello de la empresa.
	var sy: float = size.y - 28.0
	draw_polyline(PackedVector2Array([Vector2(size.x - 150.0, sy), Vector2(size.x - 138.0, sy - 12.0), Vector2(size.x - 128.0, sy + 3.0),
		Vector2(size.x - 116.0, sy - 10.0), Vector2(size.x - 104.0, sy + 2.0), Vector2(size.x - 90.0, sy - 6.0), Vector2(size.x - 70.0, sy - 2.0)]), Color("#2B3F7A"), 1.8)
	UiKit.draw_stamp(self, Rect2(Vector2(20.0, size.y - 44.0), Vector2(120.0, 26.0)), "PLASTIQUITO S.R.L.", UiKit.STAMP_RED, 9, -0.06, 0.8)
	if _typed >= float(_text.length()):
		UiKit.draw_text(self, Vector2(size.x - 128.0, size.y - 8.0), Tx.t("memo_close"), UiKit.font_mono(), 9, UiKit.INK_SOFT)


## La credencial: foto carnet, nombre y cargo en una tarjetita con cinta.
func _draw_credential(at: Vector2) -> void:
	var card: Rect2 = Rect2(at, Vector2(104.0, 118.0))
	UiKit.draw_sheet(self, card, Color("#E9F0F2"), "credential", 0.5, 1.0)
	draw_rect(Rect2(card.position, Vector2(card.size.x, 14.0)), Color("#2B3F7A"))
	UiKit.draw_text(self, card.position + Vector2(0.0, 11.0), Tx.t("memo_credential"), UiKit.font_mono_bold(), 8, Color("#F4EFE6"), HORIZONTAL_ALIGNMENT_CENTER, card.size.x)
	if _photo != null:
		draw_texture_rect(_photo, Rect2(card.position + Vector2(18.0, 18.0), Vector2(68.0, 68.0)), false)
	var nm: String = sim.player_name(Settings.language)
	UiKit.draw_text(self, card.position + Vector2(2.0, 98.0), nm, UiKit.font_text_bold(), UiKit.fit_size(UiKit.font_text_bold(), nm, 12, card.size.x - 6.0), UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, card.size.x - 4.0)
	var rk: String = sim.story.rank_name(sim.state.last_rank, Settings.language)
	UiKit.draw_text(self, card.position + Vector2(2.0, 111.0), rk, UiKit.font_mono(), UiKit.fit_size(UiKit.font_mono(), rk, 9, card.size.x - 6.0), UiKit.STAMP_RED, HORIZONTAL_ALIGNMENT_CENTER, card.size.x - 4.0)
