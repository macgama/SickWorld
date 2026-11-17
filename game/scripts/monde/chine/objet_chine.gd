@tool
extends "res://scripts/monde/rome/objet_rome.gd"
## Objets de quête de l'île de la Chine (en plus de ceux de Rome, de la Grèce, de
## l'Égypte et de la Préhistoire) :
## - « fanal » : la meule de combustible au pied d'une tour à fanal, éteinte, fendue
##   d'une lueur violette. Une fois allumée (cacher()), elle reste là et flambe, avec une
##   haute colonne de fumée noire (le signal du jour).
## - « lattes » : un tas de lattes de bois gravées (les lettres et les rapports de la
##   garnison) qui brûlent toutes seules. Une fois éteintes, il reste des lattes noircies.
## - « oeufs » : une claie de bambou où sèchent des feuilles de papier couvertes d'œufs de
##   vers à soie, rongées d'une lueur violette. Sauvées (cacher()), les feuilles sont propres.
## - « feuille_papier » : une feuille qui sèche, collée sur une planche, que des braises
##   violettes commencent à ronger. Une fois ramassée, il reste la planche nue.
## - « cuve_mercure » : une cuve de pâte à papier empoisonnée (des gouttes de mercure
##   brillantes, une lueur violette). Vidée et nettoyée (cacher()), la pâte redevient blanche.
## - « ecorce » : un tas de lanieres d'écorce de mûrier qui trempent (on le ramasse).
## - « liasse » : une liasse de lattes de bambou roulée et nouée (un livre des Han).
## - « feu_rayonnage » : une étagère de livres qui brûle ; éteinte, il reste l'étagère noircie.
## - « manuscrit » : le manuscrit du Livre des Han sur un pupitre, annoté en violet.
## - un Figé à qui l'on rend la mémoire n'a pas de forme : l'objet est invisible, posé sur
##   le personnage (meta « pnj_lie ») ; quand il est compté, le personnage se dégèle.

const PAILLE := Color(0.74, 0.64, 0.42)


## Ajoute un morceau à un nœud donné (et pas forcément au visuel).
func _morceau_dans(parent: Node3D, maillage: Mesh, materiau: Material, p: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = maillage
	mi.material_override = materiau
	mi.position = p
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Des flammes animées (comme l'incendie de la Grèce), posées dans « parent ».
func _flammes_dans(parent: Node3D, nombre: int, rayon: float, haut: float, y := 0.4) -> void:
	var feu := _emissif(Color(1.0, 0.5, 0.12), 4.0)
	feu.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	feu.albedo_color.a = 0.8
	feu.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(identifiant + "feu")
	for k in nombre:
		var f := CylinderMesh.new()
		f.top_radius = 0.0
		f.bottom_radius = rayon * hasard.randf_range(0.6, 1.0)
		f.height = haut * hasard.randf_range(0.7, 1.1)
		f.radial_segments = 6
		var a := hasard.randf() * TAU
		_flammes.append(_morceau_dans(parent, f, feu, Vector3(cos(a), 0, sin(a)) * hasard.randf_range(0.0, rayon * 1.6) + Vector3(0, y + f.height * 0.5, 0)))
	_lumiere_feu = OmniLight3D.new()
	_lumiere_feu.light_color = Color(1.0, 0.55, 0.2)
	_lumiere_feu.light_energy = 3.0
	_lumiere_feu.omni_range = maxf(7.0, haut * 4.0)
	_lumiere_feu.position.y = y + haut
	parent.add_child(_lumiere_feu)


## Une colonne de fumée qui monte haut dans le ciel (noire pour un fanal, grise sinon).
func _fumee_dans(parent: Node3D, hauteur_depart: float, noire := true, grosse := 1.0) -> void:
	var fumee := CPUParticles3D.new()
	fumee.amount = int(70 * grosse)
	fumee.lifetime = 9.0
	fumee.preprocess = 9.0
	fumee.position = Vector3(0, hauteur_depart, 0)
	fumee.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fumee.emission_sphere_radius = 0.5 * grosse
	fumee.direction = Vector3(0, 1, 0)
	fumee.spread = 8.0
	fumee.gravity = Vector3(0.35, 0.5, 0.1)
	fumee.initial_velocity_min = 1.0
	fumee.initial_velocity_max = 1.6
	fumee.scale_amount_min = 0.7
	fumee.scale_amount_max = 1.1
	var taille := Curve.new()
	taille.max_value = 6.0
	taille.add_point(Vector2(0, 0.6))
	taille.add_point(Vector2(1, 5.0 * grosse))
	fumee.scale_amount_curve = taille
	var teinte := Gradient.new()
	teinte.set_color(0, Color(0.08, 0.07, 0.06, 0.75) if noire else Color(0.3, 0.29, 0.28, 0.5))
	teinte.set_color(1, Color(0.35, 0.33, 0.3, 0.0))
	fumee.color_ramp = teinte
	var quad := QuadMesh.new()
	quad.size = Vector2(1.8, 1.8)
	var degrade := Gradient.new()
	degrade.set_color(0, Color(1, 1, 1, 1))
	degrade.set_color(1, Color(1, 1, 1, 0))
	var tache := GradientTexture2D.new()
	tache.gradient = degrade
	tache.fill = GradientTexture2D.FILL_RADIAL
	tache.fill_from = Vector2(0.5, 0.5)
	tache.fill_to = Vector2(0.5, 0.0)
	tache.width = 64
	tache.height = 64
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color.WHITE
	m.albedo_texture = tache
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	quad.material = m
	fumee.mesh = quad
	fumee.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(fumee)


## Une meule de combustible : un tas conique de fagots de roseaux et de branches.
func _meule_dans(parent: Node3D, materiau: Material, brulee := false) -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.2
	cone.bottom_radius = 1.4
	cone.height = 1.8
	cone.radial_segments = 10
	_morceau_dans(parent, cone, materiau, Vector3(0, 0.9, 0))
	var fagot := CylinderMesh.new()
	fagot.top_radius = 0.16
	fagot.bottom_radius = 0.16
	fagot.height = 1.6
	fagot.radial_segments = 6
	for k in 5:
		var a := k * TAU / 5.0
		_morceau_dans(parent, fagot, materiau, Vector3(cos(a) * 1.25, 0.35, sin(a) * 1.25), Vector3(0.0, -a, 1.2 if not brulee else 1.45))


func _construire_fanal() -> void:
	var paille := _mat_uni(PAILLE, 1.0)
	_meule_dans(_visuel, paille)
	# La fracture a éteint le fanal : une fente violette dans le tas.
	var fente := BoxMesh.new()
	fente.size = Vector3(0.06, 1.2, 0.9)
	_morceau(fente, _emissif(Color(0.62, 0.3, 1.0), 3.0), Vector3(0, 0.8, 0), Vector3(0, 0.6, 0))
	_trace_violette()
	# Allumé : le tas flambe, et la fumée noire du signal monte haut.
	_debout = Node3D.new()
	_debout.name = "Allume"
	_debout.visible = false
	add_child(_debout)
	_meule_dans(_debout, _mat_uni(Color(0.2, 0.15, 0.1), 1.0), true)
	_flammes_dans(_debout, 8, 0.45, 2.2, 0.5)
	_fumee_dans(_debout, 2.6, true, 1.3)


func _construire_lattes() -> void:
	var bois := _mat_uni(Color(0.62, 0.5, 0.32), 0.9)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(identifiant)
	var latte := BoxMesh.new()
	latte.size = Vector3(0.025, 0.008, 0.23)
	for k in 26:
		_morceau(latte, bois, Vector3(hasard.randf_range(-0.35, 0.35), 0.03 + hasard.randf() * 0.12, hasard.randf_range(-0.3, 0.3)),
				Vector3(hasard.randf_range(-0.3, 0.3), hasard.randf() * TAU, hasard.randf_range(-0.2, 0.2)))
	# Une liasse encore attachée par sa ficelle (les rapports de la garnison).
	for k in 8:
		_morceau(latte, bois, Vector3(-0.1 + k * 0.028, 0.18, 0.1), Vector3(0, 0.3, 0))
	_flammes_dans(_visuel, 5, 0.18, 0.7, 0.05)
	_fumee_dans(_visuel, 0.8, false, 0.4)
	_debout = Node3D.new()
	_debout.name = "Eteint"
	_debout.visible = false
	add_child(_debout)
	var noirci := _mat_uni(Color(0.12, 0.1, 0.08), 1.0)
	for k in 14:
		_morceau_dans(_debout, latte, noirci, Vector3(hasard.randf_range(-0.35, 0.35), 0.03, hasard.randf_range(-0.3, 0.3)),
				Vector3(0, hasard.randf() * TAU, 0))


func _construire_oeufs() -> void:
	var bambou := _mat_uni(Color(0.66, 0.6, 0.4), 0.8)
	var montant := CylinderMesh.new()
	montant.top_radius = 0.025
	montant.bottom_radius = 0.025
	montant.height = 1.5
	montant.radial_segments = 6
	for sx in [-0.45, 0.45]:
		for sz in [-0.25, 0.25]:
			_morceau(montant, bambou, Vector3(sx, 0.75, sz))
	_debout = Node3D.new()
	_debout.name = "Sauve"
	_debout.visible = false
	add_child(_debout)
	var feuille := BoxMesh.new()
	feuille.size = Vector3(0.8, 0.008, 0.45)
	var gris := _mat_uni(Color(0.55, 0.5, 0.52), 0.9)
	var propre := _mat_uni(Color(0.9, 0.86, 0.74), 0.9)
	var oeuf := SphereMesh.new()
	oeuf.radius = 0.012
	oeuf.height = 0.02
	oeuf.radial_segments = 4
	oeuf.rings = 2
	var sombre := _mat_uni(Color(0.25, 0.22, 0.2), 0.8)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(identifiant)
	for k in 3:
		var y := 0.45 + k * 0.4
		_morceau(BoxMesh.new(), bambou, Vector3(0, y - 0.02, 0)).scale = Vector3(0.95, 0.02, 0.55)
		_morceau(feuille, gris, Vector3(0, y, 0))
		_morceau_dans(_debout, feuille, propre, Vector3(0, y, 0))
		for i in 14:
			_morceau_dans(_debout, oeuf, sombre, Vector3(hasard.randf_range(-0.36, 0.36), y + 0.008, hasard.randf_range(-0.2, 0.2)))
		# Une lueur violette qui court sur les feuilles grises.
		var lueur := BoxMesh.new()
		lueur.size = Vector3(0.7, 0.01, 0.04)
		_morceau(lueur, _emissif(Color(0.62, 0.3, 1.0), 2.5), Vector3(0, y + 0.01, hasard.randf_range(-0.15, 0.15)), Vector3(0, hasard.randf_range(-0.4, 0.4), 0))
	_trace_violette()


func _construire_feuille_papier() -> void:
	var planche := BoxMesh.new()
	planche.size = Vector3(1.0, 1.3, 0.06)
	var bois := _mat_uni(Color(0.5, 0.4, 0.28), 0.9)
	var montant := BoxMesh.new()
	montant.size = Vector3(0.08, 1.9, 0.08)
	_morceau(montant, bois, Vector3(-0.46, 0.95, -0.06))
	_morceau(montant, bois, Vector3(0.46, 0.95, -0.06))
	_morceau(planche, bois, Vector3(0, 1.15, -0.06))
	var feuille := BoxMesh.new()
	feuille.size = Vector3(0.7, 0.9, 0.01)
	_morceau(feuille, _mat_uni(Color(0.92, 0.88, 0.78), 0.95), Vector3(0, 1.15, -0.02))
	var braise := BoxMesh.new()
	braise.size = Vector3(0.72, 0.05, 0.02)
	_morceau(braise, _emissif(Color(0.62, 0.3, 1.0), 3.0), Vector3(0, 0.72, -0.015), Vector3(0, 0, 0.12))
	_trace_violette()


func _construire_cuve_mercure() -> void:
	var pierre := _mat_uni(Color(0.6, 0.58, 0.54), 0.9)
	var bord := BoxMesh.new()
	bord.size = Vector3(2.2, 0.9, 1.4)
	_morceau(bord, pierre, Vector3(0, 0.45, 0))
	var surface := BoxMesh.new()
	surface.size = Vector3(1.9, 0.02, 1.1)
	_morceau(surface, _mat_uni(Color(0.55, 0.52, 0.56), 0.15, 0.6), Vector3(0, 0.91, 0))
	var goutte := SphereMesh.new()
	goutte.radius = 0.05
	goutte.height = 0.06
	var mercure := _mat_uni(Color(0.85, 0.86, 0.9), 0.05, 1.0)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(identifiant)
	for k in 9:
		_morceau(goutte, mercure, Vector3(hasard.randf_range(-0.8, 0.8), 0.93, hasard.randf_range(-0.45, 0.45)))
	var lueur := BoxMesh.new()
	lueur.size = Vector3(1.6, 0.01, 0.06)
	_morceau(lueur, _emissif(Color(0.62, 0.3, 1.0), 2.5), Vector3(0, 0.93, 0.1), Vector3(0, 0.4, 0))
	_trace_violette()
	_debout = Node3D.new()
	_debout.name = "Propre"
	_debout.visible = false
	add_child(_debout)
	_morceau_dans(_debout, bord, pierre, Vector3(0, 0.45, 0))
	_morceau_dans(_debout, surface, _mat_uni(Color(0.86, 0.84, 0.76), 0.3), Vector3(0, 0.915, 0))


func _construire_ecorce() -> void:
	var ecorce := _mat_uni(Color(0.84, 0.76, 0.58), 1.0)
	var laniere := BoxMesh.new()
	laniere.size = Vector3(1.4, 0.05, 0.1)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(identifiant)
	for k in 14:
		_morceau(laniere, ecorce, Vector3(hasard.randf_range(-0.2, 0.2), 0.05 + k * 0.035, hasard.randf_range(-0.3, 0.3)), Vector3(0, hasard.randf_range(-0.5, 0.5), 0))
	var baquet := CylinderMesh.new()
	baquet.top_radius = 0.75
	baquet.bottom_radius = 0.65
	baquet.height = 0.3
	_morceau(baquet, _mat_uni(Color(0.45, 0.35, 0.25), 0.9), Vector3(0, 0.15, 0))


## Une liasse de lattes de bambou roulée sur elle-même (un « juan », un rouleau).
func _liasse_dans(parent: Node3D, p: Vector3, rot := Vector3.ZERO) -> void:
	var rouleau := CylinderMesh.new()
	rouleau.top_radius = 0.09
	rouleau.bottom_radius = 0.09
	rouleau.height = 0.26
	rouleau.radial_segments = 10
	_morceau_dans(parent, rouleau, _mat_uni(Color(0.78, 0.68, 0.42), 0.8), p, rot)
	var lien := CylinderMesh.new()
	lien.top_radius = 0.095
	lien.bottom_radius = 0.095
	lien.height = 0.03
	lien.radial_segments = 10
	_morceau_dans(parent, lien, _mat_uni(Color(0.6, 0.1, 0.08), 0.7), p, rot)


func _construire_liasse() -> void:
	for k in 3:
		_liasse_dans(_visuel, Vector3(-0.2 + k * 0.2, 0.09, 0), Vector3(PI / 2, 0, 0))
	_liasse_dans(_visuel, Vector3(-0.1, 0.25, 0), Vector3(PI / 2, 0.2, 0))
	_liasse_dans(_visuel, Vector3(0.1, 0.25, 0), Vector3(PI / 2, -0.2, 0))


func _construire_feu_rayonnage() -> void:
	var bois := _mat_uni(Color(0.4, 0.22, 0.12), 0.8)
	var noirci := _mat_uni(Color(0.12, 0.09, 0.07), 1.0)
	for cible in [_visuel, null]:
		var parent: Node3D = cible
		if parent == null:
			_debout = Node3D.new()
			_debout.name = "Eteint"
			_debout.visible = false
			add_child(_debout)
			parent = _debout
		var m := bois if parent == _visuel else noirci
		var montant := BoxMesh.new()
		montant.size = Vector3(0.08, 2.0, 0.5)
		_morceau_dans(parent, montant, m, Vector3(-0.9, 1.0, 0))
		_morceau_dans(parent, montant, m, Vector3(0.9, 1.0, 0))
		var planche := BoxMesh.new()
		planche.size = Vector3(1.9, 0.05, 0.5)
		for k in 4:
			_morceau_dans(parent, planche, m, Vector3(0, 0.1 + k * 0.6, 0))
			if k < 3:
				for i in 6:
					_liasse_dans(parent, Vector3(-0.7 + i * 0.28, 0.24 + k * 0.6, 0), Vector3(PI / 2, 0, 0))
	_flammes_dans(_visuel, 7, 0.4, 1.6, 0.3)
	_fumee_dans(_visuel, 2.0, true, 0.7)


func _construire_manuscrit() -> void:
	var bois := _mat_uni(Color(0.42, 0.12, 0.08), 0.6)
	var pupitre := BoxMesh.new()
	pupitre.size = Vector3(1.0, 0.08, 0.6)
	_morceau(pupitre, bois, Vector3(0, 0.45, 0))
	var pied := BoxMesh.new()
	pied.size = Vector3(0.08, 0.45, 0.08)
	for sx in [-0.42, 0.42]:
		for sz in [-0.24, 0.24]:
			_morceau(pied, bois, Vector3(sx, 0.22, sz))
	# Le rouleau déroulé : des lattes côte à côte, couvertes de colonnes de caractères.
	var latte := BoxMesh.new()
	latte.size = Vector3(0.025, 0.006, 0.42)
	var bambou := _mat_uni(Color(0.82, 0.72, 0.46), 0.8)
	var encre := _mat_uni(Color(0.08, 0.07, 0.06), 0.6)
	var coup_pinceau := BoxMesh.new()
	coup_pinceau.size = Vector3(0.012, 0.004, 0.3)
	for k in 26:
		var x := -0.42 + k * 0.032
		_morceau(latte, bambou, Vector3(x, 0.5, 0))
		_morceau(coup_pinceau, encre, Vector3(x, 0.504, 0))
	# Dans la marge, une écriture fine et violette : quelqu'un a corrigé le texte.
	var marge := BoxMesh.new()
	marge.size = Vector3(0.3, 0.004, 0.025)
	for k in 3:
		_morceau(marge, _emissif(Color(0.62, 0.3, 1.0), 2.0), Vector3(0.05 + k * 0.08, 0.506, -0.19 + k * 0.01), Vector3(0, 0.2, 0))
	_liasse_dans(_visuel, Vector3(0.48, 0.58, 0), Vector3(PI / 2, 0, 0))
	_trace_violette()


## Une fiole de terre cuite renversée, du mercure répandu, et un bâton de cinabre rouge vif.
func _construire_fiole() -> void:
	var fiole := CylinderMesh.new()
	fiole.top_radius = 0.03
	fiole.bottom_radius = 0.07
	fiole.height = 0.18
	_morceau(fiole, _mat_uni(Color(0.5, 0.32, 0.2), 0.8), Vector3(0, 0.07, 0), Vector3(0, 0, PI / 2 - 0.2))
	var flaque := CylinderMesh.new()
	flaque.top_radius = 0.16
	flaque.bottom_radius = 0.16
	flaque.height = 0.01
	_morceau(flaque, _mat_uni(Color(0.86, 0.87, 0.9), 0.05, 1.0), Vector3(0.18, 0.01, 0.02))
	var cinabre := BoxMesh.new()
	cinabre.size = Vector3(0.1, 0.06, 0.06)
	_morceau(cinabre, _mat_uni(Color(0.78, 0.12, 0.08), 0.5), Vector3(-0.15, 0.03, 0.1), Vector3(0, 0.6, 0))
	_trace_violette()


func cacher() -> void:
	super.cacher()
	# Un Figé : quand on lui rend la mémoire, l'argile s'effrite.
	if has_meta("pnj_lie") and is_inside_tree():
		for pnj in get_tree().get_nodes_in_group("pnj"):
			if pnj.get("identifiant") == get_meta("pnj_lie") and pnj.has_method("degeler"):
				pnj.degeler()
