extends SceneTree
## Test automatique du chapitre 8 du Moyen Âge : la crypte de Fulbert. La descente depuis le
## chantier, Masque (ou sa craie), la galerie et ses fissures de plomb, la salle du puits et
## l'inscription « É.M. 2006 », le Brasier de plomb en trois phases (pluie de plomb, poutres,
## fumée grise et vitraux, Plomb), la fracture, Plomb arrêtée, la page du carnet (les deux
## branches), le message de Marchal, puis le chantier : le verre bleu d'Aude et le portail du QG.
## Lancement : godot --headless --path game -s res://tests/test_crypte.gd

const FICHIER := "user://test_moyen_age_crypte.cfg"
var SCENE := "res://scenes/monde/moyen_age/crypte.tscn"

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
	cfg.set_value("moyen_age", "etape", etape)
	cfg.set_value("chine", "choix_choix_masque", choix)
	cfg.save(FICHIER)
	await _charger()


func _lancer() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Test du chapitre 8 du Moyen Âge (la crypte de Fulbert)")

	# --- Au chantier : l'escalier de la crypte.
	SCENE = "res://scenes/monde/moyen_age/chantier.tscn"
	await _debut("vers_crypte")
	_verifier(_id_etape() == "vers_crypte", "il faut descendre (%s)" % _id_etape())
	var d: Vector2 = _scene.DESCENTE_CRYPTE
	await _sol(d.x, d.y + 0.5, 0.0)
	await _attendre(60)
	_verifier(_quete.zone_demandee == "crypte", "l'escalier du transept mène à la crypte (%s)" % _quete.zone_demandee)

	# --- La crypte.
	_scene.queue_free()
	await _attendre(5)
	SCENE = "res://scenes/monde/moyen_age/crypte.tscn"
	await _debut("vers_crypte")
	await _attendre(20)
	_verifier(_joueur != null and _joueur.is_on_floor(), "on arrive en haut de l'escalier de la crypte")
	_verifier(_scene.is_in_group("donjon"), "c'est un donjon (pas de monture)")
	_verifier(absf(_scene.hauteur(0, -60) - _scene.SOL) < 0.01, "la galerie est dix mètres sous terre")
	_verifier(_scene.hauteur(0, 30) < _scene.SOL - 3.0, "la salle du lac est encore plus bas")
	_verifier(_id_etape() == "masque_crypte", "Masque attend en bas de l'escalier (%s)" % _id_etape())
	_verifier(_scene.find_child("MasqueCrypte", true, false).visible, "on voit Masque")
	var lues := await _parler("MasqueCrypte")
	_verifier(lues >= 4, "Masque parle du carnet et de la galerie (%d bulles)" % lues)
	_verifier(_id_etape() == "galerie", "la galerie (%s)" % _id_etape())
	# On descend l'escalier à pied.
	await _sol(0, -100, PI)
	var y0: float = _joueur.global_position.y
	Input.action_press("avancer")
	await _attendre(200)
	Input.action_release("avancer")
	_verifier(_joueur.global_position.y < y0 - 5.0, "on descend l'escalier à pied (%.1f → %.1f)" % [y0, _joueur.global_position.y])
	# La galerie : une coulée, puis les quatre fissures.
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
	_verifier(_scene._bouchees == 15, "les quatre fissures sont bouchées (%d)" % _scene._bouchees)
	var g: Node3D = _scene.find_child("Gouttiere0", true, false)
	_verifier(g.get_node("Eteint").visible and not g.actif, "la fissure reste bouchée, sous un tas de sable")
	await _attendre(120)
	_verifier(not _scene.find_child("CouleeGalerie", true, false).visible, "plus une goutte ne tombe")
	await _sol(0, -38, PI)
	await _attendre(20)
	_verifier(_id_etape() == "puits", "on arrive à la salle du puits (%s)" % _id_etape())
	await _sol(0, -34, PI)
	await _attendre(10)
	_verifier(_vivants("masque_homme_plomb_crypte").size() == 5, "cinq hommes de Plomb gardent le puits (%d)" % _vivants("masque_homme_plomb_crypte").size())
	_tuer("masque_homme_plomb_crypte")
	await _attendre(130)
	_verifier(_id_etape() == "inscription", "la salle du puits est libre (%s)" % _id_etape())
	await _utiliser("InscriptionEM", 140)
	_verifier(_id_etape() == "brasier", "« É.M. 2006 » (%s)" % _id_etape())
	var inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("badge_marchal") >= 1, "le vieux badge de Marchal est dans le sac")

	# --- Le Brasier de plomb.
	await _sol(0, 20, PI)
	await _attendre(40)
	var boss = _scene._trouver_boss()
	_verifier(boss != null, "le cœur de la fracture brille au pied du Brasier")
	if boss == null:
		_finir()
		return
	_verifier(_scene.find_child("BrasierDePlomb", true, false).visible, "le Brasier se dresse au bord du lac")
	if int(boss.etat) != 1:
		boss.engager(combat_j)
	await _attendre(30)
	_verifier(_scene._phase == 1, "phase 1 : la pluie de plomb (%d)" % _scene._phase)
	# Le Brasier frappe fort : on remet le joueur en pleine forme avant chaque épreuve.
	combat_j.pv = combat_j.pv_max
	_scene._prochaine_pluie = 0.0
	await _attendre(12)
	_verifier(_scene.find_child("Goutte0", true, false).visible, "un cercle rouge s'allume sous tes pieds")
	pv_avant = combat_j.pv
	await _attendre(120)
	_verifier(combat_j.pv < pv_avant - combat_j.pv_max * 0.15, "les gouttes brûlent qui reste dedans (%.0f → %.0f)" % [pv_avant, combat_j.pv])
	combat_j.pv = combat_j.pv_max
	_scene._prochains_renforts = 0.0
	await _attendre(10)
	_verifier(_vivants("masque_homme_plomb_lac").size() >= 1, "des hommes de Plomb descendent (%d)" % _vivants("masque_homme_plomb_lac").size())
	_tuer("masque_homme_plomb_lac")
	combat_j.pv = combat_j.pv_max
	# Phase 2 : les poutres.
	boss.combat.pv = boss.combat.pv_max * 0.5
	await _attendre(20)
	_verifier(_scene._phase == 2, "phase 2 : les poutres (%d)" % _scene._phase)
	var poutres := 0
	for p in _scene._poutres:
		poutres += int(p.visible)
	_verifier(poutres == 2, "deux poutres barrent la salle (%d)" % poutres)
	var jeu: Array = _scene.POUTRES_A if _scene._jeu_poutres == 1 else _scene.POUTRES_B
	await _sol(6, (jeu[0].x + jeu[0].y) * 0.5, PI)
	_scene._bascule_poutres = root.get_node("Regles").maintenant() + _scene.DUREE_POUTRES - _scene.PREAVIS_POUTRES - 0.1
	pv_avant = combat_j.pv
	await _attendre(150)
	_verifier(combat_j.pv < pv_avant, "les poutres en feu brûlent (%.0f → %.0f)" % [pv_avant, combat_j.pv])
	combat_j.pv = combat_j.pv_max
	# Phase 3 : la fumée grise.
	boss.combat.pv = boss.combat.pv_max * 0.25
	await _attendre(30)
	_verifier(_scene._phase == 3, "phase 3 : la fumée grise (%d)" % _scene._phase)
	_verifier(_scene.find_child("FumeeGrise", true, false).visible, "une fumée grise couvre la salle")
	await _sol(0, 26, PI)
	await _attendre(90)
	_verifier(combat_j.a_effet("las"), "loin des vitraux, on devient las")
	await _attendre(10)
	_verifier(_vivants("masque_plomb_crypte").size() == 1, "Plomb descend se battre")
	await _utiliser("Vitrail0", 10)
	_verifier(_scene.vitraux_allumes() == 1, "un vitrail est rallumé (%d)" % _scene.vitraux_allumes())
	var v: Vector2 = _scene.VITRAUX[0]
	await _sol(v.x + 3.0, v.y, PI)
	await _attendre(150)
	_verifier(not combat_j.a_effet("las"), "dans la lumière du vitrail, la fumée ne prend pas")
	_tuer("masque_plomb_crypte")
	boss.combat.subir(999999.0, combat_j)
	await _attendre(130)
	_verifier(_id_etape() == "fermer_fracture", "le Brasier est vaincu (%s)" % _id_etape())
	_verifier(not _scene.find_child("BrasierDePlomb", true, false).visible and _scene.find_child("Cendres", true, false).visible, "il s'éteint en une flaque de plomb")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("coeur_de_plomb") >= 1, "un cœur de plomb (le trophée)")
	await _utiliser("FractureBrasier", 420)
	_verifier(_id_etape() == "plomb_arretee", "la fracture majeure est refermée (%s)" % _id_etape())
	_verifier(_scene.find_child("PlombArretee", true, false).visible, "Plomb est assise contre une colonne")
	lues = await _parler("PlombArretee")
	_verifier(lues >= 4, "Plomb se rend et parle de Marchal (%d bulles)" % lues)
	_verifier(_id_etape() == "page_masque", "Masque tient une page du carnet (%s)" % _id_etape())
	lues = await _parler("MasqueLac")
	_verifier(lues >= 3, "Masque donne la page (%d bulles)" % lues)
	_verifier(_id_etape() == "message_marchal", "un message gravé (%s)" % _id_etape())
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("page_carnet_editeur") >= 1, "la page du carnet est dans le sac")
	await _utiliser("MessageMarchal", 140)
	_verifier(_id_etape() == "retour_chantier", "le message de Marchal est lu (%s)" % _id_etape())

	# --- Une nouvelle copie du donjon : le Brasier reste éteint pour qui l'a vaincu.
	_scene.queue_free()
	await _attendre(5)
	await _charger()
	await _attendre(20)
	_verifier(not _scene.find_child("BrasierDePlomb", true, false).visible, "au retour, le Brasier est toujours éteint")
	_verifier(_scene._trouver_boss() == null, "son cœur ne revient pas")
	await _sol(0, -101.4, 0.0)
	await _attendre(90)
	_verifier(_quete.zone_demandee == "chantier", "l'escalier remonte au chantier (%s)" % _quete.zone_demandee)

	# --- L'autre branche : on se méfiait de Masque en Chine.
	_scene.queue_free()
	await _attendre(5)
	await _debut("plomb_arretee", "mefier_masque")
	await _parler("PlombArretee")
	_verifier(_id_etape() == "page_vigie", "si on se méfiait de Masque, on ramasse la page soi-même (%s)" % _id_etape())
	await _utiliser("PageCarnet", 80)
	_verifier(_id_etape() == "message_marchal", "la page est dans ta veste (%s)" % _id_etape())
	_scene.queue_free()
	await _attendre(5)
	await _debut("vers_crypte", "mefier_masque")
	await _attendre(10)
	_verifier(_id_etape() == "craie_crypte", "sans Masque, il a laissé un message à la craie (%s)" % _id_etape())
	_verifier(not _scene.find_child("MasqueCrypte", true, false).visible, "Masque n'est pas là")

	# --- Le chantier : le verre bleu d'Aude, le portail.
	_scene.queue_free()
	await _attendre(5)
	SCENE = "res://scenes/monde/moyen_age/chantier.tscn"
	root.get_node("Reseau").set_meta("arrivee_moyen_age", "crypte")
	await _debut("retour_chantier")
	_verifier(Vector2(_joueur.global_position.x, _joueur.global_position.z).distance_to(_scene.DESCENTE_CRYPTE) < 10.0, "on ressort en haut de l'escalier de la crypte")
	_verifier(_id_etape() == "aude_vitrail", "Aude attend (%s)" % _id_etape())
	_verifier(not _scene.find_child("PortailVigie", true, false).visible, "le portail de la Vigie n'est pas encore ouvert")
	lues = await _parler("Aude")
	_verifier(lues >= 4, "Aude donne le premier verre bleu (%d bulles)" % lues)
	_verifier(_id_etape() == "qg_cellule_plomb", "le portail du QG attend (%s)" % _id_etape())
	_verifier(_scene.find_child("PortailVigie", true, false).visible, "le portail s'est ouvert dans le chœur")
	inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("premier_vitrail_bleu") >= 1, "le premier verre bleu d'Aude est dans le sac")
	root.get_node("Reseau").remove_meta("mission_hub_auto")
	_quete.rentrer_au_hub()
	await _attendre(10)
	_verifier(String(root.get_node("Reseau").get_meta("mission_hub_auto", "")) == "cellule_plomb", "au QG, la mission de la cellule de Plomb se lance")
	_verifier(_quete.etape < 0, "fin du chapitre 8 : le Moyen Âge est sauvé")
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
