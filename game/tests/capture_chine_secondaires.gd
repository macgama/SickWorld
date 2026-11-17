extends SceneTree
## Captures d'écran des quêtes secondaires de la Chine (fenêtre visible, pas en --headless) :
## les lettres qui brûlent, le but de cuju, le cocon de Mei, un Figé du marché, les bêtes du
## parc (cerf, grue, macaque, vieux tigre), le liubo, la mère de Bao, la pelleteuse
## miniature, la Tempête (la chamelle de Bactriane) et le cheval céleste.
## Lancement : godot --path game -s res://tests/capture_chine_secondaires.gd -- [dossier_sortie] [vue1,vue2…]

const PROGRESSION := "user://capture_chine_secondaires.cfg"
## nom, zone, id de l'objet (ou « pnj:id »), décalage de la caméra, hauteur visée.
const VUES := [
	["lettres", "porte_de_jade", "lettre_soldat_0", Vector3(1.0, 1.0, 1.4), 0.1],
	["balise", "porte_de_jade", "balise_caravane_1", Vector3(3.0, 2.0, 4.0), 0.8],
	["cuju", "porte_de_jade", "ballon_garnison", Vector3(2.0, 1.6, 3.0), 1.2],
	["sergent", "porte_de_jade", "pnj:sergent_cuju", Vector3(1.2, 1.7, 2.2), 1.4],
	["cocon", "fleuve_jaune", "cocon_mei", Vector3(1.2, 1.3, 1.4), 0.6],
	["mures", "fleuve_jaune", "feuille_murier_2", Vector3(1.4, 1.2, 2.0), 0.4],
	["fige", "luoyang", "fige_patient_0", Vector3(1.0, 1.1, 1.6), 0.5],
	["cerf", "luoyang", "cerf_echappe", Vector3(2.4, 1.4, 2.8), 0.8],
	["grue", "luoyang", "grue_echappee", Vector3(1.4, 1.5, 2.0), 1.0],
	["macaque", "luoyang", "macaque_echappe", Vector3(1.0, 1.1, 1.4), 0.6],
	["liubo", "luoyang", "table_liubo", Vector3(0.8, 1.2, 1.0), 0.35],
	["zhou", "luoyang", "pnj:maitre_zhou", Vector3(1.2, 1.7, 2.2), 1.4],
	["the", "luoyang", "brique_the", Vector3(0.9, 1.0, 1.2), 0.4],
	["tigre", "mont_li", "vieux_tigre", Vector3(2.4, 1.4, 3.0), 0.6],
	["mere_panda", "mont_li", "mere_panda", Vector3(2.0, 1.5, 2.8), 0.9],
	["bambou", "mont_li", "pousse_bambou_0", Vector3(0.8, 0.8, 1.2), 0.3],
	["pelleteuse", "mont_li", "pelleteuse_miniature", Vector3(0.8, 0.7, 1.0), 0.15],
	["chameau", "porte_de_jade", "monture:chameau_bactriane", Vector3(3.0, 1.6, -2.2), 1.3],
	["cheval_celeste", "porte_de_jade", "monture:cheval_celeste", Vector3(3.0, 1.6, -2.2), 1.2],
]


func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _photo(dossier: String, nom: String) -> void:
	await _attendre(8)
	var image := root.get_texture().get_image()
	var sortie := dossier.path_join("chine_sec_%s.jpg" % nom)
	image.save_jpg(sortie, 0.88)
	print("Capture : ", sortie)


func _charger(zone: String) -> Node:
	var cfg := ConfigFile.new()
	cfg.set_value("chine", "etape", "fin")
	cfg.save(PROGRESSION)
	var scene: Node = load("res://scenes/monde/chine/%s.tscn" % zone).instantiate()
	scene.get_node("Quete").voyage_reel = false
	scene.get_node("Quete").fichier_progression = PROGRESSION
	root.add_child(scene)
	current_scene = scene
	await _attendre(40)
	for n in scene.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var joueur := get_first_node_in_group("joueur_local") as Node3D
	if joueur != null:
		joueur.visible = false
	return scene


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier := args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://")
	var choix: PackedStringArray = args[1].split(",") if args.size() > 1 else PackedStringArray()
	root.size = Vector2i(1280, 720)
	var zone := ""
	var scene: Node
	var camera: Camera3D
	for vue in VUES:
		if not choix.is_empty() and not choix.has(vue[0]):
			continue
		if vue[1] != zone:
			if scene != null:
				scene.queue_free()
				await _attendre(10)
			zone = vue[1]
			scene = await _charger(zone)
			camera = Camera3D.new()
			camera.fov = 55.0
			camera.far = 3000.0
			scene.add_child(camera)
			camera.make_current()
		var cible: Node3D
		var id := String(vue[2])
		if id.begins_with("pnj:"):
			cible = scene.get_node("Quete")._trouver_pnj(id.substr(4))
		elif id.begins_with("monture:"):
			var bete = load("res://scripts/joueur/apparence_monture.gd").new()
			bete.reglages = JSON.parse_string(FileAccess.get_file_as_string("res://data/montures.json")).montures[id.substr(8)]
			scene.add_child(bete)
			var p := Vector3(40, 0, 6)
			p.y = scene.hauteur(p.x, p.z)
			bete.global_position = p
			bete.rotation.y = 0.6
			cible = bete
			await _attendre(10)
		else:
			cible = get_first_node_in_group("quetes_secondaires")._objets.get(id)
		if cible == null:
			print("Introuvable : ", id)
			continue
		camera.global_position = cible.global_position + vue[3]
		camera.look_at(cible.global_position + Vector3(0, vue[4], 0))
		await _photo(dossier, vue[0])
		if id.begins_with("monture:"):
			cible.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSION))
	quit()
