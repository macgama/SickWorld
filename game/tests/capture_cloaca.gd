extends SceneTree
## Captures d'écran du donjon du Colisée (Rome, chapitre 8) : la Cloaca Maxima, puis l'arène
## et le Colosse (au repos et en plein combat), et le Colosse en ville. Fenêtre visible, pas
## en --headless.
## Lancement : godot --path game -s res://tests/capture_cloaca.gd -- [dossier_sortie] [vue1,vue2…|-]

const FICHIER := "user://capture_cloaca.cfg"
const VUES := [
	# nom, scène, étape, position caméra, point visé
	["escalier", "cloaca", "viperes_egout", Vector3(0, -6.2, -62), Vector3(0, -8.0, -30)],
	["egout", "cloaca", "viperes_egout", Vector3(-3.4, -6.4, -20), Vector3(1.0, -8.0, -60)],
	["citerne", "cloaca", "vannes", Vector3(-12, -6.0, -6), Vector3(10, -7.0, 14)],
	["canal", "cloaca", "retiaire_canal", Vector3(0, -5.6, 24), Vector3(0, -2.0, 60)],
	["colosse", "colisee", "colosse", Vector3(-10, 2.0, 8), Vector3(43, 14.0, 0)],
	["colosse_pres", "colisee", "colosse", Vector3(22, 2.4, 10), Vector3(43, 18.0, 0)],
	["combat", "colisee", "colosse:combat", Vector3(4, 7.0, 22), Vector3(36, 8.0, 0)],
	["visages", "colisee", "colosse:visages", Vector3(10, 9.0, -14), Vector3(40, 14.0, 0)],
	["ville", "rome", "entrer_cloaca", Vector3(-16, 3.0, -88), Vector3(14, 22.0, -60)],
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
		cfg.set_value("rome", "etape", etape)
		cfg.save(FICHIER)
		var scene: Node = load("res://scenes/monde/rome/%s.tscn" % vue[1]).instantiate()
		scene.get_node("Quete").voyage_reel = false
		scene.get_node("Quete").fichier_progression = FICHIER
		root.add_child(scene)
		current_scene = scene
		await _attendre(40)
		var joueur := get_first_node_in_group("joueur_local") as Node3D
		if joueur != null:
			joueur.visible = false
		if mode != "":
			# On fige le combat dans l'état voulu (phase 3 : l'eau monte, Janus et Masque).
			var phase := 3 if mode == "combat" else 2
			scene._etat_colosse(phase, PI * 0.5 + (0.0 if phase == 3 else 0.9), 1.3 if phase == 3 else scene.EAU_BAS, 3, phase == 3, phase == 3)
			scene._eau_niveau = 1.3 if phase == 3 else scene.EAU_BAS
			if phase == 3:
				scene._eau_arene.position.y = 1.3
				scene._eau_arene.visible = true
			await _attendre(30)
		var camera := Camera3D.new()
		camera.fov = 65.0
		camera.far = 4000.0
		scene.add_child(camera)
		camera.make_current()
		var pos: Vector3 = vue[3]
		var cible: Vector3 = vue[4]
		if vue[1] == "rome":
			# En ville, les hauteurs sont relatives au sol.
			pos.y += scene.hauteur(pos.x, pos.z)
			cible.y += scene.hauteur(cible.x, cible.z)
		camera.global_position = pos
		camera.look_at(cible)
		for n in scene.find_children("*", "CanvasLayer", true, false):
			(n as CanvasLayer).visible = false
		await _attendre(10)
		var image := root.get_texture().get_image()
		var sortie := dossier.path_join("cloaca_%s.jpg" % vue[0])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
		scene.queue_free()
		await _attendre(5)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	quit()
