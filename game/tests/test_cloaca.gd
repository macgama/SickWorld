extends SceneTree
## Test automatique du chapitre 8 de Rome : le donjon du Colisée. La Cloaca Maxima (vipères,
## prétoriens, les trois vannes, la grille, le rétiaire), puis l'arène : le Colosse en trois
## phases (faisceaux et rayons qui tombent, les deux visages, l'arène qui se remplit et Janus),
## Masque, la fracture, Janus arrêtée, la citoyenneté, le poème de Martial, et le portail.
## Lancement : godot --headless --path game -s res://tests/test_cloaca.gd

const FICHIER := "user://test_rome_cloaca.cfg"
var SCENE := "res://scenes/monde/rome/cloaca.tscn"

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


func _lancer() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	var cfg := ConfigFile.new()
	cfg.set_value("rome", "etape", "entrer_cloaca")
	cfg.save(FICHIER)
	await _charger()
	print("Test du chapitre 8 de Rome (Cloaca Maxima et Colosse)")

	# --- La Cloaca Maxima.
	_verifier(_joueur != null and _joueur.is_on_floor(), "on arrive au pied de l'escalier de l'égout")
	_verifier(_id_etape() == "viperes_egout", "l'arrivée termine l'étape du Forum (%s)" % _id_etape())
	_verifier(_scene.is_in_group("donjon"), "c'est un donjon (pas de monture)")
	# On descend l'escalier à pied.
	var y0: float = _joueur.global_position.y
	Input.action_press("avancer")
	await _attendre(200)
	Input.action_release("avancer")
	await _attendre(10)
	_verifier(_joueur.global_position.y < y0 - 5.0, "on descend l'escalier à pied (%.1f → %.1f)" % [y0, _joueur.global_position.y])
	await _attendre(5)
	_verifier(_vivants("vipere_egout").size() == 6, "six vipères dans le canal (%d)" % _vivants("vipere_egout").size())
	_tuer("vipere_egout")
	await _attendre(130)
	_verifier(_id_etape() == "pretoriens_citerne", "les vipères sont mortes (%s)" % _id_etape())
	await _attendre(5)
	_verifier(_tuer("pretorien_cloaca") == 4, "quatre prétoriens gardent la citerne")
	await _attendre(130)
	_verifier(_id_etape() == "vannes", "la citerne est libre (%s)" % _id_etape())
	var grille: Node3D = _scene.find_child("GrilleCanal", true, false)
	_verifier(grille != null and grille.visible, "la grille ferme le canal")
	for i in 3:
		await _utiliser("Vanne%d" % i, 230)
	_verifier(_id_etape() == "retiaire_canal", "les trois vannes sont fermées (%s)" % _id_etape())
	var vanne: Node3D = _scene.find_child("Vanne0", true, false)
	_verifier(vanne != null and vanne.get_node("Fermee").visible, "la vanne fermée reste en place")
	_verifier(not grille.visible and not _scene.find_child("EauCanal", true, false).visible, "le canal est vide et la grille levée")
	# On passe là où était la grille.
	await _sol(0, 14, PI)
	Input.action_press("avancer")
	await _attendre(90)
	Input.action_release("avancer")
	_verifier(_joueur.global_position.z > 20.0, "on franchit l'emplacement de la grille (z = %.1f)" % _joueur.global_position.z)
	await _attendre(5)
	var retiaire := _vivants("gladiateur_retiaire_fracture")
	_verifier(retiaire.size() == 1, "un rétiaire barre le canal")
	if retiaire.size() > 0:
		_verifier(retiaire[0].get_node("Apparence").get("_delegue").get("style") == "retiaire", "il a le filet et le trident")
	_tuer("gladiateur_retiaire_fracture")
	await _attendre(130)
	_verifier(_id_etape() == "vers_arene", "le chemin de l'arène est ouvert (%s)" % _id_etape())
	await _sol(0, 56, PI)
	Input.action_press("avancer")
	await _attendre(150)
	Input.action_release("avancer")
	print("  (position au bout du canal : %.1f, %.1f, %.1f)" % [_joueur.global_position.x, _joueur.global_position.y, _joueur.global_position.z])
	await _attendre(60)
	_verifier(_quete.zone_demandee == "colisee", "la herse mène à l'arène (%s)" % _quete.zone_demandee)

	# --- L'arène.
	_scene.queue_free()
	await _attendre(5)
	SCENE = "res://scenes/monde/rome/colisee.tscn"
	root.get_node("Reseau").set_meta("arrivee_rome", "cloaca")
	await _charger()
	var p: Vector3 = _joueur.global_position
	_verifier(Vector2(p.x, p.z).distance_to(_scene.HERSE_OUEST) < 4.0, "on sort par la herse de l'ouest (%.0f, %.0f)" % [p.x, p.z])
	_verifier(_id_etape() == "colosse", "le Colosse attend (%s)" % _id_etape())
	var statue: Node3D = _scene.find_child("ColosseArene", true, false)
	_verifier(statue != null and statue.visible, "le Colosse se dresse sur la terrasse de l'est")
	_verifier(not _scene.find_child("Priscus", true, false).visible, "Priscus et Verus sont partis, libres")
	await _sol(22, 0, -PI * 0.5)
	await _attendre(40)
	var boss = _scene._trouver_boss()
	_verifier(boss != null, "le cœur du Colosse brille dans le sable")
	if boss == null:
		_finir()
		return
	_verifier(boss.get_node("Apparence").get("espece") == "colosse", "un grand cristal violet")
	if int(boss.etat) != 1:
		boss.engager(_joueur.get_node("Combat"))
	await _attendre(30)
	_verifier(_scene._phase == 1, "phase 1 : la couronne du Soleil (%d)" % _scene._phase)
	# Un faisceau : on reste dessus, on est touché ; un rayon tombe.
	_scene._prochain_faisceau = 0.0
	var combat_j = _joueur.get_node("Combat")
	combat_j.pv = combat_j.pv_max
	await _attendre(20)
	_verifier(_scene.find_child("BandeFaisceau", true, false).visible, "une bande violette annonce le faisceau")
	await _sol(22, _scene._faisceau_z, -PI * 0.5)
	var pv_avant: float = combat_j.pv
	await _attendre(150)
	_verifier(combat_j.pv < pv_avant - combat_j.pv_max * 0.2, "le faisceau brûle qui reste dessus (%.0f → %.0f)" % [pv_avant, combat_j.pv])
	_verifier(_scene._tirs >= 1 and _scene.find_child("RayonTombe0", true, false).visible, "un rayon de la couronne tombe dans l'arène")
	combat_j.pv = combat_j.pv_max
	# Phase 2 : les deux visages.
	boss.combat.pv = boss.combat.pv_max * 0.5
	await _attendre(20)
	_verifier(_scene._phase == 2, "phase 2 : les deux visages (%d)" % _scene._phase)
	_verifier(_scene.find_child("SecondVisage", true, false).visible, "sa tête se fend en deux visages")
	_verifier(_scene.find_child("VisagesSol", true, false).visible, "les deux regards se voient sur le sable")
	var l: float = _scene.lacet_tete() + 0.6
	var devant: Vector2 = Vector2(-sin(l), -cos(l)) * 9.0 + _scene.COEUR
	await _sol(devant.x, devant.y)
	await _attendre(80)
	_verifier(combat_j.a_effet("visage_passe"), "le visage du passé ralentit")
	combat_j.pv = combat_j.pv_max
	# Phase 3 : Janus et l'eau.
	boss.combat.pv = boss.combat.pv_max * 0.25
	await _attendre(30)
	_verifier(_scene._phase == 3, "phase 3 : Janus (%d)" % _scene._phase)
	_verifier(boss.combat.a_effet("evite"), "tant que Janus tient la vanne, le Colosse ne craint rien")
	_verifier(_scene.find_child("JanusArene", true, false).visible, "Janus est sur la terrasse")
	var rampes := 0
	for k in 3:
		rampes += int(_scene.find_child("RayonTombe%d" % k, true, false).visible)
	_verifier(rampes == 3, "trois rayons tombés font des passerelles (%d)" % rampes)
	await _attendre(200)
	_verifier(_scene._eau_niveau > _scene.EAU_BAS + 0.2, "l'arène se remplit (%.1f m)" % _scene._eau_niveau)
	combat_j.pv = combat_j.pv_max
	# On monte vraiment sur un rayon tombé, à pied, jusqu'à la terrasse.
	var a: float = _scene.RAYONS_TOMBES[1]
	var bas: Vector2 = _scene.point_ellipse(a, -11.0)
	var haut: Vector2 = _scene.point_ellipse(a, 2.0)
	await _sol(bas.x, bas.y, _angle_vers(haut - bas))
	Input.action_press("avancer")
	await _attendre(220)
	Input.action_release("avancer")
	await _attendre(10)
	_verifier(_joueur.global_position.y > 3.6, "on monte sur la terrasse par le rayon (y = %.1f)" % _joueur.global_position.y)
	var objet: Node3D = _scene.find_child("ArreterJanusArene", true, false)
	_verifier(objet != null and objet.actif, "on peut saisir Janus")
	await _placer(objet.global_position + Vector3(0, 0.4, 0), 0.0)
	await _appuyer_f()
	await _attendre(20)
	_verifier(_scene._masque_la and _scene.find_child("MasqueArene", true, false).visible, "Masque surgit et retient Janus")
	_verifier(not boss.combat.a_effet("evite"), "le Colosse n'est plus protégé")
	boss.combat.subir(999999.0, combat_j)
	await _attendre(130)
	_verifier(_id_etape() == "fermer_fracture", "le Colosse est vaincu (%s)" % _id_etape())
	_verifier(not _scene.find_child("MasqueArene", true, false).visible, "Masque a disparu dans la faille")
	_verifier(_scene.find_child("JanusArene", true, false).visible, "Janus est restée")
	await _utiliser("FractureColosse", 420)
	_verifier(_id_etape() == "janus_arretee", "la fracture majeure est refermée (%s)" % _id_etape())
	var lues := await _parler("JanusArene")
	_verifier(lues >= 4, "Janus parle (%d bulles)" % lues)
	await _attendre(10)
	_verifier(_id_etape() == "citoyennete", "Titus descend dans l'arène (%s)" % _id_etape())
	lues = await _parler("Titus")
	_verifier(lues >= 4, "Titus fait de toi un citoyen (%d bulles)" % lues)
	await _attendre(10)
	_verifier(_id_etape() == "poeme_martial", "Martial veut lire son poème (%s)" % _id_etape())
	lues = await _parler("MartialLoge")
	_verifier(lues >= 4, "Martial lit son poème (%d bulles)" % lues)
	await _attendre(10)
	_verifier(_id_etape() == "qg_cellule_janus", "Lenoir ouvre un portail (%s)" % _id_etape())
	var portail: Node3D = _scene.find_child("PortailCampagne", true, false)
	_verifier(portail != null and portail.visible, "le portail de campagne est ouvert")
	root.get_node("Reseau").remove_meta("mission_hub_auto")
	_quete.rentrer_au_hub()
	await _attendre(10)
	_verifier(String(root.get_node("Reseau").get_meta("mission_hub_auto", "")) == "cellule_janus", "au QG, la mission de la cellule de Janus se lance")
	_verifier(_quete.etape < 0, "fin du chapitre 8 : Rome est sauvée")
	root.get_node("Reseau").remove_meta("mission_hub_auto")

	# --- Au retour, le Colosse est immobile, la fracture fermée ; la herse ramène aux égouts.
	_scene.queue_free()
	await _attendre(5)
	await _charger()
	_verifier(_scene.find_child("ColosseArene", true, false).visible, "le Colosse reste dans l'amphithéâtre")
	_verifier(_scene._trouver_boss() == null, "son cœur ne revient pas")
	await _sol(-36, 0, PI * 0.5)
	Input.action_press("avancer")
	await _attendre(90)
	Input.action_release("avancer")
	_verifier(_quete.zone_demandee == "cloaca", "la herse de l'ouest ramène aux égouts (%s)" % _quete.zone_demandee)
	_finir()


func _finir() -> void:
	print("")
	if _echecs == 0:
		print("TOUS LES TESTS PASSENT")
	else:
		print("%d ÉCHEC(S)" % _echecs)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	quit(1 if _echecs > 0 else 0)
