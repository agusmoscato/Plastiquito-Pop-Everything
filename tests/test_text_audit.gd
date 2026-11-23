extends GutTest
## Recorre las pantallas y tarjetas del juego (HUD con hoja de pedidos y barra de herramientas, MI MANO, RUTA, pedido
## grande, memos, ficha de nombre, telegrama y créditos, reciclado y Burbujario) en español y en inglés, y falla si
## algún texto se sale de su contenedor o se superpone con otro (UiKit.audit_take).

var db: DataDB
var sim: GameSim


func before_each() -> void:
	db = DataDB.new()
	assert_true(db.load_all(), str(db.errors))
	sim = GameSim.new(db, 3)
	UiKit.audit_on = true
	UiKit.audit_take()


func after_each() -> void:
	UiKit.audit_on = false
	Settings.language = "es"


func _frames(n: int = 3) -> void:
	for i: int in n:
		await get_tree().process_frame


## Dibuja `node` unos frames y devuelve los problemas de texto (con el nombre de la pantalla).
func _check(node: Node, label: String) -> void:
	add_child(node)
	await _frames(2)
	UiKit.audit_take() # solo cuenta el último frame dibujado (la tarjeta ya terminó de escribirse)
	if node is MemoCard:
		(node as MemoCard)._typed = 9999.0
	await _frames(1)
	var problems: PackedStringArray = UiKit.audit_take()
	assert_eq(problems.size(), 0, "%s (%s): %s" % [label, Settings.language, "; ".join(problems)])
	remove_child(node)
	node.free()


func _each_language(maker: Callable, label: String) -> void:
	for lang: String in ["es", "en"]:
		Settings.language = lang
		UiKit.audit_take()
		var node: Node = maker.call()
		await _check(node, label)


func test_memos_are_tidy() -> void:
	for id: String in db.story["memos"]:
		await _each_language(func() -> Node:
			var c: MemoCard = MemoCard.new()
			c.setup(sim)
			sim.memo_queue = [id]
			c._shown_id = ""
			return c, "memo " + id)


func test_big_order_ticket_is_tidy() -> void:
	sim.state.phase_sheets = 4
	sim.step(0.1, Vector2.ZERO, false)
	await _each_language(func() -> Node:
		var t: BigOrderTicket = BigOrderTicket.new()
		t.setup(sim)
		return t, "pedido grande")
	for ph: int in [2, 3, 4]:
		sim.state.perm["perm_sheet"] = ph - 1
		sim.state.big = {}
		sim.state.phase_sheets = 4
		sim.step(0.1, Vector2.ZERO, false)
		await _each_language(func() -> Node:
			var t2: BigOrderTicket = BigOrderTicket.new()
			t2.setup(sim)
			return t2, "pedido grande %d" % ph)


func test_hand_and_route_panels_are_tidy() -> void:
	sim.state.pellets = 500.0
	await _each_language(func() -> Node:
		var h: HandPanel = HandPanel.new()
		h.setup(sim)
		h.open_panel()
		return h, "MI MANO")
	sim.state.acc_owned = {"ring_alpaca": true, "glove_cocina": true}
	await _each_language(func() -> Node:
		var h2: HandPanel = HandPanel.new()
		h2.setup(sim)
		h2.open_panel()
		return h2, "MI MANO con accesorios")
	await _each_language(func() -> Node:
		var r: RoutePanel = RoutePanel.new()
		r.setup(sim)
		r.open_panel()
		return r, "RUTA")


func test_story_screens_are_tidy() -> void:
	await _each_language(func() -> Node:
		var n: NamePrompt = NamePrompt.new()
		n.setup()
		n.open_prompt()
		return n, "ficha de nombre")
	for step: int in [0, 1, 2, 3]:
		await _each_language(func() -> Node:
			var e: EndingPanel = EndingPanel.new()
			e.setup(sim)
			e.start()
			e.t = 9.0
			e.step = step
			e._credit_y = 200.0
			return e, "final paso %d" % step)


func test_hud_is_tidy_in_every_scenario() -> void:
	for ph: int in [1, 2, 3, 4]:
		var s: GameSim = GameSim.new(db, ph)
		s.state.perm["perm_sheet"] = ph - 1
		s.state.pops = 5.0e7
		s.state.pellets = 30.0
		s.state.pops_run = 5.0e9
		s.state.recycles = 1
		s.refresh_stats()
		for lang: String in ["es", "en"]:
			Settings.language = lang
			UiKit.audit_take()
			var cam: Camera3D = Camera3D.new()
			add_child_autofree(cam)
			var hud: Hud = Hud.new()
			add_child_autofree(hud)
			hud.setup(s, cam)
			hud.recycle_panel.open_panel()
			await _frames(4)
			hud.recycle_panel.close_panel()
			hud.bubble_log.visible = true
			for tab: String in ["finger", "palm", "rolling_pin", "iron", "boot", "hands", "auto_roller", "global"]:
				hud.shop.select_tab(tab)
				await _frames(2)
				var tab_problems: PackedStringArray = UiKit.audit_take()
				assert_eq(tab_problems.size(), 0, "hoja de pedidos %s esc. %d (%s): %s" % [tab, ph, lang, "; ".join(tab_problems)])
			await _frames(3)
			UiKit.audit_take()
			await _frames(1)
			var problems: PackedStringArray = UiKit.audit_take()
			assert_eq(problems.size(), 0, "HUD escenario %d (%s): %s" % [ph, lang, "; ".join(problems)])
			remove_child(hud)
			hud.free()


## Sello CADENA, ficha DOBLE FILM, cartel TURNO NOCHE y números flotantes (dibujados con draw_string directo):
## nacen todos juntos sobre la lámina y ninguno se pisa con otro.
func test_floating_texts_do_not_overlap() -> void:
	var s: GameSim = GameSim.new(db, 3)
	s.state.perm["perm_sheet"] = 2
	s.refresh_stats()
	for lang: String in ["es", "en"]:
		Settings.language = lang
		var cam: Camera3D = Camera3D.new()
		add_child_autofree(cam)
		var hud: Hud = Hud.new()
		add_child_autofree(hud)
		hud.setup(s, cam)
		await _frames(2)
		var vp: Vector2 = get_viewport().get_visible_rect().size
		var spot: Vector2 = Vector2((vp.x - Hud.SHOP_W) * 0.45, vp.y * 0.55)
		hud.special_card.start_intro(SpecialCard.ARMOR)
		hud.night_stamp.set_active(true)
		hud.chain_stamp.anchor = spot
		hud.chain_stamp.chain_ended(48, 1.25e6)
		await _frames(2)
		var stamp: Rect2 = hud.chain_stamp.screen_rect()
		var card: Rect2 = hud.special_card.screen_rect()
		assert_false(stamp.intersects(card), "el sello CADENA no tapa la ficha DOBLE FILM (%s)" % lang)
		for i: int in 8: # justo encima del sello, de la ficha y del origen de la cadena
			hud.flyers.spawn(stamp.get_center() + Vector2(float(i) * 9.0, 0.0), 1000.0 * float(i + 1))
			hud.flyers.spawn(card.get_center() + Vector2(0.0, float(i) * 3.0), 31.0 * float(i + 1))
			hud.flyers.spawn(spot + Vector2(float(i) * 120.0 - 400.0, 0.0), 7.0e5)
		for f: int in 12:
			UiKit.audit_take()
			await _frames(1)
			assert_gt(UiKit.audit_count_layer(ChainStamp.AUDIT_LAYER), 1, "se dibujan sello y ficha (%s)" % lang)
			var problems: PackedStringArray = UiKit.audit_take()
			assert_eq(problems.size(), 0, "textos flotantes frame %d (%s): %s" % [f, lang, "; ".join(problems)])
		remove_child(hud)
		hud.free()


func test_audit_really_runs_the_draw_code() -> void:
	var c: MemoCard = MemoCard.new()
	c.setup(sim)
	sim.memo_queue = ["welcome"]
	add_child_autofree(c)
	await _frames()
	assert_gt(UiKit.audit_count(), 0, "los dibujos corren (si no, este test no prueba nada)")
