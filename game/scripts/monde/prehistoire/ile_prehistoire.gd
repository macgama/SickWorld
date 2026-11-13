@tool
extends Node3D
## Base commune des zones de l'île de la Préhistoire (Côte Gelée, Steppe…).
##
## Elle sait fabriquer un terrain à partir d'une fonction de hauteur, poser les
## textures Poly Haven (galets, neige, terre, roche), l'herbe sèche, les rochers,
## la neige qui tombe et le ciel. Chaque zone (script qui hérite de celui-ci)
## décrit son relief (hauteur, _parts_sol) et ses décors (reconstruire).

## Nombre qui détermine la forme du relief. Même graine = même zone.
@export var graine := 17000:
	set(valeur):
		graine = valeur
		_demander_reconstruction()
## Nombre de touffes d'herbe sèche (baisser si le jeu rame).
@export var nombre_touffes := 90000:
	set(valeur):
		nombre_touffes = valeur
		_demander_reconstruction()
## Flocons de neige qui tombent autour du joueur.
@export var neige_qui_tombe := true:
	set(valeur):
		neige_qui_tombe = valeur
		_demander_reconstruction()
## Ambiance « grandiose » (soleil bas, ciel doré, brume, rayons) : voir
## ambiance_prehistoire.gd. Décocher pour revenir au ciel photo ci-dessous.
@export var ambiance_grandiose := true:
	set(valeur):
		ambiance_grandiose = valeur
		if is_inside_tree():
			_appliquer_ciel()
## Ciel Poly Haven utilisé si l'ambiance grandiose est décochée (nom du fichier dans assets/prehistoire/ciel/, sans .hdr).
@export var ciel := "kloofendal_misty_morning_puresky":
	set(valeur):
		ciel = valeur
		if is_inside_tree():
			_appliquer_ciel()
## Point d'apparition du joueur (x, z).
@export var point_apparition := Vector2(0, 0)

@export_tool_button("Reconstruire", "Reload") var _bouton := reconstruire

const DOSSIER := "res://assets/prehistoire/"
const SHADER_TERRAIN := preload("res://shaders/prehistoire_terrain.gdshader")
const SHADER_HERBE := preload("res://shaders/prehistoire_herbe.gdshader")
const SHADER_FRACTURE := preload("res://shaders/prehistoire_fracture.gdshader")
const AmbiancePrehistoire := preload("res://scripts/monde/prehistoire/ambiance_prehistoire.gd")

## Textures Poly Haven de chaque sol (la première trouvée est utilisée).
const TEXTURES_SOLS := {
	"galets": ["dry_river_pebbles", "clean_pebbles"],
	"neige": ["snow_02", "snow_03"],
	"sol": ["dry_ground_rocks", "brown_mud_rocks_01"],
	"roche": ["cliff_side", "rock_wall_10", "rock_boulder_dry"],
}
## Rochers et bois mort Poly Haven.
const MODELES_ROCHERS := ["rock_07", "rock_09", "stone_01", "boulder_01"]
const MODELES_BOIS := ["dead_tree_trunk", "dead_tree_trunk_02", "tree_stump_01", "dry_branches_medium_01"]
const NIVEAU_MER := 0.0

## Nom de la zone (sert à la quête et aux passages d'une zone à l'autre).
var identifiant_zone := ""
## Taille du terrain (mètres, carré centré sur 0).
var taille_terrain := 320
## Piste tassée dans la neige (suite de points x, z).
var piste: Array = []
## Textures des sols de cette zone (rouge, vert, bleu des couleurs du terrain + roche).
var sols := TEXTURES_SOLS.duplicate()
## Réglages du shader du terrain propres à la zone (ex. {"sol_saturation": 0.7}).
var reglages_terrain := {}
## Réglages du shader de l'herbe propres à la zone (ex. couleurs).
var reglages_herbe := {}

var _relief: FastNoiseLite
var _details: FastNoiseLite
var _contenu: Node3D
var _materiaux := {}
## Les feux de camp de la zone (leur lumière vacille).
var _feux: Array[OmniLight3D] = []
var _reconstruction_demandee := false
var _neige: GPUParticles3D
var _bruit_tex: NoiseTexture2D
var _temps := 0.0
var _formes_rochers: Array[ArrayMesh] = []
var _collisions_rochers: Array[Shape3D] = []
var _modeles_rochers: Array[String] = []
var _hasard_rochers := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("ile")
	reconstruire()
	if Engine.is_editor_hint():
		return
	var loups := get_node_or_null("Partie/Loups")
	if loups != null:
		loups.child_entered_tree.connect(func(n: Node): _habiller_fracture.call_deferred(n))


func _process(delta: float) -> void:
	_temps += delta
	# La neige suit la caméra.
	if _neige != null and is_instance_valid(_neige):
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			_neige.global_position = camera.global_position + Vector3(0, 6, 0)
	if _tempete != null and is_instance_valid(_tempete):
		var camera_t := get_viewport().get_camera_3d()
		if camera_t != null:
			_tempete.global_position = camera_t.global_position + Vector3(-12, 4, -4)
	_chaque_image(delta)


## À compléter par chaque zone (animations, passages…).
func _chaque_image(_delta: float) -> void:
	pass


func _preparer_bruits() -> void:
	_relief = FastNoiseLite.new()
	_relief.seed = graine
	_relief.frequency = 0.009
	_relief.fractal_octaves = 4
	_details = FastNoiseLite.new()
	_details.seed = graine + 1
	_details.frequency = 0.08
	_details.fractal_octaves = 2


## Hauteur du sol (mètres) à une position x, z du monde. À définir par chaque zone.
func hauteur(_x: float, _z: float) -> float:
	return 0.0


## Part de chaque sol (galets, neige, terre) : rouge, vert, bleu. À définir par chaque zone.
func _parts_sol(_x: float, _z: float, _h: float) -> Color:
	return Color(0, 0, 1, 1)


## Reconstruit toute la zone. Chaque zone appelle d'abord _commencer().
func reconstruire() -> void:
	_commencer()


func _commencer() -> void:
	_reconstruction_demandee = false
	_preparer_bruits()
	_materiaux.clear()
	_formes_rochers.clear()
	_collisions_rochers.clear()
	if _contenu != null and is_instance_valid(_contenu):
		_contenu.free()
	_contenu = Node3D.new()
	_contenu.name = "Genere"
	add_child(_contenu)


## Point (x, z) de la sortie vers une autre zone (Vector2.INF si aucune).
func sortie_vers(_zone: String) -> Vector2:
	return Vector2.INF


# --- Rochers ---------------------------------------------------------------------

func _preparer_rochers() -> void:
	_hasard_rochers.seed = graine + 11
	_modeles_rochers.clear()
	for id in MODELES_ROCHERS:
		if ResourceLoader.exists(DOSSIER + "modeles/%s/%s.gltf" % [id, id]):
			_modeles_rochers.append(id)
	# Quelques formes de rochers (réutilisées pour aller vite), avec leur collision.
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.9
	for k in 10:
		bruit.seed = graine + 100 + k
		var echelle := Vector3(_hasard_rochers.randf_range(0.9, 1.3), _hasard_rochers.randf_range(0.55, 0.85),
				_hasard_rochers.randf_range(0.9, 1.3))
		var maillage := _maillage_bosse(bruit, echelle, 1.8, 0.42, 16)
		_formes_rochers.append(maillage)
		_collisions_rochers.append(maillage.create_convex_shape(true, true))


## Pose un rocher (avec collision), en partie enfoui, avec de la neige dessus si le sol est enneigé.
## Un gué : une rangée de pierres plates qui dépassent de l'eau, de « depart » à
## « arrivee », et des galets immergés autour (on voit où passer).
func _placer_gue(dossier: Node3D, depart: Vector2, arrivee: Vector2, graine_gue: int) -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine_gue
	var direction := (arrivee - depart).normalized()
	var longueur := depart.distance_to(arrivee)
	var t := 0.0
	while t < longueur:
		var p := depart + direction * t + direction.orthogonal() * hasard.randf_range(-0.3, 0.3)
		if hauteur(p.x, p.y) < 0.3:
			# De grosses pierres qui sortent nettement de l'eau.
			_placer_rocher(dossier, p.x, p.y, hasard.randf_range(1.1, 1.4), -0.12)
		t += hasard.randf_range(0.9, 1.3)
	for k in 26:
		var p := depart.lerp(arrivee, hasard.randf()) + direction.orthogonal() * hasard.randf_range(-4.0, 4.0)
		if hauteur(p.x, p.y) < 0.2:
			_placer_rocher(dossier, p.x, p.y, hasard.randf_range(0.25, 0.55), 0.3)


func _placer_rocher(dossier: Node3D, x: float, z: float, taille: float, enfoui := 0.35) -> void:
	if _formes_rochers.is_empty():
		_preparer_rochers()
	var hasard := _hasard_rochers
	var y := hauteur(x, z)
	if y < NIVEAU_MER - 1.0:
		return
	var corps := StaticBody3D.new()
	corps.position = Vector3(x, y - taille * enfoui, z)
	corps.rotation = Vector3(hasard.randf_range(-0.25, 0.25), hasard.randf() * TAU, hasard.randf_range(-0.25, 0.25))
	var neige := clampf(_parts_sol(x, z, y).g * 1.2, 0.0, 1.0)
	var k := hasard.randi() % _formes_rochers.size()
	# Un vrai rocher scanné (Poly Haven) pour une partie des gros rochers.
	var scanne: Node3D = null
	if not _modeles_rochers.is_empty() and taille > 1.0 and hasard.randf() < 0.6:
		scanne = _modele(_modeles_rochers[hasard.randi() % _modeles_rochers.size()], Vector3.ZERO, 0.0, taille * 0.9, corps)
	if scanne == null:
		var visuel := MeshInstance3D.new()
		visuel.mesh = _formes_rochers[k]
		visuel.scale = Vector3.ONE * taille
		visuel.material_override = _mat_terrain()
		visuel.set_instance_shader_parameter("roche_forcee", 1.0)
		visuel.set_instance_shader_parameter("neige_en_plus", neige)
		corps.add_child(visuel)
	var collision := CollisionShape3D.new()
	collision.shape = _collisions_rochers[k]
	collision.scale = Vector3.ONE * taille
	corps.add_child(collision)
	dossier.add_child(corps)


# --- Outils communs ----------------------------------------------------------------

func _demander_reconstruction() -> void:
	if not is_inside_tree() or _reconstruction_demandee:
		return
	_reconstruction_demandee = true
	reconstruire.call_deferred()


func _texture(id: String, carte: String) -> Texture2D:
	var chemin := DOSSIER + "textures/%s/%s_%s.jpg" % [id, id, carte]
	if not ResourceLoader.exists(chemin):
		return null
	return load(chemin)


## Premier identifiant de la liste dont la texture est téléchargée ("" sinon).
func _premiere_texture(ids: Array) -> String:
	for id in ids:
		if _texture(id, "Diffuse") != null:
			return id
	return ""


func _modele(id: String, position_m: Vector3, angle_y := 0.0, echelle := 1.0, parent: Node3D = null) -> Node3D:
	var chemin := DOSSIER + "modeles/%s/%s.gltf" % [id, id]
	if not ResourceLoader.exists(chemin):
		return null
	var instance := (load(chemin) as PackedScene).instantiate() as Node3D
	instance.position = position_m
	instance.rotation.y = angle_y
	instance.scale = Vector3.ONE * echelle
	(parent if parent != null else _contenu).add_child(instance)
	return instance


func _bruit() -> NoiseTexture2D:
	if _bruit_tex == null:
		_bruit_tex = NoiseTexture2D.new()
		_bruit_tex.width = 512
		_bruit_tex.height = 512
		_bruit_tex.seamless = true
		_bruit_tex.generate_mipmaps = true
		var source := FastNoiseLite.new()
		source.seed = graine + 7
		source.frequency = 0.01
		source.fractal_octaves = 5
		_bruit_tex.noise = source
	return _bruit_tex


## Matériau du sol (le même sert aux rochers, avec de la neige sur le dessus).
func _mat_terrain() -> ShaderMaterial:
	if _materiaux.has("terrain"):
		return _materiaux["terrain"]
	var m := ShaderMaterial.new()
	m.shader = SHADER_TERRAIN
	m.set_shader_parameter("bruit", _bruit())
	m.set_shader_parameter("niveau_mer", NIVEAU_MER)
	for sol in sols:
		var id := _premiere_texture(sols[sol])
		if id == "":
			continue
		m.set_shader_parameter(sol + "_texture", true)
		m.set_shader_parameter(sol + "_couleur", _texture(id, "Diffuse"))
		m.set_shader_parameter(sol + "_relief", _texture(id, "nor_gl"))
		m.set_shader_parameter(sol + "_arm", _texture(id, "arm"))
	for cle in reglages_terrain:
		m.set_shader_parameter(cle, reglages_terrain[cle])
	_materiaux["terrain"] = m
	return m


## Change la couleur d'un modèle Poly Haven : « teinte » multiplie la couleur,
## « desature » (0 à 1) la ramène vers le gris (ex. un rocher trop orange).
func _teinter(modele: Node3D, teinte: Color, desature := 0.0) -> void:
	for n in modele.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if m == null:
				continue
			var copie := m.duplicate() as BaseMaterial3D
			if desature > 0.0 and copie.albedo_texture != null:
				var image := copie.albedo_texture.get_image()
				if image != null:
					image.decompress()
					for j in image.get_height():
						for i in image.get_width():
							var c := image.get_pixel(i, j)
							var gris := c.get_luminance()
							image.set_pixel(i, j, c.lerp(Color(gris, gris, gris), desature))
					image.generate_mipmaps()
					copie.albedo_texture = ImageTexture.create_from_image(image)
			copie.albedo_color = copie.albedo_color * teinte
			mi.set_surface_override_material(s, copie)


## Matériau du sol pour les montagnes lointaines : motifs beaucoup plus grands,
## pour éviter l'effet « gâteau en couches » des strates répétées.
func _mat_lointain() -> ShaderMaterial:
	if _materiaux.has("lointain"):
		return _materiaux["lointain"]
	var m := _mat_terrain().duplicate() as ShaderMaterial
	m.set_shader_parameter("roche_motif", 48.0)
	m.set_shader_parameter("neige_motif", 30.0)
	m.set_shader_parameter("sol_motif", 30.0)
	_materiaux["lointain"] = m
	return m


## Matériau PBR simple (bois, os…), avec texture Poly Haven si elle existe.
func _mat_pbr(id: String, couleur: Color, rugosite := 0.9, taille_motif := 2.0) -> StandardMaterial3D:
	var cle := "pbr_%s_%s" % [id, couleur.to_html()]
	if _materiaux.has(cle):
		return _materiaux[cle]
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = rugosite
	var tex := _texture(id, "Diffuse") if id != "" else null
	if tex != null:
		m.albedo_texture = tex
		m.normal_enabled = true
		m.normal_texture = _texture(id, "nor_gl")
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE / taille_motif
	_materiaux[cle] = m
	return m


func _construire_terrain() -> void:
	var cotes := taille_terrain + 1
	var demi := taille_terrain * 0.5
	var hauteurs := PackedFloat32Array()
	hauteurs.resize(cotes * cotes)
	var sommets := PackedVector3Array()
	sommets.resize(cotes * cotes)
	var couleurs := PackedColorArray()
	couleurs.resize(cotes * cotes)
	for j in cotes:
		for i in cotes:
			var x := i - demi
			var z := j - demi
			var y := hauteur(x, z)
			var k := j * cotes + i
			hauteurs[k] = y
			sommets[k] = Vector3(x, y, z)
			couleurs[k] = _parts_sol(x, z, y)
	# Normales calculées d'après les hauteurs voisines (plus rapide et plus doux).
	var normales := PackedVector3Array()
	normales.resize(cotes * cotes)
	for j in cotes:
		for i in cotes:
			var g := hauteurs[j * cotes + maxi(i - 1, 0)]
			var d := hauteurs[j * cotes + mini(i + 1, cotes - 1)]
			var h := hauteurs[maxi(j - 1, 0) * cotes + i]
			var b := hauteurs[mini(j + 1, cotes - 1) * cotes + i]
			normales[j * cotes + i] = Vector3(g - d, 2.0, h - b).normalized()
	var indices := PackedInt32Array()
	indices.resize(taille_terrain * taille_terrain * 6)
	var n := 0
	for j in taille_terrain:
		for i in taille_terrain:
			var a := j * cotes + i
			indices[n] = a
			indices[n + 1] = a + 1
			indices[n + 2] = a + cotes
			indices[n + 3] = a + 1
			indices[n + 4] = a + cotes + 1
			indices[n + 5] = a + cotes
			n += 6
	var tableaux := []
	tableaux.resize(Mesh.ARRAY_MAX)
	tableaux[Mesh.ARRAY_VERTEX] = sommets
	tableaux[Mesh.ARRAY_NORMAL] = normales
	tableaux[Mesh.ARRAY_COLOR] = couleurs
	tableaux[Mesh.ARRAY_INDEX] = indices
	var maillage := ArrayMesh.new()
	maillage.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tableaux)
	var sol := MeshInstance3D.new()
	sol.name = "Sol"
	sol.mesh = maillage
	sol.material_override = _mat_terrain()
	_contenu.add_child(sol)

	var corps := StaticBody3D.new()
	corps.name = "CollisionSol"
	var forme := CollisionShape3D.new()
	var champ := HeightMapShape3D.new()
	champ.map_width = cotes
	champ.map_depth = cotes
	champ.map_data = hauteurs
	forme.shape = champ
	corps.add_child(forme)
	_contenu.add_child(corps)


func _texture_vagues(graine_v: int, frequence: float) -> NoiseTexture2D:
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.as_normal_map = true
	t.bump_strength = 6.0
	t.generate_mipmaps = true
	var b := FastNoiseLite.new()
	b.seed = graine_v
	b.frequency = frequence
	b.fractal_octaves = 3
	t.noise = b
	return t


func _mat_glace() -> StandardMaterial3D:
	if _materiaux.has("glace"):
		return _materiaux["glace"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.70, 0.84, 0.90)
	m.roughness = 0.18
	m.metallic_specular = 0.7
	m.clearcoat_enabled = true
	m.clearcoat = 0.6
	m.subsurf_scatter_enabled = true
	m.subsurf_scatter_strength = 0.5
	m.rim_enabled = true
	m.rim = 0.3
	m.rim_tint = 0.8
	_materiaux["glace"] = m
	return m


func _mat_neige_simple() -> StandardMaterial3D:
	if _materiaux.has("neige"):
		return _materiaux["neige"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.93, 0.96)
	m.roughness = 0.7
	var tex := _texture(_premiere_texture(TEXTURES_SOLS["neige"]), "Diffuse") if _premiere_texture(TEXTURES_SOLS["neige"]) != "" else null
	if tex != null:
		m.albedo_texture = tex
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE / 4.0
	_materiaux["neige"] = m
	return m


## Bloc de glace plat et irrégulier : dessus enneigé, bords de glace bleutée.
func _maillage_banquise(hasard: RandomNumberGenerator, rayon: float, epaisseur: float) -> ArrayMesh:
	var cotes := hasard.randi_range(6, 10)
	var points: Array[Vector2] = []
	for k in cotes:
		var angle := TAU * k / cotes + hasard.randf_range(-0.2, 0.2)
		points.append(Vector2(cos(angle), sin(angle)) * rayon * hasard.randf_range(0.6, 1.15))
	var dessus := SurfaceTool.new()
	dessus.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in cotes:
		var a := points[k]
		var b := points[(k + 1) % cotes]
		dessus.set_normal(Vector3.UP)
		dessus.add_vertex(Vector3(0, epaisseur * 0.35, 0))
		dessus.add_vertex(Vector3(b.x, epaisseur * 0.3, b.y))
		dessus.add_vertex(Vector3(a.x, epaisseur * 0.3, a.y))
	var maillage := dessus.commit()
	var flancs := SurfaceTool.new()
	flancs.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in cotes:
		var a := points[k]
		var b := points[(k + 1) % cotes]
		var haut_a := Vector3(a.x, epaisseur * 0.3, a.y)
		var haut_b := Vector3(b.x, epaisseur * 0.3, b.y)
		var bas_a := Vector3(a.x * 0.85, -epaisseur, a.y * 0.85)
		var bas_b := Vector3(b.x * 0.85, -epaisseur, b.y * 0.85)
		flancs.add_vertex(haut_a)
		flancs.add_vertex(haut_b)
		flancs.add_vertex(bas_a)
		flancs.add_vertex(haut_b)
		flancs.add_vertex(bas_b)
		flancs.add_vertex(bas_a)
	flancs.generate_normals()
	flancs.commit(maillage)
	maillage.surface_set_material(0, _mat_neige_simple())
	maillage.surface_set_material(1, _mat_glace())
	return maillage


## Sphère déformée par du bruit (rochers, icebergs, montagnes lointaines).
func _maillage_bosse(bruit: FastNoiseLite, echelle: Vector3, details := 2.0, force := 0.4,
		segments := 18, couleur := Color(0, 0, 1)) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radial_segments = segments
	sphere.rings = segments / 2
	var tableaux := sphere.get_mesh_arrays()
	var sommets: PackedVector3Array = tableaux[Mesh.ARRAY_VERTEX]
	for k in sommets.size():
		var v := sommets[k]
		var deformation := 1.0 + bruit.get_noise_3dv(v * details) * force
		sommets[k] = v * deformation * echelle
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	outil.set_color(couleur)
	for index in (tableaux[Mesh.ARRAY_INDEX] as PackedInt32Array):
		outil.add_vertex(sommets[index])
	outil.generate_normals()
	return outil.commit()


func _construire_touffes() -> void:
	if nombre_touffes <= 0 or DisplayServer.get_name() == "headless":
		return
	var brin := _maillage_touffe()
	var materiau := ShaderMaterial.new()
	materiau.shader = SHADER_HERBE
	for cle in reglages_herbe:
		materiau.set_shader_parameter(cle, reglages_herbe[cle])
	brin.surface_set_material(0, materiau)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 21
	const BLOC := 20.0
	var demi := taille_terrain * 0.5 - 20.0
	var blocs := int(ceil((demi * 2.0) / BLOC))
	var par_bloc := int(nombre_touffes / float(blocs * blocs))
	for bj in blocs:
		for bi in blocs:
			var x0 := -demi + bi * BLOC
			var z0 := -demi + bj * BLOC
			var transformations: Array[Transform3D] = []
			for n in par_bloc:
				var x := x0 + hasard.randf() * BLOC
				var z := z0 + hasard.randf() * BLOC
				var y := hauteur(x, z)
				if y < NIVEAU_MER + 0.8:
					continue
				var parts := _parts_sol(x, z, y)
				# L'herbe pousse sur la terre, rarement dans la neige épaisse ou les galets.
				if parts.r > 0.5 or hasard.randf() < parts.g * 0.9:
					continue
				var pente := absf(hauteur(x + 0.5, z) - y) + absf(hauteur(x, z + 0.5) - y)
				if pente > 0.4:
					continue
				transformations.append(Transform3D(Basis(Vector3.UP, hasard.randf() * TAU).scaled(
						Vector3.ONE * hasard.randf_range(0.6, 1.5)), Vector3(x, y - 0.03, z)))
			if transformations.is_empty():
				continue
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.use_custom_data = true
			multi.mesh = brin
			multi.instance_count = transformations.size()
			for k in transformations.size():
				multi.set_instance_transform(k, transformations[k])
				multi.set_instance_custom_data(k, Color(hasard.randf(), 0, 0, 0))
			var instance := MultiMeshInstance3D.new()
			instance.multimesh = multi
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			instance.visibility_range_end = 80.0
			instance.visibility_range_end_margin = 10.0
			instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			_contenu.add_child(instance)


## Une touffe de 7 brins fins et longs, un peu couchés.
func _maillage_touffe() -> ArrayMesh:
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 7:
		var angle := k * TAU / 7.0 + 0.4
		var cote := Vector3(cos(angle), 0, sin(angle)) * 0.012
		var penche := Vector3(-sin(angle), 0, cos(angle)) * (0.1 + 0.05 * (k % 3))
		var decalage := Vector3(cos(angle * 3.0), 0, sin(angle * 3.0)) * 0.04
		var hauteur_brin := 0.35 + (k % 4) * 0.08
		var etages := 3
		var precedent_g := decalage - cote
		var precedent_d := decalage + cote
		for e in etages:
			var v1 := float(e + 1) / etages
			var largeur := 1.0 - v1
			var centre := decalage + Vector3(0, hauteur_brin * v1, 0) + penche * v1 * v1
			var g := centre - cote * largeur
			var d := centre + cote * largeur
			var v0 := float(e) / etages
			outil.set_normal(penche.normalized())
			outil.set_uv(Vector2(0, v0)); outil.add_vertex(precedent_g)
			outil.set_uv(Vector2(1, v0)); outil.add_vertex(precedent_d)
			outil.set_uv(Vector2(0, v1)); outil.add_vertex(g)
			outil.set_uv(Vector2(1, v0)); outil.add_vertex(precedent_d)
			outil.set_uv(Vector2(1, v1)); outil.add_vertex(d)
			outil.set_uv(Vector2(0, v1)); outil.add_vertex(g)
			precedent_g = g
			precedent_d = d
	return outil.commit()


func _metal() -> StandardMaterial3D:
	if not _materiaux.has("metal"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.16, 0.17, 0.19)
		m.metallic = 0.85
		m.roughness = 0.35
		_materiaux["metal"] = m
	return _materiaux["metal"]


func _lumineux(couleur: Color, energie := 3.0) -> StandardMaterial3D:
	var cle := "lum_%s_%s" % [couleur.to_html(), energie]
	if not _materiaux.has(cle):
		var m := StandardMaterial3D.new()
		m.albedo_color = couleur
		m.emission_enabled = true
		m.emission = couleur
		m.emission_energy_multiplier = energie
		_materiaux[cle] = m
	return _materiaux[cle]


func _boite(taille: Vector3, centre: Vector3, materiau: Material, parent: Node3D, collision := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.material_override = materiau
	mi.position = centre
	parent.add_child(mi)
	if collision:
		var corps := StaticBody3D.new()
		var forme := CollisionShape3D.new()
		var boite := BoxShape3D.new()
		boite.size = taille
		forme.shape = boite
		corps.add_child(forme)
		mi.add_child(corps)
	return mi


## Modèle du hub (Poly Haven) réutilisé ici pour le matériel moderne de la Vigie.
func _modele_hub(id: String, position_m: Vector3, angle_y: float, parent: Node3D) -> Node3D:
	var chemin := "res://assets/hub/modeles/%s/%s.gltf" % [id, id]
	if not ResourceLoader.exists(chemin):
		return null
	var instance := (load(chemin) as PackedScene).instantiate() as Node3D
	instance.position = position_m
	instance.rotation.y = angle_y
	parent.add_child(instance)
	return instance


## Tempête de neige (chapitre 6) : flocons serrés poussés par le vent, brouillard épais.
var en_tempete := false
var _tempete: GPUParticles3D
var _brouillard_normal := -1.0


func tempete(active: bool, _anime := true) -> void:
	en_tempete = active
	var environnement := get_node_or_null("Environnement") as WorldEnvironment
	if environnement != null and environnement.environment != null:
		var env := environnement.environment
		if _brouillard_normal < 0.0:
			_brouillard_normal = env.fog_density
		env.fog_density = _brouillard_normal * (10.0 if active else 1.0)
	if _tempete != null and is_instance_valid(_tempete):
		_tempete.queue_free()
		_tempete = null
	if not active or DisplayServer.get_name() == "headless" or _contenu == null:
		return
	_tempete = GPUParticles3D.new()
	_tempete.name = "Tempete"
	_tempete.amount = 16000
	_tempete.lifetime = 3.0
	_tempete.preprocess = 3.0
	_tempete.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 50, 80))
	var processus := ParticleProcessMaterial.new()
	processus.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	processus.emission_box_extents = Vector3(30, 8, 30)
	processus.direction = Vector3(1, -0.35, 0.3)
	processus.spread = 20.0
	processus.initial_velocity_min = 9.0
	processus.initial_velocity_max = 15.0
	processus.gravity = Vector3(2.0, -2.0, 0.5)
	processus.turbulence_enabled = true
	processus.turbulence_noise_strength = 2.0
	processus.scale_min = 0.6
	processus.scale_max = 1.6
	_tempete.process_material = processus
	var flocon := QuadMesh.new()
	flocon.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(0.95, 0.97, 1.0, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flocon.material = m
	_tempete.draw_pass_1 = flocon
	_tempete.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_contenu.add_child(_tempete)


func _construire_neige_qui_tombe() -> void:
	_neige = null
	if not neige_qui_tombe or DisplayServer.get_name() == "headless":
		return
	_neige = GPUParticles3D.new()
	_neige.name = "Neige"
	_neige.amount = 7000
	_neige.lifetime = 9.0
	_neige.preprocess = 9.0
	_neige.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 50, 80))
	var processus := ParticleProcessMaterial.new()
	processus.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	processus.emission_box_extents = Vector3(35, 10, 35)
	processus.direction = Vector3(0.4, -1, 0.15)
	processus.spread = 15.0
	processus.initial_velocity_min = 0.8
	processus.initial_velocity_max = 1.6
	processus.gravity = Vector3(0.5, -0.9, 0.2)
	processus.turbulence_enabled = true
	processus.turbulence_noise_strength = 0.6
	processus.turbulence_noise_scale = 4.0
	processus.scale_min = 0.5
	processus.scale_max = 1.3
	_neige.process_material = processus
	var flocon := QuadMesh.new()
	flocon.size = Vector2(0.035, 0.035)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(0.95, 0.97, 1.0, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flocon.material = m
	_neige.draw_pass_1 = flocon
	_neige.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_contenu.add_child(_neige)


func _appliquer_ciel() -> void:
	var environnement := get_node_or_null("Environnement") as WorldEnvironment
	if environnement == null or environnement.environment == null:
		return
	if ambiance_grandiose:
		AmbiancePrehistoire.appliquer(self, identifiant_zone)
		return
	var chemin := DOSSIER + "ciel/%s.hdr" % ciel
	if not ResourceLoader.exists(chemin):
		return
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = load(chemin)
	panorama.energy_multiplier = 1.0
	var sky := Sky.new()
	sky.sky_material = panorama
	environnement.environment.sky = sky


## Les loups touchés par la faille reçoivent des veines violettes lumineuses.
func _habiller_fracture(n: Node) -> void:
	if not is_instance_valid(n) or not (String(n.get("type_ennemi")).contains("fracture") or String(n.get("type_ennemi")).begins_with("ours")):
		return
	var apparence := n.get_node_or_null("Apparence")
	if apparence == null:
		return
	if not _materiaux.has("fracture"):
		var m := ShaderMaterial.new()
		m.shader = SHADER_FRACTURE
		m.set_shader_parameter("bruit", _bruit())
		_materiaux["fracture"] = m
	var surcouche: Material = _materiaux["fracture"]
	if String(n.get("type_ennemi")).begins_with("ours"):
		# L'Ours garde son pelage brun : la faille ne fait que le veiner.
		if not _materiaux.has("fracture_ours"):
			var m_ours := (_materiaux["fracture"] as ShaderMaterial).duplicate() as ShaderMaterial
			m_ours.set_shader_parameter("intensite", 0.55)
			_materiaux["fracture_ours"] = m_ours
		surcouche = _materiaux["fracture_ours"]
	for mi in apparence.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = surcouche
	var lueur := OmniLight3D.new()
	lueur.light_color = Color(0.6, 0.25, 1.0)
	lueur.light_energy = 0.8
	lueur.omni_range = 3.5
	lueur.position = Vector3(0, 0.8, 0)
	n.add_child(lueur)


func _distance_piste(p: Vector2) -> float:
	var meilleure := INF
	for i in piste.size() - 1:
		var a: Vector2 = piste[i]
		var b: Vector2 = piste[i + 1]
		var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		meilleure = minf(meilleure, p.distance_to(a + (b - a) * t))
	return meilleure


# --- Feux, peaux et peintures (partagés par les zones du clan) ---------------------------

func _mat_peau() -> StandardMaterial3D:
	var m := _mat_pbr("brown_leather", Color(0.6, 0.55, 0.5), 0.95, 1.2)
	m.uv1_triplanar = false
	m.uv1_scale = Vector3.ONE
	m.roughness = 1.0
	m.metallic_specular = 0.2
	return m


func _cylindre(haut: float, bas: float, hauteur_c: float, segments := 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = haut
	c.bottom_radius = bas
	c.height = hauteur_c
	c.radial_segments = segments
	return c


func _feu(parent: Node3D, p: Vector2, taille: float) -> void:
	var feu := Node3D.new()
	feu.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
	parent.add_child(feu)
	var pierre := _mat_pbr("rock_boulder_dry", Color(0.6, 0.58, 0.55), 0.9, 0.6)
	for k in 9:
		var a := k * TAU / 9.0
		var caillou := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.22 * taille
		sphere.height = 0.3 * taille
		caillou.mesh = sphere
		caillou.material_override = pierre
		caillou.position = Vector3(cos(a), 0.05, sin(a)) * 0.9 * taille
		feu.add_child(caillou)
	var braise := _lumineux(Color(1.0, 0.35, 0.08), 2.5)
	for k in 4:
		var buche := MeshInstance3D.new()
		buche.mesh = _cylindre(0.07, 0.08, 1.1 * taille, 6)
		buche.material_override = _mat_pbr("", Color(0.12, 0.09, 0.07), 0.95)
		buche.position.y = 0.25 * taille
		buche.rotation = Vector3(1.1, k * PI / 2, 0)
		feu.add_child(buche)
	var coeur := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35 * taille
	sphere.height = 0.2 * taille
	coeur.mesh = sphere
	coeur.material_override = braise
	coeur.position.y = 0.05
	feu.add_child(coeur)
	var lumiere := OmniLight3D.new()
	lumiere.light_color = Color(1.0, 0.6, 0.3)
	lumiere.light_energy = 3.2
	lumiere.omni_range = 12.0 * taille
	lumiere.shadow_enabled = true
	lumiere.position.y = 1.0
	lumiere.add_to_group("lumiere_secondaire")
	feu.add_child(lumiere)
	_feux.append(lumiere)
	if DisplayServer.get_name() == "headless":
		return
	var flammes := GPUParticles3D.new()
	flammes.amount = 60
	flammes.lifetime = 0.9
	var processus := ParticleProcessMaterial.new()
	processus.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	processus.emission_sphere_radius = 0.3 * taille
	processus.direction = Vector3.UP
	processus.spread = 12.0
	processus.initial_velocity_min = 0.8
	processus.initial_velocity_max = 1.6
	processus.gravity = Vector3(0, 0.6, 0)
	processus.scale_min = 0.6
	processus.scale_max = 1.2
	var courbe := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0, 0.6))
	c.add_point(Vector2(0.3, 1.0))
	c.add_point(Vector2(1, 0))
	courbe.curve = c
	processus.scale_curve = courbe
	var degrade := Gradient.new()
	degrade.set_color(0, Color(1.0, 0.85, 0.4, 1))
	degrade.set_color(1, Color(0.9, 0.2, 0.02, 0))
	var couleurs := GradientTexture1D.new()
	couleurs.gradient = degrade
	processus.color_ramp = couleurs
	flammes.process_material = processus
	var quad := QuadMesh.new()
	quad.size = Vector2(0.45, 0.6) * taille
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = _texture_flamme()
	quad.material = m
	flammes.draw_pass_1 = quad
	flammes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flammes.position.y = 0.2
	feu.add_child(flammes)


func _texture_flamme() -> Texture2D:
	if _materiaux.has("tex_flamme"):
		return _materiaux["tex_flamme"]
	var t := GradientTexture2D.new()
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.6)
	t.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	t.gradient = g
	_materiaux["tex_flamme"] = t
	return t


## Une main négative soufflée à l'ocre (comme dans les vraies grottes ornées).
func _texture_main() -> Texture2D:
	var taille_img := 256
	var image := Image.create(taille_img, taille_img, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 7
	# La paume et les doigts (positions sur l'image, de 0 à 1).
	var doigts := [[Vector2(0.30, 0.42), Vector2(0.18, 0.22)], [Vector2(0.42, 0.36), Vector2(0.38, 0.08)],
			[Vector2(0.52, 0.35), Vector2(0.53, 0.05)], [Vector2(0.61, 0.38), Vector2(0.67, 0.1)],
			[Vector2(0.66, 0.5), Vector2(0.84, 0.36)]]
	var dans_main := func(u: Vector2) -> bool:
		if Vector2((u.x - 0.48) / 0.2, (u.y - 0.58) / 0.22).length() < 1.0:
			return true
		if u.y > 0.62 and u.y < 0.95 and absf(u.x - 0.48) < 0.13:
			return true
		for d in doigts:
			var a: Vector2 = d[0]
			var b: Vector2 = d[1]
			var t := clampf((u - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
			if u.distance_to(a + (b - a) * t) < 0.045:
				return true
		return false
	for j in taille_img:
		for i in taille_img:
			var u := Vector2(i, j) / taille_img
			var centre := u.distance_to(Vector2(0.5, 0.5))
			# Pigment soufflé autour de la main, qui s'estompe vers les bords.
			var alpha := clampf(1.0 - centre * 2.1, 0.0, 1.0) * (0.75 + hasard.randf() * 0.25)
			if dans_main.call(u):
				alpha *= 0.05
			image.set_pixel(i, j, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)


## Bisons, chevaux, points et mains, soufflés et tracés à l'ocre.
func _texture_fresque(avec_voyageur := false) -> Texture2D:
	var largeur_img := 1024
	var hauteur_img := 384
	var image := Image.create(largeur_img, hauteur_img, true, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 90
	var tache := func(c: Vector2, rayons: Vector2, alpha: float) -> void:
		for j in range(int(c.y - rayons.y) - 2, int(c.y + rayons.y) + 3):
			for i in range(int(c.x - rayons.x) - 2, int(c.x + rayons.x) + 3):
				if i < 0 or j < 0 or i >= largeur_img or j >= hauteur_img:
					continue
				var d := Vector2((i - c.x) / rayons.x, (j - c.y) / rayons.y).length()
				if d < 1.0:
					var a := alpha * clampf((1.0 - d) * 5.0, 0.0, 1.0) * (0.75 + hasard.randf() * 0.25)
					var avant := image.get_pixel(i, j).a
					image.set_pixel(i, j, Color(1, 1, 1, maxf(avant, a)))
	var ligne := func(a: Vector2, b: Vector2, epaisseur: float, alpha: float) -> void:
		var n := int(a.distance_to(b) / 2.0) + 1
		for k in n + 1:
			tache.call(a.lerp(b, float(k) / n), Vector2(epaisseur, epaisseur), alpha)
	# Un bison : corps massif, bosse, tête basse, pattes fines.
	var bison := func(o: Vector2, s: float) -> void:
		tache.call(o, Vector2(70, 34) * s, 0.85)
		tache.call(o + Vector2(-38, -26) * s, Vector2(40, 30) * s, 0.85)
		tache.call(o + Vector2(-82, 6) * s, Vector2(22, 20) * s, 0.85)
		for dx in [-45.0, -25.0, 30.0, 50.0]:
			ligne.call(o + Vector2(dx, 20) * s, o + Vector2(dx + 4, 64) * s, 4.0 * s, 0.85)
		ligne.call(o + Vector2(-92, -8) * s, o + Vector2(-102, -26) * s, 3.0 * s, 0.85)
		ligne.call(o + Vector2(68, -8) * s, o + Vector2(84, 14) * s, 2.5 * s, 0.85)
	# Un cheval : corps plus fin, long cou, crinière.
	var cheval := func(o: Vector2, s: float) -> void:
		tache.call(o, Vector2(58, 24) * s, 0.75)
		ligne.call(o + Vector2(-46, -8) * s, o + Vector2(-78, -48) * s, 11.0 * s, 0.75)
		tache.call(o + Vector2(-88, -52) * s, Vector2(18, 10) * s, 0.75)
		for dx in [-38.0, -22.0, 28.0, 44.0]:
			ligne.call(o + Vector2(dx, 14) * s, o + Vector2(dx + 2, 58) * s, 3.5 * s, 0.75)
		ligne.call(o + Vector2(56, -4) * s, o + Vector2(74, 30) * s, 3.0 * s, 0.75)
	bison.call(Vector2(230, 190), 1.15)
	cheval.call(Vector2(520, 150), 1.0)
	bison.call(Vector2(800, 210), 0.95)
	cheval.call(Vector2(640, 280), 0.7)
	# Des rangées de points et quelques signes.
	for k in 14:
		tache.call(Vector2(380 + k * 14, 320 + sin(k * 0.8) * 8.0), Vector2(5, 5), 0.9)
	for k in 6:
		ligne.call(Vector2(940 + k * 10, 60), Vector2(944 + k * 10, 120), 3.0, 0.8)
	if avec_voyageur:
		# Le Venu-du-Brouillard, peint parmi les bêtes : une silhouette debout
		# entourée d'un cercle (le portail), et Aïna qui lui tend la main.
		for centre in [Vector2(370, 200), Vector2(430, 205)]:
			tache.call(centre + Vector2(0, -52), Vector2(10, 11), 0.9)
			ligne.call(centre + Vector2(0, -40), centre + Vector2(0, 10), 5.0, 0.9)
			ligne.call(centre + Vector2(0, 10), centre + Vector2(-12, 52), 4.0, 0.9)
			ligne.call(centre + Vector2(0, 10), centre + Vector2(12, 52), 4.0, 0.9)
			ligne.call(centre + Vector2(0, -28), centre + Vector2(-20, -2), 3.5, 0.9)
			ligne.call(centre + Vector2(0, -28), centre + Vector2(22, -10), 3.5, 0.9)
		for k in 48:
			var a := k * TAU / 48.0
			tache.call(Vector2(370, 195) + Vector2(cos(a) * 62, sin(a) * 74), Vector2(3.5, 3.5), 0.85)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
