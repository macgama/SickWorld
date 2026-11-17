extends SceneTree
## Test automatique du mont Li (Chine, zone 4) et du chapitre 6 : le paysan du puits,
## Masque (allié ou non), les soldats de terre cuite et leur général, la faille de la fosse
## des chevaux, le camp des fouilleurs, le plan du tombeau, Vera, Cinabre et son choix,
## le bébé panda et le retour en char de poste.
## Lancement : godot --headless --path game -s res://tests/test_mont_li.gd

const FICHIER := "user://test_chine_mont_li.cfg"
const SCENE := "res://scenes/monde/chine/mont_li.tscn"

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


func _calmer_autour(p: Vector3, rayon: float) -> void:
	var combat_joueur = _joueur.get_node("Combat")
	for bete in get_nodes_in_group("loups"):
		if bete.combat.est_vivant() and bete.global_position.distance_to(p) < rayon:
			bete.combat.subir(999999.0, combat_joueur)


## Va près d'un objet (en s'éloignant de « loin_de ») et appuie sur F.
func _utiliser(id_noeud: String, loin_de := Vector2.INF, attente := 20) -> void:
	var objet: Node3D = _scene.find_child(id_noeud, true, false)
	if objet == null:
		print("  (objet introuvable : %s)" % id_noeud)
		return
	_calmer_autour(objet.global_position, 30.0)
	var o := Vector2(objet.global_position.x, objet.global_position.z)
	var dir := Vector2(0, 1)
	if loin_de != Vector2.INF:
		dir = (o - loin_de).normalized()
	var p := o + dir * 1.3
	var y := maxf(_scene.hauteur(p.x, p.y), objet.global_position.y) + 0.4
	await _placer(Vector3(p.x, y, p.y), atan2(dir.x, dir.y))
	await _appuyer_f()
	await _attendre(attente)


func _debut(etape: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("chine", "etape", etape)
	cfg.save(FICHIER)
	await _charger()


func _lancer() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	# On arrive du char de poste, au début du chapitre 6 ; Masque était un allié.
	var cfg := ConfigFile.new()
	cfg.set_value("chine", "etape", "vers_mont_li")
	cfg.set_value("chine", "choix_choix_masque", "allier_masque")
	cfg.save(FICHIER)
	await _charger()
	print("Test du mont Li (Chine, chapitre 6)")

	# --- Le monde.
	_verifier(_joueur != null and _joueur.is_on_floor(), "on descend du char de poste")
	var p: Vector3 = _joueur.global_position
	_verifier(p.x > 140.0, "à l'est de la zone (%.0f, %.0f)" % [p.x, p.z])
	_verifier(_id_etape() == "paysan_puits", "l'arrivée termine l'étape du char (%s)" % _id_etape())
	for nom in ["Fosses", "Tumulus", "Hameau", "Camp", "Bambous"]:
		_verifier(_scene.find_child(nom, true, false) != null, "le mont Li a son « %s »" % nom)
	var c: Vector2 = _scene.FOSSE.get_center()
	_verifier(_scene.hauteur(c.x, c.y - 4.0) < _scene.SOL - 4.0, "la grande fosse est creusée (%.1f)" % _scene.hauteur(c.x, c.y - 4.0))
	var t: Vector2 = _scene.TUMULUS
	_verifier(_scene.hauteur(t.x, t.y) > _scene.SOL + 28.0, "la colline du tombeau domine (%.1f)" % _scene.hauteur(t.x, t.y))
	_verifier(get_first_node_in_group("balises") != null, "une balise de la Vigie permet de réapparaître")
	_verifier(_vivants("soldat_argile").size() >= 4, "des soldats de terre cuite rôdent (%d)" % _vivants("soldat_argile").size())
	var soldat: Node = _vivants("soldat_argile")[0] if not _vivants("soldat_argile").is_empty() else null
	_verifier(soldat != null and soldat.get_node("Apparence").find_child("Oublie", true, false) != null, "les soldats ont un corps d'homme")
	_verifier(soldat != null and String(soldat.get_node("Apparence").find_child("Oublie", true, false).get("variante")) == "argile", "un corps de terre cuite")
	_verifier(not _scene.find_child("CinabreLi", true, false).visible, "Cinabre n'est pas encore là")
	# On descend dans la fosse par la rampe de l'est.
	await _placer(Vector3(100, _scene.hauteur(100, -44) + 0.4, -44), PI / 2)
	Input.action_press("avancer")
	await _attendre(180)
	Input.action_release("avancer")
	var j: Vector3 = _joueur.global_position
	_verifier(j.x < 82.0 and j.y < _scene.SOL - 3.0, "la rampe mène au fond de la fosse (%.0f, %.1f)" % [j.x, j.y])

	# --- Chapitre 6 : L'armée d'argile.
	var combat_joueur = _joueur.get_node("Combat")
	_calmer_autour(Vector3(126, 4, 46), 40.0)
	var lues := await _parler("PaysanPuits")
	_verifier(lues >= 4, "le paysan raconte la tête du puits (%d bulles)" % lues)
	_verifier(_id_etape() == "masque_allie", "Masque, allié, attend au bord de la route (%s)" % _id_etape())
	lues = await _parler("MasqueLi")
	_verifier(lues >= 4, "Masque parle de Cinabre (%d bulles)" % lues)
	_verifier(_id_etape() == "soldats", "il faut descendre dans la fosse (%s)" % _id_etape())
	await _placer(Vector3(56, _scene.hauteur(56, -44) + 0.4, -44), -PI / 2)
	await _attendre(5)
	_verifier(_vivants("soldat_argile_fosse").size() == 6, "six soldats se relèvent (%d)" % _vivants("soldat_argile_fosse").size())
	await _tuer("soldat_argile_fosse", combat_joueur, "soldats")
	_verifier(_id_etape() == "general", "les soldats sont brisés (%s)" % _id_etape())
	await _attendre(5)
	var general := _vivants("general_argile")
	_verifier(general.size() == 1, "le général d'argile se dresse (%d)" % general.size())
	await _tuer("general_argile", combat_joueur, "general")
	_verifier(_id_etape() == "faille", "le général est abattu (%s)" % _id_etape())
	var faille = _scene.find_child("Faille", true, false)
	_calmer_autour(faille.global_position, 40.0)
	await _aller_pres(faille)
	await _appuyer_f()
	await _attendre(360)
	_verifier(faille.fermee, "la faille est refermée")
	_verifier(_id_etape() == "camp", "il faut aller au camp (%s)" % _id_etape())
	await _placer(Vector3(112, _scene.hauteur(112, -92) + 0.4, -92), 0.0)
	await _attendre(5)
	_verifier(_vivants("fouilleur_cinabre_camp").size() == 5, "cinq fouilleurs au camp (%d)" % _vivants("fouilleur_cinabre_camp").size())
	await _tuer("fouilleur_cinabre_camp", combat_joueur, "camp")
	_verifier(_id_etape() == "plans", "les fouilleurs sont chassés (%s)" % _id_etape())
	await _utiliser("Plans", Vector2(122, -98), 160)
	_verifier(_id_etape() == "vera_li", "on a lu le plan du tombeau (%s)" % _id_etape())
	_verifier(_scene.find_child("VeraLi", true, false).visible, "Vera est là, en vrai")
	lues = await _parler("VeraLi")
	_verifier(lues >= 4, "Vera explique le plan (%d bulles)" % lues)
	_verifier(_id_etape() == "cinabre", "Cinabre attend au tombeau (%s)" % _id_etape())
	_verifier(_scene.find_child("CinabreLi", true, false).visible, "Cinabre est devant l'entrée")
	lues = await _parler("CinabreLi")
	_verifier(lues >= 4, "Cinabre défend le Premier Empereur (%d bulles)" % lues)
	_verifier(_id_etape() == "choix_cinabre", "il faut lui répondre (%s)" % _id_etape())
	await _utiliser("RepondreUnite", _scene.CINABRE)
	await _lire_dialogue()
	await _attendre(10)
	_verifier(_id_etape() == "panda", "Cinabre s'enfuit dans le tombeau (%s)" % _id_etape())
	_verifier(not _scene.find_child("CinabreLi", true, false).visible, "Cinabre a disparu")
	_verifier(_scene.find_child("MasqueTombeau", true, false).visible, "Masque garde l'entrée")
	await _utiliser("BebePanda", Vector2(-122, 118), 160)
	_verifier(_id_etape() == "masque_tombeau", "on a trouvé le bébé panda (%s)" % _id_etape())
	var inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("bebe_panda") >= 1, "Bao le panda est dans le sac")
	lues = await _parler("MasqueTombeau")
	_verifier(lues >= 4, "Masque garde la porte (%d bulles)" % lues)
	_verifier(_quete.etape < 0, "chapitre 6 terminé (%s)" % _id_etape())
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("cuirasse_lamelles") >= 1, "la cuirasse de lamelles est dans le sac")

	# --- Au retour, tout est resté en place ; le char ramène à Luoyang.
	_scene.queue_free()
	await _attendre(5)
	await _charger()
	await _attendre(20)
	_verifier(_quete.etape < 0, "au retour, le chapitre 6 est toujours fini")
	_verifier(_scene.find_child("Faille", true, false).fermee, "la faille est toujours fermée")
	_verifier(_scene.find_child("MasqueTombeau", true, false).visible, "Masque garde toujours l'entrée")
	_verifier(not _scene.find_child("CinabreLi", true, false).visible, "Cinabre n'est plus là")
	var char_poste: Node3D = _scene.find_child("CharPoste", true, false)
	await _placer(char_poste.global_position + Vector3(-1.5, 0.4, -0.4), 0.0)
	await _appuyer_f()
	await _attendre(80)
	_verifier(_quete.zone_demandee == "luoyang", "le char ramène à Luoyang (%s)" % _quete.zone_demandee)

	# --- L'autre branche : Masque, dont on se méfie.
	_scene.queue_free()
	await _attendre(5)
	cfg = ConfigFile.new()
	cfg.set_value("chine", "etape", "paysan_puits")
	cfg.set_value("chine", "choix_choix_masque", "mefier_masque")
	cfg.save(FICHIER)
	await _charger()
	await _parler("PaysanPuits")
	_verifier(_id_etape() == "masque_mefiant", "si on se méfiait de Masque, il reste méfiant (%s)" % _id_etape())
	lues = await _parler("MasqueLi")
	_verifier(lues >= 3 and _id_etape() == "soldats", "et il indique quand même la fosse (%s)" % _id_etape())

	print("")
	if _echecs == 0:
		print("TOUS LES TESTS PASSENT")
	else:
		print("%d ÉCHEC(S)" % _echecs)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	quit(1 if _echecs > 0 else 0)
