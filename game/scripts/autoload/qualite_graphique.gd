extends Node
## Qualité graphique (autoload « QualiteGraphique ») : Bas, Moyen, Haut, Ultra.
##
## Chaque scène règle son WorldEnvironment « au maximum » (tous les effets
## voulus activés). Ce script coupe ou allège les effets coûteux selon le
## niveau choisi, sans toucher aux couleurs ni aux réglages artistiques.
## Le choix est enregistré dans user://graphismes.cfg.
## Touche F10 : passer au niveau suivant (un message s'affiche).
##
## Pour un nœud qui veut s'adapter lui-même : l'ajouter au groupe « qualite »
## et lui donner une méthode appliquer_qualite(niveau: int).
## Les lumières du groupe « lumiere_secondaire » sont éteintes en Bas.

signal niveau_change(niveau: int)

enum Niveau { BAS, MOYEN, HAUT, ULTRA }
const NOMS := ["bas", "moyen", "haut", "ultra"]
const NOMS_AFFICHES := ["Bas", "Moyen", "Haut", "Ultra"]
const FICHIER := "user://graphismes.cfg"

var niveau: int = Niveau.HAUT
var _message: Label
var _temps_message := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	if cfg.load(FICHIER) == OK:
		niveau = clampi(int(cfg.get_value("graphismes", "niveau", niveau)), 0, 3)
	get_tree().node_added.connect(_sur_noeud_ajoute)
	_creer_message()
	appliquer.call_deferred()


func _unhandled_input(evenement: InputEvent) -> void:
	if evenement is InputEventKey and evenement.pressed and not evenement.echo and evenement.keycode == KEY_F10:
		choisir((niveau + 1) % 4)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _temps_message > 0.0:
		_temps_message -= delta
		_message.modulate.a = clampf(_temps_message, 0.0, 1.0)


## Choisit un niveau (nombre 0-3 ou nom : "bas", "moyen", "haut", "ultra").
func choisir(valeur, sauver := true) -> void:
	if valeur is String:
		var i := NOMS.find(String(valeur).to_lower())
		if i < 0:
			push_warning("Qualité inconnue : %s" % valeur)
			return
		valeur = i
	niveau = clampi(int(valeur), 0, 3)
	if sauver:
		var cfg := ConfigFile.new()
		cfg.load(FICHIER)
		cfg.set_value("graphismes", "niveau", niveau)
		cfg.save(FICHIER)
	appliquer()
	_afficher("Graphismes : %s  (F10 pour changer)" % NOMS_AFFICHES[niveau])
	niveau_change.emit(niveau)


func nom() -> String:
	return NOMS_AFFICHES[niveau]


func appliquer() -> void:
	var rs := RenderingServer
	var vp := get_viewport()
	# Anticrénelage et résolution de rendu.
	match niveau:
		Niveau.BAS:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.use_taa = false
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			vp.scaling_3d_scale = 0.75
			vp.mesh_lod_threshold = 4.0
		Niveau.MOYEN:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.use_taa = false
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0
			vp.mesh_lod_threshold = 2.0
		Niveau.HAUT:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.use_taa = false
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0
			vp.mesh_lod_threshold = 1.0
		Niveau.ULTRA:
			# MSAA 4x faisait apparaître des traits noirs sur la pluie (mélange
			# additif) devant les projecteurs : 2x + SMAA lisse aussi bien.
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA
			vp.use_taa = false
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0
			vp.mesh_lod_threshold = 0.5
	# Ombres.
	var ombres := [rs.SHADOW_QUALITY_HARD, rs.SHADOW_QUALITY_SOFT_LOW, rs.SHADOW_QUALITY_SOFT_MEDIUM, rs.SHADOW_QUALITY_SOFT_HIGH]
	rs.directional_soft_shadow_filter_set_quality(ombres[niveau])
	rs.positional_soft_shadow_filter_set_quality(ombres[niveau])
	rs.directional_shadow_atlas_set_size([2048, 2048, 4096, 4096][niveau], true)
	# Effets d'écran.
	var q := [rs.ENV_SSAO_QUALITY_VERY_LOW, rs.ENV_SSAO_QUALITY_LOW, rs.ENV_SSAO_QUALITY_MEDIUM, rs.ENV_SSAO_QUALITY_HIGH]
	rs.environment_set_ssao_quality(q[niveau], niveau < 2, 0.5, 2, 50.0, 300.0)
	var qi := [rs.ENV_SSIL_QUALITY_VERY_LOW, rs.ENV_SSIL_QUALITY_LOW, rs.ENV_SSIL_QUALITY_MEDIUM, rs.ENV_SSIL_QUALITY_HIGH]
	rs.environment_set_ssil_quality(qi[niveau], niveau < 3, 0.5, 4, 50.0, 300.0)
	var qr := [rs.ENV_SSR_ROUGHNESS_QUALITY_DISABLED, rs.ENV_SSR_ROUGHNESS_QUALITY_LOW, rs.ENV_SSR_ROUGHNESS_QUALITY_MEDIUM, rs.ENV_SSR_ROUGHNESS_QUALITY_HIGH]
	rs.environment_set_ssr_roughness_quality(qr[niveau])
	var brouillard := [[64, 64], [64, 64], [96, 96], [160, 128]]
	rs.environment_set_volumetric_fog_volume_size(brouillard[niveau][0], brouillard[niveau][1])
	rs.environment_set_volumetric_fog_filter_active(niveau >= 2)
	rs.environment_glow_set_use_bicubic_upscale(niveau >= 2)
	# Ronds de pluie dans les flaques (shaders sol_mouille et eau).
	rs.global_shader_parameter_set("pluie_impacts", 0.0 if niveau == Niveau.BAS else 1.0)
	for n in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		_appliquer_environnement(n)
	for n in get_tree().get_nodes_in_group("lumiere_secondaire"):
		if n is Light3D:
			n.visible = niveau > Niveau.BAS
	for n in get_tree().get_nodes_in_group("qualite"):
		if n.has_method("appliquer_qualite"):
			n.appliquer_qualite(niveau)


func _appliquer_environnement(we: WorldEnvironment) -> void:
	var env := we.environment
	if env == null:
		return
	# On retient une fois pour toutes ce que la scène voulait au maximum.
	if not env.has_meta("qualite_max"):
		env.set_meta("qualite_max", {
			"ssr": env.ssr_enabled, "ssr_pas": env.ssr_max_steps, "ssao": env.ssao_enabled,
			"ssil": env.ssil_enabled, "sdfgi": env.sdfgi_enabled,
			"brouillard": env.volumetric_fog_enabled, "glow": env.glow_enabled,
		})
	var m: Dictionary = env.get_meta("qualite_max")
	env.ssr_enabled = m["ssr"] and niveau >= Niveau.MOYEN
	env.ssr_max_steps = int(m["ssr_pas"] * [0.3, 0.5, 0.8, 1.0][niveau])
	env.ssao_enabled = m["ssao"] and niveau >= Niveau.MOYEN
	env.ssil_enabled = m["ssil"] and niveau >= Niveau.HAUT
	env.sdfgi_enabled = m["sdfgi"] and niveau >= Niveau.ULTRA
	env.volumetric_fog_enabled = m["brouillard"] and niveau >= Niveau.MOYEN
	env.glow_enabled = m["glow"]
	var cam := we.camera_attributes as CameraAttributesPractical
	if cam != null:
		if not cam.has_meta("flou_max"):
			cam.set_meta("flou_max", cam.dof_blur_far_enabled)
		cam.dof_blur_far_enabled = cam.get_meta("flou_max") and niveau >= Niveau.HAUT


func _sur_noeud_ajoute(n: Node) -> void:
	if n is WorldEnvironment:
		_appliquer_environnement.call_deferred(n)
	elif n is Light3D or n.has_method("appliquer_qualite"):
		_appliquer_noeud.call_deferred(n)


func _appliquer_noeud(n: Node) -> void:
	if not is_instance_valid(n):
		return
	if n is Light3D and n.is_in_group("lumiere_secondaire"):
		n.visible = niveau > Niveau.BAS
	if n.is_in_group("qualite") and n.has_method("appliquer_qualite"):
		n.appliquer_qualite(niveau)


func _creer_message() -> void:
	var couche := CanvasLayer.new()
	couche.layer = 100
	add_child(couche)
	_message = Label.new()
	_message.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_message.position = Vector2(-300, 40)
	_message.custom_minimum_size = Vector2(600, 0)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 22)
	_message.add_theme_color_override("font_outline_color", Color.BLACK)
	_message.add_theme_constant_override("outline_size", 6)
	_message.modulate.a = 0.0
	couche.add_child(_message)


func _afficher(texte: String) -> void:
	_message.text = texte
	_temps_message = 2.5
