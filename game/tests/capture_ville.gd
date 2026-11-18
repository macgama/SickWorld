extends SceneTree
## Captures d'écran de la ville de Mayence (zone 3 ; fenêtre visible, pas en
## --headless).
## Lancement : godot --path game -s res://tests/capture_ville.gd -- [dossier_sortie] [vue1,vue2…|-]

const VUES := [
	# nom, position caméra, point visé, hauteurs absolues ? (sinon relatives au sol)
	["arrivee", Vector3(130, 2.0, 66), Vector3(112, 10.0, 58), false],
	["rive", Vector3(128, 2.0, 30), Vector3(122, 3.0, -30), false],
	["holzturm", Vector3(96, 2.0, 50), Vector3(112, 8.0, 58), false],
	["marche", Vector3(80, 2.2, 30), Vector3(40, 4.0, 20), false],
	["dom", Vector3(40, 2.0, -10), Vector3(-40, 20.0, 27), false],
	["dom_ouest", Vector3(-110, 2.0, 60), Vector3(-60, 20.0, 27), false],
	["rue", Vector3(52, 2.0, -20), Vector3(30, 3.0, -72), false],
	["cour", Vector3(14, 1.8, -84), Vector3(8, 2.0, -100), false],
	["atelier", Vector3(18, 1.7, -96), Vector3(4, 1.6, -102), false],
	["orfevres", Vector3(-20, 2.0, -18), Vector3(-80, 3.0, -40), false],
	["jardins", Vector3(-100, 2.0, -110), Vector3(-136, 3.0, -138), false],
	["porte_crypte", Vector3(-30, 1.8, 56), Vector3(-34, 2.5, 43), false],
	["portail", Vector3(10, 1.8, -96), Vector3(24, 2.0, -106), false],
	["haut", Vector3(220, 140.0, 160), Vector3(0, 10.0, 0), true],
	# La nuit de l'Éditeur (chapitre 6) : Marchal et sa machine dans l'atelier.
	["nuit_atelier", Vector3(14, 1.7, -93), Vector3(8, 1.2, -97.5), false],
	["nuit_cour", Vector3(14, 1.8, -82), Vector3(8, 2.0, -100), false],
	["nuit_rue", Vector3(52, 2.0, -20), Vector3(30, 3.0, -72), false],
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_ville.cfg"))
	var scene: Node = load("res://scenes/monde/mayence/ville.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_ville.cfg"
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
		if String(vue[0]).begins_with("nuit_") and not scene._nuit:
			scene.set_meta("nuit_forcee", true)
			scene._mettre_nuit(true)
			for n in get_nodes_in_group("decor_quete"):
				if n.get_meta("identifiant", "") in ["etienne_marchal", "machine_marchal"]:
					n.visible = true
			await _attendre(30)
		if vue[0] == "portail":
			scene._portail_qg.visible = true
			await _attendre(5)
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
		var sortie := dossier.path_join("ville_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
