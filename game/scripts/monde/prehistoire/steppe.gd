@tool
extends "res://scripts/monde/prehistoire/ile_prehistoire.gd"
## Île de la Préhistoire, zone 2 : la Steppe des Mammouths (niveaux 3-6).
##
## Une grande plaine d'herbe sèche, froide et venteuse, traversée par une rivière
## (un gué permet de la passer à pied). Des troupeaux de mammouths et de rennes y
## paissent. Le camp d'été du clan du Bison est installé au nord de la rivière.
## On y arrive par le col, au sud, depuis la Côte Gelée. La passe de l'est mène
## à la Forêt des Bouleaux.
##
## Tout est construit par le code au lancement (voir ile_prehistoire.gd).
## Repères : le nord est vers -Z, le col (Côte Gelée) au sud (+Z).

const Pnj := preload("res://scripts/monde/prehistoire/pnj_epoque.gd")
const ObjetQuete := preload("res://scripts/monde/prehistoire/objet_quete.gd")
const Mammouth := preload("res://scripts/monde/prehistoire/mammouth.gd")
const Grise := preload("res://scripts/monde/prehistoire/grise.gd")
const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const SHADER_MER := preload("res://shaders/prehistoire_mer.gdshader")

## Le col qui redescend vers la Côte Gelée.
const COL := Vector2(0, 170)
## La partie de chasse de Toran, juste après le col.
const CHASSE := Vector2(10, 124)
## Le gué : là, la rivière n'arrive qu'aux chevilles.
const GUE_X := 22.0
## Le camp d'été du clan du Bison.
const CAMP := Vector2(28, -58)
## La paroi où Aïna peint, au bord du camp.
const PAROI := Vector2(15, -71)
## Le vieux foyer des chasseurs (charbon).
const VIEUX_FOYER := Vector2(86, -86)
## Les rochers de pierre noire (manganèse), où rôdent des fracturés.
const MANGANESE := Vector2(-94, -106)
## Le troupeau de mammouths.
const HARDE := Vector2(-70, 78)
## Les rennes.
const RENNES := Vector2(48, 78)
## La passe de l'est, vers la Forêt des Bouleaux.
const PASSE_EST := Vector2(170, -30)

var _rivage: FastNoiseLite
var _feux: Array[OmniLight3D] = []


func _init() -> void:
	identifiant_zone = "steppe"
	taille_terrain = 360
	point_apparition = Vector2(0, 156)
	nombre_touffes = 140000
	neige_qui_tombe = false
	ciel = "table_mountain_1_puresky"
	sols = {
		"galets": ["brown_mud_02", "dry_river_pebbles"],
		"neige": ["snow_02", "snow_03"],
		"sol": ["withered_grass", "dry_ground_rocks"],
		"roche": ["cliff_side", "rock_wall_10", "rock_boulder_dry"],
	}
	reglages_terrain = {"sol_saturation": 0.75, "sol_motif": 5.0, "galets_motif": 3.5,
			"sol_teinte": Color(1.0, 0.97, 0.9), "roche_motif": 18.0}
	reglages_herbe = {"couleur_base": Color(0.2, 0.17, 0.08), "couleur_pointe": Color(0.72, 0.62, 0.38),
			"force_vent": 0.3}
	# La piste du clan : du col au gué, puis au camp.
	piste = [Vector2(0, 168), Vector2(6, 128), Vector2(14, 70), Vector2(20, 20), Vector2(GUE_X, -14),
			Vector2(26, -48)]


func _ready() -> void:
	# On arrive par la passe de l'est quand on revient de la Forêt des Bouleaux.
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_prehistoire", "") == "foret":
		Reseau.remove_meta("arrivee_prehistoire")
		point_apparition = PASSE_EST + Vector2(-16, 0)
	super._ready()


func _chaque_image(_delta: float) -> void:
	# Les feux du camp vacillent.
	for k in _feux.size():
		var feu := _feux[k]
		if is_instance_valid(feu):
			feu.light_energy = 3.2 + sin(_temps * 11.0 + k) * 0.4 + sin(_temps * 23.0 + k * 2.0) * 0.3
	if Engine.is_editor_hint():
		return
	_surveiller_col()


func sortie_vers(zone: String) -> Vector2:
	if zone == "cote_gelee":
		return COL + Vector2(0, -2)
	if zone == "foret":
		return PASSE_EST + Vector2(-6, 0)
	return Vector2.INF


# --- Relief ----------------------------------------------------------------

func _preparer_bruits() -> void:
	super._preparer_bruits()
	_relief.frequency = 0.006
	_rivage = FastNoiseLite.new()
	_rivage.seed = graine + 5
	_rivage.frequency = 0.015
	_rivage.fractal_octaves = 2


## Position (z) du milieu de la rivière pour une position x.
func riviere_z(x: float) -> float:
	if _rivage == null:
		_preparer_bruits()
	return -14.0 + sin(x * 0.021) * 15.0 + _rivage.get_noise_1d(x) * 6.0


## Distance (mètres) au milieu de la rivière.
func distance_riviere(x: float, z: float) -> float:
	return absf(z - riviere_z(x))


## Hauteur du sol (mètres) à une position x, z du monde.
func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	# Grande plaine aux ondulations douces, qui monte en collines vers le nord.
	var h := 4.0 + _relief.get_noise_2d(x, z) * 4.5 + absf(_details.get_noise_2d(x * 0.4, z * 0.4)) * 0.6
	h += smoothstep(-50.0, -150.0, z) * 7.0 + smoothstep(70.0, 150.0, z) * 5.0
	h += _details.get_noise_2d(x * 3.0, z * 3.0) * 0.06
	h = maxf(h, 1.4)
	# La rivière creuse son lit (peu profonde au gué).
	var gue := exp(-pow((x - GUE_X) / 6.0, 2.0))
	var fond := lerpf(-1.0, -0.3, gue)
	# La largeur et la pente des berges varient le long de la rivière.
	var largeur := 1.0 + _rivage.get_noise_1d(x * 1.7 + 100.0) * 0.45
	var douceur := 1.0 + absf(_rivage.get_noise_1d(x * 0.9 + 300.0)) * 1.4
	h = lerpf(fond, h, smoothstep(2.5 * largeur, (2.5 + 10.0 * douceur) * largeur + _details.get_noise_2d(x, z) * 2.0,
			distance_riviere(x, z)))
	# Montagnes tout autour, sauf le col au sud.
	var crete := 1.0 - absf(_relief.get_noise_2d(x * 3.0, z * 3.0 + 500.0))
	var passe := exp(-pow((z - PASSE_EST.y) / 13.0, 2.0)) if x > 0.0 else 0.0
	h += smoothstep(145.0, 172.0, absf(x) + _relief.get_noise_2d(z, 30.0) * 10.0) * (22.0 + crete * crete * 20.0) \
			* (1.0 - passe * 0.85)
	h += smoothstep(-138.0, -172.0, z + _relief.get_noise_2d(x, 60.0) * 10.0) * (24.0 + crete * crete * 24.0)
	var col := exp(-pow((x - COL.x) / 13.0, 2.0))
	h += smoothstep(150.0, 174.0, z) * (24.0 + crete * crete * 18.0) * (1.0 - col * 0.85)
	return h


## Part de chaque sol (berge, neige, herbe) à une position : rouge, vert, bleu.
func _parts_sol(x: float, z: float, h: float) -> Color:
	var n := _relief.get_noise_2d(x * 3.0 + 90.0, z * 3.0)
	var berge := 1.0 - smoothstep(6.0, 12.0, distance_riviere(x, z) + n * 4.0)
	var neige := smoothstep(11.0, 19.0, h + n * 4.0) + smoothstep(-120.0, -160.0, z) * 0.5
	# Le camp et la piste : la terre est piétinée.
	var camp := exp(-Vector2(x, z).distance_squared_to(CAMP) / 200.0)
	# Une piste discrète, interrompue par endroits (pas une route).
	var sur_piste := exp(-pow(_distance_piste(Vector2(x, z)) / 1.2, 2.0)) * smoothstep(-0.2, 0.3, _details.get_noise_2d(x * 0.3, z * 0.3))
	berge = maxf(berge, maxf(camp * 0.7, sur_piste * 0.3))
	return Color(berge, clampf(neige * (1.0 - berge), 0.0, 1.0), 1.0 - berge, 1.0)


# --- Construction ------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_feux.clear()
	_construire_terrain()
	_construire_riviere()
	_construire_rochers()
	_construire_touffes()
	_construire_vegetation()
	_construire_camp_du_clan()
	_construire_vieux_foyer()
	_construire_mammouths()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_appliquer_ciel()


func _construire_riviere() -> void:
	var plan := PlaneMesh.new()
	plan.size = Vector2(taille_terrain + 40, taille_terrain + 40)
	plan.subdivide_width = 90
	plan.subdivide_depth = 90
	var m := ShaderMaterial.new()
	m.shader = SHADER_MER
	m.set_shader_parameter("vagues_a", _texture_vagues(graine + 30, 0.04))
	m.set_shader_parameter("vagues_b", _texture_vagues(graine + 31, 0.09))
	m.set_shader_parameter("bruit_ecume", _bruit())
	m.set_shader_parameter("couleur_profonde", Color(0.03, 0.07, 0.07))
	m.set_shader_parameter("couleur_claire", Color(0.2, 0.3, 0.27))
	m.set_shader_parameter("transparence", 1.6)
	m.set_shader_parameter("largeur_ecume", 0.05)
	m.set_shader_parameter("vitesse", 0.05)
	m.set_shader_parameter("hauteur_houle", 0.02)
	var eau := MeshInstance3D.new()
	eau.name = "Riviere"
	eau.mesh = plan
	eau.material_override = m
	eau.position = Vector3(0, NIVEAU_MER - 0.05, 0)
	eau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_contenu.add_child(eau)


func _construire_rochers() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 12
	var dossier := Node3D.new()
	dossier.name = "Rochers"
	_contenu.add_child(dossier)
	_preparer_rochers()
	var degage := func(p: Vector2) -> bool:
		return p.distance_to(CAMP) > 20.0 and _distance_piste(p) > 5.0 and p.distance_to(CHASSE) > 10.0 \
				and p.distance_to(VIEUX_FOYER) > 5.0 and distance_riviere(p.x, p.y) > 4.0
	# Les rochers de pierre noire, au nord-ouest.
	for k in 22:
		var a := hasard.randf() * TAU
		var r := hasard.randf_range(4.0, 16.0)
		var p := MANGANESE + Vector2(cos(a), sin(a)) * r
		_placer_rocher(dossier, p.x, p.y, hasard.randf_range(1.5, 4.5), 0.3)
	# Blocs erratiques (déposés par les glaciers) : on s'en sert pour se repérer.
	for k in 14:
		var p := Vector2(hasard.randf_range(-140.0, 140.0), hasard.randf_range(-130.0, 140.0))
		if degage.call(p):
			_placer_rocher(dossier, p.x, p.y, hasard.randf_range(2.5, 5.0), 0.25)
	# Pierres éparses.
	var places := 0
	var essais := 0
	while places < 160 and essais < 2000:
		essais += 1
		var p := Vector2(hasard.randf_range(-150.0, 150.0), hasard.randf_range(-150.0, 150.0))
		if not degage.call(p):
			continue
		_placer_rocher(dossier, p.x, p.y, hasard.randf_range(0.3, 1.2))
		places += 1
	# Galets le long de la rivière.
	for k in 70:
		var x := hasard.randf_range(-150.0, 150.0)
		var cote := -1.0 if hasard.randf() < 0.5 else 1.0
		var z := riviere_z(x) + cote * hasard.randf_range(4.0, 8.0)
		if absf(x - GUE_X) > 8.0:
			_placer_rocher(dossier, x, z, hasard.randf_range(0.3, 0.9))


## Herbes hautes, buissons secs et arbustes (modèles Poly Haven), en plus des touffes.
func _construire_vegetation() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 40
	_semer("grass_medium_02", 9000, 0.7, 1.3, 60.0, hasard)
	_semer("grass_bermuda_01", 6000, 0.8, 1.4, 50.0, hasard)
	_semer("wild_rooibos_bush", 900, 0.6, 1.2, 140.0, hasard)
	# Arbustes isolés le long de la rivière (le feuillage jauni par le froid).
	for k in 26:
		var x := hasard.randf_range(-140.0, 140.0)
		var z := riviere_z(x) + (-1.0 if k % 2 == 0 else 1.0) * hasard.randf_range(9.0, 16.0)
		if Vector2(x, z).distance_to(CAMP) < 18.0 or absf(x - GUE_X) < 10.0:
			continue
		var arbuste := _modele("searsia_lucida", Vector3(x, hauteur(x, z) - 0.1, z), hasard.randf() * TAU,
				hasard.randf_range(0.8, 1.4))
		if arbuste != null:
			_teinter_feuillage(arbuste, Color(0.78, 0.56, 0.3))
	# Bois mort.
	for k in 20:
		var p := Vector2(hasard.randf_range(-130.0, 130.0), hasard.randf_range(-120.0, 130.0))
		if p.distance_to(CAMP) < 18.0 or distance_riviere(p.x, p.y) < 5.0:
			continue
		_modele(MODELES_BOIS[k % MODELES_BOIS.size()], Vector3(p.x, hauteur(p.x, p.y) - 0.1, p.y),
				hasard.randf() * TAU, hasard.randf_range(0.8, 1.3))


## Assombrit et jaunit le feuillage d'un modèle (verdure d'Afrique → arbuste de steppe froide).
func _teinter_feuillage(modele: Node3D, teinte: Color) -> void:
	for n in modele.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if m == null:
				continue
			var copie := m.duplicate() as StandardMaterial3D
			copie.albedo_color = copie.albedo_color * teinte
			mi.set_surface_override_material(s, copie)


## Sème un modèle Poly Haven par milliers (MultiMesh par carrés de 30 m, cachés au loin).
func _semer(id: String, nombre: int, echelle_min: float, echelle_max: float, portee: float,
		hasard: RandomNumberGenerator) -> void:
	var chemin := DOSSIER + "modeles/%s/%s.gltf" % [id, id]
	if not ResourceLoader.exists(chemin):
		return
	var scene := (load(chemin) as PackedScene).instantiate()
	var maillages: Array[MeshInstance3D] = []
	for n in scene.find_children("*", "MeshInstance3D", true, false):
		maillages.append(n)
	if maillages.is_empty():
		scene.free()
		return
	const BLOC := 30.0
	var demi := taille_terrain * 0.5 - 20.0
	var blocs := int(ceil(demi * 2.0 / BLOC))
	var par_bloc := int(nombre / float(blocs * blocs))
	for bj in blocs:
		for bi in blocs:
			var transformations: Array[Transform3D] = []
			for k in par_bloc:
				var x := -demi + (bi + hasard.randf()) * BLOC
				var z := -demi + (bj + hasard.randf()) * BLOC
				var y := hauteur(x, z)
				if y < NIVEAU_MER + 0.6 or y > 14.0:
					continue
				if _parts_sol(x, z, y).r > 0.4 or Vector2(x, z).distance_to(CAMP) < 14.0:
					continue
				transformations.append(Transform3D(Basis(Vector3.UP, hasard.randf() * TAU).scaled(
						Vector3.ONE * hasard.randf_range(echelle_min, echelle_max)), Vector3(x, y - 0.05, z)))
			if transformations.is_empty():
				continue
			for mi in maillages:
				var multi := MultiMesh.new()
				multi.transform_format = MultiMesh.TRANSFORM_3D
				multi.mesh = mi.mesh
				multi.instance_count = transformations.size()
				for k in transformations.size():
					multi.set_instance_transform(k, transformations[k] * mi.transform)
				var instance := MultiMeshInstance3D.new()
				instance.multimesh = multi
				instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				instance.visibility_range_end = portee
				instance.visibility_range_end_margin = 10.0
				instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				_contenu.add_child(instance)
	scene.free()


# --- Le camp d'été du clan du Bison -----------------------------------------------------

func _mat_peau() -> StandardMaterial3D:
	var m := _mat_pbr("brown_leather", Color(0.56, 0.52, 0.47), 0.95, 1.2)
	return m


func _cylindre(haut: float, bas: float, hauteur_c: float, segments := 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = haut
	c.bottom_radius = bas
	c.height = hauteur_c
	c.radial_segments = segments
	return c


func _construire_camp_du_clan() -> void:
	var camp := Node3D.new()
	camp.name = "CampDuClan"
	_contenu.add_child(camp)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 50
	var bois := _mat_pbr("rough_wood", Color(0.55, 0.45, 0.35), 0.9, 1.0)
	var os := _mat_pbr("", Color(0.68, 0.62, 0.5), 0.6)
	# Tentes en peaux, en cercle autour du grand foyer.
	var angles := [3.6, 4.4, 5.2, 0.2, 1.3, 2.4]
	for k in angles.size():
		var a: float = angles[k]
		var p := CAMP + Vector2(cos(a), sin(a)) * hasard.randf_range(10.5, 12.5)
		_tente(camp, p, a + PI / 2 + PI, hasard.randf_range(0.85, 1.15), bois)
	# Le grand foyer et les rondins où l'on s'assoit.
	_feu(camp, CAMP, 1.0)
	for k in 4:
		var a := k * TAU / 4.0 + 0.4
		var p := CAMP + Vector2(cos(a), sin(a)) * 3.2
		var rondin := MeshInstance3D.new()
		rondin.mesh = _cylindre(0.22, 0.24, 1.8, 10)
		rondin.material_override = bois
		rondin.position = Vector3(p.x, hauteur(p.x, p.y) + 0.2, p.y)
		rondin.rotation = Vector3(0, -a, PI / 2)
		camp.add_child(rondin)
	# Séchoirs à peaux.
	for k in 3:
		var a := 3.0 + k * 0.5
		var p := CAMP + Vector2(cos(a), sin(a)) * 6.5
		_sechoir(camp, p, a, bois)
	# L'entrée du camp : une arche de défenses de mammouth, tournée vers le gué.
	var entree := CAMP + Vector2(-1, 13)
	var arche := Node3D.new()
	arche.position = Vector3(entree.x, hauteur(entree.x, entree.y) - 0.2, entree.y)
	camp.add_child(arche)
	for cote in [-1.0, 1.0]:
		var precedent := Vector3(cote * 2.2, 0, 0)
		for k in 14:
			var u := (k + 1) / 14.0
			var point := Vector3(cote * 2.2 * (1.0 - u * 0.85), sin(u * PI * 0.55) * 3.3, sin(u * PI) * 0.6 - u * u * 0.3)
			var segment := MeshInstance3D.new()
			segment.mesh = _cylindre(0.13 * (1.0 - u * 0.6), 0.13 * (1.0 - (u - 1.0 / 14.0) * 0.6),
					precedent.distance_to(point) + 0.03, 8)
			segment.material_override = os
			arche.add_child(segment)
			segment.position = (precedent + point) * 0.5
			segment.basis = Basis(Quaternion(Vector3.UP, (point - precedent).normalized()))
			precedent = point
	# La paroi où Aïna peint, et la main peinte (elle apparaît à la fin du chapitre 3).
	var paroi := _modele("namaqualand_boulder_04", Vector3(PAROI.x, hauteur(PAROI.x, PAROI.y) - 0.6, PAROI.y), 0.3, 2.6, camp)
	if paroi == null:
		_placer_rocher(camp, PAROI.x, PAROI.y, 3.0, 0.2)
	else:
		# Ce bloc scanné est très orange : on le ramène vers un calcaire gris-beige.
		_teinter_feuillage(paroi, Color(0.7, 0.6, 0.55))
	var main := Decal.new()
	main.name = "MainPeinte"
	main.size = Vector3(1.4, 4.0, 1.4)
	main.texture_albedo = _texture_main()
	main.modulate = Color(0.75, 0.16, 0.06)
	main.position = Vector3(PAROI.x + 1.6, hauteur(PAROI.x, PAROI.y) + 1.6, PAROI.y + 1.6)
	# Le décalque projette vers le bas (-Y) : on le tourne vers la paroi.
	main.look_at_from_position(main.position, Vector3(PAROI.x, main.position.y, PAROI.y), Vector3.UP)
	main.rotate_object_local(Vector3.RIGHT, -PI / 2)
	main.add_to_group("decor_quete")
	main.set_meta("identifiant", "main_peinte")
	main.visible = false
	camp.add_child(main)
	# Des bois de rennes et des os empilés, des outils.
	for k in 5:
		var a := hasard.randf() * TAU
		var p := CAMP + Vector2(cos(a), sin(a)) * hasard.randf_range(5.0, 8.0)
		var tas := MeshInstance3D.new()
		tas.mesh = _cylindre(0.05, 0.07, 1.2, 6)
		tas.material_override = os
		tas.position = Vector3(p.x, hauteur(p.x, p.y) + 0.06, p.y)
		tas.rotation = Vector3(hasard.randf_range(1.3, 1.6), hasard.randf() * TAU, 0)
		camp.add_child(tas)


## Une tente conique en peaux cousues sur des perches.
func _tente(parent: Node3D, p: Vector2, angle: float, taille: float, bois: Material) -> void:
	var tente := Node3D.new()
	tente.position = Vector3(p.x, hauteur(p.x, p.y) - 0.15, p.y)
	tente.rotation.y = angle
	tente.scale = Vector3.ONE * taille
	parent.add_child(tente)
	var toile := MeshInstance3D.new()
	toile.mesh = _cylindre(0.25, 2.5, 3.8, 16)
	toile.material_override = _mat_peau()
	toile.position.y = 1.9
	tente.add_child(toile)
	# Perches qui dépassent du sommet.
	for k in 7:
		var a := k * TAU / 7.0
		var perche := MeshInstance3D.new()
		perche.mesh = _cylindre(0.035, 0.05, 4.9, 6)
		perche.material_override = bois
		perche.position = Vector3(cos(a) * 1.1, 2.4, sin(a) * 1.1)
		perche.rotation = Vector3(sin(a) * 0.55, 0, -cos(a) * 0.55)
		tente.add_child(perche)
	# Ouverture sombre côté feu.
	var porte := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 1.4)
	porte.mesh = quad
	var noir := StandardMaterial3D.new()
	noir.albedo_color = Color(0.03, 0.025, 0.02)
	porte.material_override = noir
	porte.position = Vector3(0, 0.7, -1.95)
	porte.rotation.x = -0.58
	porte.rotation.y = PI
	tente.add_child(porte)
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 2.0
	cyl.height = 3.0
	forme.shape = cyl
	forme.position.y = 1.5
	corps.add_child(forme)
	tente.add_child(corps)


## Un séchoir : deux montants, une traverse, une peau tendue.
func _sechoir(parent: Node3D, p: Vector2, angle: float, bois: Material) -> void:
	var s := Node3D.new()
	s.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
	s.rotation.y = angle
	parent.add_child(s)
	for cote in [-1.0, 1.0]:
		var montant := MeshInstance3D.new()
		montant.mesh = _cylindre(0.04, 0.05, 2.0, 6)
		montant.material_override = bois
		montant.position = Vector3(cote * 1.0, 1.0, 0)
		s.add_child(montant)
	var traverse := MeshInstance3D.new()
	traverse.mesh = _cylindre(0.035, 0.035, 2.3, 6)
	traverse.material_override = bois
	traverse.position.y = 1.9
	traverse.rotation.z = PI / 2
	s.add_child(traverse)
	var peau := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(1.6, 1.2, 0.02)
	peau.mesh = b
	peau.material_override = _mat_pbr("brown_leather", Color(0.62, 0.48, 0.34), 0.9, 1.5)
	peau.position = Vector3(0, 1.3, 0)
	peau.rotation.x = 0.06
	s.add_child(peau)


## Un feu de camp : pierres, braises, flammes et lumière qui vacille.
func _feu(parent: Node3D, p: Vector2, taille: float) -> void:
	var feu := Node3D.new()
	feu.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
	parent.add_child(feu)
	var pierre := _mat_pbr("rock_boulder_dry", Color(0.6, 0.58, 0.55), 0.9, 0.6)
	for k in 9:
		var a := k * TAU / 9.0
		var caillou := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.22 * taille
		sphere.height = 0.3 * taille
		caillou.mesh = sphere
		caillou.material_override = pierre
		caillou.position = Vector3(cos(a), 0.05, sin(a)) * 0.9 * taille
		feu.add_child(caillou)
	var braise := _lumineux(Color(1.0, 0.35, 0.08), 2.5)
	for k in 4:
		var buche := MeshInstance3D.new()
		buche.mesh = _cylindre(0.07, 0.08, 1.1 * taille, 6)
		buche.material_override = _mat_pbr("", Color(0.12, 0.09, 0.07), 0.95)
		buche.position.y = 0.25 * taille
		buche.rotation = Vector3(1.1, k * PI / 2, 0)
		feu.add_child(buche)
	var coeur := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35 * taille
	sphere.height = 0.2 * taille
	coeur.mesh = sphere
	coeur.material_override = braise
	coeur.position.y = 0.05
	feu.add_child(coeur)
	var lumiere := OmniLight3D.new()
	lumiere.light_color = Color(1.0, 0.6, 0.3)
	lumiere.light_energy = 3.2
	lumiere.omni_range = 12.0 * taille
	lumiere.shadow_enabled = true
	lumiere.position.y = 1.0
	lumiere.add_to_group("lumiere_secondaire")
	feu.add_child(lumiere)
	_feux.append(lumiere)
	if DisplayServer.get_name() == "headless":
		return
	var flammes := GPUParticles3D.new()
	flammes.amount = 60
	flammes.lifetime = 0.9
	var processus := ParticleProcessMaterial.new()
	processus.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	processus.emission_sphere_radius = 0.3 * taille
	processus.direction = Vector3.UP
	processus.spread = 12.0
	processus.initial_velocity_min = 0.8
	processus.initial_velocity_max = 1.6
	processus.gravity = Vector3(0, 0.6, 0)
	processus.scale_min = 0.6
	processus.scale_max = 1.2
	var courbe := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0, 0.6))
	c.add_point(Vector2(0.3, 1.0))
	c.add_point(Vector2(1, 0))
	courbe.curve = c
	processus.scale_curve = courbe
	var degrade := Gradient.new()
	degrade.set_color(0, Color(1.0, 0.85, 0.4, 1))
	degrade.set_color(1, Color(0.9, 0.2, 0.02, 0))
	var couleurs := GradientTexture1D.new()
	couleurs.gradient = degrade
	processus.color_ramp = couleurs
	flammes.process_material = processus
	var quad := QuadMesh.new()
	quad.size = Vector2(0.45, 0.6) * taille
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = _texture_flamme()
	quad.material = m
	flammes.draw_pass_1 = quad
	flammes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flammes.position.y = 0.2
	feu.add_child(flammes)


func _texture_flamme() -> Texture2D:
	if _materiaux.has("tex_flamme"):
		return _materiaux["tex_flamme"]
	var t := GradientTexture2D.new()
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.6)
	t.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	t.gradient = g
	_materiaux["tex_flamme"] = t
	return t


## Une main négative soufflée à l'ocre (comme dans les vraies grottes ornées).
func _texture_main() -> Texture2D:
	var taille_img := 256
	var image := Image.create(taille_img, taille_img, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 7
	# La paume et les doigts (positions sur l'image, de 0 à 1).
	var doigts := [[Vector2(0.30, 0.42), Vector2(0.18, 0.22)], [Vector2(0.42, 0.36), Vector2(0.38, 0.08)],
			[Vector2(0.52, 0.35), Vector2(0.53, 0.05)], [Vector2(0.61, 0.38), Vector2(0.67, 0.1)],
			[Vector2(0.66, 0.5), Vector2(0.84, 0.36)]]
	var dans_main := func(u: Vector2) -> bool:
		if Vector2((u.x - 0.48) / 0.2, (u.y - 0.58) / 0.22).length() < 1.0:
			return true
		if u.y > 0.62 and u.y < 0.95 and absf(u.x - 0.48) < 0.13:
			return true
		for d in doigts:
			var a: Vector2 = d[0]
			var b: Vector2 = d[1]
			var t := clampf((u - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
			if u.distance_to(a + (b - a) * t) < 0.045:
				return true
		return false
	for j in taille_img:
		for i in taille_img:
			var u := Vector2(i, j) / taille_img
			var centre := u.distance_to(Vector2(0.5, 0.5))
			# Pigment soufflé autour de la main, qui s'estompe vers les bords.
			var alpha := clampf(1.0 - centre * 2.1, 0.0, 1.0) * (0.75 + hasard.randf() * 0.25)
			if dans_main.call(u):
				alpha *= 0.05
			image.set_pixel(i, j, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)


# --- Le vieux foyer des chasseurs (charbon) ---------------------------------------------

func _construire_vieux_foyer() -> void:
	var foyer := Node3D.new()
	foyer.name = "VieuxFoyer"
	foyer.position = Vector3(VIEUX_FOYER.x, hauteur(VIEUX_FOYER.x, VIEUX_FOYER.y), VIEUX_FOYER.y)
	_contenu.add_child(foyer)
	var pierre := _mat_pbr("rock_boulder_dry", Color(0.45, 0.43, 0.4), 0.95, 0.6)
	for k in 8:
		var a := k * TAU / 8.0
		var caillou := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.28
		sphere.height = 0.35
		caillou.mesh = sphere
		caillou.material_override = pierre
		caillou.position = Vector3(cos(a), 0.05, sin(a)) * 1.3
		foyer.add_child(caillou)
	var cendre := MeshInstance3D.new()
	var disque := CylinderMesh.new()
	disque.top_radius = 1.2
	disque.bottom_radius = 1.3
	disque.height = 0.05
	cendre.mesh = disque
	cendre.material_override = _mat_pbr("", Color(0.16, 0.15, 0.14), 1.0)
	foyer.add_child(cendre)
	# Des os rongés et une lance brisée oubliée là.
	var os := _mat_pbr("", Color(0.8, 0.75, 0.64), 0.7)
	for k in 4:
		var o := MeshInstance3D.new()
		o.mesh = _cylindre(0.04, 0.05, 0.6, 6)
		o.material_override = os
		o.position = Vector3(2.0 + k * 0.3, 0.05, -0.5 + k * 0.4)
		o.rotation = Vector3(PI / 2, k, 0)
		foyer.add_child(o)


# --- Les mammouths ---------------------------------------------------------------------------

func _construire_mammouths() -> void:
	var troupeau := Node3D.new()
	troupeau.name = "Mammouths"
	_contenu.add_child(troupeau)
	var tailles := [1.0, 1.15, 0.95, 1.05, 0.55, 0.6]
	for k in tailles.size():
		var m := Mammouth.new()
		m.name = "Mammouth%d" % k
		m.centre = HARDE
		m.rayon = 32.0
		m.taille = tailles[k]
		m.graine = graine + k * 13
		var a := k * TAU / tailles.size()
		var p := HARDE + Vector2(cos(a), sin(a)) * 12.0
		m.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
		m.rotation.y = a
		troupeau.add_child(m)


# --- Paysage lointain ---------------------------------------------------------------

func _construire_lointain() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 70
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.8
	bruit.fractal_octaves = 4
	# Une couronne de montagnes enneigées tout autour de la steppe.
	for k in 16:
		bruit.seed = graine + 200 + k
		var a := k * TAU / 16.0 + hasard.randf_range(-0.1, 0.1)
		var distance := hasard.randf_range(380.0, 470.0)
		var largeur := hasard.randf_range(160.0, 260.0)
		var montagne := MeshInstance3D.new()
		montagne.mesh = _maillage_bosse(bruit, Vector3(largeur, hasard.randf_range(70.0, 150.0), largeur * 0.6),
				1.4, 0.35, 28, Color(0, 0.7, 0.3))
		montagne.material_override = _mat_lointain()
		montagne.position = Vector3(cos(a) * distance, -8.0, sin(a) * distance)
		montagne.rotation.y = -a + PI / 2
		montagne.set_instance_shader_parameter("neige_en_plus", 0.8)
		montagne.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(montagne)


# --- Limites de la zone ---------------------------------------------------------------

func _construire_limites() -> void:
	var limites := Node3D.new()
	limites.name = "Limites"
	_contenu.add_child(limites)
	var mur := func(taille: Vector3, centre: Vector3) -> void:
		var corps := StaticBody3D.new()
		corps.position = centre
		var forme := CollisionShape3D.new()
		var boite := BoxShape3D.new()
		boite.size = taille
		forme.shape = boite
		corps.add_child(forme)
		limites.add_child(corps)
	var demi := taille_terrain * 0.5 - 6.0
	mur.call(Vector3(2, 140, taille_terrain), Vector3(-demi, 40, 0))
	mur.call(Vector3(2, 140, taille_terrain), Vector3(demi, 40, 0))
	mur.call(Vector3(taille_terrain, 140, 2), Vector3(0, 40, -demi))
	mur.call(Vector3(taille_terrain, 140, 2), Vector3(0, 40, demi))


# --- Personnages et objets de la quête ------------------------------------------------

func _construire_quete() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quete"
	_contenu.add_child(dossier)
	var pnj := func(id: String, nom_noeud: String, p: Vector2, angle: float) -> void:
		var n := Pnj.new()
		n.name = nom_noeud
		n.identifiant = id
		n.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
		n.rotation.y = angle
		dossier.add_child(n)
	# La partie de chasse, au débouché du col.
	pnj.call("toran", "Toran", CHASSE, 0.0)
	pnj.call("chasseur_ulm", "Ulm", CHASSE + Vector2(-3.5, 2.5), 0.4)
	pnj.call("chasseuse_naya", "Naya", CHASSE + Vector2(3.5, 2.0), -0.4)
	# Au camp d'été.
	pnj.call("aina", "Aina", CAMP + Vector2(-4, 3), -0.9)
	pnj.call("vieille_mere", "VieilleMere", CAMP + Vector2(4.5, -3), 2.2)
	# Kéo, de retour au camp à la fin du chapitre 4 (caché jusque-là).
	pnj.call("keo", "KeoCamp", CAMP + Vector2(-6, -6), 0.6)
	var keo := dossier.get_node("KeoCamp")
	keo.add_to_group("decor_quete")
	keo.set_meta("identifiant", "keo_camp")
	keo.visible = false
	# Grise, guérie, couchée près de lui (si le joueur l'a soignée).
	var grise := Grise.new()
	grise.name = "GriseCamp"
	grise.contaminee = false
	var pg := CAMP + Vector2(-4.5, -7.5)
	grise.position = Vector3(pg.x, hauteur(pg.x, pg.y), pg.y)
	grise.add_to_group("decor_quete")
	grise.set_meta("identifiant", "grise_camp")
	grise.visible = false
	dossier.add_child(grise)
	# L'ocre rouge, sur la berge nord, à l'ouest du gué.
	var k := 0
	for x in [-14.0, -36.0, -58.0]:
		var z := riviere_z(x) - 9.0
		_objet(dossier, "Ocre%d" % k, "ocre", "ocre", "[F] Récolter l'ocre rouge", Vector2(x, z))
		_placer_rocher(dossier, x - 1.2, z - 1.0, 1.1, 0.4)
		k += 1
	_objet(dossier, "Charbon", "charbon", "charbon", "[F] Prendre du charbon", VIEUX_FOYER)
	_objet(dossier, "Manganese0", "manganese", "manganese", "[F] Détacher la pierre noire", MANGANESE + Vector2(-3, 6))
	_objet(dossier, "Manganese1", "manganese", "manganese", "[F] Détacher la pierre noire", MANGANESE + Vector2(7, -2))
	# Repères de la carte.
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.LIEU, "Camp d'été du clan du Bison", CAMP)
	repere.call(MarqueurCarte.Type.LIEU, "Col (vers la Côte Gelée)", COL + Vector2(0, -4))
	repere.call(MarqueurCarte.Type.LIEU, "Passe de l'est (vers la Forêt des Bouleaux)", PASSE_EST + Vector2(-10, 0))
	repere.call(MarqueurCarte.Type.LIEU, "Le gué", Vector2(GUE_X, riviere_z(GUE_X)))
	repere.call(MarqueurCarte.Type.LIEU, "Troupeau de mammouths", HARDE)
	repere.call(MarqueurCarte.Type.LIEU, "Rennes", RENNES)
	repere.call(MarqueurCarte.Type.LIEU, "Vieux foyer", VIEUX_FOYER)
	repere.call(MarqueurCarte.Type.DANGER, "Rochers de pierre noire", MANGANESE)
	repere.call(MarqueurCarte.Type.DANGER, "Loups", Vector2(-112, -30))
	repere.call(MarqueurCarte.Type.DANGER, "Loups", Vector2(112, 36))


func _objet(parent: Node3D, nom_noeud: String, groupe_r: String, forme_o: String, texte: String, p: Vector2) -> void:
	var o := ObjetQuete.new()
	o.name = nom_noeud
	o.identifiant = nom_noeud.to_lower()
	o.groupe = groupe_r
	o.forme = forme_o
	o.invite = texte
	o.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
	parent.add_child(o)


# --- Retour vers la Côte Gelée ------------------------------------------------------------

func _surveiller_col() -> void:
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return
	var p := Vector2(joueur.global_position.x, joueur.global_position.z)
	var quete := get_tree().get_first_node_in_group("quete")
	if quete == null or not quete.has_method("changer_de_zone"):
		return
	if p.y > COL.y and absf(p.x - COL.x) < 16.0:
		quete.changer_de_zone("cote_gelee")
	elif p.x > PASSE_EST.x - 4.0 and absf(p.y - PASSE_EST.y) < 16.0:
		quete.changer_de_zone("foret")
