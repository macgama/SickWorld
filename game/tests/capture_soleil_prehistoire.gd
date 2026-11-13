extends SceneTree
## Capture face au soleil d'une zone de la Préhistoire (pour vérifier le ciel).
## godot --path game -s res://tests/capture_soleil_prehistoire.gd -- <dossier> <zone> [qualite]
## zone : cote_gelee, steppe, falaises, foret.
## Options (4e argument, séparées par des virgules) pour chercher l'origine d'un défaut :
## sans_volume (pas de brume volumétrique), sans_soleil_brume (le soleil n'éclaire
## pas la brume), sans_aerien (pas de perspective aérienne), sans_ombres.

const Ambiance := preload("res://scripts/monde/prehistoire/ambiance_prehistoire.gd")


func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier := args[0]
	var zone_id := args[1] if args.size() > 1 else "steppe"
	var qualite := root.get_node_or_null("QualiteGraphique")
	if args.size() > 2 and args[2] != "-" and qualite != null:
		qualite.choisir(args[2], false)
	root.size = Vector2i(1280, 720)
	var scene: Node = load("res://scenes/monde/prehistoire/%s.tscn" % zone_id).instantiate()
	var quete := scene.get_node_or_null("Quete")
	if quete != null:
		quete.voyage_reel = false
		quete.fichier_progression = "user://capture_progression.cfg"
	root.add_child(scene)
	current_scene = scene
	await _attendre(10)
	for n in root.find_children("*", "CanvasLayer", true, false):
		if n.name != "PostTraitement":
			(n as CanvasLayer).visible = false
	var options := args[3].split(",") if args.size() > 3 else PackedStringArray()
	var we := scene.get_node_or_null("Environnement") as WorldEnvironment
	var soleil := scene.get_node_or_null("Soleil") as DirectionalLight3D
	if we != null and options.has("sans_volume"):
		we.environment.volumetric_fog_enabled = false
	if we != null and options.has("sans_aerien"):
		we.environment.fog_aerial_perspective = 0.0
	if soleil != null and options.has("sans_soleil_brume"):
		soleil.light_volumetric_fog_energy = 0.0
	if soleil != null and options.has("sans_ombres"):
		soleil.shadow_enabled = false
	var s: Vector2 = Ambiance.CLIMATS[zone_id]["soleil"]
	var az := deg_to_rad(s.x)
	var haut := deg_to_rad(s.y)
	var vers_soleil := Vector3(sin(az) * cos(haut), sin(haut), -cos(az) * cos(haut))
	var camera := Camera3D.new()
	camera.fov = 70.0
	camera.far = 3000.0
	scene.add_child(camera)
	var pos := Vector3(0, 0, 0)
	if scene.has_method("hauteur"):
		pos.y = scene.hauteur(0, 0)
	pos.y += 4.0
	camera.global_position = pos
	# Soleil un peu au-dessus du centre de l'image.
	camera.look_at(pos + vers_soleil - Vector3(0, 0.15, 0))
	camera.make_current()
	await _attendre(40)
	var suffixe := ("_" + "_".join(options)) if not options.is_empty() else ""
	var sortie := dossier.path_join("soleil_%s%s.jpg" % [zone_id, suffixe])
	root.get_texture().get_image().save_jpg(sortie, 0.9)
	print("Capture : ", sortie)
	quit()
