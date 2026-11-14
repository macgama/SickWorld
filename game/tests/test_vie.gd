extends SceneTree
## Les détails de vie de Hikari Bay (data/hub_vie.json) : les pigeons picorent
## sur un sol libre, s'envolent vers leur perchoir quand le joueur approche et
## redescendent quand il s'éloigne ; les bouches d'égout fument dans la rue.
## Lancement : godot --headless --path game -s res://tests/test_vie.gd

var _echecs := 0
var FICHIER := "user://test_vie_%d.cfg" % OS.get_process_id()


func _verifier(condition: bool, message: String) -> void:
	print("  OK   " if condition else "  ÉCHEC ", message)
	if not condition:
		_echecs += 1


func _initialize() -> void:
	_lancer.call_deferred()


func _attendre(images: int) -> void:
	for i in images:
		await physics_frame


func _lancer() -> void:
	print("Test des détails de vie")
	var cfg := ConfigFile.new()
	cfg.set_value("intro", "terminee", true)
	cfg.save(FICHIER)
	var scene: Node = load("res://scenes/monde/hikari_bay.tscn").instantiate()
	scene.get_node("Quetes").fichier_progression = FICHIER
	scene.get_node("Intro").fichier_progression = FICHIER
	root.add_child(scene)
	await _attendre(20)
	var lu = JSON.parse_string(FileAccess.get_file_as_string("res://data/hub_vie.json"))
	var volees := get_nodes_in_group("pigeons")
	_verifier(volees.size() == lu["pigeons"].size(), "%d volées de pigeons en ville" % volees.size())
	var espace: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state

	# Chaque coin de picorage et chaque bouche d'égout est dehors, au niveau du sol.
	var points := []
	for v in volees:
		points.append([v.name, Vector2(v.sol.x, v.sol.z)])
	for xz in lu["plaques"]:
		points.append(["plaque", Vector2(xz[0], xz[1])])
	for p in points:
		var c: Vector2 = p[1]
		var dehors := true
		for d in [Vector2.ZERO, Vector2(1.5, 0), Vector2(-1.5, 0), Vector2(0, 1.5), Vector2(0, -1.5)]:
			var q: Vector2 = c + d
			var r := espace.intersect_ray(PhysicsRayQueryParameters3D.create(
					Vector3(q.x, 30, q.y), Vector3(q.x, -2, q.y)))
			if r.is_empty() or absf(r.position.y) > 0.1:
				dehors = false
		_verifier(dehors, "%s (%.0f, %.0f) : en plein air, au sol" % [p[0], c.x, c.y])

	# Le joueur s'approche de la première volée : elle s'envole vers son perchoir.
	var joueur = get_first_node_in_group("joueur_local")
	var v = volees[0]
	_verifier(v.etat == v.Etat.SOL, "les pigeons picorent au sol au départ")
	joueur.teleporter(v.sol + Vector3(2.0, 0.3, 0), 0.0)
	await _attendre(10)
	_verifier(v.etat == v.Etat.VOL, "ils s'envolent quand le joueur approche")
	await _attendre(360)
	_verifier(v.etat == v.Etat.PERCHE, "ils se posent sur leur perchoir")
	var hauts := true
	for o in v.get_children():
		if absf((o as Node3D).global_position.y - v.perchoir.y) > 0.05 \
				or Vector2(o.global_position.x - v.perchoir.x, o.global_position.z - v.perchoir.z).length() > 1.2:
			hauts = false
	_verifier(hauts, "tous sont sur le perchoir (y = %.1f)" % v.perchoir.y)
	# Le joueur reste à côté : ils ne redescendent pas.
	await _attendre(60 * 27)
	_verifier(v.etat == v.Etat.PERCHE, "ils restent perchés tant que le joueur est là")
	# Il s'éloigne : ils reviennent picorer.
	joueur.teleporter(v.sol + Vector3(25.0, 0.3, 0), 0.0)
	await _attendre(60 * 6)
	_verifier(v.etat == v.Etat.SOL, "ils redescendent picorer quand il s'éloigne")
	var au_sol := true
	for o in v.get_children():
		if absf((o as Node3D).global_position.y - v.sol.y) > 0.05:
			au_sol = false
	_verifier(au_sol, "tous ont les pattes au sol")

	DirAccess.remove_absolute(FICHIER)
	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
