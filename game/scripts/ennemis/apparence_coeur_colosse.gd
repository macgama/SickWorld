extends Node3D
## Le cœur du Colosse (île de Rome, boss du donjon du Colisée) : la fracture majeure qui
## s'est logée dans la statue de bronze. Un grand cristal violet qui a fendu le socle, à
## ses pieds, entouré d'éclats qui tournent. C'est lui qu'on frappe ; la statue, elle, est
## un décor du Colisée (voir colisee.gd), qui bouge au rythme du combat.

const VIOLET := Color(0.62, 0.3, 1.0)

var _cristal: Node3D
var _eclats: Array[Node3D] = []
var _materiau: StandardMaterial3D
var _temps := 0.0
var _coup := 0.0
var _mort := 0.0


func _ready() -> void:
	for enfant in get_children():
		enfant.free()
	_materiau = StandardMaterial3D.new()
	_materiau.albedo_color = Color(0.45, 0.2, 0.85, 0.85)
	_materiau.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materiau.emission_enabled = true
	_materiau.emission = VIOLET
	_materiau.emission_energy_multiplier = 2.5
	_materiau.roughness = 0.1
	_materiau.metallic_specular = 1.0
	_cristal = Node3D.new()
	add_child(_cristal)
	for k in 5:
		var pointe := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = 0.5 - k * 0.05
		c.height = 3.2 - k * 0.35
		c.radial_segments = 5
		pointe.mesh = c
		pointe.material_override = _materiau
		pointe.position = Vector3(cos(k * 1.3) * 0.5 * float(k > 0), c.height * 0.5, sin(k * 1.3) * 0.5 * float(k > 0))
		pointe.rotation = Vector3(sin(k * 2.1) * 0.35 * float(k > 0), 0, cos(k * 1.7) * 0.35 * float(k > 0))
		_cristal.add_child(pointe)
	for k in 8:
		var eclat := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.18, 0.4, 0.06)
		eclat.mesh = b
		eclat.material_override = _materiau
		add_child(eclat)
		_eclats.append(eclat)
	var lumiere := OmniLight3D.new()
	lumiere.light_color = VIOLET
	lumiere.light_energy = 3.0
	lumiere.omni_range = 9.0
	lumiere.position = Vector3(0, 1.8, 0)
	add_child(lumiere)


func colorer(_allie: bool) -> void:
	pass


func mordre() -> void:
	_coup = 0.4


func animer(delta: float, _vitesse: float, mort: bool) -> void:
	_temps += delta
	_coup = maxf(0.0, _coup - delta)
	_mort = minf(1.0, _mort + delta) if mort else 0.0
	if _cristal == null:
		return
	var pulsation := 1.0 + sin(_temps * 3.0) * 0.04 + _coup * 0.3
	_cristal.scale = Vector3.ONE * pulsation * (1.0 - _mort * 0.9)
	_materiau.emission_energy_multiplier = (2.5 + sin(_temps * 3.0) * 0.8 + _coup * 4.0) * (1.0 - _mort)
	for k in _eclats.size():
		var a := _temps * 0.8 + k * TAU / _eclats.size()
		_eclats[k].position = Vector3(cos(a) * 1.6, 1.2 + sin(_temps * 1.5 + k) * 0.5, sin(a) * 1.6)
		_eclats[k].rotation = Vector3(_temps + k, _temps * 1.3, 0)
		_eclats[k].visible = not mort
