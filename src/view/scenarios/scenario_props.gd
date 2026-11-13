class_name ScenarioProps
extends RefCounted
## Objetos de cada escenario, armados solo con primitivas de Godot. Se ubican alrededor de la
## lámina (centro `c`, tamaño `e`, en el plano XZ) y escalan con ella para que se reconozcan
## igual con una lámina de 8x8 o de 150x150.

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


# --- Mesa: lámpara cálida, borde de taza y lápices ------------------------------------------------------

static func _table(root: Node3D, c: Vector2, e: Vector2, u: float) -> void:
	var lamp: Node3D = Node3D.new()
	lamp.position = Vector3(c.x - e.x * 0.58, GROUND_Y, c.y - e.y * 0.3)
	root.add_child(lamp)
	_add(lamp, _cyl(1.1 * u, 1.3 * u, 0.35 * u), _mat(Color("#2B2622"), 0.4, 0.5), Vector3(0.0, 0.17 * u, 0.0))
	_add(lamp, _cyl(0.12 * u, 0.12 * u, 4.0 * u, 12), _mat(Color("#B8893A"), 0.3, 0.8), Vector3(0.0, 2.2 * u, 0.0))
	_add(lamp, _cyl(0.6 * u, 2.0 * u, 1.8 * u), _emissive(Color("#FFB45A"), 1.6), Vector3(0.0, 4.6 * u, 0.0))
	var bulb: OmniLight3D = OmniLight3D.new()
	bulb.light_color = Color("#FFA650")
	bulb.light_energy = 2.2
	bulb.omni_range = 40.0 * u
	bulb.position = Vector3(0.0, 3.8 * u, 0.0)
	lamp.add_child(bulb)
	# Borde de una taza blanca vista desde arriba (un aro grueso con café adentro).
	var cup: Node3D = Node3D.new()
	cup.position = Vector3(c.x + e.x * 0.9, GROUND_Y, c.y - e.y * 0.78)
	root.add_child(cup)
	var rim: TorusMesh = TorusMesh.new()
	rim.inner_radius = 4.4 * u
	rim.outer_radius = 5.5 * u
	rim.rings = 40
	rim.ring_segments = 14
	_add(cup, rim, _mat(Color("#EFE9DD"), 0.2), Vector3(0.0, 2.4 * u, 0.0))
	_add(cup, _cyl(4.6 * u, 4.6 * u, 2.4 * u, 40), _mat(Color("#EFE9DD"), 0.2), Vector3(0.0, 1.2 * u, 0.0))
	_add(cup, _cyl(4.4 * u, 4.4 * u, 0.1 * u, 40), _mat(Color("#3B2412"), 0.15), Vector3(0.0, 2.3 * u, 0.0))
	# Lápices amarillos con punta y goma.
	var colors: Array[Color] = [Color("#F2C230"), Color("#E85D4A"), Color("#4C9BD6")]
	for i: int in 3:
		var pencil: Node3D = Node3D.new()
		pencil.position = Vector3(c.x + e.x * (0.78 + 0.06 * float(i)), GROUND_Y + 0.25 * u, c.y + e.y * (0.58 + 0.08 * float(i)))
		pencil.rotation_degrees = Vector3(0.0, -18.0 + 14.0 * float(i), 0.0)
		root.add_child(pencil)
		_add(pencil, _cyl(0.25 * u, 0.25 * u, 7.0 * u, 6), _mat(colors[i], 0.4), Vector3.ZERO, Vector3(0.0, 0.0, 90.0))
		_add(pencil, _cyl(0.0, 0.25 * u, 0.9 * u, 6), _mat(Color("#E7C79A"), 0.8), Vector3(-3.95 * u, 0.0, 0.0), Vector3(0.0, 0.0, 90.0))
		_add(pencil, _cyl(0.25 * u, 0.25 * u, 0.5 * u, 6), _mat(Color("#E9A0A0"), 0.7), Vector3(3.75 * u, 0.0, 0.0), Vector3(0.0, 0.0, 90.0))


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
	# Pata de silla con travesaño.
	var leg: Vector3 = Vector3(c.x - e.x * 0.64, 0.0, c.y + e.y * 0.05)
	_add(root, _cyl(0.55 * u, 0.4 * u, 16.0 * u, 16), _mat(Color("#7C7F86"), 0.3, 0.8), leg + Vector3(0.0, 8.0 * u, 0.0))
	_add(root, _cyl(0.5 * u, 0.5 * u, 0.4 * u, 16), _mat(Color("#222222"), 0.9), leg + Vector3(0.0, 0.2 * u, 0.0))
	_add(root, _cyl(0.2 * u, 0.2 * u, 7.0 * u, 12), _mat(Color("#7C7F86"), 0.3, 0.8), leg + Vector3(3.5 * u, 4.0 * u, 0.0), Vector3(0.0, 0.0, 90.0))


# --- Galpón: estanterías con cajas, líneas de seguridad y polvo ----------------------------------------

static func _warehouse(root: Node3D, c: Vector2, e: Vector2, u: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 33
	var steel: StandardMaterial3D = _mat(Color("#2F4F6F"), 0.4, 0.6)
	var plank: StandardMaterial3D = _mat(Color("#D9792B"), 0.5, 0.3)
	for s: int in 2:
		var base: Vector3 = Vector3(c.x + (float(s) - 0.5) * e.x * 0.9, 0.0, c.y - e.y * 0.62)
		for px: float in [-5.2, 5.2]:
			for pz: float in [-1.2, 1.2]:
				_add(root, _box(Vector3(0.5 * u, 14.0 * u, 0.5 * u)), steel, base + Vector3(px * u, 7.0 * u, pz * u))
		for level: int in 3:
			var y: float = (1.0 + float(level) * 4.6) * u
			_add(root, _box(Vector3(11.2 * u, 0.4 * u, 3.0 * u)), plank, base + Vector3(0.0, y, 0.0))
			var x: float = -4.6
			while x < 4.0:
				var w: float = rng.randf_range(1.6, 3.0)
				var h: float = rng.randf_range(1.4, 3.6)
				var kraft: Color = Color("#B98A56").lerp(Color("#8E6B47"), rng.randf())
				_add(root, _box(Vector3(w * u, h * u, 2.4 * u)), _mat(kraft, 0.9), base + Vector3((x + w * 0.5) * u, y + (h * 0.5 + 0.2) * u, 0.0), Vector3(0.0, rng.randf_range(-4.0, 4.0), 0.0))
				x += w + rng.randf_range(0.1, 0.5)
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
	var cone_spots: Array[Vector2] = [Vector2(-0.62, -0.5), Vector2(0.64, -0.46), Vector2(-0.66, 0.35), Vector2(0.6, 0.5)]
	for spot: Vector2 in cone_spots:
		_cone(root, Vector3(c.x + e.x * spot.x, 0.0, c.y + e.y * spot.y), u)
	_add(root, _box(Vector3(e.x * 2.4, 1.2 * u, 1.8 * u)), _mat(Color("#8C8E92"), 0.9), Vector3(c.x, 0.6 * u, c.y - e.y * 0.66))
	_add(root, _box(Vector3(e.x * 2.4, 0.12 * u, 1.9 * u)), _mat(Color("#E8C21C"), 0.7), Vector3(c.x, 1.25 * u, c.y - e.y * 0.66))
	var post: Vector3 = Vector3(c.x + e.x * 0.74, 0.0, c.y - e.y * 0.58)
	_add(root, _cyl(0.35 * u, 0.5 * u, 20.0 * u, 12), _mat(Color("#33353A"), 0.5, 0.6), post + Vector3(0.0, 10.0 * u, 0.0))
	_add(root, _box(Vector3(4.0 * u, 0.7 * u, 1.4 * u)), _emissive(Color("#FFD59A"), 2.0), post + Vector3(-1.6 * u, 20.2 * u, 0.0))


static func _cone(root: Node3D, pos: Vector3, u: float) -> void:
	var orange: StandardMaterial3D = _mat(Color("#F0701C"), 0.5)
	_add(root, _box(Vector3(3.2 * u, 0.3 * u, 3.2 * u)), _mat(Color("#C85A12"), 0.6), pos + Vector3(0.0, 0.15 * u, 0.0))
	_add(root, _cyl(0.2 * u, 1.35 * u, 4.4 * u, 20), orange, pos + Vector3(0.0, 2.5 * u, 0.0))
	_add(root, _cyl(0.5 * u, 0.85 * u, 0.7 * u, 20), _mat(Color("#F4F2EA"), 0.4), pos + Vector3(0.0, 2.9 * u, 0.0))
