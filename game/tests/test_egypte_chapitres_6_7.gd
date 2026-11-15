extends SceneTree
## Test automatique des chapitres 6 et 7 de l'Égypte : Ânkhkhaf cherche Hémiounou, Tamit
## et les nomades, les miroirs de cuivre des trois mastabas, les plans cachés, le khamsin,
## l'escorte d'Hémiounou jusqu'à la passe des tombes, puis la pierre de faîte tirée au pied
## de la rampe et les gardes des Effaceurs. Le chapitre 8 attend ensuite au chantier.
## Lancement : godot --headless --path game -s res://tests/test_egypte_chapitres_6_7.gd

const FICHIER := "user://test_egypte_ch67.cfg"
const SCENES := "res://scenes/monde/egypte/%s.tscn"

var _echecs := 0
var _scene: Node
var _joueur
var _quete
var _dialogue
var _sacs_avant := {}
var _progression_avant := {}


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


func _pres_de(cible: Vector3, recul := 1.5) -> void:
	var p := cible + Vector3(recul, 0, 0.4)
	p.y = maxf(_scene.hauteur(p.x, p.z), cible.y) + 0.4
	await _placer(p, PI / 2)


func _parler(id_pnj: String) -> int:
	var pnj := _quete._trouver_pnj(id_pnj) as Node3D
	if pnj == null:
		_verifier(false, "%s est dans la zone" % id_pnj)
		return 0
	_tuer_tous()
	await _pres_de(pnj.global_position)
	await _attendre(20)
	await _appuyer_f()
	return await _lire_dialogue()


func _utiliser(objet: Node3D, duree: float) -> void:
	_tuer_tous()
	await _pres_de(objet.global_position)
	await _appuyer_f()
	await _attendre(int(duree * 60) + 30)


func _tuer_tous() -> int:
	var n := 0
	var combat_joueur = _joueur.get_node("Combat")
	for bete in get_nodes_in_group("loups"):
		if bete.has_meta("unique") and bete.combat.est_vivant():
			bete.combat.subir(99999.0, combat_joueur)
			n += 1
	return n


func _id_etape() -> String:
	return String(_quete.etape_actuelle().get("id", ""))


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


func _a_recu(id: String) -> bool:
	var inventaire = _joueur.get_node_or_null("Inventaire")
	return inventaire != null and JSON.stringify(inventaire.etat).contains('"%s"' % id)


func _libre(p: Vector3) -> bool:
	var espace := (_scene as Node3D).get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.45
	q.shape = s
	q.transform = Transform3D(Basis(), p + Vector3(0, 1.0, 0))
	return espace.intersect_shape(q, 1).is_empty()


## Suit une escorte (le joueur reste tout près de « reference ») jusqu'à la fin de l'étape.
func _suivre(id_etape: String, reference: Callable, max_images: int) -> int:
	var tues := 0
	var images := 0
	while _id_etape() == id_etape and images < max_images:
		var ref: Node3D = reference.call()
		if ref != null:
			var p := ref.global_position + Vector3(1.8, 0, 1.8)
			_joueur.teleporter(Vector3(p.x, _scene.hauteur(p.x, p.z) + 0.4, p.z), 0.0)
		tues += _tuer_tous()
		await _attendre(20)
		images += 20
	return tues


func _lancer() -> void:
	print("Test des chapitres 6 et 7 (Égypte)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	var cfg := ConfigFile.new()
	cfg.set_value("egypte", "etape", "retour_gizeh")
	cfg.save(FICHIER)

	# --- Retour en Égypte : du port au village, Ânkhkhaf cherche Hémiounou.
	await _charger("port_des_marais")
	_verifier(_id_etape() == "retour_gizeh", "après le QG, il faut remonter au village (%s)" % _id_etape())
	var inventaire = _joueur.get_node("Inventaire")
	_sacs_avant = inventaire.etat.duplicate(true)
	for i in (inventaire.etat["cases"] as Array).size():
		inventaire.etat["cases"][i] = {}
	inventaire._sauvegarder()
	# Une progression sans quête notée, pour que le serveur redonne les récompenses
	# (il ne les donne qu'une fois par personnage) ; elle est rendue à la fin.
	var progression = _joueur.get_node("Progression")
	_progression_avant = progression.etat.duplicate(true)
	progression.etat["faits"] = []
	await _charger("village_batisseurs")
	_verifier(_id_etape() == "ankhkhaf_hemiounou", "en arrivant au village, Ânkhkhaf attend (%s)" % _id_etape())
	_verifier(not _scene.find_child("HemiounouChantier", true, false).visible, "Hémiounou n'est pas au chantier")
	_verifier(await _parler("ankhkhaf_chantier") >= 4, "Ânkhkhaf raconte la disparition d'Hémiounou")
	_verifier(_id_etape() == "vers_desert_6", "il faut partir au Désert Rouge (%s)" % _id_etape())

	# --- Au Désert Rouge : Tamit, Hémiounou, les miroirs, les plans.
	await _charger("desert_rouge")
	_verifier(_id_etape() == "parler_tamit", "les nomades d'abord (%s)" % _id_etape())
	var tamit := _quete._trouver_pnj("tamit") as Node3D
	_verifier(tamit != null and _libre(tamit.global_position + Vector3(1.5, 0, 0.4)), "on peut approcher Tamit")
	_verifier(await _parler("tamit") >= 3, "Tamit a vu le vieil homme")
	_verifier(_id_etape() == "hemiounou_tombe", "Hémiounou est devant sa tombe (%s)" % _id_etape())
	_verifier(await _parler("hemiounou") >= 4, "Hémiounou parle des miroirs et de la lumière")
	_verifier(_id_etape() == "miroirs", "il faut tourner les miroirs (%s)" % _id_etape())
	var dossier: Node = _scene._dossier_quete
	var bloques: PackedStringArray = []
	for k in 3:
		for nom in ["Miroir%d" % k, "Plan%d" % k]:
			var o: Node3D = dossier.get_node(nom)
			if not _libre(o.global_position + Vector3(1.5, 0, 0.4)):
				bloques.append(nom)
	_verifier(bloques.is_empty(), "miroirs et rouleaux accessibles %s" % bloques)
	_verifier(not dossier.get_node("Plan0").visible, "les rouleaux sont invisibles dans le noir")
	for k in 3:
		await _utiliser(dossier.get_node("Miroir%d" % k), 2.5)
	_verifier(dossier.get_node("Miroir0")._visuel.get_node_or_null("Rayon") != null, "le miroir renvoie un rayon de soleil dans la niche")
	_verifier(_id_etape() == "plans_hemiounou", "les trois miroirs sont tournés (%s)" % _id_etape())
	_verifier(dossier.get_node("Plan0").visible, "la lumière révèle les rouleaux")
	for k in 3:
		await _utiliser(dossier.get_node("Plan%d" % k), 1.5)
	_verifier(_id_etape() == "rendre_plans", "les trois plans sont pris (%s)" % _id_etape())
	_verifier(bool(_scene.en_tempete), "le khamsin se lève")
	_verifier(_a_recu("plans_hemiounou"), "les plans d'Hémiounou sont dans le sac")
	await _parler("hemiounou")
	_verifier(_id_etape() == "escorte_hemiounou", "Hémiounou se souvient : il faut l'escorter (%s)" % _id_etape())
	Engine.time_scale = 4.0
	var tues := await _suivre("escorte_hemiounou", func(): return _quete._trouver_pnj("hemiounou"), 60 * 60)
	Engine.time_scale = 1.0
	_verifier(_id_etape() == "retour_chantier_6", "Hémiounou est à la passe des tombes (%s, %d chacals)" % [_id_etape(), tues])
	_verifier(tues >= 6, "deux vagues de chacals dans la tempête (%d)" % tues)
	_verifier(not bool(_scene.en_tempete), "le vent tombe")
	_verifier(not _quete._trouver_pnj("hemiounou").visible, "Hémiounou est parti vers le chantier")

	# --- On revient plus tard : les rayons sont toujours là, les rouleaux non.
	await _charger("desert_rouge")
	dossier = _scene._dossier_quete
	_verifier(dossier.get_node("Miroir1")._visuel.get_node_or_null("Rayon") != null, "les miroirs restent tournés")
	_verifier(not dossier.get_node("Plan1")._visuel.visible, "les rouleaux ne sont plus dans les niches")
	_verifier(not _quete._trouver_pnj("hemiounou").visible, "Hémiounou n'est plus dans le désert")

	# --- Au chantier : Hémiounou, puis la pierre de faîte.
	await _charger("village_batisseurs")
	_verifier(_id_etape() == "fin_chapitre_6", "de retour au village (%s)" % _id_etape())
	_verifier(_scene.find_child("HemiounouChantier", true, false).visible, "Hémiounou est au chantier")
	await _parler("hemiounou_chantier")
	_verifier(_id_etape() == "ankhkhaf_faite", "chapitre 7 : Ânkhkhaf a réuni les équipes (%s)" % _id_etape())
	_verifier(_a_recu("coudee_royale"), "Hémiounou offre sa coudée royale")
	await _parler("ankhkhaf_chantier")
	_verifier(_id_etape() == "halage_faite", "il faut tirer la pierre de faîte (%s)" % _id_etape())
	var traineau: Node3D = _scene.find_child("TraineauFaite", true, false)
	_verifier(traineau != null and traineau.get_node_or_null("Pyramidion") != null, "la pierre de faîte est sur son traîneau")
	var depart := traineau.global_position
	Engine.time_scale = 4.0
	tues = await _suivre("halage_faite", func(): return traineau, 60 * 60)
	Engine.time_scale = 1.0
	_verifier(_id_etape() == "gardes_faite", "la pierre est au pied de la rampe (%s, %d ennemis)" % [_id_etape(), tues])
	_verifier(traineau.global_position.distance_to(depart) > 30.0, "le traîneau a avancé (%.0f m)" % traineau.global_position.distance_to(depart))
	await _attendre(20)
	tues = _tuer_tous()
	await _attendre(20)
	_verifier(tues >= 4 and _id_etape() == "fin_chapitre_7", "les gardes des Effaceurs sont repoussés (%d)" % tues)
	await _parler("hemiounou_chantier")
	_verifier(_a_recu("pectoral_faite"), "Hémiounou offre le pectoral de la pierre de faîte")
	_verifier(_id_etape() == "ankhkhaf_rampe", "le chapitre 8 commence (%s)" % _id_etape())

	# --- Plus tard : la pierre reste au pied de la rampe.
	await _charger("village_batisseurs")
	traineau = _scene.find_child("TraineauFaite", true, false)
	_verifier(Vector2(traineau.global_position.x, traineau.global_position.z).distance_to(Vector2(-6, -138)) < 1.0, "la pierre de faîte est restée au pied de la rampe")

	var inv = _joueur.get_node("Inventaire")
	inv.etat = _sacs_avant
	inv._sauvegarder()
	var prog = _joueur.get_node("Progression")
	prog.etat = _progression_avant
	prog._sauvegarder()
	_scene.queue_free()
	await _attendre(5)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Résultat : ", "tout est bon" if _echecs == 0 else "%d échec(s)" % _echecs)
	quit(0 if _echecs == 0 else 1)
