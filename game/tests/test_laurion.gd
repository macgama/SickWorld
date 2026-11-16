extends SceneTree
## Test automatique du chapitre 6 (Grèce) : la route du Laurion depuis les Oliveraies, les
## mines d'argent (Sosias, Daos, le mur de boucliers à la citerne, la vanne, les ostraka),
## les galeries (trois machines de Masque, l'éboulement, la sortie par la descenderie), Vera
## (selon la réponse donnée en Égypte), l'embuscade aux fours et la fin du chapitre.
## Lancement : godot --headless --path game -s res://tests/test_laurion.gd

const FICHIER := "user://test_grece_laurion.cfg"
const OLIVERAIES := "res://scenes/monde/grece/oliveraies.tscn"
const LAURION := "res://scenes/monde/grece/laurion.tscn"
const GALERIES := "res://scenes/monde/grece/galeries_laurion.tscn"

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


func _lancer() -> void:
	var reseau := root.get_node("Reseau")
	# --- La route du Laurion, depuis les Oliveraies.
	_sauver("vers_laurion")
	await _charger(OLIVERAIES)
	print("Test du Laurion (Grèce, chapitre 6)")
	_verifier(_id_etape() == "vers_laurion", "on part vers le Laurion (%s)" % _id_etape())
	await _placer(_sol(60, 149), 0.0)
	await _placer(_sol(60, 152.5), 0.0)
	await _attendre(60)
	_verifier(_quete.zone_demandee == "laurion", "la route du sud-est mène au Laurion (%s)" % _quete.zone_demandee)

	# --- Les mines, en surface.
	_sauver("vers_laurion")
	reseau.set_meta("arrivee_grece", "oliveraies")
	await _charger(LAURION)
	var p: Vector3 = _joueur.global_position
	_verifier(_joueur.is_on_floor() and p.z < -130.0 and absf(p.x) < 8.0, "on arrive par la route du nord (%.0f, %.0f)" % [p.x, p.z])
	_verifier(_id_etape() == "sosias", "l'arrivée termine la route (%s)" % _id_etape())
	for nom in ["Ergasterion", "Cabanes", "Fours", "Citerne", "Camp", "EntreesMine"]:
		_verifier(_scene.find_child(nom, true, false) != null, "le Laurion a son %s" % nom)
	var colline: float = _scene.hauteur(_scene.COLLINE.x, _scene.COLLINE.y)
	_verifier(colline > _scene.H_PLAINE + 20.0, "la colline des puits domine la plaine (%.0f m)" % colline)
	var lues := await _parler("Sosias")
	_verifier(lues >= 3 and _id_etape() == "daos", "Sosias, l'intendant, explique la panne (%s)" % _id_etape())
	lues = await _parler("Daos")
	_verifier(lues >= 3 and _id_etape() == "citerne", "Daos donne sa lampe et parle de la citerne (%s)" % _id_etape())
	var inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("possede"):
		_verifier(inventaire.possede("lampe_laurion"), "on a la lampe de mineur de Daos")
	await _placer(_sol(97, -20), PI)
	await _attendre(30)
	var mercenaires := []
	for m in _vivants("mercenaire_masque"):
		if Vector2(m.global_position.x, m.global_position.z).distance_to(Vector2(96, -18)) < 15.0:
			mercenaires.append(m)
	_verifier(mercenaires.size() == 4, "un mur de boucliers garde la citerne (%d)" % mercenaires.size())
	if not mercenaires.is_empty():
		var app = mercenaires[0].get_node("Apparence").get("_delegue")
		_verifier(app != null and app.get("variante") == "mercenaire", "des mercenaires en hoplites")
	await _tuer_tous("mercenaire_masque", "citerne")
	await _attendre(10)
	_verifier(_id_etape() == "vanne", "la citerne est libre (%s)" % _id_etape())
	var eau: Node3D = _scene.find_child("EauCanal", true, false)
	_verifier(eau != null and eau.visible, "l'eau part encore par le canal")
	await _objet("Vanne", 200)
	_verifier(_id_etape() == "ostraka", "la vanne est refermée (%s)" % _id_etape())
	_verifier(eau != null and not eau.visible, "le canal est à sec")
	await _objet("SacOstraka", 30)
	_verifier(_id_etape() == "descendre", "les ostraka gravés PÉRIKLÈS (%s)" % _id_etape())
	await _placer(_sol(0, 58), 0.0)
	await _placer(_sol(0, 62.6), PI)
	await _attendre(60)
	_verifier(_quete.zone_demandee == "galeries_laurion", "on descend dans la mine (%s)" % _quete.zone_demandee)
	_verifier(String(reseau.get_meta("galeries_par", "")) == "puits", "par l'entrée du puits")

	# --- Les galeries.
	reseau.set_meta("arrivee_grece", "laurion")
	await _charger(GALERIES)
	print("Les galeries")
	p = _joueur.global_position
	_verifier(_joueur.is_on_floor() and p.z < -50.0, "on arrive au pied de l'entrée (%.0f, %.1f, %.0f)" % [p.x, p.y, p.z])
	_verifier(_id_etape() == "machines", "il faut saboter les machines (%s)" % _id_etape())
	_verifier(_scene.find_child("LampeMineur", true, false) != null, "le joueur porte la lampe de Daos")
	var eboulis: Node3D = _scene.find_child("Eboulis", true, false)
	_verifier(eboulis != null and not eboulis.visible, "la galerie du sud est encore ouverte")
	_verifier(absf(_scene.hauteur(0, 0) - (-8.0)) < 0.1 and _scene.hauteur(45, 50) > -1.0, "le sol descend puis remonte par la descenderie")
	for k in 3:
		await _objet("Machine%d" % k, 220)
	_verifier(_id_etape() == "sortir_galeries", "les trois machines sont sabotées (%s)" % _id_etape())
	_verifier(eboulis != null and eboulis.visible, "un éboulement ferme le chemin de l'entrée")
	await _placer(_sol(45, 49), 0.0)
	await _placer(_sol(45, 53.2), PI)
	await _attendre(60)
	_verifier(_quete.zone_demandee == "laurion", "la descenderie ramène à la surface (%s)" % _quete.zone_demandee)
	_verifier(String(reseau.get_meta("laurion_par", "")) == "descenderie", "par la vieille descenderie")

	# --- Vera, puis l'embuscade (réponse « les noms » donnée en Égypte).
	_sauver("sortir_galeries", "repondre_noms")
	reseau.set_meta("arrivee_grece", "galeries_laurion")
	reseau.set_meta("laurion_par", "descenderie")
	await _charger(LAURION)
	print("Vera et l'embuscade")
	p = _joueur.global_position
	_verifier(Vector2(p.x, p.z).distance_to(_scene.DESCENDERIE) < 12.0, "on ressort à la descenderie (%.0f, %.0f)" % [p.x, p.z])
	_verifier(_id_etape() == "vera_prevenir", "Vera vient prévenir, comme promis en Égypte (%s)" % _id_etape())
	var vera: Node3D = _scene.find_child("VeraLaurion", true, false)
	_verifier(vera != null and vera.visible, "Vera attend près de la descenderie")
	lues = await _parler("VeraLaurion")
	_verifier(lues >= 3 and _id_etape() == "embuscade", "Vera annonce une embuscade aux fours (%s)" % _id_etape())
	await _attendre(5)
	_verifier(vera != null and not vera.visible, "Vera repart")
	await _placer(_sol(50, -74), PI)
	await _attendre(30)
	_verifier(_vivants("mercenaire_masque").size() >= 5, "les mercenaires attaquent aux fours (%d)" % _vivants("mercenaire_masque").size())
	await _tuer_tous("mercenaire_masque", "embuscade")
	await _attendre(10)
	_verifier(_id_etape() == "sosias_fin", "la mine est sauvée (%s)" % _id_etape())
	lues = await _parler("Sosias")
	await _attendre(10)
	_verifier(_quete.etape < 0, "fin du chapitre 6 : la suite (l'ostracisme) arrive bientôt")

	# --- L'autre réponse en Égypte : Vera observe, sans prévenir.
	_sauver("sortir_galeries", "repondre_mission")
	reseau.set_meta("arrivee_grece", "galeries_laurion")
	reseau.set_meta("laurion_par", "descenderie")
	await _charger(LAURION)
	print("L'autre réponse donnée à Vera")
	_verifier(_id_etape() == "vera_observer", "Vera observe de loin (%s)" % _id_etape())

	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)

