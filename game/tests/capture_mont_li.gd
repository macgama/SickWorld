extends SceneTree
## Captures d'écran de du mont Li (Chine, zone 4 ; fenêtre visible, pas en
## --headless).
## Lancement : godot --path game -s res://tests/capture_mont_li.gd -- [dossier_sortie] [vue1,vue2…|-]

const VUES := [
	# nom, position caméra, point visé, hauteurs absolues ? (sinon relatives au sol)
	["arrivee", Vector3(160, 2.2, 16), Vector3(100, 3.0, 0), false],
	["hameau", Vector3(132, 2.0, 50), Vector3(122, 1.0, 42), false],
	["fosse", Vector3(92, 3.0, -30), Vector3(40, -2.0, -46), false],
	["fosse_dedans", Vector3(70, 1.8, -44), Vector3(30, 1.2, -44), false],
	["chevaux", Vector3(64, 4.0, 36), Vector3(34, 0.0, 22), false],
	["tumulus", Vector3(-20, 2.0, 10), Vector3(-84, 20.0, -84), false],
	["entree", Vector3(-84, 2.0, -4), Vector3(-84, 2.0, -26), false],
	["camp", Vector3(100, 2.5, -80), Vector3(124, 0.5, -108), false],
	["bambous", Vector3(-100, 2.0, 80), Vector3(-120, 3.0, 112), false],
	["cheval_pres", Vector3(28, 2.0, 20), Vector3(22, 1.0, 15), false],
	["soldats_pres", Vector3(30, 2.0, -38), Vector3(22, 1.0, -37), false],
	["fosse_dessus", Vector3(40, 22.0, -10), Vector3(40, 0.0, -40), true],
	["haut", Vector3(180, 110.0, 160), Vector3(-10, 0.0, -30), true],
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_mont_li.cfg"))
	var scene: Node = load("res://scenes/monde/chine/mont_li.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_mont_li.cfg"
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
		var sortie := dossier.path_join("mont_li_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
