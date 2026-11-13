extends PanelContainer
## Fenêtre des options (écran titre et menu de jeu) : Graphismes, Son,
## Commandes, Jeu. Chaque changement s'applique tout de suite et est
## enregistré par l'autoload Options (user://options.cfg) ;
## la qualité graphique est celle de l'autoload QualiteGraphique (F10).

signal ferme

const Style := preload("res://scripts/interface/style_menu.gd")

var _onglets: TabContainer
## Action en attente d'une touche (bouton « Appuie sur une touche… »).
var _action_attendue := ""
var _bouton_attendu: Button
var _boutons_touches := {}
var _message_touches: Label
var _qualite: OptionButton


func _ready() -> void:
	theme = Style.theme()
	custom_minimum_size = Vector2(760, 560)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 10)
	add_child(colonne)

	var haut := HBoxContainer.new()
	var titre := Label.new()
	titre.text = "Options"
	titre.add_theme_font_size_override("font_size", 28)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haut.add_child(titre)
	var fermer := Button.new()
	fermer.text = "Fermer"
	fermer.pressed.connect(fermer_options)
	haut.add_child(fermer)
	colonne.add_child(haut)

	_onglets = TabContainer.new()
	_onglets.size_flags_vertical = Control.SIZE_EXPAND_FILL
	colonne.add_child(_onglets)
	_onglets.add_child(_onglet_graphismes())
	_onglets.add_child(_onglet_son())
	_onglets.add_child(_onglet_commandes())
	_onglets.add_child(_onglet_jeu())
	QualiteGraphique.niveau_change.connect(func(n): _qualite.select(n))


func fermer_options() -> void:
	_annuler_attente()
	Options.sauver()
	ferme.emit()


# --- Construction ---------------------------------------------------------

func _page(nom: String) -> VBoxContainer:
	var defile := ScrollContainer.new()
	defile.name = nom
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 10)
	var marge := MarginContainer.new()
	marge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for cote in ["left", "right", "top", "bottom"]:
		marge.add_theme_constant_override("margin_" + cote, 12)
	marge.add_child(page)
	defile.add_child(marge)
	return page


func _ligne(page: VBoxContainer, libelle: String, controle: Control, aide := "") -> void:
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = libelle
	l.custom_minimum_size = Vector2(280, 0)
	l.tooltip_text = aide
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	ligne.add_child(l)
	controle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controle.tooltip_text = aide
	ligne.add_child(controle)
	page.add_child(ligne)


func _liste(choix: Array, actuel: int, action: Callable) -> OptionButton:
	var o := OptionButton.new()
	for c in choix:
		o.add_item(str(c))
	o.select(actuel)
	o.item_selected.connect(action)
	return o


func _curseur(mini: float, maxi: float, pas: float, valeur: float, action: Callable, format := "%d %%", facteur := 100.0) -> HBoxContainer:
	var boite := HBoxContainer.new()
	var c := HSlider.new()
	c.min_value = mini
	c.max_value = maxi
	c.step = pas
	c.value = valeur
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nombre := Label.new()
	nombre.custom_minimum_size = Vector2(64, 0)
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	nombre.text = format % (valeur * facteur)
	c.value_changed.connect(func(v):
		nombre.text = format % (v * facteur)
		action.call(v))
	boite.add_child(c)
	boite.add_child(nombre)
	return boite


func _onglet_graphismes() -> Control:
	var page := _page("Graphismes")
	page.add_child(Style.titre_section("Qualité"))
	_qualite = _liste(QualiteGraphique.NOMS_AFFICHES, QualiteGraphique.niveau,
			func(i): QualiteGraphique.choisir(i))
	_ligne(page, "Qualité des graphismes", _qualite,
			"Bas : ordinateurs modestes. Ultra : cartes graphiques puissantes. Raccourci en jeu : F10.")
	page.add_child(Style.titre_section("Écran"))
	_ligne(page, "Affichage", _liste(Options.MODES_ECRAN, Options.mode_ecran, func(i):
		Options.mode_ecran = i
		Options.appliquer_affichage()
		Options.sauver()))
	var vs := CheckButton.new()
	vs.text = "Activée"
	vs.button_pressed = Options.vsync
	vs.toggled.connect(func(b):
		Options.vsync = b
		Options.appliquer_affichage()
		Options.sauver())
	_ligne(page, "Synchronisation verticale", vs, "Évite les déchirures d'image. Limite les images par seconde à la fréquence de l'écran.")
	var noms_limites := []
	for n in Options.LIMITES_IMAGES:
		noms_limites.append("Illimitée" if n == 0 else "%d images/s" % n)
	_ligne(page, "Limite d'images par seconde", _liste(noms_limites,
			maxi(0, Options.LIMITES_IMAGES.find(Options.limite_images)), func(i):
		Options.limite_images = Options.LIMITES_IMAGES[i]
		Options.appliquer_affichage()
		Options.sauver()))
	return page.get_parent().get_parent()


func _onglet_son() -> Control:
	var page := _page("Son")
	page.add_child(Style.titre_section("Volumes"))
	for b in Options.BUS:
		var bus: String = b[0]
		_ligne(page, b[1], _curseur(0.0, 1.0, 0.01, Options.volumes[bus],
				func(v): Options.regler_volume(bus, v)))
	var note := Label.new()
	note.text = "Les réglages sont gardés quand tu fermes le jeu."
	note.add_theme_color_override("font_color", Style.TEXTE_DOUX)
	note.add_theme_font_size_override("font_size", 14)
	page.add_child(note)
	return page.get_parent().get_parent()


func _onglet_commandes() -> Control:
	var page := _page("Commandes")
	page.add_child(Style.titre_section("Touches (clique puis appuie sur la nouvelle touche)"))
	for a in Options.ACTIONS_MODIFIABLES:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 34)
		_boutons_touches[a[0]] = b
		b.pressed.connect(_attendre_touche.bind(a[0], b))
		_ligne(page, a[1], b)
	_rafraichir_touches()
	_message_touches = Label.new()
	_message_touches.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
	_message_touches.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_message_touches)
	var defaut := Button.new()
	defaut.text = "Remettre les touches par défaut"
	defaut.pressed.connect(func():
		_annuler_attente()
		Options.touches_par_defaut()
		_rafraichir_touches()
		_message_touches.text = "Touches par défaut remises.")
	page.add_child(defaut)
	var note := Label.new()
	note.text = "La souris ne change pas : clic droit maintenu pour orienter le personnage, clic gauche maintenu pour tourner la caméra, molette pour le zoom. Les flèches du clavier marchent toujours pour se déplacer."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Style.TEXTE_DOUX)
	note.add_theme_font_size_override("font_size", 14)
	page.add_child(note)
	return page.get_parent().get_parent()


func _onglet_jeu() -> Control:
	var page := _page("Jeu")
	page.add_child(Style.titre_section("Caméra"))
	var regler_sensibilite := func(v: float) -> void:
		Options.sensibilite = v
		Options.appliquer_camera()
	var regler_vision := func(v: float) -> void:
		Options.champ_de_vision = v
		Options.appliquer_camera()
	_ligne(page, "Sensibilité de la souris",
			_curseur(0.05, 1.0, 0.01, Options.sensibilite, regler_sensibilite, "%d %%", 400.0))
	_ligne(page, "Champ de vision",
			_curseur(50.0, 110.0, 1.0, Options.champ_de_vision, regler_vision, "%d°", 1.0))
	page.add_child(Style.titre_section("Conseils pour débutants"))
	var c := CheckButton.new()
	c.text = "Afficher les conseils"
	c.button_pressed = Options.conseils
	c.toggled.connect(func(b):
		Options.conseils = b
		Options.sauver())
	_ligne(page, "Conseils pendant le jeu", c, "Petites bulles qui expliquent les touches au bon moment.")
	var revoir := Button.new()
	revoir.text = "Revoir tous les conseils depuis le début"
	revoir.pressed.connect(func():
		Conseils.tout_revoir()
		c.button_pressed = true
		revoir.text = "C'est noté : les conseils vont réapparaître.")
	page.add_child(revoir)
	return page.get_parent().get_parent()


# --- Changement de touche ----------------------------------------------------

func _rafraichir_touches() -> void:
	for action: String in _boutons_touches:
		(_boutons_touches[action] as Button).text = Options.nom_touche(action)


func _attendre_touche(action: String, bouton: Button) -> void:
	_annuler_attente()
	_action_attendue = action
	_bouton_attendu = bouton
	bouton.text = "Appuie sur une touche… (Échap : annuler)"
	_message_touches.text = ""


func _annuler_attente() -> void:
	_action_attendue = ""
	_bouton_attendu = null
	if not _boutons_touches.is_empty():
		_rafraichir_touches()


func _input(evenement: InputEvent) -> void:
	if _action_attendue == "" or not visible:
		return
	if not (evenement is InputEventKey and evenement.pressed and not evenement.echo):
		return
	get_viewport().set_input_as_handled()
	var touche := evenement as InputEventKey
	if touche.keycode == KEY_ESCAPE:
		_annuler_attente()
		return
	if touche.keycode in [KEY_F10]:
		_message_touches.text = "F10 est réservée à la qualité des graphismes."
		_annuler_attente()
		return
	var physique := touche.physical_keycode if touche.physical_keycode != KEY_NONE else touche.keycode
	var action := _action_attendue
	var autre := Options.changer_touche(action, physique)
	_annuler_attente()
	if autre != "":
		_message_touches.text = "Cette touche servait à « %s » : les deux touches ont été échangées." % autre
