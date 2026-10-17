// Shared "lit or not" lighting for every level material.
// A surface is either fully lit (a light reaches it: inside its cone, not in shadow,
// and facing it) or not lit at all. Overlapping lights don't add up: the brightest
// one wins, so every lit area shows the same brightness.

uniform float lit_brightness = 1.0;

void light() {
	// 1 if this light reaches this point and the surface faces it, otherwise 0
	float lit = step(0.001, ATTENUATION) * step(0.0, dot(NORMAL, LIGHT));
	// keep the light's colour, but not its strength, so every light looks equally bright
	float strongest = max(max(LIGHT_COLOR.r, LIGHT_COLOR.g), max(LIGHT_COLOR.b, 0.0001));
	vec3 light_hue = LIGHT_COLOR / strongest;
	// max, not +: a second light on the same spot doesn't make it brighter
	DIFFUSE_LIGHT = max(DIFFUSE_LIGHT, light_hue * lit_brightness * lit);
}
