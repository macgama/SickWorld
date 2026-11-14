extends SceneTree
## Captures d'écran du Port des Marais (Égypte, fenêtre visible, pas en --headless).
## Lancement : godot --path game -s res://tests/capture_port_des_marais.gd -- [dossier_sortie]

const VUES := [
	# nom, position caméra, point visé (hauteurs relatives au sol)
	["arrivee", Vector3(-31, 2.2, 100), Vector3(-30, 1.5, 82)],
	["marais", Vector3(-20, 3.0, 112), Vector3(-50, 1.0, 80)],
	["levee", Vector3(-24, 2.5, 40), Vector3(-15, 2.0, -10)],
	["port", Vector3(-30, 6.0, -4), Vector3(20, 0.0, -42)],
	["quai", Vector3(-20, 2.0, -12), Vector3(-14, 1.4, -30)],
	["traineau", Vector3(-4, 2.4, -48), Vector3(-12, 1.0, -53)],
	["rampe", Vector3(-44, 5.0, -62), Vector3(-80, 6.0, -100)],
	["pyramide", Vector3(-60, 4.0, -40), Vector3(-560, 60.0, -250)],
	["nil", Vector3(70, 3.0, 20), Vector3(140, 2.0, -40)],
	["crocodile", Vector3(0, 0, 0), Vector3(0, 0, 0)],
	["hippopotame", Vector3(0, 0, 0), Vector3(0, 0, 0)],
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_egypte.cfg"))
	var scene: Node = load("res://scenes/monde/egypte/port_des_marais.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_egypte.cfg"
	root.add_child(scene)
	current_scene = scene
	await _attendre(30)
	for n in scene.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var joueur := get_first_node_in_group("joueur_local") as Node3D
	if joueur != null:
		joueur.visible = false
	# Un hippopotame posé dans le chenal pour la photo.
	var hippo: Node3D = load("res://scenes/ennemis/loup.tscn").instantiate()
	hippo.set("type_ennemi", "hippopotame")
	hippo.position = Vector3(58, scene.hauteur(58, -38), -38)
	scene.add_child(hippo)
	await _attendre(10)
	var camera := Camera3D.new()
	camera.fov = 65.0
	camera.far = 4000.0
	scene.add_child(camera)
	camera.make_current()
	for vue in VUES:
		var pos: Vector3 = vue[1]
		var cible: Vector3 = vue[2]
		if vue[0] == "crocodile" or vue[0] == "hippopotame":
			var bete: Node3D = hippo
			if vue[0] == "crocodile":
				for b in get_nodes_in_group("loups"):
					if String(b.type_ennemi) == "crocodile_fracture":
						bete = b
						break
			bete.set_physics_process(false)
			cible = bete.global_position + Vector3(0, 0.5, 0)
			var recul := 5.5 if vue[0] == "crocodile" else 8.0
			pos = cible + Vector3(recul * 0.8, 1.6, recul * 0.6)
		else:
			pos.y += maxf(scene.hauteur(pos.x, pos.z), scene.NIVEAU_MER)
			cible.y += maxf(scene.hauteur(cible.x, cible.z), scene.NIVEAU_MER)
		camera.global_position = pos
		camera.look_at(cible)
		await _attendre(8)
		var image := root.get_texture().get_image()
		var sortie := dossier.path_join("port_des_marais_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
