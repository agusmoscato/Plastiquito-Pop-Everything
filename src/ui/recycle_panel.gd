class_name RecyclePanel
extends Control
## Centro de reciclado: cuántos Pellets se ganan (en vivo), las mejoras permanentes y el botón
## para reciclar. También sirve para gastar Pellets después de reciclar.

signal recycle_requested
signal closed
signal perm_bought(id: String, count: int)

const W: float = 470.0
const H: float = 720.0

var sim: GameSim

var _tags: Array[UpgradeTag] = []
var _recycle_button: StampButton
var _close_button: StampButton


func setup(p_sim: GameSim) -> void:
	sim = p_sim
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	for id: String in sim.upgrades.ids_for_scope("perm"):
		var tag: UpgradeTag = UpgradeTag.new()
		tag.setup(sim, id, func() -> int: return 1)
		tag.bought.connect(func(i: String, n: int, _ms: bool) -> void: perm_bought.emit(i, n))
		add_child(tag)
		_tags.append(tag)
	_recycle_button = StampButton.new()
	_recycle_button.setup(Tx.t("recycle_now"), Vector2(250.0, 52.0), UiKit.STAMP_RED)
	_recycle_button.font_size = 18
	_recycle_button.pressed.connect(func() -> void: recycle_requested.emit())
	add_child(_recycle_button)
	_close_button = StampButton.new()
	_close_button.setup(Tx.t("close"), Vector2(130.0, 44.0), UiKit.CARDBOARD_DARK)
	_close_button.font_size = 14
	_close_button.pressed.connect(close_panel)
	add_child(_close_button)


func open_panel() -> void:
	visible = true
	_layout()


func close_panel() -> void:
	visible = false
	closed.emit()


func _layout() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var left: float = (vp.x - W) * 0.5
	var top: float = (vp.y - H) * 0.5
	for i: int in _tags.size():
		_tags[i].position = Vector2(left + 36.0, top + 150.0 + float(i) * 114.0)
	_recycle_button.position = Vector2(left + 28.0, top + H - 74.0)
	_close_button.position = Vector2(left + W - 160.0, top + H - 70.0)


func _process(_delta: float) -> void:
	if not visible:
		return
	_recycle_button.disabled = not sim.can_recycle()
	queue_redraw()


func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.07, 0.04, 0.02, 0.62))
	var rect: Rect2 = Rect2(Vector2((vp.x - W) * 0.5, (vp.y - H) * 0.5), Vector2(W, H))
	UiKit.draw_sheet(self, rect, UiKit.KRAFT, "recycle_board", 4.0, 2.2)
	UiKit.draw_tape(self, rect.position + Vector2(40.0, 6.0), -0.5, 60.0, 18.0)
	UiKit.draw_tape(self, Vector2(rect.end.x - 40.0, rect.position.y + 6.0), 0.5, 60.0, 18.0)
	var x: float = rect.position.x + 28.0
	UiKit.draw_text(self, Vector2(x, rect.position.y + 52.0), Tx.t("recycle_title"), UiKit.font_title(), 24, UiKit.INK)
	UiKit.draw_text(self, Vector2(x, rect.position.y + 76.0), Tx.t("recycle_hint"), UiKit.font_text(), 13, UiKit.CARDBOARD_DARK)
	var gain: int = sim.recycle_gain()
	var gain_text: String = "%s: %d %s" % [Tx.t("recycle_gain"), gain, Tx.t("pellets")]
	UiKit.draw_stamp(self, Rect2(Vector2(x, rect.position.y + 92.0), Vector2(300.0, 40.0)), gain_text, UiKit.STAMP_RED if gain >= 1 else UiKit.INK_SOFT, 17, -0.03)
	var bal: String = "%s: %s" % [Tx.t("pellets"), NumberFormat.pops(sim.state.pellets, Settings.language)]
	UiKit.draw_text(self, Vector2(rect.end.x - 190.0, rect.position.y + 118.0), bal, UiKit.font_mono_bold(), 14, UiKit.INK, HORIZONTAL_ALIGNMENT_RIGHT, 160.0)
