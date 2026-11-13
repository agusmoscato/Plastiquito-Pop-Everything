extends GutTest

var logic: PopAudioLogic
var rng: RandomNumberGenerator


func before_each() -> void:
	logic = PopAudioLogic.new(4)
	rng = RandomNumberGenerator.new()
	rng.seed = 11
	logic.set_samples("small", ["a.ogg", "b.ogg", "c.ogg"] as Array[String])
	logic.set_samples("large", ["L.ogg"] as Array[String])
	logic.set_samples("tense", ["T.ogg"] as Array[String])


func test_pick_sample_stays_in_category() -> void:
	var seen: Dictionary = {}
	for k: int in 100:
		seen[logic.pick_sample("small", rng)] = true
	assert_eq(seen.keys().size(), 3, "usa todas las muestras de la categoría")
	for key: Variant in seen:
		assert_true(["a.ogg", "b.ogg", "c.ogg"].has(key))
	assert_eq(logic.pick_sample("nada", rng), "")
	assert_eq(logic.pick_sample("squish", rng), "")


func test_pick_category_by_pressure() -> void:
	assert_eq(logic.pick_category(1.5, rng), "tense")
	assert_eq(logic.pick_category(2.0, rng), "tense")
	logic.large_chance = 0.0
	assert_eq(logic.pick_category(1.0, rng), "small")
	logic.large_chance = 1.0
	assert_eq(logic.pick_category(1.0, rng), "large")


func test_pick_category_falls_back_to_small() -> void:
	logic.categories.erase("large")
	logic.categories.erase("tense")
	logic.large_chance = 1.0
	assert_eq(logic.pick_category(1.0, rng), "small")
	assert_eq(logic.pick_category(1.9, rng), "small")


func test_voice_limit_and_stealing_oldest() -> void:
	var v: Array[int] = []
	for i: int in 4:
		v.append(logic.acquire_voice(float(i)))
	assert_eq(v, [0, 1, 2, 3] as Array[int])
	assert_eq(logic.active_voices(), 4)
	assert_eq(logic.acquire_voice(10.0), 0, "roba la más vieja (t=0)")
	assert_eq(logic.acquire_voice(11.0), 1, "ahora la más vieja es la 1")
	assert_eq(logic.active_voices(), 4, "nunca pasa del límite")


func test_released_voice_is_reused_before_stealing() -> void:
	for i: int in 4:
		logic.acquire_voice(float(i))
	logic.release_voice(2)
	assert_eq(logic.active_voices(), 3)
	assert_eq(logic.acquire_voice(5.0), 2)


func test_streak_pitch_grows_and_caps() -> void:
	logic.streak_pitch_per_pop = 0.05
	logic.streak_pitch_max = 0.5
	assert_eq(logic.streak_pitch(), 1.0)
	logic.register_pops(1, 0.0)
	logic.register_pops(1, 0.1)
	assert_almost_eq(logic.streak_pitch(), 1.1, 0.0001)
	logic.register_pops(100, 0.2)
	assert_almost_eq(logic.streak_pitch(), 1.5, 0.0001)


func test_streak_resets_after_pause() -> void:
	logic.streak_reset_seconds = 0.6
	logic.register_pops(5, 0.0)
	logic.update_streak(0.5)
	assert_eq(logic.streak, 5)
	logic.update_streak(0.7)
	assert_eq(logic.streak, 0)
	logic.register_pops(3, 1.0)
	logic.register_pops(1, 2.0)
	assert_eq(logic.streak, 1, "register_pops también reinicia si hubo pausa")


func test_random_pitch_within_variation() -> void:
	logic.pitch_variation = 0.08
	for k: int in 200:
		var p: float = logic.pop_pitch(rng)
		assert_true(p >= 0.92 and p <= 1.08)


func test_crackle_threshold() -> void:
	logic.crackle_threshold = 30
	assert_false(logic.should_crackle(30))
	assert_true(logic.should_crackle(31))
	assert_false(logic.should_crackle(0))


func test_crackle_volume_follows_rate_and_decays() -> void:
	logic.crackle_rate_for_full_volume = 800.0
	logic.crackle_smoothing_per_second = 5.0
	assert_eq(logic.crackle_volume(), 0.0)
	var v: float = logic.update_crackle(100, 0.016)
	assert_eq(v, 1.0, "100 pops en 16 ms = 6250/s satura")
	var prev: float = v
	for k: int in 10:
		var now: float = logic.update_crackle(0, 0.1)
		assert_true(now <= prev)
		prev = now
	assert_lt(prev, 0.1)


func test_crackle_low_rate_gives_low_volume() -> void:
	var v: float = 0.0
	for k: int in 120:
		v = logic.update_crackle(2, 0.016) # ~125 pops/s
	assert_almost_eq(v, 125.0 / 800.0, 0.03)
