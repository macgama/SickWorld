extends SceneTree
## Captures d'écran du Cœur de la Pyramide (Égypte, fenêtre visible, pas en --headless),
## puis du passage des ouvriers au chantier, devant la pyramide terminée.
## Lancement : godot --path game -s res://tests/capture_coeur_pyramide.gd -- [dossier_sortie]

const PROGRESSION := "user://capture_pyramide.cfg"
const VUES := [
	# nom, position caméra, point visé (hauteurs relatives au sol)
	["vestibule", Vector3(3, 1.8, -112), Vector3(0, 0.5, -90)],
	["descendant", Vector3(0, 1.6, -92), Vector3(0, 0.0, -58)],
	["souterraine", Vector3(12, 2.6, -38), Vector3(-6, 1.0, -54)],
	["reine", Vector3(27.5, 1.8, 4), Vector3(41, 2.5, -7)],
	["galerie", Vector3(0, 1.8, 5), Vector3(0, 3.0, 40)],
	["galerie_haut", Vector3(1.5, 2.5, 52), Vector3(-0.5, 1.0, 20)],
	["antichambre", Vector3(0, 1.7, 55.5), Vector3(0, 1.6, 66)],
	["roi", Vector3(12, 2.6, 66), Vector3(-10, 2.0, 80)],
	["isfet", Vector3(-3, 3.0, 62.5 + 3.0), Vector3(-14.5, 4.0, 68)],
	["sablier", Vector3(10, 3.0, 67), Vector3(0, 7.5, 86)],
]


func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _photo(dossier: String, nom: String) -> void:
	await _attendre(8)
	var image := root.get_texture().get_image()
	var sortie := dossier.path_join("pyramide_%s.jpg" % nom)
	image.save_jpg(sortie, 0.88)
	print("Capture : ", sortie)


func _charger(chemin: String, etape: String) -> Node:
	var cfg := ConfigFile.new()
	cfg.set_value("egypte", "etape", etape)
	cfg.save(PROGRESSION)
	var scene: Node = load(chemin).instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = PROGRESSION
	root.add_child(scene)
	current_scene = scene
	await _attendre(40)
	for n in scene.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var joueur := get_first_node_in_group("joueur_local") as Node3D
	if joueur != null:
		joueur.visible = false
	return scene


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier := args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://")
	root.size = Vector2i(1280, 720)
	var scene := await _charger("res://scenes/monde/egypte/coeur_pyramide.tscn", "isfet")
	# Un cobra fracturé posé dans la chambre souterraine pour la photo.
	var cobra: Node3D = load("res://scenes/ennemis/loup.tscn").instantiate()
	cobra.set("type_ennemi", "cobra_fracture")
	cobra.position = Vector3(-1, -12.0, -48)
	cobra.rotation.y = -0.6
	scene.get_node("Partie/Loups").add_child(cobra)
	await _attendre(20)
	cobra.set_physics_process(false)
	var camera := Camera3D.new()
	camera.fov = 68.0
	camera.far = 600.0
	scene.add_child(camera)
	camera.make_current()
	# La lampe de l'agent, qui suit la caméra (le joueur est caché).
	var lampe := OmniLight3D.new()
	lampe.light_color = Color(1.0, 0.86, 0.68)
	lampe.light_energy = 2.0
	lampe.omni_range = 14.0
	lampe.shadow_enabled = true
	lampe.position = Vector3(0.6, 0.3, 0.4)
	camera.add_child(lampe)
	for vue in VUES:
		var pos: Vector3 = vue[1]
		var cible: Vector3 = vue[2]
		pos.y += scene.hauteur(pos.x, pos.z)
		cible.y += scene.hauteur(cible.x, cible.z)
		if vue[0] == "sablier":
			scene._sablier(true, 6.0)
			await _attendre(150)
		camera.global_position = pos
		camera.look_at(cible)
		await _photo(dossier, vue[0])
	scene.queue_free()
	await _attendre(10)

	# --- Le passage des ouvriers, au chantier, devant la pyramide terminée.
	var village := await _charger("res://scenes/monde/egypte/village_batisseurs.tscn", "journal_merer")
	await _attendre(20)
	var camera_v := Camera3D.new()
	camera_v.fov = 65.0
	camera_v.far = 4000.0
	village.add_child(camera_v)
	camera_v.make_current()
	var passage: Vector2 = village.PASSAGE
	for donnees in [["passage", Vector3(passage.x + 8, 2.2, passage.y + 14), Vector3(passage.x, 2.5, passage.y - 2)],
			["pyramide_finie", Vector3(passage.x - 30, 3.0, passage.y + 40), Vector3(-10, 70.0, -320)]]:
		var pos: Vector3 = donnees[1]
		var cible: Vector3 = donnees[2]
		pos.y += village.hauteur(pos.x, pos.z)
		if donnees[0] == "passage":
			cible.y += village.hauteur(cible.x, cible.z)
		camera_v.global_position = pos
		camera_v.look_at(cible)
		await _photo(dossier, donnees[0])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSION))
	quit()
