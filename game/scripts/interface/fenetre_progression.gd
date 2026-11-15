extends PanelContainer
## Fenêtre « Talents et titres » (touche N).
##
## Onglet Talents : les 3 voies de la classe, 4 talents chacune (paliers 1 à 4).
## Un clic sur un talent y met un point (un point par niveau à partir du niveau 2).
## Un palier s'ouvre quand on a assez de points dans la même voie (3, 6 puis 8).
## « Oublier mes talents » rend tous les points, gratuitement (hors combat).
##
## Onglet Arène : les 6 talents d'Arène de la classe ; on en choisit 3 (un clic pour
## choisir, un autre pour retirer). Ils ne servent que pendant un combat d'Arène, où les
## talents normaux, l'équipement et le repas sont ignorés.
##
## Onglet Titres : tous les titres des époques ; un clic sur un titre obtenu le porte
## (il s'affiche sous le nom du personnage, pour tout le monde).
##
## Rien n'est décidé ici : chaque clic envoie une demande au serveur (voir ProgressionJoueur).

const LARGEUR_TALENT := 318

var progression: Node

var _entete: Label
var _points: Label
var _onglets: TabContainer
var _voies: HBoxContainer
var _titres: VBoxContainer
var _arene_entete: Label
var _arene_grille: GridContainer
var _oublier: Button
var _confirmation: ConfirmationDialog


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.1, 0.985)
	style.border_color = Color(0.85, 0.7, 0.3, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	add_theme_stylebox_override("panel", style)

	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 10)
	add_child(colonne)

	var haut := HBoxContainer.new()
	haut.add_theme_constant_override("separation", 16)
	colonne.add_child(haut)
	var titre := _texte("Talents et titres", 20)
	haut.add_child(titre)
	_entete = _texte("", 15)
	_entete.modulate = Color(0.75, 0.85, 0.9)
	_entete.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haut.add_child(_entete)
	var aide := _texte("N ou Échap : fermer", 12)
	aide.modulate.a = 0.6
	haut.add_child(aide)
	var fermer := Button.new()
	fermer.text = "  ✕  "
	fermer.focus_mode = Control.FOCUS_NONE
	fermer.pressed.connect(func(): visible = false)
	haut.add_child(fermer)

	_onglets = TabContainer.new()
	_onglets.custom_minimum_size = Vector2(3 * LARGEUR_TALENT + 80, 600)
	colonne.add_child(_onglets)

	# --- Onglet Talents
	var talents := VBoxContainer.new()
	talents.name = "Talents"
	talents.add_theme_constant_override("separation", 10)
	_onglets.add_child(talents)
	var ligne_points := HBoxContainer.new()
	talents.add_child(ligne_points)
	_points = _texte("", 15)
	_points.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ligne_points.add_child(_points)
	_oublier = Button.new()
	_oublier.text = "Oublier mes talents"
	_oublier.focus_mode = Control.FOCUS_NONE
	_oublier.tooltip_text = "Rend tous tes points de talent, gratuitement (hors combat)."
	_oublier.pressed.connect(func(): _confirmation.popup_centered())
	ligne_points.add_child(_oublier)
	_voies = HBoxContainer.new()
	_voies.add_theme_constant_override("separation", 14)
	talents.add_child(_voies)

	# --- Onglet Arène
	var arene := VBoxContainer.new()
	arene.name = "Arène"
	arene.add_theme_constant_override("separation", 10)
	_onglets.add_child(arene)
	_arene_entete = _texte("", 15)
	_arene_entete.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_arene_entete.custom_minimum_size.x = 3 * LARGEUR_TALENT
	arene.add_child(_arene_entete)
	var explication := _texte("Ces talents ne servent QUE pendant un combat d'Arène : là-bas, tout le monde est au niveau 20 avec le même équipement, et tes talents normaux sont mis de côté. Clic : choisir ou retirer (hors combat).", 13)
	explication.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explication.custom_minimum_size.x = 3 * LARGEUR_TALENT
	explication.modulate.a = 0.7
	arene.add_child(explication)
	_arene_grille = GridContainer.new()
	_arene_grille.columns = 3
	_arene_grille.add_theme_constant_override("h_separation", 14)
	_arene_grille.add_theme_constant_override("v_separation", 12)
	arene.add_child(_arene_grille)

	# --- Onglet Titres
	var defilement := ScrollContainer.new()
	defilement.name = "Titres"
	defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_onglets.add_child(defilement)
	_titres = VBoxContainer.new()
	_titres.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_titres.add_theme_constant_override("separation", 6)
	defilement.add_child(_titres)

	_confirmation = ConfirmationDialog.new()
	_confirmation.title = "Oublier les talents"
	_confirmation.dialog_text = "Rendre tous tes points de talent ? Tu pourras les replacer tout de suite."
	_confirmation.ok_button_text = "Oublier"
	_confirmation.cancel_button_text = "Garder"
	_confirmation.confirmed.connect(func(): progression.oublier_talents())
	add_child(_confirmation)


func relier(p: Node) -> void:
	progression = p
	progression.change.connect(rafraichir)
	rafraichir()


func basculer() -> void:
	visible = not visible
	if visible:
		rafraichir()
		_centrer.call_deferred()


## Ouvre directement un onglet (0 = Talents, 1 = Arène, 2 = Titres).
func montrer_onglet(n: int) -> void:
	_onglets.current_tab = n
	if not visible:
		basculer()


func _centrer() -> void:
	reset_size()
	position = ((get_viewport_rect().size - size) / 2.0).floor()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("annuler"):
		visible = false
		get_viewport().set_input_as_handled()


func _texte(contenu: String, taille := 14) -> Label:
	var l := Label.new()
	l.text = contenu
	l.add_theme_font_size_override("font_size", taille)
	return l


func _cadre(fond: Color, bord: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fond
	s.border_color = bord
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(8)
	return s


# --- Remplissage --------------------------------------------------------------

func rafraichir() -> void:
	if progression == null or not is_inside_tree():
		return
	var d := Progression.donnees()
	var e: Dictionary = progression.etat
	var n := Progression.niveau(d, e)
	var a := Progression.avancement(d, int(e.get("xp", 0)))
	var classe: String = progression.classe()
	var nom_classe := String(progression.joueur.nom_classe())
	_entete.text = "%s niveau %d   ·   %s" % [nom_classe, n,
			("%d / %d XP vers le niveau %d" % [a.x, a.y, n + 1]) if a.y > 0 else "niveau maximum de cette époque"]
	var libres := Progression.points_libres(d, e)
	_points.text = "Points de talent à placer : %d   (un par niveau, à partir du niveau 2)" % libres
	_points.modulate = Color(1.0, 0.85, 0.4) if libres > 0 else Color(0.75, 0.8, 0.85)
	_oublier.disabled = Progression.points_depenses(e) == 0
	_remplir_voies(d, classe, e)
	_remplir_arene(d, classe, e)
	_remplir_titres(d, e)
	if visible:
		_centrer.call_deferred()


func _remplir_voies(d: Dictionary, classe: String, e: Dictionary) -> void:
	for c in _voies.get_children():
		_voies.remove_child(c)
		c.queue_free()
	for v in Progression.voies(d, classe):
		var couleur := Color.from_string(String(v.get("couleur", "#cccccc")), Color.WHITE)
		var boite := PanelContainer.new()
		boite.add_theme_stylebox_override("panel", _cadre(Color(0.08, 0.1, 0.13, 0.95), couleur.darkened(0.3)))
		_voies.add_child(boite)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		boite.add_child(col)
		var dans_voie := Progression.points_dans_voie(e, v)
		var nom := _texte("%s   ·   %d point%s" % [v.get("nom", ""), dans_voie, "s" if dans_voie > 1 else ""], 17)
		nom.add_theme_color_override("font_color", couleur.lightened(0.2))
		col.add_child(nom)
		var desc := _texte(String(v.get("description", "")), 13)
		desc.modulate.a = 0.7
		col.add_child(desc)
		for t in v.get("talents", []):
			col.add_child(_case_talent(d, classe, e, t, couleur))


func _case_talent(d: Dictionary, classe: String, e: Dictionary, t: Dictionary, couleur: Color) -> Control:
	var id := String(t["id"])
	var rang := int(e.get("talents", {}).get(id, 0))
	var rangs := int(t.get("rangs", 1))
	var raison := Progression.raison_talent_impossible(d, classe, e, id)
	var palier := int(t.get("palier", 1))
	var requis := Progression.points_requis(d, palier)

	var b := Button.new()
	b.name = "Talent_" + id
	b.custom_minimum_size = Vector2(LARGEUR_TALENT, 104)
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 13)
	var entete := "%s   %d / %d" % [t.get("nom", id), rang, rangs]
	var bas := ""
	if rang >= rangs:
		bas = "Au maximum"
	elif raison.begins_with("Il faut"):
		bas = "Palier %d : %d points dans cette voie" % [palier, requis]
	b.text = "%s\n%s%s" % [entete, t.get("texte", ""), ("\n" + bas) if bas != "" else ""]
	b.tooltip_text = "%s (palier %d)\n%s%s" % [t.get("nom", id), palier, t.get("texte", ""),
			("\n\n" + raison) if raison != "" and rang < rangs else ""]
	var fond := Color(0.12, 0.14, 0.18)
	var bord := Color(0.3, 0.33, 0.38)
	if rang >= rangs:
		fond = couleur.darkened(0.55)
		bord = couleur.lightened(0.1)
	elif rang > 0:
		fond = couleur.darkened(0.7)
		bord = couleur
	elif raison == "":
		bord = Color(1.0, 0.85, 0.4, 0.9)
	var normal := _cadre(fond, bord)
	normal.set_border_width_all(2 if raison == "" or rang > 0 else 1)
	b.add_theme_stylebox_override("normal", normal)
	var survol := _cadre(fond.lightened(0.08), bord.lightened(0.2))
	survol.set_border_width_all(2)
	b.add_theme_stylebox_override("hover", survol)
	b.add_theme_stylebox_override("pressed", survol)
	b.add_theme_stylebox_override("disabled", normal)
	if raison.begins_with("Il faut") and rang == 0:
		b.modulate = Color(1, 1, 1, 0.45)
	b.pressed.connect(func(): progression.prendre_talent(id))
	return b


func _remplir_arene(d: Dictionary, classe: String, e: Dictionary) -> void:
	for c in _arene_grille.get_children():
		_arene_grille.remove_child(c)
		c.queue_free()
	var choisis: Array = e.get("talents_arene", [])
	var places := Progression.emplacements_arene(d)
	_arene_entete.text = "Talents d'Arène choisis : %d / %d" % [choisis.size(), places]
	_arene_entete.modulate = Color(1.0, 0.85, 0.4) if choisis.size() < places else Color(0.75, 0.85, 0.9)
	var or_arene := Color(0.95, 0.55, 0.25)
	for t in Progression.talents_arene(d, classe):
		var id := String(t["id"])
		var pris := id in choisis
		var b := Button.new()
		b.name = "Arene_" + id
		b.custom_minimum_size = Vector2(LARGEUR_TALENT, 110)
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 13)
		b.text = "%s  %s%s\n%s" % [t.get("icone", "✦"), t.get("nom", id), "   ✔ choisi" if pris else "", t.get("texte", "")]
		var plein := not pris and choisis.size() >= places
		b.tooltip_text = "%s\n%s%s" % [t.get("nom", id), t.get("texte", ""),
				"\n\nClic pour le retirer." if pris else ("\n\nRetire d'abord un talent choisi." if plein else "\n\nClic pour le choisir.")]
		var fond := or_arene.darkened(0.65) if pris else Color(0.12, 0.14, 0.18)
		var bord := or_arene.lightened(0.15) if pris else (Color(0.3, 0.33, 0.38) if plein else Color(1.0, 0.85, 0.4, 0.9))
		var normal := _cadre(fond, bord)
		normal.set_border_width_all(2 if pris or not plein else 1)
		b.add_theme_stylebox_override("normal", normal)
		var survol := _cadre(fond.lightened(0.08), bord.lightened(0.2))
		survol.set_border_width_all(2)
		b.add_theme_stylebox_override("hover", survol)
		b.add_theme_stylebox_override("pressed", survol)
		if plein:
			b.modulate = Color(1, 1, 1, 0.55)
		b.pressed.connect(func(): progression.choisir_talent_arene(id))
		_arene_grille.add_child(b)


func _remplir_titres(d: Dictionary, e: Dictionary) -> void:
	for c in _titres.get_children():
		_titres.remove_child(c)
		c.queue_free()
	var porte := String(e.get("titre", ""))
	var obtenus: Array = e.get("titres", [])
	var aucun := Button.new()
	aucun.text = "Ne porter aucun titre" if porte != "" else "Aucun titre porté"
	aucun.disabled = porte == ""
	aucun.focus_mode = Control.FOCUS_NONE
	aucun.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	aucun.pressed.connect(func(): progression.choisir_titre(""))
	_titres.add_child(aucun)
	var epoque := ""
	for t in Progression.liste_titres(d):
		if String(t.get("epoque", "")) != epoque:
			epoque = String(t.get("epoque", ""))
			var section := _texte(epoque, 16)
			section.modulate = Color(0.55, 0.9, 0.95)
			_titres.add_child(section)
		var id := String(t["id"])
		var a_le_titre := id in obtenus
		var ligne := Button.new()
		ligne.name = "Titre_" + id
		ligne.focus_mode = Control.FOCUS_NONE
		ligne.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ligne.custom_minimum_size = Vector2(0, 40)
		ligne.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ligne.add_theme_font_size_override("font_size", 14)
		var etat_titre := "Porté" if id == porte else ("Obtenu : clic pour le porter" if a_le_titre else "À obtenir")
		ligne.text = "« %s »    —    %s    (%s)" % [t.get("nom", id), t.get("comment", ""), etat_titre]
		var bord := Color(1.0, 0.85, 0.4) if id == porte else (Color(0.4, 0.6, 0.45) if a_le_titre else Color(0.25, 0.27, 0.3))
		ligne.add_theme_stylebox_override("normal", _cadre(Color(0.1, 0.12, 0.15), bord))
		ligne.add_theme_stylebox_override("hover", _cadre(Color(0.14, 0.16, 0.2), bord.lightened(0.2)))
		ligne.add_theme_stylebox_override("disabled", _cadre(Color(0.08, 0.09, 0.11), bord))
		if not a_le_titre:
			ligne.disabled = true
			ligne.modulate = Color(1, 1, 1, 0.5)
		else:
			ligne.pressed.connect(func(): progression.choisir_titre(id))
		_titres.add_child(ligne)
