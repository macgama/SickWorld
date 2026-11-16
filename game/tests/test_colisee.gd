extends SceneTree
## Test automatique de l'amphithéâtre flavien (le Colisée, intérieur) et du chapitre 7 :
## Martial devant l'arche, l'entrée, la loge de Titus, les prétoriens des gradins, les
## jarres de poix, les lions et le champion de Domitien (avec Priscus et Verus à nos
## côtés), la libération des gladiateurs, le Colosse qui s'éveille et l'égoutier.
## Lancement : godot --headless --path game -s res://tests/test_colisee.gd

const FICHIER := "user://test_rome_colisee.cfg"
var SCENE := "res://scenes/monde/rome/rome.tscn"

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
	while not _joueur.is_on_floor() and images < 120:
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
	if pnj == null:
		print("  (PNJ introuvable : %s)" % id_noeud)
		return 0
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


func _calmer_autour(p: Vector3, rayon: float) -> void:
	var combat_joueur = _joueur.get_node("Combat")
	for bete in get_nodes_in_group("loups"):
		if bete.combat.est_vivant() and bete.global_position.distance_to(p) < rayon:
			bete.combat.subir(999999.0, combat_joueur)


## Angle de caméra pour regarder dans la direction « d » (le nord est vers -Z).
func _angle_vers(d: Vector2) -> float:
	return atan2(-d.x, -d.y)


## Marche tout droit pendant « images » images et rend la plus grande hauteur atteinte.
func _marcher_et_mesurer(images: int) -> float:
	var y_max: float = _joueur.global_position.y
	Input.action_press("avancer")
	for i in images:
		await physics_frame
		if _joueur.is_on_floor():
			y_max = maxf(y_max, _joueur.global_position.y)
	Input.action_release("avancer")
	await _attendre(5)
	return y_max


func _charger() -> void:
	_scene = load(SCENE).instantiate()
	_quete = _scene.get_node("Quete")
	_quete.fichier_progression = FICHIER
	_quete.voyage_reel = false
	root.add_child(_scene)
	await _attendre(40)
	_joueur = get_first_node_in_group("joueur_local")
	_dialogue = get_first_node_in_group("dialogue")


func _utiliser(id_noeud: String, loin_de := Vector2.INF, attente := 20) -> void:
	var objet: Node3D = _scene.find_child(id_noeud, true, false)
	if objet == null:
		print("  (objet introuvable : %s)" % id_noeud)
		return
	var o := Vector2(objet.global_position.x, objet.global_position.z)
	var dir := Vector2(0, 1)
	if loin_de != Vector2.INF:
		dir = (o - loin_de).normalized()
	var p := o + dir * 1.3
	await _placer(Vector3(p.x, _scene.hauteur(p.x, p.y) + 0.4, p.y), _angle_vers(-dir))
	await _appuyer_f()
	await _attendre(attente)


func _resoudre_mots() -> void:
	await _attendre(3)
	var puzzle = _quete.puzzle_mots()
	_verifier(puzzle != null and puzzle.est_ouvert(), "la fenêtre des mots s'ouvre")
	if puzzle != null:
		puzzle.resoudre()
	await _attendre(60)


func _debut_chapitre(etape: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("rome", "etape", etape)
	cfg.save(FICHIER)
	await _charger()


func _tuer(type: String) -> void:
	var combat_joueur = _joueur.get_node("Combat")
	for bete in _vivants(type):
		bete.combat.subir(999999.0, combat_joueur)


func _allies() -> Array:
	var liste := []
	for n in get_nodes_in_group("allie_quete"):
		if not n.is_queued_for_deletion():
			liste.append(n)
	return liste


func _lancer() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Test de l'amphithéâtre flavien (chapitre 7)")

	# --- À Rome : Martial devant l'arche de l'ouest.
	await _debut_chapitre("martial_jeux")
	var inventaire = _joueur.get_node_or_null("Inventaire")
	var martial: Node3D = _scene.find_child("MartialJeux", true, false)
	_verifier(martial != null and martial.visible, "Martial attend devant l'amphithéâtre")
	var martial_ble: Node3D = _scene.find_child("Martial", true, false)
	_verifier(martial_ble != null and not martial_ble.visible, "il n'est plus sur la place du blé")
	var lues := await _parler("MartialJeux")
	_verifier(lues >= 3, "Martial raconte le programme de Domitien (%d bulles)" % lues)
	_verifier(_id_etape() == "entrer_colisee", "il faut entrer dans l'amphithéâtre (%s)" % _id_etape())
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("tessere_jeux") >= 1, "la tessère est dans le sac")
	var porte: Vector2 = _scene.PORTE_COLISEE
	await _placer(Vector3(porte.x - 8.0, _scene.hauteur(porte.x - 8.0, porte.y) + 0.4, porte.y), _angle_vers(Vector2(1, 0)))
	Input.action_press("avancer")
	await _attendre(150)
	Input.action_release("avancer")
	_verifier(_quete.zone_demandee == "colisee", "la grande arche de l'ouest mène dans l'amphithéâtre (%s)" % _quete.zone_demandee)
	_scene.queue_free()
	await _attendre(5)

	# --- Dans l'amphithéâtre.
	SCENE = "res://scenes/monde/rome/colisee.tscn"
	await _charger()
	_verifier(_joueur != null and _joueur.is_on_floor(), "on arrive sur la terrasse du podium")
	var p: Vector3 = _joueur.global_position
	_verifier(absf(p.y - _scene.PODIUM) < 0.8 and Vector2(p.x, p.z).distance_to(_scene.ENTREE) < 4.0, "par le vomitoire de l'ouest (%.1f, %.1f, %.1f)" % [p.x, p.y, p.z])
	_verifier(_id_etape() == "loge_titus", "l'arrivée termine l'étape de l'entrée (%s)" % _id_etape())
	for nom in ["Podium", "Rampe", "Gradins", "Portique", "Loges", "Vomitoire", "Arene", "Foule", "Velarium0"]:
		_verifier(_scene.find_child(nom, true, false) != null, "l'amphithéâtre a son %s" % nom)
	var foule: MultiMeshInstance3D = _scene.find_child("Foule", true, false)
	_verifier(foule != null and foule.multimesh.instance_count > 6000, "une foule immense (%d)" % (foule.multimesh.instance_count if foule else 0))
	_verifier(absf(_scene.hauteur(0, 0)) < 0.01 and absf(_scene.hauteur(0, -27) - 4.0) < 0.01 and _scene.hauteur(0, -66) > 26.0,
			"l'arène, le podium, le haut des gradins (%.1f, %.1f, %.1f)" % [_scene.hauteur(0, 0), _scene.hauteur(0, -27), _scene.hauteur(0, -66)])
	# On monte les gradins à pied, depuis la terrasse du nord.
	await _placer(Vector3(10, 4.4, -27), _angle_vers(Vector2(0, -1)))
	var y_haut := await _marcher_et_mesurer(260)
	_verifier(y_haut > 12.0, "on monte les gradins à pied (%.1f m)" % y_haut)
	# On descend dans l'arène par la rampe de bois.
	var a: float = _scene.ANGLE_RAMPE
	var haut_rampe: Vector2 = _scene.point_ellipse(a, 2.5)
	var n: Vector2 = _scene.normale_ellipse(a, 0.0)
	await _placer(Vector3(haut_rampe.x, 4.4, haut_rampe.y), _angle_vers(-n))
	Input.action_press("avancer")
	await _attendre(150)
	Input.action_release("avancer")
	await _attendre(20)
	p = _joueur.global_position
	_verifier(p.y < 0.8 and _scene.decalage(p.x, p.z) < -1.0, "la rampe descend sur le sable (%.1f, %.1f, %.1f)" % [p.x, p.y, p.z])
	# Le mur du podium arrête quand on veut remonter ailleurs.
	await _placer(Vector3(0, 0.4, -18), _angle_vers(Vector2(0, -1)))
	Input.action_press("avancer")
	await _attendre(120)
	Input.action_release("avancer")
	_verifier(_joueur.global_position.y < 1.0, "le mur du podium arrête le joueur (%.1f)" % _joueur.global_position.y)

	# --- Chapitre 7, dans l'amphithéâtre.
	lues = await _parler("Titus")
	_verifier(lues >= 3, "Titus reçoit le Pérégrin dans sa loge (%d bulles)" % lues)
	_verifier(_id_etape() == "comploteurs_gradins", "des hommes en gris dans les gradins (%s)" % _id_etape())
	await _attendre(5)
	var pretoriens := _vivants("pretorien_gradins")
	_verifier(pretoriens.size() == 4, "quatre prétoriens de Domitien (%d)" % pretoriens.size())
	if pretoriens.size() > 0:
		_verifier(pretoriens[0].global_position.y > 10.0, "ils sont haut dans les gradins (%.1f)" % pretoriens[0].global_position.y)
	_tuer("pretorien_gradins")
	await _attendre(130)
	_verifier(_id_etape() == "jarres_poix", "il reste les jarres de poix (%s)" % _id_etape())
	for i in 3:
		var jarre: Node3D = _scene.find_child("JarrePoix%d" % i, true, false)
		_verifier(jarre != null and jarre.actif, "la jarre %d attend" % i)
		await _utiliser("JarrePoix%d" % i, Vector2(INF, INF), 200)
	await _attendre(130)
	_verifier(_id_etape() == "retour_titus", "les trois mèches sont éteintes (%s)" % _id_etape())
	_verifier(not _scene.find_child("Domitien", true, false).visible, "Domitien a quitté la loge")
	lues = await _parler("Titus")
	_verifier(_id_etape() == "lions_arene", "la porte des bêtes s'ouvre (%s)" % _id_etape())
	await _attendre(40)
	var lions := _vivants("lion_arene")
	_verifier(lions.size() == 5, "cinq lions fracturés dans l'arène (%d)" % lions.size())
	var allies := _allies()
	_verifier(allies.size() == 2, "Priscus et Verus combattent à nos côtés (%d)" % allies.size())
	var faction: String = _joueur.get_node("Combat").faction
	for allie in allies:
		_verifier(allie.combat.faction == faction and allie.maitre == _joueur, "%s est de notre camp" % allie.type_ennemi)
		_verifier(allie.get_node("Apparence").get("espece") == "oublie", "%s est un homme" % allie.type_ennemi)
	_tuer("lion_arene")
	await _attendre(130)
	_verifier(_id_etape() == "champion_domitien", "le champion de Domitien sort (%s)" % _id_etape())
	await _attendre(20)
	var champions := _vivants("gladiateur_champion_fracture")
	_verifier(champions.size() == 1, "un champion fracturé (%d)" % champions.size())
	_verifier(_allies().size() == 2, "les gladiateurs sont toujours là")
	if champions.size() == 1:
		champions[0].combat.subir(champions[0].combat.pv * 0.6, _joueur.get_node("Combat"))
		await _attendre(20)
		_verifier(_vivants("lion_arene").size() == 2, "à mi-vie, deux lions de renfort (%d)" % _vivants("lion_arene").size())
	_tuer("lion_arene")
	_tuer("gladiateur_champion_fracture")
	await _attendre(130)
	_verifier(_id_etape() == "liberte_gladiateurs", "le champion tombe (%s)" % _id_etape())
	await _attendre(10)
	_verifier(_allies().size() == 0, "les gladiateurs alliés s'en vont")
	_verifier(_scene.find_child("Priscus", true, false).visible, "Priscus attend au milieu de l'arène")
	lues = await _parler("Priscus")
	_verifier(_id_etape() == "parole_titus", "Titus est descendu dans l'arène (%s)" % _id_etape())
	var titus: Node3D = _scene.find_child("Titus", true, false)
	_verifier(titus.global_position.y < 1.0, "Titus est sur le sable (%.1f)" % titus.global_position.y)
	lues = await _parler("Titus")
	_verifier(lues >= 3, "Titus libère Priscus et Verus (%d bulles)" % lues)
	if inventaire != null and inventaire.has_method("quantite"):
		inventaire = _joueur.get_node_or_null("Inventaire")
		_verifier(inventaire.quantite("rudis_honneur") >= 1, "la rudis de l'arène est dans le sac")
	_verifier(_id_etape() == "colosse_regard", "Martial attend au pied du Colosse (%s)" % _id_etape())
	# On ressort par le vomitoire de l'ouest.
	var v: Vector2 = _scene.VOMITOIRE
	await _placer(Vector3(v.x + 4.0, 4.4, v.y), _angle_vers(Vector2(-1, 0)))
	Input.action_press("avancer")
	await _attendre(90)
	Input.action_release("avancer")
	_verifier(_quete.zone_demandee == "rome", "le vomitoire ramène dans Rome (%s)" % _quete.zone_demandee)
	_scene.queue_free()
	await _attendre(5)

	# --- De retour dans Rome : le Colosse, Martial, l'égoutier.
	SCENE = "res://scenes/monde/rome/rome.tscn"
	root.get_node("Reseau").set_meta("arrivee_rome", "colisee")
	await _charger()
	p = _joueur.global_position
	_verifier(Vector2(p.x, p.z).distance_to(_scene.PORTE_COLISEE) < 9.0, "on ressort devant la grande arche (%.0f, %.0f)" % [p.x, p.z])
	martial = _scene.find_child("MartialJeux", true, false)
	_verifier(Vector2(martial.global_position.x, martial.global_position.z).distance_to(_scene.MARTIAL_COLOSSE) < 1.0, "Martial est au pied du Colosse")
	await _placer(Vector3(22, _scene.hauteur(22, -44) + 0.4, -44), 0.0)
	await _attendre(130)
	_verifier(_id_etape() == "martial_colosse", "le Colosse a tourné la tête (%s)" % _id_etape())
	_verifier(_scene.find_child("YeuxColosse", true, false).visible, "ses yeux brillent de violet")
	lues = await _parler("MartialJeux")
	_verifier(_id_etape() == "bouche_egout", "direction la Cloaca Maxima (%s)" % _id_etape())
	lues = await _parler("Egoutier")
	_verifier(lues >= 3, "l'égoutier ouvre la grille (%d bulles)" % lues)
	inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("plan_cloaca") >= 1, "le plan des égouts est dans le sac")
	_verifier(_quete.etape < 0, "chapitre 7 terminé (fin provisoire)")

	# --- La progression est gardée.
	_scene.queue_free()
	await _attendre(5)
	await _charger()
	_verifier(_scene.find_child("YeuxColosse", true, false).visible, "au retour, les yeux du Colosse brillent toujours")
	_verifier(not _scene.find_child("Martial", true, false).visible, "Martial n'est pas revenu sur la place du blé")

	print("")
	if _echecs == 0:
		print("TOUS LES TESTS PASSENT")
	else:
		print("%d ÉCHEC(S)" % _echecs)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	quit(1 if _echecs > 0 else 0)
