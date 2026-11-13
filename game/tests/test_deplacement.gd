extends SceneTree
## Test automatique de l'étape 1 : on lance la colline, on simule des touches
## et on vérifie que le personnage se déplace correctement.
## Lancement : godot --headless --path game -s res://tests/test_deplacement.gd

var _echecs := 0


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


func _lancer() -> void:
	var scene: Node = load("res://scenes/monde/colline_de_test.tscn").instantiate()
	root.add_child(scene)
	await _attendre(30)
	var joueur: Joueur = scene.get_node("Joueur")
	print("Test du déplacement")
	_verifier(joueur.is_on_floor(), "le joueur est posé sur le sol au départ")
	var depart := joueur.global_position

	Input.action_press("avancer")
	await _attendre(60)
	Input.action_release("avancer")
	var parcouru := joueur.global_position - depart
	_verifier(parcouru.z < -4.0, "Z/W fait avancer vers le sommet (%.1f m)" % -parcouru.z)
	_verifier(absf(parcouru.x) < 0.5, "on avance tout droit")

	var avant_rotation := joueur.rotation.y
	Input.action_press("tourner_gauche")
	await _attendre(30)
	Input.action_release("tourner_gauche")
	_verifier(joueur.rotation.y > avant_rotation + 1.0, "Q/A fait tourner à gauche")
	_verifier(absf(angle_difference(joueur.camera.lacet, joueur.rotation.y)) < 0.05,
			"la caméra tourne avec le personnage")

	await _attendre(10)
	var avant_saut := joueur.global_position.y
	Input.action_press("sauter")
	await _attendre(2)
	Input.action_release("sauter")
	await _attendre(15)
	_verifier(joueur.global_position.y > avant_saut + 0.5, "Espace fait sauter")
	await _attendre(60)
	_verifier(joueur.is_on_floor(), "le joueur retombe sur le sol")

	var avant_esquive := joueur.global_position
	var endurance := joueur.endurance
	Input.action_press("esquive")
	await _attendre(2)
	Input.action_release("esquive")
	await _attendre(30)
	_verifier(joueur.global_position.distance_to(avant_esquive) > 3.0, "Maj fait une roulade")
	_verifier(joueur.endurance < endurance, "la roulade consomme de l'endurance")

	joueur.global_position = Vector3(0, -50, 0)
	await _attendre(3)
	_verifier(joueur.global_position.y > 0.0, "tomber hors du monde ramène au départ")

	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
