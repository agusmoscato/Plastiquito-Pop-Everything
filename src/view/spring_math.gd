class_name SpringMath
extends RefCounted
## Resorte amortiguado estable para cualquier delta. Euler explícito con rigidez 260 diverge
## cuando un frame dura más de ~0,1 s (pasaba en CI con render por software y en el primer
## frame): el desplazamiento crecía hasta infinito y el transform de la herramienta quedaba NaN.
## Acá se integra con Euler semiimplícito en subpasos de 1/240 s, se acota el delta y, si algo
## igual llegara a no ser finito, el resorte vuelve al reposo.

const MAX_SUBSTEP: float = 1.0 / 240.0
const MAX_DT: float = 0.25
const MAX_OFFSET: float = 4.0


## Avanza el resorte `dt` segundos. `state` = (desplazamiento, velocidad). Devuelve el nuevo estado.
static func step(state: Vector2, stiffness: float, damping: float, dt: float) -> Vector2:
	if not state.is_finite():
		return Vector2.ZERO
	var remaining: float = clampf(dt, 0.0, MAX_DT) if is_finite(dt) else 0.0
	var x: float = state.x
	var v: float = state.y
	while remaining > 0.0:
		var h: float = minf(remaining, MAX_SUBSTEP)
		v += (-stiffness * x - damping * v) * h
		x += v * h
		remaining -= h
	if not (is_finite(x) and is_finite(v)):
		return Vector2.ZERO
	return Vector2(clampf(x, -MAX_OFFSET, MAX_OFFSET), v)
