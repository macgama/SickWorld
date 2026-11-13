extends Control
## Écran de création du personnage, en 3 étapes :
##   1. Apparence (corps, visage, cheveux, tenue de la Vigie)
##   2. Classe (Rempart, Lame, Traqueur, Tisseur)
##   3. Origine (ville d'où vient le voyageur) et nom
##
## Tous les choix proposés viennent de data/creation_personnage.json : on peut
## ajouter une coiffure, une couleur ou une ville sans toucher à ce script.
## Le résultat est une « fiche » (voir FichePersonnage) sauvegardée sur le PC,
## puis envoyée au serveur quand on rejoint une partie.

const SCENE_MENU := "res://scenes/interface/menu.tscn"
const APPARENCE := preload("res://scripts/joueur/apparence_provisoire.gd")
const COULEUR_ACCENT := Color(0.25, 0.85, 0.9)
const ETAPES := ["Apparence", "Classe", "Origine"]
const SOUS_ONGLETS := ["Corps", "Visage", "Cheveux", "Tenue"]
## Bonus d'origine qui fonctionnent déjà dans le prototype.
const BONUS_ACTIFS := ["cout_esquive_pourcent", "recuperation_endurance_pourcent",
		"regeneration_hors_combat_pourcent"]

## Cadrages de la caméra : [distance, hauteur visée (m), hauteur de la caméra au-dessus].
const CADRAGES := {
	"corps": [3.4, 0.95, 0.15],
	"buste": [1.1, 1.66, 0.05],
	"visage": [0.62, 1.66, 0.0],
}

var etape := 0
var sous_onglet := 0
var fiche: Dictionary = {}
var _catalogue: Dictionary
var _modification := false

var _apparence: Node3D
var _camera: Camera3D
var _cadrage := "corps"
var _distance := 3.4
var _visee := Vector3(0, 0.95, 0)
var _rotation_avatar := 0.35
var _glisse := false
var _prochaine_attaque := 0.0

var _boutons_etapes: Array[Button] = []
var _contenu: VBoxContainer
var _defilement: ScrollContainer
var _precedent: Button
var _suivant: Button
var _titre_apercu: Label
var _champ_nom: LineEdit
var _erreur: Label


func _ready() -> void:
	_catalogue = Donnees.creation
	var existante := FichePersonnage.charger(_catalogue)
	_modification = not existante.is_empty()
	fiche = existante if _modification else FichePersonnage.au_hasard(_catalogue,
			FichePersonnage.par_defaut(_catalogue, ["femme", "homme"].pick_random()))
	if not _modification:
		fiche["nom"] = ""
	_construire()
	aller_etape(0)


# --- Construction de l'écran -------------------------------------------------

func _construire() -> void:
	var fond := ColorRect.new()
	fond.color = Color(0.05, 0.07, 0.1)
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)

	var lignes := HBoxContainer.new()
	lignes.set_anchors_preset(Control.PRESET_FULL_RECT)
	lignes.add_theme_constant_override("separation", 0)
	add_child(lignes)

	# À gauche : l'aperçu 3D du personnage.
	var cadre := SubViewportContainer.new()
	cadre.stretch = true
	cadre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cadre.gui_input.connect(_sur_entree_apercu)
	cadre.mouse_default_cursor_shape = Control.CURSOR_DRAG
	lignes.add_child(cadre)
	var vue := SubViewport.new()
	vue.own_world_3d = true
	vue.msaa_3d = Viewport.MSAA_4X
	cadre.add_child(vue)
	_construire_studio(vue)
	_construire_surcouche(cadre)

	# À droite : les choix.
	var panneau := PanelContainer.new()
	panneau.custom_minimum_size = Vector2(600, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.13)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panneau.add_theme_stylebox_override("panel", style)
	lignes.add_child(panneau)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 14)
	panneau.add_child(colonne)

	var titre := Label.new()
	titre.text = "Modifier ton agent" if _modification else "Nouvel agent de la Vigie"
	titre.add_theme_font_size_override("font_size", 30)
	titre.add_theme_color_override("font_color", COULEUR_ACCENT)
	colonne.add_child(titre)

	var barre_etapes := HBoxContainer.new()
	barre_etapes.add_theme_constant_override("separation", 8)
	colonne.add_child(barre_etapes)
	for i in ETAPES.size():
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, ETAPES[i]]
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 40)
		b.pressed.connect(aller_etape.bind(i))
		barre_etapes.add_child(b)
		_boutons_etapes.append(b)
	colonne.add_child(HSeparator.new())

	_defilement = ScrollContainer.new()
	_defilement.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	colonne.add_child(_defilement)
	_contenu = VBoxContainer.new()
	_contenu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contenu.add_theme_constant_override("separation", 10)
	_defilement.add_child(_contenu)

	_erreur = Label.new()
	_erreur.add_theme_color_override("font_color", Color(1, 0.5, 0.4))
	_erreur.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	colonne.add_child(_erreur)

	var pied := HBoxContainer.new()
	pied.add_theme_constant_override("separation", 8)
	colonne.add_child(pied)
	var retour := _bouton("Annuler", func(): get_tree().change_scene_to_file(SCENE_MENU))
	pied.add_child(retour)
	var espace := Control.new()
	espace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pied.add_child(espace)
	_precedent = _bouton("◀ Précédent", func(): aller_etape(etape - 1))
	pied.add_child(_precedent)
	_suivant = _bouton("Suivant ▶", _sur_suivant)
	_suivant.custom_minimum_size = Vector2(200, 44)
	pied.add_child(_suivant)


## Le « studio » : un sol, des lumières, le personnage et la caméra.
func _construire_studio(vue: SubViewport) -> void:
	var monde := Node3D.new()
	vue.add_child(monde)

	var environnement := Environment.new()
	environnement.background_mode = Environment.BG_COLOR
	environnement.background_color = Color(0.08, 0.1, 0.14)
	environnement.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environnement.ambient_light_color = Color(0.55, 0.6, 0.7)
	environnement.ambient_light_energy = 0.55
	environnement.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = environnement
	monde.add_child(we)

	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-35, -30, 0)
	soleil.light_energy = 1.3
	soleil.shadow_enabled = true
	monde.add_child(soleil)
	var contre_jour := OmniLight3D.new()
	contre_jour.position = Vector3(-1.5, 2.4, 1.8)
	contre_jour.light_color = COULEUR_ACCENT
	contre_jour.light_energy = 1.2
	contre_jour.omni_range = 6.0
	monde.add_child(contre_jour)
	var face := OmniLight3D.new()
	face.position = Vector3(0.6, 1.8, -1.6)
	face.light_energy = 0.5
	face.omni_range = 5.0
	monde.add_child(face)

	var sol := MeshInstance3D.new()
	var disque := CylinderMesh.new()
	disque.top_radius = 1.4
	disque.bottom_radius = 1.5
	disque.height = 0.08
	sol.mesh = disque
	sol.position.y = -0.04
	var mat_sol := StandardMaterial3D.new()
	mat_sol.albedo_color = Color(0.14, 0.17, 0.22)
	mat_sol.roughness = 0.4
	sol.material_override = mat_sol
	monde.add_child(sol)
	var anneau := MeshInstance3D.new()
	var tore := TorusMesh.new()
	tore.inner_radius = 1.38
	tore.outer_radius = 1.42
	anneau.mesh = tore
	var mat_anneau := StandardMaterial3D.new()
	mat_anneau.albedo_color = COULEUR_ACCENT
	mat_anneau.emission_enabled = true
	mat_anneau.emission = COULEUR_ACCENT
	mat_anneau.emission_energy_multiplier = 1.5
	anneau.material_override = mat_anneau
	monde.add_child(anneau)

	_apparence = Node3D.new()
	_apparence.set_script(APPARENCE)
	monde.add_child(_apparence)

	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 35.0
	_camera.environment = environnement
	monde.add_child(_camera)


func _construire_surcouche(cadre: Control) -> void:
	var haut := MarginContainer.new()
	haut.set_anchors_preset(Control.PRESET_TOP_WIDE)
	haut.add_theme_constant_override("margin_left", 24)
	haut.add_theme_constant_override("margin_top", 20)
	haut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(haut)
	_titre_apercu = Label.new()
	_titre_apercu.add_theme_font_size_override("font_size", 22)
	_titre_apercu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	haut.add_child(_titre_apercu)

	var bas := HBoxContainer.new()
	bas.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bas.position = Vector2(24, -64)
	bas.add_theme_constant_override("separation", 8)
	cadre.add_child(bas)
	# Les boutons sont recalés en bas à gauche quand la fenêtre change de taille.
	cadre.resized.connect(func(): bas.position = Vector2(24, cadre.size.y - 64))
	bas.add_child(_bouton("Corps entier", func(): _changer_cadrage("corps")))
	bas.add_child(_bouton("Buste", func(): _changer_cadrage("buste")))
	bas.add_child(_bouton("Visage", func(): _changer_cadrage("visage")))
	bas.add_child(_bouton("🎲 Au hasard", _au_hasard))
	var aide := Label.new()
	aide.text = "  Glisse avec la souris pour tourner, molette pour zoomer"
	aide.modulate.a = 0.6
	bas.add_child(aide)


# --- Navigation ---------------------------------------------------------------

func aller_etape(n: int) -> void:
	etape = clampi(n, 0, ETAPES.size() - 1)
	for i in _boutons_etapes.size():
		_boutons_etapes[i].set_pressed_no_signal(i == etape)
	_precedent.disabled = etape == 0
	if etape < ETAPES.size() - 1:
		_suivant.text = "Suivant ▶"
	else:
		_suivant.text = "Enregistrer" if _modification else "Créer le personnage"
	_erreur.text = ""
	_remplir()


func choisir_sous_onglet(n: int) -> void:
	sous_onglet = clampi(n, 0, SOUS_ONGLETS.size() - 1)
	_remplir()


func _sur_suivant() -> void:
	if etape < ETAPES.size() - 1:
		aller_etape(etape + 1)
	else:
		terminer()


## Vérifie le nom, sauvegarde la fiche et revient au menu. Renvoie l'erreur éventuelle.
func terminer() -> String:
	var nom := _champ_nom.text if _champ_nom != null else String(fiche.get("nom", ""))
	var erreur := FichePersonnage.erreur_nom(nom)
	if erreur != "":
		_erreur.text = erreur
		if _champ_nom != null:
			_champ_nom.grab_focus()
		return erreur
	fiche["nom"] = FichePersonnage.nettoyer_nom(nom)
	var propre := FichePersonnage.valider(fiche, _catalogue)
	if FichePersonnage.sauvegarder(propre) != OK:
		_erreur.text = "Impossible d'enregistrer le personnage sur ce PC."
		return _erreur.text
	Reseau.fiche = propre
	Reseau.nom_joueur = propre["nom"]
	Reseau.set_meta("message_menu_ok", "%s est prêt pour sa première mission." % propre["nom"])
	get_tree().change_scene_to_file(SCENE_MENU)
	return ""


func _remplir() -> void:
	for enfant in _contenu.get_children():
		_contenu.remove_child(enfant)
		enfant.queue_free()
	_champ_nom = null
	match etape:
		0:
			_remplir_apparence()
		1:
			_remplir_classe()
		2:
			_remplir_origine()
	_defilement.scroll_vertical = 0
	_actualiser_apercu()


func _remplir_apparence() -> void:
	var onglets := HBoxContainer.new()
	onglets.add_theme_constant_override("separation", 6)
	_contenu.add_child(onglets)
	for i in SOUS_ONGLETS.size():
		var b := Button.new()
		b.text = SOUS_ONGLETS[i]
		b.toggle_mode = true
		b.button_pressed = i == sous_onglet
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(choisir_sous_onglet.bind(i))
		onglets.add_child(b)
	match sous_onglet:
		0:
			_changer_cadrage("corps")
			_section("Sexe")
			_choix(_catalogue.get("sexes", []), fiche["sexe"], _choisir_sexe, 2)
			_section("Silhouette")
			for curseur in _catalogue.get("corps", []):
				_curseur_fiche("corps", curseur)
			_section("Couleur de peau")
			_nuancier(_catalogue.get("peaux", []), "peau")
			_section("Couleur des yeux")
			_nuancier(_catalogue.get("couleurs_yeux", []), "couleur_yeux")
		1:
			_changer_cadrage("visage")
			_section("Visages de départ")
			_paragraphe("Choisis une base, puis affine chaque détail avec les curseurs.")
			var types := GridContainer.new()
			types.columns = 3
			types.add_theme_constant_override("h_separation", 6)
			types.add_theme_constant_override("v_separation", 6)
			_contenu.add_child(types)
			for type in _catalogue.get("visages_types", []):
				var b := _bouton(String(type["nom"]), _appliquer_visage_type.bind(type))
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				types.add_child(b)
			var groupe := ""
			for curseur in _catalogue.get("visage", []):
				if curseur.get("groupe", "") != groupe:
					groupe = curseur.get("groupe", "")
					_section(groupe)
				_curseur_fiche("visage", curseur)
		2:
			_changer_cadrage("buste")
			_rotation_avatar = 2.4  # de trois quarts dos, pour voir l'arrière de la coiffure
			_section("Coiffure")
			_choix(_catalogue.get("coiffures", []), fiche["coiffure"],
					func(id): _changer("coiffure", id), 3)
			_section("Couleur des cheveux")
			_nuancier(_catalogue.get("couleurs_cheveux", []), "couleur_cheveux")
			_section("Barbe et moustache")
			_choix(_catalogue.get("pilosites", []), fiche["pilosite"],
					func(id): _changer("pilosite", id), 3)
		3:
			_changer_cadrage("corps")
			_section("Tenue de départ de la Vigie")
			for tenue in _catalogue.get("tenues", []):
				var b := _bouton_carte(String(tenue["nom"]), String(tenue.get("description", "")),
						tenue["id"] == fiche["tenue"], func(): _changer("tenue", tenue["id"]); _remplir())
				_contenu.add_child(b)
			_paragraphe("D'autres tenues se débloqueront en jouant (récompenses d'époque).", 0.6)


func _remplir_classe() -> void:
	_changer_cadrage("corps")
	_section("Choisis ta spécialité au sein de la Vigie")
	var grille := GridContainer.new()
	grille.columns = 2
	grille.add_theme_constant_override("h_separation", 8)
	grille.add_theme_constant_override("v_separation", 8)
	_contenu.add_child(grille)
	for classe in _catalogue.get("classes", []):
		var b := _bouton_carte(String(classe["nom"]), String(classe.get("role", "")),
				classe["id"] == fiche["classe"], func(): _changer("classe", classe["id"]); _remplir())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grille.add_child(b)

	var c := FichePersonnage.element(_catalogue, "classes", fiche["classe"])
	if c.is_empty():
		return
	_section(String(c["nom"]))
	_paragraphe(String(c.get("description", "")))
	var etoiles := int(c.get("difficulte", 1))
	_paragraphe("Rôle : %s\nArme : %s\nRessource : %s\nDifficulté : %s" % [c.get("role", ""),
			c.get("arme_texte", ""), c.get("ressource", ""), "★".repeat(etoiles) + "☆".repeat(3 - etoiles)])
	_section("Quelques compétences")
	for comp in c.get("competences", []):
		_paragraphe("• %s : %s" % [comp["nom"], comp["texte"]])
	_paragraphe("Tu gagneras aussi 2 compétences d'époque et une compétence ultime sur chaque île.", 0.6)
	if not c.get("jouable", false):
		var note := _paragraphe("Prototype : cette classe n'a pas encore ses compétences. "
				+ "En attendant, elle joue avec celles de la Lame.", 1.0)
		note.add_theme_color_override("font_color", Color(1, 0.78, 0.4))


func _remplir_origine() -> void:
	_changer_cadrage("corps")
	_section("D'où vient ton voyageur ?")
	var grille := GridContainer.new()
	grille.columns = 2
	grille.add_theme_constant_override("h_separation", 8)
	grille.add_theme_constant_override("v_separation", 8)
	_contenu.add_child(grille)
	for origine in _catalogue.get("origines", []):
		var b := _bouton_carte(String(origine["nom"]), String(origine.get("pays", "")),
				origine["id"] == fiche["origine"], func(): _changer("origine", origine["id"]); _remplir())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grille.add_child(b)

	var o := FichePersonnage.element(_catalogue, "origines", fiche["origine"])
	if not o.is_empty():
		_section("%s, %s" % [o["nom"], o.get("pays", "")])
		_paragraphe(String(o.get("description", "")))
		var bonus: Dictionary = o.get("bonus", {})
		var texte_bonus := "Bonus — " + String(bonus.get("texte", ""))
		if not bonus.get("type", "") in BONUS_ACTIFS:
			texte_bonus += " (actif quand ce système existera)"
		var l := _paragraphe(texte_bonus)
		l.add_theme_color_override("font_color", COULEUR_ACCENT)
		var quete: Dictionary = o.get("quete_intro", {})
		_paragraphe("Quête personnelle : « %s »\n%s" % [quete.get("titre", ""), quete.get("texte", "")], 0.85)

	_section("Nom de ton agent")
	_champ_nom = LineEdit.new()
	_champ_nom.max_length = FichePersonnage.NOM_LONGUEUR_MAX
	_champ_nom.placeholder_text = "Entre %d et %d lettres" % [FichePersonnage.NOM_LONGUEUR_MIN,
			FichePersonnage.NOM_LONGUEUR_MAX]
	_champ_nom.text = String(fiche.get("nom", ""))
	_champ_nom.custom_minimum_size = Vector2(0, 40)
	_champ_nom.text_changed.connect(func(t): fiche["nom"] = t; _erreur.text = ""; _actualiser_titre())
	_champ_nom.text_submitted.connect(func(_t): terminer())
	_contenu.add_child(_champ_nom)


# --- Changements ------------------------------------------------------------------

func _changer(champ: String, valeur) -> void:
	fiche[champ] = valeur
	_actualiser_apercu()


func _choisir_sexe(id: String) -> void:
	fiche["sexe"] = id
	var sexe := FichePersonnage.element(_catalogue, "sexes", id)
	fiche["corps"]["taille_cm"] = float(sexe.get("taille_par_defaut", fiche["corps"]["taille_cm"]))
	_remplir()


func _appliquer_visage_type(type: Dictionary) -> void:
	for curseur in _catalogue.get("visage", []):
		fiche["visage"][curseur["id"]] = float(type.get("valeurs", {}).get(curseur["id"], 0.0))
	_remplir()


func _au_hasard() -> void:
	var nom = fiche.get("nom", "")
	var sexe = fiche["sexe"]
	fiche = FichePersonnage.au_hasard(_catalogue, fiche)
	fiche["nom"] = nom
	fiche["sexe"] = sexe
	_remplir()


func _actualiser_apercu() -> void:
	if _apparence != null:
		_apparence.appliquer(FichePersonnage.resoudre(fiche, _catalogue))
	_actualiser_titre()


func _actualiser_titre() -> void:
	if _titre_apercu == null:
		return
	var classe := FichePersonnage.element(_catalogue, "classes", fiche.get("classe", ""))
	var origine := FichePersonnage.element(_catalogue, "origines", fiche.get("origine", ""))
	var nom := FichePersonnage.nettoyer_nom(String(fiche.get("nom", "")))
	_titre_apercu.text = "%s\n%s · %s" % [nom if nom != "" else "Agent sans nom",
			classe.get("nom", ""), origine.get("nom", "")]


func _changer_cadrage(nom: String) -> void:
	_cadrage = nom


# --- Caméra et rotation de l'aperçu ----------------------------------------------

func _sur_entree_apercu(evenement: InputEvent) -> void:
	if evenement is InputEventMouseButton:
		var b := evenement as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_LEFT:
			_glisse = b.pressed
		elif b.pressed and b.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cadrage = {"corps": "buste", "buste": "visage"}.get(_cadrage, _cadrage)
		elif b.pressed and b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cadrage = {"visage": "buste", "buste": "corps"}.get(_cadrage, _cadrage)
	elif evenement is InputEventMouseMotion and _glisse:
		_rotation_avatar += (evenement as InputEventMouseMotion).relative.x * 0.01


func _process(delta: float) -> void:
	if _apparence == null:
		return
	_apparence.rotation.y = lerp_angle(_apparence.rotation.y, _rotation_avatar, clampf(10.0 * delta, 0, 1))
	# Respiration au repos (et un coup d'arme de temps en temps sur l'étape « Classe »).
	_apparence.animer(delta, Vector3.ZERO, true, -1.0, Vector3.ZERO)
	_prochaine_attaque -= delta
	if etape == 1 and _prochaine_attaque <= 0.0:
		_prochaine_attaque = 2.5
		_apparence.attaquer()

	var reglage: Array = CADRAGES[_cadrage]
	var echelle := float(FichePersonnage.resoudre(fiche, _catalogue)["taille_cm"]) / APPARENCE.TAILLE_REFERENCE \
			if _cadrage != "corps" else 1.0
	var visee := Vector3(0, float(reglage[1]) * echelle, 0)
	if _cadrage == "visage":
		visee = _apparence.position_visage() + Vector3(0, -0.01, 0)
	var poids := clampf(6.0 * delta, 0.0, 1.0)
	_distance = lerpf(_distance, float(reglage[0]), poids)
	_visee = _visee.lerp(visee, poids)
	_camera.position = _visee + Vector3(0, float(reglage[2]), -_distance)
	_camera.look_at(_visee, Vector3.UP)


# --- Petits outils d'interface ---------------------------------------------------

func _section(texte: String) -> void:
	var l := Label.new()
	l.text = texte.to_upper()
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", COULEUR_ACCENT)
	var marge := MarginContainer.new()
	marge.add_theme_constant_override("margin_top", 8)
	marge.add_child(l)
	_contenu.add_child(marge)


func _paragraphe(texte: String, opacite := 1.0) -> Label:
	var l := Label.new()
	l.text = texte
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(500, 0)
	l.modulate.a = opacite
	_contenu.add_child(l)
	return l


func _bouton(texte: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = texte
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(action)
	return b


## Gros bouton à deux lignes (titre + sous-titre), surligné s'il est choisi.
func _bouton_carte(titre: String, sous_titre: String, choisi: bool, action: Callable) -> Button:
	var b := Button.new()
	b.text = titre + ("\n" + sous_titre if sous_titre != "" else "")
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 64)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(action)
	if choisi:
		_surligner(b)
	return b


func _surligner(b: Button) -> void:
	for etat in ["normal", "hover", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.1, 0.25, 0.3) if etat != "focus" else Color(0, 0, 0, 0)
		s.border_color = COULEUR_ACCENT
		s.set_border_width_all(2)
		s.set_corner_radius_all(4)
		s.content_margin_left = 12
		s.content_margin_right = 12
		b.add_theme_stylebox_override(etat, s)


## Rangée de boutons : un seul choisi à la fois.
func _choix(liste: Array, actuel: String, action: Callable, colonnes: int) -> void:
	var grille := GridContainer.new()
	grille.columns = colonnes
	grille.add_theme_constant_override("h_separation", 6)
	grille.add_theme_constant_override("v_separation", 6)
	_contenu.add_child(grille)
	for e in liste:
		var b := Button.new()
		b.text = String(e["nom"])
		b.custom_minimum_size = Vector2(0, 38)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if e["id"] == actuel:
			_surligner(b)
		b.pressed.connect(func(): action.call(e["id"]); _remplir_en_gardant_le_defilement())
		grille.add_child(b)


## Pastilles de couleur.
func _nuancier(liste: Array, champ: String) -> void:
	var grille := HFlowContainer.new()
	grille.add_theme_constant_override("h_separation", 6)
	grille.add_theme_constant_override("v_separation", 6)
	_contenu.add_child(grille)
	for e in liste:
		var b := Button.new()
		b.custom_minimum_size = Vector2(40, 40)
		b.tooltip_text = String(e["nom"])
		var choisi: bool = e["id"] == fiche.get(champ)
		for etat in ["normal", "hover", "pressed", "focus"]:
			var s := StyleBoxFlat.new()
			s.bg_color = Color.from_string(String(e["couleur"]), Color.GRAY)
			s.set_corner_radius_all(20)
			s.border_color = COULEUR_ACCENT if choisi else (Color(1, 1, 1, 0.5) if etat == "hover" else Color(0, 0, 0, 0))
			s.set_border_width_all(3)
			if etat == "focus" and not choisi:
				s.draw_center = false
			b.add_theme_stylebox_override(etat, s)
		b.pressed.connect(func(): _changer(champ, e["id"]); _remplir_en_gardant_le_defilement())
		grille.add_child(b)
	var nom := Label.new()
	nom.text = String(FichePersonnage.element(_catalogue, _liste_de(champ), fiche.get(champ, "")).get("nom", ""))
	nom.modulate.a = 0.7
	_contenu.add_child(nom)


func _liste_de(champ: String) -> String:
	return {"peau": "peaux", "couleur_yeux": "couleurs_yeux", "couleur_cheveux": "couleurs_cheveux"}.get(champ, champ)


func _remplir_en_gardant_le_defilement() -> void:
	var position_defilement := _defilement.scroll_vertical
	_remplir()
	await get_tree().process_frame
	_defilement.scroll_vertical = position_defilement


## Un curseur relié à fiche[section][id].
func _curseur_fiche(section: String, curseur: Dictionary) -> void:
	var id: String = curseur["id"]
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 10)
	_contenu.add_child(ligne)
	var nom := Label.new()
	nom.text = String(curseur["nom"])
	nom.custom_minimum_size = Vector2(190, 0)
	ligne.add_child(nom)
	var gauche := Label.new()
	gauche.text = String(curseur.get("gauche", ""))
	gauche.modulate.a = 0.55
	gauche.custom_minimum_size = Vector2(70, 0)
	gauche.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gauche.add_theme_font_size_override("font_size", 12)
	ligne.add_child(gauche)
	var s := HSlider.new()
	s.min_value = float(curseur.get("min", -1.0))
	s.max_value = float(curseur.get("max", 1.0))
	s.step = float(curseur.get("pas", 0.05))
	s.value = float(fiche[section].get(id, 0.0))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.name = id
	ligne.add_child(s)
	var droite := Label.new()
	droite.text = String(curseur.get("droite", ""))
	if id == "taille_cm":
		droite.text = "%d cm" % int(s.value)
	droite.modulate.a = 0.55
	droite.custom_minimum_size = Vector2(70, 0)
	droite.add_theme_font_size_override("font_size", 12)
	ligne.add_child(droite)
	s.value_changed.connect(func(v):
		fiche[section][id] = v
		if id == "taille_cm":
			droite.text = "%d cm" % int(v)
		_actualiser_apercu())
