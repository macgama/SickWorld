extends Node
## Quête principale de l'île : « Ce que les murs se rappellent ».
##
## Les chapitres et leurs étapes viennent de data/prehistoire_quete.json.
## Chaque étape demande une chose au joueur :
## - « pnj » : parler à un personnage (avec les répliques de l'étape) ;
## - « zone » : aller à un endroit ;
## - « objet » : utiliser un objet ou un endroit (F), parfois pendant quelques secondes ;
## - « tuer » : vaincre un nombre d'ennemis d'un type donné.
## Après une étape, « apres » change le monde (Lenoir se relève, la faille se ferme…).
## L'avancement est gardé dans user://progression.cfg (section « prehistoire »).

const Pnj := preload("res://scripts/monde/prehistoire/pnj_epoque.gd")
const SCENE_LOUP := preload("res://scenes/ennemis/loup.tscn")

signal etape_changee(id: String)

const DONNEES := "res://data/prehistoire_quete.json"
const OR := Color(1.0, 0.82, 0.35)
const SECTION := "prehistoire"

## Coche pour recommencer la quête depuis le début à chaque lancement.
@export var toujours_recommencer := false
## Décoche pour rester sur l'île au lieu de charger le hub (utilisé par les tests).
@export var voyage_reel := true
@export var fichier_progression := "user://progression.cfg"

var donnees := {}
## Toutes les étapes de tous les chapitres, à la suite.
var etapes: Array = []
## Numéro de l'étape en cours (-1 : quête terminée pour l'instant).
var etape := -1
## Ennemis vaincus pour l'étape « tuer » en cours.
var compteur := 0

var _ecran: CanvasLayer
var _objectif: PanelContainer
var _chapitre: Label
var _texte_objectif: Label
var _distance: Label
var _barre: ProgressBar
var _texte_barre: Label
var _cadre_barre: PanelContainer
var _voile: ColorRect
var _titre: Label
var _sous_titre: Label
var _recit: Label
var _repere: Node3D
var _cone: MeshInstance3D
var _faisceau: MeshInstance3D
var _temps := 0.0
var _en_voyage := false
var _fin_annonces := 0.0
# Action en cours (F maintenu quelques secondes).
var _canalisation: Node3D = null
var _canalisation_duree := 0.0
var _canalisation_temps := 0.0
var _canalisation_depart := Vector3.ZERO
var _combat_joueur: Node = null
## Dernière zone demandée (pour les tests, quand voyage_reel est décoché).
var zone_demandee := ""
## L'étape « choix » telle qu'elle était avant de choisir (on peut se raviser si
## l'action est interrompue).
var _avant_choix := {}
var _renforts_venus: Array[String] = []


func _ready() -> void:
	add_to_group("quete")
	var lu = JSON.parse_string(FileAccess.get_file_as_string(DONNEES))
	if lu is Dictionary:
		donnees = lu
	else:
		push_error("Impossible de lire %s : vérifie les virgules et les guillemets." % DONNEES)
	for c in donnees.get("chapitres", []):
		for e in c.get("etapes", []):
			var copie: Dictionary = e.duplicate()
			copie["chapitre"] = c.get("numero", 0)
			copie["titre_chapitre"] = c.get("titre", "")
			if not copie.has("ou"):
				copie["ou"] = c.get("ou", "")
			etapes.append(copie)
	_reprendre_choix()
	_construire_ecran()
	_construire_repere()
	var dialogue := get_tree().get_first_node_in_group("dialogue")
	if dialogue != null:
		dialogue.termine.connect(_sur_dialogue_termine)
	var loups := get_tree().get_first_node_in_group("dossier_loups")
	if loups != null:
		loups.child_entered_tree.connect(_sur_nouvel_ennemi)
	_demarrer.call_deferred()


func _demarrer() -> void:
	if multiplayer.is_server():
		for camp in donnees.get("camps", {}).get(_zone(), []):
			_faire_apparaitre(camp, false)
	var depart := 0
	if not toujours_recommencer:
		depart = _etape_sauvegardee()
	# Le monde reprend l'état des étapes déjà faites (Lenoir debout, faille fermée…).
	for i in (depart if depart >= 0 else etapes.size()):
		_appliquer_apres(etapes[i], false)
	_arrivee()
	_aller_a(depart)
	# Une étape « arriver » se termine en entrant dans la zone demandée.
	if etape_actuelle().get("arriver", "") == _zone():
		_suivante()


## Nom de la zone où se trouve le joueur (« cote_gelee », « steppe »…).
func _zone() -> String:
	var ile := get_tree().get_first_node_in_group("ile")
	return String(ile.get("identifiant_zone")) if ile != null else ""


## Vrai si l'étape se passe dans la zone actuelle.
func _ici(e: Dictionary) -> bool:
	return String(e.get("ou", "")) in ["", _zone()]


# --- Progression ------------------------------------------------------------

## Une étape « choix » propose plusieurs objets ; celui qu'on utilise décide de la
## suite (ex. soigner Grise ou la laisser partir). Le choix est gardé dans la sauvegarde.
func _reprendre_choix() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(fichier_progression) != OK:
		return
	for i in etapes.size():
		var e: Dictionary = etapes[i]
		if not e.has("choix"):
			continue
		var pris := String(cfg.get_value(SECTION, "choix_" + String(e.get("id", "")), ""))
		for option in e["choix"]:
			if option.get("objet", "") == pris:
				etapes[i] = _etape_choisie(e, option)


func _etape_choisie(e: Dictionary, option: Dictionary) -> Dictionary:
	var choisie := e.duplicate()
	choisie.erase("choix")
	choisie.merge(option, true)
	choisie["choix_fait"] = option.get("objet", "")
	return choisie


## Choix : le joueur a utilisé l'objet d'une des options.
func _choisir(option: Dictionary) -> void:
	var e := etape_actuelle()
	_avant_choix = e
	etapes[etape] = _etape_choisie(e, option)
	var cfg := ConfigFile.new()
	cfg.load(fichier_progression)
	cfg.set_value(SECTION, "choix_" + String(e.get("id", "")), option.get("objet", ""))
	cfg.save(fichier_progression)
	for objet in get_tree().get_nodes_in_group("objet_quete"):
		if objet.get("identifiant") != option.get("objet", ""):
			objet.actif = false
	var choisie := etape_actuelle()
	if choisie.has("pnj") and choisie.has("repliques"):
		var pnj := _trouver_pnj(choisie["pnj"])
		if pnj != null:
			pnj.repliques_speciales = PackedStringArray(choisie["repliques"])
	# Les renforts n'arrivent qu'une fois, même si on recommence l'action.
	var cle := "%s_%s" % [choisie.get("id", ""), option.get("objet", "")]
	if choisie.has("apparition") and multiplayer.is_server() and _ici(choisie) and not cle in _renforts_venus:
		_renforts_venus.append(cle)
		_faire_apparaitre(choisie["apparition"], true)
	_mettre_a_jour_objectif()

func _etape_sauvegardee() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(fichier_progression) != OK:
		return 0
	var id := String(cfg.get_value(SECTION, "etape", ""))
	if id == "fin":
		return -1
	for i in etapes.size():
		if etapes[i].get("id", "") == id:
			return i
	return 0


func _sauvegarder() -> void:
	var cfg := ConfigFile.new()
	cfg.load(fichier_progression)
	cfg.set_value(SECTION, "etape", etape_actuelle().get("id", "fin"))
	cfg.save(fichier_progression)


func etape_actuelle() -> Dictionary:
	return etapes[etape] if etape >= 0 and etape < etapes.size() else {}


func _aller_a(numero: int) -> void:
	var avant := etape_actuelle()
	if avant.has("pnj"):
		var pnj := _trouver_pnj(avant["pnj"])
		if pnj != null:
			pnj.repliques_speciales = PackedStringArray()
	for objet in get_tree().get_nodes_in_group("objet_quete"):
		objet.actif = false
	etape = numero if numero >= 0 and numero < etapes.size() else -1
	compteur = 0
	_avant_choix = {}
	var e := etape_actuelle()
	_sauvegarder()
	if etape >= 0:
		if e.get("chapitre", 0) != avant.get("chapitre", -1) and not avant.is_empty():
			# Après « Chapitre N terminé », on laisse le temps de lire avant d'annoncer le suivant.
			_annoncer("Chapitre %d" % e["chapitre"], e.get("titre_chapitre", ""))
		for effet in e.get("action_pnj", []):
			_appliquer_effet(effet, false)
		if e.has("pnj") and e.has("repliques"):
			var pnj := _trouver_pnj(e["pnj"])
			if pnj != null:
				pnj.repliques_speciales = PackedStringArray(e["repliques"])
		if e.has("objet"):
			var objet := _trouver_objet(e["objet"])
			if objet != null:
				objet.actif = true
		for option in e.get("choix", []):
			var objet_choix := _trouver_objet(option.get("objet", ""))
			if objet_choix != null:
				objet_choix.actif = true
		if e.has("recolter"):
			for objet in get_tree().get_nodes_in_group("objet_quete"):
				if objet.get("groupe") == e["recolter"] and objet.visible and not objet.get("ramasse"):
					objet.actif = true
		if e.has("apparition") and multiplayer.is_server() and _ici(e):
			_faire_apparaitre(e["apparition"], true)
	_mettre_a_jour_objectif()
	etape_changee.emit(e.get("id", ""))


func _mettre_a_jour_objectif() -> void:
	var e := etape_actuelle()
	if etape < 0:
		var fin: Dictionary = donnees.get("fin_provisoire", {})
		_chapitre.text = fin.get("chapitre", "")
		_texte_objectif.text = fin.get("objectif", "")
		_objectif.visible = _texte_objectif.text != ""
		return
	_objectif.visible = true
	_chapitre.text = "CHAPITRE %d · %s" % [e.get("chapitre", 0), String(e.get("titre_chapitre", "")).to_upper()]
	var texte: String = e.get("objectif", "")
	if e.has("tuer") or e.has("recolter"):
		texte += " (%d/%d)" % [compteur, int(e.get("nombre", 1))]
	_texte_objectif.text = texte
	var anim := create_tween()
	_objectif.modulate.a = 0.3
	anim.tween_property(_objectif, "modulate:a", 1.0, 0.5)


func _suivante(apres_deja_fait := false) -> void:
	var e := etape_actuelle()
	if not apres_deja_fait:
		_appliquer_apres(e, true)
	_aller_a(etape + 1 if etape + 1 < etapes.size() else -1)
	var fin: Dictionary = donnees.get("fin_provisoire", {})
	if etape < 0 and fin.has("message"):
		_annoncer(fin.get("titre", ""), fin.get("message", ""))


## Change le monde après une étape (Lenoir se relève, la faille se ferme…).
func _appliquer_apres(e: Dictionary, anime: bool) -> void:
	for effet in e.get("apres", []):
		_appliquer_effet(effet, anime)
	if anime and e.has("recompense"):
		_donner_recompense(e["recompense"])
	if anime and e.get("fin_chapitre", false):
		_annoncer("Chapitre %d terminé" % e.get("chapitre", 0), e.get("titre_chapitre", ""))


## Un changement du monde : un personnage se relève ou se déplace, un objet disparaît
## ou apparaît (ex. {"pnj": "toran", "aller": [30, -55]}, {"montrer": "main_peinte"}).
func _appliquer_effet(effet: Dictionary, anime: bool) -> void:
	if effet.has("pnj"):
		var pnj := _trouver_pnj(effet["pnj"]) as Node3D
		if pnj != null and effet.has("blesse"):
			pnj.blesse = bool(effet["blesse"])
		if pnj != null and effet.has("aller"):
			var ile := get_tree().get_first_node_in_group("ile")
			var a: Array = effet["aller"]
			var y: float = ile.hauteur(a[0], a[1]) if ile != null else pnj.global_position.y
			pnj.global_position = Vector3(a[0], y, a[1])
	if effet.has("cacher"):
		var objet := _trouver_objet(effet["cacher"])
		if objet != null and not anime and objet.has_method("fermer"):
			objet.fermer(false)
		elif objet != null:
			objet.cacher()
	if effet.has("appeler"):
		# Appelle une méthode d'un décor de quête (ex. Grise : soigner, fuir).
		for n in get_tree().get_nodes_in_group("decor_quete"):
			if n.get_meta("identifiant", "") == effet["appeler"] and n.has_method(effet.get("methode", "")):
				n.call(effet["methode"], anime)
	if effet.has("montrer"):
		for n in get_tree().get_nodes_in_group("decor_quete"):
			if n.get_meta("identifiant", "") == effet["montrer"]:
				n.visible = true


## Ajoute des objets dans les sacs du joueur (ex. [{"id": "lance_silex", "n": 1}]).
func _donner_recompense(objets: Array) -> void:
	var joueur := get_tree().get_first_node_in_group("joueur_local")
	var inventaire = joueur.get_node_or_null("Inventaire") if joueur != null else null
	var noms: PackedStringArray = []
	for o in objets:
		noms.append(String(o.get("nom", o["id"])))
	if inventaire != null and multiplayer.is_server():
		var liste: Array = []
		for o in objets:
			liste.append({"id": o["id"], "n": int(o.get("n", 1))})
		inventaire.recevoir(liste)
	_annoncer("Récompense", ", ".join(noms))


func _trouver_pnj(id: String) -> Node:
	for pnj in get_tree().get_nodes_in_group("pnj"):
		if pnj.get("identifiant") == id:
			return pnj
	return null


func _trouver_objet(id: String) -> Node:
	for objet in get_tree().get_nodes_in_group("objet_quete"):
		if objet.get("identifiant") == id:
			return objet
	return null


func _sur_dialogue_termine(id_pnj: String) -> void:
	var e := etape_actuelle()
	if e.has("pnj") and e.get("pnj", "") == id_pnj and not e.has("objet"):
		_suivante()


# --- Ennemis ----------------------------------------------------------------------

## Fait apparaître des ennemis autour d'un point. « unique » : ils ne réapparaissent pas.
func _faire_apparaitre(groupe: Dictionary, unique: bool) -> void:
	var ile := get_tree().get_first_node_in_group("ile")
	var dossier := get_tree().get_first_node_in_group("dossier_loups")
	if ile == null or dossier == null:
		return
	var centre: Array = groupe.get("position", [0, 0])
	var nombre := int(groupe.get("nombre", 1))
	var rayon := float(groupe.get("rayon", 4.0))
	for i in nombre:
		var angle := TAU * i / nombre + randf() * 0.5
		var x := float(centre[0]) + cos(angle) * rayon * randf_range(0.4, 1.0)
		var z := float(centre[1]) + sin(angle) * rayon * randf_range(0.4, 1.0)
		var p := Vector3(x, ile.hauteur(x, z) + 0.4, z)
		var loup = SCENE_LOUP.instantiate()
		loup.name = "%s_%d_%d" % [groupe.get("type", "loup"), Time.get_ticks_msec() % 100000, i]
		loup.type_ennemi = groupe.get("type", "loup")
		loup.position = p
		loup.camp = p
		loup.position_reseau = p
		loup.rotation.y = randf() * TAU
		if unique:
			loup.set_meta("unique", true)
		dossier.add_child(loup)
		if unique and groupe.get("attaque", false):
			# Ils sortent de la faille et foncent sur le joueur.
			var joueur := get_tree().get_first_node_in_group("joueur_local")
			if joueur != null:
				var combat = joueur.get_node_or_null("Combat")
				if combat != null:
					loup.engager.call_deferred(combat)


func _sur_nouvel_ennemi(n: Node) -> void:
	var combat := n.get_node_or_null("Combat")
	if combat == null or not combat.has_signal("mort"):
		return
	combat.mort.connect(func(_tueur): _sur_ennemi_vaincu(n))


func _sur_ennemi_vaincu(n: Node) -> void:
	if n.has_meta("unique") and multiplayer.is_server():
		# Le corps disparaît au bout de quelques secondes.
		get_tree().create_timer(8.0).timeout.connect(n.queue_free)
	var e := etape_actuelle()
	if not e.has("tuer") or not _ici(e):
		return
	var type := String(n.get("type_ennemi"))
	if not type.begins_with(String(e["tuer"])):
		return
	compteur += 1
	_mettre_a_jour_objectif()
	if compteur >= int(e.get("nombre", 1)):
		_suivante()


# --- Objets (F) --------------------------------------------------------------------

## Appelé par un objet de quête quand le joueur appuie sur F à côté.
func utiliser_objet(objet: Node3D) -> void:
	var e := etape_actuelle()
	if _canalisation != null:
		return
	if e.has("recolter") and objet.get("groupe") == e["recolter"]:
		_recolter(objet)
		return
	for option in e.get("choix", []):
		if option.get("objet", "") == objet.get("identifiant"):
			_choisir(option)
			e = etape_actuelle()
			break
	if e.get("objet", "") != objet.get("identifiant"):
		return
	var duree := float(e.get("duree", 0.0))
	if duree <= 0.0:
		_objet_utilise(objet)
		return
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return
	_canalisation = objet
	_canalisation_duree = duree
	_canalisation_temps = 0.0
	_canalisation_depart = joueur.global_position
	_texte_barre.text = e.get("action", "…")
	_cadre_barre.visible = true
	_combat_joueur = joueur.get_node_or_null("Combat")
	if _combat_joueur != null and not _combat_joueur.degats_recus.is_connected(_sur_degats_joueur):
		_combat_joueur.degats_recus.connect(_sur_degats_joueur)


func _objet_utilise(objet: Node3D) -> void:
	var e := etape_actuelle()
	if e.get("consomme", false):
		objet.cacher()
	if e.has("pnj") and e.has("repliques"):
		# Une action suivie d'une conversation (par exemple : soigner puis parler).
		var pnj := _trouver_pnj(e["pnj"])
		var dialogue := get_tree().get_first_node_in_group("dialogue")
		if pnj != null and dialogue != null:
			_appliquer_apres(e, true)
			pnj.parler()
			await dialogue.termine
			_suivante(true)
			return
	_suivante()


func _recolter(objet: Node3D) -> void:
	var e := etape_actuelle()
	var duree := float(e.get("duree", 0.0))
	if duree > 0.0:
		# Même fonctionnement qu'une action longue, puis on compte.
		var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
		if joueur == null:
			return
		_canalisation = objet
		_canalisation_duree = duree
		_canalisation_temps = 0.0
		_canalisation_depart = joueur.global_position
		_texte_barre.text = e.get("action", "…")
		_cadre_barre.visible = true
		return
	_compter_recolte(objet)


func _compter_recolte(objet: Node3D) -> void:
	objet.set("ramasse", true)
	objet.cacher()
	compteur += 1
	_mettre_a_jour_objectif()
	if compteur >= int(etape_actuelle().get("nombre", 1)):
		_suivante()


func _sur_degats_joueur(_montant: float, _source) -> void:
	if _canalisation != null:
		_interrompre("Interrompu !")


func _interrompre(raison: String) -> void:
	_canalisation = null
	if not _avant_choix.is_empty() and etape_actuelle().has("choix_fait"):
		# Action interrompue : le choix n'est pas encore fait, on peut changer d'avis.
		etapes[etape] = _avant_choix
		_avant_choix = {}
		var cfg := ConfigFile.new()
		cfg.load(fichier_progression)
		cfg.set_value(SECTION, "choix_" + String(etape_actuelle().get("id", "")), "")
		cfg.save(fichier_progression)
		for option in etape_actuelle().get("choix", []):
			var objet := _trouver_objet(option.get("objet", ""))
			if objet != null:
				objet.actif = true
		_mettre_a_jour_objectif()
	_texte_barre.text = raison
	get_tree().create_timer(0.8).timeout.connect(func():
		if _canalisation == null:
			_cadre_barre.visible = false)


# --- Chaque image ------------------------------------------------------------------

func _process(delta: float) -> void:
	_temps += delta
	_avancer_canalisation(delta)
	var e := etape_actuelle()
	var cible = _position_cible(e)
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	_repere.visible = cible != null and not _en_voyage
	if cible == null:
		_distance.text = ""
		return
	# Un personnage reconstruit (bouton de l'Inspecteur) reprend ses répliques de quête.
	if e.has("pnj") and e.has("repliques"):
		var pnj := _trouver_pnj(e["pnj"])
		if pnj != null and pnj.repliques_speciales.is_empty():
			pnj.repliques_speciales = PackedStringArray(e["repliques"])
	_repere.global_position = cible
	_cone.position.y = 2.7 + sin(_temps * 3.0) * 0.15
	_cone.rotation.y = _temps * 1.5
	if joueur == null:
		return
	var ecart := joueur.global_position.distance_to(cible)
	_distance.text = "%d m" % roundi(ecart)
	if e.has("zone") and _ici(e) and not e.has("arriver") and ecart < float(e.get("rayon", 4.0)):
		_suivante()


func _avancer_canalisation(delta: float) -> void:
	if _canalisation == null:
		return
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null or joueur.global_position.distance_to(_canalisation_depart) > 0.6:
		_interrompre("Interrompu : il faut rester immobile.")
		return
	_canalisation_temps += delta
	_barre.value = 100.0 * _canalisation_temps / _canalisation_duree
	if _canalisation_temps >= _canalisation_duree:
		var objet := _canalisation
		_canalisation = null
		_cadre_barre.visible = false
		if etape_actuelle().has("recolter"):
			_compter_recolte(objet)
		else:
			_objet_utilise(objet)


func _position_cible(e: Dictionary):
	var ile := get_tree().get_first_node_in_group("ile")
	# L'étape se passe dans une autre zone (ou il faut y aller) : on montre la sortie.
	var destination := String(e.get("arriver", "")) if e.has("arriver") else ("" if _ici(e) else String(e.get("ou", "")))
	if destination != "" and ile != null:
		var sortie: Vector2 = ile.sortie_vers(destination)
		if sortie == Vector2.INF:
			return null
		return Vector3(sortie.x, ile.hauteur(sortie.x, sortie.y), sortie.y)
	if e.has("choix"):
		var premier := _trouver_objet(e["choix"][0].get("objet", "")) as Node3D
		return premier.global_position if premier != null else null
	if e.has("recolter"):
		var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
		var meilleur = null
		for objet in get_tree().get_nodes_in_group("objet_quete"):
			if objet.get("groupe") == e["recolter"] and objet.actif:
				var p: Vector3 = objet.global_position
				if meilleur == null or (joueur != null and joueur.global_position.distance_to(p) < joueur.global_position.distance_to(meilleur)):
					meilleur = p
		return meilleur
	if e.has("objet"):
		var objet := _trouver_objet(e["objet"]) as Node3D
		return objet.global_position if objet != null else null
	if e.has("pnj"):
		var pnj := _trouver_pnj(e["pnj"]) as Node3D
		return pnj.global_position if pnj != null else null
	if e.has("zone"):
		var z: Array = e["zone"]
		var y: float = ile.hauteur(z[0], z[1]) if ile != null else 0.0
		return Vector3(z[0], y, z[1])
	if e.has("tuer") and e.has("lieu"):
		var l: Array = e["lieu"]
		return Vector3(l[0], ile.hauteur(l[0], l[1]) if ile != null else 0.0, l[1])
	return null


# --- Arrivée, annonces et voyage --------------------------------------------------------

func _arrivee() -> void:
	var a: Dictionary = donnees.get("zones", {}).get(_zone(), {}).get("arrivee", {})
	_titre.text = a.get("titre", "")
	_sous_titre.text = a.get("sous_titre", "")
	_recit.text = a.get("texte", "")
	_voile.color.a = 1.0
	_fin_annonces = _temps + 11.0
	var anim := create_tween()
	anim.tween_property(_titre, "modulate:a", 1.0, 1.0)
	anim.tween_property(_sous_titre, "modulate:a", 1.0, 0.8)
	anim.tween_property(_recit, "modulate:a", 1.0, 1.0)
	anim.tween_interval(2.5)
	anim.tween_property(_voile, "color:a", 0.0, 2.0)
	anim.parallel().tween_property(_recit, "modulate:a", 0.0, 1.0)
	anim.tween_interval(1.5)
	anim.tween_property(_titre, "modulate:a", 0.0, 1.2)
	anim.parallel().tween_property(_sous_titre, "modulate:a", 0.0, 1.2)


## Grand texte au milieu de l'écran pendant quelques secondes (chapitres).
## Les annonces se suivent (récompense, fin de chapitre, chapitre suivant) sans se cacher.
func _annoncer(titre: String, sous_titre: String) -> void:
	var attente := maxf(0.0, _fin_annonces - _temps)
	_fin_annonces = _temps + attente + 5.0
	var anim := create_tween()
	if attente > 0.0:
		anim.tween_interval(attente)
	anim.tween_callback(func():
		_titre.text = titre
		_sous_titre.text = sous_titre
		_recit.text = "")
	anim.tween_property(_titre, "modulate:a", 1.0, 0.8)
	anim.parallel().tween_property(_sous_titre, "modulate:a", 1.0, 0.8)
	anim.tween_interval(3.0)
	anim.tween_property(_titre, "modulate:a", 0.0, 1.0)
	anim.parallel().tween_property(_sous_titre, "modulate:a", 0.0, 1.0)


## Le joueur passe dans une autre zone de l'île (par un col, un gué…).
func changer_de_zone(zone: String) -> void:
	if _en_voyage:
		return
	var infos: Dictionary = donnees.get("zones", {}).get(zone, {})
	var scene := String(infos.get("scene", ""))
	if scene == "" or not ResourceLoader.exists(scene):
		return
	_en_voyage = true
	_titre.text = ""
	_sous_titre.text = ""
	_recit.text = ""
	var anim := create_tween()
	anim.tween_property(_voile, "color:a", 1.0, 0.8)
	if voyage_reel:
		anim.tween_callback(func():
			Reseau.set_meta("arrivee_prehistoire", _zone())
			get_tree().change_scene_to_file(scene))
	else:
		anim.tween_callback(func():
			_en_voyage = false
			zone_demandee = zone)


## Le joueur repasse le portail : retour à Hikari Bay, devant le portail du QG.
func rentrer_au_hub() -> void:
	if _en_voyage:
		return
	_en_voyage = true
	_titre.text = "Hikari Bay"
	_sous_titre.text = "Retour au QG de la Vigie"
	_recit.text = ""
	var anim := create_tween()
	anim.tween_property(_voile, "color:a", 1.0, 1.0)
	anim.parallel().tween_property(_titre, "modulate:a", 1.0, 1.0).set_delay(0.4)
	anim.parallel().tween_property(_sous_titre, "modulate:a", 1.0, 1.0).set_delay(0.6)
	anim.tween_interval(1.2)
	if voyage_reel:
		anim.tween_callback(func():
			Reseau.set_meta("arrivee_hub", "portails")
			get_tree().change_scene_to_file(Reseau.SCENE_HUB))
	else:
		anim.tween_callback(func(): _en_voyage = false)


# --- Interface ------------------------------------------------------------------------

func _construire_ecran() -> void:
	_ecran = CanvasLayer.new()
	_ecran.layer = 4
	add_child(_ecran)
	_objectif = PanelContainer.new()
	_objectif.anchor_left = 0.5
	_objectif.anchor_right = 0.5
	_objectif.offset_left = -270
	_objectif.offset_right = 270
	_objectif.offset_top = 14
	_objectif.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objectif.add_theme_stylebox_override("panel", _style(Color(0.04, 0.035, 0.03, 0.75), OR))
	_ecran.add_child(_objectif)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 2)
	_objectif.add_child(colonne)
	_chapitre = _etiquette(colonne, 13, OR)
	_texte_objectif = _etiquette(colonne, 19, Color.WHITE)
	_texte_objectif.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_distance = _etiquette(colonne, 14, Color(0.75, 0.75, 0.8))
	_objectif.visible = false
	# Barre d'action (soigner, refermer la faille…).
	_cadre_barre = PanelContainer.new()
	_cadre_barre.anchor_left = 0.5
	_cadre_barre.anchor_right = 0.5
	_cadre_barre.anchor_top = 1.0
	_cadre_barre.anchor_bottom = 1.0
	_cadre_barre.offset_left = -200
	_cadre_barre.offset_right = 200
	_cadre_barre.offset_top = -250
	_cadre_barre.offset_bottom = -200
	_cadre_barre.add_theme_stylebox_override("panel", _style(Color(0.04, 0.035, 0.03, 0.8), OR))
	_ecran.add_child(_cadre_barre)
	var col2 := VBoxContainer.new()
	_cadre_barre.add_child(col2)
	_texte_barre = _etiquette(col2, 15, Color.WHITE)
	_barre = ProgressBar.new()
	_barre.custom_minimum_size = Vector2(360, 10)
	_barre.show_percentage = false
	var plein := StyleBoxFlat.new()
	plein.bg_color = OR
	_barre.add_theme_stylebox_override("fill", plein)
	col2.add_child(_barre)
	_cadre_barre.visible = false
	# Voile noir et grands textes (arrivée, chapitres, voyages).
	var cinema := CanvasLayer.new()
	cinema.layer = 20
	add_child(cinema)
	_voile = ColorRect.new()
	_voile.color = Color(0, 0, 0, 0)
	_voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cinema.add_child(_voile)
	_titre = _texte_cinema(cinema, 54, -150, Color(1, 1, 1))
	_sous_titre = _texte_cinema(cinema, 22, -80, OR)
	_recit = _texte_cinema(cinema, 20, -20, Color(0.85, 0.85, 0.9))


func _style(fond: Color, bord: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fond
	style.border_color = Color(bord, 0.8)
	style.border_width_bottom = 2
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	return style


func _etiquette(parent: Node, taille: int, couleur: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _texte_cinema(parent: Node, taille: int, decalage: float, couleur: Color) -> Label:
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.anchor_left = 0.15
	l.anchor_right = 0.85
	l.offset_left = 0
	l.offset_right = 0
	l.offset_top = decalage
	l.offset_bottom = decalage + taille * 3
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	parent.add_child(l)
	return l


func _construire_repere() -> void:
	_repere = Node3D.new()
	_repere.name = "RepereObjectif"
	add_child(_repere)
	var lumineux := StandardMaterial3D.new()
	lumineux.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lumineux.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lumineux.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	lumineux.albedo_color = Color(OR, 0.12)
	lumineux.cull_mode = BaseMaterial3D.CULL_DISABLED
	_faisceau = MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.25
	tube.bottom_radius = 0.45
	tube.height = 30.0
	tube.cap_top = false
	tube.cap_bottom = false
	_faisceau.mesh = tube
	_faisceau.material_override = lumineux
	_faisceau.position.y = 15.0
	_faisceau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_repere.add_child(_faisceau)
	var fleche := StandardMaterial3D.new()
	fleche.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fleche.albedo_color = OR
	fleche.no_depth_test = true
	fleche.render_priority = 10
	_cone = MeshInstance3D.new()
	var pointe := CylinderMesh.new()
	pointe.top_radius = 0.3
	pointe.bottom_radius = 0.0
	pointe.height = 0.55
	pointe.radial_segments = 4
	pointe.rings = 1
	_cone.mesh = pointe
	_cone.material_override = fleche
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_repere.add_child(_cone)
	_repere.visible = false
