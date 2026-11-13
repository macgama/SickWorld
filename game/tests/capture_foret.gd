extends SceneTree
## Captures d'écran de la Forêt des Bouleaux (fenêtre visible, pas en --headless).
## Lancement : godot --path game -s res://tests/capture_foret.gd -- [dossier_sortie]

const VUES := [
	# nom, position caméra, point visé
	["arrivee", Vector3(-138, 2.5, -8), Vector3(-100, 3.0, -20)],
	["sous_bois", Vector3(-60, 2.0, 20), Vector3(-30, 4.0, 0)],
	["riviere", Vector3(-5, 3.0, -2), Vector3(20, 0.5, -20)],
	["clairiere", Vector3(58, 3.0, -50), Vector3(72, 1.0, -62)],
	["faille", Vector3(-60, 3.0, 50), Vector3(-70, 2.5, 62)],
	["traces", Vector3(-84, 1.8, -22), Vector3(-60, 0.0, -14)],
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
	var scene: Node = load("res://scenes/monde/prehistoire/foret.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_progression.cfg"
	root.add_child(scene)
	current_scene = scene
	await _attendre(10)
	var main := scene.find_child("MainPeinte", true, false)
	if main != null:
		main.visible = true
	for n in scene.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var camera := Camera3D.new()
	camera.fov = 70.0
	camera.far = 3000.0
	scene.add_child(camera)
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
		var sortie := dossier.path_join("foret_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
