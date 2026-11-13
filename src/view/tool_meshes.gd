class_name ToolMeshes
extends RefCounted
## Las herramientas 3D armadas con primitivas (sin modelos). Las usan el cursor del mundo
## (ToolView) y los íconos en vivo de la tienda (ToolIcon). La punta/contacto queda en y = 0.

const MODELS: String = "res://assets/models/"
const HAND_SCALE: float = 28.0 ## el dedo mide ~1,5 burbujas de ancho (el guante real mide 1,76 cm)

## Estilo de la mano: "glove" (guante de nitrilo, por defecto) o "skin" (piel con subsurface).
static var hand_style: String = "glove"
static var skin_color: Color = Color("#E8B896")

const TIER_COLORS: Dictionary = {
	"finger": [Color("#3D6FD6"), Color("#2F9E6B"), Color("#D5D8DB"), Color("#F2C94C")],
	"palm": [Color("#3D6FD6"), Color("#2F9E6B"), Color("#D5D8DB"), Color("#F2C94C")],
	"rolling_pin": [Color("#B98552"), Color("#9C6B3A"), Color("#C9CDD1"), Color("#F2C94C")],
	"iron": [Color("#C9CDD1"), Color("#9AA3AA"), Color("#E5A13A"), Color("#F2C94C")],
	"boot": [Color("#5A4330"), Color("#3E2F22"), Color("#8E6B47"), Color("#F2C94C")],
	"hands": [Color("#F4EFE6"), Color("#F4EFE6"), Color("#F4EFE6"), Color("#F2C94C")],
	"auto_roller": [Color("#B98552"), Color("#9C6B3A"), Color("#C9CDD1"), Color("#F2C94C")],
}


## Color del material según el hito alcanzado (cada 25 niveles cambia de color/material).
static func tier_color(tool_id: String, tier: int) -> Color:
	var list: Array = TIER_COLORS.get(tool_id, TIER_COLORS["finger"])
	var c: Color = list[clampi(tier, 0, list.size() - 1)]
	return c


static func material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.3 if metallic < 0.1 else 0.22
	m.metallic = metallic
	m.rim_enabled = true
	m.rim = 0.3
	m.rim_tint = 0.5
	return m


static func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi


## Aplica el estilo de la mano desde data/juice.json.
static func configure(juice: Dictionary) -> void:
	hand_style = str(juice.get("hand_style", "glove"))
	skin_color = Color(str(juice.get("hand_skin_color", "#E8B896")))


static func glove_material(tint: Color) -> Material:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.frequency = 0.9
	var nt: NoiseTexture2D = NoiseTexture2D.new()
	nt.noise = noise
	nt.as_normal_map = true
	nt.bump_strength = 1.2
	nt.seamless = true
	nt.width = 256
	nt.height = 256
	m.normal_enabled = true
	m.normal_texture = nt
	m.normal_scale = 0.35
	m.uv1_scale = Vector3(6.0, 6.0, 1.0)
	m.roughness = 0.45
	m.clearcoat_enabled = true
	m.clearcoat = 0.5
	m.clearcoat_roughness = 0.35
	if hand_style == "skin":
		m.albedo_color = skin_color
		m.roughness = 0.62
		m.clearcoat_enabled = false
		m.subsurf_scatter_enabled = true
		m.subsurf_scatter_strength = 0.6
	else:
		m.albedo_color = tint
	return m


static func ghost_material() -> ShaderMaterial:
	var sm: ShaderMaterial = ShaderMaterial.new()
	sm.shader = load("res://shaders/ghost_hand.gdshader") as Shader
	return sm


static func _instance(file: String) -> Node3D:
	var ps: PackedScene = load(MODELS + file + ".glb") as PackedScene
	return ps.instantiate() as Node3D


## Tiñe los materiales importados con el color del hito (los hitos 1+ cambian el material).
static func _tint(node: Node, color: Color, amount: float, metallic: float) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		for i: int in mi.mesh.get_surface_count():
			var src: StandardMaterial3D = mi.mesh.surface_get_material(i) as StandardMaterial3D
			if src == null:
				continue
			var m: StandardMaterial3D = src.duplicate() as StandardMaterial3D
			m.albedo_color = src.albedo_color.lerp(color, amount)
			m.metallic = maxf(m.metallic, metallic)
			mi.set_surface_override_material(i, m)
	for c: Node in node.get_children():
		_tint(c, color, amount, metallic)


static func _hand(pose: String, tint: Color, ghost: bool) -> HandRig:
	var rig: HandRig = HandRig.new()
	rig.setup(pose, ghost_material() if ghost else glove_material(tint))
	return rig


## Devuelve un Node3D con la herramienta. `radius` es el tamaño del golpe en el mundo.
## `icon`: encuadrada y centrada para los íconos de la tienda.
static func build(tool_id: String, radius: float, tier: int = 0, icon: bool = false) -> Node3D:
	var root: Node3D = Node3D.new()
	var body: Node3D = Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var color: Color = tier_color(tool_id, tier)
	var half: float = maxf(radius, 1.0)
	var amount: float = 0.0 if tier == 0 else 0.45
	var metal: float = 0.85 if tier >= 2 else 0.0
	match tool_id:
		"palm":
			_add_hand(body, "palm", tier, false, half * 1.8 / 0.085, Vector3.ZERO, Vector3(0.0, 24.0, 0.0))
		"hands":
			_add_hand(body, "point", tier, true, HAND_SCALE * 0.2, Vector3.ZERO, Vector3(-12.0, 28.0, 0.0))
		"rolling_pin":
			var s: float = half * 2.0 / 0.619
			_add_model(body, "pin", s, color, amount, metal)
			_add_hand(body, "grab", tier, false, s * 1.25, Vector3(0.222, 0.056, 0.0) * s, Vector3(0.0, 0.0, 0.0))
		"iron":
			var s2: float = half * 2.0 / 0.30
			_add_model(body, "iron", s2, color, amount, metal)
			_add_hand(body, "grab", tier, false, s2 * 1.1, Vector3(0.0, 0.158, -0.005) * s2, Vector3(0.0, 0.0, 0.0))
		"boot":
			_add_model(body, "boot", half * 1.8 / 0.33, color, amount, metal)
		"auto_roller":
			_add_model(body, "roller", half * 2.0 / 0.26, color, amount, metal)
		_:
			_add_hand(body, "point", tier, false, HAND_SCALE * (1.0 + 0.08 * radius), Vector3.ZERO, Vector3(-12.0, 28.0, 0.0))
	if icon:
		_fit_icon(root)
	return root


static func _add_model(body: Node3D, file: String, scale_factor: float, color: Color, amount: float, metal: float) -> void:
	var m: Node3D = _instance(file)
	m.scale = Vector3.ONE * scale_factor
	if amount > 0.0 or metal > 0.0:
		_tint(m, color, amount, metal)
	body.add_child(m)


static func _add_hand(body: Node3D, pose: String, tier: int, ghost: bool, scale_factor: float, pos: Vector3, rot_deg: Vector3) -> void:
	var pivot: Node3D = Node3D.new()
	pivot.name = "HandPivot"
	pivot.position = pos
	pivot.rotation_degrees = rot_deg
	pivot.scale = Vector3.ONE * scale_factor
	body.add_child(pivot)
	var rig: HandRig = _hand(pose, tier_color("finger", tier), ghost)
	pivot.add_child(rig)


## Escala y centra el modelo para que entre en ~2,4 unidades (cámara de los íconos).
static func _fit_icon(root: Node3D) -> void:
	var box: AABB = _bounds(root, Transform3D.IDENTITY)
	var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
	if longest <= 0.0001:
		return
	var f: float = 2.4 / longest
	var body: Node3D = root.get_node("Body") as Node3D
	body.scale = Vector3.ONE * f
	body.position = -box.get_center() * f


static func _bounds(node: Node, xf: Transform3D) -> AABB:
	var result: AABB = AABB()
	var first: bool = true
	if node is MeshInstance3D:
		result = xf * (node as MeshInstance3D).get_aabb()
		first = false
	for c: Node in node.get_children():
		var ct: Transform3D = xf
		if c is Node3D:
			ct = xf * (c as Node3D).transform
		var sub: AABB = _bounds(c, ct)
		if sub.size == Vector3.ZERO:
			continue
		result = sub if first else result.merge(sub)
		first = false
	return result
