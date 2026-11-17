extends SceneTree
## Captures d'écran de la grande audience (Chine, chapitre 7, au Palais du Sud de Luoyang ;
## fenêtre visible, pas en --headless). Le 3e argument est l'étape de la quête à charger.
## Lancement : godot --path game -s res://tests/capture_audience.gd -- [dossier_sortie] [vue1,vue2…|-] [etape]

const VUES := [
	["cour", Vector3(20, 2.0, 50), Vector3(20, 3.0, 86), false],
	["trone", Vector3(20, 3.4, 78), Vector3(20, 3.6, 87), false],
	["fonctionnaires", Vector3(-4, 2.2, 60), Vector3(20, 1.5, 74), false],
	["porte", Vector3(20, 2.0, 62), Vector3(20, 2.0, 44), false],
	["sechoirs", Vector3(36, 2.0, 56), Vector3(44, 1.4, 66), false],
	["haut", Vector3(-10, 30.0, 30), Vector3(20, 0.0, 74), false],
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_audience.cfg"))
	if args.size() > 2:
		var cfg := ConfigFile.new()
		cfg.set_value("chine", "etape", args[2])
		cfg.save("user://capture_audience.cfg")
	var scene: Node = load("res://scenes/monde/chine/luoyang.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_audience.cfg"
	root.add_child(scene)
	current_scene = scene
	await _attendre(30)
	var joueur := get_first_node_in_group("joueur_local") as Node3D
	if joueur != null:
		joueur.visible = false
		joueur.global_position = Vector3(20, scene.hauteur(20, 60) + 0.5, 60)
	await _attendre(60)
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
		var sortie := dossier.path_join("audience_%s_%s.jpg" % [args[2] if args.size() > 2 else "debut", vue[0]])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
