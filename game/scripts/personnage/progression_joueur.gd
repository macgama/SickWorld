class_name ProgressionJoueur
extends Node
## Progression d'un joueur : niveau, expérience (XP), talents et titres.
##
## Comme l'inventaire, c'est le SERVEUR qui décide : il donne l'XP (quêtes, ennemis,
## événements, découvertes), vérifie les talents choisis, enregistre et renvoie
## l'état au joueur. Les règles elles-mêmes sont dans Progression
## (scripts/personnage/progression.gd) et les réglages dans data/progression.json.
##
## Le niveau est partagé avec tout le monde par le nœud Combat (Combattant.niveau),
## le titre porté par le synchroniseur enfant (titre_affiche).
##
## Sauvegarde du prototype : un fichier par personnage, côté serveur
## (user://sauvegardes/progression/). Au tout premier chargement, l'XP des quêtes
## déjà faites (user://progression.cfg) est rendue d'un coup (« rattrapage »).

signal change
## Chez le joueur : de l'XP vient d'être gagnée (montant, raison).
signal xp_gagnee(montant: int, raison: String)
signal niveau_gagne(niveau: int)
signal titre_obtenu(nom: String)

const DOSSIER_SAUVEGARDE := "user://sauvegardes/progression/"
const ILES := Progression.ILES


## État complet (voir Progression). Sur le serveur : la référence. Chez le joueur : la copie reçue.
var etat: Dictionary = {}
## Nom du titre porté, visible par tous (sous le nom du personnage).
var titre_affiche := ""
## Désactive l'enregistrement sur disque (tests).
var sauvegarde_active := true
var _classe_appliquee := ""

@onready var joueur: Joueur = get_parent()
@onready var combat: Combattant = get_parent().get_node("Combat")
@onready var combat_joueur: CombatJoueur = get_parent().get_node("CombatJoueur")


static func donnees() -> Dictionary:
	return Progression.donnees()


## La progression du personnage joué sur ce PC (null s'il n'y en a pas).
static func du_joueur_local(arbre: SceneTree) -> Node:
	var j := arbre.get_first_node_in_group("joueur_local")
	return j.get_node_or_null("Progression") if j != null else null


func _ready() -> void:
	etat = Progression.etat_de_depart()
	joueur.get_node("Fiche").changee.connect(_sur_fiche_changee)
	if multiplayer.is_server():
		etat = _charger()
		_classe_appliquee = classe()
		Progression.nouveaux_titres(donnees(), etat, _total_secondaires())
		_appliquer()
		_decouvrir_zone.call_deferred()
	elif joueur.est_local():
		_demander_etat.rpc_id(1)


func classe() -> String:
	return combat_joueur.classe_id()


func niveau() -> int:
	return Progression.niveau(donnees(), etat)


## Bonus du niveau et des talents (même format que Objets.bonus), lu par l'Inventaire.
func bonus() -> Dictionary:
	return Progression.bonus(donnees(), classe(), etat, combat_joueur.pv_de_base())


func _sur_fiche_changee() -> void:
	# Changer de classe remet les talents à zéro (ils ne vont pas avec l'autre classe).
	if not multiplayer.is_server() or _classe_appliquee == classe():
		return
	_classe_appliquee = classe()
	Progression.oublier_talents(etat)
	_appliquer()


# --- Demandes du joueur (appelées par l'interface) ---------------------------

func prendre_talent(id: String) -> void:
	Regles.au_serveur(self, "_demander", ["talent", [id]])


func oublier_talents() -> void:
	Regles.au_serveur(self, "_demander", ["oublier", []])


func choisir_titre(id: String) -> void:
	Regles.au_serveur(self, "_demander", ["titre", [id]])


# --- Serveur : ce qui fait gagner de l'XP ------------------------------------

## Donne de l'XP (et annonce les niveaux gagnés).
func gagner_xp(montant: int, raison := "") -> void:
	if not multiplayer.is_server() or montant <= 0:
		return
	var avant := niveau()
	var plafond := Progression.xp_total_pour(donnees(), Progression.niveau_max(donnees()))
	etat["xp"] = mini(int(etat["xp"]) + montant, plafond)
	var apres := niveau()
	Regles.chez(joueur.id_reseau(), self, "_recevoir_xp", [montant, raison, apres if apres > avant else 0])
	_verifier_titres()
	_appliquer()


## Note un fait (« etape:prehistoire:vers_le_camp »…) une seule fois. Vrai si c'est nouveau.
func noter(fait: String) -> bool:
	if fait in etat["faits"]:
		return false
	etat["faits"].append(fait)
	return true


## Une étape de la quête principale vient d'être faite.
func etape_faite(ile: String, e: Dictionary) -> void:
	if not multiplayer.is_server() or not noter("etape:%s:%s" % [ile, e.get("id", "")]):
		return
	var n := Progression.niveau_zone(donnees(), String(e.get("ou", "")))
	var xp := Progression.xp_de(donnees(), "etape_quete", n)
	if e.get("fin_chapitre", false):
		xp += Progression.xp_de(donnees(), "fin_chapitre", n)
	gagner_xp(xp, "Quête")


## Une étape d'une quête secondaire vient d'être faite (finie = toute la quête).
func secondaire_faite(ile: String, id_quete: String, zone: String, finie: bool) -> void:
	if not multiplayer.is_server():
		return
	var n := Progression.niveau_zone(donnees(), zone)
	if finie:
		if not noter("secondaire:" + id_quete):
			return
		noter("secondaire_ile:%s:%s" % [ile, id_quete])
		gagner_xp(Progression.xp_de(donnees(), "quete_secondaire", n), "Quête secondaire")
	else:
		gagner_xp(Progression.xp_de(donnees(), "etape_secondaire", n), "Quête secondaire")


## Participation à un événement public (palier : or, argent ou bronze).
func evenement_fait(ile: String, id_evenement: String, zone: String, palier: String, reussi: bool) -> void:
	if not multiplayer.is_server() or palier == "":
		return
	var n := Progression.niveau_zone(donnees(), zone)
	var xp := Progression.xp_evenement(donnees(), n, palier if reussi else "bronze")
	if reussi:
		etat["faits"].append("evenement:%s:%s" % [ile, id_evenement])
	gagner_xp(xp if reussi else xp / 2, "Événement")


## Mission d'un habitant du hub accomplie.
func mission_faite(id_mission: String) -> void:
	if multiplayer.is_server() and noter("mission:" + id_mission):
		gagner_xp(Progression.xp_de(donnees(), "mission_hub", niveau()), "Mission")


## Un ennemi auquel on a participé vient d'être vaincu.
func ennemi_vaincu(type_ennemi: String, niveau_ennemi: int) -> void:
	if not multiplayer.is_server():
		return
	etat["tues"][type_ennemi] = int(etat["tues"].get(type_ennemi, 0)) + 1
	gagner_xp(Progression.xp_ennemi(donnees(), niveau_ennemi, niveau()), "")


## Première visite d'une zone.
func zone_decouverte(zone: String) -> void:
	if not multiplayer.is_server() or zone == "" or zone in etat["decouvertes"]:
		return
	if not (donnees().get("zones", {}) as Dictionary).has(zone):
		return
	etat["decouvertes"].append(zone)
	gagner_xp(Progression.xp_de(donnees(), "decouverte", Progression.niveau_zone(donnees(), zone)), "Découverte")


func _decouvrir_zone() -> void:
	var ile := get_tree().get_first_node_in_group("ile") if is_inside_tree() else null
	if ile != null and ile.get("identifiant_zone") != null:
		zone_decouverte(String(ile.get("identifiant_zone")))


## Un combat d'arène vient de finir (appelé par JcJ) : victoires, meilleure cote et
## meilleur rang du classement, pour les titres de l'Arène.
func resultat_arene(victoires: int, cote: int, rang: int) -> void:
	if not multiplayer.is_server():
		return
	var a: Dictionary = etat.get("arene", {})
	a["victoires"] = maxi(int(a.get("victoires", 0)), victoires)
	a["meilleure_cote"] = maxi(int(a.get("meilleure_cote", 0)), cote)
	if rang > 0 and (int(a.get("meilleur_rang", 0)) == 0 or rang < int(a.get("meilleur_rang", 0))):
		a["meilleur_rang"] = rang
	etat["arene"] = a
	_verifier_titres()
	_appliquer()


func _verifier_titres() -> void:
	for id in Progression.nouveaux_titres(donnees(), etat, _total_secondaires()):
		Regles.chez(joueur.id_reseau(), self, "_recevoir_titre", [Progression.nom_titre(donnees(), id)])


## Nombre de quêtes secondaires de chaque île (pour le titre « toutes les secondaires »).
static var _secondaires_par_ile := {}

func _total_secondaires() -> Dictionary:
	if _secondaires_par_ile.is_empty():
		for ile in ILES:
			var chemin := "res://data/%s_secondaires.json" % ile
			var lu = JSON.parse_string(FileAccess.get_file_as_string(chemin)) if FileAccess.file_exists(chemin) else null
			_secondaires_par_ile[ile] = (lu.get("quetes", []) as Array).size() if lu is Dictionary else 0
	return _secondaires_par_ile


# --- Serveur : demandes -------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _demander_etat() -> void:
	if multiplayer.is_server() and Regles.expediteur() == joueur.id_reseau():
		Regles.chez(joueur.id_reseau(), self, "_recevoir_etat", [etat])


@rpc("any_peer", "call_remote", "reliable")
func _demander(action: String, arguments: Array) -> void:
	if not multiplayer.is_server() or Regles.expediteur() != joueur.id_reseau():
		return
	var raison := ""
	match action:
		"talent":
			if combat.en_combat():
				raison = "Impossible en combat"
			else:
				raison = Progression.prendre_talent(donnees(), classe(), etat, String(arguments[0]))
		"oublier":
			if combat.en_combat():
				raison = "Impossible en combat"
			else:
				Progression.oublier_talents(etat)
				_dire("Talents oubliés : tes %d points sont libres" % Progression.points_libres(donnees(), etat))
		"titre":
			raison = Progression.choisir_titre(donnees(), etat, String(arguments[0]))
		_:
			raison = "Action inconnue"
	if raison != "":
		_dire(raison)
		return
	_appliquer()


## Serveur : met à jour le niveau, le titre visible et les bonus, enregistre et envoie au joueur.
func _appliquer() -> void:
	combat.niveau = niveau()
	titre_affiche = Progression.nom_titre(donnees(), String(etat.get("titre", "")))
	_sauvegarder()
	Regles.chez(joueur.id_reseau(), self, "_recevoir_etat", [etat])
	var inventaire := joueur.get_node_or_null("Inventaire")
	if inventaire != null and not inventaire.etat.is_empty():
		inventaire._appliquer()
	change.emit()


func _dire(texte: String) -> void:
	Regles.chez(joueur.id_reseau(), combat_joueur, "_recevoir_message", [texte])


# --- Chez le joueur ------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _recevoir_etat(nouvel_etat: Dictionary) -> void:
	etat = nouvel_etat
	if not multiplayer.is_server():
		var inventaire := joueur.get_node_or_null("Inventaire")
		if inventaire != null and not inventaire.etat.is_empty():
			inventaire._calculer_bonus()
	change.emit()


@rpc("authority", "call_remote", "reliable")
func _recevoir_xp(montant: int, raison: String, nouveau_niveau: int) -> void:
	xp_gagnee.emit(montant, raison)
	if nouveau_niveau > 0:
		niveau_gagne.emit(nouveau_niveau)


@rpc("authority", "call_remote", "reliable")
func _recevoir_titre(nom: String) -> void:
	titre_obtenu.emit(nom)


# --- Sauvegarde (serveur) ----------------------------------------------------

func _fichier() -> String:
	var cle := joueur.nom.to_lower().validate_filename().replace(" ", "_")
	return Profil.chemin(DOSSIER_SAUVEGARDE + (cle if cle != "" else "agent") + ".json")


func _charger() -> Dictionary:
	if sauvegarde_active and FileAccess.file_exists(_fichier()):
		return Progression.valider(donnees(), classe(), JSON.parse_string(FileAccess.get_file_as_string(_fichier())))
	var e := Progression.etat_de_depart()
	if sauvegarde_active and Reseau.a_un_joueur_local() and joueur.est_local():
		Progression.rattrapage(e, Profil.chemin("user://progression.cfg"))
	return e


func _sauvegarder() -> void:
	if not sauvegarde_active:
		return
	DirAccess.make_dir_recursive_absolute(Profil.chemin(DOSSIER_SAUVEGARDE))
	var f := FileAccess.open(_fichier(), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(etat, "\t"))
