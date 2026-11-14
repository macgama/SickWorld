extends PanelContainer
## Écran « Personnage » (touches C, I ou B) : équipement porté, caractéristiques,
## compétences d'époque, tenues de mission et contenu des sacs.
##
## Clic gauche sur un objet des sacs : l'équiper (ou accrocher le sac).
## Clic droit sur un objet des sacs : le jeter (avec confirmation).
## Clic sur un emplacement d'équipement : retirer l'objet.
## Rien n'est décidé ici : chaque clic envoie une demande au serveur (voir Inventaire).
##
## Les objets sont montrés par leur image (interface/icones/<id>.png, voir tests/generer_icones.gd),
## et le personnage est affiché en 3D au centre : il change dès qu'on l'équipe.

const APPARENCE := preload("res://scripts/joueur/apparence_agent.gd")
const TAILLE_CASE := 56
const TAILLE_EMPLACEMENT := 64
const COLONNES_SAC := 6
const GAUCHE := ["tete", "torse", "mains", "jambes", "pieds"]
const DROITE := ["arme_principale", "arme_secondaire", "bijou_1", "bijou_2", "relique"]

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
# Aperçu 3D
var _apercu: Node3D
var _camera_apercu: Camera3D
var _rotation_apercu := 0.0
var _glisse := false
var _fiche_appliquee := {}
var _visuels_appliques := {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.1, 0.985)
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
	var poupee := HBoxContainer.new()
	poupee.add_theme_constant_override("separation", 8)
	boite.add_child(poupee)
	poupee.add_child(_colonne_emplacements(GAUCHE))
	poupee.add_child(_construire_apercu())
	poupee.add_child(_colonne_emplacements(DROITE))
	boite.add_child(_section("Sacs portés"))
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 6)
	boite.add_child(ligne)
	for i in 4:
		var b := _bouton_icone(TAILLE_CASE)
		b.pressed.connect(func(): if inventaire: inventaire.decrocher_sac(i))
		ligne.add_child(b)
		_sacs_portes.append(b)
	return boite


func _colonne_emplacements(liste: Array) -> Control:
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 8)
	colonne.alignment = BoxContainer.ALIGNMENT_CENTER
	for e in liste:
		var b := _bouton_icone(TAILLE_EMPLACEMENT)
		b.pressed.connect(func(): if inventaire: inventaire.retirer(e))
		colonne.add_child(b)
		_emplacements[e] = b
	return colonne


## Case carrée qui affiche l'image d'un objet (et un petit texte quand elle est vide).
func _bouton_icone(taille: int) -> Button:
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
	quantite.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	quantite.position = Vector2(taille - 24, taille - 20)
	quantite.size = Vector2(20, 18)
	quantite.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(quantite)
	return b


## Le personnage en 3D, dans son propre petit studio (on le tourne en glissant la souris).
func _construire_apercu() -> Control:
	var cadre := SubViewportContainer.new()
	cadre.stretch = true
	cadre.custom_minimum_size = Vector2(250, 5 * TAILLE_EMPLACEMENT + 4 * 8)
	cadre.mouse_default_cursor_shape = Control.CURSOR_DRAG
	cadre.tooltip_text = "Glisse la souris pour faire tourner ton personnage"
	cadre.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			_glisse = ev.pressed
		elif ev is InputEventMouseMotion and _glisse:
			_rotation_apercu += ev.relative.x * 0.012)
	var vue := SubViewport.new()
	vue.own_world_3d = true
	vue.msaa_3d = Viewport.MSAA_4X
	cadre.add_child(vue)
	var monde := Node3D.new()
	vue.add_child(monde)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.09, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	monde.add_child(we)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-35, 150, 0)
	soleil.light_energy = 1.3
	monde.add_child(soleil)
	var contre := OmniLight3D.new()
	contre.position = Vector3(-1.4, 2.3, 1.6)
	contre.light_color = Color(0.25, 0.85, 0.9)
	contre.light_energy = 1.4
	contre.omni_range = 6.0
	monde.add_child(contre)
	var sol := MeshInstance3D.new()
	var disque := CylinderMesh.new()
	disque.top_radius = 0.7
	disque.bottom_radius = 0.75
	disque.height = 0.04
	sol.mesh = disque
	sol.position.y = -0.02
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.13, 0.16, 0.21)
	sol.material_override = mat
	monde.add_child(sol)
	_apercu = Node3D.new()
	_apercu.set_script(APPARENCE)
	monde.add_child(_apercu)
	_camera_apercu = Camera3D.new()
	_camera_apercu.fov = 30.0
	_camera_apercu.current = true
	_camera_apercu.transform = Transform3D.IDENTITY.translated(Vector3(0, 1.05, -3.9)) \
			.looking_at(Vector3(0, 0.95, 0), Vector3.UP)
	monde.add_child(_camera_apercu)
	return cadre


## Met à jour le personnage de l'aperçu (apparence de la fiche + équipement porté).
func _mettre_a_jour_apercu() -> void:
	if _apercu == null or inventaire == null:
		return
	var joueur := inventaire.get_parent()
	var fiche_noeud := joueur.get_node_or_null("Fiche")
	var fiche: Dictionary = fiche_noeud.donnees if fiche_noeud != null else {}
	if fiche != _fiche_appliquee and _apercu.has_method("appliquer"):
		_fiche_appliquee = fiche.duplicate(true)
		_apercu.appliquer(FichePersonnage.resoudre(fiche, Donnees.creation))
		_visuels_appliques = {}
	var visuels := Objets.visuels(Donnees.objets, inventaire.etat.get("equipement", {}))
	if visuels != _visuels_appliques:
		_visuels_appliques = visuels
		_apercu.equiper(visuels)


func _process(delta: float) -> void:
	if not visible or _apercu == null:
		return
	_apercu.rotation.y = lerp_angle(_apercu.rotation.y, _rotation_apercu, clampf(10.0 * delta, 0.0, 1.0))
	_apercu.animer(delta, Vector3.ZERO, true, -1.0, Vector3.ZERO)


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
	defilement.custom_minimum_size = Vector2(COLONNES_SAC * (TAILLE_CASE + 4) + 12, 7 * (TAILLE_CASE + 4))
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


func _habiller_bouton(b: Button, id: String, vide_texte: String, n := 1, nom_vide := "") -> void:
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
	var image := Objets.icone(id)
	b.icon = image
	# Sans image (objet tout neuf), on garde le nom en petit.
	if id == "":
		b.text = nom_vide
		b.modulate = Color(1, 1, 1, 0.75)
	else:
		b.text = "" if image != null else _abreger(String(Objets.objet(cat, id).get("nom", id)))
		b.modulate = Color.WHITE
	var quantite := b.get_node_or_null("Quantite") as Label
	if quantite != null:
		quantite.text = str(n) if n > 1 else ""


# --- Mise à jour ----------------------------------------------------------------

func rafraichir() -> void:
	if inventaire == null or inventaire.etat.is_empty() or not is_inside_tree():
		return
	var cat := Donnees.objets
	var etat: Dictionary = inventaire.etat

	for e in Objets.EMPLACEMENTS:
		var id := String(etat["equipement"].get(e, ""))
		var b := _emplacements[e] as Button
		var nom_emplacement := String(Objets.NOMS_EMPLACEMENTS[e])
		_habiller_bouton(b, id, nom_emplacement + " : vide", 1,
				nom_emplacement.replace("Arme principale", "Arme").replace("Arme secondaire", "Main\ngauche").replace("Relique d'époque", "Relique"))

	for i in _sacs_portes.size():
		var id := String(etat["sacs"][i]) if i < etat["sacs"].size() else ""
		_habiller_bouton(_sacs_portes[i], id, "Emplacement de sac libre : clique sur un sac dans tes sacs pour l'accrocher.", 1, "Sac")

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
		_habiller_bouton(b, id, "", int(c.get("n", 1)))
	_mettre_a_jour_apercu()
	_titre_sacs.text = "Sacs  (%d / %d places)" % [cases.size() - Objets.places_libres(etat), cases.size()]

	# Caractéristiques
	var bonus: Dictionary = inventaire.bonus
	var s: Dictionary = bonus.get("stats", {})
	var lignes: Array[String] = []
	lignes.append("[b]Points de vie[/b] : %d  (%+d grâce à l'équipement)" % [
			combat_joueur.pv_de_base() + float(s.get("pv", 0)), int(s.get("pv", 0))])
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
	var b := _bouton_icone(TAILLE_CASE)
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
