shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.45, 0.0, 0.03, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float inner = 0.55;
uniform float outer = 1.35;

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float v = smoothstep(inner, outer, d);
	COLOR = vec4(tint.rgb, v * intensity);
}