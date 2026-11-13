// Façade d'immeuble de nuit : mur texturé (Poly Haven) et fenêtres dont certaines
// sont allumées (au hasard, mais toujours les mêmes). Les fenêtres sont calculées à
// partir de la position dans le monde : aucune texture de fenêtre à dessiner.
// Derrière les vitres allumées, un « faux intérieur » donne de la profondeur.
shader_type spatial;

uniform sampler2D texture_mur : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D relief_mur : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool avec_texture = false;
// Taille réelle d'une répétition de la texture du mur (mètres).
uniform float taille_motif = 3.0;
uniform vec3 couleur_mur : source_color = vec3(0.10, 0.11, 0.13);
uniform vec3 couleur_vitre : source_color = vec3(0.02, 0.025, 0.035);
uniform vec3 lumiere_chaude : source_color = vec3(1.0, 0.78, 0.5);
uniform vec3 lumiere_froide : source_color = vec3(0.6, 0.8, 1.0);
// Part des fenêtres allumées (0 = aucune, 1 = toutes).
uniform float part_allumee : hint_range(0.0, 1.0) = 0.35;
uniform float intensite = 1.6;
// Largeur et hauteur d'un étage (mètres).
uniform vec2 taille_fenetre = vec2(3.0, 3.6);
// Pas de fenêtres en dessous de cette hauteur (rez-de-chaussée, boutiques).
uniform float hauteur_rez = 4.5;

varying vec3 position_monde;
varying vec3 normale_monde;

float hasard(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	position_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normale_monde = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	bool face_x = abs(normale_monde.x) > 0.5;
	float horizontal = face_x ? position_monde.z : position_monde.x;
	vec2 coord = vec2(horizontal, position_monde.y) / taille_fenetre;
	vec2 case_fenetre = floor(coord);
	vec2 dans_case = fract(coord);
	float vitre = step(0.16, dans_case.x) * step(dans_case.x, 0.84)
			* step(0.2, dans_case.y) * step(dans_case.y, 0.8);
	// Encadrement légèrement en saillie autour de la vitre.
	float cadre = step(0.13, dans_case.x) * step(dans_case.x, 0.87)
			* step(0.17, dans_case.y) * step(dans_case.y, 0.83) - vitre;
	float facade = step(abs(normale_monde.y), 0.5) * step(hauteur_rez, position_monde.y);
	vitre *= facade;
	cadre *= facade;
	float face = floor(dot(normale_monde, vec3(1.0, 0.0, 2.0)) + 3.0);
	float tirage = hasard(case_fenetre + face * 17.0);
	float allumee = step(1.0 - part_allumee, tirage);
	vec3 teinte = mix(lumiere_chaude, lumiere_froide, step(0.5, hasard(case_fenetre * 1.7 + 3.0)));
	// Faux intérieur : plus lumineux au plafond, avec un store à moitié baissé parfois.
	float store = step(dans_case.y, 0.2 + 0.6 * hasard(case_fenetre + 9.0)) * step(0.7, hasard(case_fenetre + 5.0));
	float interieur = mix(0.55, 1.0, smoothstep(0.2, 0.8, dans_case.y)) * (1.0 - store * 0.75);

	vec3 mur = couleur_mur;
	float rugosite_mur = 0.85;
	vec2 uv_mur = vec2(horizontal, position_monde.y) / taille_motif;
	if (abs(normale_monde.y) > 0.5) {
		uv_mur = position_monde.xz / taille_motif;
	}
	if (avec_texture) {
		mur = texture(texture_mur, uv_mur).rgb * couleur_mur * 4.0;
		NORMAL_MAP = mix(texture(relief_mur, uv_mur).rgb, vec3(0.5, 0.5, 1.0), vitre);
	}
	mur = mix(mur, vec3(0.05), cadre);
	ALBEDO = mix(mur, couleur_vitre, vitre);
	ROUGHNESS = mix(mix(rugosite_mur, 0.4, cadre), 0.05, vitre);
	METALLIC = vitre * 0.3 + cadre * 0.6;
	EMISSION = teinte * vitre * allumee * intensite * interieur * (0.6 + 0.4 * tirage);
}
