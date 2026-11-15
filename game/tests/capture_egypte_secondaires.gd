extends SceneTree
## Captures d'écran des quêtes secondaires et des événements publics de l'Égypte
## (fenêtre visible, pas en --headless) : Miou entre les jarres, le bloc des Compagnons
## de Khéops, le senet d'Ouni, un haleur blessé, le drone sur le chantier, et le khamsin.
## Lancement : godot --path game -s res://tests/capture_egypte_secondaires.gd -- [dossier_sortie]

const PROGRESSION := "user://capture_egypte_secondaires.cfg"
## nom, id de l'objet, décalage de la caméra par rapport à l'objet, hauteur visée.
const VUES := [
	["miou", "chat_nebi", Vector3(-1.2, 0.8, -1.4), 0.2],
	["marque", "bloc_equipe", Vector3(-1.2, 1.4, -3.0), 0.6],
	["senet", "plateau_senet", Vector3(0.9, 1.1, 1.3), 0.1],
	["blesse", "blesse_1", Vector3(1.6, 1.4, 1.8), 0.15],
	["drone", "drone_chantier", Vector3(0.8, 0.7, 1.1), 0.05],
	["orge", "orge_1", Vector3(1.5, 1.2, 2.6), 0.5],
]


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


func _charger(chemin: String) -> Node:
	var cfg := ConfigFile.new()
	cfg.set_value("egypte", "etape", "journal_merer")
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
	var scene := await _charger("res://scenes/monde/egypte/village_batisseurs.tscn")
	var sec := get_first_node_in_group("quetes_secondaires")
	var camera := Camera3D.new()
	camera.fov = 55.0
	camera.far = 3000.0
	scene.add_child(camera)
	camera.make_current()
	sec._objets["bloc_equipe"].appliquer_effet("marque")
	for vue in VUES:
		var objet: Node3D = sec._objets[vue[1]]
		camera.global_position = objet.global_position + vue[2]
		camera.look_at(objet.global_position + Vector3(0, vue[3], 0))
		await _photo(dossier, vue[0])
	scene.queue_free()
	await _attendre(10)

	# --- Le khamsin, au camp des nomades du Désert Rouge.
	var desert := await _charger("res://scenes/monde/egypte/desert_rouge.tscn")
	var evt := get_first_node_in_group("evenements_publics")
	var camera_d := Camera3D.new()
	camera_d.fov = 62.0
	camera_d.far = 3000.0
	desert.add_child(camera_d)
	camera_d.make_current()
	evt.declencher("khamsin")
	await _attendre(120)
	var pos := Vector3(-14, 0, 104)
	pos.y = desert.hauteur(pos.x, pos.z) + 2.2
	camera_d.global_position = pos
	camera_d.look_at(Vector3(-34, desert.hauteur(-34, 88) + 1.5, 88))
	await _photo(dossier, "khamsin")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSION))
	quit()
