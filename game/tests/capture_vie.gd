extends SceneTree
## Captures « avant / après » de la vie ambiante d'une zone (fenêtre visible, pas en --headless).
## Lancement :
##   godot --path game --rendering-driver vulkan -s res://tests/capture_vie.gd -- \
##       <scene.tscn> <dossier> <prefixe> "nom@x,y,z@cx,cy,cz" ["nom2@…" …] [--sans-vie]
## y de la caméra et du point visé : hauteur au-dessus du sol (relatif à hauteur(x, z)).
## --sans-vie : capture « avant » (sans oiseaux, insectes, figurants ni objets semés).


func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _vec(t: String) -> Vector3:
	var p := t.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


func _lancer() -> void:
	var args := Array(OS.get_cmdline_user_args()).filter(func(a): return a != "--sans-vie")
	var chemin_scene: String = args[0]
	var dossier: String = args[1]
	DirAccess.make_dir_recursive_absolute(dossier)
	var prefixe: String = args[2]
	root.size = Vector2i(1280, 720)
	var fichier := "user://capture_vie_%d.cfg" % OS.get_process_id()
	var scene: Node = load(chemin_scene).instantiate()
	var quete := scene.get_node_or_null("Quete")
	if quete != null:
		quete.voyage_reel = false
		quete.fichier_progression = fichier
	root.add_child(scene)
	current_scene = scene
	await _attendre(40)
	for n in root.find_children("*", "CanvasLayer", true, false):
		if (n as CanvasLayer).layer >= 0:
			(n as CanvasLayer).visible = false
	for j in get_nodes_in_group("joueur_local"):
		(j as Node3D).visible = false
	var camera := Camera3D.new()
	camera.fov = 65.0
	camera.far = 4000.0
	scene.add_child(camera)
	camera.make_current()
	for v: String in args.slice(3):
		var morceaux := v.split("@")
		var pos := _vec(morceaux[1])
		var cible := _vec(morceaux[2])
		if scene.has_method("hauteur"):
			var niveau = scene.get("NIVEAU_MER")
			var mer := float(niveau) if niveau != null else -1000.0
			pos.y += maxf(scene.hauteur(pos.x, pos.z), mer)
			cible.y += maxf(scene.hauteur(cible.x, cible.z), mer)
		if morceaux[0].begins_with("plan"):
			# Vue de dessus orthographique : pos = centre (x, z) ; pos.y = largeur vue (m).
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = _vec(morceaux[1]).y
			camera.global_position = Vector3(pos.x, 300, pos.z)
			camera.look_at(Vector3(pos.x, 0, pos.z), Vector3.FORWARD)
		else:
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.global_position = pos
			camera.look_at(cible)
		await _attendre(12)
		var image := root.get_texture().get_image()
		var sortie := dossier.path_join("%s_%s.jpg" % [prefixe, morceaux[0]])
		image.save_jpg(sortie, 0.88)
		print("Capture : ", sortie)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fichier))
	quit()
