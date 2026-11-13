// Eau sombre de la baie (et de la fontaine) : vagues douces, très réfléchissante,
// avec les ronds de la pluie à la surface.
shader_type spatial;

#include "res://shaders/pluie_impacts.gdshaderinc"

uniform vec3 couleur : source_color = vec3(0.005, 0.02, 0.035);
uniform float hauteur_vagues = 0.35;
uniform float vitesse = 0.6;
// 0 = eau calme (fontaine), 1 = mer.
uniform float houle : hint_range(0.0, 1.0) = 1.0;
global uniform float pluie_impacts;

varying vec3 position_monde;

float vague(vec2 p, vec2 dir, float freq, float t) {
	return sin(dot(p, normalize(dir)) * freq + t);
}

void vertex() {
	position_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = position_monde.xz;
	float t = TIME * vitesse;
	// Pente de la surface = somme de plusieurs vagues (dérivées).
	vec2 pente = vec2(0.0);
	vec4 dirs[4] = vec4[](vec4(1.0, 0.3, 0.35, 1.0), vec4(-0.4, 1.0, 0.6, 1.3), vec4(0.8, -0.7, 1.4, 1.9), vec4(0.2, 0.9, 2.6, 2.7));
	for (int i = 0; i < 4; i++) {
		vec2 d = normalize(dirs[i].xy);
		float f = dirs[i].z;
		pente += d * cos(dot(p, d) * f + t * dirs[i].w) * f * hauteur_vagues / (1.0 + float(i) * 1.5);
	}
	pente *= houle;
	vec2 ronds = impacts_pluie(p, TIME, pluie_impacts);
	vec3 n = normalize(vec3(-pente.x * 0.15 + ronds.x * 0.25, 1.0, -pente.y * 0.15 + ronds.y * 0.25));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = couleur;
	ROUGHNESS = 0.03;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	// Plus opaque et réfléchissante en regardant au loin (effet de Fresnel déjà géré).
}
