extends SceneTree
## Test automatique de la Campagne et des aqueducs (Rome, zone 2) et du chapitre 3 :
## Livia au pied des arches, Sextus le chef des fontainiers, l'ours de la carrière, la
## montée par l'échafaudage, la marche sur le canal, les trois failles qui boivent l'eau,
## l'eau qui revient, la récompense de Sextus et la Porta Maggiore.
## Lancement : godot --headless --path game -s res://tests/test_campagne.gd

const FICHIER := "user://test_rome_campagne.cfg"
const SCENE := "res://scenes/monde/rome/campagne.tscn"

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


func _lancer() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	# On reprend au début du chapitre 3 : on arrive de la voie Appienne.
	var cfg := ConfigFile.new()
	cfg.set_value("rome", "etape", "vers_campagne")
	cfg.save(FICHIER)
	await _charger()
	print("Test de la Campagne et des aqueducs (Rome, chapitre 3)")

	# --- Le monde.
	_verifier(_joueur != null and _joueur.is_on_floor(), "on arrive sur la route, au sud")
	var p: Vector3 = _joueur.global_position
	_verifier(p.z > 120.0, "au sud de la zone (%.0f, %.0f)" % [p.x, p.z])
	_verifier(_id_etape() == "livia_arches", "l'arrivée termine l'étape de la route (%s)" % _id_etape())
	_verifier(_scene.find_child("AqueducClaudia", true, false) != null, "l'aqueduc de Claude traverse la campagne")
	_verifier(_scene.find_child("PortaMaggiore", true, false) != null, "la Porta Maggiore ferme le nord")
	_verifier(_scene.find_child("Villa", true, false) != null, "une villa et ses vignes à l'ouest")
	_verifier(_scene.find_child("Carriere", true, false) != null, "une carrière de tuf à l'est")
	_verifier(_scene.find_child("RomeLointaine", true, false) != null, "on voit Rome au loin")
	var echafaudages := _scene.find_children("*Echafaudage*", "", true, false)
	_verifier(echafaudages.size() >= 2, "deux échafaudages de fontainiers (%d)" % echafaudages.size())
	var eau: Node3D = _scene.find_child("EauAqueduc", true, false)
	_verifier(eau != null and not eau.visible, "le canal est à sec")
	var r: Rect2 = _scene.CARRIERE
	_verifier(_scene.hauteur(r.get_center().x, r.get_center().y) < _scene.hauteur(r.position.x - 12.0, r.get_center().y) - 4.0, "la carrière est creusée dans le sol")
	_verifier(_vivants("sanglier_fracture_latium").size() >= 8, "des sangliers fracturés dans la campagne (%d)" % _vivants("sanglier_fracture_latium").size())
	_verifier(_vivants("loup_fracture_campagne").size() >= 6, "des loups fracturés (%d)" % _vivants("loup_fracture_campagne").size())
	# Sous les arches, on passe (les arches sont hautes) ; contre un pilier, on s'arrête.
	var a: Vector2 = _scene.point_aqueduc(1, 0.5)
	_verifier(_scene.Y_CANAL - _scene.hauteur(a.x, a.y) > 14.0, "le canal passe à plus de 14 m du sol (%.0f m)" % (_scene.Y_CANAL - _scene.hauteur(a.x, a.y)))

	# --- Chapitre 3 : L'eau qui ne vient plus.
	var combat_joueur = _joueur.get_node("Combat")
	var lues := await _parler("Livia")
	_verifier(lues >= 4, "Livia montre l'aqueduc à sec (%d bulles)" % lues)
	_verifier(_id_etape() == "rencontre_sextus", "il faut trouver Sextus (%s)" % _id_etape())
	lues = await _parler("Sextus")
	_verifier(lues >= 4, "Sextus raconte l'eau qui disparaît (%d bulles)" % lues)
	_verifier(_id_etape() == "ours_carriere", "un ours garde la carrière (%s)" % _id_etape())
	await _attendre(5)
	var ours := _vivants("ours_fracture_carriere")
	_verifier(ours.size() == 1, "l'ours fracturé est dans la carrière (%d)" % ours.size())
	if ours.size() > 0:
		_verifier(ours[0].get_node("Apparence").get("espece") == "ours", "il a un corps d'ours")
		var o: Vector3 = ours[0].global_position
		_verifier(Vector2(o.x, o.z).distance_to(_scene.OURS) < 6.0, "au fond de la carrière")
		ours[0].combat.subir(999999.0, combat_joueur)
	await _attendre(20)
	_verifier(_id_etape() == "retour_sextus", "l'ours est abattu (%s)" % _id_etape())
	var felix: Node3D = _scene.find_child("Aquarius1", true, false)
	_verifier(felix != null and felix.visible, "les fontainiers reviennent")
	await _parler("Sextus")
	_verifier(_id_etape() == "regard_sommet", "Sextus envoie sur l'aqueduc (%s)" % _id_etape())

	# L'échafaudage : on monte vraiment les deux premières rampes en marchant.
	var e: Array = _scene.echafaudage_est()
	var base: Vector2 = e[0]
	var t: Vector2 = e[1]
	var n: Vector2 = e[2]
	_calmer_autour(Vector3(base.x, 4, base.y), 40.0)
	var depart := base - t * 4.6 + n * 4.9
	var y0: float = _scene.hauteur(depart.x, depart.y)
	await _placer(Vector3(depart.x, y0 + 0.5, depart.y), _angle_vers(t))
	var y1 := await _marcher_et_mesurer(90)
	_verifier(y1 > y0 + 3.0, "on monte la première rampe en marchant (%.1f → %.1f m)" % [y0, y1])
	# Deuxième rampe : on fait demi-tour sur le palier, dans le couloir intérieur.
	var depart2 := base + t * 4.6 + n * 2.7
	await _placer(Vector3(depart2.x, y1 + 0.6, depart2.y), _angle_vers(-t))
	var y2 := await _marcher_et_mesurer(90)
	_verifier(y2 > y1 + 3.0, "puis la deuxième (%.1f m)" % y2)

	# En haut : on se tient sur le canal.
	var regard: Node3D = _scene.find_child("RegardSommet", true, false)
	await _placer(regard.global_position + Vector3(0, 0.8, 0) + Vector3(t.x, 0, t.y) * 1.2, 0.0)
	_verifier(_joueur.is_on_floor() and absf(_joueur.global_position.y - _scene.Y_CANAL) < 0.6, "on tient debout sur le canal (y = %.1f)" % _joueur.global_position.y)
	await _appuyer_f()
	await _attendre(130)
	_verifier(_id_etape() == "failles_canal", "le regard s'ouvre sur un canal à sec (%s)" % _id_etape())
	# On marche sur le canal : rien ne bloque, on ne tombe pas.
	var d: Vector2 = (_scene.AQUEDUC[2] as Vector2) - (_scene.AQUEDUC[1] as Vector2)
	await _placer(regard.global_position + Vector3(0, 0.8, 0) + Vector3(t.x, 0, t.y) * 1.2, _angle_vers(d.normalized()))
	Input.action_press("avancer")
	await _attendre(120)
	Input.action_release("avancer")
	var q: Vector3 = _joueur.global_position
	_verifier(absf(q.y - _scene.Y_CANAL) < 0.6 and Vector2(q.x, q.z).distance_to(Vector2(regard.global_position.x, regard.global_position.z)) > 5.0,
			"on avance sur le canal sans tomber (%.0f, %.1f, %.0f)" % [q.x, q.y, q.z])
	for k in 3:
		var faille: Node3D = _scene.find_child("FailleCanal%d" % k, true, false)
		# On se pose sur le canal, à côté de la faille.
		var cote := Vector3(0, 0.8, 1.4) if k == 2 else Vector3(d.normalized().x, 0, d.normalized().y) * -1.4 + Vector3(0, 0.8, 0)
		await _placer(faille.global_position + cote, 0.0)
		await _appuyer_f()
		await _attendre(380)
		_verifier(faille.fermee, "la faille %d du canal est refermée" % (k + 1))
	_verifier(_id_etape() == "recompense_sextus", "les trois failles sont fermées (%s)" % _id_etape())
	_verifier(eau.visible, "l'eau coule de nouveau dans le canal")
	var sextus: Node3D = _scene.find_child("Sextus", true, false)
	_verifier(Vector2(sextus.global_position.x, sextus.global_position.z).distance_to(_scene.SEXTUS_PORTE) < 1.0, "Sextus attend à la porte")
	lues = await _parler("Sextus")
	_verifier(lues >= 3, "Sextus entend l'eau chanter (%d bulles)" % lues)
	var inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("tunique_fontainier") >= 1, "la tunique des fontainiers est dans le sac")
		_verifier(inventaire.quantite("fistula_sextus") >= 1, "et la fistule de plomb de Sextus")
	_verifier(_id_etape() == "vers_rome", "Rome attend derrière la porte (%s)" % _id_etape())
	var porte: Vector2 = _scene.PORTE
	await _placer(Vector3(3, _scene.hauteur(3, -120) + 0.4, -120), 0.0)
	Input.action_press("avancer")
	await _attendre(60)
	Input.action_release("avancer")
	await _attendre(10)
	_verifier(_id_etape() == "entrer_rome", "chapitre 3 terminé, le chapitre 4 commence (%s)" % _id_etape())
	# La porte s'ouvre sur Rome.
	await _placer(Vector3(3, _scene.hauteur(3, -126) + 0.4, -126), 0.0)
	Input.action_press("avancer")
	await _attendre(240)
	Input.action_release("avancer")
	_verifier(_quete.zone_demandee == "rome", "la Porta Maggiore mène à Rome (%s)" % _quete.zone_demandee)
	_quete.zone_demandee = ""

	# --- La progression est gardée.
	_scene.queue_free()
	await _attendre(5)
	await _charger()
	_verifier(_id_etape() == "entrer_rome", "au retour, la quête reprend où on l'avait laissée")
	_verifier(_scene.find_child("EauAqueduc", true, false).visible, "l'eau coule toujours")
	_verifier(_scene.find_child("FailleCanal0", true, false).fermee, "les failles restent fermées")
	_verifier(_scene.find_child("Aquarius2", true, false).visible, "les fontainiers sont toujours là")
	# Retour vers la voie Appienne, au sud.
	await _placer(Vector3(0, _scene.hauteur(0, 146) + 0.4, 146), PI)
	Input.action_press("avancer")
	await _attendre(120)
	Input.action_release("avancer")
	_verifier(_quete.zone_demandee == "voie_appienne", "la route du sud ramène à la voie Appienne (%s)" % _quete.zone_demandee)

	print("")
	if _echecs == 0:
		print("TOUS LES TESTS PASSENT")
	else:
		print("%d ÉCHEC(S)" % _echecs)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	quit(1 if _echecs > 0 else 0)
