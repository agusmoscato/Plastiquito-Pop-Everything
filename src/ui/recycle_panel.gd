class_name RecyclePanel
extends Control
## Centro de reciclado: un tablero de corcho con las mejoras permanentes como ffichas clavadas
## con chinches, unidas con hilo rojo cuando una requiere otra. Muestra los Pellets que se ganan
## (en vivo) y el botón de reciclar. También sirve para gastar Pellets después de reciclar.

signal recycle_requested
signal closed
signal perm_bought(id: String, count: int)

const W: float = 1000.0
const H: float = 700.0

## Posición de cada ficha en el tablero (esquina superior izquierda, relativa al tablero).
const LAYOUT: Dictionary = {
	"perm_sheet": Vector2(36, 150), "perm_bonus": Vector2(278, 156), "perm_memory": Vector2(522, 150), "perm_golden": Vector2(762, 160),
	"perm_finger": Vector2(30, 292), "perm_palm": Vector2(274, 300), "perm_pin": Vector2(518, 290), "perm_auto": Vector2(764, 298),
	"perm_iron": Vector2(276, 438), "perm_boot": Vector2(520, 442),
}

var sim: GameSim

var _cards: Dictionary = {} ## id -> PermCard
var _recycle_button: StampButton
var _close_button: StampButton


func setup(p_sim: GameSim) -> void:
	sim = p_sim
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	for id: String in sim.upgrades.ids_for_scope("perm"):
		var card: PermCard = PermCard.new()
		card.setup(sim, id)
		card.bought.connect(func(i: String, n: int) -> void: perm_bought.emit(i, n))
		add_child(card)
		_cards[id] = card
	_recycle_button = StampButton.new()
	_recycle_button.setup(Tx.t("recycle_now"), Vector2(260.0, 54.0), UiKit.STAMP_RED)
	_recycle_button.font_size = 19
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


func _origin() -> Vector2:
	var vp: Vector2 = get_viewport_rect().size
	return Vector2((vp.x - W) * 0.5, (vp.y - H) * 0.5)


func _layout() -> void:
	var o: Vector2 = _origin()
	for id: String in _cards:
		var card: PermCard = _cards[id]
		var p: Vector2 = LAYOUT.get(id, Vector2(30, 150))
		card.position = o + p
	_recycle_button.position = o + Vector2(36.0, H - 76.0)
	_close_button.position = o + Vector2(W - 170.0, H - 72.0)


func _process(_delta: float) -> void:
	if not visible:
		return
	_layout()
	_recycle_button.disabled = not sim.can_recycle()
	queue_redraw()


func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.07, 0.04, 0.02, 0.62))
	var o: Vector2 = _origin()
	var rect: Rect2 = Rect2(o, Vector2(W, H))
	_draw_cork(rect)
	var x: float = o.x + 36.0
	# Cartel de título pegado al corcho.
	UiKit.draw_sheet(self, Rect2(Vector2(x - 8.0, o.y + 22.0), Vector2(560.0, 62.0)), UiKit.PAPER, "board_title", 1.5, 1.4)
	UiKit.draw_text(self, Vector2(x + 8.0, o.y + 52.0), Tx.t("recycle_title"), UiKit.font_title(), 22, UiKit.INK)
	UiKit.draw_text(self, Vector2(x + 8.0, o.y + 74.0), Tx.t("recycle_hint"), UiKit.font_text(), 12, UiKit.CARDBOARD_DARK)
	var gain: int = sim.recycle_gain()
	var gain_text: String = "%s: %d %s" % [Tx.t("recycle_gain"), gain, Tx.t("pellets")]
	UiKit.draw_stamp(self, Rect2(Vector2(o.x + W - 372.0, o.y + 26.0), Vector2(320.0, 40.0)), gain_text, UiKit.STAMP_RED if gain >= 1 else UiKit.INK_SOFT, 16, -0.03)
	var bal: String = "%s: %s" % [Tx.t("pellets"), NumberFormat.pops(sim.state.pellets, Settings.language)]
	UiKit.draw_text(self, Vector2(o.x + W - 372.0, o.y + 92.0), bal, UiKit.font_mono_bold(), 14, UiKit.PAPER, HORIZONTAL_ALIGNMENT_RIGHT, 320.0)
	_draw_yarn()


## Corcho: marrón con puntitos más claros y oscuros (determinísticos), marco de madera.
func _draw_cork(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position + Vector2(5.0, 6.0), rect.size), Color(0, 0, 0, 0.35))
	draw_rect(rect, Color("#B98A58"))
	for i: int in 900:
		var px: float = rect.position.x + 14.0 + UiKit.hash01("cork", i * 3) * (rect.size.x - 28.0)
		var py: float = rect.position.y + 14.0 + UiKit.hash01("cork", i * 3 + 1) * (rect.size.y - 28.0)
		var dark: bool = UiKit.hash01("cork", i * 3 + 2) > 0.5
		draw_circle(Vector2(px, py), 1.0 + UiKit.hash01("corkr", i) * 2.2, Color(0.35, 0.22, 0.1, 0.22) if dark else Color(0.95, 0.8, 0.55, 0.28))
	draw_rect(rect, Color("#5A4330"), false, 12.0)
	draw_rect(rect.grow(-12.0), Color(0, 0, 0, 0.25), false, 2.0)


## Hilo rojo entre una ficha y la que requiere (de chinche a chinche, con un poco de panza).
func _draw_yarn() -> void:
	for id: String in _cards:
		var req: Dictionary = sim.upgrades.def(id)["requires"]
		if not req.has("upgrade"):
			continue
		var need: String = str(req["upgrade"])
		if not _cards.has(need):
			continue
		var a: PermCard = _cards[need]
		var b: PermCard = _cards[id]
		var pa: Vector2 = a.position + Vector2(PermCard.W * 0.5, 12.0)
		var pb: Vector2 = b.position + Vector2(PermCard.W * 0.5, 12.0)
		var mid: Vector2 = (pa + pb) * 0.5 + Vector2(0.0, 18.0)
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in 13:
			var t: float = float(i) / 12.0
			pts.append(pa.lerp(mid, t).lerp(mid.lerp(pb, t), t))
		draw_polyline(pts, Color(0, 0, 0, 0.3), 3.0, true)
		draw_polyline(pts, UiKit.STAMP_RED, 2.0, true)
