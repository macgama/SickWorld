extends SceneTree
## Test automatique de la foire de Francfort (zone 4) et du chapitre 7 : l'arrivée par la nef
## de Fust, le quai et les libraires Scellés, le colporteur, les charrettes de Sceau, les
## caisses de livres, le message de Masque, le Römerberg, Sceau et le bûcher, le Bourreau des
## livres, la faille, l'évêque Piccolomini et la récompense de Fust.
## Lancement : godot --headless --path game -s res://tests/test_francfort.gd

const FICHIER := "user://test_mayence_francfort.cfg"
const SCENE := "res://scenes/monde/mayence/francfort.tscn"

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
	await _aller_pres(pnj, Vector3(0, 0, -1.6))
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


func _composer(nom_objet: String, phrase: String) -> void:
	var objet: Node3D = _scene.find_child(nom_objet, true, false)
	await _aller_pres(objet, Vector3(0, 0, -1.2))
	await _appuyer_f()
	await _attendre(3)
	var c = _quete.composteur()
	_verifier(c != null and c.est_ouvert(), "%s : la casse s'ouvre (« %s »)" % [nom_objet, c.phrase() if c != null else "?"])
	if c == null:
		return
	_verifier(phrase == "" or c.phrase() == phrase, "la phrase est « %s » (%s)" % [phrase, c.phrase()])
	c.resoudre()
	await _attendre(110)


func _ramasser(nom: String, attente := 90, decalage := Vector3(0, 0, 1.3)) -> void:
	await _aller_pres(_scene.find_child(nom, true, false), decalage)
	await _appuyer_f()
	await _attendre(attente)


func _lancer() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	var cfg := ConfigFile.new()
	cfg.set_value("mayence", "etape", "vers_francfort")
	cfg.save(FICHIER)
	await _charger()
	print("Test de la foire de Francfort (chapitre 7)")

	# --- Le monde.
	_verifier(_joueur != null and _joueur.is_on_floor(), "on arrive par la nef de Fust")
	var p: Vector3 = _joueur.global_position
	_verifier(p.x < -110.0 and p.z > 90.0, "sur le quai, près du ponton (%.0f, %.0f)" % [p.x, p.z])
	_verifier(_id_etape() == "fust_foire", "l'arrivée termine l'étape de la nef (%s)" % _id_etape())
	for nom in ["Cathedrale", "Romerberg", "Bucher", "VieuxPont", "EschenheimerTurm", "Saalhof", "SaintNicolas", "PreFoire", "EtalsLibraires", "GrueMain"]:
		_verifier(_scene.find_child(nom, true, false) != null, "le décor : %s" % nom)
	var nb_maisons := _scene.find_children("MaisonRhenane*", "Node3D", true, false).size()
	_verifier(nb_maisons >= 50, "des rues de maisons à colombages (%d)" % nb_maisons)
	var nb_arbres: int = _scene.find_child("Arbres", true, false).get_child_count()
	_verifier(nb_arbres >= 30, "des arbres (%d)" % nb_arbres)
	_verifier(_vivants("mercenaire_coupe_bourse").size() >= 3, "des coupe-bourses dans le pré (%d)" % _vivants("mercenaire_coupe_bourse").size())
	var pente_max := 0.0
	for rue in _scene._rues:
		for i in rue.size() - 1:
			var a: Vector2 = rue[i]
			var b: Vector2 = rue[i + 1]
			for k in 20:
				var q0 := a.lerp(b, k / 20.0)
				var q1 := a.lerp(b, (k + 1) / 20.0)
				pente_max = maxf(pente_max, absf(_scene.hauteur(q0.x, q0.y) - _scene.hauteur(q1.x, q1.y)) / maxf(q0.distance_to(q1), 0.1))
	_verifier(pente_max < 0.25, "les rues sont presque plates (pente max %.2f)" % pente_max)
	# On marche du quai jusqu'au Römerberg.
	await _placer(Vector3(-8, _scene.hauteur(-8, 96) + 0.4, 96), 0.0)
	Input.action_press("avancer")
	await _attendre(260)
	Input.action_release("avancer")
	await _attendre(5)
	_verifier(_joueur.global_position.z < 80.0, "on monte la rue du quai vers le Römerberg (z = %.1f)" % _joueur.global_position.z)

	# --- Chapitre 7 : La foire.
	var combat_joueur = _joueur.get_node("Combat")
	var lues := await _parler("JohannFust")
	_verifier(lues >= 3, "Fust à son étal (%d bulles)" % lues)
	_verifier(_id_etape() == "libraires", "les libraires Scellés (%s)" % _id_etape())

	for k in 3:
		await _composer("LibererLibraire%d" % k, "")
	_verifier(_id_etape() == "libraire_parle", "les trois libraires sont délivrés (%s)" % _id_etape())
	await _attendre(30)
	for k in 3:
		_verifier(not _scene.find_child("ScelleLibraire%d" % k, true, false).fige, "la cire est tombée du libraire %d" % k)
	await _parler("ScelleLibraire1")
	_verifier(_id_etape() == "colporteur", "le colporteur (%s)" % _id_etape())
	await _parler("ColporteurMatthis")
	_verifier(_id_etape() == "charrettes", "les charrettes de Sceau (%s)" % _id_etape())
	await _attendre(5)
	_verifier(_vivants("mercenaire_homme_sceau_foire").size() == 4, "quatre hommes de Sceau (%d)" % _vivants("mercenaire_homme_sceau_foire").size())
	await _tuer("mercenaire_homme_sceau_foire", combat_joueur, "charrettes")
	_verifier(_id_etape() == "caisses", "les caisses (%s)" % _id_etape())
	for k in 3:
		await _ramasser("CaisseLivres%d" % k, 140)
	_verifier(_id_etape() == "craie_foire", "le message à la craie (%s)" % _id_etape())
	var sceau = _scene.find_child("Sceau", true, false)
	_verifier(sceau != null and not sceau.visible, "Sceau n'est pas encore là")
	await _ramasser("CraieMasqueFoire", 110, Vector3(-1.3, 0, 0))
	_verifier(_id_etape() == "vers_romer", "monter au Römerberg (%s)" % _id_etape())
	_verifier(sceau.visible, "Sceau attend devant le bûcher")
	await _placer(Vector3(-2, _scene.hauteur(-2, 20) + 0.4, 20), 0.0)
	await _attendre(30)
	_verifier(_id_etape() == "sceau_parle", "le Römerberg (%s)" % _id_etape())
	lues = await _parler("Sceau")
	_verifier(lues >= 3, "Sceau parle (%d bulles)" % lues)
	_verifier(_scene.find_child("FeuBucher", true, false).visible, "le bûcher s'allume")
	_verifier(_id_etape() == "bourreau", "le Bourreau des livres (%s)" % _id_etape())
	await _attendre(5)
	await _tuer("mercenaire_chef_bourreau", combat_joueur, "bourreau")
	_verifier(_id_etape() == "bucher", "éteindre le bûcher (%s)" % _id_etape())
	await _ramasser("BucherRomer", 330)
	_verifier(not _scene.find_child("FeuBucher", true, false).visible, "le feu est éteint")
	_verifier(not sceau.visible, "Sceau est partie")
	_verifier(_id_etape() == "faille", "la faille (%s)" % _id_etape())
	await _attendre(5)
	await _tuer("statue_lettres_plomb_faille_foire", combat_joueur, "faille")
	var faille = _scene.find_child("Faille", true, false)
	await _aller_pres(faille)
	await _appuyer_f()
	await _attendre(360)
	_verifier(faille.fermee, "la faille est refermée")
	_verifier(_id_etape() == "piccolomini", "l'évêque Piccolomini (%s)" % _id_etape())
	lues = await _parler("EneasPiccolomini")
	_verifier(lues >= 3, "Piccolomini lit sans lunettes (%d bulles)" % lues)
	await _parler("JohannFust")
	var inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("cahier_foire") >= 1, "le cahier de la foire")
		_verifier(inventaire.quantite("bottes_colporteur") >= 1, "les bottes de colporteur")
	_verifier(_id_etape() == "retour_mayence", "chapitre 7 terminé : le chapitre 8 commence (%s)" % _id_etape())

	# --- La progression est gardée.
	_scene.queue_free()
	await _attendre(5)
	await _charger()
	await _attendre(20)
	_verifier(_scene.find_child("Faille", true, false).fermee, "au retour, la faille est toujours fermée")
	print("  (étape au retour : %s)" % _id_etape())
	for k in 3:
		_verifier(not _scene.find_child("ScelleLibraire%d" % k, true, false).fige, "au retour, le libraire %d n'est plus Scellé" % k)
	_verifier(not _scene.find_child("FeuBucher", true, false).visible, "le bûcher reste éteint")
	# Le ponton ramène à Mayence.
	await _placer(Vector3(_scene.SORTIE_O.x, 1.6, _scene.SORTIE_O.y - 1.0), 0.0)
	await _attendre(20)
	_verifier(_quete._en_voyage or root.get_node("Reseau").get_meta("arrivee_mayence", "") == "francfort", "la nef de Fust ramène à Mayence")

	print("")
	if _echecs == 0:
		print("TOUS LES TESTS PASSENT")
	else:
		print("%d ÉCHEC(S)" % _echecs)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	quit(1 if _echecs > 0 else 0)
