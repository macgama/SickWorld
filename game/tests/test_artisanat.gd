extends SceneTree
## Test automatique de l'artisanat : recettes, fabrication, amélioration (et mise à jour
## des tenues), puis en jeu dans le hub : la forge Hinode fabrique quand on est près
## de Maître Tetsuo, refuse de loin, et la fenêtre s'ouvre après la discussion.
## Lancement : godot --headless --path game -s res://tests/test_artisanat.gd

const Artisanat := preload("res://scripts/objets/artisanat.gd")
const NOM := "Testeur Artisanat"
const FICHIER := "user://sauvegardes/inventaires/testeur_artisanat.json"

var _echecs := 0


func _verifier(condition: bool, message: String) -> void:
	print("  OK   " if condition else "  ÉCHEC ", message)
	if not condition:
		_echecs += 1


func _attendre(images: int) -> void:
	for i in images:
		await physics_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var donnees = root.get_node("Donnees")
	_donnees(donnees.objets, donnees.artisanat)
	_regles(donnees.objets, donnees.artisanat, donnees.joueur["barre"])
	await _en_jeu(donnees.objets, donnees.artisanat)
	print("\n%s" % ("TOUT EST BON" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	quit(1 if _echecs > 0 else 0)


## Les fichiers de données sont cohérents entre eux.
func _donnees(cat: Dictionary, art: Dictionary) -> void:
	print("Données de l'artisanat")
	var recettes: Dictionary = art.get("recettes", {})
	_verifier(recettes.size() >= 20, "%d recettes chargées" % recettes.size())
	var erreurs: Array[String] = []
	for id in recettes:
		var r: Dictionary = recettes[id]
		if not Objets.existe(cat, String(r.get("donne", ""))):
			erreurs.append("%s : objet fabriqué inconnu" % id)
		if Artisanat.artisan(art, String(r.get("artisan", ""))).is_empty():
			erreurs.append("%s : artisan inconnu" % id)
		for ing in r.get("ingredients", {}):
			if not Objets.existe(cat, String(ing)):
				erreurs.append("%s : ingrédient inconnu %s" % [id, ing])
	_verifier(erreurs.is_empty(), "chaque recette donne un objet connu, chez un artisan connu" + ("" if erreurs.is_empty() else " : " + ", ".join(erreurs)))
	var obtenables := {}
	for table in cat.get("butin", {}).values():
		for ligne in table:
			obtenables[String(ligne.get("objet", ""))] = true
	var introuvables: Array[String] = []
	for id in cat["objets"]:
		if String(cat["objets"][id].get("type", "")) == "materiau" and not obtenables.has(id) \
				and not Artisanat.sert_a(cat, art, String(id)).is_empty():
			introuvables.append(String(id))
	_verifier(introuvables.is_empty(), "chaque matériau d'une recette tombe sur un ennemi" + ("" if introuvables.is_empty() else " : " + ", ".join(introuvables)))
	_verifier(Artisanat.artisan_du_pnj(art, "forgeron") == "forge" and Artisanat.artisan_du_pnj(art, "lea") == "atelier"
			and Artisanat.artisan_du_pnj(art, "commandante") == "", "Tetsuo tient la forge, Léa l'atelier, la commandante rien")
	var renforcee := Objets.objet(cat, "cape_chasseur_renforce")
	_verifier(String(renforcee.get("ensemble", "")) == "chasseur_du_clan" and String(renforcee.get("rarete", "")) == "rare",
			"la cape renforcée reste dans l'ensemble du Chasseur et devient rare")


## Les règles seules (sans scène).
func _regles(cat: Dictionary, art: Dictionary, barre: Array) -> void:
	print("Règles de l'artisanat")
	var etat := Objets.etat_de_depart(cat, barre)
	var raison := Artisanat.raison_impossible(cat, art, etat, "couteau_obsidienne")
	_verifier(raison.begins_with("Il te manque"), "sans matériaux : « %s »" % raison)
	Objets.ajouter(cat, etat, "silex", 3)
	Objets.ajouter(cat, etat, "tendon_seche", 2)
	raison = Artisanat.raison_impossible(cat, art, etat, "couteau_obsidienne")
	_verifier(raison.contains("1 × Silex"), "il manque encore 1 silex (%s)" % raison)
	Objets.ajouter(cat, etat, "silex", 3)
	_verifier(Artisanat.fabriquer(cat, art, etat, "couteau_obsidienne") == "", "couteau d'obsidienne fabriqué")
	_verifier(Objets.trouver(etat, "couteau_obsidienne") >= 0, "le couteau est dans les sacs")
	_verifier(Artisanat.compter(etat, "silex") == 2 and Artisanat.compter(etat, "tendon_seche") == 1,
			"4 silex et 1 tendon ont été pris (reste %d silex, %d tendon)" % [Artisanat.compter(etat, "silex"), Artisanat.compter(etat, "tendon_seche")])

	# Les piles sont vidées proprement, même réparties sur plusieurs cases.
	Objets.ajouter(cat, etat, "croc_loup", 25)
	Objets.ajouter(cat, etat, "tendon_seche", 1)
	_verifier(Artisanat.fabriquer(cat, art, etat, "collier_dents_loup") == "", "collier de crocs fabriqué")
	_verifier(Artisanat.compter(etat, "croc_loup") == 17, "8 crocs pris sur 25 (reste %d)" % Artisanat.compter(etat, "croc_loup"))

	# Amélioration : l'objet porté doit d'abord être rangé, et les tenues suivent.
	Objets.utiliser(cat, etat, Objets.trouver(etat, "capuche_chasseur"))
	Objets.enregistrer_tenue(cat, etat, 1, "Chasseur")
	Objets.ajouter(cat, etat, "eclat_de_fracture", 5)
	Objets.ajouter(cat, etat, "peau_loup", 4)
	raison = Artisanat.raison_impossible(cat, art, etat, "capuche_chasseur_renforce")
	_verifier(raison.contains("Tu portes"), "capuche portée : il faut la retirer (%s)" % raison)
	Objets.retirer(cat, etat, "tete")
	_verifier(Artisanat.fabriquer(cat, art, etat, "capuche_chasseur_renforce") == "", "capuche améliorée")
	_verifier(Objets.trouver(etat, "capuche_chasseur") < 0 and Objets.trouver(etat, "capuche_chasseur_renforce") >= 0,
			"l'ancienne capuche est remplacée par la renforcée")
	_verifier(String(etat["tenues"][1]["equipement"]["tete"]) == "capuche_chasseur_renforce",
			"la tenue « Chasseur » prévoit maintenant la capuche renforcée")
	var avant := float(Objets.objet(cat, "capuche_chasseur")["stats"]["degats_pourcent"])
	var apres := float(Objets.objet(cat, "capuche_chasseur_renforce")["stats"]["degats_pourcent"])
	_verifier(apres > avant, "plus de dégâts : %d %% → %d %%" % [avant, apres])

	# Sacs pleins : rien n'est perdu.
	var plein := Objets.etat_de_depart(cat, barre)
	Objets.ajouter(cat, plein, "silex", 4)
	Objets.ajouter(cat, plein, "tendon_seche", 2)
	for i in (plein["cases"] as Array).size():
		if (plein["cases"][i] as Dictionary).is_empty():
			plein["cases"][i] = {"id": "collier_coquillages", "n": 1}
	# 5 silex et 2 tendons : il en restera après, leurs cases ne se libèrent pas.
	Objets.ajouter(cat, plein, "silex", 1)
	var copie := plein.duplicate(true)
	raison = Artisanat.fabriquer(cat, art, plein, "couteau_obsidienne")
	_verifier(raison == "Tes sacs sont pleins" and plein == copie, "sacs pleins : refus, et rien n'a bougé (%s)" % raison)


## En jeu, dans le hub : demande au serveur, distance, fenêtre.
func _en_jeu(cat: Dictionary, art: Dictionary) -> void:
	print("Artisanat dans le hub")
	DirAccess.remove_absolute(Profil.chemin(FICHIER))
	root.get_node("Reseau").nom_joueur = NOM
	var scene: Node = load("res://scenes/monde/hikari_bay.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _attendre(40)
	var joueur = get_first_node_in_group("joueur_local")
	var inv = joueur.get_node("Inventaire")
	var forgeron: Node3D = null
	for p in get_nodes_in_group("pnj"):
		if p.identifiant == "forgeron":
			forgeron = p
	_verifier(forgeron != null, "Maître Tetsuo est à la forge")
	Objets.ajouter(cat, inv.etat, "silex", 4)
	Objets.ajouter(cat, inv.etat, "tendon_seche", 1)
	inv._appliquer()

	# De loin : refusé.
	inv.fabriquer("couteau_obsidienne")
	await _attendre(5)
	_verifier(Objets.trouver(inv.etat, "couteau_obsidienne") < 0, "loin de la forge : rien n'est fabriqué")

	# Près de Tetsuo : la fenêtre s'ouvre après la discussion, et on fabrique.
	joueur.teleporter(forgeron.global_position + Vector3(0, 0.2, 2.0), PI)
	await _attendre(15)
	var fenetre = get_first_node_in_group("fenetre_artisanat")
	_verifier(fenetre != null, "la fenêtre d'artisanat existe")
	get_first_node_in_group("dialogue").termine.emit("forgeron")
	await _attendre(3)
	_verifier(fenetre.visible and fenetre.id_artisan == "forge", "après avoir parlé à Tetsuo, l'établi de la forge s'ouvre")
	_verifier(fenetre.recette_choisie == "couteau_obsidienne", "première recette choisie : %s" % fenetre.recette_choisie)
	_verifier(not fenetre._bouton.disabled, "le bouton « Fabriquer » est actif")
	fenetre.fabriquer()
	await _attendre(5)
	_verifier(Objets.trouver(inv.etat, "couteau_obsidienne") >= 0, "près de la forge : couteau fabriqué")
	_verifier(Artisanat.compter(inv.etat, "silex") == 0, "les silex ont été consommés")
	_verifier(fenetre._bouton.disabled, "plus assez de matériaux : bouton grisé")
	fenetre.choisir_categorie("ameliorations")
	await _attendre(2)
	_verifier(fenetre.recette_choisie == "couteau_obsidienne_renforce", "onglet Améliorations : %s" % fenetre.recette_choisie)

	# On s'éloigne : la fenêtre se ferme.
	joueur.teleporter(forgeron.global_position + Vector3(0, 0.2, 12.0), PI)
	await _attendre(10)
	_verifier(not fenetre.visible, "en s'éloignant, la fenêtre se ferme")
	DirAccess.remove_absolute(Profil.chemin(FICHIER))
