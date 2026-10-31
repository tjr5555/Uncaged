shader_type canvas_item;

uniform float shimmer_strength : hint_range(0.0, 1.0) = 0.0;
uniform float sparkle_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 shine_color : source_color = vec4(1.0);
uniform float sweep_interval = 2.6;
uniform float sweep_width = 10.0;
uniform float sparkle_density = 0.08;
uniform float pulse_strength = 0.12;

varying vec2 local_pos;
varying float phase;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	local_pos = VERTEX;
	vec2 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	phase = hash(floor(origin));
}

void fragment() {
	vec4 base = COLOR;

	float cycle = fract(TIME / sweep_interval + phase);
	float center = mix(-90.0, 140.0, cycle);
	float diagonal = local_pos.x + local_pos.y;
	float band = 1.0 - smoothstep(0.0, sweep_width, abs(diagonal - center));

	float pulse = 1.0 + sin(TIME * 2.5 + phase * 6.283) * pulse_strength * shimmer_strength;

	vec2 cell = floor(local_pos / 5.0);
	float r1 = hash(cell + phase * 100.0);
	float r2 = hash(cell * 1.37 + 4.1 + phase);
	vec2 f = fract(local_pos / 5.0) - 0.5;
	float shape = smoothstep(0.5, 0.0, length(f));
	float twinkle = pow(max(0.0, sin(TIME * (2.0 + r1 * 3.0) + r1 * 6.283)), 24.0);
	float sparkle = twinkle * shape * step(1.0 - sparkle_density, r2);

	vec3 col = base.rgb * pulse;
	col += shine_color.rgb * band * shimmer_strength * 0.55;
	col += shine_color.rgb * sparkle * sparkle_strength;
	COLOR = vec4(col, base.a);
}