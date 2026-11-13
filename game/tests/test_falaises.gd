extends SceneTree
## Test automatique des Falaises Peintes (Préhistoire, zone 4) et du chapitre 6
## « L'hiver qui vient trop tôt » : la tempête, l'escorte du clan jusqu'à la
## passe du nord, la défense de l'abri d'hiver.
## Lancement : godot --headless --path game -s res://tests/test_falaises.gd

const FICHIER := "user://test_falaises_progression.cfg"

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


func _tuer_proches(centre: Vector3, rayon: float) -> int:
	var n := 0
	var combat_joueur = _joueur.get_node("Combat")
	for bete in get_nodes_in_group("loups"):
		if bete.combat.est_vivant() and bete.global_position.distance_to(centre) < rayon:
			bete.combat.subir(9999.0, combat_joueur)
			n += 1
	return n


func _lancer() -> void:
	print("Test des Falaises Peintes (Préhistoire)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	# --- Retour sur l'île : Lenoir parle de la tempête.
	await _charger("res://scenes/monde/prehistoire/cote_gelee.tscn", "retour_qg")
	var lenoir = _scene.find_child("Lenoir", true, false)
	await _aller_pres(lenoir)
	await _appuyer_f()
	var lues := await _lire_dialogue()
	_verifier(lues >= 4 and _id_etape() == "vers_le_camp_tempete", "Lenoir parle de la tempête (%d bulles, %s)" % [lues, _id_etape()])

	# --- Dans la steppe : la tempête, Aïna, l'escorte.
	await _charger("res://scenes/monde/prehistoire/steppe.tscn", "")
	_verifier(_id_etape() == "aina_tempete", "arrivé au camp, il faut parler à Aïna (%s)" % _id_etape())
	_verifier(_scene.en_tempete, "une tempête souffle sur la steppe")
	var aina = _scene.find_child("Aina", true, false)
	await _aller_pres(aina)
	await _appuyer_f()
	lues = await _lire_dialogue()
	_verifier(lues >= 5 and _id_etape() == "escorte", "Aïna demande d'escorter le clan (%d bulles, %s)" % [lues, _id_etape()])
	_verifier(not _scene.find_child("Toran", true, false).visible, "Toran est parti devant")
	# Le groupe n'avance pas si le joueur reste loin.
	await _placer(Vector3(80, _scene.hauteur(80, 40) + 0.5, 40), 0.0)
	await _attendre(120)
	_verifier(_quete.escorte_distance < 1.0, "le groupe attend le joueur")
	var vagues_vues := 0
	var tours := 0
	while _id_etape() == "escorte" and tours < 200:
		tours += 1
		aina = _scene.find_child("Aina", true, false)
		var p: Vector3 = aina.global_position + Vector3(2.5, 0, 2.5)
		p.y = _scene.hauteur(p.x, p.z) + 0.3
		_joueur.teleporter(p, 0.0)
		await _attendre(30)
		if _tuer_proches(aina.global_position, 60.0) > 0:
			vagues_vues += 1
		await _attendre(3)
	_verifier(_id_etape() == "vers_les_falaises", "le clan arrive à la passe du nord (%s, %d tours)" % [_id_etape(), tours])
	_verifier(vagues_vues >= 2, "des fracturés attaquent pendant l'escorte (%d)" % vagues_vues)
	_verifier(not aina.visible, "le clan a passé la passe")
	_verifier(_scene.hauteur(_scene.PASSE_NORD.x, _scene.PASSE_NORD.y) < 12.0, "la passe du nord est praticable (%.1f m)" % _scene.hauteur(_scene.PASSE_NORD.x, _scene.PASSE_NORD.y))
	var repere = _quete._position_cible(_quete.etape_actuelle())
	_verifier(repere != null and repere.z < -150.0, "le repère montre la passe du nord")
	await _placer(Vector3(_scene.PASSE_NORD.x, _scene.hauteur(_scene.PASSE_NORD.x, _scene.PASSE_NORD.y - 4) + 0.5, _scene.PASSE_NORD.y - 4), 0.0)
	await _attendre(70)
	_verifier(_quete.zone_demandee == "falaises", "la passe mène aux Falaises Peintes (%s)" % _quete.zone_demandee)

	# --- Aux Falaises Peintes : défendre l'abri.
	await _charger("res://scenes/monde/prehistoire/falaises.tscn", "")
	_verifier(_joueur != null and _joueur.is_on_floor(), "on arrive dans la vallée, posé au sol")
	_verifier(_id_etape() == "defendre_abri", "il faut défendre l'abri (%s)" % _id_etape())
	var abri: Vector2 = _scene.ABRI
	var pied: float = _scene.pied_falaise(abri.x)
	_verifier(_scene.hauteur(abri.x, pied - 12.0) - _scene.hauteur(abri.x, pied + 4.0) > 20.0, "une haute falaise ferme la vallée")
	_verifier(_scene.find_child("Fresque", true, false) != null, "des peintures couvrent la paroi de l'abri")
	_verifier(_scene.find_child("GrandeGrotte", true, false) != null, "l'entrée de la Grande Grotte")
	aina = _scene.find_child("Aina", true, false)
	_verifier(aina.visible and _scene.find_child("Toran", true, false).visible, "le clan est à l'abri")
	_verifier(_scene.en_tempete, "la tempête souffle encore")
	var attaquants := _vivants("loup_fracture_falaises")
	_verifier(attaquants.size() == 5, "cinq fracturés attaquent l'abri (%d)" % attaquants.size())
	var combat_joueur = _joueur.get_node("Combat")
	for loup in attaquants:
		loup.combat.subir(9999.0, combat_joueur)
		await _attendre(3)
	await _attendre(5)
	_verifier(_id_etape() == "aina_abri", "l'abri est sauf (%s)" % _id_etape())
	await _aller_pres(aina)
	await _appuyer_f()
	lues = await _lire_dialogue()
	_verifier(lues >= 5 and _id_etape() == "murs_vides", "Aïna conclut le chapitre 6 (%d bulles, %s)" % [lues, _id_etape()])
	_verifier(not _scene.en_tempete, "la tempête est passée")

	# --- Rechargements : tout reste en place.
	await _charger("res://scenes/monde/prehistoire/falaises.tscn", "")
	_verifier(_scene.find_child("Aina", true, false).visible and not _scene.en_tempete, "le clan reste à l'abri, sans tempête")
	await _charger("res://scenes/monde/prehistoire/steppe.tscn", "")
	_verifier(not _scene.find_child("Aina", true, false).visible and not _scene.find_child("Toran", true, false).visible,
			"le camp d'été est vide")

	# --- Retour vers la steppe depuis les falaises.
	await _charger("res://scenes/monde/prehistoire/falaises.tscn", "")
	await _placer(Vector3(_scene.ENTREE.x, _scene.hauteur(_scene.ENTREE.x, _scene.ENTREE.y + 7) + 0.5, _scene.ENTREE.y + 7), 0.0)
	await _attendre(70)
	_verifier(_quete.zone_demandee == "steppe", "la vallée ramène à la steppe (%s)" % _quete.zone_demandee)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
