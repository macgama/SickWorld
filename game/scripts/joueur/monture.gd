extends Node3D
## Monture du joueur : touche V pour appeler sa monture, V à nouveau pour descendre.
##
## Règles (façon WoW) :
## - il faut être immobile, vivant et hors combat ; l'appel dure 1,5 s (bouger l'annule) ;
## - pas de monture en ville (Hikari Bay) ni dans les donjons ;
## - chaque île a sa monture d'époque (data/montures.json) : renne en Préhistoire,
##   âne de bât en Égypte ;
## - une attaque reçue, une compétence lancée ou la mort font descendre de monture.
##
## C'est le serveur qui décide (il connaît le combat) ; la propriété « monture »
## est recopiée chez tous les joueurs par le nœud « Synchro », et chacun affiche
## la bête sous le personnage.

const ApparenceMonture := preload("res://scripts/joueur/apparence_monture.gd")
const PoseCavalier := preload("res://scripts/joueur/pose_cavalier.gd")
const FICHIER := "res://data/montures.json"
## Hauteur ajoutée à la caméra une fois en selle (mètres).
const CAMERA_EN_SELLE := 0.9

signal changee(id: String)

## Monture sur laquelle on est assis ("" = à pied). Décidée par le serveur.
var monture := "":
	set(valeur):
		if valeur == monture:
			return
		monture = valeur
		if is_inside_tree():
			_afficher()
		changee.emit(monture)

static var _donnees := {}

@onready var joueur: Node3D = get_parent()
@onready var combat: Node = get_parent().get_node("Combat")
@onready var combat_joueur: Node = get_parent().get_node("CombatJoueur")

var _bete: Node3D
var _pose: SkeletonModifier3D
var _squelette_pose: Skeleton3D
var _hauteur_camera := -1.0
# Serveur : appel en cours.
var _appel_id := ""
var _appel_fin := 0.0
var _pas_avant := 0.0


func _enter_tree() -> void:
	# Comme le combat, la monture appartient au serveur.
	set_multiplayer_authority(1, true)


func _ready() -> void:
	if multiplayer.is_server():
		combat.degats_recus.connect(func(montant: float, _source): if montant > 0.0: descendre("Tu es tombé de ta monture !"))
		combat.mort.connect(func(_tueur): descendre(""))
	if monture != "":
		_afficher()


# --- Données -----------------------------------------------------------------

static func donnees() -> Dictionary:
	if _donnees.is_empty():
		var lu = JSON.parse_string(FileAccess.get_file_as_string(FICHIER))
		_donnees = lu if lu is Dictionary else {"montures": {}, "reglages": {}}
	return _donnees


static func reglage(nom: String, defaut: float) -> float:
	return float(donnees().get("reglages", {}).get(nom, defaut))


static func fiche(id: String) -> Dictionary:
	return donnees().get("montures", {}).get(id, {})


## Le lieu où l'on est : "ville", "donjon", ou l'époque de l'île (« prehistoire »…).
static func lieu(arbre: SceneTree) -> String:
	var ile := arbre.get_first_node_in_group("ile")
	if ile == null:
		return "ville"
	if ile.is_in_group("donjon") or ile.get("montures_autorisees") == false:
		return "donjon"
	var zone := String(ile.get("identifiant_zone"))
	if zone == "grotte" or zone.contains("donjon") or zone.contains("coeur"):
		return "donjon"
	var chemin: String = ile.get_script().resource_path if ile.get_script() != null else ""
	for id in donnees().get("montures", {}):
		var epoque := String(fiche(id).get("epoque", ""))
		if epoque != "" and chemin.contains("/" + epoque + "/"):
			return epoque
	return "ile"


## La monture de l'époque où l'on se trouve ("" s'il n'y en a pas ici).
static func monture_du_lieu(arbre: SceneTree) -> String:
	var ici := lieu(arbre)
	for id in donnees().get("montures", {}):
		# « actif » : false = monture mise de côté (le renne, remplacé par le cheval).
		if String(fiche(id).get("epoque", "")) == ici and bool(fiche(id).get("actif", true)):
			return id
	return ""


## L'objet est-il dans les sacs du joueur (ou porté) ?
func _possede(id: String) -> bool:
	var inventaire = joueur.get_node_or_null("Inventaire")
	if inventaire == null or not inventaire.get("etat") is Dictionary:
		return false
	return Objets.possede(inventaire.etat, id)


func est_monte() -> bool:
	return monture != ""


## Multiplicateur de vitesse de course (1 à pied).
func multiplicateur() -> float:
	if monture == "":
		return 1.0
	var pourcent := float(fiche(monture).get("vitesse_pourcent", reglage("vitesse_pourcent", 70)))
	return 1.0 + pourcent / 100.0


## Pourquoi on ne peut pas appeler sa monture maintenant ("" si on peut).
func raison_impossible() -> String:
	if not combat.est_vivant():
		return "Impossible quand on est désynchronisé"
	match lieu(get_tree()):
		"ville":
			return "Pas de monture en ville"
		"donjon":
			return "Pas de monture dans un donjon"
	var ici := monture_du_lieu(get_tree())
	if ici == "":
		return "Aucune monture de cette époque"
	var requis := String(fiche(ici).get("requiert", ""))
	if requis != "" and not _possede(requis):
		if fiche(ici).has("requiert_texte"):
			return String(fiche(ici).requiert_texte)
		return "Il te faut d'abord dresser une monture ici (quête « Le cheval de Lysimaque »)" \
				if requis == "bride_lysimaque" else "Il te faut : " + requis
	if multiplayer.is_server() and combat.en_combat():
		return "Impossible en combat"
	if joueur.bouge():
		return "Il faut être immobile pour appeler sa monture"
	if Regles.maintenant() < _pas_avant:
		return "Ta monture reprend ses esprits…"
	return ""


# --- Commandes (chez le joueur) ---------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("monture") or event.is_echo() or not joueur.est_local():
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	get_viewport().set_input_as_handled()
	basculer()


## Monter (ou descendre si on est déjà en selle).
func basculer() -> void:
	if monture != "":
		Regles.au_serveur(self, "_demander_descente")
		return
	var raison := raison_impossible()
	if raison != "":
		combat_joueur.message.emit(raison)
		return
	Regles.au_serveur(self, "_demander_monture")


# --- Serveur -------------------------------------------------------------------

func _est_le_proprietaire() -> bool:
	return Regles.expediteur() == joueur.id_reseau()


@rpc("any_peer", "call_remote", "reliable")
func _demander_monture() -> void:
	if not multiplayer.is_server() or not _est_le_proprietaire() or monture != "" or _appel_id != "":
		return
	var raison := raison_impossible()
	if raison != "":
		Regles.chez(joueur.id_reseau(), combat_joueur, "_recevoir_message", [raison])
		return
	_appel_id = monture_du_lieu(get_tree())
	var duree := reglage("duree_invocation", 1.5)
	_appel_fin = Regles.maintenant() + duree
	Regles.chez(joueur.id_reseau(), combat_joueur, "_recevoir_incantation",
			[String(fiche(_appel_id).get("nom", "Monture")), duree])


@rpc("any_peer", "call_remote", "reliable")
func _demander_descente() -> void:
	if multiplayer.is_server() and _est_le_proprietaire():
		descendre("")


## Serveur : fait descendre de monture (texte = message affiché au joueur, "" pour aucun).
func descendre(texte: String) -> void:
	if not multiplayer.is_server():
		return
	if _appel_id != "":
		_annuler_appel("Interrompu" if texte != "" else "")
	if monture == "":
		return
	monture = ""
	if texte != "":
		_pas_avant = Regles.maintenant() + reglage("recharge_apres_chute", 3.0)
		Regles.chez(joueur.id_reseau(), combat_joueur, "_recevoir_message", [texte])


func _annuler_appel(texte: String) -> void:
	_appel_id = ""
	Regles.chez(joueur.id_reseau(), combat_joueur, "_recevoir_incantation", ["", -1.0])
	if texte != "":
		Regles.chez(joueur.id_reseau(), combat_joueur, "_recevoir_message", [texte])


func _physics_process(_delta: float) -> void:
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	if _appel_id != "":
		if not combat.est_vivant() or combat.en_combat() or joueur.bouge():
			_annuler_appel("Interrompu")
		elif Regles.maintenant() >= _appel_fin:
			monture = _appel_id
			_appel_id = ""
	elif monture != "":
		if not combat.est_vivant():
			descendre("")
		elif combat.en_combat():
			descendre("Tu descends de ta monture pour combattre")
		elif monture_du_lieu(get_tree()) != monture:
			descendre("")


# --- Affichage (chez tout le monde) --------------------------------------------

func _afficher() -> void:
	if _bete != null:
		_bete.queue_free()
		_bete = null
	_retirer_pose()
	var apparence: Node3D = joueur.get_node_or_null("Apparence")
	if monture == "":
		if apparence != null:
			apparence.position = Vector3.ZERO
		_regler_camera(false)
		return
	if not Reseau.a_un_joueur_local():
		return  # Serveur dédié : rien à afficher.
	_bete = ApparenceMonture.new()
	_bete.name = "Bete"
	_bete.reglages = fiche(monture)
	add_child(_bete)
	_regler_camera(true)
	if DisplayServer.get_name() != "headless":
		Audio.effet("roulade", joueur)


func _regler_camera(en_selle: bool) -> void:
	var camera = joueur.get("camera")
	if camera == null or not joueur.est_local():
		return
	if _hauteur_camera < 0.0:
		_hauteur_camera = camera.hauteur_visee
	camera.hauteur_visee = _hauteur_camera + (CAMERA_EN_SELLE if en_selle else 0.0)


func _retirer_pose() -> void:
	if _pose != null and is_instance_valid(_pose):
		_pose.queue_free()
	_pose = null
	_squelette_pose = null


## Appelée par le Joueur à chaque image quand il est en selle.
func animer(delta: float, vitesse_locale: Vector3, au_sol: bool) -> void:
	if _bete == null:
		return
	_bete.animer(delta, vitesse_locale, au_sol)
	var apparence: Node3D = joueur.get_node_or_null("Apparence")
	if apparence == null or not apparence.has_method("_squelette"):
		return
	# Le personnage peut être reconstruit (changement d'apparence) : on repose la pose.
	var squelette: Skeleton3D = apparence._squelette()
	if squelette == null:
		return
	if squelette != _squelette_pose:
		_retirer_pose()
		_pose = PoseCavalier.new()
		_pose.name = "PoseCavalier"
		squelette.add_child(_pose)
		_squelette_pose = squelette
	# On pose les hanches du cavalier sur le dos de la bête.
	var hanches_monde: Vector3 = squelette.global_transform * _pose.hanches()
	var hanches := apparence.global_transform.affine_inverse() * hanches_monde
	var selle: Vector3 = _bete.point_selle()
	var voulu := Vector3(0.0, selle.y - hanches.y + 0.06, selle.z - hanches.z)
	apparence.position = apparence.position.lerp(voulu, clampf(20.0 * delta, 0.0, 1.0)) \
			if apparence.position != Vector3.ZERO else voulu
