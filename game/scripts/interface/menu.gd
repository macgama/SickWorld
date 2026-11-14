extends Control
## Écran titre de SickWorld.
##
## En fond : Hikari Bay, la nuit sous la pluie, filmée par une caméra qui glisse
## lentement d'un plan à l'autre (le vrai décor du hub, sans joueurs ni missions).
## Devant : le logo, le personnage, et les boutons Jouer, Multijoueur,
## Mon personnage, Options, Quitter.
##
## Les plans de caméra sont dans PLANS ci-dessous : [départ, arrivée, point regardé
## au départ, point regardé à l'arrivée]. On peut en ajouter ou les changer.

const FICHIER_REGLAGES := "user://reglages.cfg"
const SCENE_CREATION := "res://scenes/interface/creation_personnage.tscn"
const SCENE_DECOR := "res://scenes/monde/hikari_bay.tscn"
const Style := preload("res://scripts/interface/style_menu.gd")
const PanneauOptions := preload("res://scripts/interface/panneau_options.gd")
const SHADER_LOGO := preload("res://shaders/logo_titre.gdshader")

## Nœuds du hub qui ne servent pas au décor (partie, interface, missions…).
const NOEUDS_RETIRES := ["Partie", "Interface", "Dialogue", "Intro", "Quetes"]

## Plans de caméra : [position départ, position arrivée, regard départ, regard arrivée].
const PLANS := [
	# La place Hikari et la statue du Gardien, en avançant doucement.
	[Vector3(9, 2.4, 34), Vector3(3, 2.0, 24), Vector3(-2, 7, -20), Vector3(-4, 8, -20)],
	# La skyline depuis les hauteurs, en glissant de côté.
	[Vector3(-52, 40, 74), Vector3(-26, 44, 70), Vector3(4, 52, -200), Vector3(18, 56, -200)],
	# Le front de mer et la baie.
	[Vector3(-34, 2.8, 64), Vector3(-20, 3.2, 72), Vector3(60, 16, 112), Vector3(70, 18, 104)],
	# La rue sud vers la place.
	[Vector3(2, 1.8, 74), Vector3(-1, 2.0, 60), Vector3(0, 6, 20), Vector3(0, 7, 18)],
	# Le marché de nuit.
	[Vector3(-18, 1.9, -50), Vector3(-21, 1.9, -62), Vector3(-22, 5, -120), Vector3(-24, 5, -122)],
]
const DUREE_PLAN := 16.0
const FONDU := 1.4

var _a_un_personnage := false
var _adresse: LineEdit
var _port: SpinBox
var _message: Label

var _decor: Node3D
var _camera: Camera3D
var _plan := 0
## Vrai après le premier changement de plan (fondu d'entrée de chaque plan).
var _plan_change := false
var _temps_plan := 0.0
var _voile: ColorRect
var _colonne: VBoxContainer
var _panneau_multi: PanelContainer
var _options: PanneauOptions
var _logo: TextureRect
var _prochain_glitch := 3.0
var _glitch := 0.0


func _ready() -> void:
	# Lancement automatique depuis la ligne de commande (serveur dédié, tests…).
	if not Reseau.has_meta("demarrage_auto_fait"):
		Reseau.set_meta("demarrage_auto_fait", true)
		if Reseau.mode == Reseau.Mode.SERVEUR_DEDIE or Reseau.mode == Reseau.Mode.REJOINDRE:
			_lancer.call_deferred(Reseau.mode)
			return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	theme = Style.theme()
	_construire()
	# Le décor est construit après la première image : le logo apparaît tout de suite.
	_charger_decor.call_deferred()


# --- Décor 3D ---------------------------------------------------------------

func _charger_decor() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or not ResourceLoader.exists(SCENE_DECOR):
		return
	var scene: PackedScene = load(SCENE_DECOR)
	_decor = scene.instantiate() as Node3D
	for nom in NOEUDS_RETIRES:
		var n := _decor.get_node_or_null(nom)
		if n != null:
			_decor.remove_child(n)
			n.free()
	_camera = Camera3D.new()
	_camera.name = "CameraTitre"
	_camera.fov = 62.0
	_camera.far = 3000.0
	_decor.add_child(_camera)
	add_child(_decor)
	move_child(_decor, 0)
	# Les interfaces (mini-carte…) ne s'affichent pas sur l'écran titre.
	for n in _decor.find_children("*", "CanvasLayer", true, false):
		if n.name != "PostTraitement":
			(n as CanvasLayer).visible = false
	_camera.make_current()
	_plan = randi() % PLANS.size()
	_temps_plan = 0.0
	_placer_camera()
	var anim := create_tween()
	anim.tween_interval(0.6)
	anim.tween_property(_voile, "color:a", 0.0, 2.5)


func _placer_camera() -> void:
	var p: Array = PLANS[_plan]
	var t := clampf(_temps_plan / DUREE_PLAN, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t) * 0.5 + t * 0.5  # départ et arrivée en douceur
	var pos: Vector3 = (p[0] as Vector3).lerp(p[1], t)
	var regard: Vector3 = (p[2] as Vector3).lerp(p[3], t)
	_camera.look_at_from_position(pos, regard, Vector3.UP)


func _process(delta: float) -> void:
	_animer_logo(delta)
	if _camera == null:
		return
	_temps_plan += delta
	# Fondu au noir avant de passer au plan suivant.
	var reste := DUREE_PLAN - _temps_plan
	if reste < FONDU:
		_voile.color.a = maxf(_voile.color.a, 1.0 - reste / FONDU)
	elif _temps_plan < FONDU and _plan_change:
		_voile.color.a = 1.0 - _temps_plan / FONDU
	if _temps_plan >= DUREE_PLAN:
		_plan = (_plan + 1) % PLANS.size()
		_temps_plan = 0.0
		_plan_change = true
	_placer_camera()



func _animer_logo(delta: float) -> void:
	if _logo == null:
		return
	_prochain_glitch -= delta
	if _prochain_glitch <= 0.0:
		_glitch = 0.25
		_prochain_glitch = randf_range(3.0, 7.0)
	_glitch = maxf(_glitch - delta, 0.0)
	(_logo.material as ShaderMaterial).set_shader_parameter("force_glitch", 1.0 if _glitch > 0.0 else 0.0)


# --- Interface ----------------------------------------------------------------

func _construire() -> void:
	var reglages := ConfigFile.new()
	reglages.load(FICHIER_REGLAGES)

	# Assombrit la gauche de l'écran pour que les boutons restent lisibles.
	var ombre := TextureRect.new()
	var degrade := Gradient.new()
	degrade.set_color(0, Color(0.0, 0.01, 0.03, 0.88))
	degrade.set_color(1, Color(0.0, 0.01, 0.03, 0.0))
	degrade.set_offset(1, 1.0)
	var tex := GradientTexture2D.new()
	tex.gradient = degrade
	tex.fill_from = Vector2(0.0, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	ombre.texture = tex
	ombre.stretch_mode = TextureRect.STRETCH_SCALE
	ombre.anchor_bottom = 1.0
	ombre.anchor_right = 0.62
	ombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ombre)

	var marge := MarginContainer.new()
	marge.anchor_bottom = 1.0
	marge.anchor_right = 0.5
	marge.add_theme_constant_override("margin_left", 90)
	marge.add_theme_constant_override("margin_top", 60)
	marge.add_theme_constant_override("margin_bottom", 50)
	add_child(marge)
	_colonne = VBoxContainer.new()
	_colonne.alignment = BoxContainer.ALIGNMENT_CENTER
	_colonne.add_theme_constant_override("separation", 12)
	marge.add_child(_colonne)

	_colonne.add_child(_construire_logo())
	var devise := Label.new()
	devise.text = "Répare l'histoire, une époque à la fois."
	devise.add_theme_color_override("font_color", Style.TEXTE_DOUX)
	devise.add_theme_font_size_override("font_size", 18)
	_colonne.add_child(devise)
	var espace := Control.new()
	espace.custom_minimum_size = Vector2(0, 26)
	_colonne.add_child(espace)

	# Le personnage : résumé.
	var fiche := FichePersonnage.charger(Donnees.creation)
	_a_un_personnage = not fiche.is_empty()
	var resume := Label.new()
	resume.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resume.custom_minimum_size = Vector2(380, 0)
	if _a_un_personnage:
		Reseau.fiche = fiche
		Reseau.nom_joueur = fiche["nom"]
		var classe := FichePersonnage.element(Donnees.creation, "classes", fiche["classe"])
		var origine := FichePersonnage.element(Donnees.creation, "origines", fiche["origine"])
		resume.text = "Agent %s\n%s · originaire de %s" % [fiche["nom"], classe.get("nom", ""), origine.get("nom", "")]
	else:
		resume.text = "Crée ton agent de la Vigie pour commencer."
	resume.add_theme_font_size_override("font_size", 17)
	resume.add_theme_color_override("font_color", Style.TEXTE)
	_colonne.add_child(resume)

	var boutons := VBoxContainer.new()
	boutons.custom_minimum_size = Vector2(380, 0)
	boutons.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	boutons.add_theme_constant_override("separation", 8)
	_colonne.add_child(boutons)
	if _a_un_personnage:
		boutons.add_child(_bouton("Jouer", func(): _lancer(Reseau.Mode.SEUL), true))
		boutons.add_child(_bouton("Multijoueur", _basculer_multi))
		boutons.add_child(_bouton("Modifier mon personnage", _vers_creation))
	else:
		boutons.add_child(_bouton("Créer mon personnage", _vers_creation, true))
	boutons.add_child(_bouton("Options", _ouvrir_options))
	boutons.add_child(_bouton("Quitter", func(): get_tree().quit()))

	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(380, 0)
	_message.add_theme_color_override("font_color", Color(1, 0.55, 0.45))
	_message.text = String(Reseau.get_meta("message_menu", ""))
	if Reseau.has_meta("message_menu"):
		Reseau.remove_meta("message_menu")
	_colonne.add_child(_message)
	if Reseau.has_meta("message_menu_ok"):
		var ok := Label.new()
		ok.add_theme_color_override("font_color", Color(0.5, 0.9, 0.6))
		ok.text = String(Reseau.get_meta("message_menu_ok"))
		Reseau.remove_meta("message_menu_ok")
		_colonne.add_child(ok)

	_construire_multi(reglages)

	# Compte en ligne (en haut à droite).
	var compte := VBoxContainer.new()
	compte.name = "Compte"
	compte.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	compte.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	compte.offset_left = -440
	compte.offset_right = -30
	compte.offset_top = 30
	add_child(compte)
	_construire_compte(compte)

	# Bas de l'écran : version et raccourci.
	var pied := Label.new()
	pied.text = "Prototype · %s     F10 : qualité des graphismes" % ProjectSettings.get_setting("application/config/version", "0.1")
	pied.add_theme_font_size_override("font_size", 13)
	pied.add_theme_color_override("font_color", Color(Style.TEXTE_DOUX, 0.6))
	pied.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	pied.offset_left = 90
	pied.offset_top = -38
	add_child(pied)

	# Options : au centre, par-dessus le reste.
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_options = PanneauOptions.new()
	_options.visible = false
	_options.ferme.connect(func():
		_options.visible = false
		_colonne.visible = true)
	centre.add_child(_options)

	# Voile noir : ouverture en fondu et transitions entre les plans.
	_voile = ColorRect.new()
	_voile.color = Color(0, 0, 0, 1)
	_voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_voile)
	move_child(_voile, 0)


## Emplacement du compte en ligne (connexion Nakama), rempli par le panneau de compte.
func _construire_compte(conteneur: VBoxContainer) -> void:
	var chemin := "res://scripts/interface/panneau_compte.gd"
	if ResourceLoader.exists(chemin):
		conteneur.add_child(load(chemin).new())


func _construire_logo() -> Control:
	# Le logo est dessiné dans une petite image (SubViewport) pour que le shader
	# puisse le fissurer et le faire scintiller.
	var vue := SubViewport.new()
	vue.transparent_bg = true
	vue.size = Vector2i(820, 170)
	vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var texte := Label.new()
	texte.text = "SICKWORLD"
	var police := FontVariation.new()
	police.base_font = Style.police()
	police.spacing_glyph = 10
	var reglages := LabelSettings.new()
	reglages.font = police
	reglages.font_size = 112
	reglages.font_color = Color.WHITE
	reglages.shadow_color = Color(Style.CYAN, 0.28)
	reglages.shadow_size = 18
	reglages.shadow_offset = Vector2.ZERO
	texte.label_settings = reglages
	texte.position = Vector2(14, 6)
	vue.add_child(texte)
	add_child(vue)
	_logo = TextureRect.new()
	_logo.texture = vue.get_texture()
	_logo.custom_minimum_size = Vector2(615, 128)
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_logo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_LOGO
	_logo.material = mat
	return _logo


func _construire_multi(reglages: ConfigFile) -> void:
	_panneau_multi = PanelContainer.new()
	_panneau_multi.visible = false
	_panneau_multi.anchor_left = 0.5
	_panneau_multi.anchor_top = 0.5
	_panneau_multi.anchor_bottom = 0.5
	_panneau_multi.offset_left = -270
	_panneau_multi.offset_top = -40
	_panneau_multi.custom_minimum_size = Vector2(420, 0)
	add_child(_panneau_multi)
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 10)
	_panneau_multi.add_child(c)
	var t := Label.new()
	t.text = "Multijoueur"
	t.add_theme_font_size_override("font_size", 22)
	c.add_child(t)
	if Reseau.a_un_serveur_officiel():
		c.add_child(Style.titre_section("Serveur officiel"))
		var o := Label.new()
		o.text = "Le serveur SickWorld en ligne, allumé en permanence : tout le monde s'y retrouve."
		o.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		o.add_theme_font_size_override("font_size", 14)
		o.add_theme_color_override("font_color", Style.TEXTE_DOUX)
		c.add_child(o)
		c.add_child(_bouton("Rejoindre le serveur officiel", _rejoindre_officiel, true))
	c.add_child(Style.titre_section("Héberger"))
	var h := Label.new()
	h.text = "Ta partie s'ouvre et tes amis peuvent te rejoindre avec ton adresse."
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_theme_font_size_override("font_size", 14)
	h.add_theme_color_override("font_color", Style.TEXTE_DOUX)
	c.add_child(h)
	c.add_child(_bouton("Héberger une partie", func(): _lancer(Reseau.Mode.HEBERGER)))
	c.add_child(Style.titre_section("Rejoindre"))
	var ligne := HBoxContainer.new()
	_adresse = LineEdit.new()
	_adresse.text = reglages.get_value("reseau", "adresse", "127.0.0.1")
	_adresse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_adresse.placeholder_text = "adresse, ex. 192.168.1.20"
	ligne.add_child(_adresse)
	_port = SpinBox.new()
	_port.min_value = 1024
	_port.max_value = 65535
	_port.value = reglages.get_value("reseau", "port", Reseau.PORT_PAR_DEFAUT)
	ligne.add_child(_port)
	c.add_child(ligne)
	c.add_child(_bouton("Rejoindre", func(): _lancer(Reseau.Mode.REJOINDRE)))


func _bouton(texte: String, action: Callable, principal := false) -> Button:
	var b := Button.new()
	b.text = texte
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 52 if principal else 44)
	b.add_theme_font_size_override("font_size", 22 if principal else 18)
	if principal:
		var s := Style.boite(Color(0.06, 0.32, 0.38, 0.85), Style.CYAN, 1)
		var s2 := Style.boite(Color(0.08, 0.42, 0.5, 0.95), Color.WHITE, 1)
		b.add_theme_stylebox_override("normal", s)
		b.add_theme_stylebox_override("hover", s2)
	b.pressed.connect(action)
	return b


func _basculer_multi() -> void:
	_panneau_multi.visible = not _panneau_multi.visible


func _ouvrir_options() -> void:
	_panneau_multi.visible = false
	_colonne.visible = false
	_options.visible = true


func _vers_creation() -> void:
	get_tree().change_scene_to_file(SCENE_CREATION)


func _unhandled_input(evenement: InputEvent) -> void:
	if evenement is InputEventKey and evenement.pressed and evenement.keycode == KEY_ESCAPE:
		if _options != null and _options.visible:
			_options.fermer_options()
			get_viewport().set_input_as_handled()
		elif _panneau_multi != null and _panneau_multi.visible:
			_panneau_multi.visible = false
			get_viewport().set_input_as_handled()


func _rejoindre_officiel() -> void:
	var officiel := Reseau.serveur_officiel()
	Reseau.mode = Reseau.Mode.REJOINDRE
	Reseau.adresse = String(officiel.get("jeu", ""))
	Reseau.port = int(officiel.get("port", Reseau.PORT_PAR_DEFAUT))
	get_tree().change_scene_to_file(Reseau.scene_depart)


func _lancer(mode: Reseau.Mode) -> void:
	Reseau.mode = mode
	if _adresse != null:
		Reseau.adresse = _adresse.text.strip_edges()
		Reseau.port = int(_port.value)
		var reglages := ConfigFile.new()
		reglages.set_value("reseau", "adresse", Reseau.adresse)
		reglages.set_value("reseau", "port", Reseau.port)
		reglages.save(FICHIER_REGLAGES)
	get_tree().change_scene_to_file(Reseau.scene_depart)
