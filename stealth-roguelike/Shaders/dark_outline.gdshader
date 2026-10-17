shader_type spatial;
// draw straight to the screen: no lighting, ignore depth, both faces
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;

// darkness
uniform vec3 dark_color : source_color = vec3(0.0, 0.0, 0.0);        // black fill for unlit areas
uniform vec3 line_color : source_color = vec3(1.0, 1.0, 1.0);        // white outlines in the dark

// light
uniform vec3 lit_color : source_color = vec3(1.0, 1.0, 1.0);         // white fill for lit areas
uniform vec3 lit_line_color : source_color = vec3(0.0, 0.0, 0.0);    // black outlines inside lit areas

// what counts as lit, and where outlines go
uniform float lit_threshold = 0.03;    // brighter than this = lit by a light
uniform float lit_softness = 0.0;      // soft band at the edge of lit areas (0 = hard edge)
uniform float line_width = 1.5;        // outline thickness in pixels
uniform float depth_threshold = 0.04;  // how big a depth jump makes an outline (fraction of distance)
uniform float normal_threshold = 0.4;  // how sharp a corner makes an outline
uniform float edge_blend = 0.0;        // how far (in pixels) light pools fade to black at their edge; 0 = hard noir cut

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

// is the scene lit at this point on screen? 1 = lit, 0 = dark
// (darkness is pure black, so anything brighter is in a light)
float lit_at(vec2 uv) {
	float lum = dot(texture(screen_tex, uv).rgb, vec3(0.299, 0.587, 0.114));
	// step when softness is 0: smoothstep needs two different edges
	return lit_softness > 0.0 ? smoothstep(lit_threshold, lit_threshold + lit_softness, lum) : step(lit_threshold, lum);
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

	// how lit is this pixel? With edge_blend, light pools fade from white through grey to
	// black at their edge, INSIDE the pool only, so the darkness outside stays pure black
	// (no glow). We check how much of the area around the pixel is lit: about half at the
	// pool's edge, all of it deep inside. Stretching that half-to-all range to 0-1 gives
	// black right at the edge, rising to white edge_blend pixels in.
	float lit = lit_at(SCREEN_UV);
	if (edge_blend > 0.0 && lit > 0.0) {
		vec2 reach = edge_blend / VIEWPORT_SIZE;
		float total = lit;
		for (int i = 0; i < 12; i++) {
			float angle = TAU * float(i) / 12.0;
			vec2 dir = vec2(cos(angle), sin(angle)) * reach;
			total += lit_at(SCREEN_UV + dir) + lit_at(SCREEN_UV + dir * 0.5);
		}
		float lit_around = total / 25.0;
		lit *= clamp((lit_around - 0.5) * 2.0, 0.0, 1.0);
	}

	// darkness: black with white outlines
	vec3 dark = mix(dark_color, line_color, edge);
	// light: white with black outlines, so shapes stay readable
	vec3 lit_area = mix(lit_color, lit_line_color, edge);
	ALBEDO = mix(dark, lit_area, lit);
}
