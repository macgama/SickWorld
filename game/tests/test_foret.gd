extends SceneTree
## Test automatique de la Forêt des Bouleaux (Préhistoire, zone 3) et du
## chapitre 4 « La louve grise » : Toran, la passe de l'est, le pistage,
## Kéo encerclé, le choix pour Grise (les deux branches), le retour au camp.
## Lancement : godot --headless --path game -s res://tests/test_foret.gd

const FICHIER := "user://test_foret_progression.cfg"

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


## Joue la forêt jusqu'au choix, puis prend « option ».
func _jouer_foret(option: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	await _charger("res://scenes/monde/prehistoire/foret.tscn", "vers_la_foret")
	_verifier(_id_etape() == "traces_1", "[%s] arrivé dans la forêt, il faut suivre les traces (%s)" % [option, _id_etape()])
	for cible in [Vector2(-80, -26), Vector2(0, -14), Vector2(46, -38)]:
		await _aller_a(cible)
		await _attendre(5)
	_verifier(_id_etape() == "fractures_keo", "[%s] les traces mènent à la clairière (%s)" % [option, _id_etape()])
	var loups := _vivants("loup_fracture_foret")
	_verifier(loups.size() == 4, "[%s] quatre fracturés encerclent Kéo (%d)" % [option, loups.size()])
	var combat_joueur = _joueur.get_node("Combat")
	for loup in loups:
		loup.combat.subir(9999.0, combat_joueur)
		await _attendre(3)
	await _attendre(5)
	_verifier(_id_etape() == "parler_keo", "[%s] Kéo est sauvé (%s)" % [option, _id_etape()])
	var keo = _scene.find_child("Keo", true, false)
	await _aller_pres(keo, Vector3(-1.2, 0, 1.2))
	await _appuyer_f()
	var lues := await _lire_dialogue()
	_verifier(lues >= 5, "[%s] Kéo explique, pour Grise (%d bulles)" % [option, lues])
	_verifier(_id_etape() == "choix_grise", "[%s] il faut choisir (%s)" % [option, _id_etape()])
	var soigner = _scene.find_child("SoignerGrise", true, false)
	var liberer = _scene.find_child("LibererGrise", true, false)
	_verifier(soigner.actif and liberer.actif, "[%s] les deux choix sont proposés" % option)


func _lancer() -> void:
	print("Test de la Forêt des Bouleaux (Préhistoire)")
	# --- Dans la steppe : Toran envoie le joueur à l'est.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	await _charger("res://scenes/monde/prehistoire/steppe.tscn", "keo_disparu")
	var toran = _scene.find_child("Toran", true, false)
	await _aller_pres(toran)
	await _appuyer_f()
	var lues := await _lire_dialogue()
	_verifier(lues >= 4 and _id_etape() == "vers_la_foret", "Toran raconte la disparition de Kéo (%d bulles, %s)" % [lues, _id_etape()])
	await _aller_a(Vector2(_scene.PASSE_EST.x - 1.0, _scene.PASSE_EST.y))
	await _attendre(70)
	_verifier(_quete.zone_demandee == "foret", "la passe de l'est mène à la forêt (%s)" % _quete.zone_demandee)

	# --- Branche 1 : soigner Grise.
	await _jouer_foret("soigner")
	_verifier(_scene.hauteur(_scene.riviere_x(_scene.GUE_Z), _scene.GUE_Z) > -0.5, "le gué est peu profond")
	_verifier(_scene.find_child("Bouleaux", true, false).get_child_count() > 500, "une vraie forêt de bouleaux")
	var grise = _scene.find_child("Grise", true, false)
	_verifier(grise.contaminee, "Grise est contaminée par la faille")
	var soigner = _scene.find_child("SoignerGrise", true, false)
	await _aller_pres(soigner, Vector3(0.5, 0, 0.5))
	await _appuyer_f()
	await _attendre(5)
	var renforts := _vivants("loup_fracture_foret")
	_verifier(renforts.size() == 2, "soigner Grise attire deux loups (%d)" % renforts.size())
	# Les loups interrompent les soins : on s'en occupe, puis on recommence.
	var combat_joueur = _joueur.get_node("Combat")
	for loup in renforts:
		loup.combat.subir(9999.0, combat_joueur)
	await _attendre(5)
	if _quete._canalisation == null:
		await _aller_pres(soigner, Vector3(0.5, 0, 0.5))
		await _appuyer_f()
	await _attendre(8 * 60 + 30)
	_verifier(_vivants("loup_fracture_foret").is_empty(), "pas de nouveaux renforts en recommençant")
	_verifier(not grise.contaminee, "Grise est soignée")
	lues = await _lire_dialogue()
	_verifier(lues >= 3, "Kéo remercie (%d bulles)" % lues)
	_verifier(_id_etape() == "retour_keo", "retour au camp (%s)" % _id_etape())
	var repere = _quete._position_cible(_quete.etape_actuelle())
	_verifier(repere != null and repere.x < -130.0, "le repère montre la sortie vers la steppe")

	# Au camp : Kéo et Grise sont là, Aïna conclut le chapitre.
	await _charger("res://scenes/monde/prehistoire/steppe.tscn", "")
	_verifier(_scene.find_child("KeoCamp", true, false).visible, "Kéo est rentré au camp")
	_verifier(_scene.find_child("GriseCamp", true, false).visible, "Grise, guérie, est avec lui")
	var aina = _scene.find_child("Aina", true, false)
	await _aller_pres(aina)
	await _appuyer_f()
	lues = await _lire_dialogue()
	_verifier(lues >= 4 and _id_etape() == "lenoir_failles", "Aïna conclut le chapitre 4 et envoie voir Lenoir (%d bulles, %s)" % [lues, _id_etape()])

	# --- Branche 2 : laisser partir Grise.
	await _jouer_foret("liberer")
	var liberer = _scene.find_child("LibererGrise", true, false)
	await _aller_pres(liberer, Vector3(-0.5, 0, 0.5))
	await _appuyer_f()
	await _attendre(5)
	lues = await _lire_dialogue()
	_verifier(lues >= 3, "Kéo laisse partir Grise (%d bulles)" % lues)
	await _attendre(500)
	_verifier(not _scene.find_child("Grise", true, false).visible, "Grise s'est enfuie")
	_verifier(_id_etape() == "retour_keo", "on peut continuer (%s)" % _id_etape())
	await _charger("res://scenes/monde/prehistoire/foret.tscn", "")
	_verifier(not _scene.find_child("Grise", true, false).visible, "au retour, Grise n'est plus là")
	await _charger("res://scenes/monde/prehistoire/steppe.tscn", "")
	_verifier(_scene.find_child("KeoCamp", true, false).visible and not _scene.find_child("GriseCamp", true, false).visible,
			"Kéo est rentré seul")

	# Retour à la steppe par la passe.
	await _charger("res://scenes/monde/prehistoire/foret.tscn", "")
	await _aller_a(Vector2(-156, -10))
	await _attendre(70)
	_verifier(_quete.zone_demandee == "steppe", "la passe ramène à la steppe (%s)" % _quete.zone_demandee)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
