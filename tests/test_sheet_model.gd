extends GutTest

var sheet: SheetModel
var _emitted: Array[PackedInt32Array] = []


func before_each() -> void:
	sheet = SheetModel.new()
	sheet.reset(8, 8)
	_emitted.clear()


func _on_changed(indices: PackedInt32Array) -> void:
	_emitted.append(indices)


func test_initial_state() -> void:
	assert_eq(sheet.cell_count(), 64)
	assert_eq(sheet.count_intact(), 64)
	assert_eq(sheet.count_popped(), 0)
	assert_eq(sheet.popped_ratio(), 0.0)
	for i: int in sheet.cell_count():
		assert_eq(sheet.get_pressure(i), 1.0)
		assert_eq(sheet.get_state(i), SheetModel.STATE_INTACT)
		assert_eq(sheet.get_type(i), SheetModel.TYPE_NORMAL)


func test_pop_changes_state_and_counters() -> void:
	assert_true(sheet.pop(5))
	assert_eq(sheet.get_state(5), SheetModel.STATE_POPPED)
	assert_eq(sheet.count_intact(), 63)
	assert_eq(sheet.count_popped(), 1)
	assert_false(sheet.pop(5), "no se puede reventar dos veces")
	assert_eq(sheet.count_popped(), 1)


func test_popped_ratio() -> void:
	for i: int in 16:
		sheet.pop(i)
	assert_almost_eq(sheet.popped_ratio(), 0.25, 0.00001)


func test_tense_state_not_counted_as_intact() -> void:
	sheet.set_state(3, SheetModel.STATE_TENSE)
	assert_eq(sheet.count_intact(), 63)
	assert_eq(sheet.count_tense(), 1)
	sheet.pop(3)
	assert_eq(sheet.count_tense(), 0)
	assert_eq(sheet.count_popped(), 1)


func test_change_signal() -> void:
	sheet.cells_changed.connect(_on_changed)
	sheet.pop(2)
	sheet.set_pressure(4, 1.7)
	sheet.set_type(6, 1)
	sheet.pop_many(PackedInt32Array([10, 11, 2]))
	assert_eq(_emitted.size(), 4)
	assert_eq(_emitted[0], PackedInt32Array([2]))
	assert_eq(_emitted[3], PackedInt32Array([10, 11]), "pop_many solo avisa los que cambiaron")


func test_no_signal_when_nothing_changes() -> void:
	sheet.pop(1)
	sheet.cells_changed.connect(_on_changed)
	assert_false(sheet.pop(1))
	assert_eq(sheet.pop_many(PackedInt32Array([1])), 0)
	assert_eq(_emitted.size(), 0)


func test_dict_roundtrip_identical() -> void:
	sheet.pop(0)
	sheet.set_pressure(7, 1.63)
	sheet.set_state(7, SheetModel.STATE_TENSE)
	sheet.set_type(9, 3)
	sheet.press[12] = 0.37
	var data: Dictionary = sheet.to_dict()
	assert_eq(data["version"], SheetModel.SAVE_VERSION)
	var other: SheetModel = SheetModel.new()
	assert_true(other.from_dict(data))
	assert_eq(other.width, sheet.width)
	assert_eq(other.height, sheet.height)
	assert_eq(other.pressure, sheet.pressure)
	assert_eq(other.state, sheet.state)
	assert_eq(other.type, sheet.type)
	assert_eq(other.press, sheet.press)
	assert_eq(other.count_popped(), 1)
	assert_eq(other.count_tense(), 1)
	assert_eq(other.to_dict(), data)


func test_dict_survives_json() -> void:
	sheet.pop(10)
	var text: String = JSON.stringify(sheet.to_dict())
	var parsed: Variant = JSON.parse_string(text)
	assert_true(parsed is Dictionary)
	var other: SheetModel = SheetModel.new()
	var parsed_dict: Dictionary = parsed
	assert_true(other.from_dict(parsed_dict))
	assert_eq(other.state, sheet.state)
	assert_eq(other.pressure, sheet.pressure)


func test_from_dict_rejects_bad_data() -> void:
	var data: Dictionary = sheet.to_dict()
	data["version"] = 999
	var other: SheetModel = SheetModel.new()
	assert_false(other.from_dict(data))
	assert_string_contains(other.last_error, "versión")
	var missing: Dictionary = sheet.to_dict()
	missing.erase("state")
	assert_false(other.from_dict(missing))
	assert_string_contains(other.last_error, "state")
