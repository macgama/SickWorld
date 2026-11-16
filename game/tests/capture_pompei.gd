extends SceneTree
## Captures d'écran de Pompéi sous la cendre (Rome, zone 4 ; fenêtre visible, pas
## en --headless).
## Lancement : godot --path game -s res://tests/capture_pompei.gd -- [dossier_sortie] [vue1,vue2…|-]

const VUES := [
	# nom, position caméra, point visé, hauteurs absolues ? (sinon relatives au sol)
	["arrivee", Vector3(0, 2.0, -140), Vector3(0, 2.0, -60), false],
	["vesuve", Vector3(-10, 3.0, -100), Vector3(900, 300.0, -1500), false],
	["maison", Vector3(-30, 16.0, -46), Vector3(-38, 8.0, -54), true],
	["dans_maison", Vector3(-30, 1.7, -60), Vector3(-44, 1.5, -50), false],
	["forum", Vector3(20, 18.0, 40), Vector3(32, 8.0, 10), true],
	["temple", Vector3(30, 2.0, 0), Vector3(34, 6.0, -26), false],
	["amphitheatre", Vector3(70, 4.0, 40), Vector3(110, 4.0, 70), false],
	["haut", Vector3(100, 80.0, 100), Vector3(0, 0.0, -40), true],
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_pompei.cfg"))
	var scene: Node = load("res://scenes/monde/rome/pompei.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_pompei.cfg"
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
		var sortie := dossier.path_join("pompei_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
