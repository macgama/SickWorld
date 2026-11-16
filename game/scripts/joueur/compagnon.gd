extends Node3D
## Le petit compagnon d'un personnage : Glaukê, la chouette de Néra (île de Grèce).
## Il apparaît quand on porte l'objet qui a la clé « compagnon » (data/objets.json) :
## la chouette se tient sur l'épaule droite quand on marche ou qu'on attend, et s'envole
## au-dessus de soi quand on court ou qu'on se bat, en battant des ailes.
## Ajouté et retiré par l'inventaire (voir inventaire.gd, _habiller).

var espece := "chouette"

var _joueur: Node3D
var _squelette: Skeleton3D
var _os_epaule := -1
var _corps: Node3D
var _ailes: Array[Node3D] = []
var _tete: Node3D
var _temps := 0.0
var _vol := 0.0
var _derniere := Vector3.ZERO
var _vitesse := 0.0
var _regard := 0.0


func _ready() -> void:
	top_level = true
	_joueur = get_parent() as Node3D
	_construire()
	if _joueur != null:
		global_position = _joueur.global_position + Vector3(0.2, 1.6, 0)
		_derniere = _joueur.global_position


func _mat(couleur: Color, rugosite := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = rugosite
	return m


func _boule(parent: Node3D, rayon: float, haut: float, mat: Material, p: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = rayon
	s.height = haut
	mi.mesh = s
	mi.material_override = mat
	mi.position = p
	parent.add_child(mi)
	return mi


## Une chevêche : 22 cm, brune tachetée de blanc, grosse tête ronde, yeux jaunes.
func _construire() -> void:
	var plume := _mat(Color(0.45, 0.34, 0.24))
	var clair := _mat(Color(0.82, 0.76, 0.66))
	var jaune := _mat(Color(1.0, 0.8, 0.25), 0.3)
	jaune.emission_enabled = true
	jaune.emission = Color(1.0, 0.75, 0.2)
	jaune.emission_energy_multiplier = 0.5
	var noir := _mat(Color(0.02, 0.02, 0.02), 0.2)
	_corps = Node3D.new()
	add_child(_corps)
	_boule(_corps, 0.065, 0.16, plume, Vector3(0, 0.08, 0))
	_boule(_corps, 0.05, 0.12, clair, Vector3(0, 0.075, -0.025))
	# Les taches blanches du dos.
	for k in 5:
		_boule(_corps, 0.008, 0.016, clair, Vector3(sin(k * 1.3) * 0.03, 0.06 + k * 0.012, 0.058))
	_tete = Node3D.new()
	_tete.position = Vector3(0, 0.17, 0)
	_corps.add_child(_tete)
	_boule(_tete, 0.05, 0.095, plume, Vector3.ZERO)
	for c in [-1.0, 1.0]:
		_boule(_tete, 0.015, 0.028, jaune, Vector3(c * 0.02, 0.005, -0.042))
		_boule(_tete, 0.007, 0.014, noir, Vector3(c * 0.02, 0.005, -0.056))
		_boule(_tete, 0.012, 0.01, clair, Vector3(c * 0.022, 0.024, -0.04))
	var bec := MeshInstance3D.new()
	var p := PrismMesh.new()
	p.size = Vector3(0.014, 0.02, 0.014)
	bec.mesh = p
	bec.material_override = _mat(Color(0.75, 0.7, 0.5))
	bec.position = Vector3(0, -0.014, -0.05)
	bec.rotation.x = PI
	_tete.add_child(bec)
	for c in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(c * 0.055, 0.11, 0.01)
		_corps.add_child(pivot)
		var aile := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.13, 0.012, 0.09)
		aile.mesh = b
		aile.material_override = plume
		aile.position = Vector3(c * 0.06, 0, 0)
		pivot.add_child(aile)
		_ailes.append(pivot)
	var queue := MeshInstance3D.new()
	var q := BoxMesh.new()
	q.size = Vector3(0.05, 0.01, 0.05)
	queue.mesh = q
	queue.material_override = plume
	queue.position = Vector3(0, 0.02, 0.06)
	queue.rotation.x = 0.5
	_corps.add_child(queue)


func _point_epaule() -> Vector3:
	if _squelette == null or not is_instance_valid(_squelette):
		_squelette = null
		var trouves := _joueur.find_children("*", "Skeleton3D", true, false)
		if not trouves.is_empty():
			_squelette = trouves[0]
			_os_epaule = _squelette.find_bone("mixamorig_RightShoulder")
	if _squelette != null and _os_epaule >= 0:
		var t := _squelette.global_transform * _squelette.get_bone_global_pose(_os_epaule)
		return t.origin + _joueur.global_transform.basis * Vector3(-0.06, 0.07, 0.02)
	return _joueur.global_transform * Vector3(-0.2, 1.52, 0.0)


func _process(delta: float) -> void:
	if _joueur == null or not is_instance_valid(_joueur):
		queue_free()
		return
	_temps += delta
	var deplacement := _joueur.global_position - _derniere
	_derniere = _joueur.global_position
	_vitesse = lerpf(_vitesse, Vector2(deplacement.x, deplacement.z).length() / maxf(delta, 0.001), 0.1)
	var combat = _joueur.get_node_or_null("Combat")
	var en_vol: bool = _vitesse > 4.5 or (combat != null and combat.has_method("en_combat") and combat.en_combat())
	_vol = move_toward(_vol, 1.0 if en_vol else 0.0, delta * 2.0)
	var perche := _point_epaule()
	var en_l_air := _joueur.global_transform * Vector3(0.5 * sin(_temps * 0.7), 2.4 + 0.15 * sin(_temps * 2.3), 0.9)
	var cible := perche.lerp(en_l_air, _vol)
	if _vol < 0.02:
		global_position = cible
	else:
		global_position = global_position.lerp(cible, minf(1.0, delta * 6.0))
	var face := _joueur.global_rotation.y
	rotation = Vector3(0, face, 0)
	# Battements d'ailes en vol ; au repos, la tête tourne de temps en temps (comme une vraie chouette).
	var battement := sin(_temps * 22.0) * 1.1 * _vol
	for k in _ailes.size():
		_ailes[k].rotation.z = (battement + 0.1 * (1.0 - _vol)) * (1.0 if k == 0 else -1.0)
	if fmod(_temps, 6.0) < delta:
		_regard = randf_range(-1.6, 1.6)
	if fmod(_temps, 6.0) > 2.2:
		_regard = move_toward(_regard, 0.0, delta * 2.0)
	_tete.rotation.y = lerp_angle(_tete.rotation.y, _regard, minf(1.0, delta * 5.0))
	_corps.rotation.x = -0.5 * _vol
