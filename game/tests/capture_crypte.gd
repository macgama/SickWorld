extends SceneTree
## Captures d'écran de de la crypte de Fulbert (Moyen Âge, donjon ; fenêtre visible, pas en
## --headless).
## Lancement : godot --path game -s res://tests/capture_crypte.gd -- [dossier_sortie] [vue1,vue2…|-]

const VUES := [
	["escalier", Vector3(0, 1.7, -99), Vector3(0, -6.0, -84), true],
	["galerie", Vector3(0, 1.7, -78), Vector3(0, 1.5, -50), false],
	["puits", Vector3(-12, 3.0, -38), Vector3(0, 0.5, -26), false],
	["inscription", Vector3(12, 1.7, -31), Vector3(17, 1.4, -31), false],
	["lac", Vector3(0, 3.0, 6), Vector3(0, 6.0, 50), false],
	["brasier", Vector3(-10, 2.0, 30), Vector3(0, 8.0, 53), false],
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_crypte.cfg"))
	var scene: Node = load("res://scenes/monde/moyen_age/crypte.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_crypte.cfg"
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
		var sortie := dossier.path_join("crypte_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
