extends SceneTree
## Test automatique des quêtes secondaires de Rome (data/rome_secondaires.json) : les « ! »
## au-dessus des donneurs, chaque objet accessible (pas dans un mur) dans les quatre zones,
## puis les dix quêtes jouées de bout en bout, étape par étape, en voyageant d'une zone à
## l'autre (Rome, la Voie Appienne, la Campagne, Pompéi). En plus : les oies qui
## disparaissent, la chaudière des thermes qui se rallume, la mule de la poste, le Bain des
## thermes, l'oie compagnon qui crie quand un prétorien approche, et les titres.
## Lancement : godot --headless --path game -s res://tests/test_rome_secondaires.gd

const FICHIER := "user://test_rome_secondaires.cfg"
const SCENES := "res://scenes/monde/rome/%s.tscn"
## Où se trouve chaque donneur (et chaque personnage des étapes).
const ZONE_PNJ := {
	"gardien_junon": "rome", "gerant_thermes": "rome", "lanista": "rome", "boulangere": "rome",
	"carpophore": "rome", "martial_jeux": "rome", "pline": "pompei", "fausta": "voie_appienne",
	"petronius": "voie_appienne", "lenoir_appia": "voie_appienne", "refugie_1": "voie_appienne",
	"refugie_3": "voie_appienne", "caecilia": "voie_appienne", "refugiee_herculanum": "campagne",
}
const SCENE_ZONE := {"rome": "rome", "voie_appienne": "voie_appienne", "campagne": "campagne", "pompei": "pompei"}

var _zone_chargee := ""

var _echecs := 0
var _scene: Node
var _joueur
var _quete
var _sec
var _dialogue
## Les sacs du profil avant le test (vidés pendant le test, rendus à la fin).
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
	# Un figurant de la foule peut se trouver plus près : on essaie de plusieurs côtés.
	for cote: Vector3 in [Vector3(0, 0, 1.2), Vector3(1.2, 0, 0), Vector3(-1.2, 0, 0), Vector3(0, 0, -1.2)]:
		var p: Vector3 = pnj.global_position + cote
		p.y = maxf(_scene.hauteur(p.x, p.z), pnj.global_position.y) + 0.3
		await _placer(p, 0.0)
		await _attendre(20)
		await _appuyer_f()
		if _dialogue.est_ouvert():
			break
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
	_zone_chargee = zone
	_scene = load(SCENES % SCENE_ZONE.get(zone, zone)).instantiate()
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


const MiniJeu := preload("res://scripts/monde/mini_jeu.gd")


## Le mini-jeu ouvert par F : on le joue bien (le curseur au milieu de la zone verte, ou la
## bonne direction au bon moment). « rater » : on rate d'abord exprès ce nombre d'essais.
func _jouer_mini_jeu(rater := 0) -> bool:
	await _attendre(5)
	var jeu = get_first_node_in_group("mini_jeu_en_cours")
	if jeu == null:
		_verifier(false, "un mini-jeu s'ouvre")
		return false
	var tours := 0
	while is_instance_valid(jeu) and not jeu.termine and tours < 30:
		tours += 1
		if jeu.type == "jauge":
			if rater > 0:
				jeu._curseur = clampf(jeu._centre + 0.45, 0.0, 1.0) if jeu._centre < 0.5 else clampf(jeu._centre - 0.45, 0.0, 1.0)
				rater -= 1
			else:
				jeu.viser_parfait()
			jeu.valider()
		else:
			jeu.viser_parfait()
			if rater > 0:
				var autre := "avancer" if jeu.pas_attendu() != "avancer" else "reculer"
				jeu.appuyer(autre)
				rater -= 1
			else:
				jeu.appuyer(jeu.pas_attendu())
		# La petite pause après chaque essai.
		await _attendre(64)
	return not is_instance_valid(jeu) or jeu.termine


func _utiliser_jeu(id: String, rater := 0) -> void:
	var objet := _objet(id)
	if objet == null:
		_verifier(false, "l'objet %s existe" % id)
		return
	await _aller_pres(objet)
	_tuer_proches(objet.global_position, 30.0)
	await _appuyer_f()
	await _jouer_mini_jeu(rater)
	await _attendre(10)


func _apparus(prefixe: String) -> int:
	var n := 0
	for bete in get_nodes_in_group("loups"):
		if String(bete.type_ennemi).begins_with(prefixe) and bete.combat.est_vivant():
			n += 1
	return n


func _aller(zone: String) -> void:
	if zone != _zone_chargee:
		await _charger(zone)
		await _attendre(30)


## Joue une quête de bout en bout : on parle au donneur, puis chaque étape dans sa zone.
func _jouer(q: Dictionary) -> void:
	var id := String(q.id)
	await _aller(String(ZONE_PNJ[q.donneur]))
	_verifier(_marque(String(q.donneur)) == "!", "%s : un « ! » au-dessus de %s" % [id, q.donneur])
	_verifier(await _parler(String(q.donneur)) >= 3, "%s : %s propose la quête" % [id, q.donneur])
	_verifier(_etat(id) == 0, "%s : la quête commence" % id)
	var etapes: Array = q.etapes
	for i in etapes.size():
		var e: Dictionary = etapes[i]
		await _aller(String(e.ou))
		if _etat(id) != i:
			_verifier(false, "%s : étape %d attendue, état %d" % [id, i, _etat(id)])
			return
		if e.has("tuer"):
			await _attendre(30)
			var app: Dictionary = e.get("apparition", {})
			var n := _apparus(String(e.tuer))
			_verifier(n >= int(e.get("nombre", 1)), "%s : %d × %s apparaissent (%d)" % [id, int(e.get("nombre", 1)), e.tuer, n])
			var p: Array = app.get("position", [0, 0])
			var tues := 0
			var essais := 0
			while _etat(id) == i and essais < 8:
				essais += 1
				tues += _tuer_proches(Vector3(p[0], 0, p[1]), 400.0, String(e.tuer))
				await _attendre(20)
		elif e.has("recolter"):
			for oid in _sec._objets:
				if _etat(id) != i:
					break
				var o = _sec._objets[oid]
				if String(o.groupe) == String(e.recolter) and o.actif:
					await _utiliser(oid)
		elif e.has("objet"):
			await _utiliser(String(e.objet))
		elif e.has("pnj"):
			if _marque(String(e.pnj)) != "?":
				_verifier(false, "%s : un « ? » au-dessus de %s (« %s »)" % [id, e.pnj, _marque(String(e.pnj))])
			await _parler(String(e.pnj))
		var attendu: int = _sec.FINIE if i == etapes.size() - 1 else i + 1
		_verifier(_etat(id) == attendu, "%s : « %s » (état %d)" % [id, e.objectif, _etat(id)])
	var recues := true
	for r in q.get("recompense", []):
		recues = recues and _a_recu(String(r.id))
	_verifier(recues, "%s : récompense reçue" % id)


func _lancer() -> void:
	print("Test des quêtes secondaires (Rome)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	var cfg := ConfigFile.new()
	# L'histoire de Rome est finie : toutes les quêtes secondaires sont ouvertes.
	cfg.set_value("rome", "etape", "fin")
	cfg.save(FICHIER)
	await _charger("rome")
	var inventaire = _joueur.get_node("Inventaire")
	_sacs_avant = inventaire.etat.duplicate(true)
	for i in (inventaire.etat["cases"] as Array).size():
		inventaire.etat["cases"][i] = {}
	inventaire._sauvegarder()
	var progression = _joueur.get_node("Progression")
	_progression_avant = progression.etat.duplicate(true)
	progression.etat["faits"] = []
	_verifier(_sec != null, "les quêtes secondaires de Rome sont chargées")
	if _sec == null:
		quit(1)
		return
	_verifier(_sec.quetes.size() == 10, "dix quêtes secondaires (%d)" % _sec.quetes.size())
	_verifier(_sec._script_objet().resource_path.ends_with("objet_rome.gd"), "les objets utilisent le script de Rome")
	var cat: Dictionary = root.get_node("Donnees").objets
	var manquants: PackedStringArray = []
	var ennemis = JSON.parse_string(FileAccess.get_file_as_string("res://data/ennemis.json"))
	for q in _sec.quetes:
		for r in q.get("recompense", []):
			if not (cat["objets"] as Dictionary).has(String(r.id)):
				manquants.append(String(r.id))
		for e in q.etapes:
			if e.has("apparition") and not (ennemis as Dictionary).has(String(e.apparition.type)):
				manquants.append(String(e.apparition.type))
			if not ZONE_PNJ.has(String(q.donneur)) or (e.has("pnj") and not ZONE_PNJ.has(String(e.pnj))):
				manquants.append("pnj " + String(e.get("pnj", q.donneur)))
	_verifier(manquants.is_empty(), "récompenses, ennemis et personnages connus %s" % manquants)
	var formes_inconnues: PackedStringArray = []
	var essai = _sec._script_objet().new()
	for o in _sec.objets_def:
		if not essai.has_method("_construire_" + String(o.forme)):
			formes_inconnues.append(String(o.forme))
	essai.free()
	_verifier(formes_inconnues.is_empty(), "toutes les formes d'objets sont dessinées %s" % formes_inconnues)
	for zone in ["rome", "voie_appienne", "campagne", "pompei"]:
		await _aller(zone)
		_verifier_acces()

	# Sans le sceau, pas de mule ; sans le strigile, pas de Bain des thermes.
	await _aller("voie_appienne")
	var monture = _joueur.get_node("Monture")
	_verifier(String(monture.raison_impossible()).contains("sceau"), "pas encore de mule à Rome : « %s »" % monture.raison_impossible())
	var sans := String(Objets.changer_competence(cat, _joueur.get_node("Inventaire").etat.duplicate(true), 5, "bain_des_thermes"))
	_verifier(sans.begins_with("Il te faut"), "sans le strigile, pas de Bain des thermes : « %s »" % sans)

	# Les quêtes, rangées pour voyager le moins possible.
	var ordre := ["oies_du_capitole", "thermes_de_titus", "ecole_de_gladiateurs", "les_murs_parlent",
			"betes_de_carpophore", "gateau_de_caton", "poste_imperiale", "cave_canem", "intrus_modernes_rome", "ce_qu_a_vu_pline"]
	for id in ordre:
		var q: Dictionary = _sec.quete(id)
		await _jouer(q)
		match id:
			"oies_du_capitole":
				await _aller("rome")
				_verifier(not _objet("oie_perdue_0")._visuel.visible, "les oies retrouvées ne sont plus dans les rues")
			"thermes_de_titus":
				var c = _objet("chaudiere_thermes")
				_verifier(c != null and c._debout != null and c._debout.visible, "la chaudière des thermes est rallumée")
				var avec := String(Objets.changer_competence(cat, _joueur.get_node("Inventaire").etat.duplicate(true), 5, "bain_des_thermes"))
				_verifier(avec == "", "avec le strigile, le Bain des thermes va dans la barre (« %s »)" % avec)
			"poste_imperiale":
				await _aller("voie_appienne")
				monture = _joueur.get_node("Monture")
				_verifier(not String(monture.raison_impossible()).contains("sceau"), "la mule de la poste répond : « %s »" % monture.raison_impossible())
			"cave_canem":
				await _aller("pompei")
				_verifier(not _objet("chien_fausta")._visuel.visible, "Ferox a quitté le seuil de la maison")
	_verifier(_sec.titres.has("Témoin du Vésuve"), "titre obtenu : « Témoin du Vésuve »")
	_verifier(_sec.titres.has("Gladiateur du Ludus"), "titre obtenu : « Gladiateur du Ludus »")
	var toutes := true
	for q in _sec.quetes:
		toutes = toutes and _etat(q.id) == _sec.FINIE
	_verifier(toutes, "les dix quêtes secondaires de Rome sont terminées")

	# L'oie compagnon : elle suit au sol, et cacarde quand un prétorien approche.
	await _aller("rome")
	var compagnon = load("res://scripts/joueur/compagnon.gd").new()
	compagnon.name = "Compagnon"
	compagnon.espece = "oie"
	_joueur.add_child(compagnon)
	await _attendre(40)
	var ecart: Vector3 = compagnon.global_position - _joueur.global_position
	_verifier(Vector2(ecart.x, ecart.z).length() < 2.5 and absf(ecart.y) < 0.8, "Cornélia suit au sol, derrière toi (%s)" % ecart)
	_verifier(not compagnon.crie(), "pas de danger : l'oie se tait")
	var garde = load("res://scenes/ennemis/loup.tscn").instantiate()
	garde.type_ennemi = "pretorien_janus"
	_scene.add_child(garde)
	garde.global_position = _joueur.global_position + Vector3(6, 0, 0)
	await _attendre(30)
	_verifier(compagnon.crie(), "un prétorien approche : l'oie cacarde")
	garde.queue_free()
	compagnon.queue_free()

	var lu := ConfigFile.new()
	lu.load(Profil.chemin(FICHIER))
	_verifier(int(lu.get_value("rome_secondaires", "etat_cave_canem", -1)) == _sec.FINIE, "les quêtes de Rome sont sauvegardées à part")

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
