@tool
extends "res://scripts/monde/chine/ile_chine.gd"
## Île de la Chine, zone 2 : le Fleuve Jaune et les terres de lœss (niveaux 42-45).
##
## L'hiver de l'an 105, au cœur de la Chine du Nord. La route de la soie arrive de l'ouest
## (la Porte de Jade) et file vers l'est, jusqu'au Fleuve Jaune. Au nord, les collines de
## lœss, la terre jaune et fine apportée par le vent, taillées en terrasses ; au pied de la
## falaise, un village de maisons-grottes (« yaodong ») avec la ferme de vers à soie de Mei
## et ses mûriers taillés. Au sud de la route, des champs de millet moissonnés, et le
## village des papetiers de Lao Fan (cuves, séchoirs, écorce de mûrier). À l'est, le Fleuve
## Jaune, large et boueux, charrie des glaçons : on le passe sur le grand bac du vieux Bo.
## Sur l'autre rive, le relais du bac et la route de Luoyang.
##
## Tout est construit par le code (voir ile_chine.gd). Le bouton « Reconstruire » de
## l'Inspecteur refait tout. Repères : le nord est vers -Z.

const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const ObjetChine := preload("res://scripts/monde/chine/objet_chine.gd")
const Faille := preload("res://scripts/monde/prehistoire/faille.gd")
const BarqueTraversee := preload("res://scripts/monde/egypte/barque_traversee.gd")
const BacPasseur := preload("res://scripts/monde/chine/bac_passeur.gd")

## Le niveau de base de la plaine (au-dessus du fleuve).
const SOL := 3.4

## La route de la soie : de la Porte de Jade (ouest) au débarcadère du bac.
const ROUTE := [Vector2(-180, 8), Vector2(-140, 12), Vector2(-100, 4), Vector2(-60, 10), Vector2(-20, 6),
		Vector2(20, 13), Vector2(52, 10), Vector2(80, 10)]
## Sur l'autre rive : du débarcadère vers Luoyang (est).
const ROUTE_EST := [Vector2(140, 12), Vector2(158, 10), Vector2(180, 12)]
const ENTREE := Vector2(-174, 8)
const SORTIE_EST := Vector2(174, 12)

## La falaise de lœss où sont creusées les maisons-grottes (de x1 à x2, au pied z).
const FALAISE := Vector3(-126, 6, -56)
const GROTTES := [-114.0, -100.0, -86.0, -72.0, -58.0, -44.0, -30.0, -16.0]
## La cour du village et la ferme de Mei.
const VILLAGE := Rect2(-124, -55, 128, 22)
const MEI := Vector2(-63, -44)
const OEUFS := [Vector2(-75, -50), Vector2(-69, -50.5), Vector2(-61, -50.5), Vector2(-55, -50)]
const VILLAGEOIS := [Vector2(-96, -44), Vector2(-40, -46), Vector2(-24, -40)]
## Les mûriers taillés, au sud de la cour, et le champ où descendent les sangliers.
const MURIERS := Rect2(-120, -30, 110, 14)
const SANGLIERS := Vector2(-30, -24)
## Les champs de millet moissonnés, au sud-ouest.
const CHAMPS := Rect2(-160, 30, 90, 70)

## Le village des papetiers de Lao Fan, au sud de la route.
const PAPETIERS := Rect2(2, 30, 50, 42)
const LAO_FAN := Vector2(26, 45)
const PAPETIERS_PNJ := [Vector2(14, 60), Vector2(40, 58), Vector2(32, 38)]
const CUVES := [Vector2(14, 52), Vector2(21, 55), Vector2(31, 55), Vector2(38, 52)]
const SECHOIRS := [Vector2(10, 40), Vector2(10, 64), Vector2(44, 64), Vector2(46, 42)]
const FEUILLES := [Vector2(10, 38.6), Vector2(10, 62.6), Vector2(44, 62.6), Vector2(46, 40.6), Vector2(27, 66.6)]
const BRIGANDS := Vector2(27, 56)

## Le Grand Solitaire et la faille, au sud, près du fleuve.
const SOLITAIRE := Vector2(48, 110)
const FAILLE := Vector2(58, 118)

## Le Fleuve Jaune : entre les deux rives (x à une position z donnée, voir rive_ouest/rive_est).
const RIVE_OUEST := 84.0
const RIVE_EST := 140.0
## Les débarcadères (rampes de terre qui descendent dans l'eau) des deux rives, en z.
const QUAI_OUEST := Vector2(80, 10)
const QUAI_EST := Vector2(142, 12)
## Le grand bac du vieux Bo : sa place au départ et son chemin d'une rive à l'autre.
const BAC := Vector2(94, 10)
const TRAVERSEE := [Vector2(94, 10), Vector2(104, 14), Vector2(114, 15), Vector2(123, 13), Vector2(129, 12)]
const MONTER_BAC := Vector2(85, 10)
const VIEUX_BO := Vector2(76, 0)
const LAO_FAN_BAC := Vector2(77, 15)
## Le passeur (pour repasser le fleuve une fois le bac parti), sur chaque rive.
const PASSEUR_OUEST := Vector2(81, 4)
const PASSEUR_EST := Vector2(143, 19)
## Sur l'autre rive : le relais du bac, les pirates, et Lao Fan qui t'attend.
const RELAIS_BAC := Vector2(158, -4)
const PIRATES := Vector2(152, 20)
const LAO_FAN_EST := Vector2(153, 6)

var _bord: FastNoiseLite
var _mur_est: StaticBody3D
var _est_ouvert := false
var _attente_sortie := 0.0


func _init() -> void:
	identifiant_zone = "fleuve_jaune"
	taille_terrain = 360
	graine = 1055
	point_apparition = ENTREE + Vector2(12, 0)
	nombre_touffes = 30000
	fertilite_sols = Vector3(0.3, 0.05, 1.0)
	neige_qui_tombe = false
	sols = {
		# Rouge : la terre nue (route, champs moissonnés, cours des villages, vase des berges).
		"galets": ["mud_cracked_dry_03", "brown_mud_02", "dry_ground_01"],
		# Vert : des plaques de neige sur les terrasses et dans les creux.
		"neige": ["snow_02", "snow_03", "snow_02"],
		# Bleu : l'herbe sèche de l'hiver.
		"sol": ["withered_grass", "dry_ground_01", "dry_ground_rocks"],
		# La falaise et les talus des terrasses : le lœss, jaune et fin.
		"roche": ["sandstone_cracks", "quarry_wall", "clay_block_wall"],
	}
	reglages_terrain = {"sol_saturation": 0.8, "sol_motif": 5.0, "galets_motif": 4.0, "neige_motif": 6.0,
			"sol_teinte": Color(0.95, 0.88, 0.76), "roche_teinte": Color(1.08, 0.9, 0.64), "roche_saturation": 0.9,
			"roche_motif": 10.0}
	reglages_herbe = {"couleur_base": Color(0.32, 0.27, 0.15), "couleur_pointe": Color(0.76, 0.66, 0.42),
			"couleur_givre": Color(0.8, 0.78, 0.7), "force_vent": 0.3}
	piste = ROUTE.duplicate()


func _ready() -> void:
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_chine", "") != "":
		var venu := String(Reseau.get_meta("arrivee_chine"))
		Reseau.remove_meta("arrivee_chine")
		# Retour de Luoyang : on arrive à l'est, sur l'autre rive.
		if venu != "porte_de_jade":
			point_apparition = SORTIE_EST + Vector2(-12, 0)
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	if zone == "porte_de_jade":
		return ENTREE
	return SORTIE_EST if zone != "fleuve_jaune" else Vector2.INF


# --- Relief -----------------------------------------------------------------------------

func _preparer_bruits() -> void:
	super._preparer_bruits()
	_relief.frequency = 0.008
	_bord = FastNoiseLite.new()
	_bord.seed = graine + 5
	_bord.frequency = 0.03
	_bord.fractal_octaves = 2


## Les rives du fleuve (x du bord de l'eau à une position z). Bien droites aux débarcadères.
func rive_ouest(z: float) -> float:
	if _bord == null:
		_preparer_bruits()
	return RIVE_OUEST + _bord.get_noise_1d(z * 0.6) * 5.0 * smoothstep(8.0, 24.0, absf(z - QUAI_OUEST.y))


func rive_est(z: float) -> float:
	if _bord == null:
		_preparer_bruits()
	return RIVE_EST + _bord.get_noise_1d(z * 0.6 + 300.0) * 5.0 * smoothstep(8.0, 24.0, absf(z - QUAI_EST.y))


## Distance à une ligne brisée.
func _distance_ligne(p: Vector2, ligne: Array) -> float:
	var meilleure := INF
	for i in ligne.size() - 1:
		meilleure = minf(meilleure, _distance_segment(p, ligne[i], ligne[i + 1]))
	return meilleure


func distance_route(p: Vector2) -> float:
	return minf(_distance_ligne(p, ROUTE), _distance_ligne(p, ROUTE_EST))


## Le pied de la falaise de lœss (z) à une position x.
func pied_falaise(x: float) -> float:
	if _bord == null:
		_preparer_bruits()
	return FALAISE.z + _bord.get_noise_1d(x) * 1.2


## Combien on est « dans » la falaise (1 entre ses deux bouts, 0 loin à l'est ou à l'ouest).
func _force_falaise(x: float) -> float:
	var dehors := maxf(maxf(FALAISE.x - x, x - FALAISE.y), 0.0)
	return 1.0 - smoothstep(0.0, 26.0, dehors)


func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	var bruit := _relief.get_noise_2d(x, z)
	var fin := _details.get_noise_2d(x * 3.0, z * 3.0)
	var p := Vector2(x, z)
	# La plaine : de longues ondulations.
	var h := SOL + bruit * 1.3 + fin * 0.08
	# Le plateau de lœss au nord : une falaise à pic devant le village, une pente douce
	# ailleurs, puis des terrasses qui montent marche après marche.
	var zf := pied_falaise(x)
	var falaise := _force_falaise(x)
	var marche := smoothstep(zf + 0.7, zf - 0.7, z)
	var douce := smoothstep(zf + 14.0, zf - 30.0, z)
	h += lerpf(douce, marche, falaise) * 9.0
	var t := clampf((zf - 8.0 - z + _bord.get_noise_1d(x * 0.5 + 77.0) * 10.0) / 110.0, 0.0, 1.0) * 20.0
	var s := t / 3.4
	h += (floor(s) + smoothstep(0.86, 1.0, s - floor(s))) * 3.4 + bruit * 0.4 * smoothstep(zf, zf - 10.0, z)
	# La cour du village, au pied de la falaise : de la terre battue bien plate.
	h = lerpf(h, SOL + 0.2 + fin * 0.04, _dans_rect(VILLAGE, x, z, 4.0) * (1.0 - marche))
	# La route, le village des papetiers, les champs.
	h = lerpf(h, SOL + bruit * 0.9, (1.0 - smoothstep(4.0, 10.0, distance_route(p))) * 0.8 * (1.0 - marche))
	h = lerpf(h, SOL + 0.1 + fin * 0.04, _dans_rect(PAPETIERS.grow(4.0), x, z, 6.0))
	h = lerpf(h, SOL + bruit * 0.5, _dans_rect(CHAMPS, x, z, 8.0) * 0.8)
	# Le fleuve : les berges plongent sous l'eau trouble.
	var dans_eau := minf(x - rive_ouest(z), rive_est(z) - x)
	h = lerpf(h, -3.2 + fin * 0.2, smoothstep(-3.0, 9.0, dans_eau))
	# Les débarcadères : une rampe de terre tassée qui descend doucement dans l'eau.
	for quai: Vector2 in [QUAI_OUEST, QUAI_EST]:
		var couloir := 1.0 - smoothstep(4.0, 6.5, absf(z - quai.y))
		if couloir <= 0.0 or (quai == QUAI_OUEST) != (x < 112.0):
			continue
		var b := (x - rive_ouest(z)) if quai == QUAI_OUEST else (rive_est(z) - x)
		var rampe := clampf(2.9 - (b + 7.0) * 0.27, -0.7, 3.4)
		h = lerpf(h, rampe, couloir * smoothstep(-11.0, -7.0, b))
	return h


## Rouge : terre nue ; vert : plaques de neige ; bleu : herbe sèche de l'hiver.
func _parts_sol(x: float, z: float, h: float) -> Color:
	var p := Vector2(x, z)
	var n := _relief.get_noise_2d(x * 2.0 + 60.0, z * 2.0)
	var nu := 1.0 - smoothstep(2.5, 6.0 + n * 2.0, distance_route(p))
	nu = maxf(nu, _dans_rect(VILLAGE, x, z, 2.0))
	nu = maxf(nu, _dans_rect(PAPETIERS.grow(2.0), x, z, 3.0))
	nu = maxf(nu, _dans_rect(CHAMPS, x, z, 4.0) * 0.9)
	nu = maxf(nu, _dans_rect(MURIERS, x, z, 3.0) * 0.7)
	# La vase des berges.
	nu = maxf(nu, 1.0 - smoothstep(1.5, 3.4, h))
	# La neige tient sur les terrasses (au nord) et dans les creux à l'ombre.
	var nord := smoothstep(pied_falaise(x) - 4.0, pied_falaise(x) - 20.0, z)
	var neige := clampf(nord * smoothstep(-0.1, 0.4, n + 0.15) + smoothstep(0.45, 0.7, n) * 0.6, 0.0, 1.0)
	neige *= 1.0 - nu * 0.8
	var herbe := maxf(0.0, 1.0 - nu - neige)
	return Color(nu + 0.001, neige, herbe, 1.0)


# --- Construction -------------------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_construire_terrain()
	_construire_fleuve()
	_construire_village_grottes()
	_construire_papetiers()
	_construire_champs()
	_construire_debarcaderes()
	_construire_vegetation()
	_construire_rochers()
	_construire_touffes()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_appliquer_ciel()


# --- Le Fleuve Jaune ------------------------------------------------------------------------

func _construire_fleuve() -> void:
	var plan := PlaneMesh.new()
	plan.size = Vector2(300, 4000)
	plan.subdivide_width = 60
	plan.subdivide_depth = 400
	var m := ShaderMaterial.new()
	m.shader = SHADER_EAU
	m.set_shader_parameter("vagues_a", _texture_vagues(graine + 30, 0.02))
	m.set_shader_parameter("vagues_b", _texture_vagues(graine + 31, 0.06))
	m.set_shader_parameter("bruit_ecume", _bruit())
	# Le fleuve « jaune » : chargé de lœss, opaque, brun-ocre.
	m.set_shader_parameter("couleur_profonde", Color(0.2, 0.13, 0.06))
	m.set_shader_parameter("couleur_claire", Color(0.42, 0.3, 0.15))
	m.set_shader_parameter("couleur_ecume", Color(0.5, 0.38, 0.22))
	m.set_shader_parameter("transparence", 0.45)
	m.set_shader_parameter("largeur_ecume", 0.2)
	m.set_shader_parameter("vitesse", 0.03)
	m.set_shader_parameter("hauteur_houle", 0.04)
	var eau := MeshInstance3D.new()
	eau.name = "FleuveJaune"
	eau.mesh = plan
	eau.material_override = m
	eau.position = Vector3((RIVE_OUEST + RIVE_EST) * 0.5, NIVEAU_MER, 0)
	eau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_contenu.add_child(eau)
	# Des glaçons charriés par le courant (en hiver, le fleuve gèle sur ses bords).
	var glacons := Node3D.new()
	glacons.name = "Glacons"
	_contenu.add_child(glacons)
	var glace := StandardMaterial3D.new()
	glace.albedo_color = Color(0.86, 0.88, 0.86)
	glace.roughness = 0.35
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 40
	for k in 70:
		var z := hasard.randf_range(-400.0, 400.0)
		var bord := hasard.randf() < 0.6
		var x := (rive_ouest(z) + hasard.randf_range(0.0, 7.0)) if bord and hasard.randf() < 0.5 \
				else ((rive_est(z) - hasard.randf_range(0.0, 7.0)) if bord else hasard.randf_range(RIVE_OUEST + 8.0, RIVE_EST - 8.0))
		if absf(z - 11.0) < 14.0 and x > RIVE_OUEST + 2.0 and x < RIVE_EST - 2.0:
			continue
		var g := MeshInstance3D.new()
		g.mesh = _cylindre(hasard.randf_range(0.6, 2.6), hasard.randf_range(0.6, 2.6), 0.14, hasard.randi_range(5, 7))
		g.material_override = glace
		g.position = Vector3(x, NIVEAU_MER + 0.03, z)
		g.rotation.y = hasard.randf() * TAU
		g.scale = Vector3(1.0, 1.0, hasard.randf_range(0.5, 1.0))
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glacons.add_child(g)


# --- Le village des maisons-grottes et la ferme de Mei -----------------------------------------

func _construire_village_grottes() -> void:
	var dossier := Node3D.new()
	dossier.name = "VillageGrottes"
	_contenu.add_child(dossier)
	for x: float in GROTTES:
		var zf := pied_falaise(x)
		_facade_yaodong(dossier, Vector3(x, hauteur(x, zf + 2.0) - 0.05, zf + 0.9), 0.0, 3.6)
	# Des murets de terre qui séparent les cours, et des portails de bois.
	var terre := _mat_terre_damee()
	for k in GROTTES.size() - 1:
		var x: float = (GROTTES[k] + GROTTES[k + 1]) * 0.5
		var z0 := pied_falaise(x) + 1.0
		_boite(Vector3(0.6, 1.5, 9.0), Vector3(x, hauteur(x, z0 + 4.5) + 0.6, z0 + 4.5), terre, dossier)
	# Les tas de tiges de millet (le combustible de l'hiver) et les jarres dans les cours.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 8
	for x: float in GROTTES:
		var z0 := pied_falaise(x) + 6.0
		if hasard.randf() < 0.7:
			_meule(dossier, Vector2(x + 2.6, z0 + hasard.randf_range(0, 2)), 0.55)
		for k in hasard.randi_range(1, 3):
			_jarre(dossier, Vector3(x - 2.0 + k * 0.7, hauteur(x, z0 - 3.0), z0 - 3.0), 0.7, hasard.randf() * TAU)
	# Le puits du village, avec son treuil.
	var puits := Vector2(-86, -40)
	var y := hauteur(puits.x, puits.y)
	var margelle := MeshInstance3D.new()
	margelle.mesh = _cylindre(0.8, 0.9, 0.8, 12)
	margelle.material_override = _mat_choix(["old_stone_wall", "stacked_stone_wall"], Color(0.7, 0.66, 0.6), 0.9, 1.0)
	margelle.position = Vector3(puits.x, y + 0.4, puits.y)
	dossier.add_child(margelle)
	var bois := _mat_bois()
	for c: float in [-1.0, 1.0]:
		_boite(Vector3(0.12, 1.6, 0.12), Vector3(puits.x + c * 0.75, y + 1.2, puits.y), bois, dossier, false)
	var treuil := MeshInstance3D.new()
	treuil.mesh = _cylindre(0.12, 0.12, 1.6, 8)
	treuil.material_override = bois
	treuil.rotation.z = PI / 2
	treuil.position = Vector3(puits.x, y + 1.85, puits.y)
	dossier.add_child(treuil)
	# La magnanerie de Mei : la grotte où dorment les œufs de vers à soie, et ses claies
	# vides devant la porte (on les a sorties en catastrophe).
	var bambou := _mat_choix(["riet_01"], Color(0.7, 0.64, 0.42), 0.9, 1.0)
	for k in 3:
		var p := Vector2(-66.0 + k * 1.4, -52.0)
		_boite(Vector3(0.05, 1.6, 1.2), Vector3(p.x, hauteur(p.x, p.y) + 0.8, p.y), bambou, dossier, false).rotation.z = 0.2
	# Une colonne de fumée violette froide qui sort de la grotte de la magnanerie.
	var fumee := Node3D.new()
	fumee.name = "FumeeMagnanerie"
	fumee.set_meta("identifiant", "fumee_magnanerie")
	fumee.add_to_group("decor_quete")
	fumee.position = Vector3(-65, hauteur(-65, -54) + 1.8, pied_falaise(-65) + 0.5)
	dossier.add_child(fumee)
	var lueur := OmniLight3D.new()
	lueur.light_color = Color(0.62, 0.3, 1.0)
	lueur.light_energy = 2.5
	lueur.omni_range = 8.0
	fumee.add_child(lueur)
	_fumee_violette(fumee)
	_fusionner(dossier)


## Une petite colonne de fumée violette (la fracture), en particules douces.
func _fumee_violette(parent: Node3D) -> void:
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.direction = Vector3(0, 1, 0.3)
	p.spread = 12.0
	p.gravity = Vector3(0.2, 0.6, 0.2)
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.0
	var taille := Curve.new()
	taille.max_value = 4.0
	taille.add_point(Vector2(0, 0.5))
	taille.add_point(Vector2(1, 3.5))
	p.scale_amount_curve = taille
	var teinte := Gradient.new()
	teinte.set_color(0, Color(0.5, 0.25, 0.85, 0.55))
	teinte.set_color(1, Color(0.35, 0.3, 0.4, 0.0))
	p.color_ramp = teinte
	p.mesh = _quad_fumee()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)


## Un carré flou, face à la caméra, pour les particules de fumée.
func _quad_fumee() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.6)
	var degrade := Gradient.new()
	degrade.set_color(0, Color(1, 1, 1, 1))
	degrade.set_color(1, Color(1, 1, 1, 0))
	var tache := GradientTexture2D.new()
	tache.gradient = degrade
	tache.fill = GradientTexture2D.FILL_RADIAL
	tache.fill_from = Vector2(0.5, 0.5)
	tache.fill_to = Vector2(0.5, 0.0)
	tache.width = 64
	tache.height = 64
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tache
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	quad.material = m
	return quad


## Une colonne de fumée noire (un incendie), en particules douces.
func _fumee_noire(parent: Node3D, grosse := 1.0) -> void:
	var p := CPUParticles3D.new()
	p.amount = int(60 * grosse)
	p.lifetime = 8.0
	p.preprocess = 8.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.8 * grosse
	p.direction = Vector3(0, 1, 0)
	p.spread = 8.0
	p.gravity = Vector3(0.4, 0.5, 0.1)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 1.6
	var taille := Curve.new()
	taille.max_value = 6.0
	taille.add_point(Vector2(0, 0.8))
	taille.add_point(Vector2(1, 5.0 * grosse))
	p.scale_amount_curve = taille
	var teinte := Gradient.new()
	teinte.set_color(0, Color(0.1, 0.09, 0.08, 0.75))
	teinte.set_color(1, Color(0.35, 0.33, 0.3, 0.0))
	p.color_ramp = teinte
	p.mesh = _quad_fumee()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)


# --- Le village des papetiers -------------------------------------------------------------------

func _construire_papetiers() -> void:
	var dossier := Node3D.new()
	dossier.name = "Papetiers"
	_contenu.add_child(dossier)
	var r := PAPETIERS
	# Quatre maisons autour de la cour (atelier, séchoir couvert, maisons).
	_maison_han(dossier, Vector2(r.position.x + 7, r.position.y + 4), Vector3(9, 2.8, 5), 0.0)
	_maison_han(dossier, Vector2(r.end.x - 8, r.position.y + 4), Vector3(8, 2.6, 5), 0.0)
	_maison_han(dossier, Vector2(r.position.x + 4, r.get_center().y + 4), Vector3(7, 2.6, 4.5), PI / 2, true)
	_maison_han(dossier, Vector2(r.end.x - 3, r.get_center().y + 6), Vector3(7, 2.6, 4.5), -PI / 2, true)
	# Le muret de terre autour du village, ouvert au nord (vers la route) et à l'est.
	var terre := _mat_terre_damee()
	var y := hauteur(r.get_center().x, r.get_center().y)
	_boite(Vector3(r.size.x * 0.4, 1.6, 0.6), Vector3(r.position.x + r.size.x * 0.2, y + 0.6, r.end.y + 2.0), terre, dossier)
	_boite(Vector3(r.size.x * 0.4, 1.6, 0.6), Vector3(r.end.x - r.size.x * 0.2, y + 0.6, r.end.y + 2.0), terre, dossier)
	# Les cuves de pâte : un bac de pierre plein d'une bouillie blanche (écorce, chanvre,
	# chiffons et vieux filets pilés), où l'on plonge le tamis.
	var pierre := _mat_choix(["old_stone_wall", "stacked_stone_wall"], Color(0.62, 0.6, 0.56), 0.9, 1.0)
	var pate := StandardMaterial3D.new()
	pate.albedo_color = Color(0.84, 0.82, 0.74)
	pate.roughness = 0.3
	for c: Vector2 in CUVES:
		var yc := hauteur(c.x, c.y)
		_boite(Vector3(2.2, 0.9, 1.4), Vector3(c.x, yc + 0.45, c.y), pierre, dossier)
		var surface := _boite(Vector3(1.9, 0.02, 1.1), Vector3(c.x, yc + 0.91, c.y), pate, dossier, false)
		surface.name = "Pate"
		# Le tamis de bambou posé sur le bord.
		_boite(Vector3(0.9, 0.04, 0.6), Vector3(c.x + 0.6, yc + 0.98, c.y - 0.3), _mat_roseaux(), dossier, false).rotation.z = 0.15
	# Les séchoirs : des murs enduits où l'on colle les feuilles mouillées au soleil.
	var feuille := StandardMaterial3D.new()
	feuille.albedo_color = Color(0.93, 0.9, 0.82)
	feuille.roughness = 0.95
	for s: Vector2 in SECHOIRS:
		var ys := hauteur(s.x, s.y)
		var horizontal := absf(s.y - r.get_center().y) > 6.0
		var taille := Vector3(6.0, 2.2, 0.5) if horizontal else Vector3(0.5, 2.2, 6.0)
		_boite(taille, Vector3(s.x, ys + 1.1, s.y), _mat_torchis(), dossier)
		_boite(taille + Vector3(0.6, 0.15, 0.6), Vector3(s.x, ys + 2.25, s.y), _mat_paille(), dossier, false)
		for cote: float in [-1.0, 1.0]:
			for i in 6:
				for j in 2:
					var d := -2.3 + i * 0.92
					var q := Vector3(d, 0.75 + j * 0.85, cote * 0.27) if horizontal else Vector3(cote * 0.27, 0.75 + j * 0.85, d)
					var t := Vector3(0.62, 0.72, 0.01) if horizontal else Vector3(0.01, 0.72, 0.62)
					_boite(t, Vector3(s.x, ys, s.y) + q, feuille, dossier, false)
	# Le pilon à bascule : une longue poutre sur un pivot, une tête de bois au-dessus d'un
	# mortier de pierre (on pèse du pied sur l'autre bout pour piler les fibres).
	var pilon := Vector2(20, 36)
	var yp := hauteur(pilon.x, pilon.y)
	var bois := _mat_bois()
	_boite(Vector3(4.2, 0.22, 0.22), Vector3(pilon.x, yp + 0.75, pilon.y), bois, dossier, false).rotation.z = 0.12
	_boite(Vector3(0.3, 0.8, 0.3), Vector3(pilon.x + 0.4, yp + 0.4, pilon.y), bois, dossier, false)
	_boite(Vector3(0.28, 0.6, 0.28), Vector3(pilon.x - 1.9, yp + 0.6, pilon.y), bois, dossier, false)
	var mortier := MeshInstance3D.new()
	mortier.mesh = _cylindre(0.45, 0.5, 0.5, 10)
	mortier.material_override = pierre
	mortier.position = Vector3(pilon.x - 1.9, yp + 0.25, pilon.y)
	dossier.add_child(mortier)
	# L'écorce de mûrier qui trempe, les bottes de chanvre et un tas de vieux chiffons.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 14
	var ecorce := StandardMaterial3D.new()
	ecorce.albedo_color = Color(0.82, 0.74, 0.56)
	ecorce.roughness = 1.0
	for k in 8:
		var q := Vector2(36 + hasard.randf_range(-3, 3), 36 + hasard.randf_range(-2, 2))
		_boite(Vector3(1.6, 0.08, 0.12), Vector3(q.x, hauteur(q.x, q.y) + 0.06 + k * 0.05, q.y), ecorce, dossier, false).rotation.y = hasard.randf() * TAU
	for k in 5:
		var q := Vector2(6 + k * 1.1, 48)
		var botte := MeshInstance3D.new()
		botte.mesh = _cylindre(0.22, 0.26, 1.6, 8)
		botte.material_override = _mat_paille()
		botte.position = Vector3(q.x, hauteur(q.x, q.y) + 0.8, q.y)
		botte.rotation.z = 0.12
		dossier.add_child(botte)
	for k in 12:
		var q := Vector2(44 + hasard.randf_range(-1.5, 1.5), 52 + hasard.randf_range(-1.5, 1.5))
		var tissu: Color = SOIES[hasard.randi() % SOIES.size()].darkened(0.3)
		_boite(Vector3(0.6, 0.12, 0.5), Vector3(q.x, hauteur(q.x, q.y) + 0.06 + hasard.randf() * 0.3, q.y), _mat_feutre(tissu), dossier, false).rotation.y = hasard.randf() * TAU
	# L'incendie du village (jusqu'à ce qu'on ait chassé les brigands).
	var incendie := Node3D.new()
	incendie.name = "IncendiePapetiers"
	incendie.set_meta("identifiant", "incendie_papetiers")
	incendie.add_to_group("decor_quete")
	dossier.add_child(incendie)
	for q: Vector2 in [Vector2(r.position.x + 7, r.position.y + 4), Vector2(r.end.x - 3, r.get_center().y + 6)]:
		var foyer := Node3D.new()
		foyer.position = Vector3(q.x, hauteur(q.x, q.y) + 3.4, q.y)
		incendie.add_child(foyer)
		_fumee_noire(foyer, 1.2)
		var lumiere := OmniLight3D.new()
		lumiere.light_color = Color(1.0, 0.5, 0.2)
		lumiere.light_energy = 3.0
		lumiere.omni_range = 10.0
		foyer.add_child(lumiere)
	_fusionner(dossier)


# --- Les champs, les mûriers et les arbres -----------------------------------------------------

func _construire_champs() -> void:
	var dossier := Node3D.new()
	dossier.name = "Champs"
	_contenu.add_child(dossier)
	# Les meules de tiges de millet dans les champs moissonnés, et les sillons.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 22
	for k in 14:
		var q := Vector2(hasard.randf_range(CHAMPS.position.x + 6, CHAMPS.end.x - 6), hasard.randf_range(CHAMPS.position.y + 6, CHAMPS.end.y - 6))
		_meule(dossier, q, hasard.randf_range(0.7, 1.1))
	_fusionner(dossier)


func _construire_vegetation() -> void:
	var arbres := Node3D.new()
	arbres.name = "Arbres"
	_contenu.add_child(arbres)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 60
	# Les mûriers taillés, en rangs, au sud du village.
	var x := MURIERS.position.x + 3.0
	while x < MURIERS.end.x:
		var z := MURIERS.position.y + 3.0
		while z < MURIERS.end.y:
			var q := Vector2(x + hasard.randf_range(-0.8, 0.8), z + hasard.randf_range(-0.8, 0.8))
			if q.distance_to(SANGLIERS) > 5.0:
				_murier(arbres, q, hasard, hasard.randf_range(0.85, 1.15))
			z += 6.5
		x += 7.0
	# Des mûriers aussi autour des papetiers (leur écorce fait le papier).
	for k in 10:
		var q := Vector2(hasard.randf_range(-8, 64), hasard.randf_range(78, 96))
		_murier(arbres, q, hasard, hasard.randf_range(0.9, 1.2))
	# Des peupliers le long de la route et au bord du fleuve.
	for k in 26:
		var t := hasard.randf()
		var i := hasard.randi_range(0, ROUTE.size() - 2)
		var a: Vector2 = ROUTE[i]
		var b: Vector2 = ROUTE[i + 1]
		var q := a.lerp(b, t) + Vector2(0, (8.0 + hasard.randf() * 4.0) * (1.0 if hasard.randf() < 0.5 else -1.0))
		if _dans_rect(PAPETIERS.grow(4.0), q.x, q.y, 0.1) > 0.5 or q.x > RIVE_OUEST - 10.0 or q.x < -168.0:
			continue
		_peuplier_hiver(arbres, q, hasard, hasard.randf_range(0.85, 1.15))
	for k in 16:
		var z := hasard.randf_range(-160.0, 160.0)
		if absf(z - 11.0) < 14.0:
			continue
		var est := hasard.randf() < 0.5
		var q := Vector2(rive_est(z) + hasard.randf_range(6, 16), z) if est else Vector2(rive_ouest(z) - hasard.randf_range(6, 14), z)
		if q.x > 170.0 or q.distance_to(RELAIS_BAC) < 10.0 or q.distance_to(PIRATES) < 8.0:
			continue
		_peuplier_hiver(arbres, q, hasard, hasard.randf_range(0.9, 1.2))
	# Des jujubiers épineux et des buissons secs sur les talus.
	var buissons := Node3D.new()
	buissons.name = "Buissons"
	_contenu.add_child(buissons)
	var plantes := 0
	var essais := 0
	while plantes < 120 and essais < 2000:
		essais += 1
		var q := Vector2(hasard.randf_range(-170.0, 76.0), hasard.randf_range(-170.0, 170.0))
		if distance_route(q) < 7.0 or _dans_rect(VILLAGE.grow(3.0), q.x, q.y, 0.1) > 0.5 \
				or _dans_rect(PAPETIERS.grow(5.0), q.x, q.y, 0.1) > 0.5 or _dans_rect(CHAMPS, q.x, q.y, 0.1) > 0.5 \
				or _dans_rect(MURIERS, q.x, q.y, 0.1) > 0.5 or q.distance_to(FAILLE) < 8.0 or q.distance_to(SOLITAIRE) < 8.0:
			continue
		_tamaris(buissons, q, hasard, hasard.randf_range(0.5, 1.0))
		plantes += 1
	_fusionner(buissons)


func _construire_rochers() -> void:
	var dossier := Node3D.new()
	dossier.name = "Rochers"
	_contenu.add_child(dossier)
	_preparer_rochers()
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 12
	var poses := 0
	var essais := 0
	# Quelques blocs de lœss durci tombés de la falaise et des terrasses.
	while poses < 30 and essais < 600:
		essais += 1
		var x := hasard.randf_range(-170.0, 70.0)
		var z := hasard.randf_range(-170.0, 170.0)
		var p := Vector2(x, z)
		if distance_route(p) < 8.0 or _dans_rect(VILLAGE.grow(2.0), x, z, 0.1) > 0.5 or _dans_rect(PAPETIERS.grow(6.0), x, z, 0.1) > 0.5 \
				or _dans_rect(CHAMPS, x, z, 0.1) > 0.5 or _dans_rect(MURIERS, x, z, 0.1) > 0.5:
			continue
		_placer_rocher(dossier, x, z, hasard.randf_range(0.5, 1.8))
		poses += 1


# --- Les débarcadères, le bac et le relais de l'autre rive -----------------------------------------

func _construire_debarcaderes() -> void:
	var dossier := Node3D.new()
	dossier.name = "Debarcaderes"
	_contenu.add_child(dossier)
	var bois := _mat_bois()
	# Des pieux d'amarrage le long des rampes, des deux côtés.
	for quai: Vector2 in [QUAI_OUEST, QUAI_EST]:
		var sens := 1.0 if quai == QUAI_OUEST else -1.0
		for k in 4:
			for c: float in [-1.0, 1.0]:
				var q := quai + Vector2(sens * (k * 2.2 - 2.0), c * 5.0)
				var pieu := MeshInstance3D.new()
				pieu.mesh = _cylindre(0.1, 0.13, 2.2, 6)
				pieu.material_override = bois
				pieu.position = Vector3(q.x, maxf(hauteur(q.x, q.y), -0.6) + 0.6, q.y)
				dossier.add_child(pieu)
	# La cabane du vieux Bo, côté ouest, et ses barques tirées sur la berge.
	_maison_han(dossier, VIEUX_BO + Vector2(-8, -6), Vector3(4.5, 2.3, 3.5), PI / 2, true)
	for k in 2:
		_sampan(dossier, Vector2(RIVE_OUEST - 3.0, -6.0 - k * 4.0), PI / 2 + 0.2 * k)
	# Le relais du bac, sur l'autre rive : une maison, une écurie, la borne de la route.
	_maison_han(dossier, RELAIS_BAC, Vector3(9, 2.8, 5), 0.0)
	_maison_han(dossier, RELAIS_BAC + Vector2(12, 4), Vector3(6, 2.4, 4), -PI / 2, true)
	_sampan(dossier, Vector2(RIVE_EST + 2.0, 30.0), -PI / 2)
	_fusionner(dossier)


## Une petite barque à fond plat (un sampan), tirée sur la berge, avec son toit de nattes.
func _sampan(parent: Node3D, p: Vector2, angle: float) -> Node3D:
	var b := Node3D.new()
	b.name = "Sampan"
	b.position = Vector3(p.x, maxf(hauteur(p.x, p.y), NIVEAU_MER - 0.1) + 0.15, p.y)
	b.rotation.y = angle
	parent.add_child(b)
	var bois := _mat_choix(["weathered_planks", "wooden_rough_planks"], Color(0.5, 0.42, 0.32), 0.9, 1.0)
	_boite(Vector3(1.6, 0.25, 6.0), Vector3(0, 0.12, 0), bois, b, false)
	for c: float in [-1.0, 1.0]:
		var bord := _boite(Vector3(0.1, 0.5, 6.0), Vector3(c * 0.8, 0.4, 0), bois, b, false)
		bord.rotation.z = c * 0.25
	for c: float in [-1.0, 1.0]:
		var pointe := _boite(Vector3(1.4, 0.3, 0.9), Vector3(0, 0.35, c * 3.1), bois, b, false)
		pointe.rotation.x = -c * 0.35
	var natte := MeshInstance3D.new()
	var demi := CylinderMesh.new()
	demi.top_radius = 0.85
	demi.bottom_radius = 0.85
	demi.height = 2.0
	demi.radial_segments = 10
	natte.mesh = demi
	natte.material_override = _mat_roseaux()
	natte.rotation.x = PI / 2
	natte.position = Vector3(0, 0.45, 0.6)
	natte.scale = Vector3(1, 1, 0.7)
	b.add_child(natte)
	return b


## Le grand bac du vieux Bo : un ponton à fond plat, des bordages bas, une cabane de nattes
## à l'arrière et la grande godille.
func _habiller_bac(barque: Node3D, longueur: float) -> void:
	var bois := _mat_choix(["weathered_planks", "wooden_rough_planks"], Color(0.48, 0.4, 0.3), 0.9, 1.0)
	var large := 3.6
	_boite(Vector3(large, 0.45, longueur), Vector3(0, -0.05, 0), bois, barque, false)
	for c: float in [-1.0, 1.0]:
		_boite(Vector3(0.14, 0.55, longueur), Vector3(c * large * 0.5, 0.35, 0), bois, barque, false)
	# L'avant et l'arrière relevés, comme sur les bacs du fleuve.
	for c: float in [-1.0, 1.0]:
		var bout := _boite(Vector3(large, 0.35, 1.2), Vector3(0, 0.25, c * (longueur * 0.5 + 0.45)), bois, barque, false)
		bout.rotation.x = -c * 0.3
	var natte := MeshInstance3D.new()
	var demi := CylinderMesh.new()
	demi.top_radius = 1.5
	demi.bottom_radius = 1.5
	demi.height = 2.4
	demi.radial_segments = 12
	natte.mesh = demi
	natte.material_override = _mat_roseaux()
	natte.rotation.x = PI / 2
	natte.position = Vector3(0, 0.6, longueur * 0.5 - 1.6)
	natte.scale = Vector3(1, 1, 0.75)
	barque.add_child(natte)
	var godille := _boite(Vector3(0.14, 0.14, 5.0), Vector3(0.6, 0.9, longueur * 0.5 + 2.0), bois, barque, false)
	godille.rotation.x = 0.25
	# Des ballots et des jarres de passagers.
	_ballots_soie(barque, Vector2.ZERO, 0.0, 3).position = Vector3(-1.0, 0.2, -longueur * 0.3)
	for k in 2:
		_jarre(barque, Vector3(1.1, 0.2, -longueur * 0.25 + k * 0.7), 0.7, k * 1.3)


# --- Paysage lointain ----------------------------------------------------------------------

func _construire_lointain() -> void:
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.8
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 70
	# La plaine continue des deux côtés du fleuve (le fleuve, lui, file au nord et au sud).
	_plan_lointain(Vector3(-962, SOL - 1.2, 0), Vector2(2080, 4000), Color(0, 0.1, 0.9))
	_plan_lointain(Vector3(1072, SOL - 1.2, 0), Vector2(1856, 4000), Color(0, 0.1, 0.9))
	# Les collines de lœss au nord et à l'ouest, et les monts Mang, bas et bleus, au sud-est.
	for m in [[Vector3(-500, -10, -900), Vector3(1400, 160, 500)], [Vector3(500, -10, -1300), Vector3(1200, 120, 600)],
			[Vector3(-1500, -10, 100), Vector3(600, 140, 1200)], [Vector3(700, -10, 1100), Vector3(1400, 110, 500)],
			[Vector3(-500, -10, 1200), Vector3(1200, 90, 500)]]:
		bruit.seed = graine + hasard.randi()
		var colline := MeshInstance3D.new()
		colline.mesh = _maillage_bosse(bruit, m[1], 1.4, 0.3, 28, Color(0.2, 0.15, 0.2))
		colline.material_override = _mat_lointain()
		colline.position = m[0]
		colline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(colline)
	# Des villages lointains sur l'autre rive : de petits toits gris.
	var lointain := Node3D.new()
	lointain.name = "VillagesLointains"
	_contenu.add_child(lointain)
	var tuiles := _mat_tuiles_han()
	var torchis := _mat_torchis()
	for k in 18:
		var p := Vector3(hasard.randf_range(220, 600), SOL - 1.2, hasard.randf_range(-500, 500))
		_boite(Vector3(8, 3, 5), p + Vector3(0, 1.5, 0), torchis, lointain, false)
		var toit := _boite(Vector3(9, 0.4, 6.4), p + Vector3(0, 3.4, 0), tuiles, lointain, false)
		toit.scale.y = 3.0
	_fusionner(lointain)


# --- Limites de la zone -----------------------------------------------------------------------

func _construire_limites() -> void:
	var limites := Node3D.new()
	limites.name = "Limites"
	_contenu.add_child(limites)
	var demi := taille_terrain * 0.5 - 4.0
	_mur_invisible(limites, Vector3(taille_terrain, 120, 2), Vector3(0, 40, -demi))
	_mur_invisible(limites, Vector3(taille_terrain, 120, 2), Vector3(0, 40, demi))
	# À l'ouest, on repart vers la Porte de Jade par la route (on ne passe qu'à cet endroit).
	_mur_invisible(limites, Vector3(2, 120, taille_terrain * 0.5 - 6.0), Vector3(-demi - 2.0, 40, -demi * 0.5 - 1.0))
	_mur_invisible(limites, Vector3(2, 120, taille_terrain * 0.5 - 22.0), Vector3(-demi - 2.0, 40, demi * 0.5 + 9.0))
	_mur_invisible(limites, Vector3(2, 120, taille_terrain), Vector3(demi, 40, 0))
	# Le fleuve : on ne s'aventure pas là où l'on n'a plus pied. Les barrières s'effacent
	# pendant la traversée du bac (groupe « limites_nil », comme pour la barque d'Égypte).
	var pas := 6.0
	var z := -demi
	while z < demi:
		if absf(z + pas * 0.5 - 11.0) > 9.0:
			for cote in [0, 1]:
				var x1 := (rive_ouest(z) + 5.0) if cote == 0 else (rive_est(z) - 5.0)
				var x2 := (rive_ouest(z + pas) + 5.0) if cote == 0 else (rive_est(z + pas) - 5.0)
				var centre := Vector3((x1 + x2) * 0.5, 0.0, z + pas * 0.5)
				_mur_invisible(limites, Vector3(1.0, 12.0, pas + 1.0), centre, atan2(x2 - x1, pas)).add_to_group("limites_nil")
		z += pas
	# Devant chaque débarcadère, un enclos d'eau peu profonde, fermé côté fleuve.
	for quai in [[rive_ouest(11.0) + 5.0, 18.0], [rive_est(11.0) - 5.0, -24.0]]:
		var x0: float = quai[0]
		var l: float = quai[1]
		_mur_invisible(limites, Vector3(1.0, 12.0, 20.0), Vector3(x0 + l, 0.0, 11.0)).add_to_group("limites_nil")
		for c: float in [-1.0, 1.0]:
			_mur_invisible(limites, Vector3(absf(l), 12.0, 1.0), Vector3(x0 + l * 0.5, 0.0, 11.0 + c * 10.0)).add_to_group("limites_nil")
	# La route de Luoyang, à l'est : fermée jusqu'à la fin du chapitre 3.
	_mur_est = _mur_invisible(limites, Vector3(2, 14, 30), Vector3(SORTIE_EST.x - 4.0, hauteur(SORTIE_EST.x, SORTIE_EST.y) + 6.0, SORTIE_EST.y))


# --- Personnages et objets de la quête ----------------------------------------------------------

func _construire_quete() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quete"
	_contenu.add_child(dossier)
	_construire_secondaires(dossier)
	_dossier_quete = dossier
	# La ferme de Mei : Mei, les villageois, et les claies d'œufs de vers à soie.
	_pnj(dossier, "mei", MEI, PI * 0.1)
	for k in VILLAGEOIS.size():
		_pnj(dossier, "villageois_loess_%d" % (k + 1), VILLAGEOIS[k], PI * (0.2 + k * 0.5))
	for k in OEUFS.size():
		var p: Vector2 = OEUFS[k]
		var claie := ObjetChine.new()
		claie.name = "Oeufs%d" % k
		claie.identifiant = "oeufs_%d" % k
		claie.groupe = "carte_oeufs"
		claie.forme = "oeufs"
		claie.invite = "[F] Sauver les œufs de vers à soie"
		claie.portee = 2.6
		claie.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
		dossier.add_child(claie)
	# Les papetiers : Lao Fan, ses ouvriers, et les feuilles qui sèchent.
	_pnj(dossier, "lao_fan", LAO_FAN, PI)
	for k in PAPETIERS_PNJ.size():
		_pnj(dossier, "papetier_%d" % (k + 1), PAPETIERS_PNJ[k], PI * (0.3 + k * 0.6))
	for k in FEUILLES.size():
		var p: Vector2 = FEUILLES[k]
		var f := ObjetChine.new()
		f.name = "Feuille%d" % k
		f.identifiant = "feuille_%d" % k
		f.groupe = "feuille_papier"
		f.forme = "feuille_papier"
		f.invite = "[F] Décoller la feuille avant qu'elle ne brûle"
		f.portee = 2.4
		f.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
		var c := PAPETIERS.get_center()
		f.rotation.y = atan2(c.x - p.x, c.y - p.y) + PI
		dossier.add_child(f)
	var faille := Faille.new()
	faille.name = "Faille"
	faille.identifiant = "faille_loess"
	faille.position = Vector3(FAILLE.x, hauteur(FAILLE.x, FAILLE.y), FAILLE.y)
	dossier.add_child(faille)
	# Le bac : le vieux Bo, Lao Fan qui attend, et le grand bac à quai.
	_pnj(dossier, "vieux_bo", VIEUX_BO, PI / 2)
	var lao_fan_bac := _pnj(dossier, "lao_fan_bac", LAO_FAN_BAC, PI / 2)
	lao_fan_bac.add_to_group("decor_quete")
	lao_fan_bac.set_meta("identifiant", "lao_fan_bac")
	lao_fan_bac.visible = false
	var bac := BarqueTraversee.new()
	bac.name = "GrandBac"
	bac.chemin = TRAVERSEE
	bac.destination = ""
	bac.longueur = 11.0
	bac.vitesse = 2.4
	bac.paroles = [
		[0.15, "Le vieux Bo", "« Accroche-toi, étranger. Le fleuve est bas en hiver, mais il a mauvais caractère. »"],
		[0.5, "Le Fleuve Jaune", "L'eau est si chargée de terre qu'elle ressemble à de la soupe de millet. Des glaçons cognent contre la coque."],
		[0.8, "Lao Fan", "« Là-bas, sur la rive ! Des hommes nous attendent... Ce ne sont pas des douaniers. »"],
	]
	bac.position = Vector3(BAC.x, -0.1, BAC.y)
	bac.rotation.y = -PI / 2
	bac.set_meta("identifiant", "grand_bac")
	dossier.add_child(bac)
	_habiller_bac(bac, 11.0)
	var monter := ObjetChine.new()
	monter.name = "MonterBac"
	monter.identifiant = "monter_bac"
	monter.invite = "[F] Monter sur le grand bac"
	monter.portee = 4.0
	monter.position = Vector3(MONTER_BAC.x, hauteur(MONTER_BAC.x, MONTER_BAC.y), MONTER_BAC.y)
	dossier.add_child(monter)
	# Le passeur, pour repasser le fleuve dans les deux sens une fois le bac parti.
	for rive in [[PASSEUR_OUEST, QUAI_EST + Vector2(6, 6), PI / 2, "la rive est (la route de Luoyang)"],
			[PASSEUR_EST, QUAI_OUEST + Vector2(-6, -6), -PI / 2, "la rive ouest (les terres de lœss)"]]:
		var passeur := BacPasseur.new()
		passeur.name = "Passeur"
		passeur.arrivee = rive[1]
		passeur.angle_arrivee = rive[2]
		passeur.nom_rive = rive[3]
		passeur.condition = "pirates"
		var q: Vector2 = rive[0]
		passeur.position = Vector3(q.x, hauteur(q.x, q.y), q.y)
		dossier.add_child(passeur)
	_pnj(dossier, "batelier_est", PASSEUR_EST + Vector2(4.0, 3.5), -PI / 2)
	# Lao Fan sur l'autre rive (il a traversé avec toi).
	var lao_fan_est := _pnj(dossier, "lao_fan_est", LAO_FAN_EST, PI * 0.6)
	lao_fan_est.add_to_group("decor_quete")
	lao_fan_est.set_meta("identifiant", "lao_fan_est")
	lao_fan_est.visible = false
	_pnj(dossier, "maitre_relais", RELAIS_BAC + Vector2(-2, 4), 0.2)
	# Repères de la carte.
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.LIEU, "Village des maisons-grottes", Vector2(-60, -46))
	repere.call(MarqueurCarte.Type.LIEU, "Village des papetiers", PAPETIERS.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Le bac du Fleuve Jaune", QUAI_OUEST)
	repere.call(MarqueurCarte.Type.LIEU, "Relais du bac", RELAIS_BAC)
	repere.call(MarqueurCarte.Type.LIEU, "Champs de millet", CHAMPS.get_center())
	repere.call(MarqueurCarte.Type.DANGER, "Faille", FAILLE)
	repere.call(MarqueurCarte.Type.LIEU, "Route de la soie, vers la Porte de Jade", ENTREE)
	repere.call(MarqueurCarte.Type.LIEU, "Route de Luoyang", SORTIE_EST)


# --- Les routes de l'ouest et de l'est ---------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	if Engine.is_editor_hint():
		return
	_attente_sortie -= delta
	if _attente_sortie > 0.0:
		return
	_attente_sortie = 0.3
	var quete := get_tree().get_first_node_in_group("quete")
	if quete == null or not quete.has_method("etape_atteinte"):
		return
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return
	var p := Vector2(joueur.global_position.x, joueur.global_position.z)
	# Vers l'ouest : la Porte de Jade, toujours ouverte.
	if p.distance_to(ENTREE) < 5.0:
		quete.changer_de_zone("porte_de_jade")
		return
	if not _est_ouvert:
		if not quete.etape_atteinte("vers_luoyang"):
			return
		_est_ouvert = true
		if _mur_est != null and is_instance_valid(_mur_est):
			_mur_est.queue_free()
	if p.distance_to(SORTIE_EST) < 6.0 and quete.donnees.get("zones", {}).has("luoyang"):
		quete.changer_de_zone("luoyang")


## Les personnages des quêtes secondaires (data/chine_secondaires.json).
func _construire_secondaires(dossier: Node3D) -> void:
	_pnj(dossier, "caravanier_fleuve", Vector2(-162, 18), PI * 0.5)
