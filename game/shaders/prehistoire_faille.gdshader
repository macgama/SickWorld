// Faille temporelle : une déchirure violette dans l'air, qui ondule et crépite.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;

uniform sampler2D bruit : filter_linear_mipmap, repeat_enable;
uniform vec3 couleur_bord : source_color = vec3(0.65, 0.25, 1.0);
uniform vec3 couleur_coeur : source_color = vec3(0.95, 0.85, 1.0);
uniform float intensite = 3.0;
// 1 = faille ouverte, 0 = refermée.
uniform float ouverture : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	// Largeur de la déchirure : fine aux extrémités, plus large au milieu.
	float profil = sin(uv.y * 3.14159) * (0.55 + 0.45 * sin(uv.y * 9.0 + t * 1.3));
	float ondule = (texture(bruit, vec2(uv.y * 1.5, t * 0.15)).r - 0.5) * 0.35;
	float x = abs(uv.x - 0.5 - ondule * profil);
	float largeur = 0.16 * profil * ouverture;
	float coeur = 1.0 - smoothstep(0.0, largeur * 0.35 + 0.002, x);
	float halo = 1.0 - smoothstep(0.0, largeur * 2.2 + 0.01, x);
	float crepite = texture(bruit, uv * vec2(4.0, 1.5) + vec2(t * 0.4, -t * 0.7)).r;
	float energie = coeur * 1.6 + halo * (0.35 + crepite * 0.9);
	vec3 c = mix(couleur_bord, couleur_coeur, coeur);
	ALBEDO = c * energie * intensite;
	ALPHA = clamp(energie, 0.0, 1.0);
}
