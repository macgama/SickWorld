// Finition « cinéma » de l'image : vignettage, légère aberration chromatique
// sur les bords (comme un objectif réel) et grain de film très discret.
shader_type canvas_item;

uniform sampler2D ecran : hint_screen_texture, filter_linear_mipmap;
uniform float vignettage : hint_range(0.0, 1.0) = 0.32;
uniform float aberration : hint_range(0.0, 0.01) = 0.0018;
uniform float grain : hint_range(0.0, 0.2) = 0.03;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r2 = dot(c, c);
	vec2 decalage = c * aberration * r2 * 4.0;
	vec3 couleur;
	couleur.r = texture(ecran, uv + decalage).r;
	couleur.g = texture(ecran, uv).g;
	couleur.b = texture(ecran, uv - decalage).b;
	couleur *= 1.0 - vignettage * smoothstep(0.05, 0.6, r2 * 1.7);
	vec3 g3 = fract(vec3((uv * 1000.0 + fract(TIME * 7.13) * 100.0).xyx) * 0.1031);
	g3 += dot(g3, g3.yzx + 33.33);
	float g = fract((g3.x + g3.y) * g3.z);
	couleur += (g - 0.5) * grain;
	COLOR = vec4(couleur, 1.0);
}
