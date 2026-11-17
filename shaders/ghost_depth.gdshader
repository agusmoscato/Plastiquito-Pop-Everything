shader_type spatial;
// Manitos fantasma, primera pasada: invisible (alfa 0), solo escribe la profundidad de la cara
// más cercana para que la pasada visible (ghost_hand.gdshader, en next_pass) no muestre el interior.
render_mode blend_mix, cull_back, unshaded, depth_draw_always, shadows_disabled;

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
