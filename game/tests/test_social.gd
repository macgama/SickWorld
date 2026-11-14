extends SceneTree
## Test de la discussion, des groupes et du donjon en groupe, avec DEUX joueurs.
## Lancer les deux en même temps (deux terminaux) :
##   godot --headless --path game -s res://tests/test_social.gd -- --role=chef --nom=Alice --port=7800
##   godot --headless --path game -s res://tests/test_social.gd -- --role=membre --nom=Bob --port=7800
## Le chef clique sur « Héberger » (le jeu lance un serveur sans fenêtre en arrière-plan),
## le membre le rejoint. Ensuite : message « Dire » + bulle, invitation, canal Groupe,
## chuchotement, départ ensemble dans la Grande Grotte (donjon privé sur un autre port),
## retour en ville.

var _echecs := 0
var _role := "chef"


func _verifier(condition: bool, message: String) -> void:
	print("  OK   " if condition else "  ÉCHEC ", "[%s] %s" % [_role, message])
	if not condition:
		_echecs += 1


func _secondes(s: float) -> void:
	await create_timer(s).timeout


## Attend qu'une condition soit vraie (au plus « limite » secondes).
func _attendre(condition: Callable, limite: float) -> bool:
	var fin := Time.get_ticks_msec() + int(limite * 1000.0)
	while Time.get_ticks_msec() < fin:
		if condition.call():
			return true
		await _secondes(0.2)
	return condition.call()


func _initialize() -> void:
	_lancer.call_deferred()


func _a_recu(social, canal: String, morceau: String) -> bool:
	for m in social.historique:
		if m["canal"] == canal and String(m["texte"]).contains(morceau):
			return true
	return false


func _scene() -> String:
	return current_scene.scene_file_path if current_scene != null else ""


func _connecte() -> bool:
	var pair := root.multiplayer.multiplayer_peer
	return pair is ENetMultiplayerPeer and pair.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED \
			and get_first_node_in_group("joueur_local") != null


func _lancer() -> void:
	var reseau = root.get_node("Reseau")
	var social = root.get_node("Social")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			_role = argument.get_slice("=", 1)
	reseau.adresse = "127.0.0.1"
	if _role == "chef":
		reseau.mode = reseau.Mode.HEBERGER
	else:
		reseau.mode = reseau.Mode.REJOINDRE
		# On attend que le serveur lancé par le chef écoute.
		await _attendre(func(): return not reseau.port_libre(reseau.port), 90.0)
		await _secondes(1.0)
	var port_ville: int = reseau.port
	var scene: Node = load(reseau.SCENE_HUB).instantiate()
	root.add_child(scene)
	current_scene = scene
	print("Test social : %s (%s), port %d" % [reseau.nom_joueur, _role, port_ville])

	_verifier(await _attendre(_connecte, 120.0), "connecté à la ville")
	if _echecs > 0:
		quit(1)
		return
	_verifier(not root.multiplayer.is_server(), "même en hébergeant, on est client du serveur lancé à côté")
	_verifier(await _attendre(func(): return get_nodes_in_group("joueur").size() >= 2, 90.0), "on voit l'autre joueur")
	_verifier(await _attendre(func(): return social.get("_interface") != null, 5.0), "la discussion et les cadres du groupe sont à l'écran")
	if _role == "chef":
		await _chef(reseau, social, port_ville)
	else:
		await _membre(reseau, social, port_ville)
	print("Résultat [%s] : %s" % [_role, "TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs])
	quit(1 if _echecs > 0 else 0)


func _chef(reseau, social, port_ville: int) -> void:
	await _secondes(1.0)
	social.saisir("Bonjour [b]Bob[/b] !")
	_verifier(await _attendre(func(): return _a_recu(social, "dire", "Bonjour"), 5.0), "« Dire » : on lit son propre message")
	var moi = get_first_node_in_group("joueur_local")
	_verifier(social.get("_interface").a_une_bulle(int(String(moi.name))), "une bulle apparaît au-dessus de notre tête")
	social.saisir("/inviter bob")
	_verifier(await _attendre(func(): return social.groupe.size() == 2, 20.0), "Bob a accepté : groupe de 2")
	_verifier(social.suis_chef(), "on est le chef du groupe")
	social.saisir("/gr On part à la grotte ?")
	_verifier(await _attendre(func(): return _a_recu(social, "groupe", "Salut chef"), 15.0), "canal Groupe : message de Bob reçu")
	_verifier(await _attendre(func(): return _a_recu(social, "prive", "secret"), 15.0), "chuchotement de Bob reçu")
	_verifier(social.dernier_chuchoteur == "Bob", "/r répondra à Bob")
	social.saisir("/z test de zone")
	_verifier(await _attendre(func(): return _a_recu(social, "zone", "test de zone"), 5.0), "canal Zone")
	social.saisir("/gu bonjour la guilde")
	_verifier(await _attendre(func(): return _a_recu(social, "systeme", "pas de guilde"), 5.0), "canal Guilde sans guilde : message d'aide")
	# Anti-spam : le 7e message en quelques secondes est refusé.
	for i in 8:
		social.envoyer("general", "spam %d" % i)
	_verifier(await _attendre(func(): return _a_recu(social, "systeme", "Doucement"), 5.0), "anti-spam")
	await _secondes(2.0)

	# --- Donjon en groupe ---
	social.entrer_en_donjon("grande_grotte")
	_verifier(await _attendre(func(): return _scene().ends_with("grotte.tscn"), 90.0), "on arrive dans la Grande Grotte")
	_verifier(await _attendre(_connecte, 60.0), "connecté au serveur du donjon")
	_verifier(reseau.en_instance() and reseau.port != port_ville, "le donjon a son propre port (%d)" % reseau.port)
	_verifier(await _attendre(func(): return get_nodes_in_group("joueur").size() == 2, 60.0), "Bob est avec nous dans le donjon")
	_verifier(await _attendre(func(): return social.groupe.size() == 2 \
			and social.groupe.all(func(m): return m["etat"] == "ici"), 20.0), "le groupe est reformé dans le donjon")
	_verifier(social.suis_chef(), "on reste le chef dans le donjon")
	social.saisir("/gr Dans la grotte !")
	_verifier(await _attendre(func(): return _a_recu(social, "groupe", "Dans la grotte"), 5.0), "canal Groupe dans le donjon")
	await _secondes(3.0)
	social.quitter_le_donjon()
	_verifier(await _attendre(func(): return _scene().ends_with("hikari_bay.tscn"), 60.0), "retour à Hikari Bay")
	_verifier(await _attendre(_connecte, 60.0), "reconnecté à la ville")
	_verifier(reseau.port == port_ville and not reseau.en_instance(), "de retour sur le port de la ville")
	_verifier(await _attendre(func(): return social.groupe.size() == 2, 20.0), "toujours en groupe avec Bob en ville")
	await _attendre(func(): return social.groupe.all(func(m): return m["etat"] == "ici"), 30.0)
	social.saisir("/quitter")
	_verifier(await _attendre(func(): return social.groupe.is_empty(), 10.0), "/quitter : plus de groupe")
	await _secondes(3.0)


func _membre(reseau, social, port_ville: int) -> void:
	_verifier(await _attendre(func(): return social.invitation_de == "Alice", 30.0), "invitation d'Alice reçue")
	_verifier(_a_recu(social, "dire", "Bonjour"), "« Dire » : message d'Alice reçu")
	var alice: Node = null
	for j in get_nodes_in_group("joueur"):
		if j != get_first_node_in_group("joueur_local"):
			alice = j
	_verifier(alice != null and social.get("_interface").a_une_bulle(int(String(alice.name))), "bulle au-dessus d'Alice")
	social.repondre_invitation(true)
	_verifier(await _attendre(func(): return social.groupe.size() == 2, 10.0), "dans le groupe d'Alice")
	_verifier(not social.suis_chef(), "Alice est le chef, pas nous")
	_verifier(await _attendre(func(): return _a_recu(social, "groupe", "grotte"), 10.0), "canal Groupe : message d'Alice reçu")
	social.saisir("/gr Salut chef")
	social.saisir("/w alice un secret")
	# On attend le départ en donjon décidé par Alice.
	_verifier(await _attendre(func(): return _scene().ends_with("grotte.tscn"), 120.0), "emmené dans la Grande Grotte avec le groupe")
	_verifier(await _attendre(_connecte, 60.0), "connecté au serveur du donjon")
	_verifier(reseau.en_instance(), "on est bien en donjon")
	_verifier(await _attendre(func(): return _a_recu(social, "groupe", "Dans la grotte"), 30.0), "canal Groupe dans le donjon")
	# Alice repart : on la suit peu après.
	await _attendre(func(): return get_nodes_in_group("joueur").size() == 1, 30.0)
	social.quitter_le_donjon()
	_verifier(await _attendre(func(): return _scene().ends_with("hikari_bay.tscn"), 60.0), "retour à Hikari Bay")
	_verifier(await _attendre(_connecte, 60.0), "reconnecté à la ville")
	_verifier(await _attendre(func(): return _a_recu(social, "systeme", "dissous"), 30.0), "Alice quitte : le groupe est dissous")
	await _secondes(2.0)
