class_name ToolMeshes
extends RefCounted
## Las herramientas 3D armadas con primitivas (sin modelos). Las usan el cursor del mundo
## (ToolView); los íconos de la tienda son imágenes pre-renderizadas (art/icons.py). La punta/contacto queda en y = 0.

const MODELS: String = "res://assets/models/"
const HAND_SCALE: float = 26.0 ## el dedo del guante mide ~1,9 cm: en el mundo, ~0,5 burbuja de ancho (se calibra en B3)
const HAND_ROT: Vector3 = Vector3(-14.0, 55.0, 0.0) ## el brazo entra desde abajo a la derecha y el índice se ve de perfil
const GHOST_SCALE: float = 0.8 ## las manitos miden el 80 % de la mano del jugador
const MESA_SCALE: float = 0.73 ## dedo y palma: en la Mesa la cámara de trabajo está más cerca (burbuja de 22 px)

## Estilo de la mano: "glove" (guante de nitrilo, por defecto) o "skin" (piel con subsurface).

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
	m.metallic = metallic
	ToyStyle.toonify(m) # mismo estilo juguete que el resto (sin brillo metálico)
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


## La mano es de persona: el color de la piel y de la manga viene horneado en los vértices del modelo
## (art/models/hand_mpfb.py, con oclusión en los pliegues). El material solo pone el estilo juguete.
static func hand_material() -> Material:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.6
	ToyStyle.toonify(m)
	return m


const ROLLER_THIN: float = 0.5 ## diámetro y mango del rodillo respecto de su ancho
const ROLLER_AXLE_Y: float = -0.155 ## alto del eje del cilindro en roller.glb (metros, del centro del modelo)
const OUTLINE_DARK: Color = Color(0.12, 0.10, 0.09) ## contorno de juguete de la mano y las herramientas
const OUTLINE_GHOST: Color = Color(0.56, 0.82, 0.95) ## contorno celeste de las manitos

static var _outline_cache: Dictionary = {} ## color html -> ShaderMaterial (se comparte)


## Contorno de juguete: un material_overlay en cada malla del modelo (ver toon_outline.gdshader).
static func add_outline(node: Node, color: Color) -> void:
	var key: String = color.to_html()
	if not _outline_cache.has(key):
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = load("res://shaders/toon_outline.gdshader") as Shader
		m.set_shader_parameter("line_color", color)
		_outline_cache[key] = m
	var mat: ShaderMaterial = _outline_cache[key]
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_overlay = mat
	for c: Node in node.get_children():
		add_outline(c, color)


## Manitos fantasma: una pasada que escribe solo profundidad y, encima, la pasada visible.
static func ghost_material() -> ShaderMaterial:
	var visible_pass: ShaderMaterial = ShaderMaterial.new()
	visible_pass.shader = load("res://shaders/ghost_hand.gdshader") as Shader
	visible_pass.render_priority = 2
	var outline: ShaderMaterial = ShaderMaterial.new()
	outline.shader = load("res://shaders/toon_outline_ghost.gdshader") as Shader
	outline.set_shader_parameter("line_color", OUTLINE_GHOST)
	outline.render_priority = 1
	outline.next_pass = visible_pass
	var depth_pass: ShaderMaterial = ShaderMaterial.new()
	depth_pass.shader = load("res://shaders/ghost_depth.gdshader") as Shader
	depth_pass.render_priority = 0
	depth_pass.next_pass = outline
	return depth_pass


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
			ToyStyle.toonify(m)
			mi.set_surface_override_material(i, m)
	for c: Node in node.get_children():
		_tint(c, color, amount, metallic)


static func _hand(pose: String, ghost: bool) -> HandRig:
	var rig: HandRig = HandRig.new()
	rig.setup(pose, ghost_material() if ghost else hand_material())
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
			_add_hand(body, "palm", tier, false, half * 1.8 / 0.085 * 0.64 * MESA_SCALE, Vector3.ZERO, Vector3(0.0, 24.0, 0.0)) # 8-15 % del alto con la cámara de trabajo
		"hands":
			_add_hand(body, "point", tier, true, HAND_SCALE * GHOST_SCALE, Vector3.ZERO, HAND_ROT)
		"rolling_pin":
			var s: float = half * 2.0 / 0.619 * 1.25 # 8-15 % del alto con la cámara de trabajo
			_add_model(body, "pin", s, color, amount, metal)
			_add_hand(body, "grab", tier, false, s * 1.25, Vector3(0.222, 0.056, 0.0) * s, Vector3(0.0, 0.0, 0.0))
		"iron":
			var s2: float = half * 2.0 / 0.30 * 0.75 # 8-15 % del alto con la cámara de trabajo; el aura marca la zona real
			_add_model(body, "iron", s2, color, amount, metal)
			_add_hand(body, "grab", tier, false, s2 * 1.1, Vector3(0.0, 0.158, -0.005) * s2, Vector3(0.0, 0.0, 0.0))
		"boot":
			# De perfil para la cámara del juego (desde arriba, parada, era una mancha marrón): la punta
			# apunta a la derecha y el costado se inclina hacia la cámara.
			var tilt: Node3D = Node3D.new()
			tilt.rotation_degrees = Vector3(-35.0, 0.0, 0.0)
			body.add_child(tilt)
			_add_model(tilt, "boot", half * 1.95 / 0.33 * 1.1, color, amount, metal) # la suela cubre el pisotón; 8-15 % del alto
			(tilt.get_child(0) as Node3D).rotation_degrees = Vector3(0.0, -80.0, 0.0)
		"auto_roller":
			# El rodillo gira sobre el centro de su cilindro (Tilt): AutomationView inclina el mango
			# hacia atrás del avance, como se usa uno de verdad (parado tapaba media lámina).
			var rs: float = half * 2.0 / 0.26
			var tilt_r: Node3D = Node3D.new()
			tilt_r.name = "Tilt"
			# El ancho del cilindro es la franja que limpia; el diámetro y el mango van a la mitad (a
			# escala uniforme el rodillo era más grueso que media lámina).
			var thin: float = rs * ROLLER_THIN
			tilt_r.position = Vector3(0.0, -ROLLER_AXLE_Y * thin, 0.0)
			body.add_child(tilt_r)
			_add_model(tilt_r, "roller", rs, color, amount, metal)
			var roller_m: Node3D = tilt_r.get_child(0) as Node3D
			roller_m.scale = Vector3(rs, thin, thin)
			roller_m.position = Vector3(0.0, ROLLER_AXLE_Y * thin, 0.0)
		_:
			_add_hand(body, "point", tier, false, HAND_SCALE * MESA_SCALE * (1.0 + 0.08 * radius), Vector3.ZERO, HAND_ROT)
	if icon:
		_fit_icon(root)
	if tool_id != "hands": # las manitos llevan su contorno dentro de ghost_material()
		ToyStyle.apply(root) # estilo juguete y contorno oscuro, como el resto del mundo
	return root


static func _add_model(body: Node3D, file: String, scale_factor: float, color: Color, amount: float, metal: float) -> void:
	var m: Node3D = _instance(file)
	m.scale = Vector3.ONE * scale_factor
	if amount > 0.0 or metal > 0.0:
		_tint(m, color, amount, metal)
	body.add_child(m)


static func _add_hand(body: Node3D, pose: String, _tier: int, ghost: bool, scale_factor: float, pos: Vector3, rot_deg: Vector3) -> void:
	var pivot: Node3D = Node3D.new()
	pivot.name = "HandPivot"
	pivot.position = pos
	pivot.rotation_degrees = rot_deg
	pivot.scale = Vector3.ONE * scale_factor
	body.add_child(pivot)
	var rig: HandRig = _hand(pose, ghost) # la piel no cambia con el nivel
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
