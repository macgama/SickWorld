class_name ZoneDeFeu
extends Node3D
## Feu des ancêtres : brûle les ennemis et soigne les alliés autour, pendant quelques secondes.

var lanceur: Combattant
var reglages: Dictionary

var _fin := 0.0
var _prochain_tic := 0.0
var _lumiere: OmniLight3D


func _ready() -> void:
	var rayon := float(reglages.get("rayon", 4))
	_fin = Regles.maintenant() + float(reglages.get("duree", 8))
	_prochain_tic = Regles.maintenant() + 0.5

	var disque := MeshInstance3D.new()
	var forme := CylinderMesh.new()
	forme.top_radius = rayon
	forme.bottom_radius = rayon
	forme.height = 0.05
	disque.mesh = forme
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.45, 0.1, 0.22)
	disque.material_override = mat
	disque.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disque.position.y = 0.1
	add_child(disque)

	var flammes := CPUParticles3D.new()
	flammes.amount = 40
	flammes.lifetime = 0.9
	flammes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flammes.emission_sphere_radius = 0.3
	flammes.direction = Vector3.UP
	flammes.spread = 15.0
	flammes.gravity = Vector3(0, 2.5, 0)
	flammes.initial_velocity_min = 0.5
	flammes.initial_velocity_max = 1.5
	flammes.scale_amount_min = 0.15
	flammes.scale_amount_max = 0.35
	var degrade := Gradient.new()
	degrade.set_color(0, Color(1.0, 0.85, 0.3, 1))
	degrade.set_color(1, Color(0.8, 0.15, 0.0, 0))
	flammes.color_ramp = degrade
	var particule := SphereMesh.new()
	particule.radius = 0.2
	particule.height = 0.4
	var mat_flamme := StandardMaterial3D.new()
	mat_flamme.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_flamme.vertex_color_use_as_albedo = true
	mat_flamme.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_flamme.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	particule.material = mat_flamme
	flammes.mesh = particule
	flammes.position.y = 0.2
	add_child(flammes)

	_lumiere = OmniLight3D.new()
	_lumiere.light_color = Color(1, 0.55, 0.2)
	_lumiere.omni_range = rayon * 2.0
	_lumiere.position.y = 1.0
	add_child(_lumiere)


func _process(_delta: float) -> void:
	var t := Regles.maintenant()
	_lumiere.light_energy = 2.0 + sin(t * 17.0) * 0.4 + sin(t * 7.0) * 0.3
	if lanceur != null and is_instance_valid(lanceur) and t >= _prochain_tic:
		_prochain_tic = t + 1.0
		var rayon := float(reglages.get("rayon", 4))
		for ennemi in Regles.hostiles_autour(lanceur, global_position, rayon):
			Regles.infliger(lanceur, ennemi, float(reglages.get("degats_par_seconde", 5)), "periodique")
		for allie in Regles.allies_autour(lanceur, global_position, rayon):
			if allie.pv < allie.pv_max:
				Regles.soigner(lanceur, allie, float(reglages.get("soin_par_seconde", 5)))
	if t >= _fin:
		queue_free()
