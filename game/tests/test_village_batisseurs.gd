extends SceneTree
## Test automatique du chapitre 4 de l'Égypte : la rampe du port qui s'ouvre, puis le
## Village des Bâtisseurs (Pésèshet, les ouvriers sans nom, Nebi, les amulettes, le
## cimetière) et les deux branches du choix : briser les amulettes ou les échanger.
## Lancement : godot --headless --path game -s res://tests/test_village_batisseurs.gd

const FICHIER := "user://test_egypte_progression.cfg"
const PORT := "res://scenes/monde/egypte/port_des_marais.tscn"
const VILLAGE := "res://scenes/monde/egypte/village_batisseurs.tscn"

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
	# Dans l'eau, le sol est plus bas que la surface : on attend qu'il ait pied.
	var images := 0
	while not _joueur.is_on_floor() and images < 90:
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


func _aller_pres(cible: Node3D) -> void:
	var p: Vector3 = cible.global_position + Vector3(0, 0, 1.6)
	p.y = maxf(_scene.hauteur(p.x, p.z), cible.global_position.y) + 0.3
	await _placer(p, 0.0)


func _parler(id_noeud: String) -> int:
	var pnj = _scene.find_child(id_noeud, true, false)
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


func _charger(scene: String) -> void:
	if _scene != null and is_instance_valid(_scene):
		_scene.queue_free()
		await _attendre(5)
	_scene = load(scene).instantiate()
	_quete = _scene.get_node("Quete")
	_quete.fichier_progression = FICHIER
	_quete.voyage_reel = false
	root.add_child(_scene)
	await _attendre(40)
	_joueur = get_first_node_in_group("joueur_local")
	_dialogue = get_first_node_in_group("dialogue")


func _utiliser(nom: String, attente: int) -> void:
	var o = _scene.find_child(nom, true, false)
	await _placer(o.global_position + Vector3(0, 0.5, 1.1), 0.0)
	await _appuyer_f()
	await _attendre(attente)


func _reprendre_a(etape: String, choix := "") -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("egypte", "etape", etape)
	if choix != "":
		cfg.set_value("egypte", "choix_choix_amulettes", choix)
	cfg.save(FICHIER)


func _lancer() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Test du chapitre 4 (Égypte) : le Village des Bâtisseurs")
	# --- La rampe du port : fermée avant le chapitre 4, ouverte ensuite.
	_reprendre_a("fin_chapitre_3")
	await _charger(PORT)
	await _attendre(30)
	_verifier(_scene.get("_mur_rampe") != null and is_instance_valid(_scene.get("_mur_rampe")), "avant le chapitre 4, la rampe du plateau est fermée")
	_reprendre_a("vers_village")
	await _charger(PORT)
	await _attendre(30)
	_verifier(_id_etape() == "vers_village", "la quête reprend au chapitre 4 (%s)" % _id_etape())
	_verifier(not is_instance_valid(_scene.get("_mur_rampe")), "la rampe du plateau est ouverte")
	var rampe: Vector2 = _scene.RAMPE + Vector2(-9, -9)
	await _placer(Vector3(rampe.x, _scene.hauteur(rampe.x, rampe.y) + 0.5, rampe.y), PI * 0.75)
	await _attendre(90)
	_verifier(_quete.zone_demandee == "village_batisseurs", "en haut de la rampe, on part au village (%s)" % _quete.zone_demandee)

	# --- Le village.
	await _charger(VILLAGE)
	_verifier(_joueur != null and _joueur.is_on_floor(), "on arrive au village par la route du port")
	_verifier(_id_etape() == "parler_pesechet", "l'arrivée au village termine l'étape (%s)" % _id_etape())
	_verifier(_scene.hauteur(0, -100) > _scene.hauteur(14, 44) + 8.0, "le chantier est sur le plateau, au-dessus du village")
	_verifier(_scene.hauteur(0, 135) < 0.0, "le canal du port passe au sud")
	_verifier(_scene.find_child("MurDuCorbeau", true, false) != null, "le mur du Corbeau ferme la ville")
	_verifier(_scene.find_child("GrandePyramide", true, false) != null, "la Grande Pyramide domine le plateau")
	_verifier(_vivants("chacal_fracture").size() >= 4, "des chacals fracturés rôdent dans le désert")
	var chacal = _vivants("chacal_fracture")[0] if not _vivants("chacal_fracture").is_empty() else null
	_verifier(chacal != null and absf(chacal.get_node("Apparence").scale.x - 0.72) < 0.01, "les chacals sont plus petits que les loups")
	# On passe la porte du mur et on monte au chantier.
	await _placer(Vector3(1, _scene.hauteur(1, 8) + 0.5, 8), 0.0)
	Input.action_press("avancer")
	await _attendre(600)
	Input.action_release("avancer")
	await _attendre(5)
	_verifier(_joueur.global_position.z < -30.0 and _joueur.global_position.y > 8.0,
			"on passe la porte du mur et on monte au plateau (z = %.0f, y = %.1f)" % [_joueur.global_position.z, _joueur.global_position.y])

	var lues := await _parler("Pesechet")
	_verifier(lues >= 3, "Pésèshet parle des ouvriers sans nom (%d bulles)" % lues)
	_verifier(_id_etape() == "examiner", "il faut examiner les malades (%s)" % _id_etape())
	var allonge = _scene.find_child("OuvrierAmnesique1", true, false)
	_verifier(allonge != null and allonge.blesse, "les malades sont allongés sur des nattes")
	for k in 3:
		await _utiliser("Examiner%d" % k, 150)
	_verifier(_id_etape() == "retour_pesechet", "les trois malades sont examinés (%s)" % _id_etape())
	await _parler("Pesechet")
	lues = await _parler("Nebi")
	_verifier(lues >= 4, "Nebi raconte la prêtresse de Memphis (%d bulles)" % lues)
	_verifier(_id_etape() == "amulettes", "il faut ramasser les amulettes (%s)" % _id_etape())
	for k in 3:
		await _utiliser("Amulette%d" % k, 120)
	_verifier(_id_etape() == "cimetiere", "les amulettes sont ramassées (%s)" % _id_etape())
	await _attendre(5)
	var oublies := _vivants("oublie_village")
	_verifier(oublies.size() == 2, "deux bâtisseurs oubliés errent au cimetière (%d)" % oublies.size())
	var combat_joueur = _joueur.get_node("Combat")
	for o in oublies:
		o.combat.subir(99999.0, combat_joueur)
	await _attendre(30)
	for k in 2:
		var obj = _scene.find_child("RendreNom%d" % k, true, false)
		_verifier(obj != null, "on peut rendre son nom au bâtisseur %d" % (k + 1))
		if obj != null:
			await _placer(obj.global_position + Vector3(0, 0.5, 1.2), 0.0)
			await _appuyer_f()
			await _attendre(170)
	_verifier(_id_etape() == "retour_nebi", "Kaï et Hétépi retrouvent leur nom (%s)" % _id_etape())
	await _attendre(10)
	_verifier(_scene.find_child("BatisseurKai", true, false) != null, "Kaï se relève, guéri")
	var inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("amulette_sablier") >= 5, "les amulettes de la prêtresse sont dans le sac")
	await _parler("Nebi")
	_verifier(_id_etape() == "choix_amulettes", "Nebi propose le choix (%s)" % _id_etape())

	# --- Branche 1 : briser les amulettes sur la pierre de la place.
	await _utiliser("BriserAmulettes", 220)
	lues = await _lire_dialogue()
	await _attendre(10)
	_verifier(_id_etape() == "chacals", "les amulettes brisées, des chacals surgissent (%s)" % _id_etape())
	var chacals := []
	for c in _vivants("chacal_fracture"):
		if Vector2(c.global_position.x, c.global_position.z).distance_to(_scene.PLACE) < 25.0:
			chacals.append(c)
	_verifier(chacals.size() == 4, "quatre chacals sur la place (%d)" % chacals.size())
	for c in chacals:
		c.combat.subir(99999.0, combat_joueur)
	await _attendre(20)
	_verifier(_id_etape() == "calmer", "les chacals sont chassés (%s)" % _id_etape())
	await _parler("Ouni")
	_verifier(_id_etape() == "fin_chapitre_4", "la branche « échanger » est sautée (%s)" % _id_etape())
	lues = await _parler("Pesechet")
	_verifier(lues >= 4, "Pésèshet remercie et parle de l'ouest (%d bulles)" % lues)
	_verifier(_quete.etape < 0, "chapitre 4 terminé")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("oudjat_peseshet") >= 1, "l'œil oudjat de Pésèshet est dans le sac")

	# --- On revient plus tard : les malades sont debout, les bâtisseurs sur la place.
	await _charger(VILLAGE)
	await _attendre(10)
	_verifier(_quete.etape < 0, "la quête reprend où on l'avait laissée")
	_verifier(_scene.find_child("BatisseurHetepi", true, false) != null, "Hétépi est sur la place")
	allonge = _scene.find_child("OuvrierAmnesique1", true, false)
	_verifier(allonge != null and not allonge.blesse, "les malades sont debout")
	_verifier(_vivants("oublie_village").is_empty(), "les oubliés ne reviennent pas")

	# --- Branche 2 : échanger les amulettes en secret.
	_reprendre_a("choix_amulettes")
	await _charger(VILLAGE)
	_verifier(_id_etape() == "choix_amulettes", "on reprend au choix (%s)" % _id_etape())
	await _utiliser("EchangerAmulettes", 150)
	lues = await _lire_dialogue()
	await _attendre(10)
	_verifier(lues >= 2, "Méret accepte d'aider (%d bulles)" % lues)
	_verifier(_id_etape() == "parler_ouni", "la branche « briser » est sautée (%s)" % _id_etape())
	await _parler("Ouni")
	_verifier(_id_etape() == "faience_ouni", "Ouni donne ses paniers d'amulettes (%s)" % _id_etape())
	for k in 4:
		await _utiliser("Panier%d" % k, 100)
	_verifier(_id_etape() == "echange_dortoirs", "les paniers sont pris (%s)" % _id_etape())
	await _utiliser("DortoirEchange", 420)
	_verifier(_id_etape() == "fin_chapitre_4", "les amulettes sont échangées en secret (%s)" % _id_etape())
	await _parler("Pesechet")
	_verifier(_quete.etape < 0, "chapitre 4 terminé par l'autre chemin")

	# --- La route ramène au Port des Marais.
	var entree: Vector2 = _scene.ENTREE + Vector2(6, 0)
	await _placer(Vector3(entree.x, _scene.hauteur(entree.x, entree.y) + 0.5, entree.y), -PI / 2)
	await _attendre(90)
	_verifier(_quete.zone_demandee == "port_des_marais", "la route de l'est ramène au port (%s)" % _quete.zone_demandee)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
