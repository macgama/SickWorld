extends SceneTree
## Test automatique de la Porte de Jade (Chine, zone 1) et des chapitres 1 et 2 :
## Masque au portail (alliance ou méfiance), la radio de Vera, les pillards qui attaquent
## la caravane, Ban Yong, les trois fanaux, l'escorte jusqu'au relais, puis les Figés du
## fort (calligraphie), les lattes qui brûlent, Gan Ying, le chef des pillards, la faille
## et l'épée de Ban Chao.
## Lancement : godot --headless --path game -s res://tests/test_porte_de_jade.gd

const FICHIER := "user://test_chine_progression.cfg"
const SCENE := "res://scenes/monde/chine/porte_de_jade.tscn"

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
	print("Test de la Porte de Jade (Chine)")

	# --- Le monde.
	_verifier(_joueur != null, "un personnage arrive sur l'île")
	var p: Vector3 = _joueur.global_position
	_verifier(Vector2(p.x, p.z).distance_to(_scene.PORTAIL) < 9.0, "juste devant le portail de la Vigie")
	_verifier(_joueur.is_on_floor(), "il a les pieds sur terre (y = %.2f)" % p.y)
	_verifier(_scene.find_child("GrandeMuraille", true, false) != null, "la Grande Muraille des Han barre le nord")
	_verifier(_scene.find_child("TourDuPortail", true, false) != null, "le portail s'est ouvert au pied d'une vieille tour en ruine")
	_verifier(_scene.find_child("PorteDeJade", true, false) != null, "le fort de la Porte de Jade est construit")
	_verifier(_scene.find_child("Relais", true, false) != null, "le relais des caravanes aussi")
	_verifier(_scene.find_child("LacSale", true, false) != null, "un lac salé gelé au sud-est")
	_verifier(_scene.find_child("MurailleLointaine", true, false) != null, "la muraille continue à perte de vue")
	var nb_chameaux := 0
	for n in _scene.find_children("Chameau*", "Node3D", true, false):
		nb_chameaux += 1
	_verifier(nb_chameaux >= 6, "des chameaux de Bactriane au relais et dans la caravane (%d)" % nb_chameaux)
	var nb_arbres: int = _scene.find_child("Arbres", true, false).get_child_count()
	_verifier(nb_arbres >= 15, "des peupliers du désert autour du lac (%d)" % nb_arbres)
	_verifier(get_first_node_in_group("balises") != null, "une balise de la Vigie permet de réapparaître")
	_verifier(_vivants("loup_fracture_jade").size() >= 8, "des loups fracturés rôdent dans les dunes (%d)" % _vivants("loup_fracture_jade").size())
	_verifier(_vivants("pillard_desert").size() >= 7, "des pillards du désert campent autour (%d)" % _vivants("pillard_desert").size())
	var pillard: Node = _vivants("pillard_desert")[0] if not _vivants("pillard_desert").is_empty() else null
	_verifier(pillard != null and pillard.get_node("Apparence").find_child("Oublie", true, false) != null, "les pillards sont des hommes (pas des loups)")
	# La route est praticable d'un bout à l'autre, sans marche brusque.
	var pente_max := 0.0
	for x in range(-150, 150, 3):
		var a := Vector2(float(x), 0.0)
		var b := Vector2(float(x + 3), 0.0)
		for i in _scene.ROUTE.size() - 1:
			var r0: Vector2 = _scene.ROUTE[i]
			var r1: Vector2 = _scene.ROUTE[i + 1]
			if a.x >= r0.x and a.x < r1.x:
				a.y = lerpf(r0.y, r1.y, inverse_lerp(r0.x, r1.x, a.x))
				b.y = lerpf(r0.y, r1.y, inverse_lerp(r0.x, r1.x, b.x))
		pente_max = maxf(pente_max, absf(_scene.hauteur(a.x, a.y) - _scene.hauteur(b.x, b.y)))
	_verifier(pente_max < 0.6, "la route monte et descend en douceur (marche max %.2f m)" % pente_max)
	var d_nord: float = _scene.hauteur(0, -150) - _scene.hauteur(0, 40)
	_verifier(d_nord > 3.0, "au nord de la muraille, les dunes s'élèvent (%.1f m)" % d_nord)

	# --- Chapitre 1 : La Porte de Jade.
	var combat_joueur = _joueur.get_node("Combat")
	_verifier(_id_etape() == "rencontre_masque", "la quête commence : quelqu'un attend au portail (%s)" % _id_etape())
	var lues := await _parler("MasqueJade")
	_verifier(lues >= 4, "Masque propose une alliance (%d bulles)" % lues)
	_verifier(_id_etape() == "choix_masque", "il attend une réponse (%s)" % _id_etape())
	await _aller_pres(_scene.find_child("AllierMasque", true, false), Vector3(0, 0, 0.6))
	await _appuyer_f()
	await _attendre(5)
	lues = await _lire_dialogue()
	_verifier(_quete.etape_actuelle().get("choix_fait", "") == "allier_masque" or _id_etape() == "radio_vera", "on accepte l'alliance")
	if _id_etape() == "choix_masque":
		await _parler("MasqueJade")
	_verifier(_id_etape() == "radio_vera", "Masque s'en va, une radio grésille (%s)" % _id_etape())
	await _aller_pres(_scene.find_child("RadioVera", true, false))
	await _appuyer_f()
	await _attendre(130)
	_verifier(_id_etape() == "vers_caravane", "Vera parle à la radio (%s)" % _id_etape())
	_verifier(not _scene.find_child("MasqueJade", true, false).visible, "Masque est parti vers l'est")
	await _placer(Vector3(-80, _scene.hauteur(-80, -22) + 0.4, -22), PI)
	await _attendre(20)
	_verifier(_id_etape() == "pillards", "sur la route, des pillards attaquent la caravane (%s)" % _id_etape())
	await _attendre(5)
	_verifier(_vivants("pillard_desert_caravane").size() == 4, "quatre pillards (%d)" % _vivants("pillard_desert_caravane").size())
	await _tuer("pillard_desert_caravane", combat_joueur, "pillards")
	_verifier(_id_etape() == "rencontre_ban_yong", "les pillards sont chassés (%s)" % _id_etape())
	_verifier(_scene.find_child("BanYongRoute", true, false).visible, "Ban Yong arrive avec ses cavaliers")
	lues = await _parler("BanYongRoute")
	_verifier(lues >= 4, "Ban Yong explique les fanaux (%d bulles)" % lues)
	_verifier(_id_etape() == "fanaux", "il faut rallumer les fanaux (%s)" % _id_etape())
	for k in 3:
		var fanal: Node3D = _scene.find_child("Fanal%d" % k, true, false)
		for bete in get_nodes_in_group("loups"):
			if bete.combat.est_vivant() and bete.global_position.distance_to(fanal.global_position) < 30.0:
				bete.combat.subir(999999.0, combat_joueur)
		await _attendre(3)
		await _aller_pres(fanal, Vector3(0, 0, 2.2))
		await _appuyer_f()
		await _attendre(220)
		_verifier(fanal.get_node_or_null("Allume") != null and fanal.get_node("Allume").visible, "le fanal %d flambe" % (k + 1))
	_verifier(_id_etape() == "wang_ba", "les trois fanaux brûlent (%s)" % _id_etape())
	_verifier(_scene.find_child("FanauxLointains", true, false).visible, "au loin, les autres tours répondent")
	await _parler("WangBa")
	_verifier(_id_etape() == "escorte_caravane", "il faut escorter la caravane (%s)" % _id_etape())
	var caravane: Node3D = _scene.find_child("CaravaneSoie", true, false)
	var images := 0
	while _id_etape() == "escorte_caravane" and images < 9000:
		images += 1
		if images % 30 == 0:
			for bete in _vivants("loup_fracture_escorte"):
				bete.combat.subir(999999.0, combat_joueur)
			var c := caravane.global_position + Vector3(2.5, 0, 2.5)
			_joueur.teleporter(Vector3(c.x, _scene.hauteur(c.x, c.z) + 0.4, c.z), 0.0)
		await physics_frame
	_verifier(_id_etape() == "ban_yong_fort", "la caravane arrive au relais (%s, %d images)" % [_id_etape(), images])
	_verifier(Vector2(caravane.global_position.x, caravane.global_position.z).distance_to(Vector2(70, 12)) < 1.0, "la caravane est garée devant le relais")
	lues = await _parler("BanYong")
	_verifier(lues >= 3, "Ban Yong parle des gardes changés en terre (%d bulles)" % lues)

	# --- Chapitre 2 : Les Figés.
	_verifier(_id_etape() == "figes_cour", "chapitre 2 : entrer dans le fort (%s)" % _id_etape())
	var fige: Node = _scene.find_child("FigeSoldat", true, false)
	_verifier(fige != null and fige.fige, "dans la cour, un soldat est figé dans l'argile")
	await _placer(Vector3(24, _scene.hauteur(24, -23) + 0.4, -23), 0.0)
	await _attendre(20)
	_verifier(_id_etape() == "ban_yong_figes", "on a vu les Figés (%s)" % _id_etape())
	await _parler("BanYong")
	_verifier(_id_etape() == "figes", "il faut rendre la mémoire aux Figés (%s)" % _id_etape())
	var feuille = null
	for k in 4:
		var objet: Node3D = _scene.find_child("Memoire%d" % k, true, false)
		await _aller_pres(objet, Vector3(0, 0, 1.2))
		await _appuyer_f()
		await _attendre(3)
		feuille = _quete.calligraphie()
		_verifier(feuille != null and feuille.est_ouvert(), "le Figé %d : la feuille de calligraphie s'ouvre (%s)" % [k + 1, feuille.caractere() if feuille != null else "?"])
		if feuille == null:
			break
		if k == 0:
			_verifier(feuille.caractere() == "人", "le premier caractère est 人, l'homme")
			# Un trait dans le désordre : l'encre s'efface.
			var mauvais := -1
			for i in feuille._ordre.size():
				if feuille._ordre[i] != 0:
					mauvais = i
					break
			feuille.choisir(mauvais)
			_verifier(feuille._place == 0 and feuille.est_ouvert(), "un trait dans le désordre : on recommence")
			_verifier(_quete.compteur == 0, "rien n'est compté tant que le caractère est faux")
		feuille.resoudre()
		await _attendre(70)
		_verifier(_quete.compteur == k + 1 or _id_etape() != "figes", "le Figé %d retrouve la mémoire (%d/4)" % [k + 1, _quete.compteur])
	_verifier(_id_etape() == "scribe", "les quatre Figés sont libérés (%s)" % _id_etape())
	_verifier(fige != null and not fige.fige, "l'argile du soldat est tombée")
	await _parler("ScribeJade")
	_verifier(_id_etape() == "lattes", "les lattes du relais brûlent (%s)" % _id_etape())
	for k in 3:
		var lattes: Node3D = _scene.find_child("Lattes%d" % k, true, false)
		await _aller_pres(lattes, Vector3(0, 0, 1.4))
		await _appuyer_f()
		await _attendre(190)
		_verifier(lattes.get_node_or_null("Eteint") != null and lattes.get_node("Eteint").visible, "le tas de lattes %d est éteint" % (k + 1))
	_verifier(_id_etape() == "gan_ying", "les registres sont sauvés (%s)" % _id_etape())
	lues = await _parler("GanYing")
	_verifier(lues >= 4, "Gan Ying reconnaît un voyageur de Rome (%d bulles)" % lues)
	_verifier(_id_etape() == "chef_pillards", "le chef des pillards campe au lac salé (%s)" % _id_etape())
	await _attendre(5)
	await _tuer("chef_pillard", combat_joueur, "chef_pillards")
	_verifier(_id_etape() == "faille", "le chef est abattu (%s)" % _id_etape())
	await _attendre(5)
	await _tuer("loup_fracture_faille_jade", combat_joueur, "faille")
	var faille = _scene.find_child("Faille", true, false)
	await _aller_pres(faille)
	await _appuyer_f()
	await _attendre(360)
	_verifier(faille.fermee, "la faille du lac est refermée")
	_verifier(_id_etape() == "recompense_ban_yong", "retour chez Ban Yong (%s)" % _id_etape())
	await _parler("BanYong")
	var inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("jian_ban_chao") >= 1, "l'épée de Ban Chao est dans le sac")
		_verifier(inventaire.quantite("manteau_frontiere") >= 1, "le manteau de la frontière aussi")
	_verifier(_id_etape() == "lettre_gan_ying", "il faut montrer le sceau à Gan Ying (%s)" % _id_etape())
	await _parler("GanYing")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("lettre_gan_ying") >= 1, "la lettre de Gan Ying pour Ban Zhao est dans le sac")
	_verifier(_id_etape() == "vers_fleuve", "chapitres 1 et 2 terminés, le chapitre 3 commence (%s)" % _id_etape())
	await _attendre(30)
	_verifier(_scene._est_ouvert, "la route de l'est s'ouvre")

	# --- La progression est gardée.
	var cfg := ConfigFile.new()
	cfg.load(FICHIER)
	_verifier(cfg.has_section("chine"), "l'avancement est enregistré dans la section « chine »")
	_verifier(String(cfg.get_value("chine", "choix_choix_masque", "")) == "allier_masque", "le choix de l'alliance avec Masque est gardé")
	_verifier(cfg.get_value("rome", "etape", "") == "", "Rome n'est pas touchée")
	_scene.queue_free()
	await _attendre(5)
	await _charger()
	await _attendre(20)
	_verifier(_id_etape() == "vers_fleuve", "au retour, on en est toujours à la route de l'est (%s)" % _id_etape())
	_verifier(_scene.find_child("Faille", true, false).fermee, "la faille est toujours fermée")
	_verifier(not _scene.find_child("FigeMarchand", true, false).fige, "le marchand n'est plus figé")
	var fanal_recharge: Node3D = _scene.find_child("Fanal1", true, false)
	_verifier(fanal_recharge.get_node("Allume").visible, "les fanaux brûlent toujours")
	_verifier(_scene.find_child("FanauxLointains", true, false).visible, "et ceux du bout de la muraille aussi")
	var c2: Node3D = _scene.find_child("CaravaneSoie", true, false)
	_verifier(Vector2(c2.global_position.x, c2.global_position.z).distance_to(Vector2(70, 12)) < 1.0, "la caravane est toujours au relais")

	# La route de l'est mène au Fleuve Jaune.
	var est: Vector2 = _scene.SORTIE_EST
	await _placer(Vector3(est.x - 3.0, _scene.hauteur(est.x - 3.0, est.y) + 0.4, est.y), -PI / 2)
	await _attendre(70)
	_verifier(_quete.zone_demandee == "fleuve_jaune", "au bout de la route, on part vers le Fleuve Jaune (%s)" % _quete.zone_demandee)

	# Retour au hub par le portail (après s'en être éloigné).
	await _placer(Vector3(-70, _scene.hauteur(-70, 50) + 0.3, 50), 0.0)
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
