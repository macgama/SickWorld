// Touffes d'herbe sèche de la steppe glaciaire, couchées par le vent froid.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 couleur_base : source_color = vec3(0.17, 0.15, 0.09);
uniform vec3 couleur_pointe : source_color = vec3(0.62, 0.55, 0.36);
uniform vec3 couleur_givre : source_color = vec3(0.82, 0.85, 0.86);
uniform float force_vent = 0.22;

varying float teinte;

void vertex() {
	vec3 origine = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float hauteur = UV.y * UV.y;
	float rafale = sin(TIME * 0.7 + origine.x * 0.05) * 0.5 + 0.5;
	float vent = sin(TIME * 2.3 + origine.x * 0.4 + origine.z * 0.3) * (0.4 + rafale);
	VERTEX.x += (vent + 0.6) * force_vent * hauteur;
	VERTEX.z += vent * force_vent * 0.35 * hauteur;
	teinte = INSTANCE_CUSTOM.r;
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.7));
}

void fragment() {
	vec3 pointe = mix(couleur_pointe, couleur_pointe * vec3(0.8, 0.85, 0.9), teinte);
	vec3 c = mix(couleur_base, pointe, UV.y);
	c = mix(c, couleur_givre, smoothstep(0.75, 1.0, UV.y) * 0.4 * teinte);
	ALBEDO = c;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	BACKLIGHT = vec3(0.35, 0.3, 0.18);
}
