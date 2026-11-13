// Goutte de pluie : un trait fin toujours tourné vers la caméra et allongé dans
// le sens de la chute. Les gouttes s'éclairent près des néons et des lampadaires
// (c'est ce qui donne l'ambiance des rues de Tokyo sous la pluie).
shader_type spatial;
render_mode world_vertex_coords, cull_disabled, shadows_disabled, depth_draw_never, blend_mix;

uniform float largeur = 0.012;
uniform float longueur = 0.6;
uniform float opacite = 0.35;
uniform vec3 couleur : source_color = vec3(0.55, 0.6, 0.7);
// Lueur propre (pour voir la pluie même loin des lumières).
uniform float lueur = 0.03;

void vertex() {
	vec3 origine = MODEL_MATRIX[3].xyz;
	vec3 axe_y = normalize(MODEL_MATRIX[1].xyz);
	vec3 vers_camera = normalize(CAMERA_POSITION_WORLD - origine);
	vec3 axe_x = normalize(cross(axe_y, vers_camera));
	VERTEX = origine + axe_x * (UV.x - 0.5) * largeur + axe_y * (0.5 - UV.y) * longueur;
	NORMAL = vers_camera;
}

void fragment() {
	float travers = 1.0 - abs(UV.x - 0.5) * 2.0;
	float le_long = smoothstep(0.0, 0.3, UV.y) * smoothstep(1.0, 0.6, UV.y);
	ALBEDO = couleur;
	EMISSION = couleur * lueur;
	ALPHA = travers * le_long * opacite;
	ROUGHNESS = 0.2;
}

void light() {
	// Une goutte diffuse la lumière dans toutes les directions.
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * 0.45;
}
