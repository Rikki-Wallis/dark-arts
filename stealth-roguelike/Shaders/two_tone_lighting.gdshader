shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

uniform float threshold = 0.5;
uniform float softness = 0.02;
uniform float shadow_min = 0.45;
uniform float shadow_max = 1.3;
uniform float lit_saturation = 1.2;
uniform vec3 shadow_colour : source_color = vec3(0.10, 0.12, 0.28);

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	
	float lit = smoothstep(threshold - softness, threshold + softness, lum);
	
	// shadow: one flat colour, but stretch the dim detail so shapes stay visible
	float shade = clamp(lum / threshold, 0.0, 1.0);
	vec3 shadow = shadow_colour * mix(shadow_min, shadow_max, shade);

	// lit: the real colour, slightly more saturated
	vec3 lit_col = mix(vec3(lum), col, lit_saturation);

	COLOR = vec4(mix(shadow, lit_col, lit), 1.0);
}
