@tool
extends "res://scripts/monde/prehistoire/ile_prehistoire.gd"
## Base commune des zones de l'île d'Égypte (Port des Marais, Carrières de Toura…).
##
## Vers -2560, sous le roi Khéops, pendant la crue du Nil. On réutilise les outils
## des zones de la Préhistoire (terrain, sols, rochers, herbe, feux), et on y ajoute
## ce qui est propre à l'Égypte : l'eau du Nil, les papyrus, les palmiers, les
## barques, les maisons en briques crues, les jarres, la Grande Pyramide au loin et
## le portail de la Vigie.
##
## Les textures et modèles Poly Haven de l'Égypte sont dans assets/egypte/ ; s'ils
## ne sont pas encore téléchargés, on prend ceux de la Préhistoire (dans
## assets/prehistoire/), puis des couleurs simples.

const DOSSIER_EGYPTE := "res://assets/egypte/"
const SHADER_EAU := preload("res://shaders/prehistoire_mer.gdshader")
const SHADER_PORTAIL := preload("res://shaders/prehistoire_portail.gdshader")

## Le portail de la Vigie de la zone (Vector2.INF si aucun).
var portail := Vector2.INF
var _voile_portail: MeshInstance3D
var _zone_portail: Area3D
var _portail_arme := false
## Barques qui se balancent sur l'eau.
var _flotteurs: Array[Node3D] = []
static var _textures_palme: Texture2D


func _ready() -> void:
	super._ready()


func _process(delta: float) -> void:
	super._process(delta)
	if _voile_portail != null and is_instance_valid(_voile_portail):
		_voile_portail.rotation.z = _temps * 0.4
	for k in _flotteurs.size():
		var b := _flotteurs[k]
		if not is_instance_valid(b):
			continue
		var base: float = b.get_meta("y", b.position.y)
		b.position.y = base + sin(_temps * 0.9 + k * 1.7) * 0.05
		b.rotation.z = sin(_temps * 0.7 + k) * 0.015
	if not Engine.is_editor_hint():
		_surveiller_portail()


# --- Ressources : d'abord l'Égypte, puis la Préhistoire ----------------------------------

func _texture(id: String, carte: String) -> Texture2D:
	for dossier in [DOSSIER_EGYPTE, DOSSIER]:
		var chemin: String = dossier + "textures/%s/%s_%s.jpg" % [id, id, carte]
		if ResourceLoader.exists(chemin):
			return load(chemin)
	return null


func _modele(id: String, position_m: Vector3, angle_y := 0.0, echelle := 1.0, parent: Node3D = null) -> Node3D:
	for dossier in [DOSSIER_EGYPTE, DOSSIER]:
		var chemin: String = dossier + "modeles/%s/%s.gltf" % [id, id]
		if ResourceLoader.exists(chemin):
			var instance := (load(chemin) as PackedScene).instantiate() as Node3D
			instance.position = position_m
			instance.rotation.y = angle_y
			instance.scale = Vector3.ONE * echelle
			(parent if parent != null else _contenu).add_child(instance)
			return instance
	return null


func _ciel_egypte(id: String) -> Texture2D:
	var chemin := DOSSIER_EGYPTE + "ciel/%s.hdr" % id
	return load(chemin) if ResourceLoader.exists(chemin) else null


## Matériau PBR avec la première texture trouvée de la liste (ou une couleur simple).
func _mat_choix(ids: Array, couleur: Color, rugosite := 0.9, taille_motif := 2.0) -> StandardMaterial3D:
	return _mat_pbr(_premiere_texture(ids), couleur, rugosite, taille_motif)


func _mat_briques() -> StandardMaterial3D:
	return _mat_choix(["clay_block_wall", "brown_mud_02"], Color(0.72, 0.6, 0.47), 0.95, 2.5)


func _mat_enduit() -> StandardMaterial3D:
	return _mat_choix(["clay_plaster", "patterned_clay_plaster", "brown_mud_02"], Color(0.82, 0.72, 0.58), 0.95, 3.0)


func _mat_calcaire() -> StandardMaterial3D:
	return _mat_choix(["white_sandstone_blocks_02", "large_sandstone_blocks", "cliff_side"], Color(0.93, 0.9, 0.82), 0.8, 2.0)


func _mat_bois() -> StandardMaterial3D:
	return _mat_choix(["weathered_planks", "rough_wood"], Color(0.62, 0.5, 0.38), 0.85, 1.5)


func _mat_roseau() -> StandardMaterial3D:
	return _mat_choix(["reed_roof_04", "riet_01", "withered_grass"], Color(0.72, 0.62, 0.4), 1.0, 2.0)


func _mat_lin(couleur := Color(0.93, 0.9, 0.82)) -> StandardMaterial3D:
	var cle := "lin_%s" % couleur.to_html()
	if not _materiaux.has(cle):
		var m := StandardMaterial3D.new()
		m.albedo_color = couleur
		m.roughness = 0.95
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.backlight_enabled = true
		m.backlight = Color(0.35, 0.32, 0.26)
		_materiaux[cle] = m
	return _materiaux[cle]


# --- Formes ---------------------------------------------------------------------------------

## Relie des sections ovales le long de Z : [z, demi-largeur, demi-hauteur, hauteur du centre].
static func _loft(sections: Array, segments := 16, demi := false) -> ArrayMesh:
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var anneaux: Array = []
	var pas := segments if not demi else segments
	for s in sections:
		var anneau := PackedVector3Array()
		for k in pas + (1 if demi else 0):
			# Coque : seulement le demi-ovale du dessous (de PI à 2 PI).
			var a := (PI + PI * k / pas) if demi else TAU * k / pas
			anneau.append(Vector3(cos(a) * float(s[1]), float(s[3]) + sin(a) * float(s[2]), float(s[0])))
		anneaux.append(anneau)
	var n_points: int = (anneaux[0] as PackedVector3Array).size()
	for i in anneaux.size() - 1:
		var a: PackedVector3Array = anneaux[i]
		var b: PackedVector3Array = anneaux[i + 1]
		for k in (n_points - 1 if demi else n_points):
			var k2 := (k + 1) % n_points
			outil.add_vertex(a[k])
			outil.add_vertex(b[k])
			outil.add_vertex(a[k2])
			outil.add_vertex(a[k2])
			outil.add_vertex(b[k])
			outil.add_vertex(b[k2])
	outil.generate_normals()
	return outil.commit()


## Jarre tournée (profil de potier) : liste de [hauteur, rayon].
static func _tour(profil: Array, segments := 16) -> ArrayMesh:
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in profil.size() - 1:
		var p0: Array = profil[i]
		var p1: Array = profil[i + 1]
		for k in segments:
			var a0 := TAU * k / segments
			var a1 := TAU * (k + 1) / segments
			var v00 := Vector3(cos(a0) * p0[1], p0[0], sin(a0) * p0[1])
			var v01 := Vector3(cos(a1) * p0[1], p0[0], sin(a1) * p0[1])
			var v10 := Vector3(cos(a0) * p1[1], p1[0], sin(a0) * p1[1])
			var v11 := Vector3(cos(a1) * p1[1], p1[0], sin(a1) * p1[1])
			outil.add_vertex(v00)
			outil.add_vertex(v10)
			outil.add_vertex(v01)
			outil.add_vertex(v01)
			outil.add_vertex(v10)
			outil.add_vertex(v11)
	outil.generate_normals()
	return outil.commit()


func _jarre(parent: Node3D, p: Vector3, taille := 1.0, angle := 0.0) -> void:
	if not _materiaux.has("forme_jarre"):
		_materiaux["forme_jarre"] = _tour([[0.0, 0.0], [0.02, 0.1], [0.12, 0.2], [0.35, 0.27], [0.55, 0.24],
				[0.68, 0.14], [0.74, 0.1], [0.78, 0.12], [0.8, 0.1]], 14)
		var m := _mat_pbr("", Color(0.66, 0.42, 0.28), 0.9)
		var argile := _premiere_texture(["clay_plaster", "brown_mud_02"])
		if argile != "":
			m = _mat_pbr(argile, Color(0.95, 0.68, 0.5), 0.9, 0.6)
		_materiaux["mat_jarre"] = m
	var mi := MeshInstance3D.new()
	mi.mesh = _materiaux["forme_jarre"]
	mi.material_override = _materiaux["mat_jarre"]
	mi.position = p
	mi.rotation.y = angle
	mi.scale = Vector3.ONE * taille
	parent.add_child(mi)


## Un bloc de calcaire blanc de Toura (environ 1,5 × 1 × 1 m, 2,5 tonnes).
func _bloc_calcaire(parent: Node3D, centre: Vector3, taille := Vector3(1.5, 1.0, 1.0), angle := 0.0,
		collision := true) -> MeshInstance3D:
	var bloc := _boite(taille, centre, _mat_calcaire(), parent, collision)
	bloc.rotation.y = angle
	return bloc


# --- Eau du Nil -------------------------------------------------------------------------------

## L'eau de la crue : une grande nappe brun-vert chargée de limon, presque opaque.
func _construire_eau(centre := Vector3.ZERO, taille := Vector2(3000, 3000)) -> void:
	var plan := PlaneMesh.new()
	plan.size = taille
	plan.subdivide_width = 160
	plan.subdivide_depth = 160
	var m := ShaderMaterial.new()
	m.shader = SHADER_EAU
	m.set_shader_parameter("vagues_a", _texture_vagues(graine + 30, 0.02))
	m.set_shader_parameter("vagues_b", _texture_vagues(graine + 31, 0.06))
	m.set_shader_parameter("bruit_ecume", _bruit())
	m.set_shader_parameter("couleur_profonde", Color(0.07, 0.075, 0.04))
	m.set_shader_parameter("couleur_claire", Color(0.3, 0.27, 0.15))
	m.set_shader_parameter("couleur_ecume", Color(0.72, 0.66, 0.52))
	m.set_shader_parameter("transparence", 1.1)
	m.set_shader_parameter("largeur_ecume", 0.35)
	m.set_shader_parameter("vitesse", 0.012)
	m.set_shader_parameter("hauteur_houle", 0.03)
	var eau := MeshInstance3D.new()
	eau.name = "Nil"
	eau.mesh = plan
	eau.material_override = m
	eau.position = centre + Vector3(0, NIVEAU_MER, 0)
	eau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_contenu.add_child(eau)


# --- Papyrus et roseaux ----------------------------------------------------------------------

## Une touffe de papyrus : des tiges triangulaires de 2 à 4 m surmontées d'une
## ombelle en plumeau (les fines tiges vertes qui retombent).
func _maillage_papyrus(hasard: RandomNumberGenerator) -> ArrayMesh:
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tiges := hasard.randi_range(7, 11)
	for t in tiges:
		var base := Vector3(hasard.randf_range(-0.35, 0.35), 0, hasard.randf_range(-0.35, 0.35))
		var haut_tige := hasard.randf_range(2.0, 3.8)
		var penche := Vector3(base.x, 0, base.z).normalized() * hasard.randf_range(0.1, 0.45)
		var sommet := base + Vector3(0, haut_tige, 0) + penche
		var r := 0.022
		# La tige : un prisme à trois faces (le papyrus a une tige triangulaire).
		for f in 3:
			var a0 := TAU * f / 3.0
			var a1 := TAU * (f + 1) / 3.0
			var c0 := Vector3(cos(a0), 0, sin(a0)) * r
			var c1 := Vector3(cos(a1), 0, sin(a1)) * r
			outil.set_uv(Vector2(0, 0)); outil.add_vertex(base + c0)
			outil.set_uv(Vector2(0, 0.82)); outil.add_vertex(sommet + c0 * 0.5)
			outil.set_uv(Vector2(1, 0)); outil.add_vertex(base + c1)
			outil.set_uv(Vector2(1, 0)); outil.add_vertex(base + c1)
			outil.set_uv(Vector2(0, 0.82)); outil.add_vertex(sommet + c0 * 0.5)
			outil.set_uv(Vector2(1, 0.82)); outil.add_vertex(sommet + c1 * 0.5)
		# L'ombelle : des brins fins qui partent du sommet et retombent en gerbe.
		var brins := 16
		for b in brins:
			var a := TAU * b / brins + hasard.randf_range(-0.2, 0.2)
			var dir := Vector3(cos(a), 0, sin(a))
			var longueur := hasard.randf_range(0.35, 0.55)
			var milieu := sommet + dir * longueur * 0.55 + Vector3(0, longueur * 0.35, 0)
			var bout := sommet + dir * longueur + Vector3(0, longueur * 0.05 - 0.08, 0)
			var cote := dir.cross(Vector3.UP).normalized() * 0.018
			outil.set_uv(Vector2(0, 0.84)); outil.add_vertex(sommet - cote)
			outil.set_uv(Vector2(1, 0.84)); outil.add_vertex(sommet + cote)
			outil.set_uv(Vector2(0, 0.95)); outil.add_vertex(milieu - cote)
			outil.set_uv(Vector2(1, 0.84)); outil.add_vertex(sommet + cote)
			outil.set_uv(Vector2(1, 0.95)); outil.add_vertex(milieu + cote)
			outil.set_uv(Vector2(0, 0.95)); outil.add_vertex(milieu - cote)
			outil.set_uv(Vector2(0, 0.95)); outil.add_vertex(milieu - cote * 0.8)
			outil.set_uv(Vector2(1, 0.95)); outil.add_vertex(milieu + cote * 0.8)
			outil.set_uv(Vector2(0.5, 1.0)); outil.add_vertex(bout)
	outil.generate_normals()
	return outil.commit()


## Sème des touffes de papyrus là où « ou_pousser(x, z) » renvoie vrai.
func _semer_papyrus(nombre: int, zone: Rect2, ou_pousser: Callable, graine_p: int) -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine_p
	var materiau := ShaderMaterial.new()
	materiau.shader = SHADER_HERBE
	materiau.set_shader_parameter("couleur_base", Color(0.16, 0.22, 0.07))
	materiau.set_shader_parameter("couleur_pointe", Color(0.52, 0.6, 0.2))
	materiau.set_shader_parameter("couleur_givre", Color(0.62, 0.64, 0.28))
	materiau.set_shader_parameter("force_vent", 0.08)
	var formes: Array[ArrayMesh] = []
	for k in 5:
		var f := _maillage_papyrus(hasard)
		f.surface_set_material(0, materiau)
		formes.append(f)
	# Par blocs de 24 m, pour que les touffes lointaines disparaissent ensemble.
	const BLOC := 24.0
	var blocs := {}
	var places := 0
	var essais := 0
	while places < nombre and essais < nombre * 6:
		essais += 1
		var x := hasard.randf_range(zone.position.x, zone.end.x)
		var z := hasard.randf_range(zone.position.y, zone.end.y)
		if not ou_pousser.call(x, z):
			continue
		var cle := Vector2i(floori(x / BLOC), floori(z / BLOC))
		if not blocs.has(cle):
			blocs[cle] = []
		var t := Transform3D(Basis(Vector3.UP, hasard.randf() * TAU).scaled(Vector3.ONE * hasard.randf_range(0.75, 1.25)),
				Vector3(x, hauteur(x, z) - 0.1, z))
		blocs[cle].append([hasard.randi() % formes.size(), t])
		places += 1
	for cle in blocs:
		var par_forme := {}
		for e in blocs[cle]:
			if not par_forme.has(e[0]):
				par_forme[e[0]] = []
			par_forme[e[0]].append(e[1])
		for f in par_forme:
			var liste: Array = par_forme[f]
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.use_custom_data = true
			multi.mesh = formes[f]
			multi.instance_count = liste.size()
			for k in liste.size():
				multi.set_instance_transform(k, liste[k])
				multi.set_instance_custom_data(k, Color(hasard.randf(), 0, 0, 0))
			var instance := MultiMeshInstance3D.new()
			instance.multimesh = multi
			instance.visibility_range_end = 170.0
			instance.visibility_range_end_margin = 15.0
			instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			_contenu.add_child(instance)


## Feuilles de nénuphar (lotus) posées sur l'eau calme, avec quelques fleurs bleues et blanches.
func _semer_lotus(nombre: int, zone: Rect2, ou_pousser: Callable, graine_l: int) -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine_l
	var feuille := CylinderMesh.new()
	feuille.top_radius = 0.28
	feuille.bottom_radius = 0.28
	feuille.height = 0.01
	feuille.radial_segments = 12
	var mf := StandardMaterial3D.new()
	mf.albedo_color = Color(0.2, 0.32, 0.12)
	mf.roughness = 0.35
	feuille.material = mf
	var fleur := SphereMesh.new()
	fleur.radius = 0.09
	fleur.height = 0.1
	fleur.radial_segments = 8
	fleur.rings = 4
	var feuilles: Array[Transform3D] = []
	var fleurs: Array[Transform3D] = []
	var couleurs: Array[Color] = []
	var essais := 0
	while feuilles.size() < nombre and essais < nombre * 8:
		essais += 1
		var x := hasard.randf_range(zone.position.x, zone.end.x)
		var z := hasard.randf_range(zone.position.y, zone.end.y)
		if not ou_pousser.call(x, z):
			continue
		for k in hasard.randi_range(2, 6):
			var p := Vector3(x + hasard.randf_range(-1.2, 1.2), NIVEAU_MER + 0.015, z + hasard.randf_range(-1.2, 1.2))
			feuilles.append(Transform3D(Basis(Vector3.UP, hasard.randf() * TAU).scaled(Vector3.ONE * hasard.randf_range(0.6, 1.3)), p))
			if hasard.randf() < 0.18:
				fleurs.append(Transform3D(Basis.IDENTITY, p + Vector3(0.1, 0.06, 0)))
				couleurs.append(Color(0.55, 0.65, 0.95) if hasard.randf() < 0.6 else Color(0.97, 0.95, 0.9))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = feuille
	mm.instance_count = feuilles.size()
	for k in feuilles.size():
		mm.set_instance_transform(k, feuilles[k])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 90.0
	_contenu.add_child(mi)
	var mfl := StandardMaterial3D.new()
	mfl.vertex_color_use_as_albedo = true
	mfl.roughness = 0.6
	mfl.emission_enabled = true
	mfl.emission = Color(0.15, 0.15, 0.2)
	fleur.material = mfl
	var mm2 := MultiMesh.new()
	mm2.transform_format = MultiMesh.TRANSFORM_3D
	mm2.use_colors = true
	mm2.mesh = fleur
	mm2.instance_count = fleurs.size()
	for k in fleurs.size():
		mm2.set_instance_transform(k, fleurs[k])
		mm2.set_instance_color(k, couleurs[k])
	var mi2 := MultiMeshInstance3D.new()
	mi2.multimesh = mm2
	mi2.visibility_range_end = 70.0
	_contenu.add_child(mi2)


# --- Palmiers dattiers ------------------------------------------------------------------------

## Image d'une palme : une nervure centrale et des folioles fines de chaque côté.
static func _texture_palme() -> Texture2D:
	if _textures_palme != null:
		return _textures_palme
	var largeur := 128
	var hauteur_img := 512
	var image := Image.create(largeur, hauteur_img, true, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 2560
	var trace := func(a: Vector2, b: Vector2, epaisseur: float, couleur: Color) -> void:
		var n := int(a.distance_to(b)) + 1
		for k in n + 1:
			var p := a.lerp(b, float(k) / n)
			var e := epaisseur * (1.0 - 0.6 * float(k) / n)
			for j in range(int(p.y - e) - 1, int(p.y + e) + 2):
				for i in range(int(p.x - e) - 1, int(p.x + e) + 2):
					if i >= 0 and j >= 0 and i < largeur and j < hauteur_img and Vector2(i, j).distance_to(p) <= e:
						image.set_pixel(i, j, couleur)
	# Folioles : de la base (en bas de l'image) vers la pointe (en haut).
	var y := hauteur_img - 30
	while y > 8:
		var t := 1.0 - float(y) / hauteur_img
		var longueur := lerpf(58.0, 18.0, t) * hasard.randf_range(0.85, 1.05)
		var vert := Color(0.24, 0.33, 0.13).lerp(Color(0.38, 0.42, 0.18), hasard.randf()) * hasard.randf_range(0.85, 1.1)
		vert.a = 1.0
		for cote in [-1.0, 1.0]:
			var depart := Vector2(largeur * 0.5, y)
			var fin := depart + Vector2(cote * longueur, -longueur * 0.55)
			trace.call(depart, fin, 2.2, vert)
		y -= int(hasard.randf_range(6.0, 9.0))
	trace.call(Vector2(largeur * 0.5, hauteur_img - 1), Vector2(largeur * 0.5, 4), 2.0, Color(0.42, 0.4, 0.2))
	image.generate_mipmaps()
	_textures_palme = ImageTexture.create_from_image(image)
	return _textures_palme


## Une palme arquée qui retombe (bande courbe, la texture fait les folioles).
static func _ajouter_palme(outil: SurfaceTool, origine: Vector3, direction: Vector3, longueur: float,
		courbure: float, largeur: float) -> void:
	var cote := direction.cross(Vector3.UP).normalized()
	var segments := 8
	var precedent_g := Vector3.ZERO
	var precedent_d := Vector3.ZERO
	for s in segments + 1:
		var t := float(s) / segments
		var centre := origine + direction * longueur * t + Vector3(0, longueur * 0.35 * t - courbure * t * t * longueur, 0)
		var l := largeur * (1.0 - t * 0.7)
		# Les deux moitiés de la palme sont un peu relevées (en V).
		var g := centre - cote * l + Vector3(0, l * 0.25, 0)
		var d := centre + cote * l + Vector3(0, l * 0.25, 0)
		if s > 0:
			var v0 := 1.0 - float(s - 1) / segments
			var v1 := 1.0 - t
			outil.set_uv(Vector2(0, v0)); outil.add_vertex(precedent_g)
			outil.set_uv(Vector2(1, v0)); outil.add_vertex(precedent_d)
			outil.set_uv(Vector2(0, v1)); outil.add_vertex(g)
			outil.set_uv(Vector2(1, v0)); outil.add_vertex(precedent_d)
			outil.set_uv(Vector2(1, v1)); outil.add_vertex(d)
			outil.set_uv(Vector2(0, v1)); outil.add_vertex(g)
		precedent_g = g
		precedent_d = d


## Un palmier dattier complet (tronc courbe + couronne), en un seul maillage à deux surfaces.
func _maillage_palmier(hasard: RandomNumberGenerator, haut: float) -> ArrayMesh:
	var tronc := SurfaceTool.new()
	tronc.begin(Mesh.PRIMITIVE_TRIANGLES)
	var courbe := Vector3(hasard.randf_range(-1, 1), 0, hasard.randf_range(-1, 1)).normalized() * hasard.randf_range(0.3, 1.4)
	var anneaux := 14
	var segments := 10
	var points: Array[Vector3] = []
	for a in anneaux + 1:
		var t := float(a) / anneaux
		points.append(courbe * t * t + Vector3(0, haut * t, 0))
	for a in anneaux:
		var r0 := lerpf(0.26, 0.17, float(a) / anneaux)
		var r1 := lerpf(0.26, 0.17, float(a + 1) / anneaux)
		# Le tronc est couvert de la base des anciennes palmes : un relief en anneaux.
		var bosse0 := 1.0 + 0.08 * (a % 2)
		var bosse1 := 1.0 + 0.08 * ((a + 1) % 2)
		for k in segments:
			var c0 := Vector3(cos(TAU * k / segments), 0, sin(TAU * k / segments))
			var c1 := Vector3(cos(TAU * (k + 1) / segments), 0, sin(TAU * (k + 1) / segments))
			tronc.add_vertex(points[a] + c0 * r0 * bosse0)
			tronc.add_vertex(points[a + 1] + c0 * r1 * bosse1)
			tronc.add_vertex(points[a] + c1 * r0 * bosse0)
			tronc.add_vertex(points[a] + c1 * r0 * bosse0)
			tronc.add_vertex(points[a + 1] + c0 * r1 * bosse1)
			tronc.add_vertex(points[a + 1] + c1 * r1 * bosse1)
	tronc.generate_normals()
	var maillage := tronc.commit()
	maillage.surface_set_material(0, _mat_choix(["palm_tree_bark", "palm_bark", "rough_wood"], Color(0.55, 0.45, 0.36), 0.95, 0.8))
	var couronne := SurfaceTool.new()
	couronne.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tete := points[-1]
	var palmes := hasard.randi_range(16, 22)
	for p in palmes:
		var a := TAU * p / palmes + hasard.randf_range(-0.15, 0.15)
		var montee := hasard.randf_range(-0.3, 0.7)
		var dir := Vector3(cos(a), montee, sin(a)).normalized()
		_ajouter_palme(couronne, tete, dir, hasard.randf_range(2.6, 3.6), hasard.randf_range(0.45, 0.9), 0.42)
	couronne.generate_normals()
	couronne.commit(maillage)
	var m := StandardMaterial3D.new()
	m.albedo_texture = _texture_palme()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.7
	m.backlight_enabled = true
	m.backlight = Color(0.25, 0.3, 0.1)
	maillage.surface_set_material(1, m)
	return maillage


## Plante des palmiers aux points donnés (avec une collision sur le tronc).
func _planter_palmiers(points: Array, graine_p: int) -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine_p
	var variantes: Array[ArrayMesh] = []
	for k in 5:
		variantes.append(_maillage_palmier(hasard, hasard.randf_range(7.0, 12.0)))
	var dossier := Node3D.new()
	dossier.name = "Palmiers"
	_contenu.add_child(dossier)
	var forme := CylinderShape3D.new()
	forme.radius = 0.28
	forme.height = 4.0
	for p in points:
		var v: Vector2 = p
		var corps := StaticBody3D.new()
		corps.position = Vector3(v.x, hauteur(v.x, v.y) - 0.2, v.y)
		corps.rotation.y = hasard.randf() * TAU
		var mi := MeshInstance3D.new()
		mi.mesh = variantes[hasard.randi() % variantes.size()]
		mi.scale = Vector3.ONE * hasard.randf_range(0.85, 1.15)
		mi.visibility_range_end = 450.0
		corps.add_child(mi)
		var c := CollisionShape3D.new()
		c.shape = forme
		c.position.y = 2.0
		corps.add_child(c)
		dossier.add_child(corps)


# --- Barques ----------------------------------------------------------------------------------

## Une barque en bois du Nil, aux bouts relevés. longueur en mètres ; « chargee » pose
## un bloc de calcaire au milieu (les cargos de Merer).
func _barque(parent: Node3D, p: Vector3, angle: float, longueur := 9.0, chargee := false, flotte := true) -> Node3D:
	var b := Node3D.new()
	b.name = "Barque"
	b.position = p
	b.rotation.y = angle
	parent.add_child(b)
	var demi := longueur * 0.5
	var large := longueur * 0.13
	var sections := []
	for k in 11:
		var t := float(k) / 10.0
		var z := lerpf(-demi, demi, t)
		var forme := sin(t * PI)
		# Les bouts se relèvent (proue et poupe en croissant).
		var releve := pow(absf(t - 0.5) * 2.0, 3.0) * longueur * 0.11
		sections.append([z, maxf(large * pow(forme, 0.6), 0.05), maxf(0.55 * pow(forme, 0.4), 0.08), 0.35 + releve])
	var coque := MeshInstance3D.new()
	coque.mesh = _loft(sections, 12, true)
	var bois := _mat_bois()
	coque.material_override = bois
	b.add_child(coque)
	# Le pont : des planches posées en travers.
	var pont := _boite(Vector3(large * 1.6, 0.05, longueur * 0.72), Vector3(0, 0.3, 0), bois, b, false)
	pont.name = "Pont"
	# Bancs des rameurs et rames rangées.
	for k in int(longueur / 2.2):
		_boite(Vector3(large * 1.7, 0.06, 0.18), Vector3(0, 0.42, -demi * 0.6 + k * 2.2), bois, b, false)
	# Les deux grandes rames-gouvernails à l'arrière.
	for cote in [-1.0, 1.0]:
		var rame := MeshInstance3D.new()
		rame.mesh = _cylindre(0.04, 0.04, longueur * 0.4, 6)
		rame.material_override = bois
		rame.position = Vector3(cote * large * 0.7, 0.6, demi * 0.75)
		rame.rotation = Vector3(-1.1, 0, cote * 0.25)
		b.add_child(rame)
	if chargee:
		_bloc_calcaire(b, Vector3(0, 0.8, -0.3), Vector3(1.4, 1.0, 1.6), 0.0, false)
	# Collision simple : on peut monter sur le pont.
	var corps := StaticBody3D.new()
	var c := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(large * 1.8, 0.6, longueur * 0.85)
	c.shape = boite
	c.position.y = 0.05
	corps.add_child(c)
	b.add_child(corps)
	if flotte:
		b.set_meta("y", p.y)
		_flotteurs.append(b)
	return b


# --- Constructions en briques crues ---------------------------------------------------------

## Une maison ou un magasin en briques crues enduites, à toit plat (avec une porte sombre).
func _maison(parent: Node3D, centre: Vector2, taille: Vector3, angle := 0.0) -> Node3D:
	var m := Node3D.new()
	m.position = Vector3(centre.x, hauteur(centre.x, centre.y) - 0.3, centre.y)
	m.rotation.y = angle
	parent.add_child(m)
	_boite(taille + Vector3(0, 0.3, 0), Vector3(0, (taille.y + 0.3) * 0.5, 0), _mat_enduit(), m)
	# Muret du toit-terrasse et poutres de palmier qui dépassent.
	_boite(Vector3(taille.x + 0.1, 0.35, taille.z + 0.1), Vector3(0, taille.y + 0.45, 0), _mat_briques(), m, false)
	var bois := _mat_choix(["palm_tree_bark", "rough_wood"], Color(0.5, 0.42, 0.32), 0.95, 0.5)
	for k in int(taille.x / 0.9):
		var poutre := MeshInstance3D.new()
		poutre.mesh = _cylindre(0.07, 0.07, 0.5, 6)
		poutre.material_override = bois
		poutre.rotation.x = PI / 2
		poutre.position = Vector3(-taille.x * 0.5 + 0.45 + k * 0.9, taille.y + 0.1, taille.z * 0.5 + 0.15)
		m.add_child(poutre)
	# Porte : un trou sombre encadré de bois.
	var porte := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.95, 1.9)
	porte.mesh = q
	porte.material_override = _mat_pbr("", Color(0.04, 0.035, 0.03), 1.0)
	porte.position = Vector3(0, 1.25, taille.z * 0.5 + 0.02)
	m.add_child(porte)
	_boite(Vector3(1.2, 0.14, 0.2), Vector3(0, 2.25, taille.z * 0.5 + 0.06), bois, m, false)
	return m


## Un auvent de lin sur quatre poteaux (l'ombre de l'intendant, des scribes…).
func _auvent(parent: Node3D, centre: Vector2, taille: Vector2, haut := 2.6, couleur := Color(0.93, 0.9, 0.8)) -> void:
	var y := hauteur(centre.x, centre.y)
	var bois := _mat_choix(["rough_wood"], Color(0.5, 0.4, 0.3), 0.9, 1.0)
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			var poteau := MeshInstance3D.new()
			poteau.mesh = _cylindre(0.05, 0.06, haut, 6)
			poteau.material_override = bois
			poteau.position = Vector3(centre.x + sx * taille.x, y + haut * 0.5, centre.y + sz * taille.y)
			parent.add_child(poteau)
	var toile := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = taille + Vector2(0.3, 0.3)
	plan.subdivide_width = 4
	plan.subdivide_depth = 4
	toile.mesh = plan
	toile.material_override = _mat_lin(couleur)
	toile.position = Vector3(centre.x, y + haut, centre.y)
	toile.rotation.x = 0.04
	parent.add_child(toile)


# --- La Grande Pyramide (au loin) -------------------------------------------------------------

## La pyramide de Khéops en fin de chantier : 230 m de côté, 146 m de haut. Le bas est
## déjà revêtu de calcaire blanc poli ; le haut montre encore ses gradins et la rampe.
func _construire_pyramide(centre: Vector3, angle := 0.0) -> void:
	var p := Node3D.new()
	p.name = "GrandePyramide"
	p.position = centre
	p.rotation.y = angle
	_contenu.add_child(p)
	var cote := 230.0
	var haut := 146.0
	var revetu := 0.72 # part de la hauteur déjà revêtue
	# Partie revêtue : une pyramide tronquée lisse.
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h1 := haut * revetu
	var demi0 := cote * 0.5
	var demi1 := demi0 * (1.0 - revetu)
	var bas := [Vector3(-demi0, 0, -demi0), Vector3(demi0, 0, -demi0), Vector3(demi0, 0, demi0), Vector3(-demi0, 0, demi0)]
	var haut_coins := [Vector3(-demi1, h1, -demi1), Vector3(demi1, h1, -demi1), Vector3(demi1, h1, demi1), Vector3(-demi1, h1, demi1)]
	for k in 4:
		var k2 := (k + 1) % 4
		outil.set_uv(Vector2(0, 0)); outil.add_vertex(bas[k])
		outil.set_uv(Vector2(1, 1)); outil.add_vertex(haut_coins[k2])
		outil.set_uv(Vector2(1, 0)); outil.add_vertex(bas[k2])
		outil.set_uv(Vector2(0, 0)); outil.add_vertex(bas[k])
		outil.set_uv(Vector2(0, 1)); outil.add_vertex(haut_coins[k])
		outil.set_uv(Vector2(1, 1)); outil.add_vertex(haut_coins[k2])
	outil.generate_normals()
	var lisse := MeshInstance3D.new()
	lisse.mesh = outil.commit()
	var blanc := _mat_choix(["white_sandstone_blocks_02", "white_plaster_rough_01", "cliff_side"], Color(0.95, 0.92, 0.84), 0.55, 6.0)
	lisse.material_override = blanc
	lisse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(lisse)
	# Le sommet en gradins (pierre plus jaune, pas encore habillée).
	var jaune := _mat_choix(["sandstone_blocks_08", "large_sandstone_blocks", "cliff_side"], Color(0.82, 0.72, 0.55), 0.95, 4.0)
	var marche := 5.0
	var y := h1
	while y < haut - 8.0:
		var demi := demi0 * (1.0 - y / haut)
		var gradin := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(demi * 2.0, marche, demi * 2.0)
		gradin.mesh = b
		gradin.material_override = jaune
		gradin.position.y = y + marche * 0.5
		gradin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.add_child(gradin)
		y += marche
	# La rampe de chantier qui tourne autour du sommet (une large bande brune).
	var rampe := _mat_choix(["dry_ground_01", "dry_ground_rocks"], Color(0.62, 0.5, 0.36), 1.0, 4.0)
	for k in 3:
		var t := float(k) / 3.0
		var yr := lerpf(h1 * 0.85, haut - 12.0, t)
		var demi := demi0 * (1.0 - yr / haut) + 3.0
		var bande := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(demi * 1.6, 3.0, 7.0)
		bande.mesh = bb
		bande.material_override = rampe
		bande.position = Vector3(demi * 0.1, yr, demi)
		bande.rotation = Vector3(0, k * PI / 2, 0.12)
		bande.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bande.rotate_y(k * PI / 2)
		p.add_child(bande)


# --- Portail de la Vigie -----------------------------------------------------------------------

## Le portail, l'anneau sur son socle, avec la zone qui ramène au QG de Hikari Bay.
func _construire_portail(parent: Node3D, p: Vector2, angle := 0.0) -> void:
	portail = p
	var cyan := Color(0.3, 0.85, 1.0)
	var sol := hauteur(p.x, p.y)
	var n := Node3D.new()
	n.name = "Portail"
	n.position = Vector3(p.x, sol, p.y)
	n.rotation.y = angle
	parent.add_child(n)
	var socle := MeshInstance3D.new()
	socle.mesh = _cylindre(3.0, 3.3, 0.8, 32)
	socle.material_override = _metal()
	socle.position.y = 0.1
	n.add_child(socle)
	for r in [[2.1, 2.5, _metal()], [2.08, 2.16, _lumineux(cyan, 4.0)]]:
		var anneau := MeshInstance3D.new()
		var tore := TorusMesh.new()
		tore.inner_radius = r[0]
		tore.outer_radius = r[1]
		tore.rings = 48
		anneau.mesh = tore
		anneau.material_override = r[2]
		anneau.rotation.x = PI / 2
		anneau.position.y = 3.0
		n.add_child(anneau)
	_voile_portail = MeshInstance3D.new()
	var disque := QuadMesh.new()
	disque.size = Vector2(4.3, 4.3)
	_voile_portail.mesh = disque
	var voile := ShaderMaterial.new()
	voile.shader = SHADER_PORTAIL
	voile.set_shader_parameter("bruit", _bruit())
	_voile_portail.material_override = voile
	_voile_portail.position.y = 3.0
	_voile_portail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(_voile_portail)
	var lumiere := OmniLight3D.new()
	lumiere.light_color = cyan
	lumiere.light_energy = 2.5
	lumiere.omni_range = 14.0
	lumiere.position = Vector3(0, 3.0, -1.5)
	n.add_child(lumiere)
	for c in [-1.0, 1.0]:
		_boite(Vector3(0.5, 5.2, 0.6), Vector3(c * 2.3, 2.7, 0), _metal(), n).visible = false
	_zone_portail = Area3D.new()
	_zone_portail.name = "RetourHub"
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(3.2, 3.5, 0.8)
	forme.shape = boite
	_zone_portail.add_child(forme)
	_zone_portail.position = Vector3(0, 2.4, 0)
	_zone_portail.collision_mask = 2
	_zone_portail.monitoring = true
	n.add_child(_zone_portail)
	_zone_portail.body_entered.connect(_sur_portail)


## Le portail ne renvoie le joueur que s'il s'en est d'abord éloigné (à l'arrivée,
## on apparaît juste devant).
func _surveiller_portail() -> void:
	if _portail_arme or _zone_portail == null or portail == Vector2.INF:
		return
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur != null and Vector2(joueur.global_position.x, joueur.global_position.z).distance_to(portail) > 8.0:
		_portail_arme = true


func _sur_portail(corps: Node3D) -> void:
	if not _portail_arme or not corps.is_in_group("joueur_local"):
		return
	_portail_arme = false
	var quete := get_tree().get_first_node_in_group("quete")
	if quete != null and quete.has_method("rentrer_au_hub"):
		quete.rentrer_au_hub()


# --- Outils de géométrie --------------------------------------------------------------------

func _dans_rect(r: Rect2, x: float, z: float, fondu: float) -> float:
	var dx := maxf(r.position.x - x, x - r.end.x)
	var dz := maxf(r.position.y - z, z - r.end.y)
	return 1.0 - smoothstep(0.0, fondu, maxf(dx, dz))


func _distance_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
	return p.distance_to(a + (b - a) * t)


## Un grand plan de terrain coloré (pour prolonger le plateau au-delà de la zone).
func _plan_lointain(centre: Vector3, taille: Vector2, couleur: Color) -> MeshInstance3D:
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	outil.set_color(couleur)
	outil.set_normal(Vector3.UP)
	var d := taille * 0.5
	var coins := [Vector3(-d.x, 0, -d.y), Vector3(d.x, 0, -d.y), Vector3(d.x, 0, d.y), Vector3(-d.x, 0, d.y)]
	for i in [0, 1, 2, 0, 2, 3]:
		outil.add_vertex(coins[i])
	var mi := MeshInstance3D.new()
	mi.mesh = outil.commit()
	mi.material_override = _mat_lointain()
	mi.position = centre
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_contenu.add_child(mi)
	return mi


# --- Limites ------------------------------------------------------------------------------------

func _mur_invisible(parent: Node3D, taille: Vector3, centre: Vector3, angle := 0.0) -> StaticBody3D:
	var corps := StaticBody3D.new()
	corps.position = centre
	corps.rotation.y = angle
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = taille
	forme.shape = boite
	corps.add_child(forme)
	parent.add_child(corps)
	return corps
