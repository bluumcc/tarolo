shader_type canvas_item;
// Fundo atmosférico: gradiente azul-noite -> roxo fosco com grão e vinheta.

uniform vec4 top_color : source_color = vec4(0.043, 0.063, 0.149, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.102, 0.067, 0.157, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float wave = 0.04 * sin(uv.x * 3.0 + TIME * 0.2);
	vec3 col = mix(top_color.rgb, bottom_color.rgb, clamp(uv.y + wave, 0.0, 1.0));
	float d = distance(uv, vec2(0.5, 0.55));
	col *= 1.0 - smoothstep(0.35, 0.95, d) * 0.65;
	col += (hash(uv * 800.0 + fract(TIME)) - 0.5) * 0.025;
	COLOR = vec4(col, 1.0);
}
