extends SceneTree
## Captures d'écran de la la ville de Rome (Rome, zone 3 ; fenêtre visible, pas
## en --headless).
## Lancement : godot --path game -s res://tests/capture_rome.gd -- [dossier_sortie] [vue1,vue2…|-]

const VUES := [
	# nom, position caméra, point visé, hauteurs absolues ? (sinon relatives au sol)
	["arrivee", Vector3(126, 2.0, 146), Vector3(100, 8.0, 60), false],
	["colisee", Vector3(118, 3.0, 40), Vector3(72, 14.0, -16), false],
	["colosse", Vector3(-4, 2.0, -34), Vector3(14, 20.0, -60), false],
	["forum", Vector3(-10, 38.0, -40), Vector3(-70, 12.0, -40), true],
	["capitole", Vector3(-66, 44.0, 20), Vector3(-132, 32.0, -40), true],
	["subure", Vector3(36, 2.0, -100), Vector3(16, 3.0, -118), false],
	["place_ble", Vector3(16, 2.0, -104), Vector3(16, 1.0, -118), false],
	["champ_mars", Vector3(-80, 4.0, -110), Vector3(-112, 6.0, -128), false],
	["vivarium", Vector3(120, 3.0, 80), Vector3(144, 1.0, 104), false],
	["haut", Vector3(150, 80.0, 150), Vector3(0, 0.0, -40), true],
	["incendie", Vector3(-100, 3.0, -96), Vector3(-120, 1.0, -124), false],
	["oies", Vector3(-136, 2.5, -20), Vector3(-142, 0.5, -28), false],
	["pantheon", Vector3(-90, 3.0, -160), Vector3(-108, 6.0, -132), false],
	["quartiers", Vector3(100, 2.0, 0), Vector3(130, 6.0, -60), false],
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_rome_ville.cfg"))
	var scene: Node = load("res://scenes/monde/rome/rome.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_rome_ville.cfg"
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
		var sortie := dossier.path_join("rome_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
