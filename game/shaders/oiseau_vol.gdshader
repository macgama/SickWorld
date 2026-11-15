shader_type spatial;
// Oiseaux en vol (vie_ambiante / volee_ciel.gd) : un maillage simple corps + ailes,
// dupliqué par MultiMesh. Les ailes battent dans le vertex shader.
// INSTANCE_CUSTOM : r = phase (0-1), g = battement (0 = plane, 1 = bat des ailes),
// b = variation de teinte (0-1).
render_mode cull_disabled;

uniform vec3 couleur_dos : source_color = vec3(0.08, 0.08, 0.09);
uniform vec3 couleur_ventre : source_color = vec3(0.12, 0.12, 0.13);
uniform vec3 couleur_bouts : source_color = vec3(0.05, 0.05, 0.05);
uniform float frequence = 4.0;
uniform float amplitude = 0.9;
uniform float rugosite = 0.8;

void vertex() {
	float phase = INSTANCE_CUSTOM.r * 6.2831;
	float bat = INSTANCE_CUSTOM.g;
	float ecart = abs(VERTEX.x);
	float s = sin(TIME * frequence + phase);
	// Plané : les ailes restent un peu relevées (dièdre) et ondulent à peine.
	float angle = mix(0.12 + 0.04 * sin(TIME * 0.7 + phase), s * amplitude, bat);
	VERTEX.y += ecart * angle;
	// Les ailes se replient légèrement en remontant.
	VERTEX.x *= 1.0 - 0.18 * bat * max(s, 0.0);
	COLOR.a = INSTANCE_CUSTOM.b;
}

void fragment() {
	vec3 base = FRONT_FACING ? couleur_dos : couleur_ventre;
	base = mix(base, couleur_bouts, clamp(COLOR.r, 0.0, 1.0));
	base *= 0.85 + 0.3 * COLOR.a;
	ALBEDO = base;
	ROUGHNESS = rugosite;
	SPECULAR = 0.25;
}
