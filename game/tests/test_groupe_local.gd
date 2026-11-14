extends SceneTree
## Test sans réseau de la discussion et des groupes (règles du serveur) :
## commandes de la discussion en solo, groupe créé à la main avec un deuxième
## personnage, butin partagé avec les membres proches (et pas avec ceux qui sont loin).
## Lancement : godot --headless --path game -s res://tests/test_groupe_local.gd

var _echecs := 0


func _verifier(condition: bool, message: String) -> void:
	print("  OK   " if condition else "  ÉCHEC ", message)
	if not condition:
		_echecs += 1


func _attendre(images: int) -> void:
	for i in images:
		await physics_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _a_recu(social, canal: String, morceau: String) -> bool:
	for m in social.historique:
		if m["canal"] == canal and String(m["texte"]).contains(morceau):
			return true
	return false


func _lancer() -> void:
	var reseau = root.get_node("Reseau")
	var social = root.get_node("Social")
	reseau.mode = reseau.Mode.SEUL
	reseau.nom_joueur = "Alice"
	var scene: Node = load("res://scenes/monde/colline_de_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _attendre(40)
	var alice = get_first_node_in_group("joueur_local")
	print("Test groupes et discussion (sans réseau)")
	_verifier(alice != null, "notre personnage est là")
	_verifier(social.get("_interface") != null, "l'interface sociale est créée")

	# --- Discussion en solo ---
	social.saisir("Bonjour tout le monde")
	_verifier(_a_recu(social, "dire", "Bonjour tout le monde"), "« Dire » arrive dans notre discussion")
	_verifier(social.get("_interface").a_une_bulle(1), "bulle au-dessus de notre tête")
	social.saisir("/1 un message général")
	_verifier(_a_recu(social, "general", "un message général") and social.canal_actif == "general",
			"/1 : canal Général, qui devient le canal par défaut")
	social.saisir("encore")
	_verifier(_a_recu(social, "general", "encore"), "le message suivant part sur le même canal")
	social.saisir("/d")
	_verifier(social.canal_actif == "dire", "/d seul : retour au canal Dire")
	social.saisir("/w Personne coucou")
	_verifier(_a_recu(social, "systeme", "Personne ne s'appelle"), "chuchoter à un absent : message d'erreur")
	social.saisir("/inviter Alice")
	_verifier(_a_recu(social, "systeme", "toi-même"), "on ne peut pas s'inviter soi-même")
	social.saisir("/gr hello")
	_verifier(_a_recu(social, "systeme", "pas dans un groupe"), "canal Groupe sans groupe : message d'aide")
	social.saisir("/nimportequoi")
	_verifier(_a_recu(social, "systeme", "Commande inconnue"), "commande inconnue")
	social.saisir("/aide")
	_verifier(_a_recu(social, "systeme", "/inviter"), "/aide liste les commandes")
	social.envoyer("dire", "x".repeat(500))
	_verifier(String(social.historique[-1]["texte"]).length() <= social.LONGUEUR_MAX, "messages limités à %d lettres" % social.LONGUEUR_MAX)
	social.entrer_en_donjon("grande_grotte")
	_verifier(_a_recu(social, "systeme", "multijoueur"), "en solo, la fenêtre Donjons explique qu'il faut le multijoueur")

	# --- Groupe et butin partagé ---
	var bob = load("res://scenes/joueur/joueur.tscn").instantiate()
	bob.name = "2"
	bob.nom = "Bob"
	scene.get_node("Partie/Joueurs").add_child(bob)
	bob.global_position = alice.global_position + Vector3(5, 0, 0)
	reseau.noms[2] = "Bob"
	var numero: int = social.creer_groupe("Alice", ["Alice", "Bob"])
	_verifier(social.groupe_du_joueur("bob") == numero, "Bob est dans le groupe d'Alice")
	_verifier(social.membres_proches(1, alice.global_position) == [2], "Bob est un membre proche")
	var butin = scene.get_node("Partie/Butin")
	var loup = get_nodes_in_group("loups")[0]
	var combat_loup = loup.get_node("Combat")
	for i in 30:
		combat_loup.menace = {alice.get_node("Combat"): 10.0}
		butin.ennemi_vaincu(combat_loup, loup.type_ennemi, alice.global_position)
	var sacs_alice: int = butin.sacs_de(1).size()
	var sacs_bob: int = butin.sacs_de(2).size()
	_verifier(sacs_alice > 0 and sacs_bob > 0, "Alice frappe, Bob (son groupe, tout proche) a aussi son butin (%d / %d sacs)" % [sacs_alice, sacs_bob])
	bob.global_position = alice.global_position + Vector3(300, 0, 0)
	await _attendre(2)
	_verifier(social.membres_proches(1, alice.global_position).is_empty(), "Bob est trop loin")
	for i in 20:
		combat_loup.menace = {alice.get_node("Combat"): 10.0}
		butin.ennemi_vaincu(combat_loup, loup.type_ennemi, alice.global_position)
	_verifier(butin.sacs_de(2).size() == sacs_bob, "trop loin : pas de butin pour Bob")
	social._envois.clear() # (l'anti-spam compte les messages envoyés plus haut)
	social.saisir("/gr à toute l'équipe")
	_verifier(_a_recu(social, "groupe", "à toute l'équipe"), "canal Groupe une fois en groupe")
	social._demander_chef("bob")
	_verifier(social._groupes[numero]["chef"] == "Bob", "le chef peut nommer un autre chef")
	social._demander_chef("Alice")
	_verifier(social._groupes[numero]["chef"] == "Bob", "un simple membre ne peut pas nommer le chef")
	_verifier(_a_recu(social, "systeme", "Seul le chef"), "… et on lui explique pourquoi")
	social._demander_depart()
	_verifier(social.groupe_du_joueur("alice") == 0 and social.groupe_du_joueur("bob") == 0,
			"Alice quitte : un groupe d'une seule personne est dissous")

	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
