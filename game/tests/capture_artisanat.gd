extends SceneTree
## Capture d'écran de l'établi d'un artisan dans le hub (fenêtre visible, pas en --headless).
## Lancement : godot --path game -s res://tests/capture_artisanat.gd -- [forge|atelier] [chemin.jpg] [categorie]

const MATERIAUX := {"silex": 9, "tendon_seche": 7, "bois_de_renne": 5, "croc_loup": 14, "peau_loup": 9,
	"eclat_de_fracture": 6, "ocre_rouge": 3}


func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var artisan := args[0] if args.size() > 0 else "forge"
	var sortie := args[1] if args.size() > 1 else "/tmp/artisanat.jpg"
	var categorie := args[2] if args.size() > 2 else ""
	root.size = Vector2i(1600, 900)
	root.get_node("Reseau").nom_joueur = "Capture"
	DirAccess.remove_absolute("user://sauvegardes/inventaires/capture.json")
	var scene: Node = load("res://scenes/monde/hikari_bay.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _attendre(30)
	var joueur = get_first_node_in_group("joueur_local")
	var inv = joueur.get_node("Inventaire")
	var cat: Dictionary = root.get_node("Donnees").objets
	for id in MATERIAUX:
		Objets.ajouter(cat, inv.etat, id, MATERIAUX[id])
	inv._appliquer()
	var pnj_vise := "forgeron" if artisan == "forge" else "lea"
	for p in get_nodes_in_group("pnj"):
		if p.identifiant == pnj_vise:
			joueur.teleporter(p.global_position + p.global_transform.basis.z * 2.2 + Vector3(0, 0.2, 0), p.rotation.y + PI)
	await _attendre(30)
	var fenetre = get_first_node_in_group("fenetre_artisanat")
	fenetre.ouvrir(artisan)
	if categorie != "":
		fenetre.choisir_categorie(categorie)
	await _attendre(90)
	var image := root.get_texture().get_image()
	image.save_jpg(sortie, 0.9)
	print("Capture : ", sortie)
	DirAccess.remove_absolute("user://sauvegardes/inventaires/capture.json")
	quit()
