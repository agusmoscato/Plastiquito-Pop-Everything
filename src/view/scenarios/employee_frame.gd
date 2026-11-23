class_name EmployeeFrame
extends Node3D
## El cuadro de "EMPLEADO DEL MES" con la foto del jugador, que aparece en el depósito de Don Tito
## (sección 7 de la 0.7.0). Después del final recibe un sello rojo "EX". La foto sale de PlayerIdentity
## (estilizada: foto carnet con borde de papel; sin Steam, la silueta). Es un cuadro apoyado en el suelo,
## en unidades de centímetro como el resto de la utilería.

const TEX_SIZE: Vector2i = Vector2i(256, 320)
const WORLD_SIZE: Vector2 = Vector2(40.0, 50.0) ## cm
const TILT_DEG: float = -52.0 ## apoyado inclinado hacia atrás: de frente a la cámara de trabajo

var _viewport: SubViewport
var _canvas: FrameCanvas
var _sprite: Sprite3D


func setup(p_sim: GameSim) -> void:
	name = "EmployeeFrame"
	_viewport = SubViewport.new()
	_viewport.size = TEX_SIZE
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS # el cuadro es chico: se redibuja siempre (así la foto y los textos nunca quedan en blanco)
	add_child(_viewport)
	_canvas = FrameCanvas.new()
	_canvas.sim = p_sim
	_canvas.size = Vector2(TEX_SIZE)
	_viewport.add_child(_canvas)
	_sprite = Sprite3D.new()
	_sprite.texture = _viewport.get_texture()
	_sprite.pixel_size = WORLD_SIZE.x / float(TEX_SIZE.x)
	_sprite.position = sprite_offset()
	_sprite.rotation_degrees = Vector3(TILT_DEG, 0.0, 0.0)
	_sprite.shaded = false
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	add_child(_sprite)


static func sprite_offset() -> Vector3:
	return Vector3(0.0, WORLD_SIZE.y * 0.5 * 0.62, -WORLD_SIZE.y * 0.22)


## Vuelve a dibujar el cuadro (por ejemplo, cuando recibe el sello EX).
func refresh() -> void:
	_canvas.queue_redraw()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


class FrameCanvas extends Control:
	var sim: GameSim
	var _photo_seen: int = -1
	var _photo: ImageTexture ## se arma fuera de _draw (una textura creada dentro de _draw sale en blanco)

	func _process(_delta: float) -> void:
		if PlayerIdentity.photo_version != _photo_seen: # la foto de Steam llega unos frames después del arranque
			_photo_seen = PlayerIdentity.photo_version
			_photo = PlayerIdentity.id_texture(160)
			queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		draw_rect(Rect2(0.0, 0.0, w, h), Color("#5A3A1E")) # marco de madera
		draw_rect(Rect2(10.0, 10.0, w - 20.0, h - 20.0), Color("#F4EFE6"))
		var tt: String = Tx.t("employee_month")
		UiKit.draw_text(self, Vector2(0.0, 52.0), tt, UiKit.font_title(), UiKit.fit_size(UiKit.font_title(), tt, 22, w - 32.0), UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, w)
		if _photo != null:
			draw_texture_rect(_photo, Rect2(48.0, 68.0, 160.0, 160.0), false)
		var nm: String = sim.player_name(Settings.language) if sim != null else ""
		UiKit.draw_text(self, Vector2(0.0, 262.0), nm, UiKit.font_text_bold(), UiKit.fit_size(UiKit.font_text_bold(), nm, 20, w - 36.0), UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, w)
		UiKit.draw_text(self, Vector2(0.0, 292.0), Tx.t("memo_company"), UiKit.font_mono(), 12, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER, w)
		if sim != null and sim.state.ending_done:
			UiKit.draw_stamp(self, Rect2(Vector2(52.0, 104.0), Vector2(152.0, 92.0)), "EX", UiKit.STAMP_RED, 64, -0.3, 0.95)
