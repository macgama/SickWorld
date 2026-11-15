extends SceneTree
## Test automatique des métiers de récolte (cueillette, minage, pêche) et des plats
## du Chef Goro : données, règles (niveaux, expérience, repas), puis en jeu sur la
## Côte Gelée : on récolte du lichen, la source disparaît puis repousse, l'action
## s'interrompt si on bouge, la pêche marche depuis la rive, et un plat se mange.
## Lancement : godot --headless --path game -s res://tests/test_recolte.gd

const Metiers := preload("res://scripts/objets/metiers.gd")
const Artisanat := preload("res://scripts/objets/artisanat.gd")
const NOM := "Testeur Recolte"
const FICHIER := "user://sauvegardes/inventaires/testeur_recolte.json"

var _echecs := 0
var _profil_test := "_test_recolte_%d" % OS.get_process_id()


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
	for d in ["sauvegardes/inventaires", "sauvegardes", "cartes", ""]:
		DirAccess.remove_absolute(Profil.dossier(_profil_test) + d)


func _lancer() -> void:
	Profil.activer(_profil_test)
	var donnees = root.get_node("Donnees")
	_donnees(donnees.objets, donnees.artisanat, donnees.recolte)
	_regles(donnees.objets, donnees.artisanat, donnees.recolte, donnees.joueur["barre"])
	await _en_jeu(donnees.objets, donnees.recolte)
	_effacer_profil_test()
	print("\n%s" % ("TOUT EST BON" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	quit(1 if _echecs > 0 else 0)


func _donnees(cat: Dictionary, art: Dictionary, rec: Dictionary) -> void:
	print("Données de la récolte")
	var sources: Dictionary = rec.get("sources", {})
	_verifier(sources.size() >= 20, "%d sources chargées" % sources.size())
	var erreurs: Array[String] = []
	var donnes := {}
	for id in sources:
		var s: Dictionary = sources[id]
		if not String(s.get("metier", "")) in Metiers.METIERS:
			erreurs.append("%s : métier inconnu" % id)
		for ligne in s.get("donne", []):
			if not Objets.existe(cat, String(ligne.get("objet", ""))):
				erreurs.append("%s : objet inconnu %s" % [id, ligne.get("objet")])
			donnes[String(ligne.get("objet", ""))] = true
	_verifier(erreurs.is_empty(), "chaque source a un métier et donne des objets connus" + ("" if erreurs.is_empty() else " : " + ", ".join(erreurs)))
	var non_places: Array[String] = []
	var places := {}
	for zone in rec.get("zones", {}):
		for p in Metiers.points_de_zone(rec, String(zone)):
			places[p["source"]] = true
	for id in sources:
		if not places.has(id):
			non_places.append(String(id))
	_verifier(non_places.is_empty(), "chaque source est posée dans au moins une zone" + ("" if non_places.is_empty() else " : " + ", ".join(non_places)))
	for zone in ["cote_gelee", "steppe", "foret", "falaises", "port_des_marais", "carrieres_toura", "village_batisseurs", "desert_rouge"]:
		_verifier(Metiers.points_de_zone(rec, zone).size() >= 8, "%s : %d points de récolte" % [zone, Metiers.points_de_zone(rec, zone).size()])
	var orphelins: Array[String] = []
	for id in cat["objets"]:
		if cat["objets"][id].has("recolte") and not donnes.has(id):
			orphelins.append(String(id))
	_verifier(orphelins.is_empty(), "chaque objet marqué « recolte » sort d'une source" + ("" if orphelins.is_empty() else " : " + ", ".join(orphelins)))
	var inutiles: Array[String] = []
	for id in donnes:
		if Artisanat.sert_a(cat, art, String(id)).is_empty():
			inutiles.append(String(id))
	_verifier(inutiles.is_empty(), "chaque objet récolté sert à au moins une recette" + ("" if inutiles.is_empty() else " : " + ", ".join(inutiles)))
	_verifier(Artisanat.artisan_du_pnj(art, "chef_goro") == "cuisine", "le Chef Goro tient la cuisine")
	var plats := Artisanat.recettes_de(art, "cuisine", "plats")
	_verifier(plats.size() >= 6, "%d plats au menu du Ramen Kaminari" % plats.size())
	for id in plats:
		var o := Objets.objet(cat, String(Artisanat.recette(art, String(id)).get("donne", "")))
		if String(o.get("type", "")) != "consommable" or (o.get("repas", {}) as Dictionary).get("stats", {}).is_empty():
			erreurs.append(String(id))
	_verifier(erreurs.is_empty(), "chaque plat est un repas avec des bonus")


func _regles(cat: Dictionary, art: Dictionary, rec: Dictionary, barre: Array) -> void:
	print("Règles des métiers")
	var etat := Objets.etat_de_depart(cat, barre)
	_verifier(Metiers.niveau(rec, etat, "cueillette") == 1, "on commence niveau 1")
	_verifier(Metiers.niveau_pour(rec, 39) == 1 and Metiers.niveau_pour(rec, 40) == 2 and Metiers.niveau_pour(rec, 99999) == Metiers.niveau_max(rec),
			"paliers : 40 xp = niveau 2, maximum %d" % Metiers.niveau_max(rec))
	var raison := Metiers.raison_impossible(cat, rec, etat, "achillee")
	_verifier(raison == "Il faut Cueillette niveau 2", "achillée trop difficile au niveau 1 : « %s »" % raison)
	_verifier(Metiers.raison_impossible(cat, rec, etat, "lichen_des_rennes") == "", "le lichen se cueille dès le niveau 1")
	var g := Metiers.gain(rec, etat, "lichen_des_rennes")
	_verifier(g == 15, "lichen : +%d xp" % g)
	var monte := Metiers.gagner(rec, etat, "cueillette", 45)
	_verifier(monte == 2 and Metiers.niveau(rec, etat, "cueillette") == 2, "45 xp : niveau 2 atteint")
	_verifier(Metiers.raison_impossible(cat, rec, etat, "achillee") == "", "au niveau 2, l'achillée se cueille")
	_verifier(Metiers.progression(rec, etat, "cueillette") == [5, 60], "progression : 5 / 60 (%s)" % [Metiers.progression(rec, etat, "cueillette")])
	Metiers.gagner(rec, etat, "minage", 400)
	_verifier(Metiers.gain(rec, etat, "affleurement_silex") == 0, "minage niveau 6 : le silex (niveau 1) ne rapporte plus rien")
	_verifier(Metiers.gain(rec, etat, "rognon_pyrite") == 12, "pyrite (3 niveaux en dessous) : moitié d'expérience")
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 7
	var tire := Metiers.tirer(cat, rec, "lichen_des_rennes", hasard)
	_verifier(tire.size() == 1 and tire[0]["id"] == "lichen_renne" and int(tire[0]["n"]) in [2, 3], "le lichen donne 2 ou 3 lichens (%s)" % [tire])
	# Sacs pleins : refus, sauf s'il reste de la place dans une pile entamée.
	var plein := etat.duplicate(true)
	for i in (plein["cases"] as Array).size():
		if (plein["cases"][i] as Dictionary).is_empty():
			plein["cases"][i] = {"id": "collier_coquillages", "n": 1}
	_verifier(Metiers.raison_impossible(cat, rec, plein, "lichen_des_rennes") == "Tes sacs sont pleins", "sacs pleins : refus")
	plein["cases"][0] = {"id": "lichen_renne", "n": 3}
	_verifier(Metiers.raison_impossible(cat, rec, plein, "lichen_des_rennes") == "", "une pile de lichen entamée : on peut cueillir")
	# La sauvegarde garde l'expérience et le repas.
	var relu := Objets.valider(cat, JSON.parse_string(JSON.stringify(etat)), barre, root.get_node("Donnees").competences)
	_verifier(Metiers.niveau(rec, relu, "minage") == 6 and Metiers.experience(relu, "cueillette") == 45, "l'expérience survit à la sauvegarde")

	print("Plats du Chef Goro")
	Objets.ajouter(cat, etat, "omble_arctique", 2)
	Objets.ajouter(cat, etat, "lichen_renne", 2)
	_verifier(Artisanat.fabriquer(cat, art, etat, "bouillon_omble") == "", "bouillon d'omble cuisiné")
	_verifier(Artisanat.compter(etat, "bouillon_omble") == 2, "la recette donne 2 bols")
	var maintenant := 1000000.0
	_verifier(Metiers.manger(cat, etat, Objets.trouver(etat, "bouillon_omble"), maintenant) == "", "on mange un bol")
	_verifier(Artisanat.compter(etat, "bouillon_omble") == 1, "il reste un bol")
	_verifier(Metiers.repas_actif(cat, etat, maintenant + 60) == "bouillon_omble", "repas actif une minute après")
	_verifier(float(Metiers.stats_repas(cat, etat, maintenant + 60).get("pv", 0)) == 25.0, "le bouillon donne +25 PV")
	_verifier(Metiers.repas_actif(cat, etat, maintenant + 1801) == "", "au bout de 30 minutes, c'est fini")
	_verifier(Metiers.manger(cat, etat, Objets.trouver(etat, "silex"), maintenant) != "", "un silex ne se mange pas")
	relu = Objets.valider(cat, JSON.parse_string(JSON.stringify(etat)), barre, root.get_node("Donnees").competences)
	_verifier(Metiers.repas_actif(cat, relu, maintenant + 60) == "bouillon_omble", "le repas survit à la sauvegarde")


## En jeu sur la Côte Gelée (serveur local).
func _en_jeu(cat: Dictionary, rec: Dictionary) -> void:
	print("Récolte en jeu (Côte Gelée)")
	DirAccess.remove_absolute(Profil.chemin(FICHIER))
	root.get_node("Reseau").nom_joueur = NOM
	var scene: Node = load("res://scenes/monde/prehistoire/cote_gelee.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _attendre(60)
	var joueur = get_first_node_in_group("joueur_local")
	var inv = joueur.get_node("Inventaire")
	inv.sauvegarde_active = false
	var recolte = get_first_node_in_group("recolte")
	_verifier(recolte != null and recolte.zone == "cote_gelee", "le gestionnaire de récolte connaît sa zone")
	var attendus := Metiers.points_de_zone(rec, "cote_gelee").size()
	_verifier(recolte.points.size() == attendus, "%d / %d points posés" % [recolte.points.size(), attendus])
	var i: int = recolte.point_proche(Vector3.ZERO, "lichen_des_rennes")
	_verifier(i >= 0, "un lichen sur la carte")
	if i < 0:
		return
	var point: Node3D = recolte.points[i]
	_verifier(absf(point.global_position.y - scene.hauteur(point.global_position.x, point.global_position.z)) < 0.05, "le lichen est posé au sol")

	# De loin : refusé.
	recolte.demander(i)
	await _attendre(3)
	_verifier(not recolte.en_cours(joueur.id_reseau()), "de loin, on ne récolte pas")

	# Tout près : la barre d'action, puis le lichen dans les sacs.
	joueur.teleporter(point.global_position + Vector3(1.2, 0.3, 0), 0.0)
	await _attendre(20)
	recolte.demander(i)
	await _attendre(2)
	_verifier(recolte.en_cours(joueur.id_reseau()), "près du lichen, la cueillette commence")
	await _attendre(int(Metiers.duree(rec, "lichen_des_rennes") * 60) + 20)
	_verifier(not recolte.en_cours(joueur.id_reseau()), "la cueillette est finie")
	_verifier(Artisanat.compter(inv.etat, "lichen_renne") >= 2, "%d lichens dans les sacs" % Artisanat.compter(inv.etat, "lichen_renne"))
	_verifier(Metiers.experience(inv.etat, "cueillette") == 15, "+15 xp de Cueillette")
	_verifier(not point.disponible() and not point.get_node("Visuel").visible, "le lichen a disparu (pour ce joueur)")
	_verifier(recolte.repousse(joueur.id_reseau(), i) > 0.0, "le serveur sait quand il repousse")
	recolte.demander(i)
	await _attendre(2)
	_verifier(not recolte.en_cours(joueur.id_reseau()), "on ne peut pas le récolter deux fois")
	# On avance l'horloge du serveur : il repousse.
	recolte._epuises[joueur.id_reseau()][i] = root.get_node("Regles").maintenant() - 1.0
	point._repousse = root.get_node("Regles").maintenant() - 1.0
	await _attendre(3)
	_verifier(point.disponible() and point.get_node("Visuel").visible, "le lichen a repoussé")

	# Bouger interrompt l'action.
	recolte.demander(i)
	await _attendre(2)
	# (process_frame part juste avant les _process : la vitesse n'est pas encore remise à zéro.)
	await process_frame
	joueur.velocity = Vector3(6, 0, 0)
	await process_frame
	joueur.velocity = Vector3.ZERO
	await _attendre(2)
	_verifier(not recolte.en_cours(joueur.id_reseau()), "bouger interrompt la cueillette")
	joueur.velocity = Vector3.ZERO

	# Pêche : depuis la rive, à quelques mètres de l'eau.
	var j: int = recolte.point_proche(Vector3.ZERO, "banc_ombles")
	_verifier(j >= 0, "un banc d'ombles sur la côte")
	if j >= 0:
		var banc: Node3D = recolte.points[j]
		var rive := Vector3.INF
		for k in 24:
			var a := k * TAU / 24.0
			for r in [3.0, 4.5, 6.0, 7.5]:
				var p: Vector3 = banc.global_position + Vector3(cos(a), 0, sin(a)) * r
				if scene.hauteur(p.x, p.z) > 0.15:
					rive = Vector3(p.x, scene.hauteur(p.x, p.z) + 0.3, p.z)
					break
			if rive != Vector3.INF:
				break
		_verifier(rive != Vector3.INF, "une rive près du banc")
		if rive == Vector3.INF:
			return
		joueur.teleporter(rive, 0.0)
		await _attendre(30)
		recolte.demander(j)
		await _attendre(2)
		_verifier(recolte.en_cours(joueur.id_reseau()), "on pêche depuis la rive")
		await _attendre(int(Metiers.duree(rec, "banc_ombles") * 60) + 20)
		_verifier(Artisanat.compter(inv.etat, "omble_arctique") >= 1, "%d omble(s) pêché(s)" % Artisanat.compter(inv.etat, "omble_arctique"))
		_verifier(Metiers.experience(inv.etat, "peche") == 15, "+15 xp de Pêche")

	# Un plat se mange en cliquant dessus, et ajoute des points de vie.
	var combat = joueur.get_node("Combat")
	var avant: float = combat.pv_max
	Objets.ajouter(cat, inv.etat, "bouillon_omble", 1)
	inv._appliquer()
	inv.utiliser(Objets.trouver(inv.etat, "bouillon_omble"))
	await _attendre(3)
	_verifier(Artisanat.compter(inv.etat, "bouillon_omble") == 0, "le bol est mangé")
	_verifier(is_equal_approx(combat.pv_max, avant + 25.0), "repas : %d → %d PV max" % [avant, combat.pv_max])
	DirAccess.remove_absolute(Profil.chemin(FICHIER))
