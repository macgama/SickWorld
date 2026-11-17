extends SceneTree
## Captures d'écran de la Fleuve Jaune et des terres de lœss (Chine, zone 2 ; fenêtre visible, pas en
## --headless).
## Lancement : godot --path game -s res://tests/capture_fleuve_jaune.gd -- [dossier_sortie] [vue1,vue2…|-]

const VUES := [
	# nom, position caméra, point visé, hauteurs absolues ? (sinon relatives au sol)
	["arrivee", Vector3(-160, 2.0, 12), Vector3(-60, 6.0, -20), false],
	["grottes", Vector3(-62, 2.0, -28), Vector3(-66, 3.0, -56), false],
	["mei", Vector3(-62, 1.8, -40), Vector3(-66, 0.8, -50), false],
	["terrasses", Vector3(20, 3.0, -50), Vector3(-60, 14.0, -130), false],
	["muriers", Vector3(-20, 2.0, -14), Vector3(-70, 1.5, -24), false],
	["papetiers", Vector3(26, 2.0, 22), Vector3(26, 1.0, 50), false],
	["cuves", Vector3(24, 1.8, 46), Vector3(26, 0.5, 56), false],
	["champs", Vector3(-70, 3.0, 20), Vector3(-120, 0.0, 70), false],
	["bac", Vector3(66, 3.0, 18), Vector3(100, 0.0, 8), false],
	["fleuve", Vector3(76, 4.0, -40), Vector3(140, 0.0, 30), false],
	["rive_est", Vector3(126, 3.0, 16), Vector3(160, 2.0, 0), true],
	["haut", Vector3(160, 110.0, 160), Vector3(-20, 0.0, -20), true],
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_fleuve_jaune.cfg"))
	var scene: Node = load("res://scenes/monde/chine/fleuve_jaune.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_fleuve_jaune.cfg"
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
		var sortie := dossier.path_join("fleuve_jaune_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
