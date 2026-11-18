@tool
extends "res://scripts/monde/moyen_age/ile_moyen_age.gd"
## Île du Moyen Âge, zone 2 : les carrières de Berchères et la forêt (niveaux 52-54).
##
## À deux lieues de Chartres, la pierre blonde de toute la cathédrale sort d'ici. À l'est,
## la grande carrière à ciel ouvert : un trou en gradins, ses parois de calcaire taillées
## en marches, une rampe où montent les charrettes, des treuils, et sur le bord la grande
## roue d'écureuil (des hommes marchent dedans pour lever les blocs). Au bord nord-est, le
## camp des carriers (cabanes, forge, blocs marqués). À l'ouest, une forêt de chênes : le
## charbonnier et sa meule qui fume, le camp des brigands au nord-ouest, la cabane d'un ermite
## au sud-ouest. On arrive de la Beauce par le chemin du sud-ouest ; au nord-est, la route
## des charrettes file vers Chartres.
##
## Tout est construit par le code (voir ile_moyen_age.gd). Repères : le nord est vers -Z.

const Faille := preload("res://scripts/monde/prehistoire/faille.gd")
const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const ObjetMoyenAge := preload("res://scripts/monde/moyen_age/objet_moyen_age.gd")

## La carrière : son centre, son rayon au bord, la hauteur d'une marche, le nombre de marches.
const CARRIERE := Vector2(50, 0)
const RAYON := 52.0
const MARCHE := 3.2
const MARCHES := 3
const LARGEUR_MARCHE := 10.0
## La rampe des charrettes : du fond (sud) jusqu'au bord (nord-est).
const RAMPE_BAS := Vector2(58, 8)
const RAMPE_HAUT := Vector2(84, -54)
## Le chemin de la Beauce (sud-ouest) jusqu'au bord ouest de la carrière.
const CHEMIN := [Vector2(-156, 150), Vector2(-110, 112), Vector2(-60, 80), Vector2(-14, 58), Vector2(10, 52), Vector2(40, 60)]
## La route des charrettes, du haut de la rampe jusqu'à Chartres (nord-est).
const ROUTE_CHARTRES := [Vector2(84, -54), Vector2(104, -80), Vector2(128, -108), Vector2(156, -134)]
const ARRIVEE := Vector2(-148, 142)
const SORTIE_SO := Vector2(-160, 152)
const SORTIE_NE := Vector2(152, -132)
## Le camp des carriers, au bord nord-est, et maître Gautier.
const CAMP := Vector2(112, -50)
const GAUTIER := Vector2(102, -44)
## Au fond du trou : les carriers Las, la charrette et ses volontaires.
const LAS_CARRIERS := [Vector2(40, 14), Vector2(28, -6), Vector2(52, -16)]
const CHARRETTE := Vector2(62, 16)
const GUILLOT := Vector2(66, 20)
const VOLONTAIRES := [Vector2(58, 21), Vector2(69, 13), Vector2(55, 12)]
## Sur le bord : le treuil coincé (ouest) et la grande roue d'écureuil (sud-est).
const TREUIL := Vector2(-1.5, 4)
const ROUE := Vector2(98, 22)
## La forêt, à l'ouest : le charbonnier, les larmes de plomb, les brigands, l'ermite.
const CHARBONNIER := Vector2(-82, 24)
const MEULE_CHARBON := Vector2(-90, 18)
const LARMES := [Vector2(-60, -14), Vector2(-104, -30), Vector2(-74, 64)]
const BRIGANDS := Vector2(-104, -88)
const CHEF := Vector2(-116, -102)
const ERMITE := Vector2(-140, 92)
const FAILLE := Vector2(-132, -120)
## L'escorte : du fond de la carrière, par la rampe, jusqu'à la route de Chartres.
const ESCORTE := [Vector2(62, 16), Vector2(64, 0), Vector2(70, -18), Vector2(78, -38), Vector2(84, -54),
		Vector2(104, -80), Vector2(128, -108), Vector2(146, -126)]

var _mur_ne: StaticBody3D
var _roue: Node3D


func _init() -> void:
	identifiant_zone = "bercheres"
	taille_terrain = 340
	graine = 1195
	point_apparition = ARRIVEE
	nombre_touffes = 20000
	fertilite_sols = Vector3(0.05, 0.25, 1.0)
	neige_qui_tombe = false
	sols = {
		# Rouge : la poussière blanche de calcaire (fond et rampe de la carrière, chemins).
		"galets": ["dry_ground_rocks", "brown_mud_rocks_01", "dry_ground_01"],
		# Vert : le sol de la forêt (feuilles, terre noire).
		"neige": ["brown_mud_02", "brown_mud_rocks_01", "brown_mud_02"],
		# Bleu : les prés.
		"sol": ["withered_grass", "brown_mud_02", "dry_ground_01"],
		"roche": ["quarry_wall", "quarry_wall_02", "white_sandstone_blocks_02"],
	}
	reglages_terrain = {"sol_saturation": 1.15, "sol_motif": 6.0, "galets_motif": 4.0, "neige_motif": 5.0,
			"sol_teinte": Color(0.66, 0.84, 0.46), "roche_teinte": Color(1.12, 1.04, 0.86), "roche_saturation": 0.75,
			"neige_eclat": 1.0, "neige_paillettes": 0.0, "roche_motif": 8.0,
			"neige_teinte": Color(0.78, 0.68, 0.56), "neige_max": Vector3(0.5, 0.42, 0.32), "neige_simple": Color(0.36, 0.3, 0.22),
			"givre": 0.0, "neige_translucide": 0.0}
	reglages_herbe = {"couleur_base": Color(0.18, 0.26, 0.1), "couleur_pointe": Color(0.56, 0.68, 0.3),
			"couleur_givre": Color(0.7, 0.68, 0.4), "force_vent": 0.5}
	reglages_couvre_sol = {"cailloux": 4.0, "fleurs": [Color(0.95, 0.92, 0.85), Color(0.6, 0.3, 0.8)], "densite_fleurs": 1.5,
			"buissons": 0.6, "litiere": 3.0}
	piste = CHEMIN.duplicate()


func _ready() -> void:
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_moyen_age", "") == "chartres":
		Reseau.remove_meta("arrivee_moyen_age")
		point_apparition = SORTIE_NE + Vector2(-10, 10)
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	if zone == "beauce":
		return SORTIE_SO
	if zone == "chartres":
		return SORTIE_NE
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


## Profondeur de la carrière en un point (0 dehors, MARCHE × MARCHES au fond) : des gradins.
func profondeur_carriere(p: Vector2) -> float:
	var d := p.distance_to(CARRIERE)
	if d > RAYON + 16.0:
		return 0.0
	var prof := 0.0
	for k in MARCHES:
		var bord := RAYON - k * LARGEUR_MARCHE
		prof += MARCHE * smoothstep(bord + 0.8, bord - 0.8, d)
	# La rampe : une pente douce et régulière, du fond jusqu'au bord.
	var axe := RAMPE_HAUT - RAMPE_BAS
	var t := clampf((p - RAMPE_BAS).dot(axe) / axe.length_squared(), 0.0, 1.0)
	var d_rampe := p.distance_to(RAMPE_BAS + axe * t)
	var prof_rampe := MARCHE * MARCHES * (1.0 - t)
	# Sur la rampe, on suit la pente (on taille dans les gradins s'il le faut).
	return lerpf(prof, prof_rampe, 1.0 - smoothstep(3.5, 5.5, d_rampe))


## Dans la forêt (0 à 1) : tout l'ouest, sauf les clairières.
func dans_foret(p: Vector2) -> float:
	var n := _relief.get_noise_2d(p.x * 1.5, p.y * 1.5) if _relief != null else 0.0
	var f := smoothstep(-10.0 + n * 20.0, -40.0 + n * 20.0, p.x)
	for c in [[CHARBONNIER + Vector2(-4, -2), 16.0], [BRIGANDS + Vector2(-6, -6), 18.0], [ERMITE, 12.0], [FAILLE, 10.0]]:
		f *= smoothstep(c[1] - 4.0, c[1] + 2.0, p.distance_to(c[0]))
	return f


func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	var bruit := _relief.get_noise_2d(x, z)
	var fin := _details.get_noise_2d(x * 3.0, z * 3.0)
	var p := Vector2(x, z)
	# Un plateau un peu plus vallonné que la Beauce.
	var h := 6.0 + bruit * 3.0 + fin * 0.1
	# Le bord de la carrière est aplani, puis on creuse.
	var plat := 1.0 - smoothstep(RAYON, RAYON + 16.0, p.distance_to(CARRIERE))
	h = lerpf(h, 6.0 + bruit * 0.6, plat)
	h -= profondeur_carriere(p)
	h += fin * 0.25 * plat * (1.0 - smoothstep(RAYON - 4.0, RAYON, p.distance_to(CARRIERE)))
	# Les chemins.
	var d_chemin := minf(_distance_piste(p), _distance_ligne(p, ROUTE_CHARTRES))
	h = lerpf(h, h - 0.1, 1.0 - smoothstep(2.0, 5.0, d_chemin))
	return h


## Rouge : poussière de calcaire et chemins ; vert : sol de forêt ; bleu : prés.
func _parts_sol(x: float, z: float, h: float) -> Color:
	var p := Vector2(x, z)
	var n := _relief.get_noise_2d(x * 2.0 + 60.0, z * 2.0)
	var pierre := 1.0 - smoothstep(RAYON + 2.0, RAYON + 10.0 + n * 4.0, p.distance_to(CARRIERE))
	pierre = maxf(pierre, 1.0 - smoothstep(1.5, 3.5, _distance_piste(p)))
	pierre = maxf(pierre, 1.0 - smoothstep(2.5, 5.0, _distance_ligne(p, ROUTE_CHARTRES)))
	pierre = maxf(pierre, 1.0 - smoothstep(10.0, 16.0, p.distance_to(CAMP)))
	var foret := dans_foret(p) * (1.0 - pierre)
	return Color(pierre + 0.001, foret, maxf(0.0, 1.0 - pierre - foret), 1.0)


# --- Construction -------------------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_construire_terrain()
	_construire_carriere()
	_construire_camp()
	_construire_foret()
	_construire_touffes()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_appliquer_ciel()


## Des blocs de pierre taillée, empilés ou posés, avec parfois une marque de tâcheron.
func _bloc(parent: Node3D, p: Vector2, taille: Vector3, angle: float, y_plus := 0.0) -> void:
	var b := _boite(taille, Vector3(p.x, hauteur(p.x, p.y) + taille.y * 0.5 - 0.05 + y_plus, p.y), _mat_calcaire(), parent)
	b.rotation.y = angle


func _construire_carriere() -> void:
	var dossier := Node3D.new()
	dossier.name = "Carriere"
	_contenu.add_child(dossier)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 3
	# Les blocs taillés au fond, en rangées, et des tas d'éclats.
	for k in 22:
		var a := hasard.randf() * TAU
		var p := CARRIERE + Vector2(cos(a), sin(a)) * hasard.randf_range(6.0, RAYON - 2.0 * LARGEUR_MARCHE - 3.0)
		if p.distance_to(CHARRETTE) < 7.0 or _pres_des_las(p, 3.5) or _distance_segment(p, RAMPE_BAS, RAMPE_HAUT) < 5.0:
			continue
		_bloc(dossier, p, Vector3(hasard.randf_range(1.2, 2.2), hasard.randf_range(0.7, 1.1), hasard.randf_range(0.8, 1.4)), hasard.randf() * PI)
	# Les blocs de la paroi pas encore détachés : des saignées dans le gradin.
	for k in 18:
		var a := k * TAU / 18.0 + hasard.randf() * 0.2
		var p := CARRIERE + Vector2(cos(a), sin(a)) * (RAYON - LARGEUR_MARCHE - 1.0)
		if _distance_segment(p, RAMPE_BAS, RAMPE_HAUT) < 6.0:
			continue
		_bloc(dossier, p, Vector3(1.6, 0.9, 1.0), -a, 0.0)
	# Des échelles contre les parois, des leviers, des coins de bois.
	var bois := _mat_colombage()
	for k in 6:
		var a := 0.5 + k * 1.0
		var p := CARRIERE + Vector2(cos(a), sin(a)) * (RAYON - 0.8)
		if _distance_segment(p, RAMPE_BAS, RAMPE_HAUT) < 6.0:
			continue
		var echelle := Node3D.new()
		echelle.position = Vector3(p.x, hauteur(p.x, p.y) - MARCHE, p.y)
		echelle.rotation.y = -a + PI / 2
		dossier.add_child(echelle)
		for cote: float in [-0.3, 0.3]:
			var montant := _boite(Vector3(0.08, 3.8, 0.08), Vector3(cote, 1.8, 0.4), bois, echelle, false)
			montant.rotation.x = -0.25
		for b in 9:
			_boite(Vector3(0.6, 0.05, 0.05), Vector3(0, 0.3 + b * 0.4, 0.5 - b * 0.1), bois, echelle, false)
	_fusionner(dossier)
	# La grande roue d'écureuil, au bord sud-est : une roue de 5 m où marchent deux hommes,
	# et la flèche de bois au-dessus du trou, avec sa poulie et un bloc pendu.
	_roue = _roue_ecureuil(_contenu, ROUE, PI * 0.95)


func _pres_des_las(p: Vector2, marge: float) -> bool:
	for l: Vector2 in LAS_CARRIERS:
		if p.distance_to(l) < marge:
			return true
	return false


func _construire_camp() -> void:
	var dossier := Node3D.new()
	dossier.name = "CampCarriers"
	_contenu.add_child(dossier)
	# Les loges des carriers (cabanes de planches), la forge, les tas de blocs marqués.
	_chaumiere(dossier, CAMP + Vector2(10, -8), Vector3(5.0, 2.6, 8.0), 0.3)
	_chaumiere(dossier, CAMP + Vector2(-2, -16), Vector3(4.5, 2.4, 6.5), -0.2)
	var forge := _maison_pans_de_bois(dossier, CAMP + Vector2(16, 8), Vector3(5.0, 3.6, 6.0), 1.2, false)
	forge.name = "Forge"
	_auvent(dossier, CAMP + Vector2(-6, 2), Vector2(5.0, 4.0), 2.4, Color(0.6, 0.52, 0.4))
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 8
	for k in 8:
		var p := CAMP + Vector2(-14.0 + (k % 4) * 2.4, 10.0 + (k / 4) * 1.8)
		_bloc(dossier, p, Vector3(1.6, 0.8, 1.0), hasard.randf_range(-0.1, 0.1))
	_fusionner(dossier)
	_charrette(dossier, CAMP + Vector2(2, 14), 0.9, true)
	_feu_de_camp_ma(dossier, CAMP + Vector2(-4, -4))
	# Les autres treuils, sur le bord (décor).
	for a in [2.2, 3.6, 4.6]:
		var p := CARRIERE + Vector2(cos(a), sin(a)) * (RAYON + 2.5)
		var t := ObjetMoyenAge.new()
		t.forme = "treuil"
		t.identifiant = "treuil_decor_%d" % int(a * 10)
		t.name = "TreuilDecor%d" % int(a * 10)
		t.invite = ""
		t.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
		t.rotation.y = -a + PI / 2
		_contenu.add_child(t)
		t.call_deferred("cacher")


func _feu_de_camp_ma(parent: Node3D, p: Vector2) -> void:
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


## La meule du charbonnier : un dôme de terre et de mottes qui fume par le haut.
func _meule_charbonnier(parent: Node3D, p: Vector2) -> void:
	var y := hauteur(p.x, p.y)
	var dome := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 3.0
	s.height = 3.4
	dome.mesh = s
	dome.material_override = _mat_uni_ma(Color(0.2, 0.17, 0.14), 1.0)
	dome.position = Vector3(p.x, y - 0.2, p.y)
	dome.scale = Vector3(1.0, 0.8, 1.0)
	parent.add_child(dome)
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.6
	forme.shape = sphere
	corps.position = dome.position
	corps.add_child(forme)
	parent.add_child(corps)
	var fumee := StandardMaterial3D.new()
	fumee.albedo_color = Color(0.5, 0.48, 0.46, 0.35)
	fumee.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fumee.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var colonne := MeshInstance3D.new()
	colonne.mesh = _cylindre(2.4, 0.4, 14.0, 8)
	colonne.material_override = fumee
	colonne.position = Vector3(p.x + 1.0, y + 8.5, p.y)
	colonne.rotation.z = -0.12
	colonne.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(colonne)
	# Le tas de bois coupé, à côté.
	var bois := _mat_colombage()
	for k in 10:
		var buche := MeshInstance3D.new()
		buche.mesh = _cylindre(0.12, 0.12, 1.4, 6)
		buche.material_override = bois
		buche.rotation.z = PI / 2
		buche.position = Vector3(p.x + 4.0, y + 0.15 + (k / 4) * 0.24, p.y - 2.0 + (k % 4) * 0.26)
		parent.add_child(buche)


func _construire_foret() -> void:
	var arbres := Node3D.new()
	arbres.name = "Arbres"
	_contenu.add_child(arbres)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 60
	var plantes := 0
	var essais := 0
	var interdits := [ARRIVEE, CHARBONNIER, MEULE_CHARBON, BRIGANDS, CHEF, ERMITE, FAILLE] + LARMES
	while plantes < 170 and essais < 5000:
		essais += 1
		var p := Vector2(hasard.randf_range(-162.0, 40.0), hasard.randf_range(-162.0, 162.0))
		if hasard.randf() > dans_foret(p) or _distance_piste(p) < 4.5 or p.distance_to(CARRIERE) < RAYON + 6.0:
			continue
		var proche := false
		for c: Vector2 in interdits:
			proche = proche or p.distance_to(c) < 7.0
		if proche:
			continue
		_arbre_realiste(arbres, p, "chene" if hasard.randf() < 0.75 else "bouleau", hasard, hasard.randf_range(0.85, 1.35))
		plantes += 1
	# Quelques arbres isolés à l'est, autour du camp.
	for k in 14:
		var p := Vector2(hasard.randf_range(60.0, 160.0), hasard.randf_range(-160.0, 160.0))
		if p.distance_to(CARRIERE) < RAYON + 8.0 or p.distance_to(CAMP) < 22.0 or _distance_ligne(p, ROUTE_CHARTRES) < 6.0 \
				or p.distance_to(ROUE) < 10.0:
			continue
		_arbre_realiste(arbres, p, "chene", hasard, hasard.randf_range(0.8, 1.2))
	var clairieres := Node3D.new()
	clairieres.name = "Clairieres"
	_contenu.add_child(clairieres)
	_meule_charbonnier(clairieres, MEULE_CHARBON)
	_chaumiere(clairieres, CHARBONNIER + Vector2(-8, 8), Vector3(3.6, 2.0, 4.4), 0.6)
	# Le camp des brigands : des abris de branches, un feu, des tonneaux volés.
	_tente(clairieres, BRIGANDS + Vector2(-6, -8), 0.6, Color(0.3, 0.26, 0.2))
	_tente(clairieres, BRIGANDS + Vector2(6, -12), -0.4, Color(0.34, 0.3, 0.22))
	_feu_de_camp_ma(clairieres, BRIGANDS + Vector2(0, -2))
	# La cabane de l'ermite.
	_chaumiere(clairieres, ERMITE + Vector2(0, -5), Vector3(3.2, 2.0, 3.8), 0.2)


# --- Paysage lointain ----------------------------------------------------------------------

func _construire_lointain() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 70
	_plan_lointain_autour(5.0, Color(0.05, 0.4, 0.55))
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.8
	for m in [[Vector3(-1400, -10, 0), Vector3(900, 70, 1600)], [Vector3(-300, -10, -1500), Vector3(1200, 60, 400)],
			[Vector3(1300, -10, 900), Vector3(900, 40, 400)]]:
		bruit.seed = graine + hasard.randi()
		var bois := MeshInstance3D.new()
		bois.mesh = _maillage_bosse(bruit, m[1], 1.4, 0.3, 24, Color(0.2, 0.0, 0.6))
		bois.material_override = _mat_lointain()
		bois.position = m[0]
		bois.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(bois)
	# Les tours de Chartres, plus proches qu'en Beauce, au nord-est.
	var chartres := Node3D.new()
	chartres.name = "ChartresLointaine"
	_contenu.add_child(chartres)
	var c := Vector3(700, 0, -900)
	var pierre := _mat_uni_ma(Color(0.72, 0.68, 0.6), 0.9)
	for cote: float in [-1.0, 1.0]:
		_boite(Vector3(16, 90, 16), c + Vector3(cote * 20, 80, 0), pierre, chartres, false)
		var fleche := MeshInstance3D.new()
		fleche.mesh = _cylindre(0.5, 11.0, 56.0 if cote < 0.0 else 40.0, 8)
		fleche.material_override = pierre
		fleche.position = c + Vector3(cote * 20, 125 + (28.0 if cote < 0.0 else 20.0), 0)
		chartres.add_child(fleche)
	var fumee := StandardMaterial3D.new()
	fumee.albedo_color = Color(0.32, 0.3, 0.3, 0.3)
	fumee.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fumee.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var colonne := MeshInstance3D.new()
	colonne.mesh = _cylindre(50.0, 12.0, 300.0, 10)
	colonne.material_override = fumee
	colonne.position = c + Vector3(0, 220, 60)
	colonne.rotation.z = -0.28
	colonne.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chartres.add_child(colonne)


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
	_mur_ne = _mur_invisible(limites, Vector3(30, 14, 2), Vector3(SORTIE_NE.x, hauteur(SORTIE_NE.x, SORTIE_NE.y) + 6.0, SORTIE_NE.y + 4.0), PI / 4)


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


func _construire_quete() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quete"
	_contenu.add_child(dossier)
	_dossier_quete = dossier
	_pnj(dossier, "maitre_gautier", GAUTIER, PI * 0.7)
	for k in LAS_CARRIERS.size():
		_las(dossier, "las_carrier_%d" % (k + 1), "courage_carrier_%d" % k, "las_carrier", LAS_CARRIERS[k], TAU * k / 3.0)
	var treuil := _objet(dossier, "treuil_coince", TREUIL, "treuil", "[F] Débloquer le treuil", "", 2.8)
	treuil.rotation.y = PI / 2
	_objet(dossier, "marcher_roue", ROUE + Vector2(-1.5, 0), "", "[F] Marcher dans la roue d'écureuil", "", 3.0)
	_pnj(dossier, "charbonnier", CHARBONNIER, PI * 0.2)
	for k in LARMES.size():
		_objet(dossier, "larme_plomb_%d" % k, LARMES[k], "larme_plomb", "[F] Ramasser les gouttes de métal", "larme_plomb")
	# La charrette de pierre (elle suit l'escorte), Guillot et les volontaires.
	var charrette := Node3D.new()
	charrette.name = "CharrettePierre"
	charrette.position = Vector3(CHARRETTE.x, hauteur(CHARRETTE.x, CHARRETTE.y), CHARRETTE.y)
	charrette.set_meta("identifiant", "charrette_pierre")
	charrette.add_to_group("decor_quete")
	dossier.add_child(charrette)
	var c := _charrette(charrette, Vector2.ZERO, 0.0, false)
	c.position = Vector3.ZERO
	_boite(Vector3(1.4, 0.8, 0.9), Vector3(0, 1.3, 0), _mat_calcaire(), charrette, false)
	var guillot := _pnj(dossier, "guillot_bercheres", GUILLOT, PI)
	guillot.add_to_group("decor_quete")
	guillot.set_meta("identifiant", "guillot_bercheres")
	guillot.visible = false
	for k in VOLONTAIRES.size():
		var v := _pnj(dossier, "volontaire_%d" % (k + 1), VOLONTAIRES[k], PI * (0.5 + k * 0.4))
		v.add_to_group("decor_quete")
		v.set_meta("identifiant", "volontaire_%d" % (k + 1))
		v.visible = false
	var faille := Faille.new()
	faille.name = "Faille"
	faille.identifiant = "faille_bercheres"
	faille.position = Vector3(FAILLE.x, hauteur(FAILLE.x, FAILLE.y), FAILLE.y)
	dossier.add_child(faille)
	_construire_secondaires(dossier)
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.LIEU, "Carrières de Berchères", CARRIERE)
	repere.call(MarqueurCarte.Type.LIEU, "Camp des carriers", CAMP)
	repere.call(MarqueurCarte.Type.LIEU, "Roue d'écureuil", ROUE)
	repere.call(MarqueurCarte.Type.LIEU, "Le charbonnier", CHARBONNIER)
	repere.call(MarqueurCarte.Type.DANGER, "Camp des brigands", BRIGANDS)
	repere.call(MarqueurCarte.Type.DANGER, "Faille", FAILLE)
	repere.call(MarqueurCarte.Type.LIEU, "Chemin de la Beauce", SORTIE_SO)
	repere.call(MarqueurCarte.Type.LIEU, "Route de Chartres", SORTIE_NE)


func _construire_secondaires(_dossier: Node3D) -> void:
	pass


# --- La roue tourne, les sorties ------------------------------------------------------------------

var _attente := 0.0
var _route_ouverte := false
var _vitesse_roue := 0.0


func _process(delta: float) -> void:
	super._process(delta)
	if _roue != null and is_instance_valid(_roue) and _vitesse_roue > 0.0:
		_roue.get_node("Roue").rotation.x += delta * _vitesse_roue
	if Engine.is_editor_hint():
		return
	_attente -= delta
	if _attente > 0.0:
		return
	_attente = 0.3
	var quete := get_tree().get_first_node_in_group("quete")
	if quete == null or not quete.has_method("etape_atteinte"):
		return
	# Une fois la roue remise en marche, elle tourne doucement (les carriers lèvent des blocs).
	_vitesse_roue = 0.35 if quete.etape_atteinte("gautier_pierre") else 0.0
	if not _route_ouverte and quete.etape_atteinte("vers_chartres"):
		_route_ouverte = true
		if _mur_ne != null and is_instance_valid(_mur_ne):
			_mur_ne.queue_free()
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return
	var p := Vector2(joueur.global_position.x, joueur.global_position.z)
	if p.distance_to(SORTIE_SO) < 7.0 and quete.donnees.get("zones", {}).has("beauce"):
		Reseau.set_meta("arrivee_moyen_age", "bercheres")
		quete.changer_de_zone("beauce")
	elif _route_ouverte and p.distance_to(SORTIE_NE) < 7.0 and quete.donnees.get("zones", {}).has("chartres"):
		quete.changer_de_zone("chartres")
