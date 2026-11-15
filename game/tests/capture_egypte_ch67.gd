extends SceneTree
## Captures d'écran des chapitres 6 et 7 de l'Égypte (fenêtre visible, pas en --headless) :
## Hémiounou devant sa tombe et le rayon du miroir de cuivre, puis la pierre de faîte.
## Lancement : godot --path game -s res://tests/capture_egypte_ch67.gd -- [dossier_sortie]

const PROGRESSION := "user://capture_egypte_ch67.cfg"


func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _photo(dossier: String, nom: String) -> void:
	await _attendre(8)
	var image := root.get_texture().get_image()
	var sortie := dossier.path_join("egypte_%s.jpg" % nom)
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


func _camera(scene: Node, fov: float) -> Camera3D:
	var camera := Camera3D.new()
	camera.fov = fov
	camera.far = 3000.0
	scene.add_child(camera)
	camera.make_current()
	return camera


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier := args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://")
	root.size = Vector2i(1280, 720)
	# Chapitre 6 : les miroirs tournés, les rouleaux dans les niches, Hémiounou devant sa tombe.
	var desert := await _charger("res://scenes/monde/egypte/desert_rouge.tscn", "plans_hemiounou")
	var camera := _camera(desert, 60.0)
	var mq: Array = desert.MASTABAS_QUETE[0]
	var niche: Vector2 = mq[0] + Vector2(float(mq[2]), float(mq[1]) * 0.4)
	var pos := Vector3(niche.x + 8.5, 0, niche.y + 6.0)
	pos.y = desert.hauteur(pos.x, pos.z) + 2.0
	camera.global_position = pos
	camera.look_at(Vector3(niche.x + 1.0, desert.hauteur(niche.x, niche.y) + 1.0, niche.y - 1.5))
	await _photo(dossier, "miroir_hemiounou")
	desert.queue_free()
	await _attendre(10)
	# Chapitre 7 : la pierre de faîte sur son traîneau, avec ses haleurs.
	var village := await _charger("res://scenes/monde/egypte/village_batisseurs.tscn", "halage_faite")
	var camera_v := _camera(village, 58.0)
	var depart: Vector2 = village.DEPART_FAITE
	var p := Vector3(depart.x + 6.0, 0, depart.y + 5.0)
	p.y = village.hauteur(p.x, p.z) + 2.2
	camera_v.global_position = p
	camera_v.look_at(Vector3(depart.x, village.hauteur(depart.x, depart.y) + 1.4, depart.y))
	await _photo(dossier, "pierre_de_faite")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSION))
	quit()
