// Façade d'immeuble de nuit, sans aucune texture de fenêtre à dessiner :
// les fenêtres sont calculées à partir de la position dans le monde.
//
// Trois styles d'immeubles (paramètre « style » ou « style_instance ») :
//   0 = béton ancien (mur texturé Poly Haven, fenêtres percées),
//   1 = tour de bureaux en verre (mur-rideau, bandeaux entre les étages),
//   2 = résidentiel (petites fenêtres, balcons, rideaux colorés).
//
// Derrière chaque vitre allumée, une vraie « pièce » est simulée (technique de
// l'« interior mapping ») : plafond éclairé, murs, sol et silhouettes de meubles
// bougent avec le point de vue, ce qui donne de la profondeur sans géométrie.
//
// Si l'immeuble donne ses limites (paramètre d'instance « bornes »), les fenêtres
// sont réparties exactement sur chaque façade (pas de fenêtre coupée aux coins)
// et des piliers d'angle et un couronnement sont ajoutés.
shader_type spatial;

uniform sampler2D texture_mur : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D relief_mur : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool avec_texture = false;
// Taille réelle d'une répétition de la texture du mur (mètres).
uniform float taille_motif = 3.0;
uniform vec3 couleur_mur : source_color = vec3(0.10, 0.11, 0.13);
uniform vec3 couleur_vitre : source_color = vec3(0.02, 0.025, 0.035);
uniform vec3 lumiere_chaude : source_color = vec3(1.0, 0.72, 0.42);
uniform vec3 lumiere_froide : source_color = vec3(0.82, 0.9, 1.0);
// Part des fenêtres allumées (0 = aucune, 1 = toutes).
uniform float part_allumee : hint_range(0.0, 1.0) = 0.35;
uniform float intensite = 1.25;
// Largeur et hauteur d'un étage (mètres) pour le style 0.
uniform vec2 taille_fenetre = vec2(3.0, 3.6);
// Pas de fenêtres en dessous de cette hauteur (rez-de-chaussée, boutiques).
uniform float hauteur_rez = 4.5;
uniform int style : hint_range(0, 2) = 0;
// Traînées sombres laissées par la pluie sur les murs.
uniform float salissure : hint_range(0.0, 1.0) = 0.5;

// Paramètres propres à chaque immeuble (réglés par immeubles_hikari.gd).
// bornes = (x min, z min, x max, z max) ; zéro = inconnues.
instance uniform vec4 bornes = vec4(0.0);
instance uniform float hauteur_toit = 0.0;
instance uniform float graine = 0.0;
// -1 = utiliser « part_allumee » / « style ».
instance uniform float allumage = -1.0;
instance uniform int style_instance = -1;

varying vec3 position_monde;
varying vec3 normale_monde;

float hasard(vec2 p) {
	// Hachage sans sin() : sin() sur de grandes valeurs est imprécis sur les cartes
	// NVIDIA et dessinait des facettes (bandes, quadrilatères) dans les motifs.
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hasard(i), hasard(i + vec2(1, 0)), f.x),
			mix(hasard(i + vec2(0, 1)), hasard(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	position_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normale_monde = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Une pièce vue à travers la vitre. uv = position dans la vitre (0..1),
// rayon = direction du regard dans le repère de la façade (x = le long de la
// façade, y = vers le haut, z = vers l'intérieur). Renvoie la lumière vue.
vec3 piece(vec2 uv, vec3 rayon, float tirage, vec3 teinte, float profondeur) {
	vec3 p = vec3(uv, 0.0);
	vec3 r = rayon;
	r.z = max(r.z, 0.05);
	float tx = ((r.x > 0.0 ? 1.0 : 0.0) - p.x) / r.x;
	float ty = ((r.y > 0.0 ? 1.0 : 0.0) - p.y) / r.y;
	float tz = profondeur / r.z;
	float t = min(min(tx, ty), tz);
	vec3 h = p + r * t;
	float lum;
	if (t == ty) {
		// Plafond (très éclairé, avec un néon) ou sol.
		if (r.y > 0.0) {
			float neon = smoothstep(0.12, 0.0, abs(h.x - 0.5)) * step(0.15, h.z / profondeur) * step(h.z / profondeur, 0.85);
			lum = 1.1 + neon * 2.5;
		} else {
			lum = 0.28;
		}
	} else if (t == tx) {
		// Murs de côté : plus sombres vers le fond.
		lum = mix(0.75, 0.45, h.z / profondeur);
	} else {
		// Mur du fond, avec un meuble ou une silhouette au hasard.
		lum = 0.62;
		float meuble = step(h.y, 0.25 + 0.35 * hasard(vec2(tirage, 3.1))) * step(abs(h.x - hasard(vec2(tirage, 7.7))), 0.18 + 0.2 * tirage);
		lum = mix(lum, 0.12, meuble);
		// Tableau ou écran.
		float cadre = step(abs(h.x - 0.5), 0.15) * step(abs(h.y - 0.62), 0.08) * step(0.6, tirage);
		lum += cadre * 0.6;
	}
	// La lumière décroît du plafond vers le sol.
	lum *= mix(0.65, 1.0, clamp(h.y, 0.0, 1.0));
	return teinte * lum;
}

void fragment() {
	int st = style_instance >= 0 ? style_instance : style;
	float part = allumage >= 0.0 ? allumage : part_allumee;
	bool face_x = abs(normale_monde.x) > 0.5;
	bool toit = normale_monde.y > 0.5;
	float horizontal = face_x ? position_monde.z : position_monde.x;
	vec3 axe_h = face_x ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);

	// Taille des cases (une fenêtre par case) selon le style.
	vec2 taille = taille_fenetre;
	if (st == 1) taille = vec2(1.6, 3.9);
	if (st == 2) taille = vec2(2.6, 3.0);
	bool a_bornes = dot(abs(bornes), vec4(1.0)) > 0.0;
	float debut = 0.0;
	float largeur_face = 0.0;
	if (a_bornes) {
		debut = face_x ? bornes.y : bornes.x;
		float fin = face_x ? bornes.w : bornes.z;
		largeur_face = fin - debut;
		// Nombre entier de fenêtres sur la façade (marge de 0,8 m aux coins).
		float n = max(1.0, floor((largeur_face - 1.6) / taille.x));
		taille.x = (largeur_face - 1.6) / n;
		debut += 0.8;
	}
	vec2 coord = vec2(horizontal - debut, position_monde.y - hauteur_rez) / taille;
	vec2 case_fenetre = floor(coord);
	vec2 dans_case = fract(coord);
	float face = floor(dot(normale_monde, vec3(1.0, 0.0, 2.0)) + 3.0);
	vec2 cle = case_fenetre + vec2(face * 17.0 + graine * 3.7, graine * 1.3);

	// Forme de la vitre dans sa case.
	vec2 marge = vec2(0.16, 0.2);
	if (st == 1) marge = vec2(0.03, 0.22);
	if (st == 2) marge = vec2(0.2, 0.25);
	float vitre = step(marge.x, dans_case.x) * step(dans_case.x, 1.0 - marge.x)
			* step(marge.y, dans_case.y) * step(dans_case.y, 1.0 - marge.y * 0.6);
	float cadre = step(marge.x - 0.03, dans_case.x) * step(dans_case.x, 1.03 - marge.x)
			* step(marge.y - 0.03, dans_case.y) * step(dans_case.y, 1.03 - marge.y * 0.6) - vitre;
	// Mur-rideau : meneaux fins, et le bandeau entre étages est lui aussi vitré (sombre).
	float bandeau = 0.0;
	if (st == 1) {
		bandeau = 1.0 - step(0.22, dans_case.y);
	}
	// Résidentiel : dalle de balcon sous une fenêtre sur trois.
	float balcon = 0.0;
	if (st == 2) {
		balcon = step(dans_case.y, 0.1) * step(0.66, hasard(vec2(case_fenetre.y, floor(case_fenetre.x / 2.0) + graine)));
	}

	float facade = step(abs(normale_monde.y), 0.5) * step(hauteur_rez, position_monde.y);
	// Pas de fenêtre en dehors de la façade utile (coins, sommet).
	float pilier = 0.0;
	float couronne = 0.0;
	if (a_bornes) {
		float u = horizontal - (face_x ? bornes.y : bornes.x);
		pilier = 1.0 - step(0.8, u) * step(u, largeur_face - 0.8);
		couronne = step(hauteur_toit - 2.2, position_monde.y);
	}
	facade *= (1.0 - pilier) * (1.0 - couronne);
	vitre *= facade;
	cadre *= facade;
	bandeau *= facade;
	balcon *= facade;

	// Quelles fenêtres sont allumées ? Les bureaux s'allument par plateaux
	// entiers, les logements fenêtre par fenêtre.
	float tirage = hasard(cle);
	float tirage_etage = hasard(vec2(case_fenetre.y + graine * 7.0, face + floor(case_fenetre.x / 6.0)));
	float allumee = step(1.0 - part, st == 1 ? mix(tirage_etage, tirage, 0.25) : tirage);
	vec3 teinte = mix(lumiere_chaude, lumiere_froide, step(st == 1 ? 0.3 : 0.6, hasard(cle * 1.7 + 3.0)));
	// Quelques fenêtres aux rideaux colorés, et des télévisions qui clignotent.
	if (st != 1 && hasard(cle + 21.0) > 0.85) {
		teinte = mix(teinte, vec3(1.0, 0.35, 0.3), 0.6);
	}
	float tele = step(0.93, hasard(cle + 41.0));
	float scintille = 0.75 + 0.25 * sin(TIME * 7.0 + tirage * 50.0) * sin(TIME * 2.3 + tirage * 20.0);
	teinte = mix(teinte, vec3(0.45, 0.6, 1.0) * scintille, tele);

	// Pièce derrière la vitre (vue en profondeur).
	vec3 vue = normalize(position_monde - CAMERA_POSITION_WORLD);
	vec2 uv_vitre = vec2((dans_case.x - marge.x) / (1.0 - 2.0 * marge.x), (dans_case.y - marge.y) / (1.0 - 1.6 * marge.y));
	vec3 rayon = vec3(dot(vue, axe_h), vue.y, dot(vue, -normale_monde));
	rayon.x *= taille.y / taille.x;
	// Store à moitié baissé dans certaines pièces.
	float store = step(0.65, hasard(cle + 5.0)) * step(1.0 - (0.15 + 0.6 * hasard(cle + 9.0)), uv_vitre.y);
	vec3 interieur = piece(uv_vitre, rayon, tirage, teinte, 1.4);
	interieur = mix(interieur, teinte * 0.35, store);

	// Mur : texture, traînées de pluie et assombrissement au pied.
	vec3 mur = couleur_mur;
	float rugosite_mur = 0.8;
	vec2 uv_mur = vec2(horizontal, position_monde.y) / taille_motif;
	if (toit) {
		uv_mur = position_monde.xz / taille_motif;
	}
	if (avec_texture) {
		mur = texture(texture_mur, uv_mur).rgb * couleur_mur * 4.0;
	}
	if (st == 1) {
		mur = vec3(0.045, 0.05, 0.06);
		rugosite_mur = 0.35;
	}
	float trainee = bruit(vec2(horizontal * 1.3, position_monde.y * 0.04 + graine)) * bruit(vec2(horizontal * 0.35, position_monde.y * 0.1));
	mur *= 1.0 - salissure * 0.6 * smoothstep(0.15, 0.6, trainee) * (1.0 - float(toit));
	mur *= mix(0.55, 1.0, smoothstep(0.0, 3.0, position_monde.y));
	// Couronnement : bande plus claire en haut de l'immeuble.
	mur = mix(mur, mur * 1.6 + vec3(0.01), couronne * (1.0 - float(toit)) * step(hauteur_rez, position_monde.y));
	if (toit) {
		mur = vec3(0.07, 0.07, 0.075) * (0.8 + 0.4 * bruit(position_monde.xz * 0.7));
		rugosite_mur = 0.6;
	}

	mur = mix(mur, vec3(0.03, 0.032, 0.036), cadre);
	mur = mix(mur, vec3(0.02, 0.025, 0.03), bandeau);
	mur = mix(mur, vec3(0.12, 0.12, 0.12), balcon);
	ALBEDO = mix(mur, couleur_vitre, vitre);
	// La pluie rend tout un peu plus brillant.
	ROUGHNESS = mix(mix(mix(rugosite_mur * 0.85, 0.3, cadre), 0.08, bandeau), 0.03, vitre);
	METALLIC = vitre * 0.4 + cadre * 0.7 + bandeau * 0.5;
	SPECULAR = 0.5 + 0.3 * vitre;
	if (avec_texture && st != 1) {
		NORMAL_MAP = mix(texture(relief_mur, uv_mur).rgb, vec3(0.5, 0.5, 1.0), vitre + cadre);
	}
	EMISSION = interieur * vitre * allumee * intensite * (0.45 + 0.55 * hasard(cle + 77.0));
	// Les vitres éteintes laissent deviner une faible lueur (veilleuses, rue).
	EMISSION += teinte * vitre * (1.0 - allumee) * 0.015;
}
