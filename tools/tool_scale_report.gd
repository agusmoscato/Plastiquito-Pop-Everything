extends SceneTree
## Informe headless de la cámara de trabajo (DESIGN 5): para la lámina inicial y la más grande de cada
## fase, a qué distancia queda la cámara, cuánto mide una burbuja, cuánto del área de juego llena la
## lámina y si la cámara sigue a la herramienta. El tamaño de la herramienta en pantalla lo fija
## ToolView con `tool_screen_fraction` (se informa el valor de datos).
## Uso: godot --headless --path . -s tools/tool_scale_report.gd

const FOV: float = 40.0 ## = CameraRig.FOV (CameraRig usa autoloads: no se carga con -s)
const PITCH: float = 55.0 ## = CameraRig.PITCH_DEGREES
const ASPECT: float = 16.0 / 9.0


func _init() -> void:
	var db: DataDB = DataDB.new()
	db.load_all()
	var fill: float = Cfg.num(db.juice, "camera_sheet_fill")
	var play: float = Cfg.num(db.juice, "camera_play_area")
	var min_px: float = Cfg.num(db.juice, "camera_min_bubble_px")
	var frac: Dictionary = db.juice["tool_screen_fraction"]
	var sizes: Array = [[1, 8, 8], [1, 20, 20], [2, 40, 40], [3, 80, 80], [4, 150, 150]]
	for row: Array in sizes:
		var ph: int = row[0]
		var w: float = row[1]
		var hh: float = row[2]
		var plan: Vector2 = work_plan(Vector2(w, hh * 0.866), play, fill, min_px)
		var view_w: float = 2.0 * plan.x * tan(deg_to_rad(FOV) * 0.5) * ASPECT
		var filled: float = minf(1.0, w / (view_w * play))
		print("fase %d lámina %3dx%-3d cámara %6.1f  burbuja %5.1f px  llena %3.0f%% del área de juego  %s" % [
			ph, int(w), int(hh), plan.x, bubble_px(plan.x), filled * 100.0, "sigue a la herramienta" if plan.y > 0.5 else "lámina entera"])
	var hand_f: float = frac.get("finger", 0.0)
	var other_f: float = frac.get("default", 0.0)
	print("herramientas: mano (dedo y palma) %.0f %% del alto, el resto %.0f %% (ToolView, tool_screen_fraction)" % [hand_f * 100.0, other_f * 100.0])
	quit()


## Misma cuenta que CameraRig.work_plan.
static func work_plan(e: Vector2, play: float, fill: float, min_px: float) -> Vector2:
	var t: float = tan(deg_to_rad(FOV) * 0.5)
	var d: float = maxf(e.x / (fill * play * 2.0 * t * ASPECT), e.y * sin(deg_to_rad(PITCH)) / (2.0 * t) * 1.15)
	if bubble_px(d) >= min_px:
		return Vector2(d, 0.0)
	return Vector2(900.0 / min_px / (2.0 * t), 1.0)


static func bubble_px(d: float) -> float:
	return 900.0 / (2.0 * d * tan(deg_to_rad(FOV) * 0.5))
