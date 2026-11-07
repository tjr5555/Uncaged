shader_type canvas_item;

uniform vec2 camera_pos = vec2(0.0, 0.0);
uniform vec2 screen_size = vec2(1920.0, 1080.0);

uniform vec4 top_color : source_color = vec4(0.26, 0.5, 0.92, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.62, 0.76, 0.92, 1.0);
uniform float horizon_start : hint_range(0.0, 1.0) = 0.45;
uniform float horizon_strength : hint_range(0.0, 1.0) = 0.7;
uniform vec4 high_color : source_color = vec4(0.16, 0.3, 0.62, 1.0);
uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cloud_shade : source_color = vec4(0.78, 0.84, 0.94, 1.0);

uniform float altitude_range = 20000.0;
uniform float cloud_amount : hint_range(0.0, 1.0) = 0.5;
uniform float cloud_opacity : hint_range(0.0, 1.0) = 1.0;
uniform float cloud_scale = 900.0;
uniform vec3 parallax = vec3(0.08, 0.18, 0.35);
uniform vec2 wind = vec2(40.0, 0.0);
uniform float pixel_size = 3.0;

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

vec2 cloud_layer(vec2 offset, float par, float scale_mult, float seed, float t) {
	vec2 pos = camera_pos * par + offset + wind * t * par;
	vec2 p = pos / (cloud_scale * scale_mult);
	p.y *= 2.2;
	float n = fbm(p + vec2(seed, seed * 1.7));
	float threshold = mix(0.78, 0.42, cloud_amount);
	return vec2(smoothstep(threshold, threshold + 0.16, n), smoothstep(threshold, threshold + 0.4, n));
}

void fragment() {
	vec2 frag = UV * screen_size;
	if (pixel_size > 1.0) {
		frag = (floor(frag / pixel_size) + 0.5) * pixel_size;
	}
	vec2 offset = frag - screen_size * 0.5;
	vec2 uv = frag / screen_size;

	float altitude = clamp(-camera_pos.y / altitude_range, -1.0, 1.0);
	float horizon = smoothstep(horizon_start, 1.0, uv.y) * horizon_strength;
	vec3 col = mix(top_color.rgb, horizon_color.rgb, horizon);
	col = mix(col, high_color.rgb, max(altitude, 0.0) * (1.0 - uv.y * 0.5));
	col = mix(col, horizon_color.rgb, max(-altitude, 0.0) * 0.4 * horizon_strength);

	vec2 far_c = cloud_layer(offset, parallax.x, 0.7, 3.1, TIME);
	vec3 far_col = mix(cloud_shade.rgb, cloud_color.rgb, far_c.y);
	col = mix(col, mix(col, far_col, 0.5), far_c.x * 0.55 * cloud_opacity);

	vec2 mid_c = cloud_layer(offset, parallax.y, 1.0, 7.7, TIME);
	col = mix(col, mix(cloud_shade.rgb, cloud_color.rgb, mid_c.y), mid_c.x * 0.7 * cloud_opacity);

	vec2 near_c = cloud_layer(offset, parallax.z, 1.6, 13.3, TIME);
	col = mix(col, mix(cloud_shade.rgb, cloud_color.rgb, near_c.y), near_c.x * 0.85 * cloud_opacity);

	COLOR = vec4(col, 1.0);
}