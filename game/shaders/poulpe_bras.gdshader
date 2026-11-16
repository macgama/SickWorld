shader_type spatial;
// Le vrai poulpe (« Octopus with Textured Reddish-Brown Skin », Pigcraft, CC-BY) n'a
// pas de squelette : ses bras ondulent ici, sommet par sommet, selon leur distance
// au centre du corps. Repère du modèle : la face regarde vers +X, le manteau est en haut.

uniform sampler2D couleur : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normales : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rugosite_metal : hint_default_white, filter_linear_mipmap, repeat_enable;
// Taches violettes de la fracture (bruit), qui pulsent.
uniform sampler2D taches : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float fracture : hint_range(0.0, 1.0) = 1.0;
uniform vec3 centre = vec3(0.0, 0.0, 0.0);
// Rythme de l'ondulation (plus vif quand il se déplace).
uniform float phase = 0.0;
// Coup de bras vers l'avant (0 à 1).
uniform float frappe : hint_range(0.0, 1.0) = 0.0;
// Mort : il s'affaisse, les bras à plat (0 à 1).
uniform float affaisse : hint_range(0.0, 1.0) = 0.0;

varying float v_bras;

void vertex() {
	vec3 p = VERTEX - centre;
	float r = length(p.xz);
	// 0 sur le corps, 1 au bout des bras.
	float w = smoothstep(0.1, 0.42, r);
	float a = atan(p.z, p.x);
	float onde = sin(phase - r * 9.0 + a * 3.0);
	float onde2 = sin(phase * 0.8 - r * 6.0 + a * 5.0 + 1.7);
	// Les bras se soulèvent et retombent, et se tordent un peu sur le côté.
	VERTEX.y += (onde * 0.07 + onde2 * 0.035) * w * w;
	float torsion = onde2 * 0.22 * w * w;
	float c = cos(torsion);
	float s = sin(torsion);
	vec2 xz = vec2(p.x * c - p.z * s, p.x * s + p.z * c);
	VERTEX.x = xz.x + centre.x;
	VERTEX.z = xz.y + centre.z;
	// Le manteau respire.
	float corps = 1.0 - w;
	VERTEX.y += corps * max(p.y, 0.0) * sin(phase * 0.45) * 0.06;
	// Le coup : les bras de devant (+X) se dressent et fouettent.
	float devant = pow(max(cos(a), 0.0), 3.0);
	VERTEX.y += frappe * devant * w * 0.45;
	VERTEX.x -= frappe * devant * w * 0.12;
	// Mort : tout s'aplatit et s'étale.
	VERTEX.y = mix(VERTEX.y, centre.y + (VERTEX.y - centre.y) * 0.35 - 0.08, affaisse);
	VERTEX.xz = mix(VERTEX.xz, centre.xz + (VERTEX.xz - centre.xz) * 1.12, affaisse * w);
	v_bras = w;
}

void fragment() {
	vec4 c = texture(couleur, UV);
	ALBEDO = c.rgb;
	vec4 rm = texture(rugosite_metal, UV);
	// La peau est humide : un peu plus brillante que la texture d'origine.
	ROUGHNESS = rm.g * 0.75;
	METALLIC = 0.0;
	SPECULAR = 0.55;
	NORMAL_MAP = texture(normales, UV).rgb;
	float t = texture(taches, UV * 2.0).r;
	float tache = smoothstep(0.8, 0.88, t) * fracture * (1.0 - affaisse);
	EMISSION = vec3(0.5, 0.12, 0.9) * tache * (0.7 + 0.5 * sin(TIME * 2.3 + t * 12.0));
}
