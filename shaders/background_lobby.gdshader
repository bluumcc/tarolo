shader_type canvas_item;

uniform vec4 top_color    : source_color = vec4(0.05, 0.02, 0.15, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.02, 0.01, 0.07, 1.0);
uniform vec4 accent_purple: source_color = vec4(0.35, 0.05, 0.80, 1.0);
uniform vec4 accent_red   : source_color = vec4(0.90, 0.08, 0.25, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;

	// Gradiente base
	vec3 base = mix(top_color.rgb, bottom_color.rgb, pow(uv.y, 1.3));

	// Halo roxo central-superior (onde fica o emblema)
	float cd = distance(uv, vec2(0.5, 0.28));
	base += accent_purple.rgb * exp(-cd * cd * 4.5) * 0.45;

	// Brilho vermelho nas bordas inferiores
	float bl = distance(uv, vec2(0.05, 1.0));
	float br = distance(uv, vec2(0.95, 1.0));
	float bc = distance(uv, vec2(0.50, 1.05));
	float red = exp(-bl*bl*5.0) + exp(-br*br*5.0) + exp(-bc*bc*3.5) * 0.6;
	base += accent_red.rgb * red * 0.22;

	// Linha horizontal suave no meio (separação visual)
	float line = exp(-pow(uv.y - 0.58, 2.0) * 400.0) * 0.06;
	base += accent_red.rgb * line;

	// Vignette
	float vign = 1.0 - dot(uv - 0.5, uv - 0.5) * 1.3;
	base *= max(vign, 0.25);

	// Grain
	float grain = hash(uv + fract(TIME * 0.07)) * 0.022;
	base += grain;

	COLOR = vec4(clamp(base, 0.0, 1.0), 1.0);
}
