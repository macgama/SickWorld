extends Node3D
## Bulle lente du Tisseur : une sphère de temps ralenti. Les ennemis dedans
## se déplacent et attaquent plus lentement tant qu'ils y restent.
##
## Comme le Feu des ancêtres : la vraie bulle tourne sur le serveur (lanceur renseigné),
## les joueurs reçoivent une copie seulement visuelle.

var lanceur: Combattant
var reglages: Dictionary

var _fin := 0.0
var _prochain_tic := 0.0
var _coque: MeshInstance3D
var _anneaux: Node3D


func _ready() -> void:
	_fin = Regles.maintenant() + float(reglages.get("duree", 6))
	if DisplayServer.get_name() != "headless":
		_construire()


func _process(delta: float) -> void:
	var t := Regles.maintenant()
	if _anneaux != null:
		_anneaux.rotate_y(delta * 0.6)
	if lanceur != null and is_instance_valid(lanceur) and t >= _prochain_tic:
		_prochain_tic = t + 0.25
		var effet := {"vitesse": float(reglages.get("vitesse", 0.4)), "cadence": float(reglages.get("cadence", 1.6))}
		for ennemi in Regles.hostiles_autour(lanceur, global_position, float(reglages.get("rayon", 6))):
			ennemi.ajouter_effet("bulle_lente", 0.6, effet, lanceur)
	if t >= _fin:
		_fin = INF
		lanceur = null
		if _coque == null:
			queue_free()
			return
		var fondu := create_tween()
		fondu.tween_property(self, "scale", Vector3.ONE * 0.05, 0.3)
		fondu.tween_callback(queue_free)


func _construire() -> void:
	var rayon := float(reglages.get("rayon", 6))
	_coque = MeshInstance3D.new()
	var boule := SphereMesh.new()
	boule.radius = rayon
	boule.height = rayon * 2.0
	boule.radial_segments = 48
	boule.rings = 24
	_coque.mesh = boule
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.45, 0.7, 1.0, 0.1)
	mat.rim_enabled = true
	mat.rim = 1.0
	_coque.material_override = mat
	_coque.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_coque.scale = Vector3.ONE * 0.05
	add_child(_coque)
	_coque.create_tween().tween_property(_coque, "scale", Vector3.ONE, 0.35).set_ease(Tween.EASE_OUT)

	# Des anneaux qui tournent doucement, comme les aiguilles d'une horloge.
	_anneaux = Node3D.new()
	_anneaux.position.y = 0.2
	add_child(_anneaux)
	var mat_anneau := StandardMaterial3D.new()
	mat_anneau.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_anneau.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_anneau.albedo_color = Color(0.6, 0.85, 1.0, 0.55)
	for i in 3:
		var anneau := MeshInstance3D.new()
		var tore := TorusMesh.new()
		var r := rayon * (0.35 + 0.3 * i)
		tore.inner_radius = r - 0.06
		tore.outer_radius = r
		tore.rings = 48
		tore.ring_segments = 4
		anneau.mesh = tore
		anneau.material_override = mat_anneau
		anneau.scale = Vector3(1, 0.1, 1)
		anneau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_anneaux.add_child(anneau)
	# Des grains de lumière suspendus, presque immobiles.
	var grains := CPUParticles3D.new()
	grains.amount = 60
	grains.lifetime = 3.0
	grains.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	grains.emission_sphere_radius = rayon * 0.9
	grains.gravity = Vector3(0, 0.05, 0)
	grains.initial_velocity_min = 0.0
	grains.initial_velocity_max = 0.1
	grains.scale_amount_min = 0.5
	grains.scale_amount_max = 1.0
	var grain := SphereMesh.new()
	grain.radius = 0.04
	grain.height = 0.08
	grain.radial_segments = 6
	grain.rings = 3
	var mat_grain := StandardMaterial3D.new()
	mat_grain.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_grain.albedo_color = Color(0.75, 0.9, 1.0)
	mat_grain.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	grain.material = mat_grain
	grains.mesh = grain
	add_child(grains)
	var lumiere := OmniLight3D.new()
	lumiere.light_color = Color(0.5, 0.75, 1.0)
	lumiere.light_energy = 1.2
	lumiere.omni_range = rayon * 1.5
	lumiere.position.y = 1.5
	add_child(lumiere)
