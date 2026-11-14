extends SceneTree
## Test automatique des événements publics de la Préhistoire (data/prehistoire_evenements.json) :
## « La Faille s'ouvre » (forêt) réussi puis raté, « La Tempête blanche » (steppe, froid et
## feux de veille), « La Grande Migration » (le troupeau de mammouths), la participation,
## la stabilité de l'époque et l'horloge sauvegardée.
## Lancement : godot --headless --path game -s res://tests/test_evenements.gd

const FICHIER := "user://test_evenements_progression.cfg"

var _echecs := 0
var _scene: Node
var _joueur
var _quete
var _evt


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


func _aller_pres(cible: Node3D) -> void:
	var p: Vector3 = cible.global_position + Vector3(0, 0, 1.6)
	p.y = _scene.hauteur(p.x, p.z) + 0.3
	await _placer(p, 0.0)


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


func _utiliser(objet: Node3D, duree: float) -> void:
	await _aller_pres(objet)
	_tuer_evenement()
	await _appuyer_f()
	await _attendre(int(duree * 60) + 30)


## Le joueur tue (lui-même) les ennemis de l'événement encore debout.
func _tuer_evenement() -> int:
	var n := 0
	var combat_joueur = _joueur.get_node("Combat")
	for bete in get_nodes_in_group("loups"):
		if bete.has_meta("evenement") and bete.combat.est_vivant():
			bete.combat.subir(99999.0, combat_joueur)
			n += 1
	return n


func _types_vivants() -> Array:
	var t := []
	for bete in get_nodes_in_group("loups"):
		if bete.has_meta("evenement") and bete.combat.est_vivant():
			t.append(String(bete.type_ennemi))
	return t


func _marqueurs_evenement() -> int:
	var n := 0
	for m in get_nodes_in_group("marqueur_carte"):
		if String(m.libelle).begins_with("Événement") and not m.is_queued_for_deletion():
			n += 1
	return n


func _charger(scene: String) -> void:
	_scene = load(scene).instantiate()
	_quete = _scene.get_node("Quete")
	_quete.fichier_progression = FICHIER
	_quete.voyage_reel = false
	root.add_child(_scene)
	await _attendre(40)
	_joueur = get_first_node_in_group("joueur_local")
	_evt = get_first_node_in_group("evenements_publics")


func _decharger() -> void:
	_scene.queue_free()
	await _attendre(5)


func _lancer() -> void:
	print("Test des événements publics (Préhistoire)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	var cfg := ConfigFile.new()
	cfg.set_value("prehistoire", "etape", "murs_vides")
	cfg.save(FICHIER)

	# --- La Faille s'ouvre (forêt).
	await _charger("res://scenes/monde/prehistoire/foret.tscn")
	_verifier(_evt != null, "les événements publics sont chargés")
	_verifier(_evt.evenements.size() >= 3, "trois événements au moins (%d)" % _evt.evenements.size())
	var faille_evt: Dictionary = _evt.evenement("faille_s_ouvre")
	_verifier(_evt.debloque(faille_evt), "« La Faille s'ouvre » est débloquée au chapitre 7")
	_verifier(float(_evt.prochain["faille_s_ouvre"]) > Time.get_unix_time_from_system() + 20.0, "pas d'événement dès l'arrivée")
	var stabilite_avant: float = _evt.stabilite
	await _placer(Vector3(72, _scene.hauteur(72, -54) + 0.3, -54), 0.0)
	_evt.declencher("faille_s_ouvre")
	await _attendre(5)
	_verifier(_evt.en_cours() and _evt.phase == 0, "l'événement commence par les vagues")
	_verifier(_evt._cadre.visible, "le cadre de l'événement est à l'écran")
	_verifier(_marqueurs_evenement() == 1, "un repère « Événement » sur la carte")
	var faille = _evt._objets.get("grande_faille")
	_verifier(faille != null and not faille.actif, "la grande faille est là, on ne peut pas encore la refermer")
	var tues := 0
	for v in 3:
		await _attendre(5)
		tues += _tuer_evenement()
		await _attendre(5)
	_verifier(tues == 12, "trois vagues de fracturés (3 + 4 + 5 = %d)" % tues)
	_verifier(_evt.phase == 1, "le chef de meute arrive")
	await _attendre(5)
	var types := _types_vivants()
	_verifier(types.has("loup_alpha_fracture") and types.size() == 3, "le chef et deux loups (%s)" % ", ".join(types))
	var chef = null
	for bete in get_nodes_in_group("loups"):
		if String(bete.type_ennemi) == "loup_alpha_fracture" and bete.combat.est_vivant():
			chef = bete
	if chef != null:
		_verifier(chef.get_node("Apparence").scale.x > 1.3, "le chef est plus grand qu'un loup")
	_tuer_evenement()
	await _attendre(10)
	_verifier(_evt.phase == 2 and faille.actif, "il faut refermer la faille")
	await _utiliser(faille, 5.0)
	await _attendre(10)
	_verifier(not _evt.en_cours(), "l'événement est fini")
	_verifier(faille.fermee, "la grande faille est refermée")
	_verifier(_marqueurs_evenement() == 0, "le repère disparaît de la carte")
	_verifier(_evt.derniere_participation == "or", "participation or en solo (%s)" % _evt.derniere_participation)
	_verifier(_evt.stabilite > stabilite_avant, "la stabilité de l'époque monte (%.0f → %.0f)" % [stabilite_avant, _evt.stabilite])
	_verifier(_evt.reussis("faille_s_ouvre") == 1, "une faille réussie est comptée")
	var sac = _joueur.get_node("Inventaire")
	_verifier(sac.compter("eclat_de_fracture") >= 4 if sac.has_method("compter") else true, "des éclats de fracture en récompense")
	_verifier(float(_evt.prochain["faille_s_ouvre"]) > Time.get_unix_time_from_system() + 2000.0, "la prochaine faille est dans 45 minutes")

	# --- Raté : le chrono s'écoule.
	_evt.declencher("faille_s_ouvre")
	await _attendre(5)
	_verifier(_types_vivants().size() == 3, "nouvelle faille, première vague")
	_evt.restant = 0.05
	await _attendre(10)
	_verifier(not _evt.en_cours(), "le chrono est fini : échec")
	_verifier(_types_vivants().is_empty(), "les fracturés repartent dans la faille")
	await _decharger()

	# --- La Tempête blanche (steppe).
	await _charger("res://scenes/monde/prehistoire/steppe.tscn")
	_verifier(_evt.reussis("faille_s_ouvre") == 1, "après rechargement, la faille réussie est toujours comptée")
	var loin := Vector3(-60, 0, -40)
	loin.y = _scene.hauteur(loin.x, loin.z) + 0.3
	await _placer(loin, 0.0)
	var combat_joueur = _joueur.get_node("Combat")
	_evt.declencher("tempete_blanche")
	await _attendre(5)
	_verifier(bool(_scene.en_tempete), "la tempête de neige se lève")
	var pv_avant: float = combat_joueur.pv
	await _attendre(int(7 * 60))
	_verifier(_evt._a_froid and combat_joueur.pv < pv_avant, "loin du feu, on a froid et on perd de la vie (%d → %d)" % [pv_avant, combat_joueur.pv])
	await _placer(Vector3(28, _scene.hauteur(28, -54) + 0.3, -54), 0.0)
	await _attendre(30)
	_verifier(not _evt._a_froid, "près du feu du camp, on est au chaud")
	for k in 3:
		await _utiliser(_evt._objets.get("feu_veille_%d" % k), 3.0)
	_verifier(_evt._objets["feu_veille_0"].get_node_or_null("FeuDeVeille") != null, "le premier feu de veille brûle")
	_verifier(_evt.phase == 1, "les trois feux sont allumés : des fracturés attaquent")
	for v in 2:
		await _attendre(5)
		_tuer_evenement()
		await _attendre(5)
	await _attendre(5)
	_verifier(not _evt.en_cours(), "le camp est sauvé")
	_verifier(not bool(_scene.en_tempete), "la tempête s'éloigne")

	# --- La Grande Migration (steppe).
	_evt.declencher("grande_migration")
	await _attendre(5)
	var troupeau: Array = _evt._troupeau.duplicate()
	_verifier(troupeau.size() >= 4, "le troupeau de mammouths se met en marche (%d)" % troupeau.size())
	var depart: Vector3 = troupeau[0].global_position
	Engine.time_scale = 6.0
	var embuscades := 0
	for s in 120:
		await _attendre(30)
		embuscades += _tuer_evenement()
		if not _evt.en_cours():
			break
	Engine.time_scale = 1.0
	_verifier(embuscades >= 3, "des fracturés tendent des embuscades (%d tués)" % embuscades)
	_verifier(not _evt.en_cours() and _evt.reussis("grande_migration") == 1, "le troupeau arrive à l'est")
	_verifier(troupeau[0].global_position.distance_to(depart) > 100.0, "les mammouths ont vraiment traversé la steppe (%d m)" % roundi(troupeau[0].global_position.distance_to(depart)))
	_verifier(troupeau[0].global_position.x > 80.0, "ils broutent maintenant à l'est (x = %d)" % roundi(troupeau[0].global_position.x))

	# --- Panique : on laisse les fracturés près du troupeau.
	_evt.declencher("grande_migration")
	await _attendre(5)
	_evt.frayeur = 99.0
	var p: Vector3 = _evt._troupeau[0].global_position
	_evt._faire_apparaitre({"type": "loup_fracture", "nombre": 2, "rayon": 2}, Vector2(p.x, p.z))
	await _attendre(30)
	_verifier(not _evt.en_cours(), "les fracturés font paniquer le troupeau : échec")
	_verifier(_evt._troupeau.is_empty(), "le troupeau n'est plus suivi")

	print("Résultat : ", "TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	quit(1 if _echecs > 0 else 0)
