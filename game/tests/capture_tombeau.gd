extends SceneTree
## Captures d'écran du tombeau du Premier Empereur (Chine, chapitre 8) : la galerie des
## arbalètes, la salle des fleuves de mercure, le palais souterrain et l'Empereur d'argile (au
## repos et en plein combat), et l'entrée au mont Li. Fenêtre visible, pas en --headless.
## Lancement : godot --path game -s res://tests/capture_tombeau.gd -- [dossier_sortie] [vue1,vue2…|-]

const FICHIER := "user://capture_tombeau.cfg"
const VUES := [
	# nom, scène, étape, position caméra, point visé
	["descente", "tombeau", "galerie", Vector3(0, -1.0, -99), Vector3(0, -9.0, -70)],
	["galerie", "tombeau", "galerie:volee", Vector3(-3.2, -8.2, -76), Vector3(2.0, -9.4, -50)],
	["fleuves", "tombeau", "fleuves", Vector3(-16, -6.0, -38), Vector3(8, -10.0, -16)],
	["palais", "tombeau", "empereur", Vector3(0, -6.5, 6), Vector3(0, -2.0, 50)],
	["empereur", "tombeau", "empereur", Vector3(-8, -8.0, 30), Vector3(0, 0.0, 52)],
	["etoiles", "tombeau", "empereur", Vector3(-18, -8.0, 12), Vector3(0, 6.0, 30)],
	["combat_mercure", "tombeau", "empereur:2", Vector3(16, -4.0, 8), Vector3(-2, -9.0, 32)],
	["autodafe", "tombeau", "empereur:3", Vector3(-22, -6.0, 8), Vector3(4, -4.0, 40)],
	["gravats", "tombeau", "cinabre_arretee", Vector3(-6, -7.0, 30), Vector3(0, -8.0, 50)],
	["entree", "mont_li", "entrer_tombeau", Vector3(-80, 7.0, -8), Vector3(-84, 5.0, -27)],
]


func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier := args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://")
	root.size = Vector2i(1280, 720)
	var choix := PackedStringArray()
	if args.size() > 1 and args[1] != "-":
		choix = args[1].split(",")
	for vue in VUES:
		if not choix.is_empty() and not choix.has(vue[0]):
			continue
		var etape: String = String(vue[2]).get_slice(":", 0)
		var mode: String = String(vue[2]).get_slice(":", 1) if String(vue[2]).contains(":") else ""
		var cfg := ConfigFile.new()
		cfg.set_value("chine", "etape", etape)
		cfg.set_value("chine", "choix_choix_masque", "allier_masque")
		cfg.save(FICHIER)
		var scene: Node = load("res://scenes/monde/chine/%s.tscn" % vue[1]).instantiate()
		scene.get_node("Quete").voyage_reel = false
		scene.get_node("Quete").fichier_progression = FICHIER
		root.add_child(scene)
		current_scene = scene
		await _attendre(40)
		var joueur := get_first_node_in_group("joueur_local") as Node3D
		if joueur != null:
			joueur.visible = false
		if mode == "volee":
			scene.set_process(false)
			scene._etat_tombeau(0, 0, -62.0, INF, 0, 0, false)
			scene._tirer(-58.0, true)
			await _attendre(2)
		elif mode != "":
			# On fige le combat dans l'état voulu (phase 2 : le mercure ; phase 3 : les bûchers).
			var phase := int(mode)
			scene.set_process(false)
			scene._etat_tombeau(phase, 15, INF, INF, 1 if phase == 2 else 0, 15 if phase == 3 else 0, false)
			await _attendre(30)
		var camera := Camera3D.new()
		camera.fov = 65.0
		camera.far = 4000.0
		scene.add_child(camera)
		camera.make_current()
		var pos: Vector3 = vue[3]
		var cible: Vector3 = vue[4]
		if vue[1] == "mont_li":
			# En ville, les hauteurs sont relatives au sol.
			pos.y += scene.hauteur(pos.x, pos.z)
			cible.y += scene.hauteur(cible.x, cible.z)
		camera.global_position = pos
		camera.look_at(cible)
		for n in scene.find_children("*", "CanvasLayer", true, false):
			(n as CanvasLayer).visible = false
		await _attendre(10)
		var image := root.get_texture().get_image()
		var sortie := dossier.path_join("tombeau_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
		scene.queue_free()
		await _attendre(5)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	quit()
