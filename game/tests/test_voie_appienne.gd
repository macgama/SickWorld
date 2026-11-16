extends SceneTree
## Test automatique de la voie Appienne (Rome, zone 1) et des chapitres 1 et 2 :
## la radio de Livia, les loups et le lion qui attaquent les réfugiés de Pompéi, l'escorte
## jusqu'au relais de Petronius, puis les Égarés de la cour (puzzle de mots), les bornes
## milliaires, la faille, le glaive de Petronius et l'arrivée de l'agent Livia Conti.
## Lancement : godot --headless --path game -s res://tests/test_voie_appienne.gd

const FICHIER := "user://test_rome_progression.cfg"
const SCENE := "res://scenes/monde/rome/voie_appienne.tscn"

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


func _aller_pres(cible: Node3D, decalage := Vector3(0, 0, 1.6)) -> void:
	var p: Vector3 = cible.global_position + decalage
	p.y = maxf(_scene.hauteur(p.x, p.z), cible.global_position.y) + 0.3
	await _placer(p, 0.0)


func _parler(id_noeud: String) -> int:
	var pnj = _scene.find_child(id_noeud, true, false)
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


func _tuer(type: String, combat_joueur, etape: String) -> void:
	for k in 30:
		var vivants := _vivants(type)
		if vivants.is_empty() or _id_etape() != etape:
			break
		vivants[0].combat.subir(999999.0, combat_joueur)
		await _attendre(4)
	await _attendre(5)


func _charger() -> void:
	_scene = load(SCENE).instantiate()
	_quete = _scene.get_node("Quete")
	_quete.fichier_progression = FICHIER
	_quete.voyage_reel = false
	root.add_child(_scene)
	await _attendre(40)
	_joueur = get_first_node_in_group("joueur_local")
	_dialogue = get_first_node_in_group("dialogue")


func _lancer() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	await _charger()
	print("Test de la voie Appienne (Rome)")

	# --- Le monde.
	_verifier(_joueur != null, "un personnage arrive sur l'île")
	var p: Vector3 = _joueur.global_position
	_verifier(Vector2(p.x, p.z).distance_to(_scene.PORTAIL) < 9.0, "juste devant le portail de la Vigie")
	_verifier(_joueur.is_on_floor(), "il a les pieds sur terre (y = %.2f)" % p.y)
	_verifier(_scene.find_child("TombeauCaeciliaMetella", true, false) != null, "le grand tombeau rond de Caecilia Metella borde la route")
	_verifier(_scene.find_child("TombeauDuPortail", true, false) != null, "le portail s'est ouvert devant un vieux tombeau")
	_verifier(_scene.find_child("Chaussee", true, false) != null, "la voie est pavée de dalles de basalte")
	_verifier(_scene.find_child("Mansio", true, false) != null, "le relais de poste de Petronius est construit")
	_verifier(_scene.find_child("AqueducsLointains", true, false) != null, "les arches des aqueducs se voient au loin")
	var nb_arbres: int = _scene.find_child("Arbres", true, false).get_child_count()
	_verifier(nb_arbres >= 40, "des pins parasols et des cyprès bordent la route (%d)" % nb_arbres)
	var nb_tombeaux: int = _scene.find_child("Tombeaux", true, false).get_child_count()
	_verifier(nb_tombeaux >= 12, "des tombeaux le long de la route (%d)" % nb_tombeaux)
	_verifier(get_first_node_in_group("balises") != null, "une balise de la Vigie permet de réapparaître")
	_verifier(_vivants("loup_fracture_appia").size() >= 8, "des loups fracturés rôdent dans la campagne (%d)" % _vivants("loup_fracture_appia").size())
	# La route est praticable d'un bout à l'autre, sans marche brusque.
	var pente_max := 0.0
	for z in range(-150, 150, 3):
		var c: Vector2 = _scene._point_voie(float(z))
		pente_max = maxf(pente_max, absf(_scene.hauteur(c.x, c.y) - _scene.hauteur(c.x, c.y + 3.0)))
	_verifier(pente_max < 0.6, "la voie monte et descend en douceur (marche max %.2f m)" % pente_max)
	_verifier(_scene.hauteur(_scene.MANSIO.get_center().x, _scene.MANSIO.get_center().y) > 2.0, "la cour du relais est au sec")

	# --- Chapitre 1 : La voie des tombeaux.
	var combat_joueur = _joueur.get_node("Combat")
	_verifier(_id_etape() == "radio_livia", "la quête commence : la radio de la Vigie (%s)" % _id_etape())
	await _aller_pres(_scene.find_child("RadioVigie", true, false))
	await _appuyer_f()
	await _attendre(130)
	_verifier(_id_etape() == "vers_voie", "la radio de Livia parle (%s)" % _id_etape())
	await _placer(Vector3(5, _scene.hauteur(5, 93) + 0.4, 93), PI)
	await _attendre(20)
	_verifier(_id_etape() == "loups_convoi", "sur la voie, des loups attaquent le convoi (%s)" % _id_etape())
	await _attendre(5)
	_verifier(_vivants("loup_fracture_convoi").size() == 3, "trois loups encerclent la charrette (%d)" % _vivants("loup_fracture_convoi").size())
	await _tuer("loup_fracture_convoi", combat_joueur, "loups_convoi")
	_verifier(_id_etape() == "lion", "les loups sont chassés : le lion surgit (%s)" % _id_etape())
	await _attendre(5)
	var lions := _vivants("lion_fracture")
	_verifier(lions.size() == 1, "un lion fracturé attaque")
	if lions.size() == 1:
		var apparence: Node = lions[0].get_node("Apparence")
		_verifier(apparence.find_child("Criniere", true, false) != null, "le lion a une crinière")
		_verifier(lions[0].scale.x > 0.99 and apparence.scale.x > 1.2, "il est plus grand qu'un loup")
	await _tuer("lion_fracture", combat_joueur, "lion")
	_verifier(_id_etape() == "rencontre_caecilia", "le lion est abattu (%s)" % _id_etape())
	var lues := await _parler("Caecilia")
	_verifier(lues >= 4, "Caecilia raconte Pompéi (%d bulles)" % lues)
	_verifier(_id_etape() == "escorte_refugies", "il faut escorter les réfugiés (%s)" % _id_etape())
	# L'escorte : on reste près de la charrette jusqu'au relais.
	var charrette: Node3D = _scene.find_child("CharretteRefugies", true, false)
	var images := 0
	while _id_etape() == "escorte_refugies" and images < 6000:
		images += 1
		if images % 30 == 0:
			for bete in _vivants("loup_fracture_convoi"):
				bete.combat.subir(999999.0, combat_joueur)
			var c := charrette.global_position + Vector3(2.5, 0, 0)
			_joueur.teleporter(Vector3(c.x, _scene.hauteur(c.x, c.z) + 0.4, c.z), 0.0)
		await physics_frame
	_verifier(_id_etape() == "rencontre_petronius", "les réfugiés arrivent au relais (%s, %d images)" % [_id_etape(), images])
	_verifier(Vector2(charrette.global_position.x, charrette.global_position.z).distance_to(Vector2(4, -14)) < 1.0, "la charrette est garée devant la porte")
	lues = await _parler("Petronius")
	_verifier(lues >= 3, "Petronius accueille l'étranger (%d bulles)" % lues)

	# --- Chapitre 2 : Les mots brisés.
	_verifier(_id_etape() == "petronius_dispute", "chapitre 2 : Petronius a un problème (%s)" % _id_etape())
	await _parler("Petronius")
	_verifier(_id_etape() == "renouer", "il faut renouer les Égarés de la cour (%s)" % _id_etape())
	var puzzle = null
	for k in 4:
		var objet: Node3D = _scene.find_child("Renouer%d" % k, true, false)
		await _aller_pres(objet, Vector3(0, 0, 1.2))
		await _appuyer_f()
		await _attendre(3)
		puzzle = _quete.puzzle_mots()
		_verifier(puzzle != null and puzzle.est_ouvert(), "l'Égaré %d : la fenêtre des mots s'ouvre" % (k + 1))
		if puzzle == null:
			break
		if k == 0:
			# Une mauvaise réponse : la phrase repart de zéro.
			var mauvais := -1
			for i in puzzle._ordre.size():
				if puzzle._ordre[i] != 0:
					mauvais = i
					break
			puzzle.choisir(mauvais)
			_verifier(puzzle._place == 0 and puzzle.est_ouvert(), "un mot dans le désordre : on recommence")
			_verifier(_quete.compteur == 0, "rien n'est compté tant que la phrase est fausse")
		puzzle.resoudre()
		await _attendre(60)
		_verifier(_quete.compteur == k + 1 or _id_etape() != "renouer", "l'Égaré %d est renoué (%d/4)" % [k + 1, _quete.compteur])
	_verifier(_id_etape() == "petronius_bornes", "les quatre Égarés se comprennent (%s)" % _id_etape())
	await _parler("Petronius")
	_verifier(_id_etape() == "bornes", "les bornes milliaires sont renversées (%s)" % _id_etape())
	for k in 3:
		var borne: Node3D = _scene.find_child("Milliaire%d" % k, true, false)
		for bete in _vivants("loup_fracture_appia"):
			if bete.global_position.distance_to(borne.global_position) < 30.0:
				bete.combat.subir(999999.0, combat_joueur)
		await _attendre(3)
		await _aller_pres(borne, Vector3(0, 0, 1.4))
		await _appuyer_f()
		await _attendre(220)
		_verifier(borne.get_node_or_null("Debout") != null and borne.get_node("Debout").visible, "la borne %d est redressée" % (k + 1))
	_verifier(_id_etape() == "faille", "les trois bornes sont debout (%s)" % _id_etape())
	await _attendre(5)
	await _tuer("loup_fracture_faille_appia", combat_joueur, "faille")
	var faille = _scene.find_child("Faille", true, false)
	await _aller_pres(faille)
	await _appuyer_f()
	await _attendre(360)
	_verifier(faille.fermee, "la faille de la voie est refermée")
	_verifier(_id_etape() == "recompense_petronius", "retour chez Petronius (%s)" % _id_etape())
	var livia: Node3D = _scene.find_child("Livia", true, false)
	_verifier(livia != null and livia.visible, "une femme attend dans la cour : l'agent Livia Conti")
	await _parler("Petronius")
	var inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("glaive_petronius") >= 1, "le glaive de Petronius est dans le sac")
		_verifier(inventaire.quantite("caligae_petronius") >= 1, "ses sandales cloutées aussi")
	_verifier(_id_etape() == "rencontre_livia", "Livia veut parler (%s)" % _id_etape())
	lues = await _parler("Livia")
	_verifier(lues >= 4, "Livia parle des aqueducs (%d bulles)" % lues)
	_verifier(_id_etape() == "vers_campagne", "chapitres 1 et 2 terminés : en route vers la campagne (%s)" % _id_etape())
	await _attendre(30)
	_verifier(_scene._nord_ouvert, "la route du nord s'ouvre")
	var nord: Vector2 = _scene.SORTIE_NORD
	await _placer(Vector3(nord.x, _scene.hauteur(nord.x, nord.y + 12.0) + 0.4, nord.y + 12.0), 0.0)
	Input.action_press("avancer")
	await _attendre(150)
	Input.action_release("avancer")
	_verifier(_quete.zone_demandee == "campagne", "la voie mène à la campagne et aux aqueducs (%s)" % _quete.zone_demandee)

	# --- La progression est gardée.
	var cfg := ConfigFile.new()
	cfg.load(FICHIER)
	_verifier(cfg.has_section("rome"), "l'avancement est enregistré dans la section « rome »")
	_verifier(cfg.get_value("grece", "etape", "") == "", "la Grèce n'est pas touchée")
	_scene.queue_free()
	await _attendre(5)
	await _charger()
	_verifier(_id_etape() == "vers_campagne", "au retour, la quête reprend où on l'avait laissée (%s)" % _id_etape())
	_verifier(_scene.find_child("Faille", true, false).fermee, "la faille est toujours fermée")
	_verifier(_scene.find_child("Livia", true, false).visible, "Livia est toujours au relais")
	var borne_rechargee: Node3D = _scene.find_child("Milliaire1", true, false)
	_verifier(borne_rechargee.get_node_or_null("Debout") != null and borne_rechargee.get_node("Debout").visible, "les bornes restent debout")
	var c2: Node3D = _scene.find_child("CharretteRefugies", true, false)
	_verifier(Vector2(c2.global_position.x, c2.global_position.z).distance_to(Vector2(4, -14)) < 1.0, "la charrette est toujours devant le relais")

	# Retour au hub par le portail (après s'en être éloigné).
	await _placer(Vector3(-20, _scene.hauteur(-20, 100) + 0.3, 100), 0.0)
	await _attendre(5)
	_verifier(_scene._portail_arme, "le portail de retour s'active quand on s'en est éloigné")
	await _placer(Vector3(_scene.PORTAIL.x, _scene.hauteur(_scene.PORTAIL.x, _scene.PORTAIL.y - 6) + 0.3, _scene.PORTAIL.y - 6), PI)
	Input.action_press("avancer")
	await _attendre(90)
	Input.action_release("avancer")
	await _attendre(5)
	_verifier(_quete._en_voyage, "traverser le portail ramène à Hikari Bay")

	print("")
	if _echecs == 0:
		print("TOUS LES TESTS PASSENT")
	else:
		print("%d ÉCHEC(S)" % _echecs)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	quit(1 if _echecs > 0 else 0)
