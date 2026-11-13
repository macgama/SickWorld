class_name CombatJoueur
extends Node
## Le combat du joueur : ciblage (Tab, clic), barre de 8 compétences (touches 1 à 8),
## attaque automatique, temps de recharge, incantations, mort et réapparition.
##
## En multijoueur, ce script tourne à deux endroits :
## - chez le joueur : il lit les touches, choisit la cible et AFFICHE l'état
##   (recharges, Élan…) ;
## - sur le serveur : il VÉRIFIE chaque demande (portée, recharge, Élan…)
##   et applique les dégâts. C'est lui qui a le dernier mot.
##
## Les compétences sont décrites dans data/competences.json,
## les classes (compétences 1 à 5, ressource, vie) dans data/classes.json
## et les compétences 6 à 8 par défaut dans data/joueur.json.
##
## La variable « elan » contient la ressource de la classe :
## Élan (Lame), Ténacité (Rempart), Concentration (Traqueur) ou Flux (Tisseur).

signal cible_changee(cible: Combattant)
signal message(texte: String)
signal incantation_changee(nom: String, progression: float)
## La barre a changé (tenue de mission, nouvelle compétence d'époque).
signal barre_changee

const SCENE_LOUP := preload("res://scenes/ennemis/loup.tscn")
const SCRIPT_PIEGE := preload("res://scripts/combat/piege.gd")
const SCRIPT_BULLE := preload("res://scripts/combat/zone_bulle.gd")
const PORTEE_CIBLAGE := 45.0
## Compétences qui visent un ennemi.
const TYPES_OFFENSIFS := ["melee", "distance", "bond", "provocation"]
## Compétences qui visent un allié (ou soi-même si on n'a pas d'allié en cible).
const TYPES_SOUTIEN := ["soin", "retour", "renfort_allie"]
## Vitesse des projectiles (mètres par seconde).
const VITESSES_PROJECTILES := {"sagaie": 35.0, "fleche": 55.0, "poison": 55.0, "eclat": 32.0}
## Pièges posés en même temps au maximum par un Traqueur.
const PIEGES_MAX := 2

var cible: Combattant = null
var barre: Array[String] = []
## id de compétence -> moment où elle sera de nouveau disponible
var recharges := {}
var fin_recharge_globale := 0.0
## Élan : calculé par le serveur et envoyé au joueur (nœud Synchro).
var elan := 0.0
var elan_max := 100.0
var attaque_auto := false
## Bonus de l'équipement sur les compétences (ensembles, reliques), remplis par l'Inventaire :
## id de compétence -> { clé: valeur ajoutée }.
var modifs_competences := {}

var _reglages: Dictionary
## Réglages de la classe du personnage (voir data/classes.json).
var _classe: Dictionary = {}
var _classe_appliquee := ""
var _pieges: Array = []
var _compteur_pieges := 0
var _prochaine_attaque_auto := 0.0
# Incantation (serveur)
var _incantation_id := ""
var _incantation_fin := 0.0
var _incantation_cible: Combattant = null
# Incantation (affichage chez le joueur)
var _barre_nom := ""
var _barre_debut := 0.0
var _barre_fin := 0.0
# Bond en cours (serveur)
var _bond_competence := ""
var _bond_cible: Combattant = null
var _bond_limite := 0.0
var _compteur_invocations := 0
var _anneau: MeshInstance3D

@onready var joueur: Joueur = get_parent()
@onready var combat: Combattant = get_parent().get_node("Combat")


func _ready() -> void:
	_reglages = Donnees.joueur
	combat.niveau = int(_reglages.get("niveau", 1))
	combat.faction = "joueur"
	combat.hauteur_centre = 1.1
	_appliquer_classe()
	for id in barre_par_defaut():
		barre.append(String(id))
	if multiplayer.is_server():
		combat.pv_max = pv_de_base()
		combat.pv = combat.pv_max
		elan = float(ressource().get("depart", 0))
		combat.nom_affiche = joueur.nom
		combat.mort.connect(_sur_mort)
		combat.degats_recus.connect(_sur_degats_recus)
	joueur.get_node("Fiche").changee.connect(_sur_fiche_changee)
	if joueur.est_local():
		(joueur.get_node("CameraRig") as CameraJoueur).clic_simple.connect(_sur_clic)
		_creer_anneau()
	else:
		set_process_unhandled_input(false)


# --- Classe et ressource -------------------------------------------------------

## Identifiant de la classe du personnage ("lame", "rempart", "traqueur" ou "tisseur").
func classe_id() -> String:
	var id := String(joueur.get_node("Fiche").donnees.get("classe", "lame"))
	return id if Donnees.classes.has(id) else "lame"


func _appliquer_classe() -> void:
	_classe_appliquee = classe_id()
	_classe = Donnees.classe(_classe_appliquee)
	elan_max = float(ressource().get("max", _reglages.get("elan_max", 100)))
	combat.facteur_menace = float(_classe.get("facteur_menace", 1.0))


## La fiche a changé (le serveur l'a vérifiée) : on reprend la classe.
func _sur_fiche_changee() -> void:
	if _classe_appliquee == classe_id():
		return
	_appliquer_classe()
	definir_barre(barre)
	if multiplayer.is_server():
		elan = float(ressource().get("depart", 0))
		var inventaire := joueur.get_node_or_null("Inventaire")
		if inventaire != null and inventaire.is_node_ready() and inventaire.has_method("_appliquer"):
			inventaire._appliquer()


## Réglages de la ressource : nom, couleur, max, depart, regeneration, perte_hors_combat, gain_par_degat_subi.
func ressource() -> Dictionary:
	var r = _classe.get("ressource")
	if r is Dictionary:
		return r
	return {"nom": "Élan", "max": _reglages.get("elan_max", 100),
			"perte_hors_combat": _reglages.get("perte_elan_hors_combat", 5)}


func nom_ressource() -> String:
	return String(ressource().get("nom", "Élan"))


## Vie de base de la classe (avant l'équipement).
func pv_de_base() -> float:
	return float(_classe.get("points_de_vie", _reglages.get("points_de_vie", 200)))


## La barre par défaut : 5 compétences de la classe + époque et ultime de joueur.json.
func barre_par_defaut() -> Array:
	var liste: Array = []
	var de_la_classe: Array = _classe.get("competences", [])
	var generale: Array = _reglages.get("barre", [])
	for i in 8:
		if i < 5 and i < de_la_classe.size():
			liste.append(String(de_la_classe[i]))
		elif i < generale.size():
			liste.append(String(generale[i]))
		else:
			liste.append("")
	return liste


func _attaque_auto() -> Dictionary:
	var a = _classe.get("attaque_automatique")
	return a if a is Dictionary else _reglages.get("attaque_automatique", {})


## Coût et gain de ressource d'une compétence (les anciens noms cout_elan / gain_elan marchent aussi).
static func cout(c: Dictionary) -> float:
	return float(c.get("cout", c.get("cout_elan", 0)))


static func gain(c: Dictionary) -> float:
	return float(c.get("gain", c.get("gain_elan", 0)))


## « Pas assez d'Élan », « Pas assez de Flux »…
func texte_pas_assez() -> String:
	var nom := nom_ressource()
	var voyelle := nom.left(1).to_lower() in ["a", "e", "é", "è", "i", "o", "u", "y", "h"]
	return "Pas assez d'" + nom if voyelle else "Pas assez de " + nom


## La cible d'une compétence de soutien : l'allié ciblé, sinon soi-même.
func cible_de_soutien() -> Combattant:
	if cible != null and is_instance_valid(cible) and cible.est_vivant() and not combat.est_hostile(cible):
		return cible
	return combat


func _est_le_proprietaire() -> bool:
	return Regles.expediteur() == joueur.id_reseau()


# --- Commandes (chez le joueur) ---------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cible_suivante"):
		cibler_suivant()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("annuler"):
		# Échap annule l'incantation, sinon enlève la cible ; sans cible,
		# il laisse passer la touche pour ouvrir le menu de jeu.
		if _barre_nom != "":
			Regles.au_serveur(self, "_demander_annulation")
			get_viewport().set_input_as_handled()
		elif cible != null:
			changer_cible(null)
			get_viewport().set_input_as_handled()
	else:
		for i in 8:
			if event.is_action_pressed("competence_%d" % (i + 1)):
				utiliser(i)
				get_viewport().set_input_as_handled()
				return


func _sur_clic(bouton: int, position_ecran: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var origine := camera.project_ray_origin(position_ecran)
	var fin := origine + camera.project_ray_normal(position_ecran) * 200.0
	var requete := PhysicsRayQueryParameters3D.create(origine, fin,
			Regles.COUCHE_MONDE | Regles.COUCHE_PERSONNAGES, [joueur.get_rid()])
	var touche := joueur.get_world_3d().direct_space_state.intersect_ray(requete)
	if touche.is_empty():
		return
	var c := (touche.collider as Node).get_node_or_null("Combat") as Combattant
	if c != null and c.est_vivant():
		# Clic droit sur un ennemi : on l'attaque, comme dans WoW.
		changer_cible(c, bouton == MOUSE_BUTTON_RIGHT and combat.est_hostile(c))


func changer_cible(nouvelle: Combattant, attaquer := false) -> void:
	if nouvelle == cible and not attaquer:
		return
	cible = nouvelle
	cible_changee.emit(cible)
	var chemin := cible.get_path() if cible != null else NodePath()
	Regles.au_serveur(self, "_choisir_cible", [chemin, attaquer])


## Touche Tab : passe à l'ennemi suivant, en commençant par les plus proches devant la caméra.
func cibler_suivant() -> void:
	var camera := get_viewport().get_camera_3d()
	var candidats: Array = []
	for c in Regles.hostiles_autour(combat, joueur.global_position, PORTEE_CIBLAGE):
		if camera != null and camera.is_position_behind(c.centre()):
			continue
		if not Regles.ligne_de_vue(combat, c):
			continue
		candidats.append(c)
	if candidats.is_empty():
		message.emit("Aucun ennemi en vue")
		return
	candidats.sort_custom(func(a, b): return Regles.distance(combat, a) < Regles.distance(combat, b))
	var index := candidats.find(cible)
	changer_cible(candidats[(index + 1) % candidats.size()])


## Touches 1 à 8 : on vérifie d'abord chez soi (pour répondre tout de suite),
## puis on demande au serveur, qui vérifie à nouveau.
func utiliser(index: int) -> bool:
	var raison := raison_impossible(index)
	if raison != "":
		message.emit(raison)
		return false
	Regles.au_serveur(self, "_demander_competence", [index])
	return true


func reapparaitre() -> void:
	Regles.au_serveur(self, "_demander_reapparition")


# --- Informations (partout) ---------------------------------------------------

func competence(index: int) -> Dictionary:
	if index < 0 or index >= barre.size():
		return {}
	return competence_par_id(barre[index])


## La compétence avec les bonus de l'équipement porté.
func competence_par_id(id: String) -> Dictionary:
	return Objets.competence_modifiee(Donnees.competence(id), modifs_competences.get(id, {}))


## Remplace la barre (appelé par l'Inventaire, sur le serveur et chez le joueur).
## Les cases 1 à 5 restent toujours celles de la classe.
func definir_barre(liste: Array) -> void:
	var nouvelle: Array[String] = []
	var defaut := barre_par_defaut()
	for i in maxi(liste.size(), 8):
		var id := String(liste[i]) if i < liste.size() else String(defaut[i])
		nouvelle.append(String(defaut[i]) if i < 5 else id)
	if nouvelle.is_empty() or nouvelle == barre:
		barre_changee.emit()
		return
	barre = nouvelle
	barre_changee.emit()


## Temps restant avant de pouvoir réutiliser la compétence (secondes), et durée totale.
func recharge_restante(index: int) -> Vector2:
	if index >= barre.size():
		return Vector2.ZERO
	var t := Regles.maintenant()
	var propre := maxf(0.0, float(recharges.get(barre[index], 0.0)) - t)
	var globale := maxf(0.0, fin_recharge_globale - t)
	var duree := float(competence(index).get("recharge", 0.0))
	if propre >= globale:
		return Vector2(propre, duree)
	return Vector2(globale, float(_reglages.get("temps_de_recharge_global", 1.0)))


## Renvoie "" si la compétence peut être lancée maintenant, sinon la raison.
func raison_impossible(index: int) -> String:
	var c := competence(index)
	if c.is_empty():
		return "Emplacement vide"
	if not combat.est_vivant():
		return "Tu es désynchronisé"
	if _incantation_id != "" or _barre_nom != "":
		return "Déjà en train de préparer une compétence"
	if recharge_restante(index).x > 0.05:
		return "Pas encore prêt"
	if elan < cout(c):
		return texte_pas_assez()
	var type := String(c.get("type", ""))
	if type in TYPES_OFFENSIFS:
		if cible == null or not is_instance_valid(cible) or not cible.est_vivant():
			return "Pas de cible"
		if not combat.est_hostile(cible):
			return "Cible invalide"
		var raison := _raison_distance(c, cible)
		if raison != "":
			return raison
		if c.has("pv_cible_max_pourcent") and cible.pourcentage_pv() > float(c["pv_cible_max_pourcent"]):
			return "La cible a encore trop de vie"
	elif type == "interception":
		if cible == null or not is_instance_valid(cible) or not cible.est_vivant() \
				or combat.est_hostile(cible) or cible == combat:
			return "Cible un allié"
		return _raison_distance(c, cible)
	elif type in TYPES_SOUTIEN:
		var allie := cible_de_soutien()
		if allie != combat:
			return _raison_distance(c, allie)
	elif type == "bulle":
		if cible != null and is_instance_valid(cible) and cible.est_vivant() and combat.est_hostile(cible):
			return _raison_distance(c, cible)
	return ""


func _raison_distance(c: Dictionary, autre: Combattant) -> String:
	var d := Regles.distance(combat, autre)
	# Le serveur accepte un peu plus de distance : les positions arrivent avec un léger retard.
	var marge := 1.5 if multiplayer.is_server() and not joueur.est_local() else 0.0
	if d > float(c.get("portee", 3.5)) + marge:
		return "Hors de portée"
	if d < float(c.get("portee_min", 0.0)) - marge:
		return "Trop près"
	if not Regles.ligne_de_vue(combat, autre):
		return "Cible non visible"
	return ""


## La cible d'une compétence au moment où on la lance.
func _cible_pour(c: Dictionary) -> Combattant:
	var type := String(c.get("type", ""))
	if type in TYPES_SOUTIEN:
		return cible_de_soutien()
	return cible


# --- Demandes reçues par le serveur -----------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _choisir_cible(chemin: NodePath, attaquer: bool) -> void:
	if not multiplayer.is_server() or not _est_le_proprietaire():
		return
	var nouvelle := get_node_or_null(chemin) as Combattant if not chemin.is_empty() else null
	if nouvelle != cible:
		attaque_auto = false
	cible = nouvelle
	if attaquer and cible != null and combat.est_hostile(cible):
		attaque_auto = true


@rpc("any_peer", "call_remote", "reliable")
func _demander_competence(index: int) -> void:
	if not multiplayer.is_server() or not _est_le_proprietaire():
		return
	var raison := raison_impossible(index)
	if raison != "":
		Regles.chez(joueur.id_reseau(), self, "_recevoir_message", [raison])
		return
	var c := competence(index)
	var gcd := float(_reglages.get("temps_de_recharge_global", 1.0))
	fin_recharge_globale = Regles.maintenant() + gcd
	Regles.chez(joueur.id_reseau(), self, "_recevoir_recharge", ["", 0.0, gcd])
	var incantation := float(c.get("incantation", 0.0))
	if incantation > 0.0:
		_incantation_id = barre[index]
		_incantation_cible = _cible_pour(c)
		_incantation_fin = Regles.maintenant() + incantation
		Regles.chez(joueur.id_reseau(), self, "_recevoir_incantation", [String(c.get("nom", "")), incantation])
		return
	_executer(barre[index])


@rpc("any_peer", "call_remote", "reliable")
func _demander_annulation() -> void:
	if multiplayer.is_server() and _est_le_proprietaire() and _incantation_id != "":
		_interrompre("Annulé")


@rpc("any_peer", "call_remote", "reliable")
func _demander_reapparition() -> void:
	if not multiplayer.is_server() or not _est_le_proprietaire() or combat.est_vivant():
		return
	var balise := get_tree().get_first_node_in_group("balises") as Node3D
	var p := joueur.global_position
	if balise != null and balise.has_method("point_de_reapparition"):
		p = balise.point_de_reapparition()
	combat.reanimer(100.0)
	elan = float(ressource().get("depart", 0))
	var penalite: Dictionary = _reglages.get("penalite_reapparition", {})
	var reduction := float(penalite.get("reduction_degats_pourcent", 10)) / 100.0
	combat.ajouter_effet("desynchronisation", float(penalite.get("duree", 120)),
			{"degats_infliges": 1.0 - reduction})
	Regles.chez(joueur.id_reseau(), joueur, "teleporter", [p, joueur.rotation.y])


@rpc("any_peer", "call_remote", "reliable")
func _bond_arrive() -> void:
	if not multiplayer.is_server() or not _est_le_proprietaire() or _bond_competence == "":
		return
	var c := competence_par_id(_bond_competence)
	_bond_competence = ""
	if is_instance_valid(_bond_cible) and Regles.distance(combat, _bond_cible) <= 4.5:
		_toucher(_bond_cible, c)


# --- Exécution (serveur) -----------------------------------------------------

func _executer(id: String, cible_choisie: Combattant = null) -> void:
	var c := competence_par_id(id)
	var visee := cible_choisie if cible_choisie != null else _cible_pour(c)
	var recharge := float(c.get("recharge", 0.0))
	recharges[id] = Regles.maintenant() + recharge
	Regles.chez(joueur.id_reseau(), self, "_recevoir_recharge", [id, recharge, 0.0])
	elan = clampf(elan - cout(c) + gain(c), 0.0, elan_max)
	combat.noter_combat()
	_animer_attaque.rpc()
	var couleur := Color.html(String(c.get("couleur", "#ffffff")))

	match String(c.get("type", "")):
		"melee":
			_toucher(visee, c)
			_effet.rpc("impact", visee.get_path(), Vector3.ZERO, couleur, 0.8)
			attaque_auto = true
		"bond":
			_bond_competence = id
			_bond_cible = visee
			_bond_limite = Regles.maintenant() + 2.0
			attaque_auto = true
			Regles.chez(joueur.id_reseau(), self, "_recevoir_bond", [visee.get_path(), true])
		"distance":
			_tirer(visee, c, String(c.get("projectile", "sagaie")))
			if float(_attaque_auto().get("portee", 3.5)) > 5.0:
				attaque_auto = true
		"zone_autour":
			for ennemi in Regles.hostiles_autour(combat, joueur.global_position, float(c.get("rayon", 5))):
				_toucher(ennemi, c)
			_effet.rpc("onde", NodePath(), joueur.global_position, couleur, float(c.get("rayon", 5)))
		"zone_au_sol":
			var zone := ZoneDeFeu.new()
			zone.lanceur = combat
			zone.reglages = c
			get_tree().current_scene.add_child(zone)
			zone.global_position = joueur.global_position
			_effet_feu.rpc(joueur.global_position, c)
		"invocation":
			_invoquer(c)
		"renfort":
			# Cri du clan (alliés autour), Peinture de guerre ou Mur de bouclier (soi-même).
			var cibles: Array[Combattant] = [combat]
			if float(c.get("rayon", 0)) > 0.0:
				cibles = Regles.allies_autour(combat, joueur.global_position, float(c["rayon"]))
				_effet.rpc("onde", NodePath(), joueur.global_position, couleur, float(c["rayon"]))
			var effet := {}
			for cle in ["degats_infliges", "reduction_degats_subis"]:
				if c.has(cle):
					effet[cle] = float(c[cle])
			for allie in cibles:
				allie.ajouter_effet(String(c.get("effet", id)), float(c.get("duree", 8)), effet, combat)
				_effet.rpc("aura", allie.get_path(), Vector3.ZERO, couleur, float(c.get("duree", 8)))
		"provocation":
			_provoquer(visee, float(c.get("duree", 4)))
			_effet.rpc("impact", visee.get_path(), Vector3.ZERO, couleur, 1.2)
			attaque_auto = true
		"interception":
			# Charge protectrice : on bondit vers l'allié et on encaisse son prochain coup.
			visee.ajouter_effet("protection", float(c.get("duree", 8)), {}, combat)
			_effet.rpc("aura", visee.get_path(), Vector3.ZERO, couleur, float(c.get("duree", 8)))
			if Regles.distance(combat, visee) > 3.0:
				Regles.chez(joueur.id_reseau(), self, "_recevoir_bond", [visee.get_path(), false])
		"piege":
			_poser_piege(c)
		"repli":
			var r: Dictionary = c.get("ralenti", {})
			for ennemi in Regles.hostiles_autour(combat, joueur.global_position, float(c.get("rayon", 8))):
				ennemi.ajouter_effet("ralenti", float(r.get("duree", 4)), {"vitesse": float(r.get("facteur", 0.5))}, combat)
			_effet.rpc("onde", NodePath(), joueur.global_position, couleur, float(c.get("rayon", 8)))
			Regles.chez(joueur.id_reseau(), joueur, "sauter_en_arriere", [float(c.get("distance", 10))])
		"soin":
			Regles.soigner(combat, visee, Donnees.entre(c.get("soin", [0, 0])))
			_effet.rpc("soin", visee.get_path(), Vector3.ZERO, couleur, 1.0)
		"retour":
			# Retour en arrière : la vie d'il y a quelques secondes (au moins un petit soin).
			var passe := visee.pv_il_y_a(float(c.get("secondes", 5)))
			var minimum := visee.pv + visee.pv_max * float(c.get("soin_minimum_pourcent", 0)) / 100.0
			Regles.soigner(combat, visee, maxf(passe, minimum) - visee.pv)
			_effet.rpc("retour", visee.get_path(), Vector3.ZERO, couleur, 1.0)
		"bulle":
			var centre := joueur.global_position
			if visee != null and is_instance_valid(visee) and visee.est_vivant() and combat.est_hostile(visee):
				centre = visee.acteur().global_position
			var bulle: Node3D = SCRIPT_BULLE.new()
			bulle.lanceur = combat
			bulle.reglages = c
			get_tree().current_scene.add_child(bulle)
			bulle.global_position = centre
			_effet_bulle.rpc(centre, c)
		"renfort_allie":
			var effet := {}
			for cle in ["vitesse", "soin_par_seconde", "degats_infliges", "reduction_degats_subis"]:
				if c.has(cle):
					effet[cle] = float(c[cle])
			visee.ajouter_effet(String(c.get("effet", id)), float(c.get("duree", 8)), effet, combat)
			_effet.rpc("trainee", visee.get_path(), Vector3.ZERO, couleur, float(c.get("duree", 8)))


## Projectile (sagaie, flèche, éclat…) : les dégâts tombent quand il arrive.
func _tirer(victime: Combattant, c: Dictionary, style: String) -> void:
	var vitesse := float(VITESSES_PROJECTILES.get(style, 35.0))
	var duree := maxf(0.12, combat.centre().distance_to(victime.centre()) / vitesse)
	_effet_projectile.rpc(victime.get_path(), duree, style)
	get_tree().create_timer(duree).timeout.connect(func(): _toucher(victime, c))


func _provoquer(victime: Combattant, duree: float) -> void:
	victime.ajouter_effet("provocation", duree, {}, combat)
	# On passe devant tout le monde dans sa liste de menace.
	var plus_haute := 0.0
	for autre in victime.menace:
		plus_haute = maxf(plus_haute, float(victime.menace[autre]))
	victime.menace[combat] = plus_haute * 1.1 + 20.0
	victime.noter_combat()
	combat.noter_combat()
	if victime.acteur().has_method("provoquer"):
		victime.acteur().provoquer(combat)


func _poser_piege(c: Dictionary) -> void:
	_pieges = _pieges.filter(func(p): return is_instance_valid(p))
	while _pieges.size() >= PIEGES_MAX:
		_pieges.pop_front().queue_free()
	_compteur_pieges += 1
	var piege: Node3D = SCRIPT_PIEGE.new()
	piege.name = "Piege_%d_%d" % [joueur.id_reseau(), _compteur_pieges]
	piege.lanceur = combat
	piege.reglages = c
	piege.combat_joueur = self
	get_tree().current_scene.add_child(piege)
	piege.global_position = joueur.global_position
	_pieges.append(piege)
	_effet_piege.rpc(String(piege.name), joueur.global_position, c)


## Un piège s'est refermé (appelé par le piège, sur le serveur).
func piege_declenche(piege: Node3D, victime: Combattant) -> void:
	_effet.rpc("liens", victime.get_path(), Vector3.ZERO, Color.WHITE, float(piege.reglages.get("immobilise", 5)))
	_retirer_piege.rpc(String(piege.name))


func _toucher(victime: Combattant, c: Dictionary) -> void:
	if victime == null or not is_instance_valid(victime) or not victime.est_vivant():
		return
	var subi := Regles.infliger(combat, victime, Donnees.entre(c.get("degats", [0, 0])))
	if c.has("menace") and subi > 0.0:
		victime.menace[combat] = float(victime.menace.get(combat, 0.0)) \
				+ subi * combat.facteur_menace * (float(c["menace"]) - 1.0)
	if c.has("saignement") and victime.est_vivant():
		var s: Dictionary = c["saignement"]
		victime.ajouter_effet("saignement", float(s["duree"]),
				{"degats_par_seconde": float(s["degats_par_seconde"])}, combat)
	if c.has("poison") and victime.est_vivant():
		var p: Dictionary = c["poison"]
		victime.ajouter_effet("poison", float(p["duree"]),
				{"degats_par_seconde": float(p["degats_par_seconde"])}, combat)
	if c.has("ralenti") and victime.est_vivant():
		var r: Dictionary = c["ralenti"]
		victime.ajouter_effet("ralenti", float(r["duree"]), {"vitesse": float(r["facteur"])}, combat)
	if c.has("etourdit") and victime.est_vivant():
		var duree := victime.ajouter_controle("etourdi", float(c["etourdit"]), combat)
		if duree > 0.0:
			_effet.rpc("etoiles", victime.get_path(), Vector3.ZERO, Color.WHITE, duree)


func _invoquer(c: Dictionary) -> void:
	var dossier := get_tree().get_first_node_in_group("dossier_loups")
	if dossier == null:
		return
	for i in int(c.get("nombre", 2)):
		_compteur_invocations += 1
		var loup: Loup = SCENE_LOUP.instantiate()
		loup.name = "Meute_%d_%d" % [joueur.id_reseau(), _compteur_invocations]
		loup.type_ennemi = "loup_allie"
		loup.faction = "joueur"
		loup.maitre = joueur
		loup.fin_invocation = Regles.maintenant() + float(c.get("duree", 20))
		var cote := -1.0 if i == 0 else 1.0
		loup.position = joueur.global_position + joueur.global_transform.basis.x * cote * 1.5 + Vector3.UP * 0.5
		dossier.add_child(loup)
		loup.camp = loup.global_position


func _interrompre(texte: String) -> void:
	_incantation_id = ""
	_incantation_cible = null
	fin_recharge_globale = 0.0
	Regles.chez(joueur.id_reseau(), self, "_recevoir_incantation", ["", -1.0])
	Regles.chez(joueur.id_reseau(), self, "_recevoir_recharge", ["", 0.0, 0.0])
	Regles.chez(joueur.id_reseau(), self, "_recevoir_message", [texte])


func _sur_mort(_tueur: Combattant) -> void:
	if _incantation_id != "":
		_interrompre("Interrompu")
	cible = null
	attaque_auto = false
	elan = 0.0


## Rempart : chaque coup reçu remplit la Ténacité.
func _sur_degats_recus(montant: float, _source: Combattant) -> void:
	var par_point := float(ressource().get("gain_par_degat_subi", 0.0))
	if par_point > 0.0 and combat.est_vivant():
		elan = minf(elan_max, elan + montant * par_point)


# --- Messages reçus par le joueur --------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _recevoir_message(texte: String) -> void:
	message.emit(texte)


## id vide = temps de recharge global.
@rpc("authority", "call_remote", "reliable")
func _recevoir_recharge(id: String, duree: float, globale: float) -> void:
	var t := Regles.maintenant()
	if id != "":
		recharges[id] = t + duree
	if id == "" or globale > 0.0:
		fin_recharge_globale = t + globale


@rpc("authority", "call_remote", "reliable")
func _recevoir_incantation(nom: String, duree: float) -> void:
	_barre_nom = nom if duree > 0.0 else ""
	_barre_debut = Regles.maintenant()
	_barre_fin = _barre_debut + maxf(duree, 0.0)
	if _barre_nom == "":
		incantation_changee.emit("", -1.0)


## Bond de la Lame (frapper = vrai) ou Charge protectrice du Rempart vers un allié.
@rpc("authority", "call_remote", "reliable")
func _recevoir_bond(chemin_cible: NodePath, frapper: bool) -> void:
	var c := get_node_or_null(chemin_cible) as Combattant
	if c == null:
		return
	if frapper:
		joueur.bondir_vers(c.acteur(), func(): Regles.au_serveur(self, "_bond_arrive"))
	else:
		joueur.bondir_vers(c.acteur(), Callable())


# --- Effets visibles par tous ------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _animer_attaque() -> void:
	if joueur.apparence.has_method("attaquer"):
		joueur.apparence.attaquer()


@rpc("authority", "call_local", "reliable")
func _effet_projectile(chemin_cible: NodePath, duree: float, style: String) -> void:
	var victime := get_node_or_null(chemin_cible) as Combattant
	if victime == null:
		return
	EffetsVisuels.projectile(self, combat.centre() + Vector3.UP * 0.4, victime.acteur(),
			victime.hauteur_centre, duree, style)


## Effets visuels courts, vus par tous les joueurs.
@rpc("authority", "call_local", "unreliable")
func _effet(type: String, chemin: NodePath, position_monde: Vector3, couleur: Color, valeur: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var c := get_node_or_null(chemin) as Combattant if not chemin.is_empty() else null
	var acteur := c.acteur() if c != null else null
	match type:
		"impact":
			if c != null:
				EffetsVisuels.impact(self, c.centre(), couleur, valeur)
		"onde":
			EffetsVisuels.onde(self, position_monde, valeur, couleur)
		"aura":
			EffetsVisuels.aura(self, acteur, couleur, valeur)
		"soin":
			EffetsVisuels.soin(self, acteur, couleur)
		"retour":
			EffetsVisuels.soin(self, acteur, couleur)
			if c != null:
				EffetsVisuels.onde(self, acteur.global_position, 2.0, couleur)
		"etoiles":
			if c != null:
				EffetsVisuels.etoiles(self, acteur, c.hauteur_centre * 2.0 + 0.3, valeur)
		"liens":
			EffetsVisuels.liens(self, acteur, valeur)
		"trainee":
			EffetsVisuels.trainee(self, acteur, couleur, valeur)


## Copies visuelles (chez les joueurs) des pièges et des bulles qui existent sur le serveur.
@rpc("authority", "call_remote", "reliable")
func _effet_piege(nom: String, position_monde: Vector3, reglages: Dictionary) -> void:
	var piege: Node3D = SCRIPT_PIEGE.new()
	piege.name = nom
	piege.reglages = reglages
	get_tree().current_scene.add_child(piege)
	piege.global_position = position_monde


@rpc("authority", "call_local", "reliable")
func _retirer_piege(nom: String) -> void:
	for piege in get_tree().get_nodes_in_group("pieges"):
		if piege.name == nom:
			piege.refermer()


@rpc("authority", "call_remote", "reliable")
func _effet_bulle(position_monde: Vector3, reglages: Dictionary) -> void:
	var bulle: Node3D = SCRIPT_BULLE.new()
	bulle.reglages = reglages
	get_tree().current_scene.add_child(bulle)
	bulle.global_position = position_monde


## Le feu « pour de vrai » existe sur le serveur ; les joueurs reçoivent une copie juste visuelle.
@rpc("authority", "call_remote", "reliable")
func _effet_feu(position_monde: Vector3, reglages: Dictionary) -> void:
	var zone := ZoneDeFeu.new()
	zone.reglages = reglages
	get_tree().current_scene.add_child(zone)
	zone.global_position = position_monde


# --- Boucle ----------------------------------------------------------------

func _process(delta: float) -> void:
	var t := Regles.maintenant()

	# Chez le joueur : cible disparue, barre de préparation.
	if joueur.est_local():
		if cible != null and (not is_instance_valid(cible) or not cible.est_vivant()):
			cible = null
			cible_changee.emit(null)
		if _barre_nom != "":
			if t >= _barre_fin:
				_barre_nom = ""
				incantation_changee.emit("", -1.0)
			else:
				incantation_changee.emit(_barre_nom, (t - _barre_debut) / maxf(0.01, _barre_fin - _barre_debut))
		_mettre_a_jour_anneau()

	if multiplayer.is_server():
		_logique_serveur(delta, t)


func _logique_serveur(delta: float, t: float) -> void:
	if cible != null and (not is_instance_valid(cible) or not cible.est_vivant()):
		cible = null
		attaque_auto = false

	# Incantation en cours.
	if _incantation_id != "":
		var c := competence_par_id(_incantation_id)
		if joueur.bouge() or not combat.est_vivant():
			_interrompre("Interrompu")
		elif _incantation_cible == null or not is_instance_valid(_incantation_cible) \
				or not _incantation_cible.est_vivant():
			_interrompre("Cible perdue")
		elif t >= _incantation_fin:
			var id := _incantation_id
			var visee := _incantation_cible
			_incantation_id = ""
			_incantation_cible = null
			if Regles.distance(combat, visee) <= float(c.get("portee", 30)) + 2.0:
				_executer(id, visee)
			else:
				Regles.chez(joueur.id_reseau(), self, "_recevoir_message", ["Hors de portée"])

	if _bond_competence != "" and t > _bond_limite:
		_bond_competence = ""

	# Attaque automatique (au corps à corps, ou à distance pour le Traqueur et le Tisseur).
	var auto := _attaque_auto()
	if attaque_auto and cible != null and combat.est_vivant() and t >= _prochaine_attaque_auto \
			and _incantation_id == "" and combat.est_hostile(cible) \
			and Regles.distance(combat, cible) <= float(auto.get("portee", 3.5)) + 1.0:
		_prochaine_attaque_auto = t + float(auto.get("intervalle", 2.0))
		if auto.has("projectile"):
			if Regles.ligne_de_vue(combat, cible):
				_tirer(cible, {"degats": auto.get("degats", [5, 8])}, String(auto["projectile"]))
		else:
			Regles.infliger(combat, cible, Donnees.entre(auto.get("degats", [5, 8])))
		elan = minf(elan_max, elan + gain(auto))
		_animer_attaque.rpc()

	# Ressource qui se remplit toute seule (Concentration, Flux).
	if combat.est_vivant():
		elan = minf(elan_max, elan + float(ressource().get("regeneration", 0.0)) * delta)

	# Hors combat : la vie remonte, l'Élan et la Ténacité redescendent.
	if combat.est_vivant() and not combat.en_combat():
		var regen := float(_reglages.get("regeneration_hors_combat_pourcent", 4)) / 100.0
		regen *= 1.0 + FichePersonnage.bonus(joueur.fiche.donnees, Donnees.creation,
				"regeneration_hors_combat_pourcent") / 100.0
		if combat.pv < combat.pv_max:
			combat.soigner(combat.pv_max * regen * delta)
		elan = maxf(0.0, elan - float(ressource().get("perte_hors_combat", 0.0)) * delta)


# --- Anneau de sélection sous la cible -------------------------------------

func _creer_anneau() -> void:
	_anneau = MeshInstance3D.new()
	var tore := TorusMesh.new()
	tore.inner_radius = 0.7
	tore.outer_radius = 0.8
	tore.rings = 32
	_anneau.mesh = tore
	_anneau.scale = Vector3(1, 0.05, 1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0.25, 0.2)
	_anneau.material_override = mat
	_anneau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_anneau.top_level = true
	_anneau.visible = false
	add_child.call_deferred(_anneau)


func _mettre_a_jour_anneau() -> void:
	if _anneau == null or not _anneau.is_inside_tree():
		return
	_anneau.visible = cible != null
	if cible != null:
		var mat := _anneau.material_override as StandardMaterial3D
		mat.albedo_color = Color(1, 0.25, 0.2) if combat.est_hostile(cible) else Color(0.3, 1, 0.4)
		_anneau.global_position = cible.acteur().get_global_transform_interpolated().origin + Vector3.UP * 0.05
