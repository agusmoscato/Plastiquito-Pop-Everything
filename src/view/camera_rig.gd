class_name CameraRig
extends Node3D
## Cámara en perspectiva inclinada (~55°). Zoom con la rueda entre límites, movimiento
## suave por interpolación y sacudida por trauma. Sin rotación libre.

signal zoomed

const PITCH_DEGREES: float = 55.0
const FOV: float = 40.0
const ZOOM_STEP: float = 1.12
const PAN_SPEED: float = 0.9 ## unidades por segundo por unidad de zoom
const SMOOTHING: float = 9.0

var camera: Camera3D
var min_zoom: float = 4.0
var max_zoom: float = 60.0
var bounds_center: Vector2 = Vector2.ZERO
var bounds_half: Vector2 = Vector2(10.0, 10.0)
var shake_cfg: Dictionary = {}

var _zoom: float = 20.0
var _target_zoom: float = 20.0
var _target_pos: Vector3 = Vector3.ZERO
var _noise: FastNoiseLite = FastNoiseLite.new()
var _noise_t: float = 0.0
var _drag_pan: bool = false


func _init() -> void:
	rotation.x = -deg_to_rad(PITCH_DEGREES)
	camera = Camera3D.new()
	camera.fov = FOV
	camera.near = 0.2
	camera.far = 4000.0
	add_child(camera)
	_noise.seed = 4
	_noise.frequency = 1.0


## Encuadra una lámina de `extents` centrada en `center` (plano XZ).
func fit_to(center: Vector2, extents: Vector2) -> void:
	bounds_center = center
	bounds_half = extents * 0.5
	var tan_half: float = tan(deg_to_rad(FOV) * 0.5)
	var aspect: float = 16.0 / 9.0
	var d_x: float = extents.x / (2.0 * tan_half * aspect)
	var d_y: float = extents.y * sin(deg_to_rad(PITCH_DEGREES)) / (2.0 * tan_half)
	var fit: float = maxf(d_x, d_y) * 1.08
	min_zoom = 3.5
	max_zoom = maxf(fit * 1.6, 12.0)
	_target_zoom = clampf(fit, min_zoom, max_zoom)
	_zoom = _target_zoom
	_target_pos = Vector3(center.x, 0.0, center.y)
	position = _target_pos
	_apply_zoom()


## Coloca la cámara de golpe (sin interpolar). Para el benchmark.
func focus(center: Vector2, distance: float) -> void:
	_target_zoom = clampf(distance, min_zoom, max_zoom)
	_zoom = _target_zoom
	_target_pos = Vector3(center.x, 0.0, center.y)
	position = _target_pos
	_apply_zoom()


func zoom_distance() -> float:
	return _zoom


func set_zoom(distance: float) -> void:
	_target_zoom = clampf(distance, min_zoom, max_zoom)


## Punto del plano y=0 bajo la posición de pantalla, como (x, z). INF si el rayo no lo toca.
func screen_to_plane(screen_pos: Vector2) -> Vector2:
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, dir)
	if hit == null:
		return Vector2(INF, INF)
	var p: Vector3 = hit
	return Vector2(p.x, p.z)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = clampf(_target_zoom / ZOOM_STEP, min_zoom, max_zoom)
			zoomed.emit()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = clampf(_target_zoom * ZOOM_STEP, min_zoom, max_zoom)
			zoomed.emit()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_drag_pan = mb.pressed
	elif event is InputEventMouseMotion and _drag_pan:
		var mm: InputEventMouseMotion = event
		_pan(Vector2(-mm.relative.x, -mm.relative.y * 1.6) * _zoom * 0.0018)


func _process(delta: float) -> void:
	var move: Vector2 = Vector2(
		Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if move != Vector2.ZERO:
		_pan(move * PAN_SPEED * _zoom * delta)
	var k: float = 1.0 - exp(-SMOOTHING * delta)
	_zoom = lerpf(_zoom, _target_zoom, k)
	position = position.lerp(_target_pos, k)
	_apply_zoom()
	_apply_shake(delta)


func _pan(offset: Vector2) -> void:
	_target_pos.x = clampf(_target_pos.x + offset.x, bounds_center.x - bounds_half.x, bounds_center.x + bounds_half.x)
	_target_pos.z = clampf(_target_pos.z + offset.y, bounds_center.y - bounds_half.y, bounds_center.y + bounds_half.y)


func _apply_zoom() -> void:
	camera.position = Vector3(0.0, 0.0, _zoom)


func _apply_shake(delta: float) -> void:
	if shake_cfg.is_empty() or not Settings.shake_allowed():
		camera.rotation = Vector3.ZERO
		camera.position.x = 0.0
		camera.position.y = 0.0
		return
	_noise_t += delta * Cfg.num(shake_cfg, "shake_noise_speed")
	var shake: float = Juice.trauma * Juice.trauma
	var max_offset: float = Cfg.num(shake_cfg, "shake_max_offset")
	var max_angle: float = deg_to_rad(Cfg.num(shake_cfg, "shake_max_angle_degrees"))
	camera.position.x = max_offset * shake * _noise.get_noise_2d(_noise_t, 0.0)
	camera.position.y = max_offset * shake * _noise.get_noise_2d(_noise_t, 100.0)
	camera.rotation.z = max_angle * shake * _noise.get_noise_2d(_noise_t, 200.0)
