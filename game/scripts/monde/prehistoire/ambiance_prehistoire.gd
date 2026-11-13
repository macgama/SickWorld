extends Node
## Ambiance « grandiose » des zones de la Préhistoire : soleil bas d'hiver,
## ciel doré et nuageux, brume bleutée au loin, rayons de lumière dans la
## brume, contraste et couleurs. S'applique au WorldEnvironment « Environnement »
## et à la lumière « Soleil » de la zone.
##
## Utilisation (une ligne dans le script de la zone) :
##   AmbiancePrehistoire.appliquer(self, "cote_gelee")
## Les réglages de chaque zone sont dans CLIMATS ci-dessous.

const SHADER_CIEL := preload("res://shaders/ciel_polaire.gdshader")
const SHADER_POST := preload("res://shaders/post_traitement.gdshader")

## Réglages par zone. soleil = (direction horizontale en degrés, hauteur en degrés).
const CLIMATS := {
	"cote_gelee": {
		"soleil": Vector2(-62.0, 13.0),
		"couleur_soleil": Color(1.0, 0.87, 0.72),
		"energie_soleil": 2.4,
		"couverture": 0.55,
		"brume": Color(0.56, 0.66, 0.8),
		"densite_brume": 0.0014,
		"brume_volume": 0.0035,
		"ambiance": 0.55,
	},
	"foret": {
		"soleil": Vector2(-100.0, 16.0),
		"couleur_soleil": Color(1.0, 0.85, 0.68),
		"energie_soleil": 2.5,
		"couverture": 0.45,
		"brume": Color(0.6, 0.68, 0.78),
		"densite_brume": 0.0025,
		"brume_volume": 0.006,
		"ambiance": 0.6,
	},
	"falaises": {
		"soleil": Vector2(-150.0, 14.0),
		"couleur_soleil": Color(1.0, 0.82, 0.62),
		"energie_soleil": 2.5,
		"couverture": 0.5,
		"brume": Color(0.6, 0.66, 0.76),
		"densite_brume": 0.0018,
		"brume_volume": 0.004,
		"ambiance": 0.6,
	},
	"steppe": {
		"soleil": Vector2(-125.0, 21.0),
		"couleur_soleil": Color(1.0, 0.84, 0.62),
		"energie_soleil": 2.6,
		"couverture": 0.4,
		"brume": Color(0.62, 0.68, 0.76),
		"densite_brume": 0.0011,
		"brume_volume": 0.0015,
		"ambiance": 0.6,
	},
}


static func appliquer(zone: Node, climat := "cote_gelee") -> void:
	var r: Dictionary = CLIMATS.get(climat, CLIMATS["cote_gelee"])
	var we := zone.get_node_or_null("Environnement") as WorldEnvironment
	var soleil := zone.get_node_or_null("Soleil") as DirectionalLight3D
	if soleil != null:
		var s: Vector2 = r["soleil"]
		# La lumière vient de cette direction (azimut, hauteur) et éclaire vers l'opposé.
		var az := deg_to_rad(s.x)
		var haut := deg_to_rad(s.y)
		var vers_soleil := Vector3(sin(az) * cos(haut), sin(haut), -cos(az) * cos(haut))
		soleil.global_transform = Transform3D(Basis.looking_at(-vers_soleil, Vector3.UP), soleil.global_position)
		soleil.light_color = r["couleur_soleil"]
		soleil.light_energy = r["energie_soleil"]
		soleil.light_angular_distance = 0.8
		soleil.light_volumetric_fog_energy = 1.2
		soleil.shadow_enabled = true
		soleil.shadow_blur = 1.2
		soleil.directional_shadow_max_distance = 260.0
		soleil.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		soleil.light_bake_mode = Light3D.BAKE_DYNAMIC
	if we == null:
		return
	var env := we.environment
	var ciel := ShaderMaterial.new()
	ciel.shader = SHADER_CIEL
	ciel.set_shader_parameter("couverture", r["couverture"])
	ciel.set_shader_parameter("couleur_soleil", r["couleur_soleil"])
	var sky := Sky.new()
	sky.sky_material = ciel
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = r["ambiance"]
	env.ambient_light_sky_contribution = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.tonemap_white = 8.0
	env.ssr_enabled = true
	env.ssr_max_steps = 80
	env.ssr_fade_out = 4.0
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.8
	env.ssil_enabled = true
	env.ssil_radius = 6.0
	env.sdfgi_enabled = true
	env.sdfgi_cascades = 6
	env.sdfgi_min_cell_size = 0.4
	env.sdfgi_use_occlusion = true
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.2
	# Brume : bleutée au loin (perspective atmosphérique), dorée vers le soleil.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = r["brume"]
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.12
	env.fog_density = r["densite_brume"]
	# La perspective aérienne lit la carte de reflets du ciel (basse résolution) :
	# trop forte, elle dessinait des bandes carrées autour du soleil.
	env.fog_aerial_perspective = 0.2
	env.fog_sky_affect = 0.35
	# Brouillard en volume : rayons de soleil.
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = r["brume_volume"]
	env.volumetric_fog_albedo = Color(0.92, 0.95, 1.0)
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 140.0
	env.volumetric_fog_ambient_inject = 0.1
	env.volumetric_fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 1.08
	# Une fois les réglages « au maximum » posés, la qualité graphique allège.
	if env.has_meta("qualite_max"):
		env.remove_meta("qualite_max")
	var qualite := zone.get_node_or_null("/root/QualiteGraphique")
	if qualite != null:
		qualite.appliquer()
	_ajouter_post(zone)


static func _ajouter_post(zone: Node) -> void:
	if Engine.is_editor_hint() or zone.has_node("PostTraitement"):
		return
	var couche := CanvasLayer.new()
	couche.name = "PostTraitement"
	couche.layer = -1
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = SHADER_POST
	m.set_shader_parameter("vignettage", 0.25)
	m.set_shader_parameter("grain", 0.02)
	rect.material = m
	couche.add_child(rect)
	zone.add_child(couche)
