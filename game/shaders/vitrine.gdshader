// Vitrine de boutique éclairée : derrière la vitre, une vraie boutique en
// profondeur (plafond lumineux, rayonnages colorés, sol brillant) simulée par
// « interior mapping », sans aucune géométrie. La vitre reflète aussi la rue.
// S'applique à une boîte fine dont la face avant regarde vers +Z (repère local).
shader_type spatial;

uniform vec3 couleur : source_color = vec3(1.0, 0.8, 0.6);
uniform float intensite = 1.4;
// Profondeur de la boutique (mètres).
uniform float profondeur = 5.0;
uniform float graine = 0.0;

varying vec3 position_locale;
varying vec3 camera_locale;
varying vec3 demi_taille;

float hasard(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	position_locale = VERTEX;
	camera_locale = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	// Taille de la boîte : on la retrouve à partir de l'échelle (BoxMesh centré).
	demi_taille = vec3(2.5, 1.5, 0.04);
}

void fragment() {
	vec3 r = normalize(position_locale - camera_locale);
	float face_avant = step(0.5, (inverse(VIEW_MATRIX * MODEL_MATRIX) * vec4(NORMAL, 0.0)).z);
	vec3 p = position_locale;
	vec3 lum = vec3(0.0);
	if (r.z < -0.01) {
		vec3 d = demi_taille;
		float tx = ((r.x > 0.0 ? d.x : -d.x) - p.x) / r.x;
		float ty = ((r.y > 0.0 ? d.y : -d.y) - p.y) / r.y;
		float tz = (-profondeur - p.z) / r.z;
		float t = min(min(tx, ty), tz);
		vec3 h = p + r * t;
		float fond = clamp(-h.z / profondeur, 0.0, 1.0);
		if (t == ty && r.y > 0.0) {
			// Plafond : rangées de dalles lumineuses.
			float dalle = step(0.55, fract(h.z * 0.7)) * step(abs(h.x), d.x * 0.7);
			lum = couleur * (0.5 + dalle * 2.8);
		} else if (t == ty) {
			// Sol brillant qui reflète les dalles du plafond.
			float reflet = step(0.55, fract(h.z * 0.7)) * step(abs(h.x), d.x * 0.6);
			lum = couleur * (0.25 + reflet * 0.35);
		} else if (t == tx) {
			// Rayonnages sur les murs de côté : étagères et produits colorés.
			float etagere = fract(h.y * 2.2 + 0.3);
			vec2 case_p = floor(vec2(h.z * 3.0, h.y * 2.2 + 0.3));
			vec3 produit = 0.5 + 0.5 * cos(6.2832 * (hasard(case_p + graine) + vec3(0.0, 0.33, 0.67)));
			lum = mix(couleur * 0.5, produit * couleur * 1.1, step(0.25, etagere) * step(etagere, 0.9));
			lum *= 0.9 - fond * 0.4;
		} else {
			// Mur du fond : rayonnage et comptoir.
			float etagere = fract(h.y * 2.2 + 0.3);
			vec2 case_p = floor(vec2(h.x * 3.0, h.y * 2.2 + 0.3));
			vec3 produit = 0.5 + 0.5 * cos(6.2832 * (hasard(case_p + graine + 5.0) + vec3(0.0, 0.33, 0.67)));
			lum = mix(couleur * 0.45, produit * couleur, step(0.25, etagere) * step(etagere, 0.9) * step(h.y, 0.9));
		}
		// Un peu plus sombre en bas (lumière qui vient du plafond).
		lum *= mix(0.6, 1.0, clamp(h.y / d.y * 0.5 + 0.5, 0.0, 1.0));
	}
	// Cadre de la vitrine (bord sombre de 8 cm).
	float cadre = 1.0 - step(abs(p.x), 2.42) * step(abs(p.y), 1.42);
	ALBEDO = mix(vec3(0.01), vec3(0.03), cadre);
	ROUGHNESS = mix(0.02, 0.4, cadre);
	METALLIC = mix(0.1, 0.8, cadre);
	SPECULAR = 0.6;
	EMISSION = lum * intensite * face_avant * (1.0 - cadre);
}
