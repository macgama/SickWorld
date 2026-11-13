extends SceneTree
## Capture d'écran du personnage avec un ensemble d'équipement (fenêtre visible, pas en --headless).
## Lancement : godot --path game -s res://tests/capture_equipement.gd -- [vigie|chasseur|gardien] [chemin.jpg] [angle] [fenetre]
## « fenetre » : laisse l'interface et ouvre l'écran Personnage.

const ENSEMBLES := {
	"vigie": {},
	"chasseur": {"tete": "capuche_chasseur", "torse": "cape_chasseur", "mains": "brassards_chasseur",
		"jambes": "jambieres_chasseur", "pieds": "mocassins_chasseur", "arme_principale": "lance_silex",
		"arme_secondaire": "couteau_obsidienne", "bijou_1": "collier_dents_loup", "relique": "propulseur_sculpte"},
	"gardien": {"tete": "bandeau_gardien", "torse": "manteau_gardien", "mains": "gants_gardien",
		"jambes": "jambieres_gardien", "pieds": "bottes_gardien", "arme_principale": "massue_os",
		"bijou_1": "collier_coquillages", "relique": "ocre_sacree"},
}


func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var ensemble := args[0] if args.size() > 0 else "chasseur"
	var sortie := args[1] if args.size() > 1 else "/tmp/equipement.jpg"
	var angle := float(args[2]) if args.size() > 2 else 150.0
	var fenetre := args.size() > 3 and args[3] == "fenetre"
	root.size = Vector2i(1600, 900)
	root.get_node("Reseau").nom_joueur = "Capture"
	DirAccess.remove_absolute(Profil.chemin("user://sauvegardes/inventaires/capture.json"))
	var scene: Node = load("res://scenes/monde/colline_de_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _attendre(20)
	var joueur = get_first_node_in_group("joueur_local")
	var inv = joueur.get_node("Inventaire")
	for e in ENSEMBLES[ensemble]:
		var id: String = ENSEMBLES[ensemble][e]
		Objets.ajouter(root.get_node("Donnees").objets, inv.etat, id, 1)
		var index := Objets.trouver(inv.etat, id)
		if index >= 0:
			Objets.equiper_dans(root.get_node("Donnees").objets, inv.etat, index, e)
	inv._appliquer()
	if not fenetre:
		for n in scene.find_children("*", "CanvasLayer", true, false):
			(n as CanvasLayer).visible = false
	var rig = joueur.get_node("CameraRig")
	rig.distance = 2.6
	rig.set("_distance_voulue", 2.6)
	rig.retour_automatique = 0.0
	rig.lacet = deg_to_rad(angle)
	rig.tangage = deg_to_rad(-8.0)
	rig.hauteur_visee = 1.1
	await _attendre(40)
	if fenetre:
		var hud = scene.find_children("*", "CanvasLayer", true, false)[0]
		if hud.has_method("basculer_personnage"):
			hud.basculer_personnage()
	await _attendre(60)
	var image := root.get_texture().get_image()
	image.save_jpg(sortie, 0.9)
	print("Capture : ", sortie)
	DirAccess.remove_absolute(Profil.chemin("user://sauvegardes/inventaires/capture.json"))
	quit()
