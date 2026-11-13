@tool
extends Node3D
## Île de la Préhistoire, zone 1 : la Côte Gelée (niveaux 1-3).
##
## Il y a environ 17 000 ans, en pleine période glaciaire. Une crique de galets
## entre deux falaises de calcaire, une mer froide où flottent des blocs de
## glace, un plateau enneigé qui monte vers le col de la Steppe des Mammouths
## (au nord). Le portail de la Vigie est installé sur la plage.
##
## Tout est construit par le code au lancement. Les textures, rochers, bois mort
## et le ciel viennent de Poly Haven (gratuits, licence CC0) : s'ils ne sont pas
## téléchargés, des matériaux simples les remplacent.
## Le bouton « Reconstruire l'île » de l'Inspecteur refait tout.
##
## Repères : le nord est vers -Z, la mer au sud (+Z).

const Pnj := preload("res://scripts/monde/prehistoire/pnj_epoque.gd")
const Faille := preload("res://scripts/monde/prehistoire/faille.gd")
const ObjetQuete := preload("res://scripts/monde/prehistoire/objet_quete.gd")
const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")

## Nombre qui détermine la forme du relief. Même graine = même île.
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
## Ciel Poly Haven utilisé (nom du fichier dans assets/prehistoire/ciel/, sans .hdr).
@export var ciel := "kloofendal_misty_morning_puresky":
	set(valeur):
		ciel = valeur
		if is_inside_tree():
			_appliquer_ciel()
## Point d'apparition du joueur (x, z), juste devant le portail.
@export var point_apparition := Vector2(0, 41)

@export_tool_button("Reconstruire l'île", "Reload") var _bouton := reconstruire

const DOSSIER := "res://assets/prehistoire/"
const SHADER_TERRAIN := preload("res://shaders/prehistoire_terrain.gdshader")
const SHADER_MER := preload("res://shaders/prehistoire_mer.gdshader")
const SHADER_HERBE := preload("res://shaders/prehistoire_herbe.gdshader")
const SHADER_FRACTURE := preload("res://shaders/prehistoire_fracture.gdshader")

## Textures Poly Haven de chaque sol (la première trouvée est utilisée).
const TEXTURES_SOLS := {
	"galets": ["dry_river_pebbles", "clean_pebbles"],
	"neige": ["snow_02", "snow_03"],
	"sol": ["dry_ground_rocks", "brown_mud_rocks_01"],
	"roche": ["cliff_side", "rock_wall_10", "rock_boulder_dry"],
}
## Rochers Poly Haven (avec leur taille habituelle en mètres, pour les mettre à l'échelle).
const MODELES_ROCHERS := ["rock_07", "rock_09", "stone_01", "boulder_01"]
const MODELES_BOIS := ["dead_tree_trunk", "dead_tree_trunk_02", "tree_stump_01", "dry_branches_medium_01"]

## Taille du terrain (mètres, carré centré sur 0).
const TAILLE := 320
const NIVEAU_MER := 0.0
## Le portail de la Vigie, sur la plage.
const PORTAIL := Vector2(0, 47)
## L'agent Lenoir, blessé contre un rocher.
const LENOIR := Vector2(-7, 36)
## Les caisses renversées où se trouve la trousse de soin.
const CAISSES := Vector2(13, 27)
## La faille ouverte au nord du camp.
const FAILLE := Vector2(3, 0)
## Le col qui mène à la Steppe des Mammouths.
const COL := Vector2(10, -138)
## Le squelette de mammouth, sur le plateau.
const MAMMOUTH := Vector2(-34, -34)
## La piste qui monte du camp vers le col (les pas ont tassé la neige).
const PISTE := [Vector2(0, 42), Vector2(3, 14), Vector2(-4, -20), Vector2(-2, -60), Vector2(6, -100), Vector2(10, -140)]

var _relief: FastNoiseLite
var _details: FastNoiseLite
var _rivage: FastNoiseLite
var _contenu: Node3D
var _materiaux := {}
var _reconstruction_demandee := false
var _neige: GPUParticles3D
var _bruit_tex: NoiseTexture2D
var _voile_portail: MeshInstance3D
var _zone_portail: Area3D
var _portail_arme := false
var _temps := 0.0


func _ready() -> void:
	add_to_group("ile")
	reconstruire()
	if Engine.is_editor_hint():
		return
	var loups := get_node_or_null("Partie/Loups")
	if loups != null:
		loups.child_entered_tree.connect(func(n: Node): _habiller_fracture.call_deferred(n))


func _demander_reconstruction() -> void:
	if not is_inside_tree() or _reconstruction_demandee:
		return
	_reconstruction_demandee = true
	reconstruire.call_deferred()


func _process(delta: float) -> void:
	_temps += delta
	# La neige suit la caméra.
	if _neige != null and is_instance_valid(_neige):
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			_neige.global_position = camera.global_position + Vector3(0, 6, 0)
	if _voile_portail != null and is_instance_valid(_voile_portail):
		_voile_portail.rotation.z = _temps * 0.4
	if Engine.is_editor_hint():
		return
	_surveiller_portail()


# --- Relief ----------------------------------------------------------------

func _preparer_bruits() -> void:
	_relief = FastNoiseLite.new()
	_relief.seed = graine
	_relief.frequency = 0.009
	_relief.fractal_octaves = 4
	_details = FastNoiseLite.new()
	_details.seed = graine + 1
	_details.frequency = 0.08
	_details.fractal_octaves = 2
	_rivage = FastNoiseLite.new()
	_rivage.seed = graine + 2
	_rivage.frequency = 0.012
	_rivage.fractal_octaves = 3


## Position (z) du bord de l'eau pour une position x : une crique au centre.
func ligne_rivage(x: float) -> float:
	if _rivage == null:
		_preparer_bruits()
	return 68.0 - 9.0 * exp(-pow(x / 55.0, 2.0)) + _rivage.get_noise_1d(x) * 7.0


## Hauteur du sol (mètres) à une position x, z du monde.
func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	# Distance au rivage : positive dans les terres, négative sous l'eau.
	var s := ligne_rivage(x) - z
	var h: float
	if s < 0.0:
		h = maxf(s * 0.16, -9.0)
	else:
		# Plage de galets en pente douce, puis plateau qui monte vers le nord.
		h = s * 0.06 + smoothstep(22.0, 75.0, s) * 4.5 + smoothstep(80.0, 200.0, s) * 7.5
	var terres := smoothstep(6.0, 40.0, s)
	h += _relief.get_noise_2d(x, z) * 3.2 * terres
	# Congères : bosses allongées par le vent.
	h += absf(_details.get_noise_2d(x * 0.6, z * 1.4)) * 0.9 * terres
	h += _details.get_noise_2d(x * 4.0, z * 4.0) * 0.08
	# Falaises de calcaire à l'ouest et à l'est (elles plongent dans la mer).
	var bord := absf(x) + _relief.get_noise_2d(z * 0.9, 300.0) * 12.0 + _details.get_noise_2d(z * 0.6, 40.0) * 3.0
	var limite := 98.0 if x < 0.0 else 106.0
	var falaise := smoothstep(limite - 4.0, limite + 3.0, bord)
	var haut_falaise := (23.0 if x < 0.0 else 29.0) + _relief.get_noise_2d(x * 1.5, z * 1.5) * 5.0 \
			+ (1.0 - absf(_details.get_noise_2d(x * 0.3, z * 0.3))) * 6.0
	h = lerpf(h, maxf(h, haut_falaise), falaise)
	# Montagnes au nord, sauf le col qui mène à la Steppe.
	var col := exp(-pow((x - COL.x) / 14.0, 2.0))
	var nord := smoothstep(-108.0, -150.0, z + _relief.get_noise_2d(x * 0.8, 77.0) * 10.0)
	# Des crêtes découpées plutôt que des dunes arrondies.
	var crete := 1.0 - absf(_relief.get_noise_2d(x * 2.2, z * 2.2 + 500.0))
	h += nord * (26.0 + crete * crete * 26.0) * (1.0 - col * 0.8)
	# Bords du terrain : de hautes crêtes pour ne jamais voir le vide.
	h += smoothstep(138.0, 158.0, absf(x)) * (18.0 + crete * 14.0)
	return h


## Part de chaque sol (galets, neige, terre) à une position : rouge, vert, bleu.
func _parts_sol(x: float, z: float, h: float) -> Color:
	var s := ligne_rivage(x) - z
	var n := _relief.get_noise_2d(x * 2.0 + 90.0, z * 2.0)
	var galets := 1.0 - smoothstep(14.0, 28.0, s + n * 9.0)
	var neige := smoothstep(16.0, 46.0, s + n * 22.0) + smoothstep(10.0, 18.0, h) * 0.8
	# Autour du camp de la Vigie et sur la piste, la neige est tassée et fondue.
	var camp := exp(-Vector2(x, z).distance_squared_to(Vector2(2, 34)) / 260.0)
	var piste := exp(-pow(_distance_piste(Vector2(x, z)) / 2.6, 2.0))
	neige *= 1.0 - maxf(camp * 0.85, piste * 0.7)
	return Color(galets, clampf(neige, 0.0, 1.0), 1.0 - galets, 1.0)


func _distance_piste(p: Vector2) -> float:
	var meilleure := INF
	for i in PISTE.size() - 1:
		var a: Vector2 = PISTE[i]
		var b: Vector2 = PISTE[i + 1]
		var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		meilleure = minf(meilleure, p.distance_to(a + (b - a) * t))
	return meilleure


# --- Construction ------------------------------------------------------------

func reconstruire() -> void:
	_reconstruction_demandee = false
	_preparer_bruits()
	_materiaux.clear()
	if _contenu != null and is_instance_valid(_contenu):
		_contenu.free()
	_contenu = Node3D.new()
	_contenu.name = "Genere"
	add_child(_contenu)
	_construire_terrain()
	_construire_mer()
	_construire_glace()
	_construire_rochers()
	_construire_bois_flotte()
	_construire_touffes()
	_construire_camp_vigie()
	_construire_squelette_mammouth()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_construire_neige_qui_tombe()
	_appliquer_ciel()


# --- Ressources Poly Haven -----------------------------------------------------

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
	for sol in TEXTURES_SOLS:
		var id := _premiere_texture(TEXTURES_SOLS[sol])
		if id == "":
			continue
		m.set_shader_parameter(sol + "_texture", true)
		m.set_shader_parameter(sol + "_couleur", _texture(id, "Diffuse"))
		m.set_shader_parameter(sol + "_relief", _texture(id, "nor_gl"))
		m.set_shader_parameter(sol + "_arm", _texture(id, "arm"))
	_materiaux["terrain"] = m
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


# --- Terrain ---------------------------------------------------------------------

func _construire_terrain() -> void:
	var cotes := TAILLE + 1
	var demi := TAILLE * 0.5
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
	indices.resize(TAILLE * TAILLE * 6)
	var n := 0
	for j in TAILLE:
		for i in TAILLE:
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


# --- Mer et glace ------------------------------------------------------------------

func _construire_mer() -> void:
	var plan := PlaneMesh.new()
	plan.size = Vector2(2400, 2000)
	plan.subdivide_width = 120
	plan.subdivide_depth = 100
	var m := ShaderMaterial.new()
	m.shader = SHADER_MER
	m.set_shader_parameter("vagues_a", _texture_vagues(graine + 30, 0.02))
	m.set_shader_parameter("vagues_b", _texture_vagues(graine + 31, 0.05))
	m.set_shader_parameter("bruit_ecume", _bruit())
	var mer := MeshInstance3D.new()
	mer.name = "Mer"
	mer.mesh = plan
	mer.material_override = m
	mer.position = Vector3(0, NIVEAU_MER, 700)
	mer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_contenu.add_child(mer)


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


func _construire_glace() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 40
	var dossier := Node3D.new()
	dossier.name = "Glace"
	_contenu.add_child(dossier)
	# Plaques de glace dérivantes près du rivage.
	var places := 0
	var essais := 0
	while places < 46 and essais < 600:
		essais += 1
		var x := hasard.randf_range(-150.0, 150.0)
		var z := hasard.randf_range(70.0, 260.0)
		if hauteur(x, z) > -1.5:
			continue
		var rayon := hasard.randf_range(1.5, 6.0) * (1.0 + (z - 70.0) / 200.0)
		var plaque := MeshInstance3D.new()
		plaque.mesh = _maillage_banquise(hasard, rayon, hasard.randf_range(0.35, 0.8))
		plaque.position = Vector3(x, NIVEAU_MER + hasard.randf_range(-0.05, 0.08), z)
		plaque.rotation.y = hasard.randf() * TAU
		dossier.add_child(plaque)
		places += 1
	# Icebergs au large.
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.7
	for k in 7:
		bruit.seed = graine + 50 + k
		var taille := hasard.randf_range(8.0, 22.0)
		var berg := MeshInstance3D.new()
		berg.mesh = _maillage_bosse(bruit, Vector3(taille, taille * hasard.randf_range(0.5, 0.9), taille * 0.8), 1.6, 0.45, 20)
		berg.material_override = _mat_glace()
		berg.position = Vector3(hasard.randf_range(-260.0, 260.0), -taille * 0.25, hasard.randf_range(170.0, 520.0))
		berg.rotation.y = hasard.randf() * TAU
		dossier.add_child(berg)
	# Glace collée au pied des falaises.
	for k in 40:
		var cote := -1.0 if k % 2 == 0 else 1.0
		var x := cote * hasard.randf_range(75.0, 115.0)
		var z := ligne_rivage(x) + hasard.randf_range(-2.0, 14.0)
		if hauteur(x, z) > NIVEAU_MER - 0.2:
			continue
		var bloc := MeshInstance3D.new()
		bloc.mesh = _maillage_banquise(hasard, hasard.randf_range(2.0, 4.0), hasard.randf_range(0.6, 1.4))
		bloc.position = Vector3(x, NIVEAU_MER + 0.05, z)
		bloc.rotation = Vector3(hasard.randf_range(-0.15, 0.15), hasard.randf() * TAU, hasard.randf_range(-0.15, 0.15))
		dossier.add_child(bloc)


# --- Rochers ---------------------------------------------------------------------

func _construire_rochers() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 11
	var dossier := Node3D.new()
	dossier.name = "Rochers"
	_contenu.add_child(dossier)
	var modeles: Array[String] = []
	for id in MODELES_ROCHERS:
		if ResourceLoader.exists(DOSSIER + "modeles/%s/%s.gltf" % [id, id]):
			modeles.append(id)
	# Quelques formes de rochers (réutilisées pour aller vite), avec leur collision.
	var formes: Array[ArrayMesh] = []
	var collisions: Array[Shape3D] = []
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.9
	for k in 10:
		bruit.seed = graine + 100 + k
		var echelle := Vector3(hasard.randf_range(0.9, 1.3), hasard.randf_range(0.55, 0.85), hasard.randf_range(0.9, 1.3))
		var maillage := _maillage_bosse(bruit, echelle, 1.8, 0.42, 16)
		formes.append(maillage)
		collisions.append(maillage.create_convex_shape(true, true))
	var placer := func(x: float, z: float, taille: float, enfoui := 0.35) -> void:
		var y := hauteur(x, z)
		if y < NIVEAU_MER - 1.0:
			return
		var corps := StaticBody3D.new()
		corps.position = Vector3(x, y - taille * enfoui, z)
		corps.rotation = Vector3(hasard.randf_range(-0.25, 0.25), hasard.randf() * TAU, hasard.randf_range(-0.25, 0.25))
		var neige := clampf(_parts_sol(x, z, y).g * 1.2, 0.0, 1.0)
		var k := hasard.randi() % formes.size()
		# Un vrai rocher scanné (Poly Haven) pour une partie des gros rochers.
		var scanne: Node3D = null
		if not modeles.is_empty() and taille > 1.0 and hasard.randf() < 0.6:
			scanne = _modele(modeles[hasard.randi() % modeles.size()], Vector3.ZERO, 0.0, taille * 0.9, corps)
		if scanne == null:
			var visuel := MeshInstance3D.new()
			visuel.mesh = formes[k]
			visuel.scale = Vector3.ONE * taille
			visuel.material_override = _mat_terrain()
			visuel.set_instance_shader_parameter("roche_forcee", 1.0)
			visuel.set_instance_shader_parameter("neige_en_plus", neige)
			corps.add_child(visuel)
		var collision := CollisionShape3D.new()
		collision.shape = collisions[k]
		collision.scale = Vector3.ONE * taille
		corps.add_child(collision)
		dossier.add_child(corps)
	# Éboulis au pied des falaises : on cherche, sur chaque ligne, où la pente commence.
	for k in 150:
		var cote := -1.0 if k % 2 == 0 else 1.0
		var z := hasard.randf_range(-110.0, 75.0)
		var x := cote * 70.0
		while absf(x) < 130.0 and hauteur(x + cote, z) - hauteur(x, z) < 0.6:
			x += cote
		x -= cote * hasard.randf_range(0.0, 7.0)
		placer.call(x, z, hasard.randf_range(0.8, 4.2) * (1.6 if hasard.randf() < 0.15 else 1.0))
	# Pans de roche scannés plaqués contre les falaises.
	for k in 36:
		var cote := -1.0 if k % 2 == 0 else 1.0
		var z := hasard.randf_range(-105.0, 70.0)
		var x := cote * 70.0
		while absf(x) < 130.0 and hauteur(x + cote, z) - hauteur(x, z) < 0.8:
			x += cote
		var id := "rock_face_01" if hasard.randf() < 0.5 else "rock_face_02"
		var pan := _modele(id, Vector3(x + cote * 1.5, hauteur(x, z) - 1.0, z), (PI / 2 if cote > 0 else -PI / 2) + hasard.randf_range(-0.4, 0.4),
				hasard.randf_range(3.5, 6.5), dossier)
		if pan != null:
			pan.rotation.x = hasard.randf_range(-0.1, 0.1)
	# Amas de gros rochers sur le plateau (on s'en sert pour se repérer).
	for k in 16:
		var cx := hasard.randf_range(-80.0, 85.0)
		var cz := hasard.randf_range(-115.0, 20.0)
		if Vector2(cx, cz).distance_to(FAILLE) < 14.0 or _distance_piste(Vector2(cx, cz)) < 8.0:
			continue
		for r in hasard.randi_range(2, 5):
			placer.call(cx + hasard.randf_range(-5.0, 5.0), cz + hasard.randf_range(-5.0, 5.0), hasard.randf_range(1.2, 3.8))
	# Rochers épars sur la plage et le plateau.
	var places := 0
	var essais := 0
	while places < 240 and essais < 3000:
		essais += 1
		var x := hasard.randf_range(-95.0, 100.0)
		var z := hasard.randf_range(-130.0, 72.0)
		var p := Vector2(x, z)
		# On garde dégagés le camp, la piste et la faille.
		if p.distance_to(Vector2(2, 38)) < 16.0 or _distance_piste(p) < 4.0 or p.distance_to(FAILLE) < 8.0:
			continue
		var grand := hasard.randf() < 0.18
		placer.call(x, z, hasard.randf_range(1.4, 3.2) if grand else hasard.randf_range(0.25, 0.9))
		places += 1
	# Le rocher contre lequel Lenoir s'est abrité.
	placer.call(LENOIR.x - 1.6, LENOIR.y - 1.2, 1.5, 0.3)


# --- Bois flotté et bois mort ---------------------------------------------------

func _construire_bois_flotte() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 60
	var dossier := Node3D.new()
	dossier.name = "BoisFlotte"
	_contenu.add_child(dossier)
	var bois := _mat_pbr("rough_wood", Color(0.72, 0.68, 0.62), 0.95, 1.5)
	var modeles: Array[String] = []
	for id in MODELES_BOIS:
		if ResourceLoader.exists(DOSSIER + "modeles/%s/%s.gltf" % [id, id]):
			modeles.append(id)
	for k in 34:
		var x := hasard.randf_range(-85.0, 90.0)
		var z := ligne_rivage(x) - hasard.randf_range(3.0, 16.0)
		if Vector2(x, z).distance_to(PORTAIL) < 9.0:
			continue
		var y := hauteur(x, z)
		var angle := hasard.randf() * TAU
		if not modeles.is_empty() and hasard.randf() < 0.5:
			var m := _modele(modeles[hasard.randi() % modeles.size()], Vector3(x, y - 0.1, z), angle,
					hasard.randf_range(0.6, 1.1), dossier)
			if m != null:
				continue
		# Tronc blanchi par le sel et le gel.
		var longueur := hasard.randf_range(1.5, 5.5)
		var tronc := MeshInstance3D.new()
		var cylindre := CylinderMesh.new()
		cylindre.top_radius = hasard.randf_range(0.06, 0.12)
		cylindre.bottom_radius = hasard.randf_range(0.14, 0.26)
		cylindre.height = longueur
		cylindre.radial_segments = 9
		tronc.mesh = cylindre
		tronc.material_override = bois
		tronc.position = Vector3(x, y + 0.1, z)
		tronc.rotation = Vector3(PI / 2 + hasard.randf_range(-0.08, 0.08), angle, 0)
		dossier.add_child(tronc)


# --- Herbe sèche ------------------------------------------------------------------

func _construire_touffes() -> void:
	if nombre_touffes <= 0 or DisplayServer.get_name() == "headless":
		return
	var brin := _maillage_touffe()
	var materiau := ShaderMaterial.new()
	materiau.shader = SHADER_HERBE
	brin.surface_set_material(0, materiau)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 21
	const BLOC := 20.0
	var demi := TAILLE * 0.5 - 20.0
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


# --- Camp de la Vigie et portail ---------------------------------------------------

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


func _construire_camp_vigie() -> void:
	var camp := Node3D.new()
	camp.name = "CampVigie"
	_contenu.add_child(camp)
	var cyan := Color(0.3, 0.85, 1.0)
	# --- Le portail : un anneau dressé sur un socle, tourné vers les terres.
	var sol := hauteur(PORTAIL.x, PORTAIL.y)
	var portail := Node3D.new()
	portail.name = "Portail"
	portail.position = Vector3(PORTAIL.x, sol, PORTAIL.y)
	camp.add_child(portail)
	var socle := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 3.0
	cyl.bottom_radius = 3.3
	cyl.height = 0.8
	socle.mesh = cyl
	socle.material_override = _metal()
	socle.position.y = 0.1
	portail.add_child(socle)
	var anneau := MeshInstance3D.new()
	var tore := TorusMesh.new()
	tore.inner_radius = 2.1
	tore.outer_radius = 2.5
	tore.rings = 48
	anneau.mesh = tore
	anneau.material_override = _metal()
	anneau.rotation.x = PI / 2
	anneau.position.y = 3.0
	portail.add_child(anneau)
	var lisere := MeshInstance3D.new()
	var tore2 := TorusMesh.new()
	tore2.inner_radius = 2.08
	tore2.outer_radius = 2.16
	tore2.rings = 48
	lisere.mesh = tore2
	lisere.material_override = _lumineux(cyan, 4.0)
	lisere.rotation.x = PI / 2
	lisere.position.y = 3.0
	portail.add_child(lisere)
	# Voile tourbillonnant (une faille apprivoisée, en bleu).
	_voile_portail = MeshInstance3D.new()
	var disque := QuadMesh.new()
	disque.size = Vector2(4.3, 4.3)
	_voile_portail.mesh = disque
	var voile := ShaderMaterial.new()
	voile.shader = preload("res://shaders/prehistoire_portail.gdshader")
	voile.set_shader_parameter("bruit", _bruit())
	_voile_portail.material_override = voile
	_voile_portail.position.y = 3.0
	_voile_portail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	portail.add_child(_voile_portail)
	var lumiere := OmniLight3D.new()
	lumiere.light_color = cyan
	lumiere.light_energy = 2.5
	lumiere.omni_range = 14.0
	lumiere.position = Vector3(0, 3.0, -1.5)
	portail.add_child(lumiere)
	# Collision des montants (on ne traverse pas l'anneau par les côtés).
	for cote in [-1.0, 1.0]:
		_boite(Vector3(0.5, 5.2, 0.6), Vector3(cote * 2.3, 2.7, 0), _metal(), portail).visible = false
	# Zone de retour vers Hikari Bay, au centre de l'anneau.
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
	portail.add_child(_zone_portail)
	_zone_portail.body_entered.connect(_sur_portail)
	# Câbles et générateur.
	var generateur := _boite(Vector3(1.4, 1.0, 0.9), Vector3(PORTAIL.x + 4.5, sol + 0.5, PORTAIL.y + 1.5),
			_mat_pbr("", Color(0.85, 0.55, 0.12), 0.6), camp)
	generateur.rotation.y = 0.3
	_boite(Vector3(0.9, 0.06, 0.5), Vector3(0, 0.53, 0), _lumineux(cyan, 2.0), generateur, false)
	# --- Tente arrachée par les fracturés.
	var t := Vector2(10, 37)
	var tente := MeshInstance3D.new()
	var prisme := PrismMesh.new()
	prisme.size = Vector3(3.2, 1.9, 3.6)
	tente.mesh = prisme
	tente.material_override = _mat_pbr("", Color(0.78, 0.33, 0.1), 0.8)
	tente.position = Vector3(t.x, hauteur(t.x, t.y) + 0.85, t.y)
	tente.rotation = Vector3(0.0, 0.7, 0.14)
	camp.add_child(tente)
	# Toile déchirée : l'entrée est ouverte, un pan pend sur le côté.
	var entree := MeshInstance3D.new()
	var triangle := PrismMesh.new()
	triangle.size = Vector3(1.4, 1.2, 0.05)
	entree.mesh = triangle
	entree.material_override = _mat_pbr("", Color(0.05, 0.05, 0.06), 1.0)
	entree.position = Vector3(0, -0.33, 1.81)
	tente.add_child(entree)
	# --- Projecteurs sur trépied.
	for p in [Vector2(-6, 44), Vector2(7, 43), Vector2(-3, 30)]:
		_projecteur(camp, p, cyan)
	# --- Caisses (renversées là où se trouve la trousse).
	var caisses := [
		[Vector2(CAISSES.x - 1.2, CAISSES.y), 0.4, 0.0], [Vector2(CAISSES.x + 0.9, CAISSES.y + 0.8), 1.2, 1.4],
		[Vector2(CAISSES.x + 0.3, CAISSES.y - 1.4), 2.4, 1.57], [Vector2(-4, 46), 0.1, 0.0],
		[Vector2(-4.2, 47.2), 0.3, 0.0], [Vector2(5, 49), 2.0, 0.0],
	]
	for c in caisses:
		var p: Vector2 = c[0]
		var y := hauteur(p.x, p.y)
		var m := _modele_hub("plastic_crate_01", Vector3(p.x, y, p.y), c[1], camp)
		if m == null:
			m = _boite(Vector3(0.6, 0.4, 0.4), Vector3(p.x, y + 0.2, p.y), _mat_pbr("", Color(0.2, 0.3, 0.38), 0.6), camp)
		m.rotation.z = c[2]
		if c[2] != 0.0:
			m.position.y += 0.2


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


func _projecteur(parent: Node3D, p: Vector2, couleur: Color) -> void:
	var y := hauteur(p.x, p.y)
	var pied := Node3D.new()
	pied.position = Vector3(p.x, y, p.y)
	parent.add_child(pied)
	for k in 3:
		var jambe := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.025
		c.bottom_radius = 0.03
		c.height = 2.1
		jambe.mesh = c
		jambe.material_override = _metal()
		var a := TAU * k / 3.0
		jambe.position = Vector3(cos(a) * 0.35, 1.0, sin(a) * 0.35)
		jambe.rotation = Vector3(sin(a) * 0.17, 0, -cos(a) * 0.17)
		pied.add_child(jambe)
	var tete := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.45, 0.3, 0.2)
	tete.mesh = b
	tete.material_override = _metal()
	tete.position.y = 2.1
	pied.add_child(tete)
	var vitre := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.38, 0.22)
	vitre.mesh = q
	vitre.material_override = _lumineux(Color(1.0, 0.95, 0.85), 6.0)
	vitre.position = Vector3(0, 2.1, -0.11)
	vitre.rotation.y = PI
	pied.add_child(vitre)
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.95, 0.88)
	spot.light_energy = 3.0
	spot.spot_range = 22.0
	spot.spot_angle = 38.0
	spot.position = Vector3(0, 2.1, -0.2)
	spot.rotation.x = -0.35
	spot.add_to_group("lumiere_secondaire")
	pied.add_child(spot)
	# Le projecteur éclaire le camp (vers son centre).
	var centre := Vector3(2, y, 36)
	var vers := centre - pied.position
	pied.rotation.y = atan2(-vers.x, -vers.z)


# --- Squelette de mammouth ----------------------------------------------------------

func _construire_squelette_mammouth() -> void:
	var os := _mat_pbr("", Color(0.80, 0.76, 0.66), 0.85)
	var y := hauteur(MAMMOUTH.x, MAMMOUTH.y)
	var squelette := Node3D.new()
	squelette.name = "SqueletteMammouth"
	squelette.position = Vector3(MAMMOUTH.x, y - 0.4, MAMMOUTH.y)
	squelette.rotation = Vector3(0, 0.9, 0.08)
	_contenu.add_child(squelette)
	# Colonne vertébrale.
	for k in 16:
		var v := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.16 - k * 0.004
		s.height = s.radius * 2.0
		v.mesh = s
		v.material_override = os
		v.position = Vector3(0, 1.3 - pow(k / 15.0 - 0.3, 2.0) * 0.8, -1.8 + k * 0.28)
		squelette.add_child(v)
	# Côtes : des arcs à moitié enfouis dans la neige.
	for k in 9:
		for cote in [-1.0, 1.0]:
			var cote_os := MeshInstance3D.new()
			var tore := TorusMesh.new()
			var r := 1.0 - absf(k - 3.0) * 0.07
			tore.inner_radius = r
			tore.outer_radius = r + 0.09
			tore.rings = 20
			tore.ring_segments = 6
			cote_os.mesh = tore
			cote_os.material_override = os
			cote_os.position = Vector3(cote * 0.15, 1.25 - r * 0.2, -1.2 + k * 0.32)
			cote_os.rotation = Vector3(0, 0, PI / 2 + cote * 0.25)
			cote_os.scale = Vector3(1.0, 1.0, 0.6)
			squelette.add_child(cote_os)
	# Crâne.
	var crane := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 1.1
	crane.mesh = sphere
	crane.material_override = os
	crane.position = Vector3(0, 1.1, -2.6)
	crane.scale = Vector3(1.0, 1.15, 0.9)
	squelette.add_child(crane)
	# Défenses : longues, recourbées en spirale.
	for cote in [-1.0, 1.0]:
		var precedent := Vector3(cote * 0.28, 0.85, -2.95)
		for k in 14:
			var t := (k + 1) / 14.0
			var point := Vector3(cote * (0.28 + sin(t * 2.4) * 0.9), 0.85 - sin(t * 1.6) * 0.55 + t * t * 1.2,
					-2.95 - sin(t * 2.0) * 2.0)
			var segment := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.13 * (1.0 - t * 0.75)
			c.bottom_radius = 0.13 * (1.0 - (t - 1.0 / 14.0) * 0.75)
			c.height = precedent.distance_to(point) + 0.02
			c.radial_segments = 8
			segment.mesh = c
			segment.material_override = os
			squelette.add_child(segment)
			segment.position = (precedent + point) * 0.5
			var direction := (point - precedent).normalized()
			segment.basis = Basis(Quaternion(Vector3.UP, direction))
			precedent = point
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(2.2, 2.0, 5.0)
	forme.shape = boite
	forme.position = Vector3(0, 1.0, -0.6)
	corps.add_child(forme)
	squelette.add_child(corps)


# --- Paysage lointain ---------------------------------------------------------------

func _construire_lointain() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 70
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.8
	bruit.fractal_octaves = 4
	# Glaciers et montagnes au nord, derrière le col.
	for k in 9:
		bruit.seed = graine + 200 + k
		var largeur := hasard.randf_range(110.0, 220.0)
		var montagne := MeshInstance3D.new()
		montagne.mesh = _maillage_bosse(bruit, Vector3(largeur, hasard.randf_range(70.0, 140.0), largeur * 0.6),
				1.4, 0.35, 28, Color(0, 0.8, 0.2))
		montagne.material_override = _mat_terrain()
		montagne.position = Vector3(-500.0 + k * 125.0 + hasard.randf_range(-30.0, 30.0), -10.0,
				hasard.randf_range(-480.0, -360.0))
		montagne.set_instance_shader_parameter("neige_en_plus", 0.85)
		montagne.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(montagne)
	# Les falaises se prolongent le long de la côte, à l'est et à l'ouest.
	for k in 6:
		bruit.seed = graine + 300 + k
		var cote := -1.0 if k % 2 == 0 else 1.0
		var cap := MeshInstance3D.new()
		cap.mesh = _maillage_bosse(bruit, Vector3(70.0, 45.0, 60.0), 1.2, 0.3, 24, Color(0, 0.6, 0.4))
		cap.material_override = _mat_terrain()
		cap.position = Vector3(cote * (210.0 + k * 40.0), -6.0, 40.0 + k * 50.0)
		cap.set_instance_shader_parameter("neige_en_plus", 0.6)
		cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(cap)


# --- Limites de la zone ---------------------------------------------------------------

func _construire_limites() -> void:
	var limites := Node3D.new()
	limites.name = "Limites"
	_contenu.add_child(limites)
	var mur := func(taille: Vector3, centre: Vector3, angle := 0.0) -> void:
		var corps := StaticBody3D.new()
		corps.position = centre
		corps.rotation.y = angle
		var forme := CollisionShape3D.new()
		var boite := BoxShape3D.new()
		boite.size = taille
		forme.shape = boite
		corps.add_child(forme)
		limites.add_child(corps)
	# Dans l'eau : on ne va pas plus loin qu'une profondeur d'environ un mètre.
	var pas := 6.0
	var x := -150.0
	while x < 150.0:
		var z1 := ligne_rivage(x) + 7.0
		var z2 := ligne_rivage(x + pas) + 7.0
		var centre := Vector3(x + pas * 0.5, 0.0, (z1 + z2) * 0.5)
		var angle := -atan2(z2 - z1, pas)
		mur.call(Vector3(pas + 1.0, 12.0, 1.0), centre, angle)
		x += pas
	# Bords du terrain.
	var demi := TAILLE * 0.5 - 4.0
	mur.call(Vector3(2, 120, TAILLE), Vector3(-demi, 40, 0))
	mur.call(Vector3(2, 120, TAILLE), Vector3(demi, 40, 0))
	mur.call(Vector3(TAILLE, 120, 2), Vector3(0, 40, -demi))
	# Le col : la Steppe des Mammouths n'est pas encore ouverte.
	mur.call(Vector3(60, 80, 2), Vector3(COL.x, hauteur(COL.x, COL.y) + 30.0, COL.y - 6.0))


# --- Personnages et objets de la quête ------------------------------------------------

func _construire_quete() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quete"
	_contenu.add_child(dossier)
	# L'agent Lenoir, blessé, adossé à un rocher.
	var lenoir := Pnj.new()
	lenoir.name = "Lenoir"
	lenoir.identifiant = "lenoir"
	lenoir.blesse = true
	lenoir.position = Vector3(LENOIR.x, hauteur(LENOIR.x, LENOIR.y), LENOIR.y)
	lenoir.rotation.y = 0.6
	dossier.add_child(lenoir)
	# Point de soin (le même endroit que Lenoir).
	var soin := ObjetQuete.new()
	soin.name = "SoinLenoir"
	soin.identifiant = "soin_lenoir"
	soin.invite = "[F] Soigner l'agent Lenoir"
	soin.position = lenoir.position
	dossier.add_child(soin)
	# La trousse de soin tombée près des caisses renversées.
	var trousse := ObjetQuete.new()
	trousse.name = "Trousse"
	trousse.identifiant = "trousse"
	trousse.invite = "[F] Ramasser la trousse de soin"
	trousse.forme = "trousse"
	trousse.position = Vector3(CAISSES.x + 0.3, hauteur(CAISSES.x + 0.3, CAISSES.y + 0.6), CAISSES.y + 0.6)
	dossier.add_child(trousse)
	# La faille.
	var faille := Faille.new()
	faille.name = "Faille"
	faille.identifiant = "faille_cote"
	faille.position = Vector3(FAILLE.x, hauteur(FAILLE.x, FAILLE.y), FAILLE.y)
	dossier.add_child(faille)
	# Repères de la carte.
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.PORTAIL, "Portail de la Vigie", PORTAIL)
	repere.call(MarqueurCarte.Type.DANGER, "Faille", FAILLE)
	repere.call(MarqueurCarte.Type.LIEU, "Col de la Steppe", COL + Vector2(0, 12))
	repere.call(MarqueurCarte.Type.LIEU, "Squelette de mammouth", MAMMOUTH)
	repere.call(MarqueurCarte.Type.LIEU, "Camp de la Vigie", Vector2(2, 36))
	repere.call(MarqueurCarte.Type.DANGER, "Tanière des loups", Vector2(-46, -58))
	repere.call(MarqueurCarte.Type.DANGER, "Tanière des loups", Vector2(48, -72))


# --- Neige qui tombe ---------------------------------------------------------------------

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


# --- Ciel -------------------------------------------------------------------------------

func _appliquer_ciel() -> void:
	var environnement := get_node_or_null("Environnement") as WorldEnvironment
	if environnement == null or environnement.environment == null:
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


# --- Créatures fracturées -------------------------------------------------------------

## Les loups touchés par la faille reçoivent des veines violettes lumineuses.
func _habiller_fracture(n: Node) -> void:
	if not is_instance_valid(n) or not String(n.get("type_ennemi")).contains("fracture"):
		return
	var apparence := n.get_node_or_null("Apparence")
	if apparence == null:
		return
	if not _materiaux.has("fracture"):
		var m := ShaderMaterial.new()
		m.shader = SHADER_FRACTURE
		m.set_shader_parameter("bruit", _bruit())
		_materiaux["fracture"] = m
	for mi in apparence.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = _materiaux["fracture"]
	var lueur := OmniLight3D.new()
	lueur.light_color = Color(0.6, 0.25, 1.0)
	lueur.light_energy = 0.8
	lueur.omni_range = 3.5
	lueur.position = Vector3(0, 0.8, 0)
	n.add_child(lueur)


# --- Retour vers Hikari Bay ---------------------------------------------------------------

## Le portail ne renvoie le joueur que s'il s'en est d'abord éloigné (à l'arrivée,
## on apparaît juste devant).
func _surveiller_portail() -> void:
	if _portail_arme or _zone_portail == null:
		return
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur != null and Vector2(joueur.global_position.x, joueur.global_position.z).distance_to(PORTAIL) > 8.0:
		_portail_arme = true


func _sur_portail(corps: Node3D) -> void:
	if not _portail_arme or not corps.is_in_group("joueur_local"):
		return
	_portail_arme = false
	var quete := get_tree().get_first_node_in_group("quete")
	if quete != null and quete.has_method("rentrer_au_hub"):
		quete.rentrer_au_hub()
