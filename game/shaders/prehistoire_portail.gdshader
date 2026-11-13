// Voile du portail de la Vigie : un tourbillon bleu, lumineux au centre.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;

uniform sampler2D bruit : filter_linear_mipmap, repeat_enable;
uniform vec3 couleur : source_color = vec3(0.25, 0.75, 1.0);
uniform float intensite = 1.6;

void fragment() {
	vec2 c = UV - 0.5;
	float r = length(c) * 2.0;
	float a = atan(c.y, c.x);
	float tour = texture(bruit, vec2(a / 6.2832 + r * 0.6 - TIME * 0.08, r * 0.5 - TIME * 0.05)).r;
	float disque = 1.0 - smoothstep(0.86, 0.97, r);
	float centre = 1.0 - smoothstep(0.0, 0.7, r);
	float e = disque * (0.25 + tour * 0.9 + centre * 0.6);
	ALBEDO = mix(couleur, vec3(0.9, 0.97, 1.0), centre * 0.6) * e * intensite;
	ALPHA = clamp(e, 0.0, 1.0);
}
