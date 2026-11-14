extends SceneTree
## Captures d'écran des montures (fenêtre visible, pas en --headless).
## Lancement : godot --path game -s res://tests/capture_montures.gd -- [dossier_sortie]

func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _capturer(scene_chemin: String, id: String, dossier: String, prefixe: String, vitesse := 0.0) -> void:
	var scene: Node = load(scene_chemin).instantiate()
	if scene.has_node("Quete"):
		scene.get_node("Quete").voyage_reel = false
		scene.get_node("Quete").fichier_progression = "user://capture_progression.cfg"
	root.add_child(scene)
	current_scene = scene
	await _attendre(20)
	for n in scene.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var joueur = get_first_node_in_group("joueur_local")
	joueur.get_node("Monture").monture = id
	var camera := Camera3D.new()
	camera.fov = 55.0
	camera.far = 3000.0
	scene.add_child(camera)
	camera.make_current()
	var vues := [["profil", Vector3(4.2, 1.6, 0.0)], ["trois_quarts", Vector3(3.0, 2.2, -3.5)],
			["dos", Vector3(-1.2, 2.8, 4.5)], ["tete", Vector3(1.4, 1.4, -2.2)]]
	for vue in vues:
		for i in 40:
			await physics_frame
			if vitesse > 0.0:
				joueur.get_node("Monture").animer(1.0 / 60.0, Vector3(0, 0, -vitesse), true)
		var base: Vector3 = joueur.global_position
		camera.global_position = base + joueur.global_transform.basis * (vue[1] as Vector3)
		camera.look_at(base + (joueur.global_transform.basis * Vector3(0, 1.0, -0.9) if vue[0] == "tete" else Vector3.UP * 1.3))
		await _attendre(3)
		var sortie := dossier.path_join("%s_%s.jpg" % [prefixe, vue[0]])
		root.get_texture().get_image().save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	scene.queue_free()
	await _attendre(5)


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier := args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://")
	root.size = Vector2i(1280, 720)
	var choix := args.slice(1)
	if choix.is_empty() or "renne" in choix:
		await _capturer("res://scenes/monde/prehistoire/steppe.tscn", "renne", dossier, "renne")
	if choix.is_empty() or "galop" in choix:
		await _capturer("res://scenes/monde/prehistoire/steppe.tscn", "renne", dossier, "galop", 11.0)
	if choix.is_empty() or "ane" in choix:
		await _capturer("res://scenes/monde/egypte/port_des_marais.tscn", "ane", dossier, "ane")
	quit()
