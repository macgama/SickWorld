extends SceneTree
## Captures d'écran de Luoyang (Chine, zone 3 ; fenêtre visible, pas en
## --headless).
## Lancement : godot --path game -s res://tests/capture_luoyang.gd -- [dossier_sortie] [vue1,vue2…|-]

const VUES := [
	# nom, position caméra, point visé, hauteurs absolues ? (sinon relatives au sol)
	["arrivee", Vector3(-180, 2.0, 26), Vector3(-150, 6.0, 20), false],
	["avenue", Vector3(-140, 2.2, 22), Vector3(-40, 3.0, 20), false],
	["palais_sud", Vector3(20, 2.0, 30), Vector3(20, 6.0, 94), false],
	["galerie", Vector3(26, 2.0, -40), Vector3(20, 4.0, 40), false],
	["pavillon", Vector3(96, 2.0, 52), Vector3(103, 4.0, 76), false],
	["bibliotheque", Vector3(100, 3.4, 68), Vector3(104, 2.2, 78), false],
	["atelier", Vector3(-96, 2.0, -32), Vector3(-110, 0.8, -50), false],
	["marche", Vector3(-80, 2.0, 46), Vector3(-110, 1.5, 72), false],
	["parc", Vector3(-84, 2.0, -100), Vector3(-116, 1.0, -124), false],
	["academie", Vector3(100, 2.0, -100), Vector3(100, 4.0, -130), false],
	["lingtai", Vector3(90, 2.0, -24), Vector3(112, 6.0, -40), false],
	["haut", Vector3(-200, 120.0, 180), Vector3(0, 0.0, -10), true],
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_luoyang.cfg"))
	var scene: Node = load("res://scenes/monde/chine/luoyang.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_luoyang.cfg"
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
		var sortie := dossier.path_join("luoyang_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
