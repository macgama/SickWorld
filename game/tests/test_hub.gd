extends SceneTree
## Test automatique du hub Hikari Bay (Place Hikari) : le joueur arrive sur la
## place, peut marcher, descendre l'escalier de la station Asahi, et les
## barrières de chantier l'empêchent de sortir du quartier.
## Lancement : godot --headless --path game -s res://tests/test_hub.gd

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
	_verifier(joueur.global_position.z > 30.0 and joueur.global_position.z < 40.0,
			"le couloir mène à la porte du QG (z = %.1f)" % joueur.global_position.z)
	# Et on remonte.
	await _placer(joueur, Vector3(-23, -3.7, 30), 0.0)
	await _avancer(joueur, 300)
	_verifier(joueur.global_position.y > -0.5 and joueur.global_position.z < 12.0,
			"on peut remonter sur la place (y = %.2f, z = %.1f)" % [joueur.global_position.y, joueur.global_position.z])

	# Barrière de chantier de la rue du Marché de nuit (nord-ouest).
	await _placer(joueur, Vector3(-20, 0.3, -40), 0.0)
	await _avancer(joueur, 180)
	_verifier(joueur.global_position.z > -57.0, "la barrière de chantier bloque la rue (z = %.1f)" % joueur.global_position.z)

	# Le garde-corps du quai empêche de tomber dans la mer.
	await _placer(joueur, Vector3(0, 0.3, 64), PI)
	await _avancer(joueur, 120)
	_verifier(joueur.global_position.z < 74.0, "le garde-corps retient au bord de l'eau (z = %.1f)" % joueur.global_position.z)

	# La ville qui change : réparer la Préhistoire cache les éclats de fracture.
	var eclats = scene.find_child("EclatsDeFracture", true, false)
	_verifier(eclats != null and eclats.visible, "la statue porte des éclats de fracture au départ")
	scene.prehistoire_reparee = true
	_verifier(not eclats.visible, "ils disparaissent quand la Préhistoire est réparée")

	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
