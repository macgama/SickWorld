extends SceneTree
## Capture d'écran de la discussion, des cadres du groupe et d'une bulle, sur la Place Hikari.
## Lancement (fenêtre visible, pas en --headless) :
##   godot --path game -s res://tests/capture_social.gd -- <dossier_sortie>
## Un faux coéquipier (« Kenji ») est ajouté à côté du joueur pour l'image.

func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier := args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://captures")
	DirAccess.make_dir_recursive_absolute(dossier)
	Profil.activer("_capture_social")
	var cfg := ConfigFile.new()
	cfg.set_value("intro", "terminee", true)
	cfg.set_value("guilde", "nom", "Les Gardiens du Temps")
	cfg.save(Profil.chemin("user://progression.cfg"))
	var reseau = root.get_node("Reseau")
	var social = root.get_node("Social")
	reseau.mode = reseau.Mode.SEUL
	reseau.nom_joueur = "Gaël"
	root.size = Vector2i(1600, 900)
	var scene: Node = load("res://scenes/monde/hikari_bay.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _attendre(60)
	var moi = get_first_node_in_group("joueur_local")
	moi.placer(Vector3(2, 0.1, 30), 0.0)
	# Un coéquipier à côté, dans le groupe.
	var kenji = load("res://scenes/joueur/joueur.tscn").instantiate()
	kenji.name = "2"
	kenji.nom = "Kenji"
	scene.get_node("Partie/Joueurs").add_child(kenji)
	kenji.global_position = moi.global_position + Vector3(-1.5, 0, 0.4)
	kenji.rotation.y = 0.5
	kenji.get_node("Fiche").donnees = FichePersonnage.valider({"nom": "Kenji", "classe": "tisseur", "sexe": "homme"}, root.get_node("Donnees").creation)
	kenji.get_node("Combat").pv = kenji.get_node("Combat").pv_max * 0.72
	reseau.noms[2] = "Kenji"
	await _attendre(20)
	social._recevoir_groupe([
		{"nom": "Gaël", "chef": true, "id": 1, "classe": "lame", "etat": "ici", "donjon": ""},
		{"nom": "Kenji", "chef": false, "id": 2, "classe": "tisseur", "etat": "ici", "donjon": ""},
		{"nom": "Aiko", "chef": false, "id": 0, "classe": "traqueur", "etat": "donjon", "donjon": "La Grande Grotte"},
	])
	social._recevoir("general", "Aiko", "Quelqu'un pour la Grande Grotte ce soir ?", 0)
	social._recevoir("guilde", "Mei", "Réunion de guilde au QG à 21 h !", 0)
	social._recevoir("prive", "Aiko", "Je vous attends devant le portail.", 0)
	social._recevoir("groupe", "Kenji", "Je soigne, tu tanks ?", 2)
	var camera := Camera3D.new()
	camera.fov = 60.0
	scene.add_child(camera)
	camera.global_position = moi.global_position + Vector3(0.6, 2.1, 5.0)
	camera.look_at(moi.global_position + Vector3(-0.7, 1.6, 0.0))
	camera.make_current()
	await _attendre(60)
	var interface = social.get("_interface")
	if interface != null:
		interface.ouvrir_discussion("/gr Rendez-vous au QG")
	# Les bulles durent quelques secondes : on parle juste avant la photo.
	social._recevoir("dire", "Gaël", "On y va, appuie sur K !", 1)
	social._recevoir("dire", "Kenji", "C'est parti, je te suis !", 2)
	await _attendre(3)
	var chemin: String = dossier.path_join("discussion-et-groupe.jpg")
	root.get_texture().get_image().save_jpg(chemin, 0.9)
	print("Capture : ", chemin)
	if interface != null:
		interface.fermer_discussion()
		interface.basculer_donjons()
	await _attendre(10)
	chemin = dossier.path_join("fenetre-donjons.jpg")
	root.get_texture().get_image().save_jpg(chemin, 0.9)
	print("Capture : ", chemin)
	quit()
