extends SceneTree
## Capture d'écran des effets visuels des classes (fenêtre visible, pas en --headless).
## Lancement : godot --path game -s res://tests/capture_classes.gd -- [chemin.jpg]


func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var sortie := args[0] if args.size() > 0 else "/tmp/classes.jpg"
	root.size = Vector2i(1600, 900)
	var reseau = root.get_node("Reseau")
	var fiche := FichePersonnage.par_defaut(root.get_node("Donnees").creation)
	fiche["classe"] = "tisseur"
	reseau.fiche = fiche
	reseau.nom_joueur = "Capture"
	var scene: Node = load("res://scenes/monde/colline_de_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _attendre(20)
	var joueur = get_first_node_in_group("joueur_local")
	joueur.get_node("Inventaire").sauvegarde_active = false
	var cj = joueur.get_node("CombatJoueur")
	var loup = scene.get_node("Partie/Loups/CampNord_Loup1")
	var voisin = scene.get_node("Partie/Loups/CampNord_Loup2")
	joueur.placer(loup.global_position + Vector3(0, 0.5, 11), 0.0)
	await _attendre(30)
	cj.changer_cible(loup.combat)
	cj.utiliser(3)
	await _attendre(70)
	# Quelques effets des autres classes, posés à côté pour la photo.
	var piege: Node3D = load("res://scripts/combat/piege.gd").new()
	piege.reglages = {"rayon": 1.8, "duree": 30}
	scene.add_child(piege)
	piege.global_position = joueur.global_position + joueur.global_transform.basis.x * 2.5 - joueur.global_transform.basis.z * 2.0
	EffetsVisuels.aura(cj, joueur, Color(0.5, 0.55, 0.6), 10.0)
	EffetsVisuels.etoiles(cj, voisin, 1.5, 10.0)
	cj.utiliser(4)
	await _attendre(30)
	EffetsVisuels.projectile(cj, joueur.global_position + Vector3.UP * 1.5, loup, 0.6, 0.6, "eclat")
	EffetsVisuels.onde(cj, joueur.global_position, 6.0, Color(0.85, 0.55, 0.1))
	await _attendre(12)
	var image := root.get_texture().get_image()
	image.save_jpg(sortie, 0.9)
	print("Capture : ", sortie)
	quit()
