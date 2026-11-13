// Ciel de la Préhistoire : soleil bas d'un hiver glaciaire, horizon doré du
// côté du soleil et bleu froid à l'opposé, nuages éclairés par la tranche
// (bords dorés, ventre gris-bleu). La direction du soleil vient de la lumière
// « Soleil » de la scène.
shader_type sky;

uniform vec3 couleur_zenith : source_color = vec3(0.10, 0.22, 0.45);
uniform vec3 horizon_froid : source_color = vec3(0.58, 0.68, 0.80);
uniform vec3 horizon_soleil : source_color = vec3(1.0, 0.66, 0.40);
uniform vec3 couleur_soleil : source_color = vec3(1.0, 0.85, 0.65);
uniform float taille_soleil = 0.9998;
uniform float force_soleil = 30.0;
// 0 = ciel dégagé, 1 = couvert.
uniform float couverture : hint_range(0.0, 1.0) = 0.5;
uniform vec3 nuage_ombre : source_color = vec3(0.32, 0.38, 0.48);
uniform vec3 nuage_lumiere : source_color = vec3(1.0, 0.82, 0.62);
// Décalage des nuages (pour varier d'une zone à l'autre).
uniform vec2 decalage = vec2(0.0);

float hasard(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
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
	for (int i = 0; i < 6; i++) {
		v += a * bruit(p);
		p = p * 2.02 + vec2(3.1, 7.7);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	vec3 s = LIGHT0_ENABLED ? LIGHT0_DIRECTION : normalize(vec3(-0.8, 0.25, -0.5));
	float cos_soleil = dot(d, s);
	float vers_soleil = clamp(cos_soleil * 0.5 + 0.5, 0.0, 1.0);
	float h = clamp(d.y, 0.0, 1.0);
	// Dégradé : l'horizon prend la couleur du soleil de son côté.
	vec3 horizon = mix(horizon_froid, horizon_soleil, pow(vers_soleil, 3.0));
	vec3 c = mix(horizon, couleur_zenith, pow(h, 0.55));
	// Halo autour du soleil. Le halo serré et le disque ne vont pas dans la carte
	// de reflets (cubemap basse résolution) : leurs fortes valeurs y faisaient
	// des carrés lumineux autour du soleil, repris par la brume et les reflets.
	c += couleur_soleil * pow(max(cos_soleil, 0.0), 24.0) * 0.8;
	if (!AT_CUBEMAP_PASS) {
		c += couleur_soleil * pow(max(cos_soleil, 0.0), 300.0) * 3.0;
	}
	if (d.y < 0.0) {
		c = mix(horizon, horizon_froid * 0.55, clamp(-d.y * 3.0, 0.0, 1.0));
	} else {
		// Nuages sur un plafond.
		vec2 uv = d.xz / (d.y + 0.08) * 0.6 + decalage;
		float forme = fbm(uv);
		float detail = fbm(uv * 3.1 + 1.7);
		float densite = smoothstep(0.62 - couverture * 0.35, 0.9, forme * 0.8 + detail * 0.3);
		// Éclairage : on décale l'échantillon vers le soleil pour trouver l'épaisseur.
		vec2 vers = normalize(s.xz + 0.0001) * 0.08;
		float epais = fbm(uv + vers) * 0.8 + detail * 0.3;
		float eclaire = clamp(1.0 - (epais - (forme * 0.8 + detail * 0.3)) * 6.0, 0.0, 1.0);
		vec3 nuage = mix(nuage_ombre, nuage_lumiere, eclaire * (0.35 + 0.65 * pow(vers_soleil, 2.0)));
		// Bords lumineux face au soleil.
		nuage += couleur_soleil * pow(max(cos_soleil, 0.0), 8.0) * (1.0 - densite) * 1.2;
		// Les nuages lointains se fondent dans l'horizon.
		float loin = smoothstep(0.0, 0.18, d.y);
		c = mix(c, nuage, densite * loin * 0.95);
	}
	// Disque du soleil (devant les nuages fins).
	float disque = smoothstep(taille_soleil - 0.00004, taille_soleil, cos_soleil);
	if (!AT_CUBEMAP_PASS) {
		c += couleur_soleil * disque * force_soleil * step(0.0, d.y);
	}
	COLOR = c;
}
