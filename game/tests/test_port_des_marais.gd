extends SceneTree
## Test automatique du Port des Marais (Égypte, zone 1) et des chapitres 1 et 2 :
## Farouk, le matériel dans les roseaux, les crocodiles, la balise, la faille,
## puis le port de Gizeh : Merer, Ânkhkhaf, le halage du bloc et l'hippopotame.
## Lancement : godot --headless --path game -s res://tests/test_port_des_marais.gd

const FICHIER := "user://test_egypte_progression.cfg"
const SCENE := "res://scenes/monde/egypte/port_des_marais.tscn"

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
	# Dans l'eau, le sol est plus bas que la surface : on attend qu'il ait pied.
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
	print("Test du Port des Marais (Égypte)")

	# --- Le monde.
	_verifier(_joueur != null, "un personnage arrive sur l'île")
	var p: Vector3 = _joueur.global_position
	_verifier(Vector2(p.x, p.z).distance_to(_scene.PORTAIL) < 9.0, "juste devant le portail de la Vigie")
	_verifier(_joueur.is_on_floor(), "il a pied dans le marais (y = %.2f)" % p.y)
	_verifier(_scene.hauteur(110, 0) < _scene.NIVEAU_MER - 1.0, "le Nil coule à l'est")
	_verifier(_scene.hauteur(-130, -40) > p.y + 8.0, "le plateau de Gizeh domine à l'ouest")
	var bassin: Vector2 = _scene.BASSIN.get_center()
	_verifier(_scene.hauteur(bassin.x, bassin.y) < _scene.NIVEAU_MER - 0.5, "le bassin du port est en eau")
	_verifier(get_first_node_in_group("balises") != null, "une balise de la Vigie permet de réapparaître")
	_verifier(_vivants("crocodile_fracture").size() >= 4, "des crocodiles fracturés rôdent (%d)" % _vivants("crocodile_fracture").size())
	_verifier(_vivants("crocodile").size() >= 4, "des crocodiles sauvages vivent sur la rive")
	var croco = _vivants("crocodile")[0] if not _vivants("crocodile").is_empty() else null
	_verifier(croco != null and croco.get_node("Apparence").get("_delegue") != null, "les crocodiles ont leur propre corps (pas celui d'un loup)")
	_verifier(_scene.find_child("GrandePyramide", true, false) != null, "la Grande Pyramide se dresse au loin")

	# Le joueur peut marcher sur la levée.
	await _placer(Vector3(-25, _scene.hauteur(-25, 30) + 0.3, 30), 0.0)
	var depart_z: float = _joueur.global_position.z
	Input.action_press("avancer")
	await _attendre(60)
	Input.action_release("avancer")
	await _attendre(5)
	_verifier(_joueur.global_position.z < depart_z - 2.0, "il avance sur la levée de terre (z = %.1f)" % _joueur.global_position.z)

	# --- Chapitre 1 : La crue.
	_verifier(_id_etape() == "retrouver_farouk", "la quête commence : retrouver Farouk (%s)" % _id_etape())
	var lues := await _parler("Farouk")
	_verifier(lues >= 4, "Farouk raconte l'hippopotame (%d bulles)" % lues)
	_verifier(_id_etape() == "materiel", "il faut repêcher le matériel (%s)" % _id_etape())
	for k in 3:
		var caisse = _scene.find_child("Caisse%d" % k, true, false)
		await _placer(caisse.global_position + Vector3(0, 0.4, 1.2), 0.0)
		await _appuyer_f()
		await _attendre(130)
	_verifier(_id_etape() == "crocodiles", "les 3 caisses sont repêchées (%s)" % _id_etape())
	var combat_joueur = _joueur.get_node("Combat")
	for bete in _vivants("crocodile_fracture"):
		bete.combat.subir(99999.0, combat_joueur)
		await _attendre(3)
		if _id_etape() != "crocodiles":
			break
	await _attendre(5)
	_verifier(_id_etape() == "balise", "les crocodiles fracturés sont vaincus (%s)" % _id_etape())
	await _aller_pres(_scene.find_child("PointBalise", true, false))
	await _appuyer_f()
	await _attendre(300)
	_verifier(_id_etape() == "rapport_farouk", "la balise est installée (%s)" % _id_etape())
	_verifier(_scene.find_child("BaliseInstallee", true, false).visible, "le trépied de la balise brille près du portail")
	await _parler("Farouk")
	_verifier(_id_etape() == "faille", "Farouk envoie refermer la faille (%s)" % _id_etape())
	await _attendre(5)
	var sortis := _vivants("crocodile_fracture_faille")
	_verifier(sortis.size() == 2, "deux crocodiles sortent de la faille (%d)" % sortis.size())
	for bete in sortis:
		bete.combat.subir(99999.0, combat_joueur)
	await _attendre(5)
	var faille = _scene.find_child("Faille", true, false)
	await _aller_pres(faille)
	await _appuyer_f()
	await _attendre(360)
	_verifier(faille.fermee, "la faille du marais est refermée")
	_verifier(_id_etape() == "fin_chapitre_1", "rapport final (%s)" % _id_etape())
	lues = await _parler("Farouk")
	_verifier(lues >= 4, "Farouk parle de Merer (%d bulles)" % lues)

	# --- Chapitre 2 : L'Occidental.
	_verifier(_id_etape() == "vers_le_port", "chapitre 2 : suivre la levée vers le port (%s)" % _id_etape())
	await _placer(Vector3(-14, _scene.hauteur(-14, -12) + 0.5, -12), PI)
	await _attendre(30)
	_verifier(_id_etape() == "rencontre_merer", "arrivée sur le quai (%s)" % _id_etape())
	lues = await _parler("Merer")
	_verifier(lues >= 4, "Merer prend le joueur pour un esprit (%d bulles)" % lues)
	await _parler("Ankhkhaf")
	_verifier(_id_etape() == "halage", "Ânkhkhaf demande d'aider au halage (%s)" % _id_etape())

	# Le halage : le traîneau n'avance que si le joueur reste près de lui.
	var traineau: Node3D = _scene.find_child("Traineau", true, false)
	var debut := traineau.global_position
	await _placer(Vector3(40, _scene.hauteur(40, 60) + 0.5, 60), 0.0)
	await _attendre(120)
	_verifier(traineau.global_position.distance_to(debut) < 0.5, "loin du traîneau, personne ne tire")
	var arrivee := Vector2(-66, -86)
	var croco_vague := false
	for i in 120:
		var t := traineau.global_position
		var derriere := t + (t - Vector3(arrivee.x, t.y, arrivee.y)).normalized() * -2.5
		derriere = t + (t - Vector3(arrivee.x, t.y, arrivee.y)).normalized() * 2.5
		await _placer(Vector3(derriere.x, _scene.hauteur(derriere.x, derriere.z) + 0.4, derriere.z), 0.0)
		await _attendre(20)
		for bete in _vivants("crocodile_fracture"):
			croco_vague = true
			bete.combat.subir(99999.0, combat_joueur)
		if _id_etape() != "halage":
			break
	_verifier(croco_vague, "des crocodiles sortent du bassin pendant le halage")
	_verifier(_id_etape() == "retour_ankhkhaf", "le bloc arrive au pied de la rampe (%s)" % _id_etape())
	var fin_t := traineau.global_position
	_verifier(Vector2(fin_t.x, fin_t.z).distance_to(arrivee) < 4.0, "le traîneau est au pied de la rampe (%.0f, %.0f)" % [fin_t.x, fin_t.z])
	await _parler("Ankhkhaf")
	_verifier(_id_etape() == "hippopotame", "il faut chasser l'hippopotame (%s)" % _id_etape())
	await _attendre(5)
	var hippo := _vivants("hippopotame_fracture")
	_verifier(hippo.size() == 1, "l'hippopotame fracturé bloque le chenal")
	if hippo.size() == 1:
		_verifier(hippo[0].get_node("Apparence").get("_delegue") != null, "il a un corps d'hippopotame")
		hippo[0].combat.subir(999999.0, combat_joueur)
	await _attendre(10)
	_verifier(_id_etape() == "recompense_ankhkhaf", "le chenal est libre (%s)" % _id_etape())
	await _parler("Ankhkhaf")
	var inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("masse_ankhkhaf") >= 1, "la masse d'Ânkhkhaf est dans le sac")
	_verifier(_id_etape() == "fin_chapitre_2", "Merer veut parler (%s)" % _id_etape())
	await _parler("Merer")
	_verifier(_quete.etape < 0, "chapitres 1 et 2 terminés (suite au chapitre 3)")

	# --- La progression est gardée.
	var cfg := ConfigFile.new()
	cfg.load(FICHIER)
	_verifier(cfg.get_value("egypte", "etape", "") == "fin", "l'avancement est enregistré dans la section « egypte »")
	_verifier(cfg.get_value("prehistoire", "etape", "") == "", "la Préhistoire n'est pas touchée")
	_scene.queue_free()
	await _attendre(5)
	await _charger()
	_verifier(_quete.etape < 0, "au retour, la quête reprend où on l'avait laissée")
	_verifier(_scene.find_child("Faille", true, false).fermee, "la faille est toujours fermée")
	_verifier(_scene.find_child("BaliseInstallee", true, false).visible, "la balise est toujours en place")
	var t2: Vector3 = _scene.find_child("Traineau", true, false).global_position
	_verifier(Vector2(t2.x, t2.z).distance_to(arrivee) < 4.0, "le bloc est toujours au pied de la rampe")

	# Retour au hub par le portail (après s'en être éloigné).
	await _placer(Vector3(-25, _scene.hauteur(-25, 60) + 0.3, 60), 0.0)
	await _attendre(5)
	_verifier(_scene._portail_arme, "le portail de retour s'active quand on s'en est éloigné")
	await _placer(Vector3(_scene.PORTAIL.x, _scene.hauteur(_scene.PORTAIL.x, _scene.PORTAIL.y + 6) + 0.3, _scene.PORTAIL.y + 6), 0.0)
	Input.action_press("avancer")
	await _attendre(90)
	Input.action_release("avancer")
	await _attendre(5)
	_verifier(_quete._en_voyage, "traverser le portail ramène à Hikari Bay")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
