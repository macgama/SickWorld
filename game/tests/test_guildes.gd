extends SceneTree
## Test automatique des GUILDES, sans réseau (le PC est son propre serveur, comme en jeu « seul »).
## Lancement : godot --headless --path game -s res://tests/test_guildes.gd
##
## 1. Les règles (scripts/guildes/regles_guildes.gd) : nom, rangs, banque, niveaux, contrats.
## 2. L'autoload Guildes dans la vraie ville : fonder au registraire, deux faux joueurs
##    (invitation, rangs, exclusion), banque au coffre, contrats qui avancent quand on
##    vainc des ennemis, sceaux reçus, ancienne guilde locale reprise, guilde sur un autre serveur.

const R := preload("res://scripts/guildes/regles_guildes.gd")

var _echecs := 0
var _profil := "_test_guildes_%d" % OS.get_process_id()


func _verifier(condition: bool, message: String) -> void:
	print("  OK   " if condition else "  ÉCHEC ", message)
	if not condition:
		_echecs += 1


func _images(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	print("Règles des guildes")
	_tester_regles()
	print("Guildes dans la ville")
	await _tester_en_ville()
	for relatif in Profil.lister(_profil):
		DirAccess.remove_absolute(Profil.dossier(_profil) + relatif)
	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)


func _tester_regles() -> void:
	var d := R.donnees()
	var cat: Dictionary = root.get_node("Donnees").objets
	_verifier(not d.is_empty(), "data/guildes.json se lit")
	_verifier(R.raison_nom(d, "Ab", []) != "", "nom trop court refusé")
	_verifier(R.raison_nom(d, "Ordre du Loup", []) != "", "nom d'une guilde du décor refusé")
	_verifier(R.raison_nom(d, "les gardiens", ["Les Gardiens"]) != "", "nom déjà pris refusé (sans tenir compte des majuscules)")
	_verifier(R.raison_nom(d, "Les Gardiens du Temps", []) == "", "bon nom accepté")
	var g := R.nouvelle(d, "Les Gardiens du Temps", 1, "Alice", 1000)
	_verifier(R.rang_de(g, "alice") == "maitre" and R.maitre(g) == "Alice", "le fondateur est maître de guilde")
	_verifier((g["banque"] as Array).size() == R.places_banque(d, g), "banque de %d places au niveau 1" % R.places_banque(d, g))
	R.ajouter_membre(d, g, "Bob", "recrue", 1001)
	R.ajouter_membre(d, g, "Chloé", "recrue", 1002)
	_verifier(R.changer_rang(d, g, "Bob", "Chloé", -1, 1003) != "", "une recrue ne peut pas promouvoir")
	_verifier(R.changer_rang(d, g, "Alice", "Bob", -1, 1003) == "" and R.rang_de(g, "Bob") == "membre", "le maître promeut Bob membre")
	_verifier(R.changer_rang(d, g, "Alice", "Bob", -1, 1003) == "" and R.rang_de(g, "Bob") == "officier", "puis officier")
	_verifier(R.changer_rang(d, g, "Alice", "Bob", -1, 1003) != "" and R.rang_de(g, "Bob") == "officier", "on ne nomme pas maître par promotion")
	_verifier(R.changer_rang(d, g, "Bob", "Chloé", -1, 1004) == "" and R.rang_de(g, "Chloé") == "membre", "un officier promeut une recrue membre")
	_verifier(R.changer_rang(d, g, "Bob", "Chloé", -1, 1004) != "", "mais pas jusqu'à son propre rang")
	_verifier(not R.au_dessus(d, g, "Bob", "Alice"), "un officier ne peut rien contre le maître")
	# Banque
	_verifier(R.deposer(cat, d, g, "silex", 30) == 0, "dépôt de 30 silex")
	var total := 0
	for c in g["banque"]:
		total += int(c.get("n", 0)) if String(c.get("id", "")) == "silex" else 0
	_verifier(total == 30 and String(g["banque"][0]["id"]) == "silex", "les silex sont rangés en piles dans la banque (%d)" % total)
	var jour := 500
	_verifier(R.retraits_restants(d, g, "Alice", jour) == -1, "le maître sort sans limite")
	_verifier(R.retraits_restants(d, g, "Chloé", jour) == 5, "un membre sort 5 objets par jour")
	for i in 5:
		R.noter_retrait(g, "Chloé", jour)
	_verifier(R.retraits_restants(d, g, "Chloé", jour) == 0 and R.retraits_restants(d, g, "Chloé", jour + 1) == 5,
			"limite atteinte aujourd'hui, remise à zéro demain")
	R.ajouter_membre(d, g, "Dan", "recrue", 1005)
	_verifier(R.retraits_restants(d, g, "Dan", jour) == 0, "une recrue ne sort rien")
	# Niveaux
	_verifier(R.niveau(d, 0) == 1 and R.niveau(d, 300) == 2 and R.niveau(d, 999999) == R.niveau_max(d), "niveaux d'après l'XP")
	# Contrats
	var semaine := 2900
	R.verifier_semaine(d, g, semaine)
	var liste: Array = g["contrats"]["liste"]
	_verifier(liste.size() == 3, "3 contrats tirés pour la semaine")
	var autre := R.tirer_contrats(d, g, semaine)
	_verifier(autre["liste"].map(func(c): return c["id"]) == liste.map(func(c): return c["id"]), "même tirage pour la même semaine")
	var c0: Dictionary = liste[0]
	_verifier(int(c0["nombre"]) == int(R.contrat_modele(d, String(c0["id"]))["base"]) + int(R.contrat_modele(d, String(c0["id"]))["par_membre"]) * 3,
			"le nombre à atteindre tient compte des 4 membres (%d)" % int(c0["nombre"]))
	var res := R.contribuer(d, g, "Bob", String(c0["type"]), int(c0["nombre"]) - 1, semaine)
	_verifier(res["contrats_finis"].is_empty() and not liste[0]["fini"], "presque fini…")
	res = R.contribuer(d, g, "Chloé", String(c0["type"]), 5, semaine)
	_verifier(liste[0]["fini"] and res["contrats_finis"].size() == 1, "contrat accompli")
	_verifier(res["recompenses"].has("bob") and res["recompenses"].has("chloé") and not res["recompenses"].has("alice"),
			"les sceaux vont à ceux qui ont aidé (%s)" % str(res["recompenses"]))
	_verifier(int(g["contrats"]["aides"]["0"]["chloé"]) == 1, "on ne compte que ce qui a servi")
	for i in range(1, liste.size()):
		R.contribuer(d, g, "Dan", String(liste[i]["type"]), int(liste[i]["nombre"]), semaine)
	_verifier(g["contrats"]["semaine_complete"], "les 3 contrats accomplis : semaine complète")
	_verifier(((g["a_donner"]["bob"] as Array).size() == 2), "Bob reçoit aussi le bonus de la semaine")
	_verifier(R.niveau(d, int(g["xp"])) >= 2 and (g["banque"] as Array).size() == R.places_banque(d, g), "la guilde monte de niveau et sa banque grandit (niv. %d, %d places)" % [R.niveau(d, int(g["xp"])), (g["banque"] as Array).size()])
	R.verifier_semaine(d, g, semaine + 1)
	_verifier(not g["contrats"]["semaine_complete"] and int(R.membre(g, "Bob")["semaine"]) == 0, "nouvelle semaine : nouveaux contrats")
	_verifier(R.type_ennemi(d, "loup_fracture_foret") == "fracture" and R.type_ennemi(d, "isfet") == "chef" and R.type_ennemi(d, "loup") == "ennemi",
			"types d'ennemis (fracture, chef, ennemi)")
	# Départ du maître
	var nouveau := R.retirer_membre(d, g, "Alice")
	_verifier(nouveau == "Bob" and R.rang_de(g, "Bob") == "maitre", "le maître part : l'officier le plus haut le remplace")


## Un faux joueur sur ce « serveur » (le PC lui-même) : un personnage dans la scène et un nom.
func _faux_joueur(partie: Node, id: int, nom: String) -> Node:
	var reseau = root.get_node("Reseau")
	reseau.noms[id] = nom
	partie.ajouter_joueur(id, nom)
	await _images(5)
	for j in get_nodes_in_group("joueur"):
		if j.name == str(id):
			return j
	return null


func _info_recue(social, morceau: String) -> bool:
	for m in social.historique:
		if String(m["texte"]).contains(morceau):
			return true
	return false


func _tester_en_ville() -> void:
	Profil.activer(_profil)
	var reseau = root.get_node("Reseau")
	var guildes = root.get_node("Guildes")
	var social = root.get_node("Social")
	# Une ancienne guilde locale (avant que le serveur gère les guildes).
	var ancien := ConfigFile.new()
	ancien.set_value("guilde", "nom", "Les Anciens")
	ancien.set_value("guilde", "couleur", 3)
	ancien.save(Profil.chemin("user://progression.cfg"))
	var scene: Node = load(reseau.SCENE_HUB).instantiate()
	var intro := scene.find_child("Intro", true, false)
	if intro != null:
		intro.voyage_reel = false
	root.add_child(scene)
	current_scene = scene
	var fin := Time.get_ticks_msec() + 60000
	while get_first_node_in_group("joueur_local") == null and Time.get_ticks_msec() < fin:
		await _images(5)
	var moi = get_first_node_in_group("joueur_local")
	_verifier(moi != null, "la ville est chargée, le joueur est là")
	await _images(40)
	var nom_moi: String = reseau.noms[root.multiplayer.get_unique_id()]
	_verifier(guildes.a_une_guilde() and String(guildes.guilde["nom"]) == "Les Anciens",
			"l'ancienne guilde locale est reprise par le serveur (%s)" % guildes.guilde.get("nom", "aucune"))
	_verifier(int(guildes.guilde.get("couleur", -1)) == 3 and String(guildes.guilde["mon_rang"]) == "maitre", "avec sa couleur, et on en est le maître")
	var appart := get_first_node_in_group("appartement")
	_verifier(appart != null and appart.get_node_or_null("BanniereGuildeMaison") != null, "sa bannière est dans la Maison des guildes")
	_verifier(get_first_node_in_group("coffre_guilde") != null, "le coffre de guilde est dans la Maison des guildes")
	var fenetre = guildes.get("_interface")
	_verifier(fenetre != null, "la fenêtre Guilde est installée")
	# On quitte cette guilde (dissolution : on est seul) puis on en fonde une au registraire.
	guildes.quitter()
	await _images(3)
	_verifier(not guildes.a_une_guilde() and guildes.nom_local() == "", "dernier membre : la guilde est dissoute")
	var r = appart.fonder_guilde("Les Veilleurs", 0)
	_verifier(r != "", "le registraire refuse un nom de la ville (%s)" % r)
	appart._fenetre.visible = true
	appart._champ_nom.text = "Les Gardiens de Kairo"
	appart._choisir_couleur(1)
	appart._valider()
	await _images(3)
	_verifier(guildes.a_une_guilde() and String(guildes.guilde["nom"]) == "Les Gardiens de Kairo" and not appart.fondation_ouverte(),
			"guilde fondée au registraire")
	_verifier(guildes.nom_local() == "Les Gardiens de Kairo", "elle est gardée sur ce PC (bannière, discussion)")
	_verifier(FileAccess.file_exists(Profil.chemin(guildes.fichier_serveur)), "le serveur l'a enregistrée")
	_verifier(guildes.guilde["contrats"]["liste"].size() == 3, "trois contrats pour la semaine")

	# Deux autres joueurs.
	var partie := get_first_node_in_group("partie")
	var bob = await _faux_joueur(partie, 9001, "Bob")
	var chloe = await _faux_joueur(partie, 9002, "Chloé")
	_verifier(bob != null and chloe != null, "deux faux joueurs dans la ville")
	guildes.inviter("Bob")
	await _images(2)
	_verifier(guildes._invitations.has("bob"), "invitation envoyée à Bob")
	guildes.expediteur_force = 9001
	guildes.repondre_invitation(true)
	guildes.expediteur_force = 0
	await _images(2)
	_verifier(R.est_membre(guildes.guilde_de(nom_moi), "Bob"), "Bob rejoint la guilde")
	_verifier(String(R.rang_de(guildes.guilde_de("Bob"), "Bob")) == "recrue", "Bob est recrue")
	guildes.expediteur_force = 9001
	guildes.inviter("Chloé")
	guildes.expediteur_force = 0
	_verifier(not guildes._invitations.has("chloé"), "une recrue ne peut pas inviter")
	guildes.promouvoir("Bob")
	guildes.promouvoir("Bob")
	await _images(2)
	_verifier(R.rang_de(guildes.guilde_de("Bob"), "Bob") == "officier", "Bob promu officier")
	guildes.expediteur_force = 9001
	guildes.inviter("Chloé")
	guildes.expediteur_force = 9002
	guildes.repondre_invitation(true)
	guildes.expediteur_force = 0
	_verifier(guildes.est_dans_ma_guilde("Chloé") or R.est_membre(guildes.guilde_de("Chloé"), "Chloé"), "un officier invite Chloé, elle accepte")
	social.historique.clear()
	social.envoyer("guilde", "Bonjour la guilde !")
	await _images(2)
	_verifier(social.historique.any(func(m): return m["canal"] == "guilde" and String(m["texte"]).contains("Bonjour")), "le canal Guilde marche (/gu)")

	# Banque : loin du coffre, puis au coffre.
	var inv = moi.get_node("Inventaire")
	var avant := Artisanat_compter(inv.etat, "silex")
	inv.recevoir([{"id": "silex", "n": 12}])
	await _images(2)
	var case_silex := -1
	for i in (inv.etat["cases"] as Array).size():
		if String((inv.etat["cases"][i] as Dictionary).get("id", "")) == "silex":
			case_silex = i
	social.historique.clear()
	guildes.deposer(case_silex)
	await _images(2)
	_verifier(_info_recue(social, "Approche-toi du coffre"), "loin du coffre : impossible de déposer")
	var coffre := get_first_node_in_group("coffre_guilde") as Node3D
	moi.teleporter(coffre.global_position + Vector3(1.5, -1.0, 0), 0.0)
	await _images(10)
	guildes.deposer(case_silex)
	await _images(3)
	var g: Dictionary = guildes.guilde_de(nom_moi)
	var dans_banque := 0
	for c in g["banque"]:
		if String((c as Dictionary).get("id", "")) == "silex":
			dans_banque += int(c["n"])
	_verifier(dans_banque >= 12 and Artisanat_compter(inv.etat, "silex") == 0, "silex déposés dans la banque (%d)" % dans_banque)
	_verifier(String(g["journal"].back()["texte"]).contains("dépose"), "le dépôt est écrit dans le journal")
	var place := -1
	for i in (g["banque"] as Array).size():
		if String((g["banque"][i] as Dictionary).get("id", "")) == "silex":
			place = i
	# Chloé (recrue) ne peut pas sortir d'objets.
	guildes.coffre_partout = true
	social.historique.clear()
	guildes.expediteur_force = 9002
	guildes.retirer(place)
	guildes.expediteur_force = 0
	guildes.coffre_partout = false
	_verifier(not (g["banque"][place] as Dictionary).is_empty(), "une recrue ne sort rien de la banque")
	guildes.retirer(place)
	await _images(3)
	_verifier(Artisanat_compter(inv.etat, "silex") >= 12 and (g["banque"][place] as Dictionary).is_empty(), "le maître reprend les silex")

	# Contrats : on fait avancer un contrat d'ennemis jusqu'au bout.
	var contrats: Array = g["contrats"]["liste"]
	var vise: Dictionary = {}
	for c in contrats:
		if String(c["type"]) in ["ennemi", "fracture", "recolte", "quete"]:
			vise = c
			break
	if vise.is_empty():
		vise = contrats[0]
	var sceaux_avant := Artisanat_compter(inv.etat, "sceau_guilde")
	var fois := int(vise["nombre"]) - int(vise["compte"])
	for i in fois:
		guildes.contribuer(moi, String(vise["type"]))
	await _images(3)
	_verifier(vise["fini"], "contrat « %s » accompli (%d actions)" % [vise["titre"], fois])
	_verifier(Artisanat_compter(inv.etat, "sceau_guilde") >= sceaux_avant + R.sceaux_par_contrat(guildes.d, g) - 1,
			"on reçoit les Sceaux de guilde dans ses sacs (%d)" % Artisanat_compter(inv.etat, "sceau_guilde"))
	# Un ennemi vaincu (vraie fonction de la progression) compte aussi.
	var ennemis_avant := int(R.membre(g, nom_moi)["total"])
	moi.get_node("Progression").ennemi_vaincu("loup_fracture_foret", 3)
	_verifier(int(R.membre(g, nom_moi)["total"]) == ennemis_avant + 2, "un loup de fracture vaincu compte comme ennemi + fracture")

	# Échange chez l'intendante : le banquet demande une guilde niveau 2.
	_verifier(root.get_node("Donnees").artisanat["recettes"].has("guilde_banquet"), "l'intendante échange des sceaux")
	var intendante = null
	for p in get_nodes_in_group("pnj"):
		if String(p.get("identifiant")) == "intendante_guilde":
			intendante = p
	_verifier(intendante != null, "Mei Takahara, l'intendante, est dans la Maison des guildes")
	moi.teleporter(intendante.global_position + Vector3(0, 0, -1.5), 0.0)
	await _images(10)
	inv.recevoir([{"id": "sceau_guilde", "n": 40}])
	g["xp"] = 0
	var r_inv: String = inv._fabriquer("guilde_banquet")
	_verifier(r_inv.contains("niveau 2"), "guilde niveau 1 : le banquet est refusé (%s)" % r_inv)
	g["xp"] = 300
	r_inv = inv._fabriquer("guilde_banquet")
	_verifier(r_inv == "" and Artisanat_compter(inv.etat, "banquet_guilde") >= 2, "guilde niveau 2 : banquet échangé")

	# Exclusion : Bob (officier) exclut Chloé.
	guildes.expediteur_force = 9001
	guildes.exclure("Chloé")
	guildes.expediteur_force = 0
	_verifier(not R.est_membre(guildes.guilde_de("Bob"), "Chloé"), "un officier exclut une membre en dessous de lui")

	# Tableau de recrutement : Chloé (sans guilde) ne peut pas entrer tant que c'est fermé.
	guildes.expediteur_force = 9002
	guildes.rejoindre(g["nom"])
	guildes.expediteur_force = 0
	_verifier(not R.est_membre(g, "Chloé"), "recrutement fermé : on ne rejoint pas sans invitation")
	guildes.changer_recrutement(true, "Ensemble contre l'oubli [test]")
	guildes.changer_blason(2, 7)
	await _images(2)
	_verifier(R.recrutement(g)["ouvert"] and R.recrutement(g)["devise"] == "Ensemble contre l'oubli (test)", "le maître ouvre le recrutement avec une devise")
	_verifier(R.blason(g) == {"forme": 2, "symbole": 7}, "le maître choisit le blason")
	_verifier(guildes._vue(g, nom_moi)["recrutement"]["ouvert"] and guildes._vue(g, nom_moi)["blason"]["symbole"] == 7, "la vue envoyée au joueur montre recrutement et blason")
	var annuaire: Array = guildes._annuaire()
	_verifier(annuaire.any(func(f): return f["nom"] == g["nom"] and f["ouvert"] and int(f["membres"]) == R.nombre_membres(g)), "la guilde est au tableau de recrutement")
	guildes.expediteur_force = 9002
	guildes.rejoindre(g["nom"])
	guildes.expediteur_force = 0
	_verifier(R.est_membre(g, "Chloé") and R.rang_de(g, "Chloé") == "recrue", "Chloé rejoint en un clic (recrue)")
	guildes.expediteur_force = 9002
	guildes.changer_recrutement(false, "")
	guildes.expediteur_force = 0
	_verifier(R.recrutement(g)["ouvert"], "une recrue ne ferme pas le recrutement")

	# Sauvegarde puis relecture du fichier du serveur.
	guildes.sauvegarder()
	guildes._chemin_charge = ""
	var relu: Dictionary = guildes.guilde_de("Bob")
	_verifier(R.blason(relu) == {"forme": 2, "symbole": 7} and R.recrutement(relu)["ouvert"], "blason et recrutement relus du fichier")
	_verifier(not relu.is_empty() and R.est_membre(relu, nom_moi) and R.rang_de(relu, "Bob") == "officier",
			"le serveur relit les guildes depuis son fichier")
	_verifier(typeof(relu["xp"]) == TYPE_INT and typeof(relu["banque"][0].get("n", 0)) == TYPE_INT, "les nombres relus sont des entiers")

	# Une guilde qui vit sur un autre serveur : on ne la touche pas, on garde ce qu'on fait.
	guildes.quitter()
	await _images(2)
	var cfg := ConfigFile.new()
	cfg.load(Profil.chemin(guildes.fichier_client))
	cfg.set_value("guilde", "nom", "La Guilde En Ligne")
	cfg.set_value("guilde", "origine", "203.0.113.5:7777")
	cfg.save(Profil.chemin(guildes.fichier_client))
	guildes.annoncer()
	await _images(2)
	_verifier(not guildes.a_une_guilde() and guildes.ailleurs.get("nom", "") == "La Guilde En Ligne", "guilde d'un autre serveur : gardée telle quelle")
	guildes.contribuer(moi, "recolte", 3)
	_verifier(int(guildes.attente().get("recolte", 0)) == 3, "ce qu'on fait ici est gardé pour elle (3 récoltes en attente)")
	scene.queue_free()
	await _images(5)


static func Artisanat_compter(etat: Dictionary, id: String) -> int:
	var total := 0
	for c in etat.get("cases", []):
		if String((c as Dictionary).get("id", "")) == id:
			total += int(c.get("n", 1))
	return total
