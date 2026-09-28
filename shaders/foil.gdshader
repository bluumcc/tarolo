shader_type canvas_item;
// Foil (metálica): faixa de brilho que atravessa a carta.

uniform vec4 tint : source_color = vec4(0.82, 0.95, 1.0, 1.0);
uniform float speed = 0.45;
uniform float width = 0.16;
uniform float strength = 0.45;

void fragment() {
	float t = fract(TIME * speed);
	float d = UV.x + UV.y * 0.6;
	float band = 1.0 - smoothstep(0.0, width, abs(d - (t * 2.4 - 0.4)));
	float sparkle = step(0.985, fract(sin(dot(floor(UV * 40.0), vec2(12.9898, 78.233))) * 43758.5453 + TIME * 0.3));
	COLOR = vec4(tint.rgb, clamp(band * strength + sparkle * 0.25, 0.0, 1.0));
}
