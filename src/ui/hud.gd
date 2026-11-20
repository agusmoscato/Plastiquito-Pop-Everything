class_name Hud
extends CanvasLayer
## El HUD como escritorio de un depósito de embalaje (docs/UI_STYLE.md). Junta todas las piezas,
## traduce los eventos de GameSim a feedback (números voladores, sellos, sonidos) y no guarda
## estado de juego: lo lee de GameSim.

signal tool_selected(id: String)
signal purchased(id: String, count: int, milestone: bool)
signal recycle_confirmed
signal chain_slammed(count: int)
signal reload_requested

const SHOP_W: float = 452.0

var sim: GameSim
var camera: Camera3D

var root: Control
var pops_panel: PopsPanel
var work_order: WorkOrder
var combo: ComboMeter
var chain_stamp: ChainStamp
var night_stamp: NightStamp
var flyers: FlyingNumbers
var shop: ShopSheet
var recycle_panel: RecyclePanel
var hand_panel: HandPanel
var route_panel: RoutePanel
var _route_button: StampButton
var _hand_button: StampButton
var bubble_log: BubbleLog
var special_card: SpecialCard
var encargo_ticket: EncargoTicket
var big_ticket: BigOrderTicket
var memo_card: MemoCard
var _zen: bool = false
var _intro_timer: float = 0.0

var _tool_buttons: Dictionary = {} ## id -> StampButton
var _recycle_button: StampButton
var _reload_button: StampButton ## "TIRAR LÁMINA NUEVA": aparece con la lámina terminada si no hay recarga automática
var _log_button: StampButton
var _in_flight: float = 0.0
var _group_value: float = 0.0
var _group_pos: Vector2 = Vector2.ZERO
var _group_count: int = 0
var _chain_origin: Vector2 = Vector2(-1.0, -1.0)
var _rate_acc: float = 0.0
var _rate_shown: float = 0.0
var _rate_timer: float = 0.0
var _refresh_timer: float = 0.0
var _shake_t: float = 0.0
var _tic_cooldown: float = 0.0
var _banner_t: float = 0.0
var _banner_text: String = ""
var _banner_joke: String = ""
var _last_vp: Vector2 = Vector2.ZERO
var _banner_ctl: Control
var _tab_timer: float = 0.0
var offline_ticket: OfflineTicket
var _arrow_t: float = 0.0
var _arrow_id: String = ""
var _arrow_ctl: Control


func setup(p_sim: GameSim, p_camera: Camera3D) -> void:
	sim = p_sim
	camera = p_camera
	layer = 20
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	pops_panel = PopsPanel.new()
	pops_panel.setup(sim)
	root.add_child(pops_panel)
	work_order = WorkOrder.new()
	work_order.setup(sim)
	root.add_child(work_order)
	encargo_ticket = EncargoTicket.new()
	encargo_ticket.setup(sim)
	root.add_child(encargo_ticket)
	big_ticket = BigOrderTicket.new()
	big_ticket.setup(sim)
	root.add_child(big_ticket)
	memo_card = MemoCard.new()
	memo_card.setup(sim)
	root.add_child(memo_card)
	combo = ComboMeter.new()
	combo.setup()
	root.add_child(combo)
	night_stamp = NightStamp.new()
	night_stamp.setup()
	root.add_child(night_stamp)
	shop = ShopSheet.new()
	shop.setup(sim)
	shop.tag_bought.connect(_on_tag_bought)
	shop.tag_affordable.connect(_on_affordable)
	root.add_child(shop)
	_build_toolbar()
	_build_recycle_button()
	bubble_log = BubbleLog.new()
	bubble_log.setup(sim)
	root.add_child(bubble_log)
	flyers = FlyingNumbers.new()
	flyers.setup()
	flyers.arrived.connect(_on_flyer_arrived)
	root.add_child(flyers)
	var hint: FirstHint = FirstHint.new()
	hint.setup(sim)
	root.add_child(hint)
	special_card = SpecialCard.new()
	special_card.setup()
	root.add_child(special_card)
	chain_stamp = ChainStamp.new()
	chain_stamp.setup()
	chain_stamp.slammed.connect(func(n: int) -> void: chain_slammed.emit(n))
	root.add_child(chain_stamp)
	_banner_ctl = Control.new()
	_banner_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_ctl.draw.connect(_draw_banner)
	_banner_ctl.material = UiKit.paper_material()
	root.add_child(_banner_ctl)
	_arrow_ctl = Control.new()
	_arrow_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arrow_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow_ctl.draw.connect(_draw_arrow)
	root.add_child(_arrow_ctl)
	offline_ticket = OfflineTicket.new()
	offline_ticket.setup()
	root.add_child(offline_ticket)
	recycle_panel = RecyclePanel.new()
	recycle_panel.setup(sim)
	recycle_panel.recycle_requested.connect(func() -> void: recycle_confirmed.emit())
	recycle_panel.perm_bought.connect(func(i: String, n: int) -> void: purchased.emit(i, n, false); PopAudio.play_ui("stamp"))
	root.add_child(recycle_panel)
	hand_panel = HandPanel.new()
	hand_panel.setup(sim)
	root.add_child(hand_panel)
	recycle_panel.hand_requested.connect(hand_panel.open_panel)
	route_panel = RoutePanel.new()
	route_panel.setup(sim)
	root.add_child(route_panel)
	_layout()
	pops_panel.odometer.set_target(sim.state.pops)
	pops_panel.odometer.snap()
	work_order.refresh()


## Modo zen "AHORA SOS MONOTRIBUTISTA" (después del final): sin números, trabajás por tu cuenta.
func set_zen(on: bool) -> void:
	_zen = on


func is_zen() -> bool:
	return _zen


func is_modal_open() -> bool:
	return recycle_panel.visible or offline_ticket.visible or hand_panel.visible or route_panel.visible


func open_recycle_panel() -> void:
	recycle_panel.open_panel()


func close_recycle_panel() -> void:
	recycle_panel.close_panel()


# --- Construcción ---------------------------------------------------------------------------

func _build_toolbar() -> void:
	var tools: Array[String] = ["finger", "palm", "rolling_pin", "iron", "boot"]
	for i: int in tools.size():
		var id: String = tools[i]
		var b: StampButton = StampButton.new()
		b.setup("%d %s" % [i + 1, Tx.t("tool_" + id)], Vector2(112.0, 92.0), UiKit.CARDBOARD_DARK)
		b.font_size = 13
		b.text_bottom = true
		b.pressed.connect(func() -> void: tool_selected.emit(id))
		root.add_child(b)
		var icon: ToolIcon = ToolIcon.new()
		icon.setup(id, 60, 0)
		icon.position = Vector2(26.0, 6.0)
		b.add_child(icon)
		_tool_buttons[id] = b


func _build_recycle_button() -> void:
	_recycle_button = StampButton.new()
	_recycle_button.setup(Tx.t("recycle"), Vector2(190.0, 64.0), UiKit.STAMP_RED)
	_recycle_button.font_size = 20
	_recycle_button.pressed.connect(open_recycle_panel)
	_recycle_button.visible = false
	root.add_child(_recycle_button)
	_reload_button = StampButton.new()
	_reload_button.setup(Tx.t("reload_sheet"), Vector2(300.0, 66.0), UiKit.STAMP_RED)
	_reload_button.font_size = 20
	_reload_button.filled = true
	_reload_button.sub_text = Tx.t("reload_hint")
	_reload_button.pressed.connect(func() -> void: reload_requested.emit())
	_reload_button.visible = false
	root.add_child(_reload_button)
	_log_button = StampButton.new()
	_log_button.setup(Tx.t("bubblepedia"), Vector2(150.0, 40.0), UiKit.CARDBOARD_DARK)
	_log_button.font_size = 12
	_log_button.pressed.connect(func() -> void: bubble_log.visible = not bubble_log.visible)
	root.add_child(_log_button)
	_hand_button = StampButton.new()
	_hand_button.setup(Tx.t("my_hand"), Vector2(150.0, 40.0), UiKit.CARDBOARD_DARK)
	_hand_button.font_size = 12
	_hand_button.pressed.connect(hand_panel.open_panel)
	root.add_child(_hand_button)
	_route_button = StampButton.new()
	_route_button.setup(Tx.t("route"), Vector2(150.0, 40.0), UiKit.CARDBOARD_DARK)
	_route_button.font_size = 12
	_route_button.pressed.connect(route_panel.open_panel)
	root.add_child(_route_button)


## Rectángulos fijos del HUD en una pantalla de `vp` (los mismos lugares que _layout). Sirve para
## ubicar la utilería donde se ve y para el test que mide cuánto de cada objeto queda a la vista.
static func layout_rects(vp: Vector2) -> Array[Rect2]:
	var free_w: float = vp.x - SHOP_W - 16.0
	return [
		Rect2(14.0, 10.0, 380.0, 128.0), # Pops
		Rect2(20.0, 148.0, 318.0, 142.0), # orden de trabajo
		Rect2(20.0, 300.0, 318.0, 124.0), # encargo
		Rect2(vp.x - SHOP_W - 6.0, 8.0, SHOP_W, 790.0), # hoja de pedidos
		Rect2(14.0, vp.y - 110.0, 190.0, 96.0), # ritmo
		Rect2(230.0, vp.y - 104.0, 4.0 * 118.0 + 112.0, 92.0), # herramientas
		Rect2(free_w - 210.0, vp.y - 84.0, 190.0, 64.0), # reciclar
		Rect2(free_w - 170.0, 76.0, 150.0, 40.0), # burbujario
	]


func _layout() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_last_vp = vp
	var free_w: float = vp.x - SHOP_W - 16.0
	pops_panel.position = Vector2(14.0, 10.0)
	work_order.position = Vector2(20.0, 148.0)
	encargo_ticket.position = Vector2(20.0, 148.0 + work_order.size.y + 10.0)
	big_ticket.position = Vector2(20.0, encargo_ticket.position.y + encargo_ticket.size.y + 10.0)
	memo_card.position = Vector2(vp.x - SHOP_W - 6.0 - memo_card.size.x - 12.0, 214.0)
	shop.position = Vector2(vp.x - SHOP_W - 6.0, 8.0)
	combo.position = Vector2(14.0, vp.y - 110.0)
	night_stamp.position = Vector2(18.0, vp.y - 178.0)
	var x: float = 230.0
	for id: String in _tool_buttons:
		var b: StampButton = _tool_buttons[id]
		b.position = Vector2(x, vp.y - 104.0)
		x += 118.0
	_recycle_button.position = Vector2(free_w - 210.0, vp.y - 84.0)
	_reload_button.position = Vector2(free_w * 0.5 - _reload_button.size.x * 0.5 + 40.0, vp.y - 190.0)
	_log_button.position = Vector2(free_w - 170.0, 76.0)
	_hand_button.position = Vector2(free_w - 170.0, 124.0)
	_route_button.position = Vector2(free_w - 170.0, 172.0)
	bubble_log.position = Vector2(free_w - 380.0, 224.0)
	flyers.target = pops_panel.odometer_center()
	flyers.blocked = _panel_rects()


# --- Eventos de la sim -------------------------------------------------------------------------

## Llamar una vez por frame, después de GameSim.step().
func on_sim_step(delta: float) -> void:
	_handle_pops()
	encargo_ticket.on_sim_step()
	big_ticket.on_sim_step()
	if sim.ev_encargo_done:
		PopAudio.play_ui("milestone", 1.15, -4.0)
		flyers.spawn(encargo_ticket.get_global_rect().get_center(), sim.ev_encargo_bonus)
	_notice_tried()
	var min_chain: int = Cfg.integer(sim.eco, "chain_stamp_min")
	if sim.chain_count > 0 and _chain_origin.x < 0.0 and sim.ev_idx.size() > 0:
		_chain_origin = _screen_of(sim.grid.cell_to_world(sim.ev_idx[0])) # donde arrancó la ola
	if sim.chain_count >= min_chain:
		chain_stamp.anchor = _chain_origin
		chain_stamp.chain_progress(sim.chain_count)
	if sim.ev_chain_ended_count >= min_chain:
		chain_stamp.anchor = _chain_origin
		chain_stamp.chain_ended(sim.ev_chain_ended_count, sim.ev_chain_ended_value)
		PopAudio.play_ui("chain_hit", 1.0, 0.0)
	if sim.chain_count == 0:
		_chain_origin = Vector2(-1.0, -1.0)
	_rate_acc += _sum_values()
	_rate_timer += delta


## La presentación en curso se da por aprendida cuando el jugador revienta una de esas.
func _notice_tried() -> void:
	var t: int = special_card.current_type()
	if t == 0:
		return
	if t == SpecialCard.ARMOR and not sim.ev_cracked.is_empty():
		special_card.tried(t)
		return
	for i: int in sim.ev_idx.size():
		if (t > 0 and sim.ev_type[i] == t) or (t == SpecialCard.VEIN and sim.ev_pressure[i] >= 1.8):
			special_card.tried(t)
			return


## Presenta lo que aparece por primera vez (una cosa a la vez) y le apunta la flecha.
func _update_intros(delta: float) -> void:
	_intro_timer -= delta
	var t: int = special_card.current_type()
	if t != 0:
		var idx: int = _intro_cell(t)
		special_card.pointer = _screen_of(sim.grid.cell_to_world(idx)) if idx >= 0 else Vector2.INF
		return
	if _intro_timer > 0.0 or is_modal_open() or FirstHint.wanted(sim.state.pops_total):
		return
	_intro_timer = 0.3
	for cand: int in [SpecialCard.VEIN, GameSim.TYPE_GOLDEN, GameSim.TYPE_BOMB, GameSim.TYPE_LINE, GameSim.TYPE_ECHO, SpecialCard.ARMOR]:
		if Settings.introduced.has(str(cand)) or _intro_cell(cand) < 0:
			continue
		if special_card.start_intro(cand):
			Settings.introduced[str(cand)] = true
			Settings.save_settings()
			PopAudio.play_ui("tic", 1.2, -2.0)
		return


## Una burbuja entera de lo que se presenta (la más cercana al centro de la lámina), o -1.
func _intro_cell(t: int) -> int:
	var best: int = -1
	var best_d: float = INF
	var c: Vector2 = sim.center()
	var cells: PackedInt32Array = sim.vein_cells
	if t != SpecialCard.VEIN:
		cells = PackedInt32Array()
		for idx: int in sim.sheet.cell_count():
			if (t == SpecialCard.ARMOR and sim.sheet.armor[idx] > 0) or (t > 0 and sim.sheet.type[idx] == t):
				cells.append(idx)
	for idx: int in cells:
		if sim.sheet.state[idx] == SheetModel.STATE_POPPED:
			continue
		var d: float = sim.grid.cell_to_world(idx).distance_squared_to(c)
		if d < best_d:
			best_d = d
			best = idx
	return best


func _sum_values() -> float:
	var total: float = 0.0
	for v: float in sim.ev_value:
		total += v
	return total


## Los reventones directos de la herramienta vuelan sueltos; los de una cadena (y los de la
## automatización) se juntan y salen como UN "+N" desde el centro de la cadena cuando termina.
func _handle_pops() -> void:
	var n: int = sim.ev_idx.size()
	if n > 0:
		_in_flight += _sum_values()
	var direct: int = mini(sim.ev_tool_pops, n)
	for i: int in direct:
		flyers.spawn(_screen_of(sim.grid.cell_to_world(sim.ev_idx[i])), sim.ev_value[i])
	for i: int in range(direct, n):
		_group_value += sim.ev_value[i]
		_group_pos += _screen_of(sim.grid.cell_to_world(sim.ev_idx[i]))
		_group_count += 1
	if _group_count > 0 and sim.chain_count == 0:
		flyers.spawn(_group_pos / float(_group_count), _group_value)
		_group_value = 0.0
		_group_pos = Vector2.ZERO
		_group_count = 0


## Rectángulos de los paneles del HUD (los "+N" no se dibujan encima).
func _panel_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for c: Control in [pops_panel, work_order, encargo_ticket, big_ticket, shop, combo, _recycle_button, _log_button, _hand_button, _route_button, _reload_button]:
		if c.visible:
			out.append(c.get_global_rect())
	for id: String in _tool_buttons:
		var b: StampButton = _tool_buttons[id]
		if b.visible:
			out.append(b.get_global_rect())
	return out


func _screen_of(world_xz: Vector2) -> Vector2:
	var pos: Vector3 = Vector3(world_xz.x, 0.3, world_xz.y)
	if camera.is_position_behind(pos):
		return Vector2(300.0, 300.0)
	return camera.unproject_position(pos)


func _on_flyer_arrived(value: float) -> void:
	_in_flight = maxf(0.0, _in_flight - value)
	pops_panel.pulse()


func show_offline(result: Dictionary) -> void:
	offline_ticket.show_result(result)


## Primera vez que algo se vuelve pagable: la etiqueta se despega más, el clip tiembla y una flecha
## dibujada con marcador la señala 3 s. Después de la primera compra, nunca más.
func _discover(id: String) -> void:
	_arrow_id = id
	_arrow_t = 3.0
	shop.select_tab(shop.tab_of(id))
	shop.shake_clip(2.0)
	var tag: UpgradeTag = shop.tag_for(id)
	if tag != null:
		tag.discovery = true


func _draw_arrow() -> void:
	if _arrow_t <= 0.0:
		return
	var tag: UpgradeTag = shop.tag_for(_arrow_id)
	if tag == null or not tag.is_visible_in_tree():
		return
	var r: Rect2 = tag.get_global_rect()
	var to: Vector2 = Vector2(r.position.x - 6.0, r.position.y + r.size.y * 0.5)
	var wob: float = sin(Time.get_ticks_msec() * 0.012) * 4.0
	var from: Vector2 = to + Vector2(-190.0 + wob, -80.0)
	var ctrl: Vector2 = to + Vector2(-120.0, 20.0)
	var a: float = clampf(_arrow_t * 2.0, 0.0, 1.0)
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 17:
		var t: float = float(i) / 16.0
		var wiggle: float = sin(t * 9.0) * 2.0 # el trazo de marcador no es perfecto
		pts.append(from.lerp(ctrl, t).lerp(ctrl.lerp(to, t), t) + Vector2(0.0, wiggle))
	var ink: Color = Color(UiKit.STAMP_RED.r, UiKit.STAMP_RED.g, UiKit.STAMP_RED.b, 0.9 * a)
	_arrow_ctl.draw_polyline(pts, ink, 6.0, true)
	_arrow_ctl.draw_polyline(pts, Color(1.0, 0.45, 0.4, 0.35 * a), 2.0, true)
	var head: Vector2 = (pts[16] - pts[14]).normalized()
	var left: Vector2 = pts[16] - head.rotated(0.5) * 30.0
	var right: Vector2 = pts[16] - head.rotated(-0.5) * 30.0
	_arrow_ctl.draw_polyline(PackedVector2Array([left, pts[16], right]), ink, 6.0, true)


func _on_tag_bought(id: String, count: int, milestone: bool) -> void:
	if not Settings.discovery_done:
		Settings.discovery_done = true
		Settings.save_settings()
		_arrow_t = 0.0
		for tid: String in shop.tag_ids():
			var tg: UpgradeTag = shop.tag_for(tid)
			if tg != null:
				tg.discovery = false
	PopAudio.play_ui("stamp", randf_range(0.95, 1.05), 0.0)
	_shake_t = 0.22
	if milestone:
		PopAudio.play_ui("milestone", 1.0, 0.0)
		_banner_t = 2.4
		var every: int = Cfg.integer(sim.eco, "milestone_every")
		var level: int = sim.upgrades.level_of(sim.state, id)
		_banner_text = "%s  x2  -  %s" % [sim.upgrades.name_of(id, Settings.language).to_upper(), "NIV %d" % (level - level % every)]
		_banner_joke = Tx.joke(level / every)
	purchased.emit(id, count, milestone)


func _on_affordable(id: String) -> void:
	if not Settings.discovery_done and _arrow_t <= 0.0:
		_discover(id)
	# El tic de "ya se puede comprar" suena como mucho una vez cada 3 s.
	if _tic_cooldown <= 0.0:
		_tic_cooldown = 3.0
		PopAudio.play_ui("tic", 1.0, -6.0)


# --- Frame ------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if sim == null:
		return
	if get_viewport().get_visible_rect().size != _last_vp:
		_layout()
	flyers.blocked = _panel_rects() # los paneles tiemblan y se mueven: se actualiza cada frame
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	chain_stamp.free_rect = Rect2(Vector2(10.0, 150.0), Vector2(vp_size.x - SHOP_W - 30.0, vp_size.y - 280.0))
	chain_stamp.blocked = flyers.blocked
	chain_stamp.max_width = (vp_size.x - SHOP_W) * ChainStamp.MAX_PLAY_FRACTION
	_tic_cooldown = maxf(0.0, _tic_cooldown - delta)
	if _arrow_t > 0.0:
		_arrow_t -= delta
		_arrow_ctl.queue_redraw()
		if _arrow_t <= 0.0:
			var shown: UpgradeTag = shop.tag_for(_arrow_id)
			if shown != null:
				shown.discovery = false
	_banner_t = maxf(0.0, _banner_t - delta)
	_banner_ctl.queue_redraw()
	_update_shake(delta)
	pops_panel.odometer.set_target(maxf(0.0, sim.state.pops - _in_flight))
	if _rate_timer >= 1.0:
		_rate_shown = _rate_acc / _rate_timer
		_rate_acc = 0.0
		_rate_timer = 0.0
		pops_panel.rate_text = "+%s/s" % NumberFormat.pops(_rate_shown, Settings.language)
	var rates: Array = sim.eco["combo_rates"]
	var top_rate: float = rates[rates.size() - 1]
	combo.update_values(sim.combo_multiplier(), clampf(sim.combo_rate() / top_rate, 0.0, 1.0))
	night_stamp.set_active(sim.night_shift())
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.2
		work_order.refresh()
		_layout()
	_update_toolbar()
	_update_recycle_button()
	if _zen:
		for c: Control in [pops_panel, work_order, encargo_ticket, big_ticket, shop, combo, _recycle_button, _log_button, _route_button, _reload_button]:
			c.visible = false
	_update_intros(delta)
	_reload_button.visible = sim.awaiting_reload and not is_modal_open()
	if _reload_button.visible: # late para que se note: la lámina está terminada
		var k: float = 1.0 + 0.04 * sin(Time.get_ticks_msec() * 0.008)
		_reload_button.scale = Vector2(k, k)
	_tab_timer -= delta
	if _tab_timer <= 0.0:
		_tab_timer = 0.5
		shop.refresh_tabs()


func _update_shake(delta: float) -> void:
	_shake_t = maxf(0.0, _shake_t - delta)
	if _shake_t > 0.0 and not Settings.reduce_motion:
		root.position = Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0)) * (_shake_t / 0.22)
	else:
		root.position = Vector2.ZERO


func _update_toolbar() -> void:
	for id: String in _tool_buttons:
		var b: StampButton = _tool_buttons[id]
		var unlocked: bool = sim.upgrades.tool_unlocked(sim.state, id)
		b.disabled = not unlocked
		b.visible = true # las herramientas bloqueadas se ven desde el principio, con candado y dónde se abren
		b.locked = not unlocked
		b.tooltip_text = Tx.t("tool_tip_" + id)
		if not unlocked:
			b.sub_text = Tx.t("unlocks_in") % _unlock_place(id)
		b.toggled_on = sim.state.selected_tool == id
		var tires: bool = unlocked and sim.wear.has(id) and sim.wear[id].tires()
		b.meter = sim.wear_fraction(id) if tires else -1.0
		b.meter_locked = sim.tool_locked(id)
		if b.meter_locked:
			b.sub_text = Tx.t("overheated") if id == "iron" else Tx.t("tired")
			b.queue_redraw()
		elif tires and sim.wear_fraction(id) > 0.0:
			b.queue_redraw()
		if id != "boot" and not b.meter_locked:
			b.sub_text = ""
		if id == "boot" and unlocked and not b.meter_locked:
			var tm: ToolModel = sim.tools["boot"]
			b.sub_text = Tx.t("boot_ready") if tm.cooldown_left <= 0.0 else "%.1f s" % tm.cooldown_left


## Dónde se abre una herramienta (el escenario de su mejora de desbloqueo).
func _unlock_place(tool_id: String) -> String:
	var n: int = 1
	for up_id: String in sim.upgrades.ids_for_tool(tool_id):
		var d: Dictionary = sim.upgrades.def(up_id)
		if str(d["kind"]) == "unlock":
			var req: Dictionary = d["requires"]
			if req.has("phase"):
				n = Cfg.integer(req, "phase")
	for p: Dictionary in sim.db.phases:
		if Cfg.integer(p, "number") == n:
			return str(p["name_" + Settings.language])
	return "?"


func _unlock_revealed(tool_id: String) -> bool:
	for up_id: String in sim.upgrades.ids_for_tool(tool_id):
		if str(sim.upgrades.def(up_id)["kind"]) == "unlock":
			return sim.upgrades.is_revealed(sim.state, up_id)
	return false


func _update_recycle_button() -> void:
	var can: bool = sim.can_recycle()
	var show_pellets: bool = sim.state.pellets > 0.0 or sim.state.recycles > 0
	_recycle_button.visible = can or show_pellets
	_recycle_button.scale = Vector2.ONE
	if can:
		_recycle_button.text = Tx.t("recycle")
		_recycle_button.sub_text = "+%d %s" % [sim.recycle_gain(), Tx.t("pellets")]
		_recycle_button.color = UiKit.STAMP_RED
		if sim.nothing_left_to_buy(): # no queda nada para comprar en este escenario: RECICLAR late
			var kk: float = 1.0 + 0.06 * sin(Time.get_ticks_msec() * 0.011)
			_recycle_button.scale = Vector2(kk, kk)
		if sim.next_phase_ready(): # alcanza para la fase siguiente: que se note
			_recycle_button.sub_text = Tx.t("recycle_opens") % Tx.t("phase_%d" % (sim.phase() + 1)).to_upper()
			var k: float = 1.0 + 0.05 * sin(Time.get_ticks_msec() * 0.009)
			_recycle_button.scale = Vector2(k, k)
	elif show_pellets:
		_recycle_button.text = Tx.t("pellets")
		_recycle_button.sub_text = NumberFormat.pops(sim.state.pellets, Settings.language)
		_recycle_button.color = UiKit.CARDBOARD_DARK


func _draw_banner() -> void:
	if _banner_t <= 0.0:
		return
	var a: float = clampf(_banner_t * 2.0, 0.0, 1.0)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var center: Vector2 = Vector2((vp.x - SHOP_W) * 0.5, 360.0)
	var punch: float = 1.0 + maxf(0.0, _banner_t - 2.1) * 2.5
	var r: Rect2 = Rect2(center - Vector2(240.0, 44.0) * punch, Vector2(480.0, 88.0) * punch)
	var gold: Color = Color("#E7B73A")
	_banner_ctl.draw_rect(Rect2(r.position + Vector2(4.0, 5.0), r.size), Color(0, 0, 0, 0.3 * a))
	_banner_ctl.draw_rect(r, Color(gold.r, gold.g, gold.b, a))
	_banner_ctl.draw_rect(r.grow(-6.0), UiKit.INK, false, 2.0)
	UiKit.draw_text(_banner_ctl, r.position + Vector2(0.0, 38.0 * punch), _banner_text, UiKit.font_title(), int(20.0 * punch), UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	UiKit.draw_text(_banner_ctl, r.position + Vector2(0.0, 66.0 * punch), _banner_joke, UiKit.font_text_bold(), int(14.0 * punch), UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
