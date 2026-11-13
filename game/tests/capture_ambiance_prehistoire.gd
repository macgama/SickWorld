extends SceneTree
## Captures de la Côte Gelée avec l'ambiance « grandiose » (graphismes).
## godot --path game -s res://tests/capture_ambiance_prehistoire.gd -- <dossier> [qualite|-] [avant]

## Captures d'écran de la Côte Gelée (fenêtre visible, pas en --headless).
## Lancement : godot --path game -s res://tests/capture_cote_gelee.gd -- [dossier_sortie]

const VUES := [
	# nom, position caméra, point visé
	["arrivee", Vector3(-3.5, 3.0, 56.0), Vector3(-2, 1.5, 20)],
	["crique", Vector3(-35, 14, 95), Vector3(10, 2, 20)],
	["camp", Vector3(-12, 3.0, 44), Vector3(4, 1.0, 32)],
	["faille", Vector3(-4, 4.5, 12), Vector3(3, 3.0, 0)],
	["plateau", Vector3(-20, 12, -10), Vector3(-34, 4, -36)],
	["falaises", Vector3(60, 6, 62), Vector3(105, 14, 30)],
	["mer", Vector3(-8, 3.5, 50), Vector3(10, 0, 120)],
	["nord", Vector3(0, 3.0, -60), Vector3(8, 10, -140)],
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
	var scene: Node = load("res://scenes/monde/prehistoire/cote_gelee.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_progression.cfg"
	root.add_child(scene)
	current_scene = scene
	await _attendre(2)
	if args.size() > 1 and args[1] != "-":
		get_root().get_node("QualiteGraphique").choisir(args[1], false)
	if args.size() > 2 and args[2] == "avant":
		scene.ambiance_grandiose = false
	await _attendre(10)
	for n in root.find_children("*", "CanvasLayer", true, false):
		if n.name != "PostTraitement":
			(n as CanvasLayer).visible = false
	var camera := Camera3D.new()
	camera.fov = 70.0
	camera.far = 3000.0
	scene.add_child(camera)
	camera.make_current()
	for vue in VUES:
		var pos: Vector3 = vue[1]
		var cible: Vector3 = vue[2]
		pos.y += scene.hauteur(pos.x, pos.z)
		cible.y += scene.hauteur(cible.x, cible.z)
		camera.global_position = pos
		camera.look_at(cible)
		await _attendre(30)
		var image := root.get_texture().get_image()
		var sortie := dossier.path_join("cote_gelee_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
