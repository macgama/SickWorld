extends SceneTree
## Capture d'écran d'un point de récolte (fenêtre visible, pas en --headless).
## Lancement : godot --path game -s res://tests/capture_recolte.gd -- zone source chemin.jpg [recolter|personnage]
##   recolter   : la capture est prise pendant l'action (barre d'action, bouchon de pêche…)
##   personnage : ouvre l'écran Personnage (niveaux des métiers) après quelques récoltes

const Metiers := preload("res://scripts/objets/metiers.gd")
const SCENES := {
	"cote_gelee": "res://scenes/monde/prehistoire/cote_gelee.tscn",
	"steppe": "res://scenes/monde/prehistoire/steppe.tscn",
	"foret": "res://scenes/monde/prehistoire/foret.tscn",
	"falaises": "res://scenes/monde/prehistoire/falaises.tscn",
	"port_des_marais": "res://scenes/monde/egypte/port_des_marais.tscn",
	"carrieres_toura": "res://scenes/monde/egypte/carrieres_toura.tscn",
	"village_batisseurs": "res://scenes/monde/egypte/village_batisseurs.tscn",
	"desert_rouge": "res://scenes/monde/egypte/desert_rouge.tscn",
}


func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var zone := args[0] if args.size() > 0 else "steppe"
	var id_source := args[1] if args.size() > 1 else ""
	var sortie := args[2] if args.size() > 2 else "/tmp/recolte.jpg"
	var action := args[3] if args.size() > 3 else ""
	root.size = Vector2i(1600, 900)
	root.get_node("Reseau").nom_joueur = "Capture"
	DirAccess.remove_absolute(Profil.chemin("user://sauvegardes/inventaires/capture.json"))
	var scene: Node = load(SCENES[zone]).instantiate()
	root.add_child(scene)
	current_scene = scene
	await _attendre(60)
	var joueur = get_first_node_in_group("joueur_local")
	var inv = joueur.get_node("Inventaire")
	inv.sauvegarde_active = false
	var rec: Dictionary = root.get_node("Donnees").recolte
	# Tous les métiers au niveau 10 : chaque source est récoltable.
	for m in Metiers.METIERS:
		Metiers.gagner(rec, inv.etat, m, 560 if action == "personnage" else 5000)
	inv._appliquer()
	var recolte = get_first_node_in_group("recolte")
	var i: int = recolte.point_proche(Vector3.ZERO, id_source)
	if i < 0:
		print("Aucun point « %s » dans %s" % [id_source, zone])
		quit(1)
		return
	var point: Node3D = recolte.points[i]
	var p := point.global_position
	# On se place face à la source : sur la rive pour la pêche, à 2 m sinon.
	var ou := Vector3.INF
	var distance := 2.0
	var fiche := Metiers.source(rec, point.source)
	if String(fiche.get("metier", "")) == "peche" or fiche.get("sur_l_eau", false):
		for r in [3.0, 4.5, 6.0, 7.5, 8.5]:
			for k in 24:
				var a := k * TAU / 24.0
				var q: Vector3 = p + Vector3(cos(a), 0, sin(a)) * r
				if ou == Vector3.INF and scene.hauteur(q.x, q.z) > 0.1:
					ou = q
	else:
		ou = p + Vector3(0.6, 0, distance)
	ou.y = scene.hauteur(ou.x, ou.z) + 0.2
	var d := p - ou
	joueur.teleporter(ou, atan2(-d.x, -d.z))
	await _attendre(40)
	var camera := joueur.get_node_or_null("CameraRig") as Node
	if camera != null and "lacet" in camera:
		camera.lacet = atan2(-d.x, -d.z)
	if action == "recolter" or action == "personnage":
		recolte.demander(i)
		# Le rendu logiciel est très lent et le temps de jeu file : on attend peu d'images.
		await _attendre(4 if action == "recolter" else 200)
	if action == "personnage":
		for fenetre in root.find_children("*", "PanelContainer", true, false):
			if "inventaire" in fenetre and fenetre.has_method("basculer") and fenetre.has_method("rafraichir"):
				fenetre.basculer()
		await _attendre(30)
	await _attendre(2 if action == "recolter" else 30)
	var image := root.get_texture().get_image()
	image.save_jpg(sortie, 0.9)
	print("Capture : ", sortie)
	quit()
