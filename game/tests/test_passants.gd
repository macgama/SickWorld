extends SceneTree
## Les passants de Hikari Bay : chargés depuis data/hub_passants.json, leurs
## chemins ne traversent aucun mur, et ceux qui marchent avancent vraiment.
## Lancement : godot --headless --path game -s res://tests/test_passants.gd

var _echecs := 0
var FICHIER := "user://test_passants_%d.cfg" % OS.get_process_id()


func _verifier(condition: bool, message: String) -> void:
	print("  OK   " if condition else "  ÉCHEC ", message)
	if not condition:
		_echecs += 1


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	print("Test des passants")
	var cfg := ConfigFile.new()
	cfg.set_value("intro", "terminee", true)
	cfg.save(FICHIER)
	var scene: Node = load("res://scenes/monde/hikari_bay.tscn").instantiate()
	scene.get_node("Quetes").fichier_progression = FICHIER
	scene.get_node("Intro").fichier_progression = FICHIER
	root.add_child(scene)
	for i in 20:
		await physics_frame
	var passants := get_nodes_in_group("passants")
	var lu = JSON.parse_string(FileAccess.get_file_as_string("res://data/hub_passants.json"))
	_verifier(passants.size() == lu["passants"].size() and passants.size() > 0, "%d passants en ville" % passants.size())
	# Les chemins ne traversent pas les murs (boule de 35 cm à hauteur de hanche).
	var espace: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var requete := PhysicsShapeQueryParameters3D.new()
	var boule := SphereShape3D.new()
	boule.radius = 0.35
	requete.shape = boule
	for p in passants:
		var bloque := ""
		var chemin: PackedVector3Array = p.chemin
		for k in chemin.size():
			var a: Vector3 = chemin[k]
			var b: Vector3 = chemin[mini(k + 1, chemin.size() - 1)]
			var n := maxi(1, int(a.distance_to(b) / 0.5))
			for i in n + 1:
				var q := a.lerp(b, float(i) / n) + Vector3(0, 1.0, 0)
				requete.transform = Transform3D(Basis(), q)
				if espace.intersect_shape(requete, 1).size() > 0 and bloque == "":
					bloque = "(%.1f, %.1f)" % [q.x, q.z]
		_verifier(bloque == "", "%s : chemin libre %s" % [p.name, bloque])
	# Ils ne traversent pas les personnages immobiles (Pnj).
	for p in passants:
		var gene := ""
		var chemin: PackedVector3Array = p.chemin
		for pnj in get_nodes_in_group("pnj"):
			var c: Vector3 = (pnj as Node3D).global_position
			if absf(c.y) > 1.0:
				continue
			for k in chemin.size():
				var a: Vector3 = chemin[k]
				var b: Vector3 = chemin[mini(k + 1, chemin.size() - 1)]
				var proche := Geometry3D.get_closest_point_to_segment(Vector3(c.x, 0, c.z), a, b)
				if proche.distance_to(Vector3(c.x, 0, c.z)) < 1.0 and gene == "":
					gene = "%s %s" % [pnj.identifiant, c]
		_verifier(gene == "", "%s : ne traverse aucun personnage %s" % [p.name, gene])
	var depart := {}
	for p in passants:
		depart[p] = p.global_position
	for i in 420:
		await physics_frame
	var marchent := 0
	var attendent := 0
	for p in passants:
		var bouge: bool = p.global_position.distance_to(depart[p]) > 1.0
		if p.vitesse > 0.0:
			marchent += 1 if bouge else 0
		else:
			attendent += 0 if bouge else 1
	var mobiles := passants.filter(func(p): return p.vitesse > 0.0).size()
	for p in passants:
		if p.vitesse > 0.0 and p.global_position.distance_to(depart[p]) <= 1.0:
			print("    immobile : %s %s" % [p.name, p.global_position])
	_verifier(marchent == mobiles, "les %d marcheurs avancent (%d)" % [mobiles, marchent])
	_verifier(attendent == passants.size() - mobiles, "ceux qui attendent restent sur place")
	scene.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
