shader_type spatial;
// Manitos fantasma, pasada visible: relleno celeste tenue con borde brillante (fresnel).
// Va como next_pass de ghost_depth.gdshader, que antes escribe solo la profundidad: así esta pasada
// dibuja únicamente la cara exterior más cercana. Sin eso se veían los dedos de atrás y el interior
// a través de la mano ("arañas de vidrio"). (depth_prepass_alpha no sirve acá: en Godot 4 solo
// escribe profundidad donde el alfa llega a 0,99.) No proyecta sombra.
render_mode blend_mix, cull_back, unshaded, depth_draw_never, shadows_disabled;

uniform vec3 core_color : source_color = vec3(0.56, 0.82, 0.95);
uniform vec3 rim_color : source_color = vec3(0.90, 0.98, 1.0);
uniform float base_alpha = 0.06; // relleno muy tenue: el contorno celeste da la forma
uniform float rim_alpha = 0.5;
uniform float rim_power = 2.2;

void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	ALBEDO = mix(core_color, rim_color, f);
	ALPHA = clamp(base_alpha + rim_alpha * f, 0.0, 1.0);
}
