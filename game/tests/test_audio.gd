extends SceneTree
## Test automatique du son : fichiers présents, bus audio, musique et ambiances
## par scène, pas, saut, roulade, coups, cris des loups, clics des boutons,
## surface des pas lue sur le terrain de la Côte Gelée.
## Lancement : godot --headless --path game -s res://tests/test_audio.gd

var _echecs := 0
var audio: Node


func _verifier(condition: bool, message: String) -> void:
	if condition:
		print("  OK   ", message)
	else:
		print("  ÉCHEC ", message)
		_echecs += 1


func _attendre(images: int) -> void:
	for i in images:
		await physics_frame


func _a_joue(debut: String, depuis: int) -> bool:
	for i in range(depuis, audio.historique.size()):
		if audio.historique[i].begins_with(debut):
			return true
	return false


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	audio = root.get_node("Audio")
	print("Test du son")
	for bus in ["Musique", "Ambiance", "Exterieur", "Effets", "Interface"]:
		_verifier(AudioServer.get_bus_index(bus) >= 0, "le bus audio « %s » existe" % bus)

	# Chaque son cité dans data/audio.json existe.
	var noms := {}
	_collecter(audio.donnees, noms)
	for liste in audio.donnees.get("musiques", {}).values():
		if liste is Dictionary:
			for piste in liste.get("pistes", []):
				noms[piste] = true
	var manquants := []
	for nom in noms:
		for sexe in ["homme", "femme"]:
			if audio.variantes(String(nom).replace("{sexe}", sexe)).is_empty():
				manquants.append(nom)
	_verifier(manquants.is_empty(), "les %d sons de data/audio.json existent %s" % [noms.size(), str(manquants)])
	_verifier(audio.variantes("pas/neige_course").size() == 5, "5 variantes de pas dans la neige")

	# Colline : musique, ambiance, pas, saut, roulade.
	var scene: Node = load("res://scenes/monde/colline_de_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _attendre(40)
	_verifier(audio.liste_musique() == "prehistoire", "la colline joue les musiques de la Préhistoire")
	_verifier(audio._ambiances.has("ambiances/vent_plaine"), "le vent de la plaine souffle")
	await _attendre(80)
	_verifier(audio.piste_en_cours().begins_with("musique/prehistoire_"), "une piste démarre (%s)" % audio.piste_en_cours())
	var joueur = get_first_node_in_group("joueur_local")
	_verifier(joueur.has_node("Bruiteur"), "le joueur a ses bruits")
	var n: int = audio.historique.size()
	Input.action_press("avancer")
	await _attendre(90)
	Input.action_release("avancer")
	var pas: Array = audio.historique.slice(n).filter(func(s): return s.begins_with("pas/herbe_course"))
	_verifier(pas.size() >= 3 and pas.size() <= 8, "des pas dans l'herbe en courant 1,5 s (%d)" % pas.size())
	n = audio.historique.size()
	Input.action_press("sauter")
	await _attendre(2)
	Input.action_release("sauter")
	await _attendre(70)
	_verifier(_a_joue("personnage/tissu", n), "bruit de vêtements au saut")
	_verifier(_a_joue("pas/herbe_reception", n), "réception au sol")
	n = audio.historique.size()
	Input.action_press("avancer")
	await _attendre(3)
	Input.action_press("esquive")
	await _attendre(2)
	Input.action_release("esquive")
	await _attendre(20)
	Input.action_release("avancer")
	_verifier(_a_joue("personnage/roulade", n), "souffle de la roulade")

	# Combat : un loup prend un coup, grogne, meurt.
	var loup = scene.get_node("Partie/Loups/CampNord_Loup1")
	_verifier(loup.has_node("Bruiteur"), "le loup a ses bruits")
	n = audio.historique.size()
	loup.combat.subir(10.0, joueur.combat)
	await _attendre(3)
	_verifier(_a_joue("combat/coup", n), "bruit de coup sur le loup")
	await _attendre(20)
	_verifier(_a_joue("betes/loup_grondement", n), "le loup gronde quand il attaque")
	n = audio.historique.size()
	for i in 8:
		loup._mordre()
	_verifier(_a_joue("betes/loup_morsure", n), "le loup mord en grognant")
	n = audio.historique.size()
	loup.combat.subir(9999.0, joueur.combat)
	await _attendre(3)
	_verifier(_a_joue("betes/loup_mort", n), "le loup gémit en mourant")
	n = audio.historique.size()
	joueur.combat.subir(5.0, null)
	await _attendre(3)
	_verifier(_a_joue("combat/coup", n), "bruit de coup sur le joueur")

	# Les boutons cliquent.
	await _attendre(60)
	var bouton := Button.new()
	root.add_child(bouton)
	n = audio.historique.size()
	bouton.pressed.emit()
	_verifier(_a_joue("interface/clic", n), "un bouton fait « clic »")
	bouton.queue_free()

	# Côte Gelée : surface des pas lue sur le terrain.
	scene.queue_free()
	await _attendre(2)
	var cote: Node = load("res://scenes/monde/prehistoire/cote_gelee.tscn").instantiate()
	root.add_child(cote)
	current_scene = cote
	await _attendre(40)
	_verifier(audio.reglages_scene.get("pas") == "auto", "la Côte Gelée lit la surface sur le terrain")
	_verifier(audio._ambiances.has("ambiances/vent_arctique"), "le vent arctique souffle sur la Côte Gelée")
	var j2 = get_first_node_in_group("joueur_local")
	var surfaces := {}
	for x in range(-120, 121, 30):
		for z in range(-120, 121, 30):
			surfaces[j2.get_node("Bruiteur").surface_sous(Vector3(x, cote.hauteur(x, z), z))] = true
	_verifier(surfaces.has("neige"), "on marche dans la neige quelque part (%s)" % str(surfaces.keys()))
	_verifier(surfaces.size() >= 2, "plusieurs surfaces sur la Côte Gelée (%s)" % str(surfaces.keys()))

	print("Résultat : ", "tout est bon" if _echecs == 0 else "%d échec(s)" % _echecs)
	quit(1 if _echecs > 0 else 0)


func _collecter(valeur, noms: Dictionary) -> void:
	if valeur is Dictionary:
		for cle in valeur:
			if cle == "son" or cle == "en_plus":
				noms[valeur[cle]] = true
			else:
				_collecter(valeur[cle], noms)
	elif valeur is Array:
		for v in valeur:
			_collecter(v, noms)
