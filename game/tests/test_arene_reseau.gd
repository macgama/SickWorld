extends SceneTree
## Test de l'Arène JcJ en réseau, avec DEUX joueurs (un vrai duel entre deux programmes).
## Lancer les deux en même temps (deux terminaux) :
##   godot --headless --path game -s res://tests/test_arene_reseau.gd -- --role=chef --nom=Alice --port=7810
##   godot --headless --path game -s res://tests/test_arene_reseau.gd -- --role=membre --nom=Bob --port=7810
## Alice héberge (le jeu lance un serveur sans fenêtre à côté), Bob la rejoint.
## Alice défie Bob, Bob accepte ; après le compte à rebours, chacun voit l'autre comme
## ennemi (faction envoyée par le serveur), Alice frappe Bob pour de vrai (attaque et
## compétences demandées au serveur), puis Bob sort du terrain : Alice gagne.

var _echecs := 0
var _role := "chef"
var _profil_test := "_test_arene_reseau_%d" % OS.get_process_id()


func _verifier(condition: bool, message: String) -> void:
	print("  OK   " if condition else "  ÉCHEC ", "[%s] %s" % [_role, message])
	if not condition:
		_echecs += 1


func _secondes(s: float) -> void:
	await create_timer(s).timeout


func _attendre(condition: Callable, limite: float) -> bool:
	var fin := Time.get_ticks_msec() + int(limite * 1000.0)
	while Time.get_ticks_msec() < fin:
		if condition.call():
			return true
		await _secondes(0.1)
	return condition.call()


func _initialize() -> void:
	Profil.activer(_profil_test)
	_lancer.call_deferred()


func _connecte() -> bool:
	var pair := root.multiplayer.multiplayer_peer
	return pair is ENetMultiplayerPeer and pair.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED \
			and get_first_node_in_group("joueur_local") != null


func _autre() -> Node:
	for j in get_nodes_in_group("joueur"):
		if j != get_first_node_in_group("joueur_local"):
			return j
	return null


func _a_recu(social, morceau: String) -> bool:
	for m in social.historique:
		if String(m["texte"]).contains(morceau):
			return true
	return false


func _lancer() -> void:
	Profil.activer(_profil_test)
	var reseau = root.get_node("Reseau")
	var jcj = root.get_node("JcJ")
	var social = root.get_node("Social")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			_role = argument.get_slice("=", 1)
	reseau.adresse = "127.0.0.1"
	if _role == "chef":
		reseau.mode = reseau.Mode.HEBERGER
	else:
		reseau.mode = reseau.Mode.REJOINDRE
		await _attendre(func(): return not reseau.port_libre(reseau.port), 90.0)
		await _secondes(1.0)
	var scene: Node = load(reseau.SCENE_HUB).instantiate()
	var intro := scene.find_child("Intro", true, false)
	if intro != null:
		intro.voyage_reel = false
	root.add_child(scene)
	current_scene = scene
	print("Test de l'Arène en réseau : %s (%s), port %d" % [reseau.nom_joueur, _role, reseau.port])
	_verifier(await _attendre(_connecte, 120.0), "connecté à la ville")
	_verifier(await _attendre(func(): return _autre() != null, 90.0), "on voit l'autre joueur")
	_verifier(await _attendre(func(): return jcj.get("_interface") != null, 5.0), "l'interface de l'Arène est là")
	var moi = get_first_node_in_group("joueur_local")
	var terrain := get_first_node_in_group("arene_jcj") as Node3D
	var centre: Vector3 = terrain.global_position
	# Tout le monde devant l'entrée de l'Arène.
	moi.teleporter(Vector3(92, 0, 78 if _role == "chef" else 80), 0.0)
	await _secondes(2.0)
	var depart: Vector3 = moi.global_position
	if _role == "chef":
		social.saisir("/duel Bob")
		_verifier(await _attendre(func(): return _a_recu(social, "Défi envoyé à Bob"), 10.0), "défi envoyé à Bob")
	else:
		_verifier(await _attendre(func(): return jcj.defi_de == "Alice", 30.0), "défi d'Alice reçu (fenêtre Accepter / Refuser)")
		jcj.repondre_defi(true)
	_verifier(await _attendre(func(): return String(jcj.etat.get("phase", "")) == "preparation", 15.0), "le serveur prépare le duel")
	_verifier(await _attendre(func(): return Vector2(moi.global_position.x - centre.x, moi.global_position.z - centre.z).length() < 12.0, 5.0),
			"on est amené sur le terrain")
	_verifier(jcj.je_me_bats(), "on se bat (d'après l'état envoyé par le serveur)")
	_verifier(await _attendre(func(): return String(jcj.etat.get("phase", "")) == "combat", 10.0), "« COMBAT ! »")
	var mon_combat = moi.get_node("Combat")
	var autre = _autre()
	var son_combat = autre.get_node("Combat")
	_verifier(await _attendre(func(): return mon_combat.est_hostile(son_combat), 3.0),
			"l'autre est maintenant un ennemi (faction %s contre %s)" % [mon_combat.faction, son_combat.faction])
	if _role == "chef":
		# Alice rejoint Bob et l'attaque (clic droit), puis lance ses compétences.
		moi.teleporter(autre.global_position + Vector3(-2.0, 0, 0), -PI / 2.0)
		await _secondes(0.6)
		var cj = moi.get_node("CombatJoueur")
		cj.changer_cible(son_combat, true)
		var fin := Time.get_ticks_msec() + 12000
		while Time.get_ticks_msec() < fin and son_combat.pv >= son_combat.pv_max:
			for i in 5:
				cj.utiliser(i)
			await _secondes(0.5)
		_verifier(son_combat.pv < son_combat.pv_max, "Alice blesse Bob pour de vrai (%d / %d)" % [son_combat.pv, son_combat.pv_max])
		_verifier(await _attendre(func(): return String(jcj.etat.get("phase", "")) == "resultat", 30.0), "le combat se termine")
		_verifier(int(jcj.etat.get("vainqueur", -1)) == jcj.equipe_de("Alice"), "Alice gagne")
		_verifier(await _attendre(func(): return _a_recu(social, "VICTOIRE") or jcj.get("_interface")._annonce.text.contains("VICTOIRE"), 3.0),
				"« VICTOIRE ! » à l'écran")
	else:
		# Bob encaisse quelques coups, puis s'enfuit par l'entrée : abandon.
		_verifier(await _attendre(func(): return mon_combat.pv < mon_combat.pv_max, 15.0), "Bob est touché par Alice")
		await _secondes(1.0)
		moi.teleporter(centre + Vector3(-30.0, 0, 0), 0.0)
		_verifier(await _attendre(func(): return String(jcj.etat.get("phase", "")) == "resultat", 10.0), "Bob sort du terrain : fin du combat")
		_verifier(jcj.get("_interface")._annonce.text.contains("DÉFAITE"), "« DÉFAITE » à l'écran")
	_verifier(await _attendre(func(): return not mon_combat.est_hostile(son_combat), 5.0), "fin du combat : plus ennemis")
	_verifier(await _attendre(func(): return mon_combat.pv == mon_combat.pv_max, 5.0), "soigné à la fin")
	_verifier(await _attendre(func(): return not jcj.combat_en_cours(), 15.0), "l'arène est libre")
	if _role == "chef":
		_verifier(await _attendre(func(): return moi.global_position.distance_to(depart) < 1.5, 5.0), "ramené là où on était")
	jcj.demander_classement()
	_verifier(await _attendre(func(): return jcj.classement.any(func(l): return l["nom"] == "Alice" and int(l["victoires"]) >= 1), 5.0),
			"le classement du serveur compte la victoire d'Alice")
	await _secondes(3.0)
	for relatif in Profil.lister(_profil_test):
		DirAccess.remove_absolute(Profil.dossier(_profil_test) + relatif)
	print("Résultat [%s] : %s" % [_role, "TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs])
	quit(1 if _echecs > 0 else 0)
