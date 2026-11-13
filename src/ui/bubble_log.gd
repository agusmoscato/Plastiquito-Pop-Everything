class_name BubbleLog
extends Control
## Burbujario (versión simple de la Fase 2): lista de las especiales descubiertas.
## La pantalla completa con colección llega en la Fase 4.

var sim: GameSim

const TYPES: Array[Dictionary] = [
	{"id": 1, "key": "golden"},
	{"id": 2, "key": "bomb"},
	{"id": 3, "key": "line"},
]


func setup(p_sim: GameSim) -> void:
	sim = p_sim
	custom_minimum_size = Vector2(360.0, 230.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	material = UiKit.paper_material()
	visible = false
	rotation = deg_to_rad(0.9)
	pivot_offset = size * 0.5


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2(4.0, 4.0), size - Vector2(10.0, 10.0))
	UiKit.draw_sheet(self, rect, UiKit.PAPER, "bubble_log", 2.0, 1.6)
	UiKit.draw_tape(self, rect.position + Vector2(24.0, 4.0), -0.4)
	UiKit.draw_text(self, Vector2(20.0, 38.0), Tx.t("bubblepedia"), UiKit.font_title(), 20, UiKit.INK)
	var y: float = 70.0
	var any: bool = false
	for t: Dictionary in TYPES:
		var type_id: int = t["id"]
		if not sim.state.is_discovered(type_id):
			continue
		any = true
		var key: String = str(t["key"])
		UiKit.draw_text(self, Vector2(20.0, y), Tx.t(key).to_upper(), UiKit.font_title(), 14, UiKit.STAMP_RED)
		draw_multiline_string(UiKit.font_text(), Vector2(20.0, y + 18.0), Tx.t(key + "_d"), HORIZONTAL_ALIGNMENT_LEFT, size.x - 50.0, 12, 2, UiKit.INK_SOFT)
		y += 64.0
	if not any:
		UiKit.draw_text(self, Vector2(20.0, 80.0), Tx.t("empty_log"), UiKit.font_text(), 13, UiKit.INK_SOFT)
