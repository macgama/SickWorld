extends Node3D
## L'anomalie du Carrefour fou (île de Rome, événement de la voie Appienne) : un morceau de
## carrefour moderne que la fracture a fait pousser sur la voie romaine. Un mât de feux
## tricolores tordu, couvert de panneaux routiers (sens interdit, flèches, stop) plantés de
## travers, et un cristal violet à la base. Quand il « crie », tous ses panneaux tournent et
## les joueurs proches ont les directions inversées (voir data/rome_evenements.json).
## « petit » : un simple feu tricolore qui sautille (les sbires du carrefour).
## Tout est fait de formes simples, sculptées en code.

const VIOLET := Color(0.62, 0.3, 1.0)

var petit := false

var _mat_feux: Array[StandardMaterial3D] = []
var _corps: Node3D
var _panneaux: Array[Node3D] = []
var _cristal: StandardMaterial3D
var _onde: MeshInstance3D
var _onde_materiau: StandardMaterial3D
var _temps := 0.0
var _souffle := 0.0
var _cri := 0.0
var _coup := 0.0
var _chute := 0.0


func _ready() -> void:
	for enfant in get_children():
		enfant.free()
	_corps = Node3D.new()
	add_child(_corps)
	var metal := _mat(Color(0.32, 0.34, 0.33), 0.5, 0.6)
	var noir := _mat(Color(0.05, 0.05, 0.05), 0.6)
	_cristal = _mat(VIOLET, 0.15)
	_cristal.emission_enabled = true
	_cristal.emission = VIOLET
	_cristal.emission_energy_multiplier = 1.8
	var e := 0.55 if petit else 1.0
	var haut := (2.2 if petit else 5.2)
	# Le mât, un peu penché, et son pied dans un bloc de bitume arraché.
	_piece(_corps, _cylindre(0.08 * e + 0.02, 0.11 * e + 0.02, haut), metal, Vector3(0, haut * 0.5, 0), Vector3(0, 0, 0.06))
	var bitume := BoxMesh.new()
	bitume.size = Vector3(1.6, 0.35, 1.4) * e
	_piece(_corps, bitume, _mat(Color(0.12, 0.12, 0.13), 0.95), Vector3(0, 0.15, 0), Vector3(0.1, 0.4, -0.08))
	# Une bande blanche de passage piéton, collée au bitume.
	for k in 3:
		var bande := BoxMesh.new()
		bande.size = Vector3(0.22, 0.02, 1.2) * e
		_piece(_corps, bande, _mat(Color(0.9, 0.9, 0.86), 0.7), Vector3((-0.45 + k * 0.45) * e, 0.34 * e, 0), Vector3(0.1, 0.4, -0.08))
	# Le boîtier des feux et ses trois lampes (rouge, orange, vert).
	var boitier := BoxMesh.new()
	boitier.size = Vector3(0.42, 1.25, 0.36) * e
	var y_feux := haut - 0.7 * e
	_piece(_corps, boitier, noir, Vector3(0, y_feux, 0))
	var couleurs := [Color(1.0, 0.15, 0.1), Color(1.0, 0.6, 0.1), Color(0.2, 1.0, 0.35)]
	for k in 3:
		var m := _mat(couleurs[k], 0.3)
		m.emission_enabled = true
		m.emission = couleurs[k]
		m.emission_energy_multiplier = 0.2
		_mat_feux.append(m)
		var lampe := SphereMesh.new()
		lampe.radius = 0.13 * e
		lampe.height = 0.2 * e
		_piece(_corps, lampe, m, Vector3(0, y_feux + (0.38 - k * 0.38) * e, -0.18 * e))
	if not petit:
		# Les panneaux plantés tout autour du mât (sens interdit, stop, flèches, cédez).
		var formes := [["rond", Color(0.85, 0.08, 0.08)], ["octo", Color(0.8, 0.06, 0.06)], ["carre", Color(0.1, 0.3, 0.8)],
				["triangle", Color(0.95, 0.95, 0.9)], ["rond", Color(0.1, 0.3, 0.8)], ["carre", Color(0.1, 0.55, 0.25)]]
		for k in formes.size():
			var pivot := Node3D.new()
			pivot.position = Vector3(0, 1.6 + k * 0.55, 0)
			pivot.rotation.y = k * 1.1
			_corps.add_child(pivot)
			_piece(pivot, _cylindre(0.03, 0.03, 0.9), metal, Vector3(0.45, 0, 0), Vector3(0, 0, PI * 0.5))
			var plaque: Mesh
			match String(formes[k][0]):
				"rond", "octo":
					plaque = _cylindre(0.38, 0.38, 0.03, 8 if formes[k][0] == "octo" else 20)
				"triangle":
					plaque = _cylindre(0.45, 0.45, 0.03, 3)
				_:
					var b := BoxMesh.new()
					b.size = Vector3(0.6, 0.03, 0.6)
					plaque = b
			_piece(pivot, plaque, _mat(formes[k][1], 0.5), Vector3(0.95, 0, 0), Vector3(PI * 0.5, 0, 0))
			# La barre blanche du sens interdit, ou la flèche.
			var barre := BoxMesh.new()
			barre.size = Vector3(0.44, 0.1, 0.035)
			_piece(pivot, barre, _mat(Color(0.95, 0.95, 0.95), 0.5), Vector3(0.95, 0, 0.025))
			_panneaux.append(pivot)
	# Le cristal de la fracture, qui a fendu le bitume.
	for k in 4:
		var pointe := _cylindre(0.0, 0.22 * e, 1.1 * e, 5)
		_piece(_corps, pointe, _cristal, Vector3(cos(k * 1.6) * 0.45 * e, 0.6 * e, sin(k * 1.6) * 0.45 * e),
				Vector3(sin(k * 2.0) * 0.5, 0, cos(k * 1.4) * 0.5))
	_onde_materiau = _mat(Color(VIOLET, 0.6), 0.2)
	_onde_materiau.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_onde_materiau.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_onde_materiau.cull_mode = BaseMaterial3D.CULL_DISABLED
	_onde = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.9
	t.outer_radius = 1.0
	_onde.mesh = t
	_onde.material_override = _onde_materiau
	_onde.position.y = 0.6
	_onde.visible = false
	add_child(_onde)


func colorer(_allie: bool) -> void:
	pass


func mordre() -> void:
	_coup = 0.35


## Avant le cri : tous les feux clignotent en orange.
func preparer_cri() -> void:
	_souffle = 2.0


func crier() -> void:
	_souffle = 0.0
	_cri = 1.2


func animer(delta: float, vitesse: float, mort: bool) -> void:
	_temps += delta
	if mort:
		_chute = minf(1.0, _chute + delta * 0.8)
		_corps.rotation.z = lerpf(0.0, 1.4, _chute * _chute)
		for m in _mat_feux:
			m.emission_energy_multiplier = 0.0
		_cristal.emission_energy_multiplier = lerpf(1.8, 0.1, _chute)
		_onde.visible = false
		return
	_souffle = maxf(0.0, _souffle - delta)
	_coup = maxf(0.0, _coup - delta)
	# Le cycle des feux, déréglé : rouge, vert, orange, au hasard du temps.
	var actif := int(_temps * (2.5 if _souffle > 0.0 else 0.8)) % 3
	for k in _mat_feux.size():
		var allume := (k == 1) if _souffle > 0.0 else (k == actif)
		if _souffle > 0.0:
			allume = allume and fmod(_temps, 0.3) < 0.15
		_mat_feux[k].emission_energy_multiplier = 4.0 if allume else 0.15
	# Les panneaux tournent lentement autour du mât ; très vite pendant le cri.
	for k in _panneaux.size():
		_panneaux[k].rotation.y += delta * (6.0 if _cri > 0.0 else 0.25) * (1.0 if k % 2 == 0 else -1.0)
	if _cri > 0.0:
		_cri -= delta
		var avance := 1.0 - maxf(_cri, 0.0) / 1.2
		_onde.visible = true
		_onde.scale = Vector3.ONE * lerpf(1.5, 18.0, avance)
		_onde_materiau.albedo_color = Color(VIOLET, 0.7 * (1.0 - avance))
		if _cri <= 0.0:
			_onde.visible = false
	# Le petit feu sautille quand il avance ; le grand tangue.
	if petit:
		_corps.position.y = absf(sin(_temps * 9.0)) * 0.25 * clampf(vitesse, 0.0, 1.0)
	_corps.rotation.x = 0.04 * sin(_temps * 1.7) - _coup * 0.4
	_cristal.emission_energy_multiplier = 1.6 + 0.5 * sin(_temps * 3.0) + (2.0 if _cri > 0.0 else 0.0)


func _cylindre(haut: float, bas: float, longueur: float, segments := 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = haut
	c.bottom_radius = bas
	c.height = longueur
	c.radial_segments = segments
	return c


func _mat(couleur: Color, rugosite := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = rugosite
	m.metallic = metal
	return m


func _piece(parent: Node3D, maillage: Mesh, materiau: Material, p: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = maillage
	mi.material_override = materiau
	mi.position = p
	mi.rotation = rot
	parent.add_child(mi)
	return mi
