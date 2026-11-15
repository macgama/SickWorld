extends SceneTree
## Captures d'écran du Pirée (Grèce, fenêtre visible, pas en --headless).
## Lancement : godot --path game -s res://tests/capture_le_piree.gd -- [dossier_sortie] [vue1,vue2…]

const VUES := [
	# nom, position caméra, point visé (hauteurs relatives au sol)
	["crique", Vector3(-64, 2.5, 122), Vector3(-50, 1.0, 108)],
	["akte", Vector3(-50, 3.5, 118), Vector3(-82, 3.0, 100)],
	["chemin", Vector3(-52, 2.2, 96), Vector3(-36, 1.5, 52)],
	["loges", Vector3(-8, 4.0, 22), Vector3(0, 2.0, -20)],
	["enclos", Vector3(-36, 2.0, 24), Vector3(-42, 1.4, 22)],
	["bassin", Vector3(18, 7.0, 44), Vector3(62, 0.0, 0)],
	["paralos", Vector3(14, 3.0, 34), Vector3(33, 1.0, 26)],
	["portique", Vector3(58, 3.0, -38), Vector3(66, 3.0, -63)],
	["ville", Vector3(-58, 5.0, -88), Vector3(-86, 2.0, -106)],
	["longs_murs", Vector3(-50, 4.0, -118), Vector3(-50, 4.0, -170)],
	["acropole", Vector3(-30, 14.0, -132), Vector3(-210, 40.0, -1800)],
	["temple", Vector3(122, 4.0, -80), Vector3(142, 4.0, -96)],
	["chien", Vector3(0, 0, 0), Vector3(0, 0, 0)],
	["poulpe", Vector3(0, 0, 0), Vector3(0, 0, 0)],
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_grece.cfg"))
	var scene: Node = load("res://scenes/monde/grece/le_piree.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_grece.cfg"
	root.add_child(scene)
	current_scene = scene
	await _attendre(30)
	for n in scene.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var joueur := get_first_node_in_group("joueur_local") as Node3D
	if joueur != null:
		joueur.visible = false
	# Le poulpe fracturé posé sur le haut-fond pour la photo.
	var poulpe: Node3D = load("res://scenes/ennemis/loup.tscn").instantiate()
	poulpe.set("type_ennemi", "poulpe_fracture")
	poulpe.position = Vector3(-53, scene.hauteur(-53, 135), 135)
	scene.add_child(poulpe)
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
		if vue[0] == "chien" or vue[0] == "poulpe":
			var bete: Node3D = poulpe
			if vue[0] == "chien":
				for b in get_nodes_in_group("loups"):
					if String(b.type_ennemi) == "chien_fracture":
						bete = b
						break
			bete.set_physics_process(false)
			cible = bete.global_position + Vector3(0, 0.5, 0)
			var recul := 3.5 if vue[0] == "chien" else 7.0
			pos = cible + Vector3(recul * 0.8, 1.6, recul * 0.6)
		else:
			pos.y += maxf(scene.hauteur(pos.x, pos.z), scene.NIVEAU_MER)
			cible.y += maxf(scene.hauteur(cible.x, cible.z), scene.NIVEAU_MER)
		camera.global_position = pos
		camera.look_at(cible)
		await _attendre(8)
		var image := root.get_texture().get_image()
		var sortie := dossier.path_join("le_piree_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
