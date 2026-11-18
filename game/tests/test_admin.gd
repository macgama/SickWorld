extends SceneTree
## Test du mode admin (autoload Admin, touche F9) : choisir son niveau, être
## invincible, commencer un chapitre d'une île et voyager vers une zone.
## Lancement : godot --headless --path game -s res://tests/test_admin.gd

var _echecs := 0
var _profil_test := "_test_admin_%d" % OS.get_process_id()


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
	Profil.activer(_profil_test)
	_lancer.call_deferred()


func _effacer_profil_test() -> void:
	for relatif in Profil.lister(_profil_test):
		DirAccess.remove_absolute(Profil.dossier(_profil_test) + relatif)
	for d in ["sauvegardes/progression", "sauvegardes/inventaires", "sauvegardes", "cartes", ""]:
		DirAccess.remove_absolute(Profil.dossier(_profil_test) + d)


func _lancer() -> void:
	Profil.activer(_profil_test)
	var admin = root.get_node("Admin")
	admin.forcer_pour_tests = true
	print("Test du mode admin")
	_verifier(admin.disponible(), "disponible en solo depuis Godot")
	var scene: Node = load("res://scenes/monde/hikari_bay.tscn").instantiate()
	var intro := scene.find_child("Intro", true, false)
	if intro != null:
		intro.voyage_reel = false
	root.add_child(scene)
	current_scene = scene
	await _attendre(30)
	var joueur = get_first_node_in_group("joueur_local")
	_verifier(joueur != null, "un personnage est en jeu")
	admin.basculer()
	_verifier(admin._panneau.visible, "F9 ouvre le panneau")
	_verifier(admin._zone_voyage.item_count == 2, "zones de Hikari Bay proposées")
	admin._ile_voyage.select(7)
	admin._remplir_zones()
	_verifier(admin._zone_voyage.item_count == 3, "trois zones pour Mayence (%d)" % admin._zone_voyage.item_count)
	admin._ile_chapitre.select(5)
	admin._remplir_chapitres()
	_verifier(admin._chapitre.item_count == 8, "huit chapitres pour le Moyen Âge")

	# Niveau
	admin.choisir_niveau(45)
	var prog = joueur.get_node("Progression")
	_verifier(prog.niveau() == 45, "niveau 45 donné (%d)" % prog.niveau())
	_verifier(joueur.get_node("Combat").niveau == 45, "le combat connaît le niveau")
	admin.choisir_niveau(3)
	_verifier(prog.niveau() == 3, "on peut redescendre au niveau 3")
	_verifier(Progression.points_libres(Progression.donnees(), prog.etat) >= 0, "pas de talents en trop")

	# Invincible, coups mortels, vitesse
	admin.invincible = true
	admin.coups_mortels = true
	admin.vitesse_rapide = true
	for i in 3:
		await process_frame
	var combat = joueur.get_node("Combat")
	var pv: float = combat.pv
	combat.subir(50.0, null)
	_verifier(combat.pv == pv, "invincible : aucun dégât")
	_verifier(combat.multiplicateur_degats() >= 1000.0, "tuer en un coup")
	_verifier(float(joueur.get_meta("admin_vitesse", 1.0)) == 3.0, "course 3 fois plus rapide")
	admin.invincible = false
	admin.coups_mortels = false
	admin.vitesse_rapide = false
	for i in 3:
		await process_frame
	combat.subir(10.0, null)
	_verifier(combat.pv < pv, "désactivé : les dégâts reviennent")

	# Chapitre 4 du Moyen Âge : l'avancement est réécrit et on part à Chartres.
	admin.commencer_chapitre("moyen_age", 4)
	var cfg := ConfigFile.new()
	cfg.load(Profil.chemin("user://progression.cfg"))
	_verifier(cfg.get_value("moyen_age", "etape", "") == "vers_chartres", "avancement mis au chapitre 4")
	_verifier(bool(cfg.get_value("intro", "terminee", false)), "intro de Hikari Bay marquée finie")
	await _attendre(240)
	_verifier(current_scene != null and current_scene.scene_file_path == "res://scenes/monde/moyen_age/chartres.tscn",
			"arrivée à Chartres (%s)" % (current_scene.scene_file_path if current_scene else "?"))
	var quete = get_first_node_in_group("quete")
	_verifier(quete != null and quete.etape_actuelle().get("chapitre", 0) == 4,
			"la quête reprend au chapitre 4 (%s)" % (quete.etape_actuelle().get("id", "") if quete else "?"))
	_verifier(get_first_node_in_group("joueur_local") != null, "le personnage est sur place")

	# En ligne, plus de mode admin.
	admin.forcer_pour_tests = false
	var reseau = root.get_node("Reseau")
	reseau.mode = 2 # Reseau.Mode.REJOINDRE
	_verifier(not admin.disponible(), "indisponible en ligne")
	reseau.mode = 0

	_effacer_profil_test()
	print("Résultat : ", "tout est bon" if _echecs == 0 else "%d échec(s)" % _echecs)
	quit(0 if _echecs == 0 else 1)
