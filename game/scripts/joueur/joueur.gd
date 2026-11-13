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

var _temps_esquive := 0.0
var _direction_esquive := Vector3.ZERO
var _point_depart := Vector3.ZERO

@onready var camera: CameraJoueur = $CameraRig
@onready var apparence: Node3D = $Apparence


func _ready() -> void:
	add_to_group("joueur")
	endurance = endurance_max
	_point_depart = global_position
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50.0)


## Place le personnage à un endroit et en fait son point de réapparition.
func placer(position_monde: Vector3, orientation: float = 0.0) -> void:
	global_position = position_monde
	rotation.y = orientation
	_point_depart = position_monde
	velocity = Vector3.ZERO
	camera.recentrer()
	reset_physics_interpolation()


func est_en_esquive() -> bool:
	return _temps_esquive > 0.0


func _physics_process(delta: float) -> void:
	var clic_droit := camera.clic_droit_maintenu()

	# 1. Orientation du personnage.
	if clic_droit:
		rotation.y = camera.lacet
	else:
		var tourner := Input.get_axis("tourner_droite", "tourner_gauche")
		if tourner != 0.0:
			var angle := deg_to_rad(vitesse_rotation_clavier) * tourner * delta
			rotation.y += angle
			camera.suivre_rotation(angle)

	# 2. Direction voulue (dans le repère du personnage).
	var avant := Input.get_axis("reculer", "avancer")
	if camera.deux_clics_maintenus():
		avant = 1.0
	var cote := Input.get_axis("pas_gauche", "pas_droite")
	if clic_droit:
		cote += Input.get_axis("tourner_gauche", "tourner_droite")
	cote = clampf(cote, -1.0, 1.0)

	var direction := -transform.basis.z * avant + transform.basis.x * cote
	if direction.length() > 1.0:
		direction = direction.normalized()
	var vitesse := vitesse_course if avant >= 0.0 else vitesse_recul

	# 3. Endurance.
	endurance = minf(endurance + recuperation_endurance * delta, endurance_max)

	# 4. Mouvement horizontal.
	if _temps_esquive > 0.0:
		_temps_esquive -= delta
		velocity.x = _direction_esquive.x * vitesse_esquive
		velocity.z = _direction_esquive.z * vitesse_esquive
	elif Input.is_action_just_pressed("esquive") and is_on_floor() and endurance >= cout_esquive:
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
		if Input.is_action_just_pressed("sauter") and _temps_esquive <= 0.0:
			velocity.y = force_saut
	else:
		velocity.y -= gravite * delta

	move_and_slide()

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
