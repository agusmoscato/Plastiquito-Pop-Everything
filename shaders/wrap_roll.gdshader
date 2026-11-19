shader_type spatial;
// Rollo de papel de burbujas: muchas vueltas de film transparente, así que se ve lechoso. Las
// burbujas son un patrón hexagonal sobre la superficie del cilindro (UV.x da la vuelta, UV.y va a lo
// largo), del mismo tamaño que las de la lámina, con su brillo y el aro donde la burbuja toca el film.
render_mode cull_back, depth_draw_always, specular_schlick_ggx;

uniform vec3 film : source_color = vec3(0.70, 0.86, 0.96);
uniform float around = 40.0; // burbujas en una vuelta
uniform float along = 20.0; // filas a lo largo del rollo
uniform float glow = 0.0; // 0..1: "tirá de acá" (lámina terminada, sin recarga automática)

void fragment() {
	vec2 g = vec2(UV.x * around, UV.y * along);
	float row = floor(g.y);
	g.x += mod(row, 2.0) * 0.5;
	vec2 f = fract(g) - 0.5;
	float d = length(f);
	float aa = fwidth(d) * 1.5;
	float dome = 1.0 - smoothstep(0.36 - aa, 0.36 + aa, d);
	float seam = smoothstep(0.30, 0.36, d) * dome; // el aro donde la burbuja se pega al film
	float shine = 1.0 - smoothstep(0.03, 0.12, length(f - vec2(-0.11, -0.12)));
	vec3 base = mix(film * 0.78, film, dome);
	base = mix(base, film * 1.15, seam * 0.6);
	ALBEDO = base;
	ROUGHNESS = mix(0.45, 0.12, dome);
	SPECULAR = 0.6;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	EMISSION = vec3(1.0) * (shine * dome * 0.55) + film * (fres * 0.25 + glow * 0.35);
	ALPHA = clamp(mix(0.78, 0.9, dome) + fres * 0.1, 0.0, 1.0);
}
