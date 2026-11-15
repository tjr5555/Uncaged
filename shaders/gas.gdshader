shader_type canvas_item;

uniform vec2 world_top_left = vec2(0.0, 0.0);
uniform float world_per_pixel = 1.0;
uniform vec2 screen_size = vec2(1920.0, 1080.0);
uniform vec2 center = vec2(0.0, 0.0);
uniform float radius = 7500.0;
uniform float edge_softness = 450.0;
uniform float gas_depth = 3000.0;
uniform float noise_scale = 900.0;
uniform float drift_speed = 60.0;
uniform vec4 gas_color : source_color = vec4(0.55, 0.25, 0.85, 1.0);
uniform vec4 gas_shade : source_color = vec4(0.25, 0.08, 0.4, 1.0);
uniform float inside : hint_range(0.0, 1.0) = 0.0;
uniform float warn : hint_range(0.0, 1.0) = 0.0;
uniform float pixel_size = 4.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amp * noise(p);
		p *= 2.03;
		amp *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 frag = UV * screen_size;
	if (pixel_size > 1.0) {
		frag = (floor(frag / pixel_size) + 0.5) * pixel_size;
	}
	vec2 world = world_top_left + frag * world_per_pixel;
	vec2 drift = vec2(TIME * drift_speed, TIME * drift_speed * 0.35);
	float n1 = fbm((world + drift) / noise_scale);
	float n2 = fbm((world - drift * 0.7) / (noise_scale * 0.55) + vec2(7.3, 2.1));

	float d = length(world - center) - radius;
	d += (n1 - 0.5) * edge_softness * 1.6;
	float edge = smoothstep(-edge_softness, edge_softness, d);
	float depth = clamp(d / gas_depth, 0.0, 1.0);
	float density = edge * mix(0.35, 0.95, depth) * (0.75 + 0.5 * n2);
	density = max(density, inside * 0.55 * (0.7 + 0.3 * n2));

	float vig = smoothstep(0.45, 0.78, length(UV - 0.5)) * warn * (0.5 + 0.5 * sin(TIME * 5.0)) * 0.35;
	density = max(density, vig);

	vec3 col = mix(gas_shade.rgb, gas_color.rgb, smoothstep(0.2, 0.8, n2));
	COLOR = vec4(col, clamp(density, 0.0, 0.92));
}