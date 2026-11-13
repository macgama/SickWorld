// Ciel de nuit pluvieux de Hikari Bay : nuages bas, éclairés par-dessous par la
// lueur orangée et rose de la ville, et éclairs lointains (réglés par
// scripts/monde/ambiance_hikari.gd).
shader_type sky;

uniform vec3 couleur_zenith : source_color = vec3(0.006, 0.008, 0.02);
uniform vec3 couleur_horizon : source_color = vec3(0.14, 0.07, 0.16);
// Couleur de la lueur de la ville sous les nuages.
uniform vec3 lueur_ville : source_color = vec3(0.5, 0.24, 0.32);
uniform float densite_nuages : hint_range(0.0, 1.0) = 0.75;
// Intensité de l'éclair en cours (0 = aucun).
uniform float eclair = 0.0;
uniform vec3 couleur_eclair : source_color = vec3(0.75, 0.8, 1.0);
// Direction (x, z) de l'éclair.
uniform vec2 direction_eclair = vec2(0.4, -1.0);

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * bruit(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 c = mix(couleur_horizon, couleur_zenith, pow(clamp(h, 0.0, 1.0), 0.4));
	if (h < 0.0) {
		c = couleur_horizon * mix(1.0, 0.5, clamp(-h * 4.0, 0.0, 1.0));
	} else {
		// Nuages projetés sur un plafond nuageux.
		vec2 uv = d.xz / (h + 0.06);
		float n = fbm(uv * 0.9);
		float n2 = fbm(uv * 2.7 + 4.0);
		float couverture = smoothstep(0.55 - densite_nuages * 0.4, 0.85, n * 0.75 + n2 * 0.35);
		// Le dessous des nuages renvoie la lumière de la ville (plus fort près de l'horizon).
		vec3 nuage = lueur_ville * (0.03 + 0.3 * pow(1.0 - h, 3.0)) * (0.5 + 0.8 * n2);
		c = mix(c, nuage, couverture * 0.92);
		// Éclair : illumine les nuages, surtout dans sa direction.
		float proche = max(0.0, dot(normalize(d.xz + 0.0001), normalize(direction_eclair)));
		c += couleur_eclair * eclair * couverture * (0.15 + 1.6 * pow(proche, 5.0)) * (1.0 - h * 0.6);
	}
	COLOR = c;
}
