// Pelage du mammouth laineux : mèches sombres et rousses, longues traînées
// verticales, et longues mèches de poils (cartes à transparence découpée).
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D bruit : filter_linear_mipmap, repeat_enable;
uniform vec3 sombre : source_color = vec3(0.07, 0.045, 0.03);
uniform vec3 roux : source_color = vec3(0.32, 0.19, 0.1);
uniform bool meches = false;

varying vec3 position_locale;
varying float clair;

void vertex() {
	position_locale = VERTEX;
	clair = COLOR.r;
}

void fragment() {
	vec3 p = position_locale;
	if (meches) {
		// Une mèche : plusieurs brins qui s'effilent vers le bas.
		float brins = texture(bruit, vec2(UV.x * 0.35 + clair, UV.y * 0.04)).r;
		float fil = sin(UV.x * 31.0 + brins * 9.0) * 0.5 + 0.5;
		float bord = 1.0 - pow(abs(UV.x * 2.0 - 1.0), 2.0);
		ALPHA = fil * bord * (1.0 - UV.y * 0.75) + brins * 0.3;
		ALPHA_SCISSOR_THRESHOLD = 0.42;
		vec3 c = mix(sombre, roux, 0.25 + clair * 0.55 + UV.y * 0.15);
		ALBEDO = c * (0.75 + fil * 0.35);
		ROUGHNESS = 0.85;
		SPECULAR = 0.25;
	} else {
		float traine = texture(bruit, vec2((p.x + p.z) * 0.9, p.y * 0.35 + p.x * 0.3)).r;
		float fin = texture(bruit, vec2((p.x - p.z) * 11.0, p.y * 1.2)).r;
		float brins = texture(bruit, vec2((p.x + p.z * 0.7) * 26.0, p.y * 2.0)).r;
		vec3 c = mix(sombre, roux, clamp(clair * 0.9 + (traine - 0.5) * 0.5, 0.0, 1.0));
		ALBEDO = c * (0.72 + fin * 0.25 + brins * 0.25);
		ROUGHNESS = 0.95;
		SPECULAR = 0.2;
		// Relief des mèches.
		float e = 0.02;
		float h0 = texture(bruit, vec2((p.x + p.z) * 7.0, p.y * 0.9)).r;
		float hx = texture(bruit, vec2((p.x + p.z) * 7.0 + e, p.y * 0.9)).r;
		float hy = texture(bruit, vec2((p.x + p.z) * 7.0, p.y * 0.9 + e)).r;
		NORMAL_MAP = normalize(vec3((h0 - hx) * 14.0, (h0 - hy) * 4.0, 1.0)) * 0.5 + 0.5;
		NORMAL_MAP_DEPTH = 1.2;
	}
	BACKLIGHT = vec3(0.12, 0.07, 0.04);
}
