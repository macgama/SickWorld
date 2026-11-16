extends SceneTree
## Captures d'écran d'Athènes (Grèce, fenêtre visible, pas en --headless).
## Lancement : godot --path game -s res://tests/capture_athenes.gd -- [dossier_sortie] [vue1,vue2…]

const VUES := [
	# nom, position caméra, point visé (hauteurs relatives au sol)
	["arrivee", Vector3(0, 2.0, 140), Vector3(0, 4.0, 60)],
	["agora", Vector3(32, 4.0, 12), Vector3(-20, 3.0, -40)],
	["poikile", Vector3(-4, 2.0, -30), Vector3(-14, 3.5, -50)],
	["marche", Vector3(28, 2.2, -2), Vector3(10, 1.0, -14)],
	["tholos", Vector3(-30, 3.0, 30), Vector3(-50, 3.0, 14)],
	["hephaisteion", Vector3(-62, 4.0, -46), Vector3(-98, 4.0, -30)],
	["ceramique", Vector3(-96, 3.0, -86), Vector3(-114, 1.0, -106)],
	["pnyx", Vector3(-70, 6.0, 110), Vector3(-92, 2.0, 82)],
	["acropole", Vector3(20, 8.0, 40), Vector3(100, 40.0, -4)],
	["parthenon", Vector3(30, 50.0, -10), Vector3(106, 40.0, -2)],
	["theatre", Vector3(72, 9.0, 76), Vector3(100, 4.0, 48)],
	["toits", Vector3(-40, 30.0, 120), Vector3(40, 4.0, 0)],
	["petrifie", Vector3(0, 0, 0), Vector3(0, 0, 0)],
	["tribunal", Vector3(-12, 4.0, 58), Vector3(-24, 1.5, 44)],
	["atelier", Vector3(58, 2.4, 56), Vector3(48, 1.2, 50)],
	["aspasie", Vector3(64, 4.0, 114), Vector3(52, 2.0, 100)],
	["masque", Vector3(0, 0, 0), Vector3(0, 0, 0)],
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_grece_athenes.cfg"))
	var scene: Node = load("res://scenes/monde/grece/athenes.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_grece_athenes.cfg"
	root.add_child(scene)
	current_scene = scene
	await _attendre(30)
	for n in scene.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var joueur := get_first_node_in_group("joueur_local") as Node3D
	if joueur != null:
		joueur.visible = false
	# Un Pétrifié posé sur l'Agora pour la photo.
	var bete: Node3D = load("res://scenes/ennemis/loup.tscn").instantiate()
	bete.set("type_ennemi", "petrifie")
	bete.position = Vector3(-26, scene.hauteur(-26, 6), 6)
	scene.add_child(bete)
	var masque: Node3D = load("res://scenes/ennemis/loup.tscn").instantiate()
	masque.set("type_ennemi", "masque_tribunal")
	masque.position = Vector3(-18, scene.hauteur(-18, 6), 6)
	scene.add_child(masque)
	await _attendre(10)
	var camera := Camera3D.new()
	camera.fov = 65.0
	camera.far = 4000.0
	scene.add_child(camera)
	camera.make_current()
	var choix: PackedStringArray = args[1].split(",") if args.size() > 1 else PackedStringArray()
	for vue in VUES:
		if not choix.is_empty() and not choix.has(vue[0]):
			continue
		var pos: Vector3 = vue[1]
		var cible: Vector3 = vue[2]
		if vue[0] == "petrifie" or vue[0] == "masque":
			var sujet: Node3D = bete if vue[0] == "petrifie" else masque
			sujet.set_physics_process(false)
			cible = sujet.global_position + Vector3(0, 1.1, 0)
			pos = cible + Vector3(1.6, 0.3, 2.0)
		else:
			pos.y += scene.hauteur(pos.x, pos.z)
			cible.y += scene.hauteur(cible.x, cible.z) if cible.y < 30.0 else 0.0
		camera.global_position = pos
		camera.look_at(cible)
		for n in scene.find_children("*", "CanvasLayer", true, false):
			(n as CanvasLayer).visible = false
		await _attendre(8)
		var image := root.get_texture().get_image()
		var sortie := dossier.path_join("athenes_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
