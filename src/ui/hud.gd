class_name Hud
extends CanvasLayer
## El HUD como escritorio de un depósito de embalaje (docs/UI_STYLE.md). Junta todas las piezas,
## traduce los eventos de GameSim a feedback (números voladores, sellos, sonidos) y no guarda
## estado de juego: lo lee de GameSim.

signal tool_selected(id: String)
signal purchased(id: String, count: int, milestone: bool)
signal recycle_confirmed
signal chain_slammed(count: int)

const SHOP_W: float = 452.0

var sim: GameSim
var camera: Camera3D

var root: Control
var pops_panel: PopsPanel
var work_order: WorkOrder
var next_bar: NextBar
var combo: ComboMeter
var chain_stamp: ChainStamp
var flyers: FlyingNumbers
var shop: ShopSheet
var recycle_panel: RecyclePanel
var bubble_log: BubbleLog

var _tool_buttons: Dictionary = {} ## id -> StampButton
var _recycle_button: StampButton
var _log_button: StampButton
var _in_flight: float = 0.0
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
	next_bar = NextBar.new()
	next_bar.setup(sim)
	root.add_child(next_bar)
	combo = ComboMeter.new()
	combo.setup()
	root.add_child(combo)
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
	_layout()
	pops_panel.odometer.set_target(sim.state.pops)
	pops_panel.odometer.snap()
	work_order.refresh()
	next_bar.refresh()


func is_modal_open() -> bool:
	return recycle_panel.visible or offline_ticket.visible


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
	_log_button = StampButton.new()
	_log_button.setup(Tx.t("bubblepedia"), Vector2(150.0, 40.0), UiKit.CARDBOARD_DARK)
	_log_button.font_size = 12
	_log_button.pressed.connect(func() -> void: bubble_log.visible = not bubble_log.visible)
	root.add_child(_log_button)


func _layout() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_last_vp = vp
	var free_w: float = vp.x - SHOP_W - 16.0
	pops_panel.position = Vector2(14.0, 10.0)
	work_order.position = Vector2(20.0, 148.0)
	next_bar.position = Vector2(free_w * 0.5 - next_bar.size.x * 0.5 + 60.0, 10.0)
	shop.position = Vector2(vp.x - SHOP_W - 6.0, 8.0)
	combo.position = Vector2(14.0, vp.y - 110.0)
	var x: float = 230.0
	for id: String in _tool_buttons:
		var b: StampButton = _tool_buttons[id]
		b.position = Vector2(x, vp.y - 104.0)
		x += 118.0
	_recycle_button.position = Vector2(free_w - 210.0, vp.y - 84.0)
	_log_button.position = Vector2(free_w - 170.0, 76.0)
	bubble_log.position = Vector2(free_w - 380.0, 124.0)
	flyers.target = pops_panel.odometer_center()


# --- Eventos de la sim -------------------------------------------------------------------------

## Llamar una vez por frame, después de GameSim.step().
func on_sim_step(delta: float) -> void:
	_handle_pops()
	var min_chain: int = Cfg.integer(sim.eco, "chain_stamp_min")
	if sim.chain_count >= min_chain:
		chain_stamp.chain_progress(sim.chain_count)
	if sim.ev_chain_ended_count >= min_chain:
		chain_stamp.chain_ended(sim.ev_chain_ended_count, sim.ev_chain_ended_value)
		PopAudio.play_ui("chain_hit", 1.0, 0.0)
	_rate_acc += _sum_values()
	_rate_timer += delta


func _sum_values() -> float:
	var total: float = 0.0
	for v: float in sim.ev_value:
		total += v
	return total


func _handle_pops() -> void:
	var n: int = sim.ev_idx.size()
	if n == 0:
		return
	_in_flight += _sum_values()
	if n <= 10:
		for i: int in n:
			var p: Vector2 = sim.grid.cell_to_world(sim.ev_idx[i])
			flyers.spawn(_screen_of(p), sim.ev_value[i])
		return
	# Muchos a la vez: se agrupan por zona de pantalla.
	var buckets: Dictionary = {}
	for i: int in n:
		var sp: Vector2 = _screen_of(sim.grid.cell_to_world(sim.ev_idx[i]))
		var key: int = int(sp.x / 170.0) * 1000 + int(sp.y / 170.0)
		var b: Dictionary = buckets.get(key, {"pos": Vector2.ZERO, "count": 0, "value": 0.0})
		var bpos: Vector2 = b["pos"]
		var bcount: int = b["count"]
		var bvalue: float = b["value"]
		b["pos"] = bpos + sp
		b["count"] = bcount + 1
		b["value"] = bvalue + sim.ev_value[i]
		buckets[key] = b
	for key: Variant in buckets:
		var b: Dictionary = buckets[key]
		var bpos: Vector2 = b["pos"]
		var bcount: int = b["count"]
		var bvalue: float = b["value"]
		flyers.spawn(bpos / float(bcount), bvalue)


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
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.2
		work_order.refresh()
		next_bar.refresh()
	_update_toolbar()
	_update_recycle_button()
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
		b.visible = unlocked or sim.phase() >= (3 if id == "iron" else (4 if id == "boot" else 1)) or id == "finger" or id == "palm" or id == "rolling_pin"
		b.toggled_on = sim.state.selected_tool == id
		if id == "boot" and unlocked:
			var tm: ToolModel = sim.tools["boot"]
			b.sub_text = Tx.t("boot_ready") if tm.cooldown_left <= 0.0 else "%.1f s" % tm.cooldown_left


func _update_recycle_button() -> void:
	var can: bool = sim.can_recycle()
	var show_pellets: bool = sim.state.pellets > 0.0 or sim.state.recycles > 0
	_recycle_button.visible = can or show_pellets
	if can:
		_recycle_button.text = Tx.t("recycle")
		_recycle_button.sub_text = "+%d %s" % [sim.recycle_gain(), Tx.t("pellets")]
		_recycle_button.color = UiKit.STAMP_RED
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
