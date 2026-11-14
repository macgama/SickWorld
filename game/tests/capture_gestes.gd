extends SceneTree
## Captures des gestes de combat des classes (fenêtre visible, pas en --headless).
## Lancement : godot --path game -s res://tests/capture_gestes.gd -- [dossier] [homme|femme]

const GESTES := ["attaque_lame", "attaque_bouclier", "bouclier_leve", "provocation", "tir_arc", "lancer",
	"incantation", "sort", "esquive_arriere"]


func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier := args[0] if args.size() > 0 else "/tmp"
	var modele := args[1] if args.size() > 1 else "homme"
	root.size = Vector2i(640, 720)
	var scene: Node = load("res://scenes/monde/colline_de_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _attendre(20)
	for n in scene.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var joueur = get_first_node_in_group("joueur_local")
	var apparence = joueur.get_node("Apparence")
	apparence.appliquer({"sexe": modele})
	var rig = joueur.get_node("CameraRig")
	rig.distance = 4.0
	rig.set("_distance_voulue", 4.0)
	rig.retour_automatique = 0.0
	rig.lacet = deg_to_rad(140.0)
	rig.tangage = deg_to_rad(-5.0)
	rig.hauteur_visee = 1.0
	await _attendre(10)
	for geste in GESTES:
		apparence.attaquer(geste, 6.0)
		await _attendre(1)
		# Image prise au milieu du geste : on fige l'animation à 45 %.
		var lecteur: AnimationPlayer = apparence.get("_lecteur")
		lecteur.speed_scale = 0.0
		lecteur.seek(lecteur.current_animation_length * 0.45, true)
		await _attendre(3)
		root.get_texture().get_image().save_jpg("%s/geste_%s.jpg" % [dossier, geste], 0.85)
		lecteur.speed_scale = 1.0
	print("Captures : ", dossier)
	quit()
