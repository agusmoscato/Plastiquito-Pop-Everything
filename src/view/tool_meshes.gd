class_name ToolMeshes
extends RefCounted
## Las herramientas 3D armadas con primitivas (sin modelos). Las usan el cursor del mundo
## (ToolView) y los íconos en vivo de la tienda (ToolIcon). La punta/contacto queda en y = 0.

const TIER_COLORS: Dictionary = {
	"finger": [Color("#E8795F"), Color("#E5A13A"), Color("#D5D8DB"), Color("#F2C94C")],
	"palm": [Color("#D9694E"), Color("#C7922F"), Color("#C9CDD1"), Color("#F2C94C")],
	"rolling_pin": [Color("#B98552"), Color("#9C6B3A"), Color("#C9CDD1"), Color("#F2C94C")],
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


## Devuelve un Node3D con la herramienta. `radius` es el tamaño del golpe en el mundo.
static func build(tool_id: String, radius: float, tier: int = 0) -> Node3D:
	var root: Node3D = Node3D.new()
	var metallic: float = 0.85 if tier >= 2 else 0.0
	var mat: StandardMaterial3D = material(tier_color(tool_id, tier), metallic)
	if tool_id != "finger": # las herramientas de área son translúcidas: dejan ver lo que aplastan
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.78
	if tool_id == "palm":
		_build_palm(root, mat, maxf(radius, 1.0) * 0.85)
	elif tool_id == "rolling_pin":
		_build_pin(root, mat, maxf(radius, 1.0))
	else:
		_build_finger(root, mat, radius)
	return root


static func _build_finger(root: Node3D, mat: StandardMaterial3D, radius: float) -> void:
	var body: Node3D = Node3D.new()
	root.add_child(body)
	body.name = "Body"
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = 0.34 + radius * 0.25
	capsule.height = 1.9 + radius * 0.5
	capsule.radial_segments = 24
	capsule.rings = 8
	_part(body, capsule, mat, Vector3(0.0, capsule.height * 0.5 - capsule.radius * 0.8, 0.0))
	body.rotation_degrees = Vector3(28.0, 0.0, 0.0)


static func _build_palm(root: Node3D, mat: StandardMaterial3D, radius: float) -> void:
	var body: Node3D = Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var plate: CylinderMesh = CylinderMesh.new()
	plate.top_radius = radius * 0.92
	plate.bottom_radius = radius
	plate.height = 0.3
	plate.radial_segments = 40
	_part(body, plate, mat, Vector3(0.0, 0.16, 0.0))
	var dome: CylinderMesh = CylinderMesh.new()
	dome.top_radius = radius * 0.5
	dome.bottom_radius = radius * 0.86
	dome.height = 0.28
	dome.radial_segments = 40
	_part(body, dome, mat, Vector3(0.0, 0.4, 0.0))
	var knob: SphereMesh = SphereMesh.new()
	knob.radius = radius * 0.2
	knob.height = radius * 0.34
	_part(body, knob, material(mat.albedo_color.lightened(0.15), mat.metallic), Vector3(0.0, 0.62, 0.0))


static func _build_pin(root: Node3D, mat: StandardMaterial3D, half_length: float) -> void:
	var body: Node3D = Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var roller: CylinderMesh = CylinderMesh.new()
	roller.top_radius = 0.42
	roller.bottom_radius = 0.42
	roller.height = half_length * 2.0
	roller.radial_segments = 28
	_part(body, roller, mat, Vector3(0.0, 0.42, 0.0), Vector3(0.0, 0.0, 90.0))
	var handle_mat: StandardMaterial3D = material(mat.albedo_color.darkened(0.25), mat.metallic)
	for side: float in [-1.0, 1.0]:
		var handle: CylinderMesh = CylinderMesh.new()
		handle.top_radius = 0.16
		handle.bottom_radius = 0.16
		handle.height = 0.9
		_part(body, handle, handle_mat, Vector3(side * (half_length + 0.4), 0.42, 0.0), Vector3(0.0, 0.0, 90.0))
		var cap: SphereMesh = SphereMesh.new()
		cap.radius = 0.2
		cap.height = 0.4
		_part(body, cap, handle_mat, Vector3(side * (half_length + 0.85), 0.42, 0.0))
