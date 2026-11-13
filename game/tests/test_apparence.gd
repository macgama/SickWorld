extends SceneTree
## Test de l'apparence de l'agent : bonnes animations selon l'action, pieds au sol,
## translucidité quand le joueur est désynchronisé.
## Lancement : godot --headless --path game -s res://tests/test_apparence.gd

var _echecs := 0


func _verifier(condition: bool, message: String) -> void:
	print("  OK   " if condition else "  ÉCHEC ", message)
	if not condition:
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
	var joueur = get_first_node_in_group("joueur_local")
	var apparence = joueur.get_node("Apparence")
	print("Test de l'apparence")
	_verifier(apparence.get("_lecteur") != null, "le personnage MakeHuman est chargé")
	var maillages: Array = apparence.find_children("*", "MeshInstance3D", true, false)
	_verifier(maillages.size() >= 5, "corps, vêtements, cheveux trouvés (%d maillages)" % maillages.size())
	var sans_texture := maillages.filter(func(m): return m.material_override == null or m.material_override.albedo_texture == null)
	_verifier(sans_texture.is_empty(), "toutes les textures sont réappliquées")
	_verifier(apparence._actuelle == "immobile", "immobile au départ")

	var squelette: Skeleton3D = apparence.find_children("*", "Skeleton3D", true, false)[0]
	var orteil := squelette.global_transform * squelette.get_bone_global_pose(squelette.find_bone("mixamorig_LeftToeBase"))
	_verifier(absf(orteil.origin.y - joueur.global_position.y) < 0.12,
			"les pieds touchent le sol (écart %.2f m)" % (orteil.origin.y - joueur.global_position.y))

	Input.action_press("avancer")
	await _attendre(30)
	_verifier(apparence._actuelle == "courir", "court en avançant")
	# Les orteils sont devant les talons : le personnage regarde dans le sens de la marche.
	var orteil_g := squelette.global_transform * squelette.get_bone_global_rest(squelette.find_bone("mixamorig_LeftToe_End"))
	var talon_g := squelette.global_transform * squelette.get_bone_global_rest(squelette.find_bone("mixamorig_LeftFoot"))
	var devant: Vector3 = -joueur.global_transform.basis.z
	_verifier((orteil_g.origin - talon_g.origin).dot(devant) > 0.0, "regarde dans le sens de la marche")
	Input.action_release("avancer")
	await _attendre(30)
	_verifier(apparence._actuelle == "immobile", "s'arrête quand on lâche la touche")

	Input.action_press("reculer")
	await _attendre(20)
	_verifier(apparence._actuelle == "reculer", "recule en marche arrière")
	Input.action_release("reculer")
	await _attendre(20)

	Input.action_press("sauter")
	await _attendre(5)
	Input.action_release("sauter")
	_verifier(apparence._actuelle == "saut", "saute")
	await _attendre(60)

	Input.action_press("esquive")
	await _attendre(4)
	Input.action_release("esquive")
	_verifier(apparence._actuelle == "roulade", "fait une roulade")
	await _attendre(40)

	apparence.attaquer()
	await _attendre(2)
	_verifier(apparence._actuelle == "attaque", "frappe")
	await _attendre(60)

	joueur.get_node("Combat").subir(5000.0, null)
	await _attendre(10)
	_verifier(apparence._actuelle == "mort", "tombe à la mort")
	var translucides: Array = maillages.filter(func(m): return m.transparency > 0.5)
	_verifier(translucides.size() == maillages.size(), "devient translucide (désynchronisé)")
	joueur.get_node("Combat").reanimer(100.0)
	await _attendre(10)
	_verifier(apparence._actuelle == "immobile", "se relève à la réanimation")

	print("Résultat : ", "TOUT EST BON" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs)
	quit(0 if _echecs == 0 else 1)
