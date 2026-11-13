extends GutTest


func test_roundtrip_within_quantization() -> void:
	for p: float in [0.0, 0.4, 1.0, 1.5, 2.0]:
		var c: Color = StatePacker.pack(p, 0.5, 0.25, 3)
		assert_almost_eq(StatePacker.pressure_of(c), p, 2.0 / 255.0 + 0.001)
		assert_almost_eq(StatePacker.squash_of(c), 0.5, 1.0 / 255.0 + 0.001)
		assert_almost_eq(StatePacker.pop_of(c), 0.25, 1.0 / 255.0 + 0.001)
		assert_eq(StatePacker.type_of(c), 3)


func test_types_distinct_and_clamped() -> void:
	for t: int in 5:
		assert_eq(StatePacker.type_of(StatePacker.pack(1.0, 0.0, 0.0, t)), t)
	assert_eq(StatePacker.type_of(StatePacker.pack(1.0, 0.0, 0.0, 99)), 7)


func test_values_clamped() -> void:
	var c: Color = StatePacker.pack(9.0, -1.0, 5.0, 0)
	assert_almost_eq(StatePacker.pressure_of(c), 2.0, 0.01)
	assert_eq(StatePacker.squash_of(c), 0.0)
	assert_eq(StatePacker.pop_of(c), 1.0)


func test_pack_to_matches_pack() -> void:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(8)
	StatePacker.pack_to(bytes, 4, 1.37, 0.6, 0.9, 2)
	var c: Color = StatePacker.pack(1.37, 0.6, 0.9, 2)
	assert_eq(bytes[4], roundi(c.r * 255.0))
	assert_eq(bytes[5], roundi(c.g * 255.0))
	assert_eq(bytes[6], roundi(c.b * 255.0))
	assert_eq(bytes[7], roundi(c.a * 255.0))
	assert_eq(bytes[0], 0, "no toca otros píxeles")


func test_default_pixel_is_intact_normal() -> void:
	var c: Color = StatePacker.default_pixel()
	assert_almost_eq(StatePacker.pressure_of(c), 1.0, 0.01)
	assert_eq(StatePacker.pop_of(c), 0.0)
	assert_eq(StatePacker.type_of(c), 0)
