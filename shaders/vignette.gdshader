shader_type canvas_item;
// Viñeta sutil y cálida en los bordes: centra la vista en la lámina. Va por debajo del HUD.
uniform float strength = 0.32;
uniform vec4 tint : source_color = vec4(0.16, 0.09, 0.04, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV - 0.5;
	uv.x *= 1.25;
	float d = smoothstep(0.42, 0.95, length(uv) * 1.35);
	COLOR = vec4(tint.rgb, d * strength);
}
