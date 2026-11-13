extends ClipBase
## Clip 3: la plancha prepara (el calor infla las burbujas cercanas antes de tocarlas) y una bomba
## dispara la cadena.
##
## PUNTO DE ENCHUFE DE LA PLANCHA: hasta que exista la plancha real en la sim, el calor se simula
## a mano en _apply_heat() subiendo presiones. Para usar la herramienta real, reemplazar
## _apply_heat() + _iron por el ToolModel de la plancha (forma rect) y su aura de calor.

const HEAT_START: float = 1.0
const HEAT_END: float = 6.5
const BOMB_AT: float = 8.4

var _iron: Node3D
var _bomb_cell: int = -1
var _bombed: bool = false


func _init() -> void:
	duration = 15.0


func setup() -> void:
	make_sheet(50, 50, 3)
	precharge(1.0, 1.12, center(), 0.0, 1.0)
	_iron = _build_iron_proxy()
	add_child(_iron)
	tool_view.visible = false
	_bomb_cell = grid.world_to_cell(center())
	sheet.type[_bomb_cell] = ChainSolver.TYPE_BOMB
	world.specials_view.bind(sheet, grid)
	cam(center() + Vector2(0.0, 6.0), 30.0)


## Plancha de primitivas: base metálica, asa negra y un resplandor naranja debajo.
func _build_iron_proxy() -> Node3D:
	var root: Node3D = Node3D.new()
	var base: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(10.0, 0.9, 6.0)
	base.mesh = bm
	base.material_override = ToolMeshes.material(Color("#C9CDD1"), 0.9)
	base.position = Vector3(0.0, 0.8, 0.0)
	root.add_child(base)
	var handle: MeshInstance3D = MeshInstance3D.new()
	var hm: BoxMesh = BoxMesh.new()
	hm.size = Vector3(5.0, 0.7, 1.0)
	handle.mesh = hm
	handle.material_override = ToolMeshes.material(Color("#26221F"), 0.0)
	handle.position = Vector3(0.0, 2.3, 0.0)
	root.add_child(handle)
	var glow: MeshInstance3D = MeshInstance3D.new()
	var gm: BoxMesh = BoxMesh.new()
	gm.size = Vector3(11.5, 0.05, 7.5)
	glow.mesh = gm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.45, 0.15, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.1)
	mat.emission_energy_multiplier = 1.4
	glow.material_override = mat
	glow.position = Vector3(0.0, 0.1, 0.0)
	root.add_child(glow)
	return root


func _iron_position(time: float) -> Vector2:
	var k: float = ease_io((time - HEAT_START) / (HEAT_END - HEAT_START))
	var c: Vector2 = center()
	return Vector2(c.x - 9.0 + 18.0 * k, c.y + sin(k * PI * 3.0) * 4.0)


func script_step(time: float, delta: float) -> void:
	var active: bool = time > HEAT_START and time < HEAT_END
	var pos: Vector2 = _iron_position(clampf(time, HEAT_START, HEAT_END))
	_iron.position = Vector3(pos.x, 0.0, pos.y) + Vector3(0.0, 0.6 * (1.0 if active else 4.0), 0.0)
	if active:
		_apply_heat(pos, Vector2(8.0, 5.5), 0.5, delta)
	if time > BOMB_AT and not _bombed:
		_bombed = true
		_iron.visible = false
		chain.pop_now(_bomb_cell)
		Juice.add_pop_trauma(30)
	var k: float = ease_io(time / duration)
	cam(center() + Vector2(0.0, lerpf(6.0, 0.0, k)), lerpf(30.0, 48.0, k))


## Calor de la plancha simulado: sube la presión en un rectángulo alrededor de `pos`
## (aura mayor que la propia plancha). No conserva aire a propósito: es un clip.
func _apply_heat(pos: Vector2, half: Vector2, rate: float, delta: float) -> void:
	var changed: PackedInt32Array = PackedInt32Array()
	for idx: int in grid.cells_in_rect(pos, half * 2.0, 0.0):
		if sheet.state[idx] == SheetModel.STATE_POPPED:
			continue
		if sheet.pressure[idx] < 1.82:
			sheet.add_pressure_quiet(idx, rate * delta)
			changed.append(idx)
	sheet.notify_changed(changed)
