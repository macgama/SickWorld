extends SceneTree
## Captures d'écran de du chantier de la cathédrale (Moyen Âge, zone 4 ; fenêtre visible, pas en
## --headless).
## Lancement : godot --path game -s res://tests/capture_chantier.gd -- [dossier_sortie] [vue1,vue2…|-]

const VUES := [
	["arrivee", Vector3(-68, 1.8, 0), Vector3(-30, 6.0, 0), false],
	["nef", Vector3(-50, 2.0, 10), Vector3(20, 10.0, -6), false],
	["grue", Vector3(-30, 2.0, -2), Vector3(-14, 5.0, 9), false],
	["loge", Vector3(-20, 1.8, 24), Vector3(-34, 1.5, 40), false],
	["beffroi", Vector3(20, 2.0, 50), Vector3(40, 8.0, 64), false],
	["atelier", Vector3(-30, 1.8, -44), Vector3(-32, 2.0, -66), false],
	["choeur", Vector3(30, 2.0, 6), Vector3(76, 6.0, 0), false],
	["crypte", Vector3(31, 6.0, -22), Vector3(31, 0.0, -48), false],
	["haut", Vector3(-150, 90.0, 120), Vector3(0, 0.0, 0), true],
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_chantier.cfg"))
	var scene: Node = load("res://scenes/monde/moyen_age/chantier.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_chantier.cfg"
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
		var sortie := dossier.path_join("chantier_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
