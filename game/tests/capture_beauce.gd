extends SceneTree
## Captures d'écran de la Beauce (Moyen Âge, zone 1 ; fenêtre visible, pas en
## --headless).
## Lancement : godot --path game -s res://tests/capture_beauce.gd -- [dossier_sortie] [vue1,vue2…|-]

const VUES := [
	# nom, position caméra, point visé, hauteurs absolues ? (sinon relatives au sol)
	["arrivee", Vector3(-104, 2.0, 96), Vector3(-112, 2.0, 118), false],
	["plaine", Vector3(-96, 2.2, 80), Vector3(-40, 2.0, 70), false],
	["champ", Vector3(-62, 1.8, 54), Vector3(-30, 1.0, 64), false],
	["ferme", Vector3(-66, 2.5, 48), Vector3(-82, 2.0, 63), false],
	["village", Vector3(20, 2.2, -8), Vector3(60, 4.0, -44), false],
	["place", Vector3(40, 1.8, -22), Vector3(62, 3.0, -40), false],
	["moulin", Vector3(-60, 2.0, -70), Vector3(-82, 7.0, -96), false],
	["gibet", Vector3(96, 2.0, -86), Vector3(124, 3.0, -116), false],
	["chartres", Vector3(120, 3.0, -40), Vector3(400, 60.0, -500), false],
	["haut", Vector3(180, 110.0, 160), Vector3(0, 0.0, -10), true],
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_beauce.cfg"))
	var scene: Node = load("res://scenes/monde/moyen_age/beauce.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_beauce.cfg"
	root.add_child(scene)
	current_scene = scene
	await _attendre(60)
	var joueur := get_first_node_in_group("joueur_local") as Node3D
	if joueur != null:
		joueur.visible = false
	var camera := Camera3D.new()
	camera.fov = 65.0
	camera.far = 4000.0
	scene.add_child(camera)
	camera.make_current()
	for n in scene.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var choix := PackedStringArray()
	if args.size() > 1 and args[1] != "-":
		choix = args[1].split(",")
	for vue in VUES:
		if not choix.is_empty() and not choix.has(vue[0]):
			continue
		var pos: Vector3 = vue[1]
		var cible: Vector3 = vue[2]
		if not vue[3]:
			pos.y += scene.hauteur(pos.x, pos.z)
			cible.y += scene.hauteur(cible.x, cible.z)
		camera.global_position = pos
		camera.look_at(cible)
		for n in scene.find_children("*", "CanvasLayer", true, false):
			(n as CanvasLayer).visible = false
		await _attendre(8)
		var image := root.get_texture().get_image()
		var sortie := dossier.path_join("beauce_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
