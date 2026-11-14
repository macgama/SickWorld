@tool
extends Node3D
## Apparence des bêtes du Nil (île d'Égypte) : crocodile et hippopotame.
##
## Aucun modèle gratuit et réaliste n'étant encore choisi pour ces animaux, ils
## sont sculptés ici dans le code : le corps est une suite de sections ovales
## (comme les couples d'une coque de bateau) qu'on relie entre elles. Chaque
## morceau (tête, mâchoire, queue, pattes) est un nœud séparé pour pouvoir
## l'animer : la queue ondule, les pattes rament sur les côtés, la gueule s'ouvre.
##
## Appelé par apparence_loup.gd (même interface : animer, mordre, colorer).

## « crocodile » ou « hippopotame ».
@export var espece := "crocodile":
	set(valeur):
		espece = valeur
		if is_inside_tree():
			_construire()

var _corps: Node3D
var _tete: Node3D
var _machoire: Node3D
var _queue: Array[Node3D] = []
var _pattes: Array[Node3D] = []
var _oreilles: Array[Node3D] = []
var _phase := 0.0
var _morsure := 0.0
var _hauteur := 0.0
static var _materiaux := {}


func _ready() -> void:
	_construire()


func _construire() -> void:
	for enfant in get_children():
		enfant.free()
	_queue.clear()
	_pattes.clear()
	_oreilles.clear()
	_corps = Node3D.new()
	_corps.name = "Corps"
	add_child(_corps)
	if espece == "hippopotame":
		_construire_hippopotame()
	else:
		_construire_crocodile()


# --- Matériaux -------------------------------------------------------------------------

## Texture de bruit « cellulaire » : de petites écailles (crocodile) ou des plis (hippopotame).
static func _bruit_cellules(graine: int, frequence: float, normale: bool, couleurs: Array) -> NoiseTexture2D:
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.generate_mipmaps = true
	var b := FastNoiseLite.new()
	b.seed = graine
	b.noise_type = FastNoiseLite.TYPE_CELLULAR
	b.frequency = frequence
	b.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	b.fractal_type = FastNoiseLite.FRACTAL_NONE
	t.noise = b
	if normale:
		t.as_normal_map = true
		t.bump_strength = 9.0
	else:
		var g := Gradient.new()
		g.set_color(0, couleurs[0])
		g.set_color(1, couleurs[1])
		t.color_ramp = g
	return t


static func _materiau(cle: String) -> StandardMaterial3D:
	if _materiaux.has(cle):
		return _materiaux[cle]
	var m := StandardMaterial3D.new()
	match cle:
		"croco":
			# Écailles vert-olive très sombre, plus claires au creux des sillons.
			m.albedo_texture = _bruit_cellules(4, 0.045, false, [Color(0.36, 0.36, 0.24), Color(0.13, 0.15, 0.09)])
			m.normal_enabled = true
			m.normal_texture = _bruit_cellules(4, 0.045, true, [])
			m.normal_scale = 1.4
			m.roughness = 0.55
			m.uv1_triplanar = true
			m.uv1_scale = Vector3.ONE * 2.2
		"croco_ventre":
			m.albedo_texture = _bruit_cellules(9, 0.06, false, [Color(0.72, 0.68, 0.52), Color(0.5, 0.47, 0.34)])
			m.normal_enabled = true
			m.normal_texture = _bruit_cellules(9, 0.06, true, [])
			m.roughness = 0.6
			m.uv1_triplanar = true
			m.uv1_scale = Vector3.ONE * 2.5
		"hippo":
			# Peau gris-brun, mouillée et luisante, parcourue de plis.
			m.albedo_texture = _bruit_cellules(12, 0.012, false, [Color(0.46, 0.38, 0.36), Color(0.3, 0.26, 0.25)])
			m.normal_enabled = true
			m.normal_texture = _bruit_cellules(12, 0.012, true, [])
			m.normal_scale = 0.5
			m.roughness = 0.32
			m.metallic_specular = 0.6
			m.uv1_triplanar = true
			m.uv1_scale = Vector3.ONE * 0.8
		"hippo_rose":
			m.albedo_color = Color(0.68, 0.45, 0.42)
			m.roughness = 0.4
		"gueule":
			m.albedo_color = Color(0.62, 0.3, 0.3)
			m.roughness = 0.35
		"dent":
			m.albedo_color = Color(0.88, 0.84, 0.72)
			m.roughness = 0.4
		"oeil_croco":
			m.albedo_color = Color(0.75, 0.62, 0.15)
			m.roughness = 0.1
			m.emission_enabled = true
			m.emission = Color(0.4, 0.3, 0.05)
			m.emission_energy_multiplier = 0.4
		"oeil":
			m.albedo_color = Color(0.06, 0.05, 0.04)
			m.roughness = 0.08
	_materiaux[cle] = m
	return m


# --- Formes ----------------------------------------------------------------------------

## Relie des sections ovales le long de l'axe Z. Chaque section : [z, demi-largeur,
## demi-hauteur, hauteur du centre, aplatissement du ventre (0 = ovale, 1 = ventre plat)].
static func _loft(sections: Array, segments := 18) -> ArrayMesh:
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var anneaux: Array = []
	for s in sections:
		var anneau := PackedVector3Array()
		for k in segments:
			var a := TAU * k / segments
			var x := cos(a) * float(s[1])
			var y := sin(a) * float(s[2])
			if y < 0.0 and s.size() > 4:
				y *= 1.0 - float(s[4]) * 0.6
			anneau.append(Vector3(x, float(s[3]) + y, float(s[0])))
		anneaux.append(anneau)
	for i in anneaux.size() - 1:
		var a: PackedVector3Array = anneaux[i]
		var b: PackedVector3Array = anneaux[i + 1]
		for k in segments:
			var k2 := (k + 1) % segments
			outil.add_vertex(a[k])
			outil.add_vertex(b[k])
			outil.add_vertex(a[k2])
			outil.add_vertex(a[k2])
			outil.add_vertex(b[k])
			outil.add_vertex(b[k2])
	# Bouchons aux deux bouts.
	for bout in [0, anneaux.size() - 1]:
		var anneau: PackedVector3Array = anneaux[bout]
		var centre := Vector3.ZERO
		for v in anneau:
			centre += v
		centre /= anneau.size()
		for k in segments:
			var k2 := (k + 1) % segments
			if bout == 0:
				outil.add_vertex(centre)
				outil.add_vertex(anneau[k2])
				outil.add_vertex(anneau[k])
			else:
				outil.add_vertex(centre)
				outil.add_vertex(anneau[k])
				outil.add_vertex(anneau[k2])
	outil.generate_normals()
	return outil.commit()


func _piece(parent: Node3D, maillage: Mesh, materiau: Material, pos := Vector3.ZERO, rot := Vector3.ZERO,
		echelle := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = maillage
	mi.material_override = materiau
	mi.position = pos
	mi.rotation = rot
	mi.scale = echelle
	parent.add_child(mi)
	return mi


func _pivot(parent: Node3D, pos: Vector3, nom: String) -> Node3D:
	var n := Node3D.new()
	n.name = nom
	n.position = pos
	parent.add_child(n)
	return n


static func _sphere(rayon: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = rayon
	s.height = rayon * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s


static func _cone(rayon: float, hauteur: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = rayon
	c.height = hauteur
	c.radial_segments = 6
	c.rings = 1
	return c


static func _cylindre(haut: float, bas: float, hauteur: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = haut
	c.bottom_radius = bas
	c.height = hauteur
	c.radial_segments = 10
	return c


# --- Crocodile du Nil (environ 4 m) -----------------------------------------------------

func _construire_crocodile() -> void:
	_hauteur = 0.0
	var peau := _materiau("croco")
	var ventre := _materiau("croco_ventre")
	# Le tronc : large et plat, le ventre près du sol.
	_piece(_corps, _loft([
		[-0.55, 0.16, 0.12, 0.3, 0.6], [-0.3, 0.3, 0.17, 0.31, 0.8], [0.1, 0.4, 0.2, 0.32, 0.9],
		[0.6, 0.42, 0.21, 0.32, 0.9], [1.05, 0.34, 0.19, 0.31, 0.8], [1.3, 0.26, 0.17, 0.3, 0.6],
	]), peau)
	# Le ventre clair dépasse à peine sous le corps.
	_piece(_corps, _loft([[-0.35, 0.24, 0.06, 0.16, 1.0], [0.6, 0.36, 0.07, 0.15, 1.0], [1.2, 0.22, 0.06, 0.16, 1.0]]), ventre)
	# Les écailles osseuses du dos (les « scutes ») : deux rangées de petites crêtes.
	var crete := BoxMesh.new()
	crete.size = Vector3(0.06, 0.06, 0.12)
	for k in 12:
		var z := -0.35 + k * 0.14
		for cote in [-1.0, 1.0]:
			_piece(_corps, crete, peau, Vector3(cote * (0.09 + 0.06 * sin(k * 0.7)), 0.51, z), Vector3(0, 0, cote * 0.3))
	# La tête : un long museau qui s'affine, les yeux et narines tout en haut.
	_tete = _pivot(_corps, Vector3(0, 0.3, -0.5), "Tete")
	_piece(_tete, _loft([
		[0.05, 0.17, 0.11, 0.04, 0.7], [-0.2, 0.2, 0.1, 0.05, 0.7], [-0.45, 0.13, 0.07, 0.02, 0.6],
		[-0.75, 0.09, 0.055, 0.0, 0.5], [-0.82, 0.1, 0.05, 0.0, 0.5], [-0.9, 0.06, 0.035, -0.005, 0.4],
	]), peau)
	for cote in [-1.0, 1.0]:
		_piece(_tete, _sphere(0.045), peau, Vector3(cote * 0.09, 0.15, -0.12), Vector3.ZERO, Vector3(1, 0.8, 1.2))
		_piece(_tete, _sphere(0.026), _materiau("oeil_croco"), Vector3(cote * 0.1, 0.17, -0.15))
		_piece(_tete, _sphere(0.02), peau, Vector3(cote * 0.03, 0.06, -0.86))
		# Les dents qui dépassent, même gueule fermée.
		for k in 7:
			_piece(_tete, _cone(0.012, 0.05), _materiau("dent"), Vector3(cote * (0.1 - k * 0.006), -0.06, -0.2 - k * 0.09),
					Vector3(PI, 0, 0))
	# La mâchoire du bas, qui s'ouvre quand il attaque.
	_machoire = _pivot(_tete, Vector3(0, -0.02, 0.0), "Machoire")
	_piece(_machoire, _loft([
		[0.05, 0.16, 0.06, -0.06, 0.4], [-0.3, 0.17, 0.05, -0.06, 0.4], [-0.7, 0.08, 0.035, -0.045, 0.3],
		[-0.88, 0.05, 0.03, -0.04, 0.3],
	]), peau)
	_piece(_machoire, _loft([[0.0, 0.13, 0.015, -0.015], [-0.75, 0.06, 0.01, -0.02]]), _materiau("gueule"))
	# La queue : quatre morceaux, de plus en plus fins et hauts (elle sert de rame).
	var parent := _corps
	var debut := 1.25
	var sections := [[0.26, 0.17], [0.19, 0.15], [0.12, 0.12], [0.06, 0.09], [0.015, 0.05]]
	for k in 4:
		var morceau := _pivot(parent, Vector3(0, 0.3 if k == 0 else 0.0, debut if k == 0 else 0.48), "Queue%d" % k)
		var a: Array = sections[k]
		var b: Array = sections[k + 1]
		_piece(morceau, _loft([[-0.03, a[0], a[1], 0.0, 0.3], [0.5, b[0], b[1], 0.0, 0.3]]), peau)
		# Les crêtes de la queue se rejoignent en une seule rangée.
		for j in 3:
			_piece(morceau, crete, peau, Vector3(0, a[1] * 0.9 + 0.02, 0.08 + j * 0.15), Vector3.ZERO, Vector3(1, 1.4 - k * 0.2, 1))
		_queue.append(morceau)
		parent = morceau
	# Quatre pattes courtes, écartées sur les côtés.
	var attaches := [Vector3(-0.3, 0.26, -0.3), Vector3(0.3, 0.26, -0.3), Vector3(-0.32, 0.26, 1.0), Vector3(0.32, 0.26, 1.0)]
	for k in 4:
		var cote := -1.0 if k % 2 == 0 else 1.0
		var patte := _pivot(_corps, attaches[k], "Patte%d" % k)
		var cuisse := _piece(patte, _cylindre(0.07, 0.09, 0.32), peau, Vector3(cote * 0.14, -0.03, 0), Vector3(0, 0, cote * 1.2))
		cuisse.name = "Cuisse"
		_piece(patte, _cylindre(0.05, 0.065, 0.24), peau, Vector3(cote * 0.28, -0.14, 0), Vector3(0, 0, cote * 0.25))
		_piece(patte, _loft([[-0.12, 0.07, 0.025, 0.0], [0.06, 0.08, 0.03, 0.0]], 10), peau, Vector3(cote * 0.31, -0.25, -0.04))
		_pattes.append(patte)


# --- Hippopotame (environ 1,5 m au garrot, 4 m de long) -----------------------------------

func _construire_hippopotame() -> void:
	_hauteur = 0.0
	var peau := _materiau("hippo")
	# Un énorme tonneau sur de courtes pattes.
	_piece(_corps, _loft([
		[1.35, 0.35, 0.4, 1.0, 0.2], [1.15, 0.7, 0.66, 1.0, 0.3], [0.6, 0.86, 0.76, 0.98, 0.3],
		[-0.1, 0.86, 0.78, 1.0, 0.3], [-0.7, 0.74, 0.72, 1.05, 0.3], [-1.05, 0.55, 0.58, 1.1, 0.2],
		[-1.25, 0.44, 0.46, 1.12, 0.1],
	], 22), peau)
	# Le ventre rosé.
	_piece(_corps, _loft([[0.9, 0.5, 0.1, 0.42, 1.0], [-0.6, 0.55, 0.12, 0.45, 1.0]]), _materiau("hippo_rose"))
	# La petite queue aplatie.
	_piece(_corps, _loft([[1.33, 0.06, 0.04, 1.05], [1.6, 0.04, 0.025, 0.85]], 8), peau)
	# La tête massive : un crâne carré prolongé par un large museau.
	_tete = _pivot(_corps, Vector3(0, 1.12, -1.2), "Tete")
	_piece(_tete, _loft([
		[0.1, 0.42, 0.4, 0.0, 0.2], [-0.25, 0.4, 0.34, 0.05, 0.3], [-0.55, 0.33, 0.27, 0.02, 0.3],
		[-0.8, 0.42, 0.26, -0.02, 0.4], [-1.0, 0.44, 0.24, -0.04, 0.4], [-1.1, 0.36, 0.18, -0.04, 0.4],
	], 20), peau)
	for cote in [-1.0, 1.0]:
		# Les yeux, les oreilles et les narines dépassent du dessus (pour rester hors de l'eau).
		_piece(_tete, _sphere(0.08), peau, Vector3(cote * 0.24, 0.34, -0.3), Vector3.ZERO, Vector3(1, 0.8, 1))
		_piece(_tete, _sphere(0.035), _materiau("oeil"), Vector3(cote * 0.27, 0.37, -0.35))
		var oreille := _pivot(_tete, Vector3(cote * 0.22, 0.38, 0.0), "Oreille")
		_piece(oreille, _sphere(0.06), peau, Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(0.6, 1.2, 0.5))
		_oreilles.append(oreille)
		_piece(_tete, _sphere(0.06), peau, Vector3(cote * 0.17, 0.2, -0.98), Vector3.ZERO, Vector3(1, 0.7, 1))
	# La mâchoire du bas, avec ses défenses : elle s'ouvre presque à angle droit.
	_machoire = _pivot(_tete, Vector3(0, -0.12, -0.35), "Machoire")
	_piece(_machoire, _loft([
		[0.3, 0.36, 0.14, -0.1, 0.3], [-0.3, 0.38, 0.13, -0.12, 0.3], [-0.68, 0.42, 0.14, -0.12, 0.3],
		[-0.78, 0.34, 0.1, -0.1, 0.3],
	], 18), peau)
	_piece(_machoire, _loft([[0.2, 0.3, 0.02, 0.01], [-0.68, 0.35, 0.02, 0.01]]), _materiau("gueule"))
	for cote in [-1.0, 1.0]:
		_piece(_machoire, _cone(0.05, 0.32), _materiau("dent"), Vector3(cote * 0.3, 0.12, -0.66), Vector3(-0.15, 0, cote * 0.12))
		_piece(_machoire, _cone(0.025, 0.12), _materiau("dent"), Vector3(cote * 0.1, 0.04, -0.75), Vector3(-0.3, 0, 0))
	# Quatre pattes courtes et épaisses.
	var attaches := [Vector3(-0.5, 0.55, -0.75), Vector3(0.5, 0.55, -0.75), Vector3(-0.5, 0.55, 0.85), Vector3(0.5, 0.55, 0.85)]
	for k in 4:
		var patte := _pivot(_corps, attaches[k], "Patte%d" % k)
		_piece(patte, _cylindre(0.2, 0.18, 0.62), peau, Vector3(0, -0.24, 0))
		_piece(patte, _cylindre(0.19, 0.21, 0.08), _materiau("hippo_rose"), Vector3(0, -0.55, 0))
		_pattes.append(patte)


# --- Animation -------------------------------------------------------------------------

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
	_morsure = 0.45 if espece == "hippopotame" else 0.3


func animer(delta: float, vitesse: float, mort: bool) -> void:
	if _corps == null:
		return
	if mort:
		# Sur le dos (crocodile) ou couché sur le flanc (hippopotame).
		var angle := PI * 0.95 if espece == "crocodile" else PI / 2
		_corps.rotation.z = lerpf(_corps.rotation.z, angle, 0.12)
		_corps.position.y = lerpf(_corps.position.y, 0.35 if espece == "crocodile" else 0.5, 0.12)
		if _machoire != null:
			_machoire.rotation.x = lerpf(_machoire.rotation.x, 0.25, 0.1)
		return
	_corps.rotation.z = lerpf(_corps.rotation.z, 0.0, 0.2)
	_corps.position.y = lerpf(_corps.position.y, 0.0, 0.2)
	_morsure = maxf(0.0, _morsure - delta)
	if espece == "hippopotame":
		_animer_hippopotame(delta, vitesse)
	else:
		_animer_crocodile(delta, vitesse)


func _animer_crocodile(delta: float, vitesse: float) -> void:
	var allure := clampf(vitesse / 5.0, 0.0, 1.0)
	_phase += delta * (1.2 + vitesse * 2.0)
	var t := Time.get_ticks_msec() * 0.001
	# Le corps ondule de gauche à droite en marchant, la queue suit avec un retard.
	var onde := sin(_phase) * 0.12 * allure
	_corps.rotation.y = onde * 0.6
	for k in _queue.size():
		_queue[k].rotation.y = sin(_phase - (k + 1) * 0.9) * (0.12 + 0.1 * k) * maxf(allure, 0.25) \
				+ sin(t * 0.7 + k) * 0.04
	# Les pattes avancent en diagonale (avant gauche avec arrière droite).
	var phases := [0.0, PI, PI, 0.0]
	for k in _pattes.size():
		var cote := -1.0 if k % 2 == 0 else 1.0
		var s := sin(_phase + phases[k])
		_pattes[k].rotation.y = s * 0.55 * allure * cote
		_pattes[k].rotation.z = maxf(0.0, cos(_phase + phases[k])) * 0.35 * allure * cote
	# La tête balance un peu ; la gueule claque d'un coup sec quand il mord.
	var mord := sin(clampf(_morsure / 0.3, 0.0, 1.0) * PI)
	_tete.rotation.y = -onde * 0.8
	_tete.rotation.x = -mord * 0.25
	_machoire.rotation.x = mord * 0.75


func _animer_hippopotame(delta: float, vitesse: float) -> void:
	var allure := clampf(vitesse / 6.0, 0.0, 1.0)
	_phase += delta * (1.5 + vitesse * 1.5)
	var t := Time.get_ticks_msec() * 0.001
	var phases := [0.0, PI, PI * 0.5, PI * 1.5]
	for k in _pattes.size():
		_pattes[k].rotation.x = sin(_phase + phases[k]) * 0.4 * allure
	# Le gros corps roule et rebondit à chaque pas.
	_corps.position.y = absf(sin(_phase)) * 0.06 * allure + sin(t * 1.3) * 0.01
	_corps.rotation.z = sin(_phase) * 0.03 * allure
	for k in _oreilles.size():
		_oreilles[k].rotation.z = sin(t * 4.0 + k * 2.0) * 0.25 * float(fmod(t, 5.0) < 0.6)
	# La menace de l'hippopotame : une gueule ouverte en grand.
	var ouverture := sin(clampf(_morsure / 0.45, 0.0, 1.0) * PI)
	_tete.rotation.x = -ouverture * 0.55 + sin(t * 0.6) * 0.03
	_machoire.rotation.x = ouverture * 0.9
