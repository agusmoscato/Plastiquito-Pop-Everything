class_name Encargo
extends RefCounted
## El encargo de la lámina (DESIGN, sesión 5): cada lámina trae un pedido chico que pide jugar bien,
## no solo apretar. Cumplirlo paga un bono y sube la racha; terminar la lámina sin cumplirlo corta la
## racha. Tipos:
##   chain    hacé una cadena de N
##   veins    reventá N burbujas tensas (las vetas de aire)
##   specials reventá todas las especiales de la lámina
##   combo    llegá al ritmo xN
## La dificultad (N) crece con la fase y con el tamaño de la lámina. Números en data/economy.json
## ("encargos"). Lógica pura: GameSim le pasa los eventos de cada paso.

const KINDS: Array[String] = ["chain", "veins", "specials", "combo"]

var kind: String = "chain"
var target: int = 1
var progress: int = 0
var done: bool = false
var closed: bool = false ## la lámina terminó: ya no se cumple ni se cobra
var specials_left: int = 0
var elapsed: float = 0.0 ## segundos de lámina en juego (el ritmo cuenta recién pasada la ventana del combo)


## Elige el encargo de una lámina nueva. `tense` = burbujas tensas al empezar, `specials` = especiales.
static func roll(rng: RandomNumberGenerator, phase: int, cells: int, tense: int, specials: int, cfg: Dictionary) -> Encargo:
	var options: Array[String] = ["chain", "combo"]
	if tense >= 6:
		options.append("veins")
	if specials >= 2:
		options.append("specials")
	var e: Encargo = Encargo.new()
	e.kind = options[rng.randi() % options.size()]
	var i: int = clampi(phase, 1, 4) - 1
	var size_k: float = sqrt(float(cells) / 64.0) # la lámina inicial de la Mesa (8 x 8) es 1
	match e.kind:
		"chain":
			var base: Array = cfg["chain_base"]
			var b: float = base[mini(i, base.size() - 1)]
			e.target = maxi(6, roundi(b * size_k))
		"veins":
			e.target = maxi(4, roundi(float(tense) * Cfg.num(cfg, "veins_fraction")))
		"specials":
			e.target = maxi(1, ceili(float(specials) * Cfg.num(cfg, "specials_fraction")))
			e.specials_left = specials
		"combo":
			var steps: Array = cfg["combo_level"]
			var lv: float = steps[mini(i, steps.size() - 1)]
			e.target = int(lv)
	return e


## Avanza con los eventos de un paso. Devuelve true el paso en que se cumple. `combo_level` solo cuenta
## pasados `combo_grace` segundos de lámina (si no, el ritmo de la lámina anterior lo cumplía solo).
func observe(chain_now: int, popped_tense: int, popped_specials: int, combo_level: int, dt: float = 0.0, combo_grace: float = 0.0) -> bool:
	if done or closed:
		return false
	elapsed += dt
	if elapsed < combo_grace:
		combo_level = 0
	match kind:
		"chain":
			progress = maxi(progress, chain_now)
		"veins":
			progress += popped_tense
		"specials":
			progress += popped_specials
		"combo":
			progress = maxi(progress, combo_level)
	if progress >= target:
		progress = target
		done = true
		return true
	return false


func ratio() -> float:
	return clampf(float(progress) / float(maxi(target, 1)), 0.0, 1.0)


## Una especial que se perdió sin reventar (derretida por la plancha): el pedido baja uno.
func lost_special() -> void:
	if kind == "specials" and not done:
		specials_left -= 1
		target = clampi(target, 1, maxi(1, specials_left)) # nunca pide más de las que quedan


func to_dict() -> Dictionary:
	return {"kind": kind, "target": target, "progress": progress, "done": done, "closed": closed,
		"specials_left": specials_left, "elapsed": elapsed}


## Desde un guardado; null si el diccionario no sirve.
static func from_dict(d: Dictionary) -> Encargo:
	if not d.has("kind") or not KINDS.has(str(d["kind"])):
		return null
	var e: Encargo = Encargo.new()
	e.kind = str(d["kind"])
	e.target = maxi(1, Cfg.integer(d, "target"))
	e.progress = Cfg.integer(d, "progress")
	e.done = Cfg.flag(d, "done")
	e.closed = Cfg.flag(d, "closed")
	e.specials_left = Cfg.integer(d, "specials_left")
	e.elapsed = Cfg.num(d, "elapsed")
	return e


## Clave del texto (Tx "enc_<kind>"), con %d = objetivo.
func text_key() -> String:
	return "enc_" + kind
