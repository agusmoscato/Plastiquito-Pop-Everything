class_name GraphicsQuality
extends RefCounted
## Calidad de gráficos (Opciones): 0 bajo, 1 medio, 2 alto. Bajo: sin sombras, sin oclusión,
## sin brillo ni desenfoque, y la imagen 3D a 2/3 de resolución (la interfaz queda nítida).
## Medio: sombras y brillo, sin oclusión ni desenfoque, 85 % de resolución. Alto: todo.

const LOW: int = 0
const MEDIUM: int = 1
const HIGH: int = 2
const SCALES: Array[float] = [0.67, 0.85, 1.0]


static func name_of(level: int, lang: String) -> String:
	var es: Array[String] = ["BAJO", "MEDIO", "ALTO"]
	var en: Array[String] = ["LOW", "MEDIUM", "HIGH"]
	return (es if lang == "es" else en)[clampi(level, LOW, HIGH)]


static func next(level: int) -> int:
	return (clampi(level, LOW, HIGH) + 2) % 3 # alto -> medio -> bajo -> alto


static func apply(world: ToyWorld, level: int) -> void:
	var q: int = clampi(level, LOW, HIGH)
	var vp: Viewport = world.get_viewport()
	if vp != null:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = SCALES[q]
	var env: Environment = world.environment.environment
	env.ssao_enabled = q == HIGH
	env.glow_enabled = q >= MEDIUM
	world.light.shadow_enabled = q >= MEDIUM
	var attrs: CameraAttributesPractical = world.camera_rig.camera.attributes as CameraAttributesPractical
	if attrs != null:
		attrs.dof_blur_far_enabled = q == HIGH
