extends SceneTree
## Capture de l'écran pendant un événement public (avec une quête secondaire en cours).
## Lancement : godot --path game -s res://tests/capture_evenement.gd -- [dossier_sortie]

func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier := args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://")
	root.size = Vector2i(1280, 720)
	var fichier := "user://capture_evenement.cfg"
	var cfg := ConfigFile.new()
	cfg.set_value("prehistoire", "etape", "murs_vides")
	cfg.set_value("prehistoire_secondaires", "etat_premier_collier", 0)
	cfg.save(fichier)
	var scene: Node = load("res://scenes/monde/prehistoire/steppe.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = fichier
	root.add_child(scene)
	current_scene = scene
	await _attendre(30)
	var joueur = get_first_node_in_group("joueur_local")
	var p := Vector3(-40, 0, 110)
	p.y = scene.hauteur(p.x, p.z) + 0.3
	joueur.teleporter(p, 0.6)
	joueur.camera.lacet = 0.6
	var evt = get_first_node_in_group("evenements_publics")
	# Le chargement est lent sans carte graphique : l'horloge a pu lancer un événement.
	for id in evt.prochain:
		evt.prochain[id] = 1e12
	if evt.en_cours():
		evt._finir(false)
	evt.declencher("grande_migration")
	await _attendre(40)
	root.get_texture().get_image().save_jpg(dossier.path_join("evenement_migration.jpg"), 0.88)
	evt._finir(true)
	await _attendre(30)
	evt.declencher("tempete_blanche")
	await _attendre(30)
	root.get_texture().get_image().save_jpg(dossier.path_join("evenement_tempete.jpg"), 0.88)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fichier))
	quit()
