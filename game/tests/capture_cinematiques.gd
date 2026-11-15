extends SceneTree
## Captures d'écran des cinématiques (fenêtre visible, pas en --headless) :
## une image au milieu de chaque plan de chaque cinématique.
## Lancement : godot --path game -s res://tests/capture_cinematiques.gd -- [dossier_sortie] [id1,id2…]

const PROGRESSION := "user://capture_cinematiques.cfg"
## Pour chaque cinématique : scène, île, étape à charger, et où poser le joueur.
const SCENES := {
	"arrivee_prehistoire": ["res://scenes/monde/prehistoire/cote_gelee.tscn", "prehistoire", "retrouver_lenoir", null],
	"montre_effaceurs": ["res://scenes/monde/prehistoire/foret.tscn", "prehistoire", "objet_impossible", Vector3(-64, 0, 57)],
	"arrivee_egypte": ["res://scenes/monde/egypte/port_des_marais.tscn", "egypte", "retrouver_farouk", null],
	"rencontre_vera": ["res://scenes/monde/egypte/desert_rouge.tscn", "egypte", "vera", Vector3(-72, 0, -70)],
	"attaque_pierre_faite": ["res://scenes/monde/egypte/village_batisseurs.tscn", "egypte", "gardes_faite", Vector3(2, 0, -134)],
	"rencontre_djedi": ["res://scenes/monde/egypte/coeur_pyramide.tscn", "egypte", "djedi", Vector3(0, 0, 38)],
	"rencontre_isfet": ["res://scenes/monde/egypte/coeur_pyramide.tscn", "egypte", "isfet", Vector3(0, 0, 63)],
}


func _initialize() -> void:
	_lancer.call_deferred()


func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier := args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://")
	var seul := args[1] if args.size() > 1 else ""
	root.size = Vector2i(1280, 720)
	for id in SCENES:
		if seul != "" and not id in seul.split(","):
			continue
		var infos: Array = SCENES[id]
		var cfg := ConfigFile.new()
		cfg.set_value(infos[1], "etape", infos[2])
		cfg.save(PROGRESSION)
		var scene: Node = load(infos[0]).instantiate()
		scene.get_node("Quete").voyage_reel = false
		scene.get_node("Quete").fichier_progression = PROGRESSION
		root.add_child(scene)
		current_scene = scene
		await _attendre(40)
		var joueur = get_first_node_in_group("joueur_local")
		if infos[3] != null and joueur != null:
			var p: Vector3 = infos[3]
			joueur.teleporter(Vector3(p.x, scene.hauteur(p.x, p.z) + 0.3, p.z), 0.0)
			await _attendre(10)
		var cin = scene.get_node("Quete").cinematiques
		cin.jouer(id)
		await _attendre(2)
		for i in cin._plans().size():
			cin._commencer_plan(i)
			cin.set_process(false)
			await create_timer(2.3).timeout
			cin._placer_camera(cin._plans()[i], 0.6)
			await _attendre(6)
			var image := root.get_texture().get_image()
			var sortie := dossier.path_join("cine_%s_%d.jpg" % [id, i + 1])
			image.save_jpg(sortie, 0.85)
			print("Capture : ", sortie)
		cin.passer()
		await create_timer(1.0).timeout
		print("Cinématique ", id, " finie : ", not cin.est_en_cours())
		scene.queue_free()
		await _attendre(5)
	quit()
