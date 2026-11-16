extends SceneTree
## Test automatique des Oliveraies d'Attique (Grèce, zone 2) et du chapitre 3 :
## la porte des Longs Murs s'ouvre au Pirée, la route entre les murs, Myrtô et Néra,
## le masque, les sangliers de l'Hymette, Théano et la faille de la Moria, la couronne,
## Néra retrouve la voix, puis la porte d'Athènes, gardée par un muet, que Socrate
## convainc d'ouvrir.
## Lancement : godot --headless --path game -s res://tests/test_oliveraies.gd

const FICHIER := "user://test_grece_oliveraies.cfg"
const PIREE := "res://scenes/monde/grece/le_piree.tscn"
const OLIVERAIES := "res://scenes/monde/grece/oliveraies.tscn"

var _echecs := 0
var _scene: Node
var _joueur
var _quete
var _dialogue


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


func _placer(position: Vector3, angle: float) -> void:
	_joueur.teleporter(position, angle)
	_joueur.camera.lacet = angle
	await _attendre(10)
	var images := 0
	while not _joueur.is_on_floor() and images < 90:
		images += 1
		await physics_frame
	await _attendre(3)


func _appuyer_f() -> void:
	var appui := InputEventAction.new()
	appui.action = "interagir"
	appui.pressed = true
	Input.parse_input_event(appui)
	await _attendre(3)
	var relache := InputEventAction.new()
	relache.action = "interagir"
	relache.pressed = false
	Input.parse_input_event(relache)
	await _attendre(2)


func _lire_dialogue() -> int:
	var lues := 0
	while _dialogue.est_ouvert() and lues < 30:
		lues += 1
		await _appuyer_f()
	return lues


func _aller_pres(cible: Node3D) -> void:
	var p: Vector3 = cible.global_position + Vector3(0, 0, 1.6)
	p.y = maxf(_scene.hauteur(p.x, p.z), cible.global_position.y) + 0.3
	await _placer(p, 0.0)


func _parler(id_noeud: String) -> int:
	var pnj = _scene.find_child(id_noeud, true, false)
	if pnj == null:
		print("  (PNJ introuvable : %s)" % id_noeud)
		return 0
	await _aller_pres(pnj)
	await _appuyer_f()
	return await _lire_dialogue()


func _id_etape() -> String:
	return _quete.etape_actuelle().get("id", "")


func _vivants(type: String) -> Array:
	var liste := []
	for bete in get_nodes_in_group("loups"):
		if String(bete.type_ennemi) == type and bete.combat.est_vivant():
			liste.append(bete)
	return liste


func _charger(scene: String) -> void:
	if _scene != null and is_instance_valid(_scene):
		_scene.queue_free()
		await _attendre(5)
	_scene = load(scene).instantiate()
	_quete = _scene.get_node("Quete")
	_quete.fichier_progression = FICHIER
	_quete.voyage_reel = false
	root.add_child(_scene)
	await _attendre(40)
	_joueur = get_first_node_in_group("joueur_local")
	_dialogue = get_first_node_in_group("dialogue")


func _tuer_tous(type: String, etape: String) -> void:
	var combat_joueur = _joueur.get_node("Combat")
	for passe in 4:
		for bete in _vivants(type):
			bete.combat.subir(99999.0, combat_joueur)
			await _attendre(3)
			if _id_etape() != etape:
				return
		await _attendre(20)


func _lancer() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	# On reprend juste après le chapitre 2 : la route d'Athènes s'ouvre.
	var cfg := ConfigFile.new()
	cfg.set_value("grece", "etape", "vers_athenes")
	cfg.save(FICHIER)
	await _charger(PIREE)
	print("Test des Oliveraies d'Attique (Grèce, chapitre 3)")

	# --- Au Pirée, la porte des Longs Murs est ouverte.
	_verifier(_id_etape() == "vers_athenes", "la quête reprend au chapitre 3 (%s)" % _id_etape())
	await _attendre(30)
	_verifier(_scene._porte_ouverte, "la porte des Longs Murs s'est ouverte")
	var porte: Vector2 = _scene.PORTE
	await _placer(Vector3(porte.x, _scene.hauteur(porte.x, porte.y - 10) + 0.4, porte.y - 10), 0.0)
	await _attendre(90)
	_verifier(_quete.zone_demandee == "oliveraies", "passer la porte mène aux Oliveraies (%s)" % _quete.zone_demandee)

	# --- Les Oliveraies.
	await _charger(OLIVERAIES)
	_verifier(_joueur != null and _joueur.is_on_floor(), "on arrive sur la route, entre les Longs Murs")
	var p: Vector3 = _joueur.global_position
	_verifier(absf(p.x) < _scene.MURS - 2.0 and p.z > 120.0, "au sud de la zone (%.0f, %.0f)" % [p.x, p.z])
	_verifier(_id_etape() == "route_markos", "l'arrivée termine l'étape de la porte (%s)" % _id_etape())
	_verifier(_scene.find_child("LongsMurs", true, false) != null, "les Longs Murs traversent la zone")
	_verifier(_scene.find_child("RempartAthenes", true, false) != null, "le rempart d'Athènes ferme le nord")
	_verifier(_scene.find_child("Moria", true, false) != null, "la Moria pousse dans le sanctuaire")
	_verifier(_scene.find_child("AcropoleLointaine", true, false) != null, "on voit l'Acropole au-dessus du rempart")
	_verifier(_scene.hauteur(150, 0) > _scene.hauteur(0, 0) + 15.0, "le mont Hymette s'élève à l'est (%.0f m)" % _scene.hauteur(150, 0))
	_verifier(_vivants("sanglier_fracture").size() >= 5, "des sangliers fracturés rôdent sur l'Hymette (%d)" % _vivants("sanglier_fracture").size())
	_verifier(_vivants("loup_fracture_oliveraie").size() >= 4, "des loups dans les oliveraies (%d)" % _vivants("loup_fracture_oliveraie").size())
	_verifier(_vivants("vipere_fracture").size() >= 3, "des vipères près du sanctuaire (%d)" % _vivants("vipere_fracture").size())
	var sanglier = _vivants("sanglier_fracture")[0] if not _vivants("sanglier_fracture").is_empty() else null
	_verifier(sanglier != null and sanglier.get_node("Apparence").get("espece") == "sanglier", "les sangliers ont un corps de sanglier")
	var vipere = _vivants("vipere_fracture")[0] if not _vivants("vipere_fracture").is_empty() else null
	_verifier(vipere != null and vipere.get_node("Apparence").get("_delegue").get("espece") == "vipere", "les vipères ont un corps de serpent")

	# On ne traverse pas les Longs Murs, sauf par les poternes.
	await _placer(Vector3(0, _scene.hauteur(0, 90) + 0.4, 90), PI / 2)
	Input.action_press("avancer")
	await _attendre(120)
	Input.action_release("avancer")
	_verifier(absf(_joueur.global_position.x) < _scene.MURS, "le mur arrête le joueur (x = %.1f)" % _joueur.global_position.x)
	var poterne: Vector2 = _scene.POTERNE_EST
	await _placer(Vector3(poterne.x - 5.0, _scene.hauteur(poterne.x - 5.0, poterne.y) + 0.4, poterne.y), -PI / 2)
	Input.action_press("avancer")
	await _attendre(120)
	Input.action_release("avancer")
	_verifier(_joueur.global_position.x > _scene.MURS + 2.0, "la poterne de l'est laisse passer (x = %.1f)" % _joueur.global_position.x)

	# --- Le chapitre 3.
	var lues := await _parler("Markos")
	_verifier(lues >= 3, "Markos raconte les Longs Murs (%d bulles)" % lues)
	_verifier(_id_etape() == "rencontre_myrto", "une femme appelle à l'aide (%s)" % _id_etape())
	lues = await _parler("Myrto")
	_verifier(lues >= 3, "Myrtô parle de sa fille muette (%d bulles)" % lues)
	_verifier(_id_etape() == "nera_muette", "il faut voir Néra (%s)" % _id_etape())
	await _parler("Nera")
	_verifier(_id_etape() == "masque", "Néra montre les ruches (%s)" % _id_etape())
	await _aller_pres(_scene.find_child("MasqueNera", true, false))
	await _appuyer_f()
	await _attendre(20)
	_verifier(_id_etape() == "sangliers", "le masque est trouvé (%s)" % _id_etape())
	_verifier(not _scene.find_child("MasqueNera", true, false).actif, "on garde le masque (il disparaît du sol)")
	await _tuer_tous("sanglier_fracture", "sangliers")
	await _attendre(5)
	_verifier(_id_etape() == "retour_myrto", "les sangliers sont chassés (%s)" % _id_etape())
	await _parler("Myrto")
	_verifier(_id_etape() == "pretresse", "Myrtô envoie chez Théano (%s)" % _id_etape())
	lues = await _parler("Pretresse")
	_verifier(lues >= 3, "Théano raconte la Moria (%d bulles)" % lues)
	_verifier(_id_etape() == "faille_moria", "il faut refermer la faille (%s)" % _id_etape())
	await _aller_pres(_scene.find_child("Faille", true, false))
	await _appuyer_f()
	await _attendre(380)
	_verifier(_id_etape() == "couronne_theano", "la faille de la Moria est refermée (%s)" % _id_etape())
	_verifier(_scene.find_child("Faille", true, false).fermee, "la faille ne brille plus")
	await _parler("Pretresse")
	var inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("couronne_olivier") >= 1, "la couronne d'olivier sacré est dans le sac")
	_verifier(_id_etape() == "nera_parle", "Théano envoie revoir Néra (%s)" % _id_etape())
	lues = await _parler("Nera")
	_verifier(lues >= 4, "Néra a retrouvé la voix (%d bulles)" % lues)
	_verifier(_id_etape() == "porte_athenes", "en route vers la porte d'Athènes (%s)" % _id_etape())
	await _attendre(10)
	var markos: Node3D = _scene.find_child("Markos", true, false)
	_verifier(markos != null and markos.global_position.z < -110.0, "Markos attend à la porte d'Athènes (z = %.0f)" % (markos.global_position.z if markos != null else 0.0))
	await _placer(Vector3(0, _scene.hauteur(0, -126) + 0.4, -126), 0.0)
	await _attendre(20)
	_verifier(_id_etape() == "garde_muet", "on arrive devant la porte (%s)" % _id_etape())
	lues = await _parler("GardePorte")
	_verifier(lues >= 3, "le garde est muet (%d bulles)" % lues)
	_verifier(_id_etape() == "socrate_porte", "un homme pieds nus arrive (%s)" % _id_etape())
	# Tant que Socrate n'a pas parlé au garde, la porte d'Athènes reste fermée.
	await _placer(Vector3(0, _scene.hauteur(0, -130) + 0.4, -130), 0.0)
	Input.action_press("avancer")
	await _attendre(120)
	Input.action_release("avancer")
	_verifier(_joueur.global_position.z > _scene.RAMPART_Z, "la porte d'Athènes est fermée (z = %.1f)" % _joueur.global_position.z)
	var socrate: Node3D = _scene.find_child("Socrate", true, false)
	_verifier(socrate != null and socrate.global_position.z > _scene.RAMPART_Z, "Socrate est arrivé devant la porte")
	lues = await _parler("Socrate")
	_verifier(lues >= 6, "Socrate convainc le garde par ses questions (%d bulles)" % lues)
	_verifier(_id_etape() == "entrer_athenes", "il faut entrer dans Athènes (%s)" % _id_etape())
	await _attendre(30)
	_verifier(_scene._porte_ouverte, "la porte d'Athènes s'est ouverte")
	await _placer(Vector3(0, _scene.hauteur(0, -134) + 0.4, -134), 0.0)
	Input.action_press("avancer")
	await _attendre(120)
	Input.action_release("avancer")
	await _attendre(60)
	_verifier(_quete.zone_demandee == "athenes", "passer la porte mène à Athènes (%s)" % _quete.zone_demandee)

	# --- La progression est gardée, et la route ramène au Pirée.
	await _charger(OLIVERAIES)
	_verifier(_id_etape() == "entrer_athenes", "au retour, la quête reprend où on l'avait laissée (%s)" % _id_etape())
	await _attendre(30)
	_verifier(_scene._porte_ouverte, "la porte d'Athènes reste ouverte")
	_verifier(_scene.find_child("Faille", true, false).fermee, "la faille de la Moria reste fermée")
	markos = _scene.find_child("Markos", true, false)
	_verifier(markos != null and markos.global_position.z < -110.0, "Markos est toujours à la porte")
	await _placer(Vector3(0, _scene.hauteur(0, 146) + 0.4, 146), PI)
	Input.action_press("avancer")
	await _attendre(90)
	Input.action_release("avancer")
	await _attendre(60)
	_verifier(_quete.zone_demandee == "le_piree", "la route du sud ramène au Pirée (%s)" % _quete.zone_demandee)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
