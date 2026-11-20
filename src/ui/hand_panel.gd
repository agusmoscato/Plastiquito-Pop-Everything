class_name HandPanel
extends Control
## "MI MANO": la mano del jugador de cerca, girando sobre un mostrador de joyería de barrio, con las
## ranuras, los accesorios disponibles y sus precios en Pellets. Al comprar, la mano se pone el
## accesorio (sonido propio). Los accesorios son permanentes: no se pierden al reciclar.

signal closed

const W: float = 1020.0
const H: float = 700.0
const CARD: Vector2 = Vector2(246.0, 58.0)
const VIEW: Vector2 = Vector2(430.0, 470.0)
const SLOT_LABEL: Dictionary = {
	"ring0": {"es": "ANILLO · ÍNDICE", "en": "RING · INDEX"}, "ring1": {"es": "ANILLO · MEDIO", "en": "RING · MIDDLE"},
	"ring2": {"es": "ANILLO · ANULAR", "en": "RING · RING FINGER"}, "bracelet": {"es": "PULSERA", "en": "BRACELET"},
	"watch": {"es": "RELOJ", "en": "WATCH"}, "glove": {"es": "GUANTE", "en": "GLOVE"},
}

var sim: GameSim

var _close_button: StampButton
var _container: SubViewportContainer
var _viewport: SubViewport
var _pivot: Node3D
var _rig: HandRig
var _built_sig: String = "?"
var _spin: float = 0.0
var _hover: String = ""
var _flash: float = 0.0
var _message: String = ""


func setup(p_sim: GameSim) -> void:
	sim = p_sim
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_view()
	_close_button = StampButton.new()
	_close_button.setup(Tx.t("close"), Vector2(130.0, 44.0), UiKit.CARDBOARD_DARK)
	_close_button.font_size = 14
	_close_button.pressed.connect(close_panel)
	add_child(_close_button)


func open_panel() -> void:
	visible = true
	_built_sig = "?"
	_message = ""
	_layout()


func close_panel() -> void:
	visible = false
	closed.emit()


func _origin() -> Vector2:
	var vp: Vector2 = get_viewport_rect().size
	return Vector2((vp.x - W) * 0.5, (vp.y - H) * 0.5)


func _layout() -> void:
	var o: Vector2 = _origin()
	_container.position = o + Vector2(34.0, 132.0)
	_close_button.position = o + Vector2(W - 170.0, H - 66.0)


# --- Vista 3D: el mostrador y la mano -------------------------------------------------------------

func _build_view() -> void:
	_container = SubViewportContainer.new()
	_container.stretch = true
	_container.size = VIEW
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(int(VIEW.x), int(VIEW.y))
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_container.add_child(_viewport)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#2A1D14")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#FFE2B8")
	env.ambient_light_energy = 0.55
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)
	var key: OmniLight3D = OmniLight3D.new()
	key.light_color = Color("#FFD9A0")
	key.light_energy = 1.4
	key.omni_range = 2.0
	key.position = Vector3(0.12, 0.35, 0.18)
	_viewport.add_child(key)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.light_energy = 0.55
	fill.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	_viewport.add_child(fill)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 32.0
	cam.position = Vector3(0.0, 0.40, 0.34)
	_viewport.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0.0, 0.0, -0.01), Vector3.UP)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	_build_counter()


## El mostrador de joyería de barrio: paño verde oscuro, marco de madera y un cartelito de precio.
func _build_counter() -> void:
	var felt: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.46, 0.02, 0.34)
	felt.mesh = bm
	felt.position = Vector3(0.0, -0.024, -0.01)
	felt.material_override = ToolMeshes.material(Color("#2F5B45"))
	_viewport.add_child(felt)
	var frame: MeshInstance3D = MeshInstance3D.new()
	var fm: BoxMesh = BoxMesh.new()
	fm.size = Vector3(0.50, 0.018, 0.38)
	frame.mesh = fm
	frame.position = Vector3(0.0, -0.036, -0.01)
	frame.material_override = ToolMeshes.material(Color("#8A5A32"))
	_viewport.add_child(frame)
	var plinth: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.07
	cm.bottom_radius = 0.075
	cm.height = 0.012
	plinth.mesh = cm
	plinth.position = Vector3(0.0, -0.011, 0.0)
	plinth.material_override = ToolMeshes.material(Color("#7B2430")) # almohadón bordó
	_viewport.add_child(plinth)


func _rebuild_hand() -> void:
	if _rig != null:
		_rig.queue_free()
	ToolMeshes.equipped = sim.state.acc_equipped
	_rig = HandRig.new()
	_rig.setup("palm", ToolMeshes.hand_material())
	_pivot.add_child(_rig)
	_rig.position = Vector3(0.0, 0.016, 0.0)
	ToolMeshes.add_outline(_rig, ToolMeshes.OUTLINE_DARK)
	_built_sig = ToolMeshes.equipped_signature()
	_flash = 1.0


# --- Lógica de la lista -----------------------------------------------------------------------------

## Lugar de cada tarjeta del catálogo (2 columnas), relativo al panel.
func _card_rect(i: int) -> Rect2:
	var col: int = i % 2
	@warning_ignore("integer_division")
	var row: int = i / 2
	return Rect2(Vector2(500.0 + float(col) * (CARD.x + 10.0), 128.0 + float(row) * (CARD.y + 8.0)), CARD)


func _slot_rect(i: int) -> Rect2:
	return Rect2(Vector2(34.0 + float(i) * 70.0, 620.0), Vector2(64.0, 56.0))


func _gui_input(event: InputEvent) -> void:
	var o: Vector2 = _origin()
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		_hover = _id_at(mm.position - o)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var id: String = _id_at(mb.position - o)
			if id != "":
				_click(id)
				accept_event()


func _id_at(p: Vector2) -> String:
	var ids: Array[String] = sim.acc.ids()
	for i: int in ids.size():
		if _card_rect(i).has_point(p):
			return ids[i]
	return ""


## Click en un accesorio: lo compra (si alcanzan los Pellets), o lo pone / lo saca si ya es tuyo.
func _click(id: String) -> void:
	var lang: String = Settings.language
	var acc_name: String = str(sim.acc.def(id)["name_" + lang])
	if sim.state.acc_owned.has(id):
		var worn: String = _slot_of(id)
		if worn != "":
			sim.unequip_accessory(worn)
			_message = Tx.t("hand_taken_off") % acc_name
			return
		var slot: String = _free_slot_for(id)
		if slot == "":
			slot = _first_slot_for(id)
		sim.equip_accessory(slot, id)
		PopAudio.play_ui("clink", 1.0, -2.0)
		_message = Tx.t("hand_put_on") % acc_name
		return
	if sim.buy_accessory(id):
		PopAudio.play_ui("clink", randf_range(0.95, 1.08))
		_message = Tx.t("hand_bought") % acc_name
	else:
		PopAudio.play_ui("tic", 0.7, -3.0)
		_message = Tx.t("hand_poor") % [int(sim.acc.cost_of(id)), acc_name]


func _slot_of(id: String) -> String:
	for slot: String in Accessories.SLOTS:
		if str(sim.state.acc_equipped.get(slot, "")) == id:
			return slot
	return ""


func _free_slot_for(id: String) -> String:
	for slot: String in Accessories.SLOTS:
		if sim.acc.fits(slot, id) and not sim.state.acc_equipped.has(slot):
			return slot
	return ""


func _first_slot_for(id: String) -> String:
	for slot: String in Accessories.SLOTS:
		if sim.acc.fits(slot, id):
			return slot
	return ""


# --- Dibujo ----------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not visible:
		return
	_layout()
	_spin += delta * 0.55
	_flash = maxf(0.0, _flash - delta * 3.0)
	if _built_sig != ToolMeshes.equipped_signature() or _rig == null or _built_sig == "?":
		ToolMeshes.equipped = sim.state.acc_equipped
		if _built_sig != ToolMeshes.equipped_signature() or _rig == null:
			_rebuild_hand()
	_pivot.rotation = Vector3(deg_to_rad(18.0), sin(_spin) * 0.9 + 0.35, 0.0)
	_pivot.scale = Vector3.ONE * (1.0 + 0.06 * _flash)
	queue_redraw()


func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.07, 0.04, 0.02, 0.66))
	var o: Vector2 = _origin()
	var lang: String = Settings.language
	# Mostrador: madera con paño y un letrero escrito a mano.
	draw_rect(Rect2(o + Vector2(5.0, 6.0), Vector2(W, H)), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(o, Vector2(W, H)), Color("#6B4426"))
	draw_rect(Rect2(o, Vector2(W, H)), Color("#3B2514"), false, 12.0)
	UiKit.draw_sheet(self, Rect2(o + Vector2(30.0, 22.0), Vector2(520.0, 70.0)), UiKit.PAPER, "hand_title", 1.5, 1.4)
	UiKit.draw_text(self, o + Vector2(48.0, 56.0), Tx.t("my_hand"), UiKit.font_title(), 24, UiKit.INK)
	UiKit.draw_text(self, o + Vector2(48.0, 80.0), Tx.t("my_hand_sub"), UiKit.font_text(), 12, UiKit.CARDBOARD_DARK)
	var bal: String = "%s: %s" % [Tx.t("pellets"), NumberFormat.pops(sim.state.pellets, lang)]
	UiKit.draw_stamp(self, Rect2(o + Vector2(W - 330.0, 28.0), Vector2(290.0, 44.0)), bal, UiKit.STAMP_RED, 17, -0.03)
	draw_rect(Rect2(_container.position - Vector2(4.0, 4.0), VIEW + Vector2(8.0, 8.0)), Color("#3B2514"), false, 4.0)
	_draw_slots(o)
	_draw_catalog(o, lang)
	if _message != "":
		UiKit.draw_text(self, o + Vector2(500.0, H - 46.0), _message, UiKit.font_mono_bold(), 13, UiKit.PAPER)


func _draw_slots(o: Vector2) -> void:
	UiKit.draw_text(self, o + Vector2(34.0, 606.0), Tx.t("my_hand_slots"), UiKit.font_mono_bold(), 11, UiKit.PAPER)
	for i: int in Accessories.SLOTS.size():
		var slot: String = Accessories.SLOTS[i]
		var r: Rect2 = _slot_rect(i)
		r.position += o
		var id: String = str(sim.state.acc_equipped.get(slot, ""))
		UiKit.draw_sheet(self, r, UiKit.PAPER if id != "" else UiKit.PAPER_SHADE, "slot" + slot, 0.5, 1.0)
		var label: String = str(SLOT_LABEL[slot][Settings.language])
		UiKit.draw_text(self, r.position + Vector2(2.0, 17.0), label.get_slice(" · ", 0).left(7), UiKit.font_mono_bold(), 9, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 4.0)
		if slot.begins_with("ring"):
			UiKit.draw_text(self, r.position + Vector2(2.0, 30.0), label.get_slice(" · ", 1).left(8), UiKit.font_mono(), 9, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 4.0)
		if id != "":
			var look: Dictionary = sim.acc.def(id)["look"]
			draw_circle(r.position + Vector2(r.size.x * 0.5, 42.0), 7.0, Color(str(look["color"])))
		else:
			UiKit.draw_text(self, r.position + Vector2(2.0, 46.0), "—", UiKit.font_mono_bold(), 14, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 4.0)


func _draw_catalog(o: Vector2, lang: String) -> void:
	var ids: Array[String] = sim.acc.ids()
	for i: int in ids.size():
		var id: String = ids[i]
		var d: Dictionary = sim.acc.def(id)
		var r: Rect2 = _card_rect(i)
		r.position += o
		var owned: bool = sim.state.acc_owned.has(id)
		var worn: bool = _slot_of(id) != ""
		var cost: int = sim.acc.cost_of(id)
		var base: Color = UiKit.PAPER if (owned or sim.state.pellets >= float(cost)) else UiKit.PAPER_SHADE
		UiKit.draw_sheet(self, r, base, "acc_" + id, 1.0 if _hover == id else 0.0, 1.0)
		var look: Dictionary = d["look"]
		draw_circle(r.position + Vector2(20.0, r.size.y * 0.5), 9.0, Color(str(look["color"])))
		draw_arc(r.position + Vector2(20.0, r.size.y * 0.5), 9.0, 0.0, TAU, 16, UiKit.INK, 1.5)
		var title: String = str(d["name_" + lang])
		var fs: int = UiKit.fit_size(UiKit.font_title(), title, 13, r.size.x - 82.0)
		UiKit.draw_text(self, r.position + Vector2(38.0, 20.0), title, UiKit.font_title(), fs, UiKit.INK)
		var desc: String = str(d["desc_" + lang])
		var ds: int = UiKit.fit_size(UiKit.font_text(), desc, 10, r.size.x - 46.0)
		UiKit.draw_text(self, r.position + Vector2(38.0, 36.0), desc, UiKit.font_text(), ds, UiKit.CARDBOARD_DARK)
		var tag: String = Tx.t("hand_worn") if worn else (Tx.t("hand_owned") if owned else "%d" % cost)
		UiKit.draw_text(self, r.position + Vector2(r.size.x - 62.0, 18.0), tag, UiKit.font_mono_bold(), 12, UiKit.STAMP_RED if not owned else UiKit.INK, HORIZONTAL_ALIGNMENT_RIGHT, 56.0)
		if not owned:
			UiKit.draw_text(self, r.position + Vector2(r.size.x - 62.0, 32.0), Tx.t("pellets").to_lower(), UiKit.font_mono(), 9, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_RIGHT, 56.0)
