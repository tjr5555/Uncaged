shader_type canvas_item;

uniform float coverage : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fog_color : source_color = vec4(0.93, 0.95, 1.0, 1.0);
uniform vec4 shade_color : source_color = vec4(0.74, 0.79, 0.9, 1.0);
uniform float cloud_scale = 3.0;
uniform vec2 drift = vec2(0.035, 0.012);
uniform float softness = 0.16;
uniform float edge_bias = 0.45;

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
	for (int i = 0; i < 5; i++) {
		value += amp * noise(p);
		p *= 2.03;
		amp *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 uv = UV * aspect * cloud_scale;
	float n1 = fbm(uv + TIME * drift);
	float n2 = fbm(uv * 1.7 - TIME * drift * 1.6 + vec2(7.3, 2.1));
	float cloud = mix(n1, n2, 0.5);
	cloud += length((UV - 0.5) * aspect) * edge_bias;
	
	float threshold = 1.4 - coverage * 1.9;
	float a = smoothstep(threshold - softness, threshold + softness, cloud);
	a = mix(a, 1.0, smoothstep(0.85, 1.0, coverage));
	a *= smoothstep(0.0, 0.08, coverage);
	
	vec3 col = mix(shade_color.rgb, fog_color.rgb, smoothstep(0.25, 0.75, n2));
	COLOR = vec4(col, a);
}





