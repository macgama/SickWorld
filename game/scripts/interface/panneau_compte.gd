extends VBoxContainer
## Panneau « Compte en ligne » du menu : se connecter, créer un compte,
## voir si la sauvegarde en ligne est à jour, se déconnecter.
## Il se suffit à lui-même : le menu fait juste add_child(panneau).
## Quand le profil change (autre compte), il recharge la scène du menu pour
## afficher le bon personnage.

const COULEUR_OK := Color(0.5, 0.9, 0.6)
const COULEUR_ERREUR := Color(1, 0.5, 0.4)
const COULEUR_DISCRET := Color(1, 1, 1, 0.65)

var _mode_creation := false
var _occupe := false
var _email: LineEdit
var _mot_de_passe: LineEdit
var _confirmation: LineEdit
var _pseudo: LineEdit
var _message: Label
var _etat: Label


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	Compte.etat_change.connect(_mettre_a_jour_etat)
	Compte.profil_change.connect(_au_changement_de_profil)
	_construire()


func _construire() -> void:
	for enfant in get_children():
		enfant.queue_free()
	_message = null
	_etat = null

	var titre := Label.new()
	titre.text = "Compte en ligne"
	titre.add_theme_font_size_override("font_size", 18)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(titre)

	if Compte.a_un_compte:
		_construire_connecte()
	else:
		_construire_formulaire()

	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_message)


func _construire_connecte() -> void:
	var qui := Label.new()
	qui.text = "Connecté : %s" % Compte.pseudo
	if Compte.email != "":
		qui.text += "  (%s)" % Compte.email
	qui.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(qui)
	_etat = Label.new()
	_etat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_etat)
	_mettre_a_jour_etat()
	var ligne := HBoxContainer.new()
	ligne.alignment = BoxContainer.ALIGNMENT_CENTER
	ligne.add_child(_bouton("Sauvegarder maintenant", _sauvegarder_maintenant))
	ligne.add_child(_bouton("Se déconnecter", _se_deconnecter))
	add_child(ligne)


func _construire_formulaire() -> void:
	var aide := Label.new()
	aide.text = ("Crée ton compte pour retrouver ton personnage sur n'importe quel PC."
			if _mode_creation else
			"Facultatif : sans compte, ta partie reste sur ce PC.")
	aide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aide.add_theme_color_override("font_color", COULEUR_DISCRET)
	add_child(aide)

	if _mode_creation:
		_pseudo = _champ("Pseudo (3 à 20 caractères)")
	_email = _champ("Adresse e-mail")
	_email.text = Compte.email
	_mot_de_passe = _champ("Mot de passe (8 caractères minimum)", true)
	if _mode_creation:
		_confirmation = _champ("Retape le mot de passe", true)
		_confirmation.text_submitted.connect(func(_t): _valider())
	else:
		_mot_de_passe.text_submitted.connect(func(_t): _valider())

	var ligne := HBoxContainer.new()
	ligne.alignment = BoxContainer.ALIGNMENT_CENTER
	if _mode_creation:
		ligne.add_child(_bouton("Créer mon compte", _valider))
		ligne.add_child(_bouton("Annuler", func(): _changer_mode(false)))
	else:
		ligne.add_child(_bouton("Se connecter", _valider))
		ligne.add_child(_bouton("Créer un compte", func(): _changer_mode(true)))
	add_child(ligne)

	# Adresse du serveur : discrète, pour plus tard (serveur en ligne).
	var serveur := HBoxContainer.new()
	var etiquette := Label.new()
	etiquette.text = "Serveur :"
	etiquette.add_theme_color_override("font_color", COULEUR_DISCRET)
	serveur.add_child(etiquette)
	var adresse := LineEdit.new()
	adresse.text = Compte.adresse
	adresse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	adresse.tooltip_text = "Laisse 127.0.0.1:7350 si le serveur tourne sur ce PC."
	adresse.text_changed.connect(Compte.changer_adresse)
	serveur.add_child(adresse)
	add_child(serveur)


func _champ(indication: String, secret := false) -> LineEdit:
	var champ := LineEdit.new()
	champ.placeholder_text = indication
	champ.secret = secret
	add_child(champ)
	return champ


func _bouton(texte: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = texte
	b.custom_minimum_size = Vector2(0, 34)
	b.pressed.connect(action)
	return b


func _changer_mode(creation: bool) -> void:
	_mode_creation = creation
	_construire()


func _valider() -> void:
	if _occupe:
		return
	if _mode_creation and _confirmation.text != _mot_de_passe.text:
		_afficher("Les deux mots de passe ne sont pas identiques.", COULEUR_ERREUR)
		return
	_occupe = true
	_afficher("Connexion au serveur…", COULEUR_DISCRET)
	var probleme: String
	if _mode_creation:
		probleme = await Compte.creer_compte(_email.text, _mot_de_passe.text, _pseudo.text.strip_edges())
	else:
		probleme = await Compte.se_connecter(_email.text, _mot_de_passe.text)
	_occupe = false
	if probleme != "" and is_inside_tree():
		_afficher(probleme, COULEUR_ERREUR)
	# En cas de succès, profil_change recharge le menu.


func _sauvegarder_maintenant() -> void:
	if not Compte.en_ligne:
		_afficher("Serveur injoignable pour l'instant : on réessaiera tout seul.", COULEUR_ERREUR)
		return
	_afficher("Envoi…", COULEUR_DISCRET)
	await Compte.synchroniser()
	if is_inside_tree():
		_afficher("", COULEUR_OK)


func _se_deconnecter() -> void:
	if _occupe:
		return
	_occupe = true
	await Compte.se_deconnecter()


func _afficher(texte: String, couleur: Color) -> void:
	if _message == null:
		return
	_message.text = texte
	_message.add_theme_color_override("font_color", couleur)


func _mettre_a_jour_etat() -> void:
	if _etat == null or not is_instance_valid(_etat):
		return
	_etat.text = Compte.etat
	_etat.add_theme_color_override("font_color", COULEUR_OK if Compte.en_ligne else COULEUR_ERREUR)


func _au_changement_de_profil() -> void:
	if is_inside_tree():
		get_tree().reload_current_scene.call_deferred()
