extends SceneTree
## Test automatique de Luoyang (Chine, zone 3) et des chapitres 4 et 5 : Ban Zhao et la
## lettre de Gan Ying, les cuves empoisonnées de Cai Lun, le choix (refaire le papier ou
## suivre le saboteur), le tigre du parc impérial, l'incendie du pavillon de l'Est, les
## manteaux rouges, les notes de l'Éditeur et le retour au QG (la charte de fondation).
## Lancement : godot --headless --path game -s res://tests/test_luoyang.gd

const FICHIER := "user://test_chine_luoyang.cfg"
const SCENE := "res://scenes/monde/chine/luoyang.tscn"

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
	# On reprend au début du chapitre 4 : on arrive du Fleuve Jaune.
	await _debut("vers_luoyang")
	print("Test de Luoyang (Chine, chapitres 4 et 5)")

	# --- Le monde.
	_verifier(_joueur != null and _joueur.is_on_floor(), "on arrive sur la route, devant la porte de l'Ouest")
	var p: Vector3 = _joueur.global_position
	_verifier(p.x < -160.0, "à l'ouest de la ville (%.0f, %.0f)" % [p.x, p.z])
	_verifier(_id_etape() == "ban_zhao", "l'arrivée termine l'étape de la route (%s)" % _id_etape())
	for nom in ["Enceinte", "Palais", "PavillonEst", "Atelier", "Marche", "Parc", "Academie", "Quartiers"]:
		_verifier(_scene.find_child(nom, true, false) != null, "la ville a son « %s »" % nom)
	_verifier(get_first_node_in_group("balises") != null, "une balise de la Vigie permet de réapparaître")
	_verifier(_vivants("pillard_luoyang").size() >= 5, "des voleurs dans les faubourgs (%d)" % _vivants("pillard_luoyang").size())
	_verifier(not _scene.find_child("PortailVigie", true, false).visible, "le portail de la Vigie n'est pas encore ouvert")
	_verifier(not _scene.find_child("IncendieBibliotheque", true, false).visible, "la bibliothèque ne brûle pas encore")
	# On entre dans la ville par la porte de l'Ouest, sur l'avenue.
	await _placer(Vector3(-166, _scene.hauteur(-166, 20) + 0.4, 20), -PI / 2)
	Input.action_press("avancer")
	await _attendre(200)
	Input.action_release("avancer")
	_verifier(_joueur.global_position.x > -146.0, "on passe la porte de l'Ouest (x = %.0f)" % _joueur.global_position.x)
	# Mais pas à travers le rempart.
	await _placer(Vector3(-166, _scene.hauteur(-166, -60) + 0.4, -60), -PI / 2)
	Input.action_press("avancer")
	await _attendre(200)
	Input.action_release("avancer")
	_verifier(_joueur.global_position.x < -150.0, "on ne traverse pas le rempart (x = %.0f)" % _joueur.global_position.x)

	# --- Chapitre 4 : Le cadeau de Cai Lun.
	var combat_joueur = _joueur.get_node("Combat")
	var lues := await _parler("BanZhao")
	_verifier(lues >= 4, "Ban Zhao lit la lettre de Gan Ying (%d bulles)" % lues)
	_verifier(_id_etape() == "cai_lun", "il faut porter la rame à Cai Lun (%s)" % _id_etape())
	lues = await _parler("CaiLun")
	_verifier(lues >= 4, "Cai Lun montre ses cuves empoisonnées (%d bulles)" % lues)
	_verifier(_id_etape() == "cuves", "il faut vider les cuves (%s)" % _id_etape())
	var cai: Vector2 = _scene.CAI_LUN
	for k in 3:
		await _utiliser("Cuve%d" % k, cai, 160)
	_verifier(_id_etape() == "choix_cai_lun", "les cuves sont vidées, il faut choisir (%s)" % _id_etape())
	var cuve: Node3D = _scene.find_child("Cuve1", true, false)
	_verifier(cuve.get_node_or_null("Propre") != null and cuve.get_node("Propre").visible, "la cuve est propre")
	# Première branche : on aide Cai Lun.
	await _utiliser("AiderCaiLun", cai)
	await _lire_dialogue()
	_verifier(_id_etape() == "ecorces", "on reste refaire le papier (%s)" % _id_etape())
	for k in 3:
		await _utiliser("Ecorce%d" % k, cai, 110)
	_verifier(_id_etape() == "piler", "l'écorce est sortie de l'eau (%s)" % _id_etape())
	await _utiliser("Pilon", cai, 300)
	_verifier(_id_etape() == "tamiser", "les fibres sont pilées (%s)" % _id_etape())
	await _utiliser("Tamis", Vector2(-108, -40), 240)
	_verifier(_id_etape() == "secher", "la feuille est tamisée (%s)" % _id_etape())
	await _utiliser("Sechoir", cai, 180)
	_verifier(_id_etape() == "cai_lun_tigre", "la feuille sèche sur le mur (%s)" % _id_etape())
	lues = await _parler("CaiLun")
	_verifier(lues >= 4, "Cai Lun entend le tigre (%d bulles)" % lues)
	_verifier(_id_etape() == "tigre", "il faut arrêter le tigre (%s)" % _id_etape())
	await _placer(Vector3(-104, _scene.hauteur(-104, -100) + 0.4, -100), 0.0)
	await _attendre(5)
	var tigre := _vivants("tigre_fracture")
	_verifier(tigre.size() == 1, "le tigre fracturé rôde dans le parc (%d)" % tigre.size())
	if tigre.size() > 0:
		_verifier(tigre[0].get_node("Apparence").get("espece") != "sanglier", "il a un corps de fauve")
		tigre[0].combat.subir(999999.0, combat_joueur)
	await _attendre(20)
	_verifier(_id_etape() == "cai_lun_cadeau", "le tigre est abattu (%s)" % _id_etape())
	lues = await _parler("CaiLun")
	_verifier(lues >= 4, "Cai Lun offre son couteau (%d bulles)" % lues)
	var inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("couteau_cai_lun") >= 1, "le couteau à gratter est dans le sac")
		_verifier(inventaire.quantite("recette_papier") >= 1, "et la recette du papier")
	_verifier(_id_etape() == "vers_pavillon", "chapitre 4 terminé (%s)" % _id_etape())

	# --- Chapitre 5 : Le pavillon de l'Est.
	await _placer(Vector3(103, _scene.hauteur(103, 58) + 0.4, 58), PI)
	await _attendre(20)
	_verifier(_id_etape() == "ma_rong", "on arrive au pavillon (%s)" % _id_etape())
	_verifier(_scene.find_child("IncendieBibliotheque", true, false).visible, "la bibliothèque brûle")
	lues = await _parler("MaRong")
	_verifier(lues >= 2, "Ma Rong organise la chaîne de seaux (%d bulles)" % lues)
	_verifier(_id_etape() == "feu", "il faut éteindre le feu (%s)" % _id_etape())
	var biblio: Vector2 = _scene.BIBLIOTHEQUE
	for k in 4:
		await _utiliser("Rayonnage%d" % k, biblio, 190)
	_verifier(_id_etape() == "liasses", "le feu est éteint (%s)" % _id_etape())
	var rayon: Node3D = _scene.find_child("Rayonnage0", true, false)
	_verifier(rayon.get_node_or_null("Eteint") != null and rayon.get_node("Eteint").visible, "le rayonnage est noirci")
	for k in 5:
		await _utiliser("Liasse%d" % k, biblio, 90)
	_verifier(_id_etape() == "mercenaires", "les livres sont à l'abri (%s)" % _id_etape())
	await _attendre(5)
	var merc := _vivants("mercenaire_cinabre")
	_verifier(merc.size() == 4, "quatre manteaux rouges (%d)" % merc.size())
	_verifier(merc.size() > 0 and merc[0].get_node("Apparence").find_child("Oublie", true, false) != null, "ce sont des hommes")
	await _tuer("mercenaire_cinabre", combat_joueur, "mercenaires")
	_verifier(_id_etape() == "manuscrit", "les mercenaires sont chassés (%s)" % _id_etape())
	await _utiliser("Manuscrit", biblio, 160)
	_verifier(_id_etape() == "ban_zhao_page", "on a lu les notes de l'Éditeur (%s)" % _id_etape())
	lues = await _parler("BanZhao")
	_verifier(lues >= 4, "Ban Zhao donne la page (%d bulles)" % lues)
	_verifier(_id_etape() == "qg_charte", "il faut rentrer au QG (%s)" % _id_etape())
	_verifier(not _scene.find_child("IncendieBibliotheque", true, false).visible, "le feu est éteint")
	var portail: Node3D = _scene.find_child("PortailVigie", true, false)
	_verifier(portail != null and portail.visible, "le portail de la Vigie est ouvert")
	await _attendre(5)
	_verifier(_scene._zone_portail.monitoring, "le portail ramène au QG")
	root.get_node("Reseau").remove_meta("mission_hub_auto")
	_quete.rentrer_au_hub()
	await _attendre(10)
	_verifier(String(root.get_node("Reseau").get_meta("mission_hub_auto", "")) == "charte_fondation", "au QG, la mission de la charte de fondation se lance")
	root.get_node("Reseau").remove_meta("mission_hub_auto")

	# --- Au retour, tout est resté en place.
	_scene.queue_free()
	await _attendre(5)
	await _charger()
	await _attendre(20)
	_verifier(_quete.etape < 0 or _quete.etape_atteinte("qg_charte"), "au retour, le chapitre 5 est fini (%s)" % _id_etape())
	_verifier(not _scene.find_child("IncendieBibliotheque", true, false).visible, "la bibliothèque ne brûle plus")
	_verifier(_scene.find_child("Rayonnage2", true, false).get_node("Eteint").visible, "les rayonnages sont toujours éteints")
	_verifier(_scene.find_child("Cuve0", true, false).get_node("Propre").visible, "les cuves sont toujours propres")
	# Chapitre 6 : Ban Zhao envoie au mont Li, en char de poste.
	_verifier(_id_etape() == "ban_zhao_qin", "le chapitre 6 commence chez Ban Zhao (%s)" % _id_etape())
	lues = await _parler("BanZhao")
	_verifier(lues >= 4, "Ban Zhao parle du mont Li (%d bulles)" % lues)
	_verifier(_id_etape() == "vers_mont_li", "il faut prendre le char de poste (%s)" % _id_etape())
	var char_poste: Node3D = _scene.find_child("CharPoste", true, false)
	_verifier(char_poste != null, "le char de poste attend derrière la porte de l'Ouest")
	await _placer(char_poste.global_position + Vector3(1.5, 0.4, 0.4), 0.0)
	await _appuyer_f()
	await _attendre(80)
	_verifier(_quete.zone_demandee == "mont_li", "le char part vers le mont Li (%s)" % _quete.zone_demandee)
	_quete.zone_demandee = ""
	# Vers l'ouest, la route ramène au Fleuve Jaune.
	var o: Vector2 = _scene.ENTREE
	await _placer(Vector3(o.x + 8.0, _scene.hauteur(o.x + 8.0, o.y) + 0.4, o.y), PI / 2)
	Input.action_press("avancer")
	await _attendre(60)
	Input.action_release("avancer")
	await _attendre(30)
	_verifier(_quete.zone_demandee == "fleuve_jaune", "la route de l'ouest ramène au Fleuve Jaune (%s)" % _quete.zone_demandee)

	# --- Deuxième branche : on suit le saboteur jusqu'au marché.
	_scene.queue_free()
	await _attendre(5)
	await _debut("choix_cai_lun")
	await _attendre(10)
	cai = _scene.CAI_LUN
	await _utiliser("SuivreSaboteur", cai)
	await _lire_dialogue()
	_verifier(_id_etape() == "filature_porte", "on suit l'ouvrier inconnu (%s)" % _id_etape())
	for z in [Vector2(-104, -22), Vector2(-100, 20), Vector2(-104, 72)]:
		await _placer(Vector3(z.x, _scene.hauteur(z.x, z.y) + 0.4, z.y), 0.0)
		await _attendre(20)
	_verifier(_id_etape() == "fiole", "il disparaît dans le marché (%s)" % _id_etape())
	await _utiliser("Fiole", Vector2(-120, 92))
	await _attendre(10)
	_verifier(_id_etape() == "cai_lun_fiole", "on a trouvé la fiole de mercure (%s)" % _id_etape())
	lues = await _parler("CaiLun")
	_verifier(lues >= 3, "Cai Lun reconnaît le sceau (%d bulles)" % lues)
	_verifier(_id_etape() == "tigre", "et les deux branches mènent au tigre (%s)" % _id_etape())

	print("")
	if _echecs == 0:
		print("TOUS LES TESTS PASSENT")
	else:
		print("%d ÉCHEC(S)" % _echecs)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	quit(1 if _echecs > 0 else 0)
