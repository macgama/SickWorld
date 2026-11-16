extends SceneTree
## Test automatique du Pirée (Grèce, zone 1) et des chapitres 1 et 2 :
## Glaukos, le sac de Markos, les chiens, la balise, le poulpe de la crique, la faille,
## puis le port : Lysimaque, Markos dans l'enclos, Phormion, la Paralos (ramer en
## cadence), les chiens et le molosse des loges, la libération de Markos.
## Lancement : godot --headless --path game -s res://tests/test_le_piree.gd

const FICHIER := "user://test_grece_progression.cfg"
const SCENE := "res://scenes/monde/grece/le_piree.tscn"

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


func _charger() -> void:
	_scene = load(SCENE).instantiate()
	_quete = _scene.get_node("Quete")
	_quete.fichier_progression = FICHIER
	_quete.voyage_reel = false
	root.add_child(_scene)
	await _attendre(40)
	_joueur = get_first_node_in_group("joueur_local")
	_dialogue = get_first_node_in_group("dialogue")


func _lancer() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	await _charger()
	print("Test du Pirée (Grèce)")

	# --- Le monde.
	_verifier(_joueur != null, "un personnage arrive sur l'île")
	var p: Vector3 = _joueur.global_position
	_verifier(Vector2(p.x, p.z).distance_to(_scene.PORTAIL) < 9.0, "juste devant le portail de la Vigie")
	_verifier(_joueur.is_on_floor(), "il a pied dans la crique (y = %.2f)" % p.y)
	_verifier(_scene.hauteur(p.x, p.z) < _scene.NIVEAU_MER, "il a de l'eau jusqu'aux genoux (fond à %.2f)" % _scene.hauteur(p.x, p.z))
	var bassin: Vector2 = _scene.BASSIN.get_center()
	_verifier(_scene.hauteur(bassin.x, bassin.y) < _scene.NIVEAU_MER - 2.0, "le bassin du Kantharos est profond")
	_verifier(_scene.hauteur(0, 150) < _scene.NIVEAU_MER - 3.0, "la mer s'étend au sud")
	_verifier(_scene.hauteur(-14, 22) > _scene.NIVEAU_MER + 1.0, "les quais de l'arsenal sont au sec")
	_verifier(_scene.hauteur(-88, 96) > _scene.hauteur(-60, 110) + 8.0, "la colline de l'Akté domine la crique")
	_verifier(get_first_node_in_group("balises") != null, "une balise de la Vigie permet de réapparaître")
	_verifier(_vivants("chien_fracture").size() >= 5, "des chiens fracturés rôdent (%d)" % _vivants("chien_fracture").size())
	var chien = _vivants("chien_fracture")[0] if not _vivants("chien_fracture").is_empty() else null
	_verifier(chien != null and chien.get_node("Apparence").get("espece") == "loup", "les chiens ont un corps d'animal")
	_verifier(_scene.find_child("Paralos", true, false) != null, "la Paralos est amarrée au quai")
	_verifier(_scene.find_child("TriereAuSec0", true, false) != null, "des trières sont au sec dans les loges")
	_verifier(_scene.find_child("AcropoleLointaine", true, false) != null, "l'Acropole se dresse au loin")
	_verifier(_scene.find_child("Emporion", true, false) != null, "le grand portique du commerce borde le bassin")

	# Le chemin côtier mène de la crique au port.
	for point in _scene.CHEMIN:
		_verifier(_scene.hauteur(point.x, point.y) > _scene.NIVEAU_MER - 0.6, "on a pied sur le chemin côtier en (%d, %d)" % [point.x, point.y])

	# Trop loin dans la mer : on regagne la rive.
	await _placer(Vector3(-60, _scene.hauteur(-60, 110) + 0.3, 110), 0.0)
	await _attendre(15)
	_joueur.teleporter(Vector3(0, 0.5, 150), 0.0)
	await _attendre(30)
	_verifier(_joueur.global_position.z < 130.0, "en eau profonde, on est ramené au bord (z = %.0f)" % _joueur.global_position.z)

	# --- Chapitre 1 : Le naufragé.
	_verifier(_id_etape() == "rencontre_glaukos", "la quête commence : rencontrer Glaukos (%s)" % _id_etape())
	var lues := await _parler("Glaukos")
	_verifier(lues >= 4, "Glaukos accueille l'étranger (%d bulles)" % lues)
	_verifier(_id_etape() == "sac_markos", "il faut récupérer le sac de Markos (%s)" % _id_etape())
	await _aller_pres(_scene.find_child("SacMarkos", true, false))
	await _appuyer_f()
	await _attendre(160)
	_verifier(_id_etape() == "chiens", "le sac est dégagé (%s)" % _id_etape())
	var combat_joueur = _joueur.get_node("Combat")
	for bete in _vivants("chien_fracture"):
		bete.combat.subir(99999.0, combat_joueur)
		await _attendre(3)
		if _id_etape() != "chiens":
			break
	await _attendre(5)
	_verifier(_id_etape() == "balise", "les chiens fracturés sont vaincus (%s)" % _id_etape())
	await _aller_pres(_scene.find_child("PointBalise", true, false))
	await _appuyer_f()
	await _attendre(300)
	_verifier(_id_etape() == "rapport_glaukos", "la balise est plantée (%s)" % _id_etape())
	_verifier(_scene.find_child("BaliseInstallee", true, false).visible, "le fanal de la balise brille")
	await _parler("Glaukos")
	_verifier(_id_etape() == "poulpe", "Glaukos parle du poulpe (%s)" % _id_etape())
	await _attendre(5)
	var poulpe := _vivants("poulpe_fracture")
	_verifier(poulpe.size() == 1, "le poulpe fracturé garde le haut-fond")
	if poulpe.size() == 1:
		_verifier(poulpe[0].get_node("Apparence").get("_delegue") != null, "il a un corps de poulpe (huit bras)")
		poulpe[0].combat.subir(999999.0, combat_joueur)
	await _attendre(10)
	_verifier(_id_etape() == "filets", "le poulpe est vaincu (%s)" % _id_etape())
	var filets = _scene.find_child("FiletsGlaukos", true, false)
	await _placer(Vector3(filets.global_position.x, _scene.hauteur(filets.global_position.x, filets.global_position.z + 1.2) + 0.3, filets.global_position.z + 1.2), 0.0)
	await _appuyer_f()
	await _attendre(130)
	_verifier(_id_etape() == "faille_glaukos", "les filets sont récupérés (%s)" % _id_etape())
	await _parler("Glaukos")
	_verifier(_id_etape() == "faille", "Glaukos montre la faille (%s)" % _id_etape())
	await _attendre(5)
	for bete in _vivants("chien_fracture_faille"):
		bete.combat.subir(99999.0, combat_joueur)
	await _attendre(5)
	var faille = _scene.find_child("Faille", true, false)
	await _aller_pres(faille)
	await _appuyer_f()
	await _attendre(360)
	_verifier(faille.fermee, "la faille de l'Akté est refermée")
	_verifier(_id_etape() == "fin_chapitre_1", "rapport final (%s)" % _id_etape())
	lues = await _parler("Glaukos")
	_verifier(lues >= 3, "Glaukos envoie chez Lysimaque (%d bulles)" % lues)

	# --- Chapitre 2 : Le Xénos.
	_verifier(_id_etape() == "vers_le_port", "chapitre 2 : suivre la côte jusqu'au port (%s)" % _id_etape())
	await _placer(Vector3(-14, _scene.hauteur(-14, 22) + 0.5, 22), PI)
	await _attendre(30)
	_verifier(_id_etape() == "rencontre_lysimaque", "arrivée devant les loges (%s)" % _id_etape())
	await _parler("Lysimaque")
	lues = await _parler("Markos")
	_verifier(lues >= 4, "Markos raconte tout à travers les barreaux (%d bulles)" % lues)
	await _parler("Phormion")
	_verifier(_id_etape() == "embarquer", "Phormion met l'étranger à l'épreuve (%s)" % _id_etape())

	# La Paralos : il faut ramer en cadence.
	var triere = _scene.find_child("Paralos", true, false)
	var depart: Vector3 = triere.global_position
	await _aller_pres(_scene.find_child("MonterTriere", true, false))
	await _appuyer_f()
	await _attendre(10)
	_verifier(_id_etape() == "triere_cadence", "à bord de la Paralos (%s)" % _id_etape())
	_verifier(triere.en_route, "la trière part à l'entraînement")
	_verifier(_joueur.global_position.distance_to(triere.global_position) < 8.0, "le joueur est sur le pont")
	# Des coups à contretemps la font à peine avancer.
	for k in 5:
		while triere.en_cadence():
			await physics_frame
		triere.ramer()
		await _attendre(20)
	var apres_rates: float = triere._cible
	_verifier(triere.coups_rates == 5 and apres_rates < 20.0, "à contretemps, la trière avance à peine (%.0f m)" % apres_rates)
	# En cadence, elle file autour du bassin.
	var images := 0
	while triere.en_route and images < 6000:
		if triere.en_cadence():
			triere.ramer()
		await physics_frame
		images += 1
	_verifier(triere.coups_en_cadence >= 20, "il a fallu ramer en cadence (%d coups)" % triere.coups_en_cadence)
	_verifier(not triere.en_route, "la trière a fait le tour du bassin")
	_verifier(triere.global_position.distance_to(depart) < 4.0, "elle revient à son quai")
	_verifier(_id_etape() == "retour_phormion", "l'épreuve est réussie (%s)" % _id_etape())
	_verifier(not _joueur.has_meta("a_bord"), "le joueur n'est plus « à bord »")

	await _parler("Phormion")
	_verifier(_id_etape() == "chiens_loges", "des chiens attaquent les loges (%s)" % _id_etape())
	await _attendre(5)
	var chiens := _vivants("chien_fracture_loges")
	_verifier(chiens.size() == 3, "trois chiens fracturés entrent dans les loges (%d)" % chiens.size())
	for bete in chiens:
		bete.combat.subir(99999.0, combat_joueur)
		await _attendre(3)
	await _attendre(5)
	_verifier(_id_etape() == "molosse", "les chiens sont chassés (%s)" % _id_etape())
	await _attendre(5)
	var molosse := _vivants("molosse_fracture")
	_verifier(molosse.size() == 1, "le molosse fracturé surgit au fond des loges")
	if molosse.size() == 1:
		molosse[0].combat.subir(999999.0, combat_joueur)
	await _attendre(10)
	_verifier(_id_etape() == "liberation", "le molosse est abattu (%s)" % _id_etape())
	await _parler("Phormion")
	var markos: Node3D = _scene.find_child("Markos", true, false)
	_verifier(Vector2(markos.global_position.x, markos.global_position.z).distance_to(Vector2(-30, 18)) < 1.0, "Markos sort de l'enclos")
	await _parler("Lysimaque")
	var inventaire = _joueur.get_node_or_null("Inventaire")
	if inventaire != null and inventaire.has_method("quantite"):
		_verifier(inventaire.quantite("xiphos_lysimaque") >= 1, "le xiphos de Lysimaque est dans le sac")
		_verifier(inventaire.quantite("bandeau_rameur") >= 1, "le bandeau de la Paralos aussi")
	_verifier(_id_etape() == "fin_chapitre_2", "Markos veut parler (%s)" % _id_etape())
	lues = await _parler("Markos")
	_verifier(lues >= 4, "Markos parle des masques (%d bulles)" % lues)
	_verifier(_id_etape() == "vers_athenes", "chapitres 1 et 2 terminés : en route pour Athènes (%s)" % _id_etape())

	# --- La progression est gardée.
	var cfg := ConfigFile.new()
	cfg.load(FICHIER)
	_verifier(cfg.has_section("grece"), "l'avancement est enregistré dans la section « grece »")
	_verifier(cfg.get_value("egypte", "etape", "") == "", "l'Égypte n'est pas touchée")
	_scene.queue_free()
	await _attendre(5)
	await _charger()
	_verifier(_id_etape() == "vers_athenes", "au retour, la quête reprend où on l'avait laissée (%s)" % _id_etape())
	_verifier(_scene.find_child("Faille", true, false).fermee, "la faille est toujours fermée")
	_verifier(_scene.find_child("BaliseInstallee", true, false).visible, "la balise est toujours en place")
	var m2: Node3D = _scene.find_child("Markos", true, false)
	_verifier(Vector2(m2.global_position.x, m2.global_position.z).distance_to(Vector2(-30, 18)) < 1.0, "Markos est toujours libre")
	_verifier(not _scene.find_child("Paralos", true, false).en_route, "la Paralos reste à quai")

	# Retour au hub par le portail (après s'en être éloigné).
	await _placer(Vector3(-50, _scene.hauteur(-50, 100) + 0.3, 100), 0.0)
	await _attendre(5)
	_verifier(_scene._portail_arme, "le portail de retour s'active quand on s'en est éloigné")
	await _placer(Vector3(_scene.PORTAIL.x, _scene.hauteur(_scene.PORTAIL.x, _scene.PORTAIL.y + 6) + 0.3, _scene.PORTAIL.y + 6), 0.0)
	Input.action_press("avancer")
	await _attendre(90)
	Input.action_release("avancer")
	await _attendre(5)
	_verifier(_quete._en_voyage, "traverser le portail ramène à Hikari Bay")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
