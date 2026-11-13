class_name SessionLog
extends RefCounted
## Registro local de una sesión de playtest (lógica pura; el archivo lo escribe el autoload).
## Clic suelto = apretar y soltar sin salir de la celda; arrastre = cruzar a otra celda apretando.

var version: String = "0.0.0"
var started_at: String = ""

var total_pops: int = 0
var max_streak: int = 0
var clicks: int = 0
var drags: int = 0
var first_drag_s: float = -1.0
var zoom_uses: int = 0
var reloads: int = 0
var volume_changes: PackedStringArray = PackedStringArray()
var purchases: int = 0
var max_chain: int = 0
var first_recycle_min: float = -1.0
var tool_uses: Dictionary = {} ## herramienta -> reventones

var _pressing: bool = false
var _press_is_drag: bool = false


func press_started() -> void:
	_pressing = true
	_press_is_drag = false


## El cursor cruzó a otra celda con el botón apretado.
func press_moved_to_new_cell(now_s: float) -> void:
	if not _pressing or _press_is_drag:
		return
	_press_is_drag = true
	if first_drag_s < 0.0:
		first_drag_s = now_s


func press_ended() -> void:
	if not _pressing:
		return
	if _press_is_drag:
		drags += 1
	else:
		clicks += 1
	_pressing = false
	_press_is_drag = false


func pops(count: int, streak: int) -> void:
	total_pops += count
	max_streak = maxi(max_streak, streak)


func volume_changed(value: float, now_s: float) -> void:
	volume_changes.append("%.2f@%.1f" % [value, now_s])


func purchase(count: int) -> void:
	purchases += count


func chain(size: int) -> void:
	max_chain = maxi(max_chain, size)


func recycled(run_minutes: float) -> void:
	if first_recycle_min < 0.0:
		first_recycle_min = run_minutes


func tool_pops(tool_id: String, count: int) -> void:
	var cur: int = tool_uses.get(tool_id, 0)
	tool_uses[tool_id] = cur + count


func zoomed() -> void:
	zoom_uses += 1


func sheet_reloaded() -> void:
	reloads += 1


## Texto CSV de dos columnas (campo,valor), una fila por dato.
func to_csv(duration_s: float) -> String:
	var rows: PackedStringArray = PackedStringArray()
	rows.append("campo,valor")
	rows.append("version,%s" % version)
	rows.append("inicio,%s" % started_at)
	rows.append("duracion_s,%.1f" % duration_s)
	rows.append("reventones_totales,%d" % total_pops)
	rows.append("segundo_primer_arrastre,%s" % ("" if first_drag_s < 0.0 else "%.1f" % first_drag_s))
	rows.append("clics_sueltos,%d" % (clicks + (1 if _pressing and not _press_is_drag else 0)))
	rows.append("arrastres,%d" % (drags + (1 if _pressing and _press_is_drag else 0)))
	rows.append("cambios_volumen,%s" % ";".join(volume_changes))
	rows.append("usos_rueda_zoom,%d" % zoom_uses)
	rows.append("recargas_lamina,%d" % reloads)
	rows.append("racha_maxima,%d" % max_streak)
	rows.append("compras_totales,%d" % purchases)
	rows.append("cadena_maxima,%d" % max_chain)
	rows.append("minuto_primer_reciclado,%s" % ("" if first_recycle_min < 0.0 else "%.1f" % first_recycle_min))
	var uses: PackedStringArray = PackedStringArray()
	var keys: Array = tool_uses.keys()
	keys.sort()
	for k: Variant in keys:
		var uses_n: int = tool_uses[k]
		uses.append("%s:%d" % [str(k), uses_n])
	rows.append("uso_herramientas,%s" % ";".join(uses))
	return "\n".join(rows) + "\n"
