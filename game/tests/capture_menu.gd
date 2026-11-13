extends SceneTree
## Captures de l'écran titre, des options, d'un conseil et du menu de jeu.
## Lancement (fenêtre visible, pas en --headless) :
##   godot --path game -s res://tests/capture_menu.gd -- <dossier_sortie> [qualite]
## (options.cfg et conseils.cfg du PC sont mis de côté puis remis.)

var FICHIERS := []
const PROGRESSION := "user://capture_menu_progression.cfg"

var _dossier := ""
var _sauvegardes := {}


func _attendre_secondes(s: float) -> void:
	var fin := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < fin:
		await process_frame


func _capturer(nom: String) -> void:
	await process_frame
	var chemin := _dossier.path_join(nom + ".jpg")
	root.get_texture().get_image().save_jpg(chemin, 0.9)
	print("Capture : ", chemin)


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	FICHIERS = ["user://options.cfg", Profil.chemin("user://conseils.cfg")]
	var args := OS.get_cmdline_user_args()
	_dossier = args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://captures_menu")
	DirAccess.make_dir_recursive_absolute(_dossier)
	for f in FICHIERS:
		if FileAccess.file_exists(f):
			_sauvegardes[f] = FileAccess.get_file_as_bytes(f)
	if args.size() > 1:
		root.get_node("QualiteGraphique").choisir(args[1], false)
	root.size = Vector2i(1600, 900)

	var menu: Node = load("res://scenes/interface/menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await _attendre_secondes(7.0)
	await _capturer("titre_1")
	for plan in [1, 2]:
		menu._plan = plan
		menu._temps_plan = 5.0
		menu._voile.color.a = 0.0
		await _attendre_secondes(3.0)
		await _capturer("titre_%d" % (plan + 1))
	menu._basculer_multi()
	await _attendre_secondes(0.5)
	await _capturer("titre_multijoueur")
	menu._basculer_multi()
	menu._ouvrir_options()
	await _attendre_secondes(0.5)
	await _capturer("options_graphismes")
	menu._options._onglets.current_tab = 2
	await _attendre_secondes(0.5)
	await _capturer("options_commandes")
	menu._options._onglets.current_tab = 1
	await _attendre_secondes(0.5)
	await _capturer("options_son")
	menu.queue_free()
	await process_frame

	# En jeu : un conseil, puis le menu Échap.
	root.get_node("Reseau").mode = 0
	var conseils := root.get_node("Conseils")
	conseils._vus.clear()
	root.get_node("Options").conseils = true
	var scene: Node = load("res://scenes/monde/hikari_bay.tscn").instantiate()
	scene.get_node("Intro").fichier_progression = PROGRESSION
	scene.get_node("Intro").voyage_reel = false
	root.add_child(scene)
	current_scene = scene
	await _attendre_secondes(14.0)
	await _capturer("conseil_deplacement")
	root.get_node("Options")._menu_jeu.ouvrir()
	await _attendre_secondes(0.5)
	await _capturer("menu_jeu")
	root.get_node("Options")._menu_jeu.fermer()
	_finir()


func _finir() -> void:
	for f in FICHIERS:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
		if _sauvegardes.has(f):
			var fa := FileAccess.open(f, FileAccess.WRITE)
			fa.store_buffer(_sauvegardes[f])
			fa.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSION))
	quit()
