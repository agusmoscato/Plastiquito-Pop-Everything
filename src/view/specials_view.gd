class_name SpecialsView
extends Node3D
## Burbujas especiales como objetos 3D propios (forma distinguible además del color):
## Dorada = joya con facetas y brillo, Bomba = esfera con mecha, Línea = cápsula larga con bandas.
## La burbuja base del MultiMesh se esconde (shader) mientras la especial está entera.

const TYPE_GOLDEN: int = 1
const TYPE_BOMB: int = 2
const TYPE_LINE: int = 3
const TYPE_ECHO: int = 4
const MAX_NODES: int = 800

var sheet: SheetModel
var grid: HexGrid

var _nodes: Dictionary = {} ## idx -> Node3D
var _meshes: Dictionary = {}
var _mats: Dictionary = {}
var _dying: Array[Dictionary] = []
var _t: float = 0.0
var _new_label_cell: Dictionary = {} ## tipo -> idx con etiqueta NUEVA


func _init() -> void:
	_build_assets()


func bind(p_sheet: SheetModel, p_grid: HexGrid) -> void:
	for n: Variant in _nodes.values():
		var node: Node3D = n
		node.queue_free()
	_nodes.clear()
	_new_label_cell.clear()
	if sheet != null and sheet.cells_changed.is_connected(_on_cells_changed):
		sheet.cells_changed.disconnect(_on_cells_changed)
	sheet = p_sheet
	grid = p_grid
	sheet.cells_changed.connect(_on_cells_changed)
	var count: int = 0
	for idx: int in sheet.cell_count():
		if sheet.type[idx] != 0 and sheet.state[idx] != SheetModel.STATE_POPPED and count < MAX_NODES:
			_spawn(idx, sheet.type[idx])
			count += 1


## Pega la etiqueta "NUEVA" sobre la primera especial de ese tipo.
func mark_new(type_id: int, text: String) -> void:
	for key: Variant in _nodes:
		var idx: int = key
		if sheet.type[idx] != type_id:
			continue
		var label: Label3D = Label3D.new()
		label.text = text
		label.font = UiKit.font_title()
		label.font_size = 54
		label.pixel_size = 0.006
		label.modulate = UiKit.STAMP_RED
		label.outline_modulate = UiKit.PAPER
		label.outline_size = 14
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.position = Vector3(0.0, 1.35, 0.0)
		label.rotation_degrees.z = -6.0
		var node: Node3D = _nodes[idx]
		node.add_child(label)
		_new_label_cell[type_id] = idx
		return


func _process(delta: float) -> void:
	_t += delta
	for key: Variant in _nodes:
		var node: Node3D = _nodes[key]
		var idx: int = key
		var type_id: int = sheet.type[idx]
		var bob: float = sin(_t * 2.2 + float(idx)) * 0.04
		node.position.y = 0.32 + bob
		if type_id == TYPE_GOLDEN:
			node.rotation.y += delta * 1.1
		elif type_id == TYPE_BOMB:
			var spark: Node3D = node.get_node_or_null("Spark") as Node3D
			if spark != null:
				var s: float = 0.8 + 0.4 * absf(sin(_t * 9.0 + float(idx)))
				spark.scale = Vector3(s, s, s)
	var alive: Array[Dictionary] = []
	for d: Dictionary in _dying:
		var node: Node3D = d["node"]
		var life: float = d["life"]
		life -= delta
		if life <= 0.0:
			node.queue_free()
			continue
		var k: float = life / 0.18
		node.scale = Vector3.ONE * k
		node.position.y += delta * 2.0
		d["life"] = life
		alive.append(d)
	_dying = alive


func _on_cells_changed(indices: PackedInt32Array) -> void:
	for idx: int in indices:
		if _nodes.has(idx) and sheet.state[idx] == SheetModel.STATE_POPPED:
			var node: Node3D = _nodes[idx]
			_nodes.erase(idx)
			_dying.append({"node": node, "life": 0.18})


func _spawn(idx: int, type_id: int) -> void:
	var node: Node3D = Node3D.new()
	var p: Vector2 = grid.cell_to_world(idx)
	node.position = Vector3(p.x, 0.32, p.y)
	add_child(node)
	if type_id == TYPE_GOLDEN:
		_add(node, "gem", "gold", Vector3.ZERO, Vector3.ZERO)
	elif type_id == TYPE_BOMB:
		_add(node, "ball", "bomb", Vector3.ZERO, Vector3.ZERO)
		_add(node, "fuse", "fuse", Vector3(0.12, 0.42, 0.0), Vector3(0.0, 0.0, -25.0))
		var spark: MeshInstance3D = _add(node, "spark", "spark", Vector3(0.22, 0.62, 0.0), Vector3.ZERO)
		spark.name = "Spark"
	elif type_id == TYPE_ECHO:
		_add(node, "echo_ball", "echo", Vector3.ZERO, Vector3.ZERO)
		_add(node, "echo_ring", "echo_ring", Vector3(0.0, 0.0, 0.0), Vector3(90.0, 0.0, 0.0))
	elif type_id == TYPE_LINE:
		_add(node, "capsule", "line", Vector3.ZERO, Vector3(0.0, 0.0, 90.0))
		for dx: float in [-0.32, 0.0, 0.32]:
			_add(node, "band", "band", Vector3(dx, 0.0, 0.0), Vector3(0.0, 0.0, 90.0))
	_nodes[idx] = node


func _add(parent: Node3D, mesh_key: String, mat_key: String, pos: Vector3, rot_deg: Vector3) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var mesh: Mesh = _meshes[mesh_key]
	var mat: Material = _mats[mat_key]
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _build_assets() -> void:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.42
	sphere.height = 0.84
	sphere.radial_segments = 6
	sphere.rings = 3
	_meshes["gem"] = _flat(sphere)
	var ball: SphereMesh = SphereMesh.new()
	ball.radius = 0.34
	ball.height = 0.68
	ball.radial_segments = 20
	ball.rings = 10
	_meshes["ball"] = ball
	var fuse: CylinderMesh = CylinderMesh.new()
	fuse.top_radius = 0.035
	fuse.bottom_radius = 0.045
	fuse.height = 0.34
	_meshes["fuse"] = fuse
	var spark: SphereMesh = SphereMesh.new()
	spark.radius = 0.07
	spark.height = 0.14
	spark.radial_segments = 8
	spark.rings = 4
	_meshes["spark"] = spark
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = 0.2
	capsule.height = 1.05
	_meshes["capsule"] = capsule
	var band: CylinderMesh = CylinderMesh.new()
	band.top_radius = 0.215
	band.bottom_radius = 0.215
	band.height = 0.07
	_meshes["band"] = band
	var echo_ball: SphereMesh = SphereMesh.new()
	echo_ball.radius = 0.28
	echo_ball.height = 0.56
	_meshes["echo_ball"] = echo_ball
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.36
	ring.outer_radius = 0.46
	_meshes["echo_ring"] = ring
	var echo_mat: StandardMaterial3D = ToolMeshes.material(Color("#BFE9FF"), 0.0)
	echo_mat.emission_enabled = true
	echo_mat.emission = Color("#8FD0F2")
	echo_mat.emission_energy_multiplier = 0.9
	_mats["echo"] = echo_mat
	_mats["echo_ring"] = echo_mat
	var gold: StandardMaterial3D = ToolMeshes.material(Color("#F2C94C"), 0.9)
	gold.emission_enabled = true
	gold.emission = Color("#F2B531")
	gold.emission_energy_multiplier = 1.7 # el único glow del juego junto al arcoíris futuro
	_mats["gold"] = gold
	_mats["bomb"] = ToolMeshes.material(Color("#2B2A33"), 0.1)
	_mats["fuse"] = ToolMeshes.material(UiKit.KRAFT_DARK)
	var spark_mat: StandardMaterial3D = StandardMaterial3D.new()
	spark_mat.albedo_color = Color("#FF8A2A")
	spark_mat.emission_enabled = true
	spark_mat.emission = Color("#FF6A1A")
	spark_mat.emission_energy_multiplier = 3.0
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats["spark"] = spark_mat
	_mats["line"] = ToolMeshes.material(Color("#2FB8CC"), 0.05)
	_mats["band"] = ToolMeshes.material(UiKit.PAPER)


## Malla con normales por cara (facetas).
func _flat(mesh: Mesh) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.create_from(mesh, 0)
	st.deindex()
	st.generate_normals()
	return st.commit()
