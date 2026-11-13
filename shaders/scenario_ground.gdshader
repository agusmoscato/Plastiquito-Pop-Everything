shader_type spatial;
// Piso de los escenarios, todo procedural: 1 madera, 2 baldosas en damero con luz de persiana,
// 3 hormigón con manchas, 4 asfalto con líneas pintadas. Se mezclan dos tipos (kind_a -> kind_b)
// para que la transición entre escenarios no tenga cortes.
render_mode cull_back;

uniform int kind_a = 1;
uniform int kind_b = 1;
uniform float blend : hint_range(0.0, 1.0) = 0.0;

varying vec3 wpos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec3 wood(vec2 p, out float rough) {
	float plank_w = 2.6;
	float id = floor(p.y / plank_w);
	float off = hash21(vec2(id, 3.0)) * 40.0;
	float grain = fbm(vec2((p.x + off) * 0.3, p.y * 5.0));
	float rings = sin((p.y + grain * 1.6) * 9.0 + off) * 0.5 + 0.5;
	vec3 dark = vec3(0.30, 0.18, 0.10);
	vec3 light = vec3(0.60, 0.40, 0.22);
	vec3 col = mix(dark, light, clamp(grain * 0.9 + rings * 0.35, 0.0, 1.0));
	col *= 0.9 + 0.2 * hash21(vec2(id, 7.0)); // cada tabla un poco distinta
	float seam = smoothstep(0.0, 0.03, fract(p.y / plank_w)) * smoothstep(0.0, 0.03, 1.0 - fract(p.y / plank_w));
	float joint = smoothstep(0.0, 0.01, fract((p.x + off) / 14.0)) ;
	rough = 0.55;
	return col * (0.35 + 0.65 * seam) * (0.8 + 0.2 * joint);
}

vec3 tiles(vec2 p, out float rough) {
	float size = 3.2;
	vec2 q = p / size;
	float checker = mod(floor(q.x) + floor(q.y), 2.0);
	vec3 a = vec3(0.80, 0.76, 0.66);
	vec3 b = vec3(0.36, 0.46, 0.44);
	float px = fwidth(q.x) + fwidth(q.y); // tamaño de baldosa en píxeles: de lejos se promedia
	float far_k = smoothstep(0.35, 0.9, px);
	vec3 col = mix(mix(a, b, checker), (a + b) * 0.5, far_k);
	col *= 0.93 + 0.14 * vnoise(p * 3.0) * (1.0 - far_k);
	vec2 f = fract(q);
	float grout = smoothstep(0.0, 0.025, f.x) * smoothstep(0.0, 0.025, 1.0 - f.x) * smoothstep(0.0, 0.025, f.y) * smoothstep(0.0, 0.025, 1.0 - f.y);
	col = mix(vec3(0.22, 0.21, 0.19), col, mix(grout, 1.0, far_k));
	// Sombras de persiana: franjas diagonales de luz de ventana.
	float s = sin((p.x * 0.8 + p.y * 0.55) * 0.9);
	float lit = mix(smoothstep(-0.12, 0.12, s), 0.5, far_k);
	col *= mix(0.6, 1.08, lit);
	rough = 0.3;
	return col;
}

vec3 concrete(vec2 p, out float rough) {
	float n = fbm(p * 0.22);
	float fine = vnoise(p * 6.0);
	vec3 col = vec3(0.36, 0.37, 0.4) * (0.8 + 0.4 * n) * (0.94 + 0.1 * fine);
	float stain = smoothstep(0.62, 0.8, fbm(p * 0.09 + 11.0));
	col = mix(col, vec3(0.2, 0.2, 0.22), stain * 0.6); // manchas de aceite
	vec2 j = abs(fract(p / 13.0) - 0.5);
	float joint = smoothstep(0.485, 0.5, max(j.x, j.y));
	col *= 1.0 - 0.45 * joint; // juntas de dilatación
	rough = 0.8;
	return col;
}

vec3 asphalt(vec2 p, out float rough) {
	float n = fbm(p * 0.35);
	float speck = step(0.8, hash21(floor(p * 9.0))) * (1.0 - smoothstep(0.4, 1.2, fwidth(p.x) * 9.0));
	vec3 col = vec3(0.09, 0.09, 0.105) * (0.8 + 0.5 * n) + speck * 0.05;
	// Líneas de estacionamiento: rayas separadas y una línea larga de demarcación.
	float col_x = abs(fract(p.x / 6.5) - 0.5) * 6.5;
	float stall = smoothstep(0.26, 0.2, col_x) * step(0.0, sin(p.y * 0.04 + 1.0));
	float band = smoothstep(0.22, 0.16, abs(mod(p.y, 38.0) - 19.0));
	float paint = max(stall, band);
	float wear = smoothstep(0.08, 0.4, fbm(p * 0.7 + 3.0));
	col = mix(col, vec3(0.86, 0.84, 0.74), paint * wear);
	rough = 0.9;
	return col;
}

vec3 ground(int kind, vec2 p, out float rough) {
	if (kind == 2) {
		return tiles(p, rough);
	} else if (kind == 3) {
		return concrete(p, rough);
	} else if (kind == 4) {
		return asphalt(p, rough);
	}
	return wood(p, rough);
}

void fragment() {
	float ra;
	float rb;
	vec3 ca = ground(kind_a, wpos.xz, ra);
	vec3 cb = ca;
	rb = ra;
	if (blend > 0.001 && kind_b != kind_a) {
		cb = ground(kind_b, wpos.xz, rb);
	}
	ALBEDO = mix(ca, cb, blend);
	ROUGHNESS = mix(ra, rb, blend);
	SPECULAR = 0.35;
}
