extends SceneTree
## Test automatique de la ville de Rome (Rome, zone 3) et du chapitre 4 : Livia à
## l'Esquilin, Martial sur la place du blé, les Égarés de la foule, le choix de l'émeute
## (les deux branches), le vivarium de Carpophore, la cage ouverte et le rhinocéros.
## Lancement : godot --headless --path game -s res://tests/test_rome.gd

const FICHIER := "user://test_rome_ville.cfg"
const SCENE := "res://scenes/monde/rome/rome.tscn"

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


func _lancer() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	await _debut_chapitre("entrer_rome")
	print("Test de Rome (chapitre 4)")

	# --- Le monde.
	_verifier(_joueur != null and _joueur.is_on_floor(), "on arrive par la porte, sur l'Esquilin")
	var p: Vector3 = _joueur.global_position
	_verifier(Vector2(p.x, p.z).distance_to(_scene.ENTREE) < 10.0, "près de l'entrée (%.0f, %.0f)" % [p.x, p.z])
	_verifier(_id_etape() == "livia_rome", "l'arrivée termine l'étape de la porte (%s)" % _id_etape())
	for nom in ["Colisee", "Colosse", "Forum", "Capitole", "Palatin", "Subure", "ChampDeMars", "Vivarium"]:
		_verifier(_scene.find_child(nom, true, false) != null, "la ville a son %s" % nom)
	_verifier(_scene.hauteur(_scene.CAPITOLE.x, _scene.CAPITOLE.y) > _scene.hauteur(-60, -40) + 15.0, "le Capitole domine le Forum")
	_verifier(_vivants("chien_fracture_subure").size() >= 8, "des chiens errants fracturés (%d)" % _vivants("chien_fracture_subure").size())
	# On ne traverse pas les murs du Colisée.
	var c: Vector2 = _scene.COLISEE
	await _placer(Vector3(c.x, _scene.hauteur(c.x, c.y + 70) + 0.4, c.y + 70), 0.0)
	Input.action_press("avancer")
	await _attendre(240)
	Input.action_release("avancer")
	_verifier(not _scene.dans_colisee(Vector2(_joueur.global_position.x, _joueur.global_position.z), -2.0), "on ne passe pas à travers l'amphithéâtre")

	# --- Chapitre 4 : Du pain et des jeux.
	var combat_joueur = _joueur.get_node("Combat")
	var lues := await _parler("Livia")
	_verifier(lues >= 4, "Livia montre la ville (%d bulles)" % lues)
	_verifier(_id_etape() == "rencontre_martial", "il faut trouver Martial (%s)" % _id_etape())
	lues = await _parler("Martial")
	_verifier(lues >= 3, "Martial raconte l'émeute (%d bulles)" % lues)
	_verifier(_id_etape() == "renouer_foule", "il faut renouer la foule (%s)" % _id_etape())
	for k in 3:
		await _utiliser("RenouerSubure%d" % k)
		await _resoudre_mots()
	await _attendre(20)
	_verifier(_id_etape() == "choix_emeute", "la foule renouée, il faut choisir (%s)" % _id_etape())

	# Première branche : organiser la distribution.
	var frumentarius: Node3D = _scene.find_child("Frumentarius", true, false)
	var f2 := Vector2(frumentarius.global_position.x, frumentarius.global_position.z)
	await _utiliser("TableBle", f2)
	await _lire_dialogue()
	_verifier(_id_etape() == "distribution", "on organise la distribution (%s)" % _id_etape())
	for k in 4:
		await _utiliser("SacBle%d" % k, f2, 140)
	await _attendre(20)
	_verifier(_id_etape() == "vers_vivarium", "le blé est distribué (%s)" % _id_etape())
	var agitateur: Node3D = _scene.find_child("Agitateur", true, false)
	_verifier(agitateur != null and not agitateur.visible, "l'agitateur a disparu")
	_verifier(not _scene.find_child("SacBle0", true, false).actif, "les sacs sont partis")
	lues = await _parler("Carpophore")
	_verifier(lues >= 3, "Carpophore raconte les cages ouvertes (%d bulles)" % lues)
	_verifier(_id_etape() == "cage_rhino", "il faut examiner la cage (%s)" % _id_etape())
	var martial: Node3D = _scene.find_child("Martial", true, false)
	await _attendre(60)
	_verifier(Vector2(martial.global_position.x, martial.global_position.z).distance_to(Vector2(118, 100)) < 3.0, "Martial a suivi jusqu'au vivarium")
	await _utiliser("CageRhino", Vector2(INF, INF), 130)
	_verifier(_id_etape() == "rhinoceros", "la cage n'a pas été forcée (%s)" % _id_etape())
	await _attendre(5)
	var rhino := _vivants("rhinoceros_fracture")
	_verifier(rhino.size() == 1, "le rhinocéros fracturé est dans les jardins (%d)" % rhino.size())
	if rhino.size() > 0:
		_verifier(rhino[0].get_node("Apparence").get("espece") == "rhinoceros", "il a un corps de rhinocéros")
		rhino[0].combat.subir(999999.0, combat_joueur)
	await _attendre(20)
	_verifier(_id_etape() == "fin_martial", "le rhinocéros est abattu (%s)" % _id_etape())
	lues = await _parler("Martial")
	_verifier(lues >= 3, "Martial a tout vu (%d bulles)" % lues)
	var inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("tablettes_martial") >= 1, "les tablettes de Martial sont dans le sac")
		_verifier(inventaire.quantite("corne_rhinoceros") >= 1, "et la corne du rhinocéros")
	_verifier(_id_etape() == "vigiles_incendie", "chapitre 4 terminé, le chapitre 5 commence (%s)" % _id_etape())

	# --- La progression est gardée.
	_scene.queue_free()
	await _attendre(5)
	await _charger()
	_verifier(_id_etape() == "vigiles_incendie", "au retour, la quête reprend où on l'avait laissée")
	_verifier(not _scene.find_child("SacBle1", true, false).actif, "les sacs restent distribués")
	_verifier(not _scene.find_child("Agitateur", true, false).visible, "l'agitateur reste parti")
	# Retour vers la campagne, au sud.
	var s: Vector2 = _scene.SORTIE_SUD
	await _placer(Vector3(s.x, _scene.hauteur(s.x, s.y - 8) + 0.4, s.y - 8), PI)
	Input.action_press("avancer")
	await _attendre(120)
	Input.action_release("avancer")
	_verifier(_quete.zone_demandee == "campagne", "la route du sud ramène à la campagne (%s)" % _quete.zone_demandee)

	# --- Deuxième branche : suivre l'agitateur.
	_scene.queue_free()
	await _attendre(5)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	await _debut_chapitre("choix_emeute")
	await _utiliser("SuivreAgitateur", _scene.PLACE_BLE)
	await _lire_dialogue()
	_verifier(_id_etape() == "filature_ruelles", "on suit l'agitateur (%s)" % _id_etape())
	for z in _scene.FILATURE:
		await _placer(Vector3(z.x, _scene.hauteur(z.x, z.y) + 0.4, z.y), 0.0)
		await _attendre(20)
	_verifier(_id_etape() == "oreillette", "il a laissé tomber quelque chose (%s)" % _id_etape())
	await _utiliser("OreilletteVigie", Vector2(INF, INF), 130)
	_verifier(_id_etape() == "vers_vivarium", "une oreillette de la Vigie (%s)" % _id_etape())
	_verifier(_scene.find_child("SacBle0", true, false).get("_visuel").visible, "dans cette branche, les sacs sont toujours là")

	# --- Chapitre 5 : Les deux visages.
	_scene.queue_free()
	await _attendre(5)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	await _debut_chapitre("vigiles_incendie")
	_verifier(_id_etape() == "vigiles_incendie", "chapitre 5 : la fumée monte du Champ de Mars (%s)" % _id_etape())
	var lues5 := await _parler("Lucretius")
	_verifier(lues5 >= 3, "le centurion des vigiles raconte l'incendie (%d bulles)" % lues5)
	_verifier(_id_etape() == "chaine_seaux", "il faut faire la chaîne des seaux (%s)" % _id_etape())
	for k in 4:
		await _utiliser("FoyerChamp%d" % k, Vector2(INF, INF), 330)
		_verifier(not _scene.find_child("FoyerChamp%d" % k, true, false).actif, "le foyer %d est éteint" % (k + 1))
	_verifier(_id_etape() == "oies_capitole", "le feu gagne le Capitole (%s)" % _id_etape())
	await _utiliser("EnclosOies", _scene.CAPITOLE, 130)
	_verifier(_id_etape() == "retour_lucretius", "les oies sont libres (%s)" % _id_etape())
	await _parler("Lucretius")
	var inv = _joueur.get_node_or_null("Inventaire")
	if inv != null and inv.has_method("quantite"):
		_verifier(inv.quantite("couronne_civique") >= 1, "la couronne civique est dans le sac")
	_verifier(_id_etape() == "surprendre_janus", "une femme près du Panthéon (%s)" % _id_etape())
	await _attendre(30)
	var livia: Node3D = _scene.find_child("Livia", true, false)
	_verifier(Vector2(livia.global_position.x, livia.global_position.z).distance_to(_scene.JANUS) < 3.0, "Livia est devant le Panthéon")
	var j: Vector2 = _scene.JANUS + Vector2(0, 8)
	await _placer(Vector3(j.x, _scene.hauteur(j.x, j.y) + 0.4, j.y), 0.0)
	await _attendre(130)
	_verifier(_id_etape() == "confrontation", "on la surprend (%s)" % _id_etape())
	lues5 = await _parler("Livia")
	_verifier(lues5 >= 3, "Livia est Janus (%d bulles)" % lues5)
	_verifier(_id_etape() == "choix_janus", "il faut lui répondre (%s)" % _id_etape())
	await _utiliser("EcouterJanus", _scene.JANUS)
	await _lire_dialogue()
	_verifier(_id_etape() == "pretoriens_janus", "Janus appelle ses prétoriens (%s)" % _id_etape())
	await _attendre(5)
	var pretoriens := _vivants("pretorien_janus")
	_verifier(pretoriens.size() == 4, "quatre prétoriens (%d)" % pretoriens.size())
	if pretoriens.size() > 0:
		_verifier(pretoriens[0].get_node("Apparence").get("espece") == "oublie", "ils ont un corps humain")
	for pr in pretoriens:
		pr.combat.subir(999999.0, _joueur.get_node("Combat"))
	await _attendre(130)
	_verifier(_id_etape() == "qg_bureau_livia", "Janus s'enfuit, Lenoir ouvre un portail (%s)" % _id_etape())
	_verifier(not livia.visible, "Livia a disparu")
	var portail: Node3D = _scene.find_child("PortailCampagne", true, false)
	_verifier(portail != null and portail.visible, "le portail de campagne est ouvert")
	root.get_node("Reseau").remove_meta("mission_hub_auto")
	_quete.rentrer_au_hub()
	await _attendre(10)
	_verifier(String(root.get_node("Reseau").get_meta("mission_hub_auto", "")) == "bureau_livia", "au QG, la mission du bureau de Livia se lance")
	_verifier(_quete.etape < 0, "chapitre 5 terminé (fin provisoire)")
	root.get_node("Reseau").remove_meta("mission_hub_auto")
	_scene.queue_free()
	await _attendre(5)
	await _charger()
	_verifier(not _scene.find_child("Livia", true, false).visible, "au retour, Livia n'est plus là")
	_verifier(not _scene.find_child("FoyerChamp2", true, false).actif, "le feu reste éteint")

	print("")
	if _echecs == 0:
		print("TOUS LES TESTS PASSENT")
	else:
		print("%d ÉCHEC(S)" % _echecs)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	quit(1 if _echecs > 0 else 0)
