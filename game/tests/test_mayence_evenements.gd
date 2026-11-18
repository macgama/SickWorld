extends SceneTree
## Test automatique des événements publics du Mayence (data/mayence_evenements.json) : chaque
## événement est lancé dans sa zone et joué jusqu'au bout, puis on vérifie la réussite, la
## participation et le compte des réussites. En plus : les loups de l'orage, les pilleurs de la
## crue et la grande statue de lettres de plomb.
## Lancement : godot --headless --path game -s res://tests/test_mayence_evenements.gd

const FICHIER := "user://test_mayence_evenements.cfg"
const SCENES := "res://scenes/monde/mayence/%s.tscn"

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
	var p: Vector3 = objet.global_position + Vector3(0, 0, 1.6)
	p.y = _scene.hauteur(p.x, p.z) + 0.3
	await _placer(p, 0.0)
	_tuer_evenement()
	await _appuyer_f()
	await _attendre(int(duree * 60) + 30)


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
	_evt = get_first_node_in_group("evenements_publics")


## Aucun objet de l'événement n'est enfoncé dans un mur ou une maison.
func _verifier_acces(id: String) -> void:
	var espace := (_scene as Node3D).get_world_3d().direct_space_state
	var bloques: PackedStringArray = []
	for oid in _evt._objets:
		var o: Node3D = _evt._objets[oid]
		if o.has_method("fermer"):
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		var s := SphereShape3D.new()
		s.radius = 0.45
		q.shape = s
		q.transform = Transform3D(Basis(), o.global_position + Vector3(0, 1.0, 0))
		if _joueur is CollisionObject3D:
			q.exclude = [(_joueur as CollisionObject3D).get_rid()]
		if not espace.intersect_shape(q, 1).is_empty():
			bloques.append(oid)
	_verifier(bloques.is_empty(), "%s : les objets sont accessibles %s" % [id, bloques])


## Joue l'événement en cours phase par phase. Renvoie le nombre d'ennemis vaincus.
func _jouer() -> int:
	var tues := 0
	var essais := 0
	while _evt.en_cours() and essais < 40:
		essais += 1
		var p: Dictionary = _evt.phase_actuelle()
		if p.has("vagues"):
			await _attendre(5)
			tues += _tuer_evenement()
			await _attendre(10)
		elif p.has("passages"):
			var borne: Node3D = _evt.prochaine_borne()
			if borne != null:
				await _placer(borne.global_position + Vector3(0, 0.5, 0.8), 0.0)
				await _attendre(70)
			else:
				await _attendre(10)
		elif p.has("mini_jeu"):
			var cible = _evt._objets.get(String(p.objet))
			await _placer(cible.global_position + Vector3(0, 0.5, 1.6), 0.0)
			await _appuyer_f()
			await _attendre(5)
			var tours := 0
			var jeu = get_first_node_in_group("mini_jeu_en_cours")
			while jeu != null and is_instance_valid(jeu) and not jeu.termine and tours < 20:
				tours += 1
				jeu.viser_parfait()
				jeu.valider()
				await _attendre(64)
			await _attendre(10)
		elif p.has("recolter") or p.has("objet"):
			var fait := false
			for oid in _evt._objets:
				var o = _evt._objets[oid]
				if is_instance_valid(o) and o.actif:
					await _utiliser(o, float(p.get("duree", 0.0)))
					fait = true
					break
			if not fait:
				await _attendre(10)
		else:
			await _attendre(10)
	return tues


func _phase_zero_finie() -> void:
	var n := 0
	while _evt.en_cours() and _evt.phase == 0 and n < 10:
		n += 1
		await _attendre(5)
		_tuer_evenement()
		await _attendre(10)


func _lancer() -> void:
	print("Test des événements publics (Mayence)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	var cfg := ConfigFile.new()
	cfg.set_value("mayence", "etape", "fin")
	cfg.save(FICHIER)
	var donnees = JSON.parse_string(FileAccess.get_file_as_string("res://data/mayence_evenements.json"))
	_verifier(donnees is Dictionary and (donnees.evenements as Array).size() == 5, "cinq événements publics")
	var ennemis = JSON.parse_string(FileAccess.get_file_as_string("res://data/ennemis.json"))
	var cat = JSON.parse_string(FileAccess.get_file_as_string("res://data/objets.json"))
	for e in donnees.evenements:
		var id := String(e.id)
		var types_inconnus: PackedStringArray = []
		for ph in e.phases:
			var groupes: Array = ph.get("vagues", []).duplicate()
			if ph.has("renforts"):
				groupes.append(ph.renforts)
			for g in groupes:
				if not (ennemis as Dictionary).has(String(g.type)):
					types_inconnus.append(String(g.type))
		for niveau in e.recompenses:
			for r in e.recompenses[niveau]:
				if not (cat.objets as Dictionary).has(String(r.id)):
					types_inconnus.append(String(r.id))
		_verifier(types_inconnus.is_empty(), "%s : ennemis et récompenses existent %s" % [id, types_inconnus])
		await _charger(String(e.zone))
		_verifier(_evt != null, "%s : les événements de Mayence sont chargés" % id)
		if _evt == null:
			continue
		_verifier(_evt.debloque(_evt.evenement(id)), "%s : débloqué une fois la quête avancée" % id)
		_verifier(float(_evt.prochain[id]) > Time.get_unix_time_from_system() + 20.0, "%s : pas dès l'arrivée dans la zone" % id)
		var pos: Array = e.position
		await _placer(Vector3(pos[0], _scene.hauteur(pos[0], pos[1]) + 0.5, pos[1]), 0.0)
		var stabilite_avant: float = _evt.stabilite
		_evt.declencher(id)
		await _attendre(5)
		_verifier(_evt.en_cours() and _evt._cadre.visible, "%s : l'événement commence, avec son cadre à l'écran" % id)
		_verifier_acces(id)
		var scripts_ok := true
		for oid in _evt._objets:
			var o = _evt._objets[oid]
			if not o.has_method("fermer"):
				scripts_ok = scripts_ok and String(o.get_script().resource_path).ends_with("objet_mayence.gd")
		_verifier(scripts_ok, "%s : les objets sont dessinés par le script de Mayence" % id)
		if id == "vendanges_sous_l_orage":
			_evt._prochain_renfort = 0.0
			await _attendre(10)
			_verifier(_types_vivants().has("loup_orage_rheingau"), "les loups de l'orage rôdent autour des vignes")
		if id == "crue_du_rhin":
			_evt._prochain_renfort = 0.0
			await _attendre(10)
			_verifier(_types_vivants().has("mercenaire_pilleur_crue"), "des pilleurs profitent de la crue")
		if id == "nuit_des_lettres":
			await _phase_zero_finie()
			await _attendre(5)
			_verifier(_types_vivants().has("statue_lettres_plomb_nuit_grande"), "la grande statue de lettres se lève")
		var tues := await _jouer()
		_verifier(not _evt.en_cours(), "%s : l'événement est fini" % id)
		_verifier(_evt.reussis(id) == 1, "%s : réussi et compté" % id)
		_verifier(_evt.derniere_participation == "or", "%s : participation or en solo (%s, %d ennemis)" % [id, _evt.derniere_participation, tues])
		_verifier(_evt.stabilite > stabilite_avant, "%s : la stabilité de Mayence monte" % id)
	await _charger("rheingau")
	var lu := ConfigFile.new()
	lu.load(Profil.chemin(FICHIER))
	_verifier(lu.has_section("mayence_evenements"), "la sauvegarde des événements de Mayence est à part")
	_scene.queue_free()
	await _attendre(5)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Résultat : ", "tout est bon" if _echecs == 0 else "%d échec(s)" % _echecs)
	quit(0 if _echecs == 0 else 1)
