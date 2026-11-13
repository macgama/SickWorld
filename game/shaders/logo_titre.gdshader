shader_type canvas_item;
// Logo de l'écran titre : dégradé cyan → blanc → violet, reflet qui balaie
// les lettres, fissure violette (une « fracture » du temps) et petits
// parasites de temps en temps (force_glitch, piloté par menu.gd).

uniform float force_glitch : hint_range(0.0, 1.0) = 0.0;
uniform vec4 couleur_a : source_color = vec4(0.35, 0.88, 0.95, 1.0);
uniform vec4 couleur_b : source_color = vec4(0.72, 0.42, 1.0, 1.0);
// Position horizontale de la fissure (0 = gauche, 1 = droite).
uniform float fissure_x = 0.455;

float hasard(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	// Parasites : des bandes horizontales se décalent.
	float t = floor(TIME * 14.0);
	float bande = floor(uv.y * 16.0);
	float decalage = (hasard(bande + t * 3.1) - 0.5) * 0.07 * force_glitch * step(0.55, hasard(bande * 7.3 + t));
	uv.x += decalage;
	// Fissure en zigzag.
	float fx = fissure_x + 0.012 * sin(uv.y * 31.0) + 0.006 * sin(uv.y * 77.0 + 1.3);
	float dans_fissure = 1.0 - smoothstep(0.0015, 0.0045, abs(uv.x - fx));
	// Les deux moitiés sont très légèrement décalées de part et d'autre.
	uv.y += (uv.x > fx ? 0.012 : 0.0);

	float ab = 0.0025 + 0.012 * force_glitch;
	vec4 base = texture(TEXTURE, uv);
	float r = texture(TEXTURE, uv + vec2(ab, 0.0)).a;
	float b = texture(TEXTURE, uv - vec2(ab, 0.0)).a;

	vec3 degrade = mix(couleur_a.rgb, vec3(1.0), smoothstep(0.05, 0.45, uv.x) * 0.75);
	degrade = mix(degrade, couleur_b.rgb, smoothstep(0.55, 1.0, uv.x) * 0.8);
	float reflet = smoothstep(0.06, 0.0, abs(uv.x - (fract(TIME * 0.09) * 1.8 - 0.4) - (uv.y - 0.5) * 0.25));
	vec3 couleur = base.rgb * degrade + vec3(reflet) * base.a * 0.7;
	// Franges colorées (aberration).
	couleur += couleur_b.rgb * max(r - base.a, 0.0) + couleur_a.rgb * max(b - base.a, 0.0);
	float alpha = max(base.a, max(r, b) * 0.6);
	// La fissure : un trait sombre bordé de violet lumineux.
	float bord = (1.0 - smoothstep(0.0, 0.02, abs(uv.x - fx))) * base.a;
	couleur = mix(couleur, couleur_b.rgb * 1.6, bord * 0.6);
	alpha *= 1.0 - dans_fissure * 0.95;
	COLOR = vec4(couleur, alpha);
}
