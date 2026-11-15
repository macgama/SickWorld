extends GPUParticles3D
## Petites vies qui flottent dans l'air (vie ambiante des zones) : nuées de moucherons
## au-dessus de l'eau, mouches autour des enclos, papillons, poussière dorée dans un
## rayon de soleil, sable soulevé par le vent, duvet de graines, lucioles…
## Décrites dans data/vie_ambiante.json (clé « insectes »).
##
## « autour » : true = le nuage suit la caméra (poussière, sable, duvet) ;
## sinon il reste sur place, à « position » (nuée au-dessus d'une mare, d'un tas…).
## Tout est calculé par la carte graphique (GPUParticles) : quasiment gratuit.

## Réglages de chaque sorte : nombre par défaut, rayon (m), taille (m), couleur,
## durée de vie (s), agitation (turbulence), vitesse, lumineux.
const SORTES := {
	"moucherons": {"nombre": 70, "rayon": 1.4, "hauteur": 1.0, "taille": 0.012, "couleur": "#1a1a1a", "vie": 6.0, "agitation": 3.5, "vitesse": 0.3, "distance": 28.0},
	"mouches": {"nombre": 14, "rayon": 2.2, "hauteur": 0.8, "taille": 0.018, "couleur": "#141210", "vie": 8.0, "agitation": 4.5, "vitesse": 1.2, "distance": 22.0},
	"papillons": {"nombre": 8, "rayon": 6.0, "hauteur": 1.2, "taille": 0.07, "couleur": "#e8d27a", "vie": 14.0, "agitation": 1.6, "vitesse": 0.8, "distance": 45.0, "ailes": true},
	"libellules": {"nombre": 6, "rayon": 7.0, "hauteur": 0.8, "taille": 0.07, "couleur": "#4a7f8a", "vie": 10.0, "agitation": 2.4, "vitesse": 2.0, "distance": 40.0, "ailes": true},
	"poussiere": {"nombre": 260, "rayon": 14.0, "hauteur": 5.0, "taille": 0.012, "couleur": "#fff1d6", "vie": 12.0, "agitation": 0.35, "vitesse": 0.08, "distance": 0.0, "lumineux": 0.7},
	"sable": {"nombre": 420, "rayon": 22.0, "hauteur": 1.2, "taille": 0.03, "couleur": "#d8b884", "vie": 3.5, "agitation": 0.6, "vitesse": 6.0, "distance": 0.0, "vent": true, "trainee": true},
	"duvet": {"nombre": 60, "rayon": 20.0, "hauteur": 5.0, "taille": 0.03, "couleur": "#f4f1e8", "vie": 16.0, "agitation": 0.6, "vitesse": 0.9, "distance": 0.0, "vent": true},
	"lucioles": {"nombre": 40, "rayon": 10.0, "hauteur": 1.6, "taille": 0.03, "couleur": "#c8ff6a", "vie": 9.0, "agitation": 0.8, "vitesse": 0.25, "distance": 60.0, "lumineux": 6.0},
	"cendres": {"nombre": 50, "rayon": 1.2, "hauteur": 3.5, "taille": 0.02, "couleur": "#ff9a40", "vie": 3.0, "agitation": 1.2, "vitesse": 1.4, "distance": 50.0, "lumineux": 5.0, "monte": true},
	"bulles": {"nombre": 30, "rayon": 4.0, "hauteur": 0.1, "taille": 0.03, "couleur": "#e8f4f8", "vie": 2.0, "agitation": 0.2, "vitesse": 0.0, "distance": 30.0},
}

var sorte := "moucherons"
## Suit la caméra (true) ou reste sur place.
var autour := false
var nombre_voulu := -1
var rayon_voulu := -1.0
## Direction du vent (degrés, 0 = vers le nord) pour le sable et le duvet.
var vent_deg := 60.0

var _fiche: Dictionary
var _distance := 0.0


func _ready() -> void:
	add_to_group("vie_ambiante")
	_fiche = SORTES.get(sorte, SORTES["moucherons"])
	var rayon := rayon_voulu if rayon_voulu > 0.0 else float(_fiche["rayon"])
	var haut := float(_fiche["hauteur"])
	amount = nombre_voulu if nombre_voulu > 0 else int(_fiche["nombre"])
	lifetime = float(_fiche["vie"])
	preprocess = lifetime
	explosiveness = 0.0
	randomness = 1.0
	local_coords = not autour
	fixed_fps = 30
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_distance = float(_fiche["distance"])
	visibility_aabb = AABB(Vector3(-rayon - 6, -2, -rayon - 6), Vector3(rayon * 2 + 12, haut * 2 + 6, rayon * 2 + 12))
	if _distance > 0.0:
		visibility_range_end = _distance
		visibility_range_end_margin = 4.0
	var p := ParticleProcessMaterial.new()
	p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(rayon, haut, rayon)
	p.gravity = Vector3.ZERO
	var vitesse := float(_fiche["vitesse"])
	if _fiche.get("vent", false):
		var d := Vector3(sin(deg_to_rad(vent_deg)), 0.05, -cos(deg_to_rad(vent_deg)))
		p.direction = d
		p.spread = 12.0
		p.initial_velocity_min = vitesse * 0.6
		p.initial_velocity_max = vitesse * 1.2
	elif _fiche.get("monte", false):
		p.direction = Vector3.UP
		p.spread = 20.0
		p.initial_velocity_min = vitesse * 0.6
		p.initial_velocity_max = vitesse
		p.damping_min = 0.3
		p.damping_max = 0.6
	else:
		p.direction = Vector3.UP
		p.spread = 180.0
		p.initial_velocity_min = 0.0
		p.initial_velocity_max = vitesse
	p.turbulence_enabled = true
	p.turbulence_noise_strength = float(_fiche["agitation"])
	p.turbulence_noise_scale = 1.2 if rayon < 3.0 else 4.0
	p.turbulence_noise_speed = Vector3(0.2, 0.3, 0.2)
	p.turbulence_influence_min = 0.05
	p.turbulence_influence_max = 0.25 if rayon < 3.0 else 0.1
	p.scale_min = 0.6
	p.scale_max = 1.4
	# Apparition et disparition en douceur.
	var courbe := Curve.new()
	courbe.add_point(Vector2(0.0, 0.0))
	courbe.add_point(Vector2(0.15, 1.0))
	courbe.add_point(Vector2(0.85, 1.0))
	courbe.add_point(Vector2(1.0, 0.0))
	var tex_courbe := CurveTexture.new()
	tex_courbe.curve = courbe
	p.scale_curve = tex_courbe
	if _fiche.get("ailes", false):
		p.particle_flag_rotate_y = true
		p.angle_min = -180.0
		p.angle_max = 180.0
	if sorte == "bulles":
		p.emission_box_extents = Vector3(rayon, 0.02, rayon)
	process_material = p
	draw_pass_1 = _maillage()


func _maillage() -> Mesh:
	var taille := float(_fiche["taille"])
	var m := StandardMaterial3D.new()
	var couleur := Color(String(_fiche["couleur"]))
	m.albedo_color = couleur
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if _fiche.has("lumineux") else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES if not _fiche.get("ailes", false) else BaseMaterial3D.BILLBOARD_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	if _fiche.has("lumineux"):
		m.emission_enabled = true
		m.emission = couleur
		m.emission_energy_multiplier = float(_fiche["lumineux"])
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color.a = 0.55 if sorte == "poussiere" else 1.0
		m.albedo_texture = _point_doux()
	elif sorte == "duvet" or sorte == "bulles":
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = _point_doux()
		m.albedo_color.a = 0.8
	elif sorte == "sable":
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = _point_doux()
		m.albedo_color.a = 0.35
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		m.roughness = 0.6
	if _fiche.get("ailes", false):
		return _ailes(taille, m)
	var q := QuadMesh.new()
	q.size = Vector2(taille * (4.0 if _fiche.get("trainee", false) else 1.0), taille)
	q.material = m
	return q


## Deux ailes en V (papillon, libellule) qui battent grâce à un petit shader.
func _ailes(taille: float, m: StandardMaterial3D) -> Mesh:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 couleur : source_color;
uniform float frequence = 14.0;
void vertex() {
	float phase = float(INSTANCE_ID) * 1.7;
	float bat = sin(TIME * frequence + phase);
	VERTEX.y += abs(VERTEX.x) * bat * 1.2;
}
void fragment() {
	ALBEDO = couleur.rgb * (0.8 + 0.2 * COLOR.r);
	ROUGHNESS = 0.7;
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	sm.set_shader_parameter("couleur", m.albedo_color)
	sm.set_shader_parameter("frequence", 24.0 if sorte == "libellules" else 13.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var l := taille
	for cote: float in [1.0, -1.0]:
		st.set_normal(Vector3.UP)
		st.set_color(Color(1, 0, 0))
		st.add_vertex(Vector3(0, 0, -l * 0.3))
		st.add_vertex(Vector3(l * cote, 0, -l * (0.6 if sorte == "papillons" else 0.1)))
		st.add_vertex(Vector3(l * 0.7 * cote, 0, l * 0.5))
	var maillage := st.commit()
	maillage.surface_set_material(0, sm)
	return maillage


static var _tex_point: Texture2D

static func _point_doux() -> Texture2D:
	if _tex_point == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 32
		t.height = 32
		_tex_point = t
	return _tex_point


func _process(_delta: float) -> void:
	if not autour:
		return
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		global_position = camera.global_position + Vector3(0, float(_fiche["hauteur"]) * 0.3, 0)
