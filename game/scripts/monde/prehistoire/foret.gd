@tool
extends "res://scripts/monde/prehistoire/ile_prehistoire.gd"
## Île de la Préhistoire, zone 3 : la Forêt des Bouleaux (niveaux 5-8).
##
## Une forêt clairsemée de bouleaux aux feuilles dorées, sur des collines douces,
## traversée du nord au sud par une rivière. C'est le territoire des loups, et les
## failles y sont nombreuses. On y arrive par l'ouest, depuis la Steppe.
##
## Les bouleaux sont fabriqués par le code (écorce blanche tachée de noir,
## feuillage en petites cartes de feuilles), car Poly Haven n'en a pas.
## Repères : le nord est vers -Z, la Steppe à l'ouest (-X).

const Pnj := preload("res://scripts/monde/prehistoire/pnj_epoque.gd")
const ObjetQuete := preload("res://scripts/monde/prehistoire/objet_quete.gd")
const Faille := preload("res://scripts/monde/prehistoire/faille.gd")
const Grise := preload("res://scripts/monde/prehistoire/grise.gd")
const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const SHADER_MER := preload("res://shaders/prehistoire_mer.gdshader")

## L'entrée de la forêt, depuis la passe de la Steppe.
const ENTREE := Vector2(-150, -10)
## Le gué : des pierres plates permettent de traverser.
const GUE_Z := -15.0
## La clairière où Kéo est encerclé.
const CLAIRIERE := Vector2(72, -62)
## Les traces de Kéo (et de Grise) dans la neige, de l'entrée à la clairière.
const TRACES := [Vector2(-140, -10), Vector2(-108, -20), Vector2(-80, -26), Vector2(-52, -12),
		Vector2(-28, -6), Vector2(0, -14), Vector2(26, -18), Vector2(46, -38), Vector2(62, -54)]
## Failles ouvertes dans la forêt (décor : elles crachent des fracturés).
const FAILLES := [Vector2(-70, 62), Vector2(104, 40), Vector2(18, 112), Vector2(-40, -110)]

## Nombre de bouleaux (baisser si le jeu rame).
@export var nombre_bouleaux := 1400:
	set(valeur):
		nombre_bouleaux = valeur
		_demander_reconstruction()

var _rivage: FastNoiseLite


func _init() -> void:
	identifiant_zone = "foret"
	taille_terrain = 320
	point_apparition = ENTREE + Vector2(10, 0)
	nombre_touffes = 70000
	neige_qui_tombe = true
	ciel = "snow_field_2_puresky"
	sols = {
		"galets": ["brown_mud_02", "dry_river_pebbles"],
		"neige": ["snow_02", "snow_03"],
		"sol": ["withered_grass", "dry_ground_rocks"],
		"roche": ["cliff_side", "rock_wall_10", "rock_boulder_dry"],
	}
	reglages_terrain = {"sol_saturation": 0.8, "sol_motif": 3.0, "galets_motif": 3.0,
			"sol_teinte": Color(1.0, 0.94, 0.82), "roche_motif": 16.0}
	reglages_herbe = {"couleur_base": Color(0.18, 0.14, 0.07), "couleur_pointe": Color(0.7, 0.55, 0.3)}
	piste = TRACES


func _chaque_image(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_surveiller_sortie()


func sortie_vers(zone: String) -> Vector2:
	return ENTREE + Vector2(4, 0) if zone == "steppe" else Vector2.INF


# --- Relief ----------------------------------------------------------------

func _preparer_bruits() -> void:
	super._preparer_bruits()
	_relief.frequency = 0.008
	_rivage = FastNoiseLite.new()
	_rivage.seed = graine + 9
	_rivage.frequency = 0.015


## Position (x) du milieu de la rivière, qui coule du nord au sud.
func riviere_x(z: float) -> float:
	if _rivage == null:
		_preparer_bruits()
	return 14.0 + sin(z * 0.025) * 14.0 + _rivage.get_noise_1d(z) * 5.0


func distance_riviere(x: float, z: float) -> float:
	return absf(x - riviere_x(z))


func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	# Collines douces.
	var h := 5.0 + _relief.get_noise_2d(x, z) * 7.0 + absf(_details.get_noise_2d(x * 0.5, z * 0.5)) * 0.8
	h += _details.get_noise_2d(x * 3.0, z * 3.0) * 0.06
	h = maxf(h, 1.5)
	# La clairière est presque plate.
	var clairiere := exp(-Vector2(x, z).distance_squared_to(CLAIRIERE) / 500.0)
	h = lerpf(h, 5.0 + _relief.get_noise_2d(CLAIRIERE.x, CLAIRIERE.y) * 7.0, clairiere * 0.7)
	# La rivière (peu profonde au gué).
	var gue := exp(-pow((z - GUE_Z) / 6.0, 2.0))
	h = lerpf(lerpf(-1.1, -0.3, gue), h, smoothstep(2.5, 13.0, distance_riviere(x, z)))
	# Montagnes autour, sauf la passe à l'ouest (vers la Steppe).
	var crete := 1.0 - absf(_relief.get_noise_2d(x * 3.0, z * 3.0 + 500.0))
	var passe := exp(-pow((z - ENTREE.y) / 13.0, 2.0)) if x < 0.0 else 0.0
	h += smoothstep(128.0, 154.0, absf(x) + _relief.get_noise_2d(z, 30.0) * 8.0) * (22.0 + crete * crete * 20.0) \
			* (1.0 - passe * 0.85)
	h += smoothstep(128.0, 154.0, absf(z) + _relief.get_noise_2d(x, 60.0) * 8.0) * (22.0 + crete * crete * 20.0)
	return h


func _parts_sol(x: float, z: float, h: float) -> Color:
	var n := _relief.get_noise_2d(x * 3.0 + 90.0, z * 3.0)
	var berge := 1.0 - smoothstep(5.0, 11.0, distance_riviere(x, z) + n * 3.0)
	# La neige s'accroche partout sous les arbres, en plaques.
	var neige := smoothstep(-0.2, 0.5, n) * 0.75 + smoothstep(12.0, 18.0, h)
	var sur_piste := exp(-pow(_distance_piste(Vector2(x, z)) / 1.4, 2.0))
	neige *= 1.0 - sur_piste * 0.3
	return Color(berge, clampf(neige * (1.0 - berge), 0.0, 1.0), 1.0 - berge, 1.0)


# --- Construction ------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_construire_terrain()
	_construire_riviere()
	_construire_rochers()
	_construire_touffes()
	_construire_bouleaux()
	_construire_traces()
	_construire_failles()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_construire_neige_qui_tombe()
	_appliquer_ciel()


func _construire_riviere() -> void:
	var plan := PlaneMesh.new()
	plan.size = Vector2(taille_terrain + 40, taille_terrain + 40)
	plan.subdivide_width = 80
	plan.subdivide_depth = 80
	var m := ShaderMaterial.new()
	m.shader = SHADER_MER
	m.set_shader_parameter("vagues_a", _texture_vagues(graine + 30, 0.04))
	m.set_shader_parameter("vagues_b", _texture_vagues(graine + 31, 0.09))
	m.set_shader_parameter("bruit_ecume", _bruit())
	m.set_shader_parameter("couleur_profonde", Color(0.03, 0.06, 0.06))
	m.set_shader_parameter("couleur_claire", Color(0.18, 0.26, 0.24))
	m.set_shader_parameter("transparence", 1.6)
	m.set_shader_parameter("largeur_ecume", 0.25)
	m.set_shader_parameter("vitesse", 0.05)
	m.set_shader_parameter("hauteur_houle", 0.02)
	var eau := MeshInstance3D.new()
	eau.name = "Riviere"
	eau.mesh = plan
	eau.material_override = m
	eau.position = Vector3(0, NIVEAU_MER - 0.05, 0)
	eau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_contenu.add_child(eau)


func _degage(p: Vector2, marge := 0.0) -> bool:
	if p.distance_to(CLAIRIERE) < 17.0 + marge or p.distance_to(ENTREE) < 14.0 + marge:
		return false
	if _distance_piste(p) < 2.5 + marge or distance_riviere(p.x, p.y) < 7.0:
		return false
	for f in FAILLES:
		if p.distance_to(f) < 7.0 + marge:
			return false
	return true


func _construire_rochers() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 12
	var dossier := Node3D.new()
	dossier.name = "Rochers"
	_contenu.add_child(dossier)
	_preparer_rochers()
	var places := 0
	var essais := 0
	while places < 140 and essais < 2000:
		essais += 1
		var p := Vector2(hasard.randf_range(-130.0, 130.0), hasard.randf_range(-130.0, 130.0))
		if not _degage(p, 2.0):
			continue
		_placer_rocher(dossier, p.x, p.y, hasard.randf_range(0.4, 2.6) * (1.8 if hasard.randf() < 0.08 else 1.0))
		places += 1
	# Pierres plates du gué.
	for k in 6:
		var z := GUE_Z + hasard.randf_range(-2.0, 2.0)
		var x := riviere_x(z) - 5.0 + k * 2.0
		_placer_rocher(dossier, x, z, 0.7, 0.55)
	# Mousses et rochers moussus près de l'eau.
	for k in 18:
		var z := hasard.randf_range(-120.0, 120.0)
		var x := riviere_x(z) + (-1.0 if k % 2 == 0 else 1.0) * hasard.randf_range(8.0, 14.0)
		if absf(z - GUE_Z) > 10.0:
			_modele("rock_moss_set_0%d" % (1 + k % 2), Vector3(x, hauteur(x, z) - 0.2, z), hasard.randf() * TAU,
					hasard.randf_range(0.8, 1.4), dossier)


# --- Les bouleaux ------------------------------------------------------------------

## Écorce de bouleau : blanche, avec des lenticelles noires horizontales.
func _texture_ecorce() -> Texture2D:
	var image := Image.create(128, 512, true, Image.FORMAT_RGB8)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 3
	var bruit := FastNoiseLite.new()
	bruit.seed = graine + 4
	bruit.frequency = 0.05
	for j in 512:
		for i in 128:
			var v := 0.86 + bruit.get_noise_2d(i * 3.0, j) * 0.08
			image.set_pixel(i, j, Color(v, v * 0.98, v * 0.93))
	for k in 140:
		var x0 := hasard.randi_range(0, 127)
		var y0 := hasard.randi_range(0, 511)
		var longueur := hasard.randi_range(6, 34)
		var epaisseur := hasard.randi_range(1, 3)
		var sombre := hasard.randf_range(0.05, 0.25)
		for i in longueur:
			for e in epaisseur:
				image.set_pixel((x0 + i) % 128, clampi(y0 + e, 0, 511), Color(sombre, sombre * 0.95, sombre * 0.9))
	# Grandes taches sombres.
	for k in 10:
		var c := Vector2(hasard.randi_range(0, 127), hasard.randi_range(0, 511))
		var r := hasard.randf_range(5.0, 14.0)
		for j in range(int(c.y - r), int(c.y + r)):
			for i in range(int(c.x - r * 1.6), int(c.x + r * 1.6)):
				if Vector2((i - c.x) / 1.6, j - c.y).length() < r and j >= 0 and j < 512:
					image.set_pixel(posmod(i, 128), j, Color(0.12, 0.11, 0.1))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## Feuillage : des grappes de petites feuilles dorées sur fond transparent.
func _texture_feuilles() -> Texture2D:
	var taille_img := 256
	var image := Image.create(taille_img, taille_img, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 5
	# Quelques brindilles.
	for k in 6:
		var a := Vector2(hasard.randf_range(20, 236), hasard.randf_range(20, 236))
		var b := a + Vector2(hasard.randf_range(-90, 90), hasard.randf_range(-90, 90))
		for t in 100:
			var p := a.lerp(b, t / 100.0)
			if p.x >= 0 and p.y >= 0 and p.x < taille_img and p.y < taille_img:
				image.set_pixelv(Vector2i(p), Color(0.25, 0.2, 0.15, 1))
	for k in 70:
		var c := Vector2(hasard.randf_range(18, 238), hasard.randf_range(18, 238))
		var angle := hasard.randf() * TAU
		var longueur := hasard.randf_range(9.0, 15.0)
		var largeur := longueur * 0.62
		var couleur := Color(0.78, 0.62, 0.18).lerp(Color(0.55, 0.58, 0.2), hasard.randf()).lerp(
				Color(0.85, 0.45, 0.12), hasard.randf() * 0.35)
		var axe := Vector2(cos(angle), sin(angle))
		for j in range(int(c.y - longueur), int(c.y + longueur)):
			for i in range(int(c.x - longueur), int(c.x + longueur)):
				var d := Vector2(i, j) - c
				var u := d.dot(axe) / longueur
				var v := d.dot(axe.orthogonal()) / largeur
				# Feuille en losange arrondi (forme de feuille de bouleau).
				if absf(v) < (1.0 - absf(u)) * (0.6 + 0.4 * (1.0 - u * u)) and i >= 0 and j >= 0 \
						and i < taille_img and j < taille_img:
					var nuance := 0.85 + 0.15 * (1.0 - absf(v))
					image.set_pixel(i, j, Color(couleur.r * nuance, couleur.g * nuance, couleur.b * nuance, 1.0))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## Un bouleau : tronc fin et blanc, légèrement penché, couronne légère.
func _maillage_bouleau(hasard: RandomNumberGenerator, ecorce: Material, feuilles: Material) -> ArrayMesh:
	var hauteur_arbre := hasard.randf_range(7.0, 15.0)
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cotes := 7
	var anneaux := 6
	var penche := Vector3(hasard.randf_range(-0.6, 0.6), 0, hasard.randf_range(-0.6, 0.6))
	for a in anneaux:
		var t0 := float(a) / anneaux
		var t1 := float(a + 1) / anneaux
		for c in cotes:
			var b0 := TAU * c / cotes
			var b1 := TAU * (c + 1) / cotes
			var points := []
			for coin in [[t0, b0], [t0, b1], [t1, b1], [t1, b0]]:
				var t: float = coin[0]
				var ang: float = coin[1]
				var rayon := lerpf(0.17, 0.035, t)
				var centre := Vector3(0, t * hauteur_arbre, 0) + penche * t * t
				points.append([centre + Vector3(cos(ang), 0, sin(ang)) * rayon, Vector3(cos(ang), 0, sin(ang)),
						Vector2(ang / TAU, t * hauteur_arbre / 2.0)])
			for i in [0, 1, 2, 0, 2, 3]:
				outil.set_normal(points[i][1])
				outil.set_uv(points[i][2])
				outil.add_vertex(points[i][0])
	outil.set_material(ecorce)
	var maillage := outil.commit()
	# La couronne : des cartes de feuilles autour du haut du tronc.
	var couronne := SurfaceTool.new()
	couronne.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nombre_cartes := hasard.randi_range(55, 85)
	for k in nombre_cartes:
		var t := hasard.randf_range(0.35, 1.0)
		var centre := Vector3(0, t * hauteur_arbre, 0) + penche * t * t
		var rayon := lerpf(2.6, 0.9, (t - 0.35) / 0.65)
		var a := hasard.randf() * TAU
		centre += Vector3(cos(a), hasard.randf_range(-0.3, 0.3), sin(a)) * rayon * hasard.randf_range(0.3, 1.0)
		var taille_carte := hasard.randf_range(1.4, 2.4)
		var droite := Vector3(cos(a + PI / 2), 0, sin(a + PI / 2)).rotated(Vector3(cos(a), 0, sin(a)),
				hasard.randf_range(-0.5, 0.5)) * taille_carte * 0.5
		var haut := Vector3(0, 1, 0).rotated(Vector3(cos(a), 0, sin(a)), hasard.randf_range(-0.6, 0.6)) * taille_carte * 0.5
		var normale := (centre - Vector3(0, centre.y, 0)).normalized() + Vector3(0, 0.6, 0)
		var coins := [centre - droite - haut, centre + droite - haut, centre + droite + haut, centre - droite + haut]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for i in [0, 1, 2, 0, 2, 3]:
			couronne.set_normal(normale.normalized())
			couronne.set_uv(uvs[i])
			couronne.add_vertex(coins[i])
	couronne.set_material(feuilles)
	return couronne.commit(maillage)


func _construire_bouleaux() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 60
	var ecorce := StandardMaterial3D.new()
	ecorce.albedo_texture = _texture_ecorce()
	ecorce.roughness = 0.8
	var feuilles := StandardMaterial3D.new()
	feuilles.albedo_texture = _texture_feuilles()
	feuilles.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	feuilles.alpha_scissor_threshold = 0.45
	feuilles.cull_mode = BaseMaterial3D.CULL_DISABLED
	feuilles.roughness = 0.8
	feuilles.backlight_enabled = true
	feuilles.backlight = Color(0.55, 0.42, 0.12)
	var modeles: Array[ArrayMesh] = []
	for k in 10:
		modeles.append(_maillage_bouleau(hasard, ecorce, feuilles))
	var dossier := Node3D.new()
	dossier.name = "Bouleaux"
	_contenu.add_child(dossier)
	var forme_tronc := CylinderShape3D.new()
	forme_tronc.radius = 0.2
	forme_tronc.height = 4.0
	var par_modele: Array = []
	for k in modeles.size():
		par_modele.append([])
	var places := 0
	var essais := 0
	var bosquets := FastNoiseLite.new()
	bosquets.seed = graine + 61
	bosquets.frequency = 0.03
	while places < nombre_bouleaux and essais < nombre_bouleaux * 8:
		essais += 1
		var p := Vector2(hasard.randf_range(-135.0, 135.0), hasard.randf_range(-135.0, 135.0))
		# Forêt clairsemée : des bosquets et des trouées.
		if bosquets.get_noise_2d(p.x, p.y) < -0.15 or not _degage(p):
			continue
		var y := hauteur(p.x, p.y)
		if y > 16.0:
			continue
		var t := Transform3D(Basis(Vector3.UP, hasard.randf() * TAU).scaled(Vector3.ONE * hasard.randf_range(0.8, 1.2)),
				Vector3(p.x, y - 0.15, p.y))
		par_modele[hasard.randi() % modeles.size()].append(t)
		var corps := StaticBody3D.new()
		corps.position = Vector3(p.x, y + 2.0, p.y)
		var forme := CollisionShape3D.new()
		forme.shape = forme_tronc
		corps.add_child(forme)
		dossier.add_child(corps)
		places += 1
	for k in modeles.size():
		var liste: Array = par_modele[k]
		if liste.is_empty():
			continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = modeles[k]
		multi.instance_count = liste.size()
		for i in liste.size():
			multi.set_instance_transform(i, liste[i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi
		dossier.add_child(instance)


# --- Traces de Kéo et de Grise -------------------------------------------------------------

func _texture_empreinte() -> Texture2D:
	var image := Image.create(64, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	for j in 128:
		for i in 64:
			var u := Vector2((i - 32) / 18.0, (j - 70) / 46.0)
			var alpha := 0.0
			if u.length() < 1.0:
				alpha = 0.8
			# Les orteils.
			for k in 5:
				var o := Vector2(-12 + k * 6, 18 + absf(k - 1.5) * 3.0)
				if Vector2(i, j).distance_to(o + Vector2(32 - 20, 0) + Vector2(8, 0)) < 3.5 + (2.0 if k == 0 else 0.0):
					alpha = 0.8
			image.set_pixel(i, j, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)


func _construire_traces() -> void:
	var dossier := Node3D.new()
	dossier.name = "Traces"
	_contenu.add_child(dossier)
	var texture := _texture_empreinte()
	var gauche := true
	for i in TRACES.size() - 1:
		var a: Vector2 = TRACES[i]
		var b: Vector2 = TRACES[i + 1]
		var pas := int(a.distance_to(b) / 1.6)
		var direction := (b - a).normalized()
		for k in pas:
			var p := a + direction * k * 1.6 + direction.orthogonal() * (0.18 if gauche else -0.18)
			gauche = not gauche
			var trace := Decal.new()
			trace.texture_albedo = texture
			trace.size = Vector3(0.22, 1.0, 0.42)
			trace.modulate = Color(0.25, 0.22, 0.2, 0.75)
			trace.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
			trace.rotation.y = atan2(-direction.x, -direction.y)
			trace.cull_mask = 1
			trace.distance_fade_enabled = true
			trace.distance_fade_begin = 30.0
			trace.distance_fade_length = 10.0
			dossier.add_child(trace)


# --- Failles ---------------------------------------------------------------------------

func _construire_failles() -> void:
	var dossier := Node3D.new()
	dossier.name = "Failles"
	_contenu.add_child(dossier)
	for k in FAILLES.size():
		var p: Vector2 = FAILLES[k]
		var f := Faille.new()
		f.name = "Faille%d" % k
		f.identifiant = "faille_foret_%d" % k
		f.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
		dossier.add_child(f)


# --- Paysage lointain ---------------------------------------------------------------

func _construire_lointain() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 70
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.8
	bruit.fractal_octaves = 4
	for k in 14:
		bruit.seed = graine + 400 + k
		var a := k * TAU / 14.0 + hasard.randf_range(-0.1, 0.1)
		var distance := hasard.randf_range(340.0, 430.0)
		var largeur := hasard.randf_range(150.0, 240.0)
		var montagne := MeshInstance3D.new()
		montagne.mesh = _maillage_bosse(bruit, Vector3(largeur, hasard.randf_range(60.0, 130.0), largeur * 0.6),
				1.4, 0.35, 28, Color(0, 0.7, 0.3))
		montagne.material_override = _mat_lointain()
		montagne.position = Vector3(cos(a) * distance, -8.0, sin(a) * distance)
		montagne.rotation.y = -a + PI / 2
		montagne.set_instance_shader_parameter("neige_en_plus", 0.85)
		montagne.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(montagne)


func _construire_limites() -> void:
	var limites := Node3D.new()
	limites.name = "Limites"
	_contenu.add_child(limites)
	var demi := taille_terrain * 0.5 - 6.0
	for donnees in [[Vector3(2, 140, taille_terrain), Vector3(-demi, 40, 0)], [Vector3(2, 140, taille_terrain), Vector3(demi, 40, 0)],
			[Vector3(taille_terrain, 140, 2), Vector3(0, 40, -demi)], [Vector3(taille_terrain, 140, 2), Vector3(0, 40, demi)]]:
		var corps := StaticBody3D.new()
		corps.position = donnees[1]
		var forme := CollisionShape3D.new()
		var boite := BoxShape3D.new()
		boite.size = donnees[0]
		forme.shape = boite
		corps.add_child(forme)
		limites.add_child(corps)


# --- Quête : Kéo et Grise ---------------------------------------------------------------

func _construire_quete() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quete"
	_contenu.add_child(dossier)
	var keo := Pnj.new()
	keo.name = "Keo"
	keo.identifiant = "keo"
	keo.position = Vector3(CLAIRIERE.x - 2.5, hauteur(CLAIRIERE.x - 2.5, CLAIRIERE.y), CLAIRIERE.y)
	keo.rotation.y = -PI / 2
	dossier.add_child(keo)
	var grise := Grise.new()
	grise.name = "Grise"
	var pg := CLAIRIERE + Vector2(2.5, 0.5)
	grise.position = Vector3(pg.x, hauteur(pg.x, pg.y), pg.y)
	grise.rotation.y = PI * 0.4
	grise.add_to_group("decor_quete")
	grise.set_meta("identifiant", "grise")
	dossier.add_child(grise)
	var soigner := ObjetQuete.new()
	soigner.name = "SoignerGrise"
	soigner.identifiant = "soigner_grise"
	soigner.invite = "[F] Soigner Grise (difficile)"
	soigner.portee = 2.2
	soigner.position = grise.position + Vector3(0.8, 0, 0)
	dossier.add_child(soigner)
	var liberer := ObjetQuete.new()
	liberer.name = "LibererGrise"
	liberer.identifiant = "liberer_grise"
	liberer.invite = "[F] Dire à Kéo de laisser partir Grise"
	liberer.portee = 2.2
	liberer.position = keo.position + Vector3(-0.8, 0, 0)
	dossier.add_child(liberer)
	# Repères de la carte.
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.LIEU, "Passe (vers la Steppe)", ENTREE + Vector2(6, 0))
	repere.call(MarqueurCarte.Type.LIEU, "Le gué", Vector2(riviere_x(GUE_Z), GUE_Z))
	repere.call(MarqueurCarte.Type.LIEU, "Clairière", CLAIRIERE)
	for f in FAILLES:
		repere.call(MarqueurCarte.Type.DANGER, "Faille", f)


func _surveiller_sortie() -> void:
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return
	var p := Vector2(joueur.global_position.x, joueur.global_position.z)
	if p.x < ENTREE.x - 4.0 and absf(p.y - ENTREE.y) < 16.0:
		var quete := get_tree().get_first_node_in_group("quete")
		if quete != null and quete.has_method("changer_de_zone"):
			quete.changer_de_zone("steppe")
