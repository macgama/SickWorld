extends SceneTree
## Test automatique du chapitre 8 de la Chine : le tombeau du Premier Empereur. L'entrée au
## mont Li, la galerie des arbalètes et ses mécanismes, la salle des fleuves de mercure,
## l'Empereur d'argile en trois phases (volées, fleuves de mercure, bûchers et Masque), la
## fracture, Cinabre, le carnet de l'Éditeur (les deux branches), puis Luoyang : le titre de
## lettré, la première feuille de Cai Lun et le portail du QG.
## Lancement : godot --headless --path game -s res://tests/test_tombeau.gd

const FICHIER := "user://test_chine_tombeau.cfg"
var SCENE := "res://scenes/monde/chine/tombeau.tscn"

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
	cfg.set_value("chine", "etape", etape)
	cfg.set_value("chine", "choix_choix_masque", choix)
	cfg.save(FICHIER)
	await _charger()


func _lancer() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Test du chapitre 8 de la Chine (le tombeau du Premier Empereur)")

	# --- Au mont Li : Masque garde l'entrée, et on descend.
	SCENE = "res://scenes/monde/chine/mont_li.tscn"
	await _debut("masque_porte_allie")
	_verifier(_id_etape() == "masque_porte_allie", "Masque attend à l'entrée (%s)" % _id_etape())
	var lues := await _parler("MasqueTombeau")
	_verifier(lues >= 3, "Masque parle des arbalètes (%d bulles)" % lues)
	_verifier(_id_etape() == "entrer_tombeau", "il faut descendre (%s)" % _id_etape())
	var e: Vector2 = _scene.ENTREE_TOMBEAU
	await _sol(e.x, e.y + 3.0, 0.0)
	Input.action_press("avancer")
	await _attendre(60)
	Input.action_release("avancer")
	await _attendre(30)
	_verifier(_quete.zone_demandee == "tombeau", "l'entrée creusée mène au tombeau (%s)" % _quete.zone_demandee)

	# --- Le tombeau.
	_scene.queue_free()
	await _attendre(5)
	SCENE = "res://scenes/monde/chine/tombeau.tscn"
	await _debut("entrer_tombeau")
	_verifier(_joueur != null and _joueur.is_on_floor(), "on arrive en haut de la galerie de Cinabre")
	_verifier(_id_etape() == "galerie", "l'arrivée termine l'étape de l'entrée (%s)" % _id_etape())
	_verifier(_scene.is_in_group("donjon"), "c'est un donjon (pas de monture)")
	_verifier(absf(_scene.hauteur(0, -60) - _scene.SOL) < 0.01, "la galerie est dix mètres sous terre")
	_verifier(_scene.hauteur(0, -32.5) == _scene.SOL and _scene.hauteur(-6, -32.5) < _scene.SOL - 0.5, "les fleuves de mercure sont plus bas que les ponts")
	_verifier(_scene.find_child("Etoiles", true, false) != null, "le palais a son plafond d'étoiles")
	# On descend à pied.
	var y0: float = _joueur.global_position.y
	Input.action_press("avancer")
	await _attendre(200)
	Input.action_release("avancer")
	_verifier(_joueur.global_position.y < y0 - 5.0, "on descend la galerie à pied (%.1f → %.1f)" % [y0, _joueur.global_position.y])
	# La galerie des arbalètes : une volée, puis les quatre mécanismes.
	var combat_j = _joueur.get_node("Combat")
	combat_j.pv = combat_j.pv_max
	await _sol(0, -60, PI)
	_scene._prochaine_volee_galerie = 0.0
	await _attendre(12)
	_verifier(_scene.find_child("VoleeGalerie", true, false).visible, "une bande rouge annonce la volée")
	var z_volee: float = _scene._volee_galerie_z
	await _sol(0, z_volee, PI)
	var pv_avant: float = combat_j.pv
	await _attendre(120)
	_verifier(combat_j.pv < pv_avant - combat_j.pv_max * 0.15, "la volée touche qui reste dessus (%.0f → %.0f)" % [pv_avant, combat_j.pv])
	combat_j.pv = combat_j.pv_max
	for k in 4:
		await _utiliser("Mecanisme%d" % k, 10)
	_verifier(_scene._desarmes == 15, "les quatre mécanismes sont bloqués (%d)" % _scene._desarmes)
	var meca: Node3D = _scene.find_child("Mecanisme0", true, false)
	_verifier(meca.get_node("Eteint").visible and not meca.actif, "le mécanisme reste figé, une barre dans la roue")
	await _attendre(120)
	_verifier(not _scene.find_child("VoleeGalerie", true, false).visible, "les arbalètes se taisent")
	# Le mercure fait mal (avant que les soldats ne se montrent).
	combat_j.pv = combat_j.pv_max
	await _placer(Vector3(-8, _scene.SOL - 0.4, -32.5), 0.0)
	await _attendre(150)
	_verifier(combat_j.pv < combat_j.pv_max * 0.97 and combat_j.pv > 0.0, "le mercure ronge qui marche dedans (%.0f)" % combat_j.pv)
	combat_j.pv = combat_j.pv_max
	await _sol(0, -38, PI)
	await _attendre(20)
	_verifier(_id_etape() == "fleuves", "on arrive à la salle des fleuves (%s)" % _id_etape())
	await _sol(0, -27, PI)
	await _attendre(10)
	_verifier(_vivants("soldat_argile_tombeau").size() == 6, "six soldats gardent les ponts (%d)" % _vivants("soldat_argile_tombeau").size())
	_tuer("soldat_argile_tombeau")
	await _attendre(130)
	_verifier(_id_etape() == "empereur", "la salle des fleuves est libre (%s)" % _id_etape())

	# --- L'Empereur d'argile.
	await _sol(0, 30, PI)
	await _attendre(40)
	var boss = _scene._trouver_boss()
	_verifier(boss != null, "le cœur de l'Empereur brille au pied du cercueil")
	if boss == null:
		_finir()
		return
	_verifier(_scene.find_child("EmpereurArgile", true, false).visible, "le géant d'argile est sur son trône")
	if int(boss.etat) != 1:
		boss.engager(combat_j)
	await _attendre(30)
	_verifier(_scene._phase == 1, "phase 1 : les arbalètes (%d)" % _scene._phase)
	_scene._prochaine_volee = 0.0
	await _attendre(12)
	_verifier(_scene.find_child("VoleePalais", true, false).visible, "une bande rouge traverse le palais")
	_scene._prochains_renforts = 0.0
	await _attendre(10)
	_verifier(_vivants("soldat_argile_piedestal").size() >= 1, "des gardes d'argile sortent des piédestaux (%d)" % _vivants("soldat_argile_piedestal").size())
	_tuer("soldat_argile_piedestal")
	combat_j.pv = combat_j.pv_max
	# Phase 2 : les fleuves de mercure.
	boss.combat.pv = boss.combat.pv_max * 0.5
	await _attendre(20)
	_verifier(_scene._phase == 2, "phase 2 : les fleuves de mercure (%d)" % _scene._phase)
	var canaux := 0
	for c in _scene._canaux:
		canaux += int(c.visible)
	_verifier(canaux == 2, "deux canaux de mercure coulent dans le palais (%d)" % canaux)
	var jeu: Array = _scene.MERCURE_A if _scene._jeu_mercure == 1 else _scene.MERCURE_B
	await _sol(6, (jeu[0].x + jeu[0].y) * 0.5, PI)
	_scene._bascule_mercure = root.get_node("Regles").maintenant() + _scene.DUREE_FLEUVE - _scene.PREAVIS_FLEUVE - 0.1
	pv_avant = combat_j.pv
	await _attendre(150)
	_verifier(combat_j.pv < pv_avant, "le mercure du palais brûle (%.0f → %.0f)" % [pv_avant, combat_j.pv])
	combat_j.pv = combat_j.pv_max
	# Phase 3 : le grand autodafé.
	boss.combat.pv = boss.combat.pv_max * 0.25
	await _attendre(30)
	_verifier(_scene._phase == 3, "phase 3 : le grand autodafé (%d)" % _scene._phase)
	_verifier(_scene.buchers_allumes() == 4, "quatre bûchers brûlent (%d)" % _scene.buchers_allumes())
	_verifier(boss.combat.a_effet("evite"), "tant que trois bûchers brûlent, l'Empereur ne craint rien")
	_verifier(_scene.find_child("CinabreSurLaTete", true, false).visible, "Cinabre est sur la tête du géant")
	_verifier(_scene.find_child("MasquePortePalais", true, false).visible, "Masque tient la porte du palais")
	var b0: Vector2 = _scene.BUCHERS[0]
	await _sol(b0.x + 2.0, b0.y, PI)
	await _attendre(80)
	_verifier(combat_j.a_effet("fumee_autodafe"), "la fumée du bûcher bloque les compétences")
	await _utiliser("Bucher0", 10)
	await _utiliser("Bucher1", 10)
	_verifier(_scene.buchers_allumes() == 2, "deux bûchers sont étouffés (%d)" % _scene.buchers_allumes())
	await _attendre(20)
	_verifier(not boss.combat.a_effet("evite"), "l'Empereur n'est plus protégé")
	boss.combat.subir(999999.0, combat_j)
	await _attendre(130)
	_verifier(_id_etape() == "fermer_fracture", "l'Empereur d'argile est vaincu (%s)" % _id_etape())
	_verifier(not _scene.find_child("EmpereurArgile", true, false).visible and _scene.find_child("Gravats", true, false).visible, "le géant tombe en morceaux")
	_verifier(_scene.find_child("CinabreTombeau", true, false).visible, "Cinabre est dans les gravats")
	var inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("perle_coiffe_imperiale") >= 1, "une perle de la coiffe impériale (le trophée)")
	await _utiliser("FractureEmpereur", 420)
	_verifier(_id_etape() == "cinabre_arretee", "la fracture majeure est refermée (%s)" % _id_etape())
	lues = await _parler("CinabreTombeau")
	_verifier(lues >= 4, "Cinabre se rend (%d bulles)" % lues)
	_verifier(_id_etape() == "carnet_masque", "Masque ramasse le carnet (%s)" % _id_etape())
	lues = await _parler("MasqueCarnet")
	_verifier(lues >= 4, "Masque garde le carnet (%d bulles)" % lues)
	_verifier(_id_etape() == "retour_luoyang", "il faut rentrer à Luoyang (%s)" % _id_etape())
	_verifier(not _scene.find_child("MasqueCarnet", true, false).visible, "Masque est reparti")

	# --- Une nouvelle copie du donjon : le géant reste en morceaux pour qui l'a vaincu.
	_scene.queue_free()
	await _attendre(5)
	await _charger()
	await _attendre(20)
	_verifier(not _scene.find_child("EmpereurArgile", true, false).visible, "au retour, le géant est toujours en morceaux")
	_verifier(_scene._trouver_boss() == null, "son cœur ne revient pas")
	await _sol(0, -101.4, 0.0)
	await _attendre(90)
	_verifier(_quete.zone_demandee == "mont_li", "la galerie remonte au mont Li (%s)" % _quete.zone_demandee)

	# --- L'autre branche : on se méfiait de Masque, on garde le carnet.
	_scene.queue_free()
	await _attendre(5)
	await _debut("cinabre_arretee", "mefier_masque")
	lues = await _parler("CinabreTombeau")
	_verifier(_id_etape() == "carnet_vigie", "si on se méfiait de Masque, on ramasse le carnet (%s)" % _id_etape())
	await _utiliser("CarnetEditeur", 80)
	_verifier(_id_etape() == "retour_luoyang", "le carnet est dans ta veste (%s)" % _id_etape())
	inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("carnet_editeur") >= 1, "le carnet de l'Éditeur est dans le sac")

	# --- Luoyang : le titre, la première feuille, le portail.
	_scene.queue_free()
	await _attendre(5)
	SCENE = "res://scenes/monde/chine/luoyang.tscn"
	await _debut("retour_luoyang")
	_verifier(_id_etape() == "imperatrice_titre", "l'impératrice attend (%s)" % _id_etape())
	_verifier(not _scene.find_child("EmpereurHe", true, false).visible, "l'empereur s'est endormi")
	lues = await _parler("ImperatriceDeng")
	_verifier(lues >= 4, "l'impératrice fait de toi un lettré (%d bulles)" % lues)
	lues = await _parler("CaiLun")
	_verifier(lues >= 4, "Cai Lun donne la première feuille (%d bulles)" % lues)
	_verifier(_id_etape() == "qg_cellule_cinabre", "le portail du QG attend (%s)" % _id_etape())
	inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("premiere_feuille") >= 1, "la première feuille de Cai Lun est dans le sac")
	root.get_node("Reseau").remove_meta("mission_hub_auto")
	_quete.rentrer_au_hub()
	await _attendre(10)
	_verifier(String(root.get_node("Reseau").get_meta("mission_hub_auto", "")) == "cellule_cinabre", "au QG, la mission de la cellule de Cinabre se lance")
	_verifier(_quete.etape < 0, "fin du chapitre 8 : la Chine est sauvée")
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
