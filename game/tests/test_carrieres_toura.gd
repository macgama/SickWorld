extends SceneTree
## Test automatique du chapitre 3 de l'Égypte : la traversée du Nil dans la barque de
## Merer, puis les Carrières de Toura (Iry, les carriers oubliés à qui l'on rend leur
## nom, l'encre, la galerie, la faille, l'amulette) et le passeur du retour.
## Lancement : godot --headless --path game -s res://tests/test_carrieres_toura.gd

const FICHIER := "user://test_egypte_progression.cfg"
const PORT := "res://scenes/monde/egypte/port_des_marais.tscn"
const TOURA := "res://scenes/monde/egypte/carrieres_toura.tscn"

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
	# Dans l'eau, le sol est plus bas que la surface : on attend qu'il ait pied.
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


func _aller_pres(cible: Node3D) -> void:
	var p: Vector3 = cible.global_position + Vector3(0, 0, 1.6)
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


func _charger(scene: String) -> void:
	if _scene != null and is_instance_valid(_scene):
		_scene.queue_free()
		await _attendre(5)
	_scene = load(scene).instantiate()
	_quete = _scene.get_node("Quete")
	_quete.fichier_progression = FICHIER
	_quete.voyage_reel = false
	root.add_child(_scene)
	await _attendre(40)
	_joueur = get_first_node_in_group("joueur_local")
	_dialogue = get_first_node_in_group("dialogue")


func _lancer() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	# On reprend juste après le chapitre 2 : Merer attend près de sa barque.
	var cfg := ConfigFile.new()
	cfg.set_value("egypte", "etape", "embarquer")
	cfg.save(FICHIER)
	await _charger(PORT)
	print("Test du chapitre 3 (Égypte) : traversée et Carrières de Toura")

	# --- La traversée.
	_verifier(_id_etape() == "embarquer", "la quête reprend au chapitre 3 (%s)" % _id_etape())
	var barque = _scene.find_child("BarqueMerer", true, false)
	_verifier(barque != null, "la barque de Merer est amarrée au quai")
	var passeur_port = _scene.find_child("Passeur", true, false)
	_verifier(passeur_port != null and not passeur_port.ouvert(), "le passeur ne traverse pas encore")
	await _aller_pres(_scene.find_child("MonterBarque", true, false))
	await _appuyer_f()
	await _attendre(10)
	_verifier(barque.en_route, "on monte à bord : la barque part")
	_verifier(_id_etape() == "traversee", "étape : traverser le Nil (%s)" % _id_etape())
	_verifier(_joueur.global_position.distance_to(barque.global_position) < 6.0, "le joueur est sur le pont")
	barque.vitesse = 25.0
	var a_bord := true
	for i in 90:
		await _attendre(10)
		if barque.en_route and _joueur.global_position.distance_to(barque.global_position) > 7.5:
			a_bord = false
		if _quete.zone_demandee != "":
			break
	_verifier(a_bord, "le joueur reste à bord pendant toute la traversée")
	_verifier(_joueur.global_position.x > 60.0, "la barque est sortie du port par le chenal (x = %.0f)" % _joueur.global_position.x)
	_verifier(_quete.zone_demandee == "carrieres_toura", "au large, on arrive à Toura (%s)" % _quete.zone_demandee)
	_verifier(passeur_port.ouvert(), "désormais, le passeur du port traverse")

	# --- Les Carrières de Toura.
	await _charger(TOURA)
	_verifier(_joueur != null and _joueur.is_on_floor(), "on débarque sur la berge de Toura")
	_verifier(_id_etape() == "rencontre_iry", "l'arrivée termine la traversée (%s)" % _id_etape())
	_verifier(_scene.hauteur(-140, 0) < -1.0, "le Nil coule à l'ouest")
	_verifier(_scene.hauteur(120, 60) > 30.0, "la falaise domine à l'est (%.0f m)" % _scene.hauteur(120, 60))
	var g1: float = _scene.hauteur(50, -30)
	var g2: float = _scene.hauteur(68, -30)
	_verifier(g2 > g1 + 3.0, "la carrière est taillée en gradins (%.1f → %.1f m)" % [g1, g2])
	_verifier(_vivants("babouin").size() >= 4 and _vivants("babouin_fracture").size() >= 4, "des babouins vivent sur les gradins")
	var babouin = _vivants("babouin_fracture")[0] if not _vivants("babouin_fracture").is_empty() else null
	_verifier(babouin != null and babouin.get_node("Apparence").get("_delegue") != null, "les babouins ont leur propre corps")

	# On peut entrer dans la galerie.
	await _placer(Vector3(36, _scene.H_PIED + 0.4, -70), -PI / 2)
	Input.action_press("avancer")
	await _attendre(90)
	Input.action_release("avancer")
	await _attendre(5)
	_verifier(_joueur.global_position.x > 42.0 and absf(_joueur.global_position.y - _scene.H_PIED) < 1.0,
			"on marche dans la galerie (x = %.1f, y = %.1f)" % [_joueur.global_position.x, _joueur.global_position.y])

	var lues := await _parler("Iry")
	_verifier(lues >= 4, "Iry raconte les carriers sans nom (%d bulles)" % lues)
	_verifier(_id_etape() == "oublies", "il faut rendre leur nom aux oubliés (%s)" % _id_etape())
	await _attendre(5)
	var oublies := _vivants("oublie")
	_verifier(oublies.size() == 3, "trois carriers oubliés errent autour du camp (%d)" % oublies.size())
	_verifier(oublies.size() > 0 and oublies[0].get_node("Apparence").get("_delegue") != null, "ce sont des hommes, pas des bêtes")
	var combat_joueur = _joueur.get_node("Combat")
	for o in oublies:
		o.combat.subir(99999.0, combat_joueur)
	await _attendre(30)
	var objets := []
	for k in 3:
		var obj = _scene.find_child("RendreNom%d" % k, true, false)
		if obj != null:
			objets.append(obj)
	_verifier(objets.size() == 3, "à terre, on peut leur rendre leur nom (%d)" % objets.size())
	for obj in objets:
		await _placer(obj.global_position + Vector3(0, 0.5, 1.2), 0.0)
		await _appuyer_f()
		await _attendre(170)
	_verifier(_id_etape() == "rapport_iry", "les trois carriers retrouvent leur nom (%s)" % _id_etape())
	await _attendre(20)
	_verifier(_scene.find_child("CarrierSenedjem", true, false) != null, "Senedjem se relève, guéri")
	_verifier(_vivants("oublie").is_empty(), "il n'y a plus d'oubliés")
	await _parler("Iry")
	_verifier(_id_etape() == "encre", "Iry envoie chercher l'encre (%s)" % _id_etape())
	for k in 4:
		await _aller_pres(_scene.find_child("Encre%d" % k, true, false))
		await _appuyer_f()
		await _attendre(90)
	_verifier(_id_etape() == "galerie", "les fragments d'encre sont ramassés (%s)" % _id_etape())
	await _placer(Vector3(78, _scene.H_PIED + 0.4, -70), -PI / 2)
	await _attendre(30)
	_verifier(_id_etape() == "faille", "au fond de la galerie, la faille (%s)" % _id_etape())
	await _attendre(5)
	var sortis := _vivants("babouin_fracture_faille")
	_verifier(sortis.size() == 3, "trois babouins fracturés en sortent (%d)" % sortis.size())
	for b in sortis:
		b.combat.subir(99999.0, combat_joueur)
	await _attendre(5)
	var faille = _scene.find_child("Faille", true, false)
	await _placer(faille.global_position + Vector3(-2.0, 0.4, 0), -PI / 2)
	await _appuyer_f()
	await _attendre(330)
	_verifier(faille.fermee, "la faille de la galerie est refermée")
	_verifier(_id_etape() == "amulette", "il reste un objet qui brille (%s)" % _id_etape())
	_verifier(_scene.find_child("AmuletteGalerie", true, false).visible, "une amulette apparaît")
	await _placer(_scene.find_child("RamasserAmulette", true, false).global_position + Vector3(-1.0, 0.4, 0), -PI / 2)
	await _appuyer_f()
	await _attendre(10)
	_verifier(_id_etape() == "fin_chapitre_3", "l'amulette est ramassée (%s)" % _id_etape())
	lues = await _parler("MererToura")
	_verifier(lues >= 4, "Merer examine l'amulette (%d bulles)" % lues)
	_verifier(_id_etape() == "vers_village", "chapitre 3 terminé, le chapitre 4 commence (%s)" % _id_etape())
	var inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("ciseau_cuivre") >= 1, "le ciseau d'Iry est dans le sac")

	# --- On revient plus tard : tout est resté en place.
	await _charger(TOURA)
	_verifier(_id_etape() == "vers_village", "la quête reprend où on l'avait laissée (%s)" % _id_etape())
	await _attendre(5)
	_verifier(_scene.find_child("CarrierNefer", true, false) != null, "les carriers libérés sont au campement")
	_verifier(_scene.find_child("Faille", true, false).fermee, "la faille est toujours fermée")
	_verifier(_vivants("oublie").is_empty(), "les oubliés ne reviennent pas")

	# --- Le passeur ramène au Port des Marais.
	var passeur = _scene.find_child("Passeur", true, false)
	await _placer(passeur.global_position + Vector3(1.5, 0.5, 0), PI / 2)
	await _appuyer_f()
	await _attendre(80)
	_verifier(_quete.zone_demandee == "port_des_marais", "le passeur ramène au Port des Marais (%s)" % _quete.zone_demandee)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
