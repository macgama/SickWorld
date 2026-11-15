extends SceneTree
## Captures des missions du jour : le bureau d'Ayaka Mori au QG, sa fenêtre de missions,
## et un éclat de temps à ramasser sur la Côte Gelée (fenêtre visible, pas en --headless).
## Lancement : godot --path game -s res://tests/capture_missions_du_jour.gd -- <dossier_sortie>

const PROFIL := "_capture_missions"
const FICHIER := "user://progression.cfg"


func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	Profil.activer(PROFIL)
	_lancer.call_deferred()


func _effacer_profil() -> void:
	for relatif in Profil.lister(PROFIL):
		DirAccess.remove_absolute(Profil.dossier(PROFIL) + relatif)


func _lancer() -> void:
	Profil.activer(PROFIL)
	_effacer_profil()
	var args := OS.get_cmdline_user_args()
	var dossier := args[0] if args.size() > 0 else "/tmp"
	root.size = Vector2i(1600, 900)
	root.get_node("Reseau").nom_joueur = "Capture"
	var cfg := ConfigFile.new()
	cfg.set_value("intro", "terminee", true)
	cfg.set_value("prehistoire", "etape", "fin")
	cfg.set_value("egypte", "etape", "vers_desert")
	cfg.save(Profil.chemin(FICHIER))

	# 1. Le bureau des missions, au QG.
	var scene: Node = load("res://scenes/monde/hikari_bay.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _attendre(40)
	var joueur = get_first_node_in_group("joueur_local")
	var qdj = get_first_node_in_group("quetes_du_jour")
	joueur.teleporter(Vector3(-5.4, -11.7, 82.5), 0.0)
	joueur.camera.lacet = 0.0
	joueur.camera.tangage = deg_to_rad(-8.0)
	await _attendre(120)
	root.get_texture().get_image().save_jpg(dossier.path_join("missions-bureau.jpg"), 0.9)
	print("Capture : bureau")

	# 2. La fenêtre : une mission acceptée, une finie à rendre, une rendue.
	var jour: Array = qdj.offres["quotidienne"]["ids"]
	var semaine: Array = qdj.offres["hebdomadaire"]["ids"]
	qdj.accepter(String(jour[0]))
	qdj.accepter(String(jour[1]))
	qdj.accepter(String(semaine[0]))
	var c: String = qdj.cle(String(jour[0]))
	for i in qdj._nombre(qdj.mission(String(jour[0]))["objectif"]):
		qdj._avancer(c)
	var c2: String = qdj.cle(String(jour[1]))
	qdj._avancer(c2)
	qdj._avancer(c2)
	joueur.teleporter(Vector3(-8.2, -11.7, 77.0), 0.0)
	await _attendre(60)
	qdj.ouvrir_fenetre()
	await _attendre(60)
	root.get_texture().get_image().save_jpg(dossier.path_join("missions-fenetre.jpg"), 0.9)
	print("Capture : fenêtre")
	qdj.fermer_fenetre()

	# 3. L'échange chez Sven.
	joueur.get_node("Inventaire").recevoir([{"id": "insigne_vigie", "n": 18}])
	joueur.teleporter(Vector3(-3.0, -11.7, 77.0), 0.0)
	await _attendre(30)
	var fenetre = get_first_node_in_group("fenetre_artisanat")
	fenetre.ouvrir("intendance")
	await _attendre(60)
	root.get_texture().get_image().save_jpg(dossier.path_join("missions-echange.jpg"), 0.9)
	print("Capture : échange")
	fenetre.fermer_fenetre()

	# 4. Sur la Côte Gelée : un éclat de temps et la liste des missions.
	var p: int = qdj.periode("quotidienne")
	qdj.offres["quotidienne"] = {"periode": p, "ids": ["eclats_dans_la_neige", "fractures_de_la_cote", jour[2]]}
	qdj.suivies = {}
	qdj.rendues = {}
	qdj.accepter("eclats_dans_la_neige")
	qdj.accepter("fractures_de_la_cote")
	qdj._avancer(qdj.cle("fractures_de_la_cote"))
	qdj._avancer(qdj.cle("fractures_de_la_cote"))
	scene.queue_free()
	await _attendre(5)
	scene = load("res://scenes/monde/prehistoire/cote_gelee.tscn").instantiate()
	scene.get_node("Quete").voyage_reel = false
	root.add_child(scene)
	current_scene = scene
	await _attendre(80)
	joueur = get_first_node_in_group("joueur_local")
	qdj = get_first_node_in_group("quetes_du_jour")
	var eclat: Node3D = null
	for k in qdj._objets:
		eclat = qdj._objets[k]
		break
	if eclat != null:
		var pos: Vector3 = eclat.global_position + Vector3(0.6, 0, 3.2)
		pos.y = scene.hauteur(pos.x, pos.z) + 0.3
		joueur.teleporter(pos, 0.0)
		joueur.camera.lacet = 0.15
		joueur.camera.tangage = deg_to_rad(-12.0)
		for loup in get_nodes_in_group("loups"):
			if loup.global_position.distance_to(pos) < 40.0:
				loup.combat.subir(99999.0, joueur.get_node("Combat"))
	await _attendre(150)
	root.get_texture().get_image().save_jpg(dossier.path_join("missions-eclat.jpg"), 0.9)
	print("Capture : éclat")
	_effacer_profil()
	quit()
