extends SceneTree
## Test de l'écran de création du personnage et de la « fiche » qu'il produit.
## Lancement : godot --headless --path game -s res://tests/test_creation_personnage.gd
## (Le personnage déjà sauvegardé sur le PC est mis de côté puis remis à la fin.)

const FICHIER := "user://personnage.json"

var _echecs := 0
var _sauvegarde_existante = null


func _verifier(condition: bool, message: String) -> void:
	print("  OK   " if condition else "  ÉCHEC ", message)
	if not condition:
		_echecs += 1


func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	if FileAccess.file_exists(FICHIER):
		_sauvegarde_existante = FileAccess.get_file_as_string(FICHIER)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	var catalogue: Dictionary = root.get_node("Donnees").creation
	_tester_fiche(catalogue)
	_tester_apparence(catalogue)
	await _tester_ecran(catalogue)
	await _tester_en_jeu(catalogue)
	_finir()


func _tester_fiche(catalogue: Dictionary) -> void:
	print("La fiche du personnage")
	_verifier(catalogue.get("classes", []).size() == 4, "les 4 classes sont dans le catalogue")
	_verifier(catalogue.get("origines", []).size() >= 6, "les villes d'origine sont dans le catalogue")
	var defaut := FichePersonnage.par_defaut(catalogue)
	_verifier(FichePersonnage.valider(defaut, catalogue) == defaut, "la fiche par défaut est valide")

	var tricheuse := {
		"nom": "<b>Hack</b>", "sexe": "dragon", "classe": "dieu", "origine": "atlantide",
		"peau": 42, "corps": {"taille_cm": 320, "corpulence": -8}, "visage": {"menton": 50.0, "inconnu": 3},
	}
	var propre := FichePersonnage.valider(tricheuse, catalogue)
	_verifier(propre["classe"] == "lame" and propre["origine"] == defaut["origine"], "classe et origine inventées remplacées")
	_verifier(propre["sexe"] in ["femme", "homme"], "sexe inconnu remplacé")
	_verifier(propre["corps"]["taille_cm"] == 200.0 and propre["corps"]["corpulence"] == -1.0,
			"curseurs du corps ramenés dans leurs limites")
	_verifier(propre["visage"]["menton"] == 1.0 and not propre["visage"].has("inconnu"),
			"curseurs du visage bornés, curseurs inconnus ignorés")
	_verifier(propre["nom"] == "Agent", "nom interdit remplacé")
	_verifier(FichePersonnage.valider("pas une fiche", catalogue) == defaut, "une fiche illisible donne la fiche par défaut")

	_verifier(FichePersonnage.erreur_nom("Al") != "", "nom trop court refusé")
	_verifier(FichePersonnage.erreur_nom("Un nom vraiment beaucoup trop long") != "", "nom trop long refusé")
	_verifier(FichePersonnage.erreur_nom("R2-D2") != "", "chiffres refusés dans le nom")
	_verifier(FichePersonnage.erreur_nom("Aïko d'Hikari-Bay") == "", "accents, tirets et apostrophes acceptés")
	_verifier(FichePersonnage.nettoyer_nom("  Jean   Luc ") == "Jean Luc", "espaces en trop retirés")

	var tokyo := defaut.duplicate(true)
	tokyo["origine"] = "tokyo"
	_verifier(FichePersonnage.bonus(tokyo, catalogue, "cout_esquive_pourcent") == -10.0, "bonus de Tokyo lu")
	_verifier(FichePersonnage.bonus(tokyo, catalogue, "reputation_pourcent") == 0.0, "pas de bonus d'une autre ville")
	for i in 20:
		var hasard := FichePersonnage.au_hasard(catalogue, defaut)
		if FichePersonnage.valider(hasard, catalogue) != hasard:
			_verifier(false, "un personnage au hasard est valide")
			return
	_verifier(true, "20 personnages au hasard sont tous valides")


## Chaque curseur du visage doit changer quelque chose sur la tête.
func _tester_apparence(catalogue: Dictionary) -> void:
	print("L'apparence suit la fiche")
	var apparence := Node3D.new()
	apparence.set_script(load("res://scripts/joueur/apparence_provisoire.gd"))
	root.add_child(apparence)
	var base := FichePersonnage.par_defaut(catalogue, "homme")
	var muets: Array[String] = []
	for curseur in catalogue.get("visage", []):
		var id: String = curseur["id"]
		var signatures := []
		for valeur in [-1.0, 1.0]:
			var f := base.duplicate(true)
			f["visage"][id] = valeur
			apparence.appliquer(FichePersonnage.resoudre(f, catalogue))
			signatures.append(_signature(apparence.get("_tete")))
		if signatures[0] == signatures[1]:
			muets.append(id)
	_verifier(muets.is_empty(), "chaque curseur du visage modifie la tête %s" % (str(muets) if not muets.is_empty() else ""))

	var petite := base.duplicate(true)
	petite["corps"]["taille_cm"] = 150
	apparence.appliquer(FichePersonnage.resoudre(petite, catalogue))
	var echelle_petite: float = apparence.get("_racine").scale.y
	var grande := base.duplicate(true)
	grande["corps"]["taille_cm"] = 200
	apparence.appliquer(FichePersonnage.resoudre(grande, catalogue))
	_verifier(apparence.get("_racine").scale.y > echelle_petite * 1.25, "la taille change la silhouette")

	var formes := {}
	for classe in catalogue.get("classes", []):
		var f := base.duplicate(true)
		f["classe"] = classe["id"]
		apparence.appliquer(FichePersonnage.resoudre(f, catalogue))
		formes[_signature(apparence)] = true
	_verifier(formes.size() == 4, "chaque classe a son arme")

	var coiffures := {}
	for coiffure in catalogue.get("coiffures", []):
		var f := base.duplicate(true)
		f["coiffure"] = coiffure["id"]
		apparence.appliquer(FichePersonnage.resoudre(f, catalogue))
		coiffures[_signature(apparence.get("_tete"))] = true
	_verifier(coiffures.size() == catalogue.get("coiffures", []).size(), "chaque coiffure est différente")
	apparence.queue_free()


func _signature(noeud: Node3D) -> String:
	var morceaux := []
	for n in noeud.find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		var t := m.global_transform
		morceaux.append("%s|%s|%s|%s" % [t.origin.snapped(Vector3.ONE * 0.0001), t.basis.x.snapped(Vector3.ONE * 0.0001),
				t.basis.y.snapped(Vector3.ONE * 0.0001), m.get_aabb().size.snapped(Vector3.ONE * 0.0001)])
	return ";".join(morceaux)


func _tester_ecran(catalogue: Dictionary) -> void:
	print("L'écran de création")
	var ecran: Node = load("res://scenes/interface/creation_personnage.tscn").instantiate()
	root.add_child(ecran)
	current_scene = ecran
	await _attendre(3)
	_verifier(ecran.etape == 0, "on commence par l'apparence")
	for i in 4:
		ecran.choisir_sous_onglet(i)
		await _attendre(1)
	_verifier(ecran.get("_cadrage") == "corps", "l'onglet Tenue montre le corps entier")
	ecran.choisir_sous_onglet(1)
	await _attendre(1)
	_verifier(ecran.get("_cadrage") == "visage", "l'onglet Visage zoome sur le visage")
	var curseur: HSlider = ecran.find_child("ecart_yeux", true, false)
	_verifier(curseur != null, "le curseur « Écart des yeux » est affiché")
	if curseur != null:
		curseur.value = 0.8
		_verifier(is_equal_approx(ecran.fiche["visage"]["ecart_yeux"], 0.8), "bouger un curseur change la fiche")

	ecran.aller_etape(1)
	ecran.fiche["classe"] = "traqueur"
	ecran.aller_etape(2)
	ecran.fiche["origine"] = "tokyo"
	ecran.aller_etape(2)
	var champ: LineEdit = ecran.get("_champ_nom")
	_verifier(champ != null, "le nom se choisit à la dernière étape")
	champ.text = "Al"
	_verifier(ecran.terminer() != "", "un nom trop court empêche de valider")
	_verifier(not FileAccess.file_exists(FICHIER), "rien n'est sauvegardé tant que le nom est refusé")
	champ.text = "Aiko Tanaka"
	_verifier(ecran.terminer() == "", "un bon nom permet de créer le personnage")
	await _attendre(3)
	var sauvee := FichePersonnage.charger(catalogue)
	_verifier(sauvee.get("nom") == "Aiko Tanaka" and sauvee.get("classe") == "traqueur"
			and sauvee.get("origine") == "tokyo", "la fiche est sauvegardée sur le PC")
	_verifier(is_equal_approx(float(sauvee["visage"]["ecart_yeux"]), 0.8), "les réglages du visage sont sauvegardés")
	_verifier(current_scene != null and current_scene.scene_file_path.ends_with("menu.tscn"), "retour au menu après création")


func _tester_en_jeu(catalogue: Dictionary) -> void:
	print("Le personnage en jeu")
	var reseau = root.get_node("Reseau")
	reseau.mode = reseau.Mode.SEUL
	reseau.fiche = FichePersonnage.charger(catalogue)
	reseau.nom_joueur = reseau.fiche["nom"]
	if current_scene != null:
		current_scene.queue_free()
	var scene: Node = load("res://scenes/monde/colline_de_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _attendre(30)
	var joueur = get_first_node_in_group("joueur_local")
	_verifier(joueur != null, "le personnage apparaît dans le monde")
	if joueur == null:
		return
	_verifier(joueur.get_node("Fiche").donnees.get("classe") == "traqueur", "il porte la fiche créée")
	_verifier(joueur.nom_classe() == "Traqueur", "le HUD affiche la bonne classe")
	_verifier(joueur.get_node("Combat").nom_affiche == "Aiko Tanaka", "le nom choisi est affiché")
	_verifier(is_equal_approx(joueur.cout_esquive, 35.0 * 0.9), "le bonus de Tokyo réduit le coût de la roulade")


func _finir() -> void:
	FichePersonnage.effacer()
	if _sauvegarde_existante != null:
		var f := FileAccess.open(FICHIER, FileAccess.WRITE)
		f.store_string(_sauvegarde_existante)
		f.close()
	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
