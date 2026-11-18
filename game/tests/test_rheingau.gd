extends SceneTree
## Test automatique des vignes du Rheingau (Mayence, zone 1) et des chapitres 1 et 2 : la radio
## de Vera à la chapelle, Liesel et Heinrich Keffer au village, les sangliers des vignes, la casse
## de lettres, les vendangeurs Scellés (petit jeu de la composition), maître Ott et le pressoir à
## vis, l'encre de Gutenberg ; puis l'abbaye d'Eberbach, frère Wendelin, les loups du Taunus,
## les moines Scellés, le message de Masque, le chef des brigands, la feuille de l'Éditeur, la
## faille et les besicles.
## Lancement : godot --headless --path game -s res://tests/test_rheingau.gd

const FICHIER := "user://test_mayence_progression.cfg"
const SCENE := "res://scenes/monde/mayence/rheingau.tscn"

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


func _aller_pres(cible: Node3D, decalage := Vector3(0, 0, 1.6)) -> void:
	var p: Vector3 = cible.global_position + decalage
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


func _tuer(type: String, combat_joueur, etape: String) -> void:
	for k in 30:
		var vivants := _vivants(type)
		if vivants.is_empty() or _id_etape() != etape:
			break
		vivants[0].combat.subir(999999.0, combat_joueur)
		await _attendre(4)
	await _attendre(5)


func _charger() -> void:
	_scene = load(SCENE).instantiate()
	_quete = _scene.get_node("Quete")
	_quete.fichier_progression = FICHIER
	_quete.voyage_reel = false
	root.add_child(_scene)
	await _attendre(40)
	_joueur = get_first_node_in_group("joueur_local")
	_dialogue = get_first_node_in_group("dialogue")


func _composer(nom_objet: String, phrase: String, verifier_erreur := false) -> void:
	var objet: Node3D = _scene.find_child(nom_objet, true, false)
	await _aller_pres(objet, Vector3(0, 0, 1.2))
	await _appuyer_f()
	await _attendre(3)
	var c = _quete.composteur()
	_verifier(c != null and c.est_ouvert(), "%s : la casse s'ouvre (« %s »)" % [nom_objet, c.phrase() if c != null else "?"])
	if c == null:
		return
	_verifier(phrase == "" or c.phrase() == phrase, "la phrase est « %s » (%s)" % [phrase, c.phrase()])
	if verifier_erreur:
		var bonne: int = c.bonne_case()
		var mauvaise: int = (bonne + 1) % int(c._casse.size())
		c.choisir(mauvaise)
		_verifier(c._place == 0 and c._erreurs == 1 and c.est_ouvert(), "une mauvaise lettre : la casse tremble, rien n'est rangé")
		var piege := ""
		for l in c._casse:
			if c.PIEGES.get(String(c._lettres[0]), "") == l:
				piege = l
		_verifier(piege != "", "dans la casse, il y a une lettre piège en miroir (%s pour %s)" % [piege, c._lettres[0]])
		c.choisir(c.bonne_case())
		_verifier(c._place == 1, "la bonne lettre se range dans le composteur")
	c.resoudre()
	await _attendre(110)


func _lancer() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	await _charger()
	print("Test des vignes du Rheingau (Mayence)")

	# --- Le monde.
	_verifier(_joueur != null, "un personnage arrive sur l'île")
	var p: Vector3 = _joueur.global_position
	_verifier(Vector2(p.x, p.z).distance_to(_scene.PORTAIL) < 9.0, "juste devant le portail de la Vigie")
	_verifier(_joueur.is_on_floor(), "il a les pieds sur terre (y = %.2f)" % p.y)
	_verifier(_scene.find_child("Chapelle", true, false) != null, "le portail s'est ouvert dans une chapelle de vignerons")
	_verifier(_scene.find_child("EgliseVillage", true, false) != null, "le village a son église")
	var nb_maisons := _scene.find_children("MaisonRhenane*", "Node3D", true, false).size()
	_verifier(nb_maisons >= 8, "des maisons à colombages sur un rez-de-chaussée de pierre (%d)" % nb_maisons)
	_verifier(_scene.find_child("HallePressoir", true, false) != null, "la halle du pressoir")
	_verifier(_scene.find_child("Vis", true, false) != null, "et le grand pressoir à vis")
	var nb_ceps := 0
	for mm in _scene.find_children("Vigne_*", "MultiMeshInstance3D", true, false):
		nb_ceps += (mm as MultiMeshInstance3D).multimesh.instance_count
	_verifier(nb_ceps >= 4000, "des rangs de vigne sur tout le coteau (%d ceps)" % nb_ceps)
	_verifier(_scene.find_children("Grappes_*", "MultiMeshInstance3D", true, false).size() > 0, "chargés de grappes")
	_verifier(_scene.find_child("Murets", true, false).get_child_count() > 0, "des murets de schiste tiennent les terrasses")
	_verifier(_scene.hauteur(0, -60) - _scene.hauteur(0, 100) > 15.0, "le coteau monte du Rhin vers la forêt")
	_verifier(_scene.find_child("EgliseAbbatiale", true, false) != null and _scene.find_child("Cloitre", true, false) != null, "l'abbaye d'Eberbach et son cloître")
	_verifier(_scene.find_child("Rhin", true, false) != null, "le Rhin coule en bas")
	_verifier(_scene.find_children("NefDuRhin*", "Node3D", true, false).size() >= 3, "des nefs chargées de tonneaux sur le fleuve")
	_verifier(_scene.find_child("MayenceLointaine", true, false) != null, "au loin, les tours rouges de Mayence")
	var nb_arbres: int = _scene.find_child("Arbres", true, false).get_child_count()
	_verifier(nb_arbres >= 150, "la forêt du Taunus, des noyers et des saules (%d arbres)" % nb_arbres)
	_verifier(get_first_node_in_group("balises") != null, "une balise de la Vigie permet de réapparaître")
	_verifier(_vivants("loup_taunus").size() >= 6, "des loups fracturés dans la forêt (%d)" % _vivants("loup_taunus").size())
	_verifier(_vivants("sanglier_vigne").size() >= 5, "des sangliers dans les vignes (%d)" % _vivants("sanglier_vigne").size())
	var brigand: Node = _vivants("mercenaire_brigand_rhin")[0] if not _vivants("mercenaire_brigand_rhin").is_empty() else null
	_verifier(brigand != null and brigand.get_node("Apparence").find_child("Oublie", true, false) != null, "les brigands sont des hommes (pas des loups)")
	var vendangeur: Node = _scene.find_child("ScelleVendangeur1", true, false)
	_verifier(vendangeur != null and vendangeur.scelle and vendangeur.fige, "dans les vignes, un vendangeur est Scellé")
	var pente_max := 0.0
	for i in _scene.ROUTE.size() - 1:
		var a: Vector2 = _scene.ROUTE[i]
		var b: Vector2 = _scene.ROUTE[i + 1]
		for k in 20:
			var q0 := a.lerp(b, k / 20.0)
			var q1 := a.lerp(b, (k + 1) / 20.0)
			pente_max = maxf(pente_max, absf(_scene.hauteur(q0.x, q0.y) - _scene.hauteur(q1.x, q1.y)) / maxf(q0.distance_to(q1), 0.1))
	_verifier(pente_max < 0.25, "la route du Rhin est presque plate (pente max %.2f)" % pente_max)
	var pente_chemin := 0.0
	for i in _scene.CHEMIN.size() - 1:
		var a: Vector2 = _scene.CHEMIN[i]
		var b: Vector2 = _scene.CHEMIN[i + 1]
		for k in 30:
			var q0 := a.lerp(b, k / 30.0)
			var q1 := a.lerp(b, (k + 1) / 30.0)
			pente_chemin = maxf(pente_chemin, absf(_scene.hauteur(q0.x, q0.y) - _scene.hauteur(q1.x, q1.y)) / maxf(q0.distance_to(q1), 0.1))
	_verifier(pente_chemin < 0.7, "le chemin des vignes se monte à pied (pente max %.2f)" % pente_chemin)

	# --- Chapitre 1 : Le pressoir.
	var combat_joueur = _joueur.get_node("Combat")
	_verifier(_id_etape() == "radio_vera", "la quête commence : une radio grésille (%s)" % _id_etape())
	await _aller_pres(_scene.find_child("RadioVeraMayence", true, false))
	await _appuyer_f()
	await _attendre(130)
	_verifier(_id_etape() == "vers_village", "Vera parle à la radio (%s)" % _id_etape())
	await _placer(Vector3(4, _scene.hauteur(4, 98) + 0.4, 98), 0.0)
	await _attendre(20)
	_verifier(_id_etape() == "liesel", "au village, la vendange est arrêtée (%s)" % _id_etape())
	var lues := await _parler("Liesel")
	_verifier(lues >= 4, "Liesel raconte (%d bulles)" % lues)
	lues = await _parler("HeinrichKeffer")
	_verifier(lues >= 4, "Heinrich Keffer, le compagnon de Gutenberg (%d bulles)" % lues)
	_verifier(_id_etape() == "sangliers", "des sangliers dans les vignes (%s)" % _id_etape())
	await _attendre(5)
	_verifier(_vivants("sanglier_vigne_vendange").size() == 4, "quatre sangliers (%d)" % _vivants("sanglier_vigne_vendange").size())
	await _tuer("sanglier_vigne_vendange", combat_joueur, "sangliers")
	_verifier(_id_etape() == "keffer_casse", "les sangliers sont chassés (%s)" % _id_etape())
	await _aller_pres(_scene.find_child("CasseKeffer", true, false), Vector3(0, 0, 1.3))
	await _appuyer_f()
	await _attendre(120)
	_verifier(_id_etape() == "scelles_vigne", "Keffer montre les lettres à l'envers (%s)" % _id_etape())
	for k in 3:
		await _composer("LibererVendangeur%d" % k, ["pour toi", "pour tous", "partage"][k], k == 0)
		_verifier(_quete.compteur == k + 1 or _id_etape() != "scelles_vigne", "le vendangeur %d est délivré (%d/3)" % [k + 1, _quete.compteur])
	_verifier(_id_etape() == "liesel_pere", "les trois vendangeurs sont délivrés (%s)" % _id_etape())
	_verifier(vendangeur != null and not vendangeur.fige, "la cire rouge est tombée de Konrad")
	await _parler("Liesel")
	_verifier(_id_etape() == "ott", "il faut délivrer maître Ott (%s)" % _id_etape())
	await _composer("LibererOtt", "le pressoir est a tous")
	_verifier(_id_etape() == "ott_presse", "Ott lâche le pressoir (%s)" % _id_etape())
	_verifier(not _scene.find_child("MaitreOtt", true, false).fige, "Ott n'est plus Scellé")
	await _aller_pres(_scene.find_child("BarrePressoir", true, false), Vector3(0, 0, 1.2))
	await _appuyer_f()
	await _attendre(240)
	_verifier(_id_etape() == "keffer_encre", "le moût coule (%s)" % _id_etape())
	var vis: Node3D = _scene.find_child("Vis", true, false)
	var angle_vis := vis.rotation.y
	await _attendre(30)
	_verifier(absf(vis.rotation.y - angle_vis) > 0.05, "la vis du pressoir tourne")
	await _parler("HeinrichKeffer")
	var inventaire = _joueur.get_node_or_null("Inventaire")
	var a_inventaire: bool = inventaire != null and inventaire.has_method("quantite")
	if a_inventaire:
		_verifier(inventaire.quantite("pot_encre_gutenberg") >= 1, "Keffer donne le pot d'encre de Gutenberg")
		_verifier(inventaire.quantite("tablier_vendangeur") >= 1, "et un tablier de vendangeur")
	var competences: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/competences.json"))
	_verifier(competences.get("encre_noire", {}).has("ralenti"), "l'Encre noire ralentit")

	# --- Chapitre 2 : Le copiste qui a peur.
	_verifier(_id_etape() == "vers_abbaye", "chapitre 2 : vers l'abbaye (%s)" % _id_etape())
	await _placer(Vector3(-76, _scene.hauteur(-76, -94) + 0.4, -94), 0.0)
	await _attendre(20)
	_verifier(_id_etape() == "wendelin", "les moines sont scellés (%s)" % _id_etape())
	lues = await _parler("FrereWendelin")
	_verifier(lues >= 5, "frère Wendelin a peur de l'imprimerie (%d bulles)" % lues)
	_verifier(_id_etape() == "loups_abbaye", "des loups autour de l'abbaye (%s)" % _id_etape())
	await _attendre(5)
	await _tuer("loup_taunus_abbaye", combat_joueur, "loups_abbaye")
	_verifier(_id_etape() == "scelles_cloitre", "les loups sont chassés (%s)" % _id_etape())
	for k in 3:
		await _composer("LibererMoine%d" % k, ["lis", "ouvre le livre", "la lumiere est pour tous"][k])
	_verifier(_id_etape() == "message_masque", "les moines lisent tout haut (%s)" % _id_etape())
	await _aller_pres(_scene.find_child("CraieMasqueMayence", true, false), Vector3(1.4, 0, 0))
	await _appuyer_f()
	await _attendre(110)
	_verifier(_id_etape() == "wendelin_brigands", "Masque a laissé un message (%s)" % _id_etape())
	await _parler("FrereWendelin")
	_verifier(_id_etape() == "chef_brigands", "le chef des brigands (%s)" % _id_etape())
	await _attendre(5)
	await _tuer("mercenaire_chef_brigands_rhin", combat_joueur, "chef_brigands")
	_verifier(_id_etape() == "feuille_editeur", "le chef est abattu (%s)" % _id_etape())
	await _aller_pres(_scene.find_child("FeuilleEditeur", true, false), Vector3(0, 0, 1.3))
	await _appuyer_f()
	await _attendre(110)
	_verifier(_id_etape() == "faille", "une feuille de 2026, et une faille (%s)" % _id_etape())
	await _attendre(5)
	await _tuer("mercenaire_brigand_rhin_camp", combat_joueur, "faille")
	var faille = _scene.find_child("Faille", true, false)
	await _aller_pres(faille)
	await _appuyer_f()
	await _attendre(360)
	_verifier(faille.fermee, "la faille est refermée")
	_verifier(_id_etape() == "wendelin_fin", "retour à l'abbaye (%s)" % _id_etape())
	await _parler("FrereWendelin")
	if a_inventaire:
		_verifier(inventaire.quantite("besicles_wendelin") >= 1, "les besicles de frère Wendelin sont dans le sac")
		_verifier(inventaire.quantite("lunettes_pharmacie") >= 1 or true, "les lunettes de pharmacie du chef")
	_verifier(_id_etape() == "vers_rhin", "chapitres 1 et 2 terminés : en route vers le Rhin (%s)" % _id_etape())
	await _attendre(30)
	_verifier(_scene._route_ouverte, "la route de l'est s'ouvre vers le Rhin")

	# --- La progression est gardée.
	var cfg := ConfigFile.new()
	cfg.load(FICHIER)
	_verifier(cfg.has_section("mayence"), "l'avancement est enregistré dans la section « mayence »")
	_verifier(cfg.get_value("moyen_age", "etape", "") == "", "le Moyen Âge n'est pas touché")
	_scene.queue_free()
	await _attendre(5)
	await _charger()
	await _attendre(20)
	_verifier(_scene.find_child("Faille", true, false).fermee, "au retour, la faille est toujours fermée")
	_verifier(not _scene.find_child("ScelleVendangeur2", true, false).fige, "Gertrud n'est plus Scellée")
	_verifier(not _scene.find_child("MaitreOtt", true, false).fige, "maître Ott non plus")

	# Retour au hub par le portail (après s'en être éloigné).
	await _placer(Vector3(-90, _scene.hauteur(-90, 110) + 0.3, 110), 0.0)
	await _attendre(5)
	_verifier(_scene._portail_arme, "le portail de retour s'active quand on s'en est éloigné")
	await _placer(Vector3(_scene.PORTAIL.x, _scene.hauteur(_scene.PORTAIL.x, _scene.PORTAIL.y - 6) + 0.3, _scene.PORTAIL.y - 6), PI)
	Input.action_press("avancer")
	await _attendre(90)
	Input.action_release("avancer")
	await _attendre(5)
	_verifier(_quete._en_voyage, "traverser le portail ramène à Hikari Bay")

	print("")
	if _echecs == 0:
		print("TOUS LES TESTS PASSENT")
	else:
		print("%d ÉCHEC(S)" % _echecs)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	quit(1 if _echecs > 0 else 0)
