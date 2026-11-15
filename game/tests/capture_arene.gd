extends SceneTree
## Captures d'écran de l'Arène JcJ : défi, compte à rebours, duel en cours, récompenses
## de fin de combat, fenêtre de l'Arène (cote et classement), boutique de médailles d'Akane.
## Lancement (fenêtre visible, pas en --headless) :
##   godot --path game -s res://tests/capture_arene.gd -- <dossier_sortie>
## Un faux adversaire (« Kenji ») est ajouté, comme s'il était connecté.

var _jcj


func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _photo(dossier: String, nom: String) -> void:
	var chemin := dossier.path_join(nom)
	root.get_texture().get_image().save_jpg(chemin, 0.9)
	print("Capture : ", chemin)


## Écrit directement la fiche d'un joueur dans le classement de la capture.
func _fiche(nom: String, cote: int, v1: int, d1: int, v2: int, d2: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(Profil.chemin(_jcj.fichier_classement))
	cfg.set_value("joueurs", _jcj._cle_joueur(nom), {"nom": nom, "cote": cote, "meilleure_cote": cote,
			"combats": v1 + d1 + v2 + d2, "victoires_1c1": v1, "defaites_1c1": d1, "victoires_2c2": v2, "defaites_2c2": d2})
	cfg.save(Profil.chemin(_jcj.fichier_classement))


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier := args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://captures")
	DirAccess.make_dir_recursive_absolute(dossier)
	Profil.activer("_capture_arene")
	var cfg := ConfigFile.new()
	cfg.set_value("intro", "terminee", true)
	cfg.save(Profil.chemin("user://progression.cfg"))
	var reseau = root.get_node("Reseau")
	_jcj = root.get_node("JcJ")
	_jcj.fichier_classement = "user://_capture_arene.cfg"
	DirAccess.remove_absolute(Profil.chemin(_jcj.fichier_classement))
	_jcj.reglages["compte_a_rebours"] = 3.0
	reseau.mode = reseau.Mode.SEUL
	reseau.nom_joueur = "Gaël"
	root.size = Vector2i(1600, 900)
	var scene: Node = load("res://scenes/monde/hikari_bay.tscn").instantiate()
	var intro := scene.find_child("Intro", true, false)
	if intro != null:
		intro.voyage_reel = false
	root.add_child(scene)
	current_scene = scene
	await _attendre(60)
	var moi = get_first_node_in_group("joueur_local")
	var partie := get_first_node_in_group("partie")
	reseau.noms[2] = "Kenji"
	partie.ajouter_joueur(2, "Kenji")
	await _attendre(5)
	var kenji = partie.joueurs.get_node("2")
	kenji.get_node("Fiche").donnees = FichePersonnage.valider({"nom": "Kenji", "classe": "rempart", "sexe": "homme"}, root.get_node("Donnees").creation)
	moi.placer(Vector3(95, 0, 78), 0.0)
	kenji.placer(Vector3(96, 0, 76), 0.0)
	# Quelques résultats pour le classement (cote, victoires, défaites).
	_fiche("Akane", 1912, 38, 9, 6, 2)
	_fiche("Gaël", 1588, 9, 4, 2, 1)
	_fiche("Kenji", 1541, 6, 5, 3, 2)
	_fiche("Mei", 1497, 4, 6, 1, 1)
	_fiche("Tom", 1452, 2, 7, 0, 2)
	# Gaël a quelques médailles dans ses sacs (pour la boutique d'Akane).
	moi.get_node("Inventaire").recevoir([{"id": "medaille_arene", "n": 34}])
	await _attendre(10)

	# --- Le défi, puis le compte à rebours ---
	_jcj._defis["gaël"] = {"de": "Kenji", "format": "1c1", "equipes": [["Kenji"], ["Gaël"]], "fin": 1e9}
	_jcj._recevoir_defi("Kenji", "1c1")
	var camera := Camera3D.new()
	camera.fov = 62.0
	scene.add_child(camera)
	camera.make_current()
	camera.global_position = moi.global_position + Vector3(-4.0, 2.4, 3.5)
	camera.look_at(moi.global_position + Vector3(4.0, 1.4, -1.0))
	await _attendre(40)
	_photo(dossier, "arene-defi.jpg")
	_jcj.repondre_defi(true)
	await _attendre(4)
	var centre: Vector3 = get_first_node_in_group("arene_jcj").global_position
	# Vue depuis derrière Gaël (équipe 1, côté est), vers Kenji à l'ouest.
	camera.global_position = moi.global_position + Vector3(4.5, 2.6, 1.2)
	camera.look_at(centre + Vector3(-9.0, 1.2, 0.0))
	await _attendre(6)
	_photo(dossier, "arene-compte-a-rebours.jpg")

	# --- Le duel ---
	_jcj._match["fin_phase"] = 0.0
	await _attendre(3)
	_jcj._match["fin_phase"] = root.get_node("Regles").maintenant() + 140.0
	moi.placer(centre + Vector3(-2.0, 0, 0.6), PI / 2.0)
	kenji.placer(centre + Vector3(-4.5, 0, 0.0), -PI / 2.0)
	var cj = moi.get_node("CombatJoueur")
	cj.changer_cible(kenji.get_node("Combat"))
	kenji.get_node("Combat").pv = kenji.get_node("Combat").pv_max * 0.46
	moi.get_node("Combat").pv = moi.get_node("Combat").pv_max * 0.71
	camera.global_position = moi.global_position + Vector3(5.5, 2.6, 2.4)
	camera.look_at(moi.global_position + Vector3(-1.8, 1.1, -0.3))
	await _attendre(40)
	_photo(dossier, "arene-duel.jpg")

	# --- Le grand écran, vu des tribunes ---
	camera.global_position = centre + Vector3(-12.0, 6.0, 9.0)
	camera.look_at(centre + Vector3(22.0, 14.0, 0.0))
	await _attendre(20)
	_photo(dossier, "arene-ecran.jpg")

	# --- Fin du combat : victoire de Gaël, cote et récompense du palier 1 600 ---
	moi.get_node("Combat").pv = moi.get_node("Combat").pv_max * 0.38
	kenji.get_node("Combat").subir(999999.0, moi.get_node("Combat"))
	camera.global_position = moi.global_position + Vector3(4.2, 2.3, 1.6)
	camera.look_at(moi.global_position + Vector3(-3.5, 1.2, -0.4))
	await _attendre(12)
	_photo(dossier, "arene-recompense.jpg")

	# --- Fenêtre de l'Arène (touche H) ---
	_jcj._liberer()
	await _attendre(5)
	camera.global_position = moi.global_position + Vector3(4.2, 2.3, 1.6)
	camera.look_at(moi.global_position + Vector3(-3.5, 1.2, -0.4))
	_jcj.basculer_fenetre()
	await _attendre(20)
	_photo(dossier, "arene-fenetre.jpg")
	_jcj.basculer_fenetre()

	# --- La boutique de médailles d'Akane ---
	# (il faut être tout près d'Akane, sinon la fenêtre se referme)
	for pnj in get_nodes_in_group("pnj"):
		if String(pnj.get("identifiant")) == "championne":
			var devant: Vector3 = pnj.global_position + pnj.global_basis.z * 2.2
			moi.teleporter(devant, pnj.rotation.y + PI)
			await _attendre(3)
			camera.global_position = devant + pnj.global_basis.z * 3.5 + Vector3(0, 2.0, 0) + pnj.global_basis.x * 1.5
			camera.look_at(pnj.global_position + Vector3(0, 1.3, 0))
	var fenetre = get_first_node_in_group("fenetre_artisanat")
	if fenetre != null:
		fenetre.ouvrir("arene")
		await _attendre(20)
		_photo(dossier, "arene-boutique.jpg")
		fenetre.fermer_fenetre()
	DirAccess.remove_absolute(Profil.chemin(_jcj.fichier_classement))
	quit()
