extends Control
## Menu de départ : créer (ou modifier) son personnage, puis jouer seul,
## héberger une partie ou en rejoindre une.

const FICHIER_REGLAGES := "user://reglages.cfg"
const SCENE_CREATION := "res://scenes/interface/creation_personnage.tscn"

var _a_un_personnage := false
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

	# Le personnage : résumé + bouton pour le créer ou le modifier.
	var fiche := FichePersonnage.charger(Donnees.creation)
	_a_un_personnage = not fiche.is_empty()
	var resume := Label.new()
	resume.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resume.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _a_un_personnage:
		Reseau.fiche = fiche
		Reseau.nom_joueur = fiche["nom"]
		var classe := FichePersonnage.element(Donnees.creation, "classes", fiche["classe"])
		var origine := FichePersonnage.element(Donnees.creation, "origines", fiche["origine"])
		resume.text = "%s\n%s · originaire de %s" % [fiche["nom"], classe.get("nom", ""), origine.get("nom", "")]
		resume.add_theme_font_size_override("font_size", 20)
	else:
		resume.text = "Crée ton agent de la Vigie pour commencer."
	colonne.add_child(resume)
	colonne.add_child(_bouton("Modifier mon personnage" if _a_un_personnage else "Créer mon personnage",
			func(): get_tree().change_scene_to_file(SCENE_CREATION)))
	colonne.add_child(HSeparator.new())

	var jouer := _bouton("Jouer seul", func(): _lancer(Reseau.Mode.SEUL))
	var heberger := _bouton("Héberger une partie (tes amis te rejoignent)",
			func(): _lancer(Reseau.Mode.HEBERGER))
	colonne.add_child(jouer)
	colonne.add_child(heberger)
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
	var rejoindre := _bouton("Rejoindre", func(): _lancer(Reseau.Mode.REJOINDRE))
	colonne.add_child(rejoindre)
	for b in [jouer, heberger, rejoindre]:
		b.disabled = not _a_un_personnage

	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_color_override("font_color", Color(1, 0.5, 0.4))
	_message.text = String(Reseau.get_meta("message_menu", ""))
	if Reseau.has_meta("message_menu"):
		Reseau.remove_meta("message_menu")
	colonne.add_child(_message)
	if Reseau.has_meta("message_menu_ok"):
		var ok := Label.new()
		ok.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ok.add_theme_color_override("font_color", Color(0.5, 0.9, 0.6))
		ok.text = String(Reseau.get_meta("message_menu_ok"))
		Reseau.remove_meta("message_menu_ok")
		colonne.add_child(ok)


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
	if _adresse != null:
		Reseau.adresse = _adresse.text.strip_edges()
		Reseau.port = int(_port.value)
		var reglages := ConfigFile.new()
		reglages.set_value("reseau", "adresse", Reseau.adresse)
		reglages.set_value("reseau", "port", Reseau.port)
		reglages.save(FICHIER_REGLAGES)
	get_tree().change_scene_to_file(Reseau.SCENE_MONDE)
