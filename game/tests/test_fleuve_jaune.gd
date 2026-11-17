extends SceneTree
## Test automatique du Fleuve Jaune et des terres de lœss (Chine, zone 2) et du chapitre 3 :
## les œufs de vers à soie de Mei, les sangliers des mûriers, les brigands du village des
## papetiers, Lao Fan et ses feuilles, le Grand Solitaire, la faille, la traversée du
## Fleuve Jaune sur le grand bac, les pirates de l'autre rive et la rame de papier.
## Lancement : godot --headless --path game -s res://tests/test_fleuve_jaune.gd

const FICHIER := "user://test_chine_fleuve.cfg"
const SCENE := "res://scenes/monde/chine/fleuve_jaune.tscn"

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


func _recolter(nom: String, nombre: int, attente: int) -> void:
	for k in nombre:
		var objet: Node3D = _scene.find_child("%s%d" % [nom, k], true, false)
		_calmer_autour(objet.global_position, 30.0)
		var c: Vector2 = _scene.PAPETIERS.get_center() if nom == "Feuille" else _scene.MEI
		var d := (c - Vector2(objet.global_position.x, objet.global_position.z)).normalized() * 1.4
		await _aller_pres(objet, Vector3(d.x, 0, d.y))
		await _appuyer_f()
		await _attendre(attente)


func _lancer() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	# On reprend au début du chapitre 3 : on arrive de la Porte de Jade.
	var cfg := ConfigFile.new()
	cfg.set_value("chine", "etape", "vers_fleuve")
	cfg.save(FICHIER)
	await _charger()
	print("Test du Fleuve Jaune et des terres de lœss (Chine, chapitre 3)")

	# --- Le monde.
	_verifier(_joueur != null and _joueur.is_on_floor(), "on arrive sur la route, à l'ouest")
	var p: Vector3 = _joueur.global_position
	_verifier(p.x < -150.0, "à l'ouest de la zone (%.0f, %.0f)" % [p.x, p.z])
	_verifier(_id_etape() == "rencontre_mei", "l'arrivée termine l'étape de la route (%s)" % _id_etape())
	_verifier(_scene.find_child("VillageGrottes", true, false) != null, "un village de maisons-grottes au pied de la falaise")
	_verifier(_scene.find_children("Yaodong*", "", true, false).size() >= 6, "des façades de yaodong (%d)" % _scene.find_children("Yaodong*", "", true, false).size())
	var xg: float = _scene.GROTTES[3]
	var zf: float = _scene.pied_falaise(xg)
	_verifier(_scene.hauteur(xg, zf - 3.0) - _scene.hauteur(xg, zf + 3.0) > 7.0, "la falaise de lœss est à pic (%.1f m)" % (_scene.hauteur(xg, zf - 3.0) - _scene.hauteur(xg, zf + 3.0)))
	_verifier(_scene.hauteur(-60, -160) > _scene.hauteur(-60, -70) + 10.0, "les terrasses montent vers le nord")
	_verifier(_scene.find_child("Papetiers", true, false) != null, "le village des papetiers est construit")
	_verifier(_scene.find_child("FleuveJaune", true, false) != null, "le Fleuve Jaune coule à l'est")
	_verifier(_scene.hauteur(112, -60) < -2.0, "le fleuve est profond en son milieu (%.1f)" % _scene.hauteur(112, -60))
	_verifier(_scene.find_child("Glacons", true, false).get_child_count() >= 30, "il charrie des glaçons")
	_verifier(_scene.find_children("Murier*", "", true, false).size() >= 20, "des mûriers taillés (%d)" % _scene.find_children("Murier*", "", true, false).size())
	_verifier(get_first_node_in_group("balises") != null, "une balise de la Vigie permet de réapparaître")
	_verifier(_vivants("sanglier_fracture_loess").size() >= 6, "des sangliers fracturés sur les terrasses (%d)" % _vivants("sanglier_fracture_loess").size())
	_verifier(_vivants("pirate_fleuve").size() >= 4, "des pirates sur l'autre rive (%d)" % _vivants("pirate_fleuve").size())
	var bac: Node3D = _scene.find_child("GrandBac", true, false)
	_verifier(bac != null and bac.get_meta("identifiant", "") == "grand_bac", "le grand bac attend à quai")
	# On ne passe pas le fleuve à pied.
	await _placer(Vector3(70, _scene.hauteur(70, -40) + 0.4, -40), -PI / 2)
	Input.action_press("avancer")
	await _attendre(240)
	Input.action_release("avancer")
	_verifier(_joueur.global_position.x < 100.0, "on ne traverse pas le fleuve à pied (x = %.0f)" % _joueur.global_position.x)

	# --- Chapitre 3 : La soie et le fleuve.
	var combat_joueur = _joueur.get_node("Combat")
	_calmer_autour(Vector3(-60, 4, -40), 50.0)
	var lues := await _parler("Mei")
	_verifier(lues >= 4, "Mei appelle à l'aide (%d bulles)" % lues)
	_verifier(_id_etape() == "oeufs", "il faut sauver les œufs (%s)" % _id_etape())
	await _recolter("Oeufs", 4, 160)
	_verifier(_id_etape() == "sangliers", "les œufs sont sauvés (%s)" % _id_etape())
	var claie: Node3D = _scene.find_child("Oeufs0", true, false)
	_verifier(claie.get_node_or_null("Sauve") != null and claie.get_node("Sauve").visible, "les feuilles d'œufs sont propres")
	_verifier(not _scene.find_child("FumeeMagnanerie", true, false).visible, "la fumée violette de la grotte s'est éteinte")
	await _attendre(5)
	_verifier(_vivants("sanglier_fracture_champs").size() == 4, "quatre sangliers dans les mûriers (%d)" % _vivants("sanglier_fracture_champs").size())
	await _tuer("sanglier_fracture_champs", combat_joueur, "sangliers")
	_verifier(_id_etape() == "mei_papetiers", "les sangliers sont chassés (%s)" % _id_etape())
	await _parler("Mei")
	_verifier(_id_etape() == "brigands", "le village des papetiers brûle (%s)" % _id_etape())
	_verifier(_scene.find_child("IncendiePapetiers", true, false).visible, "on voit la fumée de l'incendie")
	await _placer(Vector3(26, _scene.hauteur(26, 46) + 0.4, 46), 0.0)
	await _attendre(5)
	_verifier(_vivants("pillard_loess_village").size() == 5, "cinq brigands (%d)" % _vivants("pillard_loess_village").size())
	var brigand: Node = _vivants("pillard_loess_village")[0] if not _vivants("pillard_loess_village").is_empty() else null
	_verifier(brigand != null and brigand.get_node("Apparence").find_child("Oublie", true, false) != null, "les brigands sont des hommes")
	await _tuer("pillard_loess_village", combat_joueur, "brigands")
	_verifier(_id_etape() == "lao_fan", "les brigands sont chassés (%s)" % _id_etape())
	_verifier(not _scene.find_child("IncendiePapetiers", true, false).visible, "l'incendie est éteint")
	lues = await _parler("LaoFan")
	_verifier(lues >= 4, "Lao Fan explique le papier et Cai Lun (%d bulles)" % lues)
	_verifier(_id_etape() == "feuilles", "il faut décoller les feuilles (%s)" % _id_etape())
	await _recolter("Feuille", 5, 110)
	_verifier(_id_etape() == "solitaire", "les cent feuilles sont sauvées (%s)" % _id_etape())
	await _attendre(5)
	var solitaire := _vivants("sanglier_geant_loess")
	_verifier(solitaire.size() == 1, "le Grand Solitaire garde la faille (%d)" % solitaire.size())
	if solitaire.size() > 0:
		_verifier(solitaire[0].get_node("Apparence").get("espece") == "sanglier", "il a un corps de sanglier")
		solitaire[0].combat.subir(999999.0, combat_joueur)
	await _attendre(20)
	_verifier(_id_etape() == "faille", "le Grand Solitaire est abattu (%s)" % _id_etape())
	var faille = _scene.find_child("Faille", true, false)
	_calmer_autour(faille.global_position, 40.0)
	await _aller_pres(faille)
	await _appuyer_f()
	await _attendre(360)
	_verifier(faille.fermee, "la faille est refermée")
	_verifier(_id_etape() == "lao_fan_bac", "retour chez Lao Fan (%s)" % _id_etape())
	await _parler("LaoFan")
	_verifier(_id_etape() == "embarquer", "Lao Fan part au bac (%s)" % _id_etape())
	_verifier(not _scene.find_child("LaoFan", true, false).visible and _scene.find_child("LaoFanBac", true, false).visible, "Lao Fan attend au bac")

	# La traversée.
	var monter: Node3D = _scene.find_child("MonterBac", true, false)
	await _aller_pres(monter, Vector3(-1.5, 0, 0))
	_verifier(_joueur.is_on_floor(), "on tient debout sur la rampe du débarcadère")
	await _appuyer_f()
	await _attendre(10)
	_verifier(bac.en_route, "le bac quitte la rive")
	var j: Vector3 = _joueur.global_position
	_verifier(j.distance_to(bac.global_position) < 4.0, "on est à bord du bac")
	var images := 0
	while bac.en_route and images < 2400:
		images += 1
		await physics_frame
	j = _joueur.global_position
	_verifier(not bac.en_route and j.x > 120.0, "le bac arrive sur l'autre rive avec nous (x = %.0f, %d images)" % [j.x, images])
	await _attendre(20)
	_verifier(_id_etape() == "pirates", "des pirates attendent sur la rive (%s)" % _id_etape())
	# On descend du bac à pied, sur la rampe de l'autre rive.
	_calmer_autour(j, 60.0)
	await _attendre(5)
	await _placer(Vector3(j.x, j.y + 0.3, 12.0), -PI / 2)
	Input.action_press("avancer")
	await _attendre(320)
	Input.action_release("avancer")
	j = _joueur.global_position
	_verifier(j.x > 141.0 and j.y > 2.0, "on descend du bac et on monte sur la berge (%.0f, %.1f)" % [j.x, j.y])
	await _tuer("pirate_fleuve_bac", combat_joueur, "pirates")
	_verifier(_id_etape() == "lao_fan_est", "les pirates sont chassés (%s)" % _id_etape())
	lues = await _parler("LaoFanEst")
	_verifier(lues >= 4, "Lao Fan confie sa rame de papier (%d bulles)" % lues)
	var inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("rame_lao_fan") >= 1, "la rame de papier est dans le sac")
		_verifier(inventaire.quantite("gants_papetier") >= 1, "et les gants du papetier")
	_verifier(_id_etape() == "vers_luoyang", "chapitre 3 terminé, en route pour Luoyang (%s)" % _id_etape())
	await _attendre(30)
	_verifier(_scene._est_ouvert, "la route de Luoyang s'ouvre")

	# Le passeur ramène sur la rive ouest, et inversement.
	var passeurs := get_nodes_in_group("passeurs")
	_verifier(passeurs.size() == 2, "un passeur sur chaque rive (%d)" % passeurs.size())
	for passeur in passeurs:
		if passeur.global_position.x > 112.0:
			await _aller_pres(passeur, Vector3(1.2, 0, 0))
			await _appuyer_f()
			await _attendre(20)
	_verifier(_joueur.global_position.x < 84.0, "le passeur nous ramène sur la rive ouest (x = %.0f)" % _joueur.global_position.x)

	# --- La progression est gardée.
	cfg = ConfigFile.new()
	cfg.load(FICHIER)
	_verifier(cfg.has_section("chine"), "l'avancement est enregistré dans la section « chine »")
	_scene.queue_free()
	await _attendre(5)
	await _charger()
	await _attendre(20)
	_verifier(_id_etape() == "vers_luoyang", "au retour, on est toujours en route pour Luoyang (%s)" % _id_etape())
	_verifier(_scene.find_child("Faille", true, false).fermee, "la faille est toujours fermée")
	_verifier(not _scene.find_child("FumeeMagnanerie", true, false).visible, "la grotte ne fume plus")
	_verifier(not _scene.find_child("IncendiePapetiers", true, false).visible, "le village ne brûle plus")
	_verifier(_scene.find_child("Oeufs2", true, false).get_node("Sauve").visible, "les œufs sont toujours sauvés")
	_verifier(_scene.find_child("LaoFanEst", true, false).visible, "Lao Fan est sur l'autre rive")
	# Vers l'ouest, la route ramène à la Porte de Jade.
	var o: Vector2 = _scene.ENTREE
	await _placer(Vector3(o.x + 8.0, _scene.hauteur(o.x + 8.0, o.y) + 0.4, o.y), PI / 2)
	Input.action_press("avancer")
	await _attendre(60)
	Input.action_release("avancer")
	await _attendre(60)
	_verifier(_quete.zone_demandee == "porte_de_jade", "la route de l'ouest ramène à la Porte de Jade (%s)" % _quete.zone_demandee)
	# Vers l'est, la route mène à Luoyang.
	_quete.zone_demandee = ""
	var s_est: Vector2 = _scene.SORTIE_EST
	await _placer(Vector3(s_est.x - 8.0, _scene.hauteur(s_est.x - 8.0, s_est.y) + 0.4, s_est.y), -PI / 2)
	Input.action_press("avancer")
	await _attendre(60)
	Input.action_release("avancer")
	await _attendre(30)
	_verifier(_quete.zone_demandee == "luoyang", "la route de l'est mène à Luoyang (%s)" % _quete.zone_demandee)

	print("")
	if _echecs == 0:
		print("TOUS LES TESTS PASSENT")
	else:
		print("%d ÉCHEC(S)" % _echecs)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	quit(1 if _echecs > 0 else 0)
