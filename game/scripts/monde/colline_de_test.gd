@tool
class_name CollineDeTest
extends Node3D
## Terrain de test de l'étape 1 : une colline avec de l'herbe et des rochers.
##
## Tout est fabriqué par le code (aucun fichier 3D à télécharger), à partir
## d'une « graine » : changer la graine dans l'Inspecteur donne une autre colline.
## Le bouton « Régénérer le terrain » de l'Inspecteur reconstruit tout.

## Nombre qui détermine la forme de la colline. Même graine = même colline.
@export var graine := 2026:
	set(valeur):
		graine = valeur
		_demander_regeneration()
## Largeur du terrain (mètres).
@export var taille := 200:
	set(valeur):
		taille = valeur
		_demander_regeneration()
## Hauteur de la colline centrale (mètres).
@export var hauteur_colline := 16.0:
	set(valeur):
		hauteur_colline = valeur
		_demander_regeneration()
## Nombre de brins d'herbe (baisser si le jeu rame).
@export var nombre_brins_herbe := 300000:
	set(valeur):
		nombre_brins_herbe = valeur
		_demander_regeneration()
## Nombre de rochers.
@export var nombre_rochers := 120:
	set(valeur):
		nombre_rochers = valeur
		_demander_regeneration()
## Point d'apparition du joueur (x, z) ; la hauteur est calculée automatiquement.
@export var point_apparition := Vector2(0, 55)

@export_tool_button("Régénérer le terrain", "Reload") var _bouton_regenerer := regenerer

const DISTANCE_AFFICHAGE_HERBE := 70.0
const TAILLE_BLOC_HERBE := 20.0

var _relief: FastNoiseLite
var _details: FastNoiseLite
var _contenu: Node3D
var _regeneration_demandee := false


func _ready() -> void:
	regenerer()


func _demander_regeneration() -> void:
	if not is_inside_tree() or _regeneration_demandee:
		return
	_regeneration_demandee = true
	regenerer.call_deferred()


## Hauteur du sol (mètres) à une position x, z du monde.
func hauteur(x: float, z: float) -> float:
	var distance_centre := Vector2(x, z).length()
	var colline := hauteur_colline * exp(-pow(distance_centre / 42.0, 2.0))
	var bosses := _relief.get_noise_2d(x, z) * 5.0 + _details.get_noise_2d(x, z) * 0.5
	# Les bords du terrain remontent en montagnes pour qu'on ne tombe pas dans le vide.
	var demi := taille * 0.5
	var irregularite := _relief.get_noise_2d(x * 0.7 + 500.0, z * 0.7) * 18.0
	var bord := smoothstep(demi - 45.0 + irregularite, demi - 3.0, maxf(absf(x), absf(z))) * 32.0
	return colline + bosses + bord


func _preparer_bruits() -> void:
	_relief = FastNoiseLite.new()
	_relief.seed = graine
	_relief.frequency = 0.012
	_relief.fractal_octaves = 4
	_details = FastNoiseLite.new()
	_details.seed = graine + 1
	_details.frequency = 0.15


func regenerer() -> void:
	_regeneration_demandee = false
	_preparer_bruits()
	if _contenu != null and is_instance_valid(_contenu):
		_contenu.free()
	_contenu = Node3D.new()
	_contenu.name = "Genere"
	add_child(_contenu)
	_creer_sol()
	_creer_rochers()
	_creer_herbe()


# --- Sol -------------------------------------------------------------------

func _creer_sol() -> void:
	var cotes := taille + 1
	var demi := taille * 0.5
	var hauteurs := PackedFloat32Array()
	hauteurs.resize(cotes * cotes)

	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in cotes:
		for i in cotes:
			var x := i - demi
			var z := j - demi
			var y := hauteur(x, z)
			hauteurs[j * cotes + i] = y
			outil.set_uv(Vector2(i, j) / float(taille))
			outil.add_vertex(Vector3(x, y, z))
	for j in taille:
		for i in taille:
			var a := j * cotes + i
			var b := a + 1
			var c := a + cotes
			var d := c + 1
			outil.add_index(a)
			outil.add_index(b)
			outil.add_index(c)
			outil.add_index(b)
			outil.add_index(d)
			outil.add_index(c)
	outil.generate_normals()

	var materiau := ShaderMaterial.new()
	materiau.shader = load("res://shaders/terrain.gdshader")
	var bruit := NoiseTexture2D.new()
	bruit.width = 512
	bruit.height = 512
	bruit.seamless = true
	bruit.generate_mipmaps = true
	var source := FastNoiseLite.new()
	source.seed = graine + 7
	source.frequency = 0.01
	source.fractal_octaves = 5
	bruit.noise = source
	materiau.set_shader_parameter("bruit", bruit)

	var sol := MeshInstance3D.new()
	sol.name = "Sol"
	sol.mesh = outil.commit()
	sol.material_override = materiau
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


# --- Rochers ---------------------------------------------------------------

func _creer_rochers() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 11
	var materiau := StandardMaterial3D.new()
	materiau.albedo_color = Color(0.46, 0.44, 0.41)
	materiau.roughness = 0.92
	var texture := NoiseTexture2D.new()
	var bruit := FastNoiseLite.new()
	bruit.seed = graine + 13
	bruit.frequency = 0.05
	texture.noise = bruit
	texture.seamless = true
	materiau.albedo_texture = texture
	materiau.uv1_triplanar = true
	materiau.uv1_scale = Vector3(0.6, 0.6, 0.6)

	var forme_bruit := FastNoiseLite.new()
	forme_bruit.frequency = 0.9
	var demi := taille * 0.5 - 30.0
	var places := 0
	var essais := 0
	while places < nombre_rochers and essais < nombre_rochers * 10:
		essais += 1
		var x := hasard.randf_range(-demi, demi)
		var z := hasard.randf_range(-demi, demi)
		# On garde le point d'apparition dégagé.
		if Vector2(x, z).distance_to(point_apparition) < 6.0:
			continue
		forme_bruit.seed = hasard.randi()
		var grand := hasard.randf() < 0.15
		var base := hasard.randf_range(1.5, 3.5) if grand else hasard.randf_range(0.3, 1.2)
		var echelle := Vector3(base * hasard.randf_range(0.8, 1.4), base * hasard.randf_range(0.5, 0.9),
				base * hasard.randf_range(0.8, 1.4))
		var maillage := _maillage_rocher(forme_bruit, echelle)
		var corps := StaticBody3D.new()
		corps.position = Vector3(x, hauteur(x, z) - echelle.y * 0.35, z)
		corps.rotation = Vector3(hasard.randf_range(-0.2, 0.2), hasard.randf() * TAU, hasard.randf_range(-0.2, 0.2))
		var visuel := MeshInstance3D.new()
		visuel.mesh = maillage
		visuel.material_override = materiau
		corps.add_child(visuel)
		var collision := CollisionShape3D.new()
		collision.shape = maillage.create_convex_shape(true, true)
		corps.add_child(collision)
		_contenu.add_child(corps)
		places += 1


func _maillage_rocher(bruit: FastNoiseLite, echelle: Vector3) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 14
	sphere.rings = 9
	var tableaux := sphere.get_mesh_arrays()
	var sommets: PackedVector3Array = tableaux[Mesh.ARRAY_VERTEX]
	for k in sommets.size():
		var v := sommets[k]
		var deformation := 1.0 + bruit.get_noise_3dv(v * 2.0) * 0.45
		sommets[k] = v * deformation * echelle
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices: PackedInt32Array = tableaux[Mesh.ARRAY_INDEX]
	for index in indices:
		outil.add_vertex(sommets[index])
	outil.generate_normals()
	return outil.commit()


# --- Herbe -----------------------------------------------------------------

func _creer_herbe() -> void:
	# Pas d'herbe sur un serveur sans écran : personne ne la verrait.
	if nombre_brins_herbe <= 0 or DisplayServer.get_name() == "headless":
		return
	var brin := _maillage_brin()
	var materiau := ShaderMaterial.new()
	materiau.shader = load("res://shaders/herbe.gdshader")
	brin.surface_set_material(0, materiau)

	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 21
	var demi := taille * 0.5 - 8.0
	var blocs_par_cote := int(ceil(taille / TAILLE_BLOC_HERBE))
	var surface_bloc := TAILLE_BLOC_HERBE * TAILLE_BLOC_HERBE
	var densite := nombre_brins_herbe / float(taille * taille)
	var par_bloc := int(densite * surface_bloc)

	for bj in blocs_par_cote:
		for bi in blocs_par_cote:
			var x0 := -taille * 0.5 + bi * TAILLE_BLOC_HERBE
			var z0 := -taille * 0.5 + bj * TAILLE_BLOC_HERBE
			var transformations: Array[Transform3D] = []
			var teintes: Array[float] = []
			for n in par_bloc:
				var x := x0 + hasard.randf() * TAILLE_BLOC_HERBE
				var z := z0 + hasard.randf() * TAILLE_BLOC_HERBE
				if absf(x) > demi or absf(z) > demi:
					continue
				var y := hauteur(x, z)
				# Pas d'herbe sur les pentes raides (là où le sol devient rocheux).
				var pente := absf(hauteur(x + 0.5, z) - y) + absf(hauteur(x, z + 0.5) - y)
				if pente > 0.35:
					continue
				var t := Transform3D(Basis(Vector3.UP, hasard.randf() * TAU).scaled(
						Vector3.ONE * hasard.randf_range(0.6, 1.4)), Vector3(x, y - 0.02, z))
				transformations.append(t)
				teintes.append(hasard.randf())
			if transformations.is_empty():
				continue
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.use_custom_data = true
			multi.mesh = brin
			multi.instance_count = transformations.size()
			for k in transformations.size():
				multi.set_instance_transform(k, transformations[k])
				multi.set_instance_custom_data(k, Color(teintes[k], 0, 0, 0))
			var instance := MultiMeshInstance3D.new()
			instance.multimesh = multi
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			instance.visibility_range_end = DISTANCE_AFFICHAGE_HERBE
			instance.visibility_range_end_margin = 10.0
			instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			_contenu.add_child(instance)


## Une touffe de 3 brins d'herbe effilés, croisés.
func _maillage_brin() -> ArrayMesh:
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 5:
		var angle := k * TAU / 5.0 + 0.3
		var cote := Vector3(cos(angle), 0, sin(angle)) * 0.025
		var penche := Vector3(-sin(angle), 0, cos(angle)) * (0.08 + 0.04 * (k % 2))
		var decalage := Vector3(cos(angle * 2.0), 0, sin(angle * 2.0)) * 0.05
		var hauteur_brin := 0.35 + (k % 3) * 0.1
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
