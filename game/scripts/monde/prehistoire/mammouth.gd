@tool
extends Node3D
## Mammouth laineux : un géant paisible qui broute dans la steppe avec son troupeau.
## Il marche lentement d'un point à l'autre autour du centre du troupeau.
## Le modèle est fabriqué par outils/generer_mammouth.gd (corps sculpté, défenses,
## longues mèches) et animé ici par son squelette : pas lourds, trompe, queue.
## S'il manque, on retombe sur une silhouette en formes simples.

const MAILLAGE := "res://assets/animaux/mammouth/mammouth.res"
const SHADER_PELAGE := preload("res://shaders/mammouth_pelage.gdshader")

## Centre du troupeau (x, z) et rayon dans lequel il se promène.
@export var centre := Vector2.ZERO
@export var rayon := 30.0
## 1 = adulte, 0.6 = petit.
@export var taille := 1.0:
	set(valeur):
		taille = valeur
		if is_inside_tree():
			_construire()
@export var graine := 1

var _corps: Node3D
var _tete: Node3D
var _trompe: Array[Node3D] = []
var _pattes: Array[Node3D] = []
var _queue: Node3D
var _hasard := RandomNumberGenerator.new()
var _but := Vector3.ZERO
var _attente := 0.0
var _phase := 0.0
var _temps := 0.0
var _vitesse := 0.0
var _squelette: Skeleton3D
var _os: Array = []
## Grande Migration : points (x, z) à suivre l'un après l'autre, puis il broute au bout.
var _chemin: Array[Vector2] = []
var _vitesse_migration := 0.0
## Vrai pendant la panique (il court, puis s'arrête où il est).
var panique := 0.0
static var _materiaux_modele: Array = []


func _ready() -> void:
	add_to_group("mammouths")
	_hasard.seed = graine
	_construire()
	_attente = _hasard.randf_range(0.0, 2.0)
	_nouveau_but()


## Le mammouth suit « chemin » (points x, z) à « vitesse » m/s, puis broute au bout.
func migrer(chemin: Array[Vector2], vitesse: float) -> void:
	_chemin = chemin.duplicate()
	_vitesse_migration = vitesse
	_attente = 0.0
	_but = Vector3(_chemin[0].x, 0, _chemin[0].y)


func en_migration() -> bool:
	return not _chemin.is_empty()


## Arrête la migration : il broute autour de l'endroit où il se trouve.
func arreter_migration() -> void:
	_chemin.clear()
	centre = Vector2(global_position.x, global_position.z)
	rayon = minf(rayon, 20.0)
	_nouveau_but()


## Le troupeau s'affole : il court droit devant quelques secondes.
func paniquer(duree: float) -> void:
	panique = duree
	var a := _hasard.randf() * TAU
	_but = global_position + Vector3(cos(a), 0, sin(a)) * 30.0
	_attente = 0.0


func _nouveau_but() -> void:
	var a := _hasard.randf() * TAU
	var r := sqrt(_hasard.randf()) * rayon
	_but = Vector3(centre.x + cos(a) * r, 0, centre.y + sin(a) * r)


static var _relief_poils: NoiseTexture2D


func _fourrure(couleur: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = 1.0
	# Un relief de mèches pour casser l'aspect lisse.
	if _relief_poils == null:
		_relief_poils = NoiseTexture2D.new()
		_relief_poils.width = 256
		_relief_poils.height = 256
		_relief_poils.seamless = true
		_relief_poils.as_normal_map = true
		_relief_poils.bump_strength = 12.0
		var b := FastNoiseLite.new()
		b.noise_type = FastNoiseLite.TYPE_CELLULAR
		b.frequency = 0.08
		_relief_poils.noise = b
	m.normal_enabled = true
	m.normal_texture = _relief_poils
	m.normal_scale = 1.4
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(3.0, 0.6, 3.0)
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.6
	return m


func _forme(parent: Node3D, maillage: Mesh, materiau: Material, pos: Vector3, echelle := Vector3.ONE,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = maillage
	mi.material_override = materiau
	mi.position = pos
	mi.scale = echelle
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 20
	s.rings = 12
	return s


func _construire() -> void:
	for enfant in get_children():
		enfant.free()
	_trompe.clear()
	_pattes.clear()
	_squelette = null
	if ResourceLoader.exists(MAILLAGE):
		_construire_modele()
		_ajouter_collision()
		return
	var poil := _fourrure(Color(0.15, 0.1, 0.065))
	var poil_clair := _fourrure(Color(0.25, 0.17, 0.1))
	var ivoire := StandardMaterial3D.new()
	ivoire.albedo_color = Color(0.78, 0.72, 0.58)
	ivoire.roughness = 0.45
	var sombre := StandardMaterial3D.new()
	sombre.albedo_color = Color(0.05, 0.04, 0.03)
	var t := taille
	_corps = Node3D.new()
	_corps.position = Vector3(0, 2.3 * t, 0)
	_corps.scale = Vector3.ONE * t
	add_child(_corps)
	# Corps massif, bosse sur les épaules, dos qui descend vers l'arrière.
	_forme(_corps, _sphere(1.0), poil, Vector3(0, 0, 0.3), Vector3(1.25, 1.2, 1.9))
	_forme(_corps, _sphere(0.9), poil, Vector3(0, 0.55, -0.7), Vector3(1.2, 1.1, 1.1))
	# Longs poils qui pendent sous le ventre et sur les flancs.
	_forme(_corps, _sphere(1.0), poil_clair, Vector3(0, -0.45, 0.1), Vector3(1.3, 0.9, 1.9))
	# Tête haute avec son dôme.
	_tete = Node3D.new()
	_tete.position = Vector3(0, 0.6, -1.65)
	_corps.add_child(_tete)
	_forme(_tete, _sphere(0.7), poil, Vector3(0, 0.25, 0), Vector3(0.95, 1.2, 0.9))
	_forme(_tete, _sphere(0.3), poil, Vector3(0, 0.95, 0.1))
	_forme(_tete, _sphere(0.06), sombre, Vector3(-0.42, 0.25, -0.45))
	_forme(_tete, _sphere(0.06), sombre, Vector3(0.42, 0.25, -0.45))
	# Petites oreilles (contre le froid).
	_forme(_tete, _sphere(0.22), poil, Vector3(-0.62, 0.3, 0.15), Vector3(0.3, 1.0, 0.8))
	_forme(_tete, _sphere(0.22), poil, Vector3(0.62, 0.3, 0.15), Vector3(0.3, 1.0, 0.8))
	# Trompe : une chaîne de segments qui se balance.
	var parent := _tete
	var segment_pos := Vector3(0, -0.2, -0.55)
	for k in 7:
		var articulation := Node3D.new()
		articulation.position = segment_pos
		articulation.rotation.x = 0.18
		parent.add_child(articulation)
		var c := CylinderMesh.new()
		c.top_radius = 0.24 - k * 0.025
		c.bottom_radius = 0.22 - k * 0.025
		c.height = 0.38
		_forme(articulation, c, poil, Vector3(0, -0.18, 0))
		_trompe.append(articulation)
		parent = articulation
		segment_pos = Vector3(0, -0.36, 0)
	# Défenses : longues, recourbées vers l'intérieur.
	for cote in [-1.0, 1.0]:
		var precedent := Vector3(cote * 0.3, -0.3, -0.45)
		for k in 12:
			var u := (k + 1) / 12.0
			var point := Vector3(cote * (0.3 + sin(u * 2.2) * 0.75), -0.3 - sin(u * 1.8) * 0.9 + u * u * 1.4,
					-0.45 - sin(u * 2.0) * 1.7)
			var c := CylinderMesh.new()
			c.top_radius = 0.11 * (1.0 - u * 0.75)
			c.bottom_radius = 0.11 * (1.0 - (u - 1.0 / 12.0) * 0.75)
			c.height = precedent.distance_to(point) + 0.02
			c.radial_segments = 8
			var segment := _forme(_tete, c, ivoire, (precedent + point) * 0.5)
			segment.basis = Basis(Quaternion(Vector3.UP, (point - precedent).normalized()))
			precedent = point
	# Pattes en colonnes, couvertes de poils.
	var patte := CylinderMesh.new()
	patte.top_radius = 0.32
	patte.bottom_radius = 0.27
	patte.height = 1.9
	for pos in [Vector3(-0.55, -0.4, -0.9), Vector3(0.55, -0.4, -0.9), Vector3(-0.55, -0.4, 1.2), Vector3(0.55, -0.4, 1.2)]:
		var hanche := Node3D.new()
		hanche.position = pos
		_corps.add_child(hanche)
		_forme(hanche, patte, poil, Vector3(0, -0.85, 0))
		_forme(hanche, _sphere(0.33), poil_clair, Vector3(0, -1.75, 0), Vector3(1.05, 0.35, 1.05))
		_pattes.append(hanche)
	_queue = Node3D.new()
	_queue.position = Vector3(0, 0.3, 2.1)
	_corps.add_child(_queue)
	var q := CylinderMesh.new()
	q.top_radius = 0.06
	q.bottom_radius = 0.03
	q.height = 0.6
	_forme(_queue, q, poil, Vector3(0, -0.3, 0))
	_ajouter_collision()


func _ajouter_collision() -> void:
	var t := taille
	# On ne peut pas traverser un mammouth.
	var corps := AnimatableBody3D.new()
	corps.sync_to_physics = false
	var forme := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 1.3 * t
	capsule.height = 4.6 * t
	forme.shape = capsule
	forme.rotation.x = PI / 2
	forme.position = Vector3(0, 2.4 * t, 0)
	corps.add_child(forme)
	add_child(corps)


func _materiaux() -> Array:
	if _materiaux_modele.is_empty():
		var bruit := NoiseTexture2D.new()
		bruit.width = 256
		bruit.height = 256
		bruit.seamless = true
		var n := FastNoiseLite.new()
		n.frequency = 0.03
		n.fractal_octaves = 4
		bruit.noise = n
		var corps := ShaderMaterial.new()
		corps.shader = SHADER_PELAGE
		corps.set_shader_parameter("bruit", bruit)
		var meches := corps.duplicate() as ShaderMaterial
		meches.set_shader_parameter("meches", true)
		var ivoire := StandardMaterial3D.new()
		ivoire.vertex_color_use_as_albedo = true
		ivoire.roughness = 0.55
		_materiaux_modele = [corps, ivoire, meches]
	return _materiaux_modele


func _construire_modele() -> void:
	var maillage := load(MAILLAGE) as ArrayMesh
	_os = maillage.get_meta("os", [])
	_squelette = Skeleton3D.new()
	_squelette.name = "Squelette"
	_squelette.scale = Vector3.ONE * taille
	add_child(_squelette)
	var skin := Skin.new()
	for i in _os.size():
		var o: Dictionary = _os[i]
		_squelette.add_bone(o.nom)
		_squelette.set_bone_parent(i, o.parent)
		var origine: Vector3 = o.position
		if int(o.parent) >= 0:
			origine -= (_os[o.parent] as Dictionary).position
		_squelette.set_bone_rest(i, Transform3D(Basis(), origine))
		skin.add_bind(i, Transform3D(Basis(), o.position).affine_inverse())
	_squelette.reset_bone_poses()
	var mi := MeshInstance3D.new()
	mi.name = "Mammouth"
	mi.mesh = maillage
	mi.skin = skin
	var mats := _materiaux()
	for i in mini(maillage.get_surface_count(), mats.size()):
		mi.set_surface_override_material(i, mats[i])
	_squelette.add_child(mi)
	mi.skeleton = NodePath("..")


func _pose_os(nom: String, rotation_os: Quaternion, decalage := Vector3.ZERO) -> void:
	var i := _squelette.find_bone(nom)
	if i < 0:
		return
	_squelette.set_bone_pose_rotation(i, rotation_os)
	if decalage != Vector3.ZERO:
		_squelette.set_bone_pose_position(i, _squelette.get_bone_rest(i).origin + decalage)


func _animer_squelette(allure: float) -> void:
	var pas := sin(_phase) * 0.3 * allure
	var phases := [pas, -pas, -pas, pas]
	for k in 4:
		_pose_os("patte%d" % k, Quaternion(Vector3.RIGHT, phases[k]))
	var rebond := absf(sin(_phase)) * 0.05 * allure
	_pose_os("corps", Quaternion(Vector3.FORWARD, sin(_phase) * 0.025 * allure), Vector3(0, rebond, 0))
	# À l'arrêt, il broute : la tête s'abaisse et la trompe fouille l'herbe.
	var broute := 1.0 - allure
	_pose_os("tete", Quaternion(Vector3.RIGHT, -broute * 0.12 + sin(_temps * 0.5) * 0.03))
	for k in 5:
		var balance := sin(_temps * 0.9 - k * 0.6) * (0.06 + broute * 0.05)
		var lateral := sin(_temps * 0.6 - k * 0.4) * 0.05
		_pose_os("trompe%d" % k, Quaternion(Vector3.RIGHT, balance - broute * 0.06 * k * 0.3)
				* Quaternion(Vector3.FORWARD, lateral))
	_pose_os("queue", Quaternion(Vector3.FORWARD, sin(_temps * 2.0) * 0.3))


func _hauteur_sol(x: float, z: float) -> float:
	var ile := get_tree().get_first_node_in_group("ile") if is_inside_tree() else null
	return ile.hauteur(x, z) if ile != null else global_position.y


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or (_corps == null and _squelette == null):
		return
	_temps += delta
	if panique > 0.0:
		panique -= delta
		_vitesse = move_toward(_vitesse, 4.0 * taille, delta * 2.0)
		if panique <= 0.0:
			arreter_migration()
	elif not _chemin.is_empty():
		# Grande Migration : il marche d'un point au suivant sans s'arrêter.
		if Vector2(_but.x - global_position.x, _but.z - global_position.z).length() < 3.0:
			_chemin.remove_at(0)
			if _chemin.is_empty():
				centre = Vector2(global_position.x, global_position.z)
				rayon = 18.0
				_nouveau_but()
				_attente = _hasard.randf_range(2.0, 6.0)
			else:
				_but = Vector3(_chemin[0].x, 0, _chemin[0].y)
		_vitesse = move_toward(_vitesse, _vitesse_migration, delta * 0.6)
	# Choisir un nouveau coin d'herbe de temps en temps.
	elif _attente > 0.0:
		_attente -= delta
		_vitesse = move_toward(_vitesse, 0.0, delta)
	else:
		if Vector2(_but.x - global_position.x, _but.z - global_position.z).length() < 1.5:
			_nouveau_but()
			_attente = _hasard.randf_range(4.0, 14.0)
		_vitesse = move_toward(_vitesse, 1.1 * taille, delta * 0.5)
	if _vitesse > 0.01 and _but != Vector3.ZERO:
		var ecart := Vector3(_but.x - global_position.x, 0, _but.z - global_position.z)
		var voulu := atan2(-ecart.x, -ecart.z)
		rotation.y = lerp_angle(rotation.y, voulu, delta * (1.4 if panique > 0.0 or not _chemin.is_empty() else 0.6))
		var avant := -global_transform.basis.z
		global_position += Vector3(avant.x, 0, avant.z).normalized() * _vitesse * delta
	global_position.y = lerpf(global_position.y, _hauteur_sol(global_position.x, global_position.z) - 0.1, 0.2)
	# Démarche lourde, trompe qui se balance, queue qui bat.
	_phase += delta * (0.8 + _vitesse * 1.6)
	var allure := clampf(_vitesse / 1.1, 0.0, 1.0)
	if _squelette != null:
		_animer_squelette(allure)
		return
	var pas := sin(_phase) * 0.28 * allure
	_pattes[0].rotation.x = pas
	_pattes[1].rotation.x = -pas
	_pattes[2].rotation.x = -pas
	_pattes[3].rotation.x = pas
	_corps.position.y = 2.3 * taille + absf(sin(_phase)) * 0.06 * allure
	# À l'arrêt, il broute : la trompe descend vers l'herbe.
	var broute := 1.0 - allure
	for k in _trompe.size():
		_trompe[k].rotation.x = 0.12 + broute * 0.06 + sin(_temps * 0.9 + k * 0.5) * 0.05
		_trompe[k].rotation.z = sin(_temps * 0.6 + k * 0.4) * 0.04
	_tete.rotation.x = broute * 0.25 + sin(_temps * 0.5) * 0.03
	_queue.rotation.z = sin(_temps * 2.0) * 0.3
