class_name GameState
extends RefCounted
## Estado completo y serializable de la partida (DESIGN 8). Lógica pura.

const SAVE_VERSION: int = 2

var pops: float = 0.0 ## moneda actual
var pops_run: float = 0.0 ## Pops ganados en esta corrida (base de la fórmula de Pellets)
var pops_total: float = 0.0
var pellets: float = 0.0
var levels: Dictionary = {} ## id de mejora -> nivel (se reinicia al reciclar)
var perm: Dictionary = {} ## id de mejora permanente -> nivel
var discovered: Dictionary = {} ## tipo de burbuja (int como String) -> true (Burbujario)
var selected_tool: String = "finger"
var playtime_s: float = 0.0
var run_time_s: float = 0.0
var recycles: int = 0
var first_recycle_s: float = -1.0
var max_chain: int = 0
var sheets_done: int = 0
var tool_pops: Dictionary = {} ## herramienta -> reventones
var sheet: Dictionary = {} ## SheetModel.to_dict() de la lámina en curso (vacío si no hay)


func level(id: String) -> int:
	var v: int = levels.get(id, 0)
	return v


func perm_level(id: String) -> int:
	var v: int = perm.get(id, 0)
	return v


func is_discovered(type_id: int) -> bool:
	return discovered.has(str(type_id))


func discover(type_id: int) -> void:
	discovered[str(type_id)] = true


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"pops": pops, "pops_run": pops_run, "pops_total": pops_total, "pellets": pellets,
		"levels": levels.duplicate(), "perm": perm.duplicate(), "discovered": discovered.duplicate(),
		"selected_tool": selected_tool, "playtime_s": playtime_s, "run_time_s": run_time_s,
		"recycles": recycles, "first_recycle_s": first_recycle_s, "max_chain": max_chain,
		"sheets_done": sheets_done, "tool_pops": tool_pops.duplicate(), "sheet": sheet,
	}


## Carga desde un diccionario (migrándolo si es de una versión vieja). false si es inválido.
func from_dict(data: Dictionary) -> bool:
	var d: Dictionary = GameState.migrate(data)
	if d.is_empty():
		return false
	pops = Cfg.num(d, "pops")
	pops_run = Cfg.num(d, "pops_run")
	pops_total = Cfg.num(d, "pops_total")
	pellets = Cfg.num(d, "pellets")
	var lv: Dictionary = d["levels"]
	var pm: Dictionary = d["perm"]
	levels = _int_dict(lv)
	perm = _int_dict(pm)
	var disc: Dictionary = d["discovered"]
	discovered = disc.duplicate()
	selected_tool = str(d["selected_tool"])
	playtime_s = Cfg.num(d, "playtime_s")
	run_time_s = Cfg.num(d, "run_time_s")
	recycles = Cfg.integer(d, "recycles")
	first_recycle_s = Cfg.num(d, "first_recycle_s")
	max_chain = Cfg.integer(d, "max_chain")
	sheets_done = Cfg.integer(d, "sheets_done")
	var tp: Dictionary = d["tool_pops"]
	tool_pops = tp.duplicate()
	var sh: Dictionary = d["sheet"]
	sheet = sh
	return true


## Lleva un save de cualquier versión conocida a SAVE_VERSION. {} si no se reconoce.
## v1 (Fase 1): solo existía la lámina (SheetModel.to_dict), sin economía.
static func migrate(data: Dictionary) -> Dictionary:
	var d: Dictionary = data.duplicate(true)
	var version: int = 1
	if d.has("version"):
		var v: float = d["version"]
		version = int(v)
	if version == 1:
		if not d.has("pressure"):
			return {}
		var fresh: GameState = GameState.new()
		var out: Dictionary = fresh.to_dict()
		out["sheet"] = d
		return out
	if version != SAVE_VERSION:
		return {}
	for key: String in ["pops", "pops_run", "pops_total", "pellets", "levels", "perm", "discovered",
			"selected_tool", "playtime_s", "run_time_s", "recycles", "first_recycle_s", "max_chain",
			"sheets_done", "tool_pops", "sheet"]:
		if not d.has(key):
			return {}
	return d


static func _int_dict(src: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in src:
		var v: float = src[key]
		out[str(key)] = int(v)
	return out
