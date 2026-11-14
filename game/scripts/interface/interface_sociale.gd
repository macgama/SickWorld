extends CanvasLayer
## Interface de la vie sociale (créée toute seule par l'autoload Social dans chaque partie) :
## - la DISCUSSION en bas à gauche (Entrée pour écrire) ;
## - les CADRES DU GROUPE à gauche (nom, classe, vie de chaque membre ; clic = cibler,
##   clic droit = chuchoter, nommer chef, exclure) ;
## - les BULLES au-dessus de la tête des joueurs qui parlent (canal « Dire ») ;
## - l'INVITATION reçue (Accepter / Refuser) et le bouton « Inviter dans le groupe »
##   sous le cadre de la cible quand on cible un autre joueur ;
## - la fenêtre DONJONS (touche K) pour entrer dans un donjon avec son groupe.

const Style := preload("res://scripts/interface/style_menu.gd")

const TAILLE_TEXTE := 14
## Hauteur de l'historique de la discussion (pixels).
const HAUTEUR_DISCUSSION := 190
const NOMS_ETATS := {"ailleurs": "Déconnecté", "donjon": "En donjon"}

var _racine: Control
# Discussion
var _discussion: PanelContainer
var _historique: RichTextLabel
var _ligne_saisie: HBoxContainer
var _etiquette_canal: Label
var _saisie: LineEdit
var _style_ouvert: StyleBoxFlat
var _style_ferme: StyleBoxFlat
# Groupe
var _colonne_groupe: VBoxContainer
var _titre_groupe: Label
var _cadres: VBoxContainer
var _boutons_groupe: HBoxContainer
var _bouton_quitter_donjon: Button
var _menu_membre: PopupMenu
var _membre_menu := ""
var _invitation: PanelContainer
var _texte_invitation: Label
var _bouton_inviter: Button
# Donjons
var _fenetre_donjons: PanelContainer
var _liste_donjons: VBoxContainer
var _voile: ColorRect
var _titre_voile: Label
# Bulles : identifiant du joueur -> {"panneau", "fin"}
var _bulles := {}
var _calque_bulles: Control
const DUREE_BULLE := 6.0
const LARGEUR_BULLE := 260.0


func _ready() -> void:
	layer = 6
	_racine = Control.new()
	_racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	_racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.theme = Style.theme()
	add_child(_racine)
	_calque_bulles = Control.new()
	_calque_bulles.set_anchors_preset(Control.PRESET_FULL_RECT)
	_calque_bulles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.add_child(_calque_bulles)
	_construire_discussion()
	_construire_groupe()
	_construire_invitation()
	_construire_donjons()
	_construire_voile()
	Social.message_recu.connect(_sur_message)
	Social.groupe_change.connect(_rafraichir_groupe)
	Social.invitation_changee.connect(_sur_invitation)
	Social.depart_en_donjon.connect(_sur_depart_en_donjon)
	Social.bulle.connect(montrer_bulle)
	get_viewport().size_changed.connect(_placer)
	_placer()
	for m in Social.historique:
		_afficher_ligne(m["canal"], m["auteur"], m["texte"])
	_rafraichir_groupe()
	if Social.invitation_de != "":
		_sur_invitation(Social.invitation_de)


var _aide_hud: Control
var _aide_cherchee := false


## Le panneau d'aide (F1) de l'interface principale, pour ne pas le recouvrir.
func _aide_du_hud() -> Control:
	if not _aide_cherchee:
		_aide_cherchee = true
		var scene := get_parent().get_parent() if get_parent() != null else null
		if scene != null:
			for calque in scene.find_children("*", "CanvasLayer", true, false):
				var aide = calque.get("_aide")
				if aide is Control:
					_aide_hud = aide
	return _aide_hud if is_instance_valid(_aide_hud) else null


func _placer() -> void:
	var taille := get_viewport().get_visible_rect().size
	# La discussion ne doit pas passer sous la barre de compétences (au centre, ~680 px).
	if _discussion == null or _colonne_groupe == null:
		return
	var largeur := clampf((taille.x - 700.0) / 2.0 - 24.0, 280.0, 460.0)
	if _discussion.custom_minimum_size.x != largeur:
		_discussion.custom_minimum_size.x = largeur
	_discussion.position = Vector2(16, taille.y - 16 - _discussion.size.y)
	# Cadres du groupe à droite, sous la mini-carte (et sous l'aide F1 si elle est affichée) :
	# la gauche est déjà prise par le suivi des missions.
	var haut := 270.0
	var aide := _aide_du_hud()
	if aide != null and aide.visible:
		haut = maxf(haut, aide.get_global_rect().end.y + 12.0)
	_colonne_groupe.position = Vector2(taille.x - 16.0 - _colonne_groupe.size.x, haut)


# --- Discussion ----------------------------------------------------------------

func _construire_discussion() -> void:
	_style_ferme = Style.boite(Color(0.02, 0.03, 0.05, 0.25), Color(0, 0, 0, 0), 0, 6)
	_style_ouvert = Style.boite(Color(0.02, 0.03, 0.05, 0.72), Color(Style.CYAN, 0.35), 1, 6)
	for s in [_style_ferme, _style_ouvert]:
		s.content_margin_left = 8
		s.content_margin_right = 8
		s.content_margin_top = 6
		s.content_margin_bottom = 6
	_discussion = PanelContainer.new()
	_discussion.name = "Discussion"
	_discussion.add_theme_stylebox_override("panel", _style_ferme)
	_discussion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_discussion.resized.connect(_placer)
	_racine.add_child(_discussion)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 4)
	colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_discussion.add_child(colonne)
	_historique = RichTextLabel.new()
	_historique.bbcode_enabled = true
	_historique.scroll_following = true
	_historique.custom_minimum_size = Vector2(0, HAUTEUR_DISCUSSION)
	_historique.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_historique.add_theme_font_size_override("normal_font_size", TAILLE_TEXTE)
	_historique.add_theme_font_override("normal_font", Style.police())
	_historique.add_theme_font_size_override("bold_font_size", TAILLE_TEXTE)
	_historique.add_theme_constant_override("outline_size", 4)
	_historique.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_historique.meta_clicked.connect(_sur_nom_clique)
	colonne.add_child(_historique)
	_ligne_saisie = HBoxContainer.new()
	_ligne_saisie.visible = false
	colonne.add_child(_ligne_saisie)
	_etiquette_canal = Label.new()
	_etiquette_canal.add_theme_font_size_override("font_size", TAILLE_TEXTE)
	_ligne_saisie.add_child(_etiquette_canal)
	_saisie = LineEdit.new()
	_saisie.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_saisie.max_length = Social.LONGUEUR_MAX + 40
	_saisie.placeholder_text = "Écris ton message (/aide pour les commandes)"
	_saisie.add_theme_font_size_override("font_size", TAILLE_TEXTE)
	_saisie.text_submitted.connect(_sur_envoi)
	_saisie.text_changed.connect(_sur_frappe)
	_saisie.gui_input.connect(_sur_touche_saisie)
	_ligne_saisie.add_child(_saisie)


func ouvrir_discussion(debut := "") -> void:
	_ligne_saisie.visible = true
	_discussion.add_theme_stylebox_override("panel", _style_ouvert)
	_historique.mouse_filter = Control.MOUSE_FILTER_STOP
	_mettre_a_jour_canal()
	_saisie.text = debut
	_saisie.grab_focus()
	_saisie.caret_column = debut.length()


func fermer_discussion() -> void:
	_saisie.text = ""
	_saisie.release_focus()
	_ligne_saisie.visible = false
	_discussion.add_theme_stylebox_override("panel", _style_ferme)
	_historique.mouse_filter = Control.MOUSE_FILTER_IGNORE


func discussion_ouverte() -> bool:
	return _ligne_saisie.visible


func _mettre_a_jour_canal(canal := "") -> void:
	if canal == "":
		canal = Social.canal_actif
	_etiquette_canal.text = "[%s]" % Social.CANAUX[canal]["nom"]
	_etiquette_canal.add_theme_color_override("font_color", Social.CANAUX[canal]["couleur"])
	_saisie.add_theme_color_override("font_color", Social.CANAUX[canal]["couleur"])


## Pendant la frappe, « /gr » suivi d'un espace change aussitôt la couleur du canal.
func _sur_frappe(texte: String) -> void:
	if texte.begins_with("/") and texte.contains(" "):
		var commande := texte.substr(1).get_slice(" ", 0).to_lower()
		if Social.COMMANDES_CANAUX.has(commande):
			Social.canal_actif = Social.COMMANDES_CANAUX[commande]
			_saisie.text = texte.substr(commande.length() + 2)
			_saisie.caret_column = _saisie.text.length()
			_mettre_a_jour_canal()
			return
		if commande in ["w", "mp", "chuchoter", "r"]:
			_mettre_a_jour_canal("prive")


func _sur_envoi(texte: String) -> void:
	Social.saisir(texte)
	fermer_discussion()


func _sur_touche_saisie(evenement: InputEvent) -> void:
	if evenement is InputEventKey and evenement.pressed and evenement.keycode == KEY_ESCAPE:
		fermer_discussion()
		get_viewport().set_input_as_handled()


func _sur_nom_clique(meta: Variant) -> void:
	ouvrir_discussion("/w %s " % String(meta))


func _sur_message(canal: String, auteur: String, texte: String) -> void:
	_afficher_ligne(canal, auteur, texte)


func _afficher_ligne(canal: String, auteur: String, texte: String) -> void:
	var cle := "prive" if canal == "prive_envoye" else canal
	var couleur: Color = Social.CANAUX.get(cle, Social.CANAUX["systeme"])["couleur"]
	# Le texte des joueurs est affiché tel quel (pas de mise en forme cachée).
	var propre := texte.replace("[", "[lb]")
	var nom := "[url=%s]%s[/url]" % [auteur.replace("[", "").replace("]", ""), auteur.replace("[", "[lb]")]
	var ligne := ""
	match canal:
		"systeme":
			ligne = propre
		"dire":
			ligne = "%s dit : %s" % [nom, propre]
		"prive":
			ligne = "%s chuchote : %s" % [nom, propre]
		"prive_envoye":
			ligne = "À %s : %s" % [nom, propre]
		_:
			ligne = "[%s] %s : %s" % [Social.CANAUX[cle]["nom"], nom, propre]
	_historique.push_color(couleur)
	_historique.append_text(ligne)
	_historique.pop()
	_historique.newline()


# --- Groupe ---------------------------------------------------------------------

func _construire_groupe() -> void:
	_colonne_groupe = VBoxContainer.new()
	_colonne_groupe.name = "Groupe"
	_colonne_groupe.add_theme_constant_override("separation", 4)
	_colonne_groupe.custom_minimum_size.x = 240
	_colonne_groupe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.add_child(_colonne_groupe)
	_titre_groupe = Style.titre_section("Groupe")
	_colonne_groupe.add_child(_titre_groupe)
	_cadres = VBoxContainer.new()
	_cadres.add_theme_constant_override("separation", 4)
	_cadres.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colonne_groupe.add_child(_cadres)
	_boutons_groupe = HBoxContainer.new()
	_boutons_groupe.add_theme_constant_override("separation", 6)
	_colonne_groupe.add_child(_boutons_groupe)
	_boutons_groupe.add_child(_petit_bouton("Quitter le groupe", Social.quitter_le_groupe))
	_boutons_groupe.add_child(_petit_bouton("Donjons (K)", basculer_donjons))
	_bouton_quitter_donjon = _petit_bouton("Quitter le donjon", Social.quitter_le_donjon)
	_colonne_groupe.add_child(_bouton_quitter_donjon)
	_menu_membre = PopupMenu.new()
	_menu_membre.id_pressed.connect(_sur_menu_membre)
	_racine.add_child(_menu_membre)
	# Bouton « Inviter » sous le cadre de la cible (le cadre est en haut, à x = 312).
	_bouton_inviter = _petit_bouton("Inviter dans le groupe", func():
		var cible := _joueur_cible()
		if cible != null:
			Social.inviter(String(cible.get_node("Combat").nom_affiche)))
	_bouton_inviter.position = Vector2(312, 104)
	_bouton_inviter.visible = false
	_racine.add_child(_bouton_inviter)


func _petit_bouton(texte: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = texte
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(action)
	return b


func _rafraichir_groupe() -> void:
	for enfant in _cadres.get_children():
		enfant.free()
	var en_groupe := Social.est_dans_un_groupe()
	_titre_groupe.visible = en_groupe
	_boutons_groupe.visible = en_groupe
	_bouton_quitter_donjon.visible = Reseau.en_instance()
	if not en_groupe:
		return
	_titre_groupe.text = "GROUPE  %d/%d" % [Social.groupe.size(), Social.taille_max_groupe]
	var moi := Social.mon_nom().to_lower()
	for m in Social.groupe:
		if String(m["nom"]).to_lower() == moi:
			continue
		_cadres.add_child(_cadre_membre(m))


func _cadre_membre(m: Dictionary) -> PanelContainer:
	var cadre := PanelContainer.new()
	cadre.custom_minimum_size = Vector2(230, 0)
	var style := Style.boite(Color(0.03, 0.05, 0.08, 0.78), Color(Social.CANAUX["groupe"]["couleur"], 0.35), 1, 6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 5
	cadre.add_theme_stylebox_override("panel", style)
	cadre.mouse_filter = Control.MOUSE_FILTER_STOP
	cadre.set_meta("membre", m)
	cadre.gui_input.connect(_sur_clic_cadre.bind(m))
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 2)
	colonne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(colonne)
	var nom := Label.new()
	var classe := _nom_classe(String(m.get("classe", "")))
	nom.text = ("★ " if bool(m["chef"]) else "") + String(m["nom"]) + ("  · " + classe if classe != "" else "")
	nom.add_theme_font_size_override("font_size", 14)
	nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(nom)
	var barre := ProgressBar.new()
	barre.name = "Vie"
	barre.custom_minimum_size = Vector2(0, 12)
	barre.show_percentage = false
	barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(0, 0, 0, 0.6)
	var plein := StyleBoxFlat.new()
	plein.bg_color = Color(0.2, 0.75, 0.25)
	barre.add_theme_stylebox_override("background", fond)
	barre.add_theme_stylebox_override("fill", plein)
	colonne.add_child(barre)
	var etat := Label.new()
	etat.name = "Etat"
	etat.add_theme_font_size_override("font_size", 11)
	etat.modulate = Color(1, 1, 1, 0.7)
	etat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(etat)
	var e := String(m.get("etat", "ici"))
	if e != "ici":
		cadre.modulate = Color(1, 1, 1, 0.55)
		etat.text = NOMS_ETATS.get(e, e) + (" · " + String(m["donjon"]) if e == "donjon" and String(m.get("donjon", "")) != "" else "")
		barre.visible = false
	return cadre


func _nom_classe(id: String) -> String:
	if id == "":
		return ""
	return String(FichePersonnage.element(Donnees.creation, "classes", id).get("nom", id.capitalize()))


## Personnage d'un membre du groupe sur ce serveur (null s'il est ailleurs).
func _personnage(m: Dictionary) -> Node3D:
	if int(m.get("id", 0)) == 0:
		return null
	for j in get_tree().get_nodes_in_group("joueur"):
		if j.name == str(m["id"]):
			return j as Node3D
	return null


func _sur_clic_cadre(evenement: InputEvent, m: Dictionary) -> void:
	if not (evenement is InputEventMouseButton and evenement.pressed):
		return
	if evenement.button_index == MOUSE_BUTTON_LEFT:
		var p := _personnage(m)
		var local := get_tree().get_first_node_in_group("joueur_local")
		if p != null and local != null:
			local.get_node("CombatJoueur").changer_cible(p.get_node("Combat"))
	elif evenement.button_index == MOUSE_BUTTON_RIGHT:
		_membre_menu = String(m["nom"])
		_menu_membre.clear()
		_menu_membre.add_item("Chuchoter", 0)
		if Social.suis_chef():
			_menu_membre.add_item("Nommer chef du groupe", 1)
			_menu_membre.add_item("Exclure du groupe", 2)
		_menu_membre.position = Vector2i(get_viewport().get_mouse_position())
		_menu_membre.popup()
	get_viewport().set_input_as_handled()


func _sur_menu_membre(id: int) -> void:
	match id:
		0:
			ouvrir_discussion("/w %s " % _membre_menu)
		1:
			Social.nommer_chef(_membre_menu)
		2:
			Social.exclure(_membre_menu)


## Le joueur que l'on cible, si c'est un autre joueur (pour l'inviter).
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


func _process(_delta: float) -> void:
	_placer()
	_placer_bulles()
	# Vie des membres (lue sur leur personnage, que le serveur tient à jour).
	for cadre in _cadres.get_children():
		var m: Dictionary = cadre.get_meta("membre")
		var p := _personnage(m)
		var barre := cadre.find_child("Vie", true, false) as ProgressBar
		var etat := cadre.find_child("Etat", true, false) as Label
		if p == null or barre == null:
			continue
		var c: Combattant = p.get_node("Combat")
		barre.max_value = c.pv_max
		barre.value = c.pv
		var local := get_tree().get_first_node_in_group("joueur_local") as Node3D
		var loin := local != null and local.global_position.distance_to(p.global_position) > Social.PORTEE_BUTIN
		if not c.est_vivant():
			etat.text = "Désynchronisé"
		else:
			etat.text = "%d / %d%s" % [c.pv, c.pv_max, "  · loin" if loin else ""]
	var cible := _joueur_cible()
	_bouton_inviter.visible = cible != null and Reseau.mode != Reseau.Mode.SEUL \
			and not Social.est_membre(String(cible.get_node("Combat").nom_affiche)) \
			and (not Social.est_dans_un_groupe() or Social.suis_chef())


# --- Bulles -----------------------------------------------------------------------------

## Une bulle au-dessus de la tête d'un joueur qui parle (dessinée à l'écran, toujours lisible).
func montrer_bulle(id_joueur: int, texte: String) -> void:
	if _bulles.has(id_joueur):
		_bulles[id_joueur]["panneau"].free()
	var panneau := PanelContainer.new()
	var style := Style.boite(Color(0.97, 0.97, 0.94, 0.92), Color(0, 0, 0, 0.5), 1, 10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 6
	panneau.add_theme_stylebox_override("panel", style)
	panneau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var etiquette := Label.new()
	etiquette.text = texte
	etiquette.add_theme_font_size_override("font_size", 14)
	etiquette.add_theme_color_override("font_color", Color(0.08, 0.09, 0.12))
	etiquette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var largeur := etiquette.get_theme_font("font").get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	if largeur > LARGEUR_BULLE:
		etiquette.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		etiquette.custom_minimum_size.x = LARGEUR_BULLE
	panneau.add_child(etiquette)
	panneau.visible = false
	_calque_bulles.add_child(panneau)
	_bulles[id_joueur] = {"panneau": panneau, "fin": Time.get_ticks_msec() / 1000.0 + DUREE_BULLE + texte.length() * 0.04}


func a_une_bulle(id_joueur: int) -> bool:
	return _bulles.has(id_joueur)


func _placer_bulles() -> void:
	if _bulles.is_empty():
		return
	var camera := get_viewport().get_camera_3d()
	var maintenant := Time.get_ticks_msec() / 1000.0
	for id in _bulles.keys():
		var b: Dictionary = _bulles[id]
		var panneau: PanelContainer = b["panneau"]
		if maintenant > float(b["fin"]):
			panneau.free()
			_bulles.erase(id)
			continue
		var joueur := _personnage({"id": id})
		if joueur == null or camera == null:
			panneau.visible = false
			continue
		var tete := joueur.get_global_transform_interpolated().origin + Vector3.UP * 2.0
		if camera.is_position_behind(tete) or tete.distance_to(camera.global_position) > 60.0:
			panneau.visible = false
			continue
		var p := camera.unproject_position(tete)
		panneau.visible = true
		panneau.reset_size()
		panneau.position = Vector2(p.x - panneau.size.x * 0.5, p.y - panneau.size.y - 18.0)
		panneau.modulate.a = clampf((float(b["fin"]) - maintenant) / 0.6, 0.0, 1.0)


# --- Invitation -------------------------------------------------------------------

func _construire_invitation() -> void:
	_invitation = PanelContainer.new()
	_invitation.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_invitation.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_invitation.position.y = 230
	_invitation.visible = false
	_racine.add_child(_invitation)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 10)
	_invitation.add_child(colonne)
	_texte_invitation = Label.new()
	_texte_invitation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(_texte_invitation)
	var ligne := HBoxContainer.new()
	ligne.alignment = BoxContainer.ALIGNMENT_CENTER
	ligne.add_theme_constant_override("separation", 12)
	colonne.add_child(ligne)
	ligne.add_child(_petit_bouton("Accepter", func(): Social.repondre_invitation(true)))
	ligne.add_child(_petit_bouton("Refuser", func(): Social.repondre_invitation(false)))


func _sur_invitation(de: String) -> void:
	_invitation.visible = de != ""
	_texte_invitation.text = "%s t'invite dans son groupe." % de


# --- Donjons ------------------------------------------------------------------------

func _construire_donjons() -> void:
	_fenetre_donjons = PanelContainer.new()
	_fenetre_donjons.set_anchors_preset(Control.PRESET_CENTER)
	_fenetre_donjons.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_fenetre_donjons.grow_vertical = Control.GROW_DIRECTION_BOTH
	_fenetre_donjons.custom_minimum_size = Vector2(560, 0)
	_fenetre_donjons.visible = false
	_racine.add_child(_fenetre_donjons)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 12)
	_fenetre_donjons.add_child(colonne)
	var titre := Label.new()
	titre.text = "DONJONS · ダンジョン"
	titre.add_theme_font_size_override("font_size", 22)
	titre.add_theme_color_override("font_color", Style.CYAN)
	colonne.add_child(titre)
	var aide := Label.new()
	aide.text = "Chaque groupe entre dans sa propre copie du donjon. Le chef choisit, et tout le groupe part ensemble. Le donjon suit l'avancée du chef dans l'histoire."
	aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aide.custom_minimum_size.x = 520
	aide.add_theme_color_override("font_color", Style.TEXTE_DOUX)
	aide.add_theme_font_size_override("font_size", 14)
	colonne.add_child(aide)
	_liste_donjons = VBoxContainer.new()
	_liste_donjons.add_theme_constant_override("separation", 10)
	colonne.add_child(_liste_donjons)
	var fermer := _petit_bouton("Fermer (K)", basculer_donjons)
	fermer.size_flags_horizontal = Control.SIZE_SHRINK_END
	colonne.add_child(fermer)


func basculer_donjons() -> void:
	_fenetre_donjons.visible = not _fenetre_donjons.visible
	if _fenetre_donjons.visible:
		_remplir_donjons()


func _remplir_donjons() -> void:
	for enfant in _liste_donjons.get_children():
		enfant.free()
	if Reseau.en_instance():
		var l := Label.new()
		l.text = "Tu es dans %s avec ton groupe." % Reseau.nom_instance
		_liste_donjons.add_child(l)
		_liste_donjons.add_child(_petit_bouton("Quitter le donjon (retour au QG de la Vigie)", Social.quitter_le_donjon))
		return
	for d in Social.donjons():
		var carte := VBoxContainer.new()
		carte.add_theme_constant_override("separation", 4)
		_liste_donjons.add_child(carte)
		var nom := Label.new()
		nom.text = "%s   ·   %s   ·   niveau %d" % [d.get("nom", ""), d.get("epoque", ""), int(d.get("niveau", 1))]
		nom.add_theme_font_size_override("font_size", 17)
		carte.add_child(nom)
		var texte := Label.new()
		texte.text = String(d.get("description", ""))
		texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texte.custom_minimum_size.x = 520
		texte.add_theme_font_size_override("font_size", 13)
		texte.add_theme_color_override("font_color", Style.TEXTE_DOUX)
		carte.add_child(texte)
		var presents := 1
		if Social.est_dans_un_groupe():
			presents = Social.groupe.filter(func(m): return String(m.get("etat", "")) == "ici").size()
		var bouton := _petit_bouton("Entrer avec le groupe (%d joueur%s)" % [presents, "s" if presents > 1 else ""] \
				if Social.est_dans_un_groupe() else "Entrer seul", func():
			Social.entrer_en_donjon(String(d["id"]))
			basculer_donjons())
		bouton.disabled = Social.est_dans_un_groupe() and not Social.suis_chef()
		if bouton.disabled:
			bouton.tooltip_text = "Seul le chef du groupe peut choisir le donjon."
		bouton.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		carte.add_child(bouton)


# --- Voyage vers le donjon (fondu) ---------------------------------------------------

func _construire_voile() -> void:
	_voile = ColorRect.new()
	_voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_voile.color = Color(0, 0, 0, 0)
	_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.add_child(_voile)
	_titre_voile = Label.new()
	_titre_voile.set_anchors_preset(Control.PRESET_CENTER)
	_titre_voile.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_titre_voile.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titre_voile.add_theme_font_size_override("font_size", 34)
	_titre_voile.add_theme_color_override("font_color", Style.CYAN)
	_titre_voile.modulate.a = 0.0
	_voile.add_child(_titre_voile)


func _sur_depart_en_donjon(nom_donjon: String) -> void:
	_titre_voile.text = nom_donjon + "\nVoyage avec ton groupe…"
	var anim := create_tween()
	anim.tween_property(_voile, "color:a", 1.0, 1.0)
	anim.parallel().tween_property(_titre_voile, "modulate:a", 1.0, 0.8)


# --- Touches -------------------------------------------------------------------------

func _unhandled_input(evenement: InputEvent) -> void:
	if not (evenement is InputEventKey and evenement.pressed and not evenement.echo):
		return
	if discussion_ouverte():
		return
	var touche := evenement as InputEventKey
	if touche.keycode == KEY_ENTER or touche.keycode == KEY_KP_ENTER:
		ouvrir_discussion()
		get_viewport().set_input_as_handled()
	elif touche.unicode == "/".unicode_at(0):
		ouvrir_discussion("/")
		get_viewport().set_input_as_handled()
	elif touche.keycode == KEY_K:
		basculer_donjons()
		get_viewport().set_input_as_handled()
	elif touche.keycode == KEY_ESCAPE and _fenetre_donjons.visible:
		basculer_donjons()
		get_viewport().set_input_as_handled()
