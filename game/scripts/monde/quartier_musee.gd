extends RefCounted
## Le Musée et les Jardins suspendus (est de Hikari Bay), voir docs/HUB.md, section 3.
##
## L'esprit de Singapour : un musée de verre au bout d'une esplanade, des
## terrasses plantées, des « super-arbres » lumineux et une cascade.
## Le musée se visite : la salle Préhistoire contient les objets rapportés par
## les joueurs et les fresques, qui s'effacent tant que la Préhistoire est
## malade (voir HikariBay.prehistoire_reparee).
##
## Plan (le nord est vers -Z) :
##   - Rue du Musée : z de -6 à 6, de x = 30 à 70 ;
##   - Esplanade : x de 70 à 130, z de -30 à 30 ;
##   - Musée de verre : x de 104 à 128, z de -14 à 14 (entrée à l'ouest).

const Marche := preload("res://scripts/monde/quartier_marche.gd")

const MUSEE := Rect2(104, -14, 24, 28)
const HAUTEUR_MUSEE := 9.0
const VIOLET := Color(0.65, 0.35, 1.0)
const BLEU := Color(0.3, 0.65, 1.0)
const VERT := Color(0.35, 1.0, 0.55)
const CHAUD := Color(1.0, 0.85, 0.65)
const OCRE := Color(0.55, 0.18, 0.08)


static func construire(hub: HikariBay) -> void:
	_construire_musee(hub)
	_construire_salle_prehistoire(hub)
	_construire_salles_fermees(hub)
	_construire_jardins(hub)
	_lampadaires(hub)
	_construire_super_arbres(hub)
	_construire_cascade(hub)
	_construire_habitants(hub)


# --- Le bâtiment de verre -----------------------------------------------------

static func _verre(hub: HikariBay) -> StandardMaterial3D:
	if hub._materiaux.has("verre_musee"):
		return hub._materiaux["verre_musee"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.75, 0.9, 0.22)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.6
	m.roughness = 0.05
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	hub._materiaux["verre_musee"] = m
	return m


static func _construire_musee(hub: HikariBay) -> void:
	var r := MUSEE
	var sol := hub._mat_pbr("granite_tile", 2.0, "dalles", Color(0.75, 0.73, 0.7))
	# Murs de verre, grande entrée à l'ouest (z de -3 à 3).
	Marche._piece(hub, r, _verre(hub), sol, [["ouest", -3.0, 3.0]], HAUTEUR_MUSEE, 4.5)
	# Structure : poteaux d'acier blanc tous les 4 m, corniche lumineuse.
	var blanc := hub._mat_pbr("metal_plate", 2.0, "metal", Color(0.85, 0.87, 0.9))
	for i in 7:
		var x := r.position.x + i * 4.0
		for z in [r.position.y - 0.15, r.end.y + 0.15]:
			hub._bloc(x - 0.15, z - 0.15, x + 0.15, z + 0.15, 0, HAUTEUR_MUSEE, blanc)
	for i in 8:
		var z := r.position.y + i * 4.0
		for x in [r.position.x - 0.15, r.end.x + 0.15]:
			hub._bloc(x - 0.15, z - 0.15, x + 0.15, z + 0.15, 0, HAUTEUR_MUSEE, blanc)
	hub._bloc(r.position.x - 1.0, r.position.y - 1.0, r.end.x + 1.0, r.end.y + 1.0,
			HAUTEUR_MUSEE + 0.3, HAUTEUR_MUSEE + 0.8, blanc, false)
	hub._bloc(r.position.x - 1.0, r.position.y - 1.05, r.end.x + 1.0, r.position.y - 0.95,
			HAUTEUR_MUSEE + 0.35, HAUTEUR_MUSEE + 0.5, hub._neon(BLEU, 3.0), false)
	hub._bloc(r.position.x - 1.05, r.position.y - 1.0, r.position.x - 0.95, r.end.y + 1.0,
			HAUTEUR_MUSEE + 0.35, HAUTEUR_MUSEE + 0.5, hub._neon(BLEU, 3.0), false)
	hub._texte("博物館 · MUSÉE DE HIKARI BAY · Museum", Vector3(r.position.x - 1.06, HAUTEUR_MUSEE + 1.5, 0),
			Color(0.9, 0.95, 1.0), 90, -PI / 2, 3.0)
	# Accueil au centre du hall.
	var bois := Marche._bois(hub)
	hub._bloc(108.0, -2.0, 109.2, 2.0, 0, 1.05, bois)
	hub._texte("Accueil · Information · 案内", Vector3(108.6, 1.3, 2.05), CHAUD, 26, 0.0, 1.5)
	# Lumière douce du hall.
	for x in [110.0, 122.0]:
		hub._lumiere(Vector3(x, HAUTEUR_MUSEE - 1.5, 0), CHAUD, 2.0, 16.0)
	Marche._pnj(hub, "conservatrice", Vector3(107.4, 0, 0.0), PI / 2)


# --- Salle Préhistoire : vitrines et fresques ----------------------------------

static func _vitrine(hub: HikariBay, p: Vector3, titre: String) -> Node3D:
	var socle := hub._boite(Vector3(0.8, 1.0, 0.8), p + Vector3(0, 0.5, 0), hub._mat_pbr("white_rough_plaster", 1.0, "beton", Color(0.9, 0.9, 0.88)))
	socle.name = "Socle"
	hub._boite(Vector3(0.7, 0.7, 0.7), p + Vector3(0, 1.36, 0), _verre(hub), false)
	hub._texte(titre, p + Vector3(0, 0.75, 0.41), Color(0.15, 0.12, 0.1), 18, 0.0, 1.0)
	var spot := SpotLight3D.new()
	spot.position = p + Vector3(0, 3.6, 0)
	spot.rotation.x = -PI / 2
	spot.light_color = CHAUD
	spot.light_energy = 3.0
	spot.spot_range = 5.0
	spot.spot_angle = 18.0
	hub._contenu.add_child(spot)
	var objet := Node3D.new()
	objet.position = p + Vector3(0, 1.05, 0)
	hub._contenu.add_child(objet)
	return objet


static func _construire_salle_prehistoire(hub: HikariBay) -> void:
	var y := 0.0
	var ivoire := StandardMaterial3D.new()
	ivoire.albedo_color = Color(0.85, 0.78, 0.62)
	ivoire.roughness = 0.7
	hub._texte("先史時代 · Salle Préhistoire", Vector3(116.0, 4.2, -13.9), CHAUD, 60, 0.0, 2.0)
	# Vénus (statuette) : un empilement de formes arrondies.
	var venus := _vitrine(hub, Vector3(110.0, y, -8.0), "Vénus de pierre · -25 000")
	for f in [[0.0, 0.06, 0.07], [0.12, 0.09, 0.1], [0.26, 0.07, 0.08], [0.37, 0.045, 0.05]]:
		var s := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = f[2]
		m.height = f[2] * 1.6
		s.mesh = m
		s.material_override = ivoire
		s.position.y = f[0]
		venus.add_child(s)
	# Flûte en os.
	var flute := _vitrine(hub, Vector3(116.0, y, -8.0), "Flûte en os de vautour · -35 000")
	var os_ := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.025
	c.bottom_radius = 0.03
	c.height = 0.4
	os_.mesh = c
	os_.material_override = ivoire
	os_.rotation.z = PI / 2
	os_.position.y = 0.05
	flute.add_child(os_)
	# Lampe à graisse, avec sa petite flamme.
	var lampe := _vitrine(hub, Vector3(122.0, y, -8.0), "Lampe à graisse · -17 000")
	var bol := MeshInstance3D.new()
	var b := CylinderMesh.new()
	b.top_radius = 0.14
	b.bottom_radius = 0.08
	b.height = 0.08
	bol.mesh = b
	bol.material_override = hub._mat_pbr("granite_tile", 1.0, "pierre", Color(0.6, 0.5, 0.42))
	bol.position.y = 0.04
	lampe.add_child(bol)
	var flamme := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.03
	fm.height = 0.09
	flamme.mesh = fm
	flamme.material_override = hub._neon(Color(1.0, 0.6, 0.2), 5.0)
	flamme.position.y = 0.13
	lampe.add_child(flamme)
	# Mur des fresques (fond de la salle) : une paroi de roche.
	var roche := hub._mat_pbr("concrete_wall_008", 1.5, "pierre", Color(0.75, 0.62, 0.5))
	hub._bloc(107.0, -13.95, 125.0, -13.4, 0.3, 4.0, roche, false)
	var eclairage := hub._lumiere(Vector3(116.0, 3.4, -11.0), CHAUD, 2.2, 7.0)
	eclairage.name = "LumiereFresques"
	# Les fresques (visibles seulement quand la Préhistoire est réparée).
	var fresques := Node3D.new()
	fresques.name = "FresquesPrehistoire"
	fresques.position = Vector3(0, 0, -13.35)
	hub._contenu.add_child(fresques)
	var pigment := StandardMaterial3D.new()
	pigment.albedo_color = OCRE
	pigment.roughness = 1.0
	var noir := StandardMaterial3D.new()
	noir.albedo_color = Color(0.08, 0.06, 0.05)
	noir.roughness = 1.0
	_animal(fresques, Vector3(110.5, 2.5, 0), 1.2, pigment, false)
	_animal(fresques, Vector3(116.0, 1.6, 0), 1.6, noir, true)
	_animal(fresques, Vector3(121.0, 2.8, 0), 1.0, pigment, true)
	for i in 5:
		_main(fresques, Vector3(108.0 + i * 0.5, 1.2 + (i % 2) * 0.3, 0), pigment)
	# Le panneau qui remplace les fresques tant qu'elles sont effacées.
	var effacees := Label3D.new()
	effacees.name = "FresquesEffacees"
	effacees.text = "Les fresques se sont effacées.\nPersonne ne se souvient de ce qu'elles montraient."
	effacees.position = Vector3(116.0, 2.2, -13.3)
	effacees.font_size = 32
	effacees.pixel_size = 0.006
	effacees.modulate = Color(0.25, 0.2, 0.18)
	effacees.outline_size = 0
	effacees.shaded = true
	hub._contenu.add_child(effacees)


## Un animal peint à la façon des grottes : corps, tête, pattes (formes aplaties).
static func _animal(parent: Node3D, p: Vector3, taille: float, mat: Material, cornes: bool) -> void:
	var pieces := [
		[Vector3(0, 0, 0), Vector3(1.0, 0.45, 0.04)], # corps
		[Vector3(0.6, 0.12, 0), Vector3(0.32, 0.26, 0.04)], # tête
		[Vector3(-0.3, -0.35, 0), Vector3(0.08, 0.35, 0.04)], # pattes
		[Vector3(-0.1, -0.35, 0), Vector3(0.08, 0.35, 0.04)],
		[Vector3(0.22, -0.35, 0), Vector3(0.08, 0.35, 0.04)],
		[Vector3(0.38, -0.35, 0), Vector3(0.08, 0.35, 0.04)],
		[Vector3(-0.55, 0.08, 0), Vector3(0.2, 0.06, 0.04)], # queue
	]
	if cornes:
		pieces.append([Vector3(0.62, 0.36, 0), Vector3(0.05, 0.22, 0.04)])
		pieces.append([Vector3(0.72, 0.34, 0), Vector3(0.05, 0.18, 0.04)])
	for piece in pieces:
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 10
		s.rings = 5
		mi.mesh = s
		mi.material_override = mat
		mi.position = p + piece[0] * taille
		mi.scale = piece[1] * taille
		parent.add_child(mi)


## Une main négative (paume et doigts), comme sur les parois des grottes.
static func _main(parent: Node3D, p: Vector3, mat: Material) -> void:
	var paume := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	paume.mesh = s
	paume.material_override = mat
	paume.position = p
	paume.scale = Vector3(0.16, 0.18, 0.03)
	parent.add_child(paume)
	for i in 5:
		var doigt := MeshInstance3D.new()
		doigt.mesh = s
		doigt.material_override = mat
		var angle := -0.6 + i * 0.3
		doigt.position = p + Vector3(sin(angle) * 0.13, 0.08 + cos(angle) * 0.1, 0)
		doigt.scale = Vector3(0.04, 0.12, 0.03)
		doigt.rotation.z = -angle
		parent.add_child(doigt)


# --- Salles fermées (les époques encore instables) -----------------------------

static func _construire_salles_fermees(hub: HikariBay) -> void:
	var salles := [
		["Égypte antique", 110.0], ["Grèce antique", 116.0], ["Moyen Âge", 122.0],
	]
	var corde := hub._neon(Color(0.6, 0.1, 0.12), 1.0)
	var laiton := hub._mat_pbr("metal_plate", 1.0, "metal", Color(0.85, 0.65, 0.3))
	for s in salles:
		var x: float = s[1]
		# Socle vide sous une bâche, cordon rouge devant.
		hub._boite(Vector3(1.2, 1.4, 1.2), Vector3(x, 0.7, 9.0), Marche._papier(hub, Color(0.75, 0.73, 0.7), 0.05))
		hub._texte("%s\nSalle fermée · époque instable" % s[0], Vector3(x, 2.4, 9.0), Color(0.75, 0.75, 0.8), 30, PI, 1.5)
		for dx in [-1.4, 1.4]:
			hub._cylindre(0.05, 0.12, 0.95, Vector3(x + dx, 0.47, 7.2), laiton, false)
		hub._boite(Vector3(2.8, 0.04, 0.04), Vector3(x, 0.85, 7.2), corde, false)


# --- Jardins suspendus : terrasses plantées --------------------------------------

static func _construire_jardins(hub: HikariBay) -> void:
	var pierre := hub._mat_pbr("concrete_pavers_02", 2.0, "dalles", Color(0.7, 0.7, 0.68))
	var bord := hub._mat_pbr("brushed_concrete", 2.0, "beton", Color(0.8, 0.8, 0.78))
	# Deux terrasses (nord et sud) avec trois marches chacune, face à l'esplanade.
	for cote: float in [-1.0, 1.0]:
		var z_mur := 30.0 * cote
		var z_bord := 22.0 * cote
		var z1 := minf(z_mur, z_bord)
		var z2 := maxf(z_mur, z_bord)
		hub._bloc(78.0, z1, 102.0, z2, 0, 1.2, pierre)
		# Marches (visuelles) et pente cachée pour monter sans accrocher.
		for i in 3:
			var z := z_bord - cote * (0.5 + i * 0.5)
			var h := 1.2 - (i + 1) * 0.3
			hub._bloc(78.0, minf(z, z + cote * 0.5), 102.0, maxf(z, z + cote * 0.5), 0, h, bord, false)
		var pente := atan2(1.2, 2.0)
		var longueur := Vector2(2.0, 1.2).length()
		var t := Transform3D(Basis(Vector3.RIGHT, -cote * pente), Vector3(90.0, 0.6 - 0.12, z_bord - cote * 1.0))
		hub._collision_boite(Vector3(24.0, 0.2, longueur), t)
		# Bacs plantés et bancs sur la terrasse.
		for i in 4:
			var x := 81.0 + i * 6.0
			var z: float = z_mur - cote * 2.0
			hub._modele("planter_box_01", Vector3(x, 1.2, z), 0.0, 1.6)
			var plante := hub._modele("potted_plant_01", Vector3(x, 1.5, z), i * 0.8, 3.2)
			if plante == null:
				hub._cylindre(0.6, 0.3, 1.6, Vector3(x, 2.0, z), hub._mat("feuillage"), false)
		hub._lumiere(Vector3(90.0, 3.5, z_mur - cote * 4.0), VERT, 1.2, 12.0)
	# Bassin au centre de l'esplanade.
	hub._cylindre(5.0, 5.2, 0.5, Vector3(88.0, 0.25, 0.0), bord)
	var eau := hub._cylindre(4.6, 4.6, 0.1, Vector3(88.0, 0.45, 0.0), hub._mat("eau"), false)
	eau.name = "BassinMusee"
	# Allée lumineuse vers l'entrée du musée.
	for i in 6:
		var x := 74.0 + i * 5.0
		if absf(x - 88.0) < 6.0:
			continue
		for z in [-3.5, 3.5]:
			hub._cylindre(0.08, 0.1, 0.9, Vector3(x, 0.45, z), hub._mat("metal"), false)
			hub._boite(Vector3(0.18, 0.18, 0.18), Vector3(x, 0.95, z), hub._neon(CHAUD, 3.0), false)


static func _lampadaires(hub: HikariBay) -> void:
	var metal := hub._mat("metal")
	for p in [Vector3(74.0, 0, -12.0), Vector3(74.0, 0, 12.0), Vector3(102.0, 0, -11.0), Vector3(102.0, 0, 11.0),
			Vector3(84.0, 0, -19.0), Vector3(84.0, 0, 19.0)]:
		hub._cylindre(0.07, 0.1, 4.5, p + Vector3(0, 2.25, 0), metal)
		hub._boite(Vector3(0.5, 0.12, 0.5), p + Vector3(0, 4.55, 0), hub._neon(CHAUD, 4.0), false)
		hub._lumiere(p + Vector3(0, 4.2, 0), CHAUD, 1.6, 13.0)


# --- Super-arbres : grandes structures lumineuses ---------------------------------

static func _construire_super_arbres(hub: HikariBay) -> void:
	var arbres := [[Vector3(80.0, 0, -14.0), 16.0, VIOLET], [Vector3(96.0, 0, 15.0), 20.0, BLEU], [Vector3(98.0, 0, -18.0), 13.0, VERT]]
	var tronc := hub._mat_pbr("corrugated_iron", 1.0, "metal", Color(0.35, 0.3, 0.32))
	for a in arbres:
		var p: Vector3 = a[0]
		var h: float = a[1]
		var couleur: Color = a[2]
		hub._cylindre(0.7, 1.1, h, p + Vector3(0, h * 0.5, 0), tronc)
		# Couronne en entonnoir et anneaux de lumière.
		var couronne := hub._cylindre(4.5, 0.8, 3.5, p + Vector3(0, h + 1.5, 0), tronc, false)
		couronne.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in 4:
			var t := i / 3.0
			var anneau := MeshInstance3D.new()
			var tore := TorusMesh.new()
			tore.inner_radius = lerpf(1.0, 4.4, t)
			tore.outer_radius = tore.inner_radius + 0.12
			anneau.mesh = tore
			anneau.material_override = hub._neon(couleur, 3.5)
			anneau.position = p + Vector3(0, h + t * 3.2, 0)
			anneau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			hub._contenu.add_child(anneau)
		# Lianes lumineuses le long du tronc.
		for k in 6:
			var angle := k * TAU / 6.0
			var liane := hub._boite(Vector3(0.06, h, 0.06), p + Vector3(cos(angle) * 0.95, h * 0.5, sin(angle) * 0.95),
					hub._neon(couleur * 0.6, 2.0), false)
			liane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hub._lumiere(p + Vector3(0, h + 1.0, 0), couleur, 3.0, 22.0)
		hub._lumiere(p + Vector3(0, 2.0, 0), couleur, 1.2, 7.0)
	# Passerelle suspendue entre deux super-arbres.
	var a: Vector3 = arbres[0][0] + Vector3(0, 13.0, 0)
	var b: Vector3 = arbres[1][0] + Vector3(0, 13.0, 0)
	var passerelle := hub._boite(Vector3(1.8, 0.25, a.distance_to(b)), (a + b) * 0.5, hub._mat("metal"), false)
	passerelle.look_at_from_position((a + b) * 0.5, b, Vector3.UP)
	var bande := hub._boite(Vector3(0.25, 0.04, a.distance_to(b)), (a + b) * 0.5 + Vector3(0, -0.15, 0), hub._neon(BLEU, 1.2), false)
	bande.look_at_from_position((a + b) * 0.5 + Vector3(0, -0.15, 0), b + Vector3(0, -0.15, 0), Vector3.UP)


# --- Cascade sur le mur nord de l'esplanade -----------------------------------------

static func _construire_cascade(hub: HikariBay) -> void:
	var eau := StandardMaterial3D.new()
	eau.albedo_color = Color(0.45, 0.7, 0.95, 0.75)
	eau.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	eau.emission_enabled = true
	eau.emission = Color(0.3, 0.6, 1.0)
	eau.emission_energy_multiplier = 0.6
	eau.roughness = 0.05
	var rideau := hub._boite(Vector3(10.0, 14.0, 0.1), Vector3(113.0, 7.0, -29.85), eau, false)
	rideau.name = "Cascade"
	# Paroi de roche sombre derrière l'eau (cache les fenêtres de l'immeuble).
	hub._bloc(107.0, -29.98, 119.0, -29.92, 0, 14.5, hub._mat_pbr("concrete_wall_008", 2.0, "pierre", Color(0.3, 0.32, 0.35)), false)
	var bassin := hub._mat_pbr("brushed_concrete", 2.0, "beton", Color(0.8, 0.8, 0.78))
	hub._bloc(107.5, -29.8, 118.5, -26.5, 0, 0.5, bassin)
	hub._bloc(108.0, -29.6, 118.0, -27.0, 0.4, 0.45, hub._mat("eau"), false)
	var gp := GPUParticles3D.new()
	gp.amount = 80
	gp.lifetime = 1.2
	gp.position = Vector3(113.0, 0.6, -28.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(4.8, 0.1, 0.4)
	pm.direction = Vector3(0, 1, 0.3)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0, -2, 0)
	var degrade := Gradient.new()
	degrade.set_color(0, Color(1, 1, 1, 0.35))
	degrade.set_color(1, Color(1, 1, 1, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = degrade
	pm.color_ramp = gt
	gp.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	# Gouttelettes rondes et floues plutôt que des carrés.
	var rond := GradientTexture2D.new()
	rond.fill = GradientTexture2D.FILL_RADIAL
	rond.fill_from = Vector2(0.5, 0.5)
	rond.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	rond.gradient = g
	m.albedo_texture = rond
	q.material = m
	gp.draw_pass_1 = q
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hub._contenu.add_child(gp)
	hub._lumiere(Vector3(113.0, 2.5, -26.0), BLEU, 2.5, 14.0)
	hub._texte("滝 · La Cascade des Souvenirs", Vector3(113.0, 15.0, -29.7), Color(0.85, 0.95, 1.0), 50, 0.0, 2.5)


static func _construire_habitants(hub: HikariBay) -> void:
	Marche._pnj(hub, "guide_musee", Vector3(113.0, 0, -4.0), PI / 2)
	Marche._pnj(hub, "visiteuse_musee", Vector3(119.5, 0, -6.0), 0.0)
	Marche._pnj(hub, "jardinier", Vector3(92.0, 1.2, -25.0), PI)
	Marche._pnj(hub, "enfant_cascade", Vector3(110.0, 0, -25.5), 0.0)
	Marche._pnj(hub, "promeneur", Vector3(76.0, 0, 8.0), PI / 2)
