extends SceneTree
## Captures d'écran de la Porte de Jade (Chine, zone 1 ; fenêtre visible, pas en
## --headless).
## Lancement : godot --path game -s res://tests/capture_porte_de_jade.gd -- [dossier_sortie] [vue1,vue2…|-]

const VUES := [
	# nom, position caméra, point visé, hauteurs absolues ? (sinon relatives au sol)
	["arrivee", Vector3(-66, 2.0, 70), Vector3(-72, 4.0, 96), false],
	["masque", Vector3(-64, 1.8, 80), Vector3(-60, 1.2, 75), false],
	["muraille", Vector3(-40, 2.0, -50), Vector3(-90, 4.0, -76), false],
	["tour", Vector3(-12, 2.2, -38), Vector3(-20, 6.0, -60), false],
	["fort", Vector3(-6, 2.5, -10), Vector3(27, 5.0, -23), false],
	["cour", Vector3(18, 2.0, -24), Vector3(30, 1.0, -22), false],
	["relais", Vector3(74, 2.5, 8), Vector3(74, 1.5, 32), false],
	["caravane", Vector3(-74, 2.0, -18), Vector3(-86, 1.5, -30), false],
	["lac", Vector3(60, 3.0, 70), Vector3(104, 1.0, 98), false],
	["dunes", Vector3(0, 4.0, -90), Vector3(-40, 6.0, -150), false],
	["haut", Vector3(160, 90.0, 140), Vector3(0, 0.0, -20), true],
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_porte_de_jade.cfg"))
	var scene: Node = load("res://scenes/monde/chine/porte_de_jade.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_porte_de_jade.cfg"
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
		var sortie := dossier.path_join("porte_de_jade_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
