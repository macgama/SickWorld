extends Node
## Événements publics de la Préhistoire (données : data/prehistoire_evenements.json).
##
## Ils arrivent tout seuls dans une zone, à intervalles réguliers, avec une annonce à
## l'écran : une grande faille qui crache des fracturés, une tempête de neige où il faut
## allumer des feux, la migration du troupeau de mammouths à protéger… Tous les joueurs
## présents peuvent aider, sans groupe. À la fin, chacun reçoit une récompense selon sa
## participation (or, argent, bronze) et la stabilité de l'époque monte.
##
## Pour l'instant (jeu en solo ou en hôte), l'horloge des événements tourne sur la
## machine du joueur ; avec le serveur dédié, elle tournera sur le serveur.

const DONNEES := "res://data/prehistoire_evenements.json"
const ObjetQuete := preload("res://scripts/monde/prehistoire/objet_quete.gd")
const Faille := preload("res://scripts/monde/prehistoire/faille.gd")
const SECTION := "prehistoire_evenements"
const ORANGE := Color(1.0, 0.6, 0.25)
## Points de participation pour une action (allumer un feu, refermer la faille…).
const POINTS_ACTION := 150.0
## Paliers de participation (part de l'effort total).
const PALIER_OR := 0.25
const PALIER_ARGENT := 0.10

signal evenement_commence(id: String)
signal evenement_fini(id: String, reussi: bool)

var evenements: Array = []
var premier_delai := 150.0
## Stabilité de l'époque (0 à 100) : monte à chaque événement réussi, baisse avec le temps.
var stabilite := 20.0
## Heure (Unix) du prochain passage de chaque événement.
var prochain := {}

## L'événement en cours ({} si aucun), et où il en est.
var actif: Dictionary = {}
var phase := -1
var restant := 0.0
var compteur := 0
var frayeur := 0.0
## Effort de chacun : combattant → points (dégâts infligés + actions).
var efforts := {}
var _vague := 0
var _ennemis: Array[Node] = []
var _objets := {}
var _troupeau: Array[Node] = []
var _prochaine_embuscade := 0.0
var _prochain_froid := 0.0
var _a_froid := false
var _minuterie := 0.0
var _quete: Node
## Repère de l'événement sur la carte et la mini-carte.
var _marqueur: Node3D

var _cadre: PanelContainer
var _titre: Label
var _objectif: Label
var _chrono: ProgressBar
var _texte_chrono: Label
var _jauge: Label
var _participation: Label


func _ready() -> void:
	add_to_group("evenements_publics")
	_quete = get_parent()
	var lu = JSON.parse_string(FileAccess.get_file_as_string(DONNEES))
	if lu is Dictionary:
		evenements = lu.get("evenements", [])
		premier_delai = float(lu.get("premier_delai", premier_delai))
	else:
		push_error("Impossible de lire %s : vérifie les virgules et les guillemets." % DONNEES)
	_charger()
	_construire_ecran()


func _zone() -> String:
	var ile := get_tree().get_first_node_in_group("ile")
	return String(ile.get("identifiant_zone")) if ile != null else ""


func _maintenant() -> float:
	return Time.get_unix_time_from_system()


func evenement(id: String) -> Dictionary:
	for e in evenements:
		if e.id == id:
			return e
	return {}


func en_cours() -> bool:
	return not actif.is_empty()


# --- Sauvegarde --------------------------------------------------------------------

func _fichier() -> String:
	return Profil.chemin(String(_quete.get("fichier_progression")))


func _charger() -> void:
	var cfg := ConfigFile.new()
	var maintenant := _maintenant()
	if cfg.load(_fichier()) == OK and not bool(_quete.get("toujours_recommencer")):
		stabilite = float(cfg.get_value(SECTION, "stabilite", stabilite))
		# La stabilité baisse doucement avec le temps (1 point par heure).
		var depuis := maintenant - float(cfg.get_value(SECTION, "stabilite_heure", maintenant))
		stabilite = clampf(stabilite - maxf(0.0, depuis) / 3600.0, 0.0, 100.0)
		for e in evenements:
			if cfg.has_section_key(SECTION, "prochain_" + e.id):
				prochain[e.id] = float(cfg.get_value(SECTION, "prochain_" + e.id))
	for e in evenements:
		if not prochain.has(e.id):
			prochain[e.id] = maintenant + premier_delai + randf_range(0.0, 60.0)
		# On ne se fait pas surprendre en arrivant dans la zone.
		prochain[e.id] = maxf(float(prochain[e.id]), maintenant + 30.0)


func _sauvegarder() -> void:
	var cfg := ConfigFile.new()
	cfg.load(_fichier())
	cfg.set_value(SECTION, "stabilite", stabilite)
	cfg.set_value(SECTION, "stabilite_heure", _maintenant())
	for id in prochain:
		cfg.set_value(SECTION, "prochain_" + id, prochain[id])
	cfg.save(_fichier())


func reussis(id: String) -> int:
	var cfg := ConfigFile.new()
	if cfg.load(_fichier()) != OK:
		return 0
	return int(cfg.get_value(SECTION, "reussis_" + id, 0))


# --- Horloge --------------------------------------------------------------------------

func debloque(e: Dictionary) -> bool:
	var sec = _quete.get("secondaires")
	return sec == null or sec.debloquee(e)


## Rien d'autre d'important ne se passe (dialogue, scène de la quête principale…).
func _moment_calme() -> bool:
	var dialogue := get_tree().get_first_node_in_group("dialogue")
	if dialogue != null and dialogue.est_ouvert():
		return false
	var ile := get_tree().get_first_node_in_group("ile")
	if ile != null and bool(ile.get("en_tempete")):
		return false
	for bete in get_tree().get_nodes_in_group("loups"):
		if bete.has_meta("unique") and not bete.has_meta("evenement") and bete.combat.est_vivant():
			return false
	return true


func _process(delta: float) -> void:
	if en_cours():
		_suivre(delta)
	_minuterie -= delta
	if _minuterie > 0.0:
		return
	_minuterie = 1.0
	if en_cours():
		_mettre_a_jour_ecran()
		return
	if not multiplayer.is_server():
		return
	var maintenant := _maintenant()
	for e in evenements:
		if e.get("zone", "") != _zone() or not debloque(e) or maintenant < float(prochain[e.id]):
			continue
		if _moment_calme():
			declencher(e.id)
		else:
			prochain[e.id] = maintenant + 30.0
		return


# --- Déroulement ------------------------------------------------------------------------

## Lance un événement tout de suite (utilisé par l'horloge et par les tests).
func declencher(id: String) -> void:
	var e := evenement(id)
	if e.is_empty() or en_cours():
		return
	actif = e
	restant = float(e.get("duree", 300))
	efforts.clear()
	frayeur = 0.0
	_ennemis.clear()
	prochain[id] = _maintenant() + float(e.get("intervalle", 3600))
	_sauvegarder()
	var ile := get_tree().get_first_node_in_group("ile")
	if e.get("tempete", false) and ile != null and ile.has_method("tempete"):
		ile.tempete(true)
	_installer_objets(e)
	_poser_marqueur(e)
	if e.has("troupeau"):
		_lancer_troupeau(e.troupeau)
	_quete.annoncer("Événement : " + String(e.titre), String(e.get("annonce", "")))
	_cadre.visible = true
	evenement_commence.emit(id)
	phase = -1
	_phase_suivante()


func phase_actuelle() -> Dictionary:
	if not en_cours() or phase < 0 or phase >= (actif.phases as Array).size():
		return {}
	return actif.phases[phase]


func _phase_suivante() -> void:
	phase += 1
	compteur = 0
	_vague = 0
	if phase >= (actif.phases as Array).size():
		_finir(true)
		return
	var p := phase_actuelle()
	if p.has("annonce"):
		_quete.annoncer(String(actif.titre), String(p.annonce))
	for id in _objets:
		var o = _objets[id]
		if is_instance_valid(o) and not o.ramasse:
			o.actif = (p.get("objet", "") == id) or (p.has("recolter") and p.recolter == o.groupe)
	if p.has("vagues"):
		_lancer_vague()
	if p.has("embuscades"):
		_prochaine_embuscade = float(p.embuscades.get("toutes", 25.0)) * 0.5
	_mettre_a_jour_ecran()


func _suivre(delta: float) -> void:
	restant -= delta
	if restant <= 0.0:
		_finir(false)
		return
	var p := phase_actuelle()
	if actif.has("froid"):
		_suivre_froid(delta)
	if p.get("escorte", false):
		_suivre_troupeau(delta, p)
	if p.has("vagues"):
		# La vague suivante sort quand celle-ci est tombée.
		var vivants := 0
		for n in _ennemis:
			if is_instance_valid(n) and n.combat.est_vivant():
				vivants += 1
		if vivants == 0 and multiplayer.is_server():
			_vague += 1
			if _vague >= _nombre_vagues(p):
				_phase_suivante()
			else:
				_lancer_vague()


## Les vagues marquées « avec_le_chef » sortent en même temps que la précédente.
func _nombre_vagues(p: Dictionary) -> int:
	var n := 0
	for v in p.vagues:
		if not v.get("avec_le_chef", false):
			n += 1
	return n


func _lancer_vague() -> void:
	var p := phase_actuelle()
	_ennemis.clear()
	var index := 0
	for v in p.vagues:
		if v.get("avec_le_chef", false):
			if index - 1 == _vague:
				_faire_apparaitre(v)
			continue
		if index == _vague:
			_faire_apparaitre(v)
		index += 1


func _faire_apparaitre(groupe: Dictionary, centre_force := Vector2.INF) -> void:
	var ile := get_tree().get_first_node_in_group("ile")
	var dossier := get_tree().get_first_node_in_group("dossier_loups")
	if ile == null or dossier == null or not multiplayer.is_server():
		return
	var centre := centre_force
	if centre == Vector2.INF:
		var pos: Array = groupe.get("position", actif.get("position", [0, 0]))
		centre = Vector2(pos[0], pos[1])
	var nombre := int(groupe.get("nombre", 1))
	var rayon := float(groupe.get("rayon", 4.0))
	var joueur := get_tree().get_first_node_in_group("joueur_local")
	for i in nombre:
		var angle := TAU * i / nombre + randf() * 0.5
		var x := centre.x + cos(angle) * rayon * randf_range(0.4, 1.0)
		var z := centre.y + sin(angle) * rayon * randf_range(0.4, 1.0)
		var position := Vector3(x, ile.hauteur(x, z) + 0.4, z)
		var loup = _quete.SCENE_LOUP.instantiate()
		loup.name = "Evenement_%s_%d_%d" % [groupe.get("type", "loup"), Time.get_ticks_msec() % 100000, i]
		loup.type_ennemi = groupe.get("type", "loup_fracture")
		loup.position = position
		loup.camp = position
		loup.position_reseau = position
		loup.rotation.y = randf() * TAU
		loup.set_meta("unique", true)
		loup.set_meta("evenement", actif.id)
		dossier.add_child(loup, true)
		_ennemis.append(loup)
		loup.combat.degats_recus.connect(_sur_degats_ennemi)
		if groupe.get("attaque", false) and joueur != null:
			var combat = joueur.get_node_or_null("Combat")
			if combat != null:
				loup.engager.call_deferred(combat)


func _sur_degats_ennemi(montant: float, source) -> void:
	if source != null and is_instance_valid(source):
		efforts[source] = float(efforts.get(source, 0.0)) + montant


func _combat_joueur() -> Node:
	var joueur := get_tree().get_first_node_in_group("joueur_local")
	return joueur.get_node_or_null("Combat") if joueur != null else null


# --- Objets (F) -------------------------------------------------------------------------

func _installer_objets(e: Dictionary) -> void:
	_objets.clear()
	var ile := get_tree().get_first_node_in_group("ile") as Node3D
	if ile == null:
		return
	for o in e.get("objets", []):
		var objet: Node3D
		if o.get("forme", "") == "faille":
			objet = Faille.new()
			objet.portee = 6.0
		else:
			objet = ObjetQuete.new()
			objet.forme = o.get("forme", "")
		objet.name = "Evenement_" + String(o.id)
		objet.identifiant = o.id
		objet.groupe = o.get("groupe", "")
		objet.invite = o.get("invite", "[F] Utiliser")
		objet.set_meta("evenement", e.id)
		var p: Array = o.position
		objet.position = Vector3(p[0], ile.hauteur(p[0], p[1]), p[1])
		ile.add_child(objet)
		if o.has("taille"):
			objet.scale = Vector3.ONE * float(o.taille)
		_objets[o.id] = objet


## Appelé par un objet d'événement quand on appuie sur F à côté.
func utiliser_objet(objet: Node3D) -> void:
	var p := phase_actuelle()
	var bon: bool = (p.has("recolter") and p.recolter == objet.get("groupe")) or p.get("objet", "") == objet.get("identifiant")
	if not bon or not objet.actif:
		return
	var duree := float(p.get("duree", 0.0))
	var fin := func(o: Node3D): _objet_fini(o)
	if duree > 0.0:
		_quete.canaliser(objet, duree, String(p.get("action", "…")), fin)
	else:
		fin.call(objet)


func _objet_fini(objet: Node3D) -> void:
	var p := phase_actuelle()
	if p.is_empty():
		return
	objet.actif = false
	objet.ramasse = true
	var combat := _combat_joueur()
	if combat != null:
		efforts[combat] = float(efforts.get(combat, 0.0)) + POINTS_ACTION
	match String(p.get("effet", "")):
		"fermer":
			objet.call("fermer", true)
		"allumer":
			_allumer(objet)
	compteur += 1
	if compteur >= int(p.get("nombre", 1)):
		_phase_suivante()
	else:
		_mettre_a_jour_ecran()


func _allumer(objet: Node3D) -> void:
	var ile := get_tree().get_first_node_in_group("ile")
	if ile == null or not ile.has_method("_feu") or objet.get_node_or_null("FeuDeVeille") != null:
		return
	var avant := ile.get_child_count()
	ile._feu(ile, Vector2(objet.global_position.x, objet.global_position.z), 0.8)
	if ile.get_child_count() > avant:
		var feu := ile.get_child(ile.get_child_count() - 1)
		feu.reparent(objet)
		feu.name = "FeuDeVeille"


# --- Le froid de la tempête -------------------------------------------------------------

## Vrai si le joueur est près d'un feu (le feu du camp ou un feu de veille allumé).
func au_chaud(position: Vector3) -> bool:
	var froid: Dictionary = actif.get("froid", {})
	var r := float(froid.get("rayon", 9.0))
	for c in froid.get("chaleur", []):
		if Vector2(position.x, position.z).distance_to(Vector2(c[0], c[1])) < r:
			return true
	for id in _objets:
		var o = _objets[id]
		if is_instance_valid(o) and o.get_node_or_null("FeuDeVeille") != null \
				and o.global_position.distance_to(position) < r:
			return true
	return false


func _suivre_froid(delta: float) -> void:
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return
	_a_froid = not au_chaud(joueur.global_position)
	_prochain_froid -= delta
	if _prochain_froid > 0.0:
		return
	var froid: Dictionary = actif.froid
	_prochain_froid = float(froid.get("toutes", 3.0))
	var combat = joueur.get_node_or_null("Combat")
	# Pas pendant une action : le froid ne doit pas interrompre l'allumage d'un feu.
	if _a_froid and combat != null and combat.est_vivant() and multiplayer.is_server() \
			and not _quete.canalise():
		# Le froid blesse doucement, mais ne tue pas : il laisse toujours un peu de vie.
		var degats: float = combat.pv_max * float(froid.get("degats_pourcent", 3)) / 100.0
		if combat.pv - degats > combat.pv_max * 0.1:
			combat.subir(degats, null)


# --- La Grande Migration ----------------------------------------------------------------

func _lancer_troupeau(t: Dictionary) -> void:
	_troupeau.clear()
	var chemin: Array[Vector2] = []
	for p in t.chemin:
		chemin.append(Vector2(p[0], p[1]))
	var k := 0
	for m in get_tree().get_nodes_in_group("mammouths"):
		if not m.has_method("migrer"):
			continue
		# Chacun marche un peu à côté des autres, pour former un vrai troupeau.
		var decalage := Vector2(cos(k * 2.4), sin(k * 2.4)) * (3.0 + k * 1.5)
		var sien: Array[Vector2] = []
		for p in chemin:
			sien.append(p + decalage)
		m.migrer(sien, float(t.get("vitesse", 1.7)))
		_troupeau.append(m)
		k += 1


## Le mammouth le plus en avance (pour placer les embuscades devant lui).
func _meneur() -> Node3D:
	for m in _troupeau:
		if is_instance_valid(m) and m.en_migration():
			return m
	return null


func troupeau_arrive() -> bool:
	for m in _troupeau:
		if is_instance_valid(m) and m.en_migration():
			return false
	return true


func _suivre_troupeau(delta: float, p: Dictionary) -> void:
	var t: Dictionary = actif.troupeau
	if troupeau_arrive():
		_phase_suivante()
		return
	# Les fracturés proches font peur aux mammouths.
	var r := float(t.get("rayon_frayeur", 14.0))
	var proches := 0
	for n in _ennemis:
		if not is_instance_valid(n) or not n.combat.est_vivant():
			continue
		for m in _troupeau:
			if is_instance_valid(m) and m.global_position.distance_to(n.global_position) < r:
				proches += 1
				break
	if proches > 0:
		frayeur = minf(100.0, frayeur + float(t.get("frayeur_par_seconde", 4.0)) * proches * delta)
	else:
		frayeur = maxf(0.0, frayeur - 1.5 * delta)
	if frayeur >= 100.0:
		for m in _troupeau:
			if is_instance_valid(m):
				m.paniquer(randf_range(3.0, 6.0))
		_finir(false)
		return
	# Des embuscades devant le troupeau.
	var e: Dictionary = p.get("embuscades", {})
	if e.is_empty() or not multiplayer.is_server():
		return
	_prochaine_embuscade -= delta
	if _prochaine_embuscade > 0.0:
		return
	_prochaine_embuscade = float(e.get("toutes", 25.0))
	var meneur := _meneur()
	if meneur == null:
		return
	var avant := -meneur.global_transform.basis.z
	var cote := Vector3(avant.z, 0, -avant.x) * (1.0 if randf() < 0.5 else -1.0)
	var point := meneur.global_position + avant * float(e.get("devant", 22.0)) + cote * 10.0
	var vivants: Array[Node] = []
	for n in _ennemis:
		if is_instance_valid(n) and n.combat.est_vivant():
			vivants.append(n)
	_ennemis = vivants
	var groupe := e.duplicate()
	groupe["attaque"] = false
	_faire_apparaitre(groupe, Vector2(point.x, point.z))


# --- Fin -----------------------------------------------------------------------------------

## Part de l'effort total fournie par « combattant » (0 à 1).
func participation(combattant) -> float:
	var total := 0.0
	for c in efforts:
		total += float(efforts[c])
	if total <= 0.0:
		return 0.0
	return float(efforts.get(combattant, 0.0)) / total


func palier(combattant) -> String:
	if not efforts.has(combattant) or float(efforts[combattant]) <= 0.0:
		return ""
	var part := participation(combattant)
	if part >= PALIER_OR:
		return "or"
	if part >= PALIER_ARGENT:
		return "argent"
	return "bronze"


const NOMS_PALIERS := {"or": "Or", "argent": "Argent", "bronze": "Bronze"}


func _finir(reussi: bool) -> void:
	var e := actif
	var combat := _combat_joueur()
	var rang := palier(combat)
	# Ce qui reste disparaît : la faille se referme, les fracturés repartent.
	for n in _ennemis:
		if is_instance_valid(n) and n.combat.est_vivant() and multiplayer.is_server():
			n.queue_free()
	_ennemis.clear()
	for id in _objets:
		var o = _objets[id]
		if not is_instance_valid(o):
			continue
		o.actif = false
		if o.has_method("fermer"):
			o.fermer(true)
			get_tree().create_timer(3.0).timeout.connect(o.queue_free)
		elif not reussi or o.get_node_or_null("FeuDeVeille") == null:
			o.queue_free()
		else:
			# Les feux de veille brûlent encore un moment, puis s'éteignent.
			get_tree().create_timer(60.0).timeout.connect(o.queue_free)
	_objets.clear()
	var ile := get_tree().get_first_node_in_group("ile")
	if e.get("tempete", false) and ile != null and ile.has_method("tempete"):
		ile.tempete(false)
	for m in _troupeau:
		if is_instance_valid(m) and m.en_migration():
			m.arreter_migration()
	_troupeau.clear()
	if _marqueur != null and is_instance_valid(_marqueur):
		_marqueur.queue_free()
	_marqueur = null
	actif = {}
	phase = -1
	_a_froid = false
	_cadre.visible = false
	if reussi:
		stabilite = clampf(stabilite + float(e.get("stabilite", 5)), 0.0, 100.0)
		var cfg := ConfigFile.new()
		cfg.load(_fichier())
		cfg.set_value(SECTION, "reussis_" + String(e.id), int(cfg.get_value(SECTION, "reussis_" + String(e.id), 0)) + 1)
		cfg.save(_fichier())
		_quete.annoncer("%s : réussi !" % e.titre, String(e.get("reussite", "")))
	else:
		stabilite = clampf(stabilite - 2.0, 0.0, 100.0)
		_quete.annoncer("%s : échec" % e.titre, String(e.get("echec", "")))
	# Un peu de calme avant l'événement suivant de la zone.
	for autre in evenements:
		if autre.get("zone", "") == e.get("zone", "") and autre.id != e.id:
			prochain[autre.id] = maxf(float(prochain[autre.id]), _maintenant() + 180.0)
	_sauvegarder()
	if rang != "":
		# En cas d'échec, seule la petite récompense est donnée.
		var cle := rang if reussi else "bronze"
		var objets: Array = []
		for o in e.get("recompenses", {}).get(cle, []):
			if randf() < float(o.get("chance", 1.0)):
				objets.append(o)
		if not objets.is_empty():
			_quete._donner_recompense(objets)
		_quete.annoncer("Participation : " + String(NOMS_PALIERS[rang]), "Stabilité de l'époque : %d %%" % roundi(stabilite))
	derniere_participation = rang
	evenement_fini.emit(String(e.id), reussi)


## Le palier obtenu au dernier événement ("" si on n'a rien fait), pour les tests.
var derniere_participation := ""


# --- Écran ----------------------------------------------------------------------------------

func _construire_ecran() -> void:
	var ecran := CanvasLayer.new()
	ecran.layer = 4
	add_child(ecran)
	_cadre = PanelContainer.new()
	_cadre.position = Vector2(16, 176)
	_cadre.custom_minimum_size = Vector2(330, 0)
	_cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.03, 0.02, 0.66)
	style.border_color = Color(ORANGE, 0.7)
	style.border_width_left = 3
	style.set_corner_radius_all(6)
	style.set_content_margin_all(9)
	_cadre.add_theme_stylebox_override("panel", style)
	ecran.add_child(_cadre)
	var liste := VBoxContainer.new()
	liste.add_theme_constant_override("separation", 5)
	_cadre.add_child(liste)
	liste.add_child(_etiquette("ÉVÉNEMENT", 12, ORANGE))
	_titre = _etiquette("", 17, Color(1, 0.92, 0.8))
	liste.add_child(_titre)
	_objectif = _etiquette("", 14, Color(0.88, 0.88, 0.9))
	_objectif.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objectif.custom_minimum_size.x = 310
	liste.add_child(_objectif)
	var ligne := HBoxContainer.new()
	liste.add_child(ligne)
	_chrono = ProgressBar.new()
	_chrono.show_percentage = false
	_chrono.custom_minimum_size = Vector2(240, 10)
	_chrono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(1, 1, 1, 0.12)
	fond.set_corner_radius_all(3)
	var plein := StyleBoxFlat.new()
	plein.bg_color = ORANGE
	plein.set_corner_radius_all(3)
	_chrono.add_theme_stylebox_override("background", fond)
	_chrono.add_theme_stylebox_override("fill", plein)
	_chrono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.add_child(_chrono)
	_texte_chrono = _etiquette("", 13, Color(1, 0.9, 0.75))
	ligne.add_child(_texte_chrono)
	_jauge = _etiquette("", 13, Color(0.75, 0.85, 1.0))
	liste.add_child(_jauge)
	_participation = _etiquette("", 12, Color(0.8, 0.8, 0.8))
	liste.add_child(_participation)
	_cadre.visible = false


func texte_objectif() -> String:
	var p := phase_actuelle()
	if p.is_empty():
		return ""
	var texte := String(p.get("objectif", ""))
	if p.has("recolter"):
		texte += " (%d/%d)" % [compteur, int(p.get("nombre", 1))]
	elif p.has("vagues"):
		texte += " (vague %d/%d)" % [mini(_vague + 1, _nombre_vagues(p)), _nombre_vagues(p)]
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	var pos: Array = actif.get("position", [0, 0])
	var cible := Vector3(pos[0], 0, pos[1])
	var meneur := _meneur()
	if meneur != null:
		cible = meneur.global_position
	if joueur != null:
		var d := Vector2(joueur.global_position.x, joueur.global_position.z).distance_to(Vector2(cible.x, cible.z))
		if d > 25.0:
			texte += " · %d m" % roundi(d)
	return texte


func _poser_marqueur(e: Dictionary) -> void:
	var ile := get_tree().get_first_node_in_group("ile") as Node3D
	if ile == null:
		return
	var p: Array = e.get("position", [0, 0])
	_marqueur = MarqueurCarte.creer(ile, MarqueurCarte.Type.DANGER, "Événement : " + String(e.titre),
			Vector3(p[0], ile.hauteur(p[0], p[1]), p[1]), true)


func _mettre_a_jour_ecran() -> void:
	if not en_cours():
		_cadre.visible = false
		return
	var meneur := _meneur()
	if meneur != null and _marqueur != null and is_instance_valid(_marqueur):
		_marqueur.global_position = meneur.global_position
	_cadre.visible = true
	_titre.text = String(actif.titre)
	_objectif.text = texte_objectif()
	_chrono.max_value = float(actif.get("duree", 300))
	_chrono.value = restant
	_texte_chrono.text = " %d:%02d" % [int(restant) / 60, int(restant) % 60]
	if actif.has("troupeau"):
		_jauge.text = "Frayeur du troupeau : %d %%" % roundi(frayeur)
		_jauge.visible = true
	elif actif.has("froid"):
		_jauge.text = "Tu as froid ! Approche-toi d'un feu." if _a_froid else "Tu es au chaud près du feu."
		_jauge.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0) if _a_froid else Color(1.0, 0.75, 0.45))
		_jauge.visible = true
	else:
		_jauge.visible = false
	var rang := palier(_combat_joueur())
	_participation.text = "Ta participation : " + (String(NOMS_PALIERS[rang]) if rang != "" else "aucune pour l'instant")


func _etiquette(texte: String, taille: int, couleur: Color) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
