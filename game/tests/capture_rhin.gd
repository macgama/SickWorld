extends SceneTree
## Captures d'écran du Rhin et du moulin à papier (Mayence, zone 2 ; fenêtre visible, pas en
## --headless).
## Lancement : godot --path game -s res://tests/capture_rhin.gd -- [dossier_sortie] [vue1,vue2…|-]

const VUES := [
	# nom, position caméra, point visé, hauteurs absolues ? (sinon relatives au sol)
	["arrivee", Vector3(-150, 2.0, 109), Vector3(-100, 6.0, 100), false],
	["port", Vector3(-80, 2.2, 112), Vector3(-30, 3.0, 120), false],
	["quai", Vector3(-10, 2.0, 112), Vector3(-40, 1.0, 126), false],
	["chateau", Vector3(-80, 2.0, 112), Vector3(-112, 12.0, 86), false],
	["pont", Vector3(50, 2.0, 100), Vector3(66, 0.0, 112), false],
	["vallon", Vector3(74, 2.0, 60), Vector3(66, -2.0, 0), false],
	["moulin", Vector3(64, 2.0, -6), Vector3(78, 2.0, -26), false],
	["sechoirs", Vector3(88, 1.8, -32), Vector3(104, 2.0, -24), false],
	["foret", Vector3(100, 1.8, -80), Vector3(120, 3.0, -116), false],
	["rhin", Vector3(20, 6.0, 118), Vector3(-60, 2.0, 150), false],
	["haut", Vector3(150, 120.0, 220), Vector3(0, 10.0, 0), true],
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_rhin.cfg"))
	var scene: Node = load("res://scenes/monde/mayence/rhin.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_rhin.cfg"
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
		var sortie := dossier.path_join("rhin_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
