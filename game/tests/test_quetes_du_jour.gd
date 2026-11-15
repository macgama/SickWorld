extends SceneTree
## Test automatique des missions du jour et de la semaine (Ayaka Mori, QG de la Vigie) :
## tirage du jour, fenêtre, accepter, avancer (ennemis, éclats de temps, événements),
## rendre, récompenses, renouvellement le lendemain, échange d'insignes chez l'intendant.
## Lancement : godot --headless --path game -s res://tests/test_quetes_du_jour.gd

var FICHIER := "user://test_quetes_du_jour_%d.cfg" % OS.get_process_id()

var _echecs := 0
var _scene: Node
var _joueur
var _dialogue
var _qdj
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


func _appuyer_f() -> void:
	var appui := InputEventAction.new()
	appui.action = "interagir"
	appui.pressed = true
	Input.parse_input_event(appui)
	await _attendre(4)
	var relache := InputEventAction.new()
	relache.action = "interagir"
	relache.pressed = false
	Input.parse_input_event(relache)
	await _attendre(2)


func _trouver_pnj(id: String):
	for pnj in get_nodes_in_group("pnj"):
		if pnj.identifiant == id:
			return pnj
	return null


func _parler_a(id: String) -> int:
	var pnj = _trouver_pnj(id)
	if pnj == null:
		return 0
	var devant: Vector3 = pnj.global_position - pnj.global_transform.basis.z * 1.6
	await _placer(devant + Vector3(0, 0.3, 0), pnj.rotation.y + PI)
	await _appuyer_f()
	for essai in 3:
		if _dialogue.est_ouvert():
			break
		await _attendre(10)
		await _appuyer_f()
	var lues := 0
	while _dialogue.est_ouvert() and lues < 30:
		lues += 1
		await _appuyer_f()
	await _attendre(5)
	return lues


func _boutons(texte: String) -> Array:
	var resultat: Array = []
	for b in _qdj._fenetre.find_children("*", "Button", true, false):
		if (b as Button).text == texte and not b.is_queued_for_deletion():
			resultat.append(b)
	return resultat


func _compter(id: String) -> int:
	var total := 0
	for c in _joueur.get_node("Inventaire").etat.get("cases", []):
		if String((c as Dictionary).get("id", "")) == id:
			total += int(c.get("n", 1))
	return total


func _vider_sacs() -> void:
	var inventaire = _joueur.get_node("Inventaire")
	if _sacs_avant.is_empty():
		_sacs_avant = inventaire.etat.duplicate(true)
	for i in (inventaire.etat["cases"] as Array).size():
		inventaire.etat["cases"][i] = {}
	inventaire._sauvegarder()


func _remettre_sacs() -> void:
	if _sacs_avant.is_empty() or _joueur == null:
		return
	var inventaire = _joueur.get_node("Inventaire")
	inventaire.etat = _sacs_avant
	inventaire._sauvegarder()


func _charger(chemin: String) -> void:
	if _scene != null and is_instance_valid(_scene):
		_scene.queue_free()
		await _attendre(5)
	_scene = load(chemin).instantiate()
	if _scene.has_node("Quetes"):
		_scene.get_node("Quetes").fichier_progression = FICHIER
		_scene.get_node("Intro").fichier_progression = FICHIER
	if _scene.has_node("Quete"):
		_scene.get_node("Quete").fichier_progression = FICHIER
		_scene.get_node("Quete").voyage_reel = false
	root.add_child(_scene)
	await _attendre(60)
	_joueur = get_first_node_in_group("joueur_local")
	_joueur.get_node("Combat").pv_max = 1e6
	_joueur.get_node("Combat").pv = 1e6
	_dialogue = get_first_node_in_group("dialogue")
	_qdj = get_first_node_in_group("quetes_du_jour")


func _lancer() -> void:
	print("Test des missions du jour et de la semaine")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	var cfg := ConfigFile.new()
	cfg.set_value("intro", "terminee", true)
	cfg.set_value("prehistoire", "etape", "fin")
	cfg.set_value("egypte", "etape", "vers_desert")
	cfg.save(FICHIER)
	await _tester_hub()
	await _tester_ile()
	await _tester_eclats_partout()
	_remettre_sacs()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Résultat : %s" % ("tout est bon" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)


# --- Au QG ---------------------------------------------------------------------------

func _tester_hub() -> void:
	await _charger("res://scenes/monde/hikari_bay.tscn")
	_verifier(_qdj != null, "les missions du jour sont chargées dans le hub")
	if _qdj == null:
		return
	_vider_sacs()
	_verifier(_qdj.liste("quotidienne").size() >= 12 and _qdj.liste("hebdomadaire").size() >= 4,
			"%d missions du jour et %d de la semaine dans les données" % [_qdj.liste("quotidienne").size(), _qdj.liste("hebdomadaire").size()])
	# Toutes les récompenses existent dans le catalogue des objets.
	var inconnus: PackedStringArray = []
	for genre in ["quotidienne", "hebdomadaire"]:
		for m in _qdj.liste(genre):
			for r in m.get("recompense", []):
				if not Objets.existe(root.get_node("Donnees").objets, String(r["id"])):
					inconnus.append(String(r["id"]))
			for ile in m.get("apres", {}):
				_verifier(_qdj._etapes_ile(String(ile)).has(String(m["apres"][ile])), "« %s » : l'étape %s existe" % [m.id, m["apres"][ile]])
	_verifier(inconnus.is_empty(), "toutes les récompenses existent %s" % inconnus)

	var jour: Array = _qdj.offres["quotidienne"]["ids"]
	var semaine: Array = _qdj.offres["hebdomadaire"]["ids"]
	_verifier(jour.size() == 3, "3 missions du jour tirées : %s" % [jour])
	_verifier(semaine.size() == 2, "2 missions de la semaine tirées : %s" % [semaine])
	var iles := {}
	for id in jour:
		iles[_qdj.mission(id).get("ile", "")] = true
	_verifier(iles.has("prehistoire") and iles.has("egypte"), "les missions du jour alternent les îles visitées")
	_verifier(_qdj._tirer("quotidienne", _qdj.periode("quotidienne"), 3, []) == jour, "le tirage est le même pour tout le monde le même jour")
	var demain: Array = _qdj._tirer("quotidienne", _qdj.periode("quotidienne") + 1, 3, [])
	_verifier(demain != jour, "le tirage change le lendemain (%s)" % [demain])
	# Les missions d'une étape pas encore atteinte ne sont pas tirées (Égypte avant « rapport_iry »
	# : oui ; « renfort_egypte » demande rapport_iry, dépassé ; aucune ne demande plus loin).
	_verifier(not _qdj.accessible({"ile": "egypte", "apres": {"egypte": "journal_merer"}}), "une mission de fin d'histoire reste cachée")
	_verifier(_qdj.temps_restant("quotidienne") > 0 and _qdj.temps_restant("quotidienne") <= 86400, "renouvellement dans %s" % _qdj.duree_lisible(_qdj.temps_restant("quotidienne")))
	_verifier(_qdj.temps_restant("hebdomadaire") > 0 and _qdj.temps_restant("hebdomadaire") <= 7 * 86400, "missions de la semaine renouvelées dans %s" % _qdj.duree_lisible(_qdj.temps_restant("hebdomadaire")))

	var ayaka = _trouver_pnj("maitre_missions")
	var sven = _trouver_pnj("intendant")
	_verifier(ayaka != null and ayaka.nom == "Ayaka Mori", "Ayaka Mori est au QG de la Vigie")
	_verifier(sven != null and sven.nom == "Sven Halvorsen", "Sven Halvorsen, l'intendant, est à côté")
	if ayaka == null:
		return
	_verifier(ayaka.global_position.y < -11.0, "Ayaka est bien dans le Hall des opérations (y = %.1f)" % ayaka.global_position.y)
	await _attendre(70)
	var marque = ayaka.get_node_or_null("MarqueMissionsDuJour")
	_verifier(marque != null and marque.visible and marque.text == "!", "un « ! » bleu flotte au-dessus d'Ayaka")

	var lues := await _parler_a("maitre_missions")
	_verifier(lues >= 1, "Ayaka parle (%d bulles)" % lues)
	_verifier(_qdj.fenetre_ouverte(), "la fenêtre des missions s'ouvre après le dialogue")
	await _attendre(3)
	var accepter := _boutons("Accepter")
	_verifier(accepter.size() == 5, "5 boutons « Accepter » (3 du jour + 2 de la semaine) : %d" % accepter.size())
	if accepter.is_empty():
		return
	accepter[0].pressed.emit()
	await _attendre(3)
	_verifier(_qdj.etat(jour[0]) == "en_cours", "le bouton accepte la mission « %s »" % jour[0])
	for id in jour + semaine:
		_qdj.accepter(id)
	await _attendre(3)
	_verifier(_boutons("En cours").size() == 5, "les 5 missions sont en cours")
	_verifier(_qdj._cadre.visible and _qdj._liste.get_child_count() >= 11, "les missions suivies s'affichent à droite")

	# Une mission finie à la main (comme si on avait vaincu les ennemis) : on la rend.
	var premiere := String(jour[0])
	var c: String = _qdj.cle(premiere)
	var o: Dictionary = _qdj.mission(premiere)["objectif"]
	for i in _qdj._nombre(o):
		_qdj._avancer(c)
	_verifier(_qdj.etat(premiere) == "a_rendre", "« %s » est terminée, à rendre" % premiere)
	await _attendre(70)
	_verifier(marque.text == "?", "un « ? » apparaît au-dessus d'Ayaka")
	var insignes := 0
	for r in _qdj.mission(premiere)["recompense"]:
		if r["id"] == "insigne_vigie":
			insignes = int(r["n"])
	var rendre := _boutons("Rendre")
	_verifier(rendre.size() == 1, "un bouton « Rendre »")
	if not rendre.is_empty():
		rendre[0].pressed.emit()
	await _attendre(5)
	_verifier(_qdj.etat(premiere) == "rendue", "la mission est rendue")
	_verifier(_compter("insigne_vigie") == insignes and insignes > 0, "récompense : %d insignes de la Vigie" % _compter("insigne_vigie"))
	_verifier(_boutons("✓ Faite").size() == 1, "la mission rendue reste affichée « ✓ Faite »")
	if semaine.has("agent_assidu"):
		_verifier(int(_qdj.suivies[_qdj.cle("agent_assidu")]["compte"]) == 1, "« Agent assidu » compte la mission rendue")
	_qdj.fermer_fenetre()

	# La deuxième, finie mais pas rendue : elle reste à rendre le lendemain.
	var deuxieme := String(jour[1])
	var c2: String = _qdj.cle(deuxieme)
	for i in _qdj._nombre(_qdj.mission(deuxieme)["objectif"]):
		_qdj._avancer(c2)
	# Sauvegarde relue : un autre nœud (nouvelle scène) retrouve le même état.
	var relu = load("res://scripts/monde/quetes_du_jour.gd").new()
	relu.fichier_progression = FICHIER
	relu._charger()
	_verifier(relu.suivies.has(c2) and String(relu.suivies[c2]["etat"]) == "a_rendre" and relu.rendues.has(c), "l'avancement est sauvegardé")
	relu.free()

	# Le lendemain à 6 h.
	var hier: int = _qdj.periode("quotidienne")
	var semaine_finie: bool = _qdj.temps_restant("hebdomadaire") <= _qdj.temps_restant("quotidienne") + 60
	_qdj.decalage_horloge = _qdj.temps_restant("quotidienne") + 60
	_verifier(_qdj.renouveler(), "le lendemain, les missions se renouvellent")
	var nouvelles: Array = _qdj.offres["quotidienne"]["ids"]
	_verifier(nouvelles.size() == 3 and _qdj.etat(String(nouvelles[0])) == "disponible", "3 nouvelles missions du jour : %s" % [nouvelles])
	_verifier(not _qdj.suivies.has("%s@%d" % [jour[2], hier]), "la mission d'hier pas finie est oubliée")
	_verifier(_qdj.suivies.has(c2), "la mission d'hier finie reste à rendre")
	if not semaine_finie:
		for id in semaine:
			_verifier(_qdj.etat(String(id)) == "en_cours", "la mission de la semaine « %s » continue" % id)
	await _parler_a("maitre_missions")
	_verifier(_qdj.fenetre_ouverte(), "la fenêtre se rouvre")
	await _attendre(3)
	rendre = _boutons("Rendre")
	_verifier(rendre.size() == 1, "la mission d'hier se rend encore (section « passées »)")
	var avant := _compter("insigne_vigie")
	if not rendre.is_empty():
		rendre[0].pressed.emit()
	await _attendre(5)
	_verifier(_compter("insigne_vigie") > avant and not _qdj.suivies.has(c2), "rendue : %d insignes au total" % _compter("insigne_vigie"))
	_qdj.fermer_fenetre()

	# Échange chez l'intendant.
	_joueur.get_node("Inventaire").recevoir([{"id": "insigne_vigie", "n": 10}])
	await _attendre(2)
	var total := _compter("insigne_vigie")
	await _parler_a("intendant")
	var fenetre = get_first_node_in_group("fenetre_artisanat")
	_verifier(fenetre != null and fenetre.est_ouverte() and fenetre.id_artisan == "intendance", "Sven ouvre la fenêtre d'échange")
	if fenetre != null and fenetre.est_ouverte():
		_verifier(fenetre._bouton.text == "Échanger", "le bouton dit « Échanger »")
		fenetre.inventaire.fabriquer("echange_eclat_fracture")
		await _attendre(5)
		_verifier(_compter("insigne_vigie") == total - 3 and _compter("eclat_de_fracture") >= 1, "3 insignes échangés contre un éclat de fracture")
		fenetre.fermer_fenetre()
	_qdj.decalage_horloge = 0


# --- Sur une île ---------------------------------------------------------------------------

func _tester_ile() -> void:
	# On prépare deux missions en cours : des loups fracturés et des éclats sur la Côte Gelée.
	var outil = load("res://scripts/monde/quetes_du_jour.gd").new()
	outil.fichier_progression = FICHIER
	outil._charger()
	outil.reglages = {}
	var p: int = outil.periode("quotidienne")
	var ph: int = outil.periode("hebdomadaire")
	outil.offres["quotidienne"] = {"periode": p, "ids": ["fractures_de_la_cote", "eclats_dans_la_neige", "renfort_prehistoire"]}
	outil.suivies = {}
	outil.rendues = {}
	for id in ["fractures_de_la_cote", "eclats_dans_la_neige", "renfort_prehistoire"]:
		outil.suivies["%s@%d" % [id, p]] = {"id": id, "genre": "quotidienne", "periode": p, "compte": 0, "etat": "en_cours", "faits": []}
	outil.offres["hebdomadaire"] = {"periode": ph, "ids": ["grand_menage", "terreur_de_la_steppe"]}
	outil.suivies["grand_menage@%d" % ph] = {"id": "grand_menage", "genre": "hebdomadaire", "periode": ph, "compte": 0, "etat": "en_cours", "faits": []}
	outil._sauvegarder()
	outil.free()

	await _charger("res://scenes/monde/prehistoire/cote_gelee.tscn")
	_verifier(_qdj != null, "les missions du jour suivent le joueur sur l'île")
	if _qdj == null:
		return
	await _attendre(70)
	var c_eclats: String = _qdj.cle("eclats_dans_la_neige")
	var eclats: Array = []
	for k in _qdj._objets:
		if String(k).begins_with(c_eclats):
			eclats.append(_qdj._objets[k])
	_verifier(eclats.size() == 8, "8 éclats de temps sont posés sur la Côte Gelée (%d)" % eclats.size())
	_verifier(_qdj._cadre.visible, "la liste des missions s'affiche sur l'île")
	# Vaincre 5 loups fracturés près du joueur.
	var c_loups: String = _qdj.cle("fractures_de_la_cote")
	var vaincus := 0
	for essai in 20:
		if _qdj.etat("fractures_de_la_cote") != "en_cours":
			break
		var loup = _plus_proche("loup_fracture")
		if loup == null:
			# Les camps de la Côte n'ont que 4 loups fracturés : on en fait venir d'autres.
			var ici: Vector3 = _joueur.global_position
			get_first_node_in_group("quete")._faire_apparaitre({"type": "loup_fracture", "nombre": 2, "position": [ici.x + 6.0, ici.z], "rayon": 2}, true)
			await _attendre(30)
			continue
		await _placer(loup.global_position + Vector3(0, 1.0, 3.0), 0.0)
		loup.combat.subir(99999.0, _joueur.get_node("Combat"))
		vaincus += 1
		await _attendre(5)
	_verifier(_qdj.etat("fractures_de_la_cote") == "a_rendre", "5 loups fracturés vaincus : mission terminée (%d coups)" % vaincus)
	_verifier(int(_qdj.suivies[_qdj.cle("grand_menage")]["compte"]) >= 5, "« Le grand ménage » compte aussi les fracturés (%d)" % int(_qdj.suivies[_qdj.cle("grand_menage")]["compte"]))
	# Ramasser 5 éclats (F, puis l'action de 1,2 s).
	var ramasses := 0
	for objet in eclats:
		if _qdj.etat("eclats_dans_la_neige") != "en_cours":
			break
		if not is_instance_valid(objet):
			continue
		_tuer_proches(objet.global_position, 35.0)
		var pos: Vector3 = objet.global_position + Vector3(0, 0, 1.4)
		pos.y = _scene.hauteur(pos.x, pos.z) + 0.3
		await _placer(pos, 0.0)
		await _attendre(10)
		var avant := int(_qdj.suivies[c_eclats]["compte"])
		await _appuyer_f()

		await _attendre(110)
		if int(_qdj.suivies[c_eclats]["compte"]) > avant:
			ramasses += 1
	_verifier(ramasses == 5 and _qdj.etat("eclats_dans_la_neige") == "a_rendre", "5 éclats ramassés : mission terminée (%d)" % ramasses)
	var restants := 0
	for k in _qdj._objets:
		if String(k).begins_with(c_eclats):
			restants += 1
	await _attendre(2)
	_verifier(restants == 0, "les éclats restants disparaissent")

	# Un loup tué loin du joueur ne compte pas.
	var compte := int(_qdj.suivies[_qdj.cle("grand_menage")]["compte"])
	_qdj._sur_ennemi_vaincu(null, _faux_loup(_joueur.global_position + Vector3(200, 0, 0)))
	_verifier(int(_qdj.suivies[_qdj.cle("grand_menage")]["compte"]) == compte, "un ennemi vaincu loin du joueur ne compte pas")

	# Événement public réussi (on imite la fin de l'événement).
	var ev = get_first_node_in_group("evenements_publics")
	_verifier(ev != null, "les événements publics de l'île sont là")
	if ev != null:
		ev.derniere_participation = ""
		ev.evenement_fini.emit("faille_s_ouvre", true)
		_verifier(_qdj.etat("renfort_prehistoire") == "en_cours", "un événement où l'on n'a rien fait ne compte pas")
		ev.derniere_participation = "argent"
		ev.evenement_fini.emit("faille_s_ouvre", false)
		_verifier(_qdj.etat("renfort_prehistoire") == "en_cours", "un événement raté ne compte pas")
		ev.evenement_fini.emit("faille_s_ouvre", true)
		_verifier(_qdj.etat("renfort_prehistoire") == "a_rendre", "un événement réussi termine « Renfort au clan »")


func _faux_loup(position: Vector3) -> Node3D:
	var n := Node3D.new()
	n.set_meta("faux", true)
	n.set_script(null)
	root.add_child(n)
	n.global_position = position
	n.set("type_ennemi", "loup_fracture")
	return n


func _plus_proche(prefixe: String):
	var meilleur = null
	var d := INF
	for bete in get_nodes_in_group("loups"):
		if String(bete.type_ennemi).begins_with(prefixe) and bete.combat.est_vivant():
			var dd: float = bete.global_position.distance_to(_joueur.global_position)
			if dd < d:
				d = dd
				meilleur = bete
	return meilleur


func _tuer_proches(centre: Vector3, rayon: float) -> void:
	var combat_joueur = _joueur.get_node("Combat")
	for bete in get_nodes_in_group("loups"):
		if bete.combat.est_vivant() and bete.global_position.distance_to(centre) < rayon:
			bete.combat.subir(99999.0, combat_joueur)


# --- Les éclats de toutes les missions sont accessibles ---------------------------------------

func _tester_eclats_partout() -> void:
	var donnees: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quetes_du_jour.json"))
	var par_zone := {}
	for m in donnees["quotidiennes"] + donnees["hebdomadaires"]:
		var o: Dictionary = m.get("objectif", {})
		if o.has("recolter"):
			par_zone[String(o["ou"])] = o.get("positions", [])
	_verifier(par_zone.size() >= 5, "%d zones ont des éclats à ramasser" % par_zone.size())
	var ile_de := {"cote_gelee": "prehistoire", "steppe": "prehistoire", "foret": "prehistoire", "falaises": "prehistoire"}
	for zone in par_zone:
		var chemin := "res://scenes/monde/%s/%s.tscn" % [ile_de.get(zone, "egypte"), zone]
		await _charger(chemin)
		await _attendre(20)
		var espace := (_scene as Node3D).get_world_3d().direct_space_state
		var bloques: PackedStringArray = []
		for p in par_zone[zone]:
			var y: float = _scene.hauteur(float(p[0]), float(p[1]))
			var q := PhysicsShapeQueryParameters3D.new()
			var s := SphereShape3D.new()
			s.radius = 0.45
			q.shape = s
			q.transform = Transform3D(Basis(), Vector3(p[0], y + 1.0, p[1]))
			var rayon := PhysicsRayQueryParameters3D.create(Vector3(p[0], y + 40.0, p[1]), Vector3(p[0], y - 2.0, p[1]))
			var touche := espace.intersect_ray(rayon)
			var sol_ok: bool = not touche.is_empty() and absf(float(touche.position.y) - y) < 0.8
			if not espace.intersect_shape(q, 1).is_empty() or not sol_ok:
				bloques.append("[%s, %s]%s" % [p[0], p[1], "" if sol_ok else " (sol %s / %.1f)" % [touche.get("position", "rien"), y]])
		_verifier(bloques.is_empty(), "%s : les %d éclats sont accessibles %s" % [zone, par_zone[zone].size(), bloques])
