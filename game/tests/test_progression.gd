extends SceneTree
## Test automatique de la progression : niveaux, XP, talents des 4 classes, titres,
## rattrapage des quêtes déjà faites, et en jeu (loup vaincu, niveau gagné, talent pris).
## Lancement : godot --headless --path game -s res://tests/test_progression.gd

const NOM := "Testeur Progression"
const FICHIER := "user://sauvegardes/progression/testeur_progression.json"

var _echecs := 0


func _verifier(condition: bool, message: String) -> void:
	print("  OK   " if condition else "  ÉCHEC ", message)
	if not condition:
		_echecs += 1


func _attendre(images: int) -> void:
	for i in images:
		await physics_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var d: Dictionary = Progression.donnees()
	_niveaux(d)
	_equilibrage(d)
	_talents(d)
	_titres(d)
	_rattrapage(d)
	await _en_jeu(d)
	print("\n%s" % ("TOUT EST BON" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	quit(1 if _echecs > 0 else 0)


func _niveaux(d: Dictionary) -> void:
	print("Niveaux")
	_verifier(Progression.niveau_pour_xp(d, 0) == 1, "on commence au niveau 1")
	_verifier(Progression.xp_pour_niveau(d, 1) == 130, "niveau 1 → 2 : 130 XP (%d)" % Progression.xp_pour_niveau(d, 1))
	_verifier(Progression.niveau_pour_xp(d, 130) == 2, "130 XP : niveau 2")
	_verifier(Progression.niveau_pour_xp(d, 129) == 1, "129 XP : encore niveau 1")
	var total50 := Progression.xp_total_pour(d, 50)
	_verifier(Progression.niveau_pour_xp(d, total50 * 3) == 50, "pas plus loin que le niveau 50 (%d XP pour l'atteindre)" % total50)
	_verifier(Progression.avancement(d, total50) == Vector2i.ZERO, "au niveau maximum, la barre d'XP est pleine")
	_verifier(Progression.points_gagnes(d, 1) == 0 and Progression.points_gagnes(d, 20) == 19, "1 point de talent par niveau à partir du 2 (19 au niveau 20)")
	_verifier(Progression.xp_ennemi(d, 1, 1) == 11, "loup niveau 1 pour un niveau 1 : 11 XP")
	_verifier(Progression.xp_ennemi(d, 1, 10) < Progression.xp_ennemi(d, 1, 1), "un ennemi bien plus faible rapporte moins")
	_verifier(Progression.xp_ennemi(d, 15, 10) <= int(round(Progression.xp_de(d, "ennemi", 15) * 1.5)), "un ennemi plus fort rapporte plus, plafonné à +50 %")
	var e := Progression.etat_de_depart()
	e["xp"] = Progression.xp_total_pour(d, 10)
	var b := Progression.bonus(d, "lame", e, 220)
	_verifier(int(b["stats"]["pv"]) == 119, "niveau 10 : +54 %% de vie de base (220 → %d)" % (220 + int(b["stats"]["pv"])))
	_verifier(is_equal_approx(float(b["stats"]["degats_pourcent"]), 22.5), "niveau 10 : +22,5 %% de dégâts")


## Combien de niveaux rapportent les quêtes de chaque île (pour vérifier l'équilibre).
func _equilibrage(d: Dictionary) -> void:
	print("\nÉquilibrage (XP des quêtes et des combats)")
	var xp := 0
	var resultats := {}
	for ile in ["prehistoire", "egypte"]:
		var q = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s_quete.json" % ile))
		var principale := 0
		var combats := 0
		for c in q["chapitres"]:
			for et in c["etapes"]:
				var n := Progression.niveau_zone(d, String(et.get("ou", c.get("ou", ""))))
				principale += Progression.xp_de(d, "etape_quete", n)
				if et.get("fin_chapitre", false):
					principale += Progression.xp_de(d, "fin_chapitre", n)
				if et.has("tuer"):
					var ennemi: Dictionary = root.get_node("Donnees").ennemi(String(et["tuer"]))
					var niv := int(ennemi.get("niveau", n))
					combats += Progression.xp_ennemi(d, niv, niv) * int(et.get("nombre", 1))
		# En plus des ennemis des quêtes, on en croise environ 6 par étape en chemin.
		var chemin := 0
		for c in q["chapitres"]:
			for et in c["etapes"]:
				var n := Progression.niveau_zone(d, String(et.get("ou", c.get("ou", ""))))
				chemin += 3 * Progression.xp_ennemi(d, n, n)
		var s = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s_secondaires.json" % ile))
		var secondaires := 0
		for sq in s["quetes"]:
			var zone := String(sq["etapes"][0].get("ou", ""))
			secondaires += Progression.xp_de(d, "quete_secondaire", Progression.niveau_zone(d, zone))
			secondaires += (sq["etapes"] as Array).size() * Progression.xp_de(d, "etape_secondaire", Progression.niveau_zone(d, zone))
		xp += principale + combats + chemin
		var sans := Progression.niveau_pour_xp(d, xp)
		xp += secondaires
		var avec := Progression.niveau_pour_xp(d, xp)
		resultats[ile] = [sans, avec]
		print("       %s : quête principale + combats → niveau %d ; avec les quêtes secondaires → niveau %d" % [ile, sans, avec])
	_verifier(resultats["prehistoire"][0] >= 8 and resultats["prehistoire"][1] <= 11, "Préhistoire : on finit vers le niveau 10")
	_verifier(resultats["egypte"][1] >= 17 and resultats["egypte"][1] <= 20, "Égypte : on finit vers le niveau 20")


func _talents(d: Dictionary) -> void:
	print("\nTalents")
	var donnees = root.get_node("Donnees")
	for classe in ["lame", "rempart", "traqueur", "tisseur"]:
		var voies := Progression.voies(d, classe)
		var ids := {}
		var cles_ok := true
		var de_la_classe: Array = donnees.classe(classe)["competences"]
		for v in voies:
			for t in v["talents"]:
				ids[t["id"]] = true
				for id in t.get("competences", {}):
					var base: Dictionary = donnees.competence(id)
					if base.is_empty() or not id in de_la_classe:
						cles_ok = false
						print("       compétence inconnue ou d'une autre classe : %s (%s)" % [id, t["id"]])
						continue
					for cle in t["competences"][id]:
						var parties := String(cle).split(".")
						var c = base
						for p in parties:
							c = c.get(p) if c is Dictionary else null
						if c == null:
							cles_ok = false
							print("       clé absente : %s.%s (%s)" % [id, cle, t["id"]])
		_verifier(voies.size() == 3 and ids.size() == 12, "%s : 3 voies de 4 talents" % classe)
		_verifier(cles_ok, "%s : chaque talent modifie une vraie compétence de la classe" % classe)

	var e := Progression.etat_de_depart()
	_verifier(Progression.prendre_talent(d, "lame", e, "lame_affutee") != "", "niveau 1 : aucun point de talent")
	e["xp"] = Progression.xp_total_pour(d, 6)
	_verifier(Progression.points_libres(d, e) == 5, "niveau 6 : 5 points")
	_verifier(Progression.prendre_talent(d, "lame", e, "taille_eclair") != "", "palier 2 fermé sans 3 points dans la voie")
	_verifier(Progression.prendre_talent(d, "lame", e, "coup_de_bouclier") != "" and Progression.prendre_talent(d, "lame", e, "cuir_epais") != "", "pas de talent d'une autre classe")
	for i in 3:
		Progression.prendre_talent(d, "lame", e, "lame_affutee")
	_verifier(int(e["talents"]["lame_affutee"]) == 3, "Lame affûtée 3 / 3")
	_verifier(Progression.prendre_talent(d, "lame", e, "lame_affutee") != "", "pas de 4e rang")
	_verifier(Progression.prendre_talent(d, "lame", e, "taille_eclair") == "", "3 points dans Fureur : le palier 2 s'ouvre")
	Progression.prendre_talent(d, "lame", e, "taille_eclair")
	_verifier(Progression.points_libres(d, e) == 0 and Progression.prendre_talent(d, "lame", e, "taille_eclair") != "", "plus de point libre")
	var b := Progression.bonus(d, "lame", e, 220)
	_verifier(is_equal_approx(float(b["stats"]["degats_pourcent"]), 2.5 * 5 + 6.0), "dégâts : +12,5 %% (niveau 6) +6 %% (talent)")
	var taille := Objets.competence_modifiee(donnees.competence("taille_rapide"), b["competences"]["taille_rapide"])
	_verifier(taille["degats"] == [18.0, 22.0] and float(taille["gain"]) == 26.0, "Taille rapide : dégâts 14-18 → 18-22, Élan 20 → 26 (%s, %s)" % [taille["degats"], taille["gain"]])
	# Une sauvegarde trafiquée est corrigée.
	var triche := e.duplicate(true)
	triche["talents"]["coup_de_grace"] = 1
	triche["talents"]["tourbillon_acier"] = 9
	triche["titre"] = "batisseur_de_gizeh"
	var propre := Progression.valider(d, "lame", triche)
	_verifier(not propre["talents"].has("coup_de_grace") and not propre["talents"].has("tourbillon_acier"), "sauvegarde : talents sans les points nécessaires retirés")
	_verifier(int(propre["talents"].get("taille_eclair", 0)) == 2, "sauvegarde : les talents permis restent")
	_verifier(propre["titre"] == "", "sauvegarde : on ne porte pas un titre qu'on n'a pas")
	# Tout dépenser au niveau 20 : 2 voies complètes + 1 point.
	var max_e := Progression.etat_de_depart()
	max_e["xp"] = Progression.xp_total_pour(d, 20)
	var pris := 0
	for v in Progression.voies(d, "tisseur"):
		for t in v["talents"]:
			while Progression.prendre_talent(d, "tisseur", max_e, t["id"]) == "":
				pris += 1
	_verifier(pris == 19, "niveau 20 : les 19 points se placent (%d)" % pris)
	Progression.oublier_talents(max_e)
	_verifier(Progression.points_libres(d, max_e) == 19, "oublier les talents rend tous les points")


func _titres(d: Dictionary) -> void:
	print("\nTitres")
	var e := Progression.etat_de_depart()
	var gagnes := Progression.nouveaux_titres(d, e, {"egypte": 7})
	_verifier(gagnes == ["recrue"] and e["titre"] == "recrue", "« Recrue de la Vigie » dès le départ, porté")
	e["faits"].append("etape:prehistoire:vers_le_camp")
	e["tues"]["loup_fracture"] = 30
	e["tues"]["loup"] = 10
	gagnes = Progression.nouveaux_titres(d, e, {"egypte": 7})
	_verifier("ami_du_clan" in gagnes and "chasseur_de_la_steppe" in gagnes, "Ami du clan (chapitre 2) et Chasseur de la steppe (40 loups)")
	for id in ["pain_et_biere", "miou", "remede_peseshet", "marque_equipe", "intrus_modernes_egypte", "crue_qui_monte"]:
		e["faits"].append("secondaire:" + id)
		e["faits"].append("secondaire_ile:egypte:" + id)
	gagnes = Progression.nouveaux_titres(d, e, {"egypte": 7})
	_verifier("compagnon_de_kheops" in gagnes and not "ami_des_batisseurs" in gagnes, "Compagnon de Khéops ; pas encore Ami des bâtisseurs (6 / 7)")
	e["faits"].append("secondaire_ile:egypte:senet_ouni")
	_verifier("ami_des_batisseurs" in Progression.nouveaux_titres(d, e, {"egypte": 7}), "les 7 secondaires d'Égypte : Ami des bâtisseurs")
	_verifier(Progression.choisir_titre(d, e, "batisseur_de_gizeh") != "", "on ne porte pas un titre non obtenu")
	_verifier(Progression.choisir_titre(d, e, "ami_du_clan") == "" and e["titre"] == "ami_du_clan", "on porte Ami du clan")
	var ids := {}
	for t in Progression.liste_titres(d):
		ids[t["id"]] = true
	_verifier(ids.size() == Progression.liste_titres(d).size(), "chaque titre a un identifiant unique")
	# Les étapes nommées par les titres existent bien.
	var etapes_ok := true
	for t in Progression.liste_titres(d):
		if t["condition"].has("etape"):
			var parts := String(t["condition"]["etape"]).split(":")
			var q = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s_quete.json" % parts[0]))
			var trouve := false
			for c in q["chapitres"]:
				for et in c["etapes"]:
					trouve = trouve or String(et.get("id", "")) == parts[1]
			if not trouve:
				etapes_ok = false
				print("       étape introuvable : ", t["condition"]["etape"])
	_verifier(etapes_ok, "les étapes des titres existent dans les quêtes")


func _rattrapage(d: Dictionary) -> void:
	print("\nRattrapage des quêtes faites avant les niveaux")
	var chemin := "user://test_rattrapage.cfg"
	var cfg := ConfigFile.new()
	cfg.set_value("prehistoire", "etape", "fin")
	cfg.set_value("prehistoire_secondaires", "etat_main_sur_la_paroi", 999)
	cfg.set_value("prehistoire_evenements", "reussis_tempete_blanche", 2)
	cfg.set_value("egypte", "etape", "fin_chapitre_2")
	cfg.save(chemin)
	var e := Progression.etat_de_depart()
	Progression.rattrapage(e, chemin)
	var n := Progression.niveau(d, e)
	_verifier(n >= 8 and n <= 11, "Préhistoire finie + début de l'Égypte : niveau %d" % n)
	_verifier("etape:prehistoire:fresque_finale" in e["faits"] and "secondaire:main_sur_la_paroi" in e["faits"], "les quêtes faites sont notées")
	_verifier(not "etape:egypte:fin_chapitre_2" in e["faits"] and "etape:egypte:fin_chapitre_1" in e["faits"], "l'étape en cours n'est pas comptée")
	var titres := Progression.nouveaux_titres(d, e, {})
	_verifier("gardien_des_murs" in titres and "celui_qui_a_laisse_sa_trace" in titres and "rescape_de_la_crue" in titres, "les titres déjà mérités sont donnés")
	DirAccess.remove_absolute(chemin)


func _en_jeu(d: Dictionary) -> void:
	print("\nEn jeu")
	DirAccess.remove_absolute(Profil.chemin(FICHIER))
	DirAccess.remove_absolute(Profil.chemin("user://sauvegardes/inventaires/testeur_progression.json"))
	root.get_node("Reseau").nom_joueur = NOM
	var scene: Node = load("res://scenes/monde/colline_de_test.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _attendre(30)
	var joueur = get_first_node_in_group("joueur_local")
	var prog = joueur.get_node("Progression")
	var moi = joueur.get_node("Combat")
	var gains: Array = []
	var niveaux: Array = []
	prog.xp_gagnee.connect(func(m, r): gains.append(m))
	prog.niveau_gagne.connect(func(n): niveaux.append(n))
	_verifier(moi.niveau == 1 and prog.niveau() == 1, "le personnage est niveau 1")
	_verifier(prog.titre_affiche == "Recrue de la Vigie", "il porte « Recrue de la Vigie »")
	var pv_depart: float = moi.pv_max

	# Un loup vaincu rapporte de l'XP.
	var loup = scene.get_node("Partie/Loups/CampNord_Loup1")
	var lc = loup.get_node("Combat")
	lc.subir(5.0, moi)
	await _attendre(2)
	lc.subir(10000.0, moi)
	await _attendre(3)
	_verifier(int(prog.etat["xp"]) == 11 and gains == [11], "loup vaincu : +11 XP (%s)" % [prog.etat["xp"]])
	_verifier(int(prog.etat["tues"].get(String(loup.type_ennemi), 0)) == 1, "le loup est compté")

	# Assez d'XP pour le niveau 3 d'un coup.
	prog.gagner_xp(Progression.xp_total_pour(d, 3), "Test")
	await _attendre(2)
	_verifier(prog.niveau() == 3 and moi.niveau == 3 and niveaux == [3], "niveau 3 : annoncé et visible par tous")
	_verifier(moi.pv_max > pv_depart + 20, "plus de vie au niveau 3 (%d → %d)" % [pv_depart, moi.pv_max])
	# Les talents se choisissent hors combat : on attend la fin du combat contre le loup.
	for autre in scene.get_node("Partie/Loups").get_children():
		autre.queue_free()
	await _attendre(2)
	moi.dernier_moment_de_combat = -100.0
	_verifier(not moi.en_combat(), "le combat est fini")
	var degats_avant: float = moi.bonus_degats
	prog.prendre_talent("lame_affutee")
	await _attendre(2)
	_verifier(int(prog.etat["talents"].get("lame_affutee", 0)) == 1, "talent Lame affûtée pris par la demande normale")
	_verifier(is_equal_approx(moi.bonus_degats, degats_avant + 2.0), "le talent s'applique au combat (+2 %% : %s)" % moi.bonus_degats)
	prog.prendre_talent("coup_de_grace")
	await _attendre(2)
	_verifier(not prog.etat["talents"].has("coup_de_grace"), "talent du palier 4 refusé")
	prog.choisir_titre("gardien_des_murs")
	await _attendre(2)
	_verifier(prog.titre_affiche == "Recrue de la Vigie", "titre non obtenu refusé")
	_verifier(FileAccess.file_exists(Profil.chemin(FICHIER)), "la progression est enregistrée")
	var lu = JSON.parse_string(FileAccess.get_file_as_string(Profil.chemin(FICHIER)))
	_verifier(lu is Dictionary and int(lu["talents"].get("lame_affutee", 0)) == 1, "la sauvegarde contient le talent")

	# Fenêtre Talents et titres
	var hud = get_first_node_in_group("hud")
	if hud == null:
		for n in scene.find_children("*", "CanvasLayer", true, false):
			if n.has_method("basculer_talents"):
				hud = n
	_verifier(hud != null, "l'interface est là")
	if hud != null:
		hud.basculer_talents()
		await _attendre(3)
		var fenetre = hud._fenetre_progression
		_verifier(fenetre.visible, "touche N : la fenêtre s'ouvre")
		var bouton = fenetre.find_child("Talent_lame_affutee", true, false)
		_verifier(bouton != null and String(bouton.text).contains("1 / 3"), "Lame affûtée affichée à 1 / 3")
		bouton.pressed.emit()
		await _attendre(3)
		_verifier(int(prog.etat["talents"].get("lame_affutee", 0)) == 2, "un clic ajoute un rang")
	DirAccess.remove_absolute(Profil.chemin(FICHIER))
	DirAccess.remove_absolute(Profil.chemin("user://sauvegardes/inventaires/testeur_progression.json"))
