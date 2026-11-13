// Sol de ville mouillé par la pluie : texture réaliste (Poly Haven) plaquée selon
// la position dans le monde, assombrie et rendue brillante là où l'eau s'accumule
// (flaques). Les reflets des néons viennent des réflexions de l'écran (SSR).
// Les gouttes font des ronds dans l'eau (plus visibles dans les flaques).
shader_type spatial;

#include "res://shaders/pluie_impacts.gdshaderinc"

uniform sampler2D texture_couleur : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D texture_relief : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// AO (rouge), rugosité (vert), métal (bleu).
uniform sampler2D texture_arm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bruit_flaques : filter_linear_mipmap, repeat_enable;
// Taille réelle d'une répétition de la texture (mètres).
uniform float taille_motif = 4.0;
// 0 = sec, 1 = détrempé.
uniform float humidite : hint_range(0.0, 1.0) = 0.6;
// Part du sol couverte de flaques.
uniform float flaques : hint_range(0.0, 1.0) = 0.32;
uniform vec3 teinte : source_color = vec3(1.0);
// Force des ronds de pluie (0 = pas de pluie). Réglé par la qualité graphique.
global uniform float pluie_impacts;

varying vec3 position_monde;

void vertex() {
	position_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = position_monde.xz / taille_motif;
	vec3 couleur = texture(texture_couleur, uv).rgb * teinte;
	vec3 arm = texture(texture_arm, uv).rgb;
	float valeur = texture(bruit_flaques, position_monde.xz * 0.035).r;
	float flaque = smoothstep(1.0 - flaques, 1.0 - flaques + 0.08, valeur);
	// Bord des flaques : zone humide plus sombre.
	float bord = smoothstep(1.0 - flaques - 0.12, 1.0 - flaques, valeur);
	float mouille = clamp(humidite + bord * 0.4 + flaque, 0.0, 1.0);
	// Un sol mouillé est plus sombre et beaucoup plus lisse ; une flaque est un miroir.
	ALBEDO = couleur * mix(1.0, 0.62, mouille) * mix(1.0, 0.6, flaque);
	// Pellicule d'eau : très lisse dans les creux de la texture (joints, fissures).
	float pellicule = clamp(humidite * 1.4 - arm.r * 0.3, 0.0, 1.0);
	ROUGHNESS = mix(arm.g, 0.07, pellicule);
	ROUGHNESS = mix(ROUGHNESS, 0.01, flaque);
	METALLIC = arm.b;
	AO = arm.r;
	vec3 relief = mix(texture(texture_relief, uv).rgb, vec3(0.5, 0.5, 1.0), flaque * 0.95);
	vec2 ronds = impacts_pluie(position_monde.xz, TIME, pluie_impacts) * mix(0.25, 1.0, flaque);
	relief.xy += ronds * 0.35;
	NORMAL_MAP = relief;
	SPECULAR = 0.5;
}
