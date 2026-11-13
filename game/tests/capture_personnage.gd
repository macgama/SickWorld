extends SceneTree
## Capture d'écran du personnage en jeu (fenêtre visible, pas en --headless).
## Lancement : godot --path game -s res://tests/capture_personnage.gd -- [homme|femme] [chemin.jpg]


func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var modele := args[0] if args.size() > 0 else "homme"
	var sortie := args[1] if args.size() > 1 else ProjectSettings.globalize_path("res://../docs/images/personnage-en-jeu.jpg")
	root.size = Vector2i(1600, 900)
	var scene: Node = load("res://scenes/monde/colline_de_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _attendre(20)
	var joueur = get_first_node_in_group("joueur_local")
	joueur.get_node("Apparence").modele = modele
	# On cache l'interface pour ne garder que le personnage.
	for n in scene.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var rig = joueur.get_node("CameraRig")
	rig.distance = 3.2
	rig.set("_distance_voulue", 3.2)
	rig.retour_automatique = 0.0
	rig.lacet = deg_to_rad(150.0)
	rig.tangage = deg_to_rad(-8.0)
	rig.hauteur_visee = 1.2
	await _attendre(90)
	var image := root.get_texture().get_image()
	image.save_jpg(sortie, 0.9)
	print("Capture : ", sortie)
	quit()
