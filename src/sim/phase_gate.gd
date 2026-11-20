class_name PhaseGate
extends RefCounted
## Requisitos para abrir el escenario siguiente (sección 5 de la 0.7.0), además de los Pellets. Todo sale de
## data/phases.json ("requires"): el pedido grande cumplido, la herramienta del escenario a cierto nivel y un
## ritmo de Pops por segundo (en burbujas equivalentes: Pops/s dividido por el valor base del escenario).
## Los requisitos de ritmo y de nivel se traban (latch) al cumplirse una vez: reciclar reinicia los niveles,
## pero lo que ya demostraste no se pierde.


## Lista de requisitos del escenario `phase`: [{"id", "ok", "es", "en"}].
static func list(db: DataDB, phase: int, big_done: bool, latched: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var p: Dictionary = {}
	for e: Dictionary in db.phases:
		if Cfg.integer(e, "number") == phase:
			p = e
	if p.is_empty() or not p.has("requires"):
		return out
	var req: Dictionary = p["requires"]
	var needs_big: bool = req.has("big_order") and req["big_order"] == true
	if needs_big:
		out.append({"id": "big_order", "ok": big_done, "es": "Pedido grande cumplido", "en": "Big order done"})
	if req.has("tool"):
		var t: Dictionary = req["tool"]
		var key: String = "%d:tool" % phase
		out.append({"id": "tool", "ok": latched.has(key),
			"es": "%s nivel %d" % [str(t["name_es"]), Cfg.integer(t, "level")],
			"en": "%s level %d" % [str(t["name_en"]), Cfg.integer(t, "level")]})
	if req.has("rate"):
		var key2: String = "%d:rate" % phase
		var r: float = Cfg.num(req, "rate")
		out.append({"id": "rate", "ok": latched.has(key2),
			"es": "Ritmo de %s burbujas por segundo" % NumberFormat.decimal(r, 0, "es"),
			"en": "Pace of %s bubbles per second" % NumberFormat.decimal(r, 0, "en")})
	return out


static func all_ok(items: Array[Dictionary]) -> bool:
	for it: Dictionary in items:
		if it["ok"] != true:
			return false
	return true


## Requisitos que dependen de la corrida: devuelve las claves nuevas que hay que trabar ahora.
static func newly_met(db: DataDB, phase: int, tool_level: int, bubbles_per_s: float) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for e: Dictionary in db.phases:
		if Cfg.integer(e, "number") != phase or not e.has("requires"):
			continue
		var req: Dictionary = e["requires"]
		if req.has("tool"):
			var t: Dictionary = req["tool"]
			if tool_level >= Cfg.integer(t, "level"):
				out.append("%d:tool" % phase)
		if req.has("rate") and bubbles_per_s >= Cfg.num(req, "rate"):
			out.append("%d:rate" % phase)
	return out
