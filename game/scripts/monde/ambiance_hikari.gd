extends Node3D
## Ambiance de Hikari Bay : pluie qui suit la caméra (arrêtée par les toits et
## les auvents), éclaboussures, éclairs lointains et finition « cinéma » de
## l'image. Créée par HikariBay.reconstruire() ; réglée par la qualité
## graphique (autoload QualiteGraphique, touche F10).

const SHADER_PLUIE := preload("res://shaders/pluie.gdshader")
const SHADER_POST := preload("res://shaders/post_traitement.gdshader")

## Gouttes en même temps (au niveau de qualité le plus haut ; réduit en dessous).
@export var gouttes := 14000
## Des éclairs illuminent les nuages de temps en temps.
@export var eclairs := true
## Secondes entre deux éclairs (minimum, maximum).
@export var intervalle_eclairs := Vector2(18.0, 55.0)

var environnement: WorldEnvironment
var lune: DirectionalLight3D
var _pluie: GPUParticles3D
var _eclaboussures: GPUParticles3D
var _collision: GPUParticlesCollisionHeightField3D
var _post: CanvasLayer
var _prochain_eclair := 8.0
var _eclair_t := -1.0
var _energie_lune := 0.0
var _niveau := 2
var _hasard := RandomNumberGenerator.new()
var _projecteurs: Array[SpotLight3D] = []
var _sondes: Array[ReflectionProbe] = []

## Projecteurs qui dessinent des flaques de lumière sur la place
## [position, point visé, couleur, énergie].
const PROJECTEURS := [
	[Vector3(-13, 11, -10), Vector3(-9, 0, -6), Color(1.0, 0.86, 0.7), 35.0],
	[Vector3(13, 11, -10), Vector3(9, 0, -6), Color(1.0, 0.86, 0.7), 35.0],
	[Vector3(0, 12, 16), Vector3(0, 3, 2), Color(0.95, 0.85, 1.0), 40.0],
	[Vector3(-15, 10, 18), Vector3(-10, 0, 12), Color(1.0, 0.82, 0.62), 30.0],
	[Vector3(15, 10, 18), Vector3(10, 0, 12), Color(1.0, 0.82, 0.62), 30.0],
]
## Sondes de reflets (le sol mouillé et les vitres reflètent les néons, même
## hors de l'écran) : [centre, taille].
const SONDES := [
	[Vector3(0, 10, 0), Vector3(132, 36, 132)],
	[Vector3(0, 10, 52), Vector3(16, 36, 46)],
]


func _init() -> void:
	name = "Ambiance"
	add_to_group("qualite")


func _ready() -> void:
	_hasard.randomize()
	if lune != null:
		_energie_lune = lune.light_energy
	_construire_pluie()
	_construire_eclairage()
	if not Engine.is_editor_hint():
		_construire_post()
		var qualite := get_node_or_null("/root/QualiteGraphique")
		appliquer_qualite(qualite.niveau if qualite != null else 2)


# --- Éclairage de la place et reflets ------------------------------------

func _construire_eclairage() -> void:
	for p in PROJECTEURS:
		var l := SpotLight3D.new()
		add_child(l)
		l.position = p[0]
		l.look_at_from_position(p[0], p[1], Vector3.UP)
		l.light_color = p[2]
		l.light_energy = p[3]
		l.spot_range = 26.0
		l.spot_angle = 38.0
		l.spot_angle_attenuation = 1.6
		l.light_volumetric_fog_energy = 1.5
		_projecteurs.append(l)
	for s in SONDES:
		var sonde := ReflectionProbe.new()
		sonde.position = s[0]
		sonde.size = s[1]
		sonde.box_projection = true
		sonde.update_mode = ReflectionProbe.UPDATE_ONCE
		sonde.max_distance = 400.0
		sonde.mesh_lod_threshold = 4.0
		add_child(sonde)
		_sondes.append(sonde)


# --- Pluie ---------------------------------------------------------------

func _construire_pluie() -> void:
	_pluie = GPUParticles3D.new()
	_pluie.name = "Pluie"
	_pluie.amount = gouttes
	_pluie.lifetime = 1.1
	_pluie.preprocess = 1.2
	_pluie.local_coords = false
	_pluie.fixed_fps = 0
	_pluie.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pluie.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 60, 80))
	_pluie.collision_base_size = 0.05
	var p := ParticleProcessMaterial.new()
	p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(24, 0.5, 24)
	p.direction = Vector3(0.12, -1, 0.05)
	p.spread = 1.5
	p.initial_velocity_min = 19.0
	p.initial_velocity_max = 23.0
	p.gravity = Vector3(0, -9.8, 0)
	p.particle_flag_align_y = true
	p.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	p.collision_use_scale = false
	_pluie.process_material = p
	var quad := QuadMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_PLUIE
	quad.material = mat
	_pluie.draw_pass_1 = quad
	add_child(_pluie)
	# Éclaboussures au sol, à l'endroit où les gouttes touchent quelque chose.
	_eclaboussures = GPUParticles3D.new()
	_eclaboussures.name = "Eclaboussures"
	_eclaboussures.amount = 3000
	_eclaboussures.lifetime = 0.25
	_eclaboussures.local_coords = false
	_eclaboussures.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_eclaboussures.visibility_aabb = _pluie.visibility_aabb
	var pe := ParticleProcessMaterial.new()
	pe.direction = Vector3(0, 1, 0)
	pe.spread = 40.0
	pe.initial_velocity_min = 0.8
	pe.initial_velocity_max = 1.6
	pe.gravity = Vector3(0, -9.8, 0)
	pe.scale_min = 0.6
	pe.scale_max = 1.2
	_eclaboussures.process_material = pe
	var goutte := QuadMesh.new()
	goutte.size = Vector2(0.035, 0.035)
	var mg := StandardMaterial3D.new()
	mg.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mg.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mg.albedo_color = Color(0.6, 0.65, 0.75, 0.22)
	goutte.material = mg
	_eclaboussures.draw_pass_1 = goutte
	add_child(_eclaboussures)
	_eclaboussures.emitting = false
	# Les toits, auvents et le métro arrêtent la pluie (relevé de hauteur autour de la caméra).
	_collision = GPUParticlesCollisionHeightField3D.new()
	_collision.name = "AbriPluie"
	_collision.size = Vector3(56, 80, 56)
	_collision.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_512
	_collision.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
	_collision.follow_camera_enabled = true
	add_child(_collision)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var camera := get_viewport().get_camera_3d()
	if camera != null and _pluie != null:
		var c := camera.global_position
		# Pas de pluie sous terre (station Asahi, QG de la Vigie).
		var dehors := c.y > -1.5
		_pluie.visible = dehors and gouttes > 0
		_eclaboussures.visible = _pluie.visible and _niveau >= 2
		# La pluie naît au-dessus de la caméra, un peu devant elle.
		var devant := -camera.global_transform.basis.z
		devant.y = 0.0
		_pluie.global_position = c + devant.normalized() * 8.0 + Vector3(0, 18, 0)
		_collision.global_position = Vector3(c.x, 30.0, c.z)
	_animer_eclairs(delta)


# --- Éclairs ---------------------------------------------------------------

func _animer_eclairs(delta: float) -> void:
	if not eclairs or environnement == null:
		return
	var ciel := environnement.environment.sky.sky_material as ShaderMaterial if environnement.environment.sky != null else null
	if ciel == null:
		return
	if _eclair_t < 0.0:
		_prochain_eclair -= delta
		if _prochain_eclair <= 0.0:
			_eclair_t = 0.0
			_prochain_eclair = _hasard.randf_range(intervalle_eclairs.x, intervalle_eclairs.y)
			var angle := _hasard.randf_range(-PI, 0.0)
			ciel.set_shader_parameter("direction_eclair", Vector2(cos(angle), sin(angle)))
		return
	# Un éclair = deux ou trois flashs rapides puis une lueur qui s'éteint.
	_eclair_t += delta
	var t := _eclair_t
	var force := 0.0
	force = maxf(force, _flash(t, 0.0, 0.07))
	force = maxf(force, _flash(t, 0.16, 0.06) * 0.6)
	force = maxf(force, _flash(t, 0.3, 0.25))
	ciel.set_shader_parameter("eclair", force * 1.4)
	if lune != null:
		lune.light_energy = _energie_lune + force * 1.6
	if t > 0.8:
		_eclair_t = -1.0
		ciel.set_shader_parameter("eclair", 0.0)
		if lune != null:
			lune.light_energy = _energie_lune


func _flash(t: float, debut: float, duree: float) -> float:
	if t < debut:
		return 0.0
	var x := (t - debut) / duree
	return clampf(1.0 - x, 0.0, 1.0) * clampf(x * 6.0, 0.0, 1.0)


# --- Post-traitement ---------------------------------------------------------

func _construire_post() -> void:
	_post = CanvasLayer.new()
	_post.name = "PostTraitement"
	# Sous l'interface (barre de compétences, dialogues), au-dessus de la 3D.
	_post.layer = -1
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = SHADER_POST
	rect.material = m
	_post.add_child(rect)
	add_child(_post)


## Appelé par QualiteGraphique (0 = bas, 1 = moyen, 2 = haut, 3 = ultra).
func appliquer_qualite(niveau: int) -> void:
	_niveau = niveau
	if _pluie != null:
		var parts := [0.2, 0.45, 0.7, 1.0]
		_pluie.amount = maxi(500, int(gouttes * parts[niveau]))
		# Les toits arrêtent la pluie à partir du niveau moyen.
		_collision.visible = niveau >= 1
		_eclaboussures.visible = niveau >= 2
		var p := _pluie.process_material as ParticleProcessMaterial
		if niveau >= 2:
			p.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_AT_COLLISION
			p.sub_emitter_amount_at_collision = 1
			_pluie.sub_emitter = _pluie.get_path_to(_eclaboussures)
		else:
			p.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_DISABLED
			_pluie.sub_emitter = NodePath()
	if _post != null:
		_post.visible = niveau >= 1
	for l in _projecteurs:
		l.visible = niveau >= 1
		l.shadow_enabled = niveau >= 2
	for sonde in _sondes:
		sonde.visible = niveau >= 1
