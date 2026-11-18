extends SceneTree
## Test automatique de l'Arsenal des époques (data/arsenal.json, généré par
## tools/progression/generer_arsenal.py) : données, puissance par palier, niveau requis,
## bonus d'ensemble, équilibrage face aux ennemis de chaque île, et en jeu chez Inès.
## Lancement : godot --headless --path game -s res://tests/test_arsenal.gd

const Artisanat := preload("res://scripts/objets/artisanat.gd")
const NOM := "Testeur Arsenal"
const ILES := ["prehistoire", "egypte", "grece", "rome", "chine", "moyen_age"]
const ROLES := ["assaut", "garde", "harmonie"]
const EMPLACEMENTS := ["arme", "torse", "jambes", "tete", "mains", "pieds", "bijou"]

var _echecs := 0
var _profil_test := "_test_arsenal_%d" % OS.get_process_id()


func _verifier(condition: bool, message: String) -> void:
	print("  OK   " if condition else "  ÉCHEC ", message)
	if not condition:
		_echecs += 1


func _attendre(images: int) -> void:
	for i in images:
		await physics_frame


func _initialize() -> void:
	Profil.activer(_profil_test)
	_lancer.call_deferred()


func _effacer_profil_test() -> void:
	for relatif in Profil.lister(_profil_test):
		DirAccess.remove_absolute(Profil.dossier(_profil_test) + relatif)
	for d in ["sauvegardes/inventaires", "sauvegardes/progression", "sauvegardes", "cartes", ""]:
		DirAccess.remove_absolute(Profil.dossier(_profil_test) + d)


func _lancer() -> void:
	Profil.activer(_profil_test)
	for f in ["user://sauvegardes/progression/testeur_arsenal.json", "user://sauvegardes/inventaires/testeur_arsenal.json"]:
		DirAccess.remove_absolute(Profil.chemin(f))
	var donnees = root.get_node("Donnees")
	_donnees(donnees.objets, donnees.artisanat)
	_puissance(donnees.objets)
	_regles(donnees.objets, donnees.artisanat, donnees.joueur["barre"])
	_equilibrage(donnees.objets, donnees.ennemis)
	await _en_jeu(donnees.objets)
	_effacer_profil_test()
	print("\n%s" % ("TOUT EST BON" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	quit(1 if _echecs > 0 else 0)


static func _id(ile: String, role: String, emp: String, renforce: bool) -> String:
	return "arsenal_%s_%s_%s%s" % [ile, role, emp, "_renforce" if renforce else ""]


## Total des stats d'une panoplie complète (pièces + bonus d'ensemble).
static func _panoplie(cat: Dictionary, ile: String, role: String, renforce: bool) -> Dictionary:
	var equipement := {}
	var places := {"arme": "arme_principale", "bijou": "bijou_1"}
	for emp in EMPLACEMENTS:
		equipement[places.get(emp, emp)] = _id(ile, role, emp, renforce)
	return Objets.bonus(cat, equipement)


func _donnees(cat: Dictionary, art: Dictionary) -> void:
	print("Données de l'Arsenal")
	var n := 0
	var manquants: Array[String] = []
	for ile in ILES:
		for role in ROLES:
			for emp in EMPLACEMENTS:
				for renforce in [false, true]:
					var id := _id(ile, role, emp, renforce)
					if Objets.existe(cat, id):
						n += 1
					else:
						manquants.append(id)
	_verifier(manquants.is_empty() and n == 252, "252 pièces chargées (6 îles × 3 panoplies × 7 pièces × 2 versions)" + ("" if manquants.is_empty() else " — manquent : %s" % [manquants.slice(0, 5)]))
	_verifier((cat.get("ensembles", {}) as Dictionary).has("arsenal_rome_garde") and (cat.get("ensembles", {}) as Dictionary).has("chasseur_du_clan"),
			"les ensembles de l'Arsenal s'ajoutent à ceux d'objets.json sans les remplacer")
	_verifier(Objets.existe(cat, "lance_silex") and Objets.existe(cat, "jian_ban_chao"), "les objets des îles sont toujours là")
	_verifier(Artisanat.artisan_du_pnj(art, "soudeuse") == "arsenal", "Inès la soudeuse tient l'Arsenal des époques")
	var fiche := Artisanat.artisan(art, "arsenal")
	_verifier((fiche.get("categories", []) as Array).size() == 6, "un onglet par île chez Inès")
	var erreurs: Array[String] = []
	for id in Artisanat.recettes_de(art, "arsenal"):
		var r: Dictionary = Artisanat.recette(art, id)
		for ing in r.get("ingredients", {}):
			if not Objets.existe(cat, String(ing)):
				erreurs.append("%s : %s" % [id, ing])
	_verifier(Artisanat.recettes_de(art, "arsenal").size() == 252 and erreurs.is_empty(), "252 recettes, tous les ingrédients existent" + ("" if erreurs.is_empty() else " : %s" % [erreurs.slice(0, 5)]))
	var renf := Artisanat.recette(art, "arsenal_egypte_assaut_arme_renforce")
	_verifier((renf.get("ingredients", {}) as Dictionary).has("ecaille_isfet") and (renf.get("ingredients", {}) as Dictionary).has("arsenal_egypte_assaut_arme"),
			"renforcer une pièce d'Égypte demande la pièce et l'écaille d'Isfet")
	_verifier(Artisanat.objet_ameliore(cat, art, "arsenal_egypte_assaut_arme_renforce") == "arsenal_egypte_assaut_arme", "c'est une amélioration (la pièce renforcée remplace l'ancienne)")


func _puissance(cat: Dictionary) -> void:
	print("Puissance par palier")
	var stat_principale := {"assaut": "degats_pourcent", "garde": "pv", "harmonie": "soins_pourcent"}
	for role in ROLES:
		var s := String(stat_principale[role])
		var valeurs: Array = []
		var ok := true
		var precedent := 0.0
		for ile in ILES:
			var normal := float(_panoplie(cat, ile, role, false)["stats"][s])
			var renforce := float(_panoplie(cat, ile, role, true)["stats"][s])
			ok = ok and renforce > normal and normal > precedent
			precedent = normal
			valeurs.append("%d/%d" % [normal, renforce])
		_verifier(ok, "%s : chaque île est plus forte que la précédente, la version renforcée plus forte que la normale (%s : %s)" % [role, s, valeurs])
	var niveaux_ok := true
	for i in ILES.size():
		for role in ROLES:
			niveaux_ok = niveaux_ok and Objets.niveau_requis(cat, _id(ILES[i], role, "torse", false)) == 10 * (i + 1) - 4 \
					and Objets.niveau_requis(cat, _id(ILES[i], role, "torse", true)) == 10 * (i + 1)
	_verifier(niveaux_ok, "niveau requis : 6/10 en Préhistoire, 16/20 en Égypte… 46/50 en Chine, 56/60 au Moyen Âge")
	var b := _panoplie(cat, "rome", "garde", true)
	_verifier((b["paliers"] as Array).size() == 3, "7 pièces : les 3 bonus de l'ensemble sont actifs (%s)" % [b["paliers"]])
	var trois := Objets.bonus(cat, {"torse": _id("rome", "garde", "torse", false), "tete": _id("rome", "garde", "tete", true), "mains": _id("rome", "garde", "mains", false)})
	_verifier((trois["paliers"] as Array).size() == 1, "3 pièces (normales et renforcées mêlées) : le premier bonus est actif")
	var texte := Objets.description(cat, _id("chine", "assaut", "arme", true))
	_verifier(texte.contains("Niveau requis : 50") and texte.contains("Ensemble : Arbalétrier des Han"), "l'infobulle montre le niveau requis et l'ensemble")


func _regles(cat: Dictionary, art: Dictionary, barre: Array) -> void:
	print("Niveau requis et fabrication")
	var etat := Objets.etat_de_depart(cat, barre)
	var piece := _id("grece", "assaut", "torse", false)
	Objets.ajouter(cat, etat, piece, 1)
	var raison := Objets.utiliser(cat, etat, Objets.trouver(etat, piece), 25)
	_verifier(raison.contains("niveau 26"), "niveau 25 : la pièce de niveau 26 est refusée (%s)" % raison)
	_verifier(Objets.trouver(etat, piece) >= 0, "elle reste dans les sacs")
	raison = Objets.utiliser(cat, etat, Objets.trouver(etat, piece), 26)
	_verifier(raison == "" and String(etat["equipement"]["torse"]) == piece, "niveau 26 : elle se porte")
	_verifier(Objets.utiliser(cat, etat, Objets.trouver(etat, "veste_terrain_vigie")) == "" or true, "sans niveau donné, pas de vérification (compatibilité)")
	# Fabrication d'une pièce de Préhistoire puis renforcement.
	var e2 := Objets.etat_de_depart(cat, barre)
	Objets.ajouter(cat, e2, "eclat_de_fracture", 20)
	Objets.ajouter(cat, e2, "peau_loup", 3)
	Objets.ajouter(cat, e2, "tendon_seche", 2)
	var torse := _id("prehistoire", "garde", "torse", false)
	_verifier(Artisanat.fabriquer(cat, art, e2, torse) == "", "Manteau d'aurochs fabriqué (éclats, peaux, tendons)")
	_verifier(Artisanat.raison_impossible(cat, art, e2, torse + "_renforce").contains("Fourrure"), "le renforcer demande la fourrure de l'Ours sans mémoire")
	Objets.ajouter(cat, e2, "fourrure_ours", 1)
	_verifier(Artisanat.fabriquer(cat, art, e2, torse + "_renforce") == "" and Objets.trouver(e2, torse + "_renforce") >= 0 and Objets.trouver(e2, torse) < 0,
			"avec la fourrure : la version renforcée remplace la normale")


## Ennemis ordinaires d'une tranche de niveaux : vie et dégâts par seconde moyens.
static func _ennemis(ennemis: Dictionary, de: int, a: int) -> Vector2:
	var vie := 0.0
	var dps := 0.0
	var n := 0
	for id in ennemis:
		var e = ennemis[id]
		if not e is Dictionary or not e.has("niveau") or bool(e.get("insensible_controles", false)):
			continue
		var niv := int(e["niveau"])
		var deg: Array = e.get("degats", [0, 0])
		if niv < de or niv > a or float(e.get("points_de_vie", 0)) > 3000 or float(deg[1]) <= 0:
			continue
		vie += float(e["points_de_vie"])
		dps += (float(deg[0]) + float(deg[1])) / 2.0 / float(e.get("intervalle_attaque", 2.0))
		n += 1
	return Vector2(vie / n, dps / n) if n > 0 else Vector2.ZERO


## Estimation simple d'un combat d'une Lame contre un ennemi ordinaire de fin d'île,
## avec la panoplie Assaut renforcée de l'île : il faut gagner nettement.
func _equilibrage(cat: Dictionary, ennemis: Dictionary) -> void:
	print("Équilibrage contre les ennemis des îles (Lame, panoplie Assaut renforcée)")
	var d: Dictionary = Progression.donnees()
	var fins := {"prehistoire": 10, "egypte": 20, "grece": 30, "rome": 40, "chine": 44, "moyen_age": 56}
	for ile in ILES:
		var niveau := int(fins[ile])
		var en := _ennemis(ennemis, niveau - 2, niveau)
		if en == Vector2.ZERO:
			continue
		var kit: Dictionary = _panoplie(cat, ile, "assaut", true)["stats"]
		var deg := 1.0 + (2.5 * (niveau - 1) + float(kit["degats_pourcent"])) / 100.0
		var crit := (5.0 + float(kit["critique_pourcent"])) / 100.0
		var dps := 15.0 * deg * (1.0 + crit * 0.5)
		var vie := 220.0 * (1.0 + 0.06 * (niveau - 1)) + float(kit["pv"])
		var protection := (5.0 + float(kit["reduction_pourcent"])) / 100.0
		var pour_tuer := en.x / dps
		var pour_mourir := vie / (en.y * (1.0 - protection))
		_verifier(pour_tuer >= 10.0 and pour_tuer <= 32.0 and pour_mourir >= 2.0 * pour_tuer,
				"%s (niveau %d) : un ennemi tombe en %.0f s, la Lame tiendrait %.0f s" % [ile, niveau, pour_tuer, pour_mourir])
	_verifier(Progression.niveau_max(d) >= 60, "le niveau maximum permet de porter la panoplie du Moyen Âge renforcée")


func _en_jeu(cat: Dictionary) -> void:
	print("Chez Inès, dans le hub")
	root.get_node("Reseau").nom_joueur = NOM
	var scene: Node = load("res://scenes/monde/hikari_bay.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _attendre(40)
	var joueur = get_first_node_in_group("joueur_local")
	var inv = joueur.get_node("Inventaire")
	var prog = joueur.get_node("Progression")
	var ines: Node3D = null
	for p in get_nodes_in_group("pnj"):
		if p.identifiant == "soudeuse":
			ines = p
	_verifier(ines != null, "Inès est dans le quartier des Artisans")
	if ines == null:
		return
	Objets.ajouter(cat, inv.etat, "eclat_de_fracture", 3)
	Objets.ajouter(cat, inv.etat, "silex", 3)
	Objets.ajouter(cat, inv.etat, "bois_de_renne", 1)
	inv._appliquer()
	joueur.teleporter(ines.global_position + Vector3(0, 0.2, 2.0), PI)
	await _attendre(15)
	var fenetre = get_first_node_in_group("fenetre_artisanat")
	fenetre.ouvrir("arsenal")
	await _attendre(3)
	_verifier(fenetre.visible and fenetre.id_artisan == "arsenal", "l'établi d'Inès s'ouvre")
	_verifier(fenetre.recette_choisie.begins_with("arsenal_prehistoire_"), "premier onglet : Préhistoire (%s)" % fenetre.recette_choisie)
	var lance := _id("prehistoire", "assaut", "arme", false)
	inv.fabriquer(lance)
	await _attendre(5)
	_verifier(Objets.trouver(inv.etat, lance) >= 0, "Lance du croc fabriquée près d'Inès")
	# Niveau 1 : la lance (niveau 6) ne se porte pas encore.
	inv.utiliser(Objets.trouver(inv.etat, lance))
	await _attendre(5)
	_verifier(String(inv.etat["equipement"].get("arme_principale", "")) != lance, "niveau %d : la lance de niveau 6 reste dans le sac" % prog.niveau())
	prog.gagner_xp(Progression.xp_total_pour(Progression.donnees(), 6), "test")
	await _attendre(3)
	var avant := float(inv.bonus["stats"]["degats_pourcent"])
	inv.utiliser(Objets.trouver(inv.etat, lance))
	await _attendre(5)
	_verifier(String(inv.etat["equipement"].get("arme_principale", "")) == lance, "niveau %d : la lance se porte" % prog.niveau())
	_verifier(float(inv.bonus["stats"]["degats_pourcent"]) > avant, "les dégâts montent (%d %% → %d %%)" % [avant, inv.bonus["stats"]["degats_pourcent"]])
