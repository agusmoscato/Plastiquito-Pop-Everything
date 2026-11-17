extends ClipBase
## Clip 3: la plancha prepara (el calor infla las burbujas cercanas antes de tocarlas) y una bomba
## dispara la cadena. Usa la plancha REAL: el ToolModel con forma rectangular y su aura de calor
## (los mismos parámetros que en el juego, de data/economy.json) y su modelo 3D en ToolView.

const HEAT_START: float = 1.0
const HEAT_END: float = 6.5
const BOMB_AT: float = 8.4
const IRON_HALF: float = 4.0 ## mitad del largo de la plancha en el mundo (como "radio" de la herramienta)

var _bomb_cell: int = -1
var _bombed: bool = false


func _init() -> void:
	duration = 15.0


func setup() -> void:
	make_sheet(50, 50, 3)
	precharge(1.08, 1.22, center(), 0.0, 1.0) # el calor real tope es 1,4: se arranca un poco más inflado
	_configure_iron()
	_bomb_cell = grid.world_to_cell(center())
	sheet.type[_bomb_cell] = ChainSolver.TYPE_BOMB
	world.specials_view.bind(sheet, grid)
	tool_view.set_tool("iron", IRON_HALF, 0, 0.6)
	tool_view.snap_to(_iron_position(HEAT_START))
	cam(center() + Vector2(0.0, 6.0), 30.0)


## La plancha del juego: forma rectangular, calor con su tasa, tope y alcance reales.
func _configure_iron() -> void:
	var eco: Dictionary = world.db.economy
	tool_model.shape = ToolModel.SHAPE_RECT
	tool_model.radius = IRON_HALF
	tool_model.heat_rate = Cfg.num(eco, "iron_heat_rate")
	tool_model.heat_cap = Cfg.num(eco, "iron_heat_cap")
	tool_model.heat_reach = Cfg.num(eco, "iron_heat_reach")


func _iron_position(time: float) -> Vector2:
	var k: float = ease_io((time - HEAT_START) / (HEAT_END - HEAT_START))
	var c: Vector2 = center()
	return Vector2(c.x - 9.0 + 18.0 * k, c.y + sin(k * PI * 3.0) * 4.0)


func script_step(time: float, delta: float) -> void:
	var active: bool = time > HEAT_START and time < HEAT_END
	var pos: Vector2 = _iron_position(clampf(time, HEAT_START, HEAT_END))
	tool_view.visible = time < BOMB_AT
	tool_view.set_cursor(pos)
	tool_view.set_drag_direction(pos - _iron_position(clampf(time - delta, HEAT_START, HEAT_END)))
	if active:
		tool_model.apply_heat(pos, delta) # avisa a la vista de las burbujas que se inflan
	if time > BOMB_AT and not _bombed:
		_bombed = true
		chain.pop_now(_bomb_cell)
		Juice.add_pop_trauma(30)
	var k: float = ease_io(time / duration)
	cam(center() + Vector2(0.0, lerpf(6.0, 0.0, k)), lerpf(30.0, 48.0, k))
