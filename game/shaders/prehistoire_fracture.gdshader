// Surcouche des créatures « fracturées » : veines violettes lumineuses qui
// palpitent et un lisere violet sur la silhouette.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform sampler2D bruit : filter_linear_mipmap, repeat_enable;
uniform vec3 couleur : source_color = vec3(0.62, 0.22, 1.0);
uniform float intensite = 1.6;

varying vec3 position_locale;

void vertex() {
	position_locale = VERTEX;
}

void fragment() {
	float lisere = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float n = texture(bruit, position_locale.xy * 2.2 + vec2(position_locale.z * 1.7, TIME * 0.1)).r;
	float veines = 1.0 - smoothstep(0.0, 0.04, abs(n - 0.5));
	float pouls = 0.6 + 0.4 * sin(TIME * 4.0 + position_locale.z * 6.0);
	ALBEDO = couleur * (lisere * 1.2 + veines * pouls * 1.5) * intensite;
}
