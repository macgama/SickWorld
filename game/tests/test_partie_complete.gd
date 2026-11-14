extends SceneTree
## Test « partie complète » : joue toute la boucle comme un vrai joueur, avec les
## vrais changements de scène et les vraies sauvegardes (dans un profil de test) :
##   menu titre → création du personnage → menu → Jouer → intro dans Hikari Bay →
##   portail du QG → Préhistoire, les 8 chapitres dans l'ordre (Côte Gelée, Steppe,
##   Forêt, Falaises, Grande Grotte), visite guidée du QG au milieu → retour au hub.
## Puis vérifie que tout est resté enregistré (inventaire, récompenses, chapitres).
## Lancement : godot --headless --path game -s res://tests/test_partie_complete.gd
## (environ 6 minutes : les îles sont construites en code au chargement).
## Autre classe : ... -s res://tests/test_partie_complete.gd -- --classe=tisseur

const NOM := "Testeur Boucle"
## Classe jouée (changer avec : -- --classe=rempart).
var CLASSE := "traqueur"
const MAX_ACTIONS := 400

var _echecs := 0
var _profil_test := "_test_partie_%d" % OS.get_process_id()
var _scene: Node
var _joueur
var _dialogue
var _zones_vues: Array[String] = []
var _secours: Array[String] = [] # passages qu'il a fallu forcer (bug probable)


func _verifier(condition: bool, message: String) -> void:
	print("  OK   " if condition else "  ÉCHEC ", message)
	if not condition:
		_echecs += 1


func _attendre(images: int) -> void:
	for i in images:
		await physics_frame


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--classe="):
			CLASSE = arg.trim_prefix("--classe=")
	_lancer.call_deferred()


func _effacer_profil_test() -> void:
	for relatif in Profil.lister(_profil_test):
		DirAccess.remove_absolute(Profil.dossier(_profil_test) + relatif)
	for d in ["sauvegardes/inventaires", "sauvegardes", "cartes", ""]:
		DirAccess.remove_absolute(Profil.dossier(_profil_test) + d)


# --- Outils --------------------------------------------------------------------

## Attend qu'une nouvelle scène remplace la scène actuelle (vrai changement de scène).
func _attendre_scene(chemin, max_images := 1500) -> bool:
	var chemins: Array = chemin if chemin is Array else [chemin]
	for i in max_images:
		await physics_frame
		var s := current_scene
		if s != null and s != _scene and s.scene_file_path in chemins and s.is_inside_tree():
			_scene = s
			await _attendre(45)
			_joueur = get_first_node_in_group("joueur_local")
			_dialogue = get_first_node_in_group("dialogue")
			return true
	return false


func _bouton(racine: Node, texte: String) -> Button:
	for n in racine.find_children("*", "Button", true, false):
		if (n as Button).text == texte and (n as Button).is_visible_in_tree():
			return n
	return null


func _appuyer_f() -> void:
	var appui := InputEventAction.new()
	appui.action = "interagir"
	appui.pressed = true
	Input.parse_input_event(appui)
	await _attendre(3)
	var relache := InputEventAction.new()
	relache.action = "interagir"
	relache.pressed = false
	Input.parse_input_event(relache)
	await _attendre(2)


func _lire_dialogue() -> int:
	var lues := 0
	while _dialogue != null and _dialogue.est_ouvert() and lues < 40:
		lues += 1
		await _appuyer_f()
	return lues


func _soigner() -> void:
	if _joueur == null:
		return
	var c = _joueur.get_node_or_null("Combat")
	if c != null and c.est_vivant():
		c.pv = c.pv_max


func _hauteur(x: float, z: float) -> float:
	var ile := get_first_node_in_group("ile")
	return ile.hauteur(x, z) if ile != null else 0.0


func _placer(p: Vector3, angle := 0.0) -> void:
	_joueur.teleporter(p, angle)
	_joueur.camera.lacet = angle
	await _attendre(10)


func _placer_sol(x: float, z: float) -> void:
	await _placer(Vector3(x, _hauteur(x, z) + 0.4, z))


## Se place à côté d'un personnage ou d'un objet et appuie sur F.
func _utiliser(cible: Node3D, ecart := 1.4) -> void:
	var p := cible.global_position
	var depuis := Vector3(p.x, 0, p.z + ecart)
	await _placer(Vector3(depuis.x, (_hauteur(depuis.x, depuis.z) if get_first_node_in_group("ile") != null else p.y) + 0.4, depuis.z), 0.0)
	await _appuyer_f()


# --- 1. Menu titre et création -------------------------------------------------

func _menu_et_creation() -> void:
	print("1. Menu titre et création du personnage")
	change_scene_to_file("res://scenes/interface/menu.tscn")
	_verifier(await _attendre_scene("res://scenes/interface/menu.tscn"), "le menu titre s'ouvre")
	var creer := _bouton(_scene, "Créer mon personnage")
	_verifier(creer != null and _bouton(_scene, "Jouer") == null, "nouveau joueur : seul « Créer mon personnage » est proposé")
	if creer == null:
		return
	creer.pressed.emit()
	_verifier(await _attendre_scene("res://scenes/interface/creation_personnage.tscn"), "l'écran de création s'ouvre")
	var creation := _scene
	for etape in 4:
		creation.aller_etape(etape)
		await _attendre(5)
		if etape == 2:
			creation._changer("classe", CLASSE)
			creation._remplir()
	await _attendre(5)
	if creation._champ_nom != null:
		creation._champ_nom.text = NOM
	else:
		creation.fiche["nom"] = NOM
	var erreur: String = creation.terminer()
	_verifier(erreur == "", "le personnage est enregistré (%s)" % erreur)
	_verifier(await _attendre_scene("res://scenes/interface/menu.tscn"), "retour au menu")
	_verifier(Profil.a_un_personnage(_profil_test), "la fiche est dans le profil")
	var jouer := _bouton(_scene, "Jouer")
	_verifier(jouer != null, "le menu propose maintenant « Jouer »")
	if jouer != null:
		jouer.pressed.emit()
	_verifier(await _attendre_scene("res://scenes/monde/hikari_bay.tscn"), "Jouer ouvre Hikari Bay")
	_verifier(_joueur != null and String(_joueur.get("nom_affiche") if _joueur.get("nom_affiche") != null else NOM) != "", "le joueur est dans la ville")
	_verifier(root.get_node("Reseau").fiche.get("classe", "") == CLASSE, "la classe choisie est gardée (%s)" % root.get_node("Reseau").fiche.get("classe", ""))


# --- 2. Intro dans Hikari Bay ----------------------------------------------------

func _parler_hub(id: String) -> int:
	var pnj = _scene.find_child("Pnj_" + id, true, false)
	if pnj == null:
		print("    (personnage introuvable : %s)" % id)
		return 0
	await _placer(pnj.global_position + Vector3(0, 0.3, 2.0), 0.0)
	await _appuyer_f()
	return await _lire_dialogue()


func _franchir_portail_hub() -> void:
	var portail = _scene.qg["portails"][0]
	await _placer(portail.global_position + Vector3(0, -3.0, -4.0), PI)
	Input.action_press("avancer")
	await _attendre(60)
	Input.action_release("avancer")


func _intro() -> void:
	print("2. Intro dans Hikari Bay")
	var intro = _scene.get_node("Intro")
	_verifier(intro.etape_actuelle().get("id", "") == "recrutement", "l'intro commence (%s)" % intro.etape_actuelle().get("id", ""))
	await _attendre(60 * 6) # l'écran noir d'ouverture
	_verifier(await _parler_hub("recruteur") >= 5, "Kenji Duval recrute le joueur")
	await _placer(Vector3(-23, -3.7, 30), PI)
	await _attendre(5)
	_verifier(intro.etape_actuelle().get("id", "") == "commandante", "descente à la station Asahi")
	_verifier(await _parler_hub("commandante") >= 6, "la commandante donne la mission")
	_verifier(await _parler_hub("technicienne") >= 3, "Yuki prépare le portail")
	_verifier(intro.etape_actuelle().get("id", "") == "portail", "il reste le portail")
	await _franchir_portail_hub()
	_verifier(await _attendre_scene("res://scenes/monde/prehistoire/cote_gelee.tscn"), "le portail mène à la Côte Gelée")


# --- 3. Préhistoire --------------------------------------------------------------

func _quete():
	return get_first_node_in_group("quete")


func _id(q) -> String:
	return String(q.etape_actuelle().get("id", "fin"))


## Change de zone en marchant vers la sortie ; si rien ne se passe, force (et le note).
func _aller_vers_zone(q, destination: String) -> void:
	var ile := get_first_node_in_group("ile")
	var sortie: Vector2 = ile.sortie_vers(destination)
	var avant := _scene
	var depart: String = q._zone()
	# On peut passer par une zone intermédiaire (Forêt → Steppe → Côte Gelée).
	var chemins: Array = []
	for z in q.donnees["zones"].values():
		chemins.append(z["scene"])
	if sortie == Vector2.INF:
		_secours.append("pas de sortie de %s vers %s" % [q._zone(), destination])
		q.changer_de_zone(destination)
	else:
		# On franchit la sortie : un peu plus loin, dans la direction qui s'éloigne du centre.
		var dehors := sortie + sortie.normalized() * 14.0
		await _placer_sol(sortie.x, sortie.y)
		await _placer_sol(dehors.x, dehors.y)
		await _attendre(40)
		if current_scene == avant and is_instance_valid(q) and not q._en_voyage:
			_secours.append("sortie %s → %s (%s) sans effet" % [q._zone(), destination, sortie])
			q.changer_de_zone(destination)
	var ok := await _attendre_scene(chemins)
	var arrivee: String = String(get_first_node_in_group("ile").get("identifiant_zone")) if ok else "?"
	_verifier(ok, "passage %s → %s (vers %s)" % [depart, arrivee, destination])
	if ok and not arrivee in _zones_vues:
		_zones_vues.append(arrivee)
	if ok:
		_verifier(_joueur.global_position.y > _hauteur(_joueur.global_position.x, _joueur.global_position.z) - 1.0,
				"à l'arrivée (%s), le joueur est au-dessus du sol" % arrivee)


func _ennemis(type: String) -> Array:
	var liste := []
	for bete in get_nodes_in_group("loups"):
		if String(bete.type_ennemi).begins_with(type) and bete.combat.est_vivant():
			liste.append(bete)
	return liste


## Comme un joueur : on se débarrasse d'abord des ennemis qui nous attaquent
## (une action longue est interrompue par les coups).
func _nettoyer_autour(rayon := 30.0) -> void:
	var combat = _joueur.get_node("Combat")
	for bete in get_nodes_in_group("loups"):
		if bete.combat.est_vivant() and bete.global_position.distance_to(_joueur.global_position) < rayon \
				and String(bete.type_ennemi) != "renne":
			bete.combat.subir(99999.0, combat)
	await _attendre(5)


func _faire_etape(q) -> void:
	var e: Dictionary = q.etape_actuelle()
	var combat = _joueur.get_node("Combat")
	if e.has("objet") or e.has("choix") or e.has("recolter"):
		var cible = q._position_cible(e)
		if cible != null:
			await _placer_sol(cible.x, cible.z + 1.4)
		await _nettoyer_autour()
	# Pas dans la bonne zone : on y va.
	if e.has("arriver"):
		await _aller_vers_zone(q, String(e["arriver"]))
		return
	if not q._ici(e):
		await _aller_vers_zone(q, String(e["ou"]))
		return
	if e.get("portail", false):
		var portail: Vector2 = get_first_node_in_group("ile").PORTAIL
		await _placer_sol(portail.x, portail.y + 14.0) # s'éloigner arme le portail
		await _placer_sol(portail.x, portail.y)
		for i in 30:
			await _attendre(1)
			if q._en_voyage:
				break
		if not q._en_voyage:
			_secours.append("portail de la Côte Gelée sans effet")
			q.rentrer_au_hub()
		_verifier(await _attendre_scene("res://scenes/monde/hikari_bay.tscn"), "le portail de la Côte Gelée ramène au QG")
		await _visite_guidee()
		return
	if e.has("escorte"):
		for i in 60 * 120:
			if _id(q) != String(e["id"]):
				break
			if i % 20 == 0:
				var tete = q._trouver_pnj(e["escorte"][0])
				var p: Vector3 = tete.global_position
				await _placer_sol(p.x + 3.0, p.z + 3.0)
				for bete in get_nodes_in_group("loups"):
					if bete.has_meta("unique") and bete.combat.est_vivant():
						bete.combat.subir(99999.0, combat)
				_soigner()
			await _attendre(1)
		return
	if e.has("choix"):
		var objet = q._trouver_objet(e["choix"][0]["objet"])
		await _utiliser(objet)
		await _attendre(int(float(e["choix"][0].get("duree", e.get("duree", 0))) * 60) + 30)
		await _lire_dialogue()
		return
	if e.has("objet"):
		var objet = q._trouver_objet(e["objet"])
		if objet == null:
			_verifier(false, "[%s] l'objet « %s » existe" % [e["id"], e["objet"]])
			return
		await _utiliser(objet)
		await _attendre(int(float(e.get("duree", 0)) * 60) + 30)
		await _lire_dialogue()
		return
	if e.has("recolter"):
		var pos = q._position_cible(e)
		if pos == null:
			_verifier(false, "[%s] il reste quelque chose à récolter" % e["id"])
			return
		for objet in get_nodes_in_group("objet_quete"):
			if objet.get("groupe") == e["recolter"] and objet.actif and objet.global_position.distance_to(pos) < 0.1:
				await _utiliser(objet)
				await _attendre(int(float(e.get("duree", 0)) * 60) + 30)
		return
	if e.has("tuer"):
		if e.has("lieu"):
			await _placer_sol(float(e["lieu"][0]) + 6.0, float(e["lieu"][1]) + 6.0)
		var cibles := _ennemis(String(e["tuer"]))
		if cibles.is_empty():
			await _attendre(60)
			cibles = _ennemis(String(e["tuer"]))
		if cibles.is_empty():
			# Déjà vaincus avant l'étape (ex. pendant les soins) : ils réapparaissent.
			await _attendre(120)
			return
		# Le plus proche d'abord, et par petits coups pour un boss (phases).
		var bete = cibles[0]
		if bete.combat.pv_max > 2000.0:
			bete.combat.subir(bete.combat.pv_max * 0.2, combat)
		else:
			bete.combat.subir(99999.0, combat)
		await _attendre(8)
		return
	if e.has("pnj"):
		var pnj = q._trouver_pnj(e["pnj"])
		if pnj == null:
			_verifier(false, "[%s] %s est là" % [e["id"], e["pnj"]])
			return
		await _utiliser(pnj, 1.3)
		await _lire_dialogue()
		return
	if e.has("zone"):
		await _placer_sol(float(e["zone"][0]), float(e["zone"][1]))
		await _attendre(10)
		return
	_verifier(false, "étape inconnue pour le test : %s" % e)


func _visite_guidee() -> void:
	print("   Visite guidée du QG (au milieu de la Préhistoire)")
	var quetes = _scene.get_node("Quetes")
	await _attendre(30)
	_verifier(quetes.etat("montre") == "active", "la visite guidée du QG commence (%s)" % quetes.etat("montre"))
	var tours := 0
	while quetes.etat("montre") == "active" and tours < 10:
		tours += 1
		var e: Dictionary = quetes.etape_de("montre")
		await _parler_hub(String(e.get("parler", "")))
	_verifier(quetes.etat("montre") == "terminee", "visite guidée terminée")
	await _franchir_portail_hub()
	_verifier(await _attendre_scene("res://scenes/monde/prehistoire/cote_gelee.tscn"), "le portail ramène à la Côte Gelée")


func _prehistoire() -> void:
	print("3. Préhistoire")
	_zones_vues.append("cote_gelee")
	var q = _quete()
	var actions := 0
	var derniere := ""
	var meme := 0
	while actions < MAX_ACTIONS:
		q = _quete()
		if q == null or q.etape < 0:
			break
		actions += 1
		_soigner()
		var id: String = _id(q)
		if id != derniere:
			print("   étape : %s (chapitre %d, %s)" % [id, q.etape_actuelle().get("chapitre", 0), q._zone()])
			derniere = id
			meme = 0
		else:
			meme += 1
			if meme > 40:
				_verifier(false, "bloqué à l'étape « %s »" % id)
				return
		await _faire_etape(q)
	q = _quete()
	_verifier(q != null and q.etape == -1, "la Préhistoire est finie (8 chapitres, %d actions)" % actions)
	_verifier(_zones_vues.size() >= 5, "les 5 zones ont été visitées (%s)" % [_zones_vues])


# --- 4. Retour au hub et sauvegarde ------------------------------------------------

func _retour_hub() -> void:
	print("4. Retour au hub")
	var q = _quete()
	await _attendre(60 * 6)
	while q._zone() != "cote_gelee":
		var avant := _scene
		await _aller_vers_zone(q, "cote_gelee")
		if _scene == avant:
			return
		q = _quete()
	var portail: Vector2 = get_first_node_in_group("ile").PORTAIL
	await _placer_sol(portail.x, portail.y + 14.0)
	await _placer_sol(portail.x, portail.y)
	await _attendre(30)
	if not q._en_voyage:
		_secours.append("portail de la Côte Gelée sans effet (fin)")
		q.rentrer_au_hub()
	_verifier(await _attendre_scene("res://scenes/monde/hikari_bay.tscn"), "retour à Hikari Bay par le portail")
	await _attendre(120)
	var p: Vector3 = _joueur.global_position
	_verifier(p.y > -20.0 and _joueur.is_on_floor(), "le joueur est debout au QG (%.1f, %.1f, %.1f)" % [p.x, p.y, p.z])
	_verifier(_scene.get_node("Intro").intro_terminee(), "l'intro ne se rejoue pas")
	var inv = _joueur.get_node("Inventaire")
	for objet in ["lance_silex", "ocre_sacree"]:
		_verifier(Objets.trouver(inv.etat, objet) >= 0 or _porte(inv, objet), "récompense gardée : %s" % objet)
	var cfg := ConfigFile.new()
	cfg.load(Profil.chemin("user://progression.cfg"))
	_verifier(String(cfg.get_value("prehistoire", "etape", "")) == "fin", "la progression enregistrée dit « Préhistoire finie »")
	_verifier(_scene.get_node("Quetes").etat("montre") == "terminee", "la visite guidée reste terminée")

	# On quitte et on relance le jeu : tout est encore là.
	change_scene_to_file("res://scenes/interface/menu.tscn")
	await _attendre_scene("res://scenes/interface/menu.tscn")
	var jouer := _bouton(_scene, "Jouer")
	_verifier(jouer != null, "relance : le personnage est toujours là")
	if jouer != null:
		jouer.pressed.emit()
		_verifier(await _attendre_scene("res://scenes/monde/hikari_bay.tscn"), "relance : Jouer ouvre Hikari Bay")
		await _attendre(60)
		inv = _joueur.get_node("Inventaire")
		_verifier(Objets.trouver(inv.etat, "lance_silex") >= 0 or _porte(inv, "lance_silex"), "relance : l'inventaire est gardé")
		_verifier(_scene.get_node("Intro").intro_terminee(), "relance : pas d'intro")


func _porte(inv, objet: String) -> bool:
	var equipement = inv.etat.get("equipement", {})
	if equipement is Dictionary:
		for v in equipement.values():
			if v is Dictionary and String(v.get("id", "")) == objet:
				return true
			if v is String and v == objet:
				return true
	return false


func _lancer() -> void:
	print("Test : une partie complète, du menu au retour de la Préhistoire (classe : %s)" % CLASSE)
	Profil.activer(_profil_test)
	var debut := Time.get_ticks_msec()
	await _menu_et_creation()
	if _scene != null and _scene.scene_file_path.ends_with("hikari_bay.tscn"):
		await _intro()
	if _quete() != null:
		await _prehistoire()
		await _retour_hub()
	if not _secours.is_empty():
		print("Passages forcés (à vérifier) :")
		for s in _secours:
			print("   - ", s)
	print("Durée : %d s" % ((Time.get_ticks_msec() - debut) / 1000))
	_effacer_profil_test()
	print("Résultat : %s" % ("TOUT EST BON" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
