class_name ShaderWarmup
extends Node
## Precompila los shaders (sección 8 de la 0.7.0): dibuja un cuadradito de cada shader de res://shaders en un
## SubViewport diminuto durante unos frames, así ningún material (burbujas, pisos, manitos, contorno, rollo...)
## compila por primera vez en medio de una partida (tirones de más de 50 ms). Se libera solo al terminar.

const SHADERS_DIR: String = "res://shaders"
const FRAMES: int = 4

var _frames: int = 0
var _viewport: SubViewport


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(32, 32)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var cam: Camera3D = Camera3D.new()
	cam.position = Vector3(0.0, 0.0, 2.0)
	_viewport.add_child(cam)
	var count: int = 0
	for file: String in DirAccess.get_files_at(SHADERS_DIR):
		if not file.ends_with(".gdshader"):
			continue
		var sh: Shader = load(SHADERS_DIR.path_join(file)) as Shader
		if sh == null:
			continue
		var mi: MeshInstance3D = MeshInstance3D.new()
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(0.2, 0.2)
		mi.mesh = quad
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = sh
		mi.material_override = m
		mi.position = Vector3(float(count % 4) * 0.25 - 0.4, float(count / 4) * 0.25 - 0.2, 0.0)
		_viewport.add_child(mi)
		count += 1


func _process(_delta: float) -> void:
	_frames += 1
	if _frames >= FRAMES:
		queue_free()
