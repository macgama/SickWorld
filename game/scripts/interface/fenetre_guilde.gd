extends CanvasLayer
## Interface des GUILDES (créée toute seule par l'autoload Guildes dans chaque partie) :
## - la fenêtre GUILDE (touche G, /guilde, le coffre ou le tableau des contrats de la
##   Maison des guildes) : onglets Guilde, Membres, Banque, Contrats, Journal ;
## - l'INVITATION reçue (Accepter / Refuser) ;
## - le bouton « Inviter dans la guilde » sous le cadre de la cible quand on cible un joueur ;
## - les grandes nouvelles (contrat accompli, niveau de guilde) en haut de l'écran.
## Rien n'est décidé ici : chaque clic envoie une demande au serveur (voir Guildes).

const Style := preload("res://scripts/interface/style_menu.gd")
const R := preload("res://scripts/guildes/regles_guildes.gd")
const VERT := Color(0.45, 1.0, 0.55)
const ROUGE := Color(1.0, 0.45, 0.4)
const OR := Color(1.0, 0.84, 0.35)
const GRIS := Color(0.7, 0.74, 0.8)
const TAILLE_CASE := 54
enum { ONGLET_GUILDE, ONGLET_MEMBRES, ONGLET_BANQUE, ONGLET_CONTRATS, ONGLET_JOURNAL }

var _racine: Control
var _fenetre: PanelContainer
var _titre: Label
var _onglets: TabContainer
var _sans_guilde: Label
# Onglet Guilde
var _banniere: PanelContainer
var _nom_banniere: Label
var _niveau: Label
var _barre_xp: ProgressBar
var _texte_xp: Label
var _resume: Label
var _message: Label
var _champ_message: LineEdit
var _ligne_message: HBoxContainer
var _avantages: VBoxContainer
# Onglet Membres
var _ligne_inviter: HBoxContainer
var _champ_inviter: LineEdit
var _liste_membres: VBoxContainer
var _bouton_quitter: Button
var _confirmation: ConfirmationDialog
var _action_confirmee: Callable
# Onglet Banque
var _etat_banque: Label
var _grille_banque: GridContainer
var _grille_sacs: GridContainer
var _cases_banque: Array[Button] = []
var _cases_sacs: Array[Button] = []
# Onglet Contrats
var _liste_contrats: VBoxContainer
var _pied_contrats: Label
# Onglet Journal
var _journal: RichTextLabel
# Le reste
var _invitation: PanelContainer
var _texte_invitation: Label
var _bouton_inviter_cible: Button
var _annonce: PanelContainer
var _annonce_titre: Label
var _annonce_texte: Label
var _inventaire: Node
var _minuteur := 0.0


func _ready() -> void:
	layer = 7
	_racine = Control.new()
	_racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	_racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.theme = Style.theme()
	add_child(_racine)
	_construire_fenetre()
	_construire_invitation()
	_construire_annonce()
	_bouton_inviter_cible = _petit_bouton("Inviter dans la guilde", func():
		var cible := _joueur_cible()
		if cible != null:
			Guildes.inviter(String(cible.get_node("Combat").nom_affiche)))
	_bouton_inviter_cible.position = Vector2(312, 168)
	_bouton_inviter_cible.visible = false
	_racine.add_child(_bouton_inviter_cible)
	Guildes.change.connect(rafraichir)
	Guildes.invitation_changee.connect(_sur_invitation)
	Guildes.annonce.connect(_montrer_annonce)
	if not Guildes.invitation.is_empty():
		_sur_invitation(String(Guildes.invitation["de"]), String(Guildes.invitation["guilde"]))
	rafraichir()


func _process(delta: float) -> void:
	_minuteur += delta
	if _minuteur < 0.4:
		return
	_minuteur = 0.0
	if _inventaire == null or not is_instance_valid(_inventaire):
		var local := get_tree().get_first_node_in_group("joueur_local")
		_inventaire = local.get_node_or_null("Inventaire") if local != null else null
		if _inventaire != null:
			_inventaire.change.connect(_rafraichir_sacs)
			_rafraichir_sacs()
	var cible := _joueur_cible()
	_bouton_inviter_cible.visible = cible != null and Guildes.a_une_guilde() and Guildes.droit("inviter") \
			and not Guildes.est_dans_ma_guilde(String(cible.get_node("Combat").nom_affiche))
	if _fenetre.visible and _onglets.current_tab == ONGLET_BANQUE:
		_rafraichir_etat_banque()


# --- Outils ------------------------------------------------------------------------------

func _texte(contenu: String, taille := 14, couleur := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = contenu
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	return l


func _paragraphe(contenu: String, taille := 14, couleur := Color.WHITE) -> Label:
	var l := _texte(contenu, taille, couleur)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _petit_bouton(texte: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = texte
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(action)
	return b


func _cadre(fond: Color, bord: Color, marge := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fond
	s.border_color = bord
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(marge)
	return s


func _vider(conteneur: Node) -> void:
	for enfant in conteneur.get_children():
		conteneur.remove_child(enfant)
		enfant.queue_free()


func _joueur_cible() -> Node:
	var local := get_tree().get_first_node_in_group("joueur_local")
	if local == null:
		return null
	var cible = local.get_node("CombatJoueur").cible
	if cible == null or not is_instance_valid(cible):
		return null
	var acteur: Node = cible.acteur()
	if acteur is Joueur and acteur != local:
		return acteur
	return null


static func duree_lisible(secondes: int) -> String:
	var j := secondes / 86400
	var h := (secondes % 86400) / 3600
	var m := (secondes % 3600) / 60
	if j > 0:
		return "%d j %d h" % [j, h]
	if h > 0:
		return "%d h %02d" % [h, m]
	return "%d min" % maxi(1, m)


static func il_y_a(t: int) -> String:
	if t <= 0:
		return ""
	var ecart := maxi(0, int(Time.get_unix_time_from_system()) - t)
	if ecart < 120:
		return "à l'instant"
	return "il y a " + duree_lisible(ecart)


# --- Construction de la fenêtre ----------------------------------------------------------

func _construire_fenetre() -> void:
	_fenetre = PanelContainer.new()
	_fenetre.visible = false
	_fenetre.mouse_filter = Control.MOUSE_FILTER_STOP
	_fenetre.add_theme_stylebox_override("panel", _cadre(Color(0.04, 0.05, 0.08, 0.97), Color(OR, 0.55)))
	_racine.add_child(_fenetre)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 10)
	_fenetre.add_child(colonne)
	var haut := HBoxContainer.new()
	haut.add_theme_constant_override("separation", 14)
	colonne.add_child(haut)
	_titre = _texte("Guilde · ギルド", 20, OR)
	_titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haut.add_child(_titre)
	var aide := _texte("G ou Échap : fermer", 12, GRIS)
	haut.add_child(aide)
	haut.add_child(_petit_bouton("  ✕  ", fermer))

	_sans_guilde = _paragraphe("", 15)
	_sans_guilde.custom_minimum_size = Vector2(820, 120)
	colonne.add_child(_sans_guilde)

	_onglets = TabContainer.new()
	_onglets.custom_minimum_size = Vector2(840, 520)
	_onglets.tab_changed.connect(func(_n): _rafraichir_onglet())
	colonne.add_child(_onglets)
	_onglets.add_child(_construire_onglet_guilde())
	_onglets.add_child(_construire_onglet_membres())
	_onglets.add_child(_construire_onglet_banque())
	_onglets.add_child(_construire_onglet_contrats())
	_onglets.add_child(_construire_onglet_journal())

	_confirmation = ConfirmationDialog.new()
	_confirmation.ok_button_text = "Oui"
	_confirmation.cancel_button_text = "Non"
	_confirmation.confirmed.connect(func():
		if _action_confirmee.is_valid():
			_action_confirmee.call())
	_racine.add_child(_confirmation)


func _construire_onglet_guilde() -> Control:
	var page := VBoxContainer.new()
	page.name = "Guilde"
	page.add_theme_constant_override("separation", 10)
	var haut := HBoxContainer.new()
	haut.add_theme_constant_override("separation", 18)
	page.add_child(haut)
	_banniere = PanelContainer.new()
	_banniere.custom_minimum_size = Vector2(170, 210)
	haut.add_child(_banniere)
	_nom_banniere = _texte("", 20, Color(1.0, 0.92, 0.75))
	_nom_banniere.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nom_banniere.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_nom_banniere.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banniere.add_child(_nom_banniere)
	var infos := VBoxContainer.new()
	infos.add_theme_constant_override("separation", 8)
	infos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haut.add_child(infos)
	_niveau = _texte("", 22, OR)
	infos.add_child(_niveau)
	_barre_xp = ProgressBar.new()
	_barre_xp.custom_minimum_size = Vector2(0, 18)
	_barre_xp.show_percentage = false
	infos.add_child(_barre_xp)
	_texte_xp = _texte("", 13, GRIS)
	infos.add_child(_texte_xp)
	_resume = _paragraphe("", 14)
	infos.add_child(_resume)
	infos.add_child(_texte("Message de la guilde", 15, OR))
	_message = _paragraphe("", 14)
	infos.add_child(_message)
	_ligne_message = HBoxContainer.new()
	_ligne_message.add_theme_constant_override("separation", 8)
	infos.add_child(_ligne_message)
	_champ_message = LineEdit.new()
	_champ_message.placeholder_text = "Nouveau message pour toute la guilde"
	_champ_message.max_length = 160
	_champ_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_champ_message.text_submitted.connect(func(_t): _envoyer_message())
	_ligne_message.add_child(_champ_message)
	_ligne_message.add_child(_petit_bouton("Changer le message", _envoyer_message))
	page.add_child(_texte("Avantages de la guilde", 15, OR))
	_avantages = VBoxContainer.new()
	page.add_child(_avantages)
	return page


func _construire_onglet_membres() -> Control:
	var page := VBoxContainer.new()
	page.name = "Membres"
	page.add_theme_constant_override("separation", 8)
	_ligne_inviter = HBoxContainer.new()
	_ligne_inviter.add_theme_constant_override("separation", 8)
	page.add_child(_ligne_inviter)
	_champ_inviter = LineEdit.new()
	_champ_inviter.placeholder_text = "Nom du joueur à inviter"
	_champ_inviter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_champ_inviter.text_submitted.connect(func(_t): _inviter_champ())
	_ligne_inviter.add_child(_champ_inviter)
	_ligne_inviter.add_child(_petit_bouton("Inviter dans la guilde", _inviter_champ))
	var defile := ScrollContainer.new()
	defile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(defile)
	_liste_membres = VBoxContainer.new()
	_liste_membres.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_liste_membres.add_theme_constant_override("separation", 4)
	defile.add_child(_liste_membres)
	var bas := HBoxContainer.new()
	page.add_child(bas)
	var espace := Control.new()
	espace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bas.add_child(espace)
	_bouton_quitter = _petit_bouton("Quitter la guilde", func():
		var seul := (Guildes.guilde.get("membres", []) as Array).size() <= 1
		_confirmer("Dissoudre la guilde « %s » ? (la banque doit être vide)" % Guildes.guilde.get("nom", "") if seul
				else "Quitter la guilde « %s » ?" % Guildes.guilde.get("nom", ""), Guildes.quitter))
	bas.add_child(_bouton_quitter)
	return page


func _construire_onglet_banque() -> Control:
	var page := VBoxContainer.new()
	page.name = "Banque"
	page.add_theme_constant_override("separation", 8)
	_etat_banque = _paragraphe("", 14)
	page.add_child(_etat_banque)
	var defile := ScrollContainer.new()
	defile.custom_minimum_size = Vector2(0, 250)
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(defile)
	_grille_banque = GridContainer.new()
	_grille_banque.columns = 14
	_grille_banque.add_theme_constant_override("h_separation", 4)
	_grille_banque.add_theme_constant_override("v_separation", 4)
	defile.add_child(_grille_banque)
	page.add_child(_texte("Tes sacs · clique sur un objet pour le déposer dans la banque", 14, OR))
	var defile_sacs := ScrollContainer.new()
	defile_sacs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defile_sacs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(defile_sacs)
	_grille_sacs = GridContainer.new()
	_grille_sacs.columns = 14
	_grille_sacs.add_theme_constant_override("h_separation", 4)
	_grille_sacs.add_theme_constant_override("v_separation", 4)
	defile_sacs.add_child(_grille_sacs)
	return page


func _construire_onglet_contrats() -> Control:
	var page := VBoxContainer.new()
	page.name = "Contrats"
	page.add_theme_constant_override("separation", 10)
	page.add_child(_paragraphe("Chaque semaine, la guilde reçoit trois contrats. Tout ce que font les membres compte, sur toutes les îles. Un contrat accompli donne des Sceaux de guilde à ceux qui ont aidé (à échanger chez Mei Takahara, l'intendante), et de l'XP à la guilde.", 13, GRIS))
	_liste_contrats = VBoxContainer.new()
	_liste_contrats.add_theme_constant_override("separation", 12)
	page.add_child(_liste_contrats)
	_pied_contrats = _paragraphe("", 14)
	page.add_child(_pied_contrats)
	return page


func _construire_onglet_journal() -> Control:
	var page := VBoxContainer.new()
	page.name = "Journal"
	_journal = RichTextLabel.new()
	_journal.bbcode_enabled = true
	_journal.scroll_following = true
	_journal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_journal.add_theme_font_size_override("normal_font_size", 14)
	page.add_child(_journal)
	return page


func _construire_invitation() -> void:
	_invitation = PanelContainer.new()
	_invitation.visible = false
	_invitation.add_theme_stylebox_override("panel", _cadre(Color(0.05, 0.06, 0.1, 0.95), Color(OR, 0.8), 12))
	_invitation.anchor_left = 0.5
	_invitation.anchor_right = 0.5
	_invitation.offset_left = -230
	_invitation.offset_right = 230
	_invitation.offset_top = 150
	_racine.add_child(_invitation)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 8)
	_invitation.add_child(colonne)
	_texte_invitation = _paragraphe("", 15)
	_texte_invitation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(_texte_invitation)
	var boutons := HBoxContainer.new()
	boutons.alignment = BoxContainer.ALIGNMENT_CENTER
	boutons.add_theme_constant_override("separation", 16)
	colonne.add_child(boutons)
	boutons.add_child(_petit_bouton("Rejoindre la guilde", func(): Guildes.repondre_invitation(true)))
	boutons.add_child(_petit_bouton("Refuser", func(): Guildes.repondre_invitation(false)))


func _construire_annonce() -> void:
	_annonce = PanelContainer.new()
	_annonce.visible = false
	_annonce.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_annonce.add_theme_stylebox_override("panel", _cadre(Color(0.06, 0.05, 0.02, 0.88), Color(OR, 0.9), 14))
	_annonce.anchor_left = 0.5
	_annonce.anchor_right = 0.5
	_annonce.offset_left = -300
	_annonce.offset_right = 300
	_annonce.offset_top = 90
	_racine.add_child(_annonce)
	var colonne := VBoxContainer.new()
	colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_annonce.add_child(colonne)
	_annonce_titre = _texte("", 24, OR)
	_annonce_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(_annonce_titre)
	_annonce_texte = _paragraphe("", 15)
	_annonce_texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(_annonce_texte)


# --- Ouvrir, fermer --------------------------------------------------------------------------

func basculer(onglet := -1) -> void:
	if _fenetre.visible and (onglet < 0 or onglet == _onglets.current_tab):
		fermer()
	else:
		ouvrir(onglet)


func ouvrir(onglet := -1) -> void:
	if onglet >= 0:
		_onglets.current_tab = onglet
	_fenetre.visible = true
	Guildes.rafraichir()
	rafraichir()
	_centrer.call_deferred()


func fermer() -> void:
	_fenetre.visible = false
	_champ_inviter.release_focus()
	_champ_message.release_focus()


func est_ouverte() -> bool:
	return _fenetre.visible


func _centrer() -> void:
	_fenetre.reset_size()
	_fenetre.position = ((_racine.get_viewport_rect().size - _fenetre.size) / 2.0).floor()


func _discussion_ouverte() -> bool:
	var s = Social.get("_interface")
	return s != null and is_instance_valid(s) and s.has_method("discussion_ouverte") and s.discussion_ouverte()


func _unhandled_input(evenement: InputEvent) -> void:
	if not (evenement is InputEventKey and evenement.pressed and not evenement.echo):
		return
	if _discussion_ouverte() or _champ_inviter.has_focus() or _champ_message.has_focus():
		return
	var touche := evenement as InputEventKey
	if touche.keycode == KEY_G:
		basculer()
		get_viewport().set_input_as_handled()
	elif touche.keycode == KEY_ESCAPE and _fenetre.visible:
		fermer()
		get_viewport().set_input_as_handled()


func _confirmer(question: String, action: Callable) -> void:
	_confirmation.dialog_text = question
	_action_confirmee = action
	_confirmation.popup_centered()


# --- Remplissage ------------------------------------------------------------------------------

func rafraichir() -> void:
	var g: Dictionary = Guildes.guilde
	var a = not g.is_empty()
	_onglets.visible = a
	_sans_guilde.visible = not a
	if not a:
		_titre.text = "Guilde · ギルド"
		if Guildes.en_donjon:
			_sans_guilde.text = "Tu es en donjon. La guilde t'attend en ville : ce que tu fais ici (ennemis, chefs) comptera pour ses contrats à ton retour."
		elif not Guildes.ailleurs.is_empty():
			_sans_guilde.text = ("Ta guilde « %s » vit sur un autre serveur. Ce que tu fais ici compte quand même : "
					+ "c'est gardé et donné à ses contrats dès que tu y retournes.") % Guildes.ailleurs.get("nom", "")
		else:
			_sans_guilde.text = ("Tu n'as pas encore de guilde.\n\n• Pour en FONDER une : va voir Aleksander Nowak, le registraire de la Maison des guildes "
					+ "(quartier des Résidences), après sa mission « Trois signatures ».\n"
					+ "• Pour en REJOINDRE une : un membre de la guilde peut t'inviter (/ginviter TonNom, ou en te ciblant).\n\n"
					+ "Une guilde, c'est une banque partagée, des contrats chaque semaine qui rapportent des sceaux, "
					+ "et un canal de discussion (/gu).")
		return
	_titre.text = "Guilde « %s » · %s" % [g["nom"], g.get("nom_rang", "")]
	_rafraichir_onglet()


func _rafraichir_onglet() -> void:
	if Guildes.guilde.is_empty():
		return
	match _onglets.current_tab:
		ONGLET_GUILDE:
			_remplir_guilde()
		ONGLET_MEMBRES:
			_remplir_membres()
		ONGLET_BANQUE:
			_remplir_banque()
		ONGLET_CONTRATS:
			_remplir_contrats()
		ONGLET_JOURNAL:
			_remplir_journal()


func _remplir_guilde() -> void:
	var g: Dictionary = Guildes.guilde
	var style := _cadre(Guildes.couleur(int(g["couleur"])), OR, 10)
	style.set_border_width_all(3)
	_banniere.add_theme_stylebox_override("panel", style)
	_nom_banniere.text = String(g["nom"])
	var av: Dictionary = g.get("avancement", {})
	_niveau.text = "Niveau %d" % int(g["niveau"])
	if int(av.get("pour_niveau", 0)) > 0:
		_barre_xp.max_value = int(av["pour_niveau"])
		_barre_xp.value = int(av["dans_niveau"])
		_texte_xp.text = "XP de guilde : %d / %d vers le niveau %d" % [int(av["dans_niveau"]), int(av["pour_niveau"]), int(g["niveau"]) + 1]
	else:
		_barre_xp.max_value = 1
		_barre_xp.value = 1
		_texte_xp.text = "Niveau maximum atteint (%d XP)" % int(g["xp"])
	var en_ligne := (g["membres"] as Array).filter(func(m): return m["en_ligne"]).size()
	var fondee := Time.get_date_string_from_unix_time(int(g.get("fondee", 0))) if int(g.get("fondee", 0)) > 0 else "?"
	_resume.text = "Membres : %d / %d (%d en ligne)   ·   Banque : %d places   ·   Fondée le %s\nTon rang : %s" % [
			(g["membres"] as Array).size(), int(g["membres_max"]), en_ligne, int(g["places_banque"]), fondee, g.get("nom_rang", "")]
	_message.text = String(g.get("message", "")) if String(g.get("message", "")) != "" else "(pas de message)"
	_ligne_message.visible = Guildes.droit("message")
	_vider(_avantages)
	for av_ in Guildes.d.get("avantages", []):
		var ok := int(g["niveau"]) >= int(av_["niveau"])
		_avantages.add_child(_texte("%s  Niveau %d : %s" % ["✓" if ok else "·", int(av_["niveau"]), av_["texte"]], 14, VERT if ok else GRIS))
	_avantages.add_child(_texte("·  Chaque niveau : +%d places de banque, +%d membres, +%d sceau par contrat" % [
			int(R.reglage(Guildes.d, "banque_places_par_niveau", 8)), int(R.reglage(Guildes.d, "membres_max_par_niveau", 10)),
			int(R.reglage(Guildes.d, "sceaux_par_niveau", 1))], 14, GRIS))


func _envoyer_message() -> void:
	Guildes.ecrire_message(_champ_message.text)
	_champ_message.text = ""
	_champ_message.release_focus()


func _inviter_champ() -> void:
	Guildes.inviter(_champ_inviter.text)
	_champ_inviter.text = ""
	_champ_inviter.release_focus()


func _remplir_membres() -> void:
	var g: Dictionary = Guildes.guilde
	_ligne_inviter.visible = Guildes.droit("inviter")
	_vider(_liste_membres)
	var mon_ordre := 99
	var moi := Social.mon_nom().to_lower()
	for m in g["membres"]:
		if String(m["nom"]).to_lower() == moi:
			mon_ordre = int(m["ordre"])
	var entete := HBoxContainer.new()
	for t in [["Nom", 200], ["Rang", 150], ["Cette semaine", 120], ["Vu", 130]]:
		var l := _texte(t[0], 13, OR)
		l.custom_minimum_size = Vector2(t[1], 0)
		entete.add_child(l)
	_liste_membres.add_child(entete)
	var nb_rangs := (g.get("rangs", []) as Array).size()
	for m in g["membres"]:
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", 6)
		var nom := _texte(String(m["nom"]), 14, VERT if m["en_ligne"] else GRIS)
		nom.custom_minimum_size = Vector2(200, 0)
		ligne.add_child(nom)
		var rang := _texte(String(m["nom_rang"]), 14, OR if int(m["ordre"]) == 0 else Color.WHITE)
		rang.custom_minimum_size = Vector2(150, 0)
		ligne.add_child(rang)
		var semaine := _texte(str(int(m["semaine"])), 14)
		semaine.custom_minimum_size = Vector2(120, 0)
		semaine.tooltip_text = "Actions comptées pour la guilde cette semaine (au total : %d)" % int(m["total"])
		semaine.mouse_filter = Control.MOUSE_FILTER_PASS
		ligne.add_child(semaine)
		var vu := _texte("en ligne" if m["en_ligne"] else il_y_a(int(m["vu"])), 13, GRIS)
		vu.custom_minimum_size = Vector2(130, 0)
		ligne.add_child(vu)
		var nom_m := String(m["nom"])
		var en_dessous := int(m["ordre"]) > mon_ordre
		if Guildes.droit("promouvoir") and en_dessous:
			if int(m["ordre"]) > 1 and (int(m["ordre"]) - 1 > mon_ordre or mon_ordre == 0):
				var b := _petit_bouton("▲ Promouvoir", func(): Guildes.promouvoir(nom_m))
				ligne.add_child(b)
			if int(m["ordre"]) < nb_rangs - 1:
				ligne.add_child(_petit_bouton("▼ Rétrograder", func(): Guildes.retrograder(nom_m)))
		if Guildes.droit("exclure") and en_dessous:
			ligne.add_child(_petit_bouton("Exclure", func(): _confirmer("Exclure %s de la guilde ?" % nom_m, func(): Guildes.exclure(nom_m))))
		if Guildes.droit("maitre") and String(m["nom"]).to_lower() != moi:
			ligne.add_child(_petit_bouton("♛ Nommer maître", func():
				_confirmer("Donner ta place de maître de guilde à %s ? Tu deviendras officier." % nom_m, func(): Guildes.nommer_maitre(nom_m))))
		_liste_membres.add_child(ligne)
	_bouton_quitter.text = "Dissoudre la guilde" if (g["membres"] as Array).size() <= 1 else "Quitter la guilde"


func _case(taille: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(taille, taille)
	b.focus_mode = Control.FOCUS_NONE
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 9)
	b.add_theme_constant_override("icon_max_width", taille - 8)
	var quantite := Label.new()
	quantite.name = "Quantite"
	quantite.add_theme_font_size_override("font_size", 12)
	quantite.add_theme_constant_override("outline_size", 4)
	quantite.add_theme_color_override("font_outline_color", Color.BLACK)
	quantite.position = Vector2(taille - 26, taille - 20)
	quantite.size = Vector2(22, 18)
	quantite.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(quantite)
	return b


func _habiller(b: Button, c: Dictionary, aide: String) -> void:
	var cat := Donnees.objets
	var id := String(c.get("id", ""))
	var couleur := Objets.couleur_rarete(cat, id) if id != "" else Color(1, 1, 1, 0.3)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.09, 0.12, 0.95) if id != "" else Color(0.06, 0.07, 0.09, 0.6)
	s.border_color = couleur if id != "" else Color(1, 1, 1, 0.08)
	s.set_border_width_all(2 if id != "" else 1)
	s.set_corner_radius_all(5)
	s.set_content_margin_all(3)
	b.add_theme_stylebox_override("normal", s)
	var survol := s.duplicate() as StyleBoxFlat
	survol.bg_color = survol.bg_color.lightened(0.12)
	b.add_theme_stylebox_override("hover", survol)
	b.add_theme_stylebox_override("pressed", survol)
	b.add_theme_color_override("font_color", couleur)
	var image := Objets.icone(id) if id != "" else null
	b.icon = image
	b.text = "" if id == "" or image != null else String(Objets.objet(cat, id).get("nom", id)).left(10)
	b.tooltip_text = (Objets.description(cat, id) + "\n\n" + aide) if id != "" else ""
	var q := b.get_node("Quantite") as Label
	q.text = str(int(c.get("n", 1))) if id != "" and int(c.get("n", 1)) > 1 else ""


func _pres_du_coffre() -> bool:
	var local := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if local == null:
		return false
	var portee := float(R.reglage(Guildes.d, "banque_distance", 6.0))
	for c in get_tree().get_nodes_in_group("coffre_guilde"):
		if c is Node3D and (c as Node3D).global_position.distance_to(local.global_position) <= portee:
			return true
	return Guildes.coffre_partout


func _rafraichir_etat_banque() -> void:
	var g: Dictionary = Guildes.guilde
	if g.is_empty():
		return
	var pleines := (g["banque"] as Array).filter(func(c): return not (c as Dictionary).is_empty()).size()
	var r := int(g.get("retraits_restants", 0))
	var texte := "Banque de la guilde : %d / %d places occupées.   Sorties possibles aujourd'hui : %s." % [
			pleines, (g["banque"] as Array).size(), "sans limite" if r < 0 else str(r)]
	if _pres_du_coffre():
		texte += "\nClique sur un objet de la banque pour le prendre, ou sur un objet de tes sacs pour le déposer."
		_etat_banque.modulate = Color.WHITE
	else:
		texte += "\nPour déposer ou prendre, va au coffre de la guilde (Maison des guildes, quartier des Résidences)."
		_etat_banque.modulate = Color(1.0, 0.85, 0.6)
	_etat_banque.text = texte


func _remplir_banque() -> void:
	var g: Dictionary = Guildes.guilde
	var banque: Array = g["banque"]
	while _cases_banque.size() < banque.size():
		var i := _cases_banque.size()
		var b := _case(TAILLE_CASE)
		b.pressed.connect(func(): Guildes.retirer(i))
		_grille_banque.add_child(b)
		_cases_banque.append(b)
	for i in _cases_banque.size():
		_cases_banque[i].visible = i < banque.size()
		if i < banque.size():
			_habiller(_cases_banque[i], banque[i], "Clic : prendre (près du coffre)")
	_rafraichir_etat_banque()
	_rafraichir_sacs()


func _rafraichir_sacs() -> void:
	if _inventaire == null or not is_instance_valid(_inventaire) or (_inventaire.etat as Dictionary).is_empty():
		return
	var cases: Array = _inventaire.etat["cases"]
	while _cases_sacs.size() < cases.size():
		var i := _cases_sacs.size()
		var b := _case(TAILLE_CASE)
		b.pressed.connect(func(): Guildes.deposer(i))
		_grille_sacs.add_child(b)
		_cases_sacs.append(b)
	for i in _cases_sacs.size():
		_cases_sacs[i].visible = i < cases.size()
		if i < cases.size():
			_habiller(_cases_sacs[i], cases[i], "Clic : déposer dans la banque de la guilde (près du coffre)")


func _remplir_contrats() -> void:
	var g: Dictionary = Guildes.guilde
	var c: Dictionary = g.get("contrats", {})
	_vider(_liste_contrats)
	for k in (c.get("liste", []) as Array):
		var boite := PanelContainer.new()
		boite.add_theme_stylebox_override("panel", _cadre(Color(0.07, 0.08, 0.11, 0.9), Color(VERT if k["fini"] else OR, 0.45), 10))
		var colonne := VBoxContainer.new()
		colonne.add_theme_constant_override("separation", 4)
		boite.add_child(colonne)
		var haut := HBoxContainer.new()
		colonne.add_child(haut)
		var titre := _texte(String(k["titre"]), 17, VERT if k["fini"] else OR)
		titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		haut.add_child(titre)
		haut.add_child(_texte("✓ Accompli" if k["fini"] else "%d / %d" % [int(k["compte"]), int(k["nombre"])], 15, VERT if k["fini"] else Color.WHITE))
		colonne.add_child(_paragraphe(String(k["texte"]), 13, GRIS))
		var barre := ProgressBar.new()
		barre.show_percentage = false
		barre.custom_minimum_size = Vector2(0, 14)
		barre.max_value = maxi(1, int(k["nombre"]))
		barre.value = int(k["compte"])
		colonne.add_child(barre)
		_liste_contrats.add_child(boite)
	var texte := "Récompense : %d Sceaux de guilde par contrat accompli pour chaque membre qui a aidé, +%d si les trois sont accomplis." % [
			int(g.get("sceaux_par_contrat", 0)), int(g.get("sceaux_semaine", 0))]
	if c.get("semaine_complete", false):
		texte = "Tous les contrats de la semaine sont accomplis. Bravo !\n" + texte
	texte += "\nTa part cette semaine : %d actions.   Nouveaux contrats dans %s." % [int(c.get("mes_aides", 0)), duree_lisible(int(c.get("fin_dans", 0)))]
	_pied_contrats.text = texte


func _remplir_journal() -> void:
	var lignes: PackedStringArray = []
	for e in Guildes.guilde.get("journal", []):
		var date := Time.get_datetime_string_from_unix_time(int(e["t"]), true).left(16)
		lignes.append("[color=#8a94a0]%s[/color]  %s" % [date, String(e["texte"]).replace("[", "(").replace("]", ")")])
	_journal.text = "\n".join(lignes)


# --- Invitation, annonces ---------------------------------------------------------------------

func _sur_invitation(de: String, nom_guilde: String) -> void:
	_invitation.visible = de != ""
	if de != "":
		_texte_invitation.text = "%s t'invite dans la guilde\n« %s »" % [de, nom_guilde]


func _montrer_annonce(titre: String, texte: String) -> void:
	_annonce_titre.text = titre
	_annonce_texte.text = texte
	_annonce.visible = true
	_annonce.modulate.a = 0.0
	var anim := _annonce.create_tween()
	anim.tween_property(_annonce, "modulate:a", 1.0, 0.4)
	anim.tween_interval(4.5)
	anim.tween_property(_annonce, "modulate:a", 0.0, 1.0)
	anim.tween_callback(func(): _annonce.visible = false)
