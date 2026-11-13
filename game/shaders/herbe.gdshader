// Brins d'herbe qui ondulent avec le vent.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 couleur_base : source_color = vec3(0.10, 0.16, 0.05);
uniform vec3 couleur_pointe : source_color = vec3(0.40, 0.47, 0.18);
uniform float force_vent = 0.18;

varying float teinte;

void vertex() {
	vec3 origine = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float hauteur = UV.y * UV.y;
	float vent = sin(TIME * 1.7 + origine.x * 0.35 + origine.z * 0.22)
			+ 0.4 * sin(TIME * 3.1 + origine.x * 1.3);
	VERTEX.x += vent * force_vent * hauteur;
	VERTEX.z += vent * force_vent * 0.5 * hauteur;
	teinte = INSTANCE_CUSTOM.r;
	// Les brins prennent la normale « vers le haut » pour un éclairage doux.
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.7));
}

void fragment() {
	vec3 pointe = mix(couleur_pointe, couleur_pointe * vec3(1.2, 1.05, 0.7), teinte);
	ALBEDO = mix(couleur_base, pointe, UV.y);
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
	BACKLIGHT = vec3(0.25, 0.3, 0.1);
}
