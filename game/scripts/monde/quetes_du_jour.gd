extends Node
## Missions du jour et de la semaine (data/quetes_du_jour.json).
##
## Ayaka Mori, la maîtresse des missions du QG de la Vigie, propose chaque jour
## quelques missions courtes sur les îles déjà visitées, et chaque lundi des missions
## plus longues. On les accepte auprès d'elle (fenêtre qui s'ouvre après lui avoir
## parlé), on les fait sur les îles, puis on revient les lui rendre pour la récompense.
##
## Ce nœud est créé par la Partie dans chaque scène (hub et îles) : il compte les
## ennemis vaincus, les événements publics réussis et les éclats de temps ramassés,
## et affiche les missions suivies à droite de l'écran.
## L'avancement est gardé dans user://progression.cfg (section « quetes_du_jour »).

const ObjetQuete := preload("res://scripts/monde/prehistoire/objet_quete.gd")
const DONNEES := "res://data/quetes_du_jour.json"
const SECTION := "quetes_du_jour"
const OR := Color(1.0, 0.82, 0.35)
const CYAN := Color(0.45, 0.88, 1.0)
const VERT := Color(0.45, 0.92, 0.5)
## Un ennemi compte s'il meurt à moins de cette distance (mètres) du joueur.
const PORTEE_CREDIT := 60.0
const JOUR := 86400

signal change

@export var fichier_progression := "user://progression.cfg"
## Secondes ajoutées à l'horloge du PC (les tests s'en servent pour « passer au lendemain »).
var decalage_horloge := 0

var donnees := {}
var reglages := {}
## genre (« quotidienne », « hebdomadaire ») -> {"periode": int, "ids": [id…]}
var offres := {}
## "id@periode" -> {"id", "genre", "periode", "compte", "etat": "en_cours" | "a_rendre", "faits": [numéros]}
var suivies := {}
## "id@periode" -> true : missions déjà rendues pendant la période en cours.
var rendues := {}

var _ecran: CanvasLayer
var _cadre: PanelContainer
var _liste: VBoxContainer
var _annonce: Label
var _fenetre: PanelContainer
var _fenetre_corps: VBoxContainer
var _fenetre_bas: Label
var _marque: Label3D
var _objets := {} # "cle:numero" -> objet posé dans la zone
var _minuterie := 0.0
var _etapes_iles := {} # île -> [id des étapes de la quête principale]


func _ready() -> void:
	add_to_group("quetes_du_jour")
	var lu = JSON.parse_string(FileAccess.get_file_as_string(DONNEES))
	if lu is Dictionary:
		donnees = lu
	else:
		push_error("Impossible de lire %s : vérifie les virgules et les guillemets." % DONNEES)
	reglages = donnees.get("reglages", {})
	_charger()
	_construire_ecran()
	_brancher.call_deferred()
	# Certains nœuds (événements publics, personnages) arrivent un peu après la scène.
	get_tree().create_timer(1.0).timeout.connect(_brancher)


## Relie ce nœud au dialogue, aux ennemis et aux événements de la scène.
func _brancher() -> void:
	if not is_inside_tree():
		return
	# Même fichier de sauvegarde que la quête de la scène (les tests en changent).
	for groupe in ["quete", "quetes"]:
		var source := get_tree().get_first_node_in_group(groupe)
		if source != null and source.get("fichier_progression") != null:
			if String(source.get("fichier_progression")) != fichier_progression:
				fichier_progression = String(source.get("fichier_progression"))
				_charger()
			break
	var dialogue := get_tree().get_first_node_in_group("dialogue")
	if dialogue != null and not dialogue.termine.is_connected(_sur_dialogue_termine):
		dialogue.termine.connect(_sur_dialogue_termine)
	var loups := get_tree().get_first_node_in_group("dossier_loups")
	if loups != null and not loups.child_entered_tree.is_connected(_sur_nouvel_ennemi):
		loups.child_entered_tree.connect(_sur_nouvel_ennemi)
		for n in loups.get_children():
			_sur_nouvel_ennemi(n)
	for ev in get_tree().get_nodes_in_group("evenements_publics"):
		if ev.has_signal("evenement_fini") and not ev.evenement_fini.is_connected(_sur_evenement_fini):
			ev.evenement_fini.connect(_sur_evenement_fini.bind(ev))
	renouveler()
	_installer_objets()
	_rafraichir()


# --- Horloge et périodes ----------------------------------------------------------

## L'heure du PC (secondes, heure locale), décalée de l'heure de renouvellement.
func _horloge() -> int:
	var t := int(Time.get_unix_time_from_system()) + decalage_horloge
	t += int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return t - int(reglages.get("heure_renouvellement", 6)) * 3600


## Numéro du jour (ou de la semaine, qui commence le lundi) en cours.
func periode(genre: String) -> int:
	var jour := floori(_horloge() / float(JOUR))
	if genre == "hebdomadaire":
		# Le 1er janvier 1970 était un jeudi : +3 jours pour que la semaine commence lundi.
		return floori((jour + 3) / 7.0)
	return jour


## Secondes avant le prochain renouvellement.
func temps_restant(genre: String) -> int:
	var t := _horloge()
	if genre == "hebdomadaire":
		var debut := (periode(genre) + 1) * 7 - 3
		return debut * JOUR - t
	return (periode(genre) + 1) * JOUR - t


static func duree_lisible(secondes: int) -> String:
	var j := secondes / JOUR
	var h := (secondes % JOUR) / 3600
	var m := (secondes % 3600) / 60
	if j > 0:
		return "%d j %d h" % [j, h]
	if h > 0:
		return "%d h %02d" % [h, m]
	return "%d min" % maxi(1, m)


# --- Données ------------------------------------------------------------------------

func liste(genre: String) -> Array:
	return donnees.get("quotidiennes" if genre == "quotidienne" else "hebdomadaires", [])


func mission(id: String) -> Dictionary:
	for genre in ["quotidienne", "hebdomadaire"]:
		for m in liste(genre):
			if m.get("id", "") == id:
				return m
	return {}


func genre_de(id: String) -> String:
	for m in liste("hebdomadaire"):
		if m.get("id", "") == id:
			return "hebdomadaire"
	return "quotidienne"


func cle(id: String) -> String:
	return "%s@%d" % [id, periode(genre_de(id))]


## État d'une mission proposée aujourd'hui (ou cette semaine) :
## « disponible », « en_cours », « a_rendre » ou « rendue ».
func etat(id: String) -> String:
	var c := cle(id)
	if rendues.has(c):
		return "rendue"
	if suivies.has(c):
		return String(suivies[c]["etat"])
	return "disponible"


func nom_zone(zone: String) -> String:
	return String(donnees.get("noms_zones", {}).get(zone, zone))


func nom_ile(ile: String) -> String:
	return String(donnees.get("noms_iles", {}).get(ile, ile))


# --- Sauvegarde ---------------------------------------------------------------------

func _fichier() -> String:
	return Profil.chemin(fichier_progression)


func _charger() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_fichier()) != OK:
		return
	var o = cfg.get_value(SECTION, "offres", {})
	var s = cfg.get_value(SECTION, "suivies", {})
	var r = cfg.get_value(SECTION, "rendues", {})
	offres = o if o is Dictionary else {}
	suivies = s if s is Dictionary else {}
	rendues = r if r is Dictionary else {}


func _sauvegarder() -> void:
	var cfg := ConfigFile.new()
	cfg.load(_fichier())
	cfg.set_value(SECTION, "offres", offres)
	cfg.set_value(SECTION, "suivies", suivies)
	cfg.set_value(SECTION, "rendues", rendues)
	cfg.save(_fichier())


# --- Tirage des missions --------------------------------------------------------------

## L'île a-t-elle déjà été visitée (sa quête principale a commencé) ?
func ile_visitee(ile: String) -> bool:
	if ile == "":
		return ile_visitee("prehistoire") or ile_visitee("egypte")
	var cfg := ConfigFile.new()
	if cfg.load(_fichier()) != OK:
		return false
	return cfg.has_section_key(ile, "etape")


## La quête principale de l'île a-t-elle dépassé cette étape ?
func etape_passee(ile: String, id_etape: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(_fichier()) != OK:
		return false
	var actuelle := String(cfg.get_value(ile, "etape", ""))
	if actuelle == "fin":
		return true
	if actuelle == "":
		return false
	var ids: Array = _etapes_ile(ile)
	return ids.find(actuelle) > ids.find(id_etape) and ids.find(id_etape) >= 0


func _etapes_ile(ile: String) -> Array:
	if not _etapes_iles.has(ile):
		var ids: Array = []
		var lu = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s_quete.json" % ile))
		if lu is Dictionary:
			for c in lu.get("chapitres", []):
				for e in c.get("etapes", []):
					ids.append(String(e.get("id", "")))
		_etapes_iles[ile] = ids
	return _etapes_iles[ile]


## Le joueur peut-il recevoir cette mission (île visitée, histoire assez avancée) ?
func accessible(m: Dictionary) -> bool:
	if not ile_visitee(String(m.get("ile", ""))):
		return false
	var apres: Dictionary = m.get("apres", {})
	for ile in apres:
		if not etape_passee(String(ile), String(apres[ile])):
			return false
	return true


## Tire les missions de la période si elle a changé, oublie les missions périmées
## (sauf celles qui sont finies et pas encore rendues). Renvoie vrai si quelque chose change.
func renouveler() -> bool:
	var change_fait := false
	for genre in ["quotidienne", "hebdomadaire"]:
		var p := periode(genre)
		var offre: Dictionary = offres.get(genre, {})
		var ids: Array = offre.get("ids", [])
		if int(offre.get("periode", -1)) != p:
			ids = []
			change_fait = true
		var voulu := int(reglages.get("nombre_quotidiennes" if genre == "quotidienne" else "nombre_hebdomadaires", 3))
		if ids.size() < voulu:
			var tirees := _tirer(genre, p, voulu, ids)
			if tirees.size() != ids.size():
				change_fait = true
			ids = tirees
		offres[genre] = {"periode": p, "ids": ids}
	for c in suivies.keys():
		var s: Dictionary = suivies[c]
		if int(s["periode"]) != periode(String(s["genre"])) and String(s["etat"]) != "a_rendre":
			suivies.erase(c)
			change_fait = true
	for c in rendues.keys():
		var id := String(c).get_slice("@", 0)
		if String(c) != cle(id):
			rendues.erase(c)
			change_fait = true
	if change_fait:
		_sauvegarder()
	return change_fait


## Le tirage du jour : le même pour tout le monde (graine = numéro du jour), en
## alternant les îles. On garde les missions déjà tirées (« deja »).
func _tirer(genre: String, p: int, nombre: int, deja: Array) -> Array:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash("%s-%d" % [genre, p])
	var par_ile := {}
	var iles: Array = []
	for m in liste(genre):
		var ile := String(m.get("ile", ""))
		if not par_ile.has(ile):
			par_ile[ile] = []
			iles.append(ile)
		par_ile[ile].append(m)
	# Mélange de chaque île (Fisher-Yates avec la graine du jour, sans dépendre de l'accès).
	for ile in iles:
		var l: Array = par_ile[ile]
		for i in range(l.size() - 1, 0, -1):
			var j := hasard.randi_range(0, i)
			var t = l[i]
			l[i] = l[j]
			l[j] = t
	var depart := hasard.randi_range(0, maxi(0, iles.size() - 1))
	var resultat: Array = deja.duplicate()
	var restant := true
	while resultat.size() < nombre and restant:
		restant = false
		for k in iles.size():
			if resultat.size() >= nombre:
				break
			var l: Array = par_ile[iles[(depart + k) % iles.size()]]
			while not l.is_empty():
				var m: Dictionary = l.pop_front()
				if accessible(m) and not resultat.has(m.id):
					resultat.append(String(m.id))
					restant = true
					break
	return resultat


# --- Accepter, avancer, rendre ---------------------------------------------------------

## Les missions de la fenêtre : celles de la période, puis celles d'avant encore à rendre.
func missions_proposees() -> Array:
	var resultat: Array = []
	for genre in ["quotidienne", "hebdomadaire"]:
		for id in offres.get(genre, {}).get("ids", []):
			resultat.append({"id": String(id), "cle": cle(String(id)), "genre": genre, "ancienne": false})
	for c in suivies:
		var s: Dictionary = suivies[c]
		if int(s["periode"]) != periode(String(s["genre"])):
			resultat.append({"id": String(s["id"]), "cle": String(c), "genre": String(s["genre"]), "ancienne": true})
	return resultat


func accepter(id: String) -> void:
	if etat(id) != "disponible" or not (offres.get(genre_de(id), {}).get("ids", []) as Array).has(id):
		return
	var genre := genre_de(id)
	suivies[cle(id)] = {"id": id, "genre": genre, "periode": periode(genre), "compte": 0, "etat": "en_cours", "faits": []}
	_sauvegarder()
	annoncer("Nouvelle mission %s" % ("de la semaine" if genre == "hebdomadaire" else "du jour"), String(mission(id).get("titre", id)))
	_installer_objets()
	_apres_changement()


## Rend une mission finie (clé « id@période ») : la récompense va dans les sacs.
func rendre(c: String) -> void:
	if not suivies.has(c) or String(suivies[c]["etat"]) != "a_rendre":
		return
	var s: Dictionary = suivies[c]
	var m := mission(String(s["id"]))
	suivies.erase(c)
	if int(s["periode"]) == periode(String(s["genre"])):
		rendues[c] = true
	_sauvegarder()
	_donner_recompense(m.get("recompense", []))
	annoncer("Mission accomplie", String(m.get("titre", "")))
	if String(s["genre"]) == "quotidienne":
		_avancer_partout("rendre", {})
	_apres_changement()


func _avancer(c: String, n := 1) -> void:
	var s: Dictionary = suivies[c]
	var objectif: Dictionary = mission(String(s["id"])).get("objectif", {})
	s["compte"] = mini(int(s["compte"]) + n, _nombre(objectif))
	if int(s["compte"]) >= _nombre(objectif):
		s["etat"] = "a_rendre"
		annoncer("Mission terminée", "%s · retourne voir Ayaka au QG" % mission(String(s["id"])).get("titre", ""))
	_sauvegarder()
	_apres_changement()


func _nombre(objectif: Dictionary) -> int:
	return maxi(1, int(objectif.get("nombre", objectif.get("rendre", 1))))


## Fait avancer toutes les missions en cours dont l'objectif est de ce type et
## qui acceptent ces détails (type d'ennemi, île, zone, événement).
func _avancer_partout(type: String, details: Dictionary) -> void:
	for c in suivies.keys():
		var s: Dictionary = suivies[c]
		if String(s["etat"]) != "en_cours":
			continue
		var m := mission(String(s["id"]))
		if _correspond(m, type, details):
			_avancer(c)


func _correspond(m: Dictionary, type: String, details: Dictionary) -> bool:
	var o: Dictionary = m.get("objectif", {})
	var ile := String(o.get("ile", m.get("ile", "")))
	if ile != "" and String(details.get("ile", "")) != ile:
		return false
	if String(o.get("ou", "")) != "" and String(details.get("zone", "")) != String(o.get("ou", "")):
		return false
	match type:
		"tuer":
			var nom := String(details.get("ennemi", ""))
			for exclu in o.get("sauf", []):
				if nom.begins_with(String(exclu)):
					return false
			if o.has("tuer_contient"):
				return nom.contains(String(o["tuer_contient"]))
			for debut in o.get("tuer", []):
				if nom.begins_with(String(debut)):
					return true
			return false
		"evenement":
			return o.has("evenement") and (String(o["evenement"]) == "" or String(o["evenement"]) == String(details.get("evenement", "")))
		"rendre":
			return o.has("rendre")
	return false


## Objectif d'une mission en texte, avec l'avancement (pour la liste et la fenêtre).
func texte_objectif(c: String, id: String) -> String:
	var m := mission(id)
	var o: Dictionary = m.get("objectif", {})
	var compte := int(suivies[c]["compte"]) if suivies.has(c) else 0
	return "%s (%d/%d)" % [o.get("texte", ""), compte, _nombre(o)]


func texte_recompense(m: Dictionary) -> String:
	var morceaux: PackedStringArray = []
	var cat: Dictionary = Donnees.objets
	for r in m.get("recompense", []):
		var nom := String(Objets.objet(cat, String(r["id"])).get("nom", r["id"]))
		morceaux.append("%s × %d" % [nom, int(r.get("n", 1))] if int(r.get("n", 1)) > 1 else nom)
	return ", ".join(morceaux)


func _donner_recompense(objets: Array) -> void:
	var joueur := get_tree().get_first_node_in_group("joueur_local")
	var inventaire = joueur.get_node_or_null("Inventaire") if joueur != null else null
	if inventaire == null or not multiplayer.is_server():
		return
	var a_donner: Array = []
	for o in objets:
		a_donner.append({"id": String(o["id"]), "n": int(o.get("n", 1))})
	var restants: Array = inventaire.recevoir(a_donner)
	if not restants.is_empty():
		annoncer("Sacs pleins", "Une partie de la récompense n'a pas trouvé de place.")


func _apres_changement() -> void:
	_rafraichir()
	if _fenetre != null and _fenetre.visible:
		_remplir_fenetre()
	change.emit()


# --- Ce qui se passe dans le monde ------------------------------------------------------

func _zone() -> String:
	var ile := get_tree().get_first_node_in_group("ile")
	return String(ile.get("identifiant_zone")) if ile != null and ile.get("identifiant_zone") != null else ""


func _ile() -> String:
	var quete := get_tree().get_first_node_in_group("quete")
	return String(quete.get("ile")) if quete != null and quete.get("ile") != null else ""


func _sur_nouvel_ennemi(n: Node) -> void:
	if n.get("type_ennemi") == null:
		return
	if not n.is_node_ready():
		await n.ready
	var combat := n.get_node_or_null("Combat")
	if combat == null or not combat.has_signal("mort"):
		return
	if not combat.mort.is_connected(_sur_ennemi_vaincu):
		combat.mort.connect(_sur_ennemi_vaincu.bind(n))


func _sur_ennemi_vaincu(_tueur, n: Node) -> void:
	if not is_instance_valid(n):
		return
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null or joueur.global_position.distance_to((n as Node3D).global_position) > PORTEE_CREDIT:
		return
	_avancer_partout("tuer", {"ennemi": String(n.get("type_ennemi")), "ile": _ile(), "zone": _zone()})


func _sur_evenement_fini(id: String, reussi: bool, ev: Node) -> void:
	# Il faut avoir participé (palier or, argent ou bronze).
	if not reussi or String(ev.get("derniere_participation")) == "":
		return
	_avancer_partout("evenement", {"evenement": id, "ile": _ile(), "zone": _zone()})


func _sur_dialogue_termine(id_pnj: String) -> void:
	if id_pnj == String(reglages.get("pnj", "maitre_missions")):
		ouvrir_fenetre()


# --- Éclats de temps à ramasser -----------------------------------------------------------

## Pose dans la zone les objets des missions « recolter » en cours.
func _installer_objets() -> void:
	var ile := get_tree().get_first_node_in_group("ile") as Node3D
	if ile == null or not ile.has_method("hauteur"):
		return
	for c in suivies:
		var s: Dictionary = suivies[c]
		var o: Dictionary = mission(String(s["id"])).get("objectif", {})
		if not o.has("recolter") or String(o.get("ou", "")) != _zone() or String(s["etat"]) != "en_cours":
			continue
		var positions: Array = o.get("positions", [])
		for i in positions.size():
			var k := "%s:%d" % [c, i]
			if _objets.has(k) or i in (s.get("faits", []) as Array):
				continue
			var p: Array = positions[i]
			var objet: Node3D = ObjetQuete.new()
			objet.name = "EclatDuJour_%d" % i
			objet.identifiant = k
			objet.invite = String(o.get("invite", "[F] Ramasser l'éclat de temps"))
			objet.set_meta("du_jour", true)
			objet.position = Vector3(p[0], ile.hauteur(float(p[0]), float(p[1])), p[1])
			ile.add_child(objet)
			_dessiner_eclat(objet)
			objet.actif = true
			_objets[k] = objet


## Un éclat de temps : un cristal violet qui flotte et tourne doucement.
func _dessiner_eclat(objet: Node3D) -> void:
	var pivot := Node3D.new()
	pivot.name = "Eclat"
	pivot.position.y = 0.7
	objet.add_child(pivot)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.45, 1.0, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.35, 1.0)
	mat.emission_energy_multiplier = 2.2
	mat.roughness = 0.15
	mat.metallic = 0.3
	for j in 3:
		var cristal := MeshInstance3D.new()
		var prisme := CylinderMesh.new()
		prisme.top_radius = 0.0
		prisme.bottom_radius = 0.11 - j * 0.025
		prisme.height = 0.55 - j * 0.12
		prisme.radial_segments = 5
		prisme.rings = 1
		cristal.mesh = prisme
		cristal.material_override = mat
		cristal.position = Vector3((j - 1) * 0.09, prisme.height * 0.5 - 0.1, (j % 2) * 0.06)
		cristal.rotation = Vector3(0.25 * (j - 1), j * 1.3, 0.3 * (1 - j))
		pivot.add_child(cristal)
	var lueur := OmniLight3D.new()
	lueur.light_color = Color(0.62, 0.45, 1.0)
	lueur.light_energy = 1.2
	lueur.omni_range = 4.0
	pivot.add_child(lueur)
	var tween := pivot.create_tween().set_loops()
	tween.tween_property(pivot, "rotation:y", TAU, 4.0).from(0.0)


## Appelé par un éclat quand on appuie sur F à côté.
func utiliser_objet(objet: Node3D) -> void:
	var k := String(objet.get("identifiant"))
	var c := k.get_slice(":", 0)
	if not suivies.has(c) or String(suivies[c]["etat"]) != "en_cours":
		return
	var o: Dictionary = mission(String(suivies[c]["id"])).get("objectif", {})
	var fin := func(_o = null): _eclat_ramasse(k, objet)
	var quete := get_tree().get_first_node_in_group("quete")
	var duree := float(o.get("duree", 1.2))
	if quete != null and quete.has_method("canaliser") and duree > 0.0:
		quete.canaliser(objet, duree, String(o.get("action", "Ramasser l'éclat…")), fin)
	else:
		fin.call()


func _eclat_ramasse(k: String, objet: Node3D) -> void:
	var c := k.get_slice(":", 0)
	if not suivies.has(c) or String(suivies[c]["etat"]) != "en_cours":
		return
	var numero := int(k.get_slice(":", 1))
	var faits: Array = suivies[c].get("faits", [])
	if numero in faits:
		return
	faits.append(numero)
	suivies[c]["faits"] = faits
	_objets.erase(k)
	if is_instance_valid(objet):
		objet.queue_free()
	_avancer(c)
	# Mission finie : les éclats qui restent s'éteignent.
	if String(suivies[c]["etat"]) != "en_cours":
		for autre in _objets.keys():
			if String(autre).begins_with(c + ":"):
				if is_instance_valid(_objets[autre]):
					_objets[autre].queue_free()
				_objets.erase(autre)


# --- Chaque image ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_minuterie -= delta
	if _fenetre != null and _fenetre.visible:
		_fermer_si_loin()
	if _minuterie > 0.0:
		return
	_minuterie = 1.0
	if renouveler():
		annoncer("Nouvelles missions", "Ayaka Mori a de nouvelles missions au QG de la Vigie.")
		if _fenetre.visible:
			_remplir_fenetre()
	_rafraichir()


func _unhandled_input(event: InputEvent) -> void:
	if _fenetre != null and _fenetre.visible and event.is_action_pressed("annuler"):
		fermer_fenetre()
		get_viewport().set_input_as_handled()


## Liste à droite de l'écran et marque au-dessus d'Ayaka.
func _rafraichir() -> void:
	# La quête principale éteint parfois tous les objets de quête en changeant d'étape.
	for objet in _objets.values():
		if is_instance_valid(objet) and not objet.actif:
			objet.actif = true
	_mettre_a_jour_liste()
	_mettre_a_jour_marque()


func _pnj_missions() -> Node3D:
	for pnj in get_tree().get_nodes_in_group("pnj"):
		if String(pnj.get("identifiant")) == String(reglages.get("pnj", "maitre_missions")):
			return pnj
	return null


func _mettre_a_jour_marque() -> void:
	var pnj := _pnj_missions()
	if pnj == null:
		return
	var signe := ""
	for p in missions_proposees():
		var e := String(suivies[p.cle]["etat"]) if suivies.has(p.cle) else ("rendue" if rendues.has(p.cle) else "disponible")
		if e == "a_rendre":
			signe = "?"
			break
		if e == "disponible" and not p.ancienne:
			signe = "!"
	if _marque == null or not is_instance_valid(_marque):
		_marque = Label3D.new()
		_marque.name = "MarqueMissionsDuJour"
		_marque.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_marque.font_size = 120
		_marque.pixel_size = 0.005
		_marque.outline_size = 18
		_marque.modulate = CYAN
		_marque.outline_modulate = Color(0.0, 0.12, 0.25)
		_marque.position = Vector3(0, 2.75, 0)
		pnj.add_child(_marque)
	_marque.text = signe
	_marque.visible = signe != ""


# --- Écran : liste des missions suivies, annonces -----------------------------------------

func _construire_ecran() -> void:
	_ecran = CanvasLayer.new()
	_ecran.layer = 4
	add_child(_ecran)
	_cadre = PanelContainer.new()
	_cadre.anchor_left = 1.0
	_cadre.anchor_right = 1.0
	_cadre.offset_left = -340
	_cadre.offset_right = -14
	_cadre.offset_top = 268
	_cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.07, 0.6)
	style.border_color = Color(CYAN, 0.55)
	style.border_width_left = 2
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	_cadre.add_theme_stylebox_override("panel", style)
	_ecran.add_child(_cadre)
	_liste = VBoxContainer.new()
	_liste.add_theme_constant_override("separation", 5)
	_cadre.add_child(_liste)
	_cadre.visible = false
	_annonce = Label.new()
	_annonce.anchor_left = 0.2
	_annonce.anchor_right = 0.8
	_annonce.offset_top = 120
	_annonce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_annonce.add_theme_font_size_override("font_size", 24)
	_annonce.add_theme_color_override("font_color", CYAN)
	_annonce.add_theme_constant_override("outline_size", 8)
	_annonce.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_annonce.modulate.a = 0.0
	_annonce.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ecran.add_child(_annonce)
	_construire_fenetre()


func annoncer(titre: String, sous_titre: String) -> void:
	if _annonce == null:
		return
	_annonce.text = titre + ("\n" + sous_titre if sous_titre != "" else "")
	var anim := _annonce.create_tween()
	anim.tween_property(_annonce, "modulate:a", 1.0, 0.3)
	anim.tween_interval(3.2)
	anim.tween_property(_annonce, "modulate:a", 0.0, 0.8)


func _mettre_a_jour_liste() -> void:
	if _liste == null:
		return
	for enfant in _liste.get_children():
		enfant.queue_free()
	var nombre := 0
	_liste.add_child(_etiquette("MISSIONS DE LA VIGIE", 12, CYAN))
	for c in suivies:
		var s: Dictionary = suivies[c]
		var m := mission(String(s["id"]))
		if m.is_empty():
			continue
		nombre += 1
		var finie := String(s["etat"]) == "a_rendre"
		var marque := "✓ " if finie else ("◇ " if String(s["genre"]) == "hebdomadaire" else "◆ ")
		_liste.add_child(_etiquette(marque + String(m.get("titre", "")), 15, VERT if finie else Color(0.85, 0.95, 1.0)))
		var texte := "Retourne voir Ayaka Mori au QG de la Vigie" if finie else texte_objectif(c, String(s["id"]))
		var o: Dictionary = m.get("objectif", {})
		if not finie and String(o.get("ou", "")) != "" and String(o.get("ou", "")) != _zone():
			texte += " · " + nom_zone(String(o["ou"]))
		var ligne := _etiquette(texte, 13, Color(0.82, 0.85, 0.9))
		ligne.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ligne.custom_minimum_size.x = 300
		_liste.add_child(ligne)
	_cadre.visible = nombre > 0
	_placer()


## Sous la liste des quêtes secondaires de l'île (ou l'aide des touches), à droite.
func _placer() -> void:
	var haut := 268.0
	var partie := get_tree().get_first_node_in_group("partie")
	var hud := partie.get_node_or_null("Interface") if partie != null else null
	var aide = hud.get("_aide") if hud != null else null
	if aide is Control and aide.is_visible_in_tree():
		haut = maxf(haut, aide.get_global_rect().end.y + 10.0)
	var secondaires := get_tree().get_first_node_in_group("quetes_secondaires")
	var cadre = secondaires.get("_cadre") if secondaires != null else null
	if cadre is Control and cadre.visible:
		haut = maxf(haut, cadre.get_global_rect().end.y + 8.0)
	_cadre.offset_top = haut


func _etiquette(texte: String, taille: int, couleur: Color) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# --- Fenêtre d'Ayaka Mori ---------------------------------------------------------------------

func _construire_fenetre() -> void:
	_fenetre = PanelContainer.new()
	_fenetre.name = "FenetreMissions"
	_fenetre.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.075, 0.97)
	style.border_color = Color(CYAN, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	_fenetre.add_theme_stylebox_override("panel", style)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 10)
	_fenetre.add_child(colonne)
	var haut := HBoxContainer.new()
	colonne.add_child(haut)
	var textes := VBoxContainer.new()
	textes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haut.add_child(textes)
	var titre := _texte("Missions de la Vigie", 22)
	titre.modulate = CYAN
	textes.add_child(titre)
	var accueil := _texte("Ayaka Mori · « Des petites missions, chaque jour. C'est comme ça qu'on tient une époque debout. »", 13)
	accueil.modulate.a = 0.75
	textes.add_child(accueil)
	var aide := _texte("Échap : fermer", 12)
	aide.modulate.a = 0.5
	haut.add_child(aide)
	var fermer := Button.new()
	fermer.text = "  ✕  "
	fermer.focus_mode = Control.FOCUS_NONE
	fermer.pressed.connect(fermer_fenetre)
	haut.add_child(fermer)
	var defile := ScrollContainer.new()
	defile.custom_minimum_size = Vector2(760, 470)
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	colonne.add_child(defile)
	_fenetre_corps = VBoxContainer.new()
	_fenetre_corps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fenetre_corps.add_theme_constant_override("separation", 8)
	defile.add_child(_fenetre_corps)
	_fenetre_bas = _texte("", 13)
	_fenetre_bas.modulate = Color(1, 1, 1, 0.8)
	_fenetre_bas.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	colonne.add_child(_fenetre_bas)
	_fenetre.visible = false
	_ecran.add_child(_fenetre)


func _texte(contenu: String, taille := 14) -> Label:
	var l := Label.new()
	l.text = contenu
	l.add_theme_font_size_override("font_size", taille)
	return l


func ouvrir_fenetre() -> void:
	renouveler()
	_fenetre.visible = true
	_remplir_fenetre()
	_centrer.call_deferred()


func fermer_fenetre() -> void:
	_fenetre.visible = false


func fenetre_ouverte() -> bool:
	return _fenetre != null and _fenetre.visible


func _centrer() -> void:
	_fenetre.reset_size()
	_fenetre.position = ((_fenetre.get_viewport_rect().size - _fenetre.size) / 2.0).floor()


func _fermer_si_loin() -> void:
	var pnj := _pnj_missions()
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if pnj == null or joueur == null:
		return
	if joueur.global_position.distance_to(pnj.global_position) > float(reglages.get("distance", 6.0)):
		fermer_fenetre()


func _remplir_fenetre() -> void:
	for enfant in _fenetre_corps.get_children():
		enfant.queue_free()
	var proposees := missions_proposees()
	var sections := [
		["quotidienne", false, "Missions du jour · nouvelles dans %s" % duree_lisible(temps_restant("quotidienne"))],
		["hebdomadaire", false, "Missions de la semaine · nouvelles dans %s" % duree_lisible(temps_restant("hebdomadaire"))],
		["", true, "Missions passées à rendre"],
	]
	for section in sections:
		var lignes: Array = proposees.filter(func(p): return p.ancienne == section[1] and (section[1] or p.genre == section[0]))
		if lignes.is_empty() and section[1]:
			continue
		var t := _texte(section[2], 16)
		t.modulate = OR
		_fenetre_corps.add_child(t)
		if lignes.is_empty():
			var vide := _texte("Rien pour l'instant. Va d'abord explorer une époque par la Salle des portails.", 13)
			vide.modulate.a = 0.7
			_fenetre_corps.add_child(vide)
		for p in lignes:
			_fenetre_corps.add_child(_ligne_mission(p))
	var insignes := 0
	var joueur := get_tree().get_first_node_in_group("joueur_local")
	var inventaire = joueur.get_node_or_null("Inventaire") if joueur != null else null
	if inventaire != null:
		for case in inventaire.etat.get("cases", []):
			if String((case as Dictionary).get("id", "")) == "insigne_vigie":
				insignes += int(case.get("n", 1))
	_fenetre_bas.text = "Insignes de la Vigie dans tes sacs : %d · Échange-les auprès de Sven Halvorsen, l'intendant, juste à côté." % insignes


func _ligne_mission(p: Dictionary) -> Control:
	var id := String(p.id)
	var c := String(p.cle)
	var m := mission(id)
	var e := "rendue" if rendues.has(c) else (String(suivies[c]["etat"]) if suivies.has(c) else "disponible")
	var cadre := PanelContainer.new()
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(1, 1, 1, 0.045 if e != "rendue" else 0.02)
	fond.border_color = Color(CYAN if p.genre == "quotidienne" else OR, 0.5)
	fond.border_width_left = 3
	fond.set_corner_radius_all(6)
	fond.set_content_margin_all(10)
	cadre.add_theme_stylebox_override("panel", fond)
	var rangee := HBoxContainer.new()
	rangee.add_theme_constant_override("separation", 14)
	cadre.add_child(rangee)
	var textes := VBoxContainer.new()
	textes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textes.add_theme_constant_override("separation", 3)
	rangee.add_child(textes)
	var ile := String(m.get("ile", ""))
	var lieu := nom_ile(ile) if ile != "" else "Toutes les époques"
	var o: Dictionary = m.get("objectif", {})
	if String(o.get("ou", "")) != "":
		lieu += " · " + nom_zone(String(o["ou"]))
	var titre := _texte("%s   [%s]" % [m.get("titre", id), lieu], 16)
	titre.modulate = Color(1, 1, 1, 0.45) if e == "rendue" else Color(0.9, 0.97, 1.0)
	textes.add_child(titre)
	var resume := _texte(String(m.get("resume", "")), 13)
	resume.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resume.custom_minimum_size.x = 560
	resume.modulate.a = 0.7 if e != "rendue" else 0.35
	textes.add_child(resume)
	var objectif := _texte("→ " + texte_objectif(c, id), 13)
	objectif.modulate = VERT if e == "a_rendre" else Color(0.75, 0.88, 1.0, 1.0 if e != "rendue" else 0.4)
	textes.add_child(objectif)
	var gain := _texte("Récompense : " + texte_recompense(m), 13)
	gain.modulate = Color(OR, 1.0 if e != "rendue" else 0.4)
	gain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gain.custom_minimum_size.x = 560
	textes.add_child(gain)
	var bouton := Button.new()
	bouton.custom_minimum_size = Vector2(130, 40)
	bouton.focus_mode = Control.FOCUS_NONE
	bouton.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bouton.add_theme_font_size_override("font_size", 15)
	match e:
		"disponible":
			bouton.text = "Accepter"
			bouton.pressed.connect(accepter.bind(id))
		"en_cours":
			bouton.text = "En cours"
			bouton.disabled = true
		"a_rendre":
			bouton.text = "Rendre"
			bouton.pressed.connect(rendre.bind(c))
		_:
			bouton.text = "✓ Faite"
			bouton.disabled = true
	rangee.add_child(bouton)
	return cadre
