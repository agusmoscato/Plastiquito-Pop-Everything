class_name AutomationView
extends Node3D
## Se ve siempre: las Manitos (dedos fantasma semitransparentes que tocan solos) y el rodillo
## automático recorriendo la lámina. Solo lee el estado de GameSim.

const HAND_SEPARATION: float = 2.4 ## ~ancho de una manito en el mundo (palma de 8,5 cm x escala)

var sim: GameSim
var night: float = 0.0 ## turno noche (0..1): las manitos se mueven más rápido

var _hands: Array[Node3D] = []
var _dip: PackedFloat32Array = PackedFloat32Array()
var _last_target: PackedInt32Array = PackedInt32Array()
var _roller: Node3D
var _roller_key: String = ""


func bind(p_sim: GameSim) -> void:
	sim = p_sim


func _process(delta: float) -> void:
	if sim == null or sim.hands == null:
		return
	_sync_hands()
	_move_hands(delta)
	_sync_roller()


func _sync_hands() -> void:
	var want: int = mini(sim.hands.count, 12)
	while _hands.size() < want:
		var h: Node3D = ToolMeshes.build("hands", 0.0, 0)
		add_child(h)
		_hands.append(h)
		_dip.append(0.0)
		_last_target.append(-1)
	while _hands.size() > want:
		var gone: Node3D = _hands.pop_back()
		gone.queue_free()
		_dip.resize(_hands.size())
		_last_target.resize(_hands.size())
	for i: int in _hands.size():
		_hands[i].visible = true


func _move_hands(delta: float) -> void:
	var goals: PackedVector2Array = PackedVector2Array()
	goals.resize(_hands.size())
	var active: PackedByteArray = PackedByteArray()
	active.resize(_hands.size())
	for i: int in _hands.size():
		var t: int = sim.hands.targets[i] if i < sim.hands.targets.size() else -1
		if t < 0:
			_hands[i].visible = false
			continue
		if t != _last_target[i]:
			_last_target[i] = t
			_dip[i] = 1.0 # toca: baja y vuelve
		_dip[i] = maxf(0.0, _dip[i] - delta * (5.0 + 2.5 * night))
		goals[i] = sim.grid.cell_to_world(t)
		active[i] = 1
	goals = separate(goals, active, HAND_SEPARATION)
	for i: int in _hands.size():
		if active[i] == 0:
			continue
		var h: Node3D = _hands[i]
		h.position = h.position.lerp(Vector3(goals[i].x, 1.1 - 0.8 * _dip[i], goals[i].y), 1.0 - exp(-14.0 * delta))
		h.rotation.y = 0.0 # todas igual orientadas: nunca se cruzan


## Separa en el plano las manitos que quedarían encimadas (solo lo visual; el toque ya ocurrió en la sim).
static func separate(points: PackedVector2Array, active: PackedByteArray, min_dist: float) -> PackedVector2Array:
	var out: PackedVector2Array = points.duplicate()
	for _pass: int in 6: # al alejar una de otra se puede acercar a una tercera: se repite
		var moved: bool = false
		for i: int in out.size():
			if active[i] == 0:
				continue
			for j: int in range(i + 1, out.size()):
				if active[j] == 0:
					continue
				var d: Vector2 = out[j] - out[i]
				var dist: float = d.length()
				if dist >= min_dist - 0.0001:
					continue
				var dir: Vector2 = d / dist if dist > 0.0001 else Vector2.RIGHT
				out[j] = out[i] + dir * min_dist
				moved = true
		if not moved:
			break
	return out


func _sync_roller() -> void:
	if not sim.roller.enabled:
		if _roller != null:
			_roller.visible = false
		return
	var key: String = "%.2f" % sim.roller.half_width
	if _roller == null or key != _roller_key:
		if _roller != null:
			_roller.queue_free()
		_roller = ToolMeshes.build("auto_roller", sim.roller.half_width * sim.grid.spacing, 1)
		_roller.rotation.y = PI * 0.5
		add_child(_roller)
		_roller_key = key
	_roller.visible = true
	_roller.position = Vector3(sim.roller.pos.x, 0.35, sim.roller.pos.y)
