extends Node3D
## La barque de Merer (île d'Égypte) : elle emmène le joueur de l'autre côté du Nil.
##
## À l'arrêt, elle attend le long du quai. Quand la quête l'appelle (effet
## {"appeler": "barque_merer", "methode": "partir"}), le joueur est posé sur le
## pont et la barque suit son « chemin » : elle sort du bassin par le chenal, puis
## s'éloigne sur le fleuve. Au bout du chemin, on change de zone (« destination »).
## Le pont est un corps qui bouge (AnimatableBody3D) : le joueur y marche et il est
## emporté avec lui. S'il saute à l'eau, il est remis à bord.

## Points (x, z) que la barque suit, du quai jusqu'au large.
var chemin: Array = []
## Vitesse sur l'eau (mètres par seconde).
var vitesse := 4.5
## Zone où l'on arrive à la fin de la traversée.
var destination := ""
## Longueur de la barque (pour le pont et les bastingages).
var longueur := 11.0
## Ce que l'on entend pendant la traversée : [part du trajet (0 à 1), titre, texte].
var paroles: Array = []

var en_route := false
var _parcouru := 0.0
var _longueur_chemin := 0.0
var _paroles_dites := 0
var _temps := 0.0
var _pont: AnimatableBody3D
var _murs_desactives: Array = []


func _ready() -> void:
	set_meta("identifiant", "barque_merer")
	add_to_group("decor_quete")
	_pont = AnimatableBody3D.new()
	_pont.name = "Pont"
	_pont.sync_to_physics = true
	var large := longueur * 0.17
	var formes := [
		[Vector3(large * 1.6, 0.3, longueur * 0.74), Vector3(0, 0.1, 0)],
		# Bastingages invisibles : on ne tombe pas par mégarde.
		[Vector3(0.2, 1.4, longueur * 0.74), Vector3(-large * 0.9, 0.8, 0)],
		[Vector3(0.2, 1.4, longueur * 0.74), Vector3(large * 0.9, 0.8, 0)],
		[Vector3(large * 1.8, 1.4, 0.2), Vector3(0, 0.8, -longueur * 0.37)],
		[Vector3(large * 1.8, 1.4, 0.2), Vector3(0, 0.8, longueur * 0.37)],
	]
	for f in formes:
		var forme := CollisionShape3D.new()
		var boite := BoxShape3D.new()
		boite.size = f[0]
		forme.shape = boite
		forme.position = f[1]
		_pont.add_child(forme)
	add_child(_pont)
	_longueur_chemin = 0.0
	for i in range(1, chemin.size()):
		_longueur_chemin += (chemin[i] as Vector2).distance_to(chemin[i - 1])


## Appelé par la quête. anime = faux quand on recharge une partie déjà avancée :
## la barque reste alors à quai (on traversera avec le passeur).
func partir(anime: bool) -> void:
	if not anime or en_route or chemin.size() < 2:
		return
	en_route = true
	_parcouru = 0.0
	_paroles_dites = 0
	# Les barrières invisibles du bord du fleuve laissent passer la barque.
	for mur in get_tree().get_nodes_in_group("limites_nil"):
		if mur is CollisionObject3D:
			_murs_desactives.append([mur, mur.collision_layer])
			mur.collision_layer = 0
	_monter_a_bord()


## Pose le joueur au milieu du pont.
func _monter_a_bord() -> void:
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return
	var p := global_transform * Vector3(0, 0.6, longueur * 0.12)
	if joueur.has_method("teleporter"):
		joueur.teleporter(p, rotation.y)
	else:
		joueur.global_position = p


func _physics_process(delta: float) -> void:
	_temps += delta
	if not en_route:
		# À quai, la barque se balance doucement.
		rotation.z = sin(_temps * 0.9) * 0.01
		return
	_parcouru += vitesse * delta
	var p := _point(_parcouru)
	var devant := _point(_parcouru + 3.0)
	var direction := devant - p
	var y := -0.1 + sin(_temps * 1.3) * 0.04
	global_position = Vector3(p.x, y, p.y)
	if direction.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.y), clampf(delta * 1.5, 0.0, 1.0))
	rotation.z = sin(_temps * 0.9) * 0.02
	# Un joueur tombé à l'eau est remis à bord.
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur != null and joueur.global_position.distance_to(global_position) > 7.0:
		_monter_a_bord()
	var part := _parcouru / maxf(_longueur_chemin, 1.0)
	while _paroles_dites < paroles.size() and part >= float(paroles[_paroles_dites][0]):
		var quete := get_tree().get_first_node_in_group("quete")
		if quete != null and quete.has_method("_annoncer"):
			quete._annoncer(String(paroles[_paroles_dites][1]), String(paroles[_paroles_dites][2]))
		_paroles_dites += 1
	if _parcouru >= _longueur_chemin:
		_arriver()


func _arriver() -> void:
	en_route = false
	for m in _murs_desactives:
		if is_instance_valid(m[0]):
			m[0].collision_layer = m[1]
	_murs_desactives.clear()
	var quete := get_tree().get_first_node_in_group("quete")
	if quete != null and destination != "":
		quete.changer_de_zone(destination)


## Point (x, z) à une distance donnée le long du chemin.
func _point(distance: float) -> Vector2:
	var reste := maxf(distance, 0.0)
	for i in range(1, chemin.size()):
		var a: Vector2 = chemin[i - 1]
		var b: Vector2 = chemin[i]
		var l := a.distance_to(b)
		if reste <= l:
			return a.lerp(b, reste / maxf(l, 0.001))
		reste -= l
	return chemin[-1]
