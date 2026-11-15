extends SceneTree
## Test automatique des cinématiques : données valides (zones et étapes qui
## existent), lecture complète, Espace pour passer, caméra et interface rendues,
## personnage immobile pendant la cinématique, une seule lecture par personnage.
## Lancement : godot --headless --path game -s res://tests/test_cinematiques.gd

const FICHIER := "user://test_cinematiques_progression.cfg"

var _echecs := 0


func _verifier(condition: bool, message: String) -> void:
	if condition:
		print("  OK   ", message)
	else:
		print("  ÉCHEC ", message)
		_echecs += 1


func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	print("Test des cinématiques")
	# 1. Les données : chaque cinématique pointe vers une zone et une étape qui existent.
	var lu = JSON.parse_string(FileAccess.get_file_as_string("res://data/cinematiques.json"))
	_verifier(lu is Dictionary, "data/cinematiques.json se lit")
	var ids := {}
	for c in lu.get("cinematiques", []):
		var id := String(c.get("id", ""))
		_verifier(id != "" and not ids.has(id), "%s : identifiant unique" % id)
		ids[id] = true
		var quete = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s_quete.json" % c.get("ile", "")))
		_verifier(quete is Dictionary and quete.get("zones", {}).has(c.get("zone", "")),
				"%s : la zone « %s » existe" % [id, c.get("zone", "")])
		if c.get("declencheur", "") == "etape":
			var trouvee := false
			for ch in quete.get("chapitres", []):
				for e in ch.get("etapes", []):
					trouvee = trouvee or e.get("id", "") == c.get("etape", "")
			_verifier(trouvee, "%s : l'étape « %s » existe" % [id, c.get("etape", "")])
		else:
			_verifier(c.get("declencheur", "") == "arrivee", "%s : déclencheur connu" % id)
		_verifier(not c.get("plans", []).is_empty(), "%s : a des plans" % id)
		for p in c.get("plans", []):
			_verifier(float(p.get("duree", 0)) > 0.0 and p.has("camera") and p.has("regard"),
					"%s : plan complet (durée, caméra, regard)" % id)

	# 2. La lecture dans une vraie zone.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	var scene: Node = load("res://scenes/monde/prehistoire/cote_gelee.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = FICHIER
	root.add_child(scene)
	current_scene = scene
	await _attendre(30)
	var quete = scene.get_node("Quete")
	var cin = quete.cinematiques
	_verifier(cin != null, "la quête crée le nœud des cinématiques")
	_verifier(not cin.actif, "pas de cinématique automatique sans écran ni voyage réel (tests)")
	var joueur = get_first_node_in_group("joueur_local")
	var camera_jeu := root.get_viewport().get_camera_3d()
	cin.jouer("arrivee_prehistoire")
	await _attendre(3)
	_verifier(cin.est_en_cours(), "la cinématique d'arrivée démarre")
	_verifier(root.get_viewport().get_camera_3d() != camera_jeu, "la caméra de cinéma prend le relais")
	_verifier(joueur.en_cinematique(), "le personnage sait qu'une cinématique est en cours")
	_verifier(cin.deja_vue("arrivee_prehistoire"), "la cinématique est notée comme vue")
	var hud_cache := true
	for calque in scene.find_children("*", "CanvasLayer", true, false):
		if calque.name != "EcranCinematique" and calque.visible:
			hud_cache = false
	_verifier(hud_cache, "l'interface du jeu est cachée")
	# Le personnage ne bouge pas, même en appuyant sur « avancer ».
	var depart: Vector3 = joueur.global_position
	Input.action_press("avancer")
	await _attendre(20)
	Input.action_release("avancer")
	_verifier(Vector2(joueur.global_position.x - depart.x, joueur.global_position.z - depart.z).length() < 0.05,
			"le personnage reste immobile")
	# Elle passe toute seule d'un plan à l'autre.
	var plan_avant: int = cin.plan
	cin._temps_plan = 999.0
	await _attendre(2)
	_verifier(cin.plan == plan_avant + 1, "passage au plan suivant")
	# Espace : on passe.
	var espace := InputEventKey.new()
	espace.keycode = KEY_SPACE
	espace.pressed = true
	root.push_input(espace)
	await create_timer(1.2).timeout
	_verifier(not cin.est_en_cours(), "Espace passe la cinématique")
	_verifier(root.get_viewport().get_camera_3d() == camera_jeu, "la caméra du jeu revient")
	_verifier(not joueur.en_cinematique(), "le personnage peut rebouger")
	var hud_revenu := false
	for calque in scene.find_children("*", "CanvasLayer", true, false):
		if calque.name != "EcranCinematique" and calque.visible:
			hud_revenu = true
	_verifier(hud_revenu, "l'interface du jeu revient")
	# Une seule fois par personnage.
	cin.actif = true
	var suite_appelee := [false]
	var jouee: bool = cin.lancer_arrivee("cote_gelee", func(): suite_appelee[0] = true)
	_verifier(not jouee and not cin.est_en_cours(), "déjà vue : elle ne se rejoue pas")
	# Une cinématique d'étape se déclenche au début de son étape.
	cin.actif = true
	var cfg := ConfigFile.new()
	cfg.load(ProjectSettings.globalize_path(FICHIER))
	cfg.set_value("cinematiques", "arrivee_prehistoire", false)
	cfg.save(ProjectSettings.globalize_path(FICHIER))
	jouee = cin.lancer_arrivee("cote_gelee", func(): suite_appelee[0] = true)
	_verifier(jouee and cin.est_en_cours(), "pas encore vue : l'arrivée la joue")
	cin.passer()
	await create_timer(1.2).timeout
	_verifier(suite_appelee[0], "après l'arrivée, le titre de la zone s'affiche")
	cin.actif = false
	scene.queue_free()
	await _attendre(5)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Échecs : %d" % _echecs)
	quit(1 if _echecs > 0 else 0)
