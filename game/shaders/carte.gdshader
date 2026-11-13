shader_type canvas_item;
// Dessin de la carte : vue du ciel × relief, recouverte d'un brouillard là où
// le joueur n'est pas encore allé. Sert à la mini-carte (ronde, centrée sur
// le joueur) et à la grande carte (toute la zone).

uniform sampler2D carte : source_color, filter_linear, repeat_disable;
uniform sampler2D relief : filter_linear, repeat_disable;
uniform sampler2D brouillard : filter_linear, repeat_disable;
// Point de la carte (0..1) au centre du dessin, et part de la carte visible.
uniform vec2 centre = vec2(0.5);
uniform vec2 etendue = vec2(1.0);
uniform float angle = 0.0;
uniform bool rond = false;
uniform vec4 couleur_brouillard : source_color = vec4(0.045, 0.06, 0.09, 0.94);
uniform vec4 couleur_bord : source_color = vec4(0.62, 0.48, 1.0, 1.0);
uniform vec4 couleur_dehors : source_color = vec4(0.02, 0.03, 0.05, 0.9);
float hasard_carte(vec2 p) {
	// Hachage sans sin() : sin() sur de grandes valeurs est imprécis sur les cartes
	// NVIDIA et dessinait des facettes (bandes, quadrilatères) dans les motifs.
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}


float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hasard_carte(i);
	float b = hasard_carte(i + vec2(1.0, 0.0));
	float c = hasard_carte(i + vec2(0.0, 1.0));
	float d = hasard_carte(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p);
	if (rond && r > 0.5) {
		discard;
	}
	float c = cos(angle);
	float s = sin(angle);
	vec2 q = vec2(c * p.x - s * p.y, s * p.x + c * p.y);
	vec2 uv = centre + q * etendue;
	bool dedans = uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0;
	vec3 sol = texture(carte, uv).rgb * texture(relief, uv).r * 2.0;
	// Légère teinte « écran de la Vigie ».
	float gris = dot(sol, vec3(0.3, 0.55, 0.15));
	sol = mix(sol, vec3(gris) * vec3(0.9, 0.97, 1.08), 0.25);
	float vu = dedans ? texture(brouillard, uv).r : 0.0;
	// Bord du brouillard un peu irrégulier, comme de la brume.
	float brume = bruit(uv * 60.0) * 0.5 + bruit(uv * 160.0) * 0.25;
	vu = smoothstep(0.15, 0.85, vu + (brume - 0.35) * 0.35 * (1.0 - vu) * vu * 4.0);
	vec3 voile = couleur_brouillard.rgb * (0.85 + brume * 0.35);
	vec4 couleur = dedans ? vec4(mix(voile, sol, vu), mix(couleur_brouillard.a, 1.0, vu))
			: couleur_dehors;
	if (rond) {
		float anneau = smoothstep(0.455, 0.47, r);
		couleur = mix(couleur, vec4(couleur_bord.rgb * 0.8, 1.0), anneau);
		couleur.a *= 1.0 - smoothstep(0.49, 0.5, r);
	}
	COLOR = couleur;
}
