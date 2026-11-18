extends RefCounted
## Sème de petits objets de décor sur le terrain d'une zone (vie ambiante) : cailloux,
## branches mortes, touffes, buissons, souches, poteries… pour que le sol ne soit
## jamais vide. Chaque modèle Poly Haven est dessiné en MultiMesh (un appel de dessin
## par morceau, par bloc de 40 m) : des milliers d'objets ne coûtent presque rien.
##
## On ne pose un objet que là où un rayon tiré du ciel touche d'abord le sol de la
## zone (« CollisionSol ») : jamais sur un toit, dans une maison ou sur un rocher.
## Décrit dans data/vie_ambiante.json (clé « disperser »).

const DOSSIERS := ["res://assets/commun/", "res://assets/egypte/", "res://assets/prehistoire/", "res://assets/hub/"]
const BLOC := 40.0

static var _morceaux_cache := {}


## Liste des [maillage, transformation locale] d'un modèle (chaque morceau recentré).
static func morceaux(id: String) -> Array:
	if _morceaux_cache.has(id):
		return _morceaux_cache[id]
	var resultat := []
	for d in DOSSIERS:
		var chemin: String = d + "modeles/%s/%s.gltf" % [id, id]
		if not ResourceLoader.exists(chemin):
			continue
		var scene := (load(chemin) as PackedScene).instantiate() as Node3D
		for n in scene.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null:
				continue
			var t := _transformation_dans(mi, scene)
			# Recentré en x/z : un « set » de cailloux devient plusieurs cailloux séparés.
			var aabb := t * mi.mesh.get_aabb()
			var centre := aabb.get_center()
			t.origin -= Vector3(centre.x, aabb.position.y, centre.z)
			var mat: Material = mi.get_surface_override_material(0) if mi.get_surface_override_material_count() > 0 else null
			if mat == null and mi.mesh.get_surface_count() == 1:
				mat = _decoupe(mi.mesh.surface_get_material(0))
			resultat.append([mi.mesh, t, mat])
		scene.free()
		break
	_morceaux_cache[id] = resultat
	return resultat


## Feuillage semi-transparent (« BLEND » du glTF) → découpe nette (alpha scissor) :
## des milliers de touffes en mélange alpha se trient mal et paraissent laiteuses.
## Renvoie null si le matériau n'a pas besoin d'être changé.
static func _decoupe(mat: Material) -> Material:
	var base := mat as BaseMaterial3D
	if base == null or base.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
		return null
	var copie := base.duplicate() as BaseMaterial3D
	copie.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	copie.alpha_scissor_threshold = 0.5
	copie.cull_mode = BaseMaterial3D.CULL_DISABLED
	return copie


static func _transformation_dans(n: Node3D, racine: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var courant: Node = n
	while courant != null and courant != racine:
		if courant is Node3D:
			t = (courant as Node3D).transform * t
		courant = courant.get_parent()
	return t


## Sème les objets d'une fiche. ile : la zone (hauteur, _parts_sol, _distance_piste).
## fiche : {modele, nombre, zone [x1, z1, x2, z2], echelle [min, max], enfoui,
##          hors_piste (m), pente_max, sol_min (y minimum), sol_max, ombre, distance,
##          pres_de [[x, z, rayon], …] (seulement près de ces points),
##          grappes [nombre, rayon] (en bouquets), exclure [[x, z, rayon], …]}
static func semer(ile: Node3D, parent: Node3D, fiche: Dictionary, graine: int) -> int:
	var liste := morceaux(String(fiche.get("modele", "")))
	if liste.is_empty():
		return 0
	var espace := ile.get_world_3d().direct_space_state
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine
	var demi := float(ile.get("taille_terrain")) * 0.5 - 6.0 if ile.get("taille_terrain") != null else 150.0
	var z_ := fiche.get("zone", [-demi, -demi, demi, demi]) as Array
	var x1 := float(z_[0])
	var z1 := float(z_[1])
	var x2 := float(z_[2])
	var z2 := float(z_[3])
	var ech: Array = fiche.get("echelle", [0.7, 1.3])
	var enfoui := float(fiche.get("enfoui", 0.05))
	var hors_piste := float(fiche.get("hors_piste", 0.0))
	var pente_max := float(fiche.get("pente_max", 0.6))
	var sol_min := float(fiche.get("sol_min", 0.3))
	var sol_max := float(fiche.get("sol_max", 9999.0))
	var pres_de: Array = fiche.get("pres_de", [])
	var nombre := int(fiche.get("nombre", 100))
	var essais := nombre * 4
	# Une liste de transformations par morceau et par bloc.
	var par_bloc := {}
	var poses := 0
	var exclus: Array = fiche.get("exclure", [])
	# « grappes » : [nombre de bouquets, rayon d'un bouquet (m)].
	var grappes: Array[Vector2] = []
	var rayon_grappe := 0.0
	if fiche.has("grappes"):
		var gr: Array = fiche["grappes"]
		rayon_grappe = float(gr[1])
		for i in int(gr[0]):
			if not pres_de.is_empty():
				var p0: Array = pres_de[hasard.randi() % pres_de.size()]
				var a0 := hasard.randf() * TAU
				var r0 := sqrt(hasard.randf()) * float(p0[2])
				grappes.append(Vector2(float(p0[0]) + cos(a0) * r0, float(p0[1]) + sin(a0) * r0))
			else:
				grappes.append(Vector2(hasard.randf_range(x1, x2), hasard.randf_range(z1, z2)))
	while essais > 0 and poses < nombre:
		essais -= 1
		var x: float
		var z: float
		if not grappes.is_empty():
			# En bouquets : autour de centres tirés une fois pour toutes.
			var g: Vector2 = grappes[hasard.randi() % grappes.size()]
			var a_g := hasard.randf() * TAU
			var r_g := pow(hasard.randf(), 0.7) * rayon_grappe
			x = g.x + cos(a_g) * r_g
			z = g.y + sin(a_g) * r_g
		elif not pres_de.is_empty():
			var p: Array = pres_de[hasard.randi() % pres_de.size()]
			var a := hasard.randf() * TAU
			var r := sqrt(hasard.randf()) * float(p[2])
			x = float(p[0]) + cos(a) * r
			z = float(p[1]) + sin(a) * r
		else:
			x = hasard.randf_range(x1, x2)
			z = hasard.randf_range(z1, z2)
		var refuse := false
		for e: Array in exclus:
			if Vector2(x, z).distance_to(Vector2(float(e[0]), float(e[1]))) < float(e[2]):
				refuse = true
				break
		if refuse:
			continue
		if hors_piste > 0.0 and ile.has_method("_distance_piste") and ile.call("_distance_piste", Vector2(x, z)) < hors_piste:
			continue
		var requete := PhysicsRayQueryParameters3D.create(Vector3(x, 400, z), Vector3(x, -50, z))
		var touche := espace.intersect_ray(requete)
		if touche.is_empty() or (touche["collider"] as Node).name != "CollisionSol":
			continue
		var pos: Vector3 = touche["position"]
		if pos.y < sol_min or pos.y > sol_max:
			continue
		var normale: Vector3 = touche["normal"]
		if 1.0 - normale.y > pente_max * 0.5:
			continue
		var k := hasard.randi() % liste.size()
		var s := hasard.randf_range(float(ech[0]), float(ech[1]))
		var base := Basis(Vector3.UP, hasard.randf() * TAU).scaled(Vector3.ONE * s)
		# Les objets suivent un peu la pente.
		var penche := Basis(Vector3.UP.cross(normale).normalized(), Vector3.UP.angle_to(normale) * 0.6) if normale.y < 0.999 else Basis.IDENTITY
		var t := Transform3D(penche * base, pos - Vector3(0, enfoui * s, 0)) * (liste[k][1] as Transform3D)
		var cle := Vector3i(k, floori(x / BLOC), floori(z / BLOC))
		if not par_bloc.has(cle):
			par_bloc[cle] = []
		(par_bloc[cle] as Array).append(t)
		poses += 1
	var ombre := bool(fiche.get("ombre", true))
	var distance := float(fiche.get("distance", 110.0))
	for cle: Vector3i in par_bloc:
		var transfos: Array = par_bloc[cle]
		var morceau: Array = liste[cle.x]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = morceau[0]
		multi.instance_count = transfos.size()
		for i in transfos.size():
			multi.set_instance_transform(i, transfos[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%d_%d" % [fiche.get("modele", ""), cle.y, cle.z]
		mmi.multimesh = multi
		if morceau[2] != null:
			mmi.material_override = morceau[2]
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ombre else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = distance
		mmi.visibility_range_end_margin = 10.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		parent.add_child(mmi)
	return poses
