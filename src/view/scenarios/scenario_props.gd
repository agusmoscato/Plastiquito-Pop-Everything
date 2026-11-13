class_name ScenarioProps
extends RefCounted
## Objetos de cada escenario: modelos .glb (art/models) a ESCALA REAL (1 unidad = 1 cm, una burbuja
## mide ~1 cm; un lápiz 17 cm) más algo de geometría simple. Se ubican FUERA de la lámina
## (centro `c`, tamaño `e`, en el plano XZ): enmarcan los bordes y nunca se cruzan con ella.

const GROUND_Y: float = -0.05


## Escala de unidad para los objetos: 1 u = 1/20 del lado de la lámina (mínimo 1).
static func unit(e: Vector2) -> float:
	return maxf(1.0, maxf(e.x, e.y) / 20.0)


static func build(phase: int, c: Vector2, e: Vector2) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Props%d" % phase
	var u: float = unit(e)
	if phase == 2:
		_floor(root, c, e, u)
	elif phase == 3:
		_warehouse(root, c, e, u)
	elif phase == 4:
		_parking(root, c, e, u)
	else:
		_table(root, c, e, u)
	return root


# --- Utilidades --------------------------------------------------------------------------------

static func _mat(color: Color, rough: float = 0.6, metallic: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	return m


static func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	var std: StandardMaterial3D = mat as StandardMaterial3D
	var glows: bool = std != null and std.emission_enabled
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if glows else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi


## Instancia un modelo (en metros) a escala real: 1 m = 100 unidades.
static func _glb(root: Node3D, file: String, pos: Vector3, yaw_deg: float = 0.0, scale_factor: float = 100.0) -> Node3D:
	var ps: PackedScene = load("res://assets/models/%s.glb" % file) as PackedScene
	var m: Node3D = ps.instantiate() as Node3D
	m.position = pos
	m.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	m.scale = Vector3.ONE * scale_factor
	root.add_child(m)
	return m


static func _box(size: Vector3) -> BoxMesh:
	var b: BoxMesh = BoxMesh.new()
	b.size = size
	return b


static func _cyl(top: float, bottom: float, height: float, segments: int = 24) -> CylinderMesh:
	var m: CylinderMesh = CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	return m


# --- Mesa: lámpara cálida, taza y lápices (todo fuera de la lámina) -------------------------------------

static func _table(root: Node3D, c: Vector2, e: Vector2, _u: float) -> void:
	var h: Vector2 = e * 0.5
	var lamp: Node3D = Node3D.new()
	lamp.position = Vector3(c.x - h.x - 9.0, GROUND_Y, c.y - h.y - 4.0)
	root.add_child(lamp)
	_add(lamp, _cyl(2.6, 3.0, 0.8), _mat(Color("#2B2622"), 0.4, 0.5), Vector3(0.0, 0.4, 0.0))
	_add(lamp, _cyl(0.25, 0.25, 9.0, 12), _mat(Color("#B8893A"), 0.3, 0.8), Vector3(0.0, 4.8, 0.0))
	_add(lamp, _cyl(1.4, 4.2, 4.0), _emissive(Color("#FFB45A"), 1.6), Vector3(0.0, 10.0, 0.0))
	var bulb: OmniLight3D = OmniLight3D.new()
	bulb.light_color = Color("#FFA650")
	bulb.light_energy = 2.2
	bulb.omni_range = 90.0
	bulb.position = Vector3(0.0, 8.0, 0.0)
	lamp.add_child(bulb)
	_glb(root, "prop_cup", Vector3(c.x + h.x + 8.0, GROUND_Y, c.y - h.y * 0.2), 200.0)
	for i: int in 3:
		_glb(root, "prop_pencil", Vector3(c.x - h.x - 3.0 - 1.4 * float(i), GROUND_Y, c.y + h.y * 0.3 + 2.0 * float(i)), 4.0 * float(i) - 4.0)


# --- Piso: zócalo, pata de silla y ventana con persiana --------------------------------------------------

static func _floor(root: Node3D, c: Vector2, e: Vector2, u: float) -> void:
	var wall_z: float = c.y - e.y * 0.64
	_add(root, _box(Vector3(e.x * 2.4, 22.0 * u, 0.5 * u)), _mat(Color("#CFC8B5"), 0.9), Vector3(c.x, 11.0 * u, wall_z - 0.5 * u))
	_add(root, _box(Vector3(e.x * 2.4, 1.6 * u, 0.5 * u)), _mat(Color("#F1EEE6"), 0.5), Vector3(c.x, 0.8 * u, wall_z))
	# Ventana con persiana: un cuadro luminoso cruzado por tablillas oscuras.
	var win: Vector3 = Vector3(c.x + e.x * 0.35, 11.0 * u, wall_z + 0.05 * u)
	_add(root, _box(Vector3(11.0 * u, 12.0 * u, 0.3 * u)), _emissive(Color("#FFF3CF"), 1.5), win)
	for i: int in 7:
		_add(root, _box(Vector3(11.6 * u, 0.55 * u, 0.5 * u)), _mat(Color("#8D8777"), 0.6), win + Vector3(0.0, (float(i) - 3.0) * 1.55 * u, 0.3 * u))
	_add(root, _box(Vector3(12.2 * u, 0.6 * u, 0.7 * u)), _mat(Color("#F1EEE6"), 0.5), win + Vector3(0.0, -6.3 * u, 0.2 * u))
	# Pata de silla (modelo real, 42 cm) junto al borde izquierdo, fuera de la lámina.
	_glb(root, "prop_chair_leg", Vector3(c.x - e.x * 0.5 - 6.0, 0.0, c.y + e.y * 0.1))


# --- Galpón: estanterías con cajas, líneas de seguridad y polvo ----------------------------------------

static func _warehouse(root: Node3D, c: Vector2, e: Vector2, u: float) -> void:
	for sx: int in 2:
		var bx: float = c.x + (float(sx) - 0.5) * e.x * 0.8
		_glb(root, "prop_shelf", Vector3(bx, 0.0, c.y - e.y * 0.5 - 20.0))
	# Líneas amarillas de seguridad pintadas a los costados.
	var yellow: StandardMaterial3D = _mat(Color("#E8C21C"), 0.7)
	_add(root, _box(Vector3(0.5 * u, 0.06, e.y * 1.5)), yellow, Vector3(c.x - e.x * 0.68, GROUND_Y + 0.04, c.y))
	_add(root, _box(Vector3(0.5 * u, 0.06, e.y * 1.5)), yellow, Vector3(c.x + e.x * 0.68, GROUND_Y + 0.04, c.y))
	root.add_child(_dust(c, e, u))


static func _dust(c: Vector2, e: Vector2, u: float) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = "Dust"
	p.amount = 140
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.position = Vector3(c.x, 6.0 * u, c.y)
	var proc: ParticleProcessMaterial = ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(e.x * 0.9, 6.0 * u, e.y * 0.9)
	proc.direction = Vector3(0.3, 0.1, 0.0)
	proc.spread = 180.0
	proc.initial_velocity_min = 0.05 * u
	proc.initial_velocity_max = 0.35 * u
	proc.gravity = Vector3(0.0, -0.02 * u, 0.0)
	proc.scale_min = 0.5
	proc.scale_max = 1.4
	p.process_material = proc
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.1, 0.1) * u
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.95, 1.0, 0.4)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


# --- Estacionamiento: conos, cordón y farol ----------------------------------------------------------------

static func _parking(root: Node3D, c: Vector2, e: Vector2, u: float) -> void:
	var h: Vector2 = e * 0.5
	var spots: Array[Vector2] = [Vector2(-h.x - 14.0, -h.y * 0.6), Vector2(-h.x - 14.0, h.y * 0.5), Vector2(-h.x * 0.4, -h.y - 14.0), Vector2(h.x * 0.2, -h.y - 14.0)]
	for spot: Vector2 in spots:
		_glb(root, "prop_cone", Vector3(c.x + spot.x, 0.0, c.y + spot.y), spot.x * 7.0)
	_add(root, _box(Vector3(e.x * 2.4, 1.2 * u, 1.8 * u)), _mat(Color("#8C8E92"), 0.9), Vector3(c.x, 0.6 * u, c.y - e.y * 0.66 - 14.0))
	_add(root, _box(Vector3(e.x * 2.4, 0.12 * u, 1.9 * u)), _mat(Color("#E8C21C"), 0.7), Vector3(c.x, 1.25 * u, c.y - e.y * 0.66 - 14.0))
	var post: Vector3 = Vector3(c.x - e.x * 0.74, 0.0, c.y - e.y * 0.58)
	_add(root, _cyl(0.35 * u, 0.5 * u, 20.0 * u, 12), _mat(Color("#33353A"), 0.5, 0.6), post + Vector3(0.0, 10.0 * u, 0.0))
	_add(root, _box(Vector3(4.0 * u, 0.7 * u, 1.4 * u)), _emissive(Color("#FFD59A"), 2.0), post + Vector3(1.6 * u, 20.2 * u, 0.0))


static func _cone(root: Node3D, pos: Vector3, u: float) -> void:
	var orange: StandardMaterial3D = _mat(Color("#F0701C"), 0.5)
	_add(root, _box(Vector3(3.2 * u, 0.3 * u, 3.2 * u)), _mat(Color("#C85A12"), 0.6), pos + Vector3(0.0, 0.15 * u, 0.0))
	_add(root, _cyl(0.2 * u, 1.35 * u, 4.4 * u, 20), orange, pos + Vector3(0.0, 2.5 * u, 0.0))
	_add(root, _cyl(0.5 * u, 0.85 * u, 0.7 * u, 20), _mat(Color("#F4F2EA"), 0.4), pos + Vector3(0.0, 2.9 * u, 0.0))
