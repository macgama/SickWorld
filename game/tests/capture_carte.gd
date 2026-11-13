extends SceneTree
## Captures d'écran de la carte (fenêtre visible, pas en --headless) :
## la mini-carte en jeu, puis la grande carte après une petite promenade.
## Lancement : godot --path game -s res://tests/capture_carte.gd -- [hub|colline|qg] [dossier]


func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var lieu := args[0] if args.size() > 0 else "hub"
	var dossier := args[1] if args.size() > 1 else ProjectSettings.globalize_path("res://../docs/images")
	root.size = Vector2i(1600, 900)
	var cartographe = root.get_node("/root/Cartographe")
	cartographe.forcer_personnage("capture_carte")
	cartographe.effacer_personnage("capture_carte")
	var chemin := "res://scenes/monde/colline_de_test.tscn" if lieu == "colline" else "res://scenes/monde/hikari_bay.tscn"
	var scene: Node = load(chemin).instantiate()
	if scene.has_node("Intro"):
		scene.get_node("Intro").free()
	root.add_child(scene)
	current_scene = scene
	await _attendre(30)
	var joueur = get_first_node_in_group("joueur_local")
	var promenade: Array = {
		"colline": [Vector3(0, 8, 55), Vector3(-20, 8, 30), Vector3(-30, 8, 8), Vector3(-6, 16, -8)],
		"hub": [Vector3(0, 0.5, 22), Vector3(-20, 0.5, 5), Vector3(0, 0.5, -20), Vector3(25, 0.5, -5), Vector3(0, 0.5, 40)],
		"qg": [Vector3(-23, -11.5, 80), Vector3(-23, -11.5, 100), Vector3(-60, -11.5, 90), Vector3(15, -11.5, 90), Vector3(-23, -11.5, 122)],
	}[lieu]
	for p in promenade:
		joueur.teleporter(p, 0.4)
		await _attendre(25)
	await _attendre(60)
	var image := root.get_texture().get_image()
	image.save_jpg(dossier.path_join("carte-mini-%s.jpg" % lieu), 0.9)
	cartographe.get_child(0).afficher_grande_carte(true)
	await _attendre(20)
	image = root.get_texture().get_image()
	image.save_jpg(dossier.path_join("carte-grande-%s.jpg" % lieu), 0.9)
	print("Captures enregistrées dans ", dossier)
	cartographe.effacer_personnage("capture_carte")
	quit()
