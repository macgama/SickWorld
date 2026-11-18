extends SceneTree
## Captures de l'affiche d'une activité et de sa bande-annonce (fenêtre visible).
## Lancement : godot --path game -s res://tests/capture_affiche.gd -- <dossier> [id_affiche]

const Affiche := preload("res://scripts/interface/affiche_activite.gd")


func _initialize() -> void:
	_lancer.call_deferred()


func _attendre(secondes: float) -> void:
	await create_timer(secondes).timeout


func _photo(dossier: String, nom: String) -> void:
	await process_frame
	await process_frame
	var chemin := dossier.path_join(nom)
	root.get_texture().get_image().save_jpg(chemin, 0.9)
	print("Capture : ", chemin)


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier := args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://")
	var id := args[1] if args.size() > 1 else "ile_chine"
	root.size = Vector2i(1600, 900)
	var fond := ColorRect.new()
	fond.color = Color(0.1, 0.12, 0.15)
	fond.size = Vector2(1600, 900)
	root.add_child(fond)
	await _attendre(0.5)
	var a = Affiche.ouvrir(self, id, func(): print("Action !"))
	await _attendre(2.0)
	await _photo(dossier, "affiche_%s.jpg" % id)
	a.lancer_bande_annonce()
	await _attendre(2.6)
	await _photo(dossier, "affiche_%s_ba1.jpg" % id)
	await _attendre(5.5)
	await _photo(dossier, "affiche_%s_ba2.jpg" % id)
	await _attendre(10.0)
	await _photo(dossier, "affiche_%s_ba3.jpg" % id)
	quit()
