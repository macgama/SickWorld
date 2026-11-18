extends SceneTree
## Test automatique de Chartres (Moyen Âge, zone 3) et des chapitres 4 et 5 : la porte des
## Épars, Aude et les pillards, le coffret du verrier, les artisans Las, frère Anselme et le
## message de Masque ; puis le parvis, les fumigènes, les hommes de Plomb, les Las de la
## foule, le choix face à Plomb, le serment du cardinal et la cotte de l'évêque.
## Lancement : godot --headless --path game -s res://tests/test_chartres.gd

const FICHIER := "user://test_moyen_age_chartres.cfg"
const SCENE := "res://scenes/monde/moyen_age/chartres.tscn"

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
	# On reprend au début du chapitre 4 : on arrive des carrières de Berchères.
	var cfg := ConfigFile.new()
	cfg.set_value("moyen_age", "etape", "vers_chartres")
	cfg.save(FICHIER)
	await _charger()
	print("Test de Chartres (Moyen Âge, chapitres 4 et 5)")

	# --- Le monde.
	_verifier(_joueur != null and _joueur.is_on_floor(), "on arrive par la route de Berchères")
	var p: Vector3 = _joueur.global_position
	_verifier(p.x < -150.0 and p.z > 140.0, "au sud-ouest de la zone (%.0f, %.0f)" % [p.x, p.z])
	_verifier(_id_etape() == "porte_epars", "l'arrivée termine l'étape de la route (%s)" % _id_etape())
	var sommet: float = _scene.hauteur(_scene.PARVIS.x, _scene.PARVIS.y)
	var bas: float = _scene.hauteur(100, 0)
	_verifier(sommet - bas > 10.0, "la cathédrale est en haut d'une butte (%.1f m au-dessus de la ville basse)" % (sommet - bas))
	_verifier(_scene.hauteur(_scene.axe_eure(0), 0) < _scene.NIVEAU_EURE - 0.5, "l'Eure coule au pied de la ville")
	var pente_max := 0.0
	var rue: Array = _scene.GRAND_RUE
	for i in rue.size() - 1:
		for k in 20:
			var a: Vector2 = rue[i].lerp(rue[i + 1], k / 20.0)
			var b: Vector2 = rue[i].lerp(rue[i + 1], (k + 1) / 20.0)
			pente_max = maxf(pente_max, absf(_scene.hauteur(a.x, a.y) - _scene.hauteur(b.x, b.y)) / maxf(a.distance_to(b), 0.01))
	_verifier(pente_max < 0.4, "la grand-rue monte sans marche trop raide (pente max %.2f)" % pente_max)
	_verifier(_scene.find_child("Cathedrale", true, false) != null, "la façade de la cathédrale et la nef brûlée")
	_verifier(_scene.find_child("Remparts", true, false) != null, "les remparts")
	_verifier(_scene.find_child("Eure", true, false) != null and _scene.find_child("RoueMoulin", true, false) != null, "l'Eure et son moulin à eau")
	var nb_maisons: int = _scene.find_child("Maisons", true, false).get_child_count()
	_verifier(nb_maisons >= 1, "des maisons à pans de bois (%d nœuds)" % nb_maisons)
	_verifier(_vivants("chien_errant_chartres").size() >= 6, "des chiens errants (%d)" % _vivants("chien_errant_chartres").size())

	# --- Chapitre 4 : La ville basse.
	var combat_joueur = _joueur.get_node("Combat")
	var porte: Vector2 = _scene.PORTE_EPARS
	await _placer(Vector3(porte.x + 2.0, _scene.hauteur(porte.x + 2.0, porte.y) + 0.4, porte.y), 0.0)
	await _attendre(20)
	_verifier(_id_etape() == "aude", "on entre par la porte des Épars (%s)" % _id_etape())
	await _lire_dialogue()
	var lues := await _parler("Aude")
	_verifier(lues >= 4, "Aude raconte l'atelier de son père (%d bulles)" % lues)
	_verifier(_id_etape() == "pillards", "les pillards (%s)" % _id_etape())
	await _attendre(5)
	await _tuer("mercenaire_pillard_ruines", combat_joueur, "pillards")
	_verifier(_id_etape() == "coffret", "les pillards sont chassés (%s)" % _id_etape())
	await _aller_pres(_scene.find_child("CoffretVerrier", true, false), Vector3(0, 0, 1.3))
	await _appuyer_f()
	await _attendre(220)
	_verifier(_id_etape() == "aude_coffret", "le coffret est dégagé (%s)" % _id_etape())
	await _lire_dialogue()
	await _parler("Aude")
	_verifier(_id_etape() == "las_artisans", "les artisans sont Las (%s)" % _id_etape())
	for k in 3:
		await _vitrail("CourageArtisan%d" % k, ["lancette", "rose", "fleur"][k], k == 0)
	_verifier(_id_etape() == "aude_artisans", "les trois artisans reprennent leurs outils (%s)" % _id_etape())
	await _lire_dialogue()
	await _parler("Aude")
	lues = await _parler("FrereAnselme")
	_verifier(lues >= 5, "frère Anselme raconte les trois jours dans la crypte (%d bulles)" % lues)
	await _aller_pres(_scene.find_child("CraieCloitre", true, false), Vector3(0, 0, 1.4))
	await _appuyer_f()
	await _attendre(10)
	_verifier(_id_etape() == "anselme_fin", "le message de Masque est lu (%s)" % _id_etape())
	await _lire_dialogue()
	await _parler("FrereAnselme")
	_verifier(_id_etape() == "vers_parvis", "chapitre 5 : vers le parvis (%s)" % _id_etape())
	_verifier(_scene.find_child("CardinalMelior", true, false).visible, "le cardinal est arrivé sur le parvis")
	_verifier(_scene.find_child("FumeePlomb", true, false).visible, "une fumée grise rampe sur le parvis")

	# --- Chapitre 5 : Le serment du cardinal.
	await _lire_dialogue()
	var pv: Vector2 = _scene.PARVIS
	await _placer(Vector3(pv.x, _scene.hauteur(pv.x, pv.y) + 0.4, pv.y), 0.0)
	await _attendre(20)
	_verifier(_id_etape() == "cardinal", "on arrive au parvis (%s)" % _id_etape())
	await _lire_dialogue()
	lues = await _parler("CardinalMelior")
	_verifier(lues >= 3, "le cardinal demande de l'aide (%d bulles)" % lues)
	for k in 3:
		await _aller_pres(_scene.find_child("Fumigene%d" % k, true, false), Vector3(0, 0, 1.3))
		await _appuyer_f()
		await _attendre(160)
	_verifier(_id_etape() == "hommes_plomb", "les trois fumigènes sont étouffés (%s)" % _id_etape())
	await _attendre(5)
	await _tuer("masque_homme_plomb", combat_joueur, "hommes_plomb")
	_verifier(_id_etape() == "las_foule", "les hommes de Plomb sont arrêtés (%s)" % _id_etape())
	for k in 3:
		await _vitrail("CourageFoule%d" % k, ["rose", "belle_verriere", "lancette"][k])
	_verifier(not _scene.find_child("FumeePlomb", true, false).visible, "la fumée grise se dissipe")
	_verifier(_scene.find_child("PlombMasquee", true, false).visible, "Plomb apparaît sur les marches")
	await _lire_dialogue()
	lues = await _parler("PlombMasquee")
	_verifier(lues >= 4, "Plomb parle de la dîme et de Notre-Dame (%d bulles)" % lues)
	_verifier(_id_etape() == "choix_plomb", "il faut lui répondre (%s)" % _id_etape())
	await _aller_pres(_scene.find_child("BatirJuste", true, false), Vector3(0, 0, 0.8))
	await _appuyer_f()
	await _attendre(5)
	lues = await _lire_dialogue()
	if lues == 0:
		lues = await _parler("PlombMasquee")
	_verifier(lues >= 3, "« Bâtir, et rendre plus juste » (%d bulles)" % lues)
	_verifier(_id_etape() == "serment", "Plomb s'enfuit, le cardinal parle (%s)" % _id_etape())
	_verifier(not _scene.find_child("PlombMasquee", true, false).visible, "Plomb a disparu dans la foule")
	await _parler("CardinalMelior")
	_verifier(_id_etape() == "eveque_serment", "le serment de la ville (%s)" % _id_etape())
	await _lire_dialogue()
	await _parler("EvequeRenaud")
	var inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("haubert_eveque") >= 1, "l'haubert de l'évêque est dans le sac")
		_verifier(inventaire.quantite("chaperon_ecole") >= 1, "le chaperon de l'école aussi")

	# --- La progression est gardée.
	var cfg2 := ConfigFile.new()
	cfg2.load(FICHIER)
	_verifier(String(cfg2.get_value("moyen_age", "choix_choix_plomb", "")) == "batir_juste", "le choix face à Plomb est enregistré")
	_scene.queue_free()
	await _attendre(5)
	await _charger()
	await _attendre(20)
	_verifier(not _scene.find_child("LasBoulanger", true, false).fige, "Gervais le boulanger n'est plus Las")
	_verifier(_scene.find_child("CardinalMelior", true, false).visible, "le cardinal est toujours sur le parvis")
	# La route du sud-ouest ramène aux carrières.
	var so: Vector2 = _scene.SORTIE_SO
	await _placer(Vector3(so.x + 3.0, _scene.hauteur(so.x + 3.0, so.y - 2.0) + 0.4, so.y - 2.0), PI / 2)
	await _attendre(70)
	_verifier(_quete.zone_demandee == "bercheres", "la route du sud-ouest ramène aux carrières (%s)" % _quete.zone_demandee)

	print("")
	if _echecs == 0:
		print("TOUS LES TESTS PASSENT")
	else:
		print("%d ÉCHEC(S)" % _echecs)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	quit(1 if _echecs > 0 else 0)
