shader_type spatial;
// Contorno de juguete (casco invertido): se dibuja como material_overlay de la mano, las herramientas y
// las manitos. Expande la malla en espacio de pantalla, así el borde mide `px` píxeles a cualquier
// distancia, y solo se ven sus caras traseras (cull_front): queda una línea oscura alrededor de la
// silueta. Es lo que más ayuda a leer los modelos a tamaño chico.
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, skip_vertex_transform;

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
}
