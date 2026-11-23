shader_type spatial;
// Burbuja de plástico. Una instancia de MultiMesh por burbuja.
// INSTANCE_CUSTOM: r = presión - 1, g = aplastamiento (0..1),
//                  b = progreso de reventón (0 = entera, 0..1 animando, 1 = reventada),
//                  a = tipo (0 = normal) + 0,25 si tiene doble film.
// Transparencia: alpha blend + cull_back + depth prepass por el propio domo. Las burbujas
// no se superponen entre sí, así que el orden por instancia no importa (ver CHANGELOG).
// Sesión 4: se parece a un papel de burbujas de verdad: plástico transparente apenas celeste, brillos
// chicos y nítidos (el reflejo de una ventana y uno más chico), el borde que se ve más blanco por
// mirar el plástico de costado y el aro soldado donde el domo se pega al film.
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(0.66, 0.85, 0.98, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 2.2;
uniform float base_alpha : hint_range(0.0, 1.0) = 0.16; // el centro del domo casi no se ve: es transparente
uniform float rim_alpha : hint_range(0.0, 1.0) = 0.85;
uniform float glint_strength : hint_range(0.0, 3.0) = 1.4; // reflejos nítidos de la ventana
uniform float seam_alpha : hint_range(0.0, 1.0) = 0.42; // el aro soldado de la base
uniform vec3 edge_color : source_color = vec3(0.2, 0.32, 0.47); // contorno del domo: lo que se lee de lejos (0.7.3)
uniform float edge_strength : hint_range(0.0, 1.0) = 0.7;
uniform float edge_alpha : hint_range(0.0, 1.0) = 0.75;
uniform float popped_alpha : hint_range(0.0, 1.0) = 0.2; // reventadas: apagadas, para que la vista vaya a las enteras
uniform float spec_strength : hint_range(0.0, 2.0) = 1.3;
uniform float inflate_per_pressure = 0.30;
uniform float squash_height = 0.55;
uniform float squash_width = 0.12;
uniform float popped_height = 0.15;
uniform float pop_inflate = 0.10;
uniform float pop_split = 0.53; // fracción de la animación dedicada a inflarse
uniform float wrinkle_strength = 0.3;
uniform float reveal_z = 1.0e9; // las filas con z mayor todavía no aparecieron
uniform float reveal_width = 2.0; // ancho de la "curva" del rollo
uniform float roll_lift = 0.7;
uniform float roll_up_z = -1.0e9; // reciclado: las filas con z menor ya se enrollaron
uniform float crumple : hint_range(0.0, 1.0) = 0.0; // reciclado: la lámina se arruga
uniform vec2 hover_pos = vec2(1.0e9); // (x, z) de la herramienta: las burbujas que alcanza se iluminan apenas
uniform float hover_radius = 0.0;

varying float v_pressure;
varying float v_squash;
varying float v_pop;
varying float v_type;
varying float v_armor;
varying float v_mat;
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
	float fa = fract(INSTANCE_CUSTOM.a);
	v_armor = step(0.2, fa) * step(fa, 0.3);
	v_mat = step(0.35, fa) * (1.0 + step(0.5, fa) + step(0.65, fa)); // 1 térmico, 2 fría, 3 pesada
	v_type = floor(INSTANCE_CUSTOM.a + 0.01);
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

	vec3 col = tint.rgb * (1.0 + 0.3 * tense);
	// Reventada: plástico arrugado y opaco, gris, sin brillo (para que la vista vaya a las enteras).
	vec3 spent = mix(col, vec3(dot(col, vec3(0.3, 0.59, 0.11))), 0.65) * 0.8;
	col = mix(col, spent, popped);
	// Reflejos nítidos: una "ventana" grande y un punto chico, fijos respecto de la cámara (como en
	// las fotos de papel de burbujas). Se calculan en espacio de vista con el reflejo de la normal.
	vec3 r = reflect(-normalize(VIEW), n);
	float win = smoothstep(0.90, 0.955, dot(r, normalize(vec3(-0.45, 0.62, 0.64))));
	float dot2 = smoothstep(0.975, 0.99, dot(r, normalize(vec3(0.35, 0.3, 0.89))));
	float glint = (win + dot2 * 0.8) * (1.0 - popped);
	// El aro soldado de la base: una línea más blanca donde el domo se pega al film (UV.y = 1 es la base).
	float seam = smoothstep(0.72, 0.98, UV.y) * (1.0 - popped * 0.6);
	ALBEDO = mix(col, vec3(0.92, 0.97, 1.0), seam * 0.5);
	// Contorno: el borde de afuera del domo, más oscuro. A 200 px cada burbuja es un circulito marcado.
	float edge = smoothstep(0.7, 0.9, UV.y) * (1.0 - popped * 0.75);
	ALBEDO = mix(ALBEDO, edge_color, edge * edge_strength);
	// Doble film: plástico lechoso y grueso, con un segundo aro (hay que aplastarla dos veces).
	float ring2 = smoothstep(0.35, 0.45, UV.y) * (1.0 - smoothstep(0.45, 0.55, UV.y));
	ALBEDO = mix(ALBEDO, vec3(0.93, 0.95, 0.97), v_armor * (0.55 + 0.35 * ring2) * (1.0 - popped));
	// Materiales: térmico = naranja ceniza opaco, fría = azul escarcha, pesada = gris oscuro grueso.
	vec3 mat_col = v_mat > 2.5 ? vec3(0.34, 0.36, 0.40) : (v_mat > 1.5 ? vec3(0.62, 0.80, 1.0) : vec3(0.95, 0.62, 0.30));
	ALBEDO = mix(ALBEDO, mat_col, step(0.5, v_mat) * (0.55 + 0.3 * ring2) * (1.0 - popped));
	// Veta de aire: las casi llenas laten suave (se ve por dónde va a correr la cadena).
	float vein = smoothstep(1.8, 1.92, v_pressure) * (1.0 - popped);
	float beat = 0.6 + 0.4 * sin(TIME * 4.0 + v_origin.x * 0.7 + v_origin.z * 0.5);
	ALBEDO = mix(ALBEDO, vec3(1.0, 0.72, 0.38), vein * 0.7); // ámbar: se ve el camino de la cadena
	ROUGHNESS = mix(0.06, 0.65, popped);
	SPECULAR = spec_strength * 0.7 * (1.0 - 0.8 * popped);
	METALLIC = 0.0;
	EMISSION = col * (fres * 0.45 * (1.0 - 0.8 * popped) + tense * 0.12) + vec3(1.0) * glint * glint_strength;
	NORMAL = n;

	// Lo que va a reventar: brillo suave bajo la herramienta (solo burbujas enteras).
	float hv = (1.0 - smoothstep(hover_radius * 0.75, hover_radius, distance(v_origin.xz, hover_pos))) * (1.0 - popped);
	EMISSION += vec3(0.16, 0.2, 0.22) * hv;
	EMISSION += vec3(0.95, 0.55, 0.18) * vein * beat;

	float a = mix(base_alpha, rim_alpha, fres);
	a = max(a, seam * seam_alpha);
	a = max(a, edge * edge_alpha);
	a = mix(a, 0.72, v_armor * (1.0 - popped));
	a = mix(a, 0.82, step(0.5, v_mat) * (1.0 - popped));
	a = mix(a, max(a, 0.66), vein); // el plástico es casi transparente: sin esto el ámbar no se veía
	a = max(a, glint * 0.9);
	a += 0.12 * hv;
	a = mix(a, popped_alpha, popped);
	a += tense * 0.12;
	ALPHA = clamp(a, 0.0, 1.0);
}
