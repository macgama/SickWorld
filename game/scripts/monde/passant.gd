extends Node3D
## Un habitant anonyme qui marche dans les rues de Hikari Bay (ou attend sous son
## parapluie). Il suit un chemin en aller-retour et s'arrête un peu à chaque bout.
## Les passants sont décrits dans data/hub_passants.json (modifiable sans code).
## On ne leur parle pas (ce ne sont pas des Pnj) et ils ne bloquent pas le joueur.

const SCENE_APPARENCE := "res://scenes/joueur/apparence_agent.tscn"
## Au-delà de cette distance de la caméra, le passant est caché et ne calcule rien.
const DISTANCE_VISIBLE := 95.0

## « homme » ou « femme ».
var modele := "homme"
## Vitesse de marche (m/s). 0 : il reste sur place.
var vitesse := 2.4
## Points du chemin (y = 0), parcourus en aller-retour.
var chemin: PackedVector3Array = []
## Couleur du parapluie (alpha 0 : pas de parapluie).
var parapluie := Color(0, 0, 0, 0)
## Taille en cm (pour varier les silhouettes).
var taille_cm := 175.0
## Teinte de peau.
var peau := Color(0.8, 0.62, 0.5)
## Orientation quand il attend sur place (radians, 0 = regarde vers -Z).
var orientation := 0.0

var _apparence: Node3D
var _cible := 1
var _sens := 1
var _pause := 0.0


func _ready() -> void:
	add_to_group("passants")
	_apparence = (load(SCENE_APPARENCE) as PackedScene).instantiate()
	add_child(_apparence)
	_apparence.appliquer({"sexe": modele, "taille_cm": taille_cm, "peau": peau})
	if parapluie.a > 0.0:
		_ajouter_parapluie()
	if chemin.size() > 0:
		position = chemin[0]
	rotation.y = orientation
	# Chacun part à un moment différent.
	_pause = randf_range(0.0, 4.0)


func _ajouter_parapluie() -> void:
	var pivot := Node3D.new()
	pivot.name = "Parapluie"
	pivot.position = Vector3(0.24, 0.0, -0.08) * (taille_cm / 175.0)
	pivot.rotation.z = 0.12
	add_child(pivot)
	var toile := CylinderMesh.new()
	toile.top_radius = 0.02
	toile.bottom_radius = 0.5
	toile.height = 0.28
	toile.radial_segments = 8
	toile.rings = 1
	var m := StandardMaterial3D.new()
	m.albedo_color = parapluie
	m.roughness = 0.35
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = toile
	mi.material_override = m
	mi.position = Vector3(0, 2.0 * taille_cm / 175.0, 0)
	pivot.add_child(mi)
	var manche := CylinderMesh.new()
	manche.top_radius = 0.012
	manche.bottom_radius = 0.012
	manche.height = 1.15
	var noir := StandardMaterial3D.new()
	noir.albedo_color = Color(0.08, 0.08, 0.08)
	var mm := MeshInstance3D.new()
	mm.mesh = manche
	mm.material_override = noir
	mm.position = Vector3(0, 1.43 * taille_cm / 175.0, 0)
	pivot.add_child(mm)


func _physics_process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var loin := camera != null and camera.global_position.distance_to(global_position) > DISTANCE_VISIBLE
	visible = not loin
	var deplacement := Vector3.ZERO
	if vitesse > 0.0 and chemin.size() >= 2:
		if _pause > 0.0:
			_pause -= delta
		else:
			var vers := chemin[_cible] - position
			vers.y = 0.0
			var pas := vitesse * delta
			if vers.length() <= pas:
				position = chemin[_cible]
				_suivant()
			else:
				deplacement = vers.normalized() * vitesse
				position += deplacement * delta
				rotation.y = lerp_angle(rotation.y, atan2(-vers.x, -vers.z), clampf(6.0 * delta, 0.0, 1.0))
	# Loin de la caméra, il continue d'avancer mais on ne l'anime pas.
	if not loin and _apparence != null and _apparence.has_method("animer"):
		var locale := global_transform.basis.inverse() * deplacement
		_apparence.animer(delta, locale, true, -1.0, Vector3.ZERO)


## Point suivant du chemin (aller-retour), avec une pause aux deux bouts.
func _suivant() -> void:
	var prochain := _cible + _sens
	if prochain < 0 or prochain >= chemin.size():
		_sens = -_sens
		prochain = _cible + _sens
		_pause = randf_range(1.5, 6.0)
	_cible = prochain
