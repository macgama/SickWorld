extends SceneTree
## Test automatique de l'étape 2 : ciblage, compétences, loups, mort et réapparition.
## Lancement : godot --headless --path game -s res://tests/test_combat.gd

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


func _loups(faction: String) -> Array:
	return get_nodes_in_group("loups").filter(func(l): return l.faction == faction)


func _appuyer(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await _attendre(2)
	ev = InputEventAction.new()
	ev.action = action
	ev.pressed = false
	Input.parse_input_event(ev)


func _lancer() -> void:
	var scene: Node = load("res://scenes/monde/colline_de_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _attendre(30)
	var joueur = get_first_node_in_group("joueur_local")
	var cj = joueur.get_node("CombatJoueur")
	var moi = joueur.get_node("Combat")

	print("Test du combat")
	_verifier(_loups("ennemi").size() == 15, "15 loups sont apparus dans les camps (%d)" % _loups("ennemi").size())
	_verifier(cj.barre.size() == 8, "la barre contient 8 compétences")

	# On se place à 9 m d'un loup du camp nord, face à lui.
	var loup = scene.get_node("Partie/Loups/CampNord_Loup1")
	var p = loup.global_position + Vector3(0, 0.5, 9)
	joueur.placer(p, 0.0)
	await _attendre(5)
	await _appuyer("cible_suivante")
	await _attendre(2)
	_verifier(cj.cible != null, "Tab sélectionne un ennemi")
	cj.changer_cible(loup.combat)

	_verifier(cj.raison_impossible(0) == "Hors de portée", "Taille rapide refusée hors de portée")
	_verifier(cj.raison_impossible(4) != "", "Exécution refusée (loup en pleine forme)")

	# Bond (touche 4) : rapproche du loup.
	_verifier(cj.utiliser(3), "Bond utilisable à 9 m")
	await _secondes(0.8)
	_verifier(Vector2(joueur.global_position.x - loup.global_position.x,
			joueur.global_position.z - loup.global_position.z).length() < 3.5, "Bond amène au contact")
	_verifier(loup.combat.pv < loup.combat.pv_max, "le loup a pris des dégâts")
	_verifier(loup.etat == loup.Etat.POURSUIVRE, "le loup attaque le joueur")
	var voisin = scene.get_node("Partie/Loups/CampNord_Loup2")
	_verifier(voisin.etat == voisin.Etat.POURSUIVRE, "son voisin de meute vient l'aider")
	_verifier(cj.elan > 0.0, "l'Élan monte (%.0f)" % cj.elan)

	# On enchaîne les compétences jusqu'à la mort des deux loups.
	var limite := 400
	while (loup.combat.est_vivant() or voisin.combat.est_vivant()) and limite > 0 and moi.est_vivant():
		limite -= 1
		if cj.cible == null:
			cj.changer_cible(loup.combat if loup.combat.est_vivant() else voisin.combat)
		for i in [4, 2, 1, 0]:
			if cj.raison_impossible(i) == "":
				cj.utiliser(i)
				break
		await _secondes(0.1)
	_verifier(not loup.combat.est_vivant() and not voisin.combat.est_vivant(), "les deux loups sont vaincus")
	_verifier(moi.pv < moi.pv_max, "le joueur a été mordu (%d/%d)" % [moi.pv, moi.pv_max])
	_verifier(cj.cible == null, "la cible est retirée à sa mort")
	_verifier(loup.etat == loup.Etat.MORT, "le loup est couché au sol")

	# Feu des ancêtres : soigne le joueur.
	var pv_avant = moi.pv
	await _secondes(1.1)
	cj.utiliser(5)
	await _secondes(2.2)
	_verifier(moi.pv > pv_avant, "le Feu des ancêtres soigne (%d -> %d)" % [pv_avant, moi.pv])

	# Lancer au propulseur (avec préparation) sur un loup lointain.
	var loin = scene.get_node("Partie/Loups/CampOuest_Loup1")
	cj.message.connect(func(t): print("    (message du jeu : %s)" % t))
	joueur.placer(loin.global_position + Vector3(-20, 0.5, 0), -PI / 2)
	await _secondes(1.0)
	cj.changer_cible(loin.combat)
	_verifier(cj.utiliser(6), "Lancer au propulseur démarre")
	await _secondes(2.0)
	_verifier(loin.combat.pv < loin.combat.pv_max, "la sagaie touche le loup à 20 m")
	_verifier(loin.combat.a_effet("ralenti"), "le loup est ralenti")

	# Appel de la meute.
	cj.utiliser(7)
	await _attendre(5)
	_verifier(_loups("joueur").size() == 2, "Appel de la meute invoque 2 loups alliés")

	# Laisse : on s'enfuit loin, les loups abandonnent et rentrent.
	joueur.placer(Vector3(0, 30, 70), 0.0)
	await _secondes(9.0)
	var en_retour = get_nodes_in_group("loups").filter(func(l): return l.faction == "ennemi" and l.etat == l.Etat.POURSUIVRE and l._cible == moi)
	for l in en_retour:
		print("    encore en poursuite : %s à %.0f m de son camp" % [l.name, l.global_position.distance_to(l.camp)])
	_verifier(en_retour.is_empty(), "les loups abandonnent la poursuite du joueur")

	# Mort et réapparition.
	moi.subir(10000.0, null)
	await _attendre(2)
	_verifier(not moi.est_vivant(), "le joueur est désynchronisé")
	var position_mort = joueur.global_position
	Input.action_press("avancer")
	await _attendre(20)
	Input.action_release("avancer")
	_verifier(joueur.global_position.distance_to(position_mort) < 0.5, "impossible de bouger désynchronisé")
	cj.reapparaitre()
	await _attendre(5)
	var balise = scene.get_node("BaliseVigie")
	_verifier(moi.pv == moi.pv_max, "vie pleine après réapparition")
	_verifier(joueur.global_position.distance_to(balise.global_position) < 5.0, "réapparition à la balise")
	_verifier(moi.a_effet("desynchronisation"), "pénalité de -10 % appliquée")

	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
