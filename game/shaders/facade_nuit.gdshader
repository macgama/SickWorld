// Façade d'immeuble de nuit pour la maquette du hub : béton sombre et fenêtres
// dont certaines sont allumées (au hasard, mais toujours les mêmes).
// Les fenêtres sont calculées à partir de la position dans le monde : aucune
// texture à dessiner. Sera remplacé par de vrais bâtiments (Fab, Blender).
shader_type spatial;

uniform vec3 couleur_mur : source_color = vec3(0.10, 0.11, 0.13);
uniform vec3 couleur_vitre : source_color = vec3(0.03, 0.04, 0.06);
uniform vec3 lumiere_chaude : source_color = vec3(1.0, 0.78, 0.5);
uniform vec3 lumiere_froide : source_color = vec3(0.6, 0.8, 1.0);
// Part des fenêtres allumées (0 = aucune, 1 = toutes).
uniform float part_allumee : hint_range(0.0, 1.0) = 0.35;
uniform float intensite = 2.2;
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
	float horizontal = abs(normale_monde.x) > 0.5 ? position_monde.z : position_monde.x;
	vec2 coord = vec2(horizontal, position_monde.y) / taille_fenetre;
	vec2 case_fenetre = floor(coord);
	vec2 dans_case = fract(coord);
	float vitre = step(0.18, dans_case.x) * step(dans_case.x, 0.82)
			* step(0.22, dans_case.y) * step(dans_case.y, 0.78);
	// Ni sur les toits, ni au rez-de-chaussée.
	vitre *= step(abs(normale_monde.y), 0.5) * step(hauteur_rez, position_monde.y);
	float face = floor(dot(normale_monde, vec3(1.0, 0.0, 2.0)) + 3.0);
	float tirage = hasard(case_fenetre + face * 17.0);
	float allumee = step(1.0 - part_allumee, tirage);
	vec3 teinte = mix(lumiere_chaude, lumiere_froide, step(0.5, hasard(case_fenetre * 1.7 + 3.0)));
	ALBEDO = mix(couleur_mur, couleur_vitre, vitre);
	ROUGHNESS = mix(0.85, 0.08, vitre);
	METALLIC = vitre * 0.4;
	EMISSION = teinte * vitre * allumee * intensite * (0.6 + 0.4 * tirage);
}
