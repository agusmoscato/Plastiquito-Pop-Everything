class_name Upgrades
extends RefCounted
## Catálogo de mejoras (data/upgrades.json): costos, efectos por nivel y requisitos.
## Convierte los niveles de un GameState en los parámetros reales del juego (stats).

const PERM: String = "perm"

var db: DataDB
var eco: Dictionary
var order: Array[String] = [] ## ids en el orden del catálogo
## Las mejoras en Pops cuestan más en cada fase (x base de la fase, DESIGN 4); lo fija GameSim.
var cost_scale: float = 1.0


func _init(p_db: DataDB) -> void:
	db = p_db
	eco = db.economy
	for u: Dictionary in db.upgrades:
		order.append(str(u["id"]))


func def(id: String) -> Dictionary:
	return db.get_upgrade(id)


func is_perm(id: String) -> bool:
	return str(def(id)["scope"]) == PERM


func max_level(id: String) -> int:
	return Cfg.integer(def(id), "max_level")


func level_of(state: GameState, id: String) -> int:
	return state.perm_level(id) if is_perm(id) else state.level(id)


func milestone(level: int) -> float:
	return Economy.milestone_multiplier(level, Cfg.integer(eco, "milestone_every"), Cfg.num(eco, "milestone_multiplier"))


## Costo del próximo nivel (en Pops, o en Pellets si es permanente).
func next_cost(id: String, level: int) -> float:
	var d: Dictionary = def(id)
	var scale: float = 1.0 if str(d["scope"]) == PERM else cost_scale
	return ceilf(Economy.cost(Cfg.num(d, "base_cost"), Cfg.num(d, "growth"), level) * scale)


## Costo de `n` niveles más, redondeado hacia arriba por nivel (coincide con comprar de a uno).
func cost_for(id: String, level: int, n: int) -> float:
	var total: float = 0.0
	for i: int in n:
		total += next_cost(id, level + i)
	return total


func affordable_count(id: String, level: int, budget: float) -> int:
	var n: int = 0
	var spent: float = 0.0
	var cap: int = max_level(id) - level
	while n < cap:
		var c: float = next_cost(id, level + n)
		if spent + c > budget:
			break
		spent += c
		n += 1
	return n


## Efecto total a un nivel: suma (add) o producto (mult), con el x2 de cada hito.
func effect(id: String, level: int) -> float:
	var d: Dictionary = def(id)
	var per: float = Cfg.num(d, "per_level")
	var ms: float = milestone(level)
	if str(d["effect_type"]) == "mult":
		return (1.0 + per * float(level)) * ms ## "mult": 1 + per*nivel (rinde menos a más nivel)
	return per * float(level) * (ms if level > 0 else 1.0)


## true si se cumplen los requisitos (fase mínima o mejora previa).
func is_available(state: GameState, id: String) -> bool:
	var req: Dictionary = def(id)["requires"]
	if req.has("phase"):
		var ph: float = req["phase"]
		if phase_of(state) < int(ph):
			return false
	if req.has("upgrade"):
		if state.level(str(req["upgrade"])) < 1:
			return false
	return true


func phase_of(state: GameState) -> int:
	return 1 + state.perm_level("perm_sheet")


func tool_unlocked(state: GameState, tool_id: String) -> bool:
	if tool_id == "finger":
		return true
	if tool_id == "palm":
		return state.level("unlock_palm") >= 1
	if tool_id == "rolling_pin":
		return state.level("unlock_pin") >= 1
	return false


func ids_for_tool(tool_id: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in order:
		if str(def(id)["tool"]) == tool_id and str(def(id)["scope"]) == "tool":
			out.append(id)
	return out


func ids_for_scope(scope: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in order:
		if str(def(id)["scope"]) == scope:
			out.append(id)
	return out


## Sumatoria de efecto de una mejora de un tipo ("size", "force"...) de una herramienta.
func _tool_effect(state: GameState, tool_id: String, kind: String) -> float:
	for id: String in ids_for_tool(tool_id):
		var d: Dictionary = def(id)
		if str(d["kind"]) == kind:
			return effect(id, state.level(id) + _start_levels(state, id))
	return 0.0


func _tool_mult(state: GameState, tool_id: String, kind: String) -> float:
	for id: String in ids_for_tool(tool_id):
		var d: Dictionary = def(id)
		if str(d["kind"]) == kind:
			return effect(id, state.level(id) + _start_levels(state, id))
	return 1.0


## "Dedo con experiencia": el dedo arranca con niveles de fuerza regalados.
func _start_levels(state: GameState, id: String) -> int:
	if id == "finger_force":
		return int(effect("perm_finger", state.perm_level("perm_finger")))
	return 0


## Parámetros efectivos de una herramienta (para ToolModel), en unidades del mundo.
func tool_params(state: GameState, tool_id: String, spacing: float) -> Dictionary:
	var t: Dictionary = db.get_tool(tool_id)
	var b: Dictionary = t["balance"]
	var p: Dictionary = {}
	p["shape"] = str(t["shape"]) if tool_id != "finger" else "single"
	if tool_id == "palm":
		p["shape"] = "circle"
	var radius_cells: float = Cfg.num(b, "radius_cells") + _tool_effect(state, tool_id, "size")
	p["radius"] = radius_cells * spacing
	if tool_id == "finger" and radius_cells > 0.0:
		p["shape"] = "circle"
	p["force_per_second"] = Cfg.num(b, "force_per_second") * _tool_mult(state, tool_id, "force")
	p["drag_entry_fraction"] = minf(1.0, Cfg.num(b, "drag_entry_fraction") + _tool_effect(state, tool_id, "speed"))
	var special: float = _tool_effect(state, tool_id, "special")
	var air: float = Cfg.num(b, "air_share")
	var bias: float = Cfg.num(b, "direction_bias")
	if tool_id == "rolling_pin":
		bias += special
	else:
		air += special
	p["air_share"] = minf(air, 0.95)
	p["direction_bias"] = bias
	p["center_falloff"] = Cfg.num(b, "center_falloff")
	return p


## Parámetros globales derivados de los niveles.
func global_stats(state: GameState) -> Dictionary:
	var sheet_cfg: Dictionary = db.sheet
	var g: Dictionary = {}
	g["tense_threshold"] = maxf(1.3, Cfg.num(sheet_cfg, "tense_threshold") - effect("global_tense", state.level("global_tense")))
	g["chain_k"] = minf(Cfg.num(sheet_cfg, "chain_k_max"), Cfg.num(sheet_cfg, "chain_k") + effect("global_chain", state.level("global_chain")))
	var special_add: float = effect("global_special", state.level("global_special"))
	g["chance_golden"] = Cfg.num(eco, "chance_golden") + special_add + effect("perm_golden", state.perm_level("perm_golden"))
	g["chance_bomb"] = Cfg.num(eco, "chance_bomb") + special_add * 0.5
	g["chance_line"] = Cfg.num(eco, "chance_line") + special_add * 0.5
	g["value_mult"] = effect("global_value", state.level("global_value")) * (1.0 + effect("perm_bonus", state.perm_level("perm_bonus")))
	g["sheet_growth"] = int(effect("global_sheet", state.level("global_sheet")))
	g["auto_reload"] = state.level("global_reload") >= 1
	g["phase"] = phase_of(state)
	return g


# --- Textos -------------------------------------------------------------------------------

func name_of(id: String, lang: String) -> String:
	return str(def(id)["name_" + lang])


func desc_of(id: String, lang: String) -> String:
	return str(def(id)["desc_" + lang])


## Efecto acumulado a `level`, listo para mostrar ("x1,40", "+1,0 radio", "umbral 1,45"...).
func effect_text(id: String, level: int, lang: String) -> String:
	var d: Dictionary = def(id)
	var kind: String = str(d["kind"])
	var v: float = effect(id, level)
	match kind:
		"unlock":
			return "-"
		"force", "value":
			return "x" + NumberFormat.decimal(v, 2, lang)
		"size":
			return "+" + NumberFormat.decimal(v, 1, lang)
		"speed":
			return "+" + NumberFormat.decimal(v * 100.0, 0, lang) + "%"
		"special":
			if str(d["tool"]) == "rolling_pin":
				return "+" + NumberFormat.decimal(v, 1, lang)
			return "+" + NumberFormat.decimal(v * 100.0, 0, lang) + "%"
		"special_chance", "golden_chance":
			return "+" + NumberFormat.decimal(v * 100.0, 1, lang) + "%"
		"tense":
			return NumberFormat.decimal(maxf(1.3, Cfg.num(db.sheet, "tense_threshold") - v), 2, lang)
		"chain_k":
			return NumberFormat.decimal(minf(Cfg.num(db.sheet, "chain_k_max"), Cfg.num(db.sheet, "chain_k") + v), 2, lang)
		"sheet_growth":
			return "+" + str(int(v))
		"sheet_size":
			return ("Mesa" if lang == "es" else "Table") if level < 1 else ("Piso 40x40" if lang == "es" else "Floor 40x40")
		"global_bonus":
			return "+" + NumberFormat.decimal(v * 100.0, 0, lang) + "%"
		"finger_start":
			return "+" + str(int(v)) + " niv" if lang == "es" else "+" + str(int(v)) + " lv"
	return NumberFormat.decimal(v, 2, lang)
