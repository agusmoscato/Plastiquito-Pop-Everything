class_name ToolIcon
extends SubViewportContainer
## Ícono EN VIVO: la herramienta 3D real en un SubViewport chico, girando lento.
## No usa sets de íconos: es el mismo modelo que se ve en el mundo (ToolMeshes).

var kind: String = "finger"
var tier: int = 0
var variant: String = "" ## "size", "force", "speed" o "special": distingue las mejoras de una misma herramienta

var _spin: Node3D
var _vp: SubViewport
var _px: int = 64
var _cam: Camera3D
var _sway_t: float = 0.0

## Encuadre cerrado por herramienta (jornada B2): (zoom, dirección de la cámara, foco). foco "contact" =
## el punto donde la herramienta toca la lámina; "center" = el centro del modelo. Las variantes de mejora
## (regla, grilla, estela...) siguen con el encuadre general y el giro.
const FRAMING: Dictionary = {
	"finger": [2.7, Vector3(0.55, 0.75, 1.0), "contact"],  # la yema apretando una burbuja
	"hands": [2.4, Vector3(0.55, 0.75, 1.0), "contact"],
	"palm": [1.15, Vector3(0.0, 1.0, 0.18), "center"],      # la palma vista desde arriba
	"rolling_pin": [1.25, Vector3(0.35, 0.8, 1.0), "center"],  # la mano agarrando el palo
	"iron": [1.25, Vector3(0.7, 0.7, 1.0), "center"],
	"boot": [1.2, Vector3(1.0, 0.35, 0.25), "center"],      # de perfil
	"auto_roller": [1.2, Vector3(0.5, 0.7, 1.0), "center"],
}


func setup(p_kind: String, px: int, p_tier: int = 0) -> void:
	kind = p_kind
	tier = p_tier
	custom_minimum_size = Vector2(px, px)
	size = Vector2(px, px)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_px = px
	# El SubViewport se crea recién cuando el ícono se ve (hay decenas de íconos en la tienda).


func _build() -> void:
	var px: int = _px
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.size = Vector2i(px, px)
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_vp.msaa_3d = Viewport.MSAA_2X
	add_child(_vp)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.93, 1.0)
	env.ambient_light_energy = 0.7
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	light.light_energy = 1.2
	_vp.add_child(light)
	_cam = Camera3D.new()
	_cam.fov = 34.0
	_cam.position = Vector3(0.0, 2.4, 3.6)
	_cam.rotation_degrees = Vector3(-26.0, 0.0, 0.0)
	_vp.add_child(_cam)
	_spin = Node3D.new()
	_vp.add_child(_spin)
	_spin.add_child(_make_model())
	_spin.position = Vector3(0.0, 0.1, 0.0)
	_frame()


func _closeup() -> bool:
	return variant == "" and FRAMING.has(kind)


## Encuadre cerrado: la cámara mira el foco desde la dirección de la herramienta, más cerca.
func _frame() -> void:
	if _cam == null or not _closeup():
		return
	var f: Array = FRAMING[kind]
	var zoom: float = f[0]
	var dir: Vector3 = f[1]
	var focus: Vector3 = Vector3(0.0, 0.1, 0.0)
	if str(f[2]) == "contact" and _spin.get_child_count() > 0:
		var body: Node3D = (_spin.get_child(0) as Node3D).get_node_or_null("Body") as Node3D
		if body != null:
			focus = _spin.position + body.position # el contacto quedó acá al centrar el modelo
	_cam.position = focus + dir.normalized() * (4.3 / zoom)
	_cam.look_at(focus, Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.FORWARD)


func set_variant(p_variant: String) -> void:
	variant = p_variant
	if _spin == null:
		return
	for c: Node in _spin.get_children():
		_spin.remove_child(c)
		c.queue_free()
	_spin.add_child(_make_model())
	_frame()


func set_tier(p_tier: int) -> void:
	if p_tier == tier or _spin == null:
		return
	tier = p_tier
	for c: Node in _spin.get_children():
		c.queue_free()
	_spin.add_child(_make_model())


func _make_model() -> Node3D:
	if kind == "bubble":
		var root: Node3D = Node3D.new()
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = BubbleMesh.build(1.0, 0.9, 10, 24)
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = Color(0.55, 0.82, 1.0, 0.65)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.1
		m.rim_enabled = true
		m.rim = 0.8
		mi.material_override = m
		root.add_child(mi)
		return root
	var use_tier: int = tier
	var model: Node3D = ToolMeshes.build(kind, 1.2, use_tier, true)
	if _closeup() and (kind == "finger" or kind == "hands"):
		_add_pressed_bubble(model)
	match variant:
		"size":
			_add_ruler(model)
		"force":
			_add_bubble_grid(model)
		"speed":
			_add_trail(model)
		"special":
			_add_orb(model)
		"count":
			_add_copies(model)
	return model


## Primer plano del dedo: una burbuja aplastada justo debajo de la yema.
func _add_pressed_bubble(model: Node3D) -> void:
	var body: Node3D = model.get_node_or_null("Body") as Node3D
	if body == null:
		return
	var d: MeshInstance3D = MeshInstance3D.new()
	d.mesh = BubbleMesh.build(0.42, 0.8, 8, 16)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.82, 1.0, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.rim_enabled = true
	mat.rim = 0.8
	d.material_override = mat
	d.position = body.position + Vector3(0.0, -0.1, 0.0)
	d.scale = Vector3(1.25, 0.45, 1.25) # aplastada por la yema
	model.add_child(d)


## Tamaño: la herramienta al lado de una regla con marcas.
func _add_ruler(model: Node3D) -> void:
	model.scale = Vector3(0.7, 0.7, 0.7)
	var ruler: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.3, 0.06, 2.6)
	ruler.mesh = box
	ruler.material_override = ToolMeshes.material(UiKit.PAPER)
	ruler.position = Vector3(1.5, 0.03, 0.0)
	model.add_child(ruler)
	for i: int in 7:
		var tick: MeshInstance3D = MeshInstance3D.new()
		var tb: BoxMesh = BoxMesh.new()
		tb.size = Vector3(0.18 if i % 2 == 0 else 0.1, 0.08, 0.04)
		tick.mesh = tb
		tick.material_override = ToolMeshes.material(UiKit.INK)
		tick.position = Vector3(1.42, 0.07, -1.1 + float(i) * 0.36)
		model.add_child(tick)


## Fuerza: la herramienta reventando una burbuja de una grilla de 3x3.
func _add_bubble_grid(model: Node3D) -> void:
	model.scale = Vector3(0.55, 0.55, 0.55)
	model.position = Vector3(0.0, 1.0, 0.0)
	var bm: ArrayMesh = BubbleMesh.build(0.42, 0.8, 6, 12)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.82, 1.0, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.rim_enabled = true
	mat.rim = 0.8
	for gx: int in 3:
		for gz: int in 3:
			var d: MeshInstance3D = MeshInstance3D.new()
			d.mesh = bm
			d.material_override = mat
			d.position = Vector3((float(gx) - 1.0) * 0.95 * 1.8, -1.0 / 0.55 * 0.5, (float(gz) - 1.0) * 0.95 * 1.8)
			if gx == 1 and gz == 1:
				d.scale = Vector3(1.2, 0.2, 1.2) # la del centro, aplastada
			model.add_child(d)


## Velocidad: una estela de copias translúcidas detrás de la herramienta.
func _add_trail(model: Node3D) -> void:
	model.scale = Vector3(0.8, 0.8, 0.8)
	for i: int in 3:
		var ghost: Node3D = ToolMeshes.build(kind, 1.2, tier, true)
		for c: Node in ghost.get_children():
			_fade_node(c, 0.35 - 0.1 * float(i))
		ghost.position = Vector3(-0.9 * float(i + 1), 0.0, 0.0)
		model.add_child(ghost)


func _fade_node(n: Node, alpha: float) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		var src: StandardMaterial3D = mi.material_override as StandardMaterial3D
		if src != null:
			var m: StandardMaterial3D = src.duplicate() as StandardMaterial3D
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color.a = alpha
			mi.material_override = m
	for ch: Node in n.get_children():
		_fade_node(ch, alpha)


func _add_orb(model: Node3D) -> void:
	var orb: MeshInstance3D = MeshInstance3D.new()
	orb.mesh = BubbleMesh.build(0.45, 0.9, 8, 16)
	var om: StandardMaterial3D = StandardMaterial3D.new()
	om.albedo_color = Color(0.55, 0.82, 1.0, 0.7)
	om.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	om.rim_enabled = true
	om.rim = 0.8
	orb.material_override = om
	orb.position = Vector3(1.0, 0.0, 0.6)
	model.add_child(orb)


## Cantidad: varias copias de la herramienta.
func _add_copies(model: Node3D) -> void:
	model.scale = Vector3(0.75, 0.75, 0.75)
	for i: int in 2:
		var copy: Node3D = ToolMeshes.build(kind, 1.2, tier, true)
		copy.position = Vector3(1.0 - 2.0 * float(i), 0.0, -0.9)
		model.add_child(copy)


func _process(delta: float) -> void:
	if _vp == null and is_visible_in_tree():
		_build()
	if _spin != null:
		if _closeup(): # primer plano quieto, con un vaivén leve (girando no se lee a 48 px)
			_sway_t += delta
			_spin.rotation.y = sin(_sway_t * 0.9) * 0.18
		else:
			_spin.rotation.y += delta * (2.6 if variant == "speed" else 0.8)
