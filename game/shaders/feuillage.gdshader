// Feuillage des arbres réalistes (scripts/monde/vegetation/arbres.gd) :
// cartes de rameaux découpées (alpha), lumière qui traverse les feuilles,
// vent (balancement des branches + frémissement des feuilles), teinte propre à chaque arbre.
// Couleur de sommet : r = souplesse (0 tronc, 1 bout des rameaux), g = phase, b = frémissement.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D texture_feuilles : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 teinte : source_color = vec3(1.0);
// Un arbre sur deux tire vers cette teinte (variété naturelle).
uniform vec3 teinte_variation : source_color = vec3(0.86, 0.92, 0.72);
uniform float translucidite = 0.55;
uniform float force_vent = 1.0;
uniform float seuil = 0.42;
// Renfort de l'alpha au loin (0 pour l'herbe : elle s'éclaircit au lieu de faire des blocs).
uniform float remonte_alpha = 0.28;
// Taille de la texture : sert à garder les feuilles pleines au loin (mipmaps).
uniform float taille_texture = 512.0;
uniform float saturation = 1.0;

varying float v_variation;

// Hachage sans sin() (les grands sin() font des facettes sur les cartes NVIDIA).
float hachage(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	vec3 origine = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float souple = COLOR.r;
	float phase = COLOR.g * 6.2832;
	float rafale = sin(TIME * 0.55 + origine.x * 0.045 + origine.z * 0.035) * 0.5 + 0.5;
	vec3 balance = vec3(sin(TIME * 1.6 + phase + origine.x * 0.3),
			sin(TIME * 2.1 + phase * 0.7) * 0.25,
			cos(TIME * 1.25 + phase * 1.3 + origine.z * 0.3) * 0.6);
	float fremit = sin(TIME * 8.0 + phase * 5.0 + VERTEX.y * 2.5) * COLOR.b;
	VERTEX += balance * (0.035 + 0.09 * rafale) * souple * force_vent;
	VERTEX += vec3(fremit, fremit * 0.6, -fremit) * 0.025 * force_vent;
	v_variation = hachage(origine.xz * 0.37 + vec2(3.1, 7.7));
}

void fragment() {
	vec4 c = texture(texture_feuilles, UV);
	// Au loin, les mipmaps « fondent » l'alpha : on le remonte pour garder des feuillages pleins.
	vec2 d = fwidth(UV) * taille_texture;
	float mip = max(0.0, log2(max(d.x, d.y)));
	float alpha = c.a * (1.0 + mip * remonte_alpha);
	vec3 col = c.rgb * teinte * mix(vec3(1.0), teinte_variation, v_variation);
	float gris = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(gris), col, saturation);
	ALBEDO = col;
	ALPHA = alpha;
	ALPHA_SCISSOR_THRESHOLD = seuil;
	ROUGHNESS = 0.72;
	SPECULAR = 0.32;
	BACKLIGHT = col * translucidite;
	// Godot retourne la normale des faces arrière ; les normales des cartes pointent déjà
	// vers l'extérieur du houppier, on annule ce retournement (éclairage doux et uniforme).
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
