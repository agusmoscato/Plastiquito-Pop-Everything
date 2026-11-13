class_name FxPool
extends Node3D
## Pool de emisores de partículas reutilizables (pedacitos de plástico + polvito).
## Nunca se instancian nodos al reventar: se reubica y reinicia el siguiente del pool.

var _entries: Array[Node3D] = []
var _shards: Array[GPUParticles3D] = []
var _dust: Array[GPUParticles3D] = []
var _next: int = 0
var _max_per_frame: int = 6
var _frame: int = -1
var _used_this_frame: int = 0
var _special: Dictionary = {} ## tipo -> Array[GPUParticles3D] (partículas propias de cada especial)
var _special_next: Dictionary = {}


func setup(cfg: Dictionary) -> void:
	_max_per_frame = Cfg.integer(cfg, "max_fx_per_frame")
	var shard_mat: ParticleProcessMaterial = _shard_process()
	var dust_mat: ParticleProcessMaterial = _dust_process()
	var shard_mesh: QuadMesh = _quad(0.09, Color(0.75, 0.92, 1.0, 0.55), 0.0)
	var dust_mesh: QuadMesh = _quad(0.32, Color(1.0, 1.0, 1.0, 0.18), 0.0)
	for i: int in Cfg.integer(cfg, "particle_pool_size"):
		var holder: Node3D = Node3D.new()
		holder.name = "Fx%02d" % i
		add_child(holder)
		var shards: GPUParticles3D = _emitter(shard_mat, shard_mesh, Cfg.integer(cfg, "shards_per_pop"), 0.7)
		var dust: GPUParticles3D = _emitter(dust_mat, dust_mesh, Cfg.integer(cfg, "dust_per_pop"), 0.55)
		holder.add_child(shards)
		holder.add_child(dust)
		_entries.append(holder)
		_shards.append(shards)
		_dust.append(dust)
	_build_special_emitters()


## Partículas propias: Dorada = chispas amarillas hacia arriba, Bomba = brasas naranjas, Línea = rayas celestes.
func _build_special_emitters() -> void:
	var defs: Dictionary = {
		1: {"color": Color(1.0, 0.82, 0.25, 0.9), "size": 0.12, "amount": 26, "vel": 4.5, "spread": 60.0, "grav": -2.0},
		2: {"color": Color(1.0, 0.45, 0.12, 0.9), "size": 0.16, "amount": 34, "vel": 6.0, "spread": 180.0, "grav": -6.0},
		3: {"color": Color(0.35, 0.85, 0.95, 0.9), "size": 0.1, "amount": 22, "vel": 7.0, "spread": 25.0, "grav": 0.0},
	}
	for type_id: int in defs:
		var d: Dictionary = defs[type_id]
		var proc: ParticleProcessMaterial = ParticleProcessMaterial.new()
		var up: Vector3 = Vector3(0.0, 1.0, 0.0) if type_id != 3 else Vector3(1.0, 0.2, 0.0)
		proc.direction = up
		proc.spread = Cfg.num(d, "spread")
		proc.initial_velocity_min = Cfg.num(d, "vel") * 0.5
		proc.initial_velocity_max = Cfg.num(d, "vel")
		proc.gravity = Vector3(0.0, Cfg.num(d, "grav"), 0.0)
		proc.color_ramp = _fade_ramp()
		proc.scale_min = 0.6
		proc.scale_max = 1.4
		var color: Color = d["color"]
		var mesh: QuadMesh = _quad(Cfg.num(d, "size"), color, 1.0)
		var list: Array[GPUParticles3D] = []
		for i: int in 3:
			var e: GPUParticles3D = _emitter(proc, mesh, Cfg.integer(d, "amount"), 0.7)
			add_child(e)
			list.append(e)
		_special[type_id] = list
		_special_next[type_id] = 0


func emit_special(pos: Vector3, type_id: int) -> void:
	if not _special.has(type_id):
		return
	var list: Array = _special[type_id]
	var idx: int = _special_next[type_id]
	var e: GPUParticles3D = list[idx]
	_special_next[type_id] = (idx + 1) % list.size()
	e.global_position = pos
	e.restart()


func pool_size() -> int:
	return _entries.size()


## Dispara los efectos en `positions` (limitado por frame para no saturar).
func emit_at(positions: PackedVector3Array) -> void:
	if _entries.is_empty() or positions.is_empty():
		return
	var frame: int = Engine.get_process_frames()
	if frame != _frame:
		_frame = frame
		_used_this_frame = 0
	var budget: int = _max_per_frame - _used_this_frame
	if budget <= 0:
		return
	var stride: float = maxf(1.0, float(positions.size()) / float(budget))
	var i: float = 0.0
	while int(i) < positions.size() and budget > 0:
		_fire(positions[int(i)])
		budget -= 1
		_used_this_frame += 1
		i += stride


func _fire(pos: Vector3) -> void:
	_entries[_next].global_position = pos
	_shards[_next].restart()
	_dust[_next].restart()
	_next = (_next + 1) % _entries.size()


func _emitter(proc: ParticleProcessMaterial, mesh: Mesh, amount: int, lifetime: float) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.amount = maxi(1, amount)
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.local_coords = false
	p.process_material = proc
	p.draw_pass_1 = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _quad(size: float, color: Color, glow: float) -> QuadMesh:
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(size, size)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_dot()
	m.emission_enabled = glow > 0.0
	q.material = m
	return q


func _shard_process() -> ParticleProcessMaterial:
	var m: ParticleProcessMaterial = ParticleProcessMaterial.new()
	m.direction = Vector3(0.0, 1.0, 0.0)
	m.spread = 75.0
	m.initial_velocity_min = 1.5
	m.initial_velocity_max = 3.8
	m.gravity = Vector3(0.0, -9.0, 0.0)
	m.scale_min = 0.5
	m.scale_max = 1.3
	m.angular_velocity_min = -360.0
	m.angular_velocity_max = 360.0
	m.color_ramp = _fade_ramp()
	return m


func _dust_process() -> ParticleProcessMaterial:
	var m: ParticleProcessMaterial = ParticleProcessMaterial.new()
	m.direction = Vector3(0.0, 1.0, 0.0)
	m.spread = 90.0
	m.initial_velocity_min = 0.3
	m.initial_velocity_max = 1.1
	m.gravity = Vector3(0.0, 0.3, 0.0)
	m.damping_min = 1.0
	m.damping_max = 2.0
	m.scale_min = 0.6
	m.scale_max = 1.6
	m.color_ramp = _fade_ramp()
	return m


## Punto redondo suave (centro opaco, borde transparente) para que las partículas no sean cuadrados.
func _soft_dot() -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	return t


func _fade_ramp() -> GradientTexture1D:
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	g.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var t: GradientTexture1D = GradientTexture1D.new()
	t.gradient = g
	return t
