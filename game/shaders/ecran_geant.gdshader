// Écran géant de la Place Hikari : un dégradé de néons qui défile,
// avec des lignes de balayage comme un vrai écran vu de près.
shader_type spatial;
render_mode unshaded;

uniform vec3 couleur_a : source_color = vec3(1.0, 0.25, 0.7);
uniform vec3 couleur_b : source_color = vec3(0.2, 0.6, 1.0);
uniform float luminosite = 1.4;
uniform float vitesse = 0.15;

void fragment() {
	float vague = sin((UV.x * 2.0 + UV.y * 0.6 - TIME * vitesse) * 6.2832) * 0.5 + 0.5;
	vec3 couleur = mix(couleur_a, couleur_b, vague);
	float lignes = 0.85 + 0.15 * sin(UV.y * 400.0);
	float bord = smoothstep(0.0, 0.02, UV.x) * smoothstep(1.0, 0.98, UV.x)
			* smoothstep(0.0, 0.04, UV.y) * smoothstep(1.0, 0.96, UV.y);
	ALBEDO = couleur * lignes * luminosite * (0.25 + 0.75 * bord);
}
