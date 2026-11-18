extends SceneTree
## Test automatique du chantier de la cathédrale (Moyen Âge, zone 4) et des chapitres 6 et 7 :
## maître Gautier, les blocs des piliers, la grue à roue, Aude et le premier bleu, les
## gargouilles de plomb, les plans corrigés et la Cloche du beffroi ; puis la visite du roi,
## les échafaudages sabotés, l'escorte du cortège, Plomb vaincue et démasquée, l'écu du roi.
## Lancement : godot --headless --path game -s res://tests/test_chantier.gd
const FICHIER := "user://test_moyen_age_chantier.cfg"
const SCENE := "res://scenes/monde/moyen_age/chantier.tscn"

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


func _vitrail(nom_objet: String, motif: String, verifier_erreur := false) -> void:
	await _lire_dialogue()
	var objet: Node3D = _scene.find_child(nom_objet, true, false)
	await _aller_pres(objet, Vector3(0, 0, 1.2))
	await _appuyer_f()
	await _attendre(3)
	var v = _quete.vitrail()
	_verifier(v != null and v.est_ouvert(), "%s : le vitrail s'ouvre (%s)" % [nom_objet, v.motif() if v != null else "?"])
	if v == null:
		return
	_verifier(motif == "" or v.motif() == motif, "le motif est « %s » (%s)" % [motif, v.motif()])
	if verifier_erreur:
		var mauvais: int = (int(v.bon_morceau()) + 1) % int(v._ordre.size())
		v.choisir(mauvais)
		_verifier(v._place == 0 and v._erreurs == 1 and v.est_ouvert(), "un mauvais morceau : la fenêtre tremble, rien n'est posé")
		v.choisir(v.bon_morceau())
		_verifier(v._place == 1, "le bon morceau se pose")
	v.resoudre()
	await _attendre(90)


func _f_sur(nom: String, images: int, decalage := Vector3(0, 0, 1.3)) -> void:
	await _aller_pres(_scene.find_child(nom, true, false), decalage)
	await _appuyer_f()
	await _attendre(images)


func _lancer() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	# On reprend au début du chapitre 6 : on arrive du parvis de Chartres.
	var cfg := ConfigFile.new()
	cfg.set_value("moyen_age", "etape", "vers_chantier")
	cfg.save(FICHIER)
	await _charger()
	print("Test du chantier de la cathédrale (Moyen Âge, chapitres 6 et 7)")

	# --- Le monde.
	_verifier(_joueur != null and _joueur.is_on_floor(), "on arrive par le Portail royal")
	var p: Vector3 = _joueur.global_position
	_verifier(Vector2(p.x, p.z).distance_to(_scene.ARRIVEE) < 6.0, "juste derrière la façade (%.0f, %.0f)" % [p.x, p.z])
	_verifier(_id_etape() == "gautier", "l'arrivée termine l'étape du parvis (%s)" % _id_etape())
	_verifier(_scene.dans_la_cathedrale(Vector2(0, 0)), "la nef est bien dans la cathédrale")
	var ecart := 0.0
	for q: Vector2 in [Vector2(-60, 0), Vector2(0, 0), Vector2(60, 0), Vector2(-28, 30), Vector2(-30, -54), Vector2(31, -38)]:
		ecart = maxf(ecart, absf(_scene.hauteur(q.x, q.y) - _scene.SOL))
	_verifier(ecart < 1.2, "le sommet de la butte est presque plat (écart %.2f m)" % ecart)
	for nom in ["Cathedrale", "Echafaudages", "Bases", "CourSud", "Cloche", "CourNord", "Palissade", "PorteCrypte"]:
		_verifier(_scene.find_child(nom, true, false) != null, "le décor « %s » existe" % nom)
	_verifier(_scene.find_child("Roue", true, false) != null, "la grue à roue d'écureuil")
	for k in 3:
		_verifier(not _scene.find_child("Pilier%d" % k, true, false).visible, "le pilier %d n'est pas encore monté" % k)
	_verifier(not _scene.find_child("PhilippeAuguste", true, false).visible, "le roi n'est pas encore venu")

	# --- Chapitre 6 : Le chantier.
	var combat_joueur = _joueur.get_node("Combat")
	await _lire_dialogue()
	var lues := await _parler("MaitreGautier")
	_verifier(lues >= 3, "maître Gautier explique les marques de tâcheron (%d bulles)" % lues)
	_verifier(_id_etape() == "blocs_piliers", "les blocs des piliers (%s)" % _id_etape())
	for k in 3:
		await _f_sur("BlocPilier%d" % k, 160)
	_verifier(_id_etape() == "grue", "les trois blocs sont posés (%s)" % _id_etape())
	var montes := 0
	for k in 3:
		if _scene.find_child("Pilier%d" % k, true, false).visible:
			montes += 1
	_verifier(montes == 3, "les trois piliers commencent à monter (%d)" % montes)
	await _lire_dialogue()
	await _f_sur("GrueChantier", 420, Vector3(0, 0, 1.6))
	_verifier(_id_etape() == "aude_atelier", "la pierre monte sur les échafaudages (%s)" % _id_etape())
	await _lire_dialogue()
	await _attendre(20)
	_verifier(_scene._vitesse_roue > 0.0, "la grande roue tourne toute seule, maintenant")
	lues = await _parler("Aude")
	_verifier(lues >= 3, "Aude montre son atelier (%d bulles)" % lues)
	for k in 3:
		await _f_sur("CendresFougere%d" % k, 10)
	_verifier(_id_etape() == "four", "les cendres de fougère sont trouvées (%s)" % _id_etape())
	await _f_sur("FourVerrier", 360, Vector3(0, 0, 1.6))
	_verifier(_id_etape() == "aude_bleu", "le premier verre bleu (%s)" % _id_etape())
	await _lire_dialogue()
	await _parler("Aude")
	_verifier(_id_etape() == "gargouilles", "la nuit des gargouilles (%s)" % _id_etape())
	await _attendre(5)
	_verifier(_vivants("statue_gargouille_plomb").size() == 4, "quatre gargouilles descendent (%d)" % _vivants("statue_gargouille_plomb").size())
	await _tuer("statue_gargouille_plomb", combat_joueur, "gargouilles")
	_verifier(_id_etape() == "plans_corriges", "les gargouilles sont brisées (%s)" % _id_etape())
	await _lire_dialogue()
	await _f_sur("PlansCorriges", 140)
	_verifier(_id_etape() == "gautier_plans", "les plans corrigés sont lus (%s)" % _id_etape())
	await _lire_dialogue()
	lues = await _parler("MaitreGautier")
	_verifier(lues >= 4, "Gautier parle de l'encre et du roi (%d bulles)" % lues)
	_verifier(_id_etape() == "guillaume", "chapitre 7 : la visite du roi (%s)" % _id_etape())
	_verifier(_scene.find_child("PhilippeAuguste", true, false).visible, "le roi est arrivé")
	var inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("battant_cloche") >= 1, "le battant de la cloche est dans le sac")
	var competences: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/competences.json"))
	var objets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/objets.json"))
	_verifier(competences.has("cloche_du_beffroi"), "la compétence Cloche du beffroi existe")
	_verifier(String(objets["competences_requises"].get("cloche_du_beffroi", "")) == "battant_cloche", "elle demande le battant de la cloche")

	# --- Chapitre 7 : La visite du roi.
	await _lire_dialogue()
	lues = await _parler("GuillaumeLeBreton")
	_verifier(lues >= 3, "Guillaume le Breton prend des notes (%d bulles)" % lues)
	lues = await _parler("PhilippeAuguste")
	_verifier(lues >= 3, "le roi veut traverser la nef (%d bulles)" % lues)
	_verifier(_id_etape() == "etais", "les échafaudages sont sabotés (%s)" % _id_etape())
	await _lire_dialogue()
	for k in 3:
		var etai: Node3D = _scene.find_child("EtaiSabote%d" % k, true, false)
		_verifier(etai.visible, "le plomb brille dans les attaches de l'échafaudage %d" % k)
		await _f_sur("EtaiSabote%d" % k, 160)
	_verifier(_id_etape() == "escorte_roi", "les échafaudages tiennent (%s)" % _id_etape())
	var roi: Node3D = _scene.find_child("PhilippeAuguste", true, false)
	var images := 0
	var vagues := 0
	while _id_etape() == "escorte_roi" and images < 12000:
		images += 1
		if images % 30 == 0:
			var hommes := _vivants("masque_homme_plomb_chantier")
			if not hommes.is_empty():
				vagues += 1
			for bete in hommes:
				bete.combat.subir(999999.0, combat_joueur)
			var c := roi.global_position + Vector3(2.0, 0, 2.0)
			_joueur.teleporter(Vector3(c.x, _scene.hauteur(c.x, c.z) + 0.4, c.z), 0.0)
		await physics_frame
	_verifier(_id_etape() == "plomb_combat", "le cortège arrive au chœur (%s, %d images)" % [_id_etape(), images])
	_verifier(vagues >= 2, "les hommes de Plomb ont attaqué le cortège (%d fois)" % vagues)
	_verifier(Vector2(roi.global_position.x, roi.global_position.z).distance_to(Vector2(58, 0)) < 2.0, "le roi est dans le chœur")
	await _lire_dialogue()
	await _attendre(5)
	var plomb := _vivants("masque_plomb_chantier")
	_verifier(plomb.size() == 1, "Plomb attaque, devant l'escalier de la crypte")
	await _tuer("masque_plomb_chantier", combat_joueur, "plomb_combat")
	_verifier(_id_etape() == "plomb_demasquee", "Plomb est vaincue (%s)" % _id_etape())
	_verifier(_scene.find_child("PlombDemasquee", true, false).visible, "elle est à genoux, démasquée")
	await _lire_dialogue()
	lues = await _parler("PlombDemasquee")
	_verifier(lues >= 4, "Plomb parle de l'Éditeur et de la crypte (%d bulles)" % lues)
	_verifier(not _scene.find_child("PlombDemasquee", true, false).visible, "elle s'enfuit dans la crypte")
	_verifier(_id_etape() == "roi_fin", "le roi veut te voir (%s)" % _id_etape())
	await _lire_dialogue()
	await _parler("PhilippeAuguste")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("ecu_fleurdelise") >= 1, "l'écu fleurdelisé est dans le sac")

	# --- La progression est gardée.
	_scene.queue_free()
	await _attendre(5)
	await _charger()
	await _attendre(20)
	for k in 3:
		_verifier(_scene.find_child("Pilier%d" % k, true, false).visible, "le pilier %d est toujours là" % k)
	_verifier(not _scene.find_child("EtaiSabote0", true, false).visible, "le plomb des échafaudages ne revient pas")
	# Le Portail royal ramène au parvis.
	var s: Vector2 = _scene.SORTIE_CHARTRES
	await _placer(Vector3(s.x + 1.0, _scene.hauteur(s.x + 1.0, s.y) + 0.4, s.y), -PI / 2)
	await _attendre(70)
	_verifier(_quete.zone_demandee == "chartres", "le Portail royal ramène au parvis (%s)" % _quete.zone_demandee)

	print("")
	if _echecs == 0:
		print("TOUS LES TESTS PASSENT")
	else:
		print("%d ÉCHEC(S)" % _echecs)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	quit(1 if _echecs > 0 else 0)
