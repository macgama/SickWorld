extends SceneTree
## Test sans réseau des TALENTS D'ARÈNE :
## - règles : 6 talents par classe, 3 au plus, un clic choisit / retire, pas d'une autre
##   classe, gardés dans la sauvegarde ; chaque talent change vraiment quelque chose ;
## - équilibre : aucun talent ne dépasse le budget prévu, et chaque classe a des choix
##   offensifs, défensifs et contre les soins ;
## - mécanismes JcJ : résistance aux contrôles, blessure (soins réduits), vol de vie,
##   soins en plus ;
## - en vrai duel : les talents d'Arène d'Alice comptent pendant le combat (et pas ceux
##   de Bob qui n'en a pas), les talents normaux restent ignorés, et tout revient
##   comme avant à la fin ; impossible d'en changer pendant le combat.
## Lancement : godot --headless --path game -s res://tests/test_talents_arene.gd

var _echecs := 0
var _profil_test := "_test_talents_arene_%d" % OS.get_process_id()
var _jcj
var _social
var _reseau


func _verifier(condition: bool, message: String) -> void:
	print("  OK   " if condition else "  ÉCHEC ", message)
	if not condition:
		_echecs += 1


func _attendre(images: int) -> void:
	for i in images:
		await physics_frame


func _attendre_que(condition: Callable, limite: float) -> bool:
	var fin := Time.get_ticks_msec() + int(limite * 1000.0)
	while Time.get_ticks_msec() < fin:
		if condition.call():
			return true
		await physics_frame
	return condition.call()


func _initialize() -> void:
	Profil.activer(_profil_test)
	_lancer.call_deferred()


func _de_la_part(id: int, methode: String, arguments: Array = []) -> void:
	_jcj.expediteur_force = id
	_jcj.callv(methode, arguments)
	_jcj.expediteur_force = 0


func _phase() -> String:
	return String(_jcj.etat.get("phase", ""))


## Budget d'un talent : sa valeur approximative en « % de puissance ».
## Les compétences comptent à part (on vérifie juste qu'elles changent la compétence).
const BUDGET := {"degats_pourcent": 1.0, "critique_pourcent": 0.9, "reduction_pourcent": 1.2,
		"resistance_controles_pourcent": 0.22, "soins_pourcent": 0.6, "vol_de_vie_pourcent": 1.2,
		"blessure_pourcent": 0.25, "pv": 0.05}


func _regles() -> void:
	var d := Progression.donnees()
	var donnees_jeu = root.get_node("Donnees")
	for classe in ["lame", "rempart", "traqueur", "tisseur"]:
		var liste := Progression.talents_arene(d, classe)
		_verifier(liste.size() == 6, "%s : 6 talents d'Arène" % classe)
		var genres := {}
		for t in liste:
			var id := String(t["id"])
			var valeur := 0.0
			for s in t.get("stats", {}):
				_verifier(s in Progression.STATS, "%s : statistique « %s » connue" % [id, s])
				valeur += float(t["stats"][s]) * float(BUDGET.get(s, 1.0))
				genres[s] = true
			for comp in t.get("competences", {}):
				var base: Dictionary = donnees_jeu.competence(comp)
				_verifier(comp in donnees_jeu.classes[classe]["competences"], "%s : « %s » est bien une compétence du %s" % [id, comp, classe])
				var modifiee := Objets.competence_modifiee(base, t["competences"][comp])
				_verifier(modifiee != base, "%s : change vraiment « %s »" % [id, comp])
				valeur += 7.0
				genres["competence"] = true
			_verifier(valeur >= 5.0 and valeur <= 10.0, "%s : dans le budget (%.1f, entre 5 et 10)" % [id, valeur])
			_verifier(String(t.get("texte", "")) != "" and String(t.get("nom", "")) != "", "%s : nom et texte" % id)
		_verifier(genres.has("resistance_controles_pourcent"), "%s : un choix contre les contrôles" % classe)
		_verifier(classe == "tisseur" and genres.has("soins_pourcent") or genres.has("blessure_pourcent") or genres.has("competence"),
				"%s : des choix variés" % classe)

	var e := Progression.etat_de_depart()
	_verifier(Progression.choisir_talent_arene(d, "lame", e, "arene_gladiateur") == "", "choisir Gladiateur")
	_verifier(Progression.choisir_talent_arene(d, "lame", e, "arene_bastion_vivant") != "", "refus : talent d'une autre classe")
	Progression.choisir_talent_arene(d, "lame", e, "arene_plaie_mortelle")
	Progression.choisir_talent_arene(d, "lame", e, "arene_poursuite")
	_verifier(Progression.choisir_talent_arene(d, "lame", e, "arene_bourreau") != "", "refus : 4e talent (3 au plus)")
	_verifier(Progression.choisir_talent_arene(d, "lame", e, "arene_gladiateur") == "" and not "arene_gladiateur" in e["talents_arene"],
			"re-cliquer retire le talent")
	_verifier(Progression.choisir_talent_arene(d, "lame", e, "arene_bourreau") == "", "la place libérée resservit")
	var b := Progression.bonus_arene(d, "lame", e)
	_verifier(is_equal_approx(float(b["stats"]["blessure_pourcent"]), 30.0) and is_equal_approx(float(b["competences"]["bond"]["recharge"]), -4.0)
			and is_equal_approx(float(b["competences"]["execution"]["pv_cible_max_pourcent"]), 10.0), "bonus : blessure, Bond et Exécution")
	var lu := Progression.valider(d, "lame", JSON.parse_string(JSON.stringify(e)))
	_verifier(lu["talents_arene"] == e["talents_arene"], "les talents d'Arène sont gardés dans la sauvegarde")
	var faux := e.duplicate(true)
	faux["talents_arene"] = ["arene_gladiateur", "arene_gladiateur", "arene_fils_renforces", "arene_soif_de_sang", "arene_bourreau", "arene_poursuite"]
	lu = Progression.valider(d, "lame", faux)
	_verifier(lu["talents_arene"].size() == 3 and not "arene_fils_renforces" in lu["talents_arene"], "sauvegarde trafiquée : doublons, autre classe et 4e talent retirés")
	_verifier(Progression.valider(d, "rempart", e)["talents_arene"].is_empty(), "autre classe : les talents d'Arène tombent")


func _mecanismes(a, b) -> void:
	var regles = root.get_node("Regles")
	# Résistance aux contrôles.
	b.reanimer(100.0)
	b.bonus_resistance_controles = 30.0
	var duree: float = b.ajouter_controle("etourdi", 2.0, a)
	_verifier(is_equal_approx(duree, 1.4), "résistance 30 %% : étourdi 2 s → %.2f s" % duree)
	b.effets.clear()
	b.ajouter_effet("ralenti", 4.0, {"vitesse": 0.5}, a)
	var reste: float = float(b.effets["ralenti"]["fin"]) - regles.maintenant()
	_verifier(absf(reste - 2.8) < 0.05, "résistance 30 %% : ralenti 4 s → %.2f s" % reste)
	b.effets.clear()
	b.ajouter_effet("immobilise", 3.0)
	reste = float(b.effets["immobilise"]["fin"]) - regles.maintenant()
	_verifier(absf(reste - 3.0) < 0.05, "le blocage du compte à rebours (sans source) n'est pas réduit")
	b.effets.clear()
	b.bonus_resistance_controles = 0.0
	# Blessure : les soins reçus sont réduits.
	a.bonus_blessure = 30.0
	b.pv = b.pv_max - 200.0
	regles.infliger(a, b, 10.0, "periodique")
	_verifier(b.effets.has("blessure"), "un coup pose la blessure sur la cible")
	var avant: float = b.pv
	regles.soigner(null, b, 100.0)
	_verifier(is_equal_approx(b.pv - avant, 70.0), "blessure 30 %% : un soin de 100 rend %d" % int(b.pv - avant))
	a.bonus_blessure = 20.0
	regles.infliger(a, b, 10.0, "periodique")
	_verifier(is_equal_approx(float(b.effets["blessure"]["soins_recus"]), 0.7), "une blessure plus faible ne remplace pas la plus forte")
	a.bonus_blessure = 0.0
	b.effets.clear()
	# Soins en plus.
	a.bonus_soins = 12.0
	b.pv = b.pv_max - 200.0
	avant = b.pv
	regles.soigner(a, b, 100.0)
	_verifier(is_equal_approx(b.pv - avant, 112.0), "soins +12 %% : un soin de 100 rend %d" % int(b.pv - avant))
	a.bonus_soins = 0.0
	# Vol de vie (coups directs seulement).
	a.bonus_vol_de_vie = 6.0
	a.pv = a.pv_max - 100.0
	b.pv = b.pv_max
	avant = a.pv
	var subi: float = regles.infliger(a, b, 100.0, "periodique")
	_verifier(is_equal_approx(a.pv, avant), "vol de vie : rien sur les dégâts dans la durée")
	subi = regles.infliger(a, b, 100.0)
	_verifier(absf((a.pv - avant) - roundf(subi * 0.06)) <= 1.0, "vol de vie 6 %% : %d dégâts rendent %d PV" % [int(subi), int(a.pv - avant)])
	a.bonus_vol_de_vie = 0.0
	a.reanimer(100.0)
	b.reanimer(100.0)
	a.dernier_moment_de_combat = -1000.0
	b.dernier_moment_de_combat = -1000.0


func _lancer() -> void:
	Profil.activer(_profil_test)
	_jcj = root.get_node("JcJ")
	_social = root.get_node("Social")
	_reseau = root.get_node("Reseau")
	_jcj.fichier_classement = "user://_test_talents_arene_%d.cfg" % OS.get_process_id()
	_jcj.reglages["compte_a_rebours"] = 1.0
	_jcj.reglages["duree_resultat"] = 0.4
	print("Test des talents d'Arène")
	_regles()

	_reseau.mode = _reseau.Mode.SEUL
	_reseau.nom_joueur = "Alice"
	var scene: Node = load("res://scenes/monde/hikari_bay.tscn").instantiate()
	var intro := scene.find_child("Intro", true, false)
	if intro != null:
		intro.voyage_reel = false
	root.add_child(scene)
	current_scene = scene
	await _attendre(40)
	var alice = get_first_node_in_group("joueur_local")
	var partie = get_first_node_in_group("partie")
	_reseau.noms[2] = "Bob"
	partie.ajouter_joueur(2, "Bob")
	await _attendre(10)
	var bob = partie.joueurs.get_node("2")
	alice.teleporter(Vector3(90, 0, 78), 0.0)
	bob.placer(Vector3(93, 0, 77), 0.0)
	await _attendre(5)
	var a = alice.get_node("Combat")
	var b = bob.get_node("Combat")
	_mecanismes(a, b)

	var pa = alice.get_node("Progression")
	var cj = alice.get_node("CombatJoueur")
	# Alice : niveau 20 avec des talents normaux (ignorés en arène) et 3 talents d'Arène.
	pa.gagner_xp(Progression.xp_total_pour(Progression.donnees(), 20))
	for id in ["lame_affutee", "lame_affutee", "lame_affutee"]:
		pa.prendre_talent(id)
	for id in ["arene_gladiateur", "arene_plaie_mortelle", "arene_poursuite"]:
		pa.choisir_talent_arene(id)
	await _attendre(3)
	_verifier(pa.etat["talents_arene"].size() == 3, "Alice choisit 3 talents d'Arène (en passant par le serveur)")
	_verifier(is_equal_approx(a.bonus_blessure, 0.0), "hors de l'arène, les talents d'Arène ne font rien")
	var recharge_bond := float(cj.competence_par_id("bond").get("recharge", 0))
	var degats_hors: float = a.bonus_degats

	# Fenêtre N, onglet Arène.
	var fenetre := root.find_child("FenetreProgression", true, false)
	if fenetre == null:
		for n in root.find_children("*", "PanelContainer", true, false):
			if n.has_method("montrer_onglet"):
				fenetre = n
				break
	if fenetre != null:
		fenetre.montrer_onglet(1)
		await _attendre(3)
		var case_ = fenetre.find_child("Arene_arene_gladiateur", true, false)
		_verifier(case_ != null and String(case_.text).contains("choisi") and fenetre.find_children("Arene_*", "", true, false).size() == 6,
				"fenêtre N, onglet Arène : 6 talents, Gladiateur coché")
		fenetre.visible = false
	else:
		_verifier(false, "fenêtre des talents introuvable")

	_social.saisir("/duel Bob")
	_de_la_part(2, "_demander_reponse_defi", [true])
	_verifier(await _attendre_que(func(): return _phase() == "preparation", 3.0), "duel Alice contre Bob")
	await _attendre(2)
	var eq: Dictionary = _jcj.reglages["equilibrage"]
	var std := float(eq["equipement_standard"]["degats_pourcent"])
	_verifier(is_equal_approx(b.bonus_degats, a.bonus_degats - 6.0), "en duel : Alice a +6 %% de dégâts de plus que Bob (Gladiateur) — %d contre %d" % [a.bonus_degats, b.bonus_degats])
	_verifier(is_equal_approx(a.pv_max, b.pv_max), "même vie pour les deux (aucun talent de vie)")
	_verifier(is_equal_approx(a.bonus_blessure, 30.0) and is_equal_approx(b.bonus_blessure, 0.0), "Plaie mortelle : active pour Alice seulement")
	_verifier(is_equal_approx(float(cj.competence_par_id("bond").get("recharge", 0)), 11.0), "Poursuite : Bond passe à 11 s de recharge")
	_verifier(not cj.modifs_competences.has("taille_rapide") and a.bonus_degats < degats_hors + 40.0 and std > 0.0,
			"les talents normaux restent ignorés")
	pa.choisir_talent_arene("arene_bourreau")
	await _attendre(2)
	_verifier(not "arene_bourreau" in pa.etat["talents_arene"], "impossible de changer de talent d'Arène pendant le combat")
	await _attendre_que(func(): return _phase() == "combat", 3.0)
	b.subir(999999.0, a)
	_verifier(await _attendre_que(func(): return _phase() == "resultat", 2.0), "Alice gagne")
	await _attendre(2)
	_verifier(is_equal_approx(a.bonus_blessure, 0.0) and is_equal_approx(a.bonus_degats, degats_hors)
			and is_equal_approx(float(cj.competence_par_id("bond").get("recharge", 0)), recharge_bond), "après le combat, tout redevient comme avant")
	await _attendre_que(func(): return not _jcj.combat_en_cours(), 3.0)

	DirAccess.remove_absolute(Profil.chemin(_jcj.fichier_classement))
	print("Résultat : ", "TOUT EST BON" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs)
	quit(1 if _echecs > 0 else 0)
