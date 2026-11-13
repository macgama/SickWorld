class_name CameraJoueur
extends Node3D
## Caméra à la troisième personne façon World of Warcraft.
##
## - Clic gauche maintenu : tourner la caméra autour du personnage.
## - Clic droit maintenu : tourner la caméra ET le personnage.
## - Molette : zoomer / dézoomer.
## La caméra ne traverse pas le décor (elle se rapproche si un obstacle gêne).

## Hauteur du point regardé, au-dessus des pieds du personnage (mètres).
@export var hauteur_visee := 1.6
## Distance de départ entre la caméra et le personnage (mètres).
@export var distance := 7.0
@export var distance_min := 1.5
@export var distance_max := 20.0
## Sensibilité de la souris (degrés par pixel).
@export var sensibilite := 0.25
## Angle vertical minimum et maximum (degrés).
@export var inclinaison_min := -80.0
@export var inclinaison_max := 60.0
## Vitesse à laquelle la caméra revient derrière le personnage quand il bouge.
@export var retour_automatique := 2.5

## Émis quand on clique sans déplacer la souris (pour sélectionner une cible).
signal clic_simple(bouton: int, position_ecran: Vector2)

## Angle horizontal de la caméra (radians).
var lacet := 0.0
## Angle vertical de la caméra (radians).
var tangage := deg_to_rad(-18.0)

var _clic_gauche := false
var _clic_droit := false
var _position_souris := Vector2.ZERO
var _distance_voulue := 7.0
var _mouvement_cumule := 0.0

@onready var _cible: CharacterBody3D = get_parent()
@onready var _pivot: Node3D = $Pivot
@onready var _bras: SpringArm3D = $Pivot/Bras


func _ready() -> void:
	# Seul le personnage qu'on contrôle a une caméra active.
	if not _cible.is_multiplayer_authority() or not Reseau.a_un_joueur_local():
		$Pivot/Bras/Camera3D.current = false
		set_process(false)
		set_process_unhandled_input(false)
		return
	$Pivot/Bras/Camera3D.make_current()
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_distance_voulue = distance
	_bras.spring_length = distance
	_bras.add_excluded_object(_cible.get_rid())
	recentrer()


func clic_droit_maintenu() -> bool:
	return _clic_droit


func deux_clics_maintenus() -> bool:
	return _clic_gauche and _clic_droit


## Remet la caméra derrière le personnage.
func recentrer() -> void:
	lacet = _cible.global_rotation.y
	_appliquer(0.0)


## Pendant un bond : la caméra se replace derrière le personnage.
func recentrer_doucement() -> void:
	if not _clic_gauche and not _clic_droit:
		lacet = lerp_angle(lacet, _cible.global_rotation.y, 0.2)


## Le personnage a tourné au clavier : la caméra tourne avec lui.
func suivre_rotation(angle: float) -> void:
	if not _clic_gauche:
		lacet += angle


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var bouton := event as InputEventMouseButton
		match bouton.button_index:
			MOUSE_BUTTON_LEFT:
				_clic_gauche = bouton.pressed
				_mettre_a_jour_capture()
				_verifier_clic_simple(bouton)
			MOUSE_BUTTON_RIGHT:
				_clic_droit = bouton.pressed
				_mettre_a_jour_capture()
				_verifier_clic_simple(bouton)
			MOUSE_BUTTON_WHEEL_UP:
				if bouton.pressed:
					_distance_voulue = maxf(distance_min, _distance_voulue * 0.88)
			MOUSE_BUTTON_WHEEL_DOWN:
				if bouton.pressed:
					_distance_voulue = minf(distance_max, _distance_voulue / 0.88)
	elif event is InputEventMouseMotion and (_clic_gauche or _clic_droit):
		var mouvement := (event as InputEventMouseMotion).relative
		_mouvement_cumule += mouvement.length()
		lacet -= deg_to_rad(mouvement.x * sensibilite)
		tangage = clampf(tangage - deg_to_rad(mouvement.y * sensibilite),
				deg_to_rad(inclinaison_min), deg_to_rad(inclinaison_max))


func _notification(what: int) -> void:
	# Si la fenêtre perd le focus, on relâche la souris.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_clic_gauche = false
		_clic_droit = false
		_mettre_a_jour_capture()


func _verifier_clic_simple(bouton: InputEventMouseButton) -> void:
	if not bouton.pressed and not _clic_gauche and not _clic_droit and _mouvement_cumule < 6.0:
		clic_simple.emit(bouton.button_index, _position_souris)


func _mettre_a_jour_capture() -> void:
	var maintenu := _clic_gauche or _clic_droit
	if maintenu and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# On cache le curseur pendant qu'on tourne, comme dans WoW.
		_position_souris = get_viewport().get_mouse_position()
		_mouvement_cumule = 0.0
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif not maintenu and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Input.warp_mouse(_position_souris)


func _process(delta: float) -> void:
	# Quand le personnage bouge sans qu'on tienne la souris,
	# la caméra revient doucement derrière lui.
	var vitesse_horizontale := Vector2(_cible.velocity.x, _cible.velocity.z).length()
	if not _clic_gauche and not _clic_droit and vitesse_horizontale > 0.5:
		lacet = lerp_angle(lacet, _cible.global_rotation.y, 1.0 - exp(-retour_automatique * delta))
	_appliquer(delta)


func _appliquer(delta: float) -> void:
	global_position = _cible.get_global_transform_interpolated().origin + Vector3.UP * hauteur_visee
	rotation = Vector3(0.0, lacet, 0.0)
	_pivot.rotation = Vector3(tangage, 0.0, 0.0)
	if delta > 0.0:
		_bras.spring_length = lerpf(_bras.spring_length, _distance_voulue, 1.0 - exp(-12.0 * delta))
