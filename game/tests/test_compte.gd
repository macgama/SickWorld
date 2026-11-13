extends SceneTree
## Test automatique des profils de sauvegarde et du compte en ligne (Nakama).
## Lancement : godot --headless --path game -s res://tests/test_compte.gd -- --adresse=127.0.0.1:7350
## Sans serveur Nakama démarré, seule la partie hors ligne est testée.

var _echecs := 0
var Compte


func _verifier(condition: bool, message: String) -> void:
	if condition:
		print("  OK   ", message)
	else:
		print("  ÉCHEC ", message)
		_echecs += 1


func _initialize() -> void:
	_lancer.call_deferred()


func _option(nom: String, defaut: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.get_slice("=", 1)
	return defaut


func _lancer() -> void:
	Compte = root.get_node("/root/Compte")
	var adresse_avant: String = Compte.adresse

	# 1. Hors ligne : les sauvegardes du personnage vont dans le profil actif.
	_verifier(Profil.nom == Profil.HORS_LIGNE, "sans compte, on joue sur le profil hors ligne")
	_verifier(Profil.chemin("user://progression.cfg") == "user://profils/hors_ligne/progression.cfg",
			"la progression est rangée dans le profil")
	_verifier(Profil.chemin("user://cartes/lea.cfg") == "user://profils/hors_ligne/cartes/lea.cfg",
			"les cartes aussi")
	_verifier(Profil.chemin("user://graphismes.cfg") == "user://graphismes.cfg",
			"les réglages du PC restent hors du profil")
	_verifier(Profil.chemin("user://test_x.cfg") == "user://test_x.cfg", "les fichiers de test ne bougent pas")
	_verifier(Compte.verifier("pas-un-mail", "motdepasse", "", false) != "", "un e-mail invalide est refusé")
	_verifier(Compte.verifier("a@b.fr", "court", "", false) != "", "un mot de passe trop court est refusé")
	_verifier(Compte.verifier("a@b.fr", "motdepasse", "x", true) != "", "un pseudo trop court est refusé")
	_verifier(Compte.verifier("a@b.fr", "motdepasse", "Léa_42", true) == "", "un bon formulaire passe")

	# 2. Serveur injoignable : message clair, on reste hors ligne.
	Compte.changer_adresse("127.0.0.1:1")
	var probleme: String = await Compte.se_connecter("personne@exemple.fr", "motdepasse")
	_verifier(probleme.contains("ne répond pas"), "serveur éteint : « %s »" % probleme)
	_verifier(not Compte.a_un_compte and Profil.nom == Profil.HORS_LIGNE, "on reste hors ligne")

	# 3. Avec un vrai serveur Nakama.
	Compte.changer_adresse(_option("adresse", "127.0.0.1:7350"))
	var n := randi() % 1000000
	var email := "testeur%d@exemple.fr" % n
	var pseudo := "testeur%d" % n
	probleme = await Compte.creer_compte(email, "motdepasse1", pseudo)
	if probleme.contains("ne répond pas"):
		print("  (pas de serveur Nakama à %s : partie en ligne non testée)" % Compte.adresse)
	else:
		_verifier(probleme == "", "création du compte (%s)" % probleme)
		_verifier(Compte.en_ligne and Compte.pseudo == pseudo, "connecté en tant que %s" % Compte.pseudo)
		_verifier(Profil.nom == "compte_" + Compte.id_utilisateur, "le compte a son propre profil")
		if Profil.a_un_personnage(Profil.HORS_LIGNE):
			_verifier(Profil.a_un_personnage(), "le personnage hors ligne a été confié au nouveau compte")

		# Une progression écrite pendant le jeu part sur le serveur.
		var cfg := ConfigFile.new()
		cfg.set_value("test", "valeur", 42)
		cfg.save(Profil.chemin("user://progression.cfg"))
		DirAccess.make_dir_recursive_absolute(Profil.chemin("user://cartes"))
		var carte := ConfigFile.new()
		carte.set_value("brouillard", "colline", PackedByteArray([1, 2, 3, 4]))
		carte.save(Profil.chemin("user://cartes/testeur.cfg"))
		await Compte.synchroniser()
		var distants = await Compte._lister_distant()
		_verifier(distants is Dictionary and distants.has("progression.cfg") and distants.has("cartes/testeur.cfg"),
				"la progression et la carte sont sur le serveur")
		_verifier(distants is Dictionary and distants.get("progression.cfg", {}).get("empreinte") == FileAccess.get_md5(Profil.chemin("user://progression.cfg")),
				"la copie du serveur est identique")

		# Un autre PC : le profil local est vide, on se reconnecte, tout redescend.
		var dossier := Profil.dossier()
		await Compte.se_deconnecter()
		_verifier(Profil.nom == Profil.HORS_LIGNE and not Compte.a_un_compte, "déconnexion : retour au profil hors ligne")
		_effacer_dossier(dossier)
		probleme = await Compte.se_connecter(email, "motdepasse1")
		_verifier(probleme == "", "reconnexion (%s)" % probleme)
		var relu := ConfigFile.new()
		relu.load(Profil.chemin("user://progression.cfg"))
		_verifier(relu.get_value("test", "valeur", 0) == 42, "sur un « autre PC », la progression redescend du serveur")
		var carte_relue := ConfigFile.new()
		carte_relue.load(Profil.chemin("user://cartes/testeur.cfg"))
		_verifier(carte_relue.get_value("brouillard", "colline", PackedByteArray()) == PackedByteArray([1, 2, 3, 4]),
				"la carte aussi")

		# Un fichier supprimé sur le PC disparaît aussi du serveur.
		DirAccess.remove_absolute(Profil.chemin("user://cartes/testeur.cfg"))
		await Compte.synchroniser()
		distants = await Compte._lister_distant()
		_verifier(distants is Dictionary and not distants.has("cartes/testeur.cfg"), "un fichier effacé l'est aussi en ligne")

		# Erreurs courantes.
		dossier = Profil.dossier()
		await Compte.se_deconnecter()
		probleme = await Compte.se_connecter(email, "mauvais-mdp")
		_verifier(probleme.contains("incorrect"), "mauvais mot de passe : « %s »" % probleme)
		probleme = await Compte.se_connecter("inconnu%d@exemple.fr" % n, "motdepasse1")
		_verifier(probleme.contains("Aucun compte"), "compte inconnu : « %s »" % probleme)
		probleme = await Compte.creer_compte("autre%d@exemple.fr" % n, "motdepasse1", pseudo)
		_verifier(probleme.contains("pseudo"), "pseudo déjà pris : « %s »" % probleme)
		_verifier(Profil.nom == Profil.HORS_LIGNE, "après ces erreurs, on est toujours hors ligne")
		_effacer_dossier(dossier)
		if Compte.a_un_compte:
			await Compte.se_deconnecter()

	Compte.changer_adresse(adresse_avant)
	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)


func _effacer_dossier(dossier: String) -> void:
	for relatif in Profil.lister(dossier.trim_prefix(Profil.RACINE).trim_suffix("/")):
		DirAccess.remove_absolute(dossier + relatif)
	DirAccess.remove_absolute(dossier + Profil.FICHIER_SYNCHRO)
