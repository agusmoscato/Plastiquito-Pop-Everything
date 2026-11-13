extends GutTest


func test_each_phase_has_props_and_settings() -> void:
	assert_eq(ScenarioDirector.SETTINGS.size(), 4)
	assert_eq(ScenarioDirector.CAMERA_FACTOR.size(), 4)
	for phase: int in range(1, 5):
		var props: Node3D = ScenarioProps.build(phase, Vector2(10.0, 8.0), Vector2(20.0, 20.0))
		assert_gt(props.get_child_count(), 2, "fase %d tiene objetos" % phase)
		props.free()


func test_camera_moves_away_with_each_phase() -> void:
	for i: int in range(1, 4):
		assert_gt(ScenarioDirector.CAMERA_FACTOR[i], ScenarioDirector.CAMERA_FACTOR[i - 1])


func test_props_scale_with_sheet() -> void:
	assert_eq(ScenarioProps.unit(Vector2(8.0, 8.0)), 1.0)
	assert_almost_eq(ScenarioProps.unit(Vector2(150.0, 130.0)), 7.5, 0.001)


func test_lighting_differs_between_scenarios() -> void:
	var seen: Dictionary = {}
	for s: Dictionary in ScenarioDirector.SETTINGS:
		var c: Color = s["color"]
		seen[c.to_html()] = true
	assert_eq(seen.size(), 4, "cada escenario tiene su propia luz")
