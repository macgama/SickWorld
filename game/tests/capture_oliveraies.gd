extends SceneTree
## Captures d'écran du Oliveraies d'Attique (Grèce, fenêtre visible, pas en --headless).
## Lancement : godot --path game -s res://tests/capture_oliveraies.gd -- [dossier_sortie] [vue1,vue2…]

const VUES := [
	# nom, position caméra, point visé (hauteurs relatives au sol)
	["route", Vector3(0, 2.0, 140), Vector3(0, 3.0, 60)],
	["murs", Vector3(-30, 8.0, 70), Vector3(0, 4.0, 30)],
	["poterne", Vector3(28, 2.0, 46), Vector3(13, 2.5, 40)],
	["ferme", Vector3(46, 4.0, 58), Vector3(72, 1.5, 30)],
	["ruches", Vector3(84, 2.5, 34), Vector3(98, 0.5, 20)],
	["hymette", Vector3(60, 5.0, 0), Vector3(150, 10.0, -20)],
	["oliveraie", Vector3(-40, 2.0, 10), Vector3(-100, 2.0, 30)],
	["sanctuaire", Vector3(-58, 3.0, -38), Vector3(-82, 2.0, -54)],
	["porte_athenes", Vector3(0, 2.5, -100), Vector3(0, 6.0, -140)],
	["acropole", Vector3(-30, 16.0, -112), Vector3(-30, 50.0, -520)],
	["sanglier", Vector3(0, 0, 0), Vector3(0, 0, 0)],
	["vipere", Vector3(0, 0, 0), Vector3(0, 0, 0)],
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_grece_oliveraies.cfg"))
	var scene: Node = load("res://scenes/monde/grece/oliveraies.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_grece_oliveraies.cfg"
	root.add_child(scene)
	current_scene = scene
	await _attendre(30)
	for n in scene.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var joueur := get_first_node_in_group("joueur_local") as Node3D
	if joueur != null:
		joueur.visible = false
	# Un sanglier posé dans l'oliveraie pour la photo.
	var poulpe: Node3D = load("res://scenes/ennemis/loup.tscn").instantiate()
	poulpe.set("type_ennemi", "sanglier_fracture")
	poulpe.position = Vector3(-30, scene.hauteur(-30, 60), 60)
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
		if vue[0] == "sanglier" or vue[0] == "vipere":
			var bete: Node3D = poulpe
			if vue[0] == "vipere":
				for b in get_nodes_in_group("loups"):
					if String(b.type_ennemi) == "vipere_fracture":
						bete = b
						break
			bete.set_physics_process(false)
			cible = bete.global_position + Vector3(0, 0.5, 0)
			var recul := 2.2 if vue[0] == "vipere" else 3.2
			pos = cible + Vector3(recul * 0.8, 1.6, recul * 0.6)
		else:
			pos.y += maxf(scene.hauteur(pos.x, pos.z), scene.NIVEAU_MER)
			cible.y += maxf(scene.hauteur(cible.x, cible.z), scene.NIVEAU_MER)
		camera.global_position = pos
		camera.look_at(cible)
		await _attendre(8)
		var image := root.get_texture().get_image()
		var sortie := dossier.path_join("oliveraies_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
