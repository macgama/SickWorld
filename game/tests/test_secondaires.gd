extends SceneTree
## Test automatique des quêtes secondaires de la Préhistoire (data/prehistoire_secondaires.json) :
## les « ! » au-dessus des donneurs, « Le feu qui ne prend pas » (Saé), « Les traces du
## grand ours » (Toran), une quête qui se passe dans une autre zone (Vieille Mère),
## la liste à l'écran et la sauvegarde.
## Lancement : godot --headless --path game -s res://tests/test_secondaires.gd

const FICHIER := "user://test_secondaires_progression.cfg"

var _echecs := 0
var _scene: Node
var _joueur
var _quete
var _sec
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
	p.y = _scene.hauteur(p.x, p.z) + 0.3
	await _placer(p, 0.0)


func _parler(pnj: Node3D) -> int:
	await _aller_pres(pnj)
	await _attendre(40)
	await _appuyer_f()
	return await _lire_dialogue()


func _utiliser(objet: Node3D, duree: float) -> void:
	await _aller_pres(objet)
	# Les bêtes du coin interrompraient l'action.
	_tuer_proches(objet.global_position, 30.0, "")
	await _appuyer_f()
	await _attendre(int(duree * 60) + 30)


func _objet(id: String) -> Node3D:
	return _sec._objets.get(id)


func _tuer_proches(centre: Vector3, rayon: float, prefixe: String) -> int:
	var n := 0
	var combat_joueur = _joueur.get_node("Combat")
	for bete in get_nodes_in_group("loups"):
		if String(bete.type_ennemi).begins_with(prefixe) and bete.combat.est_vivant() \
				and bete.global_position.distance_to(centre) < rayon:
			bete.combat.subir(9999.0, combat_joueur)
			n += 1
	return n


func _charger() -> void:
	_scene = load("res://scenes/monde/prehistoire/steppe.tscn").instantiate()
	_quete = _scene.get_node("Quete")
	_quete.fichier_progression = FICHIER
	_quete.voyage_reel = false
	root.add_child(_scene)
	await _attendre(40)
	_joueur = get_first_node_in_group("joueur_local")
	_dialogue = get_first_node_in_group("dialogue")
	_sec = get_first_node_in_group("quetes_secondaires")


func _lancer() -> void:
	print("Test des quêtes secondaires (Préhistoire)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	var cfg := ConfigFile.new()
	# Chapitre 4 en cours : Toran attend dans la forêt, il est libre au camp… on se place
	# juste après le retour de Kéo (chapitre 4 fini) pour que le clan soit au camp.
	cfg.set_value("prehistoire", "etape", "lenoir_failles")
	cfg.save(FICHIER)
	await _charger()
	_verifier(_sec != null, "les quêtes secondaires sont chargées")
	_verifier(_sec.quetes.size() >= 5, "au moins cinq quêtes secondaires (%d)" % _sec.quetes.size())

	# --- Les donneurs portent un « ! ».
	var sae = _scene.find_child("Sae", true, false)
	var mere = _scene.find_child("VieilleMere", true, false)
	_verifier(sae != null, "Saé, la gardienne du feu, est au camp")
	await _attendre(40)
	var marque = sae.get_node_or_null("MarqueQueteSecondaire") if sae != null else null
	_verifier(marque != null and marque.text == "!", "un « ! » doré au-dessus de Saé")
	_verifier(mere.get_node_or_null("MarqueQueteSecondaire") != null, "un « ! » au-dessus de la Vieille Mère")

	# --- Le feu qui ne prend pas.
	var lues := await _parler(sae)
	_verifier(lues >= 3, "Saé explique le problème (%d bulles)" % lues)
	_verifier(_sec.etat_quete("feu_qui_ne_prend_pas") == 0, "la quête « Le feu qui ne prend pas » commence")
	_verifier(_sec._cadre.visible, "la quête apparaît dans la liste à l'écran")
	_verifier(_objet("pyrite_0").actif, "la pyrite brille, on peut la ramasser")
	for id in ["pyrite_0", "pyrite_1"]:
		await _utiliser(_objet(id), 1.5)
	_verifier(_sec.etat_quete("feu_qui_ne_prend_pas") == 1, "deux pyrites ramassées : il faut l'amadou")
	for id in ["amadou_0", "amadou_1"]:
		await _utiliser(_objet(id), 1.5)
	_verifier(_sec.etat_quete("feu_qui_ne_prend_pas") == 2, "l'amadou est récolté : il faut rallumer le foyer")
	await _utiliser(_objet("foyer_anciens"), 4.0)
	_verifier(_objet("foyer_anciens").get_node_or_null("FeuRallume") != null, "le foyer des anciens brûle de nouveau")
	_verifier(_sec.etat_quete("feu_qui_ne_prend_pas") == 3, "des fracturés arrivent")
	await _attendre(20)
	var tues := _tuer_proches(Vector3(40, 0, -44), 40.0, "loup_fracture")
	await _attendre(10)
	_verifier(tues >= 3, "trois fracturés attaquent le feu (%d)" % tues)
	_verifier(_sec.etat_quete("feu_qui_ne_prend_pas") == 4, "le feu est sauvé : retour à Saé")
	_verifier(sae.get_node("MarqueQueteSecondaire").text == "?", "un « ? » au-dessus de Saé")
	lues = await _parler(sae)
	_verifier(lues >= 3 and _sec.etat_quete("feu_qui_ne_prend_pas") == _sec.FINIE, "quête terminée, Saé donne sa pierre à feu")

	# --- Une quête dans une autre zone.
	await _parler(mere)
	_verifier(_sec.etat_quete("premier_collier") == 0, "la Vieille Mère demande des coquillages")
	_sec._mettre_a_jour_liste()
	var texte := ""
	for l in _sec._liste.get_children():
		texte += String(l.get("text")) + "\n"
	_verifier(texte.contains("Côte Gelée"), "la liste indique que les coquillages sont sur la Côte Gelée")

	# --- Les traces du grand ours.
	var toran = _scene.find_child("Toran", true, false)
	lues = await _parler(toran)
	_verifier(_sec.etat_quete("traces_du_grand_ours") == 0, "Toran parle du grand ours (%d bulles)" % lues)
	for k in 3:
		await _utiliser(_objet("trace_ours_%d" % k), 1.5)
	_verifier(_sec.etat_quete("traces_du_grand_ours") == 3, "les trois traces mènent à l'ours")
	await _attendre(20)
	var ours := []
	for bete in get_nodes_in_group("loups"):
		if String(bete.type_ennemi) == "ours_brun" and bete.combat.est_vivant():
			ours.append(bete)
	_verifier(ours.size() == 1, "le grand ours brun est là")
	if ours.size() == 1:
		_verifier(ours[0].get_node("Apparence").scale.x < 1.5, "c'est un ours normal, pas le boss")
		_verifier(ours[0].get_node_or_null("OmniLight3D") == null, "sans lueur violette de fracture")
		ours[0].combat.subir(99999.0, _joueur.get_node("Combat"))
	await _attendre(10)
	_verifier(_sec.etat_quete("traces_du_grand_ours") == 4, "l'ours est vaincu : retour à Toran")
	await _parler(toran)
	_verifier(_sec.etat_quete("traces_du_grand_ours") == _sec.FINIE, "Toran donne la cape du grand ours")

	# --- La sauvegarde.
	_scene.queue_free()
	await _attendre(5)
	await _charger()
	await _attendre(20)
	_verifier(_sec.etat_quete("feu_qui_ne_prend_pas") == _sec.FINIE, "après rechargement, la quête du feu reste finie")
	_verifier(_sec.etat_quete("premier_collier") == 0, "la quête du collier reste en cours")
	_verifier(_objet("foyer_anciens").get_node_or_null("FeuRallume") != null, "le foyer brûle toujours")
	_verifier(not _objet("pyrite_0").visible or _objet("pyrite_0").ramasse, "la pyrite ramassée ne revient pas")
	var sae2 = _scene.find_child("Sae", true, false)
	_verifier(sae2.get_node_or_null("MarqueQueteSecondaire") == null, "plus de « ! » au-dessus de Saé")
	_verifier(not _sec.debloquee(_sec.quete("main_sur_la_paroi")), "« La main sur la paroi » attend la fin de l'île")

	print("Résultat : ", "TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	quit(1 if _echecs > 0 else 0)
