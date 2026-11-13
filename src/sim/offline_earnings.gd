class_name OfflineEarnings
extends RefCounted
## Ganancias mientras no jugás: lo que produjeron Manitos y rodillo con el juego cerrado, a una
## fracción de la eficiencia y con tope de horas (todo en data/economy.json). Función pura.


## Devuelve {"seconds": segundos acreditados, "hands_pops", "roller_pops", "pops": Pops totales}.
## Si la hora actual es anterior a la última vista (reloj atrasado) no se otorga nada.
static func compute(now_unix: float, saved_at_unix: float, max_seen_unix: float, hands_per_s: float,
		roller_per_s: float, value_per_pop: float, efficiency: float, cap_hours: float) -> Dictionary:
	var out: Dictionary = {"seconds": 0.0, "hands_pops": 0.0, "roller_pops": 0.0, "pops": 0.0, "clock_cheat": false}
	if saved_at_unix <= 0.0:
		return out
	if now_unix < maxf(saved_at_unix, max_seen_unix):
		out["clock_cheat"] = now_unix < max_seen_unix - 5.0 # tolerancia de 5 s por redondeos del reloj
		return out
	var elapsed: float = minf(now_unix - saved_at_unix, cap_hours * 3600.0)
	if elapsed <= 1.0:
		return out
	var hands: float = hands_per_s * elapsed * efficiency
	var roller: float = roller_per_s * elapsed * efficiency
	out["seconds"] = elapsed
	out["hands_pops"] = floorf(hands)
	out["roller_pops"] = floorf(roller)
	out["pops"] = (floorf(hands) + floorf(roller)) * value_per_pop
	return out
