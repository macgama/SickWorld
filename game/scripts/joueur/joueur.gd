class_name Joueur
extends CharacterBody3D
## Le personnage contrôlé par le joueur.
##
## Contrôles façon World of Warcraft :
## - Z/S (ou W/S) : avancer / reculer
## - Q/D : tourner (ou faire un pas de côté si le clic droit est maintenu)
## - A/E : pas de côté
## - Clic droit maintenu : la souris oriente le personnage et la caméra
## - Clic gauche maintenu : la souris tourne seulement la caméra
## - Les deux clics : avancer
## - Espace : sauter ; Maj : roulade d'esquive
##
## Toutes les valeurs ci-dessous se règlent dans l'Inspecteur de Godot
## (sélectionner le nœud « Joueur » dans la scène).

@export_group("Déplacement")
## Vitesse de course vers l'avant ou sur le côté (mètres par seconde).
@export var vitesse_course := 7.0
## Vitesse en marche arrière (mètres par seconde).
@export var vitesse_recul := 4.5
## Vitesse de rotation avec Q/D (degrés par seconde).
@export var vitesse_rotation_clavier := 180.0
## Force du saut.
@export var force_saut := 6.0
## Gravité (plus c'est grand, plus on retombe vite).
@export var gravite := 16.0
## Contrôle en l'air (0 = aucun, 1 = autant qu'au sol).
@export_range(0.0, 1.0) var controle_en_l_air := 0.3

@export_group("Esquive")
## Vitesse pendant la roulade (mètres par seconde).
@export var vitesse_esquive := 11.0
## Durée de la roulade (secondes).
@export var duree_esquive := 0.45
## Endurance maximum.
@export var endurance_max := 100.0
## Endurance consommée par une roulade.
@export var cout_esquive := 35.0
## Endurance récupérée par seconde.
@export var recuperation_endurance := 20.0

@export_group("Apparence")
## Altitude sous laquelle le personnage est ramené à son point de départ.
@export var altitude_minimum := -30.0

var endurance := 100.0
# Valeurs de base (avant les bonus d'origine).
var _cout_esquive_base := 0.0
var _recuperation_endurance_base := 0.0

# --- État partagé sur le réseau (voir le nœud « Synchro ») ---
## Nom choisi par le joueur.
var nom := "Agent"
## Position, orientation et vitesse envoyées par le joueur qui contrôle ce personnage.
var position_reseau := Vector3.ZERO
var lacet_reseau := 0.0
var vitesse_reseau := Vector3.ZERO
## Progression de la roulade (-1 = pas de roulade) et sa direction, pour l'animation.
var esquive_reseau := -1.0
var direction_esquive_reseau := Vector3.ZERO
var _place := false

var _temps_esquive := 0.0
var _direction_esquive := Vector3.ZERO
var _point_depart := Vector3.ZERO
var _bond_cible: Node3D = null
var _bond_fin := 0.0
var _bond_arrivee := Callable()
## Repli du Traqueur : temps restant et vitesse du saut en arrière.
var _repli_temps := 0.0
var _repli_vitesse := Vector3.ZERO
const DUREE_REPLI := 0.4

@onready var camera: CameraJoueur = $CameraRig
@onready var apparence: Node3D = $Apparence
@onready var combat: Combattant = $Combat
@onready var fiche: Node = $Fiche


func _enter_tree() -> void:
	# Le personnage appartient au joueur dont il porte le numéro : c'est lui qui le déplace.
	# Le combat (vie, compétences), lui, appartient toujours au serveur (numéro 1).
	if name.is_valid_int():
		set_multiplayer_authority(name.to_int(), true)
	$Combat.set_multiplayer_authority(1, true)
	$CombatJoueur.set_multiplayer_authority(1, true)
	$Fiche.set_multiplayer_authority(1, true)
	$Inventaire.set_multiplayer_authority(1, true)


## Numéro réseau du joueur qui contrôle ce personnage.
func id_reseau() -> int:
	return get_multiplayer_authority()


## Vrai si ce personnage est celui qu'on contrôle sur ce PC.
func est_local() -> bool:
	return is_multiplayer_authority() and Reseau.a_un_joueur_local()


func _ready() -> void:
	add_to_group("joueur")
	if est_local():
		add_to_group("joueur_local")
	endurance = endurance_max
	_cout_esquive_base = cout_esquive
	_recuperation_endurance_base = recuperation_endurance
	fiche.changee.connect(_appliquer_fiche)
	_appliquer_fiche()
	_point_depart = global_position
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50.0)


## Applique la fiche du personnage : apparence et bonus d'origine.
func _appliquer_fiche() -> void:
	var catalogue: Dictionary = Donnees.creation
	if apparence.has_method("appliquer"):
		apparence.appliquer(FichePersonnage.resoudre(fiche.donnees, catalogue))
	var bonus_esquive := FichePersonnage.bonus(fiche.donnees, catalogue, "cout_esquive_pourcent")
	cout_esquive = _cout_esquive_base * (1.0 + bonus_esquive / 100.0)
	var bonus_endurance := FichePersonnage.bonus(fiche.donnees, catalogue, "recuperation_endurance_pourcent")
	recuperation_endurance = _recuperation_endurance_base * (1.0 + bonus_endurance / 100.0)


## Nom de la classe du personnage (ex. « Lame »).
func nom_classe() -> String:
	var id := String(fiche.donnees.get("classe", "lame"))
	return String(FichePersonnage.element(Donnees.creation, "classes", id).get("nom", id.capitalize()))


## Place le personnage à un endroit et en fait son point de réapparition.
func placer(position_monde: Vector3, orientation: float = 0.0) -> void:
	global_position = position_monde
	rotation.y = orientation
	_point_depart = position_monde
	velocity = Vector3.ZERO
	position_reseau = position_monde
	lacet_reseau = orientation
	_place = true
	camera.recentrer()
	reset_physics_interpolation()


func est_en_esquive() -> bool:
	return _temps_esquive > 0.0


## Vrai si le personnage se déplace (ce qui interrompt les incantations).
func bouge() -> bool:
	var v := velocity if est_local() else vitesse_reseau
	return Vector2(v.x, v.z).length() > 0.5 or absf(v.y) > 1.0


## Compétence « Bond » : fonce vers la cible puis appelle « a_l_arrivee ».
func bondir_vers(cible: Node3D, a_l_arrivee: Callable) -> void:
	_bond_cible = cible
	_bond_fin = Regles.maintenant() + 1.2
	_bond_arrivee = a_l_arrivee
	velocity.y = 4.0


## Désynchronisé (mort) : le personnage devient une silhouette translucide.
var _translucide := false
func _rendre_translucide(oui: bool) -> void:
	if oui == _translucide:
		return
	_translucide = oui
	for n in apparence.find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).transparency = 0.65 if oui else 0.0


## Compétence « Repli » (Traqueur) : saut en arrière de « distance » mètres.
@rpc("any_peer", "call_remote", "reliable")
func sauter_en_arriere(distance: float) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	_repli_temps = DUREE_REPLI
	_repli_vitesse = transform.basis.z * (distance / DUREE_REPLI)
	velocity.y = 5.0


## Le serveur demande de déplacer le personnage (réapparition…).
@rpc("any_peer", "call_remote", "reliable")
func teleporter(position_monde: Vector3, orientation: float) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	placer(position_monde, orientation)


## Envoie notre état aux autres joueurs (via le nœud Synchro).
func _publier() -> void:
	position_reseau = global_position
	lacet_reseau = rotation.y
	vitesse_reseau = velocity
	esquive_reseau = 1.0 - _temps_esquive / duree_esquive if _temps_esquive > 0.0 else -1.0
	direction_esquive_reseau = transform.basis.inverse() * _direction_esquive


## Personnage d'un autre joueur : on le fait glisser vers la position reçue.
func _suivre_le_reseau(delta: float) -> void:
	if position_reseau == Vector3.ZERO:
		return
	if global_position.distance_to(position_reseau) > 6.0:
		global_position = position_reseau
		reset_physics_interpolation()
	else:
		global_position = global_position.lerp(position_reseau, clampf(15.0 * delta, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, lacet_reseau, clampf(15.0 * delta, 0.0, 1.0))
	if apparence.has_method("animer"):
		var vitesse_locale := transform.basis.inverse() * Vector3(vitesse_reseau.x, 0.0, vitesse_reseau.z)
		apparence.animer(delta, vitesse_locale, absf(vitesse_reseau.y) < 1.0, esquive_reseau,
				direction_esquive_reseau)


func _physics_process(delta: float) -> void:
	_rendre_translucide(not combat.est_vivant())
	if not est_local():
		_suivre_le_reseau(delta)
		return
	if not _place and position_reseau != Vector3.ZERO:
		placer(position_reseau, lacet_reseau)
	_publier()
	if not combat.est_vivant():
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= gravite * delta
		move_and_slide()
		return

	if _bond_cible != null:
		_bondir(delta)
		return
	if _repli_temps > 0.0:
		_repli_temps -= delta
		velocity.x = _repli_vitesse.x
		velocity.z = _repli_vitesse.z
		velocity.y -= gravite * delta
		move_and_slide()
		_publier()
		if apparence.has_method("animer"):
			apparence.animer(delta, transform.basis.inverse() * Vector3(velocity.x, 0.0, velocity.z), false, -1.0, Vector3.ZERO)
		return

	var clic_droit := camera.clic_droit_maintenu()
	# Pendant qu'on écrit (nom d'une tenue…), les touches ne déplacent pas le personnage.
	var clavier := 0.0 if get_viewport().gui_get_focus_owner() is LineEdit else 1.0

	# 1. Orientation du personnage.
	if clic_droit:
		rotation.y = camera.lacet
	else:
		var tourner := Input.get_axis("tourner_droite", "tourner_gauche") * clavier
		if tourner != 0.0:
			var angle := deg_to_rad(vitesse_rotation_clavier) * tourner * delta
			rotation.y += angle
			camera.suivre_rotation(angle)

	# 2. Direction voulue (dans le repère du personnage).
	var avant := Input.get_axis("reculer", "avancer") * clavier
	if camera.deux_clics_maintenus():
		avant = 1.0
	var cote := Input.get_axis("pas_gauche", "pas_droite") * clavier
	if clic_droit:
		cote += Input.get_axis("tourner_gauche", "tourner_droite") * clavier
	cote = clampf(cote, -1.0, 1.0)

	var direction := -transform.basis.z * avant + transform.basis.x * cote
	if direction.length() > 1.0:
		direction = direction.normalized()
	var vitesse := vitesse_course if avant >= 0.0 else vitesse_recul
	vitesse *= combat.multiplicateur_vitesse()

	# 3. Endurance.
	endurance = minf(endurance + recuperation_endurance * delta, endurance_max)

	# 4. Mouvement horizontal.
	if _temps_esquive > 0.0:
		_temps_esquive -= delta
		velocity.x = _direction_esquive.x * vitesse_esquive
		velocity.z = _direction_esquive.z * vitesse_esquive
	elif clavier > 0.0 and Input.is_action_just_pressed("esquive") and is_on_floor() and endurance >= cout_esquive:
		endurance -= cout_esquive
		_temps_esquive = duree_esquive
		_direction_esquive = direction.normalized() if direction.length() > 0.1 else -transform.basis.z
	elif is_on_floor():
		velocity.x = direction.x * vitesse
		velocity.z = direction.z * vitesse
	else:
		var voulu := direction * vitesse
		var poids := clampf(controle_en_l_air * 8.0 * delta, 0.0, 1.0)
		velocity.x = lerpf(velocity.x, voulu.x, poids)
		velocity.z = lerpf(velocity.z, voulu.z, poids)

	# 5. Saut et gravité.
	if is_on_floor():
		if clavier > 0.0 and Input.is_action_just_pressed("sauter") and _temps_esquive <= 0.0:
			velocity.y = force_saut
	else:
		velocity.y -= gravite * delta

	move_and_slide()

	_publier()

	# 6. Sécurité : si on tombe hors du monde, on revient au départ.
	if global_position.y < altitude_minimum:
		placer(_point_depart, rotation.y)

	# 7. Animation de l'apparence.
	if apparence.has_method("animer"):
		var vitesse_locale := transform.basis.inverse() * Vector3(velocity.x, 0.0, velocity.z)
		var progression := -1.0
		var direction_locale := Vector3.ZERO
		if _temps_esquive > 0.0:
			progression = 1.0 - _temps_esquive / duree_esquive
			direction_locale = transform.basis.inverse() * _direction_esquive
		apparence.animer(delta, vitesse_locale, is_on_floor(), progression, direction_locale)


func _bondir(delta: float) -> void:
	if not is_instance_valid(_bond_cible) or Regles.maintenant() > _bond_fin:
		_bond_cible = null
		return
	var ecart := _bond_cible.global_position - global_position
	ecart.y = 0.0
	if ecart.length() < 1.8:
		_bond_cible = null
		velocity.x = 0.0
		velocity.z = 0.0
		if _bond_arrivee.is_valid():
			_bond_arrivee.call()
		return
	rotation.y = atan2(-ecart.x, -ecart.z)
	camera.recentrer_doucement()
	var v := ecart.normalized() * 24.0
	velocity.x = v.x
	velocity.z = v.z
	velocity.y -= gravite * delta
	move_and_slide()
	_publier()
	if apparence.has_method("animer"):
		apparence.animer(delta, Vector3(0, 0, -24.0), false, -1.0, Vector3.ZERO)
