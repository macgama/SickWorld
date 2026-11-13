extends Control
## Menu de départ : choisir son nom, puis jouer seul, héberger une partie ou en rejoindre une.

const FICHIER_REGLAGES := "user://reglages.cfg"

var _nom: LineEdit
var _adresse: LineEdit
var _port: SpinBox
var _message: Label


func _ready() -> void:
	# Lancement automatique depuis la ligne de commande (serveur dédié, tests…).
	if not Reseau.has_meta("demarrage_auto_fait"):
		Reseau.set_meta("demarrage_auto_fait", true)
		if Reseau.mode == Reseau.Mode.SERVEUR_DEDIE or Reseau.mode == Reseau.Mode.REJOINDRE:
			_lancer.call_deferred(Reseau.mode)
			return
	_construire()


func _construire() -> void:
	var reglages := ConfigFile.new()
	reglages.load(FICHIER_REGLAGES)

	var fond := ColorRect.new()
	fond.color = Color(0.05, 0.07, 0.1)
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var colonne := VBoxContainer.new()
	colonne.custom_minimum_size = Vector2(420, 0)
	colonne.add_theme_constant_override("separation", 12)
	centre.add_child(colonne)

	var titre := Label.new()
	titre.text = "SickWorld"
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_font_size_override("font_size", 48)
	titre.add_theme_color_override("font_color", Color(0.25, 0.85, 0.9))
	colonne.add_child(titre)
	var sous_titre := Label.new()
	sous_titre.text = "Prototype — la Vigie a besoin de toi"
	sous_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sous_titre.modulate.a = 0.7
	colonne.add_child(sous_titre)
	colonne.add_child(HSeparator.new())

	colonne.add_child(_etiquette("Nom de ton personnage"))
	_nom = LineEdit.new()
	_nom.max_length = 20
	_nom.text = reglages.get_value("joueur", "nom", "Agent")
	colonne.add_child(_nom)

	colonne.add_child(_bouton("Jouer seul", func(): _lancer(Reseau.Mode.SEUL)))
	colonne.add_child(_bouton("Héberger une partie (tes amis te rejoignent)",
			func(): _lancer(Reseau.Mode.HEBERGER)))
	colonne.add_child(HSeparator.new())

	colonne.add_child(_etiquette("Rejoindre une partie : adresse du serveur"))
	var ligne := HBoxContainer.new()
	_adresse = LineEdit.new()
	_adresse.text = reglages.get_value("reseau", "adresse", "127.0.0.1")
	_adresse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_adresse.placeholder_text = "ex. 192.168.1.20"
	ligne.add_child(_adresse)
	_port = SpinBox.new()
	_port.min_value = 1024
	_port.max_value = 65535
	_port.value = reglages.get_value("reseau", "port", Reseau.PORT_PAR_DEFAUT)
	ligne.add_child(_port)
	colonne.add_child(ligne)
	colonne.add_child(_bouton("Rejoindre", func(): _lancer(Reseau.Mode.REJOINDRE)))

	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_color_override("font_color", Color(1, 0.5, 0.4))
	_message.text = String(Reseau.get_meta("message_menu", ""))
	if Reseau.has_meta("message_menu"):
		Reseau.remove_meta("message_menu")
	colonne.add_child(_message)


func _etiquette(texte: String) -> Label:
	var l := Label.new()
	l.text = texte
	return l


func _bouton(texte: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = texte
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(action)
	return b


func _lancer(mode: Reseau.Mode) -> void:
	Reseau.mode = mode
	if _nom != null:
		Reseau.nom_joueur = _nom.text.strip_edges() if _nom.text.strip_edges() != "" else "Agent"
		Reseau.adresse = _adresse.text.strip_edges()
		Reseau.port = int(_port.value)
		var reglages := ConfigFile.new()
		reglages.set_value("joueur", "nom", Reseau.nom_joueur)
		reglages.set_value("reseau", "adresse", Reseau.adresse)
		reglages.set_value("reseau", "port", Reseau.port)
		reglages.save(FICHIER_REGLAGES)
	get_tree().change_scene_to_file(Reseau.SCENE_MONDE)
