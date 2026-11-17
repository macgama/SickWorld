extends SceneTree
## Test automatique du chapitre 7 de la Chine (« La grande audience », à Luoyang) : le
## retour en char, Ban Yong, Cai Lun, l'audience, les vagues de soldats d'argile avec les
## gardes, les séchoirs à papier, le général, Cinabre, l'empereur He et l'impératrice Deng.
## Lancement : godot --headless --path game -s res://tests/test_audience.gd

const FICHIER := "user://test_chine_audience.cfg"
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
	# On revient du mont Li en char de poste, au début du chapitre 7.
	await _debut("vers_audience")
	print("Test de la grande audience (Chine, chapitre 7)")
	_verifier(_id_etape() == "ban_yong", "l'arrivée à Luoyang termine l'étape du char (%s)" % _id_etape())
	_verifier(_scene.find_child("Audience", true, false).visible, "le palais est décoré pour le jour de l'an")
	for nom in ["BanYong", "EmpereurHe", "ImperatriceDeng", "FonctionnaireAudience1", "GardePalais3"]:
		_verifier(_scene.find_child(nom, true, false).visible, "%s est au Palais du Sud" % nom)
	_verifier(not _scene.find_child("CinabrePalais", true, false).visible, "Cinabre n'est pas encore là")
	_verifier(not _scene.find_child("Sechoir0", true, false).visible, "les séchoirs ne brûlent pas encore")
	var ban_zhao: Node3D = _scene.find_child("BanZhao", true, false)
	_verifier(_scene.PALAIS_SUD.has_point(Vector2(ban_zhao.global_position.x, ban_zhao.global_position.z)), "Ban Zhao est venue au palais")
	var empereur: Node3D = _scene.find_child("EmpereurHe", true, false)
	_verifier(empereur.global_position.y > _scene.hauteur(20, 70) + 2.0, "l'empereur est sur la terrasse de la Grande Salle")
	# La Grande Salle regarde la cour : on monte les marches depuis la cour.
	await _placer(Vector3(20, _scene.hauteur(20, 72) + 0.4, 72), PI)
	Input.action_press("avancer")
	await _attendre(120)
	Input.action_release("avancer")
	var j: Vector3 = _joueur.global_position
	_verifier(j.y > _scene.hauteur(20, 72) + 2.0, "l'escalier de la Grande Salle donne sur la cour (%.1f, %.1f)" % [j.z, j.y])

	var combat_joueur = _joueur.get_node("Combat")
	var lues := await _parler("BanYong")
	_verifier(lues >= 3, "Ban Yong garde la porte (%d bulles)" % lues)
	_verifier(_id_etape() == "cai_lun_audience", "Cai Lun attend dans la cour (%s)" % _id_etape())
	lues = await _parler("CaiLun")
	_verifier(lues >= 4, "Cai Lun répète son discours (%d bulles)" % lues)
	_verifier(_id_etape() == "audience", "l'audience va commencer (%s)" % _id_etape())
	await _placer(Vector3(20, _scene.hauteur(20, 80) + 0.4, 80), PI)
	await _attendre(10)
	_verifier(_id_etape() == "vague_porte", "les soldats d'argile attaquent (%s)" % _id_etape())
	_verifier(not _scene.find_child("FonctionnaireAudience1", true, false).visible, "les fonctionnaires ont fui")
	_verifier(_scene.find_child("Sechoir0", true, false).visible, "les séchoirs sont dans la cour")
	await _attendre(10)
	_verifier(_vivants("soldat_argile_palais").size() == 6, "six soldats à la grande porte (%d)" % _vivants("soldat_argile_palais").size())
	_verifier(get_nodes_in_group("allie_quete").size() == 2, "Ban Yong et un garde se battent avec toi (%d)" % get_nodes_in_group("allie_quete").size())
	var allie: Node = get_nodes_in_group("allie_quete")[0] if not get_nodes_in_group("allie_quete").is_empty() else null
	_verifier(allie != null and String(allie.get_node("Apparence").find_child("Oublie", true, false).get("variante")) == "han", "les gardes portent l'armure des Han")
	await _tuer("soldat_argile_palais", combat_joueur, "vague_porte")
	_verifier(_id_etape() == "vague_est", "la porte a tenu (%s)" % _id_etape())
	await _attendre(5)
	_verifier(_vivants("arbaletrier_argile_palais").size() == 4, "quatre arbalétriers à l'est (%d)" % _vivants("arbaletrier_argile_palais").size())
	await _tuer("arbaletrier_argile_palais", combat_joueur, "vague_est")
	_verifier(_id_etape() == "feuilles", "il faut sauver les feuilles (%s)" % _id_etape())
	for k in 3:
		await _utiliser("Sechoir%d" % k, Vector2(20, 76), 160)
	_verifier(_id_etape() == "general_palais", "les séchoirs sont éteints (%s)" % _id_etape())
	var eteint = _scene.find_child("Sechoir0", true, false).get_node_or_null("Eteint")
	_verifier(eteint != null and eteint.visible, "il reste les feuilles roussies")
	await _attendre(5)
	_verifier(_vivants("general_argile_palais").size() == 1, "le général d'argile franchit la porte (%d)" % _vivants("general_argile_palais").size())
	await _tuer("general_argile_palais", combat_joueur, "general_palais")
	_verifier(_id_etape() == "cinabre_palais", "le général est tombé (%s)" % _id_etape())
	_verifier(_scene.find_child("CinabrePalais", true, false).visible, "Cinabre applaudit sous la porte")
	lues = await _parler("CinabrePalais")
	_verifier(lues >= 4, "Cinabre menace (%d bulles)" % lues)
	_verifier(not _scene.find_child("CinabrePalais", true, false).visible, "Cinabre est repartie")
	_verifier(get_nodes_in_group("allie_quete").is_empty() or get_nodes_in_group("allie_quete")[0].is_queued_for_deletion(), "les gardes reprennent leur poste")
	lues = await _parler("EmpereurHe")
	_verifier(lues >= 4, "l'empereur parle de la feuille (%d bulles)" % lues)
	lues = await _parler("ImperatriceDeng")
	_verifier(lues >= 4, "l'impératrice ouvre la route du tombeau (%d bulles)" % lues)
	_verifier(_id_etape() == "vers_mont_li_tombeau", "chapitre 7 terminé, en route vers le tombeau (%s)" % _id_etape())
	var inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("bottes_garde_palais") >= 1, "les bottes de la garde sont dans le sac")
	_verifier(ban_zhao.global_position.distance_to(Vector3(103, ban_zhao.global_position.y, 54)) < 1.0, "Ban Zhao est rentrée au pavillon")

	# --- Au retour, le palais garde la trace de l'audience.
	_scene.queue_free()
	await _attendre(5)
	await _charger()
	await _attendre(20)
	_verifier(_id_etape() == "vers_mont_li_tombeau", "au retour, le chapitre 7 est toujours fini")
	_verifier(_scene.find_child("Sechoir1", true, false).visible and _scene.find_child("Sechoir1", true, false).get_node("Eteint").visible, "les séchoirs roussis sont restés")
	_verifier(not _scene.find_child("CinabrePalais", true, false).visible, "Cinabre n'est plus là")
	_verifier(not _scene.find_child("FonctionnaireAudience4", true, false).visible, "les fonctionnaires sont partis")
	_verifier(_scene.find_child("ImperatriceDeng", true, false).visible, "l'impératrice reste au palais")
	var bz: Node3D = _scene.find_child("BanZhao", true, false)
	_verifier(bz.global_position.distance_to(Vector3(103, bz.global_position.y, 54)) < 1.0, "Ban Zhao est au pavillon")

	print("")
	if _echecs == 0:
		print("TOUS LES TESTS PASSENT")
	else:
		print("%d ÉCHEC(S)" % _echecs)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	quit(1 if _echecs > 0 else 0)
