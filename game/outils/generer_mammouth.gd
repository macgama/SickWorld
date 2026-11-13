extends SceneTree
## Fabrique le maillage du mammouth laineux (assets/animaux/mammouth/mammouth.res).
## Le corps est une forme « sculptée » : des volumes simples fondus ensemble
## (corps, bosse, tête, trompe, pattes…), transformée en maillage par « surface nets ».
## Chaque sommet est relié aux os du squelette (corps, tête, trompe, pattes, queue)
## pour pouvoir l'animer, et de longues mèches de poils pendent sous le ventre.
##
## Lancer : godot --headless --path game -s res://outils/generer_mammouth.gd

const SORTIE := "res://assets/animaux/mammouth/mammouth.res"
const PAS := 0.05
const MIN := Vector3(-1.75, -0.05, -3.05)
const MAX := Vector3(1.75, 4.45, 2.75)

## Os : nom, parent, position (mètres, le mammouth regarde vers -Z, sol à y = 0).
var os := []
## Volumes : type, paramètres, os, adoucissement.
var volumes := []
var bruit := FastNoiseLite.new()
var bruit_fin := FastNoiseLite.new()

const TROMPE := [Vector3(0, 3.05, -2.2), Vector3(0, 2.45, -2.48), Vector3(0, 1.8, -2.6),
		Vector3(0, 1.15, -2.55), Vector3(0, 0.62, -2.38), Vector3(0, 0.36, -2.12)]
const HANCHES := [Vector3(-0.58, 2.0, -0.85), Vector3(0.58, 2.0, -0.85), Vector3(-0.56, 1.95, 1.2),
		Vector3(0.56, 1.95, 1.2)]


func _initialize() -> void:
	bruit.seed = 7
	bruit.frequency = 0.9
	bruit_fin.seed = 11
	bruit_fin.frequency = 4.0
	_definir()
	var maillage := _construire()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/animaux/mammouth"))
	var err := ResourceSaver.save(maillage, SORTIE, ResourceSaver.FLAG_COMPRESS)
	print("Mammouth enregistré : ", SORTIE, " (", err, ")")
	quit()


func _definir() -> void:
	os = [
		{"nom": "corps", "parent": -1, "position": Vector3(0, 2.3, 0)},
		{"nom": "tete", "parent": 0, "position": Vector3(0, 3.1, -1.45)},
	]
	for k in 5:
		os.append({"nom": "trompe%d" % k, "parent": 1 if k == 0 else 1 + k, "position": TROMPE[k]})
	for k in 4:
		os.append({"nom": "patte%d" % k, "parent": 0, "position": HANCHES[k]})
	os.append({"nom": "queue", "parent": 0, "position": Vector3(0, 2.35, 2.15)})
	# Corps : tronc, bosse des épaules, croupe basse, ventre poilu.
	_ellipse(Vector3(0, 2.3, 0.25), Vector3(1.22, 1.15, 1.85), 0)
	_ellipse(Vector3(0, 2.85, -0.75), Vector3(1.12, 1.08, 1.1), 0)
	_ellipse(Vector3(0, 3.35, -0.95), Vector3(0.7, 0.6, 0.7), 0)
	_ellipse(Vector3(0, 2.05, 1.35), Vector3(1.08, 0.98, 0.95), 0)
	_ellipse(Vector3(0, 1.75, 0.1), Vector3(1.28, 0.85, 1.75), 0)
	# Tête haute, dôme, joues.
	_ellipse(Vector3(0, 3.2, -1.8), Vector3(0.68, 0.82, 0.62), 1)
	_ellipse(Vector3(0, 3.88, -1.62), Vector3(0.36, 0.34, 0.36), 1)
	_ellipse(Vector3(0, 2.85, -2.05), Vector3(0.42, 0.45, 0.4), 1)
	# Petites oreilles.
	_ellipse(Vector3(-0.62, 3.3, -1.55), Vector3(0.14, 0.24, 0.2), 1)
	_ellipse(Vector3(0.62, 3.3, -1.55), Vector3(0.14, 0.24, 0.2), 1)
	# Trompe.
	for k in TROMPE.size() - 1:
		var r0 := lerpf(0.27, 0.09, k / 5.0)
		var r1 := lerpf(0.27, 0.09, (k + 1) / 5.0)
		_capsule(TROMPE[k], TROMPE[k + 1], r0, r1, 2 + mini(k, 4))
	# Pattes en colonnes et larges pieds.
	for k in 4:
		var h: Vector3 = HANCHES[k]
		var pied := Vector3(h.x, 0.25, h.z)
		_capsule(h + Vector3(0, 0.3, 0), pied, 0.42, 0.31, 7 + k)
		_ellipse(Vector3(h.x, 0.16, h.z - 0.03), Vector3(0.36, 0.18, 0.38), 7 + k)
	# Queue courte.
	_capsule(Vector3(0, 2.4, 2.1), Vector3(0, 1.7, 2.38), 0.09, 0.06, 11)


func _ellipse(c: Vector3, r: Vector3, idx_os: int) -> void:
	volumes.append({"type": 0, "c": c, "r": r, "os": idx_os})


func _capsule(a: Vector3, b: Vector3, ra: float, rb: float, idx_os: int) -> void:
	volumes.append({"type": 1, "a": a, "b": b, "ra": ra, "rb": rb, "os": idx_os})


func _distance_volume(v: Dictionary, p: Vector3) -> float:
	if v.type == 0:
		var r: Vector3 = v.r
		var q: Vector3 = (p - v.c) / r
		return (q.length() - 1.0) * minf(r.x, minf(r.y, r.z))
	var a: Vector3 = v.a
	var ab: Vector3 = v.b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t) - lerpf(v.ra, v.rb, t)


func _union_douce(d1: float, d2: float, k: float) -> float:
	var h := clampf(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0)
	return lerpf(d2, d1, h) - k * h * (1.0 - h)


func champ(p: Vector3) -> float:
	var d := 100.0
	for v in volumes:
		d = _union_douce(d, _distance_volume(v, p), 0.32 if v.os <= 1 else 0.14)
	# Pelage bosselé : touffes et mèches.
	var touffes := bruit.get_noise_3d(p.x * 1.0, p.y * 0.35, p.z * 1.0) * 0.06
	touffes += bruit_fin.get_noise_3d(p.x, p.y * 0.3, p.z) * 0.025
	var sur_trompe := p.z < -2.0 and p.y < 2.9
	return d + (touffes * 0.3 if sur_trompe else touffes)


func _normale(p: Vector3) -> Vector3:
	var e := 0.02
	return Vector3(champ(p + Vector3(e, 0, 0)) - champ(p - Vector3(e, 0, 0)),
			champ(p + Vector3(0, e, 0)) - champ(p - Vector3(0, e, 0)),
			champ(p + Vector3(0, 0, e)) - champ(p - Vector3(0, 0, e))).normalized()


## Poids des os pour un point : les deux os les plus proches, mélangés en douceur.
func _poids(p: Vector3) -> Array:
	var meilleurs := {}
	for v in volumes:
		var d := _distance_volume(v, p)
		if not meilleurs.has(v.os) or d < meilleurs[v.os]:
			meilleurs[v.os] = d
	var cles := meilleurs.keys()
	cles.sort_custom(func(a, b): return meilleurs[a] < meilleurs[b])
	var b0: int = cles[0]
	var b1: int = cles[1] if cles.size() > 1 else 0
	var w1 := exp(-(float(meilleurs[b1]) - float(meilleurs[b0])) * 9.0)
	return [b0, b1, 1.0 / (1.0 + w1), w1 / (1.0 + w1)]


func _construire() -> ArrayMesh:
	var n := Vector3i(((MAX - MIN) / PAS).ceil()) + Vector3i.ONE
	print("Grille ", n)
	var valeurs := PackedFloat32Array()
	valeurs.resize(n.x * n.y * n.z)
	for k in n.z:
		for j in n.y:
			for i in n.x:
				valeurs[(k * n.y + j) * n.x + i] = champ(MIN + Vector3(i, j, k) * PAS)
	var index_sommet := {}
	var sommets := PackedVector3Array()
	var coins := [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 0),
			Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(0, 1, 1), Vector3i(1, 1, 1)]
	var aretes := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]
	for k in n.z - 1:
		for j in n.y - 1:
			for i in n.x - 1:
				var vals := []
				var dedans := 0
				for c in coins:
					var val := valeurs[((k + c.z) * n.y + j + c.y) * n.x + i + c.x]
					vals.append(val)
					if val < 0.0:
						dedans += 1
				if dedans == 0 or dedans == 8:
					continue
				var somme := Vector3.ZERO
				var nb := 0
				for a in aretes:
					var va: float = vals[a[0]]
					var vb: float = vals[a[1]]
					if (va < 0.0) == (vb < 0.0):
						continue
					var t := va / (va - vb)
					somme += Vector3(coins[a[0]]).lerp(Vector3(coins[a[1]]), t)
					nb += 1
				var p := MIN + (Vector3(i, j, k) + somme / nb) * PAS
				# Un petit pas de projection vers la surface exacte.
				var nrm := _normale(p)
				p -= nrm * champ(p)
				index_sommet[Vector3i(i, j, k)] = sommets.size()
				sommets.append(p)
	print("Sommets du corps : ", sommets.size())
	var indices := PackedInt32Array()
	# Une face (deux triangles) pour chaque arête de la grille qui traverse la surface.
	for k in range(1, n.z - 1):
		for j in range(1, n.y - 1):
			for i in range(1, n.x - 1):
				var v0 := valeurs[(k * n.y + j) * n.x + i]
				for axe in 3:
					var d := Vector3i(1 if axe == 0 else 0, 1 if axe == 1 else 0, 1 if axe == 2 else 0)
					var q := Vector3i(i, j, k) + d
					var v1 := valeurs[(q.z * n.y + q.y) * n.x + q.x]
					if (v0 < 0.0) == (v1 < 0.0):
						continue
					var u := Vector3i(0, 1, 0) if axe == 0 else Vector3i(0, 0, 1) if axe == 1 else Vector3i(1, 0, 0)
					var w := Vector3i(0, 0, 1) if axe == 0 else Vector3i(1, 0, 0) if axe == 1 else Vector3i(0, 1, 0)
					var c := Vector3i(i, j, k)
					var quad := [c - u - w, c - w, c, c - u]
					var ok := true
					for cell in quad:
						if not index_sommet.has(cell):
							ok = false
					if not ok:
						continue
					var a: int = index_sommet[quad[0]]
					var b: int = index_sommet[quad[1]]
					var e: int = index_sommet[quad[2]]
					var f: int = index_sommet[quad[3]]
					if v0 < 0.0:
						indices.append_array([a, b, e, a, e, f])
					else:
						indices.append_array([a, e, b, a, f, e])
	var normales := PackedVector3Array()
	var os_s := PackedInt32Array()
	var poids_s := PackedFloat32Array()
	var couleurs := PackedColorArray()
	for p in sommets:
		normales.append(_normale(p))
		var pw := _poids(p)
		os_s.append_array([pw[0], pw[1], 0, 0])
		poids_s.append_array([pw[2], pw[3], 0.0, 0.0])
		# Pelage plus clair et roux sur le dos, plus sombre aux pattes et au ventre.
		var clair := clampf((p.y - 1.2) / 2.5, 0.0, 1.0) * 0.6 + bruit.get_noise_3d(p.x * 3, p.y * 3, p.z * 3) * 0.25
		couleurs.append(Color(clair, 0, 0))
	# Orientation des triangles : la normale du triangle doit suivre celle du champ.
	for t in range(0, indices.size(), 3):
		var a := sommets[indices[t]]
		var b := sommets[indices[t + 1]]
		var c := sommets[indices[t + 2]]
		var nf := (b - a).cross(c - a)
		if nf.dot(normales[indices[t]]) > 0.0:
			var tmp := indices[t + 1]
			indices[t + 1] = indices[t + 2]
			indices[t + 2] = tmp
	var maillage := ArrayMesh.new()
	var corps := []
	corps.resize(Mesh.ARRAY_MAX)
	corps[Mesh.ARRAY_VERTEX] = sommets
	corps[Mesh.ARRAY_NORMAL] = normales
	corps[Mesh.ARRAY_COLOR] = couleurs
	corps[Mesh.ARRAY_BONES] = os_s
	corps[Mesh.ARRAY_WEIGHTS] = poids_s
	corps[Mesh.ARRAY_INDEX] = indices
	maillage.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, corps)
	maillage.surface_set_name(0, "corps")
	maillage.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _defenses())
	maillage.surface_set_name(1, "defenses")
	maillage.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _meches(sommets, normales, os_s, poids_s))
	maillage.surface_set_name(2, "meches")
	maillage.set_meta("os", os)
	return maillage


## Les défenses : de longs tubes d'ivoire qui s'écartent puis se recourbent vers l'intérieur.
## Les yeux sont deux petites boules sombres (même surface, couleur de sommet noire).
func _defenses() -> Array:
	var st := SurfaceTool.new()
	st.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS)
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base_tete := Vector3(0, 2.9, -1.65)
	var n := 48
	for cote in [-1.0, 1.0]:
		var points: Array[Vector3] = []
		var rayons: Array[float] = []
		var couleurs: Array[Color] = []
		for k in n + 1:
			var u := float(k) / n
			points.append(base_tete + Vector3(cote * (0.3 + sin(u * 2.2) * 0.8), -0.3 - sin(u * 1.8) * 0.95 + u * u * 1.5,
					-0.45 - sin(u * 2.0) * 1.8))
			# Pointe arrondie au bout.
			rayons.append(0.125 * (1.0 - u * 0.78) * sqrt(clampf((1.0 - u) * 30.0, 0.0, 1.0)))
			couleurs.append(Color(0.74, 0.65, 0.48).darkened(0.35 * (1.0 - u)))
		_tube(st, points, rayons, couleurs)
	for cote in [-1.0, 1.0]:
		var oeil := Vector3(cote * 0.45, 3.25, -2.12)
		var points: Array[Vector3] = []
		var rayons: Array[float] = []
		var couleurs: Array[Color] = []
		for k in 9:
			var u := k / 8.0
			points.append(oeil + Vector3(0, 0, -0.03 + u * 0.08))
			rayons.append(sin(u * PI) * 0.05)
			couleurs.append(Color(0.02, 0.015, 0.01))
		_tube(st, points, rayons, couleurs)
	return st.commit_to_arrays()


## Un tube lisse le long d'une courbe (repère transporté pour éviter les torsions).
func _tube(st: SurfaceTool, points: Array[Vector3], rayons: Array[float], couleurs: Array[Color]) -> void:
	var cotes := 16
	var anneaux := []
	var axe := (points[1] - points[0]).normalized()
	var x := axe.cross(Vector3.UP).normalized()
	for k in points.size():
		var suivant := points[mini(k + 1, points.size() - 1)]
		var precedent := points[maxi(k - 1, 0)]
		var nouvel_axe := (suivant - precedent).normalized()
		# Transport parallèle : on fait tourner le repère juste ce qu'il faut.
		x = (x - nouvel_axe * x.dot(nouvel_axe)).normalized()
		axe = nouvel_axe
		var y := axe.cross(x)
		var anneau := []
		for s in cotes + 1:
			var a := s * TAU / cotes
			var radial := x * cos(a) + y * sin(a)
			anneau.append([points[k] + radial * rayons[k], radial])
		anneaux.append(anneau)
	for k in points.size() - 1:
		for s in cotes:
			var quad := [anneaux[k][s], anneaux[k][s + 1], anneaux[k + 1][s + 1], anneaux[k + 1][s]]
			var c := [couleurs[k], couleurs[k], couleurs[k + 1], couleurs[k + 1]]
			for idx in [0, 2, 1, 0, 3, 2]:
				st.set_color(c[idx])
				st.set_normal(quad[idx][1])
				st.set_bones(PackedInt32Array([1, 0, 0, 0]))
				st.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
				st.add_vertex(quad[idx][0])


## Longues mèches de poils qui pendent du ventre, des flancs, des épaules et du haut des pattes.
func _meches(sommets: PackedVector3Array, normales: PackedVector3Array, os_s: PackedInt32Array,
		poids_s: PackedFloat32Array) -> Array:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 5
	var st := SurfaceTool.new()
	st.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS)
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nombre := 0
	for i in sommets.size():
		var p := sommets[i]
		var nrm := normales[i]
		var b0 := os_s[i * 4]
		# Pas de mèches sur la trompe, les pieds et le dessus du dos.
		if b0 >= 2 and b0 <= 6:
			continue
		if p.y < 0.7 or nrm.y > 0.55:
			continue
		var proba := 0.2 if nrm.y < 0.0 else 0.1
		if hasard.randf() > proba:
			continue
		var longueur := hasard.randf_range(0.35, 0.8)
		if p.y < 2.2 and b0 == 0:
			longueur *= 1.3
		if b0 == 1:
			longueur *= 0.7
		# Les mèches ne descendent pas sous le genou.
		# Bas de toison irrégulier.
		# (plus longue sous le ventre et derrière les pattes avant, plus courte vers l'arrière).
		var plancher := lerpf(0.65, 1.45, smoothstep(-1.2, 1.8, p.z)) + hasard.randf_range(-0.25, 0.3)
		longueur = minf(longueur * hasard.randf_range(0.8, 1.35), maxf(p.y - plancher, 0.12))
		var bas := (Vector3(0, -1, 0) + nrm * 0.18 + Vector3(hasard.randf_range(-0.1, 0.1), 0,
				hasard.randf_range(-0.1, 0.1))).normalized()
		var cote := bas.cross(nrm).normalized()
		if cote.length() < 0.5:
			cote = Vector3.RIGHT
		var largeur := hasard.randf_range(0.1, 0.18)
		var depart := p - nrm * 0.04
		var milieu := depart + bas * longueur * 0.5 + nrm * 0.05
		var fin := milieu + (bas + nrm * 0.12).normalized() * longueur * 0.5
		var teinte := hasard.randf_range(0.0, 1.0)
		var bones := PackedInt32Array([os_s[i * 4], os_s[i * 4 + 1], 0, 0])
		var weights := PackedFloat32Array([poids_s[i * 4], poids_s[i * 4 + 1], 0.0, 0.0])
		var lignes := [[depart, 0.0], [milieu, 0.5], [fin, 1.0]]
		for s in 2:
			var h0: Vector3 = lignes[s][0]
			var h1: Vector3 = lignes[s + 1][0]
			var v0: float = lignes[s][1]
			var v1: float = lignes[s + 1][1]
			var w0 := largeur * (1.0 - v0 * 0.35)
			var w1 := largeur * (1.0 - v1 * 0.35)
			var quad := [[h0 - cote * w0 * 0.5, Vector2(0, v0)], [h0 + cote * w0 * 0.5, Vector2(1, v0)],
					[h1 + cote * w1 * 0.5, Vector2(1, v1)], [h1 - cote * w1 * 0.5, Vector2(0, v1)]]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_color(Color(teinte, 0, 0))
				st.set_normal(nrm)
				st.set_uv(quad[idx][1])
				st.set_bones(bones)
				st.set_weights(weights)
				st.add_vertex(quad[idx][0])
		nombre += 1
	print("Mèches : ", nombre)
	return st.commit_to_arrays()
