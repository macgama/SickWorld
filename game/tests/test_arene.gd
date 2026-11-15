extends SceneTree
## Test sans réseau de l'Arène JcJ de Hikari Bay (règles du serveur) :
## défi en duel accepté, compte à rebours, factions des équipes (les spectateurs ne
## sont ni ennemis ni alliés), victoire, soins sans pénalité et retour à sa place ;
## 2 contre 2 par la file d'attente avec deux groupes (abandon d'un joueur qui sort
## du terrain) ; victoire aux points à la fin du temps ; déconnexion en plein combat ;
## pas de retour à la balise pendant le combat ; classement.
## Les autres joueurs (Bob, Carla, Dan) sont ajoutés à la main, comme s'ils étaient connectés.
## Lancement : godot --headless --path game -s res://tests/test_arene.gd

var _echecs := 0
var _profil_test := "_test_arene_%d" % OS.get_process_id()
var _jcj
var _social
var _reseau
var _regles


func _verifier(condition: bool, message: String) -> void:
	print("  OK   " if condition else "  ÉCHEC ", message)
	if not condition:
		_echecs += 1


func _attendre(images: int) -> void:
	for i in images:
		await physics_frame


## Attend qu'une condition soit vraie (au plus « limite » secondes de jeu).
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


## Demande faite par un autre joueur (Bob = 2, Carla = 3, Dan = 4).
func _de_la_part(id: int, methode: String, arguments: Array = []) -> void:
	_jcj.expediteur_force = id
	_jcj.callv(methode, arguments)
	_jcj.expediteur_force = 0


func _combat(j):
	return j.get_node("Combat")


func _phase() -> String:
	return String(_jcj.etat.get("phase", ""))


func _lancer() -> void:
	Profil.activer(_profil_test)
	_jcj = root.get_node("JcJ")
	_social = root.get_node("Social")
	_reseau = root.get_node("Reseau")
	_regles = root.get_node("Regles")
	_jcj.fichier_classement = "user://_test_arene_%d.cfg" % OS.get_process_id()
	# Tout va plus vite pour le test.
	_jcj.reglages["compte_a_rebours"] = 1.0
	_jcj.reglages["duree_resultat"] = 0.6
	_reseau.mode = _reseau.Mode.SEUL
	_reseau.nom_joueur = "Alice"
	var scene: Node = load("res://scenes/monde/hikari_bay.tscn").instantiate()
	var intro := scene.find_child("Intro", true, false)
	if intro != null:
		intro.voyage_reel = false
	root.add_child(scene)
	current_scene = scene
	await _attendre(40)
	print("Test de l'Arène JcJ (sans réseau)")
	var alice = get_first_node_in_group("joueur_local")
	var terrain := get_first_node_in_group("arene_jcj") as Node3D
	_verifier(alice != null, "notre personnage (Alice) est là")
	_verifier(terrain != null, "le terrain de l'Arène est trouvé")
	_verifier(get_first_node_in_group("ecran_arene") != null, "le grand écran de l'Arène est trouvé")
	_verifier(scene.find_child("BorneArene", true, false) != null, "la borne d'inscription est à l'entrée")
	_verifier(await _attendre_que(func(): return _jcj.get("_interface") != null, 3.0), "l'interface de l'Arène est créée")
	var centre := terrain.global_position
	var partie := get_first_node_in_group("partie")
	var noms := {2: "Bob", 3: "Carla", 4: "Dan"}
	for id in noms:
		_reseau.noms[id] = noms[id]
		partie.ajouter_joueur(id, noms[id])
	await _attendre(10)
	var bob = partie.joueurs.get_node("2")
	var carla = partie.joueurs.get_node("3")
	var dan = partie.joueurs.get_node("4")
	# Tout le monde sur le quai de l'Arène, devant l'entrée.
	alice.teleporter(Vector3(90, 0, 78), 0.0)
	for j in [bob, carla, dan]:
		j.placer(Vector3(92 + randf() * 4.0, 0, 77), 0.0)
	await _attendre(5)
	var depart_alice: Vector3 = alice.global_position
	_verifier(not _combat(alice).est_hostile(_combat(bob)), "hors de l'arène, deux joueurs ne sont pas ennemis")

	# --- Fenêtre et commandes ---
	_jcj.basculer_fenetre()
	_verifier(_jcj.get("_interface").fenetre_ouverte(), "/arene, H ou la borne ouvrent la fenêtre de l'Arène")
	_jcj.basculer_fenetre()
	_social.saisir("/duel Alice")
	_verifier(_a_recu("toi-même"), "on ne peut pas se défier soi-même")
	_social.saisir("/duel Personne")
	_verifier(_a_recu("Personne ne s'appelle"), "défier un absent : message d'erreur")

	# --- Duel 1 contre 1 par défi ---
	_social.saisir("/duel bob")
	_verifier(_jcj._defis.has("bob") and _jcj._defis["bob"]["format"] == "1c1", "défi envoyé à Bob (duel 1 contre 1)")
	_verifier(_a_recu("Défi envoyé à Bob"), "message « Défi envoyé »")
	_de_la_part(2, "_demander_reponse_defi", [true])
	_verifier(await _attendre_que(func(): return _phase() == "preparation", 2.0), "Bob accepte : le combat se prépare")
	_verifier(_jcj.je_me_bats() and _jcj.equipe_de("Bob") == 1, "Alice (équipe 0) contre Bob (équipe 1)")
	await _attendre(3)
	_verifier(Vector2(alice.global_position.x - centre.x, alice.global_position.z - centre.z).length() < 12.0
			and alice.global_position.x < centre.x, "Alice est amenée sur le terrain, côté ouest")
	_verifier(bob.global_position.x > centre.x, "Bob est côté est")
	_verifier(_combat(alice).a_effet("immobilise"), "pendant le compte à rebours, on ne peut pas bouger")
	_verifier(not _combat(alice).est_hostile(_combat(bob)), "pendant le compte à rebours, pas encore de coups")
	_verifier(_jcj.get("_interface").texte_compte() != "", "le compte à rebours s'affiche (%s)" % _jcj.get("_interface").texte_compte())
	_verifier(String(get_first_node_in_group("ecran_arene").text).contains("Alice contre Bob"), "le grand écran annonce « Alice contre Bob »")
	_verifier(_a_recu("DJ Volt"), "DJ Volt annonce le combat à toute la ville")
	_verifier(await _attendre_que(func(): return _phase() == "combat", 3.0), "« COMBAT ! »")
	var a = _combat(alice)
	var b = _combat(bob)
	var c = _combat(carla)
	_verifier(a.est_hostile(b) and b.est_hostile(a), "Alice et Bob sont maintenant ennemis")
	_verifier(not c.est_hostile(a) and not a.est_hostile(c) and not c.est_allie(a), "Carla (spectatrice) n'est ni ennemie ni alliée des combattants")
	_verifier(not _regles.allies_autour(c, alice.global_position, 50.0).has(a), "les soins de zone d'une spectatrice n'atteignent pas les combattants")
	_verifier(not _regles.hostiles_autour(a, alice.global_position, 80.0).has(c), "les attaques de zone d'Alice épargnent les spectateurs")
	_regles.infliger(a, b, 30.0)
	_verifier(b.pv < b.pv_max, "Alice blesse Bob (%d / %d)" % [b.pv, b.pv_max])
	b.subir(99999.0, a)
	_verifier(await _attendre_que(func(): return _phase() == "resultat", 2.0), "Bob est désynchronisé : combat terminé")
	_verifier(int(_jcj.etat.get("vainqueur", -1)) == 0, "Alice gagne")
	_verifier(b.est_vivant() and b.pv == b.pv_max and not b.a_effet("desynchronisation"), "Bob est soigné, sans pénalité de désynchronisation")
	_verifier(a.faction == "joueur" and b.faction == "joueur", "chacun reprend la faction « joueur »")
	_verifier(await _attendre_que(func(): return not _jcj.combat_en_cours(), 3.0), "l'arène se libère")
	await _attendre(3)
	_verifier(alice.global_position.distance_to(depart_alice) < 1.0, "Alice est ramenée là où elle était")
	var bilan: Dictionary = _jcj.bilan("Alice")
	_verifier(int(bilan.get("victoires_1c1", 0)) == 1, "classement : 1 victoire en duel pour Alice")
	_verifier(int(_jcj.bilan("Bob").get("defaites_1c1", 0)) == 1, "classement : 1 défaite pour Bob")
	_social.saisir("/duel Bob")
	_de_la_part(2, "_demander_reponse_defi", [false])
	_verifier(_a_recu("Bob refuse"), "Bob peut refuser un défi")

	# --- 2 contre 2 par la file d'attente ---
	_social.creer_groupe("Alice", ["Alice", "Bob"])
	_social.creer_groupe("Carla", ["Carla", "Dan"])
	_de_la_part(4, "_demander_inscription", ["2c2"])
	_verifier(_jcj._files["2c2"].size() == 1 and _jcj._files["2c2"][0].size() == 2, "Dan inscrit son groupe (Carla et Dan) en 2 contre 2")
	_jcj.inscrire("2c2")
	_verifier(_jcj.ma_file == "2c2" or _phase() != "", "Alice inscrit son groupe à son tour")
	_verifier(await _attendre_que(func(): return _phase() == "preparation", 2.0), "deux équipes de 2 : le combat commence tout seul")
	_verifier(_jcj.etat.get("format") == "2c2" and _jcj.equipe_de("Bob") == _jcj.equipe_de("Alice")
			and _jcj.equipe_de("Dan") == _jcj.equipe_de("Carla") and _jcj.equipe_de("Dan") != _jcj.equipe_de("Alice"),
			"équipes : Alice & Bob contre Carla & Dan")
	_verifier(await _attendre_que(func(): return _phase() == "combat", 3.0), "« COMBAT ! » en 2 contre 2")
	var d = _combat(dan)
	_verifier(a.est_allie(b) and not a.est_hostile(b), "Alice et Bob sont alliés (soins possibles)")
	_verifier(_regles.allies_autour(a, alice.global_position, 80.0).has(b), "les soins de zone d'Alice atteignent Bob")
	_verifier(a.est_hostile(c) and a.est_hostile(d), "Carla et Dan sont les ennemis d'Alice")
	dan.placer(centre + Vector3(0, 0, 30), 0.0)
	_verifier(await _attendre_que(func(): return _a_recu("Dan a quitté le terrain"), 2.0), "Dan sort du terrain : abandon")
	_verifier(d.faction == "joueur", "Dan n'est plus dans le combat")
	_verifier(_phase() == "combat", "le combat continue (Carla est encore debout)")
	c.subir(99999.0, b)
	_verifier(await _attendre_que(func(): return _phase() == "resultat", 2.0), "Carla est désynchronisée : fin du combat")
	_verifier(int(_jcj.etat.get("vainqueur", -1)) == _jcj.equipe_de("Alice"), "Alice et Bob gagnent")
	_verifier(c.est_vivant(), "Carla est soignée à la fin")
	await _attendre_que(func(): return not _jcj.combat_en_cours(), 3.0)
	_verifier(int(_jcj.bilan("Bob").get("victoires_2c2", 0)) == 1, "classement : victoire en 2 contre 2 pour Bob")

	# --- Victoire aux points, et pas de retour à la balise pendant le combat ---
	_social._retirer_du_groupe("Bob", "%s")
	_social._retirer_du_groupe("Dan", "%s")
	_jcj.reglages["duree_max_combat"] = 1.5
	_jcj.inscrire("1c1")
	_verifier(_jcj.ma_file == "1c1", "Alice s'inscrit en duel")
	_de_la_part(4, "_demander_inscription", ["1c1"])
	_verifier(await _attendre_que(func(): return _phase() == "combat", 4.0), "Alice contre Dan (file d'attente des duels)")
	_verifier(_jcj.ma_file == "", "Alice n'est plus dans la file")
	_regles.infliger(_combat(alice), d, d.pv_max * 0.5)
	_verifier(await _attendre_que(func(): return _phase() == "resultat", 4.0), "temps écoulé")
	_verifier(int(_jcj.etat.get("vainqueur", -1)) == 0, "Alice gagne aux points (plus de vie)")
	await _attendre_que(func(): return not _jcj.combat_en_cours(), 3.0)
	_jcj.reglages["duree_max_combat"] = 180.0
	_social.saisir("/duel Bob")
	_de_la_part(2, "_demander_reponse_defi", [true])
	await _attendre_que(func(): return _phase() == "combat", 4.0)
	a.subir(99999.0, b)
	var cj = alice.get_node("CombatJoueur")
	cj._demander_reapparition()
	_verifier(not a.est_vivant(), "désynchronisée dans l'arène : pas de retour à la balise")
	_verifier(await _attendre_que(func(): return _phase() == "resultat", 2.0) and int(_jcj.etat.get("vainqueur", -1)) == 1, "Bob gagne")
	_verifier(a.est_vivant() and not a.a_effet("desynchronisation"), "Alice est soignée sans pénalité")
	await _attendre_que(func(): return not _jcj.combat_en_cours(), 3.0)

	# --- Déconnexion en plein combat ---
	_social.saisir("/duel Carla")
	_de_la_part(3, "_demander_reponse_defi", [true])
	await _attendre_que(func(): return _phase() == "combat", 4.0)
	_reseau.joueur_parti.emit(3, "Carla")
	_reseau.noms.erase(3)
	partie.retirer_joueur(3)
	_verifier(await _attendre_que(func(): return _phase() == "resultat", 2.0) and int(_jcj.etat.get("vainqueur", -1)) == 0,
			"Carla se déconnecte : Alice gagne")
	await _attendre_que(func(): return not _jcj.combat_en_cours(), 3.0)

	# --- Classement ---
	var top: Array = _jcj.meilleurs(10)
	_verifier(not top.is_empty() and top[0]["nom"] == "Alice" and int(top[0]["victoires"]) == 4,
			"classement : Alice première avec 4 victoires")
	_jcj.basculer_fenetre()
	await _attendre(3)
	_verifier(_jcj.classement.size() >= 3, "la fenêtre reçoit le classement (%d joueurs)" % _jcj.classement.size())
	_verifier(String(get_first_node_in_group("ecran_arene").text).contains("Inscription"), "l'écran revient à l'accueil quand l'arène est libre")

	DirAccess.remove_absolute(Profil.chemin(_jcj.fichier_classement))
	for relatif in Profil.lister(_profil_test):
		DirAccess.remove_absolute(Profil.dossier(_profil_test) + relatif)
	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
