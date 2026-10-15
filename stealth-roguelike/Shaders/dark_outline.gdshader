shader_type spatial;
// draw straight to the screen: no lighting, ignore depth, both faces
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;

uniform vec3 dark_color : source_color = vec3(0.04, 0.06, 0.16);  // the navy fill
uniform vec3 line_color : source_color = vec3(0.85, 0.9, 1.0);    // outline colour
uniform float lit_threshold = 0.03;    // brighter than this = lit by a light
uniform float lit_softness = 0.04;     // soft band at the edge of lit areas
uniform float line_width = 1.5;        // outline thickness in pixels
uniform float depth_threshold = 0.04;  // how big a depth jump makes an outline (fraction of distance)
uniform float normal_threshold = 0.4;  // how sharp a corner makes an outline

void vertex() {
	// ignore the quad's real position and stretch it over the whole screen
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// distance from the camera to whatever is drawn at this point on screen
float view_depth(vec2 uv, mat4 inv_projection) {
	float depth = texture(depth_tex, uv).r;
	vec4 view = inv_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
	return -view.z / view.w;
}

vec3 view_normal(vec2 uv) {
	return texture(normal_tex, uv).xyz * 2.0 - 1.0;
}

void fragment() {
	vec2 px = line_width / VIEWPORT_SIZE;
	float depth = view_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 normal = view_normal(SCREEN_UV);

	// outline wherever a neighbouring pixel is at a very different depth
	// (an object's silhouette) or faces a very different way (a corner)
	float edge = 0.0;
	vec2 offsets[4] = vec2[](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
	for (int i = 0; i < 4; i++) {
		vec2 uv = SCREEN_UV + offsets[i];
		float depth_jump = abs(view_depth(uv, INV_PROJECTION_MATRIX) - depth) / depth;
		float bend = 1.0 - dot(normal, view_normal(uv));
		edge = max(edge, max(step(depth_threshold, depth_jump), step(normal_threshold, bend)));
	}

	// is this pixel lit? (darkness is pure black, so anything brighter is in a light)
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	float lit = smoothstep(lit_threshold, lit_threshold + lit_softness, lum);

	// darkness: flat navy with white outlines. Light: the real image.
	vec3 dark = mix(dark_color, line_color, edge);
	ALBEDO = mix(dark, col, lit);
}
