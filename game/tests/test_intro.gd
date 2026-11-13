extends SceneTree
## Test automatique de l'intro dans Hikari Bay : recrutement près de la fontaine,
## descente à la station Asahi, mission de la commandante, technicienne, puis
## départ par le portail de la Préhistoire.
## Lancement : godot --headless --path game -s res://tests/test_intro.gd

const FICHIER := "user://test_intro_progression.cfg"

var _echecs := 0
var _scene: Node
var _joueur
var _intro
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
	await _attendre(4)


## Va voir un personnage et lit tout son dialogue avec F. Renvoie le nombre de bulles lues.
func _parler_a(id: String) -> int:
	var pnj = _scene.find_child("Pnj_" + id, true, false)
	if pnj == null:
		return 0
	await _placer(pnj.global_position + Vector3(0, 0.3, 2.0), 0.0)
	await _appuyer_f()
	var lues := 0
	while _dialogue.est_ouvert() and lues < 30:
		lues += 1
		await _appuyer_f()
	return lues


func _id_etape() -> String:
	return _intro.etape_actuelle().get("id", "")


func _lancer() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	_scene = load("res://scenes/monde/hikari_bay.tscn").instantiate()
	_intro = _scene.get_node("Intro")
	_intro.fichier_progression = FICHIER
	_intro.voyage_reel = false
	root.add_child(_scene)
	await _attendre(30)
	_joueur = get_first_node_in_group("joueur_local")
	_dialogue = get_first_node_in_group("dialogue")
	print("Test de l'intro de Hikari Bay")
	_verifier(_id_etape() == "recrutement", "l'intro commence par le recrutement (%s)" % _id_etape())
	_verifier(_intro._objectif.visible and _intro._texte_objectif.text != "", "l'objectif s'affiche : « %s »" % _intro._texte_objectif.text)
	_verifier(_intro._repere.visible, "un repère lumineux montre où aller")

	# Le portail refuse de s'ouvrir tant que la mission n'est pas donnée.
	var partis := []
	_intro.voyage_demande.connect(func(e, s): partis.append([e, s]))
	_verifier(not _intro.demander_voyage("Préhistoire").is_empty() and partis.is_empty(),
			"le portail reste fermé avant la mission")

	# 1. Kenji Duval, près de la fontaine.
	var recruteur = _scene.find_child("Pnj_recruteur", true, false)
	_verifier(recruteur != null, "Kenji Duval attend près de la fontaine")
	var lues := await _parler_a("recruteur")
	_verifier(lues >= 5, "il raconte la disparition des chiens et la Vigie (%d bulles)" % lues)
	_verifier(_id_etape() == "station", "l'objectif suivant est la station Asahi (%s)" % _id_etape())

	# 2. L'escalier de la station.
	await _placer(Vector3(-23, -3.7, 30), PI)
	await _attendre(5)
	_verifier(_id_etape() == "commandante", "arrivé en bas, on doit voir la commandante (%s)" % _id_etape())

	# 3. La commandante donne la mission.
	lues = await _parler_a("commandante")
	_verifier(lues >= 6, "la commandante donne la mission (%d bulles)" % lues)
	_verifier(_id_etape() == "technicienne", "puis direction la salle des portails (%s)" % _id_etape())
	var commandante = _scene.find_child("Pnj_commandante", true, false)
	_verifier(commandante.repliques_speciales.is_empty(), "ensuite, la commandante reprend ses répliques habituelles")

	# 4. Yuki Tanabe.
	lues = await _parler_a("technicienne")
	_verifier(lues >= 3, "Yuki Tanabe prépare le portail (%d bulles)" % lues)
	_verifier(_id_etape() == "portail", "il reste à traverser le portail (%s)" % _id_etape())

	# 5. Le portail de la Préhistoire, traversé à pied.
	var portail = _scene.qg["portails"][0]
	await _placer(portail.global_position + Vector3(0, -3.0, -4.0), PI)
	Input.action_press("avancer")
	await _attendre(60)
	Input.action_release("avancer")
	await _attendre(10)
	_verifier(partis.size() == 1 and partis[0][0] == "Préhistoire", "le joueur part vers la Préhistoire (%s)" % [partis])
	_verifier(partis.size() == 1 and ResourceLoader.exists(partis[0][1]), "l'île de destination existe")
	_verifier(_intro.etape == -1 and not _intro._objectif.visible, "l'intro est terminée")
	_verifier(_intro.intro_terminee(), "c'est enregistré : l'intro ne se rejoue pas")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))

	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
