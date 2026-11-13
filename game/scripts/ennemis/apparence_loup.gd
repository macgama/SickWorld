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
var _hauteur_corps := 0.62


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
	var parent := get_parent()
	if parent != null and String(parent.get("type_ennemi")).begins_with("renne"):
		_construire_renne()
		return
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


## Renne : plus grand, longues pattes, cou épais au poitrail clair, bois ramifiés.
func _construire_renne() -> void:
	var pelage := _mat(Color(0.36, 0.3, 0.24))
	var clair := _mat(Color(0.74, 0.7, 0.62))
	var sombre := _mat(Color(0.07, 0.06, 0.05))
	var bois := _mat(Color(0.55, 0.47, 0.36))
	bois.roughness = 0.7
	_corps = Node3D.new()
	_corps.position = Vector3(0, 1.0, 0)
	add_child(_corps)
	var tronc := CapsuleMesh.new()
	tronc.radius = 0.3
	tronc.height = 1.45
	_forme(_corps, tronc, pelage, Vector3.ZERO, Vector3(1, 1.05, 1), Vector3(PI / 2, 0, 0))
	_forme(_corps, tronc, clair, Vector3(0, -0.09, 0.05), Vector3(0.88, 0.8, 0.82), Vector3(PI / 2, 0, 0))
	# Cou épais et crinière claire.
	var cou := CapsuleMesh.new()
	cou.radius = 0.15
	cou.height = 0.7
	_forme(_corps, cou, clair, Vector3(0, 0.25, -0.62), Vector3.ONE, Vector3(-0.75, 0, 0))
	_tete = Node3D.new()
	_tete.position = Vector3(0, 0.5, -0.88)
	_corps.add_child(_tete)
	var crane := CapsuleMesh.new()
	crane.radius = 0.11
	crane.height = 0.5
	_forme(_tete, crane, pelage, Vector3(0, 0, -0.1), Vector3.ONE, Vector3(PI / 2 + 0.35, 0, 0))
	var truffe := SphereMesh.new()
	truffe.radius = 0.06
	truffe.height = 0.1
	_forme(_tete, truffe, sombre, Vector3(0, -0.11, -0.33))
	var oreille := PrismMesh.new()
	oreille.size = Vector3(0.07, 0.14, 0.03)
	_forme(_tete, oreille, pelage, Vector3(-0.1, 0.08, 0.06), Vector3.ONE, Vector3(0, 0, 0.9))
	_forme(_tete, oreille, pelage, Vector3(0.1, 0.08, 0.06), Vector3.ONE, Vector3(0, 0, -0.9))
	var oeil := SphereMesh.new()
	oeil.radius = 0.02
	oeil.height = 0.04
	_forme(_tete, oeil, sombre, Vector3(-0.09, 0.0, -0.1))
	_forme(_tete, oeil, sombre, Vector3(0.09, 0.0, -0.1))
	# Bois : une perche courbée de chaque côté, avec des andouillers.
	var perche := CylinderMesh.new()
	perche.top_radius = 0.015
	perche.bottom_radius = 0.03
	perche.height = 0.55
	var pointe := CylinderMesh.new()
	pointe.top_radius = 0.008
	pointe.bottom_radius = 0.02
	pointe.height = 0.24
	for cote in [-1.0, 1.0]:
		var base := Node3D.new()
		base.position = Vector3(0.07 * cote, 0.1, 0.05)
		base.rotation = Vector3(0.5, 0, -0.45 * cote)
		_tete.add_child(base)
		_forme(base, perche, bois, Vector3(0, 0.27, 0))
		var haut := Node3D.new()
		haut.position = Vector3(0, 0.52, 0)
		haut.rotation = Vector3(-0.9, 0, 0.2 * cote)
		base.add_child(haut)
		_forme(haut, perche, bois, Vector3(0, 0.25, 0), Vector3(0.8, 0.9, 0.8))
		for k in 3:
			var andouiller := Node3D.new()
			andouiller.position = Vector3(0, 0.15 + k * 0.17, 0)
			andouiller.rotation = Vector3(-0.9 + k * 0.25, 0, (0.6 + k * 0.15) * cote)
			(base if k < 2 else haut).add_child(andouiller)
			_forme(andouiller, pointe, bois, Vector3(0, 0.11, 0))
		# Andouiller de front (la « pelle »).
		var pelle := Node3D.new()
		pelle.position = Vector3(0, 0.08, 0)
		pelle.rotation = Vector3(-1.6, 0, 0)
		base.add_child(pelle)
		_forme(pelle, pointe, bois, Vector3(0, 0.11, 0))
	var patte := CapsuleMesh.new()
	patte.radius = 0.055
	patte.height = 0.95
	for pos in [Vector3(-0.16, -0.08, -0.5), Vector3(0.16, -0.08, -0.5),
			Vector3(-0.16, -0.08, 0.5), Vector3(0.16, -0.08, 0.5)]:
		var hanche := Node3D.new()
		hanche.position = pos
		_corps.add_child(hanche)
		_forme(hanche, patte, pelage, Vector3(0, -0.45, 0))
		var sabot := CylinderMesh.new()
		sabot.top_radius = 0.06
		sabot.bottom_radius = 0.08
		sabot.height = 0.08
		_forme(hanche, sabot, sombre, Vector3(0, -0.9, 0))
		_pattes.append(hanche)
	_queue = Node3D.new()
	_queue.position = Vector3(0, 0.12, 0.72)
	_corps.add_child(_queue)
	var q := SphereMesh.new()
	q.radius = 0.08
	q.height = 0.16
	_forme(_queue, q, clair, Vector3(0, 0, 0.04))
	_hauteur_corps = 1.0


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
		_corps.position.y = lerpf(_corps.position.y, 0.25 * _hauteur_corps / 0.62, 0.15)
		return
	_corps.rotation.z = lerpf(_corps.rotation.z, 0.0, 0.2)
	_corps.position.y = _hauteur_corps
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
	if _hauteur_corps < 0.7:
		_tete.position.z = -0.55 - sin(_morsure / 0.3 * PI) * 0.15
