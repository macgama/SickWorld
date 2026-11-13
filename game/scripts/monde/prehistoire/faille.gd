@tool
extends "res://scripts/monde/prehistoire/objet_quete.gd"
## Faille temporelle : une déchirure violette dans l'air, entourée d'éclats qui
## flottent. Les fracturés en sortent. Un agent de la Vigie peut la refermer
## (action de quête, en restant quelques secondes devant sans être interrompu).

const SHADER_FAILLE := preload("res://shaders/prehistoire_faille.gdshader")
const VIOLET := Color(0.62, 0.25, 1.0)

## Vrai quand la faille a été refermée.
var fermee := false
var _dechirures: Array[MeshInstance3D] = []
var _eclats: Array[MeshInstance3D] = []
var _lumiere: OmniLight3D
var _ouverture := 1.0
var _fermeture_animee := false
var _materiau: ShaderMaterial


func _init() -> void:
	invite = "[F] Refermer la faille"
	portee = 4.5


func _construire() -> void:
	super._construire()
	_etiquette.position.y = 1.6
	_halo.visible = false
	_dechirures.clear()
	_eclats.clear()
	_materiau = ShaderMaterial.new()
	_materiau.shader = SHADER_FAILLE
	var bruit := NoiseTexture2D.new()
	bruit.seamless = true
	var b := FastNoiseLite.new()
	b.frequency = 0.02
	bruit.noise = b
	_materiau.set_shader_parameter("bruit", bruit)
	# Deux plans croisés pour que la déchirure se voie sous tous les angles.
	for angle in [0.0, PI / 2]:
		var plan := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(2.6, 4.6)
		plan.mesh = q
		plan.material_override = _materiau
		plan.position.y = 2.6
		plan.rotation.y = angle
		plan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visuel.add_child(plan)
		_dechirures.append(plan)
	# Éclats de cristal violet qui flottent autour.
	var cristal := StandardMaterial3D.new()
	cristal.albedo_color = Color(0.35, 0.12, 0.6)
	cristal.emission_enabled = true
	cristal.emission = VIOLET
	cristal.emission_energy_multiplier = 2.5
	cristal.roughness = 0.1
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 42
	for k in 14:
		var eclat := MeshInstance3D.new()
		var prisme := PrismMesh.new()
		prisme.size = Vector3(0.12, 0.35, 0.12) * hasard.randf_range(0.6, 1.6)
		eclat.mesh = prisme
		eclat.material_override = cristal
		var a := TAU * k / 14.0
		eclat.position = Vector3(cos(a) * hasard.randf_range(1.0, 2.2), hasard.randf_range(0.6, 4.2),
				sin(a) * hasard.randf_range(1.0, 2.2))
		eclat.rotation = Vector3(hasard.randf() * TAU, hasard.randf() * TAU, hasard.randf() * TAU)
		eclat.set_meta("phase", hasard.randf() * TAU)
		eclat.set_meta("base", eclat.position)
		_visuel.add_child(eclat)
		_eclats.append(eclat)
	# Cristaux plantés dans le sol (ils restent après la fermeture).
	for k in 7:
		var pointe := MeshInstance3D.new()
		var p := PrismMesh.new()
		p.size = Vector3(0.25, hasard.randf_range(0.5, 1.3), 0.25)
		pointe.mesh = p
		pointe.material_override = cristal
		var a := hasard.randf() * TAU
		pointe.position = Vector3(cos(a), 0.2, sin(a)) * hasard.randf_range(0.8, 2.0)
		pointe.rotation = Vector3(hasard.randf_range(-0.5, 0.5), hasard.randf() * TAU, hasard.randf_range(-0.5, 0.5))
		add_child(pointe)
	_lumiere = OmniLight3D.new()
	_lumiere.light_color = VIOLET
	_lumiere.light_energy = 3.0
	_lumiere.omni_range = 14.0
	_lumiere.shadow_enabled = true
	_lumiere.position = Vector3(0, 2.6, 0)
	add_child(_lumiere)
	_appliquer_ouverture()


func _process(delta: float) -> void:
	super._process(delta)
	if _fermeture_animee:
		_ouverture = move_toward(_ouverture, 0.0, delta * 0.6)
		_appliquer_ouverture()
		if _ouverture <= 0.0:
			_fermeture_animee = false
	if fermee and _ouverture <= 0.0:
		return
	for eclat in _eclats:
		var phase: float = eclat.get_meta("phase")
		var base: Vector3 = eclat.get_meta("base")
		eclat.position = base * lerpf(0.2, 1.0, _ouverture) + Vector3(0, sin(_temps * 1.3 + phase) * 0.25, 0)
		eclat.rotate_y(delta * 0.8)
	if _lumiere != null:
		_lumiere.light_energy = (2.6 + sin(_temps * 13.0) * 0.4 + sin(_temps * 31.0) * 0.3) * _ouverture


func _appliquer_ouverture() -> void:
	if _materiau != null:
		_materiau.set_shader_parameter("ouverture", _ouverture)
	for eclat in _eclats:
		eclat.visible = _ouverture > 0.05
	for plan in _dechirures:
		plan.visible = _ouverture > 0.01
	if _lumiere != null:
		_lumiere.visible = _ouverture > 0.01


## Referme la faille (avec une animation, ou tout de suite au chargement d'une partie).
func fermer(anime := true) -> void:
	fermee = true
	actif = false
	if anime:
		_fermeture_animee = true
	else:
		_ouverture = 0.0
		_appliquer_ouverture()


func cacher() -> void:
	fermer(true)
