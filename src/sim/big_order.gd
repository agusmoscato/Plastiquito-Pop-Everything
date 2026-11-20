class_name BigOrder
extends RefCounted
## Pedido grande de cada escenario (sección 4 de la 0.7.0): un objetivo difícil con plazo que aparece a
## mitad de camino. Lógica pura: guarda su estado en un Dictionary (`GameState.big`) y el catálogo sale de
## data/big_orders.json.
##   estado: {"phase", "status": "idle"|"active", "left" (s), "progress", "tries", "next_at" (láminas)}

const IDLE: String = "idle"
const ACTIVE: String = "active"

var db: DataDB


func _init(p_db: DataDB) -> void:
	db = p_db


func def_for(phase: int) -> Dictionary:
	for o: Dictionary in db.big_orders:
		if Cfg.integer(o, "phase") == phase:
			return o
	return {}


func has_order(phase: int) -> bool:
	return not def_for(phase).is_empty()


## Estado inicial de un pedido (todavía no apareció).
static func fresh(phase: int, trigger_sheets: int) -> Dictionary:
	return {"phase": phase, "status": IDLE, "left": 0.0, "progress": 0.0, "tries": 0, "next_at": trigger_sheets}


## Objetivo del intento actual: cada intento fallido lo vuelve un poco más fácil (nadie queda bloqueado).
func target(state: Dictionary) -> int:
	var d: Dictionary = def_for(Cfg.integer(state, "phase"))
	var n: float = Cfg.num(d, "n")
	var easier: float = Cfg.num(d, "easier")
	return maxi(1, roundi(n * pow(easier, float(Cfg.integer(state, "tries")))))


## Plazo del intento actual (segundos): +25 % por cada intento fallido, y el multiplicador de accesorios.
func seconds(state: Dictionary, time_mult: float) -> float:
	var d: Dictionary = def_for(Cfg.integer(state, "phase"))
	return Cfg.num(d, "seconds") * (1.0 + 0.25 * float(Cfg.integer(state, "tries"))) * time_mult


func is_active(state: Dictionary) -> bool:
	return str(state.get("status", IDLE)) == ACTIVE


## ¿Toca que aparezca? (`phase_sheets`: láminas terminadas en este escenario.)
func should_start(state: Dictionary, phase_sheets: int, done: bool) -> bool:
	return not done and not is_active(state) and phase_sheets >= Cfg.integer(state, "next_at")


func start(state: Dictionary, time_mult: float) -> void:
	state["status"] = ACTIVE
	state["progress"] = 0.0
	state["left"] = seconds(state, time_mult)


## Suma lo que pasó en un paso. `step`: {"pops": n, "material": {mat: n}, "chain": n, "tool": id,
## "heavy_stomp": n}. Devuelve el progreso nuevo (el pedido se cumple al llegar a target()).
func observe(state: Dictionary, step: Dictionary) -> float:
	var d: Dictionary = def_for(Cfg.integer(state, "phase"))
	var progress: float = Cfg.num(state, "progress")
	match str(d["kind"]):
		"bubbles":
			progress += Cfg.num(step, "pops")
		"material_pops":
			var mats: Dictionary = step["material"] if step.has("material") else {}
			var key: String = str(d["material"])
			if mats.has(key):
				var got: float = mats[key]
				progress += got
		"chain_no_tool":
			if str(step.get("tool", "")) != str(d["tool"]):
				progress = maxf(progress, Cfg.num(step, "chain"))
		"heavy_one_stomp":
			progress = maxf(progress, Cfg.num(step, "heavy_stomp"))
	state["progress"] = progress
	return progress


func is_met(state: Dictionary) -> bool:
	return Cfg.num(state, "progress") >= float(target(state))


## Vence el plazo: queda inactivo y vuelve después de `retry_sheets` láminas, más fácil.
func expire(state: Dictionary, phase_sheets: int) -> void:
	var d: Dictionary = def_for(Cfg.integer(state, "phase"))
	state["status"] = IDLE
	state["left"] = 0.0
	state["progress"] = 0.0
	state["tries"] = Cfg.integer(state, "tries") + 1
	state["next_at"] = phase_sheets + Cfg.integer(d, "retry_sheets")
