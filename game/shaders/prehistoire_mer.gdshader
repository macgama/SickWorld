// Mer glaciale : eau sombre et froide, petites vagues, écume le long du rivage
// et autour des blocs de glace (calculée avec la profondeur de l'image).
shader_type spatial;
render_mode cull_back, depth_draw_always;

uniform sampler2D vagues_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D vagues_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D bruit_ecume : filter_linear_mipmap, repeat_enable;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform vec3 couleur_profonde : source_color = vec3(0.015, 0.06, 0.08);
uniform vec3 couleur_claire : source_color = vec3(0.10, 0.28, 0.30);
uniform vec3 couleur_ecume : source_color = vec3(0.86, 0.9, 0.93);
// Profondeur (mètres) à laquelle on ne voit plus le fond.
uniform float transparence = 3.5;
uniform float largeur_ecume = 0.9;
uniform float vitesse = 0.025;
uniform float hauteur_houle = 0.18;

varying vec3 position_monde;

void vertex() {
	position_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Houle lente.
	float h = sin(position_monde.x * 0.07 + TIME * 0.6) * cos(position_monde.z * 0.05 + TIME * 0.45);
	VERTEX.y += h * hauteur_houle;
}

void fragment() {
	vec2 uv = position_monde.xz;
	vec3 n1 = texture(vagues_a, uv * 0.045 + vec2(TIME * vitesse, TIME * vitesse * 0.4)).rgb;
	vec3 n2 = texture(vagues_b, uv * 0.11 - vec2(TIME * vitesse * 0.6, TIME * vitesse)).rgb;
	NORMAL_MAP = normalize(mix(n1, n2, 0.5));
	NORMAL_MAP_DEPTH = 0.7;

	// Épaisseur d'eau entre la surface et le fond (en mètres).
	float profondeur_brute = texture(DEPTH_TEXTURE, SCREEN_UV).r;
	vec4 fond = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, profondeur_brute, 1.0);
	fond.xyz /= fond.w;
	float epaisseur = clamp(-fond.z + VERTEX.z, 0.0, 100.0);

	float limpide = exp(-epaisseur / transparence);
	vec3 couleur = mix(couleur_profonde, couleur_claire, limpide * 0.8);
	// On voit un peu le fond (galets) là où l'eau est peu profonde.
	vec3 dessous = texture(SCREEN_TEXTURE, SCREEN_UV + NORMAL_MAP.xy * 0.01 - 0.005).rgb;
	couleur = mix(couleur, dessous * vec3(0.55, 0.75, 0.75), limpide * 0.75);

	// Écume au contact du rivage et de la glace.
	float motif = texture(bruit_ecume, uv * 0.35 + vec2(TIME * 0.03, 0.0)).r;
	float ecume = (1.0 - smoothstep(0.0, largeur_ecume, epaisseur)) * smoothstep(0.35, 0.65, motif + 0.25);
	ecume += (1.0 - smoothstep(0.0, largeur_ecume * 0.35, epaisseur)) * 0.6;
	ecume = clamp(ecume, 0.0, 1.0);

	ALBEDO = mix(couleur, couleur_ecume, ecume);
	ROUGHNESS = mix(0.04, 0.8, ecume);
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
