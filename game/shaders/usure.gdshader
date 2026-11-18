// Usure des matériaux (passe supplémentaire, multiplie l'image déjà éclairée) :
// variations de teinte à grande échelle, coulures sur les murs, salissure au pied,
// poussière sur les dessus. Ajoutée en « next_pass » par ile_prehistoire._mat_pbr.
shader_type spatial;
render_mode blend_mul, unshaded, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform sampler2D bruit : filter_linear_mipmap, repeat_enable;
uniform float force = 1.0;
// Teinte de la poussière (sable, terre) sur les surfaces tournées vers le ciel.
uniform vec3 poussiere = vec3(1.1, 1.05, 0.96);
// Demi-hauteur de la boîte (repère local) : la salissure monte depuis le bas. < 0 = pas de pied.
instance uniform float demi_hauteur = -1.0;

varying vec3 pos_monde;
varying vec3 n_monde;
varying float y_local;

void vertex() {
	pos_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	n_monde = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	y_local = VERTEX.y;
}

float triplanaire(vec3 p, vec3 n, float echelle) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(bruit, p.zy * echelle).r * w.x
			+ texture(bruit, p.xz * echelle).r * w.y
			+ texture(bruit, p.xy * echelle).r * w.z;
}

void fragment() {
	float macro = triplanaire(pos_monde, n_monde, 0.03);
	float moyen = triplanaire(pos_monde, n_monde, 0.16);
	float m = 1.0 + (macro - 0.5) * 0.5 * force + (moyen - 0.5) * 0.22 * force;
	// Coulures verticales sur les murs (pluie, ruissellement).
	float vertical = 1.0 - abs(n_monde.y);
	float coulure = texture(bruit, vec2(dot(pos_monde.xz, vec2(0.71, 0.71)) * 0.8, pos_monde.y * 0.035)).r;
	m *= 1.0 - vertical * smoothstep(0.42, 0.8, coulure) * 0.24 * force;
	// Salissure au pied des murs (éclaboussures, terre, humidité).
	if (demi_hauteur > 0.0) {
		float h = y_local + demi_hauteur;
		m *= mix(0.55, 1.0, smoothstep(0.0, 0.9 + moyen * 1.2, h));
	}
	vec3 c = vec3(m);
	// Poussière sur les dessus.
	float dessus = smoothstep(0.55, 0.95, n_monde.y);
	c *= mix(vec3(1.0), poussiere, dessus * (0.5 + moyen * 0.5) * force);
	ALBEDO = c;
}
