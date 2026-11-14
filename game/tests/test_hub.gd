extends SceneTree
## Test automatique du hub Hikari Bay (Place Hikari) : le joueur arrive sur la
## place, peut marcher, descendre l'escalier de la station Asahi, et les
## barrières de chantier l'empêchent de sortir du quartier.
## Lancement : godot --headless --path game -s res://tests/test_hub.gd

var _echecs := 0
var _profil_test := "_test_hub_%d" % OS.get_process_id()


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
	# Profil de test vide, propre à ce lancement : le test ne lit ni ne modifie
	# les vraies sauvegardes du joueur (avec l'intro terminée, un portail du QG
	# ferait vraiment partir le personnage vers une île au milieu du test).
	Profil.activer(_profil_test)
	_lancer.call_deferred()


func _effacer_profil_test() -> void:
	for relatif in Profil.lister(_profil_test):
		DirAccess.remove_absolute(Profil.dossier(_profil_test) + relatif)
	for d in ["sauvegardes/inventaires", "sauvegardes", "cartes", ""]:
		DirAccess.remove_absolute(Profil.dossier(_profil_test) + d)


func _avancer(joueur, images: int) -> void:
	Input.action_press("avancer")
	await _attendre(images)
	Input.action_release("avancer")
	await _attendre(5)


func _placer(joueur, position: Vector3, angle: float) -> void:
	joueur.teleporter(position, angle)
	joueur.camera.lacet = angle
	await _attendre(10)


func _lancer() -> void:
	var scene: Node = load("res://scenes/monde/hikari_bay.tscn").instantiate()
	var intro := scene.find_child("Intro", true, false)
	if intro != null:
		intro.voyage_reel = false
	root.add_child(scene)
	await _attendre(30)
	var joueur = get_first_node_in_group("joueur_local")
	print("Test du hub Hikari Bay")
	_verifier(joueur != null, "un personnage apparaît sur la place")
	_verifier(joueur.is_on_floor(), "il est posé sur le sol")
	_verifier(absf(joueur.global_position.y) < 0.5, "au niveau de la place (y = %.2f)" % joueur.global_position.y)

	var depart = joueur.global_position
	await _avancer(joueur, 60)
	_verifier(joueur.global_position.z < depart.z - 4.0, "il avance vers la statue")

	# Escalier de la station Asahi : on part du haut, face au sud (vers +Z).
	await _placer(joueur, Vector3(-23, 0.3, 9), PI)
	await _avancer(joueur, 300)
	_verifier(joueur.global_position.y < -3.5, "l'escalier descend jusqu'au couloir (y = %.2f)" % joueur.global_position.y)
	_verifier(joueur.global_position.z > 40.5,
			"la porte du QG s'ouvre devant l'agent (z = %.1f)" % joueur.global_position.z)
	# Le grand escalier du QG descend jusqu'au Hall des opérations (y = -12).
	await _placer(joueur, Vector3(-23, -3.7, 42), PI)
	await _avancer(joueur, 330)
	_verifier(joueur.global_position.y < -11.5 and joueur.global_position.z > 70.0,
			"l'escalier mène au Hall des opérations (y = %.1f, z = %.1f)" % [joueur.global_position.y, joueur.global_position.z])
	# Parler à la commandante (touche F).
	var commandante = scene.find_child("Pnj_commandante", true, false)
	_verifier(commandante != null, "la commandante est dans le hall")
	await _placer(joueur, commandante.global_position + Vector3(0, 0.3, -2.0), PI)
	var dialogue = get_first_node_in_group("dialogue")
	var appui := InputEventAction.new()
	appui.action = "interagir"
	appui.pressed = true
	Input.parse_input_event(appui)
	await _attendre(5)
	_verifier(dialogue.est_ouvert(), "F ouvre le dialogue de la commandante")
	for i in commandante.repliques.size():
		Input.parse_input_event(appui)
		await _attendre(3)
	_verifier(not dialogue.est_ouvert(), "F fait défiler puis ferme le dialogue")
	# Le portail de la Préhistoire réagit quand on le traverse.
	var franchi := [""]
	scene.portail_franchi.connect(func(e): franchi[0] = e)
	var portail = scene.qg["portails"][0]
	await _placer(joueur, portail.global_position + Vector3(0, -3.0, -4.0), PI)
	await _avancer(joueur, 60)
	_verifier(franchi[0] == "Préhistoire", "traverser le portail actif déclenche le voyage (%s, joueur en %s, portail en %s)" % [franchi[0], joueur.global_position, portail.global_position])
	# Et on remonte par le couloir de la station.
	# Et on remonte.
	await _placer(joueur, Vector3(-23, -3.7, 30), 0.0)
	await _avancer(joueur, 300)
	_verifier(joueur.global_position.y > -0.5 and joueur.global_position.z < 12.0,
			"on peut remonter sur la place (y = %.2f, z = %.1f)" % [joueur.global_position.y, joueur.global_position.z])

	# Les Résidences sont ouvertes : la rue de l'ouest mène à leur place.
	await _placer(joueur, Vector3(-36, 0.3, 0), PI / 2)
	await _avancer(joueur, 500)
	_verifier(joueur.global_position.x < -75.0, "la rue de l'ouest mène aux Résidences (x = %.1f)" % joueur.global_position.x)
	await _placer(joueur, Vector3(-92, 0.3, -15), 0.0)
	await _avancer(joueur, 120)
	_verifier(joueur.global_position.z < -19.0, "on entre dans le konbini (z = %.1f)" % joueur.global_position.z)
	await _placer(joueur, Vector3(-89, 0.3, 14), PI)
	await _avancer(joueur, 120)
	_verifier(joueur.global_position.z > 18.0, "on entre dans le hall de la Résidence Sakura (z = %.1f)" % joueur.global_position.z)
	await _placer(joueur, Vector3(-106, 0.3, 0), PI / 2)
	await _avancer(joueur, 120)
	_verifier(joueur.global_position.x < -111.0, "on entre dans la Maison des guildes (x = %.1f)" % joueur.global_position.x)
	await _placer(joueur, Vector3(-106, 0.3, 8), PI / 2)
	await _avancer(joueur, 120)
	_verifier(joueur.global_position.x > -110.0, "le mur de la Maison des guildes arrête le joueur (x = %.1f)" % joueur.global_position.x)
	# L'Arène : le quai mène à la plateforme, on entre sur le terrain par l'ouest.
	await _placer(joueur, Vector3(71, 0.3, 70), PI)
	await _avancer(joueur, 60)
	_verifier(joueur.global_position.z > 74.5 and joueur.global_position.y > -0.5, "le bout de la promenade mène au quai de l'Arène (z = %.1f)" % joueur.global_position.z)
	await _placer(joueur, Vector3(75, 0.3, 78), -PI / 2)
	await _avancer(joueur, 300)
	_verifier(joueur.global_position.x > 101.0 and joueur.global_position.y > -0.5, "le quai mène à la plateforme de l'Arène (x = %.1f)" % joueur.global_position.x)
	await _placer(joueur, Vector3(101, 0.3, 102), -PI / 2)
	await _avancer(joueur, 200)
	_verifier(joueur.global_position.x > 115.0, "on entre sur le terrain de l'Arène (x = %.1f)" % joueur.global_position.x)
	await _placer(joueur, Vector3(125, 0.3, 76), PI)
	await _avancer(joueur, 150)
	_verifier(joueur.global_position.z < 80.5, "le mur du stade arrête le joueur ailleurs qu'à l'entrée (z = %.1f)" % joueur.global_position.z)
	# La promenade reste fermée à l'ouest.
	await _placer(joueur, Vector3(-60, 0.3, 68), PI / 2)
	await _avancer(joueur, 180)
	_verifier(joueur.global_position.x > -70.0, "la barrière de chantier ferme l'ouest de la promenade (x = %.1f)" % joueur.global_position.x)

	# Le Quartier des Artisans est ouvert : la rue du nord-est mène sous le viaduc.
	await _placer(joueur, Vector3(20, 0.3, -40), 0.0)
	await _avancer(joueur, 600)
	_verifier(joueur.global_position.z < -100.0, "la rue du nord-est mène au Quartier des Artisans (z = %.1f)" % joueur.global_position.z)
	await _placer(joueur, Vector3(36, 0.3, -82), 0.0)
	await _avancer(joueur, 150)
	_verifier(joueur.global_position.z < -92.0, "on entre dans la forge Hinode (z = %.1f)" % joueur.global_position.z)
	await _placer(joueur, Vector3(62, 0.3, -82), 0.0)
	await _avancer(joueur, 150)
	_verifier(joueur.global_position.z < -92.0, "on entre dans l'atelier Fil & Fibre (z = %.1f)" % joueur.global_position.z)
	_verifier(scene.find_child("Pnj_forgeron", true, false) != null, "Maître Tetsuo est à sa forge")

	# Le Musée et les Jardins suspendus sont ouverts : la rue de l'est mène à l'esplanade.
	await _placer(joueur, Vector3(36, 0.3, 0), -PI / 2)
	await _avancer(joueur, 400)
	_verifier(joueur.global_position.x > 75.0, "la rue de l'est mène à l'esplanade du Musée (x = %.1f)" % joueur.global_position.x)
	await _placer(joueur, Vector3(100, 0.3, 0), -PI / 2)
	await _avancer(joueur, 150)
	_verifier(joueur.global_position.x > 107.0, "on entre dans le Musée par sa grande porte (x = %.1f)" % joueur.global_position.x)
	await _placer(joueur, Vector3(100, 0.3, 8), -PI / 2)
	await _avancer(joueur, 150)
	_verifier(joueur.global_position.x < 104.0, "la paroi de verre arrête le joueur ailleurs qu'à la porte (x = %.1f)" % joueur.global_position.x)
	await _placer(joueur, Vector3(90, 0.3, -17), 0.0)
	await _avancer(joueur, 150)
	_verifier(joueur.global_position.y > 1.0, "les marches mènent sur la terrasse nord (y = %.2f)" % joueur.global_position.y)
	_verifier(scene.find_child("Pnj_conservatrice", true, false) != null, "la conservatrice accueille au Musée")

	# Le Marché de nuit est ouvert : la rue du nord-ouest mène à ses ruelles.
	await _placer(joueur, Vector3(-20, 0.3, -40), 0.0)
	await _avancer(joueur, 600)
	_verifier(joueur.global_position.z < -100.0, "la rue du nord-ouest mène au Marché de nuit (z = %.1f)" % joueur.global_position.z)
	# On entre dans le restaurant Kaminari par sa porte (face à l'ouest).
	await _placer(joueur, Vector3(-19.5, 0.3, -109.5), PI / 2)
	await _avancer(joueur, 150)
	_verifier(joueur.global_position.x < -25.0, "on entre dans le restaurant de ramen (x = %.1f)" % joueur.global_position.x)
	_verifier(scene.find_child("Pnj_chef_goro", true, false) != null, "le chef Goro est dans sa cuisine")
	# Et dans la salle Tsukimi, par la ruelle de la fumée (face à l'est).
	await _placer(joueur, Vector3(-50.5, 0.3, -119.5), -PI / 2)
	await _avancer(joueur, 120)
	_verifier(joueur.global_position.x > -46.0, "on entre dans la salle Tsukimi (x = %.1f)" % joueur.global_position.x)
	# Les murs du restaurant arrêtent le joueur ailleurs qu'à la porte.
	await _placer(joueur, Vector3(-19.5, 0.3, -114.0), PI / 2)
	await _avancer(joueur, 150)
	_verifier(joueur.global_position.x > -23.2, "le mur du restaurant arrête le joueur (x = %.1f)" % joueur.global_position.x)

	# Le garde-corps du quai empêche de tomber dans la mer.
	await _placer(joueur, Vector3(0, 0.3, 64), PI)
	await _avancer(joueur, 120)
	_verifier(joueur.global_position.z < 74.0, "le garde-corps retient au bord de l'eau (z = %.1f)" % joueur.global_position.z)

	# Le Front de mer : la jetée et le Terminal des ferries, la jetée de la grande roue.
	await _placer(joueur, Vector3(-35, 0.3, 66), PI)
	await _avancer(joueur, 200)
	_verifier(joueur.global_position.z > 84.0 and joueur.global_position.y > -0.5,
			"on entre dans le Terminal des ferries par la jetée (z = %.1f)" % joueur.global_position.z)
	_verifier(joueur.global_position.z < 102.0, "la baie vitrée arrête le joueur (z = %.1f)" % joueur.global_position.z)
	await _placer(joueur, Vector3(-50, 0.3, 90), PI / 2)
	await _avancer(joueur, 120)
	_verifier(joueur.global_position.x > -52.5, "le garde-corps de la jetée retient au bord (x = %.1f)" % joueur.global_position.x)
	await _placer(joueur, Vector3(55, 0.3, 66), PI)
	await _avancer(joueur, 400)
	_verifier(joueur.global_position.z > 105.0 and joueur.global_position.z < 124.0,
			"la jetée de la grande roue est accessible (z = %.1f)" % joueur.global_position.z)
	_verifier(scene.find_child("Pnj_guichetiere", true, false) != null, "la guichetière est au terminal")

	# La ville qui change : réparer la Préhistoire cache les éclats de fracture.
	var eclats = scene.find_child("EclatsDeFracture", true, false)
	_verifier(eclats != null and eclats.visible, "la statue porte des éclats de fracture au départ")
	scene.prehistoire_reparee = true
	_verifier(not eclats.visible, "ils disparaissent quand la Préhistoire est réparée")
	var fresques = scene.find_child("FresquesPrehistoire", true, false)
	var effacees = scene.find_child("FresquesEffacees", true, false)
	_verifier(fresques != null and fresques.visible and not effacees.visible, "et les fresques du Musée réapparaissent")

	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	_effacer_profil_test()
	quit(1 if _echecs > 0 else 0)
