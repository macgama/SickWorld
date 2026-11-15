shader_type spatial;
// Robe d'un cheval recolorée : on garde le relief du poil (détails de la texture
// d'origine) mais on remplace les taches par une couleur unie (« robe »), avec le
// bas des pattes plus sombre. Sert au cheval de Przewalski (robe isabelle,
// pattes noires). Les zones roses (bouche, naseaux) gardent leur couleur.

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap;
uniform sampler2D texture_normal : hint_normal, filter_linear_mipmap;
uniform float force_normale = 1.0;
uniform vec3 robe : source_color = vec3(0.72, 0.56, 0.34);
uniform vec3 pattes : source_color = vec3(0.16, 0.12, 0.09);
// Niveau de flou (mipmap) qui donne la couleur moyenne autour du pixel.
uniform float flou = 6.0;
// Hauteur du sol sous la bête (monde) et hauteur du garrot (mètres), réglés par le jeu.
uniform float sol = 0.0;
uniform float garrot = 1.35;
uniform float rugosite = 0.85;

varying float hauteur_monde;

void vertex() {
	hauteur_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	vec4 c = texture(texture_albedo, UV);
	vec3 moyenne = textureLod(texture_albedo, UV, flou).rgb;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float lm = max(dot(moyenne, vec3(0.299, 0.587, 0.114)), 0.04);
	float detail = clamp(l / lm, 0.55, 1.5);
	float h = (hauteur_monde - sol) / max(garrot, 0.1);
	float noir = 1.0 - smoothstep(0.22, 0.42, h);
	vec3 teinte = mix(robe, pattes, noir) * detail;
	float rose = smoothstep(0.02, 0.08, c.b - c.g) * smoothstep(0.12, 0.25, c.r - c.g);
	ALBEDO = mix(teinte, c.rgb, rose);
	NORMAL_MAP = texture(texture_normal, UV).rgb;
	NORMAL_MAP_DEPTH = force_normale;
	ROUGHNESS = rugosite;
}
