class_name Economy
extends RefCounted
## Fórmulas de economía (DESIGN 3.6). Funciones puras; los números vienen de data/.


## Valor de un reventón: base_fase * p^2 * m_tipo * m_combo * m_global.
static func pop_value(base: float, pressure: float, m_type: float, m_combo: float, m_global: float) -> float:
	return base * pressure * pressure * m_type * m_combo * m_global


## Rendimientos decrecientes de las cadenas grandes: el reventón número `n` de una cadena vale
## (size / n)^alpha de su valor cuando n supera `size`. El sello de cadena muestra el número completo.
static func chain_factor(n: int, size: int, alpha: float) -> float:
	if n <= size:
		return 1.0
	return pow(float(size) / float(n), alpha)


## Costo del nivel `level` -> `level + 1`: base * g^level.
static func cost(base: float, growth: float, level: int) -> float:
	return base * pow(growth, float(level))


## Costo de comprar `n` niveles seguidos desde `level` (suma geométrica).
static func bulk_cost(base: float, growth: float, level: int, n: int) -> float:
	if n <= 0:
		return 0.0
	if is_equal_approx(growth, 1.0):
		return base * float(n)
	return base * pow(growth, float(level)) * (pow(growth, float(n)) - 1.0) / (growth - 1.0)


## Cuántos niveles se pueden pagar (hasta `cap` niveles más) con `budget`.
static func max_affordable(base: float, growth: float, level: int, budget: float, cap: int) -> int:
	var n: int = 0
	var spent: float = 0.0
	while n < cap:
		var next: float = cost(base, growth, level + n)
		if spent + next > budget:
			break
		spent += next
		n += 1
	return n


## Multiplicador por hito: x`mult` cada `every` niveles.
static func milestone_multiplier(level: int, every: int, mult: float) -> float:
	if every <= 0:
		return 1.0
	@warning_ignore("integer_division")
	return pow(mult, float(level / every))


## Multiplicador de combo según el ritmo (reventones por segundo). `rates` ascendente;
## el multiplicador es el del último escalón alcanzado y no sigue subiendo después.
static func combo_multiplier(rate: float, rates: Array, multipliers: Array) -> float:
	var out: float = 1.0
	for i: int in mini(rates.size(), multipliers.size()):
		var r: float = rates[i]
		if rate >= r:
			var m: float = multipliers[i]
			out = m
	return out
