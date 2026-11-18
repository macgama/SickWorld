extends SceneTree
## Test automatique du chapitre 8 de Mayence : la fonderie sous la cathédrale. Gutenberg à
## l'atelier, la porte de la crypte, Masque (ou sa craie), les caves et leurs moules fendus, la
## salle des casses et Hans le fondeur (Scellé), le Typographe de plomb en trois phases (pluie de
## caractères, lignes de plomb, encre noire et lanternes, Sceau), la fracture, Sceau arrêtée, son
## registre (les deux branches), puis Mayence : la première page de la Bible et le portail du QG.
## Lancement : godot --headless --path game -s res://tests/test_fonderie.gd

const FICHIER := "user://test_mayence_fonderie.cfg"
var SCENE := "res://scenes/monde/mayence/fonderie.tscn"

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


func _sol(x: float, z: float, angle := 0.0) -> void:
	await _placer(Vector3(x, _scene.hauteur(x, z) + 0.4, z), angle)


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


func _parler(id_noeud: String, decalage := Vector3(0, 0, 1.4)) -> int:
	var pnj = _scene.find_child(id_noeud, true, false)
	if pnj == null:
		print("  (PNJ introuvable : %s)" % id_noeud)
		return 0
	var p: Vector3 = pnj.global_position + decalage
	await _placer(Vector3(p.x, pnj.global_position.y + 0.4, p.z), 0.0)
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


func _tuer(type: String) -> int:
	var liste := _vivants(type)
	for b in liste:
		b.combat.subir(999999.0, _joueur.get_node("Combat"))
	return liste.size()


## Angle de caméra pour regarder dans la direction « d » (le nord est vers -Z).
func _angle_vers(d: Vector2) -> float:
	return atan2(-d.x, -d.y)


func _utiliser(id_noeud: String, attente := 20) -> void:
	var objet: Node3D = _scene.find_child(id_noeud, true, false)
	if objet == null:
		print("  (objet introuvable : %s)" % id_noeud)
		return
	await _placer(objet.global_position + Vector3(0, 0.4, 0) + objet.global_transform.basis.z * 1.2, 0.0)
	await _appuyer_f()
	await _attendre(attente)


func _charger() -> void:
	_scene = load(SCENE).instantiate()
	_quete = _scene.get_node("Quete")
	_quete.fichier_progression = FICHIER
	_quete.voyage_reel = false
	root.add_child(_scene)
	await _attendre(40)
	_joueur = get_first_node_in_group("joueur_local")
	_dialogue = get_first_node_in_group("dialogue")


func _debut(etape: String, choix := "allier_masque") -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("mayence", "etape", etape)
	cfg.set_value("chine", "choix_choix_masque", choix)
	cfg.save(FICHIER)
	await _charger()


func _composer(nom_objet: String, phrase: String) -> void:
	var objet: Node3D = _scene.find_child(nom_objet, true, false)
	await _placer(objet.global_position + Vector3(0, 0.4, 0) + Vector3(-1.2, 0, 0), 0.0)
	await _appuyer_f()
	await _attendre(3)
	var c = _quete.composteur()
	_verifier(c != null and c.est_ouvert(), "%s : la casse s'ouvre (« %s »)" % [nom_objet, c.phrase() if c != null else "?"])
	if c == null:
		return
	_verifier(phrase == "" or c.phrase() == phrase, "la phrase est « %s » (%s)" % [phrase, c.phrase()])
	c.resoudre()
	await _attendre(110)


func _lancer() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Test du chapitre 8 de Mayence (la fonderie sous la cathédrale)")

	# --- À Mayence : Gutenberg, la porte de la crypte.
	SCENE = "res://scenes/monde/mayence/ville.tscn"
	await _debut("gutenberg_fonderie")
	_verifier(_id_etape() == "gutenberg_fonderie", "Gutenberg attend à l'atelier (%s)" % _id_etape())
	var grille: Node3D = _scene.find_child("PorteCrypte", true, false).get_node("Grille")
	_verifier(grille.visible, "la grille de la crypte est fermée")
	var lues := await _parler("Gutenberg")
	_verifier(lues >= 3, "Gutenberg raconte la nuit des lettres (%d bulles)" % lues)
	_verifier(_id_etape() == "vers_fonderie", "il faut descendre (%s)" % _id_etape())
	_verifier(not _scene.find_child("HansFondeur", true, false).visible, "Hans n'est plus à l'atelier")
	await _attendre(30)
	_verifier(not grille.visible, "la grille de la crypte s'est ouverte")
	var d: Vector2 = _scene.DESCENTE_FONDERIE
	await _sol(d.x, d.y + 1.0, 0.0)
	await _attendre(60)
	_verifier(_quete.zone_demandee == "fonderie", "la porte de la crypte mène à la fonderie (%s)" % _quete.zone_demandee)

	# --- La fonderie.
	_scene.queue_free()
	await _attendre(5)
	SCENE = "res://scenes/monde/mayence/fonderie.tscn"
	await _debut("vers_fonderie")
	await _attendre(20)
	_verifier(_joueur != null and _joueur.is_on_floor(), "on arrive en haut de l'escalier de la fonderie")
	_verifier(_scene.is_in_group("donjon"), "c'est un donjon (pas de monture)")
	_verifier(absf(_scene.hauteur(0, -60) - _scene.SOL) < 0.01, "les caves sont dix mètres sous terre")
	_verifier(_scene.hauteur(0, 30) < _scene.SOL - 3.0, "la fonderie est encore plus bas")
	_verifier(_id_etape() == "masque_fonderie", "Masque attend en bas de l'escalier (%s)" % _id_etape())
	_verifier(_scene.find_child("MasqueFonderie", true, false).visible, "on voit Masque")
	lues = await _parler("MasqueFonderie")
	_verifier(lues >= 3, "Masque parle du géant et des moules (%d bulles)" % lues)
	_verifier(_id_etape() == "galerie", "les caves (%s)" % _id_etape())
	# On descend l'escalier à pied.
	await _sol(0, -100, PI)
	var y0: float = _joueur.global_position.y
	Input.action_press("avancer")
	await _attendre(200)
	Input.action_release("avancer")
	_verifier(_joueur.global_position.y < y0 - 5.0, "on descend l'escalier à pied (%.1f → %.1f)" % [y0, _joueur.global_position.y])
	# Les caves : une coulée, puis les quatre moules.
	var combat_j = _joueur.get_node("Combat")
	combat_j.pv = combat_j.pv_max
	await _sol(0, -60, PI)
	_scene._prochaine_coulee = 0.0
	await _attendre(12)
	_verifier(_scene.find_child("CouleeGalerie", true, false).visible, "une bande rouge annonce la coulée")
	var z_coulee: float = _scene._coulee_z
	await _sol(0, z_coulee, PI)
	var pv_avant: float = combat_j.pv
	await _attendre(120)
	_verifier(combat_j.pv < pv_avant - combat_j.pv_max * 0.15, "le plomb brûle qui reste dessous (%.0f → %.0f)" % [pv_avant, combat_j.pv])
	combat_j.pv = combat_j.pv_max
	for k in 4:
		await _utiliser("Gouttiere%d" % k, 10)
	_verifier(_scene._bouchees == 15, "les quatre moules sont bouchés (%d)" % _scene._bouchees)
	var g: Node3D = _scene.find_child("Gouttiere0", true, false)
	_verifier(g.get_node("Eteint").visible and not g.actif, "le moule reste bouché, sous un tas de sable")
	await _attendre(120)
	_verifier(not _scene.find_child("CouleeGalerie", true, false).visible, "plus une goutte ne tombe")
	await _sol(0, -38, PI)
	await _attendre(20)
	_verifier(_id_etape() == "casses", "on arrive à la salle des casses (%s)" % _id_etape())
	await _sol(0, -34, PI)
	await _attendre(10)
	_verifier(_vivants("statue_lettres_plomb_casse").size() == 5, "cinq hommes de lettres gardent les casses (%d)" % _vivants("statue_lettres_plomb_casse").size())
	_tuer("statue_lettres_plomb_casse")
	await _attendre(130)
	_verifier(_id_etape() == "hans_scelle", "la salle des casses est libre (%s)" % _id_etape())
	_verifier(_scene.find_child("HansScelle", true, false).fige, "Hans est Scellé contre une casse")
	await _composer("LibererHans", "une lettre pour chaque main")
	_verifier(_id_etape() == "hans_parle", "Hans est délivré (%s)" % _id_etape())
	_verifier(not _scene.find_child("HansScelle", true, false).fige, "la cire a craqué")
	lues = await _parler("HansScelle", Vector3(-1.4, 0, 0))
	_verifier(lues >= 3, "Hans raconte le géant (%d bulles)" % lues)
	_verifier(_id_etape() == "typographe", "le Typographe (%s)" % _id_etape())
	var inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("moule_hans") >= 1, "le moule à main de Hans est dans le sac")

	# --- Le Typographe de plomb.
	await _sol(0, 20, PI)
	await _attendre(40)
	var boss = _scene._trouver_boss()
	_verifier(boss != null, "le cœur de la fracture brille au pied du Typographe")
	if boss == null:
		_finir()
		return
	_verifier(_scene.find_child("TypographeDePlomb", true, false).visible, "le Typographe se dresse devant le plomb fondu")
	if int(boss.etat) != 1:
		boss.engager(combat_j)
	await _attendre(30)
	_verifier(_scene._phase == 1, "phase 1 : la pluie de caractères (%d)" % _scene._phase)
	combat_j.pv = combat_j.pv_max
	_scene._prochaine_pluie = 0.0
	await _attendre(12)
	_verifier(_scene.find_child("Goutte0", true, false).visible, "un cercle rouge s'allume sous tes pieds")
	pv_avant = combat_j.pv
	await _attendre(120)
	_verifier(combat_j.pv < pv_avant - combat_j.pv_max * 0.15, "les lettres brûlantes blessent qui reste dedans (%.0f → %.0f)" % [pv_avant, combat_j.pv])
	combat_j.pv = combat_j.pv_max
	_scene._prochains_renforts = 0.0
	await _attendre(10)
	_verifier(_vivants("statue_lettres_plomb_renfort").size() >= 1, "des hommes de lettres arrivent (%d)" % _vivants("statue_lettres_plomb_renfort").size())
	_tuer("statue_lettres_plomb_renfort")
	combat_j.pv = combat_j.pv_max
	# Phase 2 : les lignes de plomb.
	boss.combat.pv = boss.combat.pv_max * 0.5
	await _attendre(20)
	_verifier(_scene._phase == 2, "phase 2 : les lignes de plomb (%d)" % _scene._phase)
	var poutres := 0
	for p in _scene._poutres:
		poutres += int(p.visible)
	_verifier(poutres == 2, "deux lignes de plomb barrent la salle (%d)" % poutres)
	var jeu: Array = _scene.POUTRES_A if _scene._jeu_poutres == 1 else _scene.POUTRES_B
	await _sol(6, (jeu[0].x + jeu[0].y) * 0.5, PI)
	_scene._bascule_poutres = root.get_node("Regles").maintenant() + _scene.DUREE_POUTRES - _scene.PREAVIS_POUTRES - 0.1
	pv_avant = combat_j.pv
	await _attendre(150)
	_verifier(combat_j.pv < pv_avant, "les lignes de plomb brûlent (%.0f → %.0f)" % [pv_avant, combat_j.pv])
	combat_j.pv = combat_j.pv_max
	# Phase 3 : l'encre noire.
	boss.combat.pv = boss.combat.pv_max * 0.25
	await _attendre(30)
	_verifier(_scene._phase == 3, "phase 3 : l'encre noire (%d)" % _scene._phase)
	_verifier(_scene.find_child("EncreNoire", true, false).visible, "une brume d'encre couvre la salle")
	await _sol(0, 26, PI)
	await _attendre(90)
	_verifier(combat_j.a_effet("las"), "loin des lanternes, on devient las")
	await _attendre(10)
	_verifier(_vivants("masque_sceau_fonderie").size() == 1, "Sceau descend se battre")
	await _utiliser("Lanterne0", 10)
	_verifier(_scene.vitraux_allumes() == 1, "une lanterne est rallumée (%d)" % _scene.vitraux_allumes())
	var v: Vector2 = _scene.VITRAUX[0]
	await _sol(v.x + 3.0, v.y, PI)
	await _attendre(150)
	_verifier(not combat_j.a_effet("las"), "dans la lumière de la lanterne, l'encre ne prend pas")
	_tuer("masque_sceau_fonderie")
	boss.combat.subir(999999.0, combat_j)
	await _attendre(130)
	_verifier(_id_etape() == "fermer_fracture", "le Typographe est vaincu (%s)" % _id_etape())
	_verifier(not _scene.find_child("TypographeDePlomb", true, false).visible and _scene.find_child("Cendres", true, false).visible, "il s'effondre en un tas de lettres")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("poincon_originel") >= 1, "le poinçon originel (le trophée)")
	await _utiliser("FractureTypographe", 420)
	_verifier(_id_etape() == "sceau_arretee", "la fracture majeure est refermée (%s)" % _id_etape())
	_verifier(_scene.find_child("SceauArretee", true, false).visible, "Sceau est assise sur un lingot")
	lues = await _parler("SceauArretee")
	_verifier(lues >= 4, "Sceau se rend et raconte sa bibliothèque (%d bulles)" % lues)
	_verifier(_id_etape() == "registre_masque", "Masque tient le registre (%s)" % _id_etape())
	lues = await _parler("MasqueFonderieFin")
	_verifier(lues >= 3, "Masque donne le registre (%d bulles)" % lues)
	_verifier(_id_etape() == "retour_ville", "il faut remonter (%s)" % _id_etape())
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("registre_sceau") >= 1, "le registre de Sceau est dans le sac")

	# --- Une nouvelle copie du donjon : le Typographe reste à terre pour qui l'a vaincu.
	_scene.queue_free()
	await _attendre(5)
	await _charger()
	await _attendre(20)
	_verifier(not _scene.find_child("TypographeDePlomb", true, false).visible, "au retour, le Typographe est toujours à terre")
	_verifier(_scene._trouver_boss() == null, "son cœur ne revient pas")
	await _sol(0, -101.4, 0.0)
	await _attendre(90)
	_verifier(_quete.zone_demandee == "ville", "l'escalier remonte à Mayence (%s)" % _quete.zone_demandee)

	# --- L'autre branche : on se méfiait de Masque en Chine.
	_scene.queue_free()
	await _attendre(5)
	await _debut("sceau_arretee", "mefier_masque")
	await _parler("SceauArretee")
	_verifier(_id_etape() == "registre_vigie", "si on se méfiait de Masque, on ramasse le registre soi-même (%s)" % _id_etape())
	await _utiliser("RegistreSceau", 80)
	_verifier(_id_etape() == "retour_ville", "le registre est dans ta veste (%s)" % _id_etape())
	_scene.queue_free()
	await _attendre(5)
	await _debut("vers_fonderie", "mefier_masque")
	await _attendre(10)
	_verifier(_id_etape() == "craie_fonderie", "sans Masque, il a laissé un message à la craie (%s)" % _id_etape())
	_verifier(not _scene.find_child("MasqueFonderie", true, false).visible, "Masque n'est pas là")

	# --- Mayence : la première page, le portail.
	_scene.queue_free()
	await _attendre(5)
	SCENE = "res://scenes/monde/mayence/ville.tscn"
	root.get_node("Reseau").set_meta("arrivee_mayence", "fonderie")
	await _debut("retour_ville")
	_verifier(Vector2(_joueur.global_position.x, _joueur.global_position.z).distance_to(_scene.DESCENTE_FONDERIE) < 10.0, "on ressort par la porte de la crypte")
	_verifier(_id_etape() == "premiere_page", "la première page attend (%s)" % _id_etape())
	_verifier(_scene.find_child("HansFondeur", true, false).visible, "Hans est revenu à l'atelier")
	_verifier(not _scene.find_child("PortailVigie", true, false).visible, "le portail de la Vigie n'est pas encore ouvert")
	await _utiliser("PresseAtelier", 330)
	_verifier(_id_etape() == "gutenberg_bible", "la presse a tiré la première page (%s)" % _id_etape())
	lues = await _parler("Gutenberg")
	_verifier(lues >= 3, "Gutenberg donne la première page (%d bulles)" % lues)
	_verifier(_id_etape() == "qg_cellule_sceau", "le portail du QG attend (%s)" % _id_etape())
	_verifier(_scene.find_child("PortailVigie", true, false).visible, "le portail s'est ouvert dans la cour Humbrecht")
	inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("premiere_page_bible") >= 1, "la première page de la Bible est dans le sac")
	root.get_node("Reseau").remove_meta("mission_hub_auto")
	_quete.rentrer_au_hub()
	await _attendre(10)
	_verifier(String(root.get_node("Reseau").get_meta("mission_hub_auto", "")) == "cellule_sceau", "au QG, la mission de la cellule de Sceau se lance")
	_verifier(_quete.etape < 0, "fin du chapitre 8 : Mayence est sauvée")
	root.get_node("Reseau").remove_meta("mission_hub_auto")
	_finir()


func _finir() -> void:
	print("")
	if _echecs == 0:
		print("TOUS LES TESTS PASSENT")
	else:
		print("%d ÉCHEC(S)" % _echecs)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	quit(1 if _echecs > 0 else 0)
