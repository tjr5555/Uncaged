shader_type canvas_item;
render_mode blend_add;

uniform vec4 glow_color : source_color = vec4(1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float rainbow : hint_range(0.0, 1.0) = 0.0;

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec2 c = UV - 0.5;
	float d = length(c * vec2(1.0, 1.15));
	float edge = smoothstep(0.3, 0.75, d);
	float ang = atan(c.y, c.x);
	float flicker = 0.8 + 0.2 * sin(TIME * 5.0 + ang * 4.0) * sin(TIME * 3.1 - ang * 2.0);
	vec3 col = mix(glow_color.rgb, hsv2rgb(vec3(fract(ang / 6.2831 + TIME * 0.15), 0.6, 1.0)), rainbow);
	float a = edge * (intensity * 0.35 + pulse * 0.45) * flicker;
	COLOR = vec4(col * a, a);
}