// Sol de la Préhistoire : galets de plage, neige, terre gelée et roche.
// Le code du terrain indique dans la couleur des sommets la part de chaque sol
// (rouge = galets, vert = neige, bleu = terre gelée) ; la roche apparaît
// automatiquement sur les pentes raides (falaises).
// Chaque sol utilise une texture réaliste Poly Haven si elle est présente,
// sinon une couleur unie avec du bruit.
shader_type spatial;

uniform sampler2D bruit : filter_linear_mipmap, repeat_enable;

uniform sampler2D galets_couleur : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D galets_relief : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D galets_arm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool galets_texture = false;
uniform float galets_motif = 3.0;
uniform vec3 galets_simple : source_color = vec3(0.36, 0.35, 0.33);

uniform sampler2D neige_couleur : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D neige_relief : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D neige_arm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool neige_texture = false;
uniform float neige_motif = 6.0;
uniform vec3 neige_simple : source_color = vec3(0.86, 0.89, 0.93);

uniform sampler2D sol_couleur : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sol_relief : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sol_arm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool sol_texture = false;
uniform float sol_motif = 4.0;
uniform vec3 sol_simple : source_color = vec3(0.33, 0.29, 0.22);

uniform sampler2D roche_couleur : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roche_relief : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roche_arm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool roche_texture = false;
uniform float roche_motif = 8.0;
uniform vec3 roche_simple : source_color = vec3(0.52, 0.50, 0.46);
// Teinte appliquée à la roche (calcaire clair des falaises).
uniform vec3 roche_teinte : source_color = vec3(1.0, 0.97, 0.92);

// Hauteur de la mer : les galets en dessous sont mouillés (plus sombres et brillants).
uniform float niveau_mer = 0.0;
// Réglages propres à chaque objet (rochers, montagnes lointaines) :
// roche_forcee = 1 pour un rocher entier ; neige_en_plus = neige posée dessus.
instance uniform float roche_forcee = 0.0;
instance uniform float neige_en_plus = 0.0;

varying vec3 position_monde;
varying vec3 normale_monde;
varying vec4 parts;

// Échantillonne une texture à deux échelles pour casser la répétition visible.
vec4 deux_echelles(sampler2D t, vec2 uv, float melange) {
	return mix(texture(t, uv), texture(t, uv * 0.27 + vec2(0.31, 0.17)), melange);
}

void vertex() {
	position_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normale_monde = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	parts = COLOR;
}

void fragment() {
	vec2 xz = position_monde.xz;
	float grand = texture(bruit, xz * 0.008).r;
	float moyen = texture(bruit, xz * 0.05).r;
	float fin = texture(bruit, xz * 0.4).r;
	float melange = smoothstep(0.35, 0.65, grand) * 0.5;

	// --- Part de chaque sol ---
	float w_galets = parts.r;
	float w_neige = parts.g;
	float w_sol = parts.b;
	// Bord de neige irrégulier.
	w_neige = max(w_neige, neige_en_plus);
	w_neige = clamp(w_neige + (moyen - 0.5) * 0.9, 0.0, 1.0);
	w_neige = smoothstep(0.35, 0.65, w_neige);
	float pente = 1.0 - normale_monde.y;
	float w_roche = max(smoothstep(0.30, 0.48, pente + (moyen - 0.5) * 0.18), roche_forcee);
	// La neige tient sur les pentes douces, glisse des falaises.
	// (Sur un rocher, elle ne reste que sur le dessus.)
	w_neige *= mix(1.0 - smoothstep(0.25, 0.42, pente), smoothstep(0.55, 0.85, normale_monde.y), roche_forcee);
	float total = max(w_galets + w_sol, 0.001);
	w_galets /= total;
	w_sol /= total;

	// --- Galets ---
	vec2 uv_g = xz / galets_motif;
	vec3 c_galets = galets_simple * (0.7 + 0.6 * fin);
	vec3 a_galets = vec3(1.0, 0.85, 0.0);
	vec3 n_galets = vec3(0.5, 0.5, 1.0);
	if (galets_texture) {
		c_galets = deux_echelles(galets_couleur, uv_g, melange).rgb;
		a_galets = deux_echelles(galets_arm, uv_g, melange).rgb;
		n_galets = deux_echelles(galets_relief, uv_g, melange).rgb;
	}
	// Galets mouillés près de l'eau.
	float mouille = 1.0 - smoothstep(niveau_mer, niveau_mer + 0.7, position_monde.y);
	c_galets *= mix(1.0, 0.55, mouille);
	a_galets.g = mix(a_galets.g, 0.15, mouille);

	// --- Terre gelée ---
	vec2 uv_s = xz / sol_motif;
	vec3 c_sol = sol_simple * (0.75 + 0.5 * fin) * (0.85 + 0.3 * moyen);
	vec3 a_sol = vec3(1.0, 0.92, 0.0);
	vec3 n_sol = vec3(0.5, 0.5, 1.0);
	if (sol_texture) {
		c_sol = deux_echelles(sol_couleur, uv_s, melange).rgb;
		a_sol = deux_echelles(sol_arm, uv_s, melange).rgb;
		n_sol = deux_echelles(sol_relief, uv_s, melange).rgb;
	}
	// Givre léger sur la terre.
	c_sol = mix(c_sol, vec3(0.78, 0.82, 0.86), smoothstep(0.55, 0.8, moyen) * 0.35);

	// --- Neige ---
	vec2 uv_n = xz / neige_motif;
	vec3 c_neige = neige_simple * (0.93 + 0.1 * fin);
	vec3 a_neige = vec3(1.0, 0.6, 0.0);
	vec3 n_neige = vec3(0.5, 0.5, 1.0);
	if (neige_texture) {
		c_neige = deux_echelles(neige_couleur, uv_n, melange).rgb;
		a_neige = deux_echelles(neige_arm, uv_n, melange).rgb;
		n_neige = deux_echelles(neige_relief, uv_n, melange).rgb;
	}

	// --- Roche (projection triplanaire : pas d'étirement sur les falaises) ---
	vec3 poids = pow(abs(normale_monde), vec3(4.0));
	poids /= (poids.x + poids.y + poids.z);
	vec3 c_roche = roche_simple * (0.7 + 0.6 * fin) * (0.85 + 0.3 * moyen);
	vec3 a_roche = vec3(1.0, 0.9, 0.0);
	vec3 n_roche = vec3(0.5, 0.5, 1.0);
	if (roche_texture) {
		vec3 p = position_monde / roche_motif;
		c_roche = texture(roche_couleur, p.zy).rgb * poids.x + texture(roche_couleur, p.xz).rgb * poids.y
				+ texture(roche_couleur, p.xy).rgb * poids.z;
		a_roche = texture(roche_arm, p.zy).rgb * poids.x + texture(roche_arm, p.xz).rgb * poids.y
				+ texture(roche_arm, p.xy).rgb * poids.z;
		n_roche = texture(roche_relief, p.zy).rgb * poids.x + texture(roche_relief, p.xz).rgb * poids.y
				+ texture(roche_relief, p.xy).rgb * poids.z;
	}
	c_roche *= roche_teinte;

	// --- Mélange final ---
	vec3 c = c_galets * w_galets + c_sol * w_sol;
	vec3 a = a_galets * w_galets + a_sol * w_sol;
	vec3 n = n_galets * w_galets + n_sol * w_sol;
	c = mix(c, c_roche, w_roche);
	a = mix(a, a_roche, w_roche);
	n = mix(n, n_roche, w_roche);
	c = mix(c, c_neige, w_neige);
	a = mix(a, a_neige, w_neige);
	n = mix(n, n_neige, w_neige);

	ALBEDO = c;
	AO = a.r;
	AO_LIGHT_AFFECT = 0.3;
	ROUGHNESS = a.g;
	METALLIC = 0.0;
	NORMAL_MAP = n;
	SPECULAR = mix(0.4, 0.55, w_neige);
	// La neige laisse un peu passer la lumière (aspect moins « plâtre »).
	SSS_STRENGTH = w_neige * 0.25;
}
