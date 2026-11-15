extends SceneTree
## Test automatique des quêtes secondaires de l'Égypte (data/egypte_secondaires.json) :
## les « ! » au-dessus des donneurs, chaque objet accessible (pas dans un mur), puis les
## sept quêtes jouées de bout en bout dans leurs zones : « Le pain et la bière » (Méret),
## « Miou » (Nebi), « Le senet d'Ouni », « La marque de l'équipe » (le haleur), « Le
## remède de Pésèshet » (natron au Désert Rouge), « La crue qui monte trop » (Hori) et
## « Les intrus modernes » (Farouk, sur trois zones). Enfin, la sauvegarde.
## Lancement : godot --headless --path game -s res://tests/test_egypte_secondaires.gd

const FICHIER := "user://test_egypte_secondaires.cfg"
const SCENES := "res://scenes/monde/egypte/%s.tscn"

var _echecs := 0
var _scene: Node
var _joueur
var _quete
var _sec
var _dialogue
## Les sacs du profil avant le test (vidés pendant le test, rendus à la fin).
var _sacs_avant := {}


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
	while not _joueur.is_on_floor() and images < 60:
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
	var p: Vector3 = cible.global_position + Vector3(0, 0, 1.4)
	p.y = maxf(_scene.hauteur(p.x, p.z), cible.global_position.y) + 0.3
	await _placer(p, 0.0)


func _parler(id_pnj: String) -> int:
	var pnj := _quete._trouver_pnj(id_pnj) as Node3D
	if pnj == null:
		_verifier(false, "%s est dans la zone" % id_pnj)
		return 0
	_tuer_proches(pnj.global_position, 30.0)
	await _aller_pres(pnj)
	await _attendre(20)
	await _appuyer_f()
	return await _lire_dialogue()


func _utiliser(id: String) -> void:
	var objet := _objet(id)
	if objet == null:
		_verifier(false, "l'objet %s existe" % id)
		return
	await _aller_pres(objet)
	# Les bêtes du coin interrompraient l'action.
	_tuer_proches(objet.global_position, 30.0)
	await _appuyer_f()
	await _attendre(int(_duree_etape_pour(id) * 60) + 30)


func _duree_etape_pour(id: String) -> float:
	var objet := _objet(id)
	for q in _sec.quetes:
		var e: Dictionary = _sec.etape_de(q)
		if e.get("objet", "") == id or (e.has("recolter") and e.recolter == objet.groupe):
			return float(e.get("duree", 0.0))
	return 0.0


func _objet(id: String) -> Node3D:
	return _sec._objets.get(id)


func _tuer_proches(centre: Vector3, rayon: float, prefixe := "") -> int:
	var n := 0
	var combat_joueur = _joueur.get_node("Combat")
	for bete in get_nodes_in_group("loups"):
		if String(bete.type_ennemi).begins_with(prefixe) and bete.combat.est_vivant() \
				and bete.global_position.distance_to(centre) < rayon:
			bete.combat.subir(99999.0, combat_joueur)
			n += 1
	return n


func _charger(zone: String) -> void:
	if _scene != null and is_instance_valid(_scene):
		_scene.queue_free()
		await _attendre(5)
	_scene = load(SCENES % zone).instantiate()
	_quete = _scene.get_node("Quete")
	_quete.fichier_progression = FICHIER
	_quete.voyage_reel = false
	root.add_child(_scene)
	await _attendre(40)
	_joueur = get_first_node_in_group("joueur_local")
	_joueur.get_node("Combat").pv_max = 1e6
	_joueur.get_node("Combat").pv = 1e6
	_dialogue = get_first_node_in_group("dialogue")
	_sec = get_first_node_in_group("quetes_secondaires")


func _a_recu(id: String) -> bool:
	var inventaire = _joueur.get_node_or_null("Inventaire")
	return inventaire != null and JSON.stringify(inventaire.etat).contains('"%s"' % id)


func _marque(id_pnj: String) -> String:
	var pnj := _quete._trouver_pnj(id_pnj) as Node3D
	var m = pnj.get_node_or_null("MarqueQueteSecondaire") if pnj != null else null
	return String(m.text) if m != null else ""


## Aucun objet de la zone n'est enfoncé dans un mur, une maison ou une barrière.
func _verifier_acces() -> void:
	var espace := (_scene as Node3D).get_world_3d().direct_space_state
	var bloques: PackedStringArray = []
	for id in _sec._objets:
		var o: Node3D = _sec._objets[id]
		var q := PhysicsShapeQueryParameters3D.new()
		var s := SphereShape3D.new()
		s.radius = 0.45
		q.shape = s
		q.transform = Transform3D(Basis(), o.global_position + Vector3(0, 1.0, 0))
		if not espace.intersect_shape(q, 1).is_empty():
			bloques.append(id)
	_verifier(bloques.is_empty(), "les %d objets de %s sont accessibles %s" % [_sec._objets.size(), _sec._zone(), bloques])


func _etat(id: String) -> int:
	return _sec.etat_quete(id)


func _lancer() -> void:
	print("Test des quêtes secondaires (Égypte)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	var cfg := ConfigFile.new()
	# Chapitre 8 en cours : tout le village est ouvert, le Désert Rouge aussi.
	cfg.set_value("egypte", "etape", "ankhkhaf_rampe")
	cfg.save(FICHIER)
	await _charger("village_batisseurs")
	# Des sacs vides, pour que les récompenses trouvent toujours de la place.
	var inventaire = _joueur.get_node("Inventaire")
	_sacs_avant = inventaire.etat.duplicate(true)
	for i in (inventaire.etat["cases"] as Array).size():
		inventaire.etat["cases"][i] = {}
	inventaire._sauvegarder()
	_verifier(_sec != null, "les quêtes secondaires de l'Égypte sont chargées")
	if _sec == null:
		quit(1)
		return
	_verifier(_sec.quetes.size() >= 7, "au moins sept quêtes secondaires (%d)" % _sec.quetes.size())
	_verifier(_sec._script_objet().resource_path.ends_with("objet_egypte.gd"), "les objets utilisent le script de l'Égypte")
	await _attendre(40)
	for id_pnj in ["meret", "nebi", "pesechet", "ouni", "haleur_1"]:
		_verifier(_marque(id_pnj) == "!", "un « ! » doré au-dessus de %s" % id_pnj)
	_verifier_acces()

	# --- Le pain et la bière (Méret).
	_verifier(await _parler("meret") >= 3, "Méret explique qu'il manque de l'orge")
	_verifier(_etat("pain_et_biere") == 0, "« Le pain et la bière » commence")
	_verifier(_sec._cadre.visible, "la quête apparaît dans la liste à l'écran")
	_verifier(_objet("orge_0").actif, "les gerbes d'orge brillent dans les champs")
	for k in 4:
		await _utiliser("orge_%d" % k)
	_verifier(_etat("pain_et_biere") == 1, "quatre gerbes coupées : retour à Méret")
	await _parler("meret")
	_verifier(_etat("pain_et_biere") == 2, "Méret donne une cruche pour le chantier")
	await _parler("haleur_2")
	_verifier(_etat("pain_et_biere") == 3, "le haleur du plateau reçoit sa bière")
	await _parler("meret")
	_verifier(_etat("pain_et_biere") == _sec.FINIE, "« Le pain et la bière » est terminée")
	_verifier(_a_recu("pagne_shendyt"), "Méret offre le pagne shendyt")

	# --- Miou (Nebi).
	await _parler("nebi")
	_verifier(_etat("miou") == 0, "« Miou » commence")
	await _attendre(30)
	var cobras := 0
	for bete in get_nodes_in_group("loups"):
		if String(bete.type_ennemi) == "cobra_grenier" and bete.combat.est_vivant():
			cobras += 1
	_verifier(cobras >= 3, "des cobras fracturés rôdent derrière la brasserie (%d)" % cobras)
	_tuer_proches(Vector3(-16, 0, 66), 25.0, "cobra")
	await _attendre(20)
	_verifier(_etat("miou") == 1, "les cobras chassés : il faut retrouver Miou")
	await _utiliser("chat_nebi")
	_verifier(_etat("miou") == 2, "Miou est attrapée")
	_verifier(not _objet("chat_nebi")._visuel.visible, "Miou ne reste pas derrière la brasserie")
	await _parler("nebi")
	_verifier(_etat("miou") == _sec.FINIE and _a_recu("amulette_bastet"), "Nebi offre l'amulette de Bastet")

	# --- Le senet d'Ouni.
	await _parler("ouni")
	_verifier(_etat("senet_ouni") == 0, "« Le senet d'Ouni » commence")
	for k in 3:
		await _utiliser("pion_%d" % k)
	_verifier(_etat("senet_ouni") == 1, "les trois pions sont retrouvés")
	await _utiliser("plateau_senet")
	_verifier(_etat("senet_ouni") == 2, "une partie de senet avec Ouni")
	await _parler("ouni")
	_verifier(_etat("senet_ouni") == _sec.FINIE and _a_recu("pion_senet"), "Ouni offre son pion porte-bonheur")

	# --- La marque de l'équipe (le haleur du chantier).
	await _parler("haleur_1")
	_verifier(_etat("marque_equipe") == 0, "« La marque de l'équipe » commence")
	for k in 3:
		await _utiliser("ocre_chantier_%d" % k)
	_verifier(_etat("marque_equipe") == 1, "trois tas d'ocre ramassés")
	await _utiliser("bloc_equipe")
	_verifier(_etat("marque_equipe") == 2, "la marque est peinte")
	_verifier(_objet("bloc_equipe")._visuel.get_node_or_null("Marque") != null, "« Compagnons de Khéops » est écrit sur le bloc")
	await _parler("haleur_1")
	_verifier(_etat("marque_equipe") == _sec.FINIE and _a_recu("tunique_compagnons"), "la tunique des Compagnons est offerte")
	_verifier(_sec.titres.has("Compagnon de Khéops"), "titre obtenu : « Compagnon de Khéops »")

	# --- Le remède de Pésèshet : le natron est au Désert Rouge.
	await _parler("pesechet")
	_verifier(_etat("remede_peseshet") == 0, "« Le remède de Pésèshet » commence")
	await _attendre(40)
	var texte := ""
	for l in _sec._liste.get_children():
		if l is Label:
			texte += l.text + "\n"
	_verifier(texte.contains("Désert Rouge"), "la liste indique que le natron est au Désert Rouge")

	await _charger("desert_rouge")
	_verifier_acces()
	for k in 3:
		await _utiliser("natron_%d" % k)
	_verifier(_etat("remede_peseshet") == 1, "trois croûtes de natron ramassées au Désert Rouge")

	await _charger("village_batisseurs")
	_verifier(_objet("bloc_equipe")._visuel.get_node_or_null("Marque") != null, "la marque peinte est toujours là au retour")
	_verifier(not _objet("orge_0")._visuel.visible, "les gerbes coupées ne repoussent pas")
	for k in 2:
		await _utiliser("ruche_%d" % k)
	_verifier(_etat("remede_peseshet") == 2, "le miel des deux ruches est pris")
	_verifier(_objet("ruche_0")._visuel.visible, "les ruches restent à leur place")
	await _parler("pesechet")
	_verifier(_etat("remede_peseshet") == 3, "Pésèshet prépare les pansements")
	for k in 3:
		await _utiliser("blesse_%d" % k)
	_verifier(_etat("remede_peseshet") == 4, "les trois haleurs blessés sont soignés")
	_verifier(_objet("blesse_0")._visuel.visible, "les haleurs soignés restent allongés sur leur natte")
	await _parler("pesechet")
	_verifier(_etat("remede_peseshet") == _sec.FINIE and _a_recu("sandales_papyrus"), "Pésèshet offre les sandales de papyrus")

	# --- Au Port des Marais : Hori et Farouk.
	await _charger("port_des_marais")
	await _attendre(40)
	_verifier(_marque("batelier_2") == "!", "un « ! » au-dessus de Hori")
	_verifier(_marque("farouk") == "!", "un « ! » au-dessus de l'agent Farouk")
	_verifier_acces()
	await _parler("batelier_2")
	_verifier(_etat("crue_qui_monte") == 0, "« La crue qui monte trop » commence")
	for k in 3:
		await _utiliser("borne_%d" % k)
	_verifier(_etat("crue_qui_monte") == 1, "les trois bornes de crue sont lues")
	await _attendre(30)
	var crocos := _tuer_proches(Vector3(60, 0, -28), 30.0, "crocodile_fracture")
	await _attendre(20)
	_verifier(crocos >= 3 and _etat("crue_qui_monte") == 2, "les crocodiles fracturés sortent de l'eau (%d)" % crocos)
	await _parler("batelier_2")
	_verifier(_etat("crue_qui_monte") == _sec.FINIE and _a_recu("harpon_hori"), "Hori offre son harpon")

	await _parler("farouk")
	_verifier(_etat("intrus_modernes_egypte") == 0, "« Les intrus modernes » commence")
	await _utiliser("lunettes_port")
	_verifier(_etat("intrus_modernes_egypte") == 1, "les lunettes de soleil sont ramassées dans les papyrus")
	await _charger("carrieres_toura")
	_verifier_acces()
	await _utiliser("gobelet_toura")
	_verifier(_etat("intrus_modernes_egypte") == 2, "le gobelet en carton est ramassé à Toura")
	await _charger("village_batisseurs")
	await _utiliser("drone_chantier")
	_verifier(_etat("intrus_modernes_egypte") == 3, "le drone est ramassé sur le chantier")
	await _charger("port_des_marais")
	await _parler("farouk")
	_verifier(_etat("intrus_modernes_egypte") == _sec.FINIE and _a_recu("gants_vigie"), "Farouk offre les gants de la Vigie")

	# --- La sauvegarde.
	var lu := ConfigFile.new()
	lu.load(Profil.chemin(FICHIER))
	_verifier(int(lu.get_value("egypte_secondaires", "etat_miou", -1)) == _sec.FINIE, "les quêtes de l'Égypte sont sauvegardées à part")
	_verifier(not lu.has_section("prehistoire_secondaires"), "rien n'est mélangé avec la Préhistoire")

	# On rend ses sacs au profil.
	var inv = _joueur.get_node("Inventaire")
	inv.etat = _sacs_avant
	inv._sauvegarder()
	_scene.queue_free()
	await _attendre(5)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Résultat : ", "tout est bon" if _echecs == 0 else "%d échec(s)" % _echecs)
	quit(0 if _echecs == 0 else 1)
