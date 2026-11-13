extends CanvasLayer
## Interface affichée par-dessus le jeu :
## cadre du joueur, cadre de la cible, barre de compétences, barre d'incantation,
## endurance, noms au-dessus des ennemis, messages d'erreur, écran de désynchronisation.

const TEXTE_AIDE := """[b]Contrôles[/b]  (F1 pour cacher)
[b]Z Q S D[/b] / [b]W A S D[/b] : se déplacer     [b]A / E[/b] : pas de côté
[b]Clic droit maintenu[/b] : orienter le personnage
[b]Clic gauche maintenu[/b] : tourner la caméra     [b]Molette[/b] : zoom
[b]Espace[/b] : sauter     [b]Maj[/b] : roulade d'esquive
[b]Tab[/b] ou [b]clic[/b] sur un ennemi : le cibler     [b]Échap[/b] : enlever la cible
[b]Clic droit[/b] sur un ennemi : l'attaquer
[b]1 à 8[/b] : compétences (survole une case pour lire sa description)
[b]C[/b], [b]I[/b] ou [b]B[/b] : personnage, sacs et tenues     [b]F[/b] : ramasser le butin"""

const TAILLE_CASE := 70
const NOMS_EFFETS := {
	"saignement": "Saignement", "ralenti": "Ralenti", "desynchronisation": "Désynchronisé (-10 %)",
	"cri_du_clan": "Cri du clan (+15 % dégâts)", "peinture_de_guerre": "Peinture de guerre (-30 % dégâts subis)",
}

var _joueur: Joueur
var _combat: Combattant
var _combat_joueur: CombatJoueur

var _racine: Control
var _aide: PanelContainer
var _images: Label
var _endurance: ProgressBar
var _pv_joueur: ProgressBar
var _texte_pv_joueur: Label
var _elan: ProgressBar
var _effets_joueur: Label
var _nom_joueur: Label
var _statut: Label
var _cadre_cible: PanelContainer
var _nom_cible: Label
var _pv_cible: ProgressBar
var _texte_pv_cible: Label
var _effets_cible: Label
var _incantation: ProgressBar
var _texte_incantation: Label
var _message: Label
var _message_fin := 0.0
var _ecran_mort: PanelContainer
var _cases: Array[Dictionary] = []
var _plaques: Control
var _fenetre_personnage: PanelContainer


func _ready() -> void:
	_racine = Control.new()
	_racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	_racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_racine)

	_plaques = Control.new()
	_plaques.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plaques.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plaques.draw.connect(_dessiner_plaques)
	_racine.add_child(_plaques)

	_construire_cadre_joueur()
	_construire_cadre_cible()
	_construire_aide()
	_construire_barre()
	_construire_messages()
	_construire_ecran_mort()

	_images = Label.new()
	_images.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_images.position = Vector2(-110, 8)
	_images.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_images.modulate.a = 0.6
	_racine.add_child(_images)

	_statut = Label.new()
	_statut.set_anchors_preset(Control.PRESET_CENTER)
	_statut.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_statut.add_theme_font_size_override("font_size", 22)
	_statut.text = "Connexion au serveur…"
	_racine.add_child(_statut)
	Reseau.statut_change.connect(func(t): _statut.text = t)

	_connecter.call_deferred()


func _connecter() -> void:
	_joueur = get_tree().get_first_node_in_group("joueur_local") as Joueur
	if _joueur == null:
		# Le personnage n'est pas encore arrivé du serveur : on réessaie un peu plus tard.
		if is_inside_tree():
			get_tree().create_timer(0.2).timeout.connect(_connecter)
		return
	_combat = _joueur.get_node("Combat")
	_combat_joueur = _joueur.get_node("CombatJoueur")
	_combat_joueur.message.connect(_afficher_message)
	_combat_joueur.incantation_changee.connect(_sur_incantation)
	_combat_joueur.barre_changee.connect(_rafraichir_barre)
	_rafraichir_barre()
	_fenetre_personnage = preload("res://scripts/interface/fenetre_personnage.gd").new()
	_racine.add_child(_fenetre_personnage)
	_fenetre_personnage.relier(_joueur.get_node("Inventaire"), _combat_joueur)


## Écran Personnage (touches C, I ou B).
func basculer_personnage() -> void:
	if _fenetre_personnage != null:
		_fenetre_personnage.basculer()


## Noms, descriptions et couleurs des cases de la barre (rappelé quand on change de tenue).
func _rafraichir_barre() -> void:
	if _combat_joueur == null:
		return
	for i in _cases.size():
		var c := _combat_joueur.competence(i)
		var case: Dictionary = _cases[i]
		(case["nom"] as Label).text = String(c.get("nom", ""))
		var bouton := case["bouton"] as Button
		bouton.tooltip_text = "%s  (%s)\n%s%s" % [c.get("nom", ""), c.get("origine", ""),
				c.get("description", ""), _details(c)]
		var style := StyleBoxFlat.new()
		style.bg_color = Color.html(String(c.get("couleur", "#444444"))).darkened(0.25)
		style.border_color = Color(0, 0, 0, 0.8)
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		bouton.add_theme_stylebox_override("normal", style)
		var survol := style.duplicate() as StyleBoxFlat
		survol.bg_color = survol.bg_color.lightened(0.15)
		survol.border_color = Color(1, 1, 1, 0.8)
		bouton.add_theme_stylebox_override("hover", survol)
		bouton.add_theme_stylebox_override("pressed", survol)


func _details(c: Dictionary) -> String:
	var lignes: Array[String] = []
	if c.has("portee"):
		lignes.append("Portée : %s m" % c["portee"])
	if c.has("incantation"):
		lignes.append("Préparation : %s s" % c["incantation"])
	if float(c.get("recharge", 0)) > 0.0:
		lignes.append("Recharge : %s s" % c["recharge"])
	if c.has("cout_elan"):
		lignes.append("Coût : %s Élan" % c["cout_elan"])
	if lignes.is_empty():
		return ""
	return "\n\n" + "\n".join(lignes)


# --- Construction -----------------------------------------------------------

func _fond(couleur := Color(0.04, 0.06, 0.09, 0.75)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = couleur
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	return style


func _jauge(couleur: Color, hauteur: float) -> ProgressBar:
	var barre := ProgressBar.new()
	barre.show_percentage = false
	barre.custom_minimum_size = Vector2(0, hauteur)
	barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plein := StyleBoxFlat.new()
	plein.bg_color = couleur
	plein.set_corner_radius_all(3)
	var vide := StyleBoxFlat.new()
	vide.bg_color = Color(0, 0, 0, 0.6)
	vide.set_corner_radius_all(3)
	barre.add_theme_stylebox_override("fill", plein)
	barre.add_theme_stylebox_override("background", vide)
	return barre


func _texte_sur(barre: ProgressBar) -> Label:
	var etiquette := Label.new()
	etiquette.set_anchors_preset(Control.PRESET_FULL_RECT)
	etiquette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiquette.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiquette.add_theme_font_size_override("font_size", 13)
	etiquette.add_theme_constant_override("outline_size", 4)
	etiquette.add_theme_color_override("font_outline_color", Color.BLACK)
	barre.add_child(etiquette)
	return etiquette


func _petit_texte(taille := 13) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", taille)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _construire_cadre_joueur() -> void:
	var cadre := PanelContainer.new()
	cadre.add_theme_stylebox_override("panel", _fond())
	cadre.position = Vector2(16, 16)
	cadre.custom_minimum_size = Vector2(280, 0)
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.add_child(cadre)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 4)
	cadre.add_child(colonne)
	_nom_joueur = _petit_texte(15)
	colonne.add_child(_nom_joueur)
	_pv_joueur = _jauge(Color(0.2, 0.75, 0.25), 20)
	_texte_pv_joueur = _texte_sur(_pv_joueur)
	colonne.add_child(_pv_joueur)
	_elan = _jauge(Color(0.95, 0.55, 0.1), 10)
	colonne.add_child(_elan)
	_effets_joueur = _petit_texte(12)
	_effets_joueur.modulate = Color(1, 0.85, 0.6)
	colonne.add_child(_effets_joueur)


func _construire_cadre_cible() -> void:
	_cadre_cible = PanelContainer.new()
	_cadre_cible.add_theme_stylebox_override("panel", _fond())
	_cadre_cible.position = Vector2(312, 16)
	_cadre_cible.custom_minimum_size = Vector2(280, 0)
	_cadre_cible.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cadre_cible.visible = false
	_racine.add_child(_cadre_cible)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 4)
	_cadre_cible.add_child(colonne)
	_nom_cible = _petit_texte(15)
	colonne.add_child(_nom_cible)
	_pv_cible = _jauge(Color(0.8, 0.15, 0.12), 20)
	_texte_pv_cible = _texte_sur(_pv_cible)
	colonne.add_child(_pv_cible)
	_effets_cible = _petit_texte(12)
	_effets_cible.modulate = Color(1, 0.85, 0.6)
	colonne.add_child(_effets_cible)


func _construire_aide() -> void:
	_aide = PanelContainer.new()
	_aide.add_theme_stylebox_override("panel", _fond())
	_aide.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_aide.position = Vector2(-500, 40)
	_aide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.add_child(_aide)
	var texte := RichTextLabel.new()
	texte.bbcode_enabled = true
	texte.fit_content = true
	texte.custom_minimum_size = Vector2(470, 0)
	texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texte.add_theme_font_size_override("normal_font_size", 14)
	texte.add_theme_font_size_override("bold_font_size", 14)
	texte.text = TEXTE_AIDE
	_aide.add_child(texte)


func _construire_barre() -> void:
	var bas := VBoxContainer.new()
	bas.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bas.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bas.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bas.position.y = -16
	bas.alignment = BoxContainer.ALIGNMENT_END
	bas.add_theme_constant_override("separation", 8)
	bas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.add_child(bas)

	_incantation = _jauge(Color(0.95, 0.8, 0.3), 18)
	_incantation.custom_minimum_size.x = 300
	_incantation.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_incantation.visible = false
	_texte_incantation = _texte_sur(_incantation)
	bas.add_child(_incantation)

	_endurance = _jauge(Color(0.95, 0.75, 0.25), 8)
	_endurance.custom_minimum_size.x = 220
	_endurance.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bas.add_child(_endurance)

	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 6)
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bas.add_child(ligne)
	for i in 8:
		if i == 5 or i == 7:
			var espace := Control.new()
			espace.custom_minimum_size = Vector2(10, 0)
			espace.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ligne.add_child(espace)
		ligne.add_child(_construire_case(i))


func _construire_case(index: int) -> Control:
	var bouton := Button.new()
	bouton.custom_minimum_size = Vector2(TAILLE_CASE, TAILLE_CASE)
	bouton.focus_mode = Control.FOCUS_NONE
	bouton.pressed.connect(func(): if _combat_joueur: _combat_joueur.utiliser(index))

	var nom := _petit_texte(10)
	nom.set_anchors_preset(Control.PRESET_FULL_RECT)
	nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nom.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nom.add_theme_constant_override("outline_size", 3)
	nom.add_theme_color_override("font_outline_color", Color.BLACK)
	bouton.add_child(nom)

	var voile := ColorRect.new()
	voile.color = Color(0, 0, 0, 0.65)
	voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	voile.anchor_right = 1.0
	voile.anchor_bottom = 1.0
	bouton.add_child(voile)

	var compte := _petit_texte(20)
	compte.set_anchors_preset(Control.PRESET_FULL_RECT)
	compte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compte.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	compte.add_theme_constant_override("outline_size", 4)
	compte.add_theme_color_override("font_outline_color", Color.BLACK)
	bouton.add_child(compte)

	var touche := _petit_texte(12)
	touche.text = str(index + 1)
	touche.position = Vector2(4, 1)
	touche.add_theme_constant_override("outline_size", 3)
	touche.add_theme_color_override("font_outline_color", Color.BLACK)
	bouton.add_child(touche)

	_cases.append({"bouton": bouton, "nom": nom, "voile": voile, "compte": compte})
	return bouton


func _construire_messages() -> void:
	_message = Label.new()
	_message.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message.position.y = 120
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 20)
	_message.add_theme_color_override("font_color", Color(1, 0.3, 0.25))
	_message.add_theme_constant_override("outline_size", 5)
	_message.add_theme_color_override("font_outline_color", Color.BLACK)
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_racine.add_child(_message)


func _construire_ecran_mort() -> void:
	_ecran_mort = PanelContainer.new()
	_ecran_mort.add_theme_stylebox_override("panel", _fond(Color(0.02, 0.05, 0.08, 0.85)))
	_ecran_mort.set_anchors_preset(Control.PRESET_CENTER)
	_ecran_mort.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ecran_mort.grow_vertical = Control.GROW_DIRECTION_BOTH
	_ecran_mort.visible = false
	_racine.add_child(_ecran_mort)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 12)
	_ecran_mort.add_child(colonne)
	var titre := Label.new()
	titre.text = "Tu es désynchronisé"
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_font_size_override("font_size", 26)
	titre.add_theme_color_override("font_color", Color(0.4, 0.9, 0.95))
	colonne.add_child(titre)
	var texte := Label.new()
	texte.text = "Ton lien avec cette époque s'est rompu.\nRetourne à la balise de la Vigie pour te resynchroniser\n(-10 % de dégâts pendant 2 minutes)."
	texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(texte)
	var bouton := Button.new()
	bouton.text = "Retourner à la balise"
	bouton.focus_mode = Control.FOCUS_NONE
	bouton.custom_minimum_size = Vector2(0, 40)
	bouton.pressed.connect(func(): _combat_joueur.reapparaitre())
	colonne.add_child(bouton)


# --- Mise à jour -------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("aide"):
		_aide.visible = not _aide.visible
	elif event.is_action_pressed("personnage") and not event.is_echo():
		basculer_personnage()
		get_viewport().set_input_as_handled()


func _afficher_message(texte: String) -> void:
	_message.text = texte
	_message_fin = Regles.maintenant() + 1.5


func _sur_incantation(nom: String, progression: float) -> void:
	_incantation.visible = progression >= 0.0
	_incantation.max_value = 1.0
	_incantation.value = progression
	_texte_incantation.text = nom


func _noms_effets(c: Combattant) -> String:
	var noms: Array[String] = []
	var t := Regles.maintenant()
	for id in c.effets:
		if id == "evite":
			continue
		noms.append("%s %ds" % [NOMS_EFFETS.get(id, String(id).capitalize()), int(ceil(float(c.effets[id]["fin"]) - t))])
	return "  ".join(noms)


func _process(_delta: float) -> void:
	_images.text = "%d images/s" % Engine.get_frames_per_second()
	_message.visible = Regles.maintenant() < _message_fin
	if _joueur == null or not is_instance_valid(_joueur):
		_statut.visible = Reseau.a_un_joueur_local()
		return
	_statut.visible = false
	_nom_joueur.text = "%s — %s niv. %d" % [_combat.nom_affiche, _joueur.nom_classe(), _combat.niveau]
	_ecran_mort.visible = not _combat.est_vivant()

	_endurance.max_value = _joueur.endurance_max
	_endurance.value = _joueur.endurance
	_endurance.modulate.a = 0.3 if _joueur.endurance >= _joueur.endurance_max else 1.0

	_pv_joueur.max_value = _combat.pv_max
	_pv_joueur.value = _combat.pv
	_texte_pv_joueur.text = "%d / %d" % [_combat.pv, _combat.pv_max]
	_elan.max_value = _combat_joueur.elan_max
	_elan.value = _combat_joueur.elan
	_effets_joueur.text = _noms_effets(_combat)

	var cible := _combat_joueur.cible
	_cadre_cible.visible = cible != null
	if cible != null:
		_nom_cible.text = "%s  niv. %d" % [cible.nom_affiche, cible.niveau]
		_nom_cible.modulate = Color(1, 0.5, 0.45) if _combat.est_hostile(cible) else Color(0.5, 1, 0.55)
		_pv_cible.max_value = cible.pv_max
		_pv_cible.value = cible.pv
		_texte_pv_cible.text = "%d / %d  (%d %%)" % [cible.pv, cible.pv_max, cible.pourcentage_pv()]
		_effets_cible.text = _noms_effets(cible)

	for i in _cases.size():
		var case: Dictionary = _cases[i]
		var recharge := _combat_joueur.recharge_restante(i)
		var voile := case["voile"] as ColorRect
		voile.visible = recharge.x > 0.0
		if recharge.y > 0.0:
			voile.anchor_top = 1.0 - recharge.x / recharge.y
		(case["compte"] as Label).text = str(int(ceil(recharge.x))) if recharge.x > 1.5 else ""
		var raison := _combat_joueur.raison_impossible(i)
		var bouton := case["bouton"] as Button
		if raison == "Hors de portée" or raison == "Trop près" or raison == "Cible non visible":
			bouton.modulate = Color(1, 0.45, 0.45)
		elif raison == "Pas assez d'Élan" or raison == "La cible a encore trop de vie":
			bouton.modulate = Color(0.5, 0.5, 0.7)
		else:
			bouton.modulate = Color.WHITE

	_plaques.queue_redraw()


## Nom et barre de vie au-dessus des combattants proches (comme les « plaques » de WoW).
func _dessiner_plaques() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or _combat == null:
		return
	var police := ThemeDB.fallback_font
	for acteur in get_tree().get_nodes_in_group("combattants"):
		if acteur == _joueur:
			continue
		var c := acteur.get_node_or_null("Combat") as Combattant
		if c == null:
			continue
		var position_tete: Vector3 = acteur.get_global_transform_interpolated().origin + Vector3.UP * 1.5
		if camera.is_position_behind(position_tete) or position_tete.distance_to(camera.global_position) > 40.0:
			continue
		var p := camera.unproject_position(position_tete)
		var hostile := _combat.est_hostile(c)
		var couleur := Color(1, 0.4, 0.35) if hostile else Color(0.45, 1, 0.5)
		if not c.est_vivant():
			couleur = Color(0.6, 0.6, 0.6)
		var nom := c.nom_affiche
		var largeur_texte := police.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		_plaques.draw_string_outline(police, p + Vector2(-largeur_texte / 2.0, -8), nom,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
		_plaques.draw_string(police, p + Vector2(-largeur_texte / 2.0, -8), nom,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, couleur)
		if c.est_vivant() and (c.pv < c.pv_max or c == _combat_joueur.cible):
			var cadre := Rect2(p + Vector2(-40, -2), Vector2(80, 7))
			_plaques.draw_rect(cadre.grow(1), Color(0, 0, 0, 0.8))
			_plaques.draw_rect(Rect2(cadre.position, Vector2(80 * c.pv / c.pv_max, 7)),
					couleur.darkened(0.2))
		if c == _combat_joueur.cible:
			_plaques.draw_rect(Rect2(p + Vector2(-44, -26), Vector2(88, 36)), Color(1, 1, 0.6, 0.6), false, 1.5)
