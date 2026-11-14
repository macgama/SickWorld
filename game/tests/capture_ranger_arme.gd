extends SceneTree
## Capture du personnage arme rangée, pendant le geste, ou arme en main (fenêtre visible).
## Lancement : godot --path game -s res://tests/capture_ranger_arme.gd -- [vigie|chasseur|gardien] [range|geste|sorti] [chemin.jpg] [angle]

const ENSEMBLES := {
	"vigie": {"arme_principale": "lame_courte_vigie", "arme_secondaire": "dague_vigie"},
	"chasseur": {"tete": "capuche_chasseur", "torse": "cape_chasseur", "arme_principale": "lance_silex",
		"arme_secondaire": "couteau_obsidienne"},
	"gardien": {"tete": "bandeau_gardien", "torse": "manteau_gardien", "arme_principale": "massue_os"},
}


func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var ensemble := args[0] if args.size() > 0 else "vigie"
	var mode := args[1] if args.size() > 1 else "range"
	var sortie := args[2] if args.size() > 2 else "/tmp/ranger_arme.jpg"
	var angle := float(args[3]) if args.size() > 3 else 150.0
	root.size = Vector2i(1000, 1000)
	root.get_node("Reseau").nom_joueur = "Capture"
	DirAccess.remove_absolute(Profil.chemin("user://sauvegardes/inventaires/capture.json"))
	var scene: Node = load("res://scenes/monde/colline_de_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _attendre(20)
	var joueur = get_first_node_in_group("joueur_local")
	var inv = joueur.get_node("Inventaire")
	var cat: Dictionary = root.get_node("Donnees").objets
	for e in ENSEMBLES[ensemble]:
		var id: String = ENSEMBLES[ensemble][e]
		Objets.ajouter(cat, inv.etat, id, 1)
		var index := Objets.trouver(inv.etat, id)
		if index >= 0:
			Objets.equiper_dans(cat, inv.etat, index, e)
	inv._appliquer()
	for n in scene.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var rig = joueur.get_node("CameraRig")
	rig.distance = 3.0
	rig.set("_distance_voulue", 3.0)
	rig.retour_automatique = 0.0
	rig.lacet = deg_to_rad(angle)
	rig.tangage = deg_to_rad(-6.0)
	rig.hauteur_visee = 1.0
	await _attendre(60)
	var apparence = joueur.get_node("Apparence")
	if mode == "sorti":
		joueur.arme_rangee = false
		await _attendre(90)
	elif mode == "geste":
		joueur.arme_rangee = false
		# On fige l'image au moment où la main attrape l'arme.
		for i in 200:
			await process_frame
			if apparence._geste >= 0.42:
				break
		Engine.time_scale = 0.0
		await _attendre(3)
	else:
		await _attendre(30)
	var image := root.get_texture().get_image()
	image.save_jpg(sortie, 0.9)
	print("Capture : ", sortie)
	Engine.time_scale = 1.0
	DirAccess.remove_absolute(Profil.chemin("user://sauvegardes/inventaires/capture.json"))
	quit()
