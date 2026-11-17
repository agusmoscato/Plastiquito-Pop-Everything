shader_type spatial;
// Contorno de las manitos: la misma idea que toon_outline.gdshader, pero en la cola transparente y sin
// escribir profundidad. Va entre la pasada de profundidad (ghost_depth) y la visible (ghost_hand): el
// casco solo pasa la prueba de profundidad fuera de la silueta y queda la línea, sin rellenar la mano.
// (Opaco y como overlay, se dibujaba antes que la mano transparente y la tapaba entera.)
render_mode blend_mix, unshaded, cull_front, depth_draw_never, shadows_disabled, skip_vertex_transform;

uniform vec4 line_color : source_color = vec4(0.12, 0.10, 0.09, 1.0);
uniform float px = 1.6;

void vertex() {
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 view_n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 clip = PROJECTION_MATRIX * view_pos;
	vec2 dir = (PROJECTION_MATRIX * vec4(view_n, 0.0)).xy;
	float len_dir = length(dir);
	if (len_dir > 0.00001) {
		clip.xy += dir / len_dir * px * 2.0 / VIEWPORT_SIZE * clip.w;
	}
	POSITION = clip;
	VERTEX = view_pos.xyz;
	NORMAL = view_n;
}

void fragment() {
	ALBEDO = line_color.rgb;
	ALPHA = line_color.a;
}
