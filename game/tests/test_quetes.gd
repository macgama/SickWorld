extends SceneTree
## Test automatique des missions secondaires de Hikari Bay : on accepte chaque
## mission en parlant à son donneur, on fait les étapes (parler, ramasser,
## installer) et on vérifie la récompense et la sauvegarde.
## Lancement : godot --headless --path game -s res://tests/test_quetes.gd

## Un fichier par lancement : deux tests lancés en même temps ne se gênent pas.
var FICHIER := "user://test_quetes_progression_%d.cfg" % OS.get_process_id()

var _echecs := 0
var _scene: Node
var _joueur
var _quetes
var _dialogue
var _appart

const Residences := preload("res://scripts/monde/quartier_residences.gd")


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
	# Au tout premier appui, la scène peut encore finir de se charger : on réessaie.
	for essai in 3:
		if _dialogue.est_ouvert():
			break
		await _attendre(10)
		await _appuyer_f()
	var lues := 0
	while _dialogue.est_ouvert() and lues < 30:
		lues += 1
		await _appuyer_f()
	return lues


## Se place devant un bouton d'ascenseur, appuie sur F et attend la fin du fondu.
func _prendre_ascenseur(bouton: Vector3) -> void:
	await _placer(bouton + Vector3(0, 0.3, -0.8), PI)
	await _appuyer_f()
	await _attendre(90)


## Ramasse ou utilise tous les objets de l'étape en cours.
func _utiliser_objets(id: String) -> int:
	var faits := 0
	for n in 10:
		var cle := "%s:%d" % [id, n]
		if not _quetes._objets.has(cle):
			continue
		var objet: Node3D = _quetes._objets[cle]
		var p := objet.global_position
		# Les objets posés en hauteur (terrasses) : on se place à leur niveau.
		var y := p.y + 0.3 if p.y < 1.5 else 0.3
		var avant: int = _quetes.etats[id].get("faits", []).size()
		var etape: int = _quetes.etats[id].get("etape", 0)
		# Un passant (PNJ qui se promène) peut se trouver tout près : F ouvre alors
		# son dialogue. On le ferme et on réessaie.
		for essai in 3:
			# L'objet disparaît une fois utilisé (l'effet peut arriver quelques images plus tard).
			if not is_instance_valid(objet):
				break
			await _placer(Vector3(p.x, y, p.z) + objet.global_transform.basis.z * 1.0, 0.0)
			await _appuyer_f()
			while _dialogue.est_ouvert():
				await _appuyer_f()
			if _quetes.etats[id].get("faits", []).size() > avant or _quetes.etats[id].get("etape", 0) != etape:
				break
			await _attendre(30)
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
	# Retour de la Côte Gelée avec la montre : la visite guidée du QG démarre seule.
	root.get_node("Reseau").set_meta("visite_guidee_qg", true)
	root.add_child(_scene)
	await _attendre(30)
	_joueur = get_first_node_in_group("joueur_local")
	_dialogue = get_first_node_in_group("dialogue")
	print("Test des missions secondaires")
	_verifier(_quetes.quetes.size() >= 3, "%d missions chargées" % _quetes.quetes.size())
	for id in ["kuro", "kaminari", "ecran", "ferraille", "louche", "fresques", "jardins", "lanternes", "billet", "courrier", "guilde", "projecteurs", "affiche"]:
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

	# 4. Ferraille temporelle : Tetsuo -> 3 morceaux -> Tetsuo.
	await _parler_a("forgeron")
	_verifier(_quetes.etat("ferraille") == "active", "Maître Tetsuo confie sa mission")
	faits = await _utiliser_objets("ferraille")
	_verifier(faits == 3 and _quetes.etats["ferraille"]["etape"] == 1, "on ramasse les trois morceaux de ferraille")
	await _parler_a("forgeron")
	_verifier(_quetes.etat("ferraille") == "terminee", "mission « Ferraille temporelle » accomplie")

	# 5. Une louche sur mesure : Kofi -> Goro (au Marché) -> Kofi.
	await _parler_a("kofi")
	_verifier(_quetes.etat("louche") == "active", "Kofi confie sa mission")
	await _parler_a("chef_goro")
	_verifier(_quetes.etats["louche"]["etape"] == 1, "le chef Goro reçoit la louche")
	await _parler_a("kofi")
	_verifier(_quetes.etat("louche") == "terminee", "mission « Une louche sur mesure » accomplie")

	# 6. Les fresques effacées : Dr Diallo -> 3 photos -> Dr Diallo.
	await _parler_a("conservatrice")
	_verifier(_quetes.etat("fresques") == "active", "la Dr Diallo confie sa mission")
	faits = await _utiliser_objets("fresques")
	_verifier(faits == 3 and _quetes.etats["fresques"]["etape"] == 1, "on retrouve les trois photos des fresques (%d, %s)" % [faits, _quetes.etats["fresques"]])
	await _parler_a("conservatrice")
	_verifier(_quetes.etat("fresques") == "terminee", "mission « Les fresques effacées » accomplie")

	# 7. L'eau des jardins : M. Tan -> 3 vannes -> M. Tan.
	await _parler_a("jardinier")
	_verifier(_quetes.etat("jardins") == "active", "M. Tan Wei confie sa mission")
	faits = await _utiliser_objets("jardins")
	_verifier(faits == 3 and _quetes.etats["jardins"]["etape"] == 1, "on rouvre les trois vannes")
	await _parler_a("jardinier")
	_verifier(_quetes.etat("jardins") == "terminee", "mission « L'eau des jardins » accomplie")

	# 8. Les lanternes de la baie : Ume -> 3 lanternes -> Ume.
	await _parler_a("grand_mere_ume")
	_verifier(_quetes.etat("lanternes") == "active", "Grand-mère Ume confie sa mission")
	faits = await _utiliser_objets("lanternes")
	_verifier(faits == 3 and _quetes.etats["lanternes"]["etape"] == 1, "on allume les trois lanternes (%s)" % _quetes.etats["lanternes"])
	await _parler_a("grand_mere_ume")
	_verifier(_quetes.etat("lanternes") == "terminee", "mission « Les lanternes de la baie » accomplie")

	# 9. Billet pour nulle part : Rina -> capitaine -> Tomás -> Rina.
	await _parler_a("guichetiere")
	_verifier(_quetes.etat("billet") == "active", "Rina confie sa mission")
	await _parler_a("capitaine")
	_verifier(_quetes.etats["billet"]["etape"] == 1, "le capitaine envoie voir Tomás")
	await _parler_a("gardien_roue")
	_verifier(_quetes.etats["billet"]["etape"] == 2, "Tomás donne ses billets")
	await _parler_a("guichetiere")
	_verifier(_quetes.etat("billet") == "terminee", "mission « Billet pour nulle part » accomplie")

	# Sans la clé, l'ascenseur de la Résidence Sakura refuse de monter.
	_appart = get_first_node_in_group("appartement")
	_verifier(_appart != null, "l'appartement 1204 existe")
	await _prendre_ascenseur(Residences.ASCENSEUR_HALL)
	_verifier(_dialogue.est_ouvert() and _joueur.global_position.y < 5.0, "sans clé, l'ascenseur reste au rez-de-chaussée")
	while _dialogue.est_ouvert():
		await _appuyer_f()

	# 10. Courrier égaré : Mme Fujimoto -> 3 lettres -> Mme Fujimoto.
	await _parler_a("concierge")
	_verifier(_quetes.etat("courrier") == "active", "Madame Fujimoto confie sa mission")
	faits = await _utiliser_objets("courrier")
	_verifier(faits == 3 and _quetes.etats["courrier"]["etape"] == 1, "on ramasse les trois lettres (%s)" % _quetes.etats["courrier"])
	await _parler_a("concierge")
	_verifier(_quetes.etat("courrier") == "terminee", "mission « Courrier égaré » accomplie")
	# Avec la clé : l'ascenseur monte au 12e, les souvenirs sont sur l'étagère.
	await _prendre_ascenseur(Residences.ASCENSEUR_HALL)
	_verifier(absf(_joueur.global_position.y - Residences.SOL_APPART) < 1.0, "l'ascenseur monte à l'appartement 1204 (y = %.1f)" % _joueur.global_position.y)
	var souvenirs: int = _appart.get_node("Souvenirs").get_child_count()
	_verifier(souvenirs == 10, "10 souvenirs de mission sur l'étagère (%d)" % souvenirs)
	await _attendre(60)
	_verifier(absf(_joueur.global_position.y - Residences.SOL_APPART) < 1.0, "on tient debout dans l'appartement (y = %.1f)" % _joueur.global_position.y)
	await _prendre_ascenseur(Residences.ASCENSEUR_APPART)
	_verifier(_joueur.global_position.y < 1.0, "l'ascenseur redescend au hall")

	# 11. Trois signatures : registraire -> concierge -> Kaito -> registraire.
	await _parler_a("registraire")
	_verifier(_quetes.etat("guilde") == "active", "le registraire confie sa mission")
	await _parler_a("concierge")
	_verifier(_quetes.etats["guilde"]["etape"] == 1, "Madame Fujimoto signe")
	await _parler_a("caissier_konbini")
	_verifier(_quetes.etats["guilde"]["etape"] == 2, "Kaito signe")
	await _parler_a("registraire")
	_verifier(_quetes.etat("guilde") == "terminee", "mission « Trois signatures » accomplie")
	# Le registraire propose aussitôt de fonder sa guilde.
	await _attendre(5)
	_verifier(_appart.fondation_ouverte(), "la fenêtre « Fonder une guilde » s'ouvre")
	_appart._champ_nom.text = "Ab"
	_appart._valider()
	_verifier(_appart.fondation_ouverte() and _appart._erreur.text != "", "un nom trop court est refusé : %s" % _appart._erreur.text)
	_appart._champ_nom.text = "Les Gardiens de Kairo"
	_appart._choisir_couleur(2)
	_appart._valider()
	_verifier(not _appart.fondation_ouverte() and _appart.guilde().get("nom", "") == "Les Gardiens de Kairo", "la guilde est fondée et sauvegardée (%s)" % _appart.guilde())
	_verifier(_appart.get_node_or_null("BanniereGuildeMaison") != null and _appart.get_node_or_null("BanniereGuildeAppart") != null, "sa bannière est accrochée à la Maison des guildes et dans l'appartement")
	await _parler_a("registraire")
	_verifier(not _appart.fondation_ouverte(), "une seule guilde : le registraire ne repropose plus la fondation")

	# 13. Lumière sur l'Arène : Kenta -> 3 fusibles -> Kenta.
	await _parler_a("ouvrier_arene")
	_verifier(_quetes.etat("projecteurs") == "active", "Kenta confie sa mission")
	faits = await _utiliser_objets("projecteurs")
	_verifier(faits == 3 and _quetes.etats["projecteurs"]["etape"] == 1, "on remet les trois fusibles (%s)" % _quetes.etats["projecteurs"])
	await _parler_a("ouvrier_arene")
	_verifier(_quetes.etat("projecteurs") == "terminee", "mission « Lumière sur l'Arène » accomplie")

	# 14. Tête d'affiche : DJ Volt -> Marco -> Akane -> DJ Volt.
	await _parler_a("commentateur")
	_verifier(_quetes.etat("affiche") == "active", "DJ Volt confie sa mission")
	await _parler_a("chef_chantier")
	await _parler_a("championne")
	await _parler_a("commentateur")
	_verifier(_quetes.etat("affiche") == "terminee", "mission « Tête d'affiche » accomplie")

	# 12. L'objet impossible (visite guidée du QG) : Morel -> Yuki -> Théo -> Ishida -> Morel.
	_verifier(_quetes.etat("montre") == "active", "au retour de la Côte Gelée, la visite guidée du QG commence")
	for pnj in ["commandante", "technicienne", "banquier", "lame"]:
		await _parler_a(pnj)
	_verifier(_quetes.etats["montre"]["etape"] == 4, "la visite passe par les portails, le Coffre et l'entraînement (%s)" % _quetes.etats["montre"])
	await _parler_a("commandante")
	_verifier(_quetes.etat("montre") == "terminee", "mission « L'objet impossible » accomplie")
	souvenirs = _appart.get_node("Souvenirs").get_child_count()
	_verifier(souvenirs == _quetes.quetes.size(), "toutes les missions ont leur souvenir (%d)" % souvenirs)

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
