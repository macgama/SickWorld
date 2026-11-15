extends Node3D
## La vie de Hikari Bay la nuit (vie ambiante du hub) : bateaux qui croisent dans la
## baie, le grand pont suspendu au large et son flot de phares, avions et hélicoptères
## qui clignotent dans le ciel, distributeurs de boissons, vélos garés, plots…
## Décrit dans data/vie_ambiante.json, section « hikari_bay » (clés bateaux, pont,
## avions, objets). Tout est sans collision sauf les distributeurs.

const NIVEAU_EAU := -1.6

var hub: Node3D
var fiche: Dictionary = {}

var _bateaux: Array[Dictionary] = []
var _avions: Array[Dictionary] = []
var _flots: Array[Dictionary] = []
var _temps := 0.0
var _materiaux := {}


func _ready() -> void:
	add_to_group("vie_ambiante")
	for b: Dictionary in fiche.get("bateaux", []):
		_creer_bateau(b)
	if fiche.has("pont"):
		_creer_pont(fiche["pont"])
	for a: Dictionary in fiche.get("avions", []):
		_creer_avion(a)
	for o: Dictionary in fiche.get("objets", []):
		_creer_objet(o)


func _process(delta: float) -> void:
	_temps += delta
	for b in _bateaux:
		_avancer_bateau(b, delta)
	for a in _avions:
		_avancer_avion(a, delta)
	for f in _flots:
		_avancer_flot(f, delta)


# --- Matériaux ---------------------------------------------------------------------

func _mat(nom: String) -> Material:
	if _materiaux.has(nom):
		return _materiaux[nom]
	var m: Material = null
	if hub != null and hub.has_method("_mat") and nom in ["metal", "beton", "blanc"]:
		m = hub._mat(nom)
	if m == null:
		var s := StandardMaterial3D.new()
		match nom:
			"coque_blanche":
				s.albedo_color = Color(0.86, 0.87, 0.88)
				s.roughness = 0.45
			"coque_sombre":
				s.albedo_color = Color(0.12, 0.14, 0.18)
				s.roughness = 0.5
			"coque_rouge":
				s.albedo_color = Color(0.45, 0.08, 0.07)
				s.roughness = 0.55
			"pont_bateau":
				s.albedo_color = Color(0.32, 0.3, 0.28)
				s.roughness = 0.8
			"acier":
				s.albedo_color = Color(0.32, 0.34, 0.37)
				s.metallic = 0.7
				s.roughness = 0.45
			"plastique":
				s.albedo_color = Color(0.9, 0.9, 0.9)
				s.roughness = 0.4
			_:
				s.albedo_color = Color(0.5, 0.5, 0.5)
		m = s
	_materiaux[nom] = m
	return m


func _lumineux(couleur: Color, energie := 4.0) -> StandardMaterial3D:
	var cle := "l_%s_%f" % [couleur.to_html(), energie]
	if _materiaux.has(cle):
		return _materiaux[cle]
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.emission_enabled = true
	m.emission = couleur
	m.emission_energy_multiplier = energie
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materiaux[cle] = m
	return m


func _boite(parent: Node3D, taille: Vector3, p: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.material_override = m
	mi.position = p
	parent.add_child(mi)
	return mi


func _sphere(parent: Node3D, rayon: float, p: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = rayon
	s.height = rayon * 2.0
	s.radial_segments = 8
	s.rings = 4
	mi.mesh = s
	mi.material_override = m
	mi.position = p
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _cylindre(parent: Node3D, r1: float, r2: float, h: float, p: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r1
	c.bottom_radius = r2
	c.height = h
	c.radial_segments = 10
	mi.mesh = c
	mi.material_override = m
	mi.position = p
	parent.add_child(mi)
	return mi


# --- Bateaux -----------------------------------------------------------------------

## Coque effilée à l'avant (-Z), arrière carré. longueur, largeur, hauteur en mètres.
func _maillage_coque(l: float, w: float, h: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var demi := w * 0.5
	# Points du pont (haut) et de la quille (bas), de l'arrière (z+) vers la proue (z-).
	var haut := [Vector3(-demi, h, l * 0.5), Vector3(demi, h, l * 0.5), Vector3(demi, h, -l * 0.2),
			Vector3(0, h + 0.15 * h, -l * 0.5), Vector3(-demi, h, -l * 0.2)]
	var bas := [Vector3(-demi * 0.8, 0, l * 0.45), Vector3(demi * 0.8, 0, l * 0.45), Vector3(demi * 0.7, 0, -l * 0.2),
			Vector3(0, h * 0.35, -l * 0.48), Vector3(-demi * 0.7, 0, -l * 0.2)]
	for i in 5:
		var j := (i + 1) % 5
		st.add_vertex(haut[i])
		st.add_vertex(bas[j])
		st.add_vertex(bas[i])
		st.add_vertex(haut[i])
		st.add_vertex(haut[j])
		st.add_vertex(bas[j])
	# Pont (dessus).
	st.add_vertex(haut[0])
	st.add_vertex(haut[2])
	st.add_vertex(haut[1])
	st.add_vertex(haut[0])
	st.add_vertex(haut[4])
	st.add_vertex(haut[2])
	st.add_vertex(haut[4])
	st.add_vertex(haut[3])
	st.add_vertex(haut[2])
	st.generate_normals()
	return st.commit()


## sorte : ferry, vedette, peche, cargo, voilier. chemin [[x, z], …] parcouru en boucle.
func _creer_bateau(f: Dictionary) -> void:
	var sorte := String(f.get("sorte", "vedette"))
	var racine := Node3D.new()
	racine.name = "Bateau_%s_%d" % [sorte, _bateaux.size()]
	add_child(racine)
	var corps := Node3D.new()
	racine.add_child(corps)
	var fenetres := _lumineux(Color(1.0, 0.86, 0.62), 3.5)
	var rouge := _lumineux(Color(1.0, 0.12, 0.1), 8.0)
	var vert := _lumineux(Color(0.15, 1.0, 0.35), 8.0)
	var blanc := _lumineux(Color(1, 1, 0.95), 8.0)
	var l := 12.0
	var w := 4.0
	var h := 1.8
	match sorte:
		"ferry":
			l = 52.0
			w = 13.0
			h = 4.5
		"cargo":
			l = 140.0
			w = 22.0
			h = 9.0
		"peche":
			l = 15.0
			w = 4.6
			h = 2.0
		"voilier":
			l = 11.0
			w = 3.6
			h = 1.4
		_:
			l = 13.0
			w = 3.8
			h = 1.6
	var coque := MeshInstance3D.new()
	coque.mesh = _maillage_coque(l, w, h)
	coque.material_override = _mat({"cargo": "coque_rouge", "peche": "coque_sombre"}.get(sorte, "coque_blanche"))
	corps.add_child(coque)
	# Ligne de flottaison sombre.
	_boite(corps, Vector3(w * 0.9, 0.25, l * 0.6), Vector3(0, 0.35, l * 0.12), _mat("coque_sombre"))
	match sorte:
		"ferry":
			for etage in 2:
				var y := h + 1.4 + etage * 2.6
				var long := l * (0.66 - etage * 0.14)
				_boite(corps, Vector3(w * 0.86, 2.6, long), Vector3(0, y, l * 0.06), _mat("coque_blanche"))
				# Bandeaux de fenêtres allumées des deux côtés.
				for cote: float in [-1.0, 1.0]:
					_boite(corps, Vector3(0.05, 0.9, long * 0.92), Vector3(cote * w * 0.435, y + 0.2, l * 0.06), fenetres)
			_boite(corps, Vector3(w * 0.5, 2.0, 5.0), Vector3(0, h + 6.6, -l * 0.12), _mat("coque_blanche"))
			_boite(corps, Vector3(w * 0.5, 0.7, 0.05), Vector3(0, h + 6.8, -l * 0.12 - 2.52), fenetres)
			_cylindre(corps, 0.9, 1.1, 4.0, Vector3(0, h + 8.0, l * 0.18), _mat("coque_sombre"))
		"cargo":
			_boite(corps, Vector3(w * 0.9, 12.0, 14.0), Vector3(0, h + 6.0, l * 0.38), _mat("coque_blanche"))
			_boite(corps, Vector3(w * 0.9, 1.0, 0.05), Vector3(0, h + 10.5, l * 0.38 - 7.03), fenetres)
			var couleurs := [Color(0.55, 0.12, 0.1), Color(0.1, 0.25, 0.5), Color(0.6, 0.45, 0.1), Color(0.2, 0.4, 0.25), Color(0.4, 0.4, 0.42)]
			for i in 14:
				for k in 3:
					var c := StandardMaterial3D.new()
					c.albedo_color = couleurs[(i * 3 + k * 7) % couleurs.size()]
					c.roughness = 0.7
					_boite(corps, Vector3(w * 0.85, 2.5, 6.0), Vector3(0, h + 1.3 + k * 2.6, -l * 0.38 + i * 6.3), c)
			_lumineux_point(corps, Vector3(0, h + 16.0, l * 0.38), blanc, 0.5)
		"peche":
			_boite(corps, Vector3(w * 0.6, 2.0, 3.6), Vector3(0, h + 1.0, l * 0.1), _mat("coque_blanche"))
			_boite(corps, Vector3(w * 0.61, 0.6, 3.0), Vector3(0, h + 1.4, l * 0.1), fenetres)
			_cylindre(corps, 0.06, 0.08, 6.0, Vector3(0, h + 4.0, -l * 0.15), _mat("acier"))
			# Lampes de pêche (lamparos) suspendues au-dessus du pont.
			for i in 4:
				_sphere(corps, 0.22, Vector3(0, h + 3.0, -l * 0.35 + i * 2.6), _lumineux(Color(0.85, 1.0, 0.9), 10.0))
		"voilier":
			_cylindre(corps, 0.07, 0.09, 13.0, Vector3(0, h + 6.5, -l * 0.08), _mat("acier"))
			_boite(corps, Vector3(w * 0.5, 0.9, 3.0), Vector3(0, h + 0.45, l * 0.1), _mat("coque_blanche"))
			_lumineux_point(corps, Vector3(0, h + 13.2, -l * 0.08), blanc, 0.15)
		_:
			_boite(corps, Vector3(w * 0.7, 1.4, 4.5), Vector3(0, h + 0.7, 0.0), _mat("coque_blanche"))
			_boite(corps, Vector3(w * 0.71, 0.5, 4.0), Vector3(0, h + 1.0, 0.0), fenetres)
	# Feux de navigation : rouge à bâbord (gauche), vert à tribord (droite), blanc en tête de mât.
	_lumineux_point(corps, Vector3(-w * 0.5, h + 0.4, -l * 0.15), rouge, 0.12 * maxf(1.0, w / 6.0))
	_lumineux_point(corps, Vector3(w * 0.5, h + 0.4, -l * 0.15), vert, 0.12 * maxf(1.0, w / 6.0))
	_lumineux_point(corps, Vector3(0, h + 4.0 + l * 0.05, -l * 0.3), blanc, 0.14 * maxf(1.0, w / 6.0))
	# Une vraie lumière seulement sur les grands bateaux (performances).
	if sorte in ["ferry", "cargo"]:
		var o := OmniLight3D.new()
		o.light_color = Color(1.0, 0.85, 0.65)
		o.light_energy = 3.0
		o.omni_range = l * 0.6
		o.position = Vector3(0, h + 5.0, 0)
		o.add_to_group("lumiere_secondaire")
		corps.add_child(o)
	# Sillage : écume blanche derrière le bateau.
	var sillage := GPUParticles3D.new()
	sillage.amount = 60 if l < 60 else 120
	sillage.lifetime = 5.0
	sillage.local_coords = false
	sillage.position = Vector3(0, 0.1, l * 0.5)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(w * 0.4, 0.05, 0.5)
	pm.gravity = Vector3.ZERO
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.5
	pm.scale_min = w * 0.4
	pm.scale_max = w * 0.9
	var courbe := Curve.new()
	courbe.add_point(Vector2(0, 0.4))
	courbe.add_point(Vector2(1, 1.6))
	var ct := CurveTexture.new()
	ct.curve = courbe
	pm.scale_curve = ct
	var alpha := Gradient.new()
	alpha.set_color(0, Color(1, 1, 1, 0.55))
	alpha.set_color(1, Color(1, 1, 1, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = alpha
	pm.color_ramp = gt
	sillage.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.orientation = PlaneMesh.FACE_Y
	var mq := StandardMaterial3D.new()
	mq.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mq.vertex_color_use_as_albedo = true
	mq.albedo_color = Color(0.85, 0.9, 0.95, 1)
	mq.albedo_texture = preload("res://scripts/monde/vie/insectes.gd")._point_doux()
	mq.roughness = 0.3
	q.material = mq
	sillage.draw_pass_1 = q
	sillage.visibility_aabb = AABB(Vector3(-60, -2, -60), Vector3(120, 6, 120))
	sillage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	racine.add_child(sillage)
	var points := PackedVector2Array()
	for xz: Array in f.get("chemin", [[0, 200], [100, 200]]):
		points.append(Vector2(float(xz[0]), float(xz[1])))
	var b := {"racine": racine, "corps": corps, "chemin": points, "cible": 1 % points.size(),
		"vitesse": float(f.get("vitesse", {"ferry": 6.0, "cargo": 4.0, "voilier": 3.0}.get(sorte, 7.0))),
		"sillage": sillage, "phase": randf() * 10.0, "taille": l}
	racine.position = Vector3(points[0].x, NIVEAU_EAU, points[0].y)
	if points.size() > 1:
		var d := points[1] - points[0]
		racine.rotation.y = atan2(-d.x, -d.y)
	_bateaux.append(b)


func _lumineux_point(parent: Node3D, p: Vector3, m: Material, rayon: float) -> void:
	_sphere(parent, rayon, p, m)


func _avancer_bateau(b: Dictionary, delta: float) -> void:
	var racine: Node3D = b["racine"]
	var chemin: PackedVector2Array = b["chemin"]
	var corps: Node3D = b["corps"]
	var t := _temps + float(b["phase"])
	# Houle : le bateau tangue et roule doucement (moins s'il est grand).
	var calme := clampf(30.0 / float(b["taille"]), 0.15, 1.0)
	corps.position.y = sin(t * 0.9) * 0.15 * calme
	corps.rotation.x = sin(t * 0.7) * 0.025 * calme
	corps.rotation.z = sin(t * 0.55 + 1.0) * 0.04 * calme
	if chemin.size() < 2:
		(b["sillage"] as GPUParticles3D).emitting = false
		return
	var ici := Vector2(racine.position.x, racine.position.z)
	var vers: Vector2 = chemin[b["cible"]] - ici
	var pas := float(b["vitesse"]) * delta
	if vers.length() < maxf(pas, 2.0):
		b["cible"] = (int(b["cible"]) + 1) % chemin.size()
		return
	var cap := atan2(-vers.x, -vers.y)
	racine.rotation.y = lerp_angle(racine.rotation.y, cap, clampf(delta * 0.35, 0.0, 1.0))
	var avant := Vector2(-sin(racine.rotation.y), -cos(racine.rotation.y))
	ici += avant * pas
	racine.position = Vector3(ici.x, NIVEAU_EAU, ici.y)


# --- Le pont suspendu et ses voitures ----------------------------------------------

## {de: [x, z], a: [x, z], hauteur, voitures}
func _creer_pont(f: Dictionary) -> void:
	var de: Array = f.get("de", [-700, 330])
	var a: Array = f.get("a", [700, 330])
	var p1 := Vector3(float(de[0]), 0, float(de[1]))
	var p2 := Vector3(float(a[0]), 0, float(a[1]))
	var h := float(f.get("hauteur", 42.0))
	var racine := Node3D.new()
	racine.name = "Pont"
	add_child(racine)
	var longueur := p1.distance_to(p2)
	var milieu := (p1 + p2) * 0.5
	racine.position = milieu
	racine.rotation.y = atan2(-(p2 - p1).z, (p2 - p1).x)
	var acier := _mat("acier")
	var beton := _mat("beton")
	# Tablier.
	_boite(racine, Vector3(longueur, 2.2, 24.0), Vector3(0, h, 0), acier)
	# Lampadaires le long du tablier (points chauds).
	var lampe := _lumineux(Color(1.0, 0.78, 0.45), 6.0)
	var nb_lampes := int(longueur / 30.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sph := SphereMesh.new()
	sph.radius = 0.6
	sph.height = 1.2
	sph.radial_segments = 6
	sph.rings = 3
	sph.material = lampe
	mm.mesh = sph
	mm.instance_count = nb_lampes * 2
	for i in nb_lampes:
		var x := -longueur * 0.5 + (i + 0.5) * longueur / nb_lampes
		mm.set_instance_transform(i * 2, Transform3D(Basis(), Vector3(x, h + 5.0, 11.5)))
		mm.set_instance_transform(i * 2 + 1, Transform3D(Basis(), Vector3(x, h + 5.0, -11.5)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	racine.add_child(mmi)
	# Deux pylônes en H avec leurs feux rouges d'aviation, et les grands câbles illuminés.
	var x_pylones := [-longueur * 0.22, longueur * 0.22]
	var haut_pylone := h + 85.0
	var cable := _lumineux(Color(0.75, 0.88, 1.0), 2.2)
	for xp: float in x_pylones:
		for cote: float in [-1.0, 1.0]:
			_boite(racine, Vector3(5.0, haut_pylone + 20.0, 4.0), Vector3(xp, (haut_pylone - 20.0) * 0.5, cote * 13.0), beton)
			_sphere(racine, 0.9, Vector3(xp, haut_pylone, cote * 13.0), _lumineux(Color(1.0, 0.1, 0.05), 12.0))
		_boite(racine, Vector3(5.0, 4.0, 30.0), Vector3(xp, haut_pylone - 8.0, 0), beton)
		_boite(racine, Vector3(5.0, 3.0, 30.0), Vector3(xp, h - 6.0, 0), beton)
	# Câbles porteurs : chaînette entre les pylônes et jusqu'aux culées.
	var points_x := [-longueur * 0.5, x_pylones[0], x_pylones[1], longueur * 0.5]
	var hauteurs := [h + 3.0, haut_pylone - 2.0, haut_pylone - 2.0, h + 3.0]
	for cote: float in [-1.0, 1.0]:
		for s in 3:
			var xa: float = points_x[s]
			var xb: float = points_x[s + 1]
			var ya: float = hauteurs[s]
			var yb: float = hauteurs[s + 1]
			var nb := 24
			for k in nb:
				var u0 := float(k) / nb
				var u1 := float(k + 1) / nb
				var y0 := lerpf(ya, yb, u0) - (sin(u0 * PI) * (haut_pylone - h - 8.0) if s == 1 else sin(u0 * PI) * 6.0)
				var y1 := lerpf(ya, yb, u1) - (sin(u1 * PI) * (haut_pylone - h - 8.0) if s == 1 else sin(u1 * PI) * 6.0)
				var q0 := Vector3(lerpf(xa, xb, u0), y0, cote * 12.5)
				var q1 := Vector3(lerpf(xa, xb, u1), y1, cote * 12.5)
				var seg := _boite(racine, Vector3(q0.distance_to(q1), 0.5, 0.5), (q0 + q1) * 0.5, cable)
				seg.rotation.z = atan2(q1.y - q0.y, q1.x - q0.x)
				seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Piles sous le tablier, jusqu'à l'eau.
	for i in 9:
		var x := -longueur * 0.5 + (i + 0.5) * longueur / 9.0
		if absf(absf(x) - longueur * 0.22) < 40.0:
			continue
		_boite(racine, Vector3(6.0, h + 4.0, 10.0), Vector3(x, (h + NIVEAU_EAU) * 0.5 - 1.0, 0), beton)
	# Le flot de voitures : phares blancs dans un sens, feux rouges dans l'autre.
	var nb_voitures := int(f.get("voitures", 140))
	_flots.append(_creer_flot(racine, longueur, h + 1.6, -5.0, nb_voitures / 2, Color(1.0, 0.95, 0.85), 1.0, 22.0))
	_flots.append(_creer_flot(racine, longueur, h + 1.6, 5.0, nb_voitures / 2, Color(1.0, 0.12, 0.08), -1.0, 20.0))


func _creer_flot(parent: Node3D, longueur: float, y: float, z: float, nombre: int, couleur: Color, sens: float, vitesse: float) -> Dictionary:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var b := BoxMesh.new()
	b.size = Vector3(1.6, 0.35, 1.9)
	b.material = _lumineux(couleur, 9.0)
	mm.mesh = b
	mm.instance_count = nombre
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-longueur * 0.5 - 10, y - 5, z - 10), Vector3(longueur + 20, 10, 20))
	parent.add_child(mmi)
	var positions := PackedFloat32Array()
	var voies := PackedFloat32Array()
	var vitesses := PackedFloat32Array()
	for i in nombre:
		positions.append(randf() * longueur)
		voies.append(z + (randi() % 3 - 1) * 3.0)
		vitesses.append(vitesse * randf_range(0.8, 1.2))
	return {"mm": mm, "longueur": longueur, "y": y, "sens": sens, "positions": positions, "voies": voies, "vitesses": vitesses}


func _avancer_flot(f: Dictionary, delta: float) -> void:
	var mm: MultiMesh = f["mm"]
	var longueur: float = f["longueur"]
	var positions: PackedFloat32Array = f["positions"]
	var voies: PackedFloat32Array = f["voies"]
	var vitesses: PackedFloat32Array = f["vitesses"]
	var sens: float = f["sens"]
	for i in positions.size():
		positions[i] = fmod(positions[i] + vitesses[i] * delta, longueur)
		var x := (positions[i] - longueur * 0.5) * sens
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(x, f["y"], voies[i])))
	f["positions"] = positions


# --- Avions et hélicoptères --------------------------------------------------------

## sorte : avion (traverse le ciel très haut) ou helico (tourne au-dessus de la ville).
func _creer_avion(f: Dictionary) -> void:
	var sorte := String(f.get("sorte", "avion"))
	var racine := Node3D.new()
	racine.name = "Ciel_%s_%d" % [sorte, _avions.size()]
	add_child(racine)
	var corps := _mat("coque_sombre")
	if sorte == "helico":
		_boite(racine, Vector3(1.6, 1.6, 4.0), Vector3.ZERO, corps)
		_boite(racine, Vector3(0.3, 0.3, 4.0), Vector3(0, 0.3, 3.5), corps)
		var rotor := _boite(racine, Vector3(9.0, 0.05, 0.25), Vector3(0, 1.0, 0), corps)
		rotor.name = "Rotor"
		# Le projecteur de l'hélicoptère : un cône de lumière vers le sol.
		var spot := SpotLight3D.new()
		spot.light_color = Color(0.9, 0.95, 1.0)
		spot.light_energy = 6.0
		spot.spot_range = 260.0
		spot.spot_angle = 7.0
		spot.light_volumetric_fog_energy = 4.0
		spot.rotation.x = -PI / 2 + 0.35
		spot.add_to_group("lumiere_secondaire")
		racine.add_child(spot)
	else:
		_boite(racine, Vector3(3.5, 3.5, 36.0), Vector3.ZERO, corps)
		_boite(racine, Vector3(34.0, 0.6, 6.0), Vector3(0, 0, 2.0), corps)
	var feux := []
	for d: Array in [[Vector3(-1, 0, 0), Color(1, 0.1, 0.1)], [Vector3(1, 0, 0), Color(0.1, 1, 0.3)], [Vector3(0, 1, 0), Color(1, 0.15, 0.1)], [Vector3(0, 0, 1), Color(1, 1, 1)]]:
		var portee := 17.0 if sorte == "avion" else 0.9
		var p: Vector3 = (d[0] as Vector3) * Vector3(portee, 2.0, 18.0 if sorte == "avion" else 2.2)
		feux.append(_sphere(racine, 0.9 if sorte == "avion" else 0.18, p, _lumineux(d[1], 14.0)))
	var c: Array = f.get("centre", [0, 0])
	_avions.append({"racine": racine, "sorte": sorte, "feux": feux,
		"centre": Vector3(float(c[0]), float(f.get("altitude", 400.0)), float(c[1])),
		"rayon": float(f.get("rayon", 1500.0)), "vitesse": float(f.get("vitesse", 70.0)),
		"direction": deg_to_rad(float(f.get("direction", 70.0))), "phase": randf() * 100.0})


func _avancer_avion(a: Dictionary, _delta: float) -> void:
	var racine: Node3D = a["racine"]
	var t := _temps + float(a["phase"])
	var r: float = a["rayon"]
	var v: float = a["vitesse"]
	if a["sorte"] == "helico":
		var ang := t * v / r
		racine.position = a["centre"] + Vector3(cos(ang) * r, sin(t * 0.2) * 6.0, sin(ang) * r)
		racine.rotation.y = -ang
		racine.rotation.z = 0.12
		var rotor := racine.get_node_or_null("Rotor") as Node3D
		if rotor != null:
			rotor.rotation.y = t * 40.0
	else:
		# Traversée en ligne droite d'un bord à l'autre du ciel, puis recommence.
		var dir := Vector3(sin(a["direction"]), 0, -cos(a["direction"]))
		var trajet := r * 2.0
		var u := fmod(t * v, trajet + 600.0) - r
		racine.position = a["centre"] + dir * u
		racine.look_at(racine.position + dir, Vector3.UP)
	# Feux : le rouge du dessus et le blanc de queue clignotent.
	var feux: Array = a["feux"]
	(feux[2] as Node3D).visible = fmod(t, 1.2) < 0.12
	(feux[3] as Node3D).visible = fmod(t + 0.5, 1.0) < 0.08


# --- Objets de rue -----------------------------------------------------------------

## sorte : distributeur (boissons, éclairé), velos (rangée), plots, scooter.
func _creer_objet(f: Dictionary) -> void:
	var sorte := String(f.get("sorte", "distributeur"))
	var p: Array = f.get("position", [0, 0])
	var racine := Node3D.new()
	racine.name = "Rue_%s" % sorte
	racine.position = Vector3(float(p[0]), float(f.get("y", 0.0)), float(p[1]))
	racine.rotation.y = -deg_to_rad(float(f.get("regarde", 0.0)))
	add_child(racine)
	var n := int(f.get("nombre", 1))
	match sorte:
		"distributeur":
			var couleurs := [Color(0.85, 0.1, 0.12), Color(0.95, 0.95, 0.95), Color(0.1, 0.35, 0.8), Color(0.1, 0.55, 0.3), Color(0.95, 0.6, 0.1)]
			for i in n:
				_distributeur(racine, Vector3((i - (n - 1) * 0.5) * 1.05, 0, 0), couleurs[(i + int(p[0])) % couleurs.size()])
		"velos":
			for i in n:
				var v := Node3D.new()
				v.position = Vector3((i - (n - 1) * 0.5) * 0.7, 0, 0)
				v.rotation.y = randf_range(-0.12, 0.12)
				racine.add_child(v)
				_velo(v, [Color(0.1, 0.1, 0.12), Color(0.75, 0.75, 0.78), Color(0.6, 0.1, 0.1), Color(0.15, 0.3, 0.5), Color(0.85, 0.85, 0.8)][(i * 3 + int(p[1])) % 5])
		"plots":
			var orange := StandardMaterial3D.new()
			orange.albedo_color = Color(1.0, 0.38, 0.05)
			orange.emission_enabled = true
			orange.emission = Color(1.0, 0.3, 0.0)
			orange.emission_energy_multiplier = 0.15
			for i in n:
				_cylindre(racine, 0.04, 0.17, 0.7, Vector3(i * 1.2, 0.35, 0), orange)
				_boite(racine, Vector3(0.38, 0.04, 0.38), Vector3(i * 1.2, 0.02, 0), _mat("coque_sombre"))
		"scooter":
			for i in n:
				var s := Node3D.new()
				s.position = Vector3(i * 1.0, 0, 0)
				racine.add_child(s)
				_scooter(s, [Color(0.85, 0.85, 0.82), Color(0.15, 0.15, 0.17), Color(0.7, 0.12, 0.1), Color(0.3, 0.5, 0.45)][(i + int(p[0])) % 4])


func _distributeur(parent: Node3D, p: Vector3, couleur: Color) -> void:
	var corps := StandardMaterial3D.new()
	corps.albedo_color = couleur
	corps.roughness = 0.35
	corps.metallic = 0.2
	var d := Node3D.new()
	d.position = p
	parent.add_child(d)
	_boite(d, Vector3(1.0, 1.85, 0.8), Vector3(0, 0.925, 0), corps)
	# Vitrine éclairée avec trois rangées de bouteilles.
	_boite(d, Vector3(0.86, 0.95, 0.02), Vector3(0, 1.32, -0.405), _lumineux(Color(0.92, 0.96, 1.0), 2.2))
	var tons := [Color(0.9, 0.2, 0.15), Color(0.2, 0.5, 0.9), Color(0.95, 0.8, 0.2), Color(0.3, 0.75, 0.35), Color(0.9, 0.9, 0.9), Color(0.5, 0.25, 0.1)]
	for rangee in 3:
		for k in 7:
			var b := _cylindre(d, 0.035, 0.035, 0.18, Vector3(-0.36 + k * 0.12, 1.02 + rangee * 0.3, -0.42), _mat_simple(tons[(k + rangee * 2) % tons.size()]))
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Boutons lumineux, fente à monnaie, bac de sortie.
	_boite(d, Vector3(0.86, 0.06, 0.02), Vector3(0, 0.82, -0.405), _lumineux(Color(0.3, 1.0, 0.5), 3.0))
	_boite(d, Vector3(0.7, 0.22, 0.05), Vector3(0, 0.25, -0.41), _mat("coque_sombre"))
	_boite(d, Vector3(0.18, 0.3, 0.03), Vector3(0.3, 0.6, -0.41), _mat("acier"))
	var lumiere := OmniLight3D.new()
	lumiere.light_color = Color(0.85, 0.92, 1.0)
	lumiere.light_energy = 0.9
	lumiere.omni_range = 3.5
	lumiere.position = Vector3(0, 1.3, -0.9)
	lumiere.add_to_group("lumiere_secondaire")
	d.add_child(lumiere)
	var forme := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(1.0, 1.85, 0.8)
	col.shape = bx
	col.position = Vector3(0, 0.925, 0)
	forme.add_child(col)
	d.add_child(forme)


func _mat_simple(c: Color) -> StandardMaterial3D:
	var cle := "s_" + c.to_html()
	if not _materiaux.has(cle):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.3
		_materiaux[cle] = m
	return _materiaux[cle]


## Un vélo de ville (mamachari) vu de côté : deux roues, cadre, guidon, panier.
func _velo(v: Node3D, couleur: Color) -> void:
	var cadre := _mat_simple(couleur)
	var pneu := _mat("coque_sombre")
	for z: float in [-0.52, 0.52]:
		var roue := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.3
		t.outer_radius = 0.34
		t.rings = 20
		t.ring_segments = 6
		roue.mesh = t
		roue.material_override = pneu
		roue.position = Vector3(0, 0.34, z)
		roue.rotation.z = PI / 2
		v.add_child(roue)
	var tubes := [[Vector3(0, 0.34, 0.52), Vector3(0, 0.55, 0.0)], [Vector3(0, 0.55, 0.0), Vector3(0, 0.36, -0.1)],
		[Vector3(0, 0.36, -0.1), Vector3(0, 0.34, -0.52)], [Vector3(0, 0.34, -0.52), Vector3(0, 0.95, -0.42)],
		[Vector3(0, 0.55, 0.0), Vector3(0, 0.88, 0.08)], [Vector3(0, 0.34, 0.52), Vector3(0, 0.58, 0.08)]]
	for t: Array in tubes:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var c := _cylindre(v, 0.02, 0.02, a.distance_to(b), (a + b) * 0.5, cadre)
		c.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	_boite(v, Vector3(0.5, 0.03, 0.04), Vector3(0, 0.98, -0.42), _mat("acier"))
	_boite(v, Vector3(0.16, 0.06, 0.26), Vector3(0, 0.92, 0.1), pneu)
	# Le panier avant.
	_boite(v, Vector3(0.36, 0.22, 0.28), Vector3(0, 0.88, -0.62), _mat("acier"))


func _scooter(s: Node3D, couleur: Color) -> void:
	var carrosserie := _mat_simple(couleur)
	var pneu := _mat("coque_sombre")
	for z: float in [-0.55, 0.55]:
		_cylindre(s, 0.22, 0.22, 0.12, Vector3(0, 0.22, z), pneu).rotation.z = PI / 2
	_boite(s, Vector3(0.36, 0.38, 0.9), Vector3(0, 0.45, 0.2), carrosserie)
	_boite(s, Vector3(0.3, 0.12, 0.6), Vector3(0, 0.72, 0.25), pneu)
	_boite(s, Vector3(0.36, 0.7, 0.18), Vector3(0, 0.62, -0.5), carrosserie)
	_boite(s, Vector3(0.6, 0.04, 0.04), Vector3(0, 1.0, -0.55), _mat("acier"))
	_sphere(s, 0.07, Vector3(0, 0.85, -0.6), _lumineux(Color(1, 0.95, 0.85), 2.0))
