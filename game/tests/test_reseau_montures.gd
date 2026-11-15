extends SceneTree
## Test des montures en multijoueur : à lancer comme CLIENT pendant qu'un serveur
## dédié tourne sur la Steppe.
##   godot --headless --path game -- --serveur --port=7791 --scene=res://scenes/monde/prehistoire/steppe.tscn
##   godot --headless --path game -s res://tests/test_reseau_montures.gd -- --port=7791 --nom=Cavalier --role=cavalier
##   godot --headless --path game -s res://tests/test_reseau_montures.gd -- --port=7791 --nom=Temoin --role=temoin
## Le cavalier appelle son renne (le serveur décide) ; le témoin doit le voir en selle.

var _echecs := 0


func _verifier(condition: bool, message: String) -> void:
	print("  OK   " if condition else "  ÉCHEC ", message)
	if not condition:
		_echecs += 1


func _secondes(s: float) -> void:
	await create_timer(s).timeout


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var role := "cavalier"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			role = a.get_slice("=", 1)
	var reseau = root.get_node("Reseau")
	reseau.mode = reseau.Mode.REJOINDRE
	reseau.adresse = "127.0.0.1"
	var scene: Node = load("res://scenes/monde/prehistoire/steppe.tscn").instantiate()
	if scene.has_node("Quete"):
		scene.get_node("Quete").fichier_progression = "user://test_reseau_montures_%s.cfg" % role
	root.add_child(scene)
	current_scene = scene
	print("Test réseau des montures (%s)" % role)
	var joueur = null
	for i in 60:
		await _secondes(0.2)
		joueur = get_first_node_in_group("joueur_local")
		if joueur != null:
			break
	_verifier(joueur != null, "le serveur a créé notre personnage")
	if joueur == null:
		quit(1)
		return
	await _secondes(1.5)
	var m = joueur.get_node("Monture")
	if role == "cavalier":
		m.basculer()
		await _secondes(0.5)
		_verifier(not m.est_monte(), "le serveur fait durer l'appel")
		await _secondes(1.6)
		_verifier(m.monture == "cheval", "le serveur nous met en selle sur le renne")
		_verifier(m.get_node_or_null("Bete") != null, "on voit notre renne")
		await _secondes(8.0)
		m.basculer()
		await _secondes(0.6)
		_verifier(not m.est_monte(), "le serveur nous fait descendre (V)")
		await _secondes(3.0)
	else:
		var vu := false
		for i in 60:
			await _secondes(0.2)
			for j in get_nodes_in_group("joueur"):
				if j == joueur:
					continue
				var autre = j.get_node("Monture")
				if autre.monture == "cheval" and autre.get_node_or_null("Bete") != null:
					vu = true
			if vu:
				break
		_verifier(vu, "on voit l'autre joueur sur son renne")
		var descendu := false
		for i in 60:
			await _secondes(0.2)
			for j in get_nodes_in_group("joueur"):
				if j != joueur and j.get_node("Monture").monture == "" and vu:
					descendu = true
			if descendu:
				break
		_verifier(descendu, "on le voit descendre de son renne")
	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
