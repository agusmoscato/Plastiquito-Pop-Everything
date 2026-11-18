class_name ToyStyle
extends RefCounted
## Un solo estilo para todo lo 3D: juguete con sombreado en bandas (toon), sin brillos metálicos ni
## relieves de ruido, luz de borde suave y contorno oscuro. Lo usan las herramientas, la mano, la
## utilería de los escenarios y los especiales, así nada desentona (antes convivían materiales PBR
## brillantes, metal, ruido de relieve y objetos planos). Los íconos se renderizan con el mismo
## criterio en Blender (art/icons.py).

const RIM: float = 0.25
const RIM_TINT: float = 0.5


## Lleva un material al estilo juguete (en el lugar: los materiales importados se comparten entre
## instancias y así quedan todos iguales).
static func toonify(m: BaseMaterial3D) -> void:
	if m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.metallic = 0.0
	m.metallic_specular = 0.3
	m.roughness = maxf(m.roughness, 0.55)
	m.normal_enabled = false
	m.clearcoat_enabled = false
	m.rim_enabled = true
	m.rim = RIM
	m.rim_tint = RIM_TINT


## Recorre el nodo y aplica el estilo a cada material estándar; con `outline`, agrega el contorno
## oscuro a las mallas opacas que todavía no tienen overlay.
static func apply(node: Node, outline: bool = true) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		var opaque: bool = _style_materials(mi)
		if outline and opaque and mi.material_overlay == null:
			ToolMeshes.add_outline(mi, ToolMeshes.OUTLINE_DARK)
	for c: Node in node.get_children():
		apply(c, outline)


## Aplica toonify a todos los materiales de la malla. Devuelve si la malla es opaca.
static func _style_materials(mi: MeshInstance3D) -> bool:
	var opaque: bool = true
	var mats: Array[Material] = [mi.material_override]
	if mi.mesh != null:
		for i: int in mi.mesh.get_surface_count():
			mats.append(mi.get_surface_override_material(i))
			mats.append(mi.mesh.surface_get_material(i))
	for m: Material in mats:
		if m is BaseMaterial3D:
			var bm: BaseMaterial3D = m as BaseMaterial3D
			toonify(bm)
			if bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				opaque = false
		elif m is ShaderMaterial:
			opaque = false # materiales propios (burbujas, fantasmas): ya tienen su estilo
	return opaque
