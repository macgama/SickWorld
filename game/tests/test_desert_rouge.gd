extends SceneTree
## Test automatique du chapitre 5 de l'Égypte : la passe des tombes, le Désert Rouge
## (les traces, les gardes, Vera Lind et le choix de la réponse, sa fuite, le carnet,
## Lenoir), puis le retour au QG par le portail qui lance la mission « carnet » du hub.
## Lancement : godot --headless --path game -s res://tests/test_desert_rouge.gd

const FICHIER := "user://test_egypte_progression.cfg"
const PORT := "res://scenes/monde/egypte/port_des_marais.tscn"
const VILLAGE := "res://scenes/monde/egypte/village_batisseurs.tscn"
const DESERT := "res://scenes/monde/egypte/desert_rouge.tscn"

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


func _tuer_tous(type: String) -> void:
	var combat_joueur = _joueur.get_node("Combat")
	for b in _vivants(type):
		b.combat.subir(99999.0, combat_joueur)
	await _attendre(20)


func _lancer() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Test du chapitre 5 (Égypte) : le Désert Rouge")
	# --- La passe des tombes, à l'ouest du village.
	_reprendre_a("vers_desert")
	await _charger(VILLAGE)
	_verifier(_id_etape() == "vers_desert", "la quête reprend au chapitre 5 (%s)" % _id_etape())
	var passe: Vector2 = _scene.PASSE_TOMBES + Vector2(-3, 0)
	await _placer(Vector3(passe.x, _scene.hauteur(passe.x, passe.y) + 0.5, passe.y), PI / 2)
	await _attendre(90)
	_verifier(_quete.zone_demandee == "desert_rouge", "la passe des tombes mène au désert (%s)" % _quete.zone_demandee)

	# --- Le désert.
	await _charger(DESERT)
	_verifier(_joueur != null and _joueur.is_on_floor(), "on arrive dans le Désert Rouge")
	_verifier(_id_etape() == "traces", "l'arrivée termine l'étape (%s)" % _id_etape())
	_verifier(_scene.find_child("Mastabas", true, false).get_child_count() > 20, "le cimetière des nobles est plein de mastabas")
	_verifier(_scene.hauteur(10, 92) < _scene.hauteur(10, 70) - 1.5, "l'ouadi est creusé dans le sable")
	_verifier(_scene.hauteur(-80, -70) > _scene.hauteur(20, -64) + 2.0, "le repaire est sur un éperon rocheux")
	_verifier(_vivants("garde_effaceuse_camp").size() >= 2, "des gardes de l'Effaceuse patrouillent")
	var garde = _vivants("garde_effaceuse_camp")[0] if not _vivants("garde_effaceuse_camp").is_empty() else null
	_verifier(garde != null and garde.get_node("Apparence").get("_delegue") != null \
			and garde.get_node("Apparence")._delegue.variante == "garde", "les gardes sont des hommes armés")
	for k in 3:
		await _utiliser("Trace%d" % k, 140)
	_verifier(_id_etape() == "gardes", "les traces mènent au repaire (%s)" % _id_etape())
	await _attendre(5)
	_verifier(_vivants("garde_effaceuse").size() == 4, "quatre gardes protègent la tombe (%d)" % _vivants("garde_effaceuse").size())
	await _tuer_tous("garde_effaceuse")
	_verifier(_id_etape() == "vera", "les gardes sont tombés (%s)" % _id_etape())
	# On monte la rampe jusqu'à la cour.
	await _placer(Vector3(-50, _scene.hauteur(-50, -70) + 0.5, -70), PI / 2)
	Input.action_press("avancer")
	await _attendre(150)
	Input.action_release("avancer")
	await _attendre(5)
	_verifier(_joueur.global_position.x < -66.0 and _joueur.global_position.y > _scene.H_REPAIRE - 1.0,
			"la rampe monte jusqu'à la cour de la tombe (x = %.0f, y = %.1f)" % [_joueur.global_position.x, _joueur.global_position.y])
	var lues := await _parler("VeraLind")
	_verifier(lues >= 5, "Vera Lind parle (%d bulles)" % lues)
	_verifier(_id_etape() == "reponse_vera", "il faut lui répondre (%s)" % _id_etape())
	await _utiliser("RepondreNoms", 20)
	lues = await _lire_dialogue()
	await _attendre(10)
	_verifier(lues >= 3, "Vera répond à ce qu'on lui dit (%d bulles)" % lues)
	_verifier(_id_etape() == "fuite", "elle appelle ses gardes (%s)" % _id_etape())
	await _attendre(5)
	_verifier(_vivants("garde_effaceuse").size() == 3, "trois gardes attaquent (%d)" % _vivants("garde_effaceuse").size())
	await _tuer_tous("garde_effaceuse")
	await _attendre(20)
	_verifier(_id_etape() == "carnet", "Vera s'enfuit (%s)" % _id_etape())
	_verifier(not _scene.find_child("VeraLind", true, false).visible, "Vera Lind a disparu")
	_verifier(_scene.find_child("Faille", true, false).fermee, "la faille s'est refermée derrière elle")
	_verifier(_scene.find_child("CarnetVera", true, false).visible, "son carnet est tombé dans le sable")
	await _utiliser("RamasserCarnet", 20)
	_verifier(_id_etape() == "lenoir", "le carnet est ramassé (%s)" % _id_etape())
	var inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("carnet_e") >= 1, "le carnet « E. » est dans le sac")
	_verifier(_scene.find_child("LenoirDesert", true, false).visible, "Lenoir arrive")
	lues = await _parler("LenoirDesert")
	_verifier(lues >= 4, "Lenoir examine le carnet (%d bulles)" % lues)
	_verifier(_id_etape() == "qg_carnet", "il faut rentrer au QG (%s)" % _id_etape())

	# --- On revient plus tard : Vera n'est plus là, Lenoir si.
	await _charger(DESERT)
	await _attendre(10)
	_verifier(not _scene.find_child("VeraLind", true, false).visible, "Vera ne revient pas")
	_verifier(_scene.find_child("LenoirDesert", true, false).visible, "Lenoir est toujours là")
	_verifier(_scene.find_child("Faille", true, false).fermee, "la faille reste fermée")
	# La passe des tombes ramène au village.
	var entree: Vector2 = _scene.ENTREE + Vector2(3, 0)
	await _placer(Vector3(entree.x, _scene.hauteur(entree.x, entree.y) + 0.5, entree.y), -PI / 2)
	await _attendre(90)
	_verifier(_quete.zone_demandee == "village_batisseurs", "la passe ramène au village (%s)" % _quete.zone_demandee)

	# --- Le portail du marais : retour au QG, la mission « carnet » se lance.
	await _charger(PORT)
	root.get_node("Reseau").remove_meta("mission_hub_auto")
	var portail: Vector2 = _scene.PORTAIL
	await _placer(Vector3(portail.x + 12, _scene.hauteur(portail.x + 12, portail.y) + 0.5, portail.y), 0.0)
	await _attendre(20)
	_quete.rentrer_au_hub()
	await _attendre(10)
	_verifier(_quete.etape < 0, "chapitre 5 terminé au QG")
	_verifier(root.get_node("Reseau").get_meta("mission_hub_auto", "") == "carnet", "le hub lancera la mission du carnet")
	_verifier(not root.get_node("Reseau").get_meta("visite_guidee_qg", false), "pas de deuxième visite guidée")
	root.get_node("Reseau").remove_meta("mission_hub_auto")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
