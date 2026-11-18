extends SceneTree
## Test automatique des carrières de Berchères (Moyen Âge, zone 2) et du chapitre 3 : maître
## Gautier, les carriers Las, le treuil, la roue d'écureuil, le charbonnier et les larmes de
## plomb, les brigands et leur chef au chalumeau, la faille, puis l'escorte de la première
## charrette de pierre jusqu'à la route de Chartres, et le pavois.
## Lancement : godot --headless --path game -s res://tests/test_bercheres.gd

const FICHIER := "user://test_moyen_age_bercheres.cfg"
const SCENE := "res://scenes/monde/moyen_age/bercheres.tscn"

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


func _vitrail(nom_objet: String, motif: String, verifier_erreur := false) -> void:
	await _lire_dialogue()
	var objet: Node3D = _scene.find_child(nom_objet, true, false)
	await _aller_pres(objet, Vector3(0, 0, 1.2))
	await _appuyer_f()
	await _attendre(3)
	var v = _quete.vitrail()
	_verifier(v != null and v.est_ouvert(), "%s : le vitrail s'ouvre (%s)" % [nom_objet, v.motif() if v != null else "?"])
	if v == null:
		return
	_verifier(motif == "" or v.motif() == motif, "le motif est « %s » (%s)" % [motif, v.motif()])
	if verifier_erreur:
		var mauvais: int = (int(v.bon_morceau()) + 1) % int(v._ordre.size())
		v.choisir(mauvais)
		_verifier(v._place == 0 and v._erreurs == 1 and v.est_ouvert(), "un mauvais morceau : la fenêtre tremble, rien n'est posé")
		v.choisir(v.bon_morceau())
		_verifier(v._place == 1, "le bon morceau se pose")
	v.resoudre()
	await _attendre(90)


func _lancer() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	# On reprend au début du chapitre 3 : on arrive de la Beauce.
	var cfg := ConfigFile.new()
	cfg.set_value("moyen_age", "etape", "vers_bercheres")
	cfg.save(FICHIER)
	await _charger()
	print("Test des carrières de Berchères (Moyen Âge, chapitre 3)")

	# --- Le monde.
	_verifier(_joueur != null and _joueur.is_on_floor(), "on arrive par le chemin du sud-ouest")
	var p: Vector3 = _joueur.global_position
	_verifier(p.x < -130.0 and p.z > 120.0, "au sud-ouest de la zone (%.0f, %.0f)" % [p.x, p.z])
	_verifier(_id_etape() == "gautier", "l'arrivée termine l'étape de la route (%s)" % _id_etape())
	var fond: float = _scene.hauteur(_scene.CARRIERE.x, _scene.CARRIERE.y)
	var bord: float = _scene.hauteur(_scene.CARRIERE.x, _scene.CARRIERE.y - _scene.RAYON - 8.0)
	_verifier(bord - fond > 8.0, "la carrière est un trou profond (%.1f m)" % (bord - fond))
	# La rampe : une pente régulière, sans marche, du fond au bord.
	var pente_max := 0.0
	for k in 40:
		var a: Vector2 = _scene.RAMPE_BAS.lerp(_scene.RAMPE_HAUT, k / 40.0)
		var b: Vector2 = _scene.RAMPE_BAS.lerp(_scene.RAMPE_HAUT, (k + 1) / 40.0)
		pente_max = maxf(pente_max, absf(_scene.hauteur(a.x, a.y) - _scene.hauteur(b.x, b.y)) / a.distance_to(b))
	_verifier(pente_max < 0.35, "la rampe des charrettes monte en douceur (pente max %.2f)" % pente_max)
	var a2: Vector2 = _scene.CARRIERE + Vector2(-_scene.RAYON + 4.0, 0)
	var b2: Vector2 = _scene.CARRIERE + Vector2(-_scene.RAYON - 4.0, 0)
	_verifier(_scene.hauteur(b2.x, b2.y) - _scene.hauteur(a2.x, a2.y) > 2.0, "ailleurs, les parois sont taillées en marches")
	_verifier(_scene.find_child("RoueEcureuil", true, false) != null, "une grande roue d'écureuil au bord")
	_verifier(_scene.find_child("CampCarriers", true, false) != null, "le camp des carriers")
	_verifier(_scene.find_child("Forge", true, false) != null, "et sa forge")
	var nb_arbres: int = _scene.find_child("Arbres", true, false).get_child_count()
	_verifier(nb_arbres >= 120, "une vraie forêt de chênes à l'ouest (%d arbres)" % nb_arbres)
	_verifier(_scene.dans_foret(Vector2(-120, 0)) > 0.6 and _scene.dans_foret(Vector2(110, 0)) < 0.1, "la forêt est à l'ouest, pas à l'est")
	_verifier(_vivants("mercenaire_brigand").size() >= 5, "des brigands rôdent (%d)" % _vivants("mercenaire_brigand").size())
	_verifier(_vivants("loup_foret_bercheres").size() >= 8, "des loups dans les bois (%d)" % _vivants("loup_foret_bercheres").size())

	# --- Chapitre 3 : La pierre de Berchères.
	var combat_joueur = _joueur.get_node("Combat")
	var lues := await _parler("MaitreGautier")
	_verifier(lues >= 4, "maître Gautier montre son plan (%d bulles)" % lues)
	_verifier(_id_etape() == "las_carriers", "les carriers sont Las (%s)" % _id_etape())
	for k in 3:
		await _vitrail("CourageCarrier%d" % k, ["rose", "lancette", "belle_verriere"][k])
	_verifier(_id_etape() == "treuil", "les trois carriers reprennent le pic (%s)" % _id_etape())
	var treuil: Node3D = _scene.find_child("TreuilCoince", true, false)
	await _aller_pres(treuil, Vector3(1.6, 0, 0))
	await _appuyer_f()
	await _attendre(220)
	_verifier(treuil.get_node_or_null("Debloque") != null and treuil.get_node("Debloque").visible, "le treuil est débloqué")
	_verifier(_id_etape() == "roue", "il faut faire tourner la roue (%s)" % _id_etape())
	await _aller_pres(_scene.find_child("MarcherRoue", true, false), Vector3(0, 0, 1.2))
	await _appuyer_f()
	await _attendre(420)
	_verifier(_id_etape() == "gautier_pierre", "le premier bloc monte (%s)" % _id_etape())
	await _parler("MaitreGautier")
	await _attendre(20)
	var roue: Node3D = _scene.find_child("RoueEcureuil", true, false).get_node("Roue")
	var angle := roue.rotation.x
	await _attendre(30)
	_verifier(absf(roue.rotation.x - angle) > 0.02, "la roue tourne, les carriers lèvent des blocs")
	_verifier(_id_etape() == "charbonnier", "Gautier envoie chez le charbonnier (%s)" % _id_etape())
	lues = await _parler("Charbonnier")
	_verifier(lues >= 4, "le charbonnier parle des larmes de plomb (%d bulles)" % lues)
	for k in 3:
		var larme: Node3D = _scene.find_child("LarmePlomb%d" % k, true, false)
		for bete in get_nodes_in_group("loups"):
			if bete.combat.est_vivant() and bete.global_position.distance_to(larme.global_position) < 25.0:
				bete.combat.subir(999999.0, combat_joueur)
		await _aller_pres(larme, Vector3(0, 0, 1.3))
		await _appuyer_f()
		await _attendre(130)
	_verifier(_id_etape() == "charbonnier_larmes", "les trois tas de larmes sont ramassés (%s)" % _id_etape())
	await _parler("Charbonnier")
	_verifier(_id_etape() == "brigands", "le camp des brigands (%s)" % _id_etape())
	await _attendre(5)
	await _tuer("mercenaire_brigand_camp", combat_joueur, "brigands")
	_verifier(_id_etape() == "chef_brigands", "les brigands sont chassés (%s)" % _id_etape())
	await _attendre(5)
	await _tuer("mercenaire_chef_brigands", combat_joueur, "chef_brigands")
	_verifier(_id_etape() == "faille", "le chef au chalumeau est abattu (%s)" % _id_etape())
	await _attendre(5)
	await _tuer("loup_faille_bercheres", combat_joueur, "faille")
	var faille = _scene.find_child("Faille", true, false)
	await _aller_pres(faille)
	await _appuyer_f()
	await _attendre(360)
	_verifier(faille.fermee, "la faille de la forêt est refermée")
	_verifier(_id_etape() == "gautier_charrette", "retour au camp (%s)" % _id_etape())
	await _parler("MaitreGautier")
	_verifier(_scene.find_child("GuillotBercheres", true, false).visible, "Guillot et les volontaires sont arrivés")
	lues = await _parler("GuillotBercheres")
	_verifier(lues >= 3, "Guillot présente les volontaires (%d bulles)" % lues)
	_verifier(_id_etape() == "escorte_charrette", "il faut escorter la charrette (%s)" % _id_etape())
	var charrette: Node3D = _scene.find_child("CharrettePierre", true, false)
	var images := 0
	var hauteur_max := -100.0
	while _id_etape() == "escorte_charrette" and images < 12000:
		images += 1
		if images % 30 == 0:
			for bete in _vivants("mercenaire_brigand_escorte"):
				bete.combat.subir(999999.0, combat_joueur)
			var c := charrette.global_position + Vector3(2.5, 0, 2.5)
			_joueur.teleporter(Vector3(c.x, _scene.hauteur(c.x, c.z) + 0.4, c.z), 0.0)
			hauteur_max = maxf(hauteur_max, charrette.global_position.y)
		await physics_frame
	_verifier(_id_etape() == "guillot_pavois", "la charrette sort de la carrière par la rampe (%s, %d images)" % [_id_etape(), images])
	_verifier(Vector2(charrette.global_position.x, charrette.global_position.z).distance_to(Vector2(146, -126)) < 1.5, "la charrette est sur la route de Chartres")
	_verifier(hauteur_max > fond + 6.0, "elle est bien remontée du fond du trou")
	await _parler("GuillotBercheres")
	var inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("pavois_carriers") >= 1, "le pavois des carriers est dans le sac")
		_verifier(inventaire.quantite("gants_tailleur") >= 1, "les gants de tailleur aussi")
	var competences: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/competences.json"))
	_verifier(competences.has("pavois"), "la compétence Pavois existe")

	# --- La progression est gardée.
	var cfg2 := ConfigFile.new()
	cfg2.load(FICHIER)
	_verifier(cfg2.has_section("moyen_age"), "l'avancement est enregistré")
	_scene.queue_free()
	await _attendre(5)
	await _charger()
	await _attendre(20)
	_verifier(_scene.find_child("Faille", true, false).fermee, "au retour, la faille est toujours fermée")
	_verifier(not _scene.find_child("LasCarrier2", true, false).fige, "Bertin n'est plus Las")
	var c2: Node3D = _scene.find_child("CharrettePierre", true, false)
	_verifier(Vector2(c2.global_position.x, c2.global_position.z).distance_to(Vector2(146, -126)) < 1.5, "la charrette est toujours sur la route")
	# Le chemin du sud-ouest ramène en Beauce.
	var so: Vector2 = _scene.SORTIE_SO
	await _placer(Vector3(so.x + 3.0, _scene.hauteur(so.x + 3.0, so.y - 2.0) + 0.4, so.y - 2.0), PI / 2)
	await _attendre(70)
	_verifier(_quete.zone_demandee == "beauce", "le chemin du sud-ouest ramène en Beauce (%s)" % _quete.zone_demandee)

	print("")
	if _echecs == 0:
		print("TOUS LES TESTS PASSENT")
	else:
		print("%d ÉCHEC(S)" % _echecs)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	quit(1 if _echecs > 0 else 0)
