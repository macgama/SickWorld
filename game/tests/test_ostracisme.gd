extends SceneTree
## Test automatique du chapitre 7 (Grèce) : « L'ostracisme ». Le retour à Athènes, Aspasie,
## Périclès devant l'enclos du vote, les six citoyens à convaincre (le compteur de voix), le
## décompte des tessons, la Gorgone qui s'éveille, la défense de la procession des
## Panathénées, les porteurs pétrifiés, la canéphore et l'escalier secret de l'Acropole.
## Lancement : godot --headless --path game -s res://tests/test_ostracisme.gd

const FICHIER := "user://test_grece_ostracisme.cfg"
const ATHENES := "res://scenes/monde/grece/athenes.tscn"

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


func _aller_pres(cible: Node3D) -> void:
	var p: Vector3 = cible.global_position + Vector3(0, 0, 1.6)
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


func _tuer_tous(type: String, etape: String) -> void:
	var combat_joueur = _joueur.get_node("Combat")
	for passe in 4:
		for bete in _vivants(type):
			# Seulement ceux du combat en cours (pas ceux des camps, ailleurs dans la zone).
			if bete.global_position.distance_to(_joueur.global_position) > 30.0:
				continue
			bete.combat.subir(99999.0, combat_joueur)
			await _attendre(3)
			if _id_etape() != etape:
				return
		await _attendre(20)


## Se placer à côté d'un objet, décalé en x (pour choisir une tablette parmi trois).
func _aller_cote(cible: Node3D, dx: float, dz := 0.0) -> void:
	var p: Vector3 = cible.global_position + Vector3(dx, 0, dz)
	p.y = maxf(_scene.hauteur(p.x, p.z), cible.global_position.y) + 0.3
	await _placer(p, 0.0)


func _repondre(id_noeud: String, dx: float, dz := 0.0) -> int:
	var o = _scene.find_child(id_noeud, true, false)
	if o == null:
		print("  (objet introuvable : %s)" % id_noeud)
		return 0
	await _aller_cote(o, dx, dz)
	await _appuyer_f()
	await _attendre(5)
	return await _lire_dialogue()


func _sauver(etape: String, reponse_vera := "") -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	var cfg := ConfigFile.new()
	cfg.set_value("grece", "etape", etape)
	if reponse_vera != "":
		cfg.set_value("egypte", "choix_reponse_vera", reponse_vera)
	cfg.save(FICHIER)


func _sol(x: float, z: float) -> Vector3:
	return Vector3(x, _scene.hauteur(x, z) + 0.4, z)


func _objet(id_noeud: String, duree_images := 60) -> void:
	var o = _scene.find_child(id_noeud, true, false)
	if o == null:
		print("  (objet introuvable : %s)" % id_noeud)
		return
	await _aller_cote(o, 0.0, 1.2)
	var avant := _id_etape()
	# Un butin tombé tout près se ramasse d'abord : on réappuie si rien n'a commencé.
	for essai in 3:
		await _appuyer_f()
		await _attendre(5)
		if _quete._canalisation != null or _id_etape() != avant or _dialogue.est_ouvert():
			break
	await _attendre(duree_images)
	await _lire_dialogue()


func _proches(type: String, centre: Vector2, rayon: float) -> Array:
	var liste := []
	for b in _vivants(type):
		if Vector2(b.global_position.x, b.global_position.z).distance_to(centre) < rayon:
			liste.append(b)
	return liste


func _lancer() -> void:
	_sauver("retour_athenes")
	await _charger(ATHENES)
	print("Test de l'ostracisme (Grèce, chapitre 7)")
	_verifier(_id_etape() == "aspasie_vote", "l'arrivée à Athènes termine le retour (%s)" % _id_etape())
	var enclos: Node3D = _scene.find_child("EnclosVote", true, false)
	_verifier(enclos != null and not enclos.visible, "l'enclos du vote n'est pas encore monté")
	var lues := await _parler("Aspasie")
	_verifier(lues >= 4 and _id_etape() == "pericles", "Aspasie explique l'ostracisme (%s)" % _id_etape())
	lues = await _parler("Pericles")
	_verifier(lues >= 4 and _id_etape() == "rallier", "Périclès demande de parler aux gens (%s)" % _id_etape())
	_verifier(enclos != null and enclos.visible, "l'enclos du vote est monté sur l'Agora")
	for k in 6:
		await _objet("Voix%d" % k, 180)
		if k < 5:
			_verifier(_id_etape() == "rallier", "voix %d sur 6 (%s)" % [k + 1, _id_etape()])
	_verifier(_id_etape() == "enclos", "six citoyens convaincus (%s)" % _id_etape())
	await _placer(_sol(-30, -13), 0.0)
	await _attendre(30)
	_verifier(_id_etape() == "decompte", "on arrive à l'enclos (%s)" % _id_etape())
	await _objet("UrneOstraka", 250)
	_verifier(_id_etape() == "verdict", "les tessons sont comptés : ΠΡΟΣΩΠΟΝ (%s)" % _id_etape())
	lues = await _parler("Pericles")
	_verifier(lues >= 4 and _id_etape() == "procession", "Masque est chassé, les flûtes se taisent (%s)" % _id_etape())
	await _placer(_sol(32, 9), PI / 2)
	await _attendre(40)
	var serpents := _proches("serpent_gorgone", Vector2(40, 4), 20.0)
	_verifier(serpents.size() == 8, "les serpents de la Gorgone attaquent la procession (%d)" % serpents.size())
	if not serpents.is_empty():
		var app = serpents[0].get_node("Apparence").get("_delegue")
		_verifier(app != null and app.get("espece") == "gorgone", "des serpents de bronze")
	await _tuer_tous("serpent_gorgone", "procession")
	await _attendre(10)
	_verifier(_id_etape() == "procession_voix", "la procession est sauvée (%s)" % _id_etape())
	await _attendre(20)
	var petrifies := _proches("petrifie", Vector2(26, 12), 15.0)
	_verifier(petrifies.size() == 4, "quatre porteurs changés en marbre (%d)" % petrifies.size())
	for bete in petrifies:
		bete.combat.subir(99999.0, _joueur.get_node("Combat"))
	await _attendre(30)
	for k in 8:
		var objet = _scene.find_child("RendreNom%d" % k, true, false)
		if objet == null or objet.get("ramasse"):
			continue
		await _aller_cote(objet, 0.0, 1.0)
		await _appuyer_f()
		await _attendre(220)
		await _lire_dialogue()
	_verifier(_id_etape() == "canephore", "les porteurs retrouvent la voix (%s)" % _id_etape())
	var canephore: Node3D = _scene.find_child("Canephore", true, false)
	_verifier(canephore != null and canephore.visible, "la canéphore est là")
	lues = await _parler("Canephore")
	_verifier(lues >= 3 and _id_etape() == "pericles_escalier", "la canéphore parle du bouclier (%s)" % _id_etape())
	var escalier: Node3D = _scene.find_child("EscalierSecret", true, false)
	_verifier(escalier != null and escalier.visible, "l'escalier secret est ouvert")
	lues = await _parler("PericlesAcropole")
	await _attendre(10)
	_verifier(_id_etape() == "entrer_acropole", "fin du chapitre 7 : en route pour l'Acropole (%s)" % _id_etape())
	await _placer(_sol(38, -4), -PI / 2)
	_joueur.teleporter(_sol(42, -4), -PI / 2)
	await _attendre(120)
	_verifier(_quete.zone_demandee == "acropole", "l'escalier secret monte vers l'Acropole (%s)" % _quete.zone_demandee)

	# --- Reprise en cours de chapitre : l'enclos et l'escalier sont remis en place.
	_sauver("pericles_escalier")
	await _charger(ATHENES)
	print("Reprise au pied de l'Acropole")
	escalier = _scene.find_child("EscalierSecret", true, false)
	_verifier(escalier != null and escalier.visible, "l'escalier est toujours ouvert après une reprise")
	enclos = _scene.find_child("EnclosVote", true, false)
	_verifier(enclos != null and enclos.visible, "l'enclos est toujours là")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
