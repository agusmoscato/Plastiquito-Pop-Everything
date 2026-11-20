class_name Accessories
extends RefCounted
## Accesorios permanentes de la mano (sección 3 de la 0.7.0). Ranuras: 3 anillos (índice, medio y
## anular), 1 pulsera, 1 reloj y 1 guante. Se compran con Pellets y no se pierden al reciclar.
## Lógica pura: el catálogo sale de data/accessories.json y los efectos se suman a 1.0.

const SLOTS: Array[String] = ["ring0", "ring1", "ring2", "bracelet", "watch", "glove"]
const RING_FINGERS: Array[String] = ["index", "middle", "ring"] ## dedo de cada ranura de anillo

var db: DataDB


func _init(p_db: DataDB) -> void:
	db = p_db


func def(id: String) -> Dictionary:
	for a: Dictionary in db.accessories:
		if str(a["id"]) == id:
			return a
	return {}


func ids() -> Array[String]:
	var out: Array[String] = []
	for a: Dictionary in db.accessories:
		out.append(str(a["id"]))
	return out


## Tipo de ranura del accesorio ("ring", "bracelet", "watch" o "glove").
func slot_kind(id: String) -> String:
	var d: Dictionary = def(id)
	return str(d["slot"]) if d.has("slot") else ""


## true si la ranura `slot` (de SLOTS) acepta ese accesorio.
func fits(slot: String, id: String) -> bool:
	var kind: String = slot_kind(id)
	return kind != "" and slot.begins_with(kind)


func cost_of(id: String) -> int:
	var d: Dictionary = def(id)
	return Cfg.integer(d, "cost") if d.has("cost") else 0


## Efectos de lo equipado, listos para usar: {"wear_drain": {"iron": -0.2}, "chain_big": 0.25, ...}.
func aggregate(equipped: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for slot: String in SLOTS:
		if not equipped.has(slot):
			continue
		var d: Dictionary = def(str(equipped[slot]))
		if not d.has("effect"):
			continue
		var fx: Dictionary = d["effect"]
		for key: String in fx:
			_add_effect(out, key, fx[key])
	return out


func _add_effect(out: Dictionary, key: String, v: Variant) -> void:
	if v is Dictionary:
		var vd: Dictionary = v
		var sub: Dictionary = out[key] if out.has(key) else {}
		for k2: String in vd:
			var cur: float = sub[k2] if sub.has(k2) else 0.0
			var add: float = vd[k2]
			sub[k2] = cur + add
		out[key] = sub
	else:
		var cur2: float = out[key] if out.has(key) else 0.0
		var add2: float = v
		out[key] = cur2 + add2


## Valor `key` de un efecto por herramienta o material (0 si no hay).
static func per(fx: Dictionary, key: String, who: String) -> float:
	if not fx.has(key):
		return 0.0
	var d: Dictionary = fx[key]
	var v: float = d[who] if d.has(who) else 0.0
	return v


## Valor de un efecto global (0 si no hay).
static func flat(fx: Dictionary, key: String) -> float:
	var v: float = fx[key] if fx.has(key) else 0.0
	return v
