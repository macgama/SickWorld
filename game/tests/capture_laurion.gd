extends SceneTree
## Captures d'écran des mines du Laurion et de leurs galeries (Grèce, chapitre 6 ;
## fenêtre visible, pas en --headless).
## Lancement : godot --path game -s res://tests/capture_laurion.gd -- [dossier_sortie] [vue1,vue2…|-] [laurion|galeries]

const VUES_SURFACE := [
	# nom, position caméra, point visé (hauteurs relatives au sol)
	["arrivee", Vector3(0, 2.0, -142), Vector3(0, 4.0, -70)],
	["ergasterion", Vector3(-22, 4.0, -46), Vector3(-52, 1.0, -68)],
	["cabanes", Vector3(-62, 3.0, -2), Vector3(-90, 1.0, -20)],
	["fours", Vector3(18, 4.0, -62), Vector3(50, 2.0, -86)],
	["citerne", Vector3(90, 3.0, -12), Vector3(97, 1.0, -36)],
	["camp", Vector3(86, 3.0, 10), Vector3(70, 1.0, -4)],
	["colline", Vector3(40, 8.0, 20), Vector3(10, 10.0, 100)],
	["puits", Vector3(4, 2.0, 50), Vector3(0, 1.5, 63)],
	["vera", Vector3(0, 0, 0), Vector3(0, 0, 0)],
	["mercenaire", Vector3(0, 0, 0), Vector3(0, 0, 0)],
]
const VUES_GALERIES := [
	["entree", Vector3(0, 1.7, -57), Vector3(0, 0.5, -44)],
	["chantier", Vector3(-37, 1.7, -42), Vector3(-46, 1.0, -44)],
	["galerie_sud", Vector3(0, 1.7, -34), Vector3(0, 0.5, -10)],
	["machine", Vector3(6, 1.7, 9), Vector3(3, 0.6, 6)],
	["salle_est", Vector3(40, 2.0, 5), Vector3(50, 0.8, 1)],
	["descenderie", Vector3(45, 1.7, 18), Vector3(45, 1.5, 40)],
]


func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier := args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://")
	var galeries := args.size() > 2 and args[2] == "galeries"
	root.size = Vector2i(1280, 720)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_grece_laurion.cfg"))
	var chemin := "res://scenes/monde/grece/galeries_laurion.tscn" if galeries else "res://scenes/monde/grece/laurion.tscn"
	var scene: Node = load(chemin).instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = "user://capture_grece_laurion.cfg"
	root.add_child(scene)
	current_scene = scene
	await _attendre(30)
	var joueur := get_first_node_in_group("joueur_local") as Node3D
	if joueur != null:
		joueur.visible = false
	var sujets := {}
	if not galeries:
		var vera: Node3D = scene.find_child("VeraLaurion", true, false)
		if vera != null:
			vera.visible = true
			sujets["vera"] = vera
		var merc: Node3D = load("res://scenes/ennemis/loup.tscn").instantiate()
		merc.set("type_ennemi", "mercenaire_masque")
		merc.position = Vector3(60, scene.hauteur(60, -40), -40)
		scene.add_child(merc)
		sujets["mercenaire"] = merc
	await _attendre(10)
	var camera := Camera3D.new()
	camera.fov = 65.0
	camera.far = 4000.0
	scene.add_child(camera)
	camera.make_current()
	var choix := PackedStringArray()
	if args.size() > 1 and args[1] != "-":
		choix = args[1].split(",")
	for vue in (VUES_GALERIES if galeries else VUES_SURFACE):
		if not choix.is_empty() and not choix.has(vue[0]):
			continue
		var pos: Vector3 = vue[1]
		var cible: Vector3 = vue[2]
		if sujets.has(vue[0]):
			var sujet: Node3D = sujets[vue[0]]
			sujet.set_physics_process(false)
			cible = sujet.global_position + Vector3(0, 1.1, 0)
			var avant := -sujet.global_transform.basis.z if vue[0] == "vera" else Vector3(0.6, 0, 0.8)
			pos = cible + avant.normalized() * 2.4 + Vector3(0.6, 0.3, 0)
		else:
			pos.y += scene.hauteur(pos.x, pos.z)
			cible.y += scene.hauteur(cible.x, cible.z)
		camera.global_position = pos
		camera.look_at(cible)
		for n in scene.find_children("*", "CanvasLayer", true, false):
			(n as CanvasLayer).visible = false
		await _attendre(8)
		var image := root.get_texture().get_image()
		var sortie := dossier.path_join("%s_%s.jpg" % ["galeries" if galeries else "laurion", vue[0]])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	quit()
