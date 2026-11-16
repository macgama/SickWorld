extends SceneTree
## Captures d'écran de la Campagne et des aqueducs (Rome, zone 2 ; fenêtre visible, pas
## en --headless).
## Lancement : godot --path game -s res://tests/capture_campagne.gd -- [dossier_sortie] [vue1,vue2…|-]

const VUES := [
	# nom, position caméra, point visé, hauteurs absolues ? (sinon relatives au sol)
	["arrivee", Vector3(-2, 2.0, 140), Vector3(20, 10.0, 40), false],
	["arches", Vector3(100, 2.0, 10), Vector3(60, 14.0, -26), false],
	["echafaudage", Vector3(96, 3.0, 8), Vector3(76, 12.0, 22), false],
	["canal", Vector3(66, 31.7, -2), Vector3(50, 30.6, -50), true],
	["canal_eau", Vector3(66, 31.7, -2), Vector3(50, 30.6, -50), true],
	["porte", Vector3(6, 2.0, -96), Vector3(-2, 10.0, -128), false],
	["villa", Vector3(-50, 4.0, 60), Vector3(-80, 2.0, 22), false],
	["carriere", Vector3(96, 6.0, -40), Vector3(122, -2.0, -60), false],
	["statio", Vector3(80, 2.0, 40), Vector3(94, 2.0, 26), false],
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_rome_campagne.cfg"))
	var scene: Node = load("res://scenes/monde/rome/campagne.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_rome_campagne.cfg"
	root.add_child(scene)
	current_scene = scene
	await _attendre(30)
	var joueur := get_first_node_in_group("joueur_local") as Node3D
	if joueur != null:
		joueur.visible = false
	var camera := Camera3D.new()
	camera.fov = 65.0
	camera.far = 4000.0
	scene.add_child(camera)
	camera.make_current()
	var choix := PackedStringArray()
	if args.size() > 1 and args[1] != "-":
		choix = args[1].split(",")
	for vue in VUES:
		if not choix.is_empty() and not choix.has(vue[0]):
			continue
		var pos: Vector3 = vue[1]
		var cible: Vector3 = vue[2]
		if not vue[3]:
			pos.y += scene.hauteur(pos.x, pos.z)
			cible.y += scene.hauteur(cible.x, cible.z)
		var eau: Node3D = scene.find_child("EauAqueduc", true, false)
		if eau != null:
			eau.visible = vue[0] == "canal_eau"
		camera.global_position = pos
		camera.look_at(cible)
		for n in scene.find_children("*", "CanvasLayer", true, false):
			(n as CanvasLayer).visible = false
		await _attendre(8)
		var image := root.get_texture().get_image()
		var sortie := dossier.path_join("campagne_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
