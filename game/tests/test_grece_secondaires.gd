extends SceneTree
## Test automatique des quêtes secondaires de la Grèce (data/grece_secondaires.json) :
## les « ! » au-dessus des donneurs, chaque objet accessible (pas dans un mur), puis les
## dix quêtes jouées de bout en bout dans leurs zones, avec leurs mini-jeux (kottabos,
## chœur, poulain) : Athènes (Hérodote, Markos, la palestre, Sophocle, Aspasie), le Pirée
## (Lysimaque), les Oliveraies (Néra, Myrtô, Ktésippe, Théano). Puis les récompenses :
## la monture de Lysimaque, l'Huile d'athlète, la chouette compagnon, les titres.
## Lancement : godot --headless --path game -s res://tests/test_grece_secondaires.gd

const FICHIER := "user://test_grece_secondaires.cfg"
const SCENES := "res://scenes/monde/grece/%s.tscn"

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


func _lancer() -> void:
	print("Test des quêtes secondaires (Grèce)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	var cfg := ConfigFile.new()
	# Chapitre 7 en cours (les voix à rallier) : toute l'île est ouverte, et ni Aspasie ni
	# Lysimaque ne sont occupés par la quête principale.
	cfg.set_value("grece", "etape", "rallier")
	cfg.save(FICHIER)
	await _charger("athenes")
	var inventaire = _joueur.get_node("Inventaire")
	_sacs_avant = inventaire.etat.duplicate(true)
	for i in (inventaire.etat["cases"] as Array).size():
		inventaire.etat["cases"][i] = {}
	inventaire._sauvegarder()
	var progression = _joueur.get_node("Progression")
	_progression_avant = progression.etat.duplicate(true)
	progression.etat["faits"] = []
	_verifier(_sec != null, "les quêtes secondaires de la Grèce sont chargées")
	if _sec == null:
		quit(1)
		return
	_verifier(_sec.quetes.size() == 10, "dix quêtes secondaires (%d)" % _sec.quetes.size())
	_verifier(_sec._script_objet().resource_path.ends_with("objet_grece.gd"), "les objets utilisent le script de la Grèce")
	var cat: Dictionary = root.get_node("Donnees").objets
	var manquants: PackedStringArray = []
	for q in _sec.quetes:
		for r in q.get("recompense", []):
			if not (cat["objets"] as Dictionary).has(String(r.id)):
				manquants.append(String(r.id))
	_verifier(manquants.is_empty(), "toutes les récompenses existent dans objets.json %s" % manquants)
	await _attendre(40)
	for id_pnj in ["herodote", "markos", "hippomachos", "sophocle", "aspasie"]:
		_verifier(_marque(id_pnj) == "!", "un « ! » doré au-dessus de %s" % id_pnj)
	_verifier_acces()

	# --- Les derniers de Marathon (Hérodote) : Mélanthios, au Céramique.
	_verifier(await _parler("herodote") >= 3, "Hérodote parle de son enquête")
	_verifier(_etat("derniers_de_marathon") == 0, "« Les derniers de Marathon » commence")
	_verifier(_marque("veteran_melanthios") == "?", "un « ? » au-dessus de Mélanthios")
	await _parler("veteran_melanthios")
	_verifier(_etat("derniers_de_marathon") == 1, "Mélanthios a raconté la course sous les flèches")

	# --- Les intrus modernes (Markos).
	await _parler("markos")
	_verifier(_etat("intrus_modernes_grece") == 0, "« Les intrus modernes » commence")
	for id in ["moderne_pnyx", "moderne_portique", "moderne_theatre"]:
		await _utiliser(id)
	_verifier(_etat("intrus_modernes_grece") == 3, "mégaphone, affiche et caméra ramassés")
	_verifier(not _objet("moderne_pnyx")._visuel.visible, "le mégaphone a disparu de la Pnyx")
	await _parler("markos")
	_verifier(_etat("intrus_modernes_grece") == _sec.FINIE and _a_recu("montre_vigie"), "Markos offre la montre de la Vigie")

	# --- La palestre (Hippomachos).
	await _parler("hippomachos")
	_verifier(_etat("la_palestre") == 0, "« La palestre » commence")
	await _attendre(30)
	_verifier(_apparus("athlete_lutteur") >= 3, "trois lutteurs attendent dans le sable (%d)" % _apparus("athlete_lutteur"))
	_tuer_proches(Vector3(-128, 0, -63), 20.0, "athlete_lutteur")
	await _attendre(20)
	_verifier(_etat("la_palestre") == 1, "les lutteurs au sol : la course commence")
	for k in 4:
		await _utiliser("borne_gymnase_%d" % k)
	_verifier(_etat("la_palestre") == 2, "les quatre bornes du gymnase sont touchées")
	_verifier(_objet("borne_gymnase_0")._visuel.visible, "les bornes restent à leur place")
	await _attendre(30)
	_verifier(_apparus("athlete_champion") == 1, "Autolykos, le champion, entre dans le sable")
	_tuer_proches(Vector3(-128, 0, -63), 20.0, "athlete_champion")
	await _attendre(20)
	await _parler("hippomachos")
	_verifier(_etat("la_palestre") == _sec.FINIE and _a_recu("perizoma_athlete"), "Hippomachos offre le perizoma d'athlète")
	_verifier(_sec.titres.has("Athlète des Panathénées"), "titre obtenu : « Athlète des Panathénées »")

	# --- Le chœur de Sophocle : le mini-jeu de rythme (un faux pas, puis le bon rythme).
	await _parler("sophocle")
	_verifier(_etat("choeur_de_sophocle") == 0, "« Le chœur de Sophocle » commence")
	await _utiliser_jeu("place_choeur", 1)
	_verifier(_etat("choeur_de_sophocle") == 1, "la danse du chœur est réussie (malgré un faux pas)")
	await _parler("sophocle")
	_verifier(_etat("choeur_de_sophocle") == _sec.FINIE and _a_recu("masque_choreute"), "Sophocle offre un masque de choreute")

	# --- Le banquet (Aspasie) : le kottabos. D'abord une partie perdue, puis gagnée.
	await _parler("aspasie")
	_verifier(_etat("banquet_d_aspasie") == 0, "« Le banquet » commence")
	await _utiliser_jeu("banquet_aspasie", 3)
	_verifier(_etat("banquet_d_aspasie") == 0, "trois gouttes à côté : la partie est perdue, on peut rejouer")
	await _appuyer_f()
	await _jouer_mini_jeu(0)
	await _attendre(10)
	_verifier(_etat("banquet_d_aspasie") == 1, "deux disques tombés : la partie de kottabos est gagnée")
	await _parler("aspasie")
	_verifier(_etat("banquet_d_aspasie") == _sec.FINIE and _a_recu("kylix_aspasie"), "Aspasie offre sa coupe à kottabos")

	# --- Au Pirée : Lysimaque et son poulain.
	await _charger("le_piree")
	await _attendre(40)
	_verifier(_marque("lysimaque") == "!", "un « ! » au-dessus de Lysimaque")
	_verifier_acces()
	var monture = _joueur.get_node("Monture")
	_verifier(String(monture.raison_impossible()).contains("dresser"), "pas encore de monture en Grèce : « %s »" % monture.raison_impossible())
	await _parler("lysimaque")
	_verifier(_etat("cheval_de_lysimaque") == 0, "« Le cheval de Lysimaque » commence")
	var texte := ""
	for l in _sec._liste.get_children():
		if l is Label:
			texte += l.text + "\n"
	_verifier(texte.contains("Oliveraies"), "la liste indique que le poulain est dans les Oliveraies")

	# --- Les Oliveraies.
	await _charger("oliveraies")
	await _attendre(40)
	for id_pnj in ["nera", "myrto", "paysan_ktesippe", "pretresse"]:
		_verifier(_marque(id_pnj) == "!", "un « ! » doré au-dessus de %s" % id_pnj)
	_verifier(_marque("veteran_epizelos") == "?", "un « ? » au-dessus d'Épizélos")
	_verifier_acces()
	await _utiliser_jeu("poulain", 1)
	_verifier(_etat("cheval_de_lysimaque") == 1, "le poulain est dressé")
	await _parler("veteran_epizelos")
	_verifier(_etat("derniers_de_marathon") == 2, "Épizélos raconte le géant barbu")

	# La chouette de Néra.
	await _parler("nera")
	_verifier(_etat("chouette_de_nera") == 0, "« La chouette de Néra » commence")
	await _attendre(30)
	_verifier(_apparus("vipere_fracture_olivier") >= 3, "des vipères gardent l'olivier sacré")
	_tuer_proches(Vector3(-70, 0, -58), 20.0, "vipere_fracture_olivier")
	await _attendre(20)
	_verifier(_etat("chouette_de_nera") == 1, "les vipères chassées : il faut recueillir la chouette")
	await _utiliser("chouette_nera")
	for k in 3:
		await _utiliser("cigales_%d" % k)
	_verifier(_etat("chouette_de_nera") == 3, "la chouette recueillie et nourrie de cigales")
	await _parler("nera")
	_verifier(_etat("chouette_de_nera") == _sec.FINIE and _a_recu("glauke_chouette"), "Néra confie Glaukê, la petite chouette")

	# Le miel d'Hymette.
	await _parler("myrto")
	_verifier(_etat("miel_d_hymette") == 0, "« Le miel d'Hymette » commence")
	for k in 3:
		await _utiliser("essaim_%d" % k)
	for k in 4:
		await _utiliser("thym_%d" % k)
	_verifier(_etat("miel_d_hymette") == 2, "trois essaims et quatre touffes de thym")
	await _parler("myrto")
	_verifier(_etat("miel_d_hymette") == _sec.FINIE and _a_recu("gateau_miel_sesame") and _a_recu("miel_hymette"), "Myrtô offre gâteaux et miel")

	# Le sanglier de l'Hymette.
	await _parler("paysan_ktesippe")
	_verifier(_etat("sanglier_de_l_hymette") == 0, "« Le sanglier de l'Hymette » commence")
	for k in 3:
		await _utiliser("traces_sanglier_%d" % k)
	_verifier(_etat("sanglier_de_l_hymette") == 1, "les traces mènent à la montagne")
	await _attendre(30)
	_verifier(_apparus("sanglier_hymette") == 1, "le grand sanglier est là")
	_tuer_proches(Vector3(112, 0, 52), 25.0, "sanglier_hymette")
	await _attendre(20)
	await _parler("paysan_ktesippe")
	_verifier(_etat("sanglier_de_l_hymette") == _sec.FINIE and _a_recu("chlamyde_chasseur") and _a_recu("petase"), "Ktésippe offre chlamyde et pétase")

	# Les oliviers sacrés.
	await _parler("pretresse")
	_verifier(_etat("oliviers_sacres") == 0, "« Les oliviers sacrés » commence")
	await _attendre(30)
	_tuer_proches(Vector3(-84, 0, -50), 25.0, "loup_fracture_sanctuaire")
	await _attendre(20)
	_verifier(_etat("oliviers_sacres") == 1, "les loups chassés du sanctuaire")
	for k in 4:
		await _utiliser("olives_%d" % k)
	await _utiliser("pressoir_sanctuaire")
	_verifier(_etat("oliviers_sacres") == 3, "les olives sacrées sont pressées")
	var amphore = _objet("pressoir_sanctuaire")._visuel.get_node_or_null("Amphore")
	_verifier(amphore != null and amphore.visible, "l'amphore d'huile apparaît sous le pressoir")
	inventaire = _joueur.get_node("Inventaire")
	var avant := String(Objets.changer_competence(cat, inventaire.etat.duplicate(true), 5, "huile_d_athlete"))
	_verifier(avant.begins_with("Il te faut"), "sans l'amphore, pas d'Huile d'athlète : « %s »" % avant)
	await _parler("pretresse")
	_verifier(_etat("oliviers_sacres") == _sec.FINIE and _a_recu("amphore_huile_sacree"), "Théano offre l'amphore d'huile sacrée")
	inventaire = _joueur.get_node("Inventaire")
	var apres := String(Objets.changer_competence(cat, inventaire.etat.duplicate(true), 5, "huile_d_athlete"))
	_verifier(apres == "", "avec l'amphore, l'Huile d'athlète va dans la barre (« %s »)" % apres)

	# La chouette compagnon (même sans écran, elle doit pouvoir se poser sur l'épaule).
	var compagnon = load("res://scripts/joueur/compagnon.gd").new()
	compagnon.name = "Compagnon"
	_joueur.add_child(compagnon)
	await _attendre(20)
	_verifier(compagnon.global_position.distance_to(_joueur.global_position + Vector3(0, 1.5, 0)) < 1.2, "Glaukê se pose sur l'épaule (%s)" % (compagnon.global_position - _joueur.global_position))
	compagnon.queue_free()

	# --- Retour au Pirée : le poulain, puis Diphilos.
	await _charger("le_piree")
	await _parler("lysimaque")
	_verifier(_etat("cheval_de_lysimaque") == _sec.FINIE and _a_recu("bride_lysimaque"), "Lysimaque donne la bride")
	await _attendre(5)
	monture = _joueur.get_node("Monture")
	_verifier(not String(monture.raison_impossible()).contains("dresser"), "le poulain répond à l'appel : « %s »" % monture.raison_impossible())
	await _parler("veteran_diphilos")
	_verifier(_etat("derniers_de_marathon") == 3, "Diphilos raconte les rameurs de Salamine")

	# --- Retour à Athènes : Hérodote écrit.
	await _charger("athenes")
	await _parler("herodote")
	_verifier(_etat("derniers_de_marathon") == _sec.FINIE and _a_recu("pointe_lance_marathon"), "Hérodote offre la pointe de lance de Marathon")
	_verifier(_sec.titres.has("Témoin d'Hérodote"), "titre obtenu : « Témoin d'Hérodote »")
	var toutes := true
	for q in _sec.quetes:
		toutes = toutes and _etat(q.id) == _sec.FINIE
	_verifier(toutes, "les dix quêtes secondaires de la Grèce sont terminées")

	# --- La sauvegarde.
	var lu := ConfigFile.new()
	lu.load(Profil.chemin(FICHIER))
	_verifier(int(lu.get_value("grece_secondaires", "etat_la_palestre", -1)) == _sec.FINIE, "les quêtes de la Grèce sont sauvegardées à part")

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
