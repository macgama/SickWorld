extends PanelContainer
## Écran « Personnage » (touches C, I ou B) : équipement porté, caractéristiques,
## compétences d'époque, tenues de mission et contenu des sacs.
##
## Clic gauche sur un objet des sacs : l'équiper (ou accrocher le sac).
## Clic droit sur un objet des sacs : le jeter (avec confirmation).
## Clic sur un emplacement d'équipement : retirer l'objet.
## Rien n'est décidé ici : chaque clic envoie une demande au serveur (voir Inventaire).

const TAILLE_CASE := 58
const COLONNES_SAC := 8

var inventaire: Node
var combat_joueur: CombatJoueur

var _emplacements := {}
var _sacs_portes: Array[Button] = []
var _grille: GridContainer
var _titre_sacs: Label
var _stats: RichTextLabel
var _choix_competences := {}
var _tenues: Array[Dictionary] = []
var _confirmation: ConfirmationDialog
var _a_jeter := -1


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.1, 0.94)
	style.border_color = Color(0.25, 0.85, 0.9, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	add_theme_stylebox_override("panel", style)

	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 10)
	add_child(colonne)

	var haut := HBoxContainer.new()
	colonne.add_child(haut)
	var titre := _texte("Personnage", 20)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haut.add_child(titre)
	var aide := _texte("Clic : équiper / retirer     Clic droit : jeter     C, I ou Échap : fermer", 12)
	aide.modulate.a = 0.6
	haut.add_child(aide)
	var fermer := Button.new()
	fermer.text = "  ✕  "
	fermer.focus_mode = Control.FOCUS_NONE
	fermer.pressed.connect(func(): visible = false)
	haut.add_child(fermer)

	var corps := HBoxContainer.new()
	corps.add_theme_constant_override("separation", 18)
	colonne.add_child(corps)
	corps.add_child(_construire_equipement())
	corps.add_child(_construire_milieu())
	corps.add_child(_construire_sacs())

	_confirmation = ConfirmationDialog.new()
	_confirmation.title = "Jeter l'objet"
	_confirmation.ok_button_text = "Jeter"
	_confirmation.cancel_button_text = "Garder"
	_confirmation.confirmed.connect(func(): if _a_jeter >= 0: inventaire.jeter(_a_jeter))
	add_child(_confirmation)


func relier(inv: Node, cj: CombatJoueur) -> void:
	inventaire = inv
	combat_joueur = cj
	inventaire.change.connect(rafraichir)
	rafraichir()


func basculer() -> void:
	visible = not visible
	if visible:
		rafraichir()
		_centrer.call_deferred()


func _centrer() -> void:
	reset_size()
	position = ((get_viewport_rect().size - size) / 2.0).floor()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("annuler"):
		visible = false
		get_viewport().set_input_as_handled()


# --- Construction -----------------------------------------------------------

func _texte(contenu: String, taille := 14) -> Label:
	var l := Label.new()
	l.text = contenu
	l.add_theme_font_size_override("font_size", taille)
	return l


func _section(contenu: String) -> Label:
	var l := _texte(contenu, 15)
	l.modulate = Color(0.55, 0.9, 0.95)
	return l


func _construire_equipement() -> Control:
	var boite := VBoxContainer.new()
	boite.add_theme_constant_override("separation", 6)
	boite.add_child(_section("Équipement porté"))
	var grille := GridContainer.new()
	grille.columns = 2
	grille.add_theme_constant_override("h_separation", 6)
	grille.add_theme_constant_override("v_separation", 6)
	boite.add_child(grille)
	for e in Objets.EMPLACEMENTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(190, 46)
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(func(): if inventaire: inventaire.retirer(e))
		grille.add_child(b)
		_emplacements[e] = b
	boite.add_child(_section("Sacs portés"))
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 6)
	boite.add_child(ligne)
	for i in 4:
		var b := Button.new()
		b.custom_minimum_size = Vector2(83, 40)
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 10)
		b.pressed.connect(func(): if inventaire: inventaire.decrocher_sac(i))
		ligne.add_child(b)
		_sacs_portes.append(b)
	return boite


func _construire_milieu() -> Control:
	var boite := VBoxContainer.new()
	boite.add_theme_constant_override("separation", 6)
	boite.custom_minimum_size.x = 300
	boite.add_child(_section("Caractéristiques"))
	_stats = RichTextLabel.new()
	_stats.bbcode_enabled = true
	_stats.fit_content = true
	_stats.scroll_active = false
	_stats.custom_minimum_size = Vector2(300, 120)
	_stats.add_theme_font_size_override("normal_font_size", 13)
	_stats.add_theme_font_size_override("bold_font_size", 13)
	boite.add_child(_stats)

	boite.add_child(_section("Compétences d'époque"))
	for index in Objets.CASES_EPOQUE + [Objets.CASE_ULTIME]:
		var ligne := HBoxContainer.new()
		var etiquette := _texte("Touche %d%s" % [index + 1, " (ultime)" if index == Objets.CASE_ULTIME else ""], 13)
		etiquette.custom_minimum_size.x = 115
		ligne.add_child(etiquette)
		var choix := OptionButton.new()
		choix.focus_mode = Control.FOCUS_NONE
		choix.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var liste: Array = Donnees.objets.get("ultimes" if index == Objets.CASE_ULTIME else "competences_d_epoque", [])
		for id in liste:
			choix.add_item(String(Donnees.competence(String(id)).get("nom", id)))
			choix.set_item_metadata(choix.item_count - 1, String(id))
			choix.set_item_tooltip(choix.item_count - 1, String(Donnees.competence(String(id)).get("description", "")))
		choix.item_selected.connect(func(i): if inventaire: inventaire.changer_competence(index, String(choix.get_item_metadata(i))))
		ligne.add_child(choix)
		boite.add_child(ligne)
		_choix_competences[index] = choix

	boite.add_child(_section("Tenues de mission"))
	var note := _texte("« Enregistrer » retient l'équipement et la barre actuels.\n« Mettre » change de tenue (hors combat, 2 s sans bouger).", 11)
	note.modulate.a = 0.65
	boite.add_child(note)
	for i in int(Objets.reglage(Donnees.objets, "tenues_max", 4)):
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", 4)
		var nom := LineEdit.new()
		nom.placeholder_text = "Tenue %d (vide)" % (i + 1)
		nom.max_length = 24
		nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nom.text_submitted.connect(func(_t): nom.release_focus())
		ligne.add_child(nom)
		var mettre := Button.new()
		mettre.text = "Mettre"
		mettre.focus_mode = Control.FOCUS_NONE
		mettre.pressed.connect(func(): if inventaire: inventaire.mettre_tenue(i))
		ligne.add_child(mettre)
		var enregistrer := Button.new()
		enregistrer.text = "Enregistrer"
		enregistrer.focus_mode = Control.FOCUS_NONE
		enregistrer.pressed.connect(func():
			nom.release_focus()
			if inventaire: inventaire.enregistrer_tenue(i, nom.text))
		ligne.add_child(enregistrer)
		boite.add_child(ligne)
		_tenues.append({"nom": nom, "mettre": mettre})
	return boite


func _construire_sacs() -> Control:
	var boite := VBoxContainer.new()
	boite.add_theme_constant_override("separation", 6)
	var haut := HBoxContainer.new()
	_titre_sacs = _section("Sacs")
	_titre_sacs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haut.add_child(_titre_sacs)
	var ranger := Button.new()
	ranger.text = "Ranger"
	ranger.focus_mode = Control.FOCUS_NONE
	ranger.pressed.connect(func(): if inventaire: inventaire.ranger())
	haut.add_child(ranger)
	boite.add_child(haut)
	var defilement := ScrollContainer.new()
	defilement.custom_minimum_size = Vector2(COLONNES_SAC * (TAILLE_CASE + 4) + 12, 5 * (TAILLE_CASE + 4))
	defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	boite.add_child(defilement)
	_grille = GridContainer.new()
	_grille.columns = COLONNES_SAC
	_grille.add_theme_constant_override("h_separation", 4)
	_grille.add_theme_constant_override("v_separation", 4)
	defilement.add_child(_grille)
	return boite


func _style_case(couleur: Color, vide: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.12, 0.15, 0.9) if not vide else Color(0.08, 0.09, 0.11, 0.6)
	s.border_color = couleur if not vide else Color(1, 1, 1, 0.08)
	s.set_border_width_all(2 if not vide else 1)
	s.set_corner_radius_all(5)
	s.set_content_margin_all(3)
	return s


func _habiller_bouton(b: Button, id: String, vide_texte: String) -> void:
	var cat := Donnees.objets
	var couleur := Objets.couleur_rarete(cat, id) if id != "" else Color(1, 1, 1, 0.35)
	b.add_theme_stylebox_override("normal", _style_case(couleur, id == ""))
	var survol := _style_case(couleur.lightened(0.3), id == "")
	survol.bg_color = survol.bg_color.lightened(0.12)
	b.add_theme_stylebox_override("hover", survol)
	b.add_theme_stylebox_override("pressed", survol)
	b.add_theme_color_override("font_color", couleur)
	b.add_theme_color_override("font_hover_color", couleur.lightened(0.2))
	b.tooltip_text = Objets.description(cat, id) if id != "" else vide_texte


# --- Mise à jour ----------------------------------------------------------------

func rafraichir() -> void:
	if inventaire == null or inventaire.etat.is_empty() or not is_inside_tree():
		return
	var cat := Donnees.objets
	var etat: Dictionary = inventaire.etat

	for e in Objets.EMPLACEMENTS:
		var id := String(etat["equipement"].get(e, ""))
		var b := _emplacements[e] as Button
		var nom := String(Objets.objet(cat, id).get("nom", ""))
		b.text = "%s\n%s" % [Objets.NOMS_EMPLACEMENTS[e], nom if nom != "" else "—"]
		_habiller_bouton(b, id, Objets.NOMS_EMPLACEMENTS[e] + " : vide")

	for i in _sacs_portes.size():
		var id := String(etat["sacs"][i]) if i < etat["sacs"].size() else ""
		var o := Objets.objet(cat, id)
		_sacs_portes[i].text = ("%s\n+%d places" % [o.get("nom", ""), int(o.get("places", 0))]) if id != "" else "Pas de sac"
		_habiller_bouton(_sacs_portes[i], id, "Emplacement de sac libre : clique sur un sac dans tes sacs pour l'accrocher.")

	var cases: Array = etat["cases"]
	while _grille.get_child_count() < cases.size():
		_grille.add_child(_creer_case(_grille.get_child_count()))
	while _grille.get_child_count() > cases.size():
		var dernier := _grille.get_child(_grille.get_child_count() - 1)
		_grille.remove_child(dernier)
		dernier.queue_free()
	for i in cases.size():
		var c: Dictionary = cases[i]
		var b := _grille.get_child(i) as Button
		var id := String(c.get("id", ""))
		var nom := String(Objets.objet(cat, id).get("nom", ""))
		b.text = _abreger(nom) + (("\nx%d" % int(c["n"])) if int(c.get("n", 1)) > 1 else "")
		_habiller_bouton(b, id, "")
	_titre_sacs.text = "Sacs  (%d / %d places)" % [cases.size() - Objets.places_libres(etat), cases.size()]

	# Caractéristiques
	var bonus: Dictionary = inventaire.bonus
	var s: Dictionary = bonus.get("stats", {})
	var lignes: Array[String] = []
	lignes.append("[b]Points de vie[/b] : %d  (%+d grâce à l'équipement)" % [
			float(Donnees.joueur.get("points_de_vie", 200)) + float(s.get("pv", 0)), int(s.get("pv", 0))])
	lignes.append("[b]Dégâts[/b] : %+d %%" % int(s.get("degats_pourcent", 0)))
	lignes.append("[b]Protection[/b] : %d %% de dégâts en moins" % int(s.get("reduction_pourcent", 0)))
	lignes.append("[b]Coups critiques[/b] : %d %% de chances" % (10 + int(s.get("critique_pourcent", 0))))
	var paliers: Array = bonus.get("paliers", [])
	var ensembles: Dictionary = bonus.get("ensembles", {})
	for id in ensembles:
		var ens: Dictionary = (cat.get("ensembles", {}) as Dictionary).get(id, {})
		lignes.append("[color=#3ec94a]Ensemble %s : %d / 5 pièces[/color]" % [ens.get("nom", id), int(ensembles[id])])
	for p in paliers:
		lignes.append("[color=#ffd36b]  ✓ %s[/color]" % p)
	for e in ["relique"]:
		var o := Objets.objet(cat, String(etat["equipement"].get(e, "")))
		if not o.is_empty():
			lignes.append("[color=#3d8eff]Relique : %s[/color]" % o.get("nom", ""))
	_stats.text = "\n".join(lignes)

	# Compétences d'époque
	var barre: Array = etat.get("barre", [])
	for index in _choix_competences:
		var choix := _choix_competences[index] as OptionButton
		for k in choix.item_count:
			if index < barre.size() and String(choix.get_item_metadata(k)) == String(barre[index]):
				choix.select(k)

	# Tenues
	var portee: int = inventaire.tenue_portee()
	var tenues: Array = etat.get("tenues", [])
	for i in _tenues.size():
		var t: Dictionary = tenues[i] if i < tenues.size() else {}
		var nom := _tenues[i]["nom"] as LineEdit
		if not nom.has_focus():
			nom.text = String(t.get("nom", ""))
		var mettre := _tenues[i]["mettre"] as Button
		mettre.disabled = t.is_empty() or i == portee
		mettre.text = "Portée ✓" if i == portee else "Mettre"


func _creer_case(index: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(TAILLE_CASE, TAILLE_CASE)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 9)
	b.pressed.connect(func(): if inventaire: inventaire.utiliser(index))
	b.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
			_proposer_de_jeter(index))
	return b


func _proposer_de_jeter(index: int) -> void:
	var cases: Array = inventaire.etat.get("cases", [])
	if index >= cases.size() or (cases[index] as Dictionary).is_empty():
		return
	_a_jeter = index
	var nom := String(Objets.objet(Donnees.objets, String(cases[index]["id"])).get("nom", ""))
	_confirmation.dialog_text = "Jeter « %s » ? Il sera perdu pour toujours." % nom
	_confirmation.popup_centered()


## Nom court pour une case de sac (les 3 premiers mots importants).
func _abreger(nom: String) -> String:
	var mots := nom.split(" ")
	var garde: Array[String] = []
	for m in mots:
		if m.length() <= 3 and not garde.is_empty():
			continue
		garde.append(m)
		if garde.size() == 3:
			break
	return " ".join(garde)
