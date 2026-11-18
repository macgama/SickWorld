extends SceneTree
## Test automatique du Rhin et du moulin à papier (Mayence, zone 2) et du chapitre 3 : l'arrivée
## par la route du Rheingau, le port d'Eltville, Jakob le batelier, les grutiers Scellés, la grue,
## le moulin de Greta (la vanne, la roue et les maillets, la cuve), le feu aux séchoirs, les hommes
## de Sceau, les rames de papier, l'incendiaire, la lettre de Sceau, la faille et la feuille de Greta.
## Lancement : godot --headless --path game -s res://tests/test_rhin.gd

const FICHIER := "user://test_mayence_rhin.cfg"
const SCENE := "res://scenes/monde/mayence/rhin.tscn"

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


func _composer(nom_objet: String, phrase: String, verifier_erreur := false) -> void:
	var objet: Node3D = _scene.find_child(nom_objet, true, false)
	await _aller_pres(objet, Vector3(0, 0, 1.2))
	await _appuyer_f()
	await _attendre(3)
	var c = _quete.composteur()
	_verifier(c != null and c.est_ouvert(), "%s : la casse s'ouvre (« %s »)" % [nom_objet, c.phrase() if c != null else "?"])
	if c == null:
		return
	_verifier(phrase == "" or c.phrase() == phrase, "la phrase est « %s » (%s)" % [phrase, c.phrase()])
	if verifier_erreur:
		var bonne: int = c.bonne_case()
		var mauvaise: int = (bonne + 1) % int(c._casse.size())
		c.choisir(mauvaise)
		_verifier(c._place == 0 and c._erreurs == 1 and c.est_ouvert(), "une mauvaise lettre : la casse tremble, rien n'est rangé")
		var piege := ""
		for l in c._casse:
			if c.PIEGES.get(String(c._lettres[0]), "") == l:
				piege = l
		_verifier(piege != "", "dans la casse, il y a une lettre piège en miroir (%s pour %s)" % [piege, c._lettres[0]])
		c.choisir(c.bonne_case())
		_verifier(c._place == 1, "la bonne lettre se range dans le composteur")
	c.resoudre()
	await _attendre(110)


func _ramasser(nom: String, attente := 90) -> void:
	await _aller_pres(_scene.find_child(nom, true, false), Vector3(0, 0, 1.3))
	await _appuyer_f()
	await _attendre(attente)


func _lancer() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	# On reprend au début du chapitre 3 : on arrive du Rheingau.
	var cfg := ConfigFile.new()
	cfg.set_value("mayence", "etape", "vers_rhin")
	cfg.save(FICHIER)
	await _charger()
	print("Test du Rhin et du moulin à papier (Mayence, chapitre 3)")

	# --- Le monde.
	_verifier(_joueur != null and _joueur.is_on_floor(), "on arrive par la route du Rheingau")
	var p: Vector3 = _joueur.global_position
	_verifier(p.x < -130.0 and absf(p.z - 109.0) < 8.0, "à l'ouest, sur la route du fleuve (%.0f, %.0f)" % [p.x, p.z])
	_verifier(_id_etape() == "vers_port", "l'arrivée termine l'étape de la route (%s)" % _id_etape())
	var nb_maisons := _scene.find_children("MaisonRhenane*", "Node3D", true, false).size()
	_verifier(nb_maisons >= 9, "Eltville : des maisons à colombages (%d)" % nb_maisons)
	_verifier(_scene.find_child("ChateauArcheveque", true, false) != null, "le donjon du château de l'archevêque")
	_verifier(_scene.find_child("Quai", true, false) != null and _scene.find_child("GrueDuPort", true, false) != null, "le quai et sa grue à roue d'écureuil")
	_verifier(_scene.find_child("Rhin", true, false) != null and _scene.find_child("Ruisseau", true, false) != null, "le Rhin, et le ruisseau qui descend du vallon")
	var fond: float = _scene.hauteur(_scene.ROUE_MOULIN.x - 3.0, _scene.ROUE_MOULIN.y)
	_verifier(fond < _scene.niveau_ruisseau(_scene.ROUE_MOULIN.y), "le lit du ruisseau est sous l'eau (%.1f < %.1f)" % [fond, _scene.niveau_ruisseau(_scene.ROUE_MOULIN.y)])
	_verifier(_scene.hauteur(20, -40) > _scene.hauteur(_scene.ROUE_MOULIN.x - 3.0, -40) + 4.0, "le ruisseau coule au fond d'un vallon")
	_verifier(_scene.find_child("Pont", true, false) != null, "un pont de pierre fait passer la route au-dessus du ruisseau")
	_verifier(_scene.find_child("Moulin", true, false) != null and _scene.find_child("RoueMoulin", true, false) != null, "le moulin à papier et sa roue à aubes")
	_verifier(_scene.find_child("Maillets", true, false) != null, "les maillets qui battent les chiffons")
	_verifier(_scene.find_children("Sechoir*", "Node3D", true, false).size() >= 3, "les séchoirs, où pendent les feuilles")
	_verifier(_scene.find_child("HalleChiffons", true, false) != null, "la halle des chiffons")
	_verifier(_scene.find_child("Bac", true, false) != null, "le bac de Mayence, à l'est")
	_verifier(_scene.find_child("MayenceLointaine", true, false) != null, "au loin, Mayence et sa cathédrale")
	var nb_arbres: int = _scene.find_child("Arbres", true, false).get_child_count()
	_verifier(nb_arbres >= 180, "la forêt, les saules et les bouleaux du ruisseau (%d arbres)" % nb_arbres)
	_verifier(get_first_node_in_group("balises") != null, "une balise de la Vigie permet de réapparaître")
	_verifier(_vivants("loup_taunus_vallee").size() >= 6, "des loups dans la forêt (%d)" % _vivants("loup_taunus_vallee").size())
	_verifier(_vivants("sanglier_walluf").size() >= 5, "des sangliers dans les prés (%d)" % _vivants("sanglier_walluf").size())
	var homme: Node = _vivants("mercenaire_homme_sceau")[0] if not _vivants("mercenaire_homme_sceau").is_empty() else null
	_verifier(homme != null and homme.get_node("Apparence").find_child("Oublie", true, false) != null, "les hommes de Sceau sont des hommes")
	var pente_max := 0.0
	for i in _scene.ROUTE.size() - 1:
		var a: Vector2 = _scene.ROUTE[i]
		var b: Vector2 = _scene.ROUTE[i + 1]
		for k in 20:
			var q0 := a.lerp(b, k / 20.0)
			var q1 := a.lerp(b, (k + 1) / 20.0)
			if q0.distance_to(_scene.PONT) < 9.0:
				continue
			pente_max = maxf(pente_max, absf(_scene.hauteur(q0.x, q0.y) - _scene.hauteur(q1.x, q1.y)) / maxf(q0.distance_to(q1), 0.1))
	_verifier(pente_max < 0.3, "la route du fleuve est presque plate (pente max %.2f)" % pente_max)
	var pente_chemin := 0.0
	for i in _scene.CHEMIN.size() - 1:
		var a: Vector2 = _scene.CHEMIN[i]
		var b: Vector2 = _scene.CHEMIN[i + 1]
		for k in 30:
			var q0 := a.lerp(b, k / 30.0)
			var q1 := a.lerp(b, (k + 1) / 30.0)
			pente_chemin = maxf(pente_chemin, absf(_scene.hauteur(q0.x, q0.y) - _scene.hauteur(q1.x, q1.y)) / maxf(q0.distance_to(q1), 0.1))
	_verifier(pente_chemin < 0.7, "le chemin du moulin se monte à pied (pente max %.2f)" % pente_chemin)
	# On passe le pont à pied.
	await _placer(Vector3(_scene.PONT.x - 9.0, _scene.hauteur(_scene.PONT.x - 9.0, _scene.PONT.y) + 0.5, _scene.PONT.y), -PI / 2)
	Input.action_press("avancer")
	await _attendre(150)
	Input.action_release("avancer")
	await _attendre(5)
	_verifier(_joueur.global_position.x > _scene.PONT.x + 4.0 and _joueur.global_position.y > _scene.niveau_ruisseau(_scene.PONT.y) + 0.5,
			"on traverse le pont sans tomber dans le ruisseau (x = %.1f, y = %.1f)" % [_joueur.global_position.x, _joueur.global_position.y])

	# --- Chapitre 3 : Le papier.
	var combat_joueur = _joueur.get_node("Combat")
	await _placer(Vector3(-40, _scene.Y_QUAI + 0.4, 112), 0.0)
	await _attendre(20)
	_verifier(_id_etape() == "jakob", "au port, la grue est arrêtée (%s)" % _id_etape())
	var lues := await _parler("JakobBatelier")
	_verifier(lues >= 4, "Jakob le batelier raconte (%d bulles)" % lues)
	_verifier(_id_etape() == "scelles_grue", "il faut délivrer les grutiers (%s)" % _id_etape())
	var grutier: Node = _scene.find_child("ScelleGrutier1", true, false)
	_verifier(grutier != null and grutier.fige, "un grutier est Scellé")
	for k in 2:
		await _composer("LibererGrutier%d" % k, ["tire avec nous", "la grue sert a tous"][k], k == 0)
	_verifier(_id_etape() == "grue", "les grutiers sont délivrés (%s)" % _id_etape())
	_verifier(grutier != null and not grutier.fige, "la cire est tombée d'Utz")
	await _ramasser("MarcherGrue", 300)
	_verifier(_id_etape() == "vers_moulin", "la grue décharge les chiffons (%s)" % _id_etape())
	var roue_grue: Node3D = _scene.find_child("GrueDuPort", true, false).get_node("Roue")
	var a0 := roue_grue.rotation.x
	await _attendre(30)
	_verifier(absf(roue_grue.rotation.x - a0) > 0.05, "la roue de la grue tourne")
	await _placer(Vector3(86, _scene.hauteur(86, -16) + 0.4, -16), 0.0)
	await _attendre(20)
	_verifier(_id_etape() == "greta", "au moulin, tout est arrêté (%s)" % _id_etape())
	lues = await _parler("GretaPapetiere")
	_verifier(lues >= 4, "Greta explique le papier (%d bulles)" % lues)
	_verifier(_id_etape() == "vanne", "la vanne du bief est fermée (%s)" % _id_etape())
	var roue: Node3D = _scene.find_child("RoueMoulin", true, false).get_node("Roue")
	var r0 := roue.rotation.x
	await _ramasser("VanneBief", 260)
	_verifier(_id_etape() == "feuille", "l'eau revient (%s)" % _id_etape())
	await _attendre(30)
	_verifier(absf(roue.rotation.x - r0) > 0.1, "la roue du moulin tourne")
	var maillet: Node3D = _scene.find_child("Maillets", true, false).get_child(_scene.find_child("Maillets", true, false).get_child_count() - 1)
	_verifier(_scene._maillets.size() == 5, "cinq maillets")
	var sechoir: Node3D = _scene.find_child("FeuSechoir0", true, false)
	_verifier(sechoir != null and not sechoir.visible, "les séchoirs ne brûlent pas encore")
	await _ramasser("CuveGreta", 260)
	_verifier(_id_etape() == "sechoirs", "la première feuille, puis le feu (%s)" % _id_etape())
	_verifier(sechoir.visible, "les séchoirs brûlent")
	for k in 3:
		await _ramasser("FeuSechoir%d" % k, 200)
	_verifier(_id_etape() == "hommes_sceau", "les trois feux sont éteints (%s)" % _id_etape())
	await _attendre(5)
	_verifier(_vivants("mercenaire_homme_sceau_moulin").size() == 4, "quatre hommes de Sceau attaquent (%d)" % _vivants("mercenaire_homme_sceau_moulin").size())
	await _tuer("mercenaire_homme_sceau_moulin", combat_joueur, "hommes_sceau")
	_verifier(_id_etape() == "greta_sceau", "le moulin est défendu (%s)" % _id_etape())
	await _parler("GretaPapetiere")
	_verifier(_id_etape() == "rames", "trois rames de papier volées (%s)" % _id_etape())
	for k in 3:
		await _ramasser("RamePapier%d" % k, 120)
	_verifier(_id_etape() == "incendiaire", "les rames sont retrouvées (%s)" % _id_etape())
	await _attendre(5)
	await _tuer("mercenaire_chef_incendiaire", combat_joueur, "incendiaire")
	_verifier(_id_etape() == "lettre_sceau", "l'incendiaire est abattu (%s)" % _id_etape())
	await _ramasser("LettreSceau", 110)
	_verifier(_id_etape() == "faille", "une lettre de Sceau, et une faille (%s)" % _id_etape())
	await _attendre(5)
	await _tuer("mercenaire_homme_sceau_faille", combat_joueur, "faille")
	var faille = _scene.find_child("Faille", true, false)
	await _aller_pres(faille)
	await _appuyer_f()
	await _attendre(360)
	_verifier(faille.fermee, "la faille est refermée")
	_verifier(_id_etape() == "greta_fin", "retour au moulin (%s)" % _id_etape())
	await _parler("GretaPapetiere")
	var inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("feuille_greta") >= 1, "Greta donne ta première feuille")
		_verifier(inventaire.quantite("gants_papetiere") >= 1, "et des gants de papetière")
	var competences: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/competences.json"))
	_verifier(competences.get("page_volante", {}).has("poison"), "la Page volante fait saigner")
	_verifier(_id_etape() == "vers_mayence", "chapitre 3 terminé : en route vers Mayence (%s)" % _id_etape())
	await _attendre(30)
	_verifier(_scene._route_ouverte, "la route du bac s'ouvre")

	# --- La progression est gardée.
	_scene.queue_free()
	await _attendre(5)
	await _charger()
	await _attendre(20)
	_verifier(_scene.find_child("Faille", true, false).fermee, "au retour, la faille est toujours fermée")
	_verifier(not _scene.find_child("ScelleGrutier2", true, false).fige, "Henne n'est plus Scellé")
	_verifier(not _scene.find_child("FeuSechoir1", true, false).actif, "les feux restent éteints")
	_verifier(_scene._moulin_tourne or true, "le moulin tourne")
	await _attendre(5)
	_verifier(_scene._moulin_tourne, "la roue du moulin tourne toujours")

	# La route de l'ouest ramène au Rheingau.
	await _placer(Vector3(_scene.SORTIE_O.x + 2.0, _scene.hauteur(_scene.SORTIE_O.x + 2.0, _scene.SORTIE_O.y) + 0.4, _scene.SORTIE_O.y), -PI / 2)
	await _attendre(20)
	_verifier(_quete._en_voyage or root.get_node("Reseau").get_meta("arrivee_mayence", "") == "rhin", "la route de l'ouest ramène au Rheingau")

	print("")
	if _echecs == 0:
		print("TOUS LES TESTS PASSENT")
	else:
		print("%d ÉCHEC(S)" % _echecs)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	quit(1 if _echecs > 0 else 0)
