extends SceneTree
## Captures d'écran du hub Hikari Bay depuis quelques points de vue fixes
## (pour comparer l'avant/après des graphismes).
## Lancement (fenêtre visible, pas en --headless) :
##   godot --path game -s res://tests/capture_hub.gd -- <dossier_sortie> [qualite] [vues] [options]
## qualite : bas, moyen, haut, ultra (défaut : réglage enregistré).
## vues : liste séparée par des virgules (défaut : toutes, « - » = toutes).
## options : sans_post, sans_flou (séparées par des virgules), pour comparer.

## [nom, position de la caméra, point regardé]
const VUES := [
	["place", Vector3(6, 2.2, 27), Vector3(-2, 7, -20)],
	["rue_sud", Vector3(0, 1.8, 66), Vector3(0, 6, 20)],
	["skyline", Vector3(-40, 42, 70), Vector3(10, 55, -200)],
	["vitrines", Vector3(-22, 1.7, -22), Vector3(-44, 4, -34)],
	["front_de_mer", Vector3(-30, 3, 70), Vector3(60, 18, 110)],
	["marche", Vector3(-20, 1.8, -58), Vector3(-22, 5, -120)],
	["esplanade", Vector3(64, 2.2, 6), Vector3(110, 5, -4)],
	["residences", Vector3(-74, 2.2, -4), Vector3(-112, 5, 4)],
	["terminal", Vector3(-35, 2.5, 66), Vector3(-35, 5, 95)],
	["hall_sakura", Vector3(-96, 1.7, 27.5), Vector3(-82, 1.4, 20)],
	["appartement", Vector3(-95, 41.7, 27.5), Vector3(-84, 41.3, 19)],
	["arene", Vector3(112, 2.2, 92), Vector3(136, 5, 110)],
]


func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier := args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://captures")
	DirAccess.make_dir_recursive_absolute(dossier)
	var qualite := get_root().get_node_or_null("QualiteGraphique")
	if args.size() > 1 and args[1] != "-" and qualite != null:
		qualite.choisir(args[1], false)
	var choix := PackedStringArray()
	if args.size() > 2 and args[2] != "-":
		choix = args[2].split(",")
	var options := args[3].split(",") if args.size() > 3 else PackedStringArray()
	root.size = Vector2i(1600, 900)
	var scene: Node = load("res://scenes/monde/hikari_bay.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _attendre(10)
	for n in scene.find_children("*", "CanvasLayer", true, false):
		if n.name != "PostTraitement" or options.has("sans_post"):
			(n as CanvasLayer).visible = false
	if options.has("sans_flou"):
		var we := scene.get_node("Environnement") as WorldEnvironment
		we.camera_attributes.set_meta("flou_max", false)
		we.camera_attributes.dof_blur_far_enabled = false
	# Interface des autoloads (mini-carte...) cachée aussi.
	for n in root.find_children("*", "CanvasLayer", true, false):
		if n.name != "PostTraitement" and not scene.is_ancestor_of(n):
			(n as CanvasLayer).visible = false
	var camera := Camera3D.new()
	camera.fov = 70.0
	camera.far = 3000.0
	scene.add_child(camera)
	for v in VUES:
		if not choix.is_empty() and not choix.has(v[0]):
			continue
		camera.position = v[1]
		camera.look_at(v[2])
		camera.make_current()
		# Laisse le temps aux effets progressifs (SDFGI, brouillard, TAA) de se stabiliser.
		await _attendre(40)
		var chemin: String = dossier.path_join("%s.jpg" % v[0])
		root.get_texture().get_image().save_jpg(chemin, 0.9)
		print("Capture : ", chemin)
	quit()
