extends SceneTree
## Captures d'écran des Carrières de Toura (Égypte, fenêtre visible, pas en --headless).
## Lancement : godot --path game -s res://tests/capture_carrieres_toura.gd -- [dossier_sortie]

const VUES := [
	# nom, position caméra, point visé (hauteurs relatives au sol)
	["arrivee", Vector3(-92, 2.5, 18), Vector3(-40, 4.0, -4)],
	["debarcadere", Vector3(-70, 4.0, 22), Vector3(-100, 0.0, 4)],
	["campement", Vector3(-20, 2.2, 8), Vector3(-36, 1.5, -2)],
	["falaise", Vector3(-10, 3.0, 30), Vector3(60, 12.0, -10)],
	["carriere", Vector3(30, 3.0, -10), Vector3(70, 8.0, -24)],
	["gradins", Vector3(80, 3.0, 17), Vector3(56, -2.0, -20)],
	["galerie", Vector3(22, 2.2, -66), Vector3(44, 2.5, -70)],
	["couloir", Vector3(52, 2.0, -70), Vector3(84, 1.8, -70)],
	["salle", Vector3(86, 2.6, -64), Vector3(96, 1.2, -73)],
	["pyramide", Vector3(-90, 3.0, -10), Vector3(-1500, 60.0, -600)],
	["babouin", Vector3(0, 0, 0), Vector3(0, 0, 0)],
	["oublie", Vector3(0, 0, 0), Vector3(0, 0, 0)],
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_toura.cfg"))
	var scene: Node = load("res://scenes/monde/egypte/carrieres_toura.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_toura.cfg"
	root.add_child(scene)
	current_scene = scene
	await _attendre(30)
	for n in scene.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var joueur := get_first_node_in_group("joueur_local") as Node3D
	if joueur != null:
		joueur.visible = false
	# Un carrier oublié posé près du campement pour la photo.
	var oublie: Node3D = load("res://scenes/ennemis/loup.tscn").instantiate()
	oublie.set("type_ennemi", "oublie")
	oublie.position = Vector3(-24, scene.hauteur(-24, -12), -12)
	scene.get_node("Partie/Loups").add_child(oublie)
	await _attendre(10)
	var camera := Camera3D.new()
	camera.fov = 65.0
	camera.far = 4000.0
	scene.add_child(camera)
	camera.make_current()
	for vue in VUES:
		var pos: Vector3 = vue[1]
		var cible: Vector3 = vue[2]
		if vue[0] == "babouin" or vue[0] == "oublie":
			var bete: Node3D = oublie
			if vue[0] == "babouin":
				for b in get_nodes_in_group("loups"):
					if String(b.type_ennemi) == "babouin_fracture":
						bete = b
						break
			bete.set_physics_process(false)
			cible = bete.global_position + Vector3(0, 0.6 if vue[0] == "babouin" else 1.2, 0)
			var recul := 2.6 if vue[0] == "babouin" else 3.5
			pos = cible + Vector3(recul * 0.8, 0.5, recul * 0.6)
		else:
			pos.y += maxf(scene.hauteur(pos.x, pos.z), scene.NIVEAU_MER)
			cible.y += maxf(scene.hauteur(cible.x, cible.z), scene.NIVEAU_MER)
		camera.global_position = pos
		camera.look_at(cible)
		await _attendre(8)
		var image := root.get_texture().get_image()
		var sortie := dossier.path_join("carrieres_toura_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
