shader_type canvas_item;

// what has been drawn to the screen so far (the 3D world)
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float pixel_size = 1.0;    // how big each "retro pixel" is, in real pixels
uniform float color_steps = 32.0;  // colour levels per channel (lower = more retro)
uniform bool dither = true;

// 4x4 ordered (Bayer) dither pattern
const float BAYER[16] = float[16](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);

void fragment() {
	// snap this pixel to the centre of its retro-pixel block
	vec2 block = floor(FRAGCOORD.xy / pixel_size);
	vec2 uv = (block * pixel_size + pixel_size * 0.5) * SCREEN_PIXEL_SIZE;
	vec3 col = texture(screen_tex, uv).rgb;

	// reduce the number of colours, using the dither pattern to blend between them
	float offset = 0.5;
	if (dither) {
		ivec2 p = ivec2(mod(block, 4.0));
		offset = BAYER[p.y * 4 + p.x] / 16.0;
	}
	col = pow(col, vec3(0.85));  
	col = floor(col * color_steps + offset) / color_steps;

	COLOR = vec4(col, 1.0);
}
