extends SceneTree
## Test automatique du chapitre 8 de l'Égypte : Ânkhkhaf ouvre le passage des ouvriers,
## puis le donjon du Cœur de la Pyramide (cobras, bâtisseurs emmurés, bouchon de granit,
## gardes et Djedi dans la Grande Galerie, herses, Isfet et ses trois phases, la fracture
## majeure), et enfin Merer au chantier devant la pyramide terminée.
## Lancement : godot --headless --path game -s res://tests/test_coeur_pyramide.gd

const FICHIER := "user://test_egypte_progression.cfg"
const VILLAGE := "res://scenes/monde/egypte/village_batisseurs.tscn"
const DONJON := "res://scenes/monde/egypte/coeur_pyramide.tscn"

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


func _parler(id_noeud: String) -> int:
	var pnj = _scene.find_child(id_noeud, true, false)
	var p: Vector3 = pnj.global_position + Vector3(0, 0, 1.6)
	p.y = maxf(_scene.hauteur(p.x, p.z), pnj.global_position.y) + 0.3
	await _placer(p, 0.0)
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


func _utiliser(nom: String, attente: int) -> void:
	var o = _scene.find_child(nom, true, false)
	await _placer(o.global_position + Vector3(0, 0.5, 0.9), 0.0)
	await _appuyer_f()
	await _attendre(attente)


func _reprendre_a(etape: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("egypte", "etape", etape)
	cfg.save(FICHIER)


func _tuer_tous(type: String) -> void:
	var combat_joueur = _joueur.get_node("Combat")
	for b in _vivants(type):
		b.combat.subir(99999.0, combat_joueur)
	await _attendre(20)


func _marcher(angle: float, images: int) -> void:
	_joueur.camera.lacet = angle
	_joueur.rotation.y = angle
	Input.action_press("avancer")
	await _attendre(images)
	Input.action_release("avancer")
	await _attendre(5)


func _lancer() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Test du chapitre 8 (Égypte) : le Cœur de la Pyramide")
	# --- Au chantier : Ânkhkhaf fait ouvrir le passage des ouvriers.
	_reprendre_a("ankhkhaf_rampe")
	await _charger(VILLAGE)
	_verifier(_id_etape() == "ankhkhaf_rampe", "le chapitre 8 commence au chantier (%s)" % _id_etape())
	var barriere = _scene.find_child("Barriere", true, false)
	_verifier(barriere != null and barriere.visible, "une barrière ferme le passage des ouvriers")
	var lues := await _parler("AnkhkhafChantier")
	_verifier(lues >= 4, "Ânkhkhaf raconte ce qui gronde dans la pyramide (%d bulles)" % lues)
	_verifier(_id_etape() == "entrer_pyramide", "il faut entrer dans la pyramide (%s)" % _id_etape())
	_verifier(not barriere.visible, "la barrière est enlevée")
	var passage: Vector2 = _scene.PASSAGE
	await _placer(Vector3(passage.x, _scene.hauteur(passage.x, passage.y + 3.0) + 0.5, passage.y + 3.0), 0.0)
	await _marcher(0.0, 80)
	await _attendre(80)
	_verifier(_quete.zone_demandee == "coeur_pyramide", "le passage mène dans la pyramide (%s)" % _quete.zone_demandee)

	# --- Le donjon.
	await _charger(DONJON)
	_verifier(_joueur != null and _joueur.is_on_floor(), "on arrive dans le vestibule")
	_verifier(_id_etape() == "souterraine", "l'arrivée termine l'étape (%s)" % _id_etape())
	_verifier(is_equal_approx(_scene.hauteur(0, -47), -12.0), "la chambre souterraine est 12 m plus bas")
	_verifier(is_equal_approx(_scene.hauteur(0, 76), 18.0), "la chambre du Roi est 18 m plus haut")
	# On descend le couloir à pied.
	await _placer(Vector3(0, _scene.hauteur(0, -97) + 0.5, -97), PI)
	await _marcher(PI, 240)
	_verifier(_joueur.global_position.z > -75.0 and _joueur.global_position.y < -4.0,
			"le couloir descend vers la chambre souterraine (z = %.0f, y = %.1f)" % [_joueur.global_position.z, _joueur.global_position.y])
	_verifier(_vivants("cobra_fracture").size() == 5, "cinq cobras fracturés grouillent en bas (%d)" % _vivants("cobra_fracture").size())
	var cobra = _vivants("cobra_fracture")[0] if not _vivants("cobra_fracture").is_empty() else null
	_verifier(cobra != null and cobra.get_node("Apparence").get("_delegue") != null \
			and cobra.get_node("Apparence")._delegue.espece == "cobra", "ce sont de vrais serpents (coiffe, crochets)")
	await _tuer_tous("cobra_fracture")
	_verifier(_id_etape() == "emmures", "les cobras sont morts (%s)" % _id_etape())
	await _attendre(5)
	_verifier(_vivants("oublie_pyramide").size() == 3, "trois bâtisseurs emmurés attendent (%d)" % _vivants("oublie_pyramide").size())
	await _tuer_tous("oublie_pyramide")
	await _attendre(20)
	_verifier(_id_etape() == "noms_emmures", "ils sont à terre (%s)" % _id_etape())
	# Les bâtisseurs tombent parfois tout près les uns des autres : on rend les noms
	# qui restent jusqu'à ce que l'étape change.
	var essais := 0
	while _id_etape() == "noms_emmures" and essais < 8:
		essais += 1
		for o in get_nodes_in_group("objet_quete"):
			if o.get("groupe") == "nom_rendu" and o.actif and not o.ramasse:
				await _utiliser(String(o.name), 20)
				break
	_verifier(_id_etape() == "parler_sekhem", "leurs noms sont rendus (%s)" % _id_etape())
	await _attendre(10)
	lues = await _parler("EmmureSekhem")
	_verifier(lues >= 4, "Sekhem raconte le bouchon de granit (%d bulles)" % lues)
	_verifier(_id_etape() == "coins", "il faut retirer les coins (%s)" % _id_etape())
	# Le bouchon bloque la Grande Galerie.
	await _placer(Vector3(0, 0.5, -2), PI)
	await _marcher(PI, 120)
	_verifier(_joueur.global_position.z < 2.5, "le bouchon de granit ferme la galerie (z = %.1f)" % _joueur.global_position.z)
	await _utiliser("RetirerCoins", 360)
	_verifier(_id_etape() == "galerie", "le bouchon glisse (%s)" % _id_etape())
	_verifier(not _scene.find_child("BouchonGalerie", true, false).visible, "le bouchon a disparu")
	_verifier(_vivants("garde_pyramide").size() == 4, "quatre gardes tiennent la galerie (%d)" % _vivants("garde_pyramide").size())
	await _tuer_tous("garde_pyramide")
	_verifier(_id_etape() == "djedi", "les gardes sont tombés (%s)" % _id_etape())
	# On monte la galerie à pied.
	await _placer(Vector3(0, 0.5, -2), PI)
	await _marcher(PI, 420)
	_verifier(_joueur.global_position.z > 30.0 and _joueur.global_position.y > 9.0,
			"la Grande Galerie monte vers le roi (z = %.0f, y = %.1f)" % [_joueur.global_position.z, _joueur.global_position.y])
	_verifier(_vivants("garde_chef_djedi").size() == 1, "Djedi barre le palier")
	await _tuer_tous("garde_chef_djedi")
	_verifier(_id_etape() == "herses", "Djedi est vaincu (%s)" % _id_etape())
	# Les herses bloquent l'antichambre, puis se lèvent une à une.
	await _placer(Vector3(0, 18.5, 56.5), PI)
	await _marcher(PI, 120)
	_verifier(_joueur.global_position.z < 59.5, "les herses ferment l'antichambre (z = %.1f)" % _joueur.global_position.z)
	for k in 3:
		await _utiliser("LeverHerse%d" % k, 300)
	_verifier(_id_etape() == "isfet", "les trois herses sont levées (%s)" % _id_etape())
	await _attendre(200)
	_verifier(_scene.find_child("Herse0", true, false).position.y > 24.0, "la herse est remontée dans sa rainure")

	# --- Isfet.
	var isfet = _vivants("isfet")[0] if not _vivants("isfet").is_empty() else null
	_verifier(isfet != null, "Isfet attend dans la chambre du Roi")
	if isfet == null:
		quit(1)
		return
	_verifier(isfet.get_node("Apparence")._delegue != null and isfet.get_node("Apparence")._delegue.espece == "isfet",
			"c'est un serpent géant de sable et de cristal")
	# Le test joue seul : on donne au joueur la vie de tout un groupe.
	var combat_joueur = _joueur.get_node("Combat")
	combat_joueur.pv_max = 1000000.0
	combat_joueur.pv = combat_joueur.pv_max
	await _placer(Vector3(0, 18.5, 60.0), PI)
	await _marcher(PI, 160)
	_verifier(_joueur.global_position.z > 64.5, "on entre dans la chambre du Roi (z = %.1f)" % _joueur.global_position.z)
	var depart: Vector3 = isfet.global_position
	await _attendre(60)
	_verifier(isfet.etat == 1, "Isfet attaque le groupe")
	_verifier(Vector2(isfet.global_position.x - depart.x, isfet.global_position.z - depart.z).length() < 0.5,
			"il ne quitte pas son mur")
	_verifier(_scene._phase == 1, "phase 1 : les murs vivants")
	# Plongée : il rentre dans la pierre et ressort par une autre bouche.
	_scene._prochaine_plongee = 0.0
	await _attendre(20)
	_verifier(isfet.combat.a_effet("enfoui"), "il plonge dans le mur")
	await _attendre(150)
	_verifier(isfet.global_position.distance_to(depart) > 5.0, "il ressort par une autre bouche")
	combat_joueur.reanimer(100.0)
	# Phase 2 : les noms effacés.
	isfet.combat.pv = isfet.combat.pv_max * 0.6
	await _attendre(10)
	_verifier(_scene._phase == 2, "phase 2 : les noms effacés")
	_verifier(_scene.find_child("GraverCartouche0", true, false).actif, "les cartouches peuvent être gravés")
	_verifier(_vivants("cobra_fracture").size() >= 3, "des cobras sortent des murs (%d)" % _vivants("cobra_fracture").size())
	await _tuer_tous("cobra_fracture")
	_scene._prochain_effacement = 0.0
	await _attendre(10)
	_verifier(combat_joueur.a_effet("nom_efface"), "Isfet efface le nom d'un joueur")
	var combat_competences = _joueur.get_node("CombatJoueur")
	_verifier(combat_competences.raison_impossible(5).begins_with("Ton nom est effacé"), "ses compétences d'époque sont bloquées")
	combat_joueur.reanimer(100.0)
	combat_joueur.ajouter_effet("nom_efface", 40.0)
	await _utiliser("GraverCartouche0", 10)
	_verifier(not combat_joueur.a_effet("nom_efface"), "graver le cartouche rend son nom")
	# Phase 3 : le sablier de Vera.
	isfet.combat.pv = isfet.combat.pv_max * 0.3
	await _attendre(10)
	_verifier(_scene._phase == 3, "phase 3 : le sablier")
	_verifier(_scene.find_child("SableQuiMonte", true, false).visible, "la chambre se remplit de sable")
	_verifier(_scene.find_child("VeraBalcon", true, false).visible, "Vera Lind regarde depuis le balcon")
	# Le sablier se vide : le groupe est englouti, et tout recommence.
	_scene._fin_sable = 0.001
	await _attendre(10)
	_verifier(not combat_joueur.est_vivant(), "le sable engloutit le groupe")
	await _attendre(200)
	_verifier(isfet.combat.pv >= isfet.combat.pv_max * 0.99, "Isfet a récupéré toute sa vie")
	_verifier(_scene._phase == 0 and not _scene.find_child("SableQuiMonte", true, false).visible, "la chambre se vide de son sable")
	combat_joueur.reanimer(100.0)
	await _placer(Vector3(0, 18.5, 72.0), PI)
	isfet.engager(combat_joueur)
	await _attendre(20)
	isfet.combat.pv = isfet.combat.pv_max * 0.3
	await _attendre(10)
	_verifier(_scene._phase == 3, "on recommence et on revient au sablier")
	await _tuer_tous("isfet")
	await _attendre(20)
	_verifier(_id_etape() == "fermer_isfet", "Isfet est vaincu (%s)" % _id_etape())
	_verifier(_scene._phase == 0, "le combat est fini")
	await _attendre(260)
	_verifier(not _scene.find_child("VeraBalcon", true, false).visible, "Vera s'est enfuie")
	await _utiliser("FractureMajeure", 420)
	_verifier(_id_etape() == "journal_merer", "la fracture majeure est refermée (%s)" % _id_etape())
	var inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("plume_maat") >= 1, "la Plume de Maât est dans le sac")
	# On ressort par le vestibule.
	await _placer(Vector3(0, 0.5, -108), 0.0)
	await _marcher(0.0, 60)
	await _attendre(80)
	_verifier(_quete.zone_demandee == "village_batisseurs", "le passage ramène au chantier (%s)" % _quete.zone_demandee)

	# --- Au chantier : la pyramide est finie, Merer écrit la dernière page.
	await _charger(VILLAGE)
	await _attendre(10)
	var pyramide = _scene.find_child("GrandePyramide", true, false)
	_verifier(pyramide != null and pyramide.get_child_count() <= 3, "la Grande Pyramide est entièrement revêtue de blanc")
	_verifier(_scene.find_child("MererGizeh", true, false).visible, "Merer attend devant le passage")
	lues = await _parler("MererGizeh")
	_verifier(lues >= 5, "Merer lit la dernière ligne de son journal (%d bulles)" % lues)
	_verifier(_quete.etape < 0, "la quête de l'Égypte est terminée")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
