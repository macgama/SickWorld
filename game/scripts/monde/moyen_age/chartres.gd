@tool
extends "res://scripts/monde/moyen_age/ile_moyen_age.gd"
## Île du Moyen Âge, zone 3 : Chartres, la ville basse et la butte (niveaux 54-57).
##
## La ville sur sa butte, quelques semaines après l'incendie du 10 juin 1194 :
## - à l'ouest, la route de Berchères arrive à la porte des Épars, dans les remparts ;
## - les rues montent, bordées de maisons à pans de bois, jusqu'à la place du marché ;
## - en haut de la butte, le parvis et la façade ouest de la cathédrale, qui a survécu (les
##   deux tours, le Portail royal, les trois grandes fenêtres) ; derrière, la nef brûlée,
##   fermée par la palissade du chantier (la zone suivante) ; l'Hôtel-Dieu et le cloître ;
## - à l'est, la ville basse descend jusqu'à l'Eure : maisons brûlées, l'atelier du verrier,
##   les cuves des teinturiers, le moulin à eau, le lavoir, la porte Guillaume et son pont ;
## - de l'autre côté de l'Eure, les tanneries et, au sud-est, la maladrerie du Grand-Beaulieu.
##
## Tout est construit par le code. Repères : le nord est vers -Z.

const Faille := preload("res://scripts/monde/prehistoire/faille.gd")
const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const ObjetMoyenAge := preload("res://scripts/monde/moyen_age/objet_moyen_age.gd")

## Le sommet de la butte (la cathédrale) et sa hauteur.
const BUTTE := Vector2(0, -105)
const HAUT_BUTTE := 18.0
const SOL_BAS := 2.2
## L'Eure : son axe ondule autour de x = 128 ; niveau de l'eau.
const EURE_X := 128.0
const NIVEAU_EURE := 0.7
const LARGEUR_EURE := 7.5

const ARRIVEE := Vector2(-168, 158)
const SORTIE_SO := Vector2(-184, 176)
const ROUTE_BERCHERES := [Vector2(-190, 182), Vector2(-160, 150), Vector2(-132, 96), Vector2(-112, 40), Vector2(-104, 30)]
const PORTE_EPARS := Vector2(-104, 30)
## Les rues (des lignes brisées) : la grand-rue monte de la porte des Épars au marché puis au
## parvis ; une autre descend du marché vers l'Eure et la porte Guillaume.
const GRAND_RUE := [Vector2(-104, 30), Vector2(-70, 14), Vector2(-40, -10), Vector2(-24, -24), Vector2(-40, -62), Vector2(-62, -96)]
const RUE_BASSE := [Vector2(-24, -24), Vector2(10, -20), Vector2(46, -14), Vector2(80, -24), Vector2(112, -40)]
const RUE_TEINTURIERS := [Vector2(46, -14), Vector2(70, 20), Vector2(96, 48), Vector2(112, 62)]
const PLACE := Vector2(-24, -24)
const PARVIS := Vector2(-62, -110)
const RECT_PARVIS := Rect2(-84, -132, 44, 44)
## La cathédrale : la façade ouest en x = -40, la nef brûlée vers l'est.
const FACADE_X := -40.0
const CATHEDRALE := Rect2(-40, -128, 92, 36)
const SORTIE_CHANTIER := Vector2(-42.5, -110)
const HOTEL_DIEU := Vector2(14, -64)
const CLOITRE := Rect2(-6, -158, 44, 22)
const ANSELME := Vector2(8, -146)
const CRAIE_CLOITRE := Vector2(26, -144)
## La ville basse.
const BRULEES := Rect2(58, -36, 44, 40)
const ATELIER_AUDE := Vector2(84, -14)
const AUDE := Vector2(86, -8)
const COFFRET := Vector2(82, -16)
const PILLARDS := Vector2(70, -2)
const CUVES := Vector2(98, 40)
const MOULIN_EAU := Vector2(0, 18)  # x calculé sur l'Eure
const LAVOIR := Vector2(0, 74)  # x calculé sur la rive ouest
const PONT_GUILLAUME := -40.0
const PONT_SUD := 64.0
const TANNERIE := Vector2(158, 6)
const GRAND_BEAULIEU := Vector2(166, 152)
## Les Las de la ville : la teinturière, le tanneur, le boulanger du marché.
const LAS_ARTISANS := [Vector2(102, 34), Vector2(154, 14), Vector2(-14, -16)]
## Le parvis, au chapitre 5.
const CARDINAL := Vector2(-48, -116)
const EVEQUE := Vector2(-48, -104)
const PLOMB := Vector2(-45, -110)
const LAS_FOULE := [Vector2(-66, -118), Vector2(-72, -104), Vector2(-58, -98)]
const FUMIGENES := [Vector2(-74, -122), Vector2(-78, -100), Vector2(-56, -126)]
const FAILLE := Vector2(176, -150)
## Les remparts (une ligne brisée, sans le côté de l'Eure).
const REMPARTS := [Vector2(112, 92), Vector2(30, 104), Vector2(-60, 96), Vector2(-104, 70), Vector2(-104, -150),
		Vector2(-60, -166), Vector2(60, -166), Vector2(108, -128)]

var _mur_chantier: StaticBody3D
var _roue_moulin: Node3D


func _init() -> void:
	identifiant_zone = "chartres"
	taille_terrain = 400
	graine = 1196
	point_apparition = ARRIVEE
	nombre_touffes = 14000
	fertilite_sols = Vector3(0.05, 0.3, 1.0)
	neige_qui_tombe = false
	sols = {
		# Rouge : la terre battue des rues et des places, pavée par endroits.
		"galets": ["brown_mud_02", "cobblestone_floor_04", "dry_ground_01"],
		# Vert : la cendre et la suie des quartiers brûlés.
		"neige": ["brown_mud_03", "dry_river_pebbles", "brown_mud_02"],
		# Bleu : les prés, les jardins, les berges.
		"sol": ["withered_grass", "brown_mud_02", "dry_ground_01"],
		"roche": ["quarry_wall", "quarry_wall_02", "white_sandstone_blocks_02"],
	}
	reglages_terrain = {"sol_saturation": 1.1, "sol_motif": 6.0, "galets_motif": 4.0, "neige_motif": 5.0,
			"sol_teinte": Color(0.64, 0.82, 0.44), "roche_teinte": Color(1.1, 1.02, 0.86), "roche_saturation": 0.75,
			"neige_eclat": 1.0, "neige_paillettes": 0.0, "roche_motif": 8.0,
			"neige_teinte": Color(0.42, 0.38, 0.36), "neige_max": Vector3(0.3, 0.28, 0.26), "neige_simple": Color(0.2, 0.19, 0.18),
			"givre": 0.0, "neige_translucide": 0.0}
	reglages_herbe = {"couleur_base": Color(0.18, 0.26, 0.1), "couleur_pointe": Color(0.56, 0.68, 0.3),
			"couleur_givre": Color(0.7, 0.68, 0.4), "force_vent": 0.4}
	reglages_couvre_sol = {"cailloux": 3.0, "fleurs": [Color(0.95, 0.92, 0.85), Color(0.9, 0.8, 0.2)], "densite_fleurs": 1.0,
			"buissons": 0.3, "litiere": 1.0}
	piste = ROUTE_BERCHERES.duplicate()


func _ready() -> void:
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_moyen_age", "") == "chantier":
		Reseau.remove_meta("arrivee_moyen_age")
		point_apparition = PARVIS + Vector2(-6, 0)
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	if zone == "bercheres":
		return SORTIE_SO
	if zone == "chantier":
		return SORTIE_CHANTIER
	return Vector2.INF


# --- Relief -----------------------------------------------------------------------------

func _preparer_bruits() -> void:
	super._preparer_bruits()
	_relief.frequency = 0.006


func _distance_ligne(p: Vector2, ligne: Array) -> float:
	var meilleure := INF
	for i in ligne.size() - 1:
		meilleure = minf(meilleure, _distance_segment(p, ligne[i], ligne[i + 1]))
	return meilleure


## L'axe de l'Eure à la hauteur « z ».
func axe_eure(z: float) -> float:
	return EURE_X + 6.0 * sin(z * 0.02)


## La distance au milieu de l'Eure.
func distance_eure(p: Vector2) -> float:
	return absf(p.x - axe_eure(p.y))


## Dans les remparts (approximatif : à l'ouest de l'Eure, entre les murs).
func dans_la_ville(p: Vector2) -> bool:
	return p.x > -104.0 and p.x < axe_eure(p.y) - 8.0 and p.y > -164.0 and p.y < 100.0


## Le relief sans les places aplanies : la butte, l'Eure.
func _relief_brut(x: float, z: float) -> float:
	var bruit := _relief.get_noise_2d(x, z)
	var p := Vector2(x, z)
	var h := SOL_BAS + bruit * 1.0
	h += HAUT_BUTTE * (1.0 - smoothstep(55.0, 175.0, p.distance_to(BUTTE)))
	var d_eure := distance_eure(p)
	h = lerpf(h, 1.6 + bruit * 0.2, 1.0 - smoothstep(12.0, 44.0, d_eure))
	h = lerpf(h, NIVEAU_EURE - 1.6, 1.0 - smoothstep(LARGEUR_EURE - 2.0, LARGEUR_EURE + 1.5, d_eure))
	return h


func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	var fin := _details.get_noise_2d(x * 3.0, z * 3.0)
	var p := Vector2(x, z)
	var h := _relief_brut(x, z) + fin * 0.08
	# Le parvis et la cathédrale : à plat, au sommet.
	var sommet := SOL_BAS + HAUT_BUTTE
	h = lerpf(h, sommet, maxf(_dans_rect(RECT_PARVIS, x, z, 10.0), _dans_rect(CATHEDRALE.grow(4.0), x, z, 8.0)))
	# La place du marché : à plat, à la hauteur de son centre.
	h = lerpf(h, _relief_brut(PLACE.x, PLACE.y) - 1.5, 1.0 - smoothstep(10.0, 34.0, p.distance_to(PLACE)))
	# Les rues, un peu creusées par les roues.
	var d_rue := minf(_distance_ligne(p, GRAND_RUE), minf(_distance_ligne(p, RUE_BASSE), _distance_ligne(p, RUE_TEINTURIERS)))
	d_rue = minf(d_rue, _distance_piste(p))
	h = lerpf(h, h - 0.08, 1.0 - smoothstep(2.0, 4.0, d_rue))
	return h


## Rouge : rues et places ; vert : cendre des quartiers brûlés ; bleu : prés et berges.
func _parts_sol(x: float, z: float, _h: float) -> Color:
	var p := Vector2(x, z)
	var d_rue := minf(_distance_ligne(p, GRAND_RUE), minf(_distance_ligne(p, RUE_BASSE), _distance_ligne(p, RUE_TEINTURIERS)))
	var rue := 1.0 - smoothstep(3.0, 5.0, minf(d_rue, _distance_piste(p)))
	rue = maxf(rue, 1.0 - smoothstep(16.0, 22.0, p.distance_to(PLACE)))
	rue = maxf(rue, _dans_rect(RECT_PARVIS, x, z, 4.0))
	rue = maxf(rue, _dans_rect(CATHEDRALE.grow(6.0), x, z, 4.0) * 0.7)
	if dans_la_ville(p):
		var n := _relief.get_noise_2d(x * 3.0, z * 3.0)
		rue = maxf(rue, smoothstep(0.0, 0.5, n) * 0.6)
	# Le lit de l'Eure : de la vase brune, des galets.
	rue = maxf(rue, 1.0 - smoothstep(LARGEUR_EURE, LARGEUR_EURE + 3.0, distance_eure(p)))
	var cendre := _dans_rect(BRULEES, x, z, 8.0) * (1.0 - rue)
	cendre = maxf(cendre, _dans_rect(CATHEDRALE.grow(10.0), x, z, 6.0) * 0.5)
	return Color(rue + 0.001, cendre, maxf(0.0, 1.0 - rue - cendre), 1.0)


# --- Construction -------------------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_construire_terrain()
	_construire_eure()
	_construire_remparts()
	_construire_cathedrale()
	_construire_haute_ville()
	_construire_maisons()
	_construire_ville_basse()
	_construire_faubourg()
	_construire_vegetation()
	_construire_touffes()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_appliquer_ciel()


## Un point à éviter quand on pose des maisons ou des arbres.
func _occupe(p: Vector2, marge := 4.0) -> bool:
	if RECT_PARVIS.grow(marge).has_point(p) or CATHEDRALE.grow(marge + 6.0).has_point(p) or CLOITRE.grow(marge).has_point(p):
		return true
	if p.distance_to(PLACE) < 18.0 + marge or p.distance_to(HOTEL_DIEU) < 14.0 + marge:
		return true
	if BRULEES.grow(marge).has_point(p) or p.distance_to(CUVES) < 10.0 + marge:
		return true
	if distance_eure(p) < 16.0 + marge:
		return true
	for l in [GRAND_RUE, RUE_BASSE, RUE_TEINTURIERS]:
		if _distance_ligne(p, l) < 4.0 + marge:
			return true
	for q: Vector2 in LAS_ARTISANS:
		if p.distance_to(q) < 4.0 + marge:
			return true
	return false


# --- L'Eure ------------------------------------------------------------------------------------

func _construire_eure() -> void:
	var plan := PlaneMesh.new()
	plan.size = Vector2(34, 420)
	plan.subdivide_width = 8
	plan.subdivide_depth = 120
	# Une eau simple (sans effet d'écran) : verte et sombre, un peu transparente, avec des
	# rides ; elle s'affiche pareil quel que soit le rendu choisi.
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.2, 0.16, 0.88)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.08
	m.metallic = 0.2
	m.metallic_specular = 0.8
	m.normal_enabled = true
	m.normal_texture = _texture_vagues(graine + 30, 0.04)
	m.normal_scale = 0.4
	m.uv1_scale = Vector3(4, 40, 1)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var eau := MeshInstance3D.new()
	eau.name = "Eure"
	eau.mesh = plan
	eau.material_override = m
	eau.position = Vector3(EURE_X, NIVEAU_EURE, 0)
	eau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_contenu.add_child(eau)
	var dossier := Node3D.new()
	dossier.name = "Ponts"
	_contenu.add_child(dossier)
	# Les deux ponts de pierre : le pont de la porte Guillaume et le pont du sud.
	for z: float in [PONT_GUILLAUME, PONT_SUD]:
		var x := axe_eure(z)
		_boite(Vector3(30.0, 0.4, 5.0), Vector3(x, 1.55, z), _mat_calcaire(), dossier)
		for cote: float in [-1.0, 1.0]:
			_boite(Vector3(30.0, 0.7, 0.4), Vector3(x, 2.1, z + cote * 2.3), _mat_calcaire(), dossier)
		for k in 3:
			_boite(Vector3(1.4, 2.4, 4.6), Vector3(x - 6.0 + k * 6.0, 0.35, z), _mat_calcaire(), dossier, false)
	# Des roseaux et des barques le long des berges.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 5
	var bois := _mat_colombage()
	for k in 5:
		var z := hasard.randf_range(-180.0, 180.0)
		if absf(z - PONT_GUILLAUME) < 12.0 or absf(z - PONT_SUD) < 12.0 or absf(z - MOULIN_EAU.y) < 14.0:
			continue
		var barque := _boite(Vector3(1.4, 0.4, 4.6), Vector3(axe_eure(z) - 5.0, NIVEAU_EURE + 0.1, z), bois, dossier, false)
		barque.rotation.y = hasard.randf_range(-0.3, 0.3)
	_fusionner(dossier)
	# Le moulin à eau, sur pilotis au bord de l'Eure : la roue (« RoueMoulin ») tourne.
	var x_moulin := axe_eure(MOULIN_EAU.y) - 9.0
	var moulin := _maison_pans_de_bois(_contenu, Vector2(x_moulin - 3.0, MOULIN_EAU.y), Vector3(6.0, 5.0, 9.0), PI / 2, false)
	moulin.name = "MoulinAEau"
	_roue_moulin = Node3D.new()
	_roue_moulin.name = "RoueMoulin"
	_roue_moulin.position = Vector3(x_moulin + 2.4, NIVEAU_EURE + 1.0, MOULIN_EAU.y)
	_contenu.add_child(_roue_moulin)
	for k in 12:
		var a := k * TAU / 12.0
		var pale := _boite(Vector3(0.1, 0.9, 1.4), Vector3(0, cos(a) * 2.2, sin(a) * 2.2), bois, _roue_moulin, false)
		pale.rotation.x = -a
	for k in 3:
		var rayon := _boite(Vector3(0.12, 4.4, 0.14), Vector3.ZERO, bois, _roue_moulin, false)
		rayon.rotation.x = k * PI / 3
	_boite(Vector3(1.6, 0.3, 0.3), Vector3(0, 0, 0), bois, _roue_moulin, false)


# --- Les remparts et les portes ------------------------------------------------------------------

func _construire_remparts() -> void:
	var dossier := Node3D.new()
	dossier.name = "Remparts"
	_contenu.add_child(dossier)
	var pierre := _mat_calcaire()
	var haut := 8.0
	for i in REMPARTS.size() - 1:
		var a: Vector2 = REMPARTS[i]
		var b: Vector2 = REMPARTS[i + 1]
		var longueur := a.distance_to(b)
		var morceaux := int(ceil(longueur / 8.0))
		for k in morceaux:
			var q := a.lerp(b, (k + 0.5) / morceaux)
			if q.distance_to(PORTE_EPARS) < 6.0:
				continue
			var y := hauteur(q.x, q.y)
			var mur := _boite(Vector3(longueur / morceaux + 0.3, haut + 3.0, 3.0), Vector3(q.x, y + haut * 0.5 - 1.5, q.y), pierre, dossier)
			mur.rotation.y = -(b - a).angle()
			# Les créneaux.
			for c in 2:
				var t := (k + 0.25 + c * 0.5) / morceaux
				var r := a.lerp(b, t)
				var merlon := _boite(Vector3(1.6, 1.0, 0.8), Vector3(r.x, y + haut + 0.0, r.y), pierre, dossier, false)
				merlon.rotation.y = mur.rotation.y
		# Une tour ronde à chaque angle.
		_tour_ronde(dossier, a, haut + 3.0, 4.2)
	_tour_ronde(dossier, REMPARTS[REMPARTS.size() - 1], haut + 3.0, 4.2)
	# La porte des Épars : deux tours, une voûte, une herse levée.
	for cote: float in [-1.0, 1.0]:
		_tour_ronde(dossier, PORTE_EPARS + Vector2(0, cote * 6.5), haut + 5.0, 4.0)
	var y := hauteur(PORTE_EPARS.x, PORTE_EPARS.y)
	_boite(Vector3(4.0, 4.0, 10.0), Vector3(PORTE_EPARS.x, y + haut + 1.0, PORTE_EPARS.y), pierre, dossier)
	_boite(Vector3(0.3, 1.2, 6.0), Vector3(PORTE_EPARS.x - 1.6, y + haut - 1.4, PORTE_EPARS.y), _mat_uni_ma(Color(0.2, 0.18, 0.16), 0.5), dossier, false)
	# La porte Guillaume, au bout du pont, sur la rive ouest de l'Eure.
	var g := Vector2(axe_eure(PONT_GUILLAUME) - 17.0, PONT_GUILLAUME)
	for cote: float in [-1.0, 1.0]:
		_tour_ronde(dossier, g + Vector2(0, cote * 6.0), haut + 6.0, 3.8)
	var yg := hauteur(g.x, g.y)
	_boite(Vector3(5.0, 5.0, 9.0), Vector3(g.x, yg + haut + 1.5, g.y), pierre, dossier)
	_fusionner(dossier)


func _tour_ronde(parent: Node3D, p: Vector2, haut: float, rayon: float) -> void:
	var y := hauteur(p.x, p.y)
	var tour := MeshInstance3D.new()
	tour.mesh = _cylindre(rayon, rayon * 1.08, haut + 2.0, 16)
	tour.material_override = _mat_calcaire()
	tour.position = Vector3(p.x, y + haut * 0.5 - 1.0, p.y)
	parent.add_child(tour)
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = rayon
	cyl.height = haut + 2.0
	forme.shape = cyl
	corps.add_child(forme)
	corps.position = tour.position
	parent.add_child(corps)
	var toit := MeshInstance3D.new()
	toit.mesh = _cylindre(0.1, rayon + 0.6, rayon * 1.6, 16)
	toit.material_override = _mat_tuiles_plates()
	toit.position = Vector3(p.x, y + haut + rayon * 0.8, p.y)
	parent.add_child(toit)


# --- La cathédrale : la façade qui a survécu, la nef brûlée -----------------------------------------

func _construire_cathedrale() -> void:
	var dossier := Node3D.new()
	dossier.name = "Cathedrale"
	_contenu.add_child(dossier)
	var pierre := _mat_calcaire()
	var noir := _mat_pierre_brulee()
	var sombre := _mat_uni_ma(Color(0.03, 0.03, 0.035), 1.0)
	var y := SOL_BAS + HAUT_BUTTE - 0.3
	var zc := CATHEDRALE.get_center().y
	# Les deux tours de la façade (le nord vers -z) : 14 m de côté.
	for cote: float in [-1.0, 1.0]:
		var zt := zc + cote * 13.0
		_boite(Vector3(14.0, 44.0, 12.0), Vector3(FACADE_X + 6.0, y + 22.0, zt), pierre, dossier)
		# Les contreforts d'angle.
		for c: float in [-1.0, 1.0]:
			_boite(Vector3(2.0, 36.0, 2.0), Vector3(FACADE_X - 1.0, y + 18.0, zt + c * 6.2), pierre, dossier)
		# Les baies hautes des tours.
		for k in 3:
			_boite(Vector3(0.2, 5.0, 1.4), Vector3(FACADE_X - 1.02, y + 16.0 + k * 9.0, zt), sombre, dossier, false)
	# Le clocher sud : la grande flèche de pierre octogonale (le « clocher vieux »).
	var fleche := MeshInstance3D.new()
	fleche.mesh = _cylindre(0.4, 6.6, 44.0, 8)
	fleche.material_override = pierre
	fleche.position = Vector3(FACADE_X + 6.0, y + 66.0, zc + 13.0)
	dossier.add_child(fleche)
	# Le clocher nord : une flèche de charpente couverte de plomb, plus basse.
	var nord := MeshInstance3D.new()
	nord.mesh = _cylindre(0.3, 6.0, 16.0, 4)
	nord.material_override = _mat_uni_ma(Color(0.42, 0.44, 0.48), 0.4)
	nord.position = Vector3(FACADE_X + 6.0, y + 52.0, zc - 13.0)
	nord.rotation.y = PI / 4
	dossier.add_child(nord)
	# Le corps central : le Portail royal (trois portes), les trois grandes fenêtres.
	_boite(Vector3(10.0, 30.0, 14.0), Vector3(FACADE_X + 5.0, y + 15.0, zc), pierre, dossier)
	for k in 3:
		var z := zc + (k - 1) * 4.2
		var large := 3.0 if k == 1 else 2.2
		_boite(Vector3(0.3, 6.0 if k == 1 else 5.0, large), Vector3(FACADE_X - 0.1, y + (3.0 if k == 1 else 2.5), z), sombre, dossier, false)
		# Les statues-colonnes, de part et d'autre de chaque porte.
		for c: float in [-1.0, 1.0]:
			for s in 2:
				var statue := MeshInstance3D.new()
				statue.mesh = _cylindre(0.22, 0.26, 3.2, 8)
				statue.material_override = pierre
				statue.position = Vector3(FACADE_X - 0.5, y + 2.4, z + c * (large * 0.5 + 0.35 + s * 0.5))
				dossier.add_child(statue)
		# Les trois fenêtres du XIIe siècle, qui ont survécu : du bleu de Chartres.
		var bleu := _mat_uni_ma(Color(0.1, 0.22, 0.6), 0.3)
		bleu.emission_enabled = true
		bleu.emission = Color(0.12, 0.26, 0.85)
		bleu.emission_energy_multiplier = 0.9
		_boite(Vector3(0.2, 9.0, 2.0), Vector3(FACADE_X - 0.05, y + 16.0, z), bleu, dossier, false)
	# Les marches du parvis.
	for k in 3:
		_boite(Vector3(2.0, 0.25 * (k + 1), 40.0), Vector3(FACADE_X - 2.0 - (2 - k) * 1.2, y + 0.3, zc), pierre, dossier)
	# La nef brûlée : des murs noircis, des piliers cassés, des poutres calcinées.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 11
	for cote: float in [-1.0, 1.0]:
		var z := zc + cote * 16.0
		for k in 9:
			var x := FACADE_X + 16.0 + k * 9.0
			var haut := hasard.randf_range(4.0, 14.0)
			_boite(Vector3(8.6, haut, 1.6), Vector3(x, y + haut * 0.5, z), noir if hasard.randf() < 0.5 else pierre, dossier)
			_boite(Vector3(1.8, haut + 2.0, 2.4), Vector3(x + 4.4, y + haut * 0.5 + 1.0, z + cote * 1.0), pierre, dossier)
	for k in 8:
		for cote: float in [-1.0, 1.0]:
			var pilier := MeshInstance3D.new()
			var haut := hasard.randf_range(2.0, 9.0)
			pilier.mesh = _cylindre(0.9, 1.0, haut, 10)
			pilier.material_override = noir
			pilier.position = Vector3(FACADE_X + 18.0 + k * 9.0, y + haut * 0.5, zc + cote * 7.0)
			dossier.add_child(pilier)
	for k in 14:
		var poutre := _boite(Vector3(0.5, 0.5, hasard.randf_range(5.0, 11.0)),
				Vector3(FACADE_X + hasard.randf_range(16.0, 88.0), y + 0.3, zc + hasard.randf_range(-12.0, 12.0)), noir, dossier, false)
		poutre.rotation = Vector3(hasard.randf_range(-0.3, 0.3), hasard.randf() * PI, hasard.randf_range(-0.2, 0.2))
	# La palissade du chantier, tout autour de la nef : on n'y entre que par le Portail royal.
	var bois := _mat_colombage()
	var r := CATHEDRALE.grow(6.0)
	r.position.x += 14.0
	r.size.x -= 14.0
	for seg in [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end], [r.end, Vector2(r.position.x, r.end.y)]]:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var n := int(a.distance_to(b) / 0.5)
		for k in n:
			var q := a.lerp(b, (k + 0.5) / n)
			_boite(Vector3(0.32, 3.0 + 0.4 * ((k * 7) % 3), 0.32), Vector3(q.x, hauteur(q.x, q.y) + 1.4, q.y), bois, dossier, false)
		var mur := _mur_invisible(dossier, Vector3(a.distance_to(b), 6.0, 0.8), Vector3((a.x + b.x) * 0.5, y + 3.0, (a.y + b.y) * 0.5))
		mur.rotation.y = -(b - a).angle()
	_fusionner(dossier)
	# La fumée qui monte encore de la nef.
	var fumee := StandardMaterial3D.new()
	fumee.albedo_color = Color(0.32, 0.3, 0.3, 0.22)
	fumee.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fumee.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for k in 3:
		var colonne := MeshInstance3D.new()
		colonne.mesh = _cylindre(14.0 + k * 4.0, 4.0, 90.0, 10)
		colonne.material_override = fumee
		colonne.position = Vector3(FACADE_X + 30.0 + k * 22.0, y + 50.0, zc + (k - 1) * 6.0)
		colonne.rotation.z = -0.2
		colonne.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(colonne)


# --- La haute ville : le parvis, la place du marché, l'Hôtel-Dieu, le cloître ------------------------

func _construire_haute_ville() -> void:
	var dossier := Node3D.new()
	dossier.name = "HauteVille"
	_contenu.add_child(dossier)
	var bois := _mat_colombage()
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 20
	# L'Hôtel-Dieu : une longue salle de pierre au toit de tuiles, et sa chapelle.
	var hd := Node3D.new()
	hd.name = "HotelDieu"
	hd.position = Vector3(HOTEL_DIEU.x, hauteur(HOTEL_DIEU.x, HOTEL_DIEU.y) - 0.3, HOTEL_DIEU.y)
	dossier.add_child(hd)
	_boite(Vector3(26.0, 8.0, 11.0), Vector3(0, 4.0, 0), _mat_calcaire(), hd)
	var toit := Node3D.new()
	toit.position = Vector3(0, 8.0, 0)
	toit.rotation.y = PI / 2
	hd.add_child(toit)
	_toit_pentu(toit, Vector3.ZERO, 11.0, 26.0, _mat_tuiles_plates(), _mat_calcaire(), 0.85, 0.2)
	var sombre := _mat_uni_ma(Color(0.04, 0.035, 0.04), 1.0)
	for k in 5:
		_boite(Vector3(0.9, 2.6, 0.1), Vector3(-10.0 + k * 5.0, 4.6, 5.52), sombre, hd, false)
	_boite(Vector3(1.6, 2.6, 0.1), Vector3(0, 1.3, 5.54), bois, hd, false)
	# Le cloître des chanoines : une cour fermée par des galeries à arcades.
	var c := CLOITRE
	var yc := hauteur(c.get_center().x, c.get_center().y)
	for seg in [[c.position, Vector2(c.end.x, c.position.y)], [Vector2(c.end.x, c.position.y), c.end],
			[Vector2(c.position.x, c.end.y), c.position]]:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var mur := _boite(Vector3(a.distance_to(b), 6.0, 1.2), Vector3((a.x + b.x) * 0.5, yc + 2.5, (a.y + b.y) * 0.5), _mat_calcaire(), dossier)
		mur.rotation.y = -(b - a).angle()
	# Côté sud, une galerie d'arcades ouverte (on y entre).
	var n := int(c.size.x / 3.0)
	for k in n + 1:
		var x := c.position.x + k * c.size.x / n
		var col := MeshInstance3D.new()
		col.mesh = _cylindre(0.22, 0.25, 3.0, 8)
		col.material_override = _mat_calcaire()
		col.position = Vector3(x, yc + 1.4, c.end.y)
		dossier.add_child(col)
	_boite(Vector3(c.size.x + 1.0, 0.6, 1.0), Vector3(c.get_center().x, yc + 3.1, c.end.y), _mat_calcaire(), dossier, false)
	_puits(dossier, c.get_center() + Vector2(4, 0))
	# La place du marché : les étals, les auvents de toile, une croix de pierre.
	for k in 10:
		var a := k * TAU / 10.0 + 0.3
		var q := PLACE + Vector2(cos(a), sin(a)) * 12.0
		if _distance_ligne(q, GRAND_RUE) < 3.5 or _distance_ligne(q, RUE_BASSE) < 3.5:
			continue
		_etal(dossier, q, -a + PI / 2, hasard)
	var croix := MeshInstance3D.new()
	croix.mesh = _cylindre(0.25, 0.35, 4.0, 8)
	croix.material_override = _mat_calcaire()
	croix.position = Vector3(PLACE.x, hauteur(PLACE.x, PLACE.y) + 2.0, PLACE.y)
	dossier.add_child(croix)
	_boite(Vector3(1.6, 0.3, 0.3), Vector3(PLACE.x, hauteur(PLACE.x, PLACE.y) + 3.4, PLACE.y), _mat_calcaire(), dossier, false)
	_boite(Vector3(2.4, 0.5, 2.4), Vector3(PLACE.x, hauteur(PLACE.x, PLACE.y) + 0.2, PLACE.y), _mat_calcaire(), dossier)
	# Sur le parvis : les réfugiés qui campent, des paniers, des braseros éteints.
	for k in 4:
		var q := PARVIS + Vector2(-16.0 + k * 3.0, 18.0 - (k % 2) * 3.0)
		_tente(dossier, q, hasard.randf() * PI, Color(0.62, 0.56, 0.46), 0.8)
	_fusionner(dossier)


## Un étal du marché : un auvent de toile de couleur sur quatre poteaux, une table, des
## paniers, des tonneaux ou des pains.
func _etal(parent: Node3D, q: Vector2, angle: float, hasard: RandomNumberGenerator) -> void:
	var m := Node3D.new()
	m.position = Vector3(q.x, hauteur(q.x, q.y), q.y)
	m.rotation.y = angle
	parent.add_child(m)
	var bois := _mat_colombage()
	for c in 4:
		var poteau := MeshInstance3D.new()
		poteau.mesh = _cylindre(0.06, 0.07, 2.4, 6)
		poteau.material_override = bois
		poteau.position = Vector3(-1.4 if c < 2 else 1.4, 1.2, -1.0 if c % 2 == 0 else 1.0)
		m.add_child(poteau)
	var toile: Color = TEINTURES[hasard.randi() % TEINTURES.size()].lerp(Color(0.85, 0.8, 0.7), 0.35)
	var auvent := _boite(Vector3(3.2, 0.06, 2.4), Vector3(0, 2.4, 0), _mat_uni_ma(toile, 1.0), m, false)
	auvent.rotation.x = 0.15
	_boite(Vector3(2.6, 0.9, 1.0), Vector3(0, 0.45, -0.4), bois, m)
	for k in 3:
		var panier := MeshInstance3D.new()
		panier.mesh = _cylindre(0.26, 0.2, 0.26, 10)
		panier.material_override = _mat_uni_ma([Color(0.86, 0.7, 0.36), Color(0.62, 0.14, 0.1), Color(0.4, 0.5, 0.2)][hasard.randi() % 3], 1.0)
		panier.position = Vector3(-0.8 + k * 0.8, 1.03, -0.4)
		m.add_child(panier)


# --- Les maisons de la ville -----------------------------------------------------------------------

func _construire_maisons() -> void:
	var dossier := Node3D.new()
	dossier.name = "Maisons"
	_contenu.add_child(dossier)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 30
	# Le long des rues, des deux côtés, tournées vers la rue.
	for rue in [GRAND_RUE, RUE_BASSE, RUE_TEINTURIERS]:
		for i in rue.size() - 1:
			var a: Vector2 = rue[i]
			var b: Vector2 = rue[i + 1]
			var dir := (b - a).normalized()
			var normale := Vector2(-dir.y, dir.x)
			var longueur := a.distance_to(b)
			var t := 6.0
			while t < longueur - 4.0:
				for cote: float in [-1.0, 1.0]:
					var largeur := hasard.randf_range(5.0, 6.5)
					var q := a + dir * t + normale * cote * (4.5 + largeur * 0.5)
					if not dans_la_ville(q) or _occupe_sauf_rues(q, 1.5) or _trop_pres(dossier, q, 6.0):
						continue
					var n := -normale * cote
					_maison_pans_de_bois(dossier, q, Vector3(largeur, hasard.randf_range(5.0, 7.0), hasard.randf_range(6.0, 8.0)),
							atan2(n.x, n.y), hasard.randf() < 0.2)
				t += hasard.randf_range(7.0, 9.0)
	# Et des maisons partout où il reste de la place dans les murs.
	var poses := 0
	var essais := 0
	while poses < 50 and essais < 2500:
		essais += 1
		var q := Vector2(hasard.randf_range(-96.0, 110.0), hasard.randf_range(-156.0, 92.0))
		if not dans_la_ville(q) or _occupe(q, 3.0) or _trop_pres(dossier, q, 10.0):
			continue
		_maison_pans_de_bois(dossier, q, Vector3(hasard.randf_range(5.0, 7.0), hasard.randf_range(4.6, 6.5), hasard.randf_range(6.0, 9.0)),
				(hasard.randi() % 4) * PI / 2 + hasard.randf_range(-0.15, 0.15), hasard.randf() < 0.35)
		poses += 1
	_fusionner(dossier)


func _occupe_sauf_rues(p: Vector2, marge: float) -> bool:
	if RECT_PARVIS.grow(marge).has_point(p) or CATHEDRALE.grow(marge + 6.0).has_point(p) or CLOITRE.grow(marge).has_point(p):
		return true
	if p.distance_to(PLACE) < 18.0 + marge or p.distance_to(HOTEL_DIEU) < 16.0 + marge:
		return true
	if BRULEES.grow(marge).has_point(p) or p.distance_to(CUVES) < 10.0 + marge or distance_eure(p) < 18.0:
		return true
	for q: Vector2 in LAS_ARTISANS:
		if p.distance_to(q) < 5.0:
			return true
	for l in [GRAND_RUE, RUE_BASSE, RUE_TEINTURIERS]:
		if _distance_ligne(p, l) < 4.2:
			return true
	return false


func _trop_pres(dossier: Node3D, q: Vector2, distance: float) -> bool:
	for n in dossier.get_children():
		if n is Node3D and Vector2((n as Node3D).position.x, (n as Node3D).position.z).distance_to(q) < distance:
			return true
	return false


# --- La ville basse : les maisons brûlées, l'atelier du verrier, les teinturiers, le lavoir ------------

## Une maison brûlée : les murs de pierre noircis, sans toit, des poutres tombées.
func _maison_brulee(parent: Node3D, q: Vector2, taille: Vector3, angle: float, hasard: RandomNumberGenerator) -> void:
	var m := Node3D.new()
	m.position = Vector3(q.x, hauteur(q.x, q.y) - 0.2, q.y)
	m.rotation.y = angle
	parent.add_child(m)
	var noir := _mat_pierre_brulee()
	var pierre := _mat_calcaire()
	for face in 4:
		var long_face := taille.z if face < 2 else taille.x
		var haut := hasard.randf_range(1.0, taille.y)
		var p := Vector3(taille.x * 0.5 * (1 if face == 0 else -1), haut * 0.5, 0) if face < 2 \
				else Vector3(0, haut * 0.5, taille.z * 0.5 * (1 if face == 2 else -1))
		if face == 2:
			# La façade : un trou de porte au milieu.
			for c: float in [-1.0, 1.0]:
				_boite(Vector3(long_face * 0.38, haut, 0.5), p + Vector3(c * long_face * 0.31, 0, 0), noir if c < 0 else pierre, m)
			continue
		_boite(Vector3(0.5, haut, long_face) if face < 2 else Vector3(long_face, haut, 0.5), p, noir if face % 2 == 0 else pierre, m)
	for k in 4:
		var poutre := _boite(Vector3(0.3, 0.3, taille.z * 0.8), Vector3(hasard.randf_range(-1.5, 1.5), 0.3 + k * 0.2, 0), noir, m, false)
		poutre.rotation = Vector3(hasard.randf_range(-0.4, 0.4), hasard.randf_range(-0.6, 0.6), 0)


func _construire_ville_basse() -> void:
	var dossier := Node3D.new()
	dossier.name = "VilleBasse"
	_contenu.add_child(dossier)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 40
	# Le quartier brûlé.
	var poses := 0
	var essais := 0
	var ruines: Array[Vector2] = []
	while poses < 9 and essais < 400:
		essais += 1
		var q := Vector2(hasard.randf_range(BRULEES.position.x + 4.0, BRULEES.end.x - 4.0), hasard.randf_range(BRULEES.position.y + 4.0, BRULEES.end.y - 4.0))
		var libre := q.distance_to(AUDE) > 6.0 and q.distance_to(PILLARDS) > 5.0 and _distance_ligne(q, RUE_BASSE) > 6.0
		for r in ruines:
			libre = libre and q.distance_to(r) > 9.0
		if not libre:
			continue
		ruines.append(q)
		_maison_brulee(dossier, q, Vector3(hasard.randf_range(5.0, 7.0), 4.0, hasard.randf_range(6.0, 8.0)), (hasard.randi() % 4) * PI / 2, hasard)
		poses += 1
	# L'atelier du verrier : les murs, le four éteint, des éclats de verre de couleur.
	_maison_brulee(dossier, ATELIER_AUDE + Vector2(-4, -4), Vector3(7.0, 3.0, 8.0), 0.0, hasard)
	var four := MeshInstance3D.new()
	four.mesh = _cylindre(1.0, 1.4, 1.8, 12)
	four.material_override = _mat_uni_ma(Color(0.36, 0.22, 0.16), 1.0)
	four.position = Vector3(ATELIER_AUDE.x + 2.0, hauteur(ATELIER_AUDE.x + 2.0, ATELIER_AUDE.y - 6.0) + 0.9, ATELIER_AUDE.y - 6.0)
	dossier.add_child(four)
	for k in 30:
		var eclat := _boite(Vector3(0.12, 0.01, 0.08), Vector3(ATELIER_AUDE.x + hasard.randf_range(-4.0, 4.0),
				hauteur(ATELIER_AUDE.x, ATELIER_AUDE.y) + 0.02, ATELIER_AUDE.y + hasard.randf_range(-4.0, 4.0)),
				_mat_uni_ma([Color(0.1, 0.2, 0.75), Color(0.7, 0.1, 0.08), Color(0.8, 0.6, 0.1), Color(0.1, 0.5, 0.2)][k % 4], 0.2), dossier, false)
		eclat.rotation.y = hasard.randf() * PI
	# Les cuves des teinturiers : bleu de guède, rouge de garance, jaune de gaude.
	var couleurs := [Color(0.08, 0.16, 0.5), Color(0.55, 0.08, 0.06), Color(0.75, 0.62, 0.12)]
	for k in 6:
		var q := CUVES + Vector2((k % 3) * 3.2 - 3.2, (k / 3) * 3.4 - 1.7)
		var y := hauteur(q.x, q.y)
		var cuve := MeshInstance3D.new()
		cuve.mesh = _cylindre(1.2, 1.1, 1.0, 14)
		cuve.material_override = _mat_colombage()
		cuve.position = Vector3(q.x, y + 0.5, q.y)
		dossier.add_child(cuve)
		var teinture := MeshInstance3D.new()
		teinture.mesh = _cylindre(1.08, 1.08, 0.05, 14)
		teinture.material_override = _mat_uni_ma(couleurs[k % 3], 0.15)
		teinture.position = Vector3(q.x, y + 0.92, q.y)
		dossier.add_child(teinture)
	# Des draps teints qui sèchent sur des perches.
	for k in 4:
		var q := CUVES + Vector2(-8.0, -6.0 + k * 4.0)
		var y := hauteur(q.x, q.y)
		_boite(Vector3(0.08, 0.08, 3.2), Vector3(q.x, y + 2.4, q.y), _mat_colombage(), dossier, false)
		_boite(Vector3(0.03, 1.8, 3.0), Vector3(q.x, y + 1.5, q.y), _mat_uni_ma(couleurs[k % 3].lightened(0.15), 1.0), dossier, false)
	# Le lavoir : un toit sur poteaux au bord de l'eau, des pierres plates inclinées.
	var xl := axe_eure(LAVOIR.y) - 11.0
	var yl := hauteur(xl, LAVOIR.y)
	for c in 4:
		_boite(Vector3(0.25, 3.0, 0.25), Vector3(xl + (-3.0 if c < 2 else 3.0), yl + 1.4, LAVOIR.y + (-5.0 if c % 2 == 0 else 5.0)), _mat_colombage(), dossier, false)
	var toit := Node3D.new()
	toit.position = Vector3(xl, yl + 2.9, LAVOIR.y)
	dossier.add_child(toit)
	_toit_pentu(toit, Vector3.ZERO, 6.4, 10.4, _mat_tuiles_plates(), _mat_colombage(), 0.5, 0.15)
	for k in 5:
		var pierre := _boite(Vector3(1.2, 0.2, 1.6), Vector3(xl + 4.2, yl + 0.1, LAVOIR.y - 4.0 + k * 2.0), _mat_calcaire(), dossier, false)
		pierre.rotation.z = 0.3
	_fusionner(dossier)


# --- De l'autre côté de l'Eure : les tanneries, le Grand-Beaulieu -----------------------------------

func _construire_faubourg() -> void:
	var dossier := Node3D.new()
	dossier.name = "Faubourg"
	_contenu.add_child(dossier)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 50
	# Les tanneries : des fosses, des peaux tendues sur des cadres, une cabane.
	_chaumiere(dossier, TANNERIE + Vector2(10, -6), Vector3(5.0, 2.6, 8.0), PI / 2)
	_maison_pans_de_bois(dossier, TANNERIE + Vector2(12, 14), Vector3(6.0, 5.0, 8.0), -PI / 2, true)
	var peau := _mat_uni_ma(Color(0.56, 0.4, 0.26), 1.0)
	for k in 5:
		var q := TANNERIE + Vector2(-2.0, -10.0 + k * 3.0)
		var y := hauteur(q.x, q.y)
		for c: float in [-1.0, 1.0]:
			_boite(Vector3(0.1, 2.2, 0.1), Vector3(q.x, y + 1.0, q.y + c * 1.0), _mat_colombage(), dossier, false)
		_boite(Vector3(0.05, 1.5, 1.8), Vector3(q.x, y + 1.2, q.y), peau, dossier, false)
	for k in 4:
		var q := TANNERIE + Vector2(-8.0 + (k % 2) * 3.0, -2.0 + (k / 2) * 3.0)
		var fosse := MeshInstance3D.new()
		fosse.mesh = _cylindre(1.1, 1.1, 0.1, 12)
		fosse.material_override = _mat_uni_ma(Color(0.24, 0.18, 0.1), 0.2)
		fosse.position = Vector3(q.x, hauteur(q.x, q.y) + 0.04, q.y)
		dossier.add_child(fosse)
	# Quelques maisons du faubourg, le long du chemin.
	for k in 6:
		var q := Vector2(170.0 + hasard.randf_range(-4.0, 6.0), -110.0 + k * 34.0)
		if q.distance_to(TANNERIE) < 16.0:
			continue
		_chaumiere(dossier, q, Vector3(5.0, 2.6, hasard.randf_range(6.0, 8.0)), PI / 2)
	# La maladrerie du Grand-Beaulieu : une chapelle, des cabanes, une haie et une croix.
	_eglise_village(dossier, GRAND_BEAULIEU, 0.0)
	for k in 4:
		_chaumiere(dossier, GRAND_BEAULIEU + Vector2(-16.0 + k * 8.0, 18.0), Vector3(4.0, 2.2, 5.0), 0.0)
	_haie(dossier, GRAND_BEAULIEU + Vector2(-24, -14), GRAND_BEAULIEU + Vector2(18, -14), hasard)
	_haie(dossier, GRAND_BEAULIEU + Vector2(-24, -14), GRAND_BEAULIEU + Vector2(-24, 28), hasard)
	_fusionner(dossier)


# --- Les arbres -----------------------------------------------------------------------------------

func _construire_vegetation() -> void:
	var arbres := Node3D.new()
	arbres.name = "Arbres"
	_contenu.add_child(arbres)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 60
	var plantes := 0
	var essais := 0
	while plantes < 90 and essais < 3000:
		essais += 1
		var p := Vector2(hasard.randf_range(-192.0, 192.0), hasard.randf_range(-192.0, 192.0))
		if dans_la_ville(p) and hasard.randf() < 0.85:
			continue
		if _occupe(p, 4.0) or _distance_piste(p) < 5.0 or p.distance_to(ARRIVEE) < 8.0 or p.distance_to(GRAND_BEAULIEU) < 26.0:
			continue
		if p.x > -108.0 and p.x < -100.0:
			continue
		var essence := "saule" if distance_eure(p) < 30.0 else ("chene" if hasard.randf() < 0.6 else "bouleau")
		_arbre_realiste(arbres, p, essence, hasard, hasard.randf_range(0.8, 1.2))
		plantes += 1


# --- Paysage lointain ----------------------------------------------------------------------

func _construire_lointain() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 70
	_plan_lointain_autour(1.8, Color(0.05, 0.4, 0.55))
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.8
	for m in [[Vector3(-1400, -10, 0), Vector3(900, 40, 1600)], [Vector3(300, -10, -1500), Vector3(1400, 50, 400)],
			[Vector3(1400, -10, 400), Vector3(600, 60, 1400)]]:
		bruit.seed = graine + hasard.randi()
		var bois := MeshInstance3D.new()
		bois.mesh = _maillage_bosse(bruit, m[1], 1.4, 0.3, 24, Color(0.2, 0.0, 0.6))
		bois.material_override = _mat_lointain()
		bois.position = m[0]
		bois.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(bois)


# --- Limites de la zone -----------------------------------------------------------------------

func _construire_limites() -> void:
	var limites := Node3D.new()
	limites.name = "Limites"
	_contenu.add_child(limites)
	var demi := taille_terrain * 0.5 - 4.0
	_mur_invisible(limites, Vector3(2, 120, taille_terrain), Vector3(-demi, 40, 0))
	_mur_invisible(limites, Vector3(2, 120, taille_terrain), Vector3(demi, 40, 0))
	_mur_invisible(limites, Vector3(taille_terrain, 120, 2), Vector3(0, 40, -demi))
	_mur_invisible(limites, Vector3(taille_terrain, 120, 2), Vector3(0, 40, demi))
	# Le Portail royal reste fermé tant que le chantier n'a pas commencé (chapitre 6).
	var y := SOL_BAS + HAUT_BUTTE
	_mur_chantier = _mur_invisible(limites, Vector3(1.0, 8.0, 14.0), Vector3(FACADE_X - 1.4, y + 3.0, CATHEDRALE.get_center().y))


# --- Personnages et objets de la quête ----------------------------------------------------------

func _objet(dossier: Node3D, id: String, p: Vector2, forme := "", invite := "", groupe := "", portee := 2.4) -> Node3D:
	var o := ObjetMoyenAge.new()
	o.name = id.to_pascal_case()
	o.identifiant = id
	o.forme = forme
	o.groupe = groupe
	o.invite = invite
	o.portee = portee
	o.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
	dossier.add_child(o)
	return o


func _las(dossier: Node3D, id_pnj: String, id_objet: String, groupe: String, p: Vector2, angle: float) -> void:
	_pnj(dossier, id_pnj, p, angle)
	var o := _objet(dossier, id_objet, p, "", "[F] Rendre courage (le vitrail)", groupe, 2.2)
	o.set_meta("pnj_lie", id_pnj)


func _pnj_cache(dossier: Node3D, id: String, p: Vector2, angle: float) -> Node3D:
	var n := _pnj(dossier, id, p, angle)
	n.add_to_group("decor_quete")
	n.set_meta("identifiant", id)
	n.visible = false
	return n


## La fumée grise de Plomb sur le parvis (chapitre 5) : des nappes basses, translucides.
func _construire_fumee_parvis(dossier: Node3D) -> void:
	var fumee := Node3D.new()
	fumee.name = "FumeePlomb"
	fumee.add_to_group("decor_quete")
	fumee.set_meta("identifiant", "fumee_plomb")
	fumee.visible = false
	dossier.add_child(fumee)
	var gris := StandardMaterial3D.new()
	gris.albedo_color = Color(0.5, 0.5, 0.52, 0.28)
	gris.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gris.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gris.cull_mode = BaseMaterial3D.CULL_DISABLED
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 90
	var y := SOL_BAS + HAUT_BUTTE
	for k in 14:
		var nappe := MeshInstance3D.new()
		nappe.mesh = _cylindre(hasard.randf_range(4.0, 7.0), hasard.randf_range(5.0, 8.0), hasard.randf_range(1.5, 3.0), 12)
		nappe.material_override = gris
		nappe.position = Vector3(PARVIS.x + hasard.randf_range(-16.0, 16.0), y + 1.0, PARVIS.y + hasard.randf_range(-16.0, 16.0))
		nappe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fumee.add_child(nappe)


func _construire_quete() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quete"
	_contenu.add_child(dossier)
	_dossier_quete = dossier
	# Chapitre 4 : Aude, les pillards, le coffret du verrier, les artisans Las, frère Anselme.
	_pnj(dossier, "aude", AUDE, PI * 0.8)
	_objet(dossier, "coffret_verrier", COFFRET, "coffret", "[F] Dégager le coffret du verrier des décombres", "", 2.4)
	var noms := ["las_teinturiere", "las_tanneur", "las_boulanger"]
	for k in LAS_ARTISANS.size():
		_las(dossier, noms[k], "courage_artisan_%d" % k, "las_artisan", LAS_ARTISANS[k], PI * (0.3 + k * 0.6))
	_pnj(dossier, "frere_anselme", ANSELME, PI * 0.1)
	var craie := _objet(dossier, "craie_cloitre", CRAIE_CLOITRE, "craie", "[F] Lire le message à la craie")
	craie.set_meta("texte_craie", "ELLE RÉPARE LES VITRAUX\nDE NOTRE TEMPS.\nELLE SE FAIT APPELER PLOMB.\n— M.")
	craie.rotation.y = PI
	# Chapitre 5 : le parvis, le cardinal, l'évêque, la foule, Plomb, les fumigènes.
	_pnj_cache(dossier, "cardinal_melior", CARDINAL, -PI / 2)
	_pnj_cache(dossier, "eveque_renaud", EVEQUE, -PI / 2)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 80
	for k in 10:
		var q := PARVIS + Vector2(-10.0 + (k % 5) * 4.0 + hasard.randf_range(-1.0, 1.0), -8.0 + (k / 5) * 16.0 + hasard.randf_range(-1.5, 1.5))
		_pnj_cache(dossier, "foule_parvis_%d" % (k + 1), q, PI / 2 + hasard.randf_range(-0.3, 0.3))
	for k in LAS_FOULE.size():
		_las(dossier, "las_foule_%d" % (k + 1), "courage_foule_%d" % k, "las_foule", LAS_FOULE[k], PI / 2)
	for k in FUMIGENES.size():
		var f := _objet(dossier, "fumigene_%d" % k, FUMIGENES[k], "fumigene", "[F] Étouffer le fumigène sous ton manteau", "fumigene")
		f.add_to_group("decor_quete")
		f.set_meta("identifiant", "fumigene_%d" % k)
		f.visible = false
	_construire_fumee_parvis(dossier)
	_pnj_cache(dossier, "plomb_masquee", PLOMB, -PI / 2)
	for r in [["batir_juste", "[F] « Bâtir, et rendre plus juste. »", Vector2(-2.6, -2.2)],
			["demander_editeur_plomb", "[F] « Qui t'a envoyée ici ? »", Vector2(-2.6, 2.2)]]:
		_objet(dossier, r[0], PLOMB + r[2], "", r[1], "", 1.8)
	var faille := Faille.new()
	faille.name = "Faille"
	faille.identifiant = "faille_chartres"
	faille.position = Vector3(FAILLE.x, hauteur(FAILLE.x, FAILLE.y), FAILLE.y)
	dossier.add_child(faille)
	_construire_secondaires(dossier)
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.LIEU, "Cathédrale (la façade)", Vector2(FACADE_X, CATHEDRALE.get_center().y))
	repere.call(MarqueurCarte.Type.LIEU, "Parvis", PARVIS)
	repere.call(MarqueurCarte.Type.LIEU, "Place du marché", PLACE)
	repere.call(MarqueurCarte.Type.LIEU, "Hôtel-Dieu", HOTEL_DIEU)
	repere.call(MarqueurCarte.Type.LIEU, "Cloître des chanoines", CLOITRE.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Porte des Épars", PORTE_EPARS)
	repere.call(MarqueurCarte.Type.LIEU, "Porte Guillaume", Vector2(axe_eure(PONT_GUILLAUME) - 17.0, PONT_GUILLAUME))
	repere.call(MarqueurCarte.Type.LIEU, "Atelier du verrier", ATELIER_AUDE)
	repere.call(MarqueurCarte.Type.LIEU, "Teinturiers", CUVES)
	repere.call(MarqueurCarte.Type.LIEU, "Tanneries", TANNERIE)
	repere.call(MarqueurCarte.Type.LIEU, "Grand-Beaulieu (maladrerie)", GRAND_BEAULIEU)
	repere.call(MarqueurCarte.Type.DANGER, "Faille", FAILLE)
	repere.call(MarqueurCarte.Type.LIEU, "Route de Berchères", SORTIE_SO)


func _construire_secondaires(_dossier: Node3D) -> void:
	pass


# --- Le moulin tourne, les sorties ------------------------------------------------------------------

var _attente := 0.0
var _chantier_ouvert := false


func _process(delta: float) -> void:
	super._process(delta)
	if _roue_moulin != null and is_instance_valid(_roue_moulin):
		_roue_moulin.rotation.x -= delta * 0.6
	if Engine.is_editor_hint():
		return
	_attente -= delta
	if _attente > 0.0:
		return
	_attente = 0.3
	var quete := get_tree().get_first_node_in_group("quete")
	if quete == null or not quete.has_method("etape_atteinte"):
		return
	if not _chantier_ouvert and quete.etape_atteinte("vers_chantier"):
		_chantier_ouvert = true
		if _mur_chantier != null and is_instance_valid(_mur_chantier):
			_mur_chantier.queue_free()
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return
	var p := Vector2(joueur.global_position.x, joueur.global_position.z)
	if p.distance_to(SORTIE_SO) < 7.0 and quete.donnees.get("zones", {}).has("bercheres"):
		Reseau.set_meta("arrivee_moyen_age", "chartres")
		quete.changer_de_zone("bercheres")
	elif _chantier_ouvert and p.distance_to(SORTIE_CHANTIER) < 2.5 and quete.donnees.get("zones", {}).has("chantier"):
		quete.changer_de_zone("chantier")
