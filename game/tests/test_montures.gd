extends SceneTree
## Test des montures : appeler sa monture (V) dans la Steppe, aller plus vite,
## descendre en étant attaqué, refus en ville et dans le donjon.
## Lancement : godot --headless --path game -s res://tests/test_montures.gd

var _echecs := 0


func _verifier(condition: bool, message: String) -> void:
	if condition:
		print("  OK   ", message)
	else:
		print("  ÉCHEC ", message)
		_echecs += 1


func _attendre(images: int) -> void:
	for i in images:
		await physics_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _charger(chemin: String) -> Node:
	var scene: Node = load(chemin).instantiate()
	root.add_child(scene)
	await _attendre(40)
	return scene


func _vider(scene: Node) -> void:
	scene.queue_free()
	await _attendre(5)


var _allure := ""


func _vitesse(joueur) -> float:
	var depart: Vector3 = joueur.global_position
	Input.action_press("avancer")
	await _attendre(60)
	var bete = joueur.get_node("Monture").get_node_or_null("Bete")
	_allure = bete._courante if bete != null else ""
	Input.action_release("avancer")
	await _attendre(5)
	var d: Vector3 = joueur.global_position - depart
	return Vector2(d.x, d.z).length()


func _lancer() -> void:
	print("Test des montures")
	var Monture = load("res://scripts/joueur/monture.gd")
	_verifier(Monture.fiche("renne").get("epoque") == "prehistoire", "le renne est la monture de la Préhistoire")
	_verifier(Monture.fiche("ane").get("epoque") == "egypte", "l'âne de bât est la monture de l'Égypte")

	# --- Steppe (Préhistoire) ---
	var scene := await _charger("res://scenes/monde/prehistoire/steppe.tscn")
	var joueur = get_first_node_in_group("joueur_local")
	var m = joueur.get_node("Monture")
	_verifier(Monture.lieu(self) == "prehistoire", "la Steppe est en Préhistoire (%s)" % Monture.lieu(self))
	_verifier(Monture.monture_du_lieu(self) == "renne", "la monture de la Steppe est le renne")
	var a_pied: float = await _vitesse(joueur)

	var messages := []
	joueur.get_node("CombatJoueur").message.connect(func(t): messages.append(t))
	# Appel en bougeant : refusé.
	Input.action_press("avancer")
	await _attendre(10)
	m.basculer()
	await _attendre(2)
	Input.action_release("avancer")
	_verifier(not m.est_monte() and messages.size() > 0 and String(messages[-1]).contains("immobile"),
			"on ne peut pas appeler sa monture en courant")
	await _attendre(20)

	# Appel immobile : 1,5 s puis en selle.
	m.basculer()
	await _attendre(30)
	_verifier(not m.est_monte(), "l'appel prend du temps (barre d'incantation)")
	await _attendre(80)
	_verifier(m.est_monte() and m.monture == "renne", "après 1,5 s, on est sur le renne")
	_verifier(m.get_node_or_null("Bete") != null, "le renne apparaît sous le personnage")
	await _attendre(10)
	_verifier(joueur.apparence.position.y > 0.3, "le cavalier est assis sur le dos (%.2f m)" % joueur.apparence.position.y)
	var squelette = joueur.apparence._squelette()
	_verifier(squelette.get_node_or_null("PoseCavalier") != null, "le cavalier prend la pose assise")
	var en_selle: float = await _vitesse(joueur)
	_verifier(_allure in ["Run", "Sprint"], "le renne galope (%s)" % _allure)
	_verifier(en_selle > a_pied * 1.5, "on va plus vite à dos de renne (%.1f m contre %.1f m)" % [en_selle, a_pied])

	# Une attaque fait tomber.
	joueur.combat.subir(5.0, null)
	await _attendre(3)
	_verifier(not m.est_monte(), "une attaque reçue fait tomber de la monture")
	_verifier(m.get_node_or_null("Bete") == null or m.get_node("Bete").is_queued_for_deletion(), "le renne disparaît")
	await _attendre(5)
	_verifier(joueur.apparence.position == Vector3.ZERO, "le personnage revient au sol")
	m.basculer()
	await _attendre(5)
	_verifier(not m.est_monte() and m._appel_id == "", "pas de nouvel appel pendant le combat")

	# Après le combat (5 s), on peut remonter puis descendre avec V.
	await _attendre(400)
	m.basculer()
	await _attendre(110)
	_verifier(m.est_monte(), "hors combat, on peut remonter")
	m.basculer()
	await _attendre(5)
	_verifier(not m.est_monte(), "V à nouveau : on descend")
	await _vider(scene)

	# --- Égypte : l'âne ---
	scene = await _charger("res://scenes/monde/egypte/port_des_marais.tscn")
	joueur = get_first_node_in_group("joueur_local")
	m = joueur.get_node("Monture")
	_verifier(Monture.monture_du_lieu(self) == "ane", "la monture du Port des Marais est l'âne")
	await _attendre(30)
	m.basculer()
	await _attendre(110)
	_verifier(m.monture == "ane", "on monte sur l'âne en Égypte")
	var bete = m.get_node_or_null("Bete")
	var bois_caches := true
	if bete != null:
		for mi in bete.find_children("Chifre*", "MeshInstance3D", true, false):
			bois_caches = bois_caches and not mi.visible
	_verifier(bete != null and bois_caches, "l'âne n'a pas de bois")
	_verifier(bete != null and bete._anim != null and bete._anim.has_animation("H_Walk"), "c'est le vrai modèle d'âne (WildMesh 3D)")
	Input.action_press("avancer")
	await _attendre(60)
	_verifier(bete != null and bete._courante in ["H_Canter", "H_Gallop", "H_Sprint"], "l'âne galope (%s, %.1f m/s naturels)" % [bete._courante, bete._vitesses_ref.get(bete._courante, 0.0)])
	Input.action_release("avancer")
	await _attendre(20)
	_verifier(bete._courante == "H_Idle_01", "l'âne s'arrête (%s)" % bete._courante)
	await _vider(scene)

	# --- Donjon et ville : refusé ---
	scene = await _charger("res://scenes/monde/prehistoire/grotte.tscn")
	_verifier(Monture.lieu(self) == "donjon", "la Grande Grotte est un donjon")
	joueur = get_first_node_in_group("joueur_local")
	joueur.get_node("Monture").basculer()
	await _attendre(110)
	_verifier(not joueur.get_node("Monture").est_monte(), "pas de monture dans la Grande Grotte")
	await _vider(scene)

	scene = await _charger("res://scenes/monde/colline_de_test.tscn")
	_verifier(Monture.monture_du_lieu(self) == "", "pas de monture hors des îles")
	await _vider(scene)

	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
