extends SceneTree
## Test automatique du chapitre 5 de la Préhistoire, « L'objet impossible » :
## Lenoir, la grande faille de la forêt, la montre à gousset, le retour au portail.
## Lancement : godot --headless --path game -s res://tests/test_chapitre5.gd

const FICHIER := "user://test_chapitre5_progression.cfg"

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


func _aller_a(p2: Vector2) -> void:
	await _placer(Vector3(p2.x, _scene.hauteur(p2.x, p2.y) + 0.3, p2.y), 0.0)


func _aller_pres(cible: Node3D, decalage := Vector3(0, 0, 1.2)) -> void:
	var p: Vector3 = cible.global_position + decalage
	p.y = _scene.hauteur(p.x, p.z) + 0.3
	await _placer(p, 0.0)


func _id_etape() -> String:
	return _quete.etape_actuelle().get("id", "")


func _vivants(type: String) -> Array:
	var liste := []
	for bete in get_nodes_in_group("loups"):
		if String(bete.type_ennemi) == type and bete.combat.est_vivant():
			liste.append(bete)
	return liste


func _charger(chemin: String, etape: String, choix := "") -> void:
	if _scene != null:
		_scene.queue_free()
		await _attendre(5)
	if etape != "":
		var cfg := ConfigFile.new()
		cfg.load(FICHIER)
		cfg.set_value("prehistoire", "etape", etape)
		if choix != "":
			cfg.set_value("prehistoire", "choix_choix_grise", choix)
		cfg.save(FICHIER)
	_scene = load(chemin).instantiate()
	_quete = _scene.get_node("Quete")
	_quete.fichier_progression = FICHIER
	_quete.voyage_reel = false
	root.add_child(_scene)
	await _attendre(40)
	_joueur = get_first_node_in_group("joueur_local")
	_dialogue = get_first_node_in_group("dialogue")


func _lancer() -> void:
	print("Test du chapitre 5 (Préhistoire)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	# --- Sur la côte : Lenoir écoute le récit et envoie le joueur à la grande faille.
	await _charger("res://scenes/monde/prehistoire/cote_gelee.tscn", "lenoir_failles")
	var lenoir = _scene.find_child("Lenoir", true, false)
	_verifier(not lenoir.blesse, "Lenoir est debout")
	await _aller_pres(lenoir)
	await _appuyer_f()
	var lues := await _lire_dialogue()
	_verifier(lues >= 4 and _id_etape() == "vers_la_faille", "Lenoir parle des failles (%d bulles, %s)" % [lues, _id_etape()])
	var repere = _quete._position_cible(_quete.etape_actuelle())
	_verifier(repere != null and repere.z < -120.0, "le repère montre le col")

	# --- Dans la steppe, le repère montre la passe de l'est.
	await _charger("res://scenes/monde/prehistoire/steppe.tscn", "")
	repere = _quete._position_cible(_quete.etape_actuelle())
	_verifier(repere != null and repere.x > 150.0, "dans la steppe, le repère montre la passe de l'est")

	# --- Dans la forêt : fermer la grande faille.
	await _charger("res://scenes/monde/prehistoire/foret.tscn", "")
	_verifier(_id_etape() == "fermer_faille_foret", "arrivé dans la forêt, il faut fermer la faille (%s)" % _id_etape())
	var faille = _scene.find_child("Faille0", true, false)
	var montre = _scene.find_child("MontreGousset", true, false)
	_verifier(not montre.visible, "rien ne brille tant que la faille est ouverte")
	repere = _quete._position_cible(_quete.etape_actuelle())
	_verifier(repere != null and Vector2(repere.x, repere.z).distance_to(Vector2(-70, 62)) < 3.0, "le repère montre la grande faille")
	var combat_joueur = _joueur.get_node("Combat")
	var sortis := _vivants("loup_fracture_foret")
	_verifier(sortis.size() == 3, "trois fracturés gardent la faille (%d)" % sortis.size())
	# Les gardiens de la faille (camp de fracturés et loups du coin).
	for loup in get_nodes_in_group("loups"):
		if loup.combat.est_vivant() and loup.global_position.distance_to(faille.global_position) < 40.0:
			loup.combat.subir(9999.0, combat_joueur)
	await _attendre(5)
	await _aller_pres(faille, Vector3(0, 0, 2.0))
	await _appuyer_f()
	await _attendre(8 * 60 + 40)
	_verifier(faille.fermee, "la grande faille est fermée")
	_verifier(_id_etape() == "objet_impossible", "quelque chose brille (%s)" % _id_etape())
	_verifier(montre.visible, "la montre apparaît dans la neige")
	await _aller_pres(montre, Vector3(0, 0, 1.0))
	await _appuyer_f()
	await _attendre(10)
	_verifier(_id_etape() == "retour_lenoir", "la montre est ramassée (%s)" % _id_etape())
	var inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("montre_gousset_brisee") >= 1, "la montre est dans le sac")

	# --- Rechargement de la forêt : la faille reste fermée, la montre n'est plus là.
	await _charger("res://scenes/monde/prehistoire/foret.tscn", "")
	_verifier(_scene.find_child("Faille0", true, false).fermee, "la faille est toujours fermée")
	var visuel_montre = _scene.find_child("MontreGousset", true, false)
	_verifier(not visuel_montre.actif, "la montre ne peut plus être ramassée")
	repere = _quete._position_cible(_quete.etape_actuelle())
	_verifier(repere != null and repere.x < -130.0, "le repère montre la sortie vers la steppe")

	# --- Retour au portail : Lenoir comprend, le joueur passe le portail.
	await _charger("res://scenes/monde/prehistoire/cote_gelee.tscn", "")
	lenoir = _scene.find_child("Lenoir", true, false)
	await _aller_pres(lenoir)
	await _appuyer_f()
	lues = await _lire_dialogue()
	_verifier(lues >= 5 and _id_etape() == "qg_vigie", "Lenoir est troublé (%d bulles, %s)" % [lues, _id_etape()])
	repere = _quete._position_cible(_quete.etape_actuelle())
	_verifier(repere != null and Vector2(repere.x, repere.z).distance_to(_scene.PORTAIL) < 1.0, "le repère montre le portail")
	_quete.rentrer_au_hub()
	await _attendre(5)
	_verifier(_quete.etape == -1 and _quete.visite_qg_demandee, "le chapitre 5 se termine au QG")
	_verifier(root.get_node("Reseau").get_meta("visite_guidee_qg", false), "le hub sait qu'il faut une visite guidée")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
