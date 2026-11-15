extends SceneTree
## Captures d'écran des guildes : Maison des guildes (coffre, tableau des contrats, intendante)
## et la fenêtre Guilde (onglets Guilde, Membres, Banque, Contrats).
## Lancement (fenêtre visible, pas en --headless) :
##   godot --path game -s res://tests/capture_guildes.gd -- <dossier_sortie>

const R := preload("res://scripts/guildes/regles_guildes.gd")


func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _photo(dossier: String, nom: String) -> void:
	await _attendre(4)
	var chemin := dossier.path_join(nom)
	root.get_texture().get_image().save_jpg(chemin, 0.9)
	print("Capture : ", chemin)


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier := args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://captures")
	DirAccess.make_dir_recursive_absolute(dossier)
	var profil := "_capture_guildes_%d" % OS.get_process_id()
	Profil.activer(profil)
	var cfg := ConfigFile.new()
	cfg.set_value("intro", "terminee", true)
	cfg.set_value("guilde", "nom", "Les Gardiens du Temps")
	cfg.set_value("guilde", "couleur", 1)
	cfg.save(Profil.chemin("user://progression.cfg"))
	var reseau = root.get_node("Reseau")
	var guildes = root.get_node("Guildes")
	reseau.mode = reseau.Mode.SEUL
	reseau.nom_joueur = "Gaël"
	root.size = Vector2i(1600, 900)
	var scene: Node = load("res://scenes/monde/hikari_bay.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _attendre(80)
	var moi = get_first_node_in_group("joueur_local")
	var partie := get_first_node_in_group("partie")
	# Des membres pour la liste (Kenji et Aiko en ligne, les autres partis).
	var noms := {9001: "Kenji", 9002: "Aiko"}
	for id in noms:
		reseau.noms[id] = noms[id]
		partie.ajouter_joueur(id, noms[id])
	await _attendre(10)
	var g: Dictionary = guildes.guilde_de("Gaël")
	var t := int(Time.get_unix_time_from_system())
	for n in ["Kenji", "Aiko"]:
		R.ajouter_membre(guildes.d, g, n, "membre", t - 86400 * 3)
		guildes._index[n.to_lower()] = g["cle"]
	g["membres"]["kenji"]["rang"] = "officier"
	for n in [["Mei", "membre", 7200], ["Lucas", "recrue", 3 * 86400], ["Sofia", "membre", 26 * 3600]]:
		R.ajouter_membre(guildes.d, g, n[0], n[1], t - 86400 * 5)
		g["membres"][String(n[0]).to_lower()]["vu"] = t - int(n[2])
		guildes._index[String(n[0]).to_lower()] = g["cle"]
	g["xp"] = 1200
	R.ajuster_banque(guildes.d, g)
	for o in [["silex", 40], ["ocre_rouge", 12], ["sac_expedition_vigie", 1], ["ramen_perche", 6], ["omble_arctique", 18], ["medaille_arene", 25], ["eclat_fracture", 9], ["lame_courte_vigie", 1]]:
		if Objets.existe(root.get_node("Donnees").objets, o[0]):
			R.deposer(root.get_node("Donnees").objets, guildes.d, g, o[0], o[1])
	g["message"] = "Sortie à la Grande Grotte samedi 21 h ! Pensez au Banquet de guilde."
	var c: Array = g["contrats"]["liste"]
	var parts := {"gaël": [0.5, 0.2, 0.0], "kenji": [0.3, 0.4, 0.2], "aiko": [0.25, 0.3, 0.1], "mei": [0.0, 0.1, 0.1], "sofia": [0.1, 0.0, 0.05]}
	for qui in parts:
		for i in c.size():
			var n := int(int(c[i]["nombre"]) * float(parts[qui][i]))
			if n > 0:
				R.contribuer(guildes.d, g, String(g["membres"][qui]["nom"]), String(c[i]["type"]), n, guildes.semaine())
	for e in ["Kenji dépose Silex × 40.", "Aiko sort Ramen Kaminari à la perche du Nil.", "Contrat accompli : %s." % c[0]["titre"], "Sofia rejoint la guilde (invitée par Kenji)."]:
		R.noter(guildes.d, g, e, t - 3600)
	guildes._changer(g)
	guildes.rafraichir()
	await _attendre(5)

	# 1. La Maison des guildes : coffre, tableau des contrats, intendante.
	var camera := Camera3D.new()
	camera.fov = 62.0
	scene.add_child(camera)
	camera.global_position = Vector3(-112.0, 2.6, 3.0)
	camera.look_at(Vector3(-121.0, 1.4, 11.5))
	camera.make_current()
	moi.teleporter(Vector3(-118.5, 0.1, 9.0), PI * 0.75)
	await _attendre(60)
	await _photo(dossier, "maison-des-guildes.jpg")

	# 2. Les onglets de la fenêtre Guilde, devant le coffre.
	moi.teleporter(Vector3(-124.6, 0.1, 10.4), -PI / 2)
	camera.global_position = Vector3(-119.5, 2.4, 10.4)
	camera.look_at(Vector3(-126.4, 1.3, 10.4))
	await _attendre(30)
	var fenetre = guildes.get("_interface")
	for onglet in [[0, "fenetre-guilde.jpg"], [1, "fenetre-membres.jpg"], [2, "fenetre-banque.jpg"], [3, "fenetre-contrats.jpg"]]:
		fenetre.ouvrir(onglet[0])
		await _attendre(12)
		await _photo(dossier, onglet[1])
	fenetre.fermer()
	# 3. L'invitation et la grande annonce.
	guildes._recevoir_invitation("Kenji", "Les Gardiens du Temps")
	guildes.annonce.emit("Contrat de guilde accompli", "Chasse aux fractures ! Ceux qui ont aidé reçoivent 13 Sceaux de guilde.")
	await _attendre(40)
	await _photo(dossier, "invitation-et-annonce.jpg")
	for relatif in Profil.lister(profil):
		DirAccess.remove_absolute(Profil.dossier(profil) + relatif)
	quit()
