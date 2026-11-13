shader_type canvas_item;
// Grano de cartón y papel generado por código. Se aplica sobre dibujos con _draw():
// multiplica el color por fibras horizontales, grano fino y manchas suaves.
// Usa FRAGCOORD (ruido fijo en pantalla), así que todo el HUD comparte el mismo "cartón".

uniform float grain : hint_range(0.0, 0.3) = 0.07;
uniform float fibers : hint_range(0.0, 0.3) = 0.06;
uniform float blotch : hint_range(0.0, 0.3) = 0.05;
uniform float corrugated : hint_range(0.0, 0.3) = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = FRAGCOORD.xy;
	float g = vnoise(p * 0.9) - 0.5;
	float f = vnoise(vec2(p.x * 0.035, p.y * 0.9)) - 0.5;
	float b = vnoise(p * 0.012) - 0.5;
	float c = sin(p.x * 0.55) * 0.5;
	float k = 1.0 + g * grain * 2.0 + f * fibers * 2.0 + b * blotch * 2.0 + c * corrugated;
	COLOR.rgb *= k;
}
