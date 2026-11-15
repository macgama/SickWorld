@tool
extends Node3D
## Apparence du poulpe (île de Grèce), sculptée en code : un manteau en forme de
## sac, deux gros yeux, et huit bras faits de segments qui ondulent chacun à son rythme.
## Le poulpe fracturé de la crique est bien plus grand qu'un vrai (près de 4 m de bras).
##
## Appelé par apparence_loup.gd (même interface : animer, mordre, colorer).

var _corps: Node3D
var _manteau: Node3D
var _bras: Array = []
var _phase := 0.0
var _frappe := 0.0
static var _peau: StandardMaterial3D


func _ready() -> void:
	_construire()


static func _materiau() -> StandardMaterial3D:
	if _peau != null:
		return _peau
	_peau = StandardMaterial3D.new()
	# Une peau rouge-brun marbrée, un peu luisante (le poulpe change de couleur).
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = 0.06
	t.noise = n
	var g := Gradient.new()
	g.set_color(0, Color(0.36, 0.12, 0.09))
	g.set_color(1, Color(0.72, 0.38, 0.26))
	t.color_ramp = g
	_peau.albedo_texture = t
	_peau.roughness = 0.35
	_peau.uv1_scale = Vector3(2, 2, 2)
	return _peau


func _construire() -> void:
	for enfant in get_children():
		enfant.free()
	_bras.clear()
	var peau := _materiau()
	_corps = Node3D.new()
	_corps.name = "Corps"
	# Il se tient sur le haut-fond, le corps au-dessus de l'eau.
	_corps.position.y = 0.35
	add_child(_corps)
	# Le manteau (la « tête » en sac), penché vers l'arrière.
	_manteau = Node3D.new()
	_manteau.position = Vector3(0, 0.8, 0.3)
	_manteau.rotation.x = 1.15
	_corps.add_child(_manteau)
	var sac := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.55
	s.height = 1.6
	s.radial_segments = 16
	s.rings = 10
	sac.mesh = s
	sac.material_override = peau
	sac.position.y = 0.55
	_manteau.add_child(sac)
	# Les yeux, de chaque côté, à la base du manteau.
	var oeil_m := StandardMaterial3D.new()
	oeil_m.albedo_color = Color(0.85, 0.75, 0.35)
	oeil_m.roughness = 0.2
	var pupille_m := StandardMaterial3D.new()
	pupille_m.albedo_color = Color(0.02, 0.02, 0.02)
	for cote: float in [-1.0, 1.0]:
		var oeil := MeshInstance3D.new()
		var so := SphereMesh.new()
		so.radius = 0.12
		so.height = 0.24
		oeil.mesh = so
		oeil.material_override = oeil_m
		oeil.position = Vector3(cote * 0.4, 0.78, -0.2)
		_corps.add_child(oeil)
		var pupille := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.03, 0.05, 0.14)
		pupille.mesh = b
		pupille.material_override = pupille_m
		pupille.position = Vector3(cote * 0.1, 0, -0.03)
		oeil.add_child(pupille)
	# Les huit bras : chacun une chaîne de 7 segments qui s'amincissent.
	for k in 8:
		var a := TAU * (k + 0.5) / 8.0
		var racine := Node3D.new()
		racine.position = Vector3(cos(a) * 0.3, 0.45, sin(a) * 0.3)
		racine.rotation.y = -a + PI / 2
		_corps.add_child(racine)
		var segments: Array = []
		var parent := racine
		for j in 8:
			var seg := Node3D.new()
			seg.position = Vector3(0, 0, -0.34) if j > 0 else Vector3.ZERO
			parent.add_child(seg)
			var mi := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.19 * (1.0 - j / 8.6)
			c.bottom_radius = 0.19 * (1.0 - (j + 1) / 8.6)
			c.height = 0.37
			c.radial_segments = 8
			mi.mesh = c
			mi.material_override = peau
			mi.rotation.x = -PI / 2
			mi.position.z = -0.17
			seg.add_child(mi)
			# Les ventouses, pâles, sous le bras.
			if j < 7:
				var ventouse := MeshInstance3D.new()
				var v := CylinderMesh.new()
				v.top_radius = c.bottom_radius * 0.55
				v.bottom_radius = c.bottom_radius * 0.55
				v.height = 0.04
				v.radial_segments = 8
				ventouse.mesh = v
				ventouse.material_override = _materiau_ventouse()
				ventouse.position = Vector3(0, -c.bottom_radius * 0.85, -0.17)
				seg.add_child(ventouse)
			segments.append(seg)
			parent = seg
		_bras.append(segments)
	_poser(0.0, 0.0, 0.0)


static var _ventouse: StandardMaterial3D


static func _materiau_ventouse() -> StandardMaterial3D:
	if _ventouse == null:
		_ventouse = StandardMaterial3D.new()
		_ventouse.albedo_color = Color(0.93, 0.78, 0.68)
		_ventouse.roughness = 0.4
	return _ventouse


## Place les bras : les quatre de devant se dressent et s'enroulent (menaçants),
## ceux de derrière s'étalent sur l'eau. « coup » lève les deux bras qui frappent.
func _poser(phase: float, coup: float, t: float) -> void:
	for k in _bras.size():
		var segments: Array = _bras[k]
		var a := TAU * (k + 0.5) / 8.0
		# sin(a) < 0 : bras tournés vers l'avant (vers -Z, là où il regarde).
		var dresse := clampf(-sin(a) * 1.4, 0.0, 1.0)
		var devant := 1.0 if k in [5, 6] else 0.0
		for j in segments.size():
			var seg: Node3D = segments[j]
			var onde := sin(phase * 1.3 - j * 0.7 + k * 1.1)
			var repos := lerpf(-0.12 if j == 0 else 0.06, 0.35 if j == 0 else 0.16, dresse)
			seg.rotation.x = onde * 0.18 + repos + devant * coup * (0.7 if j < 2 else -0.2)
			seg.rotation.y = sin(phase * 0.9 - j * 0.5 + k * 2.3) * 0.16


func colorer(allie: bool) -> void:
	if not allie:
		return
	var lueur := StandardMaterial3D.new()
	lueur.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lueur.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	lueur.albedo_color = Color(0.1, 0.35, 0.45)
	for mi in find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = lueur


func mordre() -> void:
	_frappe = 0.6


func animer(delta: float, vitesse: float, mort: bool) -> void:
	if _corps == null:
		return
	var t := Time.get_ticks_msec() * 0.001
	if mort:
		# Il s'affaisse, les bras à plat.
		_corps.position.y = lerpf(_corps.position.y, -0.35, 0.08)
		_manteau.rotation.x = lerpf(_manteau.rotation.x, 1.3, 0.06)
		for segments in _bras:
			for seg in segments:
				seg.rotation.x = lerpf(seg.rotation.x, 0.0, 0.1)
		return
	_phase += delta * (1.5 + vitesse * 1.2)
	_frappe = maxf(0.0, _frappe - delta)
	var coup := sin(clampf(_frappe / 0.6, 0.0, 1.0) * PI)
	# Le manteau gonfle et dégonfle (il respire).
	_manteau.scale = Vector3.ONE * (1.0 + sin(t * 1.8) * 0.04)
	_corps.position.y = 0.35 + sin(t * 1.1) * 0.05
	_poser(_phase, coup, t)
