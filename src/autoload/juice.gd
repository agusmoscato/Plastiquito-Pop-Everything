extends Node
## Autoload de "juice": partículas, hitstop y trauma para la sacudida de cámara.
## Parámetros en data/juice.json.

var cfg: Dictionary = {}
var trauma: float = 0.0 ## 0..1; la cámara lo lee y lo convierte en sacudida
var fx: FxPool

var _hitstop_until_ms: int = 0
var _hitstop_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var db: DataDB = DataDB.new()
	if not db.load_all():
		push_error("Juice: data inválida: %s" % "; ".join(db.errors))
		return
	cfg = db.juice
	fx = FxPool.new()
	fx.name = "FxPool"
	add_child(fx)
	fx.setup(cfg)


func _process(delta: float) -> void:
	if cfg.is_empty():
		return
	trauma = maxf(0.0, trauma - Cfg.num(cfg, "shake_decay_per_second") * delta)
	if _hitstop_active and Time.get_ticks_msec() >= _hitstop_until_ms:
		_end_hitstop()


## Congela el juego `ms` milisegundos (30 a 60 recomendado).
func hitstop(ms: int) -> void:
	if cfg.is_empty() or ms <= 0:
		return
	if Settings.reduce_motion:
		return
	_hitstop_until_ms = maxi(_hitstop_until_ms, Time.get_ticks_msec() + ms)
	if not _hitstop_active:
		_hitstop_active = true
		Engine.time_scale = 0.02


func _end_hitstop() -> void:
	_hitstop_active = false
	Engine.time_scale = 1.0


## Suma trauma en función de la cantidad de reventones del frame.
func add_pop_trauma(pops: int) -> void:
	if cfg.is_empty() or not Settings.shake_allowed():
		return
	trauma = minf(Cfg.num(cfg, "shake_max_trauma"), trauma + Cfg.num(cfg, "shake_per_pop") * float(pops))


func pops_at(positions: PackedVector3Array) -> void:
	if fx != null:
		fx.emit_at(positions)
