extends RefCounted
## Fabrique les pièces d'équipement visibles sur le personnage (armes, capuche, cape…).
##
## PROVISOIRE : ce sont des maquettes en formes simples (comme les blocs du hub),
## en attendant de vrais modèles 3D (Blender / Fab). Chaque forme est décrite dans
## data/objets.json par « visuel » : { "forme": "lance", "couleur": "#6b4a2b", "teinte": … }.
##
## Chaque pièce est accrochée à un os du squelette Mixamo (axe Y = le long de l'os,
## +Z = devant le personnage). Les réglages de position sont dans ACCROCHES.

## forme -> liste de [os, position, rotation en degrés, côté (1 droite / -1 gauche miroir)]
const ACCROCHES := {
	"capuche_loup": [["mixamorig_Head", Vector3(0, 0.0, 0), Vector3.ZERO]],
	"bandeau": [["mixamorig_Head", Vector3(0, 0.0, 0), Vector3.ZERO]],
	"cape_fourrure": [["mixamorig_Spine2", Vector3(0, 0, 0), Vector3.ZERO]],
	"brassards": [["mixamorig_LeftForeArm", Vector3(0, 0.15, 0), Vector3.ZERO],
			["mixamorig_RightForeArm", Vector3(0, 0.15, 0), Vector3.ZERO]],
	"jambieres": [["mixamorig_LeftLeg", Vector3(0, 0.17, 0), Vector3.ZERO],
			["mixamorig_RightLeg", Vector3(0, 0.17, 0), Vector3.ZERO]],
	"bottes_fourrure": [["mixamorig_LeftLeg", Vector3(0, 0.33, 0), Vector3.ZERO],
			["mixamorig_RightLeg", Vector3(0, 0.33, 0), Vector3.ZERO]],
	"collier": [["mixamorig_Neck", Vector3(0, -0.02, 0.01), Vector3(-20, 0, 0)]],
}
## Armes : tenues dans la main (l'emplacement décide de la main) :
## [os, position dans la main, direction de l'arme dans le repère du corps (+Z = devant)].
const MAIN := {
	"arme_principale": ["mixamorig_RightHand", Vector3(0.0, 0.08, 0.02), Vector3(0.0, 0.8, 0.6)],
	"arme_secondaire": ["mixamorig_LeftHand", Vector3(0.0, 0.08, 0.02), Vector3(0.0, -0.3, 1.0)],
}


static var _bruit: NoiseTexture2D


static func _materiau(couleur: Color, rugosite := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = rugosite
	m.metallic = metal
	return m


## Fourrure et cuir : une texture de bruit casse l'aspect « plastique ».
static func _fourrure(couleur: Color) -> StandardMaterial3D:
	if _bruit == null:
		_bruit = NoiseTexture2D.new()
		_bruit.width = 256
		_bruit.height = 256
		_bruit.seamless = true
		var n := FastNoiseLite.new()
		n.frequency = 0.09
		n.fractal_octaves = 4
		_bruit.noise = n
		_bruit.color_ramp = Gradient.new()
		_bruit.color_ramp.set_color(0, Color(0.55, 0.55, 0.55))
		_bruit.color_ramp.set_color(1, Color(1.15, 1.15, 1.15))
	var m := _materiau(couleur, 1.0)
	m.albedo_texture = _bruit
	m.uv1_scale = Vector3(3, 3, 3)
	m.normal_enabled = true
	m.normal_texture = _bruit
	m.normal_scale = 0.4
	return m


static func _piece(parent: Node3D, maillage: Mesh, mat: Material, pos: Vector3,
		echelle := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = maillage
	mi.material_override = mat
	mi.position = pos
	mi.scale = echelle
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


static func _cylindre(haut: float, bas: float, hauteur: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = haut
	c.bottom_radius = bas
	c.height = hauteur
	c.radial_segments = 16
	c.rings = 1
	return c


static func _sphere(rayon: float, demi := false) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = rayon
	s.height = rayon * (1.0 if demi else 2.0)
	s.is_hemisphere = demi
	s.radial_segments = 20
	s.rings = 10
	return s


static func _boite(taille: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = taille
	return b


## Construit la forme demandée. L'axe d'une arme est +Y, la poignée à l'origine.
static func construire(forme: String, couleur: Color, cote := 1.0) -> Node3D:
	var n := Node3D.new()
	n.name = forme
	var mat := _materiau(couleur)
	match forme:
		"lame":
			var acier := _materiau(couleur, 0.3, 0.85)
			_piece(n, _cylindre(0.016, 0.016, 0.14), _materiau(Color(0.12, 0.12, 0.13)), Vector3.ZERO)
			_piece(n, _boite(Vector3(0.11, 0.02, 0.03)), _materiau(Color(0.2, 0.2, 0.22), 0.4, 0.7), Vector3(0, 0.08, 0))
			_piece(n, _boite(Vector3(0.045, 0.6, 0.008)), acier, Vector3(0, 0.39, 0))
			_piece(n, _cylindre(0.0, 0.023, 0.06), acier, Vector3(0, 0.72, 0), Vector3(1, 1, 0.18))
		"dague":
			var acier := _materiau(couleur, 0.3, 0.85)
			_piece(n, _cylindre(0.014, 0.014, 0.11), _materiau(Color(0.12, 0.12, 0.13)), Vector3.ZERO)
			_piece(n, _boite(Vector3(0.07, 0.015, 0.025)), _materiau(Color(0.2, 0.2, 0.22), 0.4, 0.7), Vector3(0, 0.06, 0))
			_piece(n, _boite(Vector3(0.032, 0.26, 0.007)), acier, Vector3(0, 0.2, 0))
			_piece(n, _cylindre(0.0, 0.016, 0.05), acier, Vector3(0, 0.355, 0), Vector3(1, 1, 0.2))
		"lance":
			_piece(n, _cylindre(0.017, 0.02, 1.9), mat, Vector3(0, 0.45, 0))
			_piece(n, _cylindre(0.023, 0.023, 0.07), _materiau(Color(0.55, 0.45, 0.3)), Vector3(0, 1.36, 0))
			_piece(n, _cylindre(0.0, 0.04, 0.2), _materiau(Color(0.32, 0.3, 0.28), 0.5), Vector3(0, 1.49, 0), Vector3(1, 1, 0.35))
		"couteau":
			_piece(n, _cylindre(0.015, 0.017, 0.1), _materiau(Color(0.4, 0.28, 0.17)), Vector3.ZERO)
			_piece(n, _cylindre(0.0, 0.03, 0.2), _materiau(couleur, 0.15), Vector3(0, 0.15, 0), Vector3(1, 1, 0.25))
		"massue":
			var os_mat := _fourrure(couleur)
			_piece(n, _cylindre(0.045, 0.022, 0.62), os_mat, Vector3(0, 0.25, 0))
			_piece(n, _sphere(0.075), os_mat, Vector3(0, 0.56, 0), Vector3(1, 1.25, 1))
		"capuche_loup":
			# Tête de loup portée comme une capuche : calotte, museau sur le front, oreilles, pan dans le dos.
			var fourrure := _fourrure(couleur)
			_piece(n, _sphere(0.125, true), fourrure, Vector3(0, 0.12, -0.005), Vector3(1.08, 1.25, 1.12))
			_piece(n, _boite(Vector3(0.09, 0.06, 0.13)), fourrure, Vector3(0, 0.235, 0.1), Vector3.ONE, Vector3(-18, 0, 0))
			_piece(n, _cylindre(0.0, 0.03, 0.08), fourrure, Vector3(0.07, 0.29, -0.01), Vector3(1, 1, 0.5), Vector3(0, 0, -15))
			_piece(n, _cylindre(0.0, 0.03, 0.08), fourrure, Vector3(-0.07, 0.29, -0.01), Vector3(1, 1, 0.5), Vector3(0, 0, 15))
			_piece(n, _cylindre(0.1, 0.13, 0.26), fourrure, Vector3(0, 0.02, -0.08), Vector3(1, 1, 0.45), Vector3(12, 0, 0))
		"bandeau":
			var t := TorusMesh.new()
			t.inner_radius = 0.105
			t.outer_radius = 0.125
			t.rings = 24
			_piece(n, t, mat, Vector3(0, 0.155, 0.025), Vector3(0.95, 0.9, 1.08), Vector3(-10, 0, 0))
			var braise := _materiau(Color(0.9, 0.35, 0.1))
			braise.emission_enabled = true
			braise.emission = Color(1.0, 0.4, 0.1)
			braise.emission_energy_multiplier = 1.5
			for i in 3:
				_piece(n, _sphere(0.012), braise, Vector3((i - 1) * 0.035, 0.16, 0.135))
		"cape_fourrure":
			# Mantelet sur les épaules + pan de fourrure dans le dos.
			var fourrure := _fourrure(couleur)
			_piece(n, _sphere(0.2), fourrure, Vector3(0, 0.1, -0.015), Vector3(1.15, 0.36, 0.8))
			_piece(n, _cylindre(0.17, 0.24, 0.66), fourrure, Vector3(0, -0.2, -0.14), Vector3(1, 1, 0.22), Vector3(-6, 0, 0))
		"brassards":
			_piece(n, _cylindre(0.044, 0.052, 0.16), _fourrure(couleur.darkened(0.15)), Vector3.ZERO)
		"jambieres":
			_piece(n, _cylindre(0.064, 0.076, 0.3), _fourrure(couleur), Vector3.ZERO)
		"bottes_fourrure":
			_piece(n, _cylindre(0.07, 0.066, 0.1), _fourrure(couleur.darkened(0.1)), Vector3.ZERO)
		"collier":
			var t := TorusMesh.new()
			t.inner_radius = 0.07
			t.outer_radius = 0.08
			t.rings = 24
			_piece(n, t, _materiau(Color(0.35, 0.25, 0.15)), Vector3.ZERO, Vector3(1, 1, 1.15))
			for i in 5:
				var a := deg_to_rad(-40.0 + i * 20.0)
				_piece(n, _cylindre(0.0, 0.009, 0.035), mat, Vector3(sin(a) * 0.075, -0.012, cos(a) * 0.086),
						Vector3.ONE, Vector3(180, 0, 0))
		_:
			n.free()
			return null
	for mi in n.get_children():
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return n


## Habille un squelette : retire les anciennes pièces et accroche les nouvelles.
## visuels : emplacement -> { forme, couleur, teinte }
static func habiller(squelette: Skeleton3D, visuels: Dictionary) -> void:
	for ancien in squelette.get_children():
		if ancien.has_meta("equipement"):
			ancien.free()
	for emplacement in visuels:
		var v: Dictionary = visuels[emplacement]
		var forme := String(v.get("forme", ""))
		if forme == "":
			continue
		var couleur := Color.from_string(String(v.get("couleur", "#808080")), Color.GRAY)
		var accroches: Array = []
		if MAIN.has(emplacement):
			accroches = [MAIN[emplacement]]
		else:
			accroches = ACCROCHES.get(forme, [])
		var arme := MAIN.has(emplacement)
		for a in accroches:
			var os := squelette.find_bone(String(a[0]))
			if os < 0:
				continue
			var piece := construire(forme, couleur)
			if piece == null:
				continue
			var attache := BoneAttachment3D.new()
			attache.set_meta("equipement", true)
			attache.bone_name = String(a[0])
			squelette.add_child(attache)
			piece.position = a[1]
			if arme:
				# On oriente l'arme dans le repère de la main au repos, pour qu'elle pointe vers a[2].
				var main := squelette.get_bone_global_rest(os).basis.orthonormalized()
				var axe: Vector3 = (a[2] as Vector3).normalized()
				var cote_axe := axe.cross(Vector3.RIGHT).normalized()
				var voulu := Basis(cote_axe.cross(axe), axe, cote_axe)
				piece.basis = main.inverse() * voulu
			else:
				piece.rotation_degrees = a[2]
			attache.add_child(piece)
