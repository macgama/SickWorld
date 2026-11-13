extends SceneTree
## Test du multijoueur : à lancer comme CLIENT pendant qu'un serveur dédié tourne.
##   godot --headless --path game -- --serveur --port=7790        (dans un terminal)
##   godot --headless --path game -s res://tests/test_reseau.gd -- --port=7790 --nom=Alice
## Le test se connecte, vérifie qu'il reçoit le monde, combat un loup et vérifie
## que le serveur a bien appliqué les dégâts.

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
	reseau.mode = reseau.Mode.REJOINDRE
	reseau.adresse = "127.0.0.1"
	var nom: String = reseau.nom_joueur
	var scene: Node = load("res://scenes/monde/colline_de_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene

	print("Test réseau (%s)" % nom)
	var joueur = null
	for i in 50:
		await _secondes(0.2)
		joueur = get_first_node_in_group("joueur_local")
		if joueur != null:
			break
	_verifier(joueur != null, "le serveur a créé notre personnage")
	if joueur == null:
		quit(1)
		return
	await _secondes(1.0)
	_verifier(not root.multiplayer.is_server(), "on est bien un client (numéro %d)" % root.multiplayer.get_unique_id())
	_verifier(joueur.name == str(root.multiplayer.get_unique_id()), "le personnage porte notre numéro")
	_verifier(joueur.get_node("Combat").nom_affiche == nom, "notre nom est connu du serveur")
	var loups = get_nodes_in_group("loups")
	_verifier(loups.size() >= 15, "on voit les loups créés par le serveur (%d)" % loups.size())
	_verifier(Vector2(joueur.global_position.x, joueur.global_position.z).distance_to(Vector2(0, 55)) < 5.0,
			"on apparaît près de la balise")

	# On attend un éventuel autre joueur pour vérifier qu'on se voit.
	await _secondes(2.0)
	var autres = get_nodes_in_group("joueur").filter(func(j): return j != joueur)
	print("    autres joueurs visibles : %s" % ", ".join(autres.map(func(j): return j.get_node("Combat").nom_affiche)))

	# Combat : on se place près d'un loup et on l'attaque.
	var loup = scene.get_node("Partie/Loups/CampNord_Loup1" if nom == "Alice" else "Partie/Loups/CampEst_Loup1")
	var cj = joueur.get_node("CombatJoueur")
	cj.message.connect(func(t): print("    (message du serveur : %s)" % t))
	joueur.placer(loup.global_position + Vector3(0, 0.5, 2.5), 0.0)
	await _secondes(1.0)
	cj.changer_cible(loup.get_node("Combat"))
	await _secondes(0.3)
	var pv_avant = loup.get_node("Combat").pv
	cj.utiliser(0)
	await _secondes(1.0)
	var pv_apres = loup.get_node("Combat").pv
	_verifier(pv_apres < pv_avant, "le serveur applique nos dégâts au loup (%d -> %d)" % [pv_avant, pv_apres])
	_verifier(cj.elan > 0.0, "l'Élan calculé par le serveur nous parvient (%.0f)" % cj.elan)
	_verifier(cj.recharge_restante(0).x >= 0.0, "les temps de recharge sont reçus")
	await _secondes(2.0)
	_verifier(loup.etat == 1, "le loup nous poursuit (état reçu du serveur)")
	_verifier(joueur.get_node("Combat").pv < joueur.get_node("Combat").pv_max, "le loup nous mord")

	# Triche : on demande une compétence hors de portée en contournant la vérification locale.
	var lointain = scene.get_node("Partie/Loups/CampSud_Loup1")
	var pv_lointain = lointain.get_node("Combat").pv
	cj.cible = lointain.get_node("Combat")
	cj.rpc_id(1, "_choisir_cible", lointain.get_node("Combat").get_path(), false)
	cj.rpc_id(1, "_demander_competence", 0)
	await _secondes(1.0)
	_verifier(lointain.get_node("Combat").pv == pv_lointain, "le serveur refuse une attaque hors de portée")

	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
