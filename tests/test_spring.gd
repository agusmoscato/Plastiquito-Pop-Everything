extends GutTest
## Bug de la Fase 3b: con frames largos (render por software en CI, primer frame) el resorte de la
## herramienta divergía y Godot llenaba el log con "!v.is_finite()" en instance_set_transform.

const K: float = 260.0
const C: float = 16.0


func _old_explicit_euler(s: Vector2, dt: float) -> Vector2:
	var v: float = s.y + (-K * s.x - C * s.y) * dt
	return Vector2(s.x + v * dt, v)


func test_old_integration_diverged_with_long_frames() -> void:
	var s: Vector2 = Vector2(0.0, 3.5)
	for i: int in 400:
		s = _old_explicit_euler(s, 0.5)
	assert_false(s.is_finite() and absf(s.x) < 1.0e6, "reproduce el bug: el método viejo explota")


func test_spring_stays_finite_with_long_frames() -> void:
	var s: Vector2 = Vector2(0.0, 3.5)
	for i: int in 400:
		s = SpringMath.step(s, K, C, 0.5)
		assert_true(s.is_finite())
	assert_lt(absf(s.x), 0.01, "con frames largos igual vuelve al reposo")


func test_spring_settles_at_normal_framerate() -> void:
	var s: Vector2 = Vector2(0.0, 3.5)
	var peak: float = 0.0
	for i: int in 120:
		s = SpringMath.step(s, K, C, 1.0 / 60.0)
		peak = maxf(peak, absf(s.x))
	assert_gt(peak, 0.05, "el rebote se ve")
	assert_lt(absf(s.x), 0.01, "en 2 s se calma")


func test_spring_recovers_from_bad_input() -> void:
	assert_eq(SpringMath.step(Vector2(NAN, 0.0), K, C, 0.016), Vector2.ZERO)
	assert_eq(SpringMath.step(Vector2(INF, 1.0), K, C, 0.016), Vector2.ZERO)
	assert_true(SpringMath.step(Vector2(0.1, 0.0), K, C, INF).is_finite())


func test_tool_view_position_stays_finite_with_long_frames() -> void:
	var tv: ToolView = ToolView.new()
	tv.set_cursor(Vector2(3.0, 2.0))
	tv.set_pressing(true)
	for i: int in 200:
		if i % 7 == 0:
			tv.bounce(4.0)
		tv._process(0.6)
		assert_true(tv.position.is_finite(), "frame %d" % i)
	tv.free()
