shader_type spatial;
render_mode specular_disabled;

// A single flat colour, lit with the shared "lit or not" lighting, for the
// low-poly level kit. Make one material per surface type and set its colour.
#include "res://Shaders/binary_light.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.5, 0.5, 0.5, 1.0);

void fragment() {
	ALBEDO = albedo.rgb;
}
