shader_type spatial;
// Écran d'affiche du hub : deux images en fondu, chacune avec un lent travelling
// (cadre = focus x, focus y, zoom), un léger balayage de lignes et un liseré.
render_mode unshaded, cull_back;

uniform sampler2D image_a : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D image_b : source_color, filter_linear_mipmap, repeat_disable;
uniform float melange : hint_range(0.0, 1.0) = 0.0;
uniform vec3 cadre_a = vec3(0.5, 0.5, 1.0);
uniform vec3 cadre_b = vec3(0.5, 0.5, 1.0);
uniform float luminosite = 1.15;
uniform vec4 liseret : source_color = vec4(0.35, 0.88, 0.95, 1.0);

vec2 dans_cadre(vec2 uv, vec3 c) {
	vec2 taille = vec2(1.0 / max(c.z, 1.0));
	return (vec2(1.0) - taille) * c.xy + uv * taille;
}

void fragment() {
	vec3 a = texture(image_a, dans_cadre(UV, cadre_a)).rgb;
	vec3 b = texture(image_b, dans_cadre(UV, cadre_b)).rgb;
	vec3 c = mix(a, b, melange);
	// Lignes de balayage très discrètes et bas de l'image assombri (pour le texte).
	c *= 0.94 + 0.06 * sin(UV.y * 900.0 + TIME * 3.0);
	c *= mix(1.0, 0.45, smoothstep(0.62, 1.0, UV.y));
	// Liseré lumineux.
	float bord = max(smoothstep(0.988, 1.0, max(UV.x, UV.y)), smoothstep(0.012, 0.0, min(UV.x, UV.y)));
	c = mix(c, liseret.rgb * 1.6, bord);
	ALBEDO = c * luminosite;
}
