extends SceneTree
## Captures d'écran de la foire de Francfort (zone 4 ; fenêtre visible, pas en
## --headless).
## Lancement : godot --path game -s res://tests/capture_francfort.gd -- [dossier_sortie] [vue1,vue2…|-]

const VUES := [
	# nom, position caméra, point visé, hauteurs absolues ? (sinon relatives au sol)
	["arrivee", Vector3(-118, 2.0, 104), Vector3(-60, 4.0, 92), false],
	["quai", Vector3(-60, 2.0, 100), Vector3(10, 3.0, 92), false],
	["etals", Vector3(-30, 1.8, 82), Vector3(-24, 1.4, 90), false],
	["romer", Vector3(18, 2.0, 30), Vector3(-30, 8.0, 6), false],
	["bucher", Vector3(8, 1.8, 18), Vector3(-2, 2.0, 6), false],
	["dom", Vector3(10, 2.0, -6), Vector3(60, 22.0, -29), false],
	["pont", Vector3(20, 2.0, 92), Vector3(40, 6.0, 140), false],
	["pre", Vector3(104, 2.0, 10), Vector3(140, 3.0, -40), false],
	["eschenheim", Vector3(-20, 2.0, -100), Vector3(-30, 24.0, -154), false],
	["haut", Vector3(200, 140.0, 220), Vector3(0, 10.0, 0), true],
]


func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier := args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://")
	root.size = Vector2i(1280, 720)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_francfort.cfg"))
	var scene: Node = load("res://scenes/monde/mayence/francfort.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_francfort.cfg"
	root.add_child(scene)
	current_scene = scene
	await _attendre(60)
	var joueur := get_first_node_in_group("joueur_local") as Node3D
	if joueur != null:
		joueur.visible = false
	var camera := Camera3D.new()
	camera.fov = 65.0
	camera.far = 4000.0
	scene.add_child(camera)
	camera.make_current()
	for n in scene.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var choix := PackedStringArray()
	if args.size() > 1 and args[1] != "-":
		choix = args[1].split(",")
	for vue in VUES:
		if not choix.is_empty() and not choix.has(vue[0]):
			continue
		if vue[0] == "bucher":
			for n in get_nodes_in_group("decor_quete"):
				if n.get_meta("identifiant", "") in ["sceau", "feu_bucher"]:
					n.visible = true
			await _attendre(10)
		var pos: Vector3 = vue[1]
		var cible: Vector3 = vue[2]
		if not vue[3]:
			pos.y += scene.hauteur(pos.x, pos.z)
			cible.y += scene.hauteur(cible.x, cible.z)
		camera.global_position = pos
		camera.look_at(cible)
		for n in scene.find_children("*", "CanvasLayer", true, false):
			(n as CanvasLayer).visible = false
		await _attendre(8)
		var image := root.get_texture().get_image()
		var sortie := dossier.path_join("francfort_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
