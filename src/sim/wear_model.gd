class_name WearModel
extends RefCounted
## Desgaste de UNA herramienta (sección 2 de la 0.7.0): un medidor que sube al usarla y baja al
## descansar. Al llegar al máximo la herramienta se traba (plancha recalentada, bota sin aire) hasta
## que baja de `resume_fraction`. Las mejoras suben capacidad y recuperación, nunca quitan el límite.
## Lógica pura: sin nodos.

var capacity: float = 0.0 ## 0 = no se cansa (manitos y rodillo)
var drain_per_second: float = 0.0
var recover_per_second: float = 1.0
var resume_fraction: float = 0.5 ## destrabada cuando el medidor baja a esta fracción
var value: float = 0.0
var locked: bool = false
var _used: bool = false


func configure(p_capacity: float, p_drain: float, p_recover: float, p_resume: float) -> void:
	var frac: float = fraction()
	capacity = p_capacity
	drain_per_second = p_drain
	recover_per_second = p_recover
	resume_fraction = p_resume
	value = frac * capacity


## true si esta herramienta se cansa.
func tires() -> bool:
	return capacity > 0.0


## Medidor de 0 (fresca) a 1 (a punto de trabarse).
func fraction() -> float:
	return clampf(value / capacity, 0.0, 1.0) if capacity > 0.0 else 0.0


## Gasta `amount` (segundos de uso, o 1 por pisotón). Devuelve false si la herramienta está trabada.
func use(amount: float) -> bool:
	if not tires():
		return true
	if locked:
		return false
	_used = true
	value = minf(capacity, value + amount)
	if value >= capacity:
		locked = true
	return true


## Se llama una vez por paso: si no se usó en este paso, descansa.
func tick(dt: float) -> void:
	if not tires():
		return
	if not _used:
		value = maxf(0.0, value - recover_per_second * dt)
		if locked and value <= capacity * resume_fraction:
			locked = false
	_used = false


func available() -> bool:
	return not locked
