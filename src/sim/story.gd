class_name Story
extends RefCounted
## La historia (sección 7 de la 0.7.0): sos el empleado nuevo de Plastiquito S.R.L. y al final te echan.
## Lógica pura: decide qué memo toca, el cargo de la credencial y los textos (data/story.json). El jefe
## nunca aparece en pantalla: habla con memos escritos a máquina. El nombre y la foto se usan solo
## localmente (nunca se suben).

var db: DataDB


func _init(p_db: DataDB) -> void:
	db = p_db


func cfg() -> Dictionary:
	return db.story


## Cargo de la credencial según los reciclados (Pasante → Reventador Junior → Senior → Jefe de Cuadrilla).
func rank_index(recycles: int) -> int:
	var ranks: Array = cfg()["ranks"]
	var out: int = 0
	for i: int in ranks.size():
		var r: Dictionary = ranks[i]
		if recycles >= Cfg.integer(r, "recycles"):
			out = i
	return out


func rank_name(index: int, lang: String) -> String:
	var ranks: Array = cfg()["ranks"]
	var r: Dictionary = ranks[clampi(index, 0, ranks.size() - 1)]
	return str(r[lang])


## Texto de un memo con {name} y {rank} ya reemplazados.
func memo_text(id: String, lang: String, player: String, rank: String = "") -> String:
	var memos: Dictionary = cfg()["memos"]
	if not memos.has(id):
		return ""
	var m: Dictionary = memos[id]
	return str(m[lang]).replace("{name}", player).replace("{rank}", rank)


func fallback_name(lang: String) -> String:
	return str(cfg()["fallback_name_" + lang])


func telegram_body(lang: String) -> String:
	var t: Dictionary = cfg()["telegram"]
	return str(t["body_" + lang])


func telegram_header(lang: String) -> String:
	var t: Dictionary = cfg()["telegram"]
	return str(t["header_" + lang])


func credits(lang: String) -> Array:
	var out: Array = cfg()["credits_" + lang]
	return out
