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
	"masque_theatre": [["mixamorig_Head", Vector3(0, 0.0, 0), Vector3.ZERO]],
	"cape_fourrure": [["mixamorig_Spine2", Vector3(0, 0, 0), Vector3.ZERO]],
	"brassards": [["mixamorig_LeftForeArm", Vector3(0, 0.15, 0), Vector3.ZERO],
			["mixamorig_RightForeArm", Vector3(0, 0.15, 0), Vector3.ZERO]],
	"jambieres": [["mixamorig_LeftLeg", Vector3(0, 0.17, 0), Vector3.ZERO],
			["mixamorig_RightLeg", Vector3(0, 0.17, 0), Vector3.ZERO]],
	"bottes_fourrure": [["mixamorig_LeftLeg", Vector3(0, 0.33, 0), Vector3.ZERO],
			["mixamorig_RightLeg", Vector3(0, 0.33, 0), Vector3.ZERO]],
	"collier": [["mixamorig_Neck", Vector3(0, -0.02, 0.01), Vector3(-20, 0, 0)]],
	"casque_gladiateur": [["mixamorig_Head", Vector3(0, 0.0, 0), Vector3.ZERO]],
	"casque_thrace": [["mixamorig_Head", Vector3(0, 0.0, 0), Vector3.ZERO]],
	"manica": [["mixamorig_RightForeArm", Vector3(0, 0.12, 0), Vector3.ZERO]],
}
## Armes : tenues dans la main (l'emplacement décide de la main) :
## [os, position dans la main, direction de l'arme dans le repère du corps (+Z = devant)].
const MAIN := {
	"arme_principale": ["mixamorig_RightHand", Vector3(0.0, 0.08, 0.02), Vector3(0.0, 0.8, 0.6)],
	"arme_secondaire": ["mixamorig_LeftHand", Vector3(0.0, 0.08, 0.02), Vector3(0.0, -0.3, 1.0)],
}
## Armes rangées (hors combat, touche R) : où chaque forme d'arme se range.
## [os, position dans le repère du corps (x = vers la DROITE du personnage, y = haut,
## z = devant), direction de l'arme (de la poignée vers la pointe), « dos » ou « hanche »].
## Pour une arme tenue en main gauche (arme secondaire), le côté est inversé (miroir).
const RANGEMENT := {
	# Lame et lance : dans le dos, en diagonale, poignée au-dessus de l'épaule droite.
	"lame": ["mixamorig_Spine2", Vector3(0.1, 0.27, -0.16), Vector3(-0.45, -1.0, -0.06), "dos"],
	"lance": ["mixamorig_Spine2", Vector3(-0.08, -0.12, -0.19), Vector3(0.72, 1.0, -0.04), "dos"],
	"propulseur": ["mixamorig_Spine2", Vector3(0.1, 0.1, -0.15), Vector3(-0.35, -1.0, -0.05), "dos"],
	# Massue, dague, couteau : à la ceinture, pointe vers le bas. L'arme de la main droite
	# se porte sur la hanche GAUCHE (on la dégaine en croisant, comme dans l'animation
	# « Withdrawing Sword ») ; celle de la main gauche, sur la hanche droite.
	"massue": ["mixamorig_Hips", Vector3(-0.18, 0.05, 0.0), Vector3(-0.1, -1.0, -0.45), "hanche"],
	"dague": ["mixamorig_Hips", Vector3(-0.17, 0.03, 0.04), Vector3(-0.05, -1.0, -0.3), "hanche"],
	"couteau": ["mixamorig_Hips", Vector3(-0.17, 0.03, 0.04), Vector3(-0.05, -1.0, -0.3), "hanche"],
}
## Arme d'une forme inconnue : à la ceinture.
const RANGEMENT_PAR_DEFAUT := ["mixamorig_Hips", Vector3(-0.18, 0.03, 0.03), Vector3(-0.05, -1.0, -0.3), "hanche"]


## Où se range l'arme d'un emplacement (voir RANGEMENT), côté déjà corrigé pour la main gauche.
static func rangement(forme: String, emplacement: String) -> Array:
	var r: Array = (RANGEMENT.get(forme, RANGEMENT_PAR_DEFAUT) as Array).duplicate()
	if emplacement == "arme_secondaire":
		r[1] = Vector3(-r[1].x, r[1].y, r[1].z)
		r[2] = Vector3(-r[2].x, r[2].y, r[2].z)
	return r


## Repère du corps (droite, haut, devant) dans l'espace du squelette, mesuré sur la pose de repos.
static func repere_corps(squelette: Skeleton3D) -> Basis:
	var p := func(nom: String) -> Vector3:
		var i := squelette.find_bone(nom)
		return squelette.get_bone_global_rest(i).origin if i >= 0 else Vector3.ZERO
	var droite: Vector3 = (p.call("mixamorig_RightArm") - p.call("mixamorig_LeftArm"))
	var haut: Vector3 = (p.call("mixamorig_Head") - p.call("mixamorig_Hips"))
	if droite.length() < 0.001 or haut.length() < 0.001:
		return Basis(Vector3(-1, 0, 0), Vector3.UP, Vector3.BACK)
	haut = haut.normalized()
	droite = (droite - haut * droite.dot(haut)).normalized()
	return Basis(droite, haut, haut.cross(droite).normalized())


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
		"masque_theatre":
			# Un masque de théâtre blanc (lin et stuc) : yeux et bouche percés, et un
			# éclat de faille violet planté dans le front (les masques de l'Effaceur).
			_piece(n, _sphere(0.11, true), mat, Vector3(0, 0.1, 0.085), Vector3(0.95, 1.25, 0.55), Vector3(90, 0, 0))
			var trou := _materiau(Color(0.03, 0.025, 0.025))
			for i: float in [-1.0, 1.0]:
				_piece(n, _sphere(0.02), trou, Vector3(i * 0.04, 0.125, 0.145), Vector3(1.3, 0.6, 0.5))
			_piece(n, _sphere(0.025), trou, Vector3(0, 0.045, 0.14), Vector3(1.4, 0.9, 0.5))
			var eclat := _materiau(Color(0.6, 0.3, 1.0))
			eclat.emission_enabled = true
			eclat.emission = Color(0.6, 0.3, 1.0)
			eclat.emission_energy_multiplier = 2.5
			_piece(n, _cylindre(0.0, 0.018, 0.08), eclat, Vector3(0, 0.19, 0.14), Vector3.ONE, Vector3(30, 0, 0))
		"casque_hoplite":
			# Le casque corinthien : une calotte de bronze qui descend sur les joues, la
			# fente des yeux en T, et un cimier de crin.
			var bronze := _materiau(couleur, 0.35, 0.85)
			_piece(n, _sphere(0.13, true), bronze, Vector3(0, 0.1, 0.0), Vector3(1.0, 1.35, 1.12))
			_piece(n, _boite(Vector3(0.22, 0.12, 0.2)), bronze, Vector3(0, 0.02, 0.02))
			var fente := _materiau(Color(0.03, 0.025, 0.02))
			_piece(n, _boite(Vector3(0.16, 0.025, 0.02)), fente, Vector3(0, 0.12, 0.13))
			_piece(n, _boite(Vector3(0.03, 0.09, 0.02)), fente, Vector3(0, 0.07, 0.13))
			_piece(n, _boite(Vector3(0.035, 0.09, 0.3)), _materiau(Color(0.55, 0.12, 0.08), 0.95), Vector3(0, 0.3, -0.02))
		"casque_gladiateur", "casque_thrace":
			# Le casque des gladiateurs (galea) : une calotte de bronze à large bord, la
			# visière ronde percée d'une grille, et un haut cimier. Le mirmillon porte un
			# cimier en crête de poisson ; le Thrace, une tête de griffon recourbée.
			var bronze := _materiau(couleur, 0.32, 0.85)
			_piece(n, _sphere(0.13, true), bronze, Vector3(0, 0.1, 0.0), Vector3(1.05, 1.3, 1.12))
			_piece(n, _cylindre(0.2, 0.2, 0.012), bronze, Vector3(0, 0.03, 0.0), Vector3(1.0, 1.0, 1.1))
			_piece(n, _sphere(0.115, true), bronze, Vector3(0, 0.08, 0.04), Vector3(1.0, 0.95, 0.95), Vector3(-90, 0, 0))
			var grille := _materiau(Color(0.05, 0.045, 0.04))
			for i in 4:
				_piece(n, _boite(Vector3(0.012, 0.11, 0.012)), grille, Vector3(-0.045 + i * 0.03, 0.11, 0.155))
			if forme == "casque_thrace":
				_piece(n, _cylindre(0.02, 0.04, 0.22), bronze, Vector3(0, 0.3, -0.03), Vector3(1, 1, 1), Vector3(-25, 0, 0))
				_piece(n, _sphere(0.045), bronze, Vector3(0, 0.39, 0.06), Vector3(0.8, 0.8, 1.4))
				_piece(n, _boite(Vector3(0.02, 0.07, 0.22)), _materiau(Color(0.7, 0.1, 0.08), 0.95), Vector3(0, 0.33, -0.08))
			else:
				_piece(n, _boite(Vector3(0.03, 0.12, 0.34)), bronze, Vector3(0, 0.27, -0.01))
				_piece(n, _boite(Vector3(0.024, 0.06, 0.3)), _materiau(Color(0.85, 0.75, 0.3), 0.9), Vector3(0, 0.35, -0.02))
		"scutum":
			# Le grand bouclier rectangulaire et bombé du mirmillon, peint en rouge.
			var bois := _materiau(couleur, 0.7)
			for i in 5:
				var a := (i - 2) * 0.22
				_piece(n, _boite(Vector3(0.13, 0.95, 0.03)), bois, Vector3(sin(a) * 0.32, 0.1, 0.06 + cos(a) * 0.32 - 0.32), Vector3.ONE, Vector3(0, rad_to_deg(a), 0))
			_piece(n, _sphere(0.07), _materiau(Color(0.7, 0.55, 0.25), 0.35, 0.85), Vector3(0, 0.1, 0.1), Vector3(1, 1, 0.4))
		"parmula":
			# Le petit bouclier carré du Thrace.
			_piece(n, _boite(Vector3(0.5, 0.55, 0.035)), _materiau(couleur, 0.6), Vector3(0, 0.1, 0.06))
			_piece(n, _boite(Vector3(0.52, 0.04, 0.04)), _materiau(Color(0.7, 0.55, 0.25), 0.35, 0.85), Vector3(0, 0.37, 0.06))
		"manica":
			_piece(n, _cylindre(0.05, 0.06, 0.26), _materiau(couleur, 0.85), Vector3.ZERO)
		"sica":
			# L'épée courbe du Thrace.
			var acier := _materiau(couleur, 0.3, 0.85)
			_piece(n, _cylindre(0.016, 0.016, 0.12), _materiau(Color(0.12, 0.12, 0.13)), Vector3.ZERO)
			_piece(n, _boite(Vector3(0.04, 0.3, 0.008)), acier, Vector3(0, 0.22, 0))
			_piece(n, _boite(Vector3(0.035, 0.22, 0.008)), acier, Vector3(0.05, 0.44, 0), Vector3.ONE, Vector3(0, 0, -28))
		"rudis":
			# Le glaive de bois qu'on remet au gladiateur libéré.
			_piece(n, _cylindre(0.017, 0.017, 0.13), _materiau(Color(0.3, 0.2, 0.12)), Vector3.ZERO)
			_piece(n, _boite(Vector3(0.05, 0.55, 0.02)), _materiau(couleur, 0.8), Vector3(0, 0.35, 0))
		"bouclier_rond":
			# L'hoplon : un grand bouclier rond et creux, bois plaqué de bronze, tenu au bras.
			var bronze := _materiau(couleur, 0.35, 0.8)
			_piece(n, _cylindre(0.45, 0.45, 0.05), bronze, Vector3(0, 0.1, 0.06), Vector3.ONE, Vector3(90, 0, 0))
			_piece(n, _sphere(0.08), _materiau(Color(0.12, 0.1, 0.08)), Vector3(0, 0.1, 0.09), Vector3(1, 1, 0.3))
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
		# --- Formes utilisées seulement pour les icônes (objets qui ne se voient pas sur le corps) ---
		"veste":
			var tissu := _materiau(couleur, 0.8)
			_piece(n, _boite(Vector3(0.34, 0.42, 0.16)), tissu, Vector3.ZERO)
			_piece(n, _cylindre(0.05, 0.06, 0.36), tissu, Vector3(-0.22, 0.02, 0), Vector3.ONE, Vector3(0, 0, -18))
			_piece(n, _cylindre(0.05, 0.06, 0.36), tissu, Vector3(0.22, 0.02, 0), Vector3.ONE, Vector3(0, 0, 18))
			_piece(n, _cylindre(0.07, 0.08, 0.05), _materiau(couleur.darkened(0.3)), Vector3(0, 0.22, 0))
			var insigne := _materiau(Color(0.25, 0.85, 0.9))
			insigne.emission_enabled = true
			insigne.emission = Color(0.25, 0.85, 0.9)
			_piece(n, _boite(Vector3(0.05, 0.05, 0.01)), insigne, Vector3(-0.08, 0.1, 0.085))
		"pantalon":
			var tissu := _materiau(couleur, 0.8)
			_piece(n, _boite(Vector3(0.3, 0.1, 0.16)), tissu, Vector3(0, 0.25, 0))
			_piece(n, _cylindre(0.07, 0.06, 0.5), tissu, Vector3(-0.08, -0.03, 0), Vector3.ONE, Vector3(0, 0, -4))
			_piece(n, _cylindre(0.07, 0.06, 0.5), tissu, Vector3(0.08, -0.03, 0), Vector3.ONE, Vector3(0, 0, 4))
			_piece(n, _boite(Vector3(0.31, 0.025, 0.17)), _materiau(Color(0.15, 0.12, 0.1)), Vector3(0, 0.29, 0))
		"rangers":
			var cuir := _materiau(couleur, 0.5)
			_piece(n, _cylindre(0.06, 0.065, 0.18), cuir, Vector3(0, 0.09, 0))
			_piece(n, _boite(Vector3(0.11, 0.07, 0.26)), cuir, Vector3(0, -0.02, 0.06))
			_piece(n, _boite(Vector3(0.12, 0.025, 0.27)), _materiau(Color(0.08, 0.08, 0.08)), Vector3(0, -0.06, 0.06))
		"torche":
			_piece(n, _cylindre(0.02, 0.025, 0.5), _materiau(Color(0.38, 0.26, 0.15)), Vector3.ZERO)
			_piece(n, _sphere(0.045), _fourrure(couleur), Vector3(0, 0.26, 0), Vector3(1, 1.5, 1))
			var flamme := _materiau(Color(1.0, 0.6, 0.15))
			flamme.emission_enabled = true
			flamme.emission = Color(1.0, 0.5, 0.1)
			flamme.emission_energy_multiplier = 2.5
			_piece(n, _cylindre(0.0, 0.05, 0.14), flamme, Vector3(0, 0.38, 0))
		"griffe":
			var corne := _materiau(couleur, 0.35)
			for i in 3:
				_piece(n, _cylindre(0.0, 0.022, 0.22), corne, Vector3((i - 1) * 0.05, 0.1 + (0.02 if i == 1 else 0.0), 0),
						Vector3.ONE, Vector3(0, 0, (i - 1) * -12 - 10))
			_piece(n, _sphere(0.07), _fourrure(Color(0.25, 0.18, 0.12)), Vector3(0, -0.02, 0), Vector3(1.4, 0.7, 0.8))
		"propulseur":
			var bois := _fourrure(couleur)
			_piece(n, _cylindre(0.018, 0.026, 0.5), bois, Vector3.ZERO)
			_piece(n, _cylindre(0.0, 0.02, 0.06), bois, Vector3(0.0, 0.27, 0.02), Vector3.ONE, Vector3(30, 0, 0))
			_piece(n, _sphere(0.035), bois, Vector3(0, -0.24, 0), Vector3(1, 0.8, 1.3))
		"ocre":
			_piece(n, _sphere(0.11, true), _fourrure(Color(0.45, 0.35, 0.25)), Vector3(0, 0, 0), Vector3(1, 0.6, 1), Vector3(180, 0, 0))
			_piece(n, _sphere(0.095), _fourrure(couleur), Vector3(0, 0.0, 0), Vector3(1, 0.35, 1))
		"dent":
			_piece(n, _cylindre(0.0, 0.04, 0.24), _materiau(couleur, 0.3), Vector3(0, 0.04, 0), Vector3.ONE, Vector3(0, 0, -12))
			_piece(n, _cylindre(0.035, 0.03, 0.07), _materiau(couleur.darkened(0.25), 0.6), Vector3(0.012, -0.11, 0))
		"croc":
			for i in 2:
				_piece(n, _cylindre(0.0, 0.028, 0.16), _materiau(couleur, 0.3), Vector3((i - 0.5) * 0.08, 0, 0),
						Vector3.ONE, Vector3(0, 0, (i - 0.5) * 30))
		"peau":
			_piece(n, _sphere(0.18), _fourrure(couleur), Vector3.ZERO, Vector3(1.3, 0.12, 1.0), Vector3(60, 0, 15))
		"silex":
			var pierre := _materiau(couleur, 0.35)
			var caillou := SphereMesh.new()
			caillou.radius = 0.09
			caillou.height = 0.16
			caillou.radial_segments = 6
			caillou.rings = 3
			_piece(n, caillou, pierre, Vector3.ZERO, Vector3(1.3, 1, 0.8), Vector3(10, 30, 20))
			_piece(n, caillou, pierre, Vector3(0.11, -0.04, 0.03), Vector3(0.6, 0.5, 0.5), Vector3(40, 10, 0))
		# --- Matériaux d'artisanat (data/artisanat.json) ---
		"tendon":
			# Un écheveau de tendon séché : trois boucles et un lien.
			var fibre := _materiau(couleur, 0.6)
			for i in 3:
				var boucle := TorusMesh.new()
				boucle.inner_radius = 0.075
				boucle.outer_radius = 0.09
				boucle.rings = 24
				_piece(n, boucle, fibre, Vector3((i - 1) * 0.02, 0, 0), Vector3(1, 1, 0.55), Vector3(90, (i - 1) * 25, 0))
			_piece(n, _cylindre(0.03, 0.03, 0.05), _materiau(couleur.darkened(0.35)), Vector3(0, -0.085, 0), Vector3.ONE, Vector3(0, 0, 90))
		"bois_renne":
			# Un bois de renne : merrain courbe et trois andouillers.
			var bois := _materiau(couleur, 0.55)
			_piece(n, _cylindre(0.014, 0.024, 0.42), bois, Vector3(0, 0.0, 0), Vector3.ONE, Vector3(0, 0, -14))
			for i in 3:
				var y := -0.1 + i * 0.12
				_piece(n, _cylindre(0.0, 0.013, 0.14), bois, Vector3(0.05 + y * 0.25, y + 0.04, 0), Vector3.ONE, Vector3(0, 0, -55 + i * 8))
		"eclat":
			# Éclat de fracture : cristal violet qui luit.
			var cristal := _materiau(couleur, 0.1, 0.3)
			cristal.emission_enabled = true
			cristal.emission = couleur
			cristal.emission_energy_multiplier = 1.4
			var pointe := CylinderMesh.new()
			pointe.top_radius = 0.0
			pointe.bottom_radius = 0.05
			pointe.height = 0.26
			pointe.radial_segments = 5
			_piece(n, pointe, cristal, Vector3(0, 0.05, 0), Vector3.ONE, Vector3(0, 0, -8))
			_piece(n, pointe, cristal, Vector3(0.06, -0.01, 0.01), Vector3(0.7, 0.6, 0.7), Vector3(0, 0, -35))
			_piece(n, pointe, cristal, Vector3(-0.055, -0.02, 0.0), Vector3(0.6, 0.5, 0.6), Vector3(0, 0, 30))
		"sac":
			var cuir := _fourrure(couleur)
			_piece(n, _sphere(0.15), cuir, Vector3.ZERO, Vector3(1, 1.05, 0.8))
			_piece(n, _cylindre(0.05, 0.08, 0.08), cuir, Vector3(0, 0.15, 0))
			var lien := TorusMesh.new()
			lien.inner_radius = 0.045
			lien.outer_radius = 0.058
			_piece(n, lien, _materiau(Color(0.3, 0.2, 0.12)), Vector3(0, 0.15, 0))
		"sac_a_dos":
			var toile := _materiau(couleur, 0.85)
			_piece(n, _boite(Vector3(0.28, 0.36, 0.14)), toile, Vector3.ZERO)
			_piece(n, _sphere(0.14, true), toile, Vector3(0, 0.18, 0), Vector3(1, 0.5, 0.5))
			_piece(n, _boite(Vector3(0.2, 0.14, 0.06)), _materiau(couleur.darkened(0.2)), Vector3(0, -0.07, 0.09))
			var insigne := _materiau(Color(0.25, 0.85, 0.9))
			insigne.emission_enabled = true
			insigne.emission = Color(0.25, 0.85, 0.9)
			_piece(n, _boite(Vector3(0.04, 0.04, 0.01)), insigne, Vector3(0, 0.08, 0.075))
		"montre":
			var or_ := _materiau(couleur, 0.25, 0.9)
			_piece(n, _cylindre(0.09, 0.09, 0.03), or_, Vector3.ZERO, Vector3.ONE, Vector3(90, 0, 0))
			_piece(n, _cylindre(0.078, 0.078, 0.005), _materiau(Color(0.92, 0.9, 0.84), 0.4), Vector3(0, 0, 0.016), Vector3.ONE, Vector3(90, 0, 0))
			_piece(n, _boite(Vector3(0.004, 0.06, 0.004)), _materiau(Color(0.1, 0.1, 0.1)), Vector3(0, 0.02, 0.02))
			_piece(n, _boite(Vector3(0.1, 0.004, 0.004)), _materiau(Color(0.1, 0.1, 0.1)), Vector3(0.01, -0.01, 0.021), Vector3.ONE, Vector3(0, 0, 35))
			var anneau := TorusMesh.new()
			anneau.inner_radius = 0.015
			anneau.outer_radius = 0.025
			_piece(n, anneau, or_, Vector3(0, 0.11, 0), Vector3.ONE, Vector3(90, 0, 0))
		# --- Récolte (data/recolte.json) et plats du Chef Goro ---
		"plante":
			# Une botte de tiges liées (lichen, papyrus, lin).
			var tige := _materiau(couleur, 0.85)
			for i in 7:
				var a := (i - 3) * 6.0
				_piece(n, _cylindre(0.008, 0.012, 0.34), tige, Vector3((i - 3) * 0.012, 0, 0), Vector3.ONE, Vector3(0, 0, a))
			_piece(n, _cylindre(0.035, 0.035, 0.03), _materiau(Color(0.45, 0.32, 0.18)), Vector3(0, -0.04, 0))
			_piece(n, _sphere(0.06), _materiau(couleur.lightened(0.2), 0.9), Vector3(0, 0.17, 0), Vector3(1.6, 0.6, 0.8))
		"ecorce":
			# Un rouleau d'écorce de bouleau, blanc strié de noir.
			var blanc := _materiau(couleur, 0.7)
			blanc.cull_mode = BaseMaterial3D.CULL_DISABLED
			_piece(n, _cylindre(0.07, 0.07, 0.26), blanc, Vector3.ZERO, Vector3.ONE, Vector3(0, 0, 70))
			for i in 4:
				_piece(n, _boite(Vector3(0.012, 0.03, 0.005)), _materiau(Color(0.12, 0.1, 0.08)), Vector3(-0.08 + i * 0.05, 0.03 + i * 0.017, 0.07))
		"fleur":
			var vert := _materiau(Color(0.3, 0.45, 0.22), 0.9)
			_piece(n, _cylindre(0.008, 0.01, 0.3), vert, Vector3(0, -0.05, 0))
			for i in 6:
				var a := deg_to_rad(i * 60.0)
				_piece(n, _sphere(0.045), _materiau(couleur, 0.6), Vector3(cos(a) * 0.05, 0.11, sin(a) * 0.05), Vector3(1.3, 0.35, 0.8))
			_piece(n, _sphere(0.03), _materiau(Color(0.95, 0.8, 0.3), 0.6), Vector3(0, 0.12, 0))
		"champignon":
			_piece(n, _sphere(0.14, true), _materiau(couleur, 0.95), Vector3(0, 0, 0), Vector3(1.2, 0.7, 0.9))
			_piece(n, _cylindre(0.15, 0.16, 0.025), _materiau(couleur.lightened(0.35), 0.95), Vector3(0, -0.005, 0), Vector3(1.2, 1, 0.9))
		"minerai":
			var roche := _materiau(Color(0.38, 0.36, 0.33), 0.9)
			var caillou := SphereMesh.new()
			caillou.radius = 0.11
			caillou.height = 0.18
			caillou.radial_segments = 7
			caillou.rings = 4
			_piece(n, caillou, roche, Vector3.ZERO, Vector3(1.3, 1, 1), Vector3(10, 30, 20))
			for i in 5:
				_piece(n, _sphere(0.04), _materiau(couleur, 0.35, 0.4), Vector3(-0.07 + i * 0.035, 0.02 + (i % 2) * 0.04, 0.08), Vector3(1, 0.7, 0.5))
		"cristal":
			var pierre := _materiau(couleur, 0.1, 0.3)
			pierre.emission_enabled = true
			pierre.emission = couleur * 0.35
			for i in 3:
				var pointe := CylinderMesh.new()
				pointe.top_radius = 0.0
				pointe.bottom_radius = 0.045
				pointe.height = 0.24 - i * 0.05
				pointe.radial_segments = 6
				_piece(n, pointe, pierre, Vector3((i - 1) * 0.055, -i * 0.02, 0), Vector3.ONE, Vector3(0, 0, (1 - i) * 22))
		"poisson":
			var ecailles := _materiau(couleur, 0.35, 0.25)
			_piece(n, _sphere(0.1), ecailles, Vector3.ZERO, Vector3(2.0, 0.85, 0.5))
			var queue := CylinderMesh.new()
			queue.top_radius = 0.0
			queue.bottom_radius = 0.08
			queue.height = 0.1
			queue.radial_segments = 4
			_piece(n, queue, _materiau(couleur.darkened(0.25), 0.5), Vector3(-0.23, 0, 0), Vector3(1, 1, 0.25), Vector3(0, 0, 90))
			_piece(n, _sphere(0.015), _materiau(Color(0.05, 0.05, 0.05), 0.2), Vector3(0.15, 0.02, 0.045))
			_piece(n, _boite(Vector3(0.1, 0.04, 0.01)), _materiau(couleur.darkened(0.3), 0.5), Vector3(0, 0.09, 0), Vector3.ONE, Vector3(0, 0, -10))
		"ambre":
			var gomme := _materiau(couleur, 0.15)
			gomme.emission_enabled = true
			gomme.emission = couleur * 0.3
			_piece(n, _sphere(0.08), gomme, Vector3.ZERO, Vector3(1.2, 1, 0.9))
			_piece(n, _sphere(0.05), gomme, Vector3(0.1, -0.03, 0.02))
			_piece(n, _sphere(0.04), gomme, Vector3(-0.08, -0.05, 0.03))
		"pierre":
			_piece(n, _sphere(0.12), _materiau(couleur, 0.8), Vector3.ZERO, Vector3(1.3, 0.75, 1.0), Vector3(10, 20, 0))
		"bol":
			# Un bol fumant du Ramen Kaminari.
			_piece(n, _sphere(0.15, true), _materiau(Color(0.12, 0.1, 0.1), 0.4), Vector3(0, 0, 0), Vector3(1, 0.7, 1), Vector3(180, 0, 0))
			_piece(n, _cylindre(0.14, 0.14, 0.01), _materiau(couleur, 0.5), Vector3(0, -0.01, 0))
			_piece(n, _boite(Vector3(0.1, 0.015, 0.05)), _materiau(couleur.lightened(0.3), 0.6), Vector3(0.03, 0.0, 0.02), Vector3.ONE, Vector3(0, 25, 0))
			_piece(n, _cylindre(0.004, 0.004, 0.3), _materiau(Color(0.75, 0.6, 0.4), 0.6), Vector3(-0.02, 0.06, 0), Vector3.ONE, Vector3(0, 0, 75))
		_:
			n.free()
			return null
	for mi in n.get_children():
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return n


## Habille un squelette : retire les anciennes pièces et accroche les nouvelles.
## visuels : emplacement -> { forme, couleur, teinte }
## armes_rangees : les armes vont dans le dos / à la ceinture au lieu des mains.
static func habiller(squelette: Skeleton3D, visuels: Dictionary, armes_rangees := false) -> void:
	var corps := repere_corps(squelette)
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
			squelette.add_child(attache)
			if arme and armes_rangees:
				var r := rangement(forme, emplacement)
				os = squelette.find_bone(String(r[0]))
				if os < 0:
					attache.free()
					piece.free()
					continue
				attache.bone_name = String(r[0])
				attache.name = "Rangement_" + emplacement
				# Position et direction données dans le repère du corps, converties dans celui de l'os.
				var repere_os := squelette.get_bone_global_rest(os).basis
				var echelle_os := repere_os.get_scale()
				var pos_corps: Vector3 = corps * (r[1] as Vector3)
				piece.position = repere_os.orthonormalized().inverse() * pos_corps / echelle_os
				var axe_r: Vector3 = (corps * (r[2] as Vector3)).normalized()
				var dos := corps.z * -1.0
				var cote_r := axe_r.cross(dos).normalized()
				if cote_r.length() < 0.01:
					cote_r = corps.x
				piece.basis = repere_os.orthonormalized().inverse() * Basis(cote_r, axe_r, cote_r.cross(axe_r)).orthonormalized()
				attache.add_child(piece)
				continue
			attache.bone_name = String(a[0])
			if arme:
				attache.name = "Main_" + emplacement
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
