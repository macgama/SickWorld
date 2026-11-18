extends SceneTree
## Captures d'écran des carrières de Berchères (Moyen Âge, zone 2 ; fenêtre visible, pas en
## --headless).
## Lancement : godot --path game -s res://tests/capture_bercheres.gd -- [dossier_sortie] [vue1,vue2…|-]

const VUES := [
	["arrivee", Vector3(-144, 2.0, 138), Vector3(-100, 2.0, 108), false],
	["bord", Vector3(-6, 2.2, 10), Vector3(50, -6.0, 0), false],
	["fond", Vector3(30, 1.8, 10), Vector3(60, 2.0, -20), false],
	["rampe", Vector3(54, 2.0, 14), Vector3(84, 2.0, -54), false],
	["roue", Vector3(112, 2.5, 36), Vector3(98, 3.0, 22), false],
	["camp", Vector3(96, 2.0, -34), Vector3(112, 2.0, -50), false],
	["foret", Vector3(-60, 1.8, 40), Vector3(-90, 2.0, 18), false],
	["brigands", Vector3(-96, 2.0, -78), Vector3(-104, 1.0, -88), false],
	["haut", Vector3(150, 90.0, 120), Vector3(30, 0.0, -10), true],
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_bercheres.cfg"))
	var scene: Node = load("res://scenes/monde/moyen_age/bercheres.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_bercheres.cfg"
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
		var sortie := dossier.path_join("bercheres_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
