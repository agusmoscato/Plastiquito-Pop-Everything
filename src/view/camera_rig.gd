class_name CameraRig
extends Node3D
## Cámara en perspectiva inclinada (~55°). Zoom con la rueda entre límites, movimiento
## suave por interpolación y sacudida por trauma. Sin rotación libre.

signal zoomed
signal intro_finished ## terminó el plano de presentación (o se salteó)

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
var _smooth: float = SMOOTHING
var _pull_left: float = 0.0
## Fracción del ancho visible que se desplaza el encuadre hacia la izquierda (la tienda tapa la derecha).
var screen_shift: float = 0.0
## Cámara de trabajo (DESIGN 5): la lámina ENTERA llena `sheet_fill` del ancho del área de juego (la zona
## a la izquierda de la hoja de pedidos) mientras sus burbujas midan `min_bubble_px` o más. Cuando ya no
## entra, la cámara se acerca a `min_bubble_px` y sigue a la herramienta. La transición de reciclado
## muestra la lámina entera y con la rueda se ve todo. Los clips no la usan (work_mode en false).
var work_mode: bool = false
var sheet_fill: float = 0.58
var play_area: float = 0.71 ## fracción del ancho de pantalla que queda a la izquierda de la hoja de pedidos
var min_bubble_px: float = 10.0
var _work_zoom: float = 0.0
var _return_in: float = -1.0 ## segundos hasta volver de la vista entera al zoom de trabajo
var _following: bool = false
var _follow_needed: bool = false
const FOLLOW_INNER: float = 0.35 ## el cursor puede moverse libre en el 35 % central; afuera, la cámara lo sigue
const FOLLOW_SPEED: float = 3.5
const HOLD_WHOLE_S: float = 1.2 ## después de la transición, cuánto se sostiene la lámina entera
var _intro_t: float = -1.0 ## plano de presentación en curso (segundos), -1 si no hay
var _intro_hold: float = 0.9
var _intro_move: float = 2.4
var _intro_pos: Vector3 = Vector3.ZERO
var _intro_zoom: float = 20.0
var _user_zoom: float = -1.0 ## zoom elegido con la rueda (se conserva al recargar la lámina); -1 = el de trabajo
var _last_extents: Vector2 = Vector2.ZERO


func _init() -> void:
	rotation.x = -deg_to_rad(PITCH_DEGREES)
	camera = Camera3D.new()
	camera.fov = FOV
	# Efecto maqueta: lo que queda más lejos que la lámina se desenfoca suave (la distancia se
	# ajusta con el zoom en _apply_zoom).
	var attrs: CameraAttributesPractical = CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_amount = 0.06
	camera.attributes = attrs
	camera.near = 0.2
	camera.far = 4000.0
	add_child(camera)
	_noise.seed = 4
	_noise.frequency = 1.0


## Encuadra una lámina de `extents` centrada en `center` (plano XZ).
func fit_to(center: Vector2, extents: Vector2, animate_seconds: float = 0.0) -> void:
	if animate_seconds <= 0.0 and work_mode and extents == _last_extents and _user_zoom > 0.0:
		_keep_user_view(center, extents) # lámina nueva del mismo tamaño: la cámara queda donde estaba
		return
	if extents != _last_extents:
		_user_zoom = -1.0 # lámina de otro tamaño: vuelve al encuadre de trabajo
	_last_extents = extents
	bounds_center = center
	bounds_half = extents * 0.5
	var tan_half: float = tan(deg_to_rad(FOV) * 0.5)
	var aspect: float = 16.0 / 9.0
	if is_inside_tree():
		var vs: Vector2 = get_viewport().get_visible_rect().size
		aspect = vs.x / maxf(vs.y, 1.0) # horizontal, vertical (clips para shorts) o cualquier ventana
	var fit: float = fit_distance(extents, aspect)
	min_zoom = 3.5
	var plan: Vector2 = work_plan(extents, aspect, play_area, sheet_fill, min_bubble_px)
	_work_zoom = plan.x if work_mode else fit
	var follows: bool = plan.y > 0.5
	max_zoom = maxf(maxf(fit, _work_zoom) * 1.6, 12.0) # con la rueda siempre se puede ver todo
	var start_zoom: float = fit if animate_seconds > 0.0 else _work_zoom
	_target_zoom = clampf(start_zoom, min_zoom, max_zoom)
	_return_in = animate_seconds + HOLD_WHOLE_S if (work_mode and animate_seconds > 0.0) else -1.0
	_follow_needed = work_mode and follows
	_following = _follow_needed and _return_in < 0.0
	var visible_w: float = 2.0 * _target_zoom * tan_half * aspect
	_target_pos = Vector3(center.x + screen_shift * visible_w, 0.0, center.y)
	if animate_seconds > 0.0:
		_smooth = 4.0 / animate_seconds # alejarse suave (clip de reciclado)
		_pull_left = animate_seconds
		_zoom = minf(_zoom, _target_zoom * 0.5) # arranca cerca y se aleja
		position = _target_pos
		return
	_zoom = _target_zoom
	position = _target_pos
	_apply_zoom()


func _keep_user_view(center: Vector2, extents: Vector2) -> void:
	bounds_center = center
	bounds_half = extents * 0.5
	_target_zoom = clampf(_user_zoom, min_zoom, max_zoom)
	_update_following()


## Sigue a la herramienta si la lámina no entra, o si el jugador se acercó con la rueda.
func _update_following() -> void:
	if not work_mode or _return_in >= 0.0:
		return
	_following = _follow_needed or _target_zoom < _work_zoom * 0.95


func is_following() -> bool:
	return _following


# --- Cuentas de cámara sin nodos (para ubicar la utilería y para los tests) -------------------------

## Transformación de la cámara mirando a `target` desde `zoom` de distancia (la misma que arma el rig).
static func view_transform(target: Vector3, zoom: float) -> Transform3D:
	var rig: Transform3D = Transform3D(Basis(Vector3.RIGHT, -deg_to_rad(PITCH_DEGREES)), target)
	return rig * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, zoom))


## Punto del mundo en la pantalla (x, y en píxeles; z = profundidad, <= 0 si queda detrás).
static func project(cam: Transform3D, p: Vector3, screen: Vector2) -> Vector3:
	var local: Vector3 = cam.affine_inverse() * p
	var depth: float = -local.z
	if depth <= 0.001:
		return Vector3(0.0, 0.0, -1.0)
	var f: float = 1.0 / tan(deg_to_rad(FOV) * 0.5)
	var aspect: float = screen.x / screen.y
	var nx: float = local.x / depth * f / aspect
	var ny: float = local.y / depth * f
	return Vector3((nx * 0.5 + 0.5) * screen.x, (0.5 - ny * 0.5) * screen.y, depth)


## Punto del plano y = 0 que se ve en `pixel`.
static func unproject_to_plane(cam: Transform3D, pixel: Vector2, screen: Vector2) -> Vector2:
	var f: float = 1.0 / tan(deg_to_rad(FOV) * 0.5)
	var aspect: float = screen.x / screen.y
	var nx: float = (pixel.x / screen.x - 0.5) * 2.0
	var ny: float = (0.5 - pixel.y / screen.y) * 2.0
	var dir_local: Vector3 = Vector3(nx * aspect / f, ny / f, -1.0)
	var dir: Vector3 = (cam.basis * dir_local).normalized()
	var o: Vector3 = cam.origin
	if absf(dir.y) < 0.0001:
		return Vector2(INF, INF)
	var t: float = -o.y / dir.y
	var hit: Vector3 = o + dir * t
	return Vector2(hit.x, hit.z)


## Cámara de trabajo al entrar a una lámina (como fit_to en modo trabajo): (objetivo, distancia).
static func work_view(c: Vector2, e: Vector2, screen: Vector2, play: float, fill: float, min_px: float, shift: float) -> Transform3D:
	var aspect: float = screen.x / screen.y
	var plan: Vector2 = work_plan(e, aspect, play, fill, min_px)
	var tan_half: float = tan(deg_to_rad(FOV) * 0.5)
	var visible_w: float = 2.0 * plan.x * tan_half * aspect
	return view_transform(Vector3(c.x + shift * visible_w, 0.0, c.y), plan.x)


## Distancia que encuadra toda la lámina (con margen).
static func fit_distance(extents: Vector2, aspect: float) -> float:
	var tan_half: float = tan(deg_to_rad(FOV) * 0.5)
	var d_x: float = extents.x / (2.0 * tan_half * aspect)
	var d_y: float = extents.y * sin(deg_to_rad(PITCH_DEGREES)) / (2.0 * tan_half)
	return maxf(d_x, d_y) * 1.3


## Plan de la cámara de trabajo: (distancia, 1 si tiene que seguir a la herramienta). La lámina entera
## llena `fill` del ancho del área de juego (y entra a lo alto); si así las burbujas quedan por debajo de
## `min_px`, se acerca a `min_px` y sigue a la herramienta.
static func work_plan(extents: Vector2, aspect: float, play: float, fill: float, min_px: float) -> Vector2:
	var tan_half: float = tan(deg_to_rad(FOV) * 0.5)
	var d_w: float = extents.x / (fill * play * 2.0 * tan_half * aspect)
	var d_h: float = extents.y * sin(deg_to_rad(PITCH_DEGREES)) / (2.0 * tan_half) * 1.15
	var d: float = maxf(d_w, d_h)
	if bubble_px_at(d) >= min_px:
		return Vector2(d, 0.0)
	return Vector2(work_distance(min_px), 1.0)


static func bubble_px_at(distance: float) -> float:
	return 900.0 / (2.0 * distance * tan(deg_to_rad(FOV) * 0.5))


## Distancia a la que una burbuja (1 unidad) mide `px` en una pantalla de 900 px de alto.
static func work_distance(px: float) -> float:
	var view_h: float = 900.0 / maxf(px, 1.0)
	return view_h / (2.0 * tan(deg_to_rad(FOV) * 0.5))


## Sigue a la herramienta: si el cursor sale del 35 % central de lo visible, la cámara se corre
## suave para traerlo de vuelta (sin salir de la lámina). Solo con la cámara de trabajo.
func follow(cursor: Vector2, valid: bool, delta: float) -> void:
	if not _following or not valid or not cursor.is_finite():
		return
	var tan_half: float = tan(deg_to_rad(FOV) * 0.5)
	var half_h: float = _zoom * tan_half / sin(deg_to_rad(PITCH_DEGREES)) # alto visible sobre el plano
	var half_w: float = _zoom * tan_half * 16.0 / 9.0 * (1.0 - screen_shift * 2.0)
	var center: Vector2 = Vector2(_target_pos.x - screen_shift * 2.0 * half_w, _target_pos.z)
	var off: Vector2 = cursor - center
	var lim: Vector2 = Vector2(half_w, half_h) * FOLLOW_INNER
	var push: Vector2 = Vector2(signf(off.x) * maxf(absf(off.x) - lim.x, 0.0), signf(off.y) * maxf(absf(off.y) - lim.y, 0.0))
	if push != Vector2.ZERO:
		_pan(push * minf(1.0, FOLLOW_SPEED * delta))


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
			zoom_by(1.0 / ZOOM_STEP)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(ZOOM_STEP)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT:
			_drag_pan = mb.pressed
	elif event is InputEventMouseMotion and _drag_pan:
		var mm: InputEventMouseMotion = event
		_pan(Vector2(-mm.relative.x, -mm.relative.y * 1.6) * _zoom * 0.0018)


## Zoom con la rueda: el jugador elige y la cámara lo recuerda entre láminas.
func zoom_by(factor: float) -> void:
	_target_zoom = clampf(_target_zoom * factor, min_zoom, max_zoom)
	_user_zoom = _target_zoom
	if _return_in > 0.0: # tocó la rueda durante la vista entera: manda el jugador
		_return_in = -1.0
		_smooth = SMOOTHING
	_update_following()
	zoomed.emit()


## Plano de presentación: la cámara arranca en `target` a `zoom` (el escenario entero), espera `hold` s y
## en `move` s baja con una curva suave (zoom en escala logarítmica, aceleración y frenado) a la cámara
## de trabajo que dejó fit_to.
func play_intro(target: Vector3, zoom: float, hold: float, move: float) -> void:
	_intro_pos = target
	_intro_zoom = maxf(zoom, 0.5)
	_intro_hold = maxf(hold, 0.0)
	_intro_move = maxf(move, 0.1)
	_intro_t = 0.0
	position = target
	_zoom = _intro_zoom
	_apply_zoom()


func in_intro() -> bool:
	return _intro_t >= 0.0


func skip_intro() -> void:
	if in_intro():
		_intro_t = _intro_hold + _intro_move


func _step_intro(delta: float) -> void:
	_intro_t += delta
	var k: float = clampf((_intro_t - _intro_hold) / _intro_move, 0.0, 1.0)
	k = k * k * k * (k * (k * 6.0 - 15.0) + 10.0) # arranca y frena suave
	var lift: float = sin(k * PI) * 0.06 # una curva: se eleva un poco a mitad de camino
	_zoom = exp(lerpf(log(_intro_zoom), log(maxf(_target_zoom, 0.5)), k)) * (1.0 + lift)
	position = _intro_pos.lerp(_target_pos, k)
	_apply_zoom()
	if _intro_t >= _intro_hold + _intro_move:
		_intro_t = -1.0
		_zoom = _target_zoom
		position = _target_pos
		intro_finished.emit()


func _process(delta: float) -> void:
	if in_intro():
		_step_intro(delta)
		_apply_shake(delta)
		return
	var move: Vector2 = Vector2(
		Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	move += Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if move != Vector2.ZERO:
		_pan(move * PAN_SPEED * _zoom * delta)
	if _pull_left > 0.0:
		_pull_left -= delta
		if _pull_left <= 0.0:
			_smooth = SMOOTHING
	if _return_in > 0.0: # la transición mostró la lámina entera: vuelve al zoom de trabajo
		_return_in -= delta
		if _return_in <= 0.0:
			_target_zoom = clampf(_work_zoom, min_zoom, max_zoom)
			_smooth = 2.5
			_pull_left = 1.2
			_following = _follow_needed
			_return_in = -1.0
	var k: float = 1.0 - exp(-_smooth * delta)
	_zoom = lerpf(_zoom, _target_zoom, k)
	position = position.lerp(_target_pos, k)
	_apply_zoom()
	_apply_shake(delta)


func _pan(offset: Vector2) -> void:
	_target_pos.x = clampf(_target_pos.x + offset.x, bounds_center.x - bounds_half.x, bounds_center.x + bounds_half.x)
	_target_pos.z = clampf(_target_pos.z + offset.y, bounds_center.y - bounds_half.y, bounds_center.y + bounds_half.y)


func _apply_zoom() -> void:
	camera.position = Vector3(0.0, 0.0, _zoom)
	var attrs: CameraAttributesPractical = camera.attributes as CameraAttributesPractical
	if attrs != null:
		attrs.dof_blur_far_distance = _zoom * 1.35
		attrs.dof_blur_far_transition = _zoom * 0.9


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
