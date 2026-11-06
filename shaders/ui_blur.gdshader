shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float blur_radius = 3.0;
uniform vec4 tint : source_color = vec4(0.04, 0.07, 0.14, 0.55);

void fragment() {
	vec2 step_size = SCREEN_PIXEL_SIZE * blur_radius * amount;
	vec3 sum = vec3(0.0);
	float total = 0.0;
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++){
			float w = exp(-float(x * x + y * y) / 8.0);
			sum += texture(screen_texture, SCREEN_UV + vec2(float(x), float(y)) * step_size).rgb * w;
			total += w;
		}
	}
	vec3 col = mix(sum / total, tint.rgb, tint.a * amount);
	COLOR = vec4(col, 1.0);
}