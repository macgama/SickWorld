extends SceneTree
## Fabrique les icônes des objets (interface/icones/<id>.png) en photographiant leur maquette 3D.
## À relancer quand on ajoute un objet. Fenêtre visible nécessaire (pas --headless) :
##   godot --path game -s res://tests/generer_icones.gd
## Sur le PC on peut aussi remplacer une icône par sa propre image PNG (128 × 128, fond transparent).

const VisuelEquipement := preload("res://scripts/objets/visuel_equipement.gd")
const DOSSIER := "res://interface/icones/"
const TAILLE := 256
const FINALE := 128
## Formes portées par paire (on en montre deux côte à côte).
const PAIRES := ["brassards", "jambieres", "bottes_fourrure"]
const ARMES := ["lame", "dague", "lance", "couteau", "massue", "torche", "propulseur"]


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var vue := SubViewport.new()
	vue.size = Vector2i(TAILLE, TAILLE)
	vue.transparent_bg = true
	vue.own_world_3d = true
	vue.msaa_3d = Viewport.MSAA_8X
	vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vue)
	var monde := Node3D.new()
	vue.add_child(monde)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.75)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	monde.add_child(we)
	var cle := DirectionalLight3D.new()
	cle.rotation_degrees = Vector3(-40, 35, 0)
	cle.light_energy = 1.6
	monde.add_child(cle)
	var contre := DirectionalLight3D.new()
	contre.rotation_degrees = Vector3(-20, 200, 0)
	contre.light_energy = 0.9
	contre.light_color = Color(0.6, 0.9, 1.0)
	monde.add_child(contre)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0, 0, 3)
	camera.current = true
	monde.add_child(camera)

	DirAccess.make_dir_recursive_absolute(DOSSIER)
	var cat: Dictionary = root.get_node("Donnees").objets
	var n := 0
	for id in cat["objets"]:
		var o: Dictionary = cat["objets"][id]
		var v: Dictionary = o.get("icone", o.get("visuel", {}))
		var forme := String(v.get("forme", ""))
		if forme == "":
			print("  (pas de forme pour %s)" % id)
			continue
		var couleur := Color.from_string(String(v.get("couleur", "#808080")), Color.GRAY)
		var pivot := Node3D.new()
		monde.add_child(pivot)
		var copies := 2 if forme in PAIRES else 1
		for i in copies:
			var piece := VisuelEquipement.construire(forme, couleur)
			if piece == null:
				continue
			pivot.add_child(piece)
			if copies == 2:
				piece.position.x = (i - 0.5) * 0.17
		if forme in ARMES:
			pivot.rotation_degrees = Vector3(0, 20, -45)
		elif forme in ["bandeau", "collier"]:
			pivot.rotation_degrees = Vector3(40, 20, 0)
		elif forme == "cape_fourrure":
			pivot.rotation_degrees = Vector3(15, 150, 0)
		elif forme == "capuche_loup":
			pivot.rotation_degrees = Vector3(12, 30, 0)
		else:
			pivot.rotation_degrees = Vector3(10, 25, 0)
		await process_frame
		# Cadrage : on centre la boîte englobante et on règle le zoom.
		var boite := AABB()
		var premiere := true
		for m in pivot.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
			boite = b if premiere else boite.merge(b)
			premiere = false
		pivot.position -= boite.get_center()
		camera.size = maxf(boite.size.x, boite.size.y) * 1.18
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image := vue.get_texture().get_image()
		image.resize(FINALE, FINALE, Image.INTERPOLATE_LANCZOS)
		if o.has("ameliore_de"):
			_marque_renforce(image)
		image.save_png(DOSSIER + id + ".png")
		pivot.free()
		n += 1
	print("%d icônes enregistrées dans %s" % [n, DOSSIER])
	quit()


## Petit losange violet en haut à droite : objet renforcé par les artisans (éclats de fracture).
func _marque_renforce(image: Image) -> void:
	var centre := Vector2(FINALE - 17, 17)
	for y in 34:
		for x in 34:
			var p := Vector2(FINALE - 34 + x, y)
			var d := absf(p.x - centre.x) + absf(p.y - centre.y)
			if d <= 11.0:
				image.set_pixelv(Vector2i(p), Color(0.62, 0.45, 1.0).lerp(Color(0.95, 0.9, 1.0), clampf(1.0 - d / 6.0, 0.0, 1.0)))
			elif d <= 14.0:
				image.set_pixelv(Vector2i(p), Color(0.1, 0.05, 0.2, 1.0))
