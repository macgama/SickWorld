extends Node
## Inventaire, équipement et tenues de mission d'un joueur.
##
## Comme le combat, c'est le SERVEUR qui décide : le joueur envoie des demandes
## (« équipe l'objet de la case 3 », « mets la tenue 2 »), le serveur vérifie,
## modifie l'inventaire, l'enregistre et renvoie le nouvel état au joueur.
## Les règles elles-mêmes sont dans Objets (scripts/objets/objets.gd).
##
## Ce qui se voit sur le personnage (« porte ») est partagé avec tout le monde
## par le synchroniseur enfant ; le contenu des sacs, lui, n'est envoyé qu'au propriétaire.
##
## Sauvegarde du prototype : un fichier par personnage, côté serveur
## (user://sauvegardes/inventaires/). Elle passera dans Nakama à l'étape 4.

signal change
signal porte_change

const DOSSIER_SAUVEGARDE := "user://sauvegardes/inventaires/"
const Artisanat := preload("res://scripts/objets/artisanat.gd")

## État complet (voir Objets). Sur le serveur : la référence. Chez le joueur : la copie reçue.
var etat: Dictionary = {}
## Ce que le personnage porte (emplacement -> id d'objet), visible par tous.
var porte: Dictionary = {}:
	set(valeur):
		porte = valeur
		porte_change.emit()
		_habiller.call_deferred()
## Bonus calculés à partir de l'équipement (voir Objets.bonus).
var bonus: Dictionary = {}
## Tenue en train d'être mise (serveur) : -1 = aucune.
var _changement := -1
var _fin_changement := 0.0
## Désactive l'enregistrement sur disque (tests).
var sauvegarde_active := true

@onready var joueur: Joueur = get_parent()
@onready var combat: Combattant = get_parent().get_node("Combat")
@onready var combat_joueur: CombatJoueur = get_parent().get_node("CombatJoueur")


func _ready() -> void:
	if multiplayer.is_server():
		etat = _charger()
		_appliquer()
	elif joueur.est_local():
		# Le premier envoi du serveur peut arriver avant que notre personnage existe ici :
		# on redemande l'inventaire une fois prêt.
		_demander_etat.rpc_id(1)


func cat() -> Dictionary:
	return Donnees.objets


## Barre par défaut de la classe du personnage (compétences 1 à 5 de sa classe).
func _barre_par_defaut() -> Array:
	return combat_joueur.barre_par_defaut()


# --- Demandes du joueur (appelées par l'interface) ---------------------------

## Clic sur une case des sacs : équiper l'objet (ou accrocher le sac).
func utiliser(index: int) -> void:
	Regles.au_serveur(self, "_demander", ["utiliser", [index]])


func retirer(emplacement: String) -> void:
	Regles.au_serveur(self, "_demander", ["retirer", [emplacement]])


func jeter(index: int) -> void:
	Regles.au_serveur(self, "_demander", ["jeter", [index]])


func decrocher_sac(place: int) -> void:
	Regles.au_serveur(self, "_demander", ["decrocher_sac", [place]])


func ranger() -> void:
	Regles.au_serveur(self, "_demander", ["ranger", []])


func changer_competence(index: int, id: String) -> void:
	Regles.au_serveur(self, "_demander", ["competence", [index, id]])


func enregistrer_tenue(numero: int, nom: String) -> void:
	Regles.au_serveur(self, "_demander", ["enregistrer_tenue", [numero, nom]])


func mettre_tenue(numero: int) -> void:
	Regles.au_serveur(self, "_demander", ["mettre_tenue", [numero]])


## Fabrique (ou améliore) un objet chez un artisan du hub (voir data/artisanat.json).
func fabriquer(recette: String) -> void:
	Regles.au_serveur(self, "_demander", ["fabriquer", [recette]])


## Numéro de la tenue qui correspond exactement à ce que l'on porte (-1 si aucune).
func tenue_portee() -> int:
	var tenues: Array = etat.get("tenues", [])
	for i in tenues.size():
		var t: Dictionary = tenues[i]
		if not t.is_empty() and t["equipement"] == etat["equipement"] and t["barre"] == etat["barre"]:
			return i
	return -1


# --- Serveur -----------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _demander_etat() -> void:
	if multiplayer.is_server() and Regles.expediteur() == joueur.id_reseau() and not etat.is_empty():
		Regles.chez(joueur.id_reseau(), self, "_recevoir_etat", [etat])


@rpc("any_peer", "call_remote", "reliable")
func _demander(action: String, arguments: Array) -> void:
	if not multiplayer.is_server() or Regles.expediteur() != joueur.id_reseau():
		return
	var raison := ""
	if not combat.est_vivant():
		raison = "Tu es désynchronisé"
	elif combat.en_combat() and action != "jeter" and action != "ranger":
		raison = "Impossible en combat"
	elif _changement >= 0:
		raison = "Tu es en train de te changer"
	if raison == "":
		raison = _executer(action, arguments)
	if raison != "":
		_dire(raison)
		return
	if action != "mettre_tenue":
		_appliquer()


func _executer(action: String, a: Array) -> String:
	var c := cat()
	match action:
		"utiliser":
			return Objets.utiliser(c, etat, int(a[0]))
		"retirer":
			return Objets.retirer(c, etat, String(a[0])) if String(a[0]) in Objets.EMPLACEMENTS else "?"
		"jeter":
			return Objets.jeter(etat, int(a[0]))
		"decrocher_sac":
			return Objets.decrocher_sac(c, etat, int(a[0]))
		"ranger":
			Objets.tasser(etat)
			return ""
		"competence":
			return Objets.changer_competence(c, etat, int(a[0]), String(a[1]))
		"enregistrer_tenue":
			var r := Objets.enregistrer_tenue(c, etat, int(a[0]), String(a[1]))
			if r == "":
				_dire("Tenue « %s » enregistrée" % etat["tenues"][int(a[0])]["nom"])
			return r
		"fabriquer":
			return _fabriquer(String(a[0]))
		"mettre_tenue":
			var numero := int(a[0])
			var r := Objets.raison_tenue_impossible(c, etat, numero)
			if r != "":
				return r
			if tenue_portee() == numero:
				return "Tu portes déjà cette tenue"
			_changement = numero
			var duree := float(Objets.reglage(c, "duree_changement_de_tenue", 2.0))
			_fin_changement = Regles.maintenant() + duree
			Regles.chez(joueur.id_reseau(), combat_joueur, "_recevoir_incantation",
					["Se changer : " + String(etat["tenues"][numero]["nom"]), duree])
			return ""
	return "Action inconnue"


## Serveur : il faut être près d'un artisan qui connaît la recette.
func _fabriquer(id_recette: String) -> String:
	var art: Dictionary = Donnees.artisanat
	var r := Artisanat.recette(art, id_recette)
	if r.is_empty():
		return "Recette inconnue"
	var id_artisan := String(r.get("artisan", ""))
	if not Artisanat.artisan_proche(get_tree(), art, id_artisan, joueur.global_position):
		return "Approche-toi de l'artisan (%s)" % Artisanat.artisan(art, id_artisan).get("nom", id_artisan)
	var raison := Artisanat.fabriquer(cat(), art, etat, id_recette)
	if raison == "":
		var donne := String(r["donne"])
		var n := maxi(1, int(r.get("quantite", 1)))
		_dire("Fabriqué : %s%s" % [Objets.objet(cat(), donne).get("nom", donne), " × %d" % n if n > 1 else ""])
	return raison


func _process(_delta: float) -> void:
	if _changement < 0 or not multiplayer.is_server():
		return
	if joueur.bouge() or combat.en_combat() or not combat.est_vivant():
		_changement = -1
		Regles.chez(joueur.id_reseau(), combat_joueur, "_recevoir_incantation", ["", -1.0])
		_dire("Changement de tenue interrompu")
		return
	if Regles.maintenant() >= _fin_changement:
		var numero := _changement
		_changement = -1
		var manquants := Objets.mettre_tenue(cat(), etat, numero)
		if not manquants.is_empty():
			_dire("Introuvable dans tes sacs : " + ", ".join(manquants))
		_appliquer()


## Serveur : ajoute le butin ramassé. Renvoie ce qui n'a pas trouvé de place.
func recevoir(objets: Array) -> Array:
	var restants: Array = []
	for o in objets:
		var reste := Objets.ajouter(cat(), etat, String(o["id"]), int(o["n"]))
		if reste > 0:
			restants.append({"id": o["id"], "n": reste})
	_appliquer()
	return restants


## Serveur : recalcule les bonus, met à jour le combat, la barre et l'apparence,
## enregistre et envoie le nouvel état au joueur.
func _appliquer() -> void:
	_calculer_bonus()
	var base := combat_joueur.pv_de_base()
	var avant := combat.pv_max
	combat.pv_max = base + float(bonus["stats"]["pv"])
	if combat.est_vivant():
		combat.pv = clampf(combat.pv + maxf(0.0, combat.pv_max - avant), 1.0, combat.pv_max)
	combat.bonus_degats = float(bonus["stats"]["degats_pourcent"])
	combat.bonus_reduction = float(bonus["stats"]["reduction_pourcent"])
	combat.bonus_critique = float(bonus["stats"]["critique_pourcent"])
	porte = (etat["equipement"] as Dictionary).duplicate()
	_sauvegarder()
	Regles.chez(joueur.id_reseau(), self, "_recevoir_etat", [etat])
	change.emit()


func _calculer_bonus() -> void:
	bonus = Objets.bonus(cat(), etat.get("equipement", {}))
	combat_joueur.modifs_competences = bonus["competences"]
	combat_joueur.definir_barre(etat.get("barre", []))


func _dire(texte: String) -> void:
	Regles.chez(joueur.id_reseau(), combat_joueur, "_recevoir_message", [texte])


# --- Chez le joueur ------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _recevoir_etat(nouvel_etat: Dictionary) -> void:
	etat = nouvel_etat
	if not multiplayer.is_server():
		_calculer_bonus()
	change.emit()


## Habille le personnage avec ce qu'il porte (visible chez tout le monde).
func _habiller() -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var apparence := joueur.get_node_or_null("Apparence")
	if apparence == null or not apparence.has_method("equiper"):
		return
	apparence.equiper(Objets.visuels(cat(), porte))


# --- Sauvegarde (serveur) ----------------------------------------------------

func _fichier() -> String:
	var cle := joueur.nom.to_lower().validate_filename().replace(" ", "_")
	return Profil.chemin(DOSSIER_SAUVEGARDE + (cle if cle != "" else "agent") + ".json")


func _charger() -> Dictionary:
	var lu = null
	if sauvegarde_active and FileAccess.file_exists(_fichier()):
		lu = JSON.parse_string(FileAccess.get_file_as_string(_fichier()))
	return Objets.valider(cat(), lu, _barre_par_defaut(), Donnees.competences)


func _sauvegarder() -> void:
	if not sauvegarde_active:
		return
	DirAccess.make_dir_recursive_absolute(Profil.chemin(DOSSIER_SAUVEGARDE))
	var f := FileAccess.open(_fichier(), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(etat, "\t"))
