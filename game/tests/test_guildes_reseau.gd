extends SceneTree
## Test des GUILDES en réseau, avec DEUX joueurs (deux programmes).
## Lancer les deux en même temps (deux terminaux) :
##   godot --headless --path game -s res://tests/test_guildes_reseau.gd -- --role=chef --nom=Alice --port=7830
##   godot --headless --path game -s res://tests/test_guildes_reseau.gd -- --role=membre --nom=Bob --port=7830
## Alice héberge (un serveur sans fenêtre est lancé à côté), fonde une guilde et invite Bob ;
## Bob accepte. Ils se parlent sur le canal Guilde, Alice promeut Bob, Bob dépose un objet
## dans la banque, et le contrat avance pour les deux.

var _echecs := 0
var _role := "chef"
var _profil_test := "_test_guildes_reseau_%d" % OS.get_process_id()
var _port := 7830


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


func _a_recu(social, morceau: String) -> bool:
	for m in social.historique:
		if String(m["texte"]).contains(morceau):
			return true
	return false


func _membre(guildes, nom: String) -> Dictionary:
	for m in guildes.guilde.get("membres", []):
		if String(m["nom"]) == nom:
			return m
	return {}


func _lancer() -> void:
	Profil.activer(_profil_test)
	var reseau = root.get_node("Reseau")
	var guildes = root.get_node("Guildes")
	var social = root.get_node("Social")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			_role = argument.get_slice("=", 1)
		elif argument.begins_with("--port="):
			_port = int(argument.get_slice("=", 1))
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
	var nom_guilde := "Test Réseau %d" % (_port + Time.get_ticks_msec() % 1000)
	print("Test des guildes en réseau : %s (%s), port %d" % [reseau.nom_joueur, _role, reseau.port])
	_verifier(await _attendre(_connecte, 120.0), "connecté à la ville")
	_verifier(await _attendre(func(): return get_nodes_in_group("joueur").size() >= 2, 90.0), "on voit l'autre joueur")
	var moi = get_first_node_in_group("joueur_local")
	if _role == "chef":
		await _secondes(2.0)
		guildes.fonder(nom_guilde, 2)
		_verifier(await _attendre(func(): return guildes.a_une_guilde(), 10.0), "le serveur enregistre la guilde")
		await _secondes(1.0)
		social.saisir("/ginviter Bob")
		_verifier(await _attendre(func(): return _a_recu(social, "Invitation dans la guilde envoyée à Bob"), 10.0), "invitation envoyée à Bob")
		_verifier(await _attendre(func(): return not _membre(guildes, "Bob").is_empty(), 30.0), "Bob apparaît dans la liste des membres")
		_verifier(bool(_membre(guildes, "Bob").get("en_ligne", false)), "Bob est en ligne")
		guildes.promouvoir("Bob")
		_verifier(await _attendre(func(): return String(_membre(guildes, "Bob").get("rang", "")) == "membre", 10.0), "Bob promu membre")
		social.envoyer("guilde", "Salut Bob, bienvenue !")
		_verifier(await _attendre(func(): return _a_recu(social, "Merci Alice"), 30.0), "Alice lit la réponse de Bob sur le canal Guilde")
		_verifier(await _attendre(func(): return guildes.guilde.get("journal", []).any(func(e): return String(e["texte"]).contains("Bob dépose")), 40.0),
				"le dépôt de Bob est dans le journal de la guilde")
	else:
		_verifier(await _attendre(func(): return not guildes.invitation.is_empty(), 60.0), "Bob reçoit l'invitation d'Alice")
		_verifier(String(guildes.invitation.get("de", "")) == "Alice", "elle vient d'Alice")
		guildes.repondre_invitation(true)
		_verifier(await _attendre(func(): return guildes.a_une_guilde(), 10.0), "Bob est dans la guilde")
		_verifier(String(guildes.guilde["mon_rang"]) == "recrue", "Bob commence recrue")
		_verifier(guildes.nom_local() == String(guildes.guilde["nom"]), "Bob garde le nom de sa guilde sur son PC")
		_verifier(await _attendre(func(): return _a_recu(social, "bienvenue"), 30.0), "Bob lit le message d'Alice sur le canal Guilde")
		social.envoyer("guilde", "Merci Alice !")
		_verifier(await _attendre(func(): return String(guildes.guilde.get("mon_rang", "")) == "membre", 20.0), "Bob voit sa promotion")
		# Au coffre : Bob dépose un objet.
		var coffre := get_first_node_in_group("coffre_guilde") as Node3D
		moi.teleporter(coffre.global_position + Vector3(1.5, -1.0, 0), 0.0)
		await _secondes(1.5)
		var inv = moi.get_node("Inventaire")
		var index := -1
		for i in (inv.etat["cases"] as Array).size():
			if not (inv.etat["cases"][i] as Dictionary).is_empty():
				index = i
				break
		_verifier(index >= 0, "Bob a quelque chose dans ses sacs")
		guildes.deposer(index)
		_verifier(await _attendre(func(): return guildes.guilde.get("banque", []).any(func(c): return not (c as Dictionary).is_empty()), 10.0),
				"l'objet de Bob est dans la banque de la guilde")
		_verifier(await _attendre(func(): return (inv.etat["cases"][index] as Dictionary).is_empty(), 5.0), "et n'est plus dans ses sacs")
		await _secondes(6.0)
	await _secondes(3.0)
	for relatif in Profil.lister(_profil_test):
		DirAccess.remove_absolute(Profil.dossier(_profil_test) + relatif)
	print("Résultat [%s] : %s" % [_role, "TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs])
	quit(1 if _echecs > 0 else 0)
