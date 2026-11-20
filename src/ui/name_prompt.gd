class_name NamePrompt
extends Control
## Ficha de empleado: la primera vez, sin Steam, la empresa pregunta "¿Cómo te llamás?". Si no se completa, el
## jugador queda como "Empleado N° 4417". El nombre se guarda solo en el guardado local.

signal done(player_name: String)

var _edit: LineEdit
var _ok: StampButton
var _skip: StampButton


func setup() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_edit = LineEdit.new()
	_edit.custom_minimum_size = Vector2(340.0, 38.0)
	_edit.size = _edit.custom_minimum_size
	_edit.max_length = 24
	_edit.placeholder_text = Tx.t("name_hint")
	_edit.add_theme_font_override("font", UiKit.font_text_bold())
	_edit.add_theme_font_size_override("font_size", 18)
	_edit.text_submitted.connect(func(_t: String) -> void: _confirm())
	add_child(_edit)
	_ok = StampButton.new()
	_ok.setup(Tx.t("name_ok"), Vector2(150.0, 48.0), UiKit.STAMP_RED)
	_ok.filled = true
	_ok.pressed.connect(_confirm)
	add_child(_ok)
	_skip = StampButton.new()
	_skip.setup(Tx.t("name_skip"), Vector2(190.0, 40.0), UiKit.CARDBOARD_DARK)
	_skip.font_size = 12
	_skip.pressed.connect(func() -> void: _close(""))
	add_child(_skip)


func open_prompt() -> void:
	visible = true
	_edit.text = ""
	_edit.grab_focus()


func _confirm() -> void:
	_close(_edit.text.strip_edges())


func _close(player_name: String) -> void:
	visible = false
	done.emit(player_name)


func _process(_delta: float) -> void:
	if not visible:
		return
	var c: Vector2 = get_viewport_rect().size * 0.5
	_edit.position = c + Vector2(-170.0, -12.0)
	_ok.position = c + Vector2(-180.0, 50.0)
	_skip.position = c + Vector2(-10.0, 54.0)
	queue_redraw()


func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.07, 0.04, 0.02, 0.7))
	var c: Vector2 = vp * 0.5
	var r: Rect2 = Rect2(c + Vector2(-230.0, -150.0), Vector2(460.0, 330.0))
	UiKit.draw_sheet(self, r, Color("#FFF6D8"), "name_card", 1.2, 1.4)
	UiKit.draw_text(self, r.position + Vector2(0.0, 40.0), Tx.t("name_title"), UiKit.font_title(), 22, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	UiKit.draw_text(self, r.position + Vector2(0.0, 66.0), Tx.t("memo_company"), UiKit.font_mono_bold(), 11, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	UiKit.draw_text(self, r.position + Vector2(0.0, 112.0), Tx.t("name_question"), UiKit.font_text_bold(), 18, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	UiKit.draw_text(self, r.position + Vector2(0.0, r.size.y - 14.0), Tx.t("name_privacy"), UiKit.font_mono(), 9, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
