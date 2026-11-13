extends SceneTree
## Test automatique de la fin de la Préhistoire : chapitre 7 « Les murs vides »
## (résine, torches, Toran) et chapitre 8 dans la Grande Grotte (donjon) :
## galerie, cristaux, l'Ours Sans Mémoire et ses phases, la fracture majeure,
## la fresque finale.
## Lancement : godot --headless --path game -s res://tests/test_grotte.gd

const FICHIER := "user://test_grotte_progression.cfg"

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


func _aller_a(p2: Vector2) -> void:
	await _placer(Vector3(p2.x, _scene.hauteur(p2.x, p2.y) + 0.3, p2.y), 0.0)


func _aller_pres(cible: Node3D, decalage := Vector3(0, 0, 1.2)) -> void:
	var p: Vector3 = cible.global_position + decalage
	p.y = _scene.hauteur(p.x, p.z) + 0.3
	await _placer(p, 0.0)


func _id_etape() -> String:
	return _quete.etape_actuelle().get("id", "")


func _vivants(type: String) -> Array:
	var liste := []
	for bete in get_nodes_in_group("loups"):
		if String(bete.type_ennemi) == type and bete.combat.est_vivant():
			liste.append(bete)
	return liste


func _charger(chemin: String, etape: String, choix := "") -> void:
	if _scene != null:
		_scene.queue_free()
		await _attendre(5)
	if etape != "":
		var cfg := ConfigFile.new()
		cfg.load(FICHIER)
		cfg.set_value("prehistoire", "etape", etape)
		if choix != "":
			cfg.set_value("prehistoire", "choix_choix_grise", choix)
		cfg.save(FICHIER)
	_scene = load(chemin).instantiate()
	_quete = _scene.get_node("Quete")
	_quete.fichier_progression = FICHIER
	_quete.voyage_reel = false
	root.add_child(_scene)
	await _attendre(40)
	_joueur = get_first_node_in_group("joueur_local")
	_dialogue = get_first_node_in_group("dialogue")


func _tuer_proches(centre: Vector3, rayon: float) -> int:
	var n := 0
	var combat_joueur = _joueur.get_node("Combat")
	for bete in get_nodes_in_group("loups"):
		if bete.combat.est_vivant() and bete.global_position.distance_to(centre) < rayon:
			bete.combat.subir(9999.0, combat_joueur)
			n += 1
	return n


func _lancer() -> void:
	print("Test de la Grande Grotte (Préhistoire)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	# --- Chapitre 7, aux Falaises Peintes.
	await _charger("res://scenes/monde/prehistoire/falaises.tscn", "murs_vides")
	var aina = _scene.find_child("Aina", true, false)
	_verifier(aina.visible, "le clan est à l'abri")
	await _aller_pres(aina)
	await _appuyer_f()
	var lues := await _lire_dialogue()
	_verifier(lues >= 5 and _id_etape() == "resine", "Aïna voit les peintures pâlir (%d bulles, %s)" % [lues, _id_etape()])
	var fresque := _scene.find_child("Fresque", true, false) as Decal
	_verifier(fresque.modulate.a < 0.5, "la fresque de l'abri pâlit")
	var faits := 0
	for objet in get_nodes_in_group("objet_quete"):
		if objet.groupe != "resine":
			continue
		await _aller_pres(objet)
		await _appuyer_f()
		await _attendre(2 * 60 + 20)
		faits += 1
	_verifier(faits == 3 and _id_etape() == "torches", "trois troncs de résine grattés (%d, %s)" % [faits, _id_etape()])
	await _aller_pres(_scene.find_child("VieilleMere", true, false))
	await _appuyer_f()
	lues = await _lire_dialogue()
	_verifier(lues >= 5 and _id_etape() == "recruter_toran", "la Vieille Mère fait les torches et parle de l'Ours (%d bulles, %s)" % [lues, _id_etape()])
	var toran = _scene.find_child("Toran", true, false)
	await _aller_pres(toran)
	await _appuyer_f()
	lues = await _lire_dialogue()
	_verifier(lues >= 4 and _id_etape() == "devant_la_grotte", "Toran et Naya viennent (%d bulles, %s)" % [lues, _id_etape()])
	_verifier(Vector2(toran.global_position.x, toran.global_position.z).distance_to(Vector2(72, -30)) < 2.0, "Toran attend devant la grotte")
	await _placer(Vector3(76, _scene.hauteur(76, -32) + 0.4, -32), 0.0)
	await _attendre(10)
	_verifier(_id_etape() == "entrer_grotte", "chapitre 8 : entrer dans la grotte (%s)" % _id_etape())
	var bouche: Vector3 = _quete._position_cible(_quete.etape_actuelle())
	_verifier(bouche != null, "le repère montre l'entrée de la grotte")
	await _placer(bouche + Vector3(0, 0.4, 0), 0.0)
	await _attendre(70)
	_verifier(_quete.zone_demandee == "grotte", "l'entrée mène à la Grande Grotte (%s)" % _quete.zone_demandee)

	# --- Chapitre 8, dans la grotte.
	await _charger("res://scenes/monde/prehistoire/grotte.tscn", "")
	_verifier(_joueur != null and _joueur.is_on_floor(), "on arrive dans la grotte, posé au sol")
	_verifier(_id_etape() == "galerie", "il faut traverser la galerie (%s)" % _id_etape())
	var p: Vector3 = _joueur.global_position
	_verifier(_scene.hauteur(p.x + 12.0, p.z) - _scene.hauteur(p.x, p.z) > 10.0, "des parois de roche de chaque côté")
	_verifier(_scene.find_child("Voute", true, false) != null, "une voûte ferme la grotte")
	_verifier(_scene.find_child("Peintures", true, false).get_child_count() >= 5, "des peintures dans la galerie")
	var combat_joueur = _joueur.get_node("Combat")
	for etape in ["galerie", "cristaux"]:
		var souvenirs := _vivants("loup_fracture_grotte")
		_verifier(souvenirs.size() == 4, "[%s] quatre souvenirs fracturés (%d)" % [etape, souvenirs.size()])
		for bete in souvenirs:
			bete.combat.subir(9999.0, combat_joueur)
			await _attendre(3)
		await _attendre(5)
	_verifier(_id_etape() == "ours", "l'antre de l'Ours (%s)" % _id_etape())
	var ours = _vivants("ours_sans_memoire")
	_verifier(ours.size() == 1, "l'Ours Sans Mémoire est là")
	ours = ours[0]
	_verifier(ours.get_node("Apparence").scale.x > 2.0, "il est immense")
	# Les phases : sous 66 % puis 33 %, des renforts.
	ours.combat.subir(ours.combat.pv_max * 0.4, combat_joueur)
	await _attendre(10)
	var renforts := _vivants("loup_fracture_grotte")
	_verifier(renforts.size() == 3, "à 60 %%, trois souvenirs surgissent (%d)" % renforts.size())
	for bete in renforts:
		bete.combat.subir(9999.0, combat_joueur)
	ours.combat.subir(ours.combat.pv_max * 0.35, combat_joueur)
	await _attendre(10)
	renforts = _vivants("loup_fracture_grotte")
	_verifier(renforts.size() == 4, "à 25 %%, quatre de plus (%d)" % renforts.size())
	for bete in renforts:
		bete.combat.subir(9999.0, combat_joueur)
	ours.combat.subir(99999.0, combat_joueur)
	await _attendre(10)
	_verifier(_id_etape() == "fermer_fracture", "l'Ours est vaincu (%s)" % _id_etape())
	var fracture = _scene.find_child("FractureMajeure", true, false)
	await _aller_pres(fracture, Vector3(0, 0, 4.0))
	await _appuyer_f()
	await _attendre(6 * 60 + 40)
	_verifier(fracture.fermee, "la fracture majeure est refermée")
	_verifier(_id_etape() == "fresque_finale", "retour à l'abri (%s)" % _id_etape())
	var repere = _quete._position_cible(_quete.etape_actuelle())
	_verifier(repere != null and repere.z > 100.0, "le repère montre la sortie de la grotte")
	await _placer(Vector3(_scene.ENTREE.x, _scene.hauteur(_scene.ENTREE.x, _scene.ENTREE.y + 4) + 0.5, _scene.ENTREE.y + 4), 0.0)
	await _attendre(70)
	_verifier(_quete.zone_demandee == "falaises", "la sortie ramène aux falaises (%s)" % _quete.zone_demandee)

	# --- La fresque finale.
	await _charger("res://scenes/monde/prehistoire/falaises.tscn", "")
	aina = _scene.find_child("Aina", true, false)
	await _aller_pres(aina)
	await _appuyer_f()
	lues = await _lire_dialogue()
	_verifier(lues >= 5 and _quete.etape == -1, "Aïna montre la fresque : l'île est sauvée (%d bulles)" % lues)
	_verifier(_scene.find_child("FresqueVoyageur", true, false).visible and not _scene.find_child("Fresque", true, false).visible,
			"le Venu-du-Brouillard est peint sur la paroi")
	await _charger("res://scenes/monde/prehistoire/falaises.tscn", "")
	_verifier(_scene.find_child("FresqueVoyageur", true, false).visible, "la fresque reste après rechargement")
	await _charger("res://scenes/monde/prehistoire/grotte.tscn", "")
	_verifier(_scene.find_child("FractureMajeure", true, false).fermee and _vivants("ours_sans_memoire").is_empty(),
			"dans la grotte, la fracture reste fermée et l'Ours ne revient pas")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
