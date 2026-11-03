shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.8, 0.7, 1.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.3;
uniform float facing = 1.0;
uniform vec2 radius = vec2(0.42, 0.46);
uniform float front_bias = 0.35;
uniform vec2 drift = vec2(0.05, -0.03);
uniform vec2 pixel_grid = vec2(0.0, 0.0);

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
	vec2 uv = UV;
	if (pixel_grid.x > 0.0 && pixel_grid.y > 0.0) {
		uv = (floor(uv * pixel_grid) + 0.5) / pixel_grid;
	}

	vec2 c = uv - 0.5;
	c.x -= facing * front_bias * 0.15;
	float falloff = 1.0 - smoothstep(0.2, 1.0, length(c / radius));

	float n1 = fbm(uv * vec2(3.0, 4.0) + TIME * drift);
	float n2 = fbm(uv * 6.0 - TIME * drift * 1.7 + vec2(3.1, 1.7));
	float cloud = smoothstep(0.35, 0.8, n1 * 0.7 + n2 * 0.4);

	vec3 col = mix(tint.rgb * 0.85, vec3(1.0), n2 * 0.4);
	COLOR = vec4(col, falloff * cloud * strength);
}