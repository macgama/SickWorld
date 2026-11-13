extends SceneTree
## Test automatique des missions secondaires de Hikari Bay : on accepte chaque
## mission en parlant à son donneur, on fait les étapes (parler, ramasser,
## installer) et on vérifie la récompense et la sauvegarde.
## Lancement : godot --headless --path game -s res://tests/test_quetes.gd

const FICHIER := "user://test_quetes_progression.cfg"

var _echecs := 0
var _scene: Node
var _joueur
var _quetes
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


func _trouver_pnj(id: String):
	for pnj in get_nodes_in_group("pnj"):
		if pnj.identifiant == id:
			return pnj
	return null


## Va voir un personnage et lit tout son dialogue. Renvoie le nombre de bulles.
func _parler_a(id: String) -> int:
	var pnj = _trouver_pnj(id)
	if pnj == null:
		return 0
	var devant: Vector3 = pnj.global_position - pnj.global_transform.basis.z * 1.6
	await _placer(devant + Vector3(0, 0.3, 0), pnj.rotation.y + PI)
	await _appuyer_f()
	var lues := 0
	while _dialogue.est_ouvert() and lues < 30:
		lues += 1
		await _appuyer_f()
	return lues


## Ramasse ou utilise tous les objets de l'étape en cours.
func _utiliser_objets(id: String) -> int:
	var faits := 0
	for n in 10:
		var cle := "%s:%d" % [id, n]
		if not _quetes._objets.has(cle):
			continue
		var objet: Node3D = _quetes._objets[cle]
		var p := objet.global_position
		await _placer(Vector3(p.x, 0.3, p.z) + objet.global_transform.basis.z * 1.0, 0.0)
		await _appuyer_f()
		faits += 1
	return faits


func _lancer() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))
	_scene = load("res://scenes/monde/hikari_bay.tscn").instantiate()
	_quetes = _scene.get_node("Quetes")
	_quetes.fichier_progression = FICHIER
	# L'intro n'est pas testée ici : on la considère comme terminée.
	var intro = _scene.get_node("Intro")
	intro.fichier_progression = FICHIER
	var cfg := ConfigFile.new()
	cfg.set_value("intro", "terminee", true)
	cfg.save(FICHIER)
	root.add_child(_scene)
	await _attendre(30)
	_joueur = get_first_node_in_group("joueur_local")
	_dialogue = get_first_node_in_group("dialogue")
	print("Test des missions secondaires")
	_verifier(_quetes.quetes.size() >= 3, "%d missions chargées" % _quetes.quetes.size())
	for id in ["kuro", "kaminari", "ecran"]:
		var donneur: String = _quetes.quete(id)["donneur"]
		_verifier(_trouver_pnj(donneur) != null, "le donneur de « %s » est en ville (%s)" % [id, donneur])
		var marque = _quetes._marques.get(donneur)
		_verifier(marque != null and marque.visible and marque.text == "!", "un « ! » flotte au-dessus de %s" % donneur)

	# 1. Kuro a disparu : parler, ramasser 3 affiches, revenir.
	var lues := await _parler_a("mme_sato")
	_verifier(lues >= 3 and _quetes.etat("kuro") == "active", "Mme Sato confie la mission (%d bulles)" % lues)
	_verifier(_quetes._suivi.visible and "Kuro" in _quetes._suivi_titre.text, "la mission suivie s'affiche : %s" % _quetes._suivi_objectif.text)
	_verifier(_quetes._objets.size() == 3, "trois affiches sont apparues en ville")
	var faits := await _utiliser_objets("kuro")
	_verifier(faits == 3 and _quetes.etats["kuro"]["etape"] == 1, "on ramasse les trois affiches")
	_verifier(_quetes._marques["mme_sato"].text == "?", "un « ? » indique de retourner voir Mme Sato")
	await _parler_a("mme_sato")
	_verifier(_quetes.etat("kuro") == "terminee", "mission « Kuro a disparu » accomplie")

	# 2. Un bol pour la route : Goro -> Okada -> Goro.
	await _parler_a("chef_goro")
	_verifier(_quetes.etat("kaminari") == "active", "le chef Goro confie sa mission")
	await _parler_a("mme_okada")
	_verifier(_quetes.etats["kaminari"]["etape"] == 1, "Mme Okada donne les poireaux")
	await _parler_a("chef_goro")
	_verifier(_quetes.etat("kaminari") == "terminee", "mission « Un bol pour la route » accomplie")

	# 3. L'écran qui grésille : Nina -> 3 capteurs -> Nina.
	await _parler_a("nina")
	_verifier(_quetes.etat("ecran") == "active", "Nina confie sa mission")
	faits = await _utiliser_objets("ecran")
	_verifier(faits == 3 and _quetes.etats["ecran"]["etape"] == 1, "on installe les trois capteurs")
	await _parler_a("nina")
	_verifier(_quetes.etat("ecran") == "terminee", "mission « L'écran qui grésille » accomplie")

	# Après coup : plus de marques, des répliques de remerciement, le journal.
	var visibles := 0
	for m in _quetes._marques.values():
		visibles += 1 if m.visible else 0
	_verifier(visibles == 0, "plus aucun « ! » ni « ? » une fois tout accompli")
	var appui := InputEventAction.new()
	appui.action = "journal"
	appui.pressed = true
	Input.parse_input_event(appui)
	await _attendre(4)
	_verifier(_quetes._journal.visible and "Accomplies" in _quetes._journal_texte.text, "J ouvre le journal des missions")
	var relu := ConfigFile.new()
	relu.load(FICHIER)
	_verifier(relu.get_value("quetes", "ecran", {}).get("etat", "") == "terminee", "l'avancement est sauvegardé")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FICHIER))

	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
