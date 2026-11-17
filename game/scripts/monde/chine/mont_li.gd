@tool
extends "res://scripts/monde/chine/ile_chine.gd"
## Île de la Chine, zone 4 : le mont Li, le tombeau du Premier Empereur (niveaux 47-50).
##
## La nuit, le vent. On descend du char de poste à l'est, près du hameau de Lishan, où un
## paysan creuse un puits. À l'ouest, la grande colline du tombeau, carrée comme une
## pyramide et couverte de pins. Entre les deux, les fosses que les hommes de Cinabre ont
## ouvertes : des couloirs de terre où dorment, en rangs, les soldats de terre cuite...
## et certains se relèvent. Au nord-est, le camp des fouilleurs (tentes, feux, caisses, et
## du matériel moderne caché sous les bâches). Au sud-ouest, une forêt de bambous des
## monts Qinling. Au pied sud de la colline, l'entrée creusée du tombeau, d'où sort une
## vapeur de mercure violette.
##
## Tout est construit par le code (voir ile_chine.gd). Le bouton « Reconstruire » de
## l'Inspecteur refait tout. Repères : le nord est vers -Z.

const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const ObjetChine := preload("res://scripts/monde/chine/objet_chine.gd")
const Faille := preload("res://scripts/monde/prehistoire/faille.gd")
const CharPoste := preload("res://scripts/monde/chine/char_poste.gd")

const SOL := 4.0
## Le char de poste qui ramène à Luoyang, à l'est, au bout de la route.
const CHAR_POSTE := Vector2(164, 24)
const ROUTE := [Vector2(176, 24), Vector2(140, 28), Vector2(104, 10), Vector2(70, -6), Vector2(20, -12), Vector2(-40, -10), Vector2(-80, -8)]
## Le hameau de Lishan, le puits du paysan.
const VILLAGE := Rect2(110, 32, 36, 28)
const PUITS := Vector2(124, 44)
const PAYSAN := Vector2(127, 46)
const VILLAGEOIS := [Vector2(134, 52), Vector2(116, 54)]
## Masque attend au bord de la route, entre le hameau et les fosses.
const MASQUE := Vector2(96, 0)
## La grande fosse (l'infanterie) : des couloirs séparés par des murets de terre.
const FOSSE := Rect2(0, -64, 84, 40)
const PROFONDEUR := 4.5
const MURETS := [-56.0, -48.0, -40.0, -32.0]
const GENERAL := Vector2(42, -44)
## La petite fosse (les chevaux et les chars), et la faille au fond.
const FOSSE2 := Rect2(14, 8, 44, 28)
const PROFONDEUR2 := 4.0
const FAILLE := Vector2(34, 22)
## Le tumulus (la colline du tombeau) : une pyramide de terre carrée, à pans, plantée de pins.
const TUMULUS := Vector2(-84, -84)
const DEMI_BASE := 62.0
const DEMI_SOMMET := 18.0
const HAUT_TUMULUS := 34.0
## L'entrée creusée par Cinabre, au pied sud de la colline.
const ENTREE_TOMBEAU := Vector2(-84, -26)
const CINABRE := Vector2(-84, -12)
const MASQUE_TOMBEAU := Vector2(-74, -12)
## Le camp des fouilleurs de Cinabre.
const CAMP := Rect2(96, -126, 52, 42)
const PLANS := Vector2(122, -106)
const VERA := Vector2(108, -80)
## La forêt de bambous et le bébé panda.
const BAMBOUS := Rect2(-178, 30, 112, 142)
const PANDA := Vector2(-122, 112)

var _attente := 0.0


func _init() -> void:
	identifiant_zone = "mont_li"
	taille_terrain = 380
	graine = 1210
	point_apparition = CHAR_POSTE + Vector2(-4, 6)
	nombre_touffes = 20000
	neige_qui_tombe = false
	sols = {
		# Rouge : la terre retournée des fosses, la route, les cours.
		"galets": ["brown_mud_02", "dry_ground_01", "mud_cracked_dry_03"],
		# Vert : des plaques de neige.
		"neige": ["snow_02", "snow_03", "snow_02"],
		# Bleu : l'herbe sèche, les aiguilles de pin sous les arbres.
		"sol": ["withered_grass", "dry_ground_rocks", "dry_ground_01"],
		"roche": ["clay_block_wall", "brown_mud_rocks_01", "quarry_wall"],
	}
	reglages_terrain = {"sol_saturation": 0.75, "sol_motif": 5.0, "galets_motif": 4.0, "neige_motif": 6.0,
			"sol_teinte": Color(0.82, 0.8, 0.74), "roche_teinte": Color(0.9, 0.78, 0.66), "roche_saturation": 0.85}
	reglages_herbe = {"couleur_base": Color(0.22, 0.22, 0.14), "couleur_pointe": Color(0.56, 0.52, 0.36),
			"couleur_givre": Color(0.7, 0.72, 0.76), "force_vent": 0.5}
	piste = ROUTE.duplicate()


func _ready() -> void:
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_chine", "") != "":
		Reseau.remove_meta("arrivee_chine")
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	if zone == "luoyang" or zone == "fleuve_jaune" or zone == "porte_de_jade":
		return CHAR_POSTE
	if zone == "tombeau":
		return ENTREE_TOMBEAU
	return Vector2.INF


# --- Relief -----------------------------------------------------------------------------

func _preparer_bruits() -> void:
	super._preparer_bruits()
	_relief.frequency = 0.007


func _distance_ligne(p: Vector2, ligne: Array) -> float:
	var meilleure := INF
	for i in ligne.size() - 1:
		meilleure = minf(meilleure, _distance_segment(p, ligne[i], ligne[i + 1]))
	return meilleure


## Le tumulus : 1 au sommet, 0 au pied (une pyramide carrée aux arêtes un peu arrondies).
func _part_tumulus(x: float, z: float) -> float:
	var d := maxf(absf(x - TUMULUS.x), absf(z - TUMULUS.y)) * 0.85 + Vector2(x, z).distance_to(TUMULUS) * 0.15
	return clampf((DEMI_BASE - d) / (DEMI_BASE - DEMI_SOMMET), 0.0, 1.0)


## Une fosse : 1 au fond, 0 dehors (bords presque à pic), avec une rampe à l'est.
func _part_fosse(r: Rect2, x: float, z: float, rampe_z: Vector2) -> float:
	var dedans := minf(minf(x - r.position.x, r.end.x - x), minf(z - r.position.y, r.end.y - z))
	var fond := smoothstep(-0.2, 1.0, dedans)
	# La rampe : on descend en pente douce par l'est, sur une bande de 10 m de large.
	if z > rampe_z.x and z < rampe_z.y and x > r.end.x - 1.0 and x < r.end.x + 12.0:
		var bord := minf(z - rampe_z.x, rampe_z.y - z)
		fond = maxf(fond, (1.0 - clampf((x - r.end.x + 1.0) / 13.0, 0.0, 1.0)) * smoothstep(0.0, 1.5, bord))
	return fond


func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	var bruit := _relief.get_noise_2d(x, z)
	var fin := _details.get_noise_2d(x * 3.0, z * 3.0)
	var p := Vector2(x, z)
	var h := SOL + bruit * 2.2 + fin * 0.1
	# Au sud et au sud-ouest, les premières collines des monts Qinling.
	h += smoothstep(60.0, 180.0, z - x * 0.2) * 9.0 * (0.6 + bruit * 0.4)
	# La route et le hameau, plus plats.
	h = lerpf(h, SOL + bruit * 0.6, (1.0 - smoothstep(4.0, 10.0, _distance_ligne(p, ROUTE))) * 0.85)
	h = lerpf(h, SOL + 0.1 + fin * 0.04, _dans_rect(VILLAGE, x, z, 6.0))
	h = lerpf(h, SOL + fin * 0.05, _dans_rect(CAMP.grow(2.0), x, z, 6.0))
	# Les fosses : un replat autour, puis on creuse.
	h = lerpf(h, SOL + fin * 0.05, _dans_rect(FOSSE.grow(10.0), x, z, 6.0))
	h = lerpf(h, SOL + fin * 0.05, _dans_rect(FOSSE2.grow(8.0), x, z, 6.0))
	h -= _part_fosse(FOSSE, x, z, Vector2(-50.0, -38.0)) * PROFONDEUR
	h -= _part_fosse(FOSSE2, x, z, Vector2(16.0, 28.0)) * PROFONDEUR2
	# Le tumulus, et la tranchée que Cinabre a creusée dans son flanc sud.
	var t := _part_tumulus(x, z)
	h += (t * t * (3.0 - 2.0 * t)) * HAUT_TUMULUS + bruit * 1.2 * t
	var tranchee := 1.0 - smoothstep(4.0, 6.0, absf(x - ENTREE_TOMBEAU.x))
	tranchee *= smoothstep(ENTREE_TOMBEAU.y - 4.0, ENTREE_TOMBEAU.y + 2.0, z)
	h = lerpf(h, minf(h, SOL + 0.1 - clampf((ENTREE_TOMBEAU.y + 14.0 - z) * 0.12, 0.0, 1.6)), tranchee)
	return h


## Rouge : terre nue ; vert : neige ; bleu : herbe sèche.
func _parts_sol(x: float, z: float, h: float) -> Color:
	var p := Vector2(x, z)
	var n := _relief.get_noise_2d(x * 2.0 + 40.0, z * 2.0)
	var terre := 1.0 - smoothstep(3.0, 6.0, _distance_ligne(p, ROUTE))
	terre = maxf(terre, _dans_rect(FOSSE.grow(8.0), x, z, 4.0))
	terre = maxf(terre, _dans_rect(FOSSE2.grow(6.0), x, z, 4.0))
	terre = maxf(terre, _dans_rect(VILLAGE, x, z, 4.0) * 0.8)
	terre = maxf(terre, _dans_rect(CAMP, x, z, 4.0))
	terre = maxf(terre, (1.0 - smoothstep(4.0, 9.0, absf(x - ENTREE_TOMBEAU.x))) * smoothstep(ENTREE_TOMBEAU.y - 2.0, ENTREE_TOMBEAU.y + 6.0, z) * (1.0 - smoothstep(-6.0, 4.0, z)))
	var neige := smoothstep(0.3, 0.65, n) * 0.7 * (1.0 - terre)
	neige = maxf(neige, smoothstep(SOL + 14.0, SOL + 30.0, h) * 0.5)
	var herbe := maxf(0.0, 1.0 - terre - neige)
	return Color(terre + 0.001, neige, herbe, 1.0)


# --- Construction -------------------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_construire_terrain()
	_construire_fosses()
	_construire_tumulus()
	_construire_hameau()
	_construire_camp()
	_construire_bambous()
	_construire_touffes()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_appliquer_ciel()


func _mat_terre_cuite_grise() -> StandardMaterial3D:
	var m := _mat_pbr("clay_block_wall", Color(0.85, 0.74, 0.64), 0.95, 1.2)
	return m


## Un soldat de terre cuite immobile (décor) : 1,85 m, robe à pans, cuirasse de lamelles,
## chignon sur le côté. « casse » : renversé, la tête roulée à côté.
func _statue_argile(parent: Node3D, p: Vector3, angle: float, hasard: RandomNumberGenerator, casse := false) -> void:
	var argile := _mat_terre_cuite_grise()
	var sombre := _mat_pbr("", Color(0.5, 0.42, 0.37), 0.95)
	var soldat := Node3D.new()
	soldat.position = p
	soldat.rotation.y = angle
	parent.add_child(soldat)
	var corps := Node3D.new()
	soldat.add_child(corps)
	if casse:
		corps.rotation = Vector3(PI / 2 * (1.0 if hasard.randf() < 0.5 else -1.0), 0, hasard.randf_range(-0.4, 0.4))
		corps.position.y = 0.3
	# Le socle, les jambes, la robe, la cuirasse.
	_boite(Vector3(0.6, 0.08, 0.5), Vector3(0, 0.04, 0), sombre, corps, false)
	for c in [-1.0, 1.0]:
		var jambe := MeshInstance3D.new()
		jambe.mesh = _cylindre(0.08, 0.09, 0.7, 6)
		jambe.material_override = argile
		jambe.position = Vector3(c * 0.12, 0.43, 0)
		corps.add_child(jambe)
	var robe := MeshInstance3D.new()
	robe.mesh = _cylindre(0.2, 0.3, 0.55, 8)
	robe.material_override = argile
	robe.position.y = 0.95
	corps.add_child(robe)
	_boite(Vector3(0.42, 0.42, 0.26), Vector3(0, 1.34, 0), sombre, corps, false)
	for c in [-1.0, 1.0]:
		var bras := MeshInstance3D.new()
		bras.mesh = _cylindre(0.06, 0.07, 0.55, 6)
		bras.material_override = argile
		bras.position = Vector3(c * 0.28, 1.25, -0.08)
		bras.rotation.x = 0.35
		corps.add_child(bras)
	if not casse or hasard.randf() < 0.4:
		var tete := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.12
		s.height = 0.27
		s.radial_segments = 8
		s.rings = 5
		tete.mesh = s
		tete.material_override = argile
		tete.position.y = 1.7
		corps.add_child(tete)
		var chignon := MeshInstance3D.new()
		var c2 := SphereMesh.new()
		c2.radius = 0.06
		c2.height = 0.1
		c2.radial_segments = 6
		c2.rings = 3
		chignon.mesh = c2
		chignon.material_override = sombre
		chignon.position = Vector3(0.08, 1.82, 0.02)
		corps.add_child(chignon)
	elif casse:
		var tete := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.12
		s.height = 0.27
		s.radial_segments = 8
		s.rings = 5
		tete.mesh = s
		tete.material_override = argile
		tete.position = Vector3(hasard.randf_range(-0.8, 0.8), 0.12, hasard.randf_range(-0.8, 0.8))
		soldat.add_child(tete)


## Un cheval de terre cuite (décor), grandeur nature.
func _cheval_argile(parent: Node3D, p: Vector3, angle: float) -> void:
	var argile := _mat_terre_cuite_grise()
	var cheval := Node3D.new()
	cheval.position = p
	cheval.rotation.y = angle
	parent.add_child(cheval)
	var corps := MeshInstance3D.new()
	corps.mesh = _cylindre(0.36, 0.38, 1.7, 10)
	corps.material_override = argile
	corps.position.y = 1.25
	corps.rotation.x = PI / 2
	cheval.add_child(corps)
	for k in 4:
		var jambe := MeshInstance3D.new()
		jambe.mesh = _cylindre(0.07, 0.08, 1.0, 6)
		jambe.material_override = argile
		jambe.position = Vector3(-0.2 if k % 2 == 0 else 0.2, 0.55, -0.6 if k < 2 else 0.6)
		cheval.add_child(jambe)
	var cou := MeshInstance3D.new()
	cou.mesh = _cylindre(0.14, 0.2, 0.8, 8)
	cou.material_override = argile
	cou.position = Vector3(0, 1.65, -0.85)
	cou.rotation.x = -0.6
	cheval.add_child(cou)
	_boite(Vector3(0.2, 0.26, 0.55), Vector3(0, 1.95, -1.15), argile, cheval, false)


## Un pin noir (les arbres plantés sur le tumulus).
func _pin(parent: Node3D, p: Vector2, hasard: RandomNumberGenerator, taille := 1.0) -> Node3D:
	var ecorce := _mat_pbr("bark_willow_02", Color(0.42, 0.34, 0.3), 0.95, 1.0)
	return _arbre_realiste(parent, p, "pin", hasard, taille, ecorce, 0.2)


## Une touffe de bambous : une douzaine de tiges hautes et fines, des bouquets de feuilles.
func _bambous(parent: Node3D, p: Vector2, hasard: RandomNumberGenerator) -> Node3D:
	var touffe := Node3D.new()
	touffe.name = "Bambou%d" % parent.get_child_count()
	touffe.position = Vector3(p.x, hauteur(p.x, p.y) - 0.1, p.y)
	parent.add_child(touffe)
	var tige_mat := _mat_pbr("", Color(0.46, 0.56, 0.26), 0.55)
	var feuilles := _mat_pbr("", Color(0.24, 0.38, 0.14), 0.8)
	for k in hasard.randi_range(8, 14):
		var h := hasard.randf_range(5.0, 9.0)
		var a := hasard.randf() * TAU
		var r := hasard.randf_range(0.0, 1.2)
		var penche := Vector3(hasard.randf_range(-0.12, 0.12), 0, hasard.randf_range(-0.12, 0.12))
		var tige := MeshInstance3D.new()
		tige.mesh = _cylindre(0.035, 0.05, h, 5)
		tige.material_override = tige_mat
		tige.position = Vector3(cos(a) * r, h * 0.5, sin(a) * r)
		tige.rotation = penche
		touffe.add_child(tige)
		for f in 6:
			var bouquet := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = hasard.randf_range(0.18, 0.32)
			s.height = s.radius * 3.2
			s.radial_segments = 5
			s.rings = 3
			bouquet.mesh = s
			bouquet.material_override = feuilles
			var y := h * (0.55 + f * 0.08)
			bouquet.position = tige.position + Vector3(penche.z * y + hasard.randf_range(-0.6, 0.6), y - h * 0.5, -penche.x * y + hasard.randf_range(-0.6, 0.6))
			bouquet.rotation = Vector3(hasard.randf_range(0.6, 1.2), hasard.randf() * TAU, 0)
			touffe.add_child(bouquet)
	return touffe


## Une torche plantée (un poteau, une flamme, une lumière chaude).
func _torche(parent: Node3D, p: Vector2) -> void:
	var y := hauteur(p.x, p.y)
	var poteau := MeshInstance3D.new()
	poteau.mesh = _cylindre(0.05, 0.06, 2.2, 6)
	poteau.material_override = _mat_pbr("", Color(0.25, 0.17, 0.1), 0.9)
	poteau.position = Vector3(p.x, y + 1.1, p.y)
	parent.add_child(poteau)
	var flamme := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.14
	s.height = 0.36
	flamme.mesh = s
	flamme.material_override = _lumineux(Color(1.0, 0.55, 0.18), 4.0)
	flamme.position = Vector3(p.x, y + 2.35, p.y)
	parent.add_child(flamme)
	var lumiere := OmniLight3D.new()
	lumiere.light_color = Color(1.0, 0.6, 0.3)
	lumiere.light_energy = 1.8
	lumiere.omni_range = 9.0
	lumiere.position = Vector3(p.x, y + 2.6, p.y)
	parent.add_child(lumiere)


## Une vapeur de mercure : une brume violette et argentée qui rampe au ras du sol.
func _vapeur_mercure(parent: Node3D, p: Vector3, rayon := 3.0) -> void:
	var v := CPUParticles3D.new()
	v.amount = 40
	v.lifetime = 6.0
	v.preprocess = 6.0
	v.position = p
	v.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	v.emission_sphere_radius = rayon
	v.direction = Vector3(0, 1, 0)
	v.spread = 60.0
	v.gravity = Vector3(0.2, 0.05, 0)
	v.initial_velocity_min = 0.1
	v.initial_velocity_max = 0.4
	var taille := Curve.new()
	taille.max_value = 6.0
	taille.add_point(Vector2(0, 1.5))
	taille.add_point(Vector2(1, 4.0))
	v.scale_amount_curve = taille
	var teinte := Gradient.new()
	teinte.set_color(0, Color(0.6, 0.45, 0.95, 0.0))
	teinte.add_point(0.3, Color(0.7, 0.6, 0.95, 0.28))
	teinte.set_color(teinte.get_point_count() - 1, Color(0.8, 0.8, 0.9, 0.0))
	v.color_ramp = teinte
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.6)
	var degrade := Gradient.new()
	degrade.set_color(0, Color(1, 1, 1, 1))
	degrade.set_color(1, Color(1, 1, 1, 0))
	var tache := GradientTexture2D.new()
	tache.gradient = degrade
	tache.fill = GradientTexture2D.FILL_RADIAL
	tache.fill_from = Vector2(0.5, 0.5)
	tache.fill_to = Vector2(0.5, 0.0)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tache
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	quad.material = m
	v.mesh = quad
	v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(v)


# --- Les fosses ----------------------------------------------------------------------------------

func _construire_fosses() -> void:
	var dossier := Node3D.new()
	dossier.name = "Fosses"
	_contenu.add_child(dossier)
	var statues := Node3D.new()
	statues.name = "Statues"
	dossier.add_child(statues)
	var terre := _mat_terre_damee()
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 11
	var fond := SOL - PROFONDEUR
	# Les murets de terre entre les couloirs (le dessus au niveau du sol, comme dans la vraie
	# fosse n° 1), couverts de nattes et de poutres effondrées par endroits.
	for z: float in MURETS:
		_boite(Vector3(FOSSE.size.x - 16.0, PROFONDEUR + 0.2, 1.8), Vector3(FOSSE.get_center().x, fond + PROFONDEUR * 0.5 - 0.1, z), terre, dossier)
		for k in 6:
			var x := FOSSE.position.x + 10.0 + k * 12.0 + hasard.randf_range(-2.0, 2.0)
			var poutre := _boite(Vector3(0.35, 0.3, 7.6), Vector3(x, fond + 0.4, z + 4.0), _mat_bois(), dossier, false)
			poutre.rotation = Vector3(hasard.randf_range(-0.2, 0.2), hasard.randf_range(-0.3, 0.3), hasard.randf_range(-0.5, 0.5))
	# Les soldats, en rangs dans les couloirs, tournés vers l'est (vers la rampe).
	var couloirs := [-60.0, -52.0, -44.0, -36.0, -28.0]
	for z0: float in couloirs:
		for rang: float in [-1.4, 1.4]:
			var x := FOSSE.position.x + 9.0
			while x < FOSSE.end.x - 9.0:
				var p := Vector2(x + hasard.randf_range(-0.2, 0.2), z0 + rang)
				if p.distance_to(GENERAL) > 6.0 and hasard.randf() < 0.8:
					_statue_argile(statues, Vector3(p.x, hauteur(p.x, p.y), p.y), -PI / 2 + hasard.randf_range(-0.08, 0.08),
							hasard, hasard.randf() < 0.3)
				x += 2.6
	# La petite fosse : des chevaux en rangs, attelés deux par deux, et la faille au fond.
	for k in 4:
		for c in 2:
			var q := Vector2(FOSSE2.position.x + 8.0 + k * 8.0, FOSSE2.position.y + 7.0 + c * 12.0)
			if q.distance_to(FAILLE) > 6.0:
				_cheval_argile(statues, Vector3(q.x, hauteur(q.x, q.y), q.y), -PI / 2)
	# Les échelles et les paniers des fouilleurs, au bord des fosses.
	for q: Vector2 in [Vector2(10, -24), Vector2(40, -64), Vector2(70, -24), Vector2(20, 36)]:
		var echelle := _boite(Vector3(0.6, 5.0, 0.1), Vector3(q.x, SOL - 2.0, q.y + (0.6 if q.y > -40.0 and q.y < 0.0 else -0.6)), _mat_bois(), dossier, false)
		echelle.rotation.x = 0.25 * (1.0 if q.y > -40.0 else -1.0)
	for q: Vector2 in [Vector2(-4, -40), Vector2(90, -64), Vector2(90, -20), Vector2(62, 4)]:
		_torche(dossier, q)
	# Des torches plantées au fond des couloirs par les fouilleurs, tous les vingt mètres.
	for z0: float in [-60.0, -44.0, -28.0]:
		for x: float in [12.0, 34.0, 56.0, 76.0]:
			if Vector2(x, z0).distance_to(GENERAL) > 5.0:
				_torche(dossier, Vector2(x, z0))
	for x: float in [20.0, 40.0]:
		_torche(dossier, Vector2(x, 12.0))
	_fusionner(dossier)


# --- Le tumulus et l'entrée du tombeau --------------------------------------------------------

func _construire_tumulus() -> void:
	var dossier := Node3D.new()
	dossier.name = "Tumulus"
	_contenu.add_child(dossier)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 21
	var poses := 0
	var essais := 0
	while poses < 110 and essais < 1200:
		essais += 1
		var q := TUMULUS + Vector2(hasard.randf_range(-DEMI_BASE, DEMI_BASE), hasard.randf_range(-DEMI_BASE, DEMI_BASE))
		if _part_tumulus(q.x, q.y) < 0.12 or (absf(q.x - ENTREE_TOMBEAU.x) < 10.0 and q.y > ENTREE_TOMBEAU.y - 16.0):
			continue
		_pin(dossier, q, hasard, hasard.randf_range(0.8, 1.2))
		poses += 1
	# L'entrée : un cadre de grosses poutres, une porte de bronze arrachée, le noir derrière,
	# et la vapeur de mercure qui en sort.
	var e := ENTREE_TOMBEAU
	var y := hauteur(e.x, e.y)
	var bois := _mat_bois()
	for c in [-1.0, 1.0]:
		_boite(Vector3(0.6, 4.4, 0.6), Vector3(e.x + c * 2.4, y + 2.2, e.y), bois, dossier)
	_boite(Vector3(5.6, 0.6, 0.7), Vector3(e.x, y + 4.5, e.y), bois, dossier)
	var noir := _boite(Vector3(4.2, 4.2, 0.4), Vector3(e.x, y + 2.1, e.y - 0.6), _mat_pbr("", Color(0.01, 0.01, 0.015), 1.0), dossier)
	noir.name = "PorteTombeau"
	var porte := _boite(Vector3(2.2, 4.0, 0.2), Vector3(e.x + 3.6, y + 0.3, e.y + 2.0), _mat_pbr("", Color(0.3, 0.34, 0.24), 0.35), dossier, false)
	porte.rotation = Vector3(-1.35, 0.4, 0)
	var lueur := OmniLight3D.new()
	lueur.light_color = Color(0.6, 0.35, 1.0)
	lueur.light_energy = 2.5
	lueur.omni_range = 10.0
	lueur.position = Vector3(e.x, y + 2.0, e.y + 1.5)
	dossier.add_child(lueur)
	_vapeur_mercure(dossier, Vector3(e.x, y + 0.6, e.y + 2.0), 2.4)
	for c in [-1.0, 1.0]:
		_torche(dossier, Vector2(e.x + c * 5.0, e.y + 8.0))
	_fusionner(dossier)


# --- Le hameau de Lishan ---------------------------------------------------------------------------

func _construire_hameau() -> void:
	var dossier := Node3D.new()
	dossier.name = "Hameau"
	_contenu.add_child(dossier)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 31
	for m in [[Vector2(118, 36), 0.0], [Vector2(138, 38), 0.0], [Vector2(140, 56), PI], [Vector2(116, 56), PI / 2]]:
		_maison_han(dossier, m[0], Vector3(7.0, 2.6, 5.0), m[1], true)
	# Le puits que le paysan creuse : un trou rond, un treuil, un tas de terre... et une tête.
	var y := hauteur(PUITS.x, PUITS.y)
	var margelle := MeshInstance3D.new()
	margelle.mesh = _cylindre(0.9, 1.0, 0.5, 14)
	margelle.material_override = _mat_terre_damee()
	margelle.position = Vector3(PUITS.x, y + 0.25, PUITS.y)
	dossier.add_child(margelle)
	var trou := MeshInstance3D.new()
	trou.mesh = _cylindre(0.7, 0.7, 0.05, 14)
	trou.material_override = _mat_pbr("", Color(0.02, 0.02, 0.02), 1.0)
	trou.position = Vector3(PUITS.x, y + 0.51, PUITS.y)
	dossier.add_child(trou)
	for c in [-1.0, 1.0]:
		_boite(Vector3(0.12, 1.6, 0.12), Vector3(PUITS.x + c * 1.0, y + 0.8, PUITS.y), _mat_bois(), dossier, false)
	_boite(Vector3(2.2, 0.12, 0.12), Vector3(PUITS.x, y + 1.55, PUITS.y), _mat_bois(), dossier, false)
	var tas := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.4
	s.height = 1.2
	tas.mesh = s
	tas.material_override = _mat_terre_damee()
	tas.position = Vector3(PUITS.x - 2.6, y - 0.1, PUITS.y + 1.0)
	dossier.add_child(tas)
	_statue_argile(dossier, Vector3(PUITS.x - 1.6, y, PUITS.y - 1.6), 0.6, hasard, true)
	_feu(dossier, Vector2(130, 46), 0.8)
	for k in 3:
		_meule(dossier, Vector2(146 + k * 2.2, 46 + k * 1.4), 0.8)
	_fusionner(dossier)


# --- Le camp des fouilleurs --------------------------------------------------------------------------

func _construire_camp() -> void:
	var dossier := Node3D.new()
	dossier.name = "Camp"
	_contenu.add_child(dossier)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 41
	var rouge := Color(0.5, 0.12, 0.1)
	for t in [[Vector2(106, -116), 0.2], [Vector2(122, -118), -0.1], [Vector2(138, -112), 0.3],
			[Vector2(104, -98), 1.4], [Vector2(140, -96), -1.2]]:
		_tente(dossier, t[0], t[1], rouge, 1.3)
	_feu(dossier, Vector2(122, -98), 1.2)
	_feu(dossier, Vector2(112, -88), 0.8)
	# Des caisses, des paniers de terre, et sous une bâche : un groupe électrogène qui
	# ronronne, avec une petite diode verte (du matériel moderne).
	var bois := _mat_bois()
	for k in 10:
		var q := Vector2(hasard.randf_range(CAMP.position.x + 4.0, CAMP.end.x - 4.0), hasard.randf_range(CAMP.position.y + 4.0, CAMP.end.y - 4.0))
		if q.distance_to(PLANS) < 4.0 or q.distance_to(Vector2(122, -98)) < 4.0:
			continue
		var c := _boite(Vector3(1.0, 0.7, 0.8), Vector3(q.x, hauteur(q.x, q.y) + 0.35, q.y), bois, dossier)
		c.rotation.y = hasard.randf() * TAU
	var y := hauteur(134.0, -104.0)
	_boite(Vector3(1.4, 0.9, 0.9), Vector3(134, y + 0.45, -104), _mat_pbr("", Color(0.2, 0.22, 0.2), 0.5), dossier)
	var bache := _boite(Vector3(2.0, 0.05, 1.6), Vector3(134, y + 1.0, -104), _mat_pbr("", Color(0.26, 0.3, 0.22), 0.9), dossier, false)
	bache.rotation.z = 0.15
	var diode := MeshInstance3D.new()
	var d := SphereMesh.new()
	d.radius = 0.03
	d.height = 0.06
	diode.mesh = d
	diode.material_override = _lumineux(Color(0.2, 1.0, 0.3), 4.0)
	diode.position = Vector3(134.7, y + 0.7, -103.5)
	dossier.add_child(diode)
	_vapeur_mercure(dossier, Vector3(100, hauteur(100.0, -120.0) + 0.5, -120), 3.0)
	for q: Vector2 in [Vector2(96, -84), Vector2(148, -84), Vector2(96, -126), Vector2(148, -126)]:
		_torche(dossier, q)
	_fusionner(dossier)


# --- La forêt de bambous -----------------------------------------------------------------------------

func _construire_bambous() -> void:
	var dossier := Node3D.new()
	dossier.name = "Bambous"
	_contenu.add_child(dossier)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 51
	var poses := 0
	var essais := 0
	while poses < 150 and essais < 2000:
		essais += 1
		var q := Vector2(hasard.randf_range(BAMBOUS.position.x, BAMBOUS.end.x), hasard.randf_range(BAMBOUS.position.y, BAMBOUS.end.y))
		if q.distance_to(PANDA) < 5.0 or _distance_ligne(q, ROUTE) < 6.0:
			continue
		# Un sentier serpente vers la clairière du panda.
		if absf(q.x - (-100.0 + sin(q.y * 0.05) * 10.0)) < 2.5 and q.y < PANDA.y:
			continue
		_bambous(dossier, q, hasard)
		poses += 1
	# Quelques pins aussi, au nord et à l'est de la zone.
	for k in 40:
		var q := Vector2(hasard.randf_range(-180.0, 180.0), hasard.randf_range(-180.0, -140.0))
		if not CAMP.grow(6.0).has_point(q) and _part_tumulus(q.x, q.y) <= 0.0:
			_pin(dossier, q, hasard, hasard.randf_range(0.8, 1.1))
	_fusionner(dossier)


# --- Paysage lointain ----------------------------------------------------------------------------

func _construire_lointain() -> void:
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.8
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 70
	_plan_lointain(Vector3(0, SOL - PROFONDEUR - 1.5, 0), Vector2(4000, 4000), Color(0, 0.2, 0.8))
	# Les monts Qinling, hauts et sombres au sud ; la plaine de la Wei au nord.
	for m in [[Vector3(-200, -10, 1100), Vector3(2200, 420, 700)], [Vector3(900, -10, 900), Vector3(1200, 300, 600)],
			[Vector3(-1200, -10, 300), Vector3(700, 260, 1400)], [Vector3(300, -10, -1300), Vector3(1800, 90, 500)]]:
		bruit.seed = graine + hasard.randi()
		var colline := MeshInstance3D.new()
		colline.mesh = _maillage_bosse(bruit, m[1], 1.4, 0.3, 28, Color(0.25, 0.3, 0.2))
		colline.material_override = _mat_lointain()
		colline.position = m[0]
		colline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(colline)


# --- Limites de la zone --------------------------------------------------------------------------

func _construire_limites() -> void:
	var limites := Node3D.new()
	limites.name = "Limites"
	_contenu.add_child(limites)
	var demi := taille_terrain * 0.5 - 4.0
	_mur_invisible(limites, Vector3(taille_terrain, 140, 2), Vector3(0, 40, -demi))
	_mur_invisible(limites, Vector3(taille_terrain, 140, 2), Vector3(0, 40, demi))
	_mur_invisible(limites, Vector3(2, 140, taille_terrain), Vector3(demi, 40, 0))
	_mur_invisible(limites, Vector3(2, 140, taille_terrain), Vector3(-demi, 40, 0))


# --- Personnages et objets de la quête ----------------------------------------------------------

func _objet(dossier: Node3D, nom: String, id: String, p: Vector2, forme := "", invite := "", groupe := "", portee := 2.6) -> Node3D:
	var o := ObjetChine.new()
	o.name = nom
	o.identifiant = id
	o.forme = forme
	o.groupe = groupe
	o.invite = invite
	o.portee = portee
	o.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
	dossier.add_child(o)
	return o


func _pnj_cache(dossier: Node3D, id: String, p: Vector2, angle: float) -> Node3D:
	var n := _pnj(dossier, id, p, angle)
	n.add_to_group("decor_quete")
	n.set_meta("identifiant", id)
	n.visible = false
	return n


func _construire_quete() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quete"
	_contenu.add_child(dossier)
	_dossier_quete = dossier
	# Le hameau : le paysan du puits et ses voisins.
	_pnj(dossier, "paysan_puits", PAYSAN, PI * 0.75)
	for k in VILLAGEOIS.size():
		_pnj(dossier, "villageois_lishan_%d" % (k + 1), VILLAGEOIS[k], PI * (0.3 + k * 0.7))
	# Masque, au bord de la route ; Vera au camp ; Cinabre et Masque devant le tombeau.
	_pnj(dossier, "masque_li", MASQUE, PI / 2)
	_pnj_cache(dossier, "vera_li", VERA, PI)
	_pnj_cache(dossier, "cinabre_li", CINABRE, 0.0)
	_pnj_cache(dossier, "masque_tombeau", MASQUE_TOMBEAU, -PI / 4)
	# La réponse à Cinabre (deux objets de choix, devant elle).
	for r in [["RepondreUnite", "repondre_unite", "[F] « L'unité, oui. Mais sans brûler les livres. »", Vector2(-2.6, 3.0)],
			["DemanderEditeur", "demander_editeur", "[F] « Qui t'a envoyée ici ? »", Vector2(2.6, 3.0)]]:
		var q: Vector2 = CINABRE + r[3]
		_objet(dossier, r[0], r[1], q, "", r[2], "", 2.0)
	# Les plans de Cinabre, sous une tente du camp ; le bébé panda dans les bambous.
	_objet(dossier, "Plans", "plans_cinabre", PLANS, "plans", "[F] Regarder les plans étalés sur la caisse", "", 2.6)
	_objet(dossier, "BebePanda", "bebe_panda", PANDA, "panda", "[F] Approcher doucement du petit panda", "", 2.4)
	# La faille, au fond de la petite fosse.
	var faille := Faille.new()
	faille.name = "Faille"
	faille.identifiant = "faille_mont_li"
	faille.position = Vector3(FAILLE.x, hauteur(FAILLE.x, FAILLE.y), FAILLE.y)
	dossier.add_child(faille)
	# Le char de poste, qui ramène à Luoyang.
	var char_poste := CharPoste.new()
	char_poste.name = "CharPoste"
	char_poste.destination = "luoyang"
	char_poste.nom_destination = "Luoyang"
	char_poste.position = Vector3(CHAR_POSTE.x, hauteur(CHAR_POSTE.x, CHAR_POSTE.y), CHAR_POSTE.y)
	char_poste.rotation.y = -PI / 2
	dossier.add_child(char_poste)
	# Repères de la carte.
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.LIEU, "Char de poste (Luoyang)", CHAR_POSTE)
	repere.call(MarqueurCarte.Type.LIEU, "Hameau de Lishan", VILLAGE.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "La grande fosse", FOSSE.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "La fosse des chevaux", FOSSE2.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Tombeau du Premier Empereur", TUMULUS)
	repere.call(MarqueurCarte.Type.LIEU, "Entrée du tombeau", ENTREE_TOMBEAU)
	repere.call(MarqueurCarte.Type.LIEU, "Camp des fouilleurs", CAMP.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Forêt de bambous", BAMBOUS.get_center())


func _process(delta: float) -> void:
	super._process(delta)
