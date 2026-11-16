extends SceneTree
## Test automatique d'Athènes (Grèce, zone 3) et de la fin du chapitre 3 : l'arrivée par
## la porte du sud, l'Agora muette, Socrate, l'interrogatoire de Kallias (une mauvaise
## réponse, puis la bonne), les Pétrifiés à qui l'on rend la voix, le potier Lydos au
## Céramique, les chiens et la faille du Portique peint, le manteau de Socrate ; puis le
## chapitre 4 (l'or de Phidias, la pesée au tribunal, et les deux choix pour Ménon).
## Lancement : godot --headless --path game -s res://tests/test_athenes.gd

const FICHIER := "user://test_grece_athenes.cfg"
const ATHENES := "res://scenes/monde/grece/athenes.tscn"

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


func _lancer() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	# On reprend au moment où l'on franchit la porte d'Athènes avec Socrate.
	var cfg := ConfigFile.new()
	cfg.set_value("grece", "etape", "entrer_athenes")
	cfg.save(FICHIER)
	await _charger(ATHENES)
	print("Test d'Athènes (Grèce, fin du chapitre 3)")

	# --- La ville.
	_verifier(_joueur != null and _joueur.is_on_floor(), "on arrive dans Athènes, debout")
	var p: Vector3 = _joueur.global_position
	_verifier(p.z > 120.0 and absf(p.x) < 10.0, "juste derrière la porte du sud (%.0f, %.0f)" % [p.x, p.z])
	_verifier(_id_etape() == "markos_ville", "l'arrivée termine l'étape de la porte (%s)" % _id_etape())
	for nom in ["Agora", "PortiquePeint", "Tholos", "Bouleuterion", "Hephaisteion", "Ceramique", "Pnyx", "Parthenon", "Theatre", "Quartiers"]:
		_verifier(_scene.find_child(nom, true, false) != null, "Athènes a son %s" % nom)
	var haut_acropole: float = _scene.hauteur(_scene.ACROPOLE.x, _scene.ACROPOLE.y)
	_verifier(haut_acropole > _scene.H_AGORA + 30.0, "le rocher de l'Acropole domine la ville (%.0f m)" % haut_acropole)
	_verifier(absf(_scene.hauteur(-10, -10) - _scene.H_AGORA) < 0.05, "l'Agora est plate")
	_verifier(_scene.hauteur(_scene.ORCHESTRE.x, _scene.ORCHESTRE.y - 28.0) > _scene.H_ORCHESTRE + 8.0, "les gradins du théâtre montent vers le rocher")
	_verifier(_vivants("chien_fracture_ville").size() >= 5, "des chiens errants fracturés en ville (%d)" % _vivants("chien_fracture_ville").size())
	var maisons := 0
	for n in _scene.find_child("Quartiers", true, false).find_children("*", "StaticBody3D", true, false):
		maisons += 1
	_verifier(maisons > 300, "des centaines de maisons, avec leurs murs (%d)" % maisons)
	# On ne monte pas sur l'Acropole (le donjon, plus tard).
	await _placer(Vector3(100, _scene.hauteur(100, 46) + 0.4, 46), 0.0)
	Input.action_press("avancer")
	await _attendre(150)
	Input.action_release("avancer")
	_verifier(_joueur.global_position.y < _scene.H_AGORA + 20.0, "on ne grimpe pas sur l'Acropole (y = %.0f)" % _joueur.global_position.y)

	# --- Le chapitre 3, à Athènes.
	var lues := await _parler("Markos")
	_verifier(lues >= 3, "Markos s'émerveille devant Socrate (%d bulles)" % lues)
	_verifier(_id_etape() == "agora", "direction l'Agora (%s)" % _id_etape())
	await _placer(Vector3(-10, _scene.H_AGORA + 0.4, 2), 0.0)
	await _attendre(20)
	_verifier(_id_etape() == "socrate_agora", "l'Agora est muette (%s)" % _id_etape())
	var socrate: Node3D = _scene.find_child("Socrate", true, false)
	_verifier(socrate != null and socrate.global_position.z < -30.0, "Socrate attend devant le Portique peint")
	lues = await _parler("Socrate")
	_verifier(lues >= 3, "Socrate explique sa méthode (%d bulles)" % lues)
	_verifier(_id_etape() == "kallias", "il faut écouter Kallias (%s)" % _id_etape())
	lues = await _parler("Kallias")
	_verifier(lues >= 4, "Kallias témoigne (%d bulles)" % lues)
	_verifier(_id_etape() == "question_kallias", "il faut trouver la contradiction (%s)" % _id_etape())
	lues = await _repondre("ReponseKalliasFievre", -1.0)
	_verifier(lues >= 3, "une mauvaise réponse : Socrate donne un indice (%d bulles)" % lues)
	_verifier(_id_etape() == "question_kallias", "une mauvaise réponse ne fait pas avancer (%s)" % _id_etape())
	lues = await _repondre("ReponseKalliasParle", -1.0)
	_verifier(lues >= 4, "la bonne réponse : Kallias avoue (%d bulles)" % lues)
	_verifier(_id_etape() == "petrifies", "les Pétrifiés se réveillent (%s)" % _id_etape())
	await _attendre(20)
	var petrifies := _vivants("petrifie")
	_verifier(petrifies.size() == 3, "trois Pétrifiés sur l'Agora (%d)" % petrifies.size())
	if not petrifies.is_empty():
		var apparence = petrifies[0].get_node("Apparence").get("_delegue")
		_verifier(apparence != null and apparence.get("variante") == "petrifie", "un Athénien à moitié changé en marbre")
	await _tuer_tous("petrifie", "petrifies")
	await _attendre(20)
	var voix := []
	for o in get_nodes_in_group("objet_quete"):
		if o.get("groupe") == "voix_rendue":
			voix.append(o)
	_verifier(voix.size() == 3, "on peut rendre la voix aux trois Pétrifiés (%d)" % voix.size())
	for o in voix:
		await _aller_cote(o, 1.0)
		await _appuyer_f()
		await _attendre(200)
	await _attendre(10)
	_verifier(_id_etape() == "cherephon", "les Pétrifiés ont retrouvé la voix (%s)" % _id_etape())
	_verifier(_scene.find_child("PetrifieCherephon", true, false) != null, "Chéréphon est redevenu lui-même")
	lues = await _parler("Socrate")
	_verifier(_id_etape() == "ceramique", "Socrate envoie au Céramique (%s)" % _id_etape())
	await _placer(Vector3(-112, _scene.hauteur(-112, -96) + 0.4, -96), 0.0)
	await _attendre(20)
	_verifier(_id_etape() == "lydos", "on arrive chez les potiers (%s)" % _id_etape())
	lues = await _parler("Lydos")
	_verifier(lues >= 3, "Lydos témoigne (%d bulles)" % lues)
	lues = await _repondre("ReponseLydosVases", 1.0)
	_verifier(_id_etape() == "question_lydos", "regarder les vases ne prouve rien (%s)" % _id_etape())
	lues = await _repondre("ReponseLydosFour", 1.0)
	_verifier(lues >= 4, "le four qui fume : Lydos avoue (%d bulles)" % lues)
	_verifier(_id_etape() == "chiens_poikile", "au Portique peint ! (%s)" % _id_etape())
	await _placer(Vector3(-14, _scene.H_AGORA + 0.4, -36), 0.0)
	await _attendre(30)
	_verifier(_vivants("chien_fracture_agora").size() == 3, "trois chiens fracturés sous le portique")
	await _tuer_tous("chien_fracture_agora", "chiens_poikile")
	await _attendre(5)
	_verifier(_id_etape() == "faille_poikile", "les chiens sont chassés (%s)" % _id_etape())
	var faille: Node3D = _scene.find_child("Faille", true, false)
	await _aller_cote(faille, 1.2)
	await _appuyer_f()
	await _attendre(380)
	_verifier(_id_etape() == "socrate_fin", "la faille du Portique peint est refermée (%s)" % _id_etape())
	_verifier(not _scene.find_child("MasquesPoikile", true, false).visible, "les masques d'argile sont détruits")
	lues = await _parler("Socrate")
	_verifier(lues >= 4, "Socrate parle d'Aspasie (%d bulles)" % lues)
	var inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("tribon_socrate") >= 1, "le tribôn de Socrate est dans le sac")
	_verifier(_id_etape() == "aspasie", "chapitre 4 : Aspasie attend le joueur (%s)" % _id_etape())

	# --- La progression est gardée, et la porte du sud ramène aux Oliveraies.
	await _charger(ATHENES)
	await _attendre(20)
	_verifier(_id_etape() == "aspasie", "au retour, la quête reprend où on l'avait laissée (%s)" % _id_etape())
	_verifier(_scene.find_child("PetrifieCherephon", true, false) != null, "Chéréphon est toujours là")
	_verifier(not _scene.find_child("MasquesPoikile", true, false).visible, "les masques ne reviennent pas")
	await _placer(Vector3(0, _scene.hauteur(0, 142) + 0.4, 142), PI)
	Input.action_press("avancer")
	await _attendre(90)
	Input.action_release("avancer")
	await _attendre(60)
	_verifier(_quete.zone_demandee == "oliveraies", "la porte du sud ramène aux Oliveraies (%s)" % _quete.zone_demandee)

	# --- Chapitre 4 : « L'or de Phidias ».
	await _charger(ATHENES)
	print("Chapitre 4")
	for nom in ["Heliee", "AtelierPhidias", "MaisonAspasie"]:
		_verifier(_scene.find_child(nom, true, false) != null, "Athènes a son %s" % nom)
	lues = await _parler("Aspasie")
	_verifier(lues >= 5, "Aspasie raconte l'accusation de Ménon (%d bulles)" % lues)
	_verifier(_id_etape() == "phidias", "direction l'atelier de Phidias (%s)" % _id_etape())
	lues = await _parler("Phidias")
	_verifier(_id_etape() == "plaques", "il faut rassembler les plaques d'or (%s)" % _id_etape())
	for k in 4:
		await _aller_cote(_scene.find_child("Plaque%d" % k, true, false), 1.0)
		await _appuyer_f()
		await _attendre(130)
	_verifier(_id_etape() == "tribunal", "les quatre plaques sont rassemblées (%s)" % _id_etape())
	var phidias: Node3D = _scene.find_child("Phidias", true, false)
	_verifier(phidias != null and Vector2(phidias.global_position.x, phidias.global_position.z).distance_to(Vector2(-22, 46)) < 2.0, "Phidias part au tribunal")
	await _placer(Vector3(-24, _scene.hauteur(-24, 40) + 0.4, 40), 0.0)
	await _attendre(20)
	_verifier(_id_etape() == "pesee", "au tribunal (%s)" % _id_etape())
	lues = await _repondre("PeserMenonSeul", 0.0, 1.0)
	_verifier(lues >= 3 and _id_etape() == "pesee", "les poids de Ménon seuls : il manque de l'or ?! (%s)" % _id_etape())
	lues = await _repondre("PeserTresor", 0.0, 1.0)
	_verifier(lues >= 5, "les poids de Ménon sont truqués (%d bulles)" % lues)
	_verifier(_id_etape() == "choix_menon", "que faire de Ménon ? (%s)" % _id_etape())
	lues = await _repondre("DemasquerMenon", 0.0, 1.0)
	_verifier(_id_etape() == "bagarre_tribunal", "on démasque Ménon : les Masqués attaquent (%s)" % _id_etape())
	await _attendre(30)
	var masques := _vivants("masque_tribunal")
	_verifier(masques.size() == 3, "trois Masqués dans le tribunal (%d)" % masques.size())
	if not masques.is_empty():
		var apparence = masques[0].get_node("Apparence").get("_delegue")
		_verifier(apparence != null and apparence.get("variante") == "masque", "un Masqué porte un masque de théâtre")
	await _tuer_tous("masque_tribunal", "bagarre_tribunal")
	await _attendre(5)
	_verifier(_id_etape() == "phidias_merci", "le tribunal est sauvé (%s)" % _id_etape())
	lues = await _parler("Phidias")
	_verifier(lues >= 3, "Phidias est acquitté (%d bulles)" % lues)
	_verifier(_quete.etape < 0, "la suite (chapitre 5) arrive bientôt")

	# --- L'autre choix : laisser filer Ménon et le suivre.
	var cfg2 := ConfigFile.new()
	cfg2.set_value("grece", "etape", "choix_menon")
	cfg2.save(FICHIER)
	await _charger(ATHENES)
	print("Chapitre 4, l'autre choix")
	_verifier(_id_etape() == "choix_menon", "on reprend au choix (%s)" % _id_etape())
	await _repondre("SuivreMenon", 0.0, 1.0)
	_verifier(_id_etape() == "filature_pnyx", "on suit Ménon vers la Pnyx (%s)" % _id_etape())
	await _placer(Vector3(-74, _scene.hauteur(-74, 62) + 0.4, 62), 0.0)
	await _attendre(20)
	_verifier(_id_etape() == "filature_ceramique", "puis vers le Céramique (%s)" % _id_etape())
	await _placer(Vector3(-128, _scene.hauteur(-128, -118) + 0.4, -118), 0.0)
	await _attendre(20)
	_verifier(_id_etape() == "jeton", "Ménon a rencontré un masqué (%s)" % _id_etape())
	await _repondre("JetonLaurion", 1.0, 0.0)
	await _attendre(10)
	_verifier(_id_etape() == "phidias_merci", "un jeton des mines du Laurion (%s)" % _id_etape())
	_verifier(_vivants("masque_tribunal").is_empty(), "pas de bagarre dans ce choix-là")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
