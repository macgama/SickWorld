extends Node
## Cinématiques de l'île : de courts films joués avec le moteur du jeu.
##
## La caméra se détache du personnage et suit des « plans » (un mouvement de
## caméra, un texte ou une réplique), avec des bandes noires en haut et en bas.
## Espace ou Échap passe la cinématique. Pendant ce temps, le personnage ne
## bouge pas et les ennemis attendent.
##
## Chaque cinématique se joue une seule fois par personnage (gardé dans la
## section « cinematiques » de user://progression.cfg). Elle se déclenche :
## - « arrivee » : en arrivant dans une zone (avant le titre de la zone) ;
## - « etape » : quand une étape de la quête principale commence.
##
## Tout le contenu (plans, textes, positions) vient de data/cinematiques.json.
## Ce nœud est créé par la quête de l'île (quete.gd).

signal commencee(id: String)
signal terminee(id: String)

const DONNEES := "res://data/cinematiques.json"
const GROUPE_EN_COURS := "cinematique_en_cours"
const OR := Color(1.0, 0.82, 0.35)
## Hauteur des bandes noires (part de l'écran, en haut et en bas).
const BANDES := 0.13
## Calque de rendu où l'on range, le temps du film, ce que la caméra de cinéma
## ne doit pas voir (noms au-dessus des têtes, faisceau de l'objectif).
const CALQUE_CACHE := 1 << 19

## Faux : les cinématiques ne se jouent jamais (tests, multijoueur).
var actif := true
## Toutes les cinématiques du fichier de données.
var toutes: Array = []
## Identifiant de la cinématique en cours ("" : aucune).
var en_cours := ""
## Numéro du plan affiché.
var plan := -1

var _quete: Node
var _file: Array = []
var _cinema: Dictionary = {}
var _suite := Callable()
var _temps_plan := 0.0
var _camera: Camera3D
var _camera_avant: Camera3D
var _calques_caches: Array[CanvasLayer] = []
var _dossiers_figes: Array = []
var _rendus_caches: Array = []
var _fin_demandee := false

var _ecran: CanvasLayer
var _bande_haut: ColorRect
var _bande_bas: ColorRect
var _noir: ColorRect
var _titre: Label
var _sous_titre: Label
var _nom: Label
var _texte: Label
var _aide: Label


func _ready() -> void:
	_quete = get_parent()
	var lu = JSON.parse_string(FileAccess.get_file_as_string(DONNEES))
	if lu is Dictionary:
		toutes = lu.get("cinematiques", [])
	else:
		push_error("Impossible de lire %s : vérifie les virgules et les guillemets." % DONNEES)
	# Pas de cinématique sans écran (tests), ni à plusieurs (chacun son rythme).
	actif = DisplayServer.get_name() != "headless" and Reseau.mode == Reseau.Mode.SEUL \
			and bool(_quete.get("voyage_reel"))
	if _quete.has_signal("etape_changee"):
		_quete.etape_changee.connect(_sur_etape)
	_construire_ecran()
	set_process(false)


# --- Déclencheurs -----------------------------------------------------------------

## Appelé par la quête en arrivant dans une zone. Si une cinématique d'arrivée
## doit se jouer, elle se joue et « suite » est appelée à la fin (le titre de la
## zone) ; renvoie alors vrai.
func lancer_arrivee(zone: String, suite: Callable) -> bool:
	for c in toutes:
		if c.get("declencheur", "") == "arrivee" and c.get("zone", "") == zone and _peut_jouer(c):
			jouer(c.get("id", ""), suite)
			return true
	return false


func _sur_etape(id: String) -> void:
	if id == "":
		return
	for c in toutes:
		if c.get("declencheur", "") == "etape" and c.get("etape", "") == id \
				and c.get("zone", _zone()) == _zone() and _peut_jouer(c):
			jouer.call_deferred(c.get("id", ""))


func _peut_jouer(c: Dictionary) -> bool:
	return actif and not deja_vue(c.get("id", "")) and c.get("ile", _ile()) == _ile()


func _zone() -> String:
	var ile := get_tree().get_first_node_in_group("ile")
	return String(ile.get("identifiant_zone")) if ile != null else ""


func _ile() -> String:
	return String(_quete.get("ile")) if _quete.get("ile") != null else ""


# --- Progression ---------------------------------------------------------------

func _fichier() -> String:
	var f = _quete.get("fichier_progression")
	return Profil.chemin(String(f) if f != null else "user://progression.cfg")


func deja_vue(id: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(_fichier()) != OK:
		return false
	return bool(cfg.get_value("cinematiques", id, false))


func _marquer_vue(id: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(_fichier())
	cfg.set_value("cinematiques", id, true)
	cfg.save(_fichier())


## Les cinématiques de cette zone (pour les revoir depuis le menu).
func cinematiques_de_la_zone() -> Array:
	var liste := []
	for c in toutes:
		if c.get("ile", _ile()) == _ile() and c.get("zone", _zone()) == _zone():
			liste.append(c)
	return liste


# --- Lecture ------------------------------------------------------------------------

func est_en_cours() -> bool:
	return en_cours != ""


## Joue la cinématique « id ». « suite » est appelée quand elle est finie (ou passée).
func jouer(id: String, suite := Callable()) -> void:
	var c := _trouver(id)
	if c.is_empty():
		if suite.is_valid():
			suite.call()
		return
	if est_en_cours():
		if id != en_cours and not _file.has(id):
			_file.append(id)
		return
	en_cours = id
	_cinema = c
	_suite = suite
	_fin_demandee = false
	_marquer_vue(id)
	add_to_group(GROUPE_EN_COURS)
	# Le jeu se met en retrait : interface cachée, ennemis figés, caméra de cinéma.
	_calques_caches.clear()
	for calque in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if calque != _ecran and calque.visible:
			calque.visible = false
			_calques_caches.append(calque)
	_dossiers_figes.clear()
	for dossier in get_tree().get_nodes_in_group("dossier_loups"):
		_dossiers_figes.append([dossier, dossier.process_mode])
		dossier.process_mode = Node.PROCESS_MODE_DISABLED
	_rendus_caches.clear()
	var scene := get_tree().current_scene if get_tree().current_scene != null else _quete.get_parent()
	var a_cacher: Array = scene.find_children("*", "Label3D", true, false)
	for repere in scene.find_children("Repere*", "Node3D", true, false):
		a_cacher.append_array(repere.find_children("*", "GeometryInstance3D", true, false))
	for n in a_cacher:
		_rendus_caches.append([n, n.layers])
		n.layers = CALQUE_CACHE
	_camera_avant = get_viewport().get_camera_3d()
	_camera = Camera3D.new()
	_camera.name = "CameraCinematique"
	_camera.far = 4000.0
	_camera.fov = 55.0
	_camera.cull_mask = 0xFFFFF & ~CALQUE_CACHE
	add_child(_camera)
	_camera.make_current()
	_ecran.visible = true
	_noir.color.a = 1.0
	_titre.modulate.a = 0.0
	_sous_titre.modulate.a = 0.0
	_nom.text = ""
	_texte.text = ""
	_aide.modulate.a = 0.0
	_bande_haut.anchor_bottom = 0.0
	_bande_bas.anchor_top = 1.0
	var bandes := create_tween().set_trans(Tween.TRANS_SINE)
	bandes.tween_property(_bande_haut, "anchor_bottom", BANDES, 0.8)
	bandes.parallel().tween_property(_bande_bas, "anchor_top", 1.0 - BANDES, 0.8)
	bandes.tween_property(_aide, "modulate:a", 0.75, 0.6).set_delay(1.0)
	commencee.emit(id)
	_commencer_plan(0)
	set_process(true)


func _trouver(id: String) -> Dictionary:
	for c in toutes:
		if c.get("id", "") == id:
			return c
	return {}


func _plans() -> Array:
	return _cinema.get("plans", [])


func _commencer_plan(numero: int) -> void:
	plan = numero
	_temps_plan = 0.0
	var p: Dictionary = _plans()[plan]
	_placer_camera(p, 0.0)
	# Fondu au noir : au début de la cinématique, et quand le plan le demande.
	if plan == 0 or p.get("fondu", false):
		_noir.color.a = 1.0
		create_tween().tween_property(_noir, "color:a", 0.0, float(p.get("duree_fondu", 1.2)))
	else:
		_noir.color.a = 0.0
	# Grand titre (nom de l'époque, d'un personnage…).
	_titre.text = p.get("titre", "")
	_sous_titre.text = p.get("sous_titre", "")
	if _titre.text != "" or _sous_titre.text != "":
		var t := create_tween()
		t.tween_property(_titre, "modulate:a", 1.0, 1.0).set_delay(0.4)
		t.parallel().tween_property(_sous_titre, "modulate:a", 1.0, 1.0).set_delay(0.9)
		t.tween_interval(maxf(0.5, float(p.get("duree", 5.0)) - 3.2))
		t.tween_property(_titre, "modulate:a", 0.0, 0.8)
		t.parallel().tween_property(_sous_titre, "modulate:a", 0.0, 0.8)
	# Réplique (avec un nom) ou narration (sans nom), en bas de l'écran.
	_nom.text = String(p.get("nom", "")).to_upper()
	_texte.text = p.get("texte", "")
	_texte.add_theme_color_override("font_color",
			Color(1, 1, 1) if _nom.text != "" else Color(0.82, 0.82, 0.88))
	_nom.modulate.a = 0.0
	_texte.modulate.a = 0.0
	if _texte.text != "":
		var s := create_tween()
		s.tween_property(_nom, "modulate:a", 1.0, 0.4).set_delay(0.3)
		s.parallel().tween_property(_texte, "modulate:a", 1.0, 0.5).set_delay(0.3)


func _process(delta: float) -> void:
	if not est_en_cours() or _fin_demandee:
		return
	_temps_plan += delta
	var p: Dictionary = _plans()[plan]
	var duree := float(p.get("duree", 5.0))
	_placer_camera(p, clampf(_temps_plan / duree, 0.0, 1.0))
	# Le texte s'efface juste avant la fin du plan.
	if _texte.text != "" and _temps_plan > duree - 0.45 and _texte.modulate.a > 0.99:
		var s := create_tween()
		s.tween_property(_nom, "modulate:a", 0.0, 0.35)
		s.parallel().tween_property(_texte, "modulate:a", 0.0, 0.35)
	if _temps_plan >= duree:
		if plan + 1 < _plans().size():
			_commencer_plan(plan + 1)
		else:
			_finir()


## Place la caméra le long du plan (avancement de 0 à 1, adouci au début et à la fin).
func _placer_camera(p: Dictionary, avancement: float) -> void:
	var a := smoothstep(0.0, 1.0, avancement) if p.get("adoucir", true) else avancement
	var positions = p.get("camera", [[0, 3, 0]])
	var regards = p.get("regard", "joueur")
	var de := _point(positions[0] if positions is Array and positions.size() > 0 and positions[0] is Array else positions)
	var vers := _point(positions[1]) if positions is Array and positions.size() > 1 and positions[1] is Array else de
	var position := de.lerp(vers, a)
	var cible: Vector3
	if regards is Array and regards.size() > 1 and not (regards[0] is float or regards[0] is int):
		cible = _point(regards[0]).lerp(_point(regards[1]), a)
	else:
		cible = _point(regards)
	var fovs = p.get("fov", 55.0)
	_camera.fov = lerpf(float(fovs[0]), float(fovs[1]), a) if fovs is Array else float(fovs)
	_camera.global_position = position
	if not position.is_equal_approx(cible):
		var haut := Vector3.UP if absf((cible - position).normalized().y) < 0.99 else Vector3.FORWARD
		_camera.look_at(cible, haut)


## Un point de la cinématique : [x, hauteur au-dessus du sol, z], ou « joueur »,
## « pnj:<id> », « ennemi:<type> », « objet:<id> », « decor:<id> » (suivis s'ils bougent).
func _point(valeur) -> Vector3:
	if valeur is Array and valeur.size() >= 3:
		var x := float(valeur[0])
		var z := float(valeur[2])
		var y := float(valeur[1])
		if _cinema.get("hauteurs", "sol") == "sol":
			y += _sol(x, z)
		return Vector3(x, y, z)
	var texte := String(valeur)
	var n: Node3D = null
	var dessus := 1.5
	if texte == "joueur":
		n = get_tree().get_first_node_in_group("joueur_local") as Node3D
	elif texte.begins_with("pnj:"):
		for pnj in get_tree().get_nodes_in_group("pnj"):
			if pnj.get("identifiant") == texte.substr(4) and pnj is Node3D:
				n = pnj
				break
	elif texte.begins_with("ennemi:"):
		dessus = 1.1
		var type := texte.substr(7)
		for dossier in get_tree().get_nodes_in_group("dossier_loups"):
			for e in dossier.get_children():
				if e is Node3D and e.get("type_ennemi") == type:
					n = e
					break
	elif texte.begins_with("objet:"):
		dessus = 0.2
		for o in get_tree().get_nodes_in_group("objet_quete"):
			if o.get("identifiant") == texte.substr(6) and o is Node3D:
				n = o
				break
	elif texte.begins_with("decor:"):
		dessus = 0.5
		for d in get_tree().get_nodes_in_group("decor_quete"):
			if d.get_meta("identifiant", "") == texte.substr(6) and d is Node3D:
				n = d
				break
	if n == null:
		var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
		return joueur.global_position + Vector3.UP * 1.5 if joueur != null else Vector3.ZERO
	return n.global_position + Vector3.UP * dessus


## Hauteur du sol (ou de l'eau) à cet endroit de la zone.
func _sol(x: float, z: float) -> float:
	var ile := get_tree().get_first_node_in_group("ile")
	if ile == null or not ile.has_method("hauteur"):
		return 0.0
	var h := float(ile.hauteur(x, z))
	if _cinema.get("eau", true):
		h = maxf(h, 0.0)
	return h


# --- Fin ---------------------------------------------------------------------------------

func passer() -> void:
	if est_en_cours() and not _fin_demandee:
		_finir()


func _finir() -> void:
	_fin_demandee = true
	var anim := create_tween()
	anim.tween_property(_noir, "color:a", 1.0, 0.6)
	anim.parallel().tween_property(_nom, "modulate:a", 0.0, 0.3)
	anim.parallel().tween_property(_texte, "modulate:a", 0.0, 0.3)
	anim.parallel().tween_property(_titre, "modulate:a", 0.0, 0.3)
	anim.parallel().tween_property(_sous_titre, "modulate:a", 0.0, 0.3)
	anim.parallel().tween_property(_aide, "modulate:a", 0.0, 0.3)
	anim.tween_callback(_rendre_la_main)


func _rendre_la_main() -> void:
	var id := en_cours
	var suite := _suite
	if is_instance_valid(_camera_avant):
		_camera_avant.make_current()
	if is_instance_valid(_camera):
		_camera.queue_free()
	_camera = null
	for calque in _calques_caches:
		if is_instance_valid(calque):
			calque.visible = true
	_calques_caches.clear()
	for d in _dossiers_figes:
		if is_instance_valid(d[0]):
			d[0].process_mode = d[1]
	_dossiers_figes.clear()
	for r in _rendus_caches:
		if is_instance_valid(r[0]):
			r[0].layers = r[1]
	_rendus_caches.clear()
	remove_from_group(GROUPE_EN_COURS)
	en_cours = ""
	plan = -1
	_cinema = {}
	_suite = Callable()
	set_process(false)
	# Les bandes s'en vont pendant que l'image revient.
	var anim := create_tween()
	anim.tween_property(_bande_haut, "anchor_bottom", 0.0, 0.6)
	anim.parallel().tween_property(_bande_bas, "anchor_top", 1.0, 0.6)
	if suite.is_valid():
		# La suite (titre de la zone) commence sur un écran noir : on s'efface d'un coup.
		_noir.color.a = 0.0
		suite.call()
	else:
		anim.parallel().tween_property(_noir, "color:a", 0.0, 0.8)
	anim.tween_callback(func():
		if not est_en_cours():
			_ecran.visible = false)
	terminee.emit(id)
	if not _file.is_empty():
		jouer(_file.pop_front())


func _input(event: InputEvent) -> void:
	if not est_en_cours():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var touche := (event as InputEventKey).keycode
		if touche == KEY_SPACE or touche == KEY_ESCAPE or event.is_action("annuler"):
			passer()
	# Rien d'autre ne passe pendant la cinématique (ni déplacement, ni compétence).
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()


# --- Interface ---------------------------------------------------------------------------

func _construire_ecran() -> void:
	_ecran = CanvasLayer.new()
	_ecran.name = "EcranCinematique"
	_ecran.layer = 40
	add_child(_ecran)
	_noir = _rect(Color(0, 0, 0, 0))
	_noir.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bande_haut = _rect(Color.BLACK)
	_bande_haut.anchor_right = 1.0
	_bande_haut.anchor_bottom = 0.0
	_bande_bas = _rect(Color.BLACK)
	_bande_bas.anchor_top = 1.0
	_bande_bas.anchor_right = 1.0
	_bande_bas.anchor_bottom = 1.0
	_titre = _etiquette(52, Color(1, 1, 1))
	_titre.anchor_left = 0.1
	_titre.anchor_right = 0.9
	_titre.anchor_top = 0.17
	_titre.anchor_bottom = 0.27
	_titre.add_theme_constant_override("outline_size", 8)
	_titre.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_sous_titre = _etiquette(22, OR)
	_sous_titre.anchor_left = 0.1
	_sous_titre.anchor_right = 0.9
	_sous_titre.anchor_top = 0.27
	_sous_titre.anchor_bottom = 0.33
	_sous_titre.add_theme_constant_override("outline_size", 6)
	_sous_titre.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	# Répliques : dans la bande du bas, comme des sous-titres de film.
	_nom = _etiquette(17, OR)
	_nom.anchor_left = 0.15
	_nom.anchor_right = 0.85
	_nom.anchor_top = 0.872
	_nom.anchor_bottom = 0.902
	_texte = _etiquette(20, Color(1, 1, 1))
	_texte.anchor_left = 0.1
	_texte.anchor_right = 0.9
	_texte.anchor_top = 0.902
	_texte.anchor_bottom = 0.995
	_texte.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_texte.add_theme_constant_override("outline_size", 5)
	_texte.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_aide = _etiquette(13, Color(0.75, 0.75, 0.8))
	_aide.text = "Espace : passer"
	_aide.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_aide.anchor_left = 0.6
	_aide.anchor_right = 0.98
	_aide.anchor_top = 0.04
	_aide.anchor_bottom = 0.09
	_ecran.visible = false


func _rect(couleur: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = couleur
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.offset_left = 0
	r.offset_right = 0
	r.offset_top = 0
	r.offset_bottom = 0
	_ecran.add_child(r)
	return r


func _etiquette(taille: int, couleur: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.offset_left = 0
	l.offset_right = 0
	l.offset_top = 0
	l.offset_bottom = 0
	_ecran.add_child(l)
	return l
