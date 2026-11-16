extends Node3D
## L'anomalie de la Faille de l'Agora (île de Grèce) : le Mur de haut-parleurs.
## Une tour de baffles modernes empilés de travers, ficelés de câbles, que la fracture a
## fait pousser au milieu de l'Agora comme un arbre de cristal. Elle hurle : sa voix couvre
## celle des joueurs (voir le « cri » dans data/grece_evenements.json).
## Tout est fait de formes simples, sculptées en code.

const VIOLET := Color(0.62, 0.3, 1.0)

var _tour: Node3D
var _membranes: Array[MeshInstance3D] = []
var _diodes: StandardMaterial3D
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
	_tour = Node3D.new()
	add_child(_tour)
	var caisson := _mat(Color(0.07, 0.07, 0.08), 0.6)
	var grille := _mat(Color(0.16, 0.16, 0.17), 0.45, 0.4)
	var membrane := _mat(Color(0.1, 0.1, 0.11), 0.35)
	_diodes = _mat(Color(0.25, 0.9, 1.0), 0.3)
	_diodes.emission_enabled = true
	_diodes.emission = Color(0.25, 0.9, 1.0)
	_diodes.emission_energy_multiplier = 2.0
	_cristal = _mat(VIOLET, 0.15)
	_cristal.emission_enabled = true
	_cristal.emission = VIOLET
	_cristal.emission_energy_multiplier = 1.6
	_cristal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cristal.albedo_color.a = 0.85
	# Six baffles empilés, de plus en plus petits, un peu de travers.
	var y := 0.0
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 4381
	for k in 6:
		var largeur := 1.9 - k * 0.2
		var haut := 1.0 - k * 0.07
		var boite := Node3D.new()
		boite.position = Vector3(hasard.randf_range(-0.12, 0.12), y + haut * 0.5, hasard.randf_range(-0.1, 0.1))
		boite.rotation = Vector3(hasard.randf_range(-0.05, 0.05), hasard.randf_range(-0.5, 0.5), hasard.randf_range(-0.06, 0.06))
		_tour.add_child(boite)
		var b := BoxMesh.new()
		b.size = Vector3(largeur, haut, largeur * 0.62)
		_piece(boite, b, caisson, Vector3.ZERO)
		var g := BoxMesh.new()
		g.size = Vector3(largeur * 0.94, haut * 0.9, 0.02)
		_piece(boite, g, grille, Vector3(0, 0, largeur * 0.31 + 0.01))
		# Deux haut-parleurs (un grand, un petit) sur chaque face avant.
		for j in 2:
			var r := haut * (0.34 if j == 0 else 0.18)
			var c := CylinderMesh.new()
			c.top_radius = r
			c.bottom_radius = r * 0.55
			c.height = 0.12
			var m := _piece(boite, c, membrane, Vector3((-0.22 if j == 0 else 0.42) * largeur, 0, largeur * 0.31 + 0.05),
					Vector3(PI / 2, 0, 0))
			_membranes.append(m)
			var cache := SphereMesh.new()
			cache.radius = r * 0.25
			cache.height = r * 0.3
			_piece(m, cache, grille, Vector3(0, 0.07, 0))
		var d := BoxMesh.new()
		d.size = Vector3(0.05, 0.05, 0.02)
		_piece(boite, d, _diodes, Vector3(largeur * 0.4, -haut * 0.38, largeur * 0.31 + 0.03))
		y += haut * 0.96
	# Les câbles qui pendent, et les cristaux de la fracture qui percent les caissons.
	var cable := _mat(Color(0.03, 0.03, 0.03), 0.7)
	for k in 5:
		var c := CylinderMesh.new()
		c.top_radius = 0.025
		c.bottom_radius = 0.025
		c.height = y * hasard.randf_range(0.4, 0.9)
		_piece(_tour, c, cable, Vector3(hasard.randf_range(-0.9, 0.9), c.height * 0.5, hasard.randf_range(-0.7, 0.7)),
				Vector3(hasard.randf_range(-0.15, 0.15), 0, hasard.randf_range(-0.15, 0.15)))
	for k in 9:
		var p := PrismMesh.new()
		p.size = Vector3(0.28, hasard.randf_range(0.6, 1.4), 0.28)
		var a := hasard.randf() * TAU
		_piece(_tour, p, _cristal, Vector3(cos(a) * 0.8, hasard.randf_range(0.3, y), sin(a) * 0.6),
				Vector3(hasard.randf_range(-0.9, 0.9), a, hasard.randf_range(-0.9, 0.9)))
	# L'onde du cri : un anneau qui s'élargit sur le sol.
	_onde_materiau = _mat(Color(VIOLET, 0.0), 0.2)
	_onde_materiau.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_onde_materiau.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_onde_materiau.cull_mode = BaseMaterial3D.CULL_DISABLED
	_onde = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.92
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


## Le souffle avant le cri : les membranes rougeoient, la tour gonfle.
func preparer_cri() -> void:
	_souffle = 2.0


func crier() -> void:
	_souffle = 0.0
	_cri = 1.2


func animer(delta: float, _vitesse: float, mort: bool) -> void:
	_temps += delta
	if mort:
		# La tour s'écroule de côté et s'éteint.
		_chute = minf(1.0, _chute + delta * 0.8)
		_tour.rotation.z = lerpf(0.0, 1.35, _chute * _chute)
		_tour.position.y = -0.4 * _chute
		_diodes.emission_energy_multiplier = 0.0
		_cristal.emission_energy_multiplier = lerpf(1.6, 0.1, _chute)
		_onde.visible = false
		return
	_souffle = maxf(0.0, _souffle - delta)
	_coup = maxf(0.0, _coup - delta)
	var vibre := 0.03 * sin(_temps * 42.0)
	var gonfle := 0.0
	if _souffle > 0.0:
		gonfle = (2.0 - _souffle) * 0.04
		vibre *= 3.0
	if _cri > 0.0:
		_cri -= delta
		vibre = 0.12 * sin(_temps * 70.0)
		var avance := 1.0 - maxf(_cri, 0.0) / 1.2
		_onde.visible = true
		_onde.scale = Vector3.ONE * lerpf(1.5, 20.0, avance)
		_onde_materiau.albedo_color = Color(VIOLET, 0.7 * (1.0 - avance))
		if _cri <= 0.0:
			_onde.visible = false
	for m in _membranes:
		m.scale = Vector3.ONE * (1.0 + vibre + gonfle * 2.0 + _coup * 0.4)
	_tour.scale = Vector3(1.0 + gonfle, 1.0 + gonfle * 0.5, 1.0 + gonfle)
	var rouge := _souffle > 0.0 or _cri > 0.0
	_diodes.emission = Color(1.0, 0.2, 0.15) if rouge else Color(0.25, 0.9, 1.0)
	_diodes.albedo_color = _diodes.emission
	_diodes.emission_energy_multiplier = 2.0 + (2.0 * absf(sin(_temps * 12.0)) if rouge else 0.6 * absf(sin(_temps * 2.0)))
	_cristal.emission_energy_multiplier = 1.4 + 0.5 * sin(_temps * 3.0) + (2.0 if _cri > 0.0 else 0.0)


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
