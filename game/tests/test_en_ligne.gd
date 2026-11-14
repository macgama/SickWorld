extends SceneTree
## Test du serveur en ligne : rejoint un serveur dédié (sur ce PC ou sur Oracle Cloud)
## dans la ville d'Hikari Bay, vérifie que le serveur crée notre personnage, qu'il
## voit nos déplacements, et liste les autres joueurs présents.
##   godot --headless --path game -s res://tests/test_en_ligne.gd -- --adresse=1.2.3.4 --nom=Alice
## Options : --port=7777, --duree=10 (secondes passées en ville, on reste connecté
## jusqu'au bout pour que les autres nous voient), --attendre=1 (nombre d'autres
## joueurs qu'on doit avoir vus pour réussir), --officiel (adresse du fichier
## data/serveur_officiel.json).

var _echecs := 0


func _verifier(condition: bool, message: String) -> void:
	print("  OK   " if condition else "  ÉCHEC ", message)
	if not condition:
		_echecs += 1


func _secondes(s: float) -> void:
	await create_timer(s).timeout


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var reseau = root.get_node("Reseau")
	var duree := 10.0
	var attendre := 0
	reseau.adresse = "127.0.0.1"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--adresse="):
			reseau.adresse = argument.get_slice("=", 1)
		elif argument.begins_with("--duree="):
			duree = float(argument.get_slice("=", 1))
		elif argument.begins_with("--attendre="):
			attendre = int(argument.get_slice("=", 1))
		elif argument == "--officiel":
			var officiel: Dictionary = reseau.serveur_officiel()
			reseau.adresse = String(officiel.get("jeu", ""))
			reseau.port = int(officiel.get("port", reseau.PORT_PAR_DEFAUT))
	reseau.mode = reseau.Mode.REJOINDRE
	var nom: String = reseau.nom_joueur
	print("Test en ligne : %s rejoint %s:%d" % [nom, reseau.adresse, reseau.port])
	var debut := Time.get_ticks_msec()
	var scene: Node = load(reseau.SCENE_HUB).instantiate()
	root.add_child(scene)
	current_scene = scene

	var joueur = null
	for i in 150:
		await _secondes(0.2)
		joueur = get_first_node_in_group("joueur_local")
		if joueur != null:
			break
	_verifier(joueur != null, "le serveur a créé notre personnage")
	if joueur == null:
		quit(1)
		return
	print("    connecté en %.1f s (numéro %d)" % [(Time.get_ticks_msec() - debut) / 1000.0, root.multiplayer.get_unique_id()])
	await _secondes(1.0)
	_verifier(not root.multiplayer.is_server(), "on est bien un client")
	_verifier(joueur.get_node("Combat").nom_affiche == nom, "notre nom est connu du serveur")

	# On marche un peu : les autres joueurs doivent nous voir bouger.
	var depart: Vector3 = joueur.global_position
	joueur.placer(depart + Vector3(3, 0, 0), 0.0)
	var vus := {}
	var fin := Time.get_ticks_msec() + int(duree * 1000.0)
	while Time.get_ticks_msec() < fin:
		await _secondes(1.0)
		for j in get_nodes_in_group("joueur"):
			if j != joueur:
				vus[j.get_node("Combat").nom_affiche] = true
	print("    autres joueurs vus : %s" % (", ".join(vus.keys()) if not vus.is_empty() else "aucun"))
	_verifier(vus.size() >= attendre, "on voit au moins %d autre(s) joueur(s)" % attendre)
	_verifier(root.multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED,
			"toujours connecté après %.0f s" % duree)

	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
