class_name EffetsVisuels
extends RefCounted
## Effets visuels des compétences (projectiles, éclats, boucliers, soins, étourdissements…).
##
## Ils sont seulement décoratifs : les dégâts et les soins sont décidés par le serveur.
## Chaque fonction crée quelques formes simples qui s'animent puis disparaissent toutes seules.
## Rien n'est créé sur un serveur sans écran (--headless).


static func _actif(noeud: Node) -> bool:
	return noeud != null and noeud.is_inside_tree() and DisplayServer.get_name() != "headless" \
			and noeud.get_tree().current_scene != null


static func _matiere(couleur: Color, lumineux := true, transparent := true) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = couleur
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if lumineux:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = Color(couleur.r, couleur.g, couleur.b)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


static func _forme(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


## Petites étincelles qui jaillissent (impacts, soins…).
static func _etincelles(couleur: Color, nombre := 24, vitesse := 3.0, montee := 0.0, duree := 0.6) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = nombre
	p.lifetime = duree
	p.one_shot = true
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	p.direction = Vector3.UP
	p.spread = 180.0 if montee == 0.0 else 25.0
	p.gravity = Vector3(0, montee if montee != 0.0 else -6.0, 0)
	p.initial_velocity_min = vitesse * 0.5
	p.initial_velocity_max = vitesse
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var degrade := Gradient.new()
	degrade.set_color(0, Color(couleur.r, couleur.g, couleur.b, 1.0))
	degrade.set_color(1, Color(couleur.r, couleur.g, couleur.b, 0.0))
	p.color_ramp = degrade
	var grain := SphereMesh.new()
	grain.radius = 0.05
	grain.height = 0.1
	grain.radial_segments = 6
	grain.rings = 3
	var mat := _matiere(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	grain.material = mat
	p.mesh = grain
	p.emitting = true
	return p


static func _ajouter(parent: Node, enfant: Node3D, position_monde: Vector3, vie: float) -> void:
	var scene := parent.get_tree().current_scene
	scene.add_child(enfant)
	enfant.global_position = position_monde
	enfant.get_tree().create_timer(vie).timeout.connect(func():
		if is_instance_valid(enfant):
			enfant.queue_free())


# --- Projectiles ---------------------------------------------------------------

## Un projectile qui vole de « depart » jusqu'à la victime en « duree » secondes.
## style : "sagaie", "fleche", "poison" ou "eclat".
static func projectile(depuis: Node, depart: Vector3, victime: Node3D, hauteur_victime: float,
		duree: float, style: String) -> void:
	if not _actif(depuis) or victime == null:
		return
	var objet := Node3D.new()
	var arc := 1.5
	match style:
		"fleche", "poison":
			arc = 0.4
			var bois := CylinderMesh.new()
			bois.top_radius = 0.008
			bois.bottom_radius = 0.008
			bois.height = 0.8
			var tige := _forme(bois, _matiere(Color(0.55, 0.42, 0.28), false, false))
			tige.rotation.x = PI / 2
			objet.add_child(tige)
			var pointe_forme := CylinderMesh.new()
			pointe_forme.top_radius = 0.0
			pointe_forme.bottom_radius = 0.025
			pointe_forme.height = 0.08
			var couleur_pointe := Color(0.35, 0.95, 0.4) if style == "poison" else Color(0.75, 0.75, 0.8)
			var pointe := _forme(pointe_forme, _matiere(couleur_pointe, style == "poison", false))
			pointe.rotation.x = -PI / 2
			pointe.position.z = -0.44
			objet.add_child(pointe)
			if style == "poison":
				var trainee := _etincelles(Color(0.4, 1.0, 0.35), 20, 0.4, 0.0, 0.4)
				trainee.one_shot = false
				trainee.explosiveness = 0.0
				trainee.gravity = Vector3(0, -1, 0)
				objet.add_child(trainee)
		"eclat":
			arc = 0.2
			var boule := SphereMesh.new()
			boule.radius = 0.16
			boule.height = 0.32
			objet.add_child(_forme(boule, _matiere(Color(0.55, 0.85, 1.0, 0.9))))
			var trainee := _etincelles(Color(0.5, 0.8, 1.0), 30, 0.3, 0.0, 0.35)
			trainee.one_shot = false
			trainee.explosiveness = 0.0
			trainee.gravity = Vector3.ZERO
			objet.add_child(trainee)
			var lumiere := OmniLight3D.new()
			lumiere.light_color = Color(0.5, 0.8, 1.0)
			lumiere.light_energy = 1.5
			lumiere.omni_range = 4.0
			objet.add_child(lumiere)
		_:
			var forme := CylinderMesh.new()
			forme.top_radius = 0.015
			forme.bottom_radius = 0.025
			forme.height = 1.4
			var hampe := _forme(forme, _matiere(Color(0.45, 0.32, 0.2), false, false))
			hampe.rotation.x = PI / 2
			objet.add_child(hampe)
	depuis.get_tree().current_scene.add_child(objet)
	objet.global_position = depart
	var voler := func(t: float) -> void:
		if not is_instance_valid(victime) or not is_instance_valid(objet):
			return
		var arrivee := victime.global_position + Vector3.UP * hauteur_victime
		var p := depart.lerp(arrivee, t) + Vector3.UP * sin(t * PI) * arc
		var direction := p - objet.global_position
		objet.global_position = p
		if direction.length() > 0.001:
			objet.look_at(p + direction, Vector3.UP)
	var animation := objet.create_tween()
	animation.tween_method(voler, 0.0, 1.0, duree)
	animation.tween_callback(func():
		if is_instance_valid(victime):
			var couleur := Color(0.6, 0.85, 1.0) if style == "eclat" else Color(1.0, 0.85, 0.5)
			if style == "poison":
				couleur = Color(0.4, 1.0, 0.35)
			impact(objet, victime.global_position + Vector3.UP * hauteur_victime, couleur, 0.6)
		objet.queue_free())


# --- Éclats et ondes -------------------------------------------------------------

## Petite explosion de lumière à l'endroit d'un coup.
static func impact(depuis: Node, ou: Vector3, couleur: Color, taille := 1.0) -> void:
	if not _actif(depuis):
		return
	var racine := Node3D.new()
	var boule := SphereMesh.new()
	boule.radius = 0.5 * taille
	boule.height = 1.0 * taille
	var flash := _forme(boule, _matiere(Color(couleur.r, couleur.g, couleur.b, 0.7)))
	racine.add_child(flash)
	racine.add_child(_etincelles(couleur, 18, 4.0 * taille))
	_ajouter(depuis, racine, ou, 0.8)
	var t := flash.create_tween().set_parallel()
	t.tween_property(flash, "scale", Vector3.ONE * 1.8, 0.25)
	t.tween_property(flash.material_override, "albedo_color:a", 0.0, 0.25)


## Onde circulaire qui s'élargit au sol (Onde de choc, Frappe tournoyante, Repli…).
static func onde(depuis: Node, ou: Vector3, rayon: float, couleur: Color) -> void:
	if not _actif(depuis):
		return
	var tore := TorusMesh.new()
	tore.inner_radius = 0.85
	tore.outer_radius = 1.0
	tore.rings = 48
	var anneau := _forme(tore, _matiere(Color(couleur.r, couleur.g, couleur.b, 0.85)))
	anneau.scale = Vector3(0.3, 0.3, 0.3)
	var racine := Node3D.new()
	racine.add_child(anneau)
	var poussiere := _etincelles(couleur.lerp(Color(0.6, 0.55, 0.45), 0.5), 40, rayon * 1.2, 0.0, 0.7)
	poussiere.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	poussiere.emission_ring_axis = Vector3.UP
	poussiere.emission_ring_radius = 0.5
	poussiere.emission_ring_inner_radius = 0.3
	poussiere.emission_ring_height = 0.1
	poussiere.spread = 80.0
	poussiere.direction = Vector3(1, 0.3, 0)
	racine.add_child(poussiere)
	_ajouter(depuis, racine, ou + Vector3.UP * 0.15, 0.9)
	var t := anneau.create_tween().set_parallel()
	t.tween_property(anneau, "scale", Vector3(rayon, 1.0, rayon), 0.35).set_ease(Tween.EASE_OUT)
	t.tween_property(anneau.material_override, "albedo_color:a", 0.0, 0.5)


## Colonne de lumière douce qui monte (soins).
static func soin(depuis: Node, acteur: Node3D, couleur := Color(0.4, 1.0, 0.5)) -> void:
	if not _actif(depuis) or acteur == null:
		return
	var racine := Node3D.new()
	var monte := _etincelles(couleur, 30, 1.2, 3.0, 1.0)
	monte.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	monte.emission_ring_axis = Vector3.UP
	monte.emission_ring_radius = 0.6
	monte.emission_ring_inner_radius = 0.4
	monte.emission_ring_height = 0.1
	racine.add_child(monte)
	var cylindre := CylinderMesh.new()
	cylindre.top_radius = 0.6
	cylindre.bottom_radius = 0.7
	cylindre.height = 2.2
	cylindre.cap_top = false
	cylindre.cap_bottom = false
	var colonne := _forme(cylindre, _matiere(Color(couleur.r, couleur.g, couleur.b, 0.35)))
	colonne.position.y = 1.1
	racine.add_child(colonne)
	acteur.add_child(racine)
	var t := colonne.create_tween()
	t.tween_property(colonne.material_override, "albedo_color:a", 0.0, 0.9)
	t.tween_callback(racine.queue_free).set_delay(0.3)


# --- Effets qui suivent un personnage --------------------------------------------

## Bulle translucide autour d'un personnage (Mur de bouclier, protection…).
static func aura(depuis: Node, acteur: Node3D, couleur: Color, duree: float, rayon := 1.1) -> void:
	if not _actif(depuis) or acteur == null:
		return
	var boule := SphereMesh.new()
	boule.radius = rayon
	boule.height = rayon * 2.0
	var mat := _matiere(Color(couleur.r, couleur.g, couleur.b, 0.0))
	mat.rim_enabled = true
	mat.rim = 1.0
	var bulle := _forme(boule, mat)
	bulle.position.y = 1.0
	acteur.add_child(bulle)
	var t := bulle.create_tween()
	t.tween_property(mat, "albedo_color:a", 0.22, 0.2)
	t.tween_interval(maxf(0.0, duree - 0.6))
	t.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	t.tween_callback(bulle.queue_free)


## Petites étoiles qui tournent au-dessus de la tête (étourdi).
static func etoiles(depuis: Node, acteur: Node3D, hauteur: float, duree: float) -> void:
	if not _actif(depuis) or acteur == null:
		return
	var pivot := Node3D.new()
	pivot.position.y = hauteur
	for i in 4:
		var forme := SphereMesh.new()
		forme.radius = 0.07
		forme.height = 0.14
		var etoile := _forme(forme, _matiere(Color(1.0, 0.9, 0.3)))
		var a := TAU * i / 4.0
		etoile.position = Vector3(cos(a), 0, sin(a)) * 0.35
		pivot.add_child(etoile)
	acteur.add_child(pivot)
	var t := pivot.create_tween()
	t.tween_property(pivot, "rotation:y", TAU * duree * 1.2, duree)
	t.tween_callback(pivot.queue_free)


## Liens au sol autour des pattes (immobilisé par un piège).
static func liens(depuis: Node, acteur: Node3D, duree: float) -> void:
	if not _actif(depuis) or acteur == null:
		return
	var racine := Node3D.new()
	for i in 6:
		var forme := CylinderMesh.new()
		forme.top_radius = 0.02
		forme.bottom_radius = 0.04
		forme.height = 0.7
		var corde := _forme(forme, _matiere(Color(0.62, 0.5, 0.3), false, false))
		var a := TAU * i / 6.0
		corde.position = Vector3(cos(a), 0.25, sin(a)) * 0.55
		corde.rotation = Vector3(0.6 * sin(a), 0, -0.6 * cos(a))
		racine.add_child(corde)
	acteur.add_child(racine)
	acteur.get_tree().create_timer(duree).timeout.connect(func():
		if is_instance_valid(racine):
			racine.queue_free())


## Traînée de vitesse (Accélération) : des particules dorées qui suivent le personnage.
static func trainee(depuis: Node, acteur: Node3D, couleur: Color, duree: float) -> void:
	if not _actif(depuis) or acteur == null:
		return
	var p := _etincelles(couleur, 40, 0.3, 0.6, 0.8)
	p.one_shot = false
	p.explosiveness = 0.0
	p.local_coords = false
	p.emission_sphere_radius = 0.5
	p.position.y = 0.9
	acteur.add_child(p)
	acteur.get_tree().create_timer(duree).timeout.connect(func():
		if is_instance_valid(p):
			p.emitting = false
			p.get_tree().create_timer(1.0).timeout.connect(p.queue_free))
