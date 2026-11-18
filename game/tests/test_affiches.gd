extends SceneTree
## Test des affiches d'activités (sans écran) : données, avancée d'une île,
## récompenses, portails. Lancement : godot --headless --path game -s res://tests/test_affiches.gd

const Affiche := preload("res://scripts/interface/affiche_activite.gd")

var _erreurs := 0


func _verifier(condition: bool, message: String) -> void:
	if not condition:
		_erreurs += 1
		printerr("ÉCHEC : ", message)


func _initialize() -> void:
	var toutes := Affiche.donnees()
	_verifier(toutes.size() >= 10, "au moins 10 affiches")
	for id in toutes:
		var a: Dictionary = toutes[id]
		_verifier(String(a.get("titre", "")) != "", id + " : titre")
		_verifier(String(a.get("accroche", "")) != "", id + " : accroche")
		var images: Array = a.get("images", [])
		_verifier(images.size() >= 3, id + " : au moins 3 images")
		for plan in a.get("bande_annonce", []):
			_verifier(int(plan.get("image", 0)) < images.size(), id + " : plan sur une image qui existe")
			_verifier(float(plan.get("duree", 0)) >= 2.0, id + " : plan assez long")
	# Chaque portail ouvert du QG a son affiche.
	for epoque in preload("res://scripts/monde/qg_vigie.gd").EPOQUES:
		_verifier(Affiche.id_du_portail(epoque) != "", "affiche du portail " + epoque)
	# Les donjons de groupe ont leur affiche.
	var donjons = JSON.parse_string(FileAccess.get_file_as_string("res://data/donjons.json"))
	for d in donjons["donjons"]:
		_verifier(Affiche.existe("donjon_" + String(d["id"])), "affiche du donjon " + String(d["id"]))
	# Avancée d'une île lue dans une sauvegarde de test.
	var fichier := "user://test_affiches_%d.cfg" % OS.get_process_id()
	var cfg := ConfigFile.new()
	cfg.save(Profil.chemin(fichier))
	_verifier(Affiche.avancee_ile("grece", fichier)["etat"] == "nouvelle", "île jamais visitée = nouvelle")
	var quete = JSON.parse_string(FileAccess.get_file_as_string("res://data/grece_quete.json"))
	var etape_ch4 := String(quete["chapitres"][3]["etapes"][2]["id"])
	cfg.set_value("grece", "etape", etape_ch4)
	cfg.save(Profil.chemin(fichier))
	var av := Affiche.avancee_ile("grece", fichier)
	_verifier(av["etat"] == "en_cours" and int(av["chapitre"]) == 4, "étape du chapitre 4 = en cours, chapitre 4 (%s)" % str(av))
	cfg.set_value("grece", "etape", "fin")
	cfg.set_value("mayence", "etape", "fin")
	cfg.save(Profil.chemin(fichier))
	_verifier(Affiche.avancee_ile("grece", fichier)["etat"] == "terminee", "8 chapitres finis = terminée")
	_verifier(Affiche.avancee_ile("mayence", fichier)["etat"] == "a_suivre", "Mayence finie pour l'instant = la suite arrive")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profil.chemin(fichier)))
	# Récompenses calculées depuis les données du jeu.
	var r := Affiche.recompenses_ile("chine")
	_verifier(r.size() == 2 and "Panoplies" in r[0] and "Montures" in r[1], "récompenses de la Chine : " + str(r))
	# Sans écran, l'affiche ne s'ouvre pas (l'appelant agit tout de suite).
	_verifier(Affiche.ouvrir(self, "ile_chine") == null, "pas d'affiche en --headless")
	print("test_affiches : ", "OK" if _erreurs == 0 else "%d échec(s)" % _erreurs)
	quit(1 if _erreurs > 0 else 0)
