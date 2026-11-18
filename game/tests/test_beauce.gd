extends SceneTree
## Test automatique de la Beauce (Moyen Âge, zone 1) et des chapitres 1 et 2 : la radio de
## Vera et le message de Masque au dolmen, Guillot et les loups du champ, les moissonneurs
## Las (puzzle du vitrail), la fronde, puis le village, le curé, le meunier du moulin, les
## routiers du gibet, leur chef à la lampe frontale, la faille et l'épée de routier.
## Lancement : godot --headless --path game -s res://tests/test_beauce.gd

const FICHIER := "user://test_moyen_age_progression.cfg"
const SCENE := "res://scenes/monde/moyen_age/beauce.tscn"

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


func _lancer() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	await _charger()
	print("Test de la Beauce (Moyen Âge)")

	# --- Le monde.
	_verifier(_joueur != null, "un personnage arrive sur l'île")
	var p: Vector3 = _joueur.global_position
	_verifier(Vector2(p.x, p.z).distance_to(_scene.PORTAIL) < 9.0, "juste devant le portail de la Vigie")
	_verifier(_joueur.is_on_floor(), "il a les pieds sur terre (y = %.2f)" % p.y)
	_verifier(_scene.find_child("Dolmen", true, false) != null, "le portail s'est ouvert sous un dolmen")
	_verifier(_scene.find_child("EgliseVillage", true, false) != null, "le village a son église")
	_verifier(_scene.find_child("Puits", true, false) != null, "et son puits")
	var nb_maisons := _scene.find_children("MaisonPansDeBois*", "Node3D", true, false).size()
	var nb_chaumieres := _scene.find_children("Chaumiere*", "Node3D", true, false).size()
	_verifier(nb_maisons >= 5 and nb_chaumieres >= 3, "des maisons à pans de bois (%d) et des chaumières (%d)" % [nb_maisons, nb_chaumieres])
	_verifier(_scene.find_child("MoulinAVent", true, false) != null, "un moulin à vent sur sa butte")
	var ailes: Node3D = _scene.find_child("Ailes", true, false)
	var angle_avant := ailes.rotation.z
	await _attendre(30)
	_verifier(absf(ailes.rotation.z - angle_avant) > 0.05, "ses ailes tournent")
	_verifier(_scene.find_child("Gibet", true, false) != null, "le gibet sur l'autre butte")
	_verifier(_scene.find_child("FermeGuillot", true, false) != null, "la ferme de Guillot")
	_verifier(_scene.find_child("ChartresLointaine", true, false) != null, "au loin, les tours de Chartres fument encore")
	_verifier(_scene.hauteur(_scene.MOULIN.x, _scene.MOULIN.y) - _scene.hauteur(0, 0) > 2.5, "le moulin est sur une butte")
	_verifier(_scene.dans_champ(-30, 90) > 0.9 and _scene.dans_champ(52, -30) < 0.1, "des champs de blé autour, pas sur la place")
	var nb_arbres: int = _scene.find_child("Arbres", true, false).get_child_count()
	_verifier(nb_arbres >= 20, "des chênes isolés dans la plaine (%d)" % nb_arbres)
	_verifier(get_first_node_in_group("balises") != null, "une balise de la Vigie permet de réapparaître")
	_verifier(_vivants("loup_beauce").size() >= 8, "des loups fracturés rôdent (%d)" % _vivants("loup_beauce").size())
	_verifier(_vivants("sanglier_beauce").size() >= 4, "des sangliers dans les blés (%d)" % _vivants("sanglier_beauce").size())
	var routier: Node = _vivants("mercenaire_routier")[0] if not _vivants("mercenaire_routier").is_empty() else null
	_verifier(routier != null and routier.get_node("Apparence").find_child("Oublie", true, false) != null, "les routiers sont des hommes (pas des loups)")
	var las: Node = _scene.find_child("LasMoissonneur1", true, false)
	_verifier(las != null and las.las and las.fige, "dans le champ, un moissonneur est Las")
	var pente_max := 0.0
	for i in _scene.ROUTE.size() - 1:
		var a: Vector2 = _scene.ROUTE[i]
		var b: Vector2 = _scene.ROUTE[i + 1]
		for k in 20:
			var q0 := a.lerp(b, k / 20.0)
			var q1 := a.lerp(b, (k + 1) / 20.0)
			pente_max = maxf(pente_max, absf(_scene.hauteur(q0.x, q0.y) - _scene.hauteur(q1.x, q1.y)) / maxf(q0.distance_to(q1), 0.1))
	_verifier(pente_max < 0.25, "la route est presque plate (pente max %.2f)" % pente_max)

	# --- Chapitre 1 : Les fumées de Chartres.
	var combat_joueur = _joueur.get_node("Combat")
	_verifier(_id_etape() == "radio_vera", "la quête commence : une radio grésille (%s)" % _id_etape())
	await _aller_pres(_scene.find_child("RadioVera", true, false))
	await _appuyer_f()
	await _attendre(130)
	_verifier(_id_etape() == "craie_masque", "Vera parle à la radio (%s)" % _id_etape())
	var craie: Node3D = _scene.find_child("CraieMasque", true, false)
	await _aller_pres(craie, Vector3(0, 0, 1.4))
	await _appuyer_f()
	await _attendre(110)
	_verifier(_id_etape() == "vers_ferme", "on lit le message de Masque (%s)" % _id_etape())
	await _placer(Vector3(-64, _scene.hauteur(-64, 60) + 0.4, 60), 0.0)
	await _attendre(20)
	_verifier(_id_etape() == "guillot", "au champ, la moisson s'est arrêtée (%s)" % _id_etape())
	var lues := await _parler("Guillot")
	_verifier(lues >= 4, "Guillot raconte la fumée grise (%d bulles)" % lues)
	_verifier(_id_etape() == "loups", "des loups sortent du blé (%s)" % _id_etape())
	await _attendre(5)
	_verifier(_vivants("loup_beauce_moisson").size() == 4, "quatre loups (%d)" % _vivants("loup_beauce_moisson").size())
	await _tuer("loup_beauce_moisson", combat_joueur, "loups")
	_verifier(_id_etape() == "guillot_verre", "les loups sont chassés (%s)" % _id_etape())
	await _parler("Guillot")
	var inventaire = _joueur.get_node_or_null("Inventaire")
	var a_inventaire: bool = inventaire != null and inventaire.has_method("quantite")
	if a_inventaire:
		_verifier(inventaire.quantite("verre_guillot") >= 1, "Guillot donne son morceau de verre bleu")
	_verifier(_id_etape() == "las_moisson", "il faut rendre courage aux moissonneurs (%s)" % _id_etape())
	for k in 3:
		await _vitrail("CourageMoisson%d" % k, ["fleur", "lancette", "rose"][k], k == 0)
		_verifier(_quete.compteur == k + 1 or _id_etape() != "las_moisson", "le moissonneur %d se relève (%d/3)" % [k + 1, _quete.compteur])
	_verifier(_id_etape() == "guillot_fronde", "les trois moissonneurs ont repris courage (%s)" % _id_etape())
	_verifier(las != null and not las.las or not las.fige, "la fumée grise est tombée de Thibaut")
	await _parler("Guillot")
	if a_inventaire:
		_verifier(inventaire.quantite("fronde_berger") >= 1, "la fronde du berger est dans le sac")
	var competences: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/competences.json"))
	_verifier(competences.get("fronde_de_berger", {}).get("etourdit", 0) == 2, "la Fronde de berger étourdit 2 s")

	# --- Chapitre 2 : Le moulin et le gibet.
	_verifier(_id_etape() == "vers_village", "chapitre 2 : vers le village (%s)" % _id_etape())
	await _placer(Vector3(52, _scene.hauteur(52, -26) + 0.4, -26), 0.0)
	await _attendre(20)
	_verifier(_id_etape() == "refugiee", "des réfugiés de Chartres sur la place (%s)" % _id_etape())
	lues = await _parler("RefugieeChartres")
	_verifier(lues >= 4, "Ermengarde raconte l'incendie (%d bulles)" % lues)
	await _vitrail("CourageForgeron", "lancette")
	await _vitrail("CourageLavandiere", "fleur")
	_verifier(_id_etape() == "cure", "le village se relève (%s)" % _id_etape())
	await _parler("CureVillage")
	_verifier(_id_etape() == "vers_moulin", "le curé envoie au moulin (%s)" % _id_etape())
	await _placer(Vector3(-78, _scene.hauteur(-78, -84) + 0.4, -84), 0.0)
	await _attendre(20)
	_verifier(_id_etape() == "meunier_las", "le meunier est Las (%s)" % _id_etape())
	await _vitrail("CourageMeunier", "belle_verriere")
	_verifier(_id_etape() == "meunier", "la Belle Verrière lui rend courage (%s)" % _id_etape())
	_verifier(not _scene.find_child("Meunier", true, false).fige, "le meunier n'est plus gris")
	await _parler("Meunier")
	_verifier(_id_etape() == "routiers", "les routiers ont volé la farine (%s)" % _id_etape())
	await _attendre(5)
	_verifier(_vivants("mercenaire_routier_camp").size() == 5, "cinq routiers au camp (%d)" % _vivants("mercenaire_routier_camp").size())
	await _tuer("mercenaire_routier_camp", combat_joueur, "routiers")
	_verifier(_id_etape() == "sacs", "le camp est libre (%s)" % _id_etape())
	for k in 3:
		var sac: Node3D = _scene.find_child("SacFarine%d" % k, true, false)
		await _aller_pres(sac, Vector3(0, 0, 1.3))
		await _appuyer_f()
		await _attendre(120)
	_verifier(_id_etape() == "chef_routiers", "les trois sacs sont repris (%s)" % _id_etape())
	await _attendre(5)
	await _tuer("mercenaire_chef_routiers", combat_joueur, "chef_routiers")
	_verifier(_id_etape() == "lampe", "le chef est abattu (%s)" % _id_etape())
	await _aller_pres(_scene.find_child("LampeFrontale", true, false), Vector3(0, 0, 1.3))
	await _appuyer_f()
	await _attendre(110)
	if a_inventaire:
		_verifier(inventaire.quantite("lampe_frontale_routier") >= 1, "la lampe frontale est dans le sac")
	_verifier(_id_etape() == "faille", "une faille derrière le gibet (%s)" % _id_etape())
	await _attendre(5)
	await _tuer("loup_faille_beauce", combat_joueur, "faille")
	var faille = _scene.find_child("Faille", true, false)
	await _aller_pres(faille)
	await _appuyer_f()
	await _attendre(360)
	_verifier(faille.fermee, "la faille est refermée")
	_verifier(_id_etape() == "retour_meunier", "retour au moulin (%s)" % _id_etape())
	await _parler("Meunier")
	if a_inventaire:
		_verifier(inventaire.quantite("epee_routier") >= 1, "l'épée de routier est dans le sac")
		_verifier(inventaire.quantite("gambison_beauce") >= 1, "le gambison aussi")
	_verifier(_id_etape() == "vers_bercheres", "chapitres 1 et 2 terminés, le chapitre 3 commence (%s)" % _id_etape())
	await _attendre(30)
	_verifier(_scene._route_ouverte, "la route des carrières s'ouvre au nord-est")
	var ne: Vector2 = _scene.SORTIE_NE
	await _placer(Vector3(ne.x - 3.0, _scene.hauteur(ne.x - 3.0, ne.y) + 0.4, ne.y), -PI / 2)
	await _attendre(70)
	_verifier(_quete.zone_demandee == "bercheres", "au bout de la route, on part vers les carrières (%s)" % _quete.zone_demandee)

	# --- La progression est gardée.
	var cfg := ConfigFile.new()
	cfg.load(FICHIER)
	_verifier(cfg.has_section("moyen_age"), "l'avancement est enregistré dans la section « moyen_age »")
	_verifier(cfg.get_value("chine", "etape", "") == "", "la Chine n'est pas touchée")
	_scene.queue_free()
	await _attendre(5)
	await _charger()
	await _attendre(20)
	_verifier(_scene.find_child("Faille", true, false).fermee, "au retour, la faille est toujours fermée")
	_verifier(not _scene.find_child("LasMoissonneur2", true, false).fige, "Jehan n'est plus Las")
	_verifier(not _scene.find_child("Meunier", true, false).fige, "le meunier non plus")

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
