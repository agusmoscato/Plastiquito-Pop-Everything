extends SceneTree
## Informe headless de escala (jornada B3): con la cámara por defecto de cada fase, qué fracción del
## alto de pantalla ocupa cada herramienta y cuánto mide su zona de contacto contra su área de golpe.
## Uso: godot --headless --path . -s tools/tool_scale_report.gd

const PHASE_TOOLS: Dictionary = {1: ["finger", "palm"], 2: ["rolling_pin"], 3: ["iron"], 4: ["boot"]}


func _init() -> void:
	var db: DataDB = DataDB.new()
	db.load_all()
	ToolMeshes.configure(db.juice)
	for phase: int in PHASE_TOOLS:
		var sim: GameSim = GameSim.new(db, 1)
		sim.state.perm["perm_sheet"] = phase - 1
		for id: String in ["unlock_palm", "unlock_pin", "unlock_iron", "unlock_boot"]:
			sim.state.levels[id] = 1
		sim.refresh_stats()
		sim.new_sheet()
		var ext: Vector2 = Vector2(sim.grid.spacing * float(sim.grid.width), sim.grid.row_step * float(sim.grid.height))
		var factor: float = ScenarioDirector.CAMERA_FACTOR[phase - 1]
		var px: float = Cfg.num(db.juice, "camera_min_bubble_px")
		var cap: float = 900.0 / px / (2.0 * tan(deg_to_rad(CameraRig.FOV) * 0.5)) if px > 0.0 else INF
		var d: float = minf(fit_distance(ext * factor), cap) # igual que CameraRig.fit_to + legible_distance
		var view_h: float = 2.0 * d * tan(deg_to_rad(CameraRig.FOV) * 0.5)
		var tools: Array = PHASE_TOOLS[phase]
		for id: String in tools:
			sim.select_tool(id)
			var tm: ToolModel = sim.selected_tool()
			var root: Node3D = ToolMeshes.build(id, tm.radius, 0)
			var box: AABB = ToolMeshes._bounds(root, Transform3D.IDENTITY)
			var p: float = deg_to_rad(CameraRig.PITCH_DEGREES)
			var screen_h: float = box.size.z * sin(p) + box.size.y * cos(p)
			var hit: float = maxf(tm.radius * 2.0, sim.grid.spacing)
			print("fase %d %-12s lámina %3dx%-3d cámara %6.1f  burbuja %4.1f px  herramienta %5.1f%% del alto  (caja %.1f x %.1f x %.1f, golpe %.1f)" % [
				phase, id, sim.grid.width, sim.grid.height, d, 900.0 / view_h, 100.0 * screen_h / view_h, box.size.x, box.size.y, box.size.z, hit])
			root.free()
	quit()


## Misma cuenta que CameraRig.fit_to con pantalla 16:9.
static func fit_distance(extents: Vector2) -> float:
	var tan_half: float = tan(deg_to_rad(CameraRig.FOV) * 0.5)
	var d_x: float = extents.x / (2.0 * tan_half * 16.0 / 9.0)
	var d_y: float = extents.y * sin(deg_to_rad(CameraRig.PITCH_DEGREES)) / (2.0 * tan_half)
	return maxf(d_x, d_y) * 1.3
