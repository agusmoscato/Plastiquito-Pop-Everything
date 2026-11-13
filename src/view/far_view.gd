class_name FarView
extends Node3D
## Dibujo de lejos: un plano por bloque de 64x64 celdas con una textura de estado RGBA8 de
## 1 píxel por burbuja (ver StatePacker) y el shader shaders/far_sheet.gdshader.
## Solo se vuelve a subir la textura de los bloques que cambiaron y que se ven de lejos;
## los demás quedan marcados como "atrasados" y se actualizan cuando la cámara se aleja.

var chunk_size: int = 64
var near_distance: float = 55.0
var fade_margin: float = 18.0

var _grid: HexGrid
var _chunks_x: int = 0
var _nodes: Array[MeshInstance3D] = []
var _materials: Array[ShaderMaterial] = []
var _images: Array[Image] = []
var _bytes: Array[PackedByteArray] = []
var _sizes: PackedInt32Array = PackedInt32Array() ## ancho y alto de cada bloque (de a pares)
var _textures: Array[ImageTexture] = []
var _centers: PackedVector3Array = PackedVector3Array()
var _fades: PackedFloat32Array = PackedFloat32Array()
var _stale: Dictionary = {} ## id de bloque -> true (la imagen cambió y la textura no)
var _shader: Shader
var uploads_last_frame: int = 0


func _init() -> void:
	_shader = load("res://shaders/far_sheet.gdshader") as Shader


func chunk_count() -> int:
	return _nodes.size()


func build(grid: HexGrid, p_chunk_size: int, p_near_distance: float, p_fade_margin: float) -> void:
	clear()
	_grid = grid
	chunk_size = p_chunk_size
	near_distance = p_near_distance
	fade_margin = p_fade_margin
	_chunks_x = ceili(float(grid.width) / float(chunk_size))
	var chunks_y: int = ceili(float(grid.height) / float(chunk_size))
	for cy: int in chunks_y:
		for cx: int in _chunks_x:
			_build_chunk(cx, cy)


func clear() -> void:
	for n: MeshInstance3D in _nodes:
		n.queue_free()
	_nodes.clear()
	_materials.clear()
	_images.clear()
	_bytes.clear()
	_sizes = PackedInt32Array()
	_textures.clear()
	_stale.clear()
	_fades = PackedFloat32Array()
	_centers = PackedVector3Array()


## Escribe el estado de una celda en el buffer del bloque (la textura se sube en sync()).
func set_cell(chunk_id: int, lx: int, ly: int, pressure: float, squash: float, pop: float, type_id: int) -> void:
	var w: int = _sizes[chunk_id * 2]
	StatePacker.pack_to(_bytes[chunk_id], (ly * w + lx) * 4, pressure, squash, pop, type_id)
	_stale[chunk_id] = true


func center_of(chunk_id: int) -> Vector3:
	return _centers[chunk_id]


## Sube las texturas atrasadas de los bloques que hoy se dibujan de lejos (o a punto de).
func sync(camera_pos: Vector3) -> void:
	uploads_last_frame = 0
	if _stale.is_empty():
		return
	var threshold: float = near_distance - fade_margin * 1.5
	var done: Array[int] = []
	for key: Variant in _stale:
		var id: int = key
		if camera_pos.distance_to(_centers[id]) >= threshold:
			_images[id].set_data(_sizes[id * 2], _sizes[id * 2 + 1], false, Image.FORMAT_RGBA8, _bytes[id])
			_images[id].generate_mipmaps()
			_textures[id].update(_images[id])
			done.append(id)
			uploads_last_frame += 1
	for id: int in done:
		_stale.erase(id)


## Fundido del bloque (0 = no se ve, 1 = opaco). Solo se toca el material si cambió de verdad.
func set_fade(chunk_id: int, f: float) -> void:
	if absf(f - _fades[chunk_id]) < 0.004:
		return
	_fades[chunk_id] = f
	_materials[chunk_id].set_shader_parameter("fade", f)
	_nodes[chunk_id].visible = f > 0.0


func fade_of(chunk_id: int) -> float:
	return _fades[chunk_id]


func set_reveal_z(z: float) -> void:
	for m: ShaderMaterial in _materials:
		m.set_shader_parameter("reveal_z", z)


func _build_chunk(cx: int, cy: int) -> void:
	var q0: int = cx * chunk_size
	var r0: int = cy * chunk_size
	var w: int = mini(chunk_size, _grid.width - q0)
	var h: int = mini(chunk_size, _grid.height - r0)
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(StatePacker.default_pixel())
	_bytes.append(img.get_data())
	img.generate_mipmaps()
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_sizes.append(w)
	_sizes.append(h)
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("state_tex", tex)
	mat.set_shader_parameter("chunk_q0", float(q0))
	mat.set_shader_parameter("chunk_r0", float(r0))
	mat.set_shader_parameter("chunk_w", float(w))
	mat.set_shader_parameter("chunk_h", float(h))
	mat.set_shader_parameter("spacing", _grid.spacing)
	mat.set_shader_parameter("hex_size", _grid.hex_size)
	mat.set_shader_parameter("row_step", _grid.row_step)
	mat.set_shader_parameter("bubble_r", _grid.bubble_radius * 0.94)
	var x0: float = _grid.spacing * float(q0) - _grid.spacing
	var x1: float = _grid.spacing * float(q0 + w) + _grid.spacing
	var z0: float = _grid.row_step * float(r0) - _grid.row_step * 1.5
	var z1: float = _grid.row_step * float(r0 + h) + _grid.row_step * 1.5
	var quad: PlaneMesh = PlaneMesh.new()
	quad.size = Vector2(x1 - x0, z1 - z0)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = "Far_%d_%d" % [cx, cy]
	node.mesh = quad
	node.material_override = mat
	node.position = Vector3((x0 + x1) * 0.5, 0.05, (z0 + z1) * 0.5)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 1.0
	node.visible = false
	add_child(node)
	_nodes.append(node)
	_materials.append(mat)
	_images.append(img)
	_textures.append(tex)
	_centers.append(Vector3((x0 + x1) * 0.5, 0.0, (z0 + z1) * 0.5))
	_fades.append(0.0)
