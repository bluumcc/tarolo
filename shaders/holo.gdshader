shader_type canvas_item;
// Polychrome (holográfica): arco-íris em movimento com listras finas.

uniform float strength = 0.32;

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	float h = fract(UV.x * 0.8 + UV.y * 0.5 + TIME * 0.15);
	vec3 col = hsv2rgb(vec3(h, 0.65, 1.0));
	float stripes = 0.5 + 0.5 * sin((UV.x - UV.y) * 42.0 + TIME * 2.0);
	COLOR = vec4(col, strength * (0.55 + 0.45 * stripes));
}
