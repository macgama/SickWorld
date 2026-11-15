extends SceneTree
## Test sans réseau des RÉCOMPENSES et de l'ÉQUILIBRAGE de l'Arène JcJ :
## - calcul de la cote (Elo) ;
## - combats équilibrés : un agent niveau 1 sans équipement et un agent niveau 20 très
##   bien équipé ont exactement la même vie et les mêmes dégâts pendant le combat, puis
##   retrouvent leurs vraies statistiques à la fin ;
## - fin d'un combat : cote, médailles dans les sacs, titre « Baptême de l'arène » ;
## - palier de cote 1 600 : objet (une seule fois) et titre ;
## - 1re place du classement (après 10 combats) : Trophée de la baie et titre ;
## - plus rien ne compte après 3 combats le même jour contre le même adversaire ;
## - plafond de médailles par jour ; boutique de médailles d'Akane ; fenêtre de l'Arène.
## Lancement : godot --headless --path game -s res://tests/test_arene_recompenses.gd

var _echecs := 0
var _profil_test := "_test_arene_rec_%d" % OS.get_process_id()
var _jcj
var _social
var _reseau
var _regles
var _partie


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


func _a_recu(morceau: String) -> bool:
	for m in _social.historique:
		if String(m["texte"]).contains(morceau):
			return true
	return false


func _de_la_part(id: int, methode: String, arguments: Array = []) -> void:
	_jcj.expediteur_force = id
	_jcj.callv(methode, arguments)
	_jcj.expediteur_force = 0


func _phase() -> String:
	return String(_jcj.etat.get("phase", ""))


func _combien(joueur, id: String) -> int:
	var n := 0
	for c in joueur.get_node("Inventaire").etat.get("cases", []):
		if c is Dictionary and String(c.get("id", "")) == id:
			n += int(c.get("n", 1))
	return n


## Un duel complet Alice contre « adversaire » (id réseau), gagné par « gagnant ».
func _duel(alice, adversaire, id: int, alice_gagne: bool) -> void:
	_social.saisir("/duel " + String(adversaire.nom))
	_de_la_part(id, "_demander_reponse_defi", [true])
	await _attendre_que(func(): return _phase() == "combat", 4.0)
	var perdant = adversaire if alice_gagne else alice
	var gagnant = alice if alice_gagne else adversaire
	perdant.get_node("Combat").subir(999999.0, gagnant.get_node("Combat"))
	await _attendre_que(func(): return _phase() == "resultat", 2.0)
	await _attendre_que(func(): return not _jcj.combat_en_cours(), 3.0)
	await _attendre(2)


func _lancer() -> void:
	Profil.activer(_profil_test)
	_jcj = root.get_node("JcJ")
	_social = root.get_node("Social")
	_reseau = root.get_node("Reseau")
	_regles = root.get_node("Regles")
	_jcj.fichier_classement = "user://_test_arene_rec_%d.cfg" % OS.get_process_id()
	_jcj.reglages["compte_a_rebours"] = 0.5
	_jcj.reglages["duree_resultat"] = 0.4
	print("Test des récompenses et de l'équilibrage de l'Arène")

	# --- Cote Elo ---
	_verifier(is_equal_approx(_jcj.chances_elo(1500, 1500), 0.5), "Elo : à cote égale, une chance sur deux")
	_verifier(_jcj.variation_cote(1500, 1500, 1.0, 32) == 16 and _jcj.variation_cote(1500, 1500, 0.0, 32) == -16,
			"Elo : à cote égale, +16 / -16 (k = 32)")
	_verifier(_jcj.variation_cote(1400, 1700, 1.0, 32) > 25, "Elo : battre bien plus fort que soi rapporte beaucoup (%d)" % _jcj.variation_cote(1400, 1700, 1.0, 32))
	_verifier(_jcj.variation_cote(1700, 1400, 1.0, 32) < 6, "Elo : battre bien plus faible que soi rapporte peu (%d)" % _jcj.variation_cote(1700, 1400, 1.0, 32))

	# --- Titres d'arène (règles pures) ---
	var d := Progression.donnees()
	var e := Progression.etat_de_depart()
	e["arene"] = {"victoires": 1, "meilleure_cote": 1610, "meilleur_rang": 0}
	var t := Progression.nouveaux_titres(d, e)
	_verifier("bapteme_arene" in t and "espoir_de_la_baie" in t and not "combattant_de_la_baie" in t,
			"titres : 1 victoire et 1 610 de cote donnent « Baptême » et « Espoir de la baie »")
	e["arene"]["meilleur_rang"] = 1
	t = Progression.nouveaux_titres(d, e)
	_verifier("champion_de_la_baie" in t and "grand_nom_de_l_arene" in t, "titres : la 1re place donne « Champion de la baie » (et le top 10)")
	var lu := Progression.valider(d, "lame", JSON.parse_string(JSON.stringify(e)))
	_verifier(int(lu["arene"]["meilleure_cote"]) == 1610 and int(lu["arene"]["meilleur_rang"]) == 1, "le bilan d'arène est gardé dans la sauvegarde")

	# --- Scène : Alice (niveau 1) et Bob (niveau 20, très bien équipé) ---
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
	_partie = get_first_node_in_group("partie")
	var noms := {2: "Bob", 3: "Carla"}
	for id in noms:
		_reseau.noms[id] = noms[id]
		_partie.ajouter_joueur(id, noms[id])
	await _attendre(10)
	var bob = _partie.joueurs.get_node("2")
	var carla = _partie.joueurs.get_node("3")
	alice.teleporter(Vector3(90, 0, 78), 0.0)
	bob.placer(Vector3(93, 0, 77), 0.0)
	carla.placer(Vector3(95, 0, 77), 0.0)
	await _attendre(5)
	var a = alice.get_node("Combat")
	var b = bob.get_node("Combat")
	# Même classe pour comparer (la vie de base dépend de la classe).
	_verifier(alice.get_node("CombatJoueur").classe_id() == bob.get_node("CombatJoueur").classe_id(), "Alice et Bob sont de la même classe")
	# Juste le niveau 20 (le maximum monte avec chaque île : 30 depuis la Grèce).
	bob.get_node("Progression").gagner_xp(Progression.xp_total_pour(Progression.donnees(), 20))
	var inv_b = bob.get_node("Inventaire")
	inv_b.etat["equipement"]["arme_principale"] = "lame_legende"
	inv_b.etat["equipement"]["torse"] = "veste_arene"
	inv_b.etat["equipement"]["mains"] = "gants_etoile"
	inv_b._appliquer()
	await _attendre(2)
	var pv_alice := float(a.pv_max)
	var pv_bob := float(b.pv_max)
	var degats_bob := float(b.bonus_degats)
	_verifier(bob.get_node("Progression").niveau() == 20 and pv_bob > pv_alice * 1.5 and degats_bob > float(a.bonus_degats) + 40.0,
			"hors de l'arène, Bob (niv. 20) est bien plus fort qu'Alice (niv. 1) : %d PV contre %d" % [pv_bob, pv_alice])

	# --- Combat équilibré ---
	_social.saisir("/duel Bob")
	_de_la_part(2, "_demander_reponse_defi", [true])
	_verifier(await _attendre_que(func(): return _phase() == "preparation", 3.0), "duel Alice contre Bob")
	await _attendre(2)
	_verifier(is_equal_approx(a.pv_max, b.pv_max) and is_equal_approx(a.bonus_degats, b.bonus_degats)
			and is_equal_approx(a.bonus_reduction, b.bonus_reduction) and is_equal_approx(a.bonus_critique, b.bonus_critique),
			"pendant le combat, même vie et mêmes dégâts pour les deux (%d PV, +%d %% dégâts)" % [a.pv_max, a.bonus_degats])
	_verifier(a.pv == a.pv_max and b.pv == b.pv_max, "les deux commencent avec toute leur vie")
	_verifier(alice.get_node("Inventaire").mode_arene and alice.get_node("CombatJoueur").modifs_competences.is_empty(),
			"l'équipement et les talents ne modifient plus les compétences")
	_verifier(String(_jcj.get("_interface")._titre_bandeau.text).contains("Combat équilibré"), "le bandeau annonce un combat équilibré")
	await _attendre_que(func(): return _phase() == "combat", 3.0)
	b.subir(999999.0, a)
	_verifier(await _attendre_que(func(): return _phase() == "resultat", 2.0), "Alice (niv. 1) bat Bob (niv. 20)")
	await _attendre(2)
	_verifier(is_equal_approx(b.pv_max, pv_bob) and is_equal_approx(b.bonus_degats, degats_bob) and is_equal_approx(a.pv_max, pv_alice),
			"à la fin, chacun retrouve ses vraies statistiques")
	_verifier(b.pv == b.pv_max, "Bob est soigné avec sa vraie vie (%d)" % b.pv)
	await _attendre_que(func(): return not _jcj.combat_en_cours(), 3.0)
	await _attendre(2)

	# --- Récompenses du premier combat ---
	var fa: Dictionary = _jcj.bilan("Alice")
	var fb: Dictionary = _jcj.bilan("Bob")
	_verifier(int(fa.get("cote", 0)) == 1524 and int(fb.get("cote", 0)) == 1476, "cote : Alice 1 524 (+24), Bob 1 476 (-24) (premiers combats : k = 48)")
	_verifier(_combien(alice, "medaille_arene") == 3 and _combien(bob, "medaille_arene") == 1, "médailles : 3 pour la gagnante, 1 pour le perdant")
	_verifier("bapteme_arene" in alice.get_node("Progression").etat["titres"], "Alice obtient le titre « Baptême de l'arène »")
	_verifier(not "bapteme_arene" in bob.get_node("Progression").etat["titres"], "Bob ne l'a pas (il a perdu)")
	_verifier(_a_recu("Cote 1524 (+24)"), "message : « Cote 1524 (+24) · +3 médailles »")
	_verifier(String(_jcj.get("_interface")._recompense.text).contains("Cote 1524"), "l'écran de fin montre la cote gagnée")

	# --- Palier de cote 1 600 ---
	var cfg := ConfigFile.new()
	cfg.load(Profil.chemin(_jcj.fichier_classement))
	var cle: String = _jcj._cle_joueur("Alice")
	var f: Dictionary = cfg.get_value("joueurs", cle)
	f["cote"] = 1590
	f["meilleure_cote"] = 1590
	cfg.set_value("joueurs", cle, f)
	cfg.save(Profil.chemin(_jcj.fichier_classement))
	await _duel(alice, carla, 3, true)
	_verifier(int(_jcj.bilan("Alice").get("cote", 0)) >= 1600, "Alice passe 1 600 de cote (%d)" % int(_jcj.bilan("Alice").get("cote", 0)))
	_verifier(_combien(alice, "bandeau_espoir") == 1, "palier 1 600 : le Bandeau de l'Espoir est dans ses sacs")
	_verifier("espoir_de_la_baie" in alice.get_node("Progression").etat["titres"], "palier 1 600 : titre « Espoir de la baie »")
	await _duel(alice, carla, 3, true)
	_verifier(_combien(alice, "bandeau_espoir") == 1, "l'objet d'un palier n'est donné qu'une fois")

	# --- Combats arrangés : 3 par jour contre le même adversaire ---
	await _duel(alice, carla, 3, true)
	var cote_avant := int(_jcj.bilan("Alice").get("cote", 0))
	var medailles_avant := _combien(alice, "medaille_arene")
	await _duel(alice, carla, 3, true)
	_verifier(int(_jcj.bilan("Alice").get("cote", 0)) == cote_avant and _combien(alice, "medaille_arene") == medailles_avant,
			"4e combat du jour contre Carla : ni cote ni médailles")
	_verifier(_a_recu("Combat amical"), "message « Combat amical »")

	# --- 1re place du classement (après 10 combats) ---
	_verifier(int(_jcj.bilan_affiche("Alice")["rang"]) == 0, "moins de 10 combats : pas encore classée")
	cfg.load(Profil.chemin(_jcj.fichier_classement))
	f = cfg.get_value("joueurs", cle)
	f["combats"] = 12
	f["medailles_jour"] = {"jour": _jcj._aujourdhui(), "n": 29}
	cfg.set_value("joueurs", cle, f)
	cfg.save(Profil.chemin(_jcj.fichier_classement))
	medailles_avant = _combien(alice, "medaille_arene")
	await _duel(alice, bob, 2, true)
	_verifier(int(_jcj.bilan_affiche("Alice")["rang"]) == 1, "après 13 combats, Alice est 1re du classement")
	_verifier(_combien(alice, "trophee_baie") == 1 and _combien(alice, "insigne_grand_nom") == 1, "1re place : Trophée de la baie et Insigne des Dix")
	_verifier("champion_de_la_baie" in alice.get_node("Progression").etat["titres"], "1re place : titre « Champion de la baie »")
	_verifier(_combien(alice, "medaille_arene") == medailles_avant + 1, "plafond de 30 médailles par jour (29 + 1 seulement)")
	var classement: Array = _jcj.meilleurs(10)
	_verifier(not classement.is_empty() and String(classement[0]["nom"]) == "Alice" and classement[0].get("classe", false),
			"le classement est trié par cote, Alice en tête")

	# --- Fenêtre de l'Arène ---
	_jcj.basculer_fenetre()
	await _attendre(5)
	var texte_bilan := String(_jcj.get("_interface")._bilan_fenetre.text)
	_verifier(texte_bilan.contains("1er du classement") and texte_bilan.contains("Prochaine récompense à 1750"),
			"la fenêtre montre la cote, le rang et la prochaine récompense")
	_jcj.basculer_fenetre()

	# --- Boutique d'Akane ---
	var artisanat := preload("res://scripts/objets/artisanat.gd")
	_verifier(artisanat.artisan_du_pnj(root.get_node("Donnees").artisanat, "championne") == "arene", "Akane échange les médailles (boutique de l'Arène)")
	var recettes := 0
	for id in root.get_node("Donnees").artisanat.get("recettes", {}):
		var r: Dictionary = root.get_node("Donnees").artisanat["recettes"][id]
		if String(r.get("artisan", "")) == "arene":
			recettes += 1
			_verifier(not Objets.objet(root.get_node("Donnees").objets, String(r["donne"])).is_empty(), "l'échange « %s » donne un vrai objet" % id)
	_verifier(recettes >= 4, "la boutique propose %d échanges" % recettes)
	for palier in _jcj.reglages["recompenses"]["paliers"]:
		_verifier(not Objets.objet(root.get_node("Donnees").objets, String(palier["objet"])).is_empty()
				and not Progression.titre(d, String(palier["titre"])).is_empty(), "palier %s : l'objet et le titre existent" % palier.get("cote", palier.get("rang")))

	DirAccess.remove_absolute(Profil.chemin(_jcj.fichier_classement))
	print("Résultat : ", "TOUT EST BON" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs)
	quit(1 if _echecs > 0 else 0)
