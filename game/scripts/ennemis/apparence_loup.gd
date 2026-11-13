@tool
extends Node3D
## Silhouette provisoire d'un loup, faite de formes simples.
## Sera remplacée par un vrai modèle 3D animé (Fab / Poly Haven) plus tard.

var _corps: Node3D
var _tete: Node3D
var _pattes: Array[Node3D] = []
var _queue: Node3D
var _phase := 0.0
var _morsure := 0.0
var _materiaux: Array[StandardMaterial3D] = []


func _ready() -> void:
	for enfant in get_children():
		enfant.queue_free()
	_construire()


func _mat(couleur: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = 0.9
	_materiaux.append(m)
	return m


func _forme(parent: Node3D, maillage: Mesh, materiau: Material, pos: Vector3, echelle := Vector3.ONE,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = maillage
	mi.material_override = materiau
	mi.position = pos
	mi.scale = echelle
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _construire() -> void:
	var pelage := _mat(Color(0.42, 0.38, 0.33))
	var clair := _mat(Color(0.62, 0.58, 0.52))
	var sombre := _mat(Color(0.08, 0.07, 0.06))

	_corps = Node3D.new()
	_corps.position = Vector3(0, 0.62, 0)
	add_child(_corps)
	var tronc := CapsuleMesh.new()
	tronc.radius = 0.22
	tronc.height = 1.1
	_forme(_corps, tronc, pelage, Vector3.ZERO, Vector3(1, 1, 1.0), Vector3(PI / 2, 0, 0))
	_forme(_corps, tronc, clair, Vector3(0, -0.06, -0.05), Vector3(0.85, 0.8, 0.8), Vector3(PI / 2, 0, 0))

	_tete = Node3D.new()
	_tete.position = Vector3(0, 0.18, -0.55)
	_corps.add_child(_tete)
	var crane := SphereMesh.new()
	crane.radius = 0.16
	crane.height = 0.3
	_forme(_tete, crane, pelage, Vector3.ZERO)
	var museau := BoxMesh.new()
	museau.size = Vector3(0.12, 0.11, 0.24)
	_forme(_tete, museau, clair, Vector3(0, -0.04, -0.18))
	var truffe := SphereMesh.new()
	truffe.radius = 0.035
	truffe.height = 0.07
	_forme(_tete, truffe, sombre, Vector3(0, -0.01, -0.31))
	var oreille := PrismMesh.new()
	oreille.size = Vector3(0.08, 0.12, 0.04)
	_forme(_tete, oreille, pelage, Vector3(-0.08, 0.15, 0.02))
	_forme(_tete, oreille, pelage, Vector3(0.08, 0.15, 0.02))
	var oeil := SphereMesh.new()
	oeil.radius = 0.022
	oeil.height = 0.044
	var yeux := _mat(Color(0.9, 0.7, 0.2))
	yeux.emission_enabled = true
	yeux.emission = Color(0.9, 0.6, 0.1)
	yeux.emission_energy_multiplier = 0.6
	_forme(_tete, oeil, yeux, Vector3(-0.07, 0.04, -0.12))
	_forme(_tete, oeil, yeux, Vector3(0.07, 0.04, -0.12))

	var patte := CapsuleMesh.new()
	patte.radius = 0.05
	patte.height = 0.55
	for pos in [Vector3(-0.12, -0.05, -0.38), Vector3(0.12, -0.05, -0.38),
			Vector3(-0.12, -0.05, 0.38), Vector3(0.12, -0.05, 0.38)]:
		var hanche := Node3D.new()
		hanche.position = pos
		_corps.add_child(hanche)
		_forme(hanche, patte, pelage, Vector3(0, -0.27, 0))
		_pattes.append(hanche)

	_queue = Node3D.new()
	_queue.position = Vector3(0, 0.08, 0.55)
	_corps.add_child(_queue)
	var q := CapsuleMesh.new()
	q.radius = 0.05
	q.height = 0.5
	_forme(_queue, q, pelage, Vector3(0, -0.12, 0.18), Vector3.ONE, Vector3(-0.9, 0, 0))


## Loups invoqués : pelage plus clair et lueur bleue de la Vigie.
func colorer(allie: bool) -> void:
	if not allie or _materiaux.is_empty():
		return
	_materiaux[0].albedo_color = Color(0.75, 0.78, 0.82)
	_materiaux[0].emission_enabled = true
	_materiaux[0].emission = Color(0.2, 0.7, 0.9)
	_materiaux[0].emission_energy_multiplier = 0.4


func mordre() -> void:
	_morsure = 0.3


func animer(delta: float, vitesse: float, mort: bool) -> void:
	if _corps == null:
		return
	if mort:
		# Couché sur le flanc.
		_corps.rotation.z = lerpf(_corps.rotation.z, PI / 2, 0.15)
		_corps.position.y = lerpf(_corps.position.y, 0.25, 0.15)
		return
	_corps.rotation.z = lerpf(_corps.rotation.z, 0.0, 0.2)
	_corps.position.y = 0.62
	_phase += delta * (3.0 + vitesse * 2.2)
	var allure := clampf(vitesse / 6.0, 0.0, 1.0)
	var swing := sin(_phase) * 0.7 * allure
	_pattes[0].rotation.x = swing
	_pattes[1].rotation.x = -swing
	_pattes[2].rotation.x = -swing
	_pattes[3].rotation.x = swing
	_corps.position.y += absf(sin(_phase)) * 0.05 * allure
	_queue.rotation.y = sin(_phase * 0.5) * 0.3
	_morsure = maxf(0.0, _morsure - delta)
	_tete.rotation.x = sin(_morsure / 0.3 * PI) * 0.5
	_tete.position.z = -0.55 - sin(_morsure / 0.3 * PI) * 0.15
