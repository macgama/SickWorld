extends SceneTree
## Captures du tableau de recrutement des guildes et des blasons (fenêtre visible).
## Lancement : godot --path game -s res://tests/capture_tableau_guildes.gd -- <dossier>

const Tableau := preload("res://scripts/interface/tableau_guildes.gd")


func _initialize() -> void:
	_lancer.call_deferred()


func _photo(dossier: String, nom: String) -> void:
	for i in 4:
		await process_frame
	var chemin := dossier.path_join(nom)
	root.get_texture().get_image().save_jpg(chemin, 0.9)
	print("Capture : ", chemin)


func _lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var dossier := args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://")
	root.size = Vector2i(1600, 900)
	var fond := ColorRect.new()
	fond.color = Color(0.12, 0.1, 0.09)
	fond.size = Vector2(1600, 900)
	root.add_child(fond)
	var liste := [
		{"nom": "Les Gardiens du Temps", "couleur": 1, "niveau": 4, "membres": 27, "membres_max": 60, "en_ligne": 9, "maitre": "Aiko", "ouvert": true, "devise": "Ensemble contre l'oubli. Débutants bienvenus, sorties donjon chaque soir.", "blason": {"forme": 0, "symbole": 1}},
		{"nom": "Ordre de la Flamme", "couleur": 3, "niveau": 6, "membres": 41, "membres_max": 80, "en_ligne": 14, "maitre": "Renaud", "ouvert": true, "devise": "Arène et classement : on vise le top 10.", "blason": {"forme": 3, "symbole": 2}},
		{"nom": "Lune de Jade", "couleur": 2, "niveau": 2, "membres": 8, "membres_max": 40, "en_ligne": 3, "maitre": "Mei", "ouvert": true, "devise": "Récolte, cuisine et artisanat, à notre rythme.", "blason": {"forme": 1, "symbole": 3}},
		{"nom": "Les Cartographes de l'Ombre", "couleur": 4, "niveau": 8, "membres": 70, "membres_max": 100, "en_ligne": 22, "maitre": "Kenji", "ouvert": false, "devise": "", "blason": {"forme": 2, "symbole": 9}},
	]
	var guildes := root.get_node("Guildes")
	var t = Tableau.ouvrir(self)
	await _photo(dossier, "tableau-sans-guilde-vide.jpg")
	t._remplir(liste)
	await _photo(dossier, "tableau-sans-guilde.jpg")
	guildes.guilde = {"nom": "Les Veilleurs d'Hikari", "couleur": 0, "blason": {"forme": 0, "symbole": 0},
			"recrutement": {"ouvert": true, "devise": "On répare l'histoire, une époque à la fois."},
			"droits": {"inviter": true, "promouvoir": true}}
	t._remplir_ma_guilde()
	t._remplir(liste)
	await _photo(dossier, "tableau-ma-guilde.jpg")
	# Planche de tous les blasons (4 formes × 12 symboles).
	t.queue_free()
	var Blason := preload("res://scripts/interface/dessin_blason.gd")
	var grille := GridContainer.new()
	grille.columns = 12
	grille.position = Vector2(40, 60)
	root.add_child(grille)
	for f in 4:
		for s in 12:
			var b = Blason.new()
			b.custom_minimum_size = Vector2(120, 120)
			b.forme = f
			b.symbole = s
			b.couleur = [Color("#801f59"), Color("#2666cc"), Color("#1f8059"), Color("#d9801a")][f]
			grille.add_child(b)
	await _photo(dossier, "blasons.jpg")
	quit()
