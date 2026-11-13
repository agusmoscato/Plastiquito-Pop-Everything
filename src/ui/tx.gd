class_name Tx
extends RefCounted
## Textos de la interfaz en español e inglés. Cortos y secos: la empresa de embalaje
## se toma demasiado en serio las burbujas.

const T: Dictionary = {
	"dept": {"es": "DEPTO. DE REVENTONES", "en": "POPPING DEPARTMENT"},
	"pops": {"es": "POPS", "en": "POPS"},
	"pellets": {"es": "PELLETS", "en": "PELLETS"},
	"work_order": {"es": "ORDEN DE TRABAJO", "en": "WORK ORDER"},
	"next_order": {"es": "SIGUIENTE PEDIDO", "en": "NEXT ORDER"},
	"ready": {"es": "LISTO PARA SELLAR", "en": "READY TO STAMP"},
	"rhythm": {"es": "RITMO", "en": "RHYTHM"},
	"recycle": {"es": "RECICLAR", "en": "RECYCLE"},
	"recycle_now": {"es": "RECICLAR AHORA", "en": "RECYCLE NOW"},
	"close": {"es": "CERRAR", "en": "CLOSE"},
	"bubblepedia": {"es": "BURBUJARIO", "en": "BUBBLE LOG"},
	"new": {"es": "NUEVA", "en": "NEW"},
	"chain": {"es": "CADENA", "en": "CHAIN"},
	"goal_palm": {"es": "Habilitar la palma", "en": "Unlock the palm"},
	"goal_recycle": {"es": "Primer reciclado", "en": "First recycling"},
	"goal_pin": {"es": "Habilitar el palo de amasar", "en": "Unlock the rolling pin"},
	"goal_next_pellet": {"es": "Próximo Pellet", "en": "Next Pellet"},
	"recycle_title": {"es": "CENTRO DE RECICLADO", "en": "RECYCLING CENTER"},
	"recycle_hint": {"es": "La lámina y los Pops se convierten en Pellets.", "en": "The sheet and Pops become Pellets."},
	"recycle_gain": {"es": "Ganarías", "en": "You would earn"},
	"empty_log": {"es": "Todavía no apareció ninguna especial.", "en": "No special bubble has shown up yet."},
	"tool_finger": {"es": "DEDO", "en": "FINGER"},
	"tool_palm": {"es": "PALMA", "en": "PALM"},
	"tool_rolling_pin": {"es": "PALO", "en": "PIN"},
	"tool_iron": {"es": "PLANCHA", "en": "IRON"},
	"tool_boot": {"es": "BOTA", "en": "BOOT"},
	"tool_hands": {"es": "MANITOS", "en": "HANDS"},
	"tool_auto_roller": {"es": "RODILLO", "en": "ROLLER"},
	"tool_global": {"es": "GLOBAL", "en": "GLOBAL"},
	"boot_ready": {"es": "LISTA", "en": "READY"},
	"welcome_title": {"es": "TURNO NOCHE", "en": "NIGHT SHIFT"},
	"welcome_collect": {"es": "COBRAR", "en": "COLLECT"},
	"welcome_hands": {"es": "Manitos", "en": "Little hands"},
	"welcome_roller": {"es": "Rodillo", "en": "Roller"},
	"welcome_time": {"es": "Tiempo", "en": "Time"},
	"welcome_eff": {"es": "Eficiencia", "en": "Efficiency"},
	"welcome_total": {"es": "TOTAL", "en": "TOTAL"},
	"board_title": {"es": "TABLERO DE MEJORAS PERMANENTES", "en": "PERMANENT UPGRADE BOARD"},
	"echo": {"es": "Eco", "en": "Echo"},
	"echo_d": {"es": "Se vuelve a inflar una vez, a los 2 s.", "en": "Re-inflates once, after 2 s."},
	"golden": {"es": "Dorada", "en": "Golden"},
	"bomb": {"es": "Bomba", "en": "Bomb"},
	"line": {"es": "Línea", "en": "Line"},
	"golden_d": {"es": "Vale x10. Brilla, para que no te la pierdas.", "en": "Worth x10. It shines so you will not miss it."},
	"bomb_d": {"es": "Revienta todo a radio 3. Con mecha corta.", "en": "Pops everything in radius 3. Short fuse."},
	"line_d": {"es": "Revienta su fila entera, hacia los dos lados.", "en": "Pops its whole row, both ways."},
}

const MILESTONE_JOKES: Array[Dictionary] = [
	{"es": "Hito aprobado por Calidad.", "en": "Milestone approved by Quality."},
	{"es": "El efecto se duplica. Nadie sabe por qué.", "en": "Effect doubled. Nobody knows why."},
	{"es": "Recursos Humanos ya lo sabe.", "en": "Human Resources has been notified."},
	{"es": "Se archiva en la carpeta de logros.", "en": "Filed under achievements."},
	{"es": "Informe trimestral: excelente.", "en": "Quarterly report: excellent."},
]


static func t(key: String) -> String:
	var entry: Dictionary = T.get(key, {})
	var out: String = str(entry.get(Settings.language, key))
	return out


static func joke(n: int) -> String:
	var j: Dictionary = MILESTONE_JOKES[n % MILESTONE_JOKES.size()]
	return str(j[Settings.language])
