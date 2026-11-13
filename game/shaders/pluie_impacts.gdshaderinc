// Impacts de gouttes de pluie sur une surface horizontale : petits cercles qui
// s'élargissent et s'effacent. Renvoie une déformation de la normale (x, y).
// Partagé par le sol mouillé et l'eau.

float hasard_pluie(vec2 p) {
	// Hachage sans sin() : sin() sur de grandes valeurs est imprécis sur les cartes
	// NVIDIA et dessinait des facettes (bandes, quadrilatères) dans les motifs.
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 _couche_impacts(vec2 p, float t) {
	vec2 cellule = floor(p);
	vec2 f = fract(p);
	vec2 n = vec2(0.0);
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			vec2 o = vec2(float(i), float(j));
			vec2 c = cellule + o;
			float h = hasard_pluie(c);
			vec2 centre = o + vec2(hasard_pluie(c + 1.3), hasard_pluie(c + 7.1));
			float phase = fract(t * (0.9 + 0.4 * h) + h);
			vec2 d = f - centre;
			float r = length(d);
			float rayon = phase * 0.55;
			float anneau = sin(clamp((r - rayon) * 38.0, -6.2832, 6.2832)) * smoothstep(0.12, 0.0, abs(r - rayon));
			n += d / (r + 0.0001) * anneau * (1.0 - phase) * (1.0 - phase);
		}
	}
	return n;
}

vec2 impacts_pluie(vec2 position_xz, float t, float intensite) {
	if (intensite <= 0.0) {
		return vec2(0.0);
	}
	vec2 n = _couche_impacts(position_xz * 2.2, t);
	n += _couche_impacts(position_xz * 2.2 + vec2(13.7, 5.3), t + 0.5) * 0.8;
	return n * intensite;
}
