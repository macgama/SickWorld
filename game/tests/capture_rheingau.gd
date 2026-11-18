extends SceneTree
## Captures d'écran des vignes du Rheingau (Mayence, zone 1 ; fenêtre visible, pas en
## --headless).
## Lancement : godot --path game -s res://tests/capture_rheingau.gd -- [dossier_sortie] [vue1,vue2…|-]

const VUES := [
	# nom, position caméra, point visé, hauteurs absolues ? (sinon relatives au sol)
	["arrivee", Vector3(-118, 2.0, 100), Vector3(-136, 3.0, 110), false],
	["coteau", Vector3(-40, 2.0, 70), Vector3(-20, 6.0, 0), false],
	["rangs", Vector3(-30, 1.7, 30), Vector3(10, 1.0, 28), false],
	["terrasses", Vector3(60, 2.0, 56), Vector3(20, 0.0, -10), false],
	["village", Vector3(-30, 3.0, 70), Vector3(30, 4.0, 100), false],
	["pressoir", Vector3(-2, 1.8, 98), Vector3(-4, 2.0, 88), false],
	["rhin", Vector3(-60, 8.0, 60), Vector3(40, -4.0, 200), false],
	["abbaye", Vector3(-50, 3.0, -80), Vector3(-92, 6.0, -116), false],
	["cloitre", Vector3(-84, 1.8, -96), Vector3(-96, 1.5, -106), false],
	["foret", Vector3(10, 1.8, -110), Vector3(-10, 4.0, -150), false],
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_rheingau.cfg"))
	var scene: Node = load("res://scenes/monde/mayence/rheingau.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_rheingau.cfg"
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
		var sortie := dossier.path_join("rheingau_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
