// Feu d'obstacle rouge au sommet des immeubles : clignote lentement, comme les
// vrais feux d'aviation, et reste visible de très loin.
shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform vec3 couleur : source_color = vec3(1.0, 0.08, 0.05);
uniform float energie = 12.0;
// Durée d'un cycle (secondes).
uniform float periode = 2.4;
instance uniform float decalage = 0.0;

void fragment() {
	float t = fract(TIME / periode + decalage);
	float allume = smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.35, 0.55, t));
	ALBEDO = couleur * (0.08 + allume * energie);
}
