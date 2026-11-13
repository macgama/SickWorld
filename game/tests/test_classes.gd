extends SceneTree
## Test automatique des 4 classes : chaque classe a ses 5 compétences, sa ressource,
## et chaque compétence fait ce qu'elle annonce. On termine par un petit
## « banc d'essai » d'équilibrage : chaque classe affronte seule deux loups.
## Lancement : godot --headless --path game -s res://tests/test_classes.gd

var _echecs := 0
var _bilan: Array[String] = []


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


func _distance(a: Node3D, b: Node3D) -> float:
	return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()


## Charge la colline de test avec un personnage de la classe demandée.
func _partie(classe: String) -> Node:
	if current_scene != null:
		current_scene.queue_free()
		await _attendre(5)
	var reseau = root.get_node("Reseau")
	reseau.mode = reseau.Mode.SEUL
	var fiche := FichePersonnage.par_defaut(root.get_node("Donnees").creation)
	fiche["classe"] = classe
	reseau.fiche = fiche
	reseau.nom_joueur = "Essai %s" % classe.capitalize()
	var scene: Node = load("res://scenes/monde/colline_de_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _attendre(30)
	var joueur = get_first_node_in_group("joueur_local")
	joueur.get_node("Inventaire").sauvegarde_active = false
	return scene


## Utilise la compétence « index » ; si elle n'est pas prête, attend un peu et réessaie.
func _utiliser(cj, index: int, essais := 30) -> bool:
	for i in essais:
		if cj.raison_impossible(index) == "":
			return cj.utiliser(index)
		await _secondes(0.1)
	print("    (impossible : %s)" % cj.raison_impossible(index))
	return false


func _lancer() -> void:
	var donnees = root.get_node("Donnees")
	print("Les données des classes")
	for id in ["lame", "rempart", "traqueur", "tisseur"]:
		var c: Dictionary = donnees.classes.get(id, {})
		var competences: Array = c.get("competences", [])
		var toutes_existent := competences.size() == 5
		for comp in competences:
			toutes_existent = toutes_existent and donnees.competences.has(comp)
		_verifier(toutes_existent, "%s : 5 compétences décrites dans competences.json" % id)
	for classe in donnees.creation.get("classes", []):
		_verifier(classe.get("jouable", false), "%s est jouable à la création" % classe["nom"])

	await _tester_rempart()
	await _tester_traqueur()
	await _tester_tisseur()
	for id in ["lame", "rempart", "traqueur", "tisseur"]:
		await _banc_d_essai(id)

	print("\nBilan d'équilibrage (seul contre 2 loups des steppes) :")
	for ligne in _bilan:
		print("  " + ligne)
	print("\n%s (%d échec(s))" % ["RÉUSSI" if _echecs == 0 else "RATÉ", _echecs])
	quit(1 if _echecs > 0 else 0)


func _commun(joueur, cj, classe: String, ressource: String, pv: float) -> void:
	var moi = joueur.get_node("Combat")
	var attendu: Array = root.get_node("Donnees").classes[classe]["competences"]
	_verifier(cj.barre.slice(0, 5) == attendu, "les touches 1 à 5 sont les compétences du %s" % classe.capitalize())
	_verifier(cj.barre[5] != "" and cj.barre[7] != "", "les touches 6 à 8 gardent les compétences d'époque")
	_verifier(cj.nom_ressource() == ressource, "la ressource s'appelle %s" % ressource)
	_verifier(is_equal_approx(cj.pv_de_base(), pv) and moi.pv_max >= pv,
			"vie de base : %d (avec l'équipement : %d)" % [pv, moi.pv_max])


# --- Rempart -------------------------------------------------------------------

func _tester_rempart() -> void:
	print("\nLe Rempart")
	var scene := await _partie("rempart")
	var joueur = get_first_node_in_group("joueur_local")
	var cj = joueur.get_node("CombatJoueur")
	var moi = joueur.get_node("Combat")
	_commun(joueur, cj, "rempart", "Ténacité", 300)
	_verifier(cj.elan == 0.0, "la Ténacité commence vide")

	var loup = scene.get_node("Partie/Loups/CampNord_Loup1")
	joueur.placer(loup.global_position + Vector3(0, 0.5, 16), 0.0)
	await _attendre(5)
	cj.changer_cible(loup.combat)
	_verifier(await _utiliser(cj, 1), "Provocation à 16 m")
	await _attendre(3)
	_verifier(loup.combat.a_effet("provocation"), "le loup est provoqué")
	_verifier(loup.etat == loup.Etat.POURSUIVRE and loup._cible == moi, "le loup fonce sur le Rempart")
	await _secondes(3.0)
	_verifier(cj.elan > 0.0, "les morsures remplissent la Ténacité (%.0f)" % cj.elan)

	_verifier(await _utiliser(cj, 2), "Mur de bouclier")
	_verifier(moi.a_effet("mur_de_bouclier"), "le bouclier est levé")
	var pv_avant: float = moi.pv
	_r().infliger(loup.combat, moi, 50.0, "periodique")
	_verifier(pv_avant - moi.pv <= 21.0, "le Mur de bouclier réduit un coup de 50 à %d" % (pv_avant - moi.pv))

	# Coup de bouclier jusqu'à avoir de quoi lancer l'Onde de choc.
	var limite := 80
	while cj.elan < 30.0 and limite > 0:
		limite -= 1
		if cj.raison_impossible(0) == "":
			cj.utiliser(0)
		await _secondes(0.1)
	_verifier(await _utiliser(cj, 4), "Onde de choc")
	await _attendre(2)
	_verifier(loup.combat.a_effet("etourdi"), "le loup est étourdi")
	var p: Vector3 = loup.global_position
	await _secondes(1.0)
	_verifier(loup.global_position.distance_to(p) < 0.2, "étourdi, le loup ne bouge plus")
	var voisin = scene.get_node("Partie/Loups/CampNord_Loup2")
	var menace_moi: float = voisin.combat.menace.get(moi, 0.0)
	_verifier(menace_moi > 0.0, "le Rempart génère de la menace sur les loups autour (%.0f)" % menace_moi)

	# Charge protectrice sur un loup de la meute (allié).
	await _secondes(1.0)
	_verifier(await _utiliser(cj, 7), "Appel de la meute (pour avoir des alliés)")
	await _attendre(5)
	var allies: Array = get_nodes_in_group("loups").filter(func(l): return l.faction == "joueur")
	await _secondes(1.2)
	var hostile = loup if loup.combat.est_vivant() else voisin
	cj.changer_cible(hostile.combat)
	_verifier(cj.raison_impossible(3) == "Cible un allié", "Charge protectrice refusée sur un ennemi")
	var allie = allies[0]
	allie.global_position = joueur.global_position + Vector3(8, 0, 0)
	await _attendre(2)
	cj.changer_cible(allie.combat)
	_verifier(await _utiliser(cj, 3), "Charge protectrice sur un allié")
	await _attendre(2)
	_verifier(allie.combat.a_effet("protection"), "l'allié est protégé")
	var pv_allie: float = allie.combat.pv
	pv_avant = moi.pv
	_r().infliger(loup.combat, allie.combat, 30.0, "periodique")
	_verifier(allie.combat.pv == pv_allie and moi.pv < pv_avant, "le Rempart encaisse le coup à la place de l'allié")


# --- Traqueur ------------------------------------------------------------------

func _tester_traqueur() -> void:
	print("\nLe Traqueur")
	var scene := await _partie("traqueur")
	var joueur = get_first_node_in_group("joueur_local")
	var cj = joueur.get_node("CombatJoueur")
	_commun(joueur, cj, "traqueur", "Concentration", 190)
	_verifier(cj.elan == cj.elan_max, "la Concentration commence pleine")

	var loup = scene.get_node("Partie/Loups/CampOuest_Loup1")
	joueur.placer(loup.global_position + Vector3(0, 0.5, 24), 0.0)
	await _attendre(5)
	_verifier(await _utiliser(cj, 3), "Piège à collet posé à ses pieds")
	await _attendre(2)
	_verifier(get_nodes_in_group("pieges").size() == 1, "le piège est au sol")
	cj.changer_cible(loup.combat)
	_verifier(await _utiliser(cj, 0), "Tir rapide à 24 m")
	await _secondes(0.8)
	_verifier(loup.combat.pv < loup.combat.pv_max, "la flèche touche le loup")
	_verifier(cj.elan < cj.elan_max, "le tir consomme de la Concentration")
	var immobilise := false
	for i in 100:
		await _secondes(0.1)
		if get_nodes_in_group("loups").any(func(l): return l.combat.a_effet("immobilise")):
			immobilise = true
			break
	_verifier(immobilise, "un loup marche dans le piège et reste immobilisé")
	_verifier(get_nodes_in_group("pieges").is_empty() or not get_nodes_in_group("pieges")[0].lanceur,
			"le piège s'est refermé")
	await _utiliser(cj, 1)
	await _secondes(0.6)
	_verifier(loup.combat.a_effet("poison"), "Flèche empoisonnée : le loup est empoisonné")

	# Repli : quand le loup arrive au contact, on saute en arrière.
	for i in 60:
		if _distance(joueur, loup) < 3.0:
			break
		await _secondes(0.1)
	var depart: Vector3 = joueur.global_position
	_verifier(await _utiliser(cj, 4), "Repli")
	await _secondes(0.6)
	_verifier(joueur.global_position.distance_to(depart) > 6.0,
			"le Traqueur a sauté en arrière (%.1f m)" % joueur.global_position.distance_to(depart))
	_verifier(loup.combat.a_effet("ralenti"), "le loup est ralenti par le Repli")

	# Tir visé : 1,5 s de préparation.
	var pv_loup: float = loup.combat.pv
	var voisin = scene.get_node("Partie/Loups/CampOuest_Loup2")
	if not loup.combat.est_vivant():
		cj.changer_cible(voisin.combat)
	else:
		cj.changer_cible(loup.combat)
	var visee = cj.cible
	pv_loup = visee.pv
	_verifier(await _utiliser(cj, 2), "Tir visé démarre")
	await _secondes(2.3)
	_verifier(visee.pv < pv_loup or not visee.est_vivant(), "le Tir visé touche après la préparation")


# --- Tisseur -------------------------------------------------------------------

func _tester_tisseur() -> void:
	print("\nLe Tisseur")
	var scene := await _partie("tisseur")
	var joueur = get_first_node_in_group("joueur_local")
	var cj = joueur.get_node("CombatJoueur")
	var moi = joueur.get_node("Combat")
	_commun(joueur, cj, "tisseur", "Flux", 190)

	var loup = scene.get_node("Partie/Loups/CampNord_Loup1")
	joueur.placer(loup.global_position + Vector3(0, 0.5, 20), 0.0)
	await _attendre(5)
	cj.changer_cible(loup.combat)
	_verifier(await _utiliser(cj, 1), "Éclat temporel à 20 m")
	await _secondes(0.9)
	_verifier(loup.combat.pv < loup.combat.pv_max, "l'éclat touche le loup")
	_verifier(await _utiliser(cj, 3), "Bulle lente autour du loup")
	await _secondes(0.5)
	_verifier(loup.combat.a_effet("bulle_lente"), "le loup est pris dans la bulle")
	_verifier(loup.combat.multiplicateur_vitesse() < 0.5 and loup.combat.multiplicateur_cadence() > 1.5,
			"il court et attaque plus lentement")

	# On se laisse mordre, puis on se soigne.
	for i in 80:
		if moi.pv < moi.pv_max - 50:
			break
		await _secondes(0.1)
	cj.changer_cible(null)
	var pv_avant: float = moi.pv
	_verifier(await _utiliser(cj, 0), "Fil de vie (sans allié en cible : sur soi)")
	# Pendant la préparation, on éloigne le loup pour ne pas fausser le calcul.
	loup.combat.ajouter_controle("etourdi", 3.0)
	await _secondes(1.8)
	_verifier(moi.pv > pv_avant + 20, "Fil de vie soigne (%d -> %d)" % [pv_avant, moi.pv])

	# Le loup s'en va : on garde une vie stable pendant 5 secondes.
	loup.combat.subir(9999.0, null)
	await _secondes(5.5)
	var pv_haut: float = moi.pv
	_r().infliger(null, moi, 60.0, "periodique")
	await _secondes(0.6)
	_verifier(await _utiliser(cj, 2), "Retour en arrière")
	await _attendre(2)
	_verifier(moi.pv >= pv_haut - 25, "la vie revient à celle d'avant le coup (%d, avant : %d)" % [moi.pv, pv_haut])

	_verifier(await _utiliser(cj, 4), "Accélération")
	await _attendre(2)
	_verifier(moi.a_effet("acceleration") and moi.multiplicateur_vitesse() > 1.2, "le Tisseur court plus vite")


# --- Banc d'essai --------------------------------------------------------------

const ROTATIONS := {
	"lame": [4, 2, 1, 0],
	"rempart": [4, 0],
	"traqueur": [2, 1, 0],
	"tisseur": [1],
}


func _banc_d_essai(classe: String) -> void:
	print("\nBanc d'essai : %s contre 2 loups" % classe.capitalize())
	var scene := await _partie(classe)
	var joueur = get_first_node_in_group("joueur_local")
	var cj = joueur.get_node("CombatJoueur")
	var moi = joueur.get_node("Combat")
	var loup = scene.get_node("Partie/Loups/CampEst_Loup1")
	var voisin = scene.get_node("Partie/Loups/CampEst_Loup2")
	var distance_depart := 3.0 if classe in ["lame", "rempart"] else 22.0
	joueur.placer(loup.global_position + Vector3(0, 0.5, distance_depart), 0.0)
	await _attendre(5)
	cj.changer_cible(loup.combat, true)
	var debut: float = _r().maintenant()
	var soins := 0
	var limite := 900
	while (loup.combat.est_vivant() or voisin.combat.est_vivant()) and limite > 0 and moi.est_vivant():
		limite -= 1
		if cj.cible == null or not cj.cible.est_vivant():
			cj.changer_cible(loup.combat if loup.combat.est_vivant() else voisin.combat, true)
		# Le Tisseur se soigne sous 50 % de vie.
		if classe == "tisseur" and moi.pourcentage_pv() < 50.0 and cj.raison_impossible(2) == "":
			cj.utiliser(2)
			soins += 1
		elif classe == "tisseur" and moi.pourcentage_pv() < 50.0 and cj.raison_impossible(0) == "":
			var cible_avant = cj.cible
			cj.changer_cible(null)
			cj.utiliser(0)
			soins += 1
			await _secondes(1.7)
			cj.changer_cible(cible_avant, true)
		else:
			for i in ROTATIONS[classe]:
				if cj.raison_impossible(i) == "":
					cj.utiliser(i)
					break
		await _secondes(0.1)
	var duree: float = _r().maintenant() - debut
	var gagne: bool = not loup.combat.est_vivant() and not voisin.combat.est_vivant()
	_verifier(gagne, "%s vient à bout de 2 loups seul" % classe.capitalize())
	_bilan.append("%-9s %5.1f s   vie restante %3d / %3d (%3d %%)%s" % [classe.capitalize(), duree, moi.pv, moi.pv_max,
			moi.pourcentage_pv(), "   soins lancés : %d" % soins if soins > 0 else ""])


func _r() -> Node:
	return root.get_node("Regles")
