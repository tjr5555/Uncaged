shader_type canvas_item;

uniform vec4 core_color : source_color = vec4(0.55, 0.35, 1.0, 1.0);
uniform vec4 rim_color : source_color = vec4(0.92, 0.88, 1.0, 1.0);
uniform float facing = 1.0;
uniform vec2 ellipse = vec2(0.16, 0.46);
uniform float ring_width = 0.09;
uniform float swirl_speed = 1.2;
uniform vec2 pixel_grid = vec2(90.0, 105.0);
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float haze_strength = 0.45;

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

void fragment() {
	vec2 uv = UV;
	if (pixel_grid.x > 0.0 && pixel_grid.y > 0.0) {
		uv = (floor(uv * pixel_grid) + 0.5) / pixel_grid;
	}

	vec2 c = uv - 0.5;
	float breathe = 1.0 + 0.03 * sin(TIME * 2.0) + pulse * 0.1;
	vec2 q = c / (ellipse * breathe);
	float r = length(q);
	float ang = atan(q.y, q.x);

	float swirl = ang * 3.0 + r * 9.0 - TIME * swirl_speed * 3.0;
	float bands = 0.5 + 0.5 * sin(swirl);
	float grain = noise(vec2(cos(ang), sin(ang)) * 3.0 + vec2(r * 6.0 - TIME * 1.5, TIME * 0.4));

	float inside = 1.0 - smoothstep(0.94, 1.0, r);
	float k_ring = (r - 1.0) / ring_width;
	float k_glow = (r - 1.0) / (ring_width * 3.0);
	float ring = exp(-k_ring * k_ring);
	float glow = exp(-k_glow * k_glow);
	float near_side = mix(0.55, 1.0, smoothstep(-0.3, 0.3, q.x * facing));

	vec3 interior = mix(core_color.rgb * 0.2, core_color.rgb, clamp(r * (0.6 + 0.4 * bands) + grain * 0.2, 0.0, 1.0));
	vec3 col = interior * inside;
	col += rim_color.rgb * ring * near_side * (1.0 + pulse);
	col += core_color.rgb * glow * 0.45;
	float a = inside * (0.8 + 0.2 * bands) + ring * near_side + glow * 0.35 * (1.0 + pulse);

	float out_front = c.x * facing;
	float spread = clamp((out_front - ellipse.x * 0.3) / (0.5 - ellipse.x * 0.3), 0.0, 1.0);
	float vertical = 1.0 - smoothstep(0.55, 1.0, abs(c.y) / ellipse.y);
	float streaks = 0.65 + 0.35 * sin(out_front * 45.0 + TIME * 6.0);
	float haze = step(0.0, out_front) * (1.0 - inside) * pow(1.0 - spread, 2.0) * vertical * streaks;
	haze *= haze_strength * (1.0 + pulse);

	col += mix(core_color.rgb, rim_color.rgb, 0.5) * haze;
	a += haze;

	a *= smoothstep(0.0, 0.04, uv.x) * smoothstep(1.0, 0.96, uv.x);
	a *= smoothstep(0.0, 0.03, uv.y) * smoothstep(1.0, 0.97, uv.y);
	COLOR = vec4(col, clamp(a, 0.0, 1.0));
}