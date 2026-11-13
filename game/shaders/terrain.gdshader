// Matériau du terrain : herbe, terre et roche selon la pente, avec des variations
// de couleur pour éviter un aspect uniforme. Sera remplacé par des textures
// réalistes (Poly Haven) dans une prochaine étape.
shader_type spatial;

uniform sampler2D bruit : filter_linear_mipmap, repeat_enable;
uniform vec3 herbe_sombre : source_color = vec3(0.17, 0.26, 0.09);
uniform vec3 herbe_claire : source_color = vec3(0.33, 0.40, 0.15);
uniform vec3 terre : source_color = vec3(0.29, 0.23, 0.16);
uniform vec3 roche : source_color = vec3(0.40, 0.38, 0.35);

varying vec3 position_monde;
varying vec3 normale_monde;

void vertex() {
	position_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normale_monde = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float grand = texture(bruit, position_monde.xz * 0.012).r;
	float moyen = texture(bruit, position_monde.xz * 0.09).r;
	float fin = texture(bruit, position_monde.xz * 0.7).r;

	vec3 herbe = mix(herbe_sombre, herbe_claire, smoothstep(0.3, 0.7, grand));
	herbe = mix(herbe, terre, smoothstep(0.62, 0.78, moyen) * 0.75);
	herbe *= 0.8 + 0.4 * fin;

	float pente = 1.0 - normale_monde.y;
	float part_roche = smoothstep(0.22, 0.38, pente + (moyen - 0.5) * 0.2);
	vec3 couleur_roche = roche * (0.75 + 0.5 * fin) * (0.85 + 0.3 * moyen);

	ALBEDO = mix(herbe, couleur_roche, part_roche);
	ROUGHNESS = mix(0.95, 0.85, part_roche);
	SPECULAR = 0.3;
}
