shader_type spatial;
render_mode blend_mix, cull_back, unshaded, depth_draw_never, shadows_disabled;
// Manitos fantasma: celeste translúcido con borde brillante (fresnel). No proyecta sombra.

uniform vec3 core_color : source_color = vec3(0.22, 0.78, 0.9);
uniform vec3 rim_color : source_color = vec3(0.82, 1.0, 1.0);
uniform float base_alpha = 0.2;
uniform float rim_alpha = 0.6;
uniform float rim_power = 2.4;

uniform float cut_z = 0.36; // se corta el antebrazo: las manitos son solo manos
varying float vz;

void vertex() {
	vz = VERTEX.z;
}

void fragment() {
	if (vz > cut_z) {
		discard;
	}
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	ALBEDO = mix(core_color, rim_color, f);
	ALPHA = clamp(base_alpha + rim_alpha * f, 0.0, 1.0);
}
