extends SceneTree
## Retour d'une île par le portail : le joueur doit apparaître dans la salle des
## portails du QG (sous la place), debout sur le sol, et pas dans le vide.
## Lancement : godot --headless --path game -s res://tests/test_retour_portail.gd

const QgVigie := preload("res://scripts/monde/qg_vigie.gd")

var _echecs := 0
var FICHIER := "user://test_retour_portail_%d.cfg" % OS.get_process_id()


func _verifier(condition: bool, message: String) -> void:
	print("  OK   " if condition else "  ÉCHEC ", message)
	if not condition:
		_echecs += 1


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	print("Test du retour au hub par le portail")
	var cfg := ConfigFile.new()
	cfg.set_value("intro", "terminee", true)
	cfg.save(FICHIER)
	for cas in [{"arrivee_hub": "portails"}, {"arrivee_hub": "portails", "visite_guidee_qg": true}]:
		var reseau := root.get_node("Reseau")
		for cle in cas:
			reseau.set_meta(cle, cas[cle])
		var scene: Node = load("res://scenes/monde/hikari_bay.tscn").instantiate()
		scene.get_node("Quetes").fichier_progression = FICHIER
		scene.get_node("Intro").fichier_progression = FICHIER
		root.add_child(scene)
		for i in 180:
			await physics_frame
		var joueur := get_first_node_in_group("joueur_local") as Node3D
		var p := joueur.global_position
		var salle := QgVigie.PORTAILS.grow(0.5)
		_verifier(salle.has_point(Vector2(p.x, p.z)), "%s : le joueur est dans la salle des portails (%.1f, %.1f)" % [cas.keys(), p.x, p.z])
		_verifier(absf(p.y - QgVigie.SOL) < 1.0, "%s : il est debout sur le sol du QG (y = %.1f)" % [cas.keys(), p.y])
		scene.free()
		for i in 5:
			await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
