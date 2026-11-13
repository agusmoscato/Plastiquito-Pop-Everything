shader_type spatial;
// Burbuja de plástico. Una instancia de MultiMesh por burbuja.
// INSTANCE_CUSTOM: r = presión - 1, g = aplastamiento (0..1),
//                  b = progreso de reventón (0 = entera, 0..1 animando, 1 = reventada),
//                  a = tipo (0 = normal).
// Transparencia: alpha blend + cull_back + depth prepass por el propio domo. Las burbujas
// no se superponen entre sí, así que el orden por instancia no importa (ver CHANGELOG).
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(0.45, 0.75, 1.0, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 2.6;
uniform float base_alpha : hint_range(0.0, 1.0) = 0.17;
uniform float rim_alpha : hint_range(0.0, 1.0) = 0.8;
uniform float popped_alpha : hint_range(0.0, 1.0) = 0.38;
uniform float spec_strength : hint_range(0.0, 2.0) = 1.0;
uniform float inflate_per_pressure = 0.30;
uniform float squash_height = 0.55;
uniform float squash_width = 0.12;
uniform float popped_height = 0.15;
uniform float pop_inflate = 0.10;
uniform float pop_split = 0.53; // fracción de la animación dedicada a inflarse
uniform float wrinkle_strength = 0.55;
uniform float reveal_z = 1.0e9; // las filas con z mayor todavía no aparecieron
uniform float reveal_width = 2.0; // ancho de la "curva" del rollo
uniform float roll_lift = 0.7;
uniform float roll_up_z = -1.0e9; // reciclado: las filas con z menor ya se enrollaron
uniform float crumple : hint_range(0.0, 1.0) = 0.0; // reciclado: la lámina se arruga

varying float v_pressure;
varying float v_squash;
varying float v_pop;
varying float v_type;
varying vec3 v_origin;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	v_pressure = 1.0 + INSTANCE_CUSTOM.r;
	v_squash = INSTANCE_CUSTOM.g;
	v_pop = INSTANCE_CUSTOM.b;
	v_type = INSTANCE_CUSTOM.a;
	v_origin = MODEL_MATRIX[3].xyz;

	float infl = 1.0 + inflate_per_pressure * (v_pressure - 1.0);
	float h = 1.0 - squash_height * v_squash;
	float w = 1.0 + squash_width * v_squash;

	if (v_pop > 0.0) {
		float up = smoothstep(0.0, pop_split, v_pop);
		float down = smoothstep(pop_split, 1.0, v_pop);
		float bump = 1.0 + pop_inflate * up;
		h = mix(h * bump, popped_height, down);
		w = mix(w * bump, 1.12, down);
		infl = mix(infl, 1.0, down);
	}

	// Rollo que se desenrolla: las filas que todavía no llegaron se esconden y
	// las del borde se levantan como si salieran de un cilindro.
	float k = clamp((reveal_z - v_origin.z) / reveal_width, 0.0, 1.0);
	float visible_scale = smoothstep(0.0, 0.25, k);
	float lift = (1.0 - k) * roll_lift;
	float k2 = clamp((v_origin.z - roll_up_z) / reveal_width, 0.0, 1.0);
	visible_scale *= smoothstep(0.0, 0.25, k2);
	lift += (1.0 - k2) * roll_lift;
	// Burbujas especiales: las dibuja SpecialsView mientras estén enteras.
	float hidden = step(0.5, v_type) * (1.0 - step(0.001, v_pop));
	visible_scale *= 1.0 - hidden;
	// Arrugado: se achican y se desparraman en altura de forma desigual.
	float h1 = hash21(v_origin.xz * 3.17);
	float h2 = hash21(v_origin.xz * 1.93 + 5.0);
	w *= 1.0 - 0.3 * crumple * h1;
	h *= 1.0 + 1.1 * crumple * (h2 - 0.3);

	VERTEX.xz *= w * infl * visible_scale;
	VERTEX.y *= h * infl * visible_scale;
	VERTEX.y += lift * visible_scale;

	// La normal se corrige con la inversa de la escala para que el achatado se vea bien.
	NORMAL = normalize(vec3(NORMAL.x / (w * infl + 0.0001), NORMAL.y / (h * infl + 0.0001), NORMAL.z / (w * infl + 0.0001)));
}

void fragment() {
	vec3 n = normalize(NORMAL);
	float popped = smoothstep(0.75, 1.0, v_pop);

	// Arrugas del plástico reventado: ruido en las normales.
	if (popped > 0.0) {
		vec2 q = v_origin.xz * 7.3 + UV * 5.0 + vec2(v_origin.x * 3.1, v_origin.z * 1.7);
		float nx = vnoise(q * 2.0) - 0.5;
		float nz = vnoise(q * 2.0 + 17.0) - 0.5;
		float fine = vnoise(q * 6.0 + 3.0) - 0.5;
		n = normalize(n + popped * wrinkle_strength * vec3(nx + fine * 0.5, 0.0, nz - fine * 0.5) * 2.0);
	}

	float ndv = clamp(dot(n, normalize(VIEW)), 0.0, 1.0);
	float fres = pow(1.0 - ndv, rim_power);
	float tense = smoothstep(1.3, 1.9, v_pressure);

	vec3 col = tint.rgb * (1.0 + 0.35 * tense);
	ALBEDO = col;
	ROUGHNESS = mix(0.12, 0.3, popped);
	SPECULAR = spec_strength;
	METALLIC = 0.0;
	EMISSION = col * (fres * 0.5 + tense * 0.12);
	NORMAL = n;

	float a = mix(base_alpha, rim_alpha, fres);
	a = mix(a, max(a, popped_alpha), popped);
	a += tense * 0.12;
	ALPHA = clamp(a, 0.0, 1.0);
}
