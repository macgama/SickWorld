extends SceneTree
## Test automatique de la Côte Gelée (Préhistoire, zone 1) et du chapitre 1 de la
## quête principale : arrivée devant le portail, Lenoir blessé, trousse de soin,
## soins, loups fracturés, fermeture de la faille, rapport, puis piste vers le col.
## Lancement : godot --headless --path game -s res://tests/test_cote_gelee.gd

const FICHIER := "user://test_prehistoire_progression.cfg"

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
	var ile = _scene
	var p: Vector3 = cible.global_position + Vector3(0, 0, 1.6)
	p.y = ile.hauteur(p.x, p.z) + 0.3
	await _placer(p, 0.0)


func _id_etape() -> String:
	return _quete.etape_actuelle().get("id", "")


func _fractures_vivants(prefixe: String) -> Array:
	var liste := []
	for loup in get_nodes_in_group("loups"):
		if String(loup.type_ennemi).begins_with(prefixe) and loup.combat.est_vivant():
			liste.append(loup)
	return liste


func _lancer() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	_scene = load("res://scenes/monde/prehistoire/cote_gelee.tscn").instantiate()
	_quete = _scene.get_node("Quete")
	_quete.fichier_progression = FICHIER
	_quete.voyage_reel = false
	root.add_child(_scene)
	await _attendre(40)
	_joueur = get_first_node_in_group("joueur_local")
	_dialogue = get_first_node_in_group("dialogue")
	print("Test de la Côte Gelée (Préhistoire)")

	# --- Le monde.
	_verifier(_joueur != null, "un personnage arrive sur l'île")
	_verifier(_joueur.is_on_floor(), "il est posé sur les galets")
	var p: Vector3 = _joueur.global_position
	_verifier(Vector2(p.x, p.z).distance_to(_scene.PORTAIL) < 9.0, "juste devant le portail de la Vigie")
	_verifier(_scene.hauteur(0, 120) < -3.0, "la mer est au sud")
	_verifier(_scene.hauteur(-120, 0) > 15.0 and _scene.hauteur(125, 0) > 15.0, "des falaises à l'ouest et à l'est")
	_verifier(_scene.hauteur(0, -60) > p.y + 4.0, "le plateau monte vers le nord")
	_verifier(get_first_node_in_group("balises") != null, "une balise de la Vigie permet de réapparaître")
	_verifier(_fractures_vivants("loup_fracture").size() == 4, "quatre loups fracturés rôdent autour du camp")
	_verifier(_fractures_vivants("loup").size() >= 10, "des loups sauvages vivent sur le plateau")

	# Le joueur peut marcher vers le nord.
	await _placer(Vector3(0, _scene.hauteur(0, 41) + 0.3, 41), 0.0)
	Input.action_press("avancer")
	await _attendre(60)
	Input.action_release("avancer")
	await _attendre(5)
	_verifier(_joueur.global_position.z < 38.0, "il avance dans la neige (z = %.1f)" % _joueur.global_position.z)

	# On ne peut pas partir à la nage.
	await _placer(Vector3(0, _scene.hauteur(0, 55) + 0.3, 55), PI)
	Input.action_press("avancer")
	await _attendre(240)
	Input.action_release("avancer")
	await _attendre(5)
	_verifier(_joueur.global_position.y > -1.6, "un mur invisible l'arrête dans l'eau peu profonde (y = %.2f)" % _joueur.global_position.y)

	# --- Chapitre 1.
	_verifier(_id_etape() == "retrouver_lenoir", "la quête commence : retrouver Lenoir (%s)" % _id_etape())
	_verifier(_quete._objectif.visible and _quete._texte_objectif.text != "", "objectif : « %s »" % _quete._texte_objectif.text)
	var lenoir = _scene.find_child("Lenoir", true, false)
	_verifier(lenoir != null and lenoir.blesse, "l'agent Lenoir est blessé, au sol")
	await _aller_pres(lenoir)
	await _appuyer_f()
	var lues := await _lire_dialogue()
	_verifier(lues >= 4, "Lenoir raconte l'attaque (%d bulles)" % lues)
	_verifier(_id_etape() == "trousse", "il faut récupérer la trousse (%s)" % _id_etape())

	var trousse = _scene.find_child("Trousse", true, false)
	await _aller_pres(trousse)
	await _appuyer_f()
	_verifier(_id_etape() == "soigner", "trousse ramassée, il faut soigner Lenoir (%s)" % _id_etape())

	# Les soins sont interrompus si on bouge.
	await _aller_pres(lenoir)
	await _appuyer_f()
	_verifier(_quete._canalisation != null, "les soins commencent")
	await _placer(_joueur.global_position + Vector3(2, 0, 0), 0.0)
	await _attendre(5)
	_verifier(_quete._canalisation == null and _id_etape() == "soigner", "bouger interrompt les soins")
	await _aller_pres(lenoir)
	await _appuyer_f()
	await _attendre(200)
	_verifier(not lenoir.blesse, "Lenoir est soigné et se relève")
	_verifier(_dialogue.est_ouvert(), "il explique les règles et le combat")
	lues = await _lire_dialogue()
	_verifier(lues >= 5, "(%d bulles)" % lues)
	_verifier(_id_etape() == "fractures", "il faut éliminer les fracturés (%s)" % _id_etape())
	_verifier(_quete._texte_objectif.text.ends_with("(0/4)"), "compteur : %s" % _quete._texte_objectif.text)

	var combat_joueur = _joueur.get_node("Combat")
	for loup in _fractures_vivants("loup_fracture"):
		loup.combat.subir(9999.0, combat_joueur)
		await _attendre(3)
	await _attendre(5)
	_verifier(_id_etape() == "rapport_lenoir", "les 4 fracturés sont vaincus (%s)" % _id_etape())

	await _aller_pres(lenoir)
	await _appuyer_f()
	lues = await _lire_dialogue()
	_verifier(_id_etape() == "faille", "Lenoir envoie refermer la faille (%s)" % _id_etape())
	await _attendre(5)
	var sortis := _fractures_vivants("loup_fracture_faille")
	_verifier(sortis.size() == 2, "deux loups sortent de la faille (%d)" % sortis.size())
	for loup in sortis:
		loup.combat.subir(9999.0, combat_joueur)
	await _attendre(5)

	var faille = _scene.find_child("Faille", true, false)
	_verifier(faille != null and not faille.fermee, "la faille est ouverte")
	await _aller_pres(faille)
	await _appuyer_f()
	await _attendre(330)
	_verifier(faille.fermee, "la faille est refermée")
	_verifier(_id_etape() == "fin_chapitre_1", "rapport final (%s)" % _id_etape())
	await _aller_pres(lenoir)
	await _appuyer_f()
	lues = await _lire_dialogue()
	_verifier(lues >= 4, "Lenoir parle du clan du Bison (%d bulles)" % lues)
	_verifier(_id_etape() == "vers_le_col", "chapitre 2 : suivre la piste vers le col (%s)" % _id_etape())
	var repere: Vector3 = _quete._position_cible(_quete.etape_actuelle())
	_verifier(repere != null and repere.z < -120.0, "le repère doré montre le col (z = %.0f)" % (repere.z if repere != null else 0.0))

	# --- La progression est gardée : on recharge l'île.
	var cfg := ConfigFile.new()
	cfg.load(FICHIER)
	_verifier(cfg.get_value("prehistoire", "etape", "") == "vers_le_col", "l'avancement est enregistré")
	_scene.queue_free()
	await _attendre(5)
	_scene = load("res://scenes/monde/prehistoire/cote_gelee.tscn").instantiate()
	_quete = _scene.get_node("Quete")
	_quete.fichier_progression = FICHIER
	_quete.voyage_reel = false
	root.add_child(_scene)
	await _attendre(40)
	_joueur = get_first_node_in_group("joueur_local")
	_dialogue = get_first_node_in_group("dialogue")
	_verifier(_id_etape() == "vers_le_col", "au retour, la quête reprend où on l'avait laissée")
	_verifier(not _scene.find_child("Lenoir", true, false).blesse, "Lenoir est toujours debout")
	_verifier(_scene.find_child("Faille", true, false).fermee, "la faille est toujours fermée")

	# Le col.
	await _placer(Vector3(10, _scene.hauteur(10, -142) + 0.5, -142), 0.0)
	await _attendre(70)
	_verifier(_quete.zone_demandee == "steppe", "le col mène à la Steppe des Mammouths (%s)" % _quete.zone_demandee)
	_verifier(_id_etape() == "vers_le_col", "l'étape se termine en arrivant dans la Steppe, pas avant")

	# Retour au hub par le portail.
	_verifier(_scene._portail_arme, "le portail de retour s'active quand on s'en est éloigné")
	await _placer(Vector3(0, _scene.hauteur(0, 43) + 0.3, 43), PI)
	Input.action_press("avancer")
	await _attendre(80)
	Input.action_release("avancer")
	await _attendre(5)
	_verifier(_quete._en_voyage, "traverser le portail ramène à Hikari Bay")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
