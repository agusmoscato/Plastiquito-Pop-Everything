extends ClipBase
## Clip 4: transición Piso -> Galpón. La lámina del Piso se arruga y se enrolla, entra la del
## Galpón (más grande), y el escenario, la luz y la cámara cambian juntos durante 4 s.

const CRUMPLE_AT: float = 3.0
const SWAP_AT: float = 4.6
const TRANSITION_S: float = 4.0

var _swapped: bool = false


func _init() -> void:
	duration = 13.0


func setup() -> void:
	make_sheet(40, 40, 2)
	precharge(1.2, 1.5, center(), 8.0, 1.75)
	tool_model.shape = "circle"
	tool_model.radius = 2.0
	tool_model.force_per_second = 3.5
	tool_model.air_share = 0.6
	tool_model.center_falloff = 1.5
	tool_model.drag_entry_fraction = 0.6
	tool_view.set_tool("palm", 2.0, 0, 0.5)
	tool_view.snap_to(center())
	cam(center(), 22.0)


func script_step(time: float, delta: float) -> void:
	var c: Vector2 = center()
	if time < CRUMPLE_AT:
		var path: Vector2 = c + Vector2(sin(time * 1.3) * 7.0, cos(time * 0.9) * 5.0)
		drive_tool(path, true, delta)
		cam(c, lerpf(22.0, 26.0, time / CRUMPLE_AT))
		return
	if time < SWAP_AT:
		tool_view.set_pressing(false)
		var k: float = (time - CRUMPLE_AT) / (SWAP_AT - CRUMPLE_AT)
		world.sheet_view.set_recycle_progress(minf(k * 1.6, 1.0), lerpf(-1.5, world.sheet_view.extents().y + 2.0, ease_io(k)))
		cam(c, 26.0)
		return
	if not _swapped:
		_swapped = true
		world.sheet_view.clear_recycle_effect()
		tool_view.visible = false
		make_sheet(80, 80, 2)
		precharge(1.15, 1.45, center(), 12.0, 1.8)
		world.sheet_view.begin_roll_in()
		world.transition_to_phase(3, TRANSITION_S)
		chain.pop_now(grid.world_to_cell(center()))
	# La cámara la lleva el rig (fit_to animado dentro de transition_to_phase).
