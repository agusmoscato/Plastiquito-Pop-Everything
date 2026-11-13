extends GutTest


func test_format_small_numbers() -> void:
	assert_eq(NumberFormat.pops(0.0), "0")
	assert_eq(NumberFormat.pops(7.9), "7")
	assert_eq(NumberFormat.pops(999.99), "999")
	assert_eq(NumberFormat.pops(-5.0), "-5")


func test_format_thousands_and_rounding_edges() -> void:
	assert_eq(NumberFormat.pops(1000.0, "en"), "1.000K")
	assert_eq(NumberFormat.pops(1234.0, "en"), "1.234K")
	assert_eq(NumberFormat.pops(12340.0, "en"), "12.34K")
	assert_eq(NumberFormat.pops(123456.0, "en"), "123.5K")
	assert_eq(NumberFormat.pops(999949.0, "en"), "999.9K")
	assert_eq(NumberFormat.pops(999950.0, "en"), "1.000M", "999,95K sube a 1,000M")
	assert_eq(NumberFormat.pops(999999.0, "en"), "1.000M")
	assert_eq(NumberFormat.pops(999999999.0, "en"), "1.000B")
	assert_eq(NumberFormat.pops(1.5e12, "en"), "1.500T")


func test_format_decimal_comma_in_spanish() -> void:
	assert_eq(NumberFormat.pops(1234.0, "es"), "1,234K")
	assert_eq(NumberFormat.pops(1.5e6, "es"), "1,500M")
	assert_eq(NumberFormat.decimal(1.5, 1, "es"), "1,5")
	assert_eq(NumberFormat.decimal(1.5, 1, "en"), "1.5")


func test_format_suffix_chain_and_never_scientific() -> void:
	var expected: Array[String] = ["K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]
	for i: int in expected.size():
		var v: float = 1.5 * pow(1000.0, float(i + 1))
		var text: String = NumberFormat.pops(v, "en")
		assert_true(text.ends_with(expected[i]), "%s deberia terminar en %s" % [text, expected[i]])
		assert_false(text.contains("e"), text)
	var huge: String = NumberFormat.pops(1.0e50, "en")
	assert_false(huge.contains("e+") or huge.contains("E"), huge)


func test_format_four_significant_figures() -> void:
	for v: float in [1.0e3, 1.2345e4, 5.6789e5, 9.9999e8, 4.4444e11, 7.0e14]:
		var text: String = NumberFormat.pops(v, "en")
		var digits: int = 0
		for ch: String in text:
			if ch >= "0" and ch <= "9":
				digits += 1
		assert_true(digits <= 4, text)


func test_duration_format() -> void:
	assert_eq(NumberFormat.duration(65.0), "1:05")
	assert_eq(NumberFormat.duration(3725.0), "1:02:05")


func test_pop_value_formula() -> void:
	assert_almost_eq(Economy.pop_value(2.0, 2.0, 10.0, 3.0, 1.5), 2.0 * 4.0 * 10.0 * 3.0 * 1.5, 0.0001)
	assert_almost_eq(Economy.pop_value(1.0, 2.0, 1.0, 1.0, 1.0), 4.0 * Economy.pop_value(1.0, 1.0, 1.0, 1.0, 1.0), 0.0001, "tensa vale 4 veces")


func test_cost_and_bulk_cost() -> void:
	assert_almost_eq(Economy.cost(10.0, 1.2, 0), 10.0, 0.0001)
	assert_almost_eq(Economy.cost(10.0, 1.2, 3), 17.28, 0.001)
	var sum: float = 0.0
	for i: int in 10:
		sum += Economy.cost(10.0, 1.15, 5 + i)
	assert_almost_eq(Economy.bulk_cost(10.0, 1.15, 5, 10), sum, 0.001)
	assert_eq(Economy.max_affordable(10.0, 1.2, 0, 10.0, 99), 1)
	assert_eq(Economy.max_affordable(10.0, 1.2, 0, 9.99, 99), 0)
	assert_eq(Economy.max_affordable(10.0, 1.2, 0, 1000.0, 3), 3, "respeta el tope")


func test_milestones_double_every_25_levels() -> void:
	assert_eq(Economy.milestone_multiplier(24, 25, 2.0), 1.0)
	assert_eq(Economy.milestone_multiplier(25, 25, 2.0), 2.0)
	assert_eq(Economy.milestone_multiplier(50, 25, 2.0), 4.0)


func test_combo_steps_plateau() -> void:
	var rates: Array = [0.0, 2.0, 4.0, 6.0, 8.0]
	var mults: Array = [1.0, 1.5, 2.0, 3.0, 5.0]
	assert_eq(Economy.combo_multiplier(0.0, rates, mults), 1.0)
	assert_eq(Economy.combo_multiplier(1.99, rates, mults), 1.0)
	assert_eq(Economy.combo_multiplier(4.0, rates, mults), 2.0)
	assert_eq(Economy.combo_multiplier(8.0, rates, mults), 5.0)
	assert_eq(Economy.combo_multiplier(80.0, rates, mults), 5.0, "no sube más allá del último escalón")


func test_combo_tracker_sliding_window() -> void:
	var c: ComboTracker = ComboTracker.new()
	c.window_seconds = 2.0
	for i: int in 8:
		c.add(1.0, float(i) * 0.25)
	assert_almost_eq(c.rate(1.75), 4.0, 0.001)
	assert_eq(c.multiplier(1.75), 2.0)
	assert_eq(c.multiplier(10.0), 1.0, "sin golpes vuelve a x1")


func test_prestige_formula() -> void:
	assert_eq(Prestige.pellets_for(0.0, 1.0e5, 0.5), 0)
	assert_eq(Prestige.pellets_for(99999.0, 1.0e5, 0.5), 0)
	assert_eq(Prestige.pellets_for(1.0e5, 1.0e5, 0.5), 1)
	assert_eq(Prestige.pellets_for(4.0e5, 1.0e5, 0.5), 2)
	assert_eq(Prestige.pellets_for(1.0e7, 1.0e5, 0.5), 10)
	assert_almost_eq(Prestige.pops_needed(10, 1.0e5, 0.5), 1.0e7, 1.0)


func test_chain_factor_diminishing_returns() -> void:
	assert_eq(Economy.chain_factor(10, 60, 0.6), 1.0)
	assert_eq(Economy.chain_factor(60, 60, 0.6), 1.0)
	assert_almost_eq(Economy.chain_factor(120, 60, 0.6), pow(0.5, 0.6), 0.0001)
	assert_lt(Economy.chain_factor(1000, 60, 0.6), Economy.chain_factor(500, 60, 0.6))
