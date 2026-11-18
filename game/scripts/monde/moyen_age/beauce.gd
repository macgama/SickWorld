@tool
extends "res://scripts/monde/moyen_age/ile_moyen_age.gd"
## Île du Moyen Âge, zone 1 : la Beauce (niveaux 50-52).
##
## L'été 1194, quelques semaines après l'incendie de Chartres. Une immense plaine de blé mûr
## sous un grand ciel ; au milieu, un village (l'église et son clocher, le puits, des maisons
## à pans de bois et des chaumières) ; la ferme de Guillot le charretier au sud de la route ;
## un moulin à vent sur sa butte au nord-ouest ; le gibet sur une butte au nord-est, où
## campent des routiers. La route file vers le nord-est : au bout, on voit les deux tours de
## Chartres qui fument encore. Le portail de la Vigie s'est ouvert dans un vieux dolmen, au
## bord d'un champ, au sud-ouest.
##
## Tout est construit par le code (voir ile_moyen_age.gd). Le bouton « Reconstruire » de
## l'Inspecteur refait tout. Repères : le nord est vers -Z.

const Faille := preload("res://scripts/monde/prehistoire/faille.gd")
const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const ObjetMoyenAge := preload("res://scripts/monde/moyen_age/objet_moyen_age.gd")
const ApparenceMonture := preload("res://scripts/joueur/apparence_monture.gd")
const Monture := preload("res://scripts/joueur/monture.gd")

## Le dolmen du portail, au sud-ouest, et ce qu'on trouve autour.
const DOLMEN := Vector2(-112, 116)
const PORTAIL := Vector2(-110, 108)
const RADIO := Vector2(-104.5, 105)
const CRAIE := Vector2(-117, 106)
## Le chemin du dolmen jusqu'à la route.
const SENTIER := [Vector2(-110, 104), Vector2(-96, 84), Vector2(-80, 66), Vector2(-70, 50)]
## La grande route de Chartres, du sud-ouest (Orléans) au nord-est (Chartres).
const ROUTE := [Vector2(-170, 30), Vector2(-110, 42), Vector2(-60, 44), Vector2(-10, 24), Vector2(40, -2),
		Vector2(90, -36), Vector2(130, -56), Vector2(170, -70)]
## La ferme de Guillot (cour fermée de murets), au sud de la route.
const FERME := Rect2(-92, 54, 22, 18)
const GUILLOT := Vector2(-64, 58)
## Le champ de Guillot, à l'est de la ferme : la bande moissonnée au nord, le blé debout au sud.
const CHAMP_GUILLOT := Rect2(-58, 66, 56, 40)
const MOISSON := Rect2(-58, 56, 56, 10)
const LAS_MOISSON := [Vector2(-46, 60), Vector2(-30, 62), Vector2(-14, 59)]
const LOUPS_MOISSON := Vector2(-24, 84)
## Les autres champs (blé mûr) et les prés.
const CHAMPS := [Rect2(-165, -40, 70, 60), Rect2(10, 30, 70, 46), Rect2(-60, -70, 60, 50), Rect2(96, 10, 60, 50),
		Rect2(-165, 64, 34, 40), Rect2(40, 92, 70, 50), Rect2(-20, 118, 50, 34)]
## Le village : la place, l'église (portail à l'ouest), le puits, les maisons.
const PLACE := Vector2(52, -30)
const EGLISE := Vector2(66, -50)
const PUITS := Vector2(48, -28)
const MAISONS := [[Vector2(30, -38), 0.2, true], [Vector2(32, -20), -0.1, true], [Vector2(50, -12), 1.5, false],
		[Vector2(70, -22), 1.7, true], [Vector2(84, -40), 0.4, false], [Vector2(40, -60), 0.1, true],
		[Vector2(22, -54), -0.3, true], [Vector2(90, -62), 0.9, true]]
const REFUGIEE := Vector2(55, -24)
const LAS_VILLAGE := [Vector2(44, -36), Vector2(60, -36)]
const CURE := Vector2(58, -42)
## Le moulin à vent, sur sa butte au nord-ouest.
const MOULIN := Vector2(-82, -96)
const MEUNIER := Vector2(-77, -88)
## Le gibet sur sa butte au nord-est, le camp des routiers et la faille.
const GIBET := Vector2(128, -122)
const CAMP_ROUTIERS := Vector2(108, -100)
const SACS := [Vector2(102, -96), Vector2(112, -94), Vector2(106, -106)]
const CHEF := Vector2(122, -108)
const LAMPE := Vector2(124, -104)
const FAILLE := Vector2(142, -98)
## La sortie : la route de Chartres et des carrières de Berchères, au nord-est (plus tard).
const SORTIE_NE := Vector2(160, -66)

var _ailes: Node3D
var _mur_ne: StaticBody3D


func _init() -> void:
	identifiant_zone = "beauce"
	taille_terrain = 340
	graine = 1194
	point_apparition = PORTAIL + Vector2(0, -5)
	nombre_touffes = 26000
	fertilite_sols = Vector3(0.1, 0.05, 1.0)
	neige_qui_tombe = false
	sols = {
		# Rouge : la terre battue de la route, des cours et des chemins.
		"galets": ["brown_mud_02", "dry_ground_rocks", "brown_mud_rocks_01"],
		# Vert : le chaume des champs (blé mûr et moissonné), doré.
		"neige": ["withered_grass", "dry_ground_01", "withered_grass"],
		# Bleu : les prés et les bords de chemin, verts d'été.
		"sol": ["withered_grass", "brown_mud_02", "dry_ground_01"],
		"roche": ["old_stone_wall", "rock_wall_10", "cliff_side"],
	}
	reglages_terrain = {"sol_saturation": 1.15, "sol_motif": 6.0, "galets_motif": 4.0, "neige_motif": 5.0,
			"sol_teinte": Color(0.66, 0.84, 0.46), "roche_teinte": Color(1.0, 0.95, 0.85), "roche_saturation": 0.8,
			"neige_eclat": 1.0, "neige_paillettes": 0.0, "roche_motif": 10.0,
			"neige_teinte": Color(1.25, 1.02, 0.6), "neige_max": Vector3(0.92, 0.76, 0.42), "neige_simple": Color(0.82, 0.68, 0.36),
			"givre": 0.0, "neige_translucide": 0.0}
	reglages_herbe = {"couleur_base": Color(0.2, 0.28, 0.1), "couleur_pointe": Color(0.6, 0.7, 0.32),
			"couleur_givre": Color(0.74, 0.7, 0.4), "force_vent": 0.6}
	reglages_couvre_sol = {"cailloux": 2.0, "fleurs": [Color(0.85, 0.12, 0.1), Color(0.28, 0.4, 0.9), Color(0.95, 0.92, 0.85)],
			"densite_fleurs": 3.0, "buissons": 0.3}
	piste = SENTIER.duplicate()


func _ready() -> void:
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_moyen_age", "") == "bercheres":
		Reseau.remove_meta("arrivee_moyen_age")
		# Retour des carrières : on arrive au nord-est, sur la route.
		point_apparition = SORTIE_NE + Vector2(-10, 4)
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	if zone == "beauce":
		return Vector2.INF
	return SORTIE_NE


# --- Relief -----------------------------------------------------------------------------

func _preparer_bruits() -> void:
	super._preparer_bruits()
	_relief.frequency = 0.005


func _distance_ligne(p: Vector2, ligne: Array) -> float:
	var meilleure := INF
	for i in ligne.size() - 1:
		meilleure = minf(meilleure, _distance_segment(p, ligne[i], ligne[i + 1]))
	return meilleure


func distance_route(p: Vector2) -> float:
	return _distance_ligne(p, ROUTE)


## Dans un champ de blé (0 à 1).
func dans_champ(x: float, z: float) -> float:
	var v := _dans_rect(CHAMP_GUILLOT, x, z, 2.0)
	v = maxf(v, _dans_rect(MOISSON, x, z, 1.5))
	for r: Rect2 in CHAMPS:
		v = maxf(v, _dans_rect(r, x, z, 2.0))
	return v


func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	var bruit := _relief.get_noise_2d(x, z)
	var fin := _details.get_noise_2d(x * 3.0, z * 3.0)
	var p := Vector2(x, z)
	# La Beauce : une plaine presque plate, de très longues ondulations.
	var h := 4.0 + bruit * 1.8 + fin * 0.06
	# La butte du moulin et celle du gibet.
	h += 5.0 * (1.0 - smoothstep(10.0, 40.0, p.distance_to(MOULIN)))
	h += 4.0 * (1.0 - smoothstep(10.0, 34.0, p.distance_to(GIBET + Vector2(-6, 6))))
	# La route, un peu creusée par les charrettes.
	h = lerpf(h, 3.9 + bruit * 1.6, (1.0 - smoothstep(3.0, 9.0, distance_route(p))) * 0.8)
	# Le replat du village, de la ferme et du dolmen.
	h = lerpf(h, 4.0 + bruit * 1.2, 1.0 - smoothstep(30.0, 46.0, p.distance_to(PLACE + Vector2(6, -10))))
	h = lerpf(h, 4.0 + bruit * 1.2, _dans_rect(FERME.grow(6.0), x, z, 6.0))
	h = lerpf(h, 4.2 + bruit * 1.2, 1.0 - smoothstep(8.0, 14.0, p.distance_to(PORTAIL + Vector2(-1, 4))))
	var d_sentier := _distance_piste(p)
	h = lerpf(h, h - 0.08, 1.0 - smoothstep(2.0, 5.0, d_sentier))
	return h


## Rouge : terre battue ; vert : champs de blé ; bleu : prés.
func _parts_sol(x: float, z: float, h: float) -> Color:
	var p := Vector2(x, z)
	var n := _relief.get_noise_2d(x * 2.0 + 60.0, z * 2.0)
	var terre := 1.0 - smoothstep(2.5, 5.5 + n * 1.5, distance_route(p))
	terre = maxf(terre, 1.0 - smoothstep(1.0, 2.6, _distance_piste(p)))
	terre = maxf(terre, _dans_rect(FERME.grow(1.0), x, z, 2.0))
	terre = maxf(terre, 1.0 - smoothstep(10.0, 16.0, p.distance_to(PLACE)))
	terre = maxf(terre, 1.0 - smoothstep(4.0, 8.0, p.distance_to(CAMP_ROUTIERS)))
	var champ := dans_champ(x, z) * (1.0 - terre)
	var pre := maxf(0.0, 1.0 - champ - terre)
	return Color(terre + 0.001, champ, pre, 1.0)


# --- Construction -------------------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_construire_terrain()
	_construire_champs()
	_construire_village()
	_construire_ferme()
	_construire_moulin()
	_construire_gibet()
	_construire_vegetation()
	_construire_touffes()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_appliquer_ciel()


func _construire_champs() -> void:
	var dossier := Node3D.new()
	dossier.name = "Champs"
	_contenu.add_child(dossier)
	_champ_ble(dossier, CHAMP_GUILLOT)
	for r: Rect2 in CHAMPS:
		_champ_ble(dossier, r)
	# Dans la bande déjà moissonnée de Guillot : des dizeaux de gerbes.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 4
	var dizeaux := Node3D.new()
	dizeaux.name = "Dizeaux"
	dossier.add_child(dizeaux)
	for k in 9:
		var p := Vector2(MOISSON.position.x + 4.0 + k * 6.0, MOISSON.position.y + 3.0 + (k % 2) * 3.0)
		var trop_pres := false
		for l: Vector2 in LAS_MOISSON:
			trop_pres = trop_pres or p.distance_to(l) < 3.0
		if not trop_pres:
			_dizeau(dizeaux, p, hasard)
	# Des dizeaux aussi sur deux autres champs, et des meules de paille.
	for k in 12:
		var r: Rect2 = CHAMPS[k % 2]
		_dizeau(dizeaux, Vector2(r.position.x + 6.0 + (k / 2) * 9.0, r.end.y + 4.0), hasard)
	_fusionner(dizeaux)
	for p: Vector2 in [Vector2(-84, 40), Vector2(8, 48), Vector2(-130, 30)]:
		_meule(dossier, p, 1.4)


func _construire_village() -> void:
	var dossier := Node3D.new()
	dossier.name = "Village"
	_contenu.add_child(dossier)
	_eglise_village(dossier, EGLISE, 0.0)
	_puits(dossier, PUITS)
	for k in MAISONS.size():
		var m: Array = MAISONS[k]
		if k % 3 == 2:
			_chaumiere(dossier, m[0], Vector3(5.0, 2.4, 7.0), m[1])
		else:
			_maison_pans_de_bois(dossier, m[0], Vector3(5.5, 4.4 + (k % 2) * 1.0, 8.0), m[1], m[2])
	# Le cimetière autour de l'église : un muret bas et quelques croix de pierre.
	var y := hauteur(EGLISE.x, EGLISE.y)
	for k in 6:
		var c := Vector2(EGLISE.x - 4.0 + k * 3.0, EGLISE.y + 9.0)
		_boite(Vector3(0.18, 1.0, 0.18), Vector3(c.x, hauteur(c.x, c.y) + 0.5, c.y), _mat_calcaire(), dossier, false)
		_boite(Vector3(0.6, 0.16, 0.16), Vector3(c.x, hauteur(c.x, c.y) + 0.75, c.y), _mat_calcaire(), dossier, false)
	_boite(Vector3(26.0, 0.8, 0.6), Vector3(EGLISE.x + 2.0, y + 0.3, EGLISE.y + 12.0), _mat_calcaire(), dossier)
	# Une charrette de réfugiés sur la place, des ballots, et l'étal d'un marchand.
	_charrette(dossier, PLACE + Vector2(8, 6), 0.8, true)
	_auvent(dossier, PLACE + Vector2(-8, 10), Vector2(4.0, 3.0), 2.4, Color(0.62, 0.16, 0.12))
	_fusionner(dossier)


func _construire_ferme() -> void:
	var dossier := Node3D.new()
	dossier.name = "FermeGuillot"
	_contenu.add_child(dossier)
	var r := FERME
	var y := hauteur(r.get_center().x, r.get_center().y)
	var pierre := _mat_calcaire()
	# Les murets de la cour, ouverts au nord (vers la route) et à l'est (vers le champ).
	_boite(Vector3(r.size.x, 1.4, 0.6), Vector3(r.get_center().x, y + 0.5, r.end.y), pierre, dossier)
	_boite(Vector3(0.6, 1.4, r.size.y), Vector3(r.position.x, y + 0.5, r.get_center().y), pierre, dossier)
	_boite(Vector3(0.6, 1.4, r.size.y * 0.4), Vector3(r.end.x, y + 0.5, r.end.y - r.size.y * 0.2), pierre, dossier)
	_boite(Vector3(r.size.x * 0.4, 1.4, 0.6), Vector3(r.position.x + r.size.x * 0.2, y + 0.5, r.position.y), pierre, dossier)
	var maison := _maison_pans_de_bois(dossier, Vector2(r.position.x + 6.0, r.end.y - 5.0), Vector3(6.0, 4.6, 9.0), PI / 2, true)
	maison.name = "MaisonGuillot"
	var grange := _chaumiere(dossier, Vector2(r.end.x - 6.0, r.position.y + 6.0), Vector3(7.0, 3.4, 10.0), 0.0)
	grange.name = "Grange"
	_fusionner(dossier)
	_charrette(dossier, Vector2(r.get_center().x + 2.0, r.get_center().y + 1.0), 0.3, false)
	_meule(dossier, Vector2(r.position.x + 4.0, r.position.y + 4.0), 1.0)
	# Les deux chevaux du Perche de Guillot (gris pommelé), dans la cour.
	if not Engine.is_editor_hint() and DisplayServer.get_name() != "headless":
		for k in 2:
			var cheval: Node3D = ApparenceMonture.new()
			cheval.name = "ChevalPerche%d" % k
			var fiche: Dictionary = Monture.fiche("cheval_perche").duplicate(true)
			if k == 1:
				fiche["robe"] = {"couleur": "#5e5a56", "pattes": "#2a2826", "crins": "#1c1a18"}
			cheval.reglages = fiche
			var c := Vector2(r.get_center().x - 3.0 + k * 3.0, r.get_center().y - 4.0)
			cheval.position = Vector3(c.x, hauteur(c.x, c.y), c.y)
			cheval.rotation.y = 0.4 + k * 1.2
			dossier.add_child(cheval)


func _construire_moulin() -> void:
	var dossier := Node3D.new()
	dossier.name = "Moulin"
	_contenu.add_child(dossier)
	var moulin := _moulin_a_vent(dossier, MOULIN, 0.6)
	_ailes = moulin.get_node("Ailes")
	_chaumiere(dossier, MOULIN + Vector2(-12, -10), Vector3(4.5, 2.4, 6.0), 0.6)
	for k in 3:
		var s := MOULIN + Vector2(6 + k * 1.2, -4)
		var sac := _boite(Vector3(0.7, 0.8, 0.5), Vector3(s.x, hauteur(s.x, s.y) + 0.4, s.y), _mat_uni_ma(Color(0.8, 0.76, 0.66), 1.0), dossier, false)
		sac.rotation.y = k * 0.5


func _construire_gibet() -> void:
	var dossier := Node3D.new()
	dossier.name = "Gibet"
	_contenu.add_child(dossier)
	_gibet(dossier, GIBET, 0.3)
	# Le camp des routiers : des tentes, un feu, une charrette volée.
	_tente(dossier, CAMP_ROUTIERS + Vector2(-8, -4), 0.3, Color(0.4, 0.34, 0.26))
	_tente(dossier, CAMP_ROUTIERS + Vector2(6, -10), -0.6, Color(0.32, 0.3, 0.26))
	_feu_de_camp(dossier, CAMP_ROUTIERS + Vector2(0, 2))
	_charrette(dossier, CAMP_ROUTIERS + Vector2(-10, 8), 1.2, true)


## Un petit feu de camp : un rond de pierres, des flammes, et sa lumière.
func _feu_de_camp(parent: Node3D, p: Vector2) -> void:
	var y := hauteur(p.x, p.y)
	for k in 8:
		var a := k * TAU / 8.0
		_boite(Vector3(0.3, 0.2, 0.3), Vector3(p.x + cos(a) * 0.6, y + 0.08, p.y + sin(a) * 0.6), _mat_calcaire(), parent, false)
	var feu := StandardMaterial3D.new()
	feu.albedo_color = Color(1.0, 0.5, 0.15, 0.85)
	feu.emission_enabled = true
	feu.emission = Color(1.0, 0.45, 0.12)
	feu.emission_energy_multiplier = 4.0
	feu.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	feu.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for k in 3:
		var flamme := MeshInstance3D.new()
		flamme.mesh = _cylindre(0.0, 0.18, 0.6, 6)
		flamme.material_override = feu
		flamme.position = Vector3(p.x + (k - 1) * 0.15, y + 0.32, p.y + (k % 2) * 0.12)
		parent.add_child(flamme)
	var lumiere := OmniLight3D.new()
	lumiere.light_color = Color(1.0, 0.6, 0.3)
	lumiere.light_energy = 2.0
	lumiere.omni_range = 7.0
	lumiere.position = Vector3(p.x, y + 1.0, p.y)
	parent.add_child(lumiere)


## Libre pour planter un arbre ou une haie ?
func _libre(p: Vector2, marge := 6.0) -> bool:
	if distance_route(p) < 6.0 or _distance_piste(p) < 4.0 or dans_champ(p.x, p.y) > 0.01:
		return false
	if p.distance_to(PLACE) < 34.0 or _dans_rect(FERME.grow(marge), p.x, p.y, 0.1) > 0.5:
		return false
	for c: Vector2 in [PORTAIL, DOLMEN, MOULIN, GIBET, CAMP_ROUTIERS, FAILLE, CHEF, GUILLOT]:
		if p.distance_to(c) < marge + 8.0:
			return false
	return true


func _construire_vegetation() -> void:
	var arbres := Node3D.new()
	arbres.name = "Arbres"
	_contenu.add_child(arbres)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 60
	# La Beauce n'a presque pas d'arbres : quelques chênes isolés au bord des chemins, des
	# noyers près du village, un bosquet près du dolmen, et des haies.
	var plantes := 0
	var essais := 0
	while plantes < 34 and essais < 1500:
		essais += 1
		var p := Vector2(hasard.randf_range(-160.0, 160.0), hasard.randf_range(-160.0, 160.0))
		if not _libre(p):
			continue
		_arbre_realiste(arbres, p, "chene", hasard, hasard.randf_range(0.8, 1.25))
		plantes += 1
	for k in 6:
		var a := k * TAU / 6.0
		var p := DOLMEN + Vector2(cos(a), sin(a)) * hasard.randf_range(12.0, 18.0)
		if _libre(p, 2.0) or p.distance_to(PORTAIL) > 10.0:
			_arbre_realiste(arbres, p, "chene" if k % 2 == 0 else "bouleau", hasard, hasard.randf_range(0.7, 1.0))
	var haies := Node3D.new()
	haies.name = "Haies"
	_contenu.add_child(haies)
	_haie(haies, Vector2(CHAMP_GUILLOT.position.x, CHAMP_GUILLOT.end.y + 2.0), Vector2(CHAMP_GUILLOT.end.x, CHAMP_GUILLOT.end.y + 2.0), hasard)
	_haie(haies, Vector2(FERME.position.x - 2.0, FERME.end.y + 3.0), Vector2(FERME.position.x - 2.0, FERME.position.y - 6.0), hasard)
	_haie(haies, Vector2(20, -76), Vector2(100, -80), hasard)


# --- Paysage lointain ----------------------------------------------------------------------

func _construire_lointain() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 70
	# La plaine de blé qui continue jusqu'à l'horizon (les champs dorés tout autour).
	_plan_lointain_autour(3.0, Color(0.05, 0.4, 0.55))
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.8
	# Des bois lointains, bas, sur l'horizon.
	for m in [[Vector3(-1500, -10, 900), Vector3(1200, 40, 300)], [Vector3(1300, -10, 1200), Vector3(1000, 50, 300)],
			[Vector3(-1200, -10, -1500), Vector3(1400, 45, 300)]]:
		bruit.seed = graine + hasard.randi()
		var bois := MeshInstance3D.new()
		bois.mesh = _maillage_bosse(bruit, m[1], 1.4, 0.3, 24, Color(0.2, 0.0, 0.6))
		bois.material_override = _mat_lointain()
		bois.position = m[0]
		bois.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(bois)
	# Chartres au nord-est, sur sa butte : les remparts, la ville, les deux tours de la
	# cathédrale (la façade ouest a survécu à l'incendie), et la fumée qui monte encore.
	var chartres := Node3D.new()
	chartres.name = "ChartresLointaine"
	_contenu.add_child(chartres)
	var c := Vector3(900, 0, -1300)
	var pierre := _mat_uni_ma(Color(0.72, 0.68, 0.6), 0.9)
	var butte := MeshInstance3D.new()
	bruit.seed = graine + 5
	butte.mesh = _maillage_bosse(bruit, Vector3(500, 40, 400), 1.2, 0.2, 20, Color(0.2, 0.0, 0.6))
	butte.material_override = _mat_lointain()
	butte.position = c + Vector3(0, -6, 0)
	chartres.add_child(butte)
	for k in 14:
		_boite(Vector3(hasard.randf_range(20, 50), hasard.randf_range(12, 20), hasard.randf_range(20, 40)),
				c + Vector3(-220 + k * 32, 40, hasard.randf_range(-60, 60)), _mat_uni_ma(Color(0.6, 0.54, 0.46), 0.9), chartres, false)
	for cote: float in [-1.0, 1.0]:
		_boite(Vector3(18, 100, 18), c + Vector3(cote * 22, 90, 0), pierre, chartres, false)
		var fleche := MeshInstance3D.new()
		fleche.mesh = _cylindre(0.5, 12.0, 60.0 if cote < 0.0 else 44.0, 8)
		fleche.material_override = pierre
		fleche.position = c + Vector3(cote * 22, 140 + (30.0 if cote < 0.0 else 22.0), 0)
		chartres.add_child(fleche)
	# Les ruines noircies de la nef, derrière la façade.
	_boite(Vector3(40, 30, 120), c + Vector3(0, 55, 70), _mat_uni_ma(Color(0.2, 0.18, 0.16), 1.0), chartres, false)
	var fumee := StandardMaterial3D.new()
	fumee.albedo_color = Color(0.32, 0.3, 0.3, 0.38)
	fumee.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fumee.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for k in 3:
		var colonne := MeshInstance3D.new()
		colonne.mesh = _cylindre(60.0, 14.0, 360.0, 10)
		colonne.material_override = fumee
		colonne.position = c + Vector3(-30 + k * 30, 260, 60 + k * 20)
		colonne.rotation.z = -0.28
		colonne.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chartres.add_child(colonne)
	# D'autres clochers de villages au loin, dans la plaine.
	for p in [Vector3(-900, 0, -700), Vector3(-600, 0, 1100), Vector3(1200, 0, 300), Vector3(300, 0, 1500)]:
		_boite(Vector3(5, 14, 5), p + Vector3(0, 10, 0), pierre, chartres, false)
		var f := MeshInstance3D.new()
		f.mesh = _cylindre(0.1, 3.6, 9.0, 4)
		f.material_override = _mat_uni_ma(Color(0.3, 0.3, 0.34), 0.7)
		f.position = p + Vector3(0, 21.5, 0)
		chartres.add_child(f)


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
	# La route de Chartres et des carrières : fermée tant que l'histoire n'y mène pas.
	_mur_ne = _mur_invisible(limites, Vector3(2, 14, 30), Vector3(SORTIE_NE.x - 4.0, hauteur(SORTIE_NE.x, SORTIE_NE.y) + 6.0, SORTIE_NE.y))


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


## Un Las et l'objet invisible posé sur lui pour lui rendre courage (puzzle du vitrail).
func _las(dossier: Node3D, id_pnj: String, id_objet: String, groupe: String, p: Vector2, angle: float) -> void:
	_pnj(dossier, id_pnj, p, angle)
	var o := _objet(dossier, id_objet, p, "", "[F] Rendre courage (le vitrail)", groupe, 2.2)
	o.set_meta("pnj_lie", id_pnj)


func _construire_quete() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quete"
	_contenu.add_child(dossier)
	_dossier_quete = dossier
	_dolmen(dossier, DOLMEN, PI)
	_construire_portail(dossier, PORTAIL, PI)
	_objet(dossier, "radio_vera", RADIO, "radio_vigie", "[F] Prendre la radio qui grésille")
	var craie := _objet(dossier, "craie_masque", CRAIE, "craie", "[F] Lire le message à la craie")
	craie.set_meta("texte_craie", "IL EST DÉJÀ PASSÉ ICI.\nROUTE DE CHARTRES.\n— M.")
	craie.rotation.y = PI * 0.15
	# La ferme et le champ de Guillot : les moissonneurs Las, les gerbes.
	_pnj(dossier, "guillot", GUILLOT, PI * 0.6)
	_pnj(dossier, "perrine", GUILLOT + Vector2(-6, -3), PI * 0.4)
	for k in LAS_MOISSON.size():
		_las(dossier, "las_moissonneur_%d" % (k + 1), "courage_moisson_%d" % k, "las_moisson", LAS_MOISSON[k], PI * (0.2 + k * 0.5))
	# Le village : la réfugiée de Chartres, les Las de la place, le curé.
	_pnj(dossier, "refugiee_chartres", REFUGIEE, -PI * 0.3)
	_las(dossier, "las_forgeron", "courage_forgeron", "las_village", LAS_VILLAGE[0], PI * 0.5)
	_las(dossier, "las_lavandiere", "courage_lavandiere", "las_village", LAS_VILLAGE[1], -PI * 0.4)
	_pnj(dossier, "cure_village", CURE, PI)
	# Le moulin : le meunier, Las.
	_las(dossier, "meunier", "courage_meunier", "las_meunier", MEUNIER, PI * 0.8)
	# Le camp des routiers : les sacs de farine volés, la lampe du chef, la faille.
	for k in SACS.size():
		_objet(dossier, "sac_farine_%d" % k, SACS[k], "sac_farine", "[F] Reprendre le sac de farine", "sac_farine")
	_objet(dossier, "lampe_frontale", LAMPE, "lampe_frontale", "[F] Ramasser l'objet qui clignote")
	var faille := Faille.new()
	faille.name = "Faille"
	faille.identifiant = "faille_beauce"
	faille.position = Vector3(FAILLE.x, hauteur(FAILLE.x, FAILLE.y), FAILLE.y)
	dossier.add_child(faille)
	_construire_secondaires(dossier)
	# Repères de la carte.
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.PORTAIL, "Portail de la Vigie (le dolmen)", PORTAIL)
	repere.call(MarqueurCarte.Type.DANGER, "Faille", FAILLE)
	repere.call(MarqueurCarte.Type.LIEU, "Ferme de Guillot", FERME.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Le village et son église", PLACE)
	repere.call(MarqueurCarte.Type.LIEU, "Moulin à vent", MOULIN)
	repere.call(MarqueurCarte.Type.LIEU, "Le gibet", GIBET)
	repere.call(MarqueurCarte.Type.LIEU, "Route de Chartres et des carrières de Berchères", SORTIE_NE)


# --- Le moulin tourne, la route s'ouvre --------------------------------------------------------

var _attente := 0.0
var _route_ouverte := false


func _process(delta: float) -> void:
	super._process(delta)
	if _ailes != null and is_instance_valid(_ailes):
		_ailes.rotation.z += delta * 0.6
	if Engine.is_editor_hint():
		return
	_attente -= delta
	if _attente > 0.0:
		return
	_attente = 0.3
	var quete := get_tree().get_first_node_in_group("quete")
	if quete == null or not quete.has_method("etape_atteinte"):
		return
	if not _route_ouverte:
		if not quete.etape_atteinte("vers_bercheres"):
			return
		_route_ouverte = true
		if _mur_ne != null and is_instance_valid(_mur_ne):
			_mur_ne.queue_free()
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return
	var p := Vector2(joueur.global_position.x, joueur.global_position.z)
	if p.distance_to(SORTIE_NE) < 6.0 and quete.donnees.get("zones", {}).has("bercheres"):
		quete.changer_de_zone("bercheres")


## Les personnages des quêtes secondaires (data/moyen_age_secondaires.json).
func _construire_secondaires(dossier: Node3D) -> void:
	_pnj(dossier, "dame_heloise", Vector2(-16, 34), PI * 0.9)
