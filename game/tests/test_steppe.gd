extends SceneTree
## Test automatique de la Steppe des Mammouths (Préhistoire, zone 2) et des
## chapitres 2 et 3 de la quête principale : arrivée par le col, Toran méfiant,
## chasse aux rennes, la lance de Toran, le gué, le camp d'été, le rêve d'Aïna,
## les pigments (ocre, charbon, manganèse) et la main peinte.
## Lancement : godot --headless --path game -s res://tests/test_steppe.gd

const FICHIER := "user://test_steppe_progression.cfg"

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
	p.y = _scene.hauteur(p.x, p.z) + 0.3
	await _placer(p, 0.0)


func _id_etape() -> String:
	return _quete.etape_actuelle().get("id", "")


func _vivants(prefixe: String) -> Array:
	var liste := []
	for bete in get_nodes_in_group("loups"):
		if String(bete.type_ennemi).begins_with(prefixe) and bete.combat.est_vivant():
			liste.append(bete)
	return liste


func _charger() -> void:
	_scene = load("res://scenes/monde/prehistoire/steppe.tscn").instantiate()
	_quete = _scene.get_node("Quete")
	_quete.fichier_progression = FICHIER
	_quete.voyage_reel = false
	root.add_child(_scene)
	await _attendre(40)
	_joueur = get_first_node_in_group("joueur_local")
	_dialogue = get_first_node_in_group("dialogue")


func _recolter_tout(groupe: String) -> int:
	var faits := 0
	for objet in get_nodes_in_group("objet_quete"):
		if objet.groupe != groupe or objet.ramasse:
			continue
		await _aller_pres(objet)
		await _appuyer_f()
		await _attendre(int(float(_quete.etape_actuelle().get("duree", 0)) * 60) + 20)
		faits += 1
	return faits


func _lancer() -> void:
	# On arrive du col : le chapitre 1 est fini, l'étape « vers_le_col » est en cours.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	var cfg := ConfigFile.new()
	cfg.set_value("prehistoire", "etape", "vers_le_col")
	cfg.save(FICHIER)
	await _charger()
	print("Test de la Steppe des Mammouths (Préhistoire)")

	# --- Le monde.
	_verifier(_joueur != null and _joueur.is_on_floor(), "un personnage arrive par le col, posé sur l'herbe")
	var p: Vector3 = _joueur.global_position
	_verifier(p.z > 140.0, "au sud de la steppe (z = %.0f)" % p.z)
	_verifier(_scene.hauteur(_scene.GUE_X, _scene.riviere_z(_scene.GUE_X)) > -0.5, "le gué est peu profond")
	_verifier(_scene.hauteur(-60, _scene.riviere_z(-60)) < -0.7, "ailleurs, la rivière est plus profonde")
	_verifier(_scene.hauteur(0, -175) > 25.0 and _scene.hauteur(175, 0) > 20.0, "des montagnes ferment la steppe")
	_verifier(get_nodes_in_group("mammouths").size() >= 5, "un troupeau de mammouths broute (%d)" % get_nodes_in_group("mammouths").size())
	_verifier(_vivants("renne").size() >= 6, "des rennes paissent (%d)" % _vivants("renne").size())
	_verifier(_vivants("loup_fracture").size() == 3, "des loups fracturés rôdent près des rochers noirs")
	_verifier(get_first_node_in_group("balises") != null, "une balise de la Vigie près du col")
	var mammouth: Node3D = get_nodes_in_group("mammouths")[0]
	var depart_mammouth := mammouth.global_position
	await _attendre(400)
	_verifier(mammouth.global_position.distance_to(depart_mammouth) > 0.3, "les mammouths se déplacent")

	# --- Chapitre 2.
	_verifier(_id_etape() == "rencontre_toran", "arrivé dans la steppe, il faut rejoindre la partie de chasse (%s)" % _id_etape())
	var toran = _scene.find_child("Toran", true, false)
	_verifier(toran != null and toran.global_position.distance_to(_joueur.global_position) < 45.0, "Toran attend près du col")
	await _aller_pres(toran)
	await _appuyer_f()
	var lues := await _lire_dialogue()
	_verifier(lues >= 4, "Toran se méfie (%d bulles)" % lues)
	_verifier(_id_etape() == "chasse_renne", "il faut chasser trois rennes (%s)" % _id_etape())
	var ulm = _scene.find_child("Ulm", true, false)
	_verifier(Vector2(ulm.global_position.x, ulm.global_position.z).distance_to(_scene.RENNES) < 20.0, "les chasseurs partent vers les rennes")

	# Un renne s'enfuit quand on s'approche.
	var renne = _vivants("renne")[0]
	var avant: Vector3 = renne.global_position
	await _placer(avant + Vector3(3, 0.5, 0), 0.0)
	await _attendre(90)
	_verifier(renne.global_position.distance_to(_joueur.global_position) > 5.0, "le renne s'enfuit (%.1f m)" % renne.global_position.distance_to(_joueur.global_position))
	var pv_joueur: float = _joueur.get_node("Combat").pv
	_verifier(pv_joueur >= _joueur.get_node("Combat").pv_max - 0.1, "un renne n'attaque pas")

	var combat_joueur = _joueur.get_node("Combat")
	for k in 3:
		_vivants("renne")[0].combat.subir(9999.0, combat_joueur)
		await _attendre(3)
	await _attendre(5)
	_verifier(_id_etape() == "toran_confiance", "trois rennes abattus (%s)" % _id_etape())
	await _aller_pres(toran)
	await _appuyer_f()
	lues = await _lire_dialogue()
	_verifier(lues >= 4, "Toran accepte le Venu-du-Brouillard (%d bulles)" % lues)
	var inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("lance_silex") >= 1, "Toran donne sa lance")
	_verifier(Vector2(toran.global_position.x, toran.global_position.z).distance_to(_scene.CAMP) < 10.0, "Toran rentre au camp")
	_verifier(_id_etape() == "vers_le_camp", "direction le camp d'été (%s)" % _id_etape())

	# Traverser le gué à pied.
	var zg: float = _scene.riviere_z(_scene.GUE_X)
	await _placer(Vector3(_scene.GUE_X, _scene.hauteur(_scene.GUE_X, zg + 12) + 0.3, zg + 12), 0.0)
	Input.action_press("avancer")
	await _attendre(260)
	Input.action_release("avancer")
	await _attendre(5)
	_verifier(_joueur.global_position.z < zg - 8.0, "on traverse le gué à pied (z = %.1f)" % _joueur.global_position.z)
	await _placer(Vector3(26, _scene.hauteur(26, -46) + 0.3, -46), 0.0)
	await _attendre(5)

	# --- Chapitre 3.
	_verifier(_id_etape() == "aina_reve", "au camp, Aïna attend (%s)" % _id_etape())
	var aina = _scene.find_child("Aina", true, false)
	await _aller_pres(aina)
	await _appuyer_f()
	lues = await _lire_dialogue()
	_verifier(lues >= 5, "Aïna raconte son rêve (%d bulles)" % lues)
	_verifier(_id_etape() == "ocre", "il faut de l'ocre (%s)" % _id_etape())
	_verifier(_quete._texte_objectif.text.ends_with("(0/3)"), "compteur : %s" % _quete._texte_objectif.text)
	var cible = _quete._position_cible(_quete.etape_actuelle())
	_verifier(cible != null, "le repère montre l'ocre la plus proche")
	var faits := await _recolter_tout("ocre")
	_verifier(_id_etape() == "charbon", "trois veines d'ocre récoltées (%d, %s)" % [faits, _id_etape()])
	await _recolter_tout("charbon")
	_verifier(_id_etape() == "manganese", "charbon pris dans le vieux foyer (%s)" % _id_etape())
	for loup in _vivants("loup_fracture"):
		loup.combat.subir(9999.0, combat_joueur)
	await _attendre(5)
	await _recolter_tout("manganese")
	_verifier(_id_etape() == "peinture", "pierre noire récoltée (%s)" % _id_etape())
	var main := _scene.find_child("MainPeinte", true, false) as Node3D
	_verifier(main != null and not main.visible, "la paroi est encore vierge")
	await _aller_pres(aina)
	await _appuyer_f()
	lues = await _lire_dialogue()
	_verifier(lues >= 5, "Aïna peint et parle de Kéo (%d bulles)" % lues)
	_verifier(main.visible, "une main peinte apparaît sur la paroi")
	_verifier(_quete.etape == -1, "fin des chapitres disponibles")

	# --- Rechargement : tout reste en place.
	_scene.queue_free()
	await _attendre(5)
	await _charger()
	_verifier(_quete.etape == -1, "la progression est gardée")
	toran = _scene.find_child("Toran", true, false)
	_verifier(Vector2(toran.global_position.x, toran.global_position.z).distance_to(_scene.CAMP) < 10.0, "Toran est au camp")
	_verifier(_scene.find_child("MainPeinte", true, false).visible, "la main peinte est toujours là")

	# --- Retour vers la Côte Gelée par le col.
	await _placer(Vector3(0, _scene.hauteur(0, 172) + 0.5, 172), 0.0)
	await _attendre(70)
	_verifier(_quete.zone_demandee == "cote_gelee", "le col ramène à la Côte Gelée (%s)" % _quete.zone_demandee)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
