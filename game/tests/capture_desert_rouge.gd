extends SceneTree
## Captures d'écran du Désert Rouge (Égypte, fenêtre visible, pas en --headless).
## Lancement : godot --path game -s res://tests/capture_desert_rouge.gd -- [dossier_sortie]

const VUES := [
	# nom, position caméra, point visé (hauteurs relatives au sol)
	["arrivee", Vector3(140, 2.5, -26), Vector3(80, 3.0, -40)],
	["mastabas", Vector3(100, 3.0, -20), Vector3(70, 2.0, -60)],
	["rue", Vector3(118, 2.0, -36), Vector3(40, 2.0, -58)],
	["repaire", Vector3(-40, 4.0, -60), Vector3(-80, 3.0, -70)],
	["cour", Vector3(-70, 2.4, -66), Vector3(-88, 1.5, -72)],
	["dunes", Vector3(-60, 4.0, 20), Vector3(-140, 2.0, -10)],
	["ouadi", Vector3(30, 3.0, 100), Vector3(-30, -1.0, 70)],
	["nomades", Vector3(-24, 2.4, 98), Vector3(-34, 1.0, 86)],
	["pyramide", Vector3(130, 3.0, -50), Vector3(420, 60.0, -120)],
	["garde", Vector3(0, 0, 0), Vector3(0, 0, 0)],
	["vera", Vector3(0, 0, 0), Vector3(0, 0, 0)],
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_desert.cfg"))
	var scene: Node = load("res://scenes/monde/egypte/desert_rouge.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_desert.cfg"
	root.add_child(scene)
	current_scene = scene
	await _attendre(30)
	for n in scene.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var joueur := get_first_node_in_group("joueur_local") as Node3D
	if joueur != null:
		joueur.visible = false
	# Un garde de l'Effaceuse posé près du cimetière pour la photo.
	var oublie: Node3D = load("res://scenes/ennemis/loup.tscn").instantiate()
	oublie.set("type_ennemi", "garde_effaceuse")
	oublie.position = Vector3(110, scene.hauteur(110, -26), -26)
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
		if vue[0] == "garde" or vue[0] == "vera":
			var bete: Node3D = oublie
			if vue[0] == "vera":
				bete = scene.find_child("VeraLind", true, false)
			else:
				bete.set_physics_process(false)
			cible = bete.global_position + Vector3(0, 1.2, 0)
			var recul := 3.0
			pos = cible + Vector3(recul * 0.8, 0.5, recul * 0.6)
		else:
			pos.y += maxf(scene.hauteur(pos.x, pos.z), scene.NIVEAU_MER)
			cible.y += maxf(scene.hauteur(cible.x, cible.z), scene.NIVEAU_MER)
		camera.global_position = pos
		camera.look_at(cible)
		await _attendre(8)
		var image := root.get_texture().get_image()
		var sortie := dossier.path_join("desert_rouge_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
