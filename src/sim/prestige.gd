class_name Prestige
extends RefCounted
## Reciclado (DESIGN 3.7): Pellets = floor(sqrt(Pops de la corrida / divisor)). Parámetros en data.


static func pellets_for(pops_run: float, divisor: float, exponent: float) -> int:
	if pops_run <= 0.0 or divisor <= 0.0:
		return 0
	return int(floorf(pow(pops_run / divisor, exponent)))


## Pops que hacen falta para ganar `pellets` Pellets (inversa de la fórmula).
static func pops_needed(pellets: int, divisor: float, exponent: float) -> float:
	return divisor * pow(float(pellets), 1.0 / exponent)


## Reinicia la corrida: se pierden Pops y mejoras normales; se conservan Pellets,
## mejoras permanentes, Burbujario y estadísticas. Devuelve los Pellets ganados.
static func recycle(state: GameState, gained: int) -> int:
	state.pellets += float(gained)
	state.recycles += 1
	if state.first_recycle_s < 0.0:
		state.first_recycle_s = state.run_time_s
	state.pops = 0.0
	state.pops_run = 0.0
	state.levels = {}
	state.run_time_s = 0.0
	state.sheet = {}
	state.selected_tool = "finger"
	return gained
