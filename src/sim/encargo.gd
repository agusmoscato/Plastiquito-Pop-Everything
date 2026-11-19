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
var specials_left: int = 0


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
			e.target = specials
			e.specials_left = specials
		"combo":
			var steps: Array = cfg["combo_level"]
			var lv: float = steps[mini(i, steps.size() - 1)]
			e.target = int(lv)
	return e


## Avanza con los eventos de un paso. Devuelve true el paso en que se cumple.
func observe(chain_now: int, popped_tense: int, popped_specials: int, combo_level: int) -> bool:
	if done:
		return false
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


## Clave del texto (Tx "enc_<kind>"), con %d = objetivo.
func text_key() -> String:
	return "enc_" + kind
