extends SceneTree
## Test automatique de la ville de Mayence (zone 3) et des chapitres 4 et 5 : l'arrivée par le
## bac, le Holzturm, la cathédrale, la cour Humbrecht ; Gutenberg, couler une lettre, composer,
## presser, délivrer Fust, les lettres de plomb de la cave ; puis le coffre vide, l'enquête de
## Konrad Humery, l'orfèvre Hennen, le Holzturm, le receleur, les poinçons et la faille.
## Lancement : godot --headless --path game -s res://tests/test_ville.gd

const FICHIER := "user://test_mayence_ville.cfg"
const SCENE := "res://scenes/monde/mayence/ville.tscn"

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
	var cfg := ConfigFile.new()
	cfg.set_value("mayence", "etape", "vers_mayence")
	cfg.save(FICHIER)
	await _charger()
	print("Test de la ville de Mayence (chapitres 4 et 5)")

	# --- Le monde.
	_verifier(_joueur != null and _joueur.is_on_floor(), "on arrive par le bac")
	var p: Vector3 = _joueur.global_position
	_verifier(p.x > 110.0 and absf(p.z - 58.0) < 8.0, "sur la rive, devant le Holzturm (%.0f, %.0f)" % [p.x, p.z])
	_verifier(_id_etape() == "vers_humbrecht", "l'arrivée termine l'étape du bac (%s)" % _id_etape())
	_verifier(_scene.find_child("Cathedrale", true, false) != null, "la cathédrale Saint-Martin")
	_verifier(_scene.find_child("Holzturm", true, false) != null and _scene.find_child("Fischtor", true, false) != null, "le Holzturm et la porte des Pêcheurs")
	_verifier(_scene.find_child("Remparts", true, false).get_child_count() > 20, "des remparts et des tours rondes")
	var nb_maisons := _scene.find_children("MaisonRhenane*", "Node3D", true, false).size()
	_verifier(nb_maisons >= 60, "des rues de maisons à colombages (%d)" % nb_maisons)
	_verifier(_scene.find_child("Marche", true, false) != null, "le marché")
	_verifier(_scene.find_child("AtelierGutenberg", true, false) != null and _scene.find_child("PresseGutenberg", true, false) != null, "l'atelier de Gutenberg et sa presse")
	_verifier(_scene.find_child("Fonderie", true, false) != null, "la fonderie")
	_verifier(_scene.find_child("SaintChristophe", true, false) != null, "l'église Saint-Christophe")
	_verifier(_scene.find_child("ChatAtelier", true, false) != null, "le chat de l'atelier")
	var nb_arbres: int = _scene.find_child("Arbres", true, false).get_child_count()
	_verifier(nb_arbres >= 50, "des arbres dans les jardins et hors les murs (%d)" % nb_arbres)
	_verifier(_vivants("statue_lettres_plomb").size() >= 3, "des hommes de lettres de plomb dans les jardins (%d)" % _vivants("statue_lettres_plomb").size())
	_verifier(_vivants("mercenaire_archeveque").size() >= 4, "des mercenaires de l'archevêque (%d)" % _vivants("mercenaire_archeveque").size())
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
	# On passe le Holzturm à pied.
	await _placer(Vector3(124, _scene.hauteur(124, 58) + 0.4, 58), PI / 2)
	Input.action_press("avancer")
	await _attendre(220)
	Input.action_release("avancer")
	await _attendre(5)
	_verifier(_joueur.global_position.x < 104.0, "on passe sous la voûte du Holzturm (x = %.1f)" % _joueur.global_position.x)

	# --- Chapitre 4 : La cour Humbrecht.
	var combat_joueur = _joueur.get_node("Combat")
	await _placer(Vector3(14, _scene.hauteur(14, -86) + 0.4, -86), 0.0)
	await _attendre(20)
	_verifier(_id_etape() == "keffer_ville", "la cour Humbrecht (%s)" % _id_etape())
	var lues := await _parler("HeinrichKeffer")
	_verifier(lues >= 3, "Keffer accueille (%d bulles)" % lues)
	lues = await _parler("Gutenberg")
	_verifier(lues >= 5, "Gutenberg en personne (%d bulles)" % lues)
	_verifier(_id_etape() == "fondre", "il faut couler une lettre (%s)" % _id_etape())
	await _ramasser("MouleAtelier", 300)
	_verifier(_id_etape() == "composer", "une lettre de plomb (%s)" % _id_etape())
	await _composer("CasseAtelier", "in principio")
	_verifier(_id_etape() == "presser", "« in principio » (%s)" % _id_etape())
	await _ramasser("PresseAtelier", 240)
	_verifier(_id_etape() == "schoeffer", "la première épreuve (%s)" % _id_etape())
	await _parler("PeterSchoeffer")
	_verifier(_id_etape() == "fust", "Fust est Scellé (%s)" % _id_etape())
	var fust: Node = _scene.find_child("JohannFust", true, false)
	_verifier(fust != null and fust.fige, "Fust serre sa bourse")
	await _composer("LibererFust", "un livre pour mille lecteurs")
	_verifier(_id_etape() == "fust_parle", "Fust est délivré (%s)" % _id_etape())
	_verifier(not fust.fige, "la cire est tombée de Fust")
	await _parler("JohannFust")
	_verifier(_id_etape() == "lettres_cave", "des lettres remontent de la cave (%s)" % _id_etape())
	await _attendre(5)
	_verifier(_vivants("statue_lettres_plomb_cave").size() == 5, "cinq hommes de lettres (%d)" % _vivants("statue_lettres_plomb_cave").size())
	await _tuer("statue_lettres_plomb_cave", combat_joueur, "lettres_cave")
	_verifier(_id_etape() == "gutenberg_fin", "la cave est nettoyée (%s)" % _id_etape())
	await _parler("Gutenberg")
	var inventaire = _joueur.get_node_or_null("Inventaire")
	var a_inventaire: bool = inventaire != null and inventaire.has_method("quantite")
	if a_inventaire:
		_verifier(inventaire.quantite("tablier_pressier") >= 1, "le tablier de pressier")
		_verifier(inventaire.quantite("premiere_lettre") >= 1, "et ta première lettre de plomb")

	# --- Chapitre 5 : Les poinçons volés.
	_verifier(_id_etape() == "coffre", "chapitre 5 : le coffre (%s)" % _id_etape())
	await _ramasser("CoffrePoincons", 160)
	_verifier(_id_etape() == "humery", "le coffre est vide (%s)" % _id_etape())
	lues = await _parler("KonradHumery")
	_verifier(lues >= 3, "le syndic Humery (%d bulles)" % lues)
	for nom in ["IndiceOrfevres", "IndiceMarche", "IndiceRive"]:
		await _ramasser(nom, 160)
	_verifier(_id_etape() == "humery_piste", "trois taches de cire (%s)" % _id_etape())
	await _parler("KonradHumery")
	_verifier(_id_etape() == "hennen", "l'orfèvre Hennen (%s)" % _id_etape())
	await _composer("LibererHennen", "chaque lettre est a tous")
	_verifier(_id_etape() == "hennen_parle", "Hennen est délivré (%s)" % _id_etape())
	await _parler("OrfevreHennen")
	_verifier(_id_etape() == "holzturm", "les hommes de Sceau au Holzturm (%s)" % _id_etape())
	await _attendre(5)
	await _tuer("mercenaire_homme_sceau_tour", combat_joueur, "holzturm")
	_verifier(_id_etape() == "receleur", "la porte est passée (%s)" % _id_etape())
	await _attendre(5)
	await _tuer("mercenaire_chef_receleur", combat_joueur, "receleur")
	_verifier(_id_etape() == "poincons", "le receleur est arrêté (%s)" % _id_etape())
	await _ramasser("PoinconsGutenberg", 110)
	_verifier(_id_etape() == "faille", "les poinçons sont repris (%s)" % _id_etape())
	await _attendre(5)
	await _tuer("statue_lettres_plomb_faille", combat_joueur, "faille")
	var faille = _scene.find_child("Faille", true, false)
	await _aller_pres(faille)
	await _appuyer_f()
	await _attendre(360)
	_verifier(faille.fermee, "la faille est refermée")
	_verifier(_id_etape() == "gutenberg_rendre", "retour à l'atelier (%s)" % _id_etape())
	await _parler("Gutenberg")
	if a_inventaire:
		_verifier(inventaire.quantite("poincon_g") >= 1, "le poinçon « G »")
	_verifier(_id_etape() == "veillee", "chapitre 6 : la veillée (%s)" % _id_etape())

	# --- Chapitre 6 : L'offre de l'Éditeur.
	var marchal = _scene.find_child("EtienneMarchal", true, false)
	_verifier(marchal != null and not marchal.visible, "Marchal n'est pas encore là")
	await _parler("Gutenberg")
	_verifier(_id_etape() == "lumiere", "la lumière blanche (%s)" % _id_etape())
	await _attendre(30)
	_verifier(_scene._nuit, "la nuit est tombée sur Mayence")
	_verifier(_scene.find_child("LumieresNuit", true, false).visible, "les lanternes sont allumées")
	_verifier(marchal.visible and _scene.find_child("MachineMarchal", true, false).visible, "Marchal et sa machine sont dans l'atelier")
	await _placer(Vector3(10.0, 1.6, -97.5), 0.0)
	await _attendre(30)
	_verifier(_id_etape() == "marchal", "l'Éditeur (%s)" % _id_etape())
	lues = await _parler("EtienneMarchal")
	_verifier(lues >= 3, "Marchal fait son offre (%d bulles)" % lues)
	_verifier(_id_etape() == "gutenberg_hesite", "Gutenberg hésite (%s)" % _id_etape())
	await _parler("Gutenberg")
	_verifier(_id_etape() == "convaincre", "le choix (%s)" % _id_etape())
	await _ramasser("DireApprendre", 30)
	await _parler("Gutenberg")
	_verifier(_id_etape() == "marchal_apprendre", "la réponse « apprendre » mène à la bonne suite (%s)" % _id_etape())
	await _parler("EtienneMarchal")
	_verifier(not marchal.visible, "Marchal est parti avec sa machine")
	if a_inventaire:
		_verifier(inventaire.quantite("carte_marchal") >= 1, "la carte de visite de Marchal")
	_verifier(_id_etape() == "torches_sceau", "les torches de Sceau (%s)" % _id_etape())
	await _attendre(5)
	await _tuer("mercenaire_homme_sceau_nuit", combat_joueur, "torches_sceau")
	_verifier(_id_etape() == "affiche_sceau", "l'affiche (%s)" % _id_etape())
	await _attendre(30)
	_verifier(not _scene._nuit, "le jour se lève")
	await _ramasser("AfficheSceau", 110)
	_verifier(_id_etape() == "gutenberg_aube", "retour à Gutenberg (%s)" % _id_etape())
	await _parler("Gutenberg")
	if a_inventaire:
		_verifier(inventaire.quantite("cape_veilleur") >= 1, "la cape du veilleur")
	_verifier(_id_etape() == "vers_francfort", "chapitre 7 : la nef de Fust pour Francfort (%s)" % _id_etape())
	await _attendre(20)
	_verifier(_scene._route_francfort, "le ponton de la nef de Fust est ouvert")

	# --- La progression est gardée.
	_scene.queue_free()
	await _attendre(5)
	await _charger()
	await _attendre(20)
	_verifier(_scene.find_child("Faille", true, false).fermee, "au retour, la faille est toujours fermée")
	_verifier(not _scene.find_child("JohannFust", true, false).fige, "Fust n'est plus Scellé")
	_verifier(not _scene.find_child("OrfevreHennen", true, false).fige, "Hennen non plus")
	_verifier(not _scene.find_child("EtienneMarchal", true, false).visible, "Marchal n'est pas revenu")
	_verifier(not _scene._nuit, "il fait jour au retour")
	# Le ponton du bac ramène au Rhin.
	await _placer(Vector3(_scene.SORTIE_E.x - 1.0, 1.6, _scene.SORTIE_E.y), PI / 2)
	await _attendre(20)
	_verifier(_quete._en_voyage or root.get_node("Reseau").get_meta("arrivee_mayence", "") == "ville", "le bac ramène au Rhin")
	root.get_node("Reseau").remove_meta("arrivee_mayence")

	print("")
	if _echecs == 0:
		print("TOUS LES TESTS PASSENT")
	else:
		print("%d ÉCHEC(S)" % _echecs)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	quit(1 if _echecs > 0 else 0)
