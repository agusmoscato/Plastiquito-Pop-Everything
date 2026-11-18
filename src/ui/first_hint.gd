class_name FirstHint
extends Control
## Primera vez: una etiqueta de papel arriba de la lámina que explica cómo se juega. Se va sola
## después de los primeros reventones (y no vuelve a aparecer en una partida con Pops).

const GONE_AFTER_POPS: float = 6.0

var sim: GameSim
var _t: float = 0.0
var _fade: float = 1.0


func setup(p_sim: GameSim) -> void:
	sim = p_sim
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	material = UiKit.paper_material()


## Visible mientras el jugador todavía no reventó casi nada.
static func wanted(pops_total: float) -> bool:
	return pops_total < GONE_AFTER_POPS


func _process(delta: float) -> void:
	_t += delta
	var target: float = 1.0 if sim != null and wanted(sim.state.pops_total) else 0.0
	_fade = move_toward(_fade, target, delta * 2.0)
	visible = _fade > 0.01
	queue_redraw()


func _draw() -> void:
	var lines: Array[String] = [Tx.t("hint_1"), Tx.t("hint_2")]
	var w: float = 460.0
	var play_w: float = size.x - 452.0
	var bob: float = sin(_t * 2.4) * 4.0
	var rect: Rect2 = Rect2(Vector2((play_w - w) * 0.5, 120.0 + bob), Vector2(w, 74.0))
	var a: float = _fade
	modulate = Color(1, 1, 1, a)
	UiKit.draw_sheet(self, rect, UiKit.PAPER, "first_hint", 2.0, 1.4)
	UiKit.draw_tape(self, Vector2(rect.position.x + 26.0, rect.position.y + 4.0), -0.5, 40.0, 14.0)
	UiKit.draw_text(self, rect.position + Vector2(0.0, 30.0), lines[0], UiKit.font_title(), 18, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, w)
	UiKit.draw_text(self, rect.position + Vector2(0.0, 56.0), lines[1], UiKit.font_text(), 13, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER, w)
