extends SceneTree
## Captures d'écran de Chartres (Moyen Âge, zone 3 ; fenêtre visible, pas en
## --headless).
## Lancement : godot --path game -s res://tests/capture_chartres.gd -- [dossier_sortie] [vue1,vue2…|-]

const VUES := [
	["arrivee", Vector3(-160, 2.0, 150), Vector3(-104, 10.0, 30), false],
	["porte", Vector3(-124, 2.0, 40), Vector3(-104, 4.0, 30), false],
	["grand_rue", Vector3(-80, 1.8, 20), Vector3(-30, 4.0, -20), false],
	["marche", Vector3(-6, 2.0, -6), Vector3(-30, 2.0, -30), false],
	["parvis", Vector3(-86, 1.8, -112), Vector3(-40, 14.0, -110), false],
	["facade", Vector3(-70, 1.8, -96), Vector3(-36, 30.0, -112), false],
	["ville_basse", Vector3(50, 2.0, -15), Vector3(86, 1.0, -12), false],
	["eure", Vector3(146, 12.0, 46), Vector3(126, 0.0, 10), true],
	["haut", Vector3(220, 120.0, 180), Vector3(0, 0.0, -40), true],
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_chartres.cfg"))
	var scene: Node = load("res://scenes/monde/moyen_age/chartres.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_chartres.cfg"
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
		var sortie := dossier.path_join("chartres_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
