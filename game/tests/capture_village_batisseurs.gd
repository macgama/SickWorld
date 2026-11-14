extends SceneTree
## Captures d'écran du Village des Bâtisseurs (Égypte, fenêtre visible, pas en --headless).
## Lancement : godot --path game -s res://tests/capture_village_batisseurs.gd -- [dossier_sortie]

const VUES := [
	# nom, position caméra, point visé (hauteurs relatives au sol)
	["arrivee", Vector3(140, 2.5, 64), Vector3(60, 4.0, 50)],
	["place", Vector3(30, 2.4, 52), Vector3(10, 1.5, 40)],
	["pyramide", Vector3(14, 2.0, 60), Vector3(-10, 70.0, -320)],
	["dortoirs", Vector3(-30, 2.2, 6), Vector3(-50, 1.5, 22)],
	["boulangerie", Vector3(-2, 2.4, 74), Vector3(-10, 0.8, 64)],
	["soins", Vector3(48, 2.2, 84), Vector3(58, 0.5, 76)],
	["cimetiere", Vector3(-80, 3.0, 50), Vector3(-104, 1.0, 30)],
	["mur", Vector3(10, 2.0, 22), Vector3(0, 5.0, -8)],
	["chantier", Vector3(20, 3.0, -60), Vector3(-6, 2.0, -110)],
	["atelier", Vector3(-24, 2.2, 76), Vector3(-30, 1.0, 88)],
	["chacal", Vector3(0, 0, 0), Vector3(0, 0, 0)],
	["villageois", Vector3(0, 0, 0), Vector3(0, 0, 0)],
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_village.cfg"))
	var scene: Node = load("res://scenes/monde/egypte/village_batisseurs.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_village.cfg"
	root.add_child(scene)
	current_scene = scene
	await _attendre(30)
	for n in scene.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var joueur := get_first_node_in_group("joueur_local") as Node3D
	if joueur != null:
		joueur.visible = false
	# Un chacal fracturé posé sur la place pour la photo.
	var oublie: Node3D = load("res://scenes/ennemis/loup.tscn").instantiate()
	oublie.set("type_ennemi", "chacal_fracture")
	oublie.position = Vector3(24, scene.hauteur(24, 50), 50)
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
		if vue[0] == "chacal" or vue[0] == "villageois":
			var bete: Node3D = oublie
			if vue[0] == "villageois":
				bete = scene.find_child("Meret", true, false)
			else:
				bete.set_physics_process(false)
			cible = bete.global_position + Vector3(0, 0.5 if vue[0] == "chacal" else 1.2, 0)
			var recul := 2.6 if vue[0] == "chacal" else 3.0
			pos = cible + Vector3(recul * 0.8, 0.5, recul * 0.6)
		else:
			pos.y += maxf(scene.hauteur(pos.x, pos.z), scene.NIVEAU_MER)
			cible.y += maxf(scene.hauteur(cible.x, cible.z), scene.NIVEAU_MER)
		camera.global_position = pos
		camera.look_at(cible)
		await _attendre(8)
		var image := root.get_texture().get_image()
		var sortie := dossier.path_join("village_batisseurs_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
