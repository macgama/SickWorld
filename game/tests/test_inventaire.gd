extends SceneTree
## Test automatique de l'inventaire : sacs, équipement, ensembles, tenues de mission,
## butin personnel des loups et sauvegarde.
## Lancement : godot --headless --path game -s res://tests/test_inventaire.gd

const NOM := "Testeur Inventaire"
const FICHIER := "user://sauvegardes/inventaires/testeur_inventaire.json"

var _echecs := 0


func _verifier(condition: bool, message: String) -> void:
	print("  OK   " if condition else "  ÉCHEC ", message)
	if not condition:
		_echecs += 1


func _attendre(images: int) -> void:
	for i in images:
		await physics_frame


func _secondes(s: float) -> void:
	await create_timer(s).timeout


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var cat: Dictionary = root.get_node("Donnees").objets
	var donnees = root.get_node("Donnees")
	_regles(cat, donnees)
	await _en_jeu(cat)
	print("\n%s" % ("TOUT EST BON" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	quit(1 if _echecs > 0 else 0)


## Les règles seules (sans scène).
func _regles(cat: Dictionary, donnees) -> void:
	print("Règles de l'inventaire")
	var barre: Array = donnees.joueur["barre"]
	var etat := Objets.etat_de_depart(cat, barre)
	_verifier(Objets.capacite(cat, etat) == 16 + 12, "sac de départ 16 places + sac d'expédition 12 places (%d)" % Objets.capacite(cat, etat))
	_verifier(etat["equipement"]["arme_principale"] == "lame_courte_vigie", "la lame de la Vigie est équipée au départ")
	_verifier(Objets.trouver(etat, "capuche_chasseur") >= 0, "la capuche du chasseur est dans les sacs")
	_verifier(not (etat["tenues"][0] as Dictionary).is_empty(), "une tenue « Agent de la Vigie » est déjà enregistrée")

	# Piles
	_verifier(Objets.ajouter(cat, etat, "croc_loup", 25) == 0, "25 crocs rangés")
	var piles := (etat["cases"] as Array).filter(func(c): return c.get("id", "") == "croc_loup")
	_verifier(piles.size() == 2 and int(piles[0]["n"]) == 20, "les crocs s'empilent par 20 (2 piles)")

	# Équiper la capuche + la cape → ensemble 2 pièces
	Objets.utiliser(cat, etat, Objets.trouver(etat, "capuche_chasseur"))
	Objets.utiliser(cat, etat, Objets.trouver(etat, "cape_chasseur"))
	_verifier(etat["equipement"]["tete"] == "capuche_chasseur", "capuche équipée")
	_verifier(Objets.trouver(etat, "veste_terrain_vigie") >= 0, "l'ancienne veste revient dans les sacs")
	var b := Objets.bonus(cat, etat["equipement"])
	_verifier(int(b["ensembles"]["chasseur_du_clan"]) == 2, "2 pièces du Chasseur du clan")
	_verifier(float(b["stats"]["degats_pourcent"]) >= 8.0 + 6.0, "bonus 2 pièces : +8 %% dégâts (total %s %%)" % b["stats"]["degats_pourcent"])

	# 4 pièces → la compétence d'époque change
	for id in ["brassards_chasseur", "jambieres_chasseur"]:
		Objets.ajouter(cat, etat, id, 1)
		Objets.utiliser(cat, etat, Objets.trouver(etat, id))
	b = Objets.bonus(cat, etat["equipement"])
	var lancer := Objets.competence_modifiee(donnees.competence("lancer_au_propulseur"), b["competences"].get("lancer_au_propulseur", {}))
	_verifier(float(lancer["portee"]) == 38.0, "4 pièces : Lancer au propulseur à 38 m (%s)" % lancer["portee"])
	_verifier(float(lancer["ralenti"]["duree"]) == 9.0, "4 pièces : ralentit 9 s (%s)" % lancer["ralenti"]["duree"])
	_verifier(float(donnees.competence("lancer_au_propulseur")["portee"]) == 30.0, "la compétence d'origine n'est pas modifiée")

	# Relique
	Objets.ajouter(cat, etat, "propulseur_sculpte", 1)
	Objets.utiliser(cat, etat, Objets.trouver(etat, "propulseur_sculpte"))
	b = Objets.bonus(cat, etat["equipement"])
	lancer = Objets.competence_modifiee(donnees.competence("lancer_au_propulseur"), b["competences"]["lancer_au_propulseur"])
	_verifier(float(lancer["recharge"]) == 6.0, "relique : recharge 10 → 6 s (%s)" % lancer["recharge"])

	# Barre et tenues
	_verifier(Objets.changer_competence(cat, etat, 5, "peinture_de_guerre") == "", "touche 6 → Peinture de guerre")
	_verifier(Objets.changer_competence(cat, etat, 6, "peinture_de_guerre") == "" and etat["barre"][5] != "peinture_de_guerre",
			"pas deux fois la même compétence : elles s'échangent")
	_verifier(Objets.changer_competence(cat, etat, 0, "cri_du_clan") != "", "les touches 1 à 5 restent celles de la classe")
	Objets.enregistrer_tenue(cat, etat, 1, "Chasseur")
	var tenue_chasseur: Dictionary = (etat["tenues"][1] as Dictionary).duplicate(true)
	Objets.mettre_tenue(cat, etat, 0)
	_verifier(etat["equipement"]["tete"] == "" and etat["equipement"]["torse"] == "veste_terrain_vigie",
			"tenue 1 : retour à la tenue de la Vigie")
	_verifier(etat["barre"] == barre, "tenue 1 : la barre d'origine revient")
	var manquants := Objets.mettre_tenue(cat, etat, 1)
	_verifier(manquants.is_empty() and etat["equipement"] == tenue_chasseur["equipement"], "tenue 2 : le Chasseur est remis en entier")
	_verifier(String(etat["barre"][6]) == "peinture_de_guerre", "tenue 2 : Peinture de guerre revient en touche 7")

	# Sacs
	var avant := Objets.capacite(cat, etat)
	Objets.ajouter(cat, etat, "besace_peau_loup", 1)
	Objets.utiliser(cat, etat, Objets.trouver(etat, "besace_peau_loup"))
	_verifier(Objets.capacite(cat, etat) == avant + 8 and (etat["cases"] as Array).size() == avant + 8, "la besace ajoute 8 places")
	_verifier(Objets.decrocher_sac(cat, etat, 1) == "" and Objets.capacite(cat, etat) == avant, "on peut la décrocher")
	_verifier(Objets.trouver(etat, "besace_peau_loup") >= 0, "elle revient dans les sacs")
	var plein := Objets.etat_de_depart(cat, barre)
	while Objets.places_libres(plein) > 0:
		Objets.ajouter(cat, plein, "silex", 20)
	_verifier(Objets.ajouter(cat, plein, "peau_loup", 1) == 1, "sacs pleins : l'objet ne rentre pas")
	_verifier(Objets.retirer(cat, plein, "torse") != "", "sacs pleins : impossible de retirer la veste")

	# Sauvegarde : on n'accepte pas n'importe quoi
	var triche := etat.duplicate(true)
	triche["cases"][0] = {"id": "epee_magique_inexistante", "n": 1}
	triche["cases"][1] = {"id": "croc_loup", "n": 9999}
	triche["equipement"]["tete"] = "lance_silex"
	var propre := Objets.valider(cat, triche, barre, donnees.competences)
	_verifier((propre["cases"][0] as Dictionary).is_empty(), "sauvegarde : objet inconnu retiré")
	_verifier(int(propre["cases"][1]["n"]) == 20, "sauvegarde : pile limitée à 20")
	_verifier(propre["equipement"]["tete"] == "", "sauvegarde : une lance ne se porte pas sur la tête")

	# Butin
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 42
	var total := 0
	var pieces := 0
	for i in 200:
		var butin := Objets.tirer_butin(cat, "loup", hasard)
		total += butin.size()
		for o in butin:
			if String(Objets.objet(cat, o["id"]).get("type", "")) == "equipement":
				pieces += 1
	_verifier(total > 150 and pieces > 30, "200 loups : %d objets dont %d pièces d'équipement" % [total, pieces])


## Dans le jeu : serveur, loups, butin personnel, changement de tenue.
func _en_jeu(cat: Dictionary) -> void:
	print("\nInventaire en jeu")
	DirAccess.remove_absolute(Profil.chemin(FICHIER))
	root.get_node("Reseau").nom_joueur = NOM
	var scene: Node = load("res://scenes/monde/colline_de_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _attendre(30)
	var joueur = get_first_node_in_group("joueur_local")
	var inv = joueur.get_node("Inventaire")
	var moi = joueur.get_node("Combat")
	var cj = joueur.get_node("CombatJoueur")
	_verifier(not inv.etat.is_empty(), "le joueur a un inventaire")
	_verifier(moi.pv_max == 220 + 40, "PV : 220 + 40 de l'équipement de départ (%d)" % moi.pv_max)
	_verifier(moi.bonus_degats == 8.0, "dégâts : +8 %% (lame + dague) (%s)" % moi.bonus_degats)
	_verifier(FileAccess.file_exists(Profil.chemin(FICHIER)), "l'inventaire est enregistré")
	var porte_visible: Dictionary = inv.porte
	_verifier(porte_visible.get("arme_principale", "") == "lame_courte_vigie", "l'arme portée est partagée (visible par les autres)")

	# Équiper par la demande normale (comme un clic)
	inv.utiliser(Objets.trouver(inv.etat, "capuche_chasseur"))
	inv.utiliser(Objets.trouver(inv.etat, "cape_chasseur"))
	await _attendre(2)
	_verifier(inv.porte.get("tete", "") == "capuche_chasseur", "la capuche est portée")
	_verifier(moi.bonus_degats == 22.0, "le bonus de l'ensemble s'applique au combat (%s %%)" % moi.bonus_degats)
	inv.changer_competence(5, "peinture_de_guerre")
	await _attendre(2)
	_verifier(cj.barre[5] == "peinture_de_guerre", "la barre du combat suit (touche 6 = Peinture de guerre)")
	inv.enregistrer_tenue(1, "Chasseur")
	await _attendre(2)

	# Changer de tenue : 2 secondes sans bouger
	inv.mettre_tenue(0)
	await _attendre(2)
	_verifier(inv.porte.get("tete", "") == "capuche_chasseur", "pendant le changement, rien n'a encore changé")
	await _secondes(2.3)
	_verifier(inv.porte.get("tete", "") == "" and cj.barre[5] == "feu_des_ancetres", "après 2 s : tenue de la Vigie remise, Feu des ancêtres revient")
	_verifier(inv.tenue_portee() == 0, "la tenue portée est reconnue")

	# Peinture de guerre : réduit les dégâts
	inv.mettre_tenue(1)
	await _secondes(2.3)
	_verifier(inv.tenue_portee() == 1, "retour à la tenue Chasseur")
	cj.utiliser(5)
	await _attendre(3)
	_verifier(moi.a_effet("peinture_de_guerre"), "Peinture de guerre lancée")

	# Butin personnel : on tue un loup
	var butin = scene.get_node("Partie/Butin")
	var loup = scene.get_node("Partie/Loups/CampNord_Loup1")
	var tirages := 0
	var lc = loup.get_node("Combat")
	lc.subir(5.0, moi)
	await _attendre(2)
	# On force un butin certain pour le test.
	var table_origine: Array = cat["butin"]["loup"]
	cat["butin"]["loup"] = [{"objet": "lance_silex", "chance": 1.0}, {"objet": "croc_loup", "chance": 1.0, "quantite": [3, 3]}]
	lc.subir(10000.0, moi)
	cat["butin"]["loup"] = table_origine
	await _attendre(2)
	var sacs: Array = butin.sacs_de(1)
	_verifier(sacs.size() == 1, "le loup laisse un sac de butin pour nous")
	_verifier(butin.sac_a_portee() < 0, "trop loin pour le ramasser")
	joueur.placer(loup.global_position + Vector3(1.5, 0.5, 0), 0.0)
	await _attendre(5)
	_verifier(butin.sac_a_portee() == sacs[0], "à côté du loup, le sac est à portée")
	butin.ramasser_le_plus_proche()
	await _attendre(3)
	_verifier(butin.sacs_de(1).is_empty(), "le sac a été ramassé")
	_verifier(Objets.trouver(inv.etat, "lance_silex") >= 0, "la lance est dans les sacs")

	# Pas de changement d'équipement en combat
	moi.noter_combat()
	var avant: Dictionary = inv.etat["equipement"].duplicate()
	inv.utiliser(Objets.trouver(inv.etat, "lance_silex"))
	await _attendre(2)
	_verifier(inv.etat["equipement"] == avant, "impossible de changer d'arme en combat")
	moi.dernier_moment_de_combat = -1000.0
	inv.utiliser(Objets.trouver(inv.etat, "lance_silex"))
	await _attendre(2)
	_verifier(inv.porte.get("arme_principale", "") == "lance_silex", "hors combat : la lance est équipée")

	# Rechargement de la sauvegarde
	var relu = JSON.parse_string(FileAccess.get_file_as_string(Profil.chemin(FICHIER)))
	_verifier(relu is Dictionary and relu["equipement"]["arme_principale"] == "lance_silex", "la sauvegarde contient la lance équipée")
	DirAccess.remove_absolute(Profil.chemin(FICHIER))
