shader_type spatial;
// Dibujo de lejos: un plano por bloque de 64x64 celdas que dibuja las burbujas desde la textura
// de estado (1 píxel por burbuja, ver StatePacker). Los domos son falsos: la celda se calcula con
// matemática hexagonal en el fragmento y la normal y el brillo salen de la posición dentro del domo.
// R = presión/2, G = aplastamiento, B = progreso de reventón, A = tipo*32.
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

uniform sampler2D state_tex : filter_linear_mipmap, repeat_disable;
uniform float chunk_q0 = 0.0;
uniform float chunk_r0 = 0.0;
uniform float chunk_w = 64.0;
uniform float chunk_h = 64.0;
uniform float spacing = 1.0;
uniform float hex_size = 0.577;
uniform float row_step = 0.866;
uniform float bubble_r = 0.47;
uniform vec4 tint : source_color = vec4(0.45, 0.75, 1.0, 1.0);
uniform float base_alpha : hint_range(0.0, 1.0) = 0.2;
uniform float rim_alpha : hint_range(0.0, 1.0) = 0.8;
uniform float popped_alpha : hint_range(0.0, 1.0) = 0.38;
uniform float reveal_z = 1.0e9;
uniform float fade : hint_range(0.0, 1.0) = 1.0; // fundido cerca/lejos (lo maneja SheetView por bloque)

varying vec3 v_world;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 wp = v_world.xz;
	// Cuántos píxeles ocupa una celda: si son pocos, se dibuja un color plano promedio (mipmap de la
	// textura de estado) en vez de domos, para que no haya moiré a lo lejos.
	float wpp = max(length(dFdx(wp)), length(dFdy(wp)));
	float px_per_cell = spacing / max(wpp, 0.00001);
	float flat_k = smoothstep(4.5, 2.2, px_per_cell);
	vec4 avg = vec4(0.0);
	if (flat_k > 0.0) {
		vec2 cpos = vec2(wp.x / spacing - chunk_q0 + 0.5, wp.y / row_step - chunk_r0 + 0.5);
		vec2 uvq = clamp(cpos / vec2(chunk_w, chunk_h), vec2(0.0), vec2(1.0));
		avg = textureLod(state_tex, uvq, log2(max(1.0, 3.0 / px_per_cell * 3.0)));
		if (cpos.x < -0.5 || cpos.y < -0.5 || cpos.x > chunk_w + 0.5 || cpos.y > chunk_h + 0.5 || wp.y > reveal_z) {
			discard;
		}
	}
	// Celda bajo el punto (hexágonos pointy-top, filas desplazadas odd-r).
	float qf = (0.5773502692 * wp.x - wp.y / 3.0) / hex_size;
	float rf = (2.0 / 3.0) * wp.y / hex_size;
	float xf = qf;
	float zf = rf;
	float yf = -xf - zf;
	float rx = floor(xf + 0.5);
	float ry = floor(yf + 0.5);
	float rz = floor(zf + 0.5);
	float dx = abs(rx - xf);
	float dy = abs(ry - yf);
	float dz = abs(rz - zf);
	if (dx > dy && dx > dz) {
		rx = -ry - rz;
	} else if (dy > dz) {
		ry = -rx - rz;
	} else {
		rz = -rx - ry;
	}
	float row = rz;
	float odd = mod(abs(row), 2.0);
	float col = rx + (row - odd) * 0.5;
	vec2 local = vec2(col - chunk_q0, row - chunk_r0);
	if (local.x < 0.0 || local.y < 0.0 || local.x >= chunk_w || local.y >= chunk_h || wp.y > reveal_z) {
		discard;
	}
	vec4 s = texelFetch(state_tex, ivec2(local), 0);
	float pressure = s.r * 2.0;
	float squash = s.g;
	float pop = s.b;
	int type_id = int(floor(s.a * 255.0 / 32.0 + 0.5));
	vec2 center = vec2(spacing * (col + 0.5 * odd), row_step * row);
	bool popped = pop > 0.5;

	float infl = popped ? 1.12 : 1.0 + 0.3 * (pressure - 1.0);
	vec2 d = (wp - center) / (bubble_r * infl * (1.0 + 0.12 * squash));
	float rr = dot(d, d);
	if (rr > 1.0 && flat_k < 0.01) {
		discard;
	}
	float height = popped ? 0.15 : 0.8 * (1.0 - 0.55 * squash);
	float nz = sqrt(max(1.0 - rr, 0.0));
	vec3 nw = normalize(vec3(d.x, nz * 0.9 / max(height, 0.05) * 0.6, d.y));
	float tense = smoothstep(1.3, 1.9, pressure);

	vec3 col_rgb = tint.rgb * (1.0 + 0.35 * tense);
	float a;
	float rough = 0.12;
	if (popped) {
		float n1 = hash21(floor(wp * 9.0)) - 0.5;
		float n2 = hash21(floor(wp * 9.0) + 17.0) - 0.5;
		nw = normalize(vec3(nw.x * 0.35 + n1 * 0.7, 1.0, nw.z * 0.35 + n2 * 0.7));
		a = popped_alpha;
		rough = 0.3;
	} else {
		float ndv0 = clamp(nz, 0.0, 1.0);
		a = mix(rim_alpha, base_alpha, pow(ndv0, 0.5)) + tense * 0.12;
	}
	vec3 emis = vec3(0.0);
	// Especiales: color y forma simplificada (la dorada brilla, la bomba lleva un punto, la línea bandas).
	if (!popped && type_id > 0) {
		if (type_id == 1) {
			col_rgb = vec3(0.95, 0.78, 0.25);
			emis = col_rgb * 0.6;
			a = 0.95;
		} else if (type_id == 2) {
			col_rgb = mix(vec3(0.17, 0.16, 0.2), vec3(1.0, 0.45, 0.12), step(rr, 0.06));
			a = 0.95;
		} else if (type_id == 3) {
			float band = step(0.5, fract(d.x * 1.5 + 0.5));
			col_rgb = mix(vec3(0.18, 0.72, 0.8), vec3(0.95, 0.95, 0.9), band * 0.6);
			a = 0.95;
		} else if (type_id == 4) {
			col_rgb = mix(vec3(0.5, 0.9, 0.7), vec3(1.0, 1.0, 0.8), smoothstep(0.6, 1.0, rr));
			emis = vec3(0.1, 0.25, 0.15);
			a = 0.9;
		}
	}
	if (rr > 1.0) {
		a = 0.0;
	}
	if (flat_k > 0.0) {
		vec3 flat_col = mix(vec3(0.46, 0.55, 0.66), vec3(0.55, 0.72, 0.9), avg.b);
		float flat_a = 0.95;
		col_rgb = mix(col_rgb, flat_col, flat_k);
		a = mix(a, flat_a, flat_k);
		nz = mix(nz, 1.0, flat_k);
		rough = mix(rough, 0.7, flat_k);
		nw = normalize(mix(nw, vec3(0.0, 1.0, 0.0), flat_k));
	}
	ALBEDO = col_rgb;
	ROUGHNESS = rough;
	SPECULAR = mix(1.0, 0.25, flat_k);
	EMISSION = emis + col_rgb * (1.0 - nz) * 0.4;
	vec3 nview = (VIEW_MATRIX * vec4(nw, 0.0)).xyz;
	NORMAL = dot(nview, nview) > 0.0001 ? normalize(nview) : vec3(0.0, 0.0, 1.0);
	ALPHA = clamp(a, 0.0, 1.0) * fade;
}
