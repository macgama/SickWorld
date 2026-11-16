extends SceneTree
## Captures d'écran du donjon de l'Acropole (Grèce, chapitre 8 ; fenêtre visible, pas en --headless).
## Lancement : godot --path game -s res://tests/capture_acropole.gd -- [dossier_sortie] [vue1,vue2…|-]

const VUES := [
	# nom, position caméra, point visé (hauteurs relatives au sol)
	["escalier", Vector3(0, 1.7, -93), Vector3(0, 1.2, -76)],
	["grotte", Vector3(10, 3.0, -46), Vector3(-6, 1.0, -60)],
	["fissure", Vector3(0, 1.7, -40), Vector3(0, 1.5, -24)],
	["plateau", Vector3(-22, 3.0, -14), Vector3(0, 6.0, 40)],
	["parthenon", Vector3(26, 5.0, 8), Vector3(0, 6.0, 50)],
	["cella", Vector3(0, 2.0, 42), Vector3(0, 7.0, 69)],
	["bouclier", Vector3(-4.2, 1.8, 49.6), Vector3(-7.4, 1.0, 47)],
	["statue", Vector3(0, 0, 0), Vector3(0, 0, 0)],
	["meduse", Vector3(0, 0, 0), Vector3(0, 0, 0)],
]


func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _bete(scene: Node, type: String, p: Vector2) -> Node3D:
	var b: Node3D = load("res://scenes/ennemis/loup.tscn").instantiate()
	b.set("type_ennemi", type)
	b.position = Vector3(p.x, scene.hauteur(p.x, p.y), p.y)
	scene.add_child(b)
	return b


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier := args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://")
	root.size = Vector2i(1280, 720)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_grece_acropole.cfg"))
	var scene: Node = load("res://scenes/monde/grece/acropole.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_grece_acropole.cfg"
	root.add_child(scene)
	current_scene = scene
	await _attendre(30)
	var joueur := get_first_node_in_group("joueur_local") as Node3D
	if joueur != null:
		joueur.visible = false
	var sujets := {}
	sujets["statue"] = _bete(scene, "statue_fracturee", Vector2(0, -54))
	var meduse := _bete(scene, "meduse", Vector2(3.2, 63.5))
	meduse.rotation.y = PI
	sujets["meduse"] = meduse
	await _attendre(10)
	var camera := Camera3D.new()
	camera.fov = 65.0
	camera.far = 4000.0
	scene.add_child(camera)
	camera.make_current()
	var choix := PackedStringArray()
	if args.size() > 1 and args[1] != "-":
		choix = args[1].split(",")
	for vue in VUES:
		if not choix.is_empty() and not choix.has(vue[0]):
			continue
		var pos: Vector3 = vue[1]
		var cible: Vector3 = vue[2]
		if sujets.has(vue[0]):
			var sujet: Node3D = sujets[vue[0]]
			sujet.set_physics_process(false)
			cible = sujet.global_position + Vector3(0, 1.1, 0)
			var avant := Vector3(0.5, 0, 0.9) if vue[0] == "statue" else Vector3(-0.35, 0, -1.0)
			var recul := 3.2 if vue[0] == "statue" else 5.5
			cible.y += 0.4 if vue[0] == "statue" else 1.4
			pos = cible + avant.normalized() * recul + Vector3(0, 0.2, 0)
		else:
			pos.y += scene.hauteur(pos.x, pos.z)
			cible.y += scene.hauteur(cible.x, cible.z)
		camera.global_position = pos
		camera.look_at(cible)
		for n in scene.find_children("*", "CanvasLayer", true, false):
			(n as CanvasLayer).visible = false
		await _attendre(8)
		var image := root.get_texture().get_image()
		var sortie := dossier.path_join("%s_%s.jpg" % ["acropole", vue[0]])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
