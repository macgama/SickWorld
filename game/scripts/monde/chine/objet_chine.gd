@tool
extends "res://scripts/monde/rome/objet_rome.gd"
## Objets de quête de l'île de la Chine (en plus de ceux de Rome, de la Grèce, de
## l'Égypte et de la Préhistoire) :
## - « fanal » : la meule de combustible au pied d'une tour à fanal, éteinte, fendue
##   d'une lueur violette. Une fois allumée (cacher()), elle reste là et flambe, avec une
##   haute colonne de fumée noire (le signal du jour).
## - « lattes » : un tas de lattes de bois gravées (les lettres et les rapports de la
##   garnison) qui brûlent toutes seules. Une fois éteintes, il reste des lattes noircies.
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


func cacher() -> void:
	super.cacher()
	# Un Figé : quand on lui rend la mémoire, l'argile s'effrite.
	if has_meta("pnj_lie") and is_inside_tree():
		for pnj in get_tree().get_nodes_in_group("pnj"):
			if pnj.get("identifiant") == get_meta("pnj_lie") and pnj.has_method("degeler"):
				pnj.degeler()
