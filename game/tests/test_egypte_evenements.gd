extends SceneTree
## Test automatique des événements publics de l'Égypte (data/egypte_evenements.json) :
## chaque événement est lancé dans sa zone et joué jusqu'au bout (vagues, objets à utiliser,
## chef), puis on vérifie la réussite, la participation et le compte des réussites.
## Le Khamsin a en plus son vent de sable : hors des tentes des nomades, le sable brûle.
## Lancement : godot --headless --path game -s res://tests/test_egypte_evenements.gd

const FICHIER := "user://test_egypte_evenements.cfg"
const SCENES := "res://scenes/monde/egypte/%s.tscn"

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


func _lancer() -> void:
	print("Test des événements publics (Égypte)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	var cfg := ConfigFile.new()
	cfg.set_value("egypte", "etape", "journal_merer")
	cfg.save(FICHIER)
	var donnees = JSON.parse_string(FileAccess.get_file_as_string("res://data/egypte_evenements.json"))
	_verifier(donnees is Dictionary and (donnees.evenements as Array).size() >= 5, "cinq événements publics au moins")
	for e in donnees.evenements:
		var id := String(e.id)
		await _charger(String(e.zone))
		_verifier(_evt != null, "%s : les événements de l'Égypte sont chargés" % id)
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
		if id == "khamsin":
			_verifier(bool(_scene.en_tempete), "le khamsin se lève")
			var combat_joueur = _joueur.get_node("Combat")
			var loin := Vector3(10, 0, 40)
			loin.y = _scene.hauteur(loin.x, loin.z) + 0.3
			await _placer(loin, 0.0)
			var pv_avant: float = combat_joueur.pv
			await _attendre(int(7 * 60))
			_verifier(_evt._a_froid and combat_joueur.pv < pv_avant, "hors des tentes, le sable brûle (%d → %d)" % [pv_avant, combat_joueur.pv])
			_evt._mettre_a_jour_ecran()
			_verifier(_evt._jauge.text.contains("sable"), "le message parle du sable, pas du froid (%s)" % _evt._jauge.text)
			await _placer(Vector3(pos[0] + 2, _scene.hauteur(pos[0] + 2, pos[1]) + 0.3, pos[1]), 0.0)
			await _attendre(30)
			_verifier(not _evt._a_froid, "sous les tentes des nomades, on est à l'abri")
		if id == "hippopotame_enrage" or id == "faille_chantier":
			# Le chef sort après les premières vagues.
			var vu_chef := false
			var essais := 0
			while _evt.en_cours() and _evt.phase == 0 and essais < 10:
				essais += 1
				await _attendre(5)
				_tuer_evenement()
				await _attendre(10)
			await _attendre(5)
			for t in _types_vivants():
				if t in ["hippopotame_fracture", "garde_effaceuse"]:
					vu_chef = true
			_verifier(vu_chef, "%s : le chef arrive (%s)" % [id, ", ".join(_types_vivants())])
		var tues := await _jouer()
		_verifier(not _evt.en_cours(), "%s : l'événement est fini" % id)
		_verifier(_evt.reussis(id) == 1, "%s : réussi et compté" % id)
		_verifier(_evt.derniere_participation == "or", "%s : participation or en solo (%s, %d ennemis)" % [id, _evt.derniere_participation, tues])
		_verifier(_evt.stabilite > stabilite_avant, "%s : la stabilité de l'Égypte monte" % id)
		if id == "khamsin":
			_verifier(not bool(_scene.en_tempete), "le khamsin s'éloigne")
	var lu := ConfigFile.new()
	lu.load(Profil.chemin(FICHIER))
	_verifier(lu.has_section("egypte_evenements") and not lu.has_section("prehistoire_evenements"), "la sauvegarde des événements de l'Égypte est à part")
	_scene.queue_free()
	await _attendre(5)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Résultat : ", "tout est bon" if _echecs == 0 else "%d échec(s)" % _echecs)
	quit(0 if _echecs == 0 else 1)
