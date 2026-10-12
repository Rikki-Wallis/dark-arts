shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(0.85, 0.8, 0.65, 1.0);
uniform float thickness = 3.0;  // in screen pixels; keep it >= the filter's pixel_size

void vertex() {
	// position of this vertex on screen
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	// which way the surface faces, on screen
	vec2 dir = normalize((PROJECTION_MATRIX * vec4(mat3(MODELVIEW_MATRIX) * NORMAL, 0.0)).xy);
	// push the vertex outwards by a fixed number of pixels (* clip.w keeps it constant with distance)
	clip.xy += dir / VIEWPORT_SIZE * thickness * 2.0 * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
