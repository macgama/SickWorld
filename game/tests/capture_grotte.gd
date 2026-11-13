extends SceneTree
## Captures d'écran de la Grande Grotte (fenêtre visible, pas en --headless).
## Lancement : godot --path game -s res://tests/capture_grotte.gd -- [dossier_sortie]

const VUES := [
	# nom, position caméra, point visé (hauteurs au-dessus du sol)
	["entree", Vector3(0, 1.8, 92), Vector3(0, 2.0, 64)],
	["galerie", Vector3(-24, 1.8, 10), Vector3(-42, 3.0, 24)],
	["cristaux", Vector3(6, 1.8, -12), Vector3(16, 1.0, -30)],
	["antre", Vector3(0, 3.0, -56), Vector3(0, 3.0, -92)],
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
	var scene: Node = load("res://scenes/monde/prehistoire/grotte.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_progression.cfg"
	root.add_child(scene)
	current_scene = scene
	await _attendre(10)
	# Le clan est à l'abri (comme après le chapitre 6).
	for n in get_nodes_in_group("decor_quete"):
		if n.get_meta("identifiant", "") == "clan_abri":
			n.visible = true
	for n in scene.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var camera := Camera3D.new()
	camera.fov = 70.0
	camera.far = 3000.0
	scene.add_child(camera)
	# La torche du joueur (il n'y a pas de joueur pendant la capture).
	var torche := OmniLight3D.new()
	torche.light_color = Color(1.0, 0.62, 0.3)
	torche.light_energy = 2.6
	torche.omni_range = 14.0
	torche.position = Vector3(0.6, 0.2, 0.5)
	camera.add_child(torche)
	camera.make_current()
	var choisies := args.slice(1)
	for vue in VUES:
		if not choisies.is_empty() and not vue[0] in choisies:
			continue
		var pos: Vector3 = vue[1]
		var cible: Vector3 = vue[2]
		pos.y += scene.hauteur(pos.x, pos.z)
		cible.y += scene.hauteur(cible.x, cible.z)
		camera.global_position = pos
		camera.look_at(cible)
		await _attendre(5)
		var image := root.get_texture().get_image()
		var sortie := dossier.path_join("grotte_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
