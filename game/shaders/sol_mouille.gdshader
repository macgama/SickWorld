// Sol de ville mouillé par la pluie : texture réaliste (Poly Haven) plaquée selon
// la position dans le monde, assombrie et rendue brillante là où l'eau s'accumule
// (flaques). Les reflets des néons viennent des réflexions de l'écran (SSR).
shader_type spatial;

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
uniform float flaques : hint_range(0.0, 1.0) = 0.2;
uniform vec3 teinte : source_color = vec3(1.0);

varying vec3 position_monde;

void vertex() {
	position_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = position_monde.xz / taille_motif;
	vec3 couleur = texture(texture_couleur, uv).rgb * teinte;
	vec3 arm = texture(texture_arm, uv).rgb;
	float flaque = smoothstep(1.0 - flaques, 1.0 - flaques + 0.08,
			texture(bruit_flaques, position_monde.xz * 0.035).r);
	float mouille = clamp(humidite + flaque, 0.0, 1.0);
	// Un sol mouillé est plus sombre et beaucoup plus lisse ; une flaque est un miroir.
	ALBEDO = couleur * mix(1.0, 0.7, mouille);
	ROUGHNESS = mix(arm.g, 0.12, humidite * 0.75);
	ROUGHNESS = mix(ROUGHNESS, 0.02, flaque);
	METALLIC = arm.b;
	AO = arm.r;
	NORMAL_MAP = mix(texture(texture_relief, uv).rgb, vec3(0.5, 0.5, 1.0), flaque * 0.9);
	SPECULAR = 0.5;
}
