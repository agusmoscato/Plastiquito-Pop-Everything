class_name NumberFormat
extends RefCounted
## Formato de números para pantalla: máximo 4 cifras significativas, sufijos K, M, B, T, Qa…
## y nunca notación científica. Coma decimal en español, punto en inglés.

const SUFFIXES: PackedStringArray = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]


## Formatea una cantidad de Pops. Debajo de 1000 se muestra entera (hacia abajo).
static func pops(value: float, lang: String = "es") -> String:
	if value < 0.0:
		return "-" + pops(-value, lang)
	if value < 1000.0:
		return str(int(floorf(value)))
	var e: int = 1
	var scaled: float = value / 1000.0
	while scaled >= 1000.0 and e < SUFFIXES.size() - 1:
		scaled /= 1000.0
		e += 1
	var decimals: int = _decimals_for(scaled)
	var rounded: float = _round_to(scaled, decimals)
	if rounded >= 1000.0 and e < SUFFIXES.size() - 1: # 999,96K -> 1,000M
		e += 1
		scaled /= 1000.0
		decimals = _decimals_for(scaled)
		rounded = _round_to(scaled, decimals)
	return _with_decimal(rounded, decimals, lang) + SUFFIXES[e]


## Número decimal corto (multiplicadores, porcentajes) con coma o punto según el idioma.
static func decimal(value: float, decimals: int, lang: String = "es") -> String:
	return _with_decimal(_round_to(value, decimals), decimals, lang)


## Segundos como m:ss (o h:mm:ss).
static func duration(seconds: float) -> String:
	var s: int = int(seconds)
	@warning_ignore("integer_division")
	var h: int = s / 3600
	@warning_ignore("integer_division")
	var m: int = (s % 3600) / 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, s % 60]
	return "%d:%02d" % [m, s % 60]


static func _decimals_for(scaled: float) -> int:
	if scaled < 10.0:
		return 3
	if scaled < 100.0:
		return 2
	return 1


static func _round_to(v: float, decimals: int) -> float:
	var f: float = pow(10.0, float(decimals))
	return roundf(v * f) / f


static func _with_decimal(v: float, decimals: int, lang: String) -> String:
	var text: String = ("%." + str(decimals) + "f") % v
	if lang == "es":
		text = text.replace(".", ",")
	return text
