extends SceneTree
## Test automatique de Pompéi sous la cendre (Rome, zone 4) et du chapitre 6 : Pline, les
## pilleurs, la descente dans la maison de Caecilia, la marque de la Vigie, la secousse,
## le matériel de Damien Roche, Masque, Vera, et la route du retour vers la voie Appienne.
## Lancement : godot --headless --path game -s res://tests/test_pompei.gd

const FICHIER := "user://test_rome_pompei.cfg"
var SCENE := "res://scenes/monde/rome/pompei.tscn"

var _echecs := 0
var _scene: Node
var _joueur
var _quete
var _dialogue


func _verifier(condition: bool, message: String) -> void:
	if condition:
		print("  OK   ", message)
	else:
		print("  ÉCHEC ", message)
		_echecs += 1


func _attendre(images: int) -> void:
	for i in images:
		await physics_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _placer(position: Vector3, angle: float) -> void:
	_joueur.teleporter(position, angle)
	_joueur.camera.lacet = angle
	await _attendre(10)
	var images := 0
	while not _joueur.is_on_floor() and images < 120:
		images += 1
		await physics_frame
	await _attendre(3)


func _appuyer_f() -> void:
	var appui := InputEventAction.new()
	appui.action = "interagir"
	appui.pressed = true
	Input.parse_input_event(appui)
	await _attendre(3)
	var relache := InputEventAction.new()
	relache.action = "interagir"
	relache.pressed = false
	Input.parse_input_event(relache)
	await _attendre(2)


func _lire_dialogue() -> int:
	var lues := 0
	while _dialogue.est_ouvert() and lues < 30:
		lues += 1
		await _appuyer_f()
	return lues


func _aller_pres(cible: Node3D, decalage := Vector3(0, 0, 1.6)) -> void:
	var p: Vector3 = cible.global_position + decalage
	p.y = maxf(_scene.hauteur(p.x, p.z), cible.global_position.y) + 0.3
	await _placer(p, 0.0)


func _parler(id_noeud: String) -> int:
	var pnj = _scene.find_child(id_noeud, true, false)
	if pnj == null:
		print("  (PNJ introuvable : %s)" % id_noeud)
		return 0
	await _aller_pres(pnj)
	await _appuyer_f()
	return await _lire_dialogue()


func _id_etape() -> String:
	return _quete.etape_actuelle().get("id", "")


func _vivants(type: String) -> Array:
	var liste := []
	for bete in get_nodes_in_group("loups"):
		if String(bete.type_ennemi) == type and bete.combat.est_vivant():
			liste.append(bete)
	return liste


func _calmer_autour(p: Vector3, rayon: float) -> void:
	var combat_joueur = _joueur.get_node("Combat")
	for bete in get_nodes_in_group("loups"):
		if bete.combat.est_vivant() and bete.global_position.distance_to(p) < rayon:
			bete.combat.subir(999999.0, combat_joueur)


## Angle de caméra pour regarder dans la direction « d » (le nord est vers -Z).
func _angle_vers(d: Vector2) -> float:
	return atan2(-d.x, -d.y)


## Marche tout droit pendant « images » images et rend la plus grande hauteur atteinte.
func _marcher_et_mesurer(images: int) -> float:
	var y_max: float = _joueur.global_position.y
	Input.action_press("avancer")
	for i in images:
		await physics_frame
		if _joueur.is_on_floor():
			y_max = maxf(y_max, _joueur.global_position.y)
	Input.action_release("avancer")
	await _attendre(5)
	return y_max


func _charger() -> void:
	_scene = load(SCENE).instantiate()
	_quete = _scene.get_node("Quete")
	_quete.fichier_progression = FICHIER
	_quete.voyage_reel = false
	root.add_child(_scene)
	await _attendre(40)
	_joueur = get_first_node_in_group("joueur_local")
	_dialogue = get_first_node_in_group("dialogue")


func _utiliser(id_noeud: String, loin_de := Vector2.INF, attente := 20) -> void:
	var objet: Node3D = _scene.find_child(id_noeud, true, false)
	if objet == null:
		print("  (objet introuvable : %s)" % id_noeud)
		return
	var o := Vector2(objet.global_position.x, objet.global_position.z)
	var dir := Vector2(0, 1)
	if loin_de != Vector2.INF:
		dir = (o - loin_de).normalized()
	var p := o + dir * 1.3
	await _placer(Vector3(p.x, _scene.hauteur(p.x, p.y) + 0.4, p.y), _angle_vers(-dir))
	await _appuyer_f()
	await _attendre(attente)


func _resoudre_mots() -> void:
	await _attendre(3)
	var puzzle = _quete.puzzle_mots()
	_verifier(puzzle != null and puzzle.est_ouvert(), "la fenêtre des mots s'ouvre")
	if puzzle != null:
		puzzle.resoudre()
	await _attendre(60)


func _debut_chapitre(etape: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("rome", "etape", etape)
	cfg.save(FICHIER)
	await _charger()


func _lancer() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	await _debut_chapitre("vers_pompei")
	print("Test de Pompéi (chapitre 6)")

	# --- Le monde.
	_verifier(_joueur != null and _joueur.is_on_floor(), "on arrive par la route de Rome, au nord")
	var p: Vector3 = _joueur.global_position
	_verifier(Vector2(p.x, p.z).distance_to(_scene.ENTREE) < 10.0, "près de la porte ensevelie (%.0f, %.0f)" % [p.x, p.z])
	_verifier(_id_etape() == "rencontre_pline", "l'arrivée termine l'étape de la route (%s)" % _id_etape())
	for nom in ["ToitsEnsevelis", "Forum", "MaisonCaecilia", "FosseForum", "Amphitheatre", "Rempart", "Vesuve"]:
		_verifier(_scene.find_child(nom, true, false) != null, "Pompéi a son %s" % nom)
	var m: Vector2 = _scene.MAISON.get_center()
	_verifier(_scene.hauteur(m.x, m.y) < _scene.hauteur(m.x, _scene.MAISON.position.y - 16.0) - 4.0, "la maison est au fond d'une fouille")
	_verifier(_vivants("pilleur_cendre").size() >= 6, "des pilleurs fouillent la cendre (%d)" % _vivants("pilleur_cendre").size())

	# --- Chapitre 6.
	var combat_joueur = _joueur.get_node("Combat")
	var lues := await _parler("Pline")
	_verifier(lues >= 3, "Pline raconte son oncle (%d bulles)" % lues)
	_verifier(_id_etape() == "pilleurs_maison", "des pilleurs à chasser (%s)" % _id_etape())
	await _attendre(5)
	var pilleurs := _vivants("pilleur_cendre_maison")
	_verifier(pilleurs.size() == 3, "trois pilleurs à la maison de Caecilia (%d)" % pilleurs.size())
	if pilleurs.size() > 0:
		_verifier(pilleurs[0].get_node("Apparence").get("espece") == "oublie", "ce sont des hommes")
	for pi in pilleurs:
		pi.combat.subir(999999.0, combat_joueur)
	await _attendre(130)
	_verifier(_id_etape() == "descendre_maison", "les pilleurs ont fui (%s)" % _id_etape())
	# On descend vraiment la pente de cendre, à pied.
	_calmer_autour(Vector3(m.x, 0, m.y), 60.0)
	var haut: Vector2 = Vector2(m.x, _scene.MAISON.position.y - 12.0)
	await _placer(Vector3(haut.x, _scene.hauteur(haut.x, haut.y) + 0.4, haut.y), _angle_vers(Vector2(0, 1)))
	var y0: float = _joueur.global_position.y
	Input.action_press("avancer")
	await _attendre(150)
	Input.action_release("avancer")
	await _attendre(130)
	_verifier(_joueur.global_position.y < y0 - 4.0, "on descend à pied dans la fouille (%.1f → %.1f)" % [y0, _joueur.global_position.y])
	if _id_etape() == "descendre_maison":
		await _placer(Vector3(-37, _scene.hauteur(-37, -53) + 0.4, -53), 0.0)
		await _attendre(130)
	_verifier(_id_etape() == "marque_vigie", "on est dans la maison de Caecilia (%s)" % _id_etape())
	await _utiliser("MarqueVigie", Vector2(INF, INF), 130)
	_verifier(_id_etape() == "secousse", "Roche est passé par ici (%s)" % _id_etape())
	await _placer(Vector3(24, _scene.hauteur(24, -4) + 0.4, -4), 0.0)
	await _attendre(130)
	_verifier(_id_etape() == "materiel_roche", "la terre tremble (%s)" % _id_etape())
	await _utiliser("MaterielRoche", Vector2(INF, INF), 330)
	_verifier(_id_etape() == "verite_masque", "l'enregistrement de Janus (%s)" % _id_etape())
	var masque: Node3D = _scene.find_child("MasquePompei", true, false)
	_verifier(masque != null and masque.visible, "Masque est là")
	lues = await _parler("MasquePompei")
	_verifier(lues >= 3, "Masque comprend qu'on lui a menti (%d bulles)" % lues)
	await _attendre(10)
	_verifier(_id_etape() == "vera_pompei", "Vera regardait (%s)" % _id_etape())
	_verifier(not masque.visible, "Masque est reparti")
	lues = await _parler("VeraPompei")
	_verifier(lues >= 3, "Vera prête sa fréquence (%d bulles)" % lues)
	await _attendre(30)
	_verifier(_id_etape() == "retour_pline", "Pline attend au Forum (%s)" % _id_etape())
	lues = await _parler("Pline")
	_verifier(lues >= 3, "Pline donne ses tablettes (%d bulles)" % lues)
	var inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("tablettes_pline") >= 1, "les tablettes de Pline sont dans le sac")
		_verifier(inventaire.quantite("enregistreur_roche") >= 1, "et l'enregistreur de Roche")
	_verifier(_quete.etape < 0, "chapitre 6 terminé (fin provisoire)")

	# --- La progression est gardée.
	_scene.queue_free()
	await _attendre(5)
	await _charger()
	_verifier(not _scene.find_child("MasquePompei", true, false).visible, "au retour, Masque n'est plus là")
	_verifier(not _scene.find_child("VeraPompei", true, false).visible, "ni Vera")
	_verifier(not _scene.find_child("MaterielRoche", true, false).actif, "le sac est ramassé")
	# Retour vers la voie Appienne, au nord.
	var s: Vector2 = _scene.SORTIE_NORD
	await _placer(Vector3(s.x, _scene.hauteur(s.x, s.y + 10) + 0.4, s.y + 10), 0.0)
	Input.action_press("avancer")
	await _attendre(120)
	Input.action_release("avancer")
	_verifier(_quete.zone_demandee == "voie_appienne", "la route du nord ramène à la voie Appienne (%s)" % _quete.zone_demandee)

	# --- Sur la voie Appienne, la route du sud mène à Pompéi.
	_scene.queue_free()
	await _attendre(5)
	SCENE = "res://scenes/monde/rome/voie_appienne.tscn"
	await _charger()
	var sud: Vector2 = _scene.SORTIE_SUD
	await _placer(Vector3(sud.x, _scene.hauteur(sud.x, sud.y - 14) + 0.4, sud.y - 14), PI)
	Input.action_press("avancer")
	await _attendre(200)
	Input.action_release("avancer")
	_verifier(_quete.zone_demandee == "pompei", "la voie Appienne mène à Pompéi, au sud (%s)" % _quete.zone_demandee)

	print("")
	if _echecs == 0:
		print("TOUS LES TESTS PASSENT")
	else:
		print("%d ÉCHEC(S)" % _echecs)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	quit(1 if _echecs > 0 else 0)
