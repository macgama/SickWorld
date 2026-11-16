extends SceneTree
## Test automatique du chapitre 8 (Grèce) : « Que le temps n'efface pas », le donjon de
## l'Acropole. L'escalier secret, les hoplites de marbre de la grotte, les serpents du
## plateau, Phidias, les portes du Parthénon, puis Méduse : son regard pétrifie ceux qui
## lui font face (pas ceux qui lui tournent le dos), l'égide (phase 2) qu'un bouclier poli
## fait tomber, Masque qui la protège (phase 3), la fracture et Hérodote.
## Lancement : godot --headless --path game -s res://tests/test_acropole.gd

const FICHIER := "user://test_grece_acropole.cfg"
const ACROPOLE := "res://scenes/monde/grece/acropole.tscn"

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


func _aller_pres(cible: Node3D) -> void:
	var p: Vector3 = cible.global_position + Vector3(0, 0, 1.6)
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


func _tuer_tous(type: String, etape: String) -> void:
	var combat_joueur = _joueur.get_node("Combat")
	for passe in 4:
		for bete in _vivants(type):
			# Seulement ceux du combat en cours (pas ceux des camps, ailleurs dans la zone).
			if bete.global_position.distance_to(_joueur.global_position) > 30.0:
				continue
			bete.combat.subir(99999.0, combat_joueur)
			await _attendre(3)
			if _id_etape() != etape:
				return
		await _attendre(20)


## Se placer à côté d'un objet, décalé en x (pour choisir une tablette parmi trois).
func _aller_cote(cible: Node3D, dx: float, dz := 0.0) -> void:
	var p: Vector3 = cible.global_position + Vector3(dx, 0, dz)
	p.y = maxf(_scene.hauteur(p.x, p.z), cible.global_position.y) + 0.3
	await _placer(p, 0.0)


func _repondre(id_noeud: String, dx: float, dz := 0.0) -> int:
	var o = _scene.find_child(id_noeud, true, false)
	if o == null:
		print("  (objet introuvable : %s)" % id_noeud)
		return 0
	await _aller_cote(o, dx, dz)
	await _appuyer_f()
	await _attendre(5)
	return await _lire_dialogue()


func _sauver(etape: String, reponse_vera := "") -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	var cfg := ConfigFile.new()
	cfg.set_value("grece", "etape", etape)
	if reponse_vera != "":
		cfg.set_value("egypte", "choix_reponse_vera", reponse_vera)
	cfg.save(FICHIER)


func _sol(x: float, z: float) -> Vector3:
	return Vector3(x, _scene.hauteur(x, z) + 0.4, z)


func _objet(id_noeud: String, duree_images := 60) -> void:
	var o = _scene.find_child(id_noeud, true, false)
	if o == null:
		print("  (objet introuvable : %s)" % id_noeud)
		return
	await _aller_cote(o, 0.0, 1.2)
	var avant := _id_etape()
	# Un butin tombé tout près se ramasse d'abord : on réappuie si rien n'a commencé.
	for essai in 3:
		await _appuyer_f()
		await _attendre(5)
		if _quete._canalisation != null or _id_etape() != avant or _dialogue.est_ouvert():
			break
	await _attendre(duree_images)
	await _lire_dialogue()


func _proches(type: String, centre: Vector2, rayon: float) -> Array:
	var liste := []
	for b in _vivants(type):
		if Vector2(b.global_position.x, b.global_position.z).distance_to(centre) < rayon:
			liste.append(b)
	return liste


func _regard(angle: float) -> bool:
	var combat_joueur = _joueur.get_node("Combat")
	combat_joueur.retirer_effet("regard_gorgone")
	await _placer(_sol(0, 52), angle)
	_scene._regard_a = 0.0
	_scene._fenetre_fin = 0.0
	_scene._prochain_regard = 0.0
	for i in 260:
		await physics_frame
		_joueur.rotation.y = angle
		if combat_joueur.a_effet("regard_gorgone"):
			return true
	return false


func _lancer() -> void:
	_sauver("entrer_acropole")
	await _charger(ACROPOLE)
	print("Test du donjon de l'Acropole (Grèce, chapitre 8)")
	_verifier(_id_etape() == "statues", "on arrive par l'escalier secret (%s)" % _id_etape())
	await _placer(_sol(0, -58), 0.0)
	await _attendre(40)
	var statues := _vivants("statue_fracturee")
	_verifier(statues.size() == 4, "quatre hoplites de marbre dans la grotte (%d)" % statues.size())
	if not statues.is_empty():
		var app = statues[0].get_node("Apparence").get("_delegue")
		_verifier(app != null and app.get("variante") == "statue", "ils ont l'air de statues")
	await _tuer_tous("statue_fracturee", "statues")
	await _attendre(10)
	_verifier(_id_etape() == "plateau", "les statues sont brisées (%s)" % _id_etape())
	await _placer(_sol(0, -10), PI)
	await _attendre(30)
	_verifier(_id_etape() == "serpents_plateau", "on sort sur le plateau (%s)" % _id_etape())
	await _placer(_sol(0, 4), PI)
	await _attendre(40)
	_verifier(_vivants("serpent_gorgone").size() == 6, "six serpents de bronze sur le chantier (%d)" % _vivants("serpent_gorgone").size())
	await _tuer_tous("serpent_gorgone", "serpents_plateau")
	await _attendre(10)
	_verifier(_id_etape() == "phidias", "le chantier est libéré (%s)" % _id_etape())
	var lues := await _parler("PhidiasAcropole")
	_verifier(lues >= 4 and _id_etape() == "porte", "Phidias explique les boucliers polis (%s)" % _id_etape())
	var portes: Node3D = _scene.find_child("PortesParthenon", true, false)
	_verifier(portes != null and portes.visible, "les portes de bronze sont fermées")
	await _objet("PorteParthenon", 300)
	_verifier(_id_etape() == "meduse", "on pousse les portes (%s)" % _id_etape())
	_verifier(portes != null and not portes.visible, "les portes sont ouvertes")

	# --- Méduse
	await _placer(_sol(0, 52), PI)
	await _attendre(60)
	var boss = _scene._trouver_boss()
	_verifier(boss != null, "Méduse sort du bouclier d'Athéna")
	if boss == null:
		_finir()
		return
	var app_boss = boss.get_node("Apparence").get("_delegue")
	_verifier(app_boss != null and app_boss.get("variante") == "gorgone", "elle a l'air d'une Gorgone")
	if int(boss.etat) != 1:
		boss.engager(_joueur.get_node("Combat"))
	await _attendre(30)
	_verifier(_scene._phase == 1, "le combat commence (phase %d)" % _scene._phase)
	_verifier(await _regard(PI), "son regard pétrifie qui lui fait face")
	_verifier(not await _regard(0.0), "dos tourné, on n'est pas pétrifié")
	_joueur.get_node("Combat").retirer_effet("regard_gorgone")
	# Phase 2 : l'égide.
	boss.combat.pv = boss.combat.pv_max * 0.6
	await _attendre(20)
	_verifier(_scene._phase == 2 and boss.combat.a_effet("evite"), "phase 2 : l'égide la protège")
	_scene._regard_a = 0.0
	_scene._prochain_regard = 1e12
	var bouclier = _scene.find_child("BouclierPoli0", true, false)
	_verifier(bouclier != null and bouclier.actif, "les boucliers polis servent en phase 2")
	await _aller_cote(bouclier, 0.0, 1.0)
	await _appuyer_f()
	await _attendre(5)
	_verifier(not boss.combat.a_effet("evite") and boss.combat.a_effet("regard_renvoye"), "le bouclier poli lui renvoie son regard")
	# Phase 3 : Masque.
	await _placer(_sol(0, 52), PI)
	boss.combat.pv = boss.combat.pv_max * 0.3
	await _attendre(40)
	var masque = _scene._trouver_masque()
	_verifier(_scene._phase == 3 and masque != null, "phase 3 : Masque surgit de la faille")
	_verifier(boss.combat.a_effet("evite"), "tant que Masque est là, elle est protégée")
	if masque != null:
		masque.combat.pv = masque.combat.pv_max * 0.2
	await _attendre(20)
	_verifier(_scene._trouver_masque() == null, "blessé, Masque s'enfuit")
	await _attendre(5)
	_verifier(not boss.combat.a_effet("evite"), "Méduse n'est plus protégée")
	boss.combat.subir(99999.0, _joueur.get_node("Combat"))
	await _attendre(30)
	_verifier(_id_etape() == "fermer_fracture", "Méduse est vaincue (%s)" % _id_etape())
	await _objet("FractureMeduse", 420)
	_verifier(_id_etape() == "herodote", "la fracture majeure est refermée (%s)" % _id_etape())
	var herodote: Node3D = _scene.find_child("HerodoteAcropole", true, false)
	_verifier(herodote != null and herodote.visible, "Hérodote est entré dans le temple")
	lues = await _parler("HerodoteAcropole")
	await _attendre(10)
	_verifier(lues >= 4 and _quete.etape < 0, "fin du chapitre 8 : la Grèce est sauvée")

	# --- Reprise en cours de chapitre, et sortie par l'escalier.
	_sauver("meduse")
	await _charger(ACROPOLE)
	print("Reprise devant Méduse")
	portes = _scene.find_child("PortesParthenon", true, false)
	_verifier(portes != null and not portes.visible, "les portes restent ouvertes après une reprise")
	await _placer(_sol(0, -92), 0.0)
	_joueur.teleporter(_sol(0, -95.6), 0.0)
	await _attendre(120)
	_verifier(_quete.zone_demandee == "athenes", "redescendre l'escalier ramène à Athènes (%s)" % _quete.zone_demandee)
	_finir()


func _finir() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
