extends SceneTree
## Captures d'écran de l'amphithéâtre flavien (Rome, le Colisée ; fenêtre visible, pas
## en --headless).
## Lancement : godot --path game -s res://tests/capture_colisee.gd -- [dossier_sortie] [vue1,vue2…|-]

const VUES := [
	# nom, position caméra, point visé, hauteurs absolues ? (sinon relatives au sol)
	["arrivee", Vector3(-42.6, 5.8, 0), Vector3(40, 6.0, 0), true],
	["arene", Vector3(-28, 1.8, 6), Vector3(40, 16.0, -10), true],
	["loge", Vector3(0, 3.0, 6), Vector3(0, 7.0, 27), true],
	["gradins", Vector3(14, 5.8, -25), Vector3(-6, 22.0, -60), true],
	["haut", Vector3(0, 30.0, -66), Vector3(0, 0.0, 10), true],
	["velarium", Vector3(-6, 1.8, -4), Vector3(10, 40.0, 30), true],
	["dessus", Vector3(110, 95.0, 110), Vector3(0, 0.0, 0), true],
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_colisee.cfg"))
	var scene: Node = load("res://scenes/monde/rome/colisee.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_colisee.cfg"
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
	for n in scene.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
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
		camera.global_position = pos
		camera.look_at(cible)
		for n in scene.find_children("*", "CanvasLayer", true, false):
			(n as CanvasLayer).visible = false
		await _attendre(8)
		var image := root.get_texture().get_image()
		var sortie := dossier.path_join("colisee_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
