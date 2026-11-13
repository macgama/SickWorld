extends SceneTree
## Test de l'écran titre, des options, du menu de jeu (Échap) et des conseils.
## Lancement : godot --headless --path game -s res://tests/test_menu.gd
## (Les fichiers options.cfg et conseils.cfg du PC sont mis de côté puis remis.)

var FICHIERS := []
const PROGRESSION := "user://test_menu_progression.cfg"

var _echecs := 0
var _sauvegardes := {}


func _verifier(condition: bool, message: String) -> void:
	print("  OK   " if condition else "  ÉCHEC ", message)
	if not condition:
		_echecs += 1


func _attendre(images: int) -> void:
	for i in images:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _touche(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	var fin := ev.duplicate() as InputEventKey
	fin.pressed = false
	Input.parse_input_event(fin)


func _lancer() -> void:
	FICHIERS = ["user://options.cfg", Profil.chemin("user://conseils.cfg")]
	for f in FICHIERS:
		if FileAccess.file_exists(f):
			_sauvegardes[f] = FileAccess.get_file_as_bytes(f)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	var options := root.get_node("Options")
	var conseils := root.get_node("Conseils")
	conseils._vus.clear()
	options.conseils = true
	_tester_options(options)
	_tester_conseils_textes(conseils)
	await _tester_ecran_titre()
	await _tester_hub(options, conseils)
	_finir()


func _tester_options(options: Node) -> void:
	print("Options")
	options.regler_volume("Master", 0.5)
	var i := AudioServer.get_bus_index("Master")
	_verifier(absf(AudioServer.get_bus_volume_db(i) - linear_to_db(0.5)) < 0.1,
			"le volume général change le bus Master (%.1f dB)" % AudioServer.get_bus_volume_db(i))
	var avant_saut: InputEventKey = options.premiere_touche("sauter")
	var avant_journal: InputEventKey = options.premiere_touche("journal")
	var autre: String = options.changer_touche("sauter", KEY_J)
	_verifier(options.premiere_touche("sauter").physical_keycode == KEY_J, "sauter passe sur J")
	_verifier(autre == "Journal des missions", "J servait au journal : échange signalé (%s)" % autre)
	_verifier(options.premiere_touche("journal").physical_keycode == avant_saut.physical_keycode,
			"le journal récupère l'ancienne touche de saut (%s)" % options.nom_touche("journal"))
	var cfg := ConfigFile.new()
	_verifier(cfg.load("user://options.cfg") == OK and int(cfg.get_value("touches", "sauter", 0)) == KEY_J,
			"la nouvelle touche est enregistrée dans options.cfg")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_J
	ev.pressed = true
	_verifier(InputMap.event_is_action(ev, "sauter"), "appuyer sur J déclenche bien « sauter »")
	options.touches_par_defaut()
	_verifier(options.premiere_touche("sauter").physical_keycode == avant_saut.physical_keycode
			and options.premiere_touche("journal").physical_keycode == avant_journal.physical_keycode,
			"« touches par défaut » remet Espace et J")
	_verifier(InputMap.action_get_events("avancer").size() == 2, "les flèches restent en touches secondaires")
	_verifier(options.touches_deplacement().split(" ").size() == 4, "touches de déplacement : %s" % options.touches_deplacement())


func _tester_conseils_textes(conseils: Node) -> void:
	print("Textes des conseils")
	_verifier(conseils.conseils.size() >= 8, "%d conseils lus dans data/conseils.json" % conseils.conseils.size())
	var texte: String = conseils.remplacer_touches("Appuie sur {interagir} puis {deplacement}, {echap}")
	_verifier(not texte.contains("{"), "les touches sont remplacées : %s" % texte)
	for c: Dictionary in conseils.conseils:
		var t: String = conseils.remplacer_touches(String(c.get("texte", "")))
		if t.contains("{"):
			_verifier(false, "touche inconnue dans le conseil « %s »" % c.get("id"))


func _tester_ecran_titre() -> void:
	print("Écran titre")
	var menu: Node = load("res://scenes/interface/menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await _attendre(20)
	_verifier(menu._decor != null and menu._decor.is_inside_tree(), "le décor de Hikari Bay est chargé en fond")
	_verifier(menu._decor != null and menu._decor.get_node_or_null("Partie") == null, "sans partie ni joueurs")
	_verifier(get_first_node_in_group("joueur_local") == null, "aucun joueur n'apparaît")
	_verifier(menu._camera != null and menu._camera.current, "la caméra du titre filme la ville")
	var p0: Vector3 = menu._camera.global_position
	await _attendre(30)
	_verifier(menu._camera.global_position.distance_to(p0) > 0.001, "la caméra glisse doucement")
	# Plan suivant.
	menu._temps_plan = menu.DUREE_PLAN - 0.01
	var plan: int = menu._plan
	await _attendre(3)
	_verifier(menu._plan == (plan + 1) % menu.PLANS.size(), "passage au plan suivant")
	var textes := []
	for b in menu.find_children("*", "Button", true, false):
		textes.append((b as Button).text)
	_verifier("Options" in textes and "Quitter" in textes, "boutons : %s" % ", ".join(textes))
	menu._ouvrir_options()
	await _attendre(2)
	_verifier(menu._options.visible and not menu._colonne.visible, "le bouton Options ouvre les options")
	_verifier(menu._options._onglets.get_tab_count() == 4, "4 onglets : Graphismes, Son, Commandes, Jeu")
	_touche(KEY_ESCAPE)
	await _attendre(2)
	_verifier(not menu._options.visible and menu._colonne.visible, "Échap referme les options")
	menu.queue_free()
	current_scene = null
	await _attendre(3)


func _tester_hub(options: Node, conseils: Node) -> void:
	print("Conseils et menu de jeu dans Hikari Bay")
	root.get_node("Reseau").mode = 0  # SEUL
	var scene: Node = load("res://scenes/monde/hikari_bay.tscn").instantiate()
	var intro := scene.get_node("Intro")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSION))
	intro.fichier_progression = PROGRESSION
	intro.voyage_reel = false
	root.add_child(scene)
	current_scene = scene
	# L'ouverture dure ~10 s : on accélère le temps.
	Engine.time_scale = 6.0
	var limite := 0
	while conseils._actuel.get("id", "") != "deplacement" and limite < 600:
		limite += 1
		await process_frame
	Engine.time_scale = 1.0
	_verifier(conseils._actuel.get("id", "") == "deplacement", "le premier conseil (se déplacer) apparaît après l'ouverture")
	_verifier(conseils._bulle.visible and conseils._texte.get_parsed_text().length() > 20,
			"la bulle affiche : %s" % conseils._texte.get_parsed_text().replace("\n", " "))
	_verifier(conseils.deja_vu("deplacement"), "le conseil est noté comme vu")
	var joueur := get_first_node_in_group("joueur_local") as Node3D
	if joueur != null:
		joueur.teleporter(joueur.global_position + Vector3(8, 0, 0), 0.0)
	var t := 0
	while conseils._actuel.get("id", "") == "deplacement" and t < 300:
		t += 1
		await process_frame
	_verifier(conseils._actuel.get("id", "") != "deplacement", "le conseil disparaît quand le joueur a marché")

	# Échap : menu de jeu et pause en solo.
	_touche(KEY_ESCAPE)
	await _attendre(2)
	_verifier(options.menu_jeu_ouvert(), "Échap ouvre le menu de jeu")
	_verifier(paused, "le jeu est en pause en solo")
	_touche(KEY_ESCAPE)
	await _attendre(2)
	_verifier(not options.menu_jeu_ouvert() and not paused, "Échap referme le menu et reprend le jeu")

	# Conseils coupés : plus rien ne s'affiche.
	options.conseils = false
	conseils._effacer()
	conseils.montrer("carte")
	await _attendre(5)
	_verifier(conseils._actuel.is_empty(), "conseils coupés dans les options : rien ne s'affiche")
	options.conseils = true
	scene.queue_free()
	await _attendre(3)


func _finir() -> void:
	for f in FICHIERS:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
		if _sauvegardes.has(f):
			var fa := FileAccess.open(f, FileAccess.WRITE)
			fa.store_buffer(_sauvegardes[f])
			fa.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSION))
	print("")
	print("Résultat : %s" % ("tout est bon" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
