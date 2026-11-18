@tool
extends "res://scripts/monde/mayence/ile_mayence.gd"
## Île de Mayence, zone 2 : le Rhin et le moulin à papier (niveaux 62-65).
##
## Un matin d'octobre 1450, en aval de Mayence. Le Rhin coule au sud, très large, couvert de
## bateaux. Sur la rive, le petit port d'Eltville : ses maisons à colombages, le donjon de
## grès du château de l'archevêque, un quai de pierre et sa grue à roue d'écureuil qui décharge
## les ballots de chiffons. Au milieu de la zone, un ruisseau (la Walluf) descend du Taunus
## dans un vallon boisé ; sur sa rive est, le moulin à papier de Greta : la roue à aubes, les
## maillets qui battent les chiffons, la cuve, et les séchoirs où les feuilles pendent sur des
## cordes. Au nord, la forêt ; au fond, le camp de Sceau et la faille. À l'est, la route mène
## au bac qui traverse vers Mayence. On arrive du Rheingau par la route de l'ouest.
##
## Tout est construit par le code (voir ile_mayence.gd). Repères : le nord est vers -Z.

const Faille := preload("res://scripts/monde/prehistoire/faille.gd")
const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const ObjetMayence := preload("res://scripts/monde/mayence/objet_mayence.gd")

## Le Rhin : la berge, le niveau de l'eau.
const BERGE_Z := 128.0
const NIVEAU_RHIN := 0.4
## La route du fleuve, d'ouest (le Rheingau) en est (le bac de Mayence).
const ROUTE := [Vector2(-170, 112), Vector2(-120, 108), Vector2(-80, 106), Vector2(-40, 104), Vector2(0, 106),
		Vector2(40, 110), Vector2(66, 112), Vector2(100, 112), Vector2(140, 114), Vector2(170, 116)]
const ARRIVEE := Vector2(-150, 109)
const SORTIE_O := Vector2(-165, 111)
const SORTIE_E := Vector2(165, 115)
## Le port d'Eltville : la place, le quai, la grue, le batelier, le château de l'archevêque.
const PORT := Vector2(-40, 98)
const QUAI := Rect2(-74, 116, 66, 9)
const Y_QUAI := 4.9
const GRUE := Vector2(-28, 121)
const JAKOB := Vector2(-46, 118)
const SCELLES_GRUE := [Vector2(-34, 118), Vector2(-21, 117)]
const BURG := Vector2(-112, 86)
const MAISONS := [[Vector2(-60, 92), 0.0, Color(0.94, 0.9, 0.8)], [Vector2(-48, 86), PI, Color(0.9, 0.78, 0.62)],
		[Vector2(-30, 90), 0.05, Color(0.92, 0.86, 0.72)], [Vector2(-18, 96), -PI / 2, Color(0.86, 0.68, 0.6)],
		[Vector2(-72, 98), PI / 2, Color(0.95, 0.92, 0.84)], [Vector2(-8, 88), -0.1, Color(0.9, 0.82, 0.66)],
		[Vector2(-84, 94), 0.0, Color(0.88, 0.84, 0.76)], [Vector2(-36, 78), PI, Color(0.92, 0.8, 0.7)],
		[Vector2(-62, 78), 0.1, Color(0.9, 0.86, 0.8)]]
## Le ruisseau (la Walluf), du Taunus (nord) jusqu'au Rhin, et le pont de la route.
const RUISSEAU := [Vector2(30, -175), Vector2(40, -130), Vector2(56, -96), Vector2(66, -60), Vector2(68, -24),
		Vector2(62, 10), Vector2(58, 46), Vector2(62, 80), Vector2(65, 112), Vector2(68, 140)]
const PONT := Vector2(65, 112)
## Le moulin à papier, sur la rive est : le bâtiment, la roue, les maillets, la cuve, Greta.
const REPLAT := Rect2(74, -62, 42, 74)
const MOULIN := Vector2(80, -26)
const ROUE_MOULIN := Vector2(71.2, -26)
const MAILLETS := Vector2(79, -12)
const CUVE := Vector2(90.5, -24)
const GRETA := Vector2(92, -20)
const VANNE := Vector2(70.5, -44)
const CHIFFONS := Vector2(96, -54)
const SECHOIRS := [Vector2(102, -40), Vector2(106, -18), Vector2(100, 2)]
## Le chemin du moulin (depuis le pont) et celui de la forêt (jusqu'au camp de Sceau).
const CHEMIN := [Vector2(72, 110), Vector2(76, 74), Vector2(74, 40), Vector2(80, 8), Vector2(86, -10),
		Vector2(92, -40), Vector2(100, -66), Vector2(112, -92), Vector2(122, -112)]
## La forêt : les rames de papier perdues, le camp de Sceau, son incendiaire, la faille.
const RAMES := [Vector2(102, -72), Vector2(116, -94), Vector2(90, -100)]
const CAMP := Vector2(124, -118)
const CHEF := Vector2(130, -124)
const LETTRE := Vector2(117, -113)
const FAILLE := Vector2(144, -140)
## Le bac de Mayence, à l'est.
const BAC := Vector2(150, 126)

var _mur_e: StaticBody3D
var _nefs: Array[Node3D] = []
var _roue: Node3D
var _maillets: Array[Node3D] = []
var _eau_ruisseau: StandardMaterial3D


func _init() -> void:
	identifiant_zone = "rhin"
	taille_terrain = 340
	graine = 1451
	point_apparition = ARRIVEE
	nombre_touffes = 30000
	fertilite_sols = Vector3(0.08, 0.3, 1.0)
	neige_qui_tombe = false
	sols = {
		# Rouge : la terre battue de la route et des chemins, les galets de la berge et du ruisseau.
		"galets": ["brown_mud_02", "dry_river_pebbles", "dry_ground_rocks"],
		# Vert : le sol de la forêt (feuilles mortes, terre noire).
		"neige": ["brown_mud_02", "brown_mud_rocks_01", "brown_mud_02"],
		# Bleu : les prés et les talus.
		"sol": ["withered_grass", "brown_mud_02", "dry_ground_01"],
		"roche": ["rock_wall_10", "cliff_side", "stacked_stone_wall"],
	}
	reglages_terrain = {"sol_saturation": 1.18, "sol_motif": 6.0, "galets_motif": 4.0, "neige_motif": 5.0,
			"sol_teinte": Color(0.68, 0.82, 0.46), "roche_teinte": Color(0.82, 0.78, 0.74), "roche_saturation": 0.8,
			"neige_eclat": 1.0, "neige_paillettes": 0.0, "roche_motif": 8.0,
			"neige_teinte": Color(0.8, 0.66, 0.52), "neige_max": Vector3(0.58, 0.44, 0.32), "neige_simple": Color(0.4, 0.3, 0.22),
			"givre": 0.0, "neige_translucide": 0.0}
	reglages_herbe = {"couleur_base": Color(0.18, 0.27, 0.1), "couleur_pointe": Color(0.6, 0.66, 0.3),
			"couleur_givre": Color(0.74, 0.62, 0.36), "force_vent": 0.5}
	reglages_couvre_sol = {"cailloux": 3.0, "fleurs": [Color(0.95, 0.92, 0.85), Color(0.96, 0.8, 0.2), Color(0.62, 0.36, 0.86)],
			"densite_fleurs": 1.6, "buissons": 0.6, "litiere": 3.0}
	piste = CHEMIN.duplicate()


func _ready() -> void:
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_mayence", "") == "ville":
		Reseau.remove_meta("arrivee_mayence")
		# Retour de Mayence : on arrive au bac, à l'est.
		point_apparition = SORTIE_E + Vector2(-12, -3)
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	if zone == "rheingau":
		return SORTIE_O
	if zone == "rhin":
		return Vector2.INF
	return SORTIE_E


# --- Relief -----------------------------------------------------------------------------

func _preparer_bruits() -> void:
	super._preparer_bruits()
	_relief.frequency = 0.007


func _distance_ligne(p: Vector2, ligne: Array) -> float:
	var meilleure := INF
	for i in ligne.size() - 1:
		meilleure = minf(meilleure, _distance_segment(p, ligne[i], ligne[i + 1]))
	return meilleure


func distance_route(p: Vector2) -> float:
	return _distance_ligne(p, ROUTE)


func distance_ruisseau(p: Vector2) -> float:
	return _distance_ligne(p, RUISSEAU)


## Le niveau de l'eau du ruisseau (il descend doucement vers le Rhin).
func niveau_ruisseau(z: float) -> float:
	var n := 1.0 + (BERGE_Z - z) * 0.085
	return lerpf(n, NIVEAU_RHIN + 0.05, smoothstep(BERGE_Z - 14.0, BERGE_Z, z))


## Le coteau sans le vallon : il monte du Rhin (sud) vers le Taunus (nord).
func _coteau(x: float, z: float) -> float:
	var bruit := _relief.get_noise_2d(x, z)
	var calme := smoothstep(BERGE_Z + 4.0, BERGE_Z - 60.0, z)
	var h := 3.2 + (BERGE_Z - z) * 0.12 + bruit * 4.0 * calme
	# La berge descend sous l'eau.
	h = lerpf(h, -2.5, smoothstep(BERGE_Z - 8.0, BERGE_Z + 8.0, z))
	return h


func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	var p := Vector2(x, z)
	var h := _coteau(x, z)
	h += _details.get_noise_2d(x * 3.0, z * 3.0) * 0.08
	# La route, un peu creusée, mais pas au-dessus du ruisseau (le pont passe par-dessus).
	var d_ruisseau := distance_ruisseau(p)
	var pres_ruisseau := 1.0 - smoothstep(4.0, 9.0, d_ruisseau)
	h = lerpf(h, _coteau(x, z) - 0.15, (1.0 - smoothstep(3.0, 8.0, distance_route(p))) * 0.85 * (1.0 - pres_ruisseau))
	# Le port et la place, presque plats ; le replat du moulin taillé dans le versant.
	h = lerpf(h, 4.6 + _relief.get_noise_2d(x, z) * 0.4, 1.0 - smoothstep(34.0, 56.0, p.distance_to(PORT + Vector2(-10, 0))))
	h = lerpf(h, niveau_ruisseau(MOULIN.y) + 1.7, _dans_rect(REPLAT, x, z, 38.0))
	h = lerpf(h, _coteau(CAMP.x, CAMP.y), 1.0 - smoothstep(10.0, 20.0, p.distance_to(CAMP)))
	# Le vallon du ruisseau : des versants en V, et le lit creusé au fond.
	var n := niveau_ruisseau(z)
	h = minf(h, n + 0.8 + maxf(d_ruisseau - 3.0, 0.0) * 0.36)
	h = lerpf(h, n - 0.7, 1.0 - smoothstep(1.8, 3.2, d_ruisseau))
	h = lerpf(h, h - 0.08, 1.0 - smoothstep(2.0, 4.0, _distance_piste(p)))
	return h


## Rouge : terre battue et galets ; vert : sol de la forêt ; bleu : prés.
func _parts_sol(x: float, z: float, h: float) -> Color:
	var p := Vector2(x, z)
	var n := _relief.get_noise_2d(x * 2.0 + 60.0, z * 2.0)
	var terre := 1.0 - smoothstep(2.5, 5.5 + n * 1.5, distance_route(p))
	terre = maxf(terre, 1.0 - smoothstep(1.2, 2.8, _distance_piste(p)))
	terre = maxf(terre, 1.0 - smoothstep(16.0, 26.0, p.distance_to(PORT + Vector2(-8, 4))))
	terre = maxf(terre, smoothstep(BERGE_Z - 10.0, BERGE_Z - 2.0, z))
	terre = maxf(terre, 1.0 - smoothstep(3.0, 5.0, distance_ruisseau(p)))
	terre = maxf(terre, _dans_rect(REPLAT.grow(-6.0), x, z, 6.0) * 0.8)
	terre = maxf(terre, 1.0 - smoothstep(6.0, 11.0, p.distance_to(CAMP)))
	var foret := smoothstep(-50.0, -80.0, z + n * 12.0) * (1.0 - terre)
	var pre := maxf(0.0, 1.0 - foret - terre)
	return Color(terre + 0.001, foret, pre, 1.0)


# --- Construction -------------------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_construire_terrain()
	_construire_rhin()
	_construire_ruisseau()
	_construire_port()
	_construire_moulin()
	_construire_camp()
	_construire_bac()
	_construire_vegetation()
	_construire_touffes()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_appliquer_ciel()


func _construire_rhin() -> void:
	_eau_du_rhin(Vector3(0, NIVEAU_RHIN, BERGE_Z + 420.0), Vector2(5200, 860))
	var dossier := Node3D.new()
	dossier.name = "Bateaux"
	_contenu.add_child(dossier)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 7
	# Les barques et les nefs amarrées le long du quai d'Eltville.
	for k in 5:
		var b := _barque_rhin(dossier, Vector3(-70 + k * 14 + hasard.randf_range(-2, 2), NIVEAU_RHIN + 0.1, QUAI.end.y + 4.0 + hasard.randf_range(0, 2)),
				PI * 0.5 + hasard.randf_range(-0.15, 0.15))
		b.name = "Barque%d" % k
	var amarree := _nef_du_rhin(dossier, Vector3(-48, NIVEAU_RHIN + 0.2, QUAI.end.y + 9.0), PI / 2, Color(0.88, 0.84, 0.76))
	amarree.name = "NefAmarree"
	# Au large, les nefs qui descendent ou remontent le fleuve.
	for k in 3:
		var n := _nef_du_rhin(dossier, Vector3(-260 + k * 260, NIVEAU_RHIN + 0.2, BERGE_Z + 80.0 + k * 50.0), PI / 2,
				[Color(0.74, 0.3, 0.22), Color(0.88, 0.82, 0.7), Color(0.86, 0.84, 0.78)][k])
		_nefs.append(n)


## Le ruisseau : un ruban d'eau qui suit le lit, du Taunus au Rhin (l'eau défile).
func _construire_ruisseau() -> void:
	var points: Array[Vector2] = []
	for i in RUISSEAU.size() - 1:
		var a: Vector2 = RUISSEAU[i]
		var b: Vector2 = RUISSEAU[i + 1]
		var pas := int(ceilf(a.distance_to(b) / 2.0))
		for k in pas:
			points.append(a.lerp(b, float(k) / pas))
	points.append(RUISSEAU[-1])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var longueur := 0.0
	var largeur := 2.6
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var dir := (b - a).normalized()
		var cote := Vector2(-dir.y, dir.x) * largeur
		var ya := niveau_ruisseau(a.y)
		var yb := niveau_ruisseau(b.y)
		var l2 := longueur + a.distance_to(b)
		var sommets := [Vector3(a.x - cote.x, ya, a.y - cote.y), Vector3(a.x + cote.x, ya, a.y + cote.y),
				Vector3(b.x + cote.x, yb, b.y + cote.y), Vector3(b.x - cote.x, yb, b.y - cote.y)]
		var uvs := [Vector2(0, longueur / 5.0), Vector2(1, longueur / 5.0), Vector2(1, l2 / 5.0), Vector2(0, l2 / 5.0)]
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uvs[k])
			st.add_vertex(sommets[k])
		longueur = l2
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.28, 0.24, 0.82)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic = 0.2
	m.metallic_specular = 0.8
	m.normal_enabled = true
	m.normal_texture = _texture_vagues(graine + 33, 0.08)
	m.normal_scale = 0.7
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_eau_ruisseau = m
	var eau := MeshInstance3D.new()
	eau.name = "Ruisseau"
	eau.mesh = st.commit()
	eau.material_override = m
	eau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_contenu.add_child(eau)
	# Des galets et des pierres moussues dans le lit.
	var dossier := Node3D.new()
	dossier.name = "LitRuisseau"
	_contenu.add_child(dossier)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 21
	var pierre := _mat_schiste()
	for k in 90:
		var q: Vector2 = points[hasard.randi() % points.size()]
		q += Vector2(hasard.randf_range(-3.4, 3.4), hasard.randf_range(-1.0, 1.0))
		var s := hasard.randf_range(0.3, 0.8)
		var galet := _boite(Vector3(s, s * 0.5, s * 0.8), Vector3(q.x, hauteur(q.x, q.y) + s * 0.15, q.y), pierre, dossier, false)
		galet.rotation = Vector3(hasard.randf() * 0.3, hasard.randf() * TAU, hasard.randf() * 0.3)
	_fusionner(dossier)
	# Le pont de pierre de la route : une arche de grès, un tablier et deux parapets.
	var pont := Node3D.new()
	pont.name = "Pont"
	_contenu.add_child(pont)
	var y := maxf(hauteur(PONT.x - 8.0, PONT.y), hauteur(PONT.x + 8.0, PONT.y))
	var gres := _mat_gres_rouge()
	_boite(Vector3(18.0, 0.5, 4.6), Vector3(PONT.x, y - 0.2, PONT.y), _mat_schiste(), pont)
	for cote: float in [-1.0, 1.0]:
		_boite(Vector3(12.0, 0.7, 0.4), Vector3(PONT.x, y + 0.4, PONT.y + cote * 2.1), gres, pont)
		_boite(Vector3(1.6, y - niveau_ruisseau(PONT.y) + 1.4, 4.8), Vector3(PONT.x + cote * 4.2, (y + niveau_ruisseau(PONT.y)) * 0.5 - 0.85, PONT.y), gres, pont)


func _construire_port() -> void:
	var dossier := Node3D.new()
	dossier.name = "Eltville"
	_contenu.add_child(dossier)
	for k in MAISONS.size():
		var m: Array = MAISONS[k]
		_maison_rhenane(dossier, m[0], Vector3(6.0 + (k % 3) * 0.8, 6.6 + (k % 2) * 1.0, 8.0), m[1], m[2])
	_puits(dossier, PORT + Vector2(4, 2))
	_charrette(dossier, PORT + Vector2(-6, 10), 0.4, true)
	_auvent(dossier, PORT + Vector2(10, 4), Vector2(4.0, 3.0), 2.4, Color(0.72, 0.24, 0.2))
	_auvent(dossier, PORT + Vector2(-2, -4), Vector2(3.6, 2.6), 2.3, Color(0.86, 0.8, 0.62))
	_fusionner(dossier)
	# Le quai de pierre, avec ses bornes d'amarrage et son escalier.
	var quai := Node3D.new()
	quai.name = "Quai"
	_contenu.add_child(quai)
	var yq := Y_QUAI
	var pierre := _mat_schiste()
	var gres := _mat_gres_rouge()
	_boite(Vector3(QUAI.size.x, yq + 3.0, QUAI.size.y), Vector3(QUAI.get_center().x, (yq - 3.0) * 0.5, QUAI.get_center().y), pierre, quai)
	_boite(Vector3(QUAI.size.x + 0.2, 0.3, 0.7), Vector3(QUAI.get_center().x, yq + 0.05, QUAI.end.y - 0.3), gres, quai, false)
	for k in 7:
		var x := QUAI.position.x + 5.0 + k * 9.4
		var borne := MeshInstance3D.new()
		borne.mesh = _cylindre(0.2, 0.26, 0.8, 10)
		borne.material_override = gres
		borne.position = Vector3(x, yq + 0.4, QUAI.end.y - 1.0)
		quai.add_child(borne)
	# Des ballots de chiffons, des tonneaux et des caisses sur le quai.
	var toile := _mat_uni_ma(Color(0.74, 0.68, 0.56), 1.0)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 5
	for k in 14:
		var c := Vector2(hasard.randf_range(QUAI.position.x + 3.0, QUAI.end.x - 3.0), hasard.randf_range(QUAI.position.y + 1.5, QUAI.end.y - 2.5))
		if c.distance_to(GRUE) < 5.0 or c.distance_to(JAKOB) < 3.0:
			continue
		for sc in SCELLES_GRUE:
			if c.distance_to(sc) < 3.0:
				c = Vector2.INF
		if c == Vector2.INF:
			continue
		if k % 3 == 0:
			var t := MeshInstance3D.new()
			t.mesh = _cylindre(0.42, 0.42, 1.0, 12)
			t.material_override = _mat_chene_clair()
			t.position = Vector3(c.x, yq + 0.5, c.y)
			quai.add_child(t)
		else:
			var b := _boite(Vector3(1.2, 0.8, 0.9), Vector3(c.x, yq + 0.4, c.y), toile, quai, false)
			b.rotation.y = hasard.randf() * TAU
	# La grue du port : une roue d'écureuil sur le quai, la flèche au-dessus de l'eau (elle
	# décharge les ballots de chiffons pour le moulin).
	_roue = _roue_ecureuil(_contenu, GRUE, PI)
	_roue.name = "GrueDuPort"
	_roue.position.y = yq
	var ballot := _roue.find_child("BlocPendu", true, false) as MeshInstance3D
	if ballot != null:
		ballot.material_override = toile
	# Le château de l'archevêque : un gros donjon carré de grès, ses créneaux, un logis et un mur.
	var burg := Node3D.new()
	burg.name = "ChateauArcheveque"
	_contenu.add_child(burg)
	var yb := hauteur(BURG.x, BURG.y)
	var donjon := Vector3(9.0, 26.0, 9.0)
	_boite(donjon, Vector3(BURG.x, yb + donjon.y * 0.5 - 0.5, BURG.y), gres, burg)
	_boite(Vector3(donjon.x + 0.6, 0.8, donjon.z + 0.6), Vector3(BURG.x, yb + 0.2, BURG.y), pierre, burg, false)
	for k in 4:
		for t in 4:
			var bord := -donjon.x * 0.5 + 0.6 + t * (donjon.x - 1.2) / 3.0
			var pos := [Vector3(bord, 0, -donjon.z * 0.5), Vector3(bord, 0, donjon.z * 0.5),
					Vector3(-donjon.x * 0.5, 0, bord), Vector3(donjon.x * 0.5, 0, bord)][k] as Vector3
			_boite(Vector3(1.0, 1.2, 1.0), Vector3(BURG.x, yb + donjon.y + 0.1, BURG.y) + pos, gres, burg, false)
	var sombre := _mat_uni_ma(Color(0.05, 0.05, 0.06), 1.0)
	for k in 3:
		_boite(Vector3(0.8, 1.6, 0.1), Vector3(BURG.x, yb + 9.0 + k * 5.0, BURG.y + donjon.z * 0.5 + 0.03), sombre, burg, false)
	var logis := _maison_rhenane(burg, BURG + Vector2(12, 4), Vector3(8.0, 8.0, 14.0), PI / 2, Color(0.92, 0.88, 0.8))
	logis.name = "LogisArcheveque"
	for seg in [[BURG + Vector2(-8, -10), BURG + Vector2(24, -10)], [BURG + Vector2(24, -10), BURG + Vector2(24, 14)],
			[BURG + Vector2(-8, -10), BURG + Vector2(-8, 14)]]:
		_muret_sec(burg, seg[0], seg[1], 2.6)


## Un séchoir : un hangar ouvert à quatre poteaux, toit d'ardoise, et des cordes où pendent
## les feuilles de papier.
func _sechoir(parent: Node3D, p: Vector2, angle: float) -> Node3D:
	var s := Node3D.new()
	s.name = "Sechoir%d" % parent.get_child_count()
	s.position = Vector3(p.x, hauteur(p.x, p.y) - 0.1, p.y)
	s.rotation.y = angle
	parent.add_child(s)
	var bois := _mat_colombage()
	var taille := Vector3(8.0, 3.6, 5.0)
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			_boite(Vector3(0.24, taille.y, 0.24), Vector3(x * taille.x * 0.5, taille.y * 0.5, z * taille.z * 0.5), bois, s)
			_boite(Vector3(0.5, 0.3, 0.5), Vector3(x * taille.x * 0.5, 0.15, z * taille.z * 0.5), _mat_schiste(), s, false)
	for z: float in [-1.0, 1.0]:
		_boite(Vector3(taille.x + 0.4, 0.22, 0.22), Vector3(0, taille.y, z * taille.z * 0.5), bois, s, false)
	var toit := Node3D.new()
	toit.position = Vector3(0, taille.y, 0)
	s.add_child(toit)
	_toit_pentu(toit, Vector3.ZERO, taille.z + 1.2, taille.x + 1.0, _mat_ardoise(), bois, 0.7, 0.16)
	var papier := _mat_uni_ma(Color(0.95, 0.93, 0.86), 0.95)
	var corde := _mat_uni_ma(Color(0.7, 0.62, 0.45), 1.0)
	for r in 5:
		var z := -taille.z * 0.5 + 0.7 + r * (taille.z - 1.4) / 4.0
		_boite(Vector3(taille.x, 0.02, 0.02), Vector3(0, 2.6, z), corde, s, false)
		for k in 13:
			var f := _boite(Vector3(0.5, 0.01, 0.7), Vector3(-taille.x * 0.5 + 0.4 + k * 0.6, 2.58, z), papier, s, false)
			# La feuille pliée en deux sur la corde (on ne voit que le pli et les deux pans).
			f.rotation.x = PI * 0.5
			f.position.y = 2.25
	return s


## Un maillet du moulin : une longue tige de chêne et sa tête ferrée, levée par l'arbre à cames.
func _maillet(parent: Node3D, p: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = p
	parent.add_child(pivot)
	_boite(Vector3(0.16, 0.16, 2.6), Vector3(0, 0, -1.3), _mat_chene_clair(), pivot, false)
	_boite(Vector3(0.32, 0.6, 0.32), Vector3(0, -0.3, -2.5), _mat_chene_clair(), pivot, false)
	_boite(Vector3(0.34, 0.08, 0.34), Vector3(0, -0.6, -2.5), _mat_uni_ma(Color(0.2, 0.2, 0.22), 0.5), pivot, false)
	return pivot


func _construire_moulin() -> void:
	var dossier := Node3D.new()
	dossier.name = "MoulinPapier"
	_contenu.add_child(dossier)
	var y := niveau_ruisseau(MOULIN.y) + 1.7
	# Le bâtiment du moulin : rez de pierre, étage à colombages, haut toit d'ardoise.
	var bat := _maison_rhenane(dossier, MOULIN, Vector3(9.0, 8.0, 14.0), PI / 2, Color(0.93, 0.9, 0.82))
	bat.name = "Moulin"
	# La roue à aubes, dans le ruisseau, contre le mur ouest ; elle tourne une fois la vanne ouverte.
	var roue := Node3D.new()
	roue.name = "RoueMoulin"
	roue.position = Vector3(ROUE_MOULIN.x, niveau_ruisseau(ROUE_MOULIN.y) + 1.6, ROUE_MOULIN.y)
	dossier.add_child(roue)
	var r := Node3D.new()
	r.name = "Roue"
	roue.add_child(r)
	var bois := _mat_chene_clair()
	var sombre := _mat_uni_ma(Color(0.28, 0.2, 0.13), 0.9)
	for cote: float in [-0.55, 0.55]:
		for k in 18:
			var a := k * TAU / 18.0
			var jante := _boite(Vector3(0.14, 0.92, 0.2), Vector3(cote, cos(a) * 2.4, sin(a) * 2.4), sombre, r, false)
			jante.rotation.x = -a
		for k in 4:
			var rayon := _boite(Vector3(0.12, 4.8, 0.14), Vector3(cote, 0, 0), sombre, r, false)
			rayon.rotation.x = k * PI / 4
	for k in 18:
		var a := k * TAU / 18.0
		var aube := _boite(Vector3(1.2, 0.06, 0.6), Vector3(0, cos(a) * 2.5, sin(a) * 2.5), bois, r, false)
		aube.rotation.x = -a
	var axe := MeshInstance3D.new()
	axe.mesh = _cylindre(0.2, 0.2, 5.0, 10)
	axe.material_override = sombre
	axe.rotation.z = PI / 2
	axe.position = Vector3(2.0, 0, 0)
	roue.add_child(axe)
	_roue_moulin = r
	# Le bief : une goulotte de planches qui amène l'eau, et la vanne en amont.
	for k in 6:
		var z := VANNE.y + 2.0 + k * 2.6
		_boite(Vector3(1.6, 0.12, 2.7), Vector3(ROUE_MOULIN.x - 0.6, niveau_ruisseau(z) + 0.05, z), sombre, dossier, false)
	# Les maillets qui battent les chiffons, sous un appentis au sud du moulin.
	var appentis := Node3D.new()
	appentis.name = "Maillets"
	appentis.position = Vector3(MAILLETS.x, y, MAILLETS.y)
	dossier.add_child(appentis)
	_boite(Vector3(5.6, 0.9, 1.4), Vector3(0, 0.45, -2.6), _mat_chene_clair(), appentis)
	_boite(Vector3(5.6, 0.06, 1.2), Vector3(0, 0.91, -2.6), _mat_uni_ma(Color(0.9, 0.88, 0.82), 0.9), appentis, false)
	_boite(Vector3(6.4, 0.3, 0.3), Vector3(0, 1.4, 0.4), sombre, appentis, false)
	for k in 5:
		var m := _maillet(appentis, Vector3(-2.2 + k * 1.1, 1.6, 0.4))
		_maillets.append(m)
	for x: float in [-3.0, 3.0]:
		for z: float in [-3.4, 1.2]:
			_boite(Vector3(0.2, 3.2, 0.2), Vector3(x, 1.6, z), _mat_colombage(), appentis)
	var t := Node3D.new()
	t.position = Vector3(0, 3.2, -1.1)
	appentis.add_child(t)
	_toit_pentu(t, Vector3.ZERO, 5.6, 7.0, _mat_ardoise(), _mat_colombage(), 0.6, 0.16)
	# La halle des chiffons (le pourrissoir) : des tas de chiffons qui fermentent dans l'eau.
	var halle := _halle_pressoir(dossier, CHIFFONS, Vector2(10.0, 7.0), 0.1)
	halle.name = "HalleChiffons"
	var chiffon := _mat_uni_ma(Color(0.82, 0.78, 0.7), 1.0)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 9
	for k in 9:
		var c := CHIFFONS + Vector2(hasard.randf_range(-4.0, 4.0), hasard.randf_range(-2.4, 2.4))
		var tas := _boite(Vector3(1.4, 0.6, 1.2), Vector3(c.x, hauteur(c.x, c.y) + 0.2, c.y), chiffon, dossier, false)
		tas.rotation.y = hasard.randf() * TAU
		tas.scale = Vector3(1, hasard.randf_range(0.6, 1.4), 1)
	# Les séchoirs, et le petit muret du replat.
	for k in SECHOIRS.size():
		_sechoir(dossier, SECHOIRS[k], 0.1 * k)
	_muret_sec(dossier, Vector2(REPLAT.end.x - 2.0, REPLAT.position.y + 6.0), Vector2(REPLAT.end.x - 2.0, REPLAT.end.y - 6.0), 1.0)


var _roue_moulin: Node3D


func _construire_camp() -> void:
	var dossier := Node3D.new()
	dossier.name = "CampSceau"
	_contenu.add_child(dossier)
	_tente(dossier, CAMP + Vector2(-8, -2), 0.3, Color(0.3, 0.28, 0.28))
	_tente(dossier, CAMP + Vector2(6, -8), -0.6, Color(0.26, 0.24, 0.24))
	_charrette(dossier, CAMP + Vector2(-10, 8), 1.2, false)
	# Des tonneaux de poix, des torches, et un feu.
	for k in 3:
		var t := MeshInstance3D.new()
		t.mesh = _cylindre(0.42, 0.42, 1.0, 12)
		t.material_override = _mat_uni_ma(Color(0.12, 0.1, 0.08), 0.6)
		var c := CAMP + Vector2(2 + k * 1.1, 6)
		t.position = Vector3(c.x, hauteur(c.x, c.y) + 0.5, c.y)
		dossier.add_child(t)
	var feu := CAMP + Vector2(0, 2)
	var yf := hauteur(feu.x, feu.y)
	for k in 8:
		var a := k * TAU / 8.0
		_boite(Vector3(0.3, 0.2, 0.3), Vector3(feu.x + cos(a) * 0.6, yf + 0.08, feu.y + sin(a) * 0.6), _mat_schiste(), dossier, false)
	var lumiere := OmniLight3D.new()
	lumiere.light_color = Color(1.0, 0.6, 0.3)
	lumiere.light_energy = 2.0
	lumiere.omni_range = 7.0
	lumiere.position = Vector3(feu.x, yf + 1.0, feu.y)
	dossier.add_child(lumiere)


func _construire_bac() -> void:
	var dossier := Node3D.new()
	dossier.name = "Bac"
	_contenu.add_child(dossier)
	var bois := _mat_colombage()
	_boite(Vector3(4.0, 0.25, 14.0), Vector3(BAC.x, NIVEAU_RHIN + 0.9, BAC.y - 1.0), bois, dossier)
	for k in 4:
		for cote: float in [-1.0, 1.0]:
			var pieu := MeshInstance3D.new()
			pieu.mesh = _cylindre(0.12, 0.14, 3.2, 8)
			pieu.material_override = bois
			pieu.position = Vector3(BAC.x + cote * 1.9, NIVEAU_RHIN - 0.4, BAC.y - 6.0 + k * 3.6)
			dossier.add_child(pieu)
	# Le bac lui-même : un grand bateau plat qui attend, et sa cabane de passeur.
	var bac := _nef_du_rhin(dossier, Vector3(BAC.x + 6.0, NIVEAU_RHIN + 0.2, BAC.y + 6.0), 0.1, Color(0.86, 0.82, 0.72))
	bac.name = "NefDuBac"
	var cabane := _chaumiere(dossier, BAC + Vector2(-8, -16), Vector3(3.4, 2.4, 3.8), 0.2)
	cabane.name = "CabanePasseur"


## Libre pour planter un arbre ?
func _libre(p: Vector2, marge := 6.0) -> bool:
	if distance_route(p) < 7.0 or _distance_piste(p) < 4.0 or distance_ruisseau(p) < 5.0:
		return false
	if p.distance_to(PORT) < 52.0 or p.y > BERGE_Z - 6.0:
		return false
	if _dans_rect(REPLAT.grow(4.0), p.x, p.y, 0.1) > 0.5 or p.distance_to(BURG) < 26.0:
		return false
	for c: Vector2 in [CAMP, FAILLE, CHEF, BAC, LETTRE]:
		if p.distance_to(c) < marge + 8.0:
			return false
	for c: Vector2 in RAMES:
		if p.distance_to(c) < 4.0:
			return false
	return true


func _construire_vegetation() -> void:
	var arbres := Node3D.new()
	arbres.name = "Arbres"
	_contenu.add_child(arbres)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 60
	# La forêt du Taunus au nord : châtaigniers, hêtres roux, chênes.
	var plantes := 0
	var essais := 0
	while plantes < 360 and essais < 12000:
		essais += 1
		var p := Vector2(hasard.randf_range(-165.0, 165.0), hasard.randf_range(-165.0, -55.0))
		if not _libre(p, 2.0):
			continue
		var essences := ["chataignier", "hetre_automne", "chene", "chataignier", "hetre_automne"]
		_arbre_realiste(arbres, p, essences[hasard.randi() % essences.size()], hasard, hasard.randf_range(0.8, 1.2))
		plantes += 1
	# Les bouleaux et les saules le long du ruisseau.
	for k in 46:
		var i := hasard.randi() % (RUISSEAU.size() - 1)
		var q: Vector2 = (RUISSEAU[i] as Vector2).lerp(RUISSEAU[i + 1], hasard.randf())
		q.x += (1.0 if hasard.randf() < 0.5 else -1.0) * hasard.randf_range(5.5, 9.0)
		if not _libre(q, 1.0) or distance_ruisseau(q) < 5.0:
			continue
		_arbre_realiste(arbres, q, "saule" if k % 3 == 0 else "bouleau_automne", hasard, hasard.randf_range(0.8, 1.15))
	# Des noyers et des chênes isolés dans les prés, entre la route et la forêt.
	plantes = 0
	essais = 0
	while plantes < 34 and essais < 3000:
		essais += 1
		var p := Vector2(hasard.randf_range(-160.0, 160.0), hasard.randf_range(-50.0, BERGE_Z - 12.0))
		if not _libre(p, 5.0):
			continue
		_arbre_realiste(arbres, p, "noyer" if plantes % 2 == 0 else "chene", hasard, hasard.randf_range(0.85, 1.2))
		plantes += 1
	# Les saules de la berge du Rhin.
	for k in 14:
		var p := Vector2(-160 + k * 24 + hasard.randf_range(-6, 6), BERGE_Z - 3.0 + hasard.randf_range(-2, 1))
		if (p.x > QUAI.position.x - 4.0 and p.x < QUAI.end.x + 4.0) or absf(p.x - BAC.x) < 8.0 or distance_ruisseau(p) < 6.0:
			continue
		_arbre_realiste(arbres, p, "saule", hasard, hasard.randf_range(0.8, 1.1))
	var haies := Node3D.new()
	haies.name = "Haies"
	_contenu.add_child(haies)
	_haie(haies, Vector2(-150, 60), Vector2(-90, 64), hasard)
	_haie(haies, Vector2(100, 60), Vector2(160, 56), hasard)
	_haie(haies, Vector2(-20, 40), Vector2(40, 36), hasard)


# --- Paysage lointain ----------------------------------------------------------------------

func _construire_lointain() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 70
	_plan_lointain_autour(-3.0, Color(0.1, 0.1, 0.8))
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.8
	for m in [[Vector3(0, -10, -900), Vector3(3200, 170, 600)], [Vector3(-1400, -10, -500), Vector3(1400, 120, 500)],
			[Vector3(1500, -10, -600), Vector3(1500, 110, 500)], [Vector3(0, -12, 1250), Vector3(4200, 45, 500)]]:
		bruit.seed = graine + hasard.randi()
		var colline := MeshInstance3D.new()
		colline.mesh = _maillage_bosse(bruit, m[1], 1.4, 0.3, 24, Color(0.2, 0.0, 0.6))
		colline.material_override = _mat_lointain()
		colline.position = m[0]
		colline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(colline)
	# Mayence, plus proche maintenant, au sud-est sur l'autre rive : remparts, toits, et les
	# tours rouges de la cathédrale Saint-Martin.
	var ville := Node3D.new()
	ville.name = "MayenceLointaine"
	_contenu.add_child(ville)
	var c := Vector3(1300, 0, 760)
	var gres := _mat_uni_ma(GRES_ROUGE.darkened(0.1), 0.9)
	_boite(Vector3(760, 9, 8), c + Vector3(0, 4.5, -120), _mat_uni_ma(Color(0.56, 0.52, 0.48), 0.9), ville, false)
	for k in 26:
		_boite(Vector3(hasard.randf_range(16, 36), hasard.randf_range(10, 18), hasard.randf_range(16, 32)),
				c + Vector3(-360 + k * 28, 6, hasard.randf_range(-100, 60)), _mat_uni_ma(Color(0.52, 0.46, 0.44), 0.9), ville, false)
	for t in [[Vector3(-30, 0, 0), 80.0], [Vector3(30, 0, 0), 64.0], [Vector3(0, 0, 0), 92.0]]:
		_boite(Vector3(16, t[1], 16), c + t[0] + Vector3(0, t[1] * 0.5, 0), gres, ville, false)
		var f := MeshInstance3D.new()
		f.mesh = _cylindre(0.5, 10.0, 26.0, 8)
		f.material_override = _mat_uni_ma(ARDOISE, 0.6)
		f.position = c + t[0] + Vector3(0, t[1] + 13.0, 0)
		ville.add_child(f)
	_boite(Vector3(30, 26, 120), c + Vector3(0, 13, 60), gres, ville, false)


# --- Limites de la zone -----------------------------------------------------------------------

func _construire_limites() -> void:
	var limites := Node3D.new()
	limites.name = "Limites"
	_contenu.add_child(limites)
	var demi := taille_terrain * 0.5 - 4.0
	_mur_invisible(limites, Vector3(2, 140, taille_terrain), Vector3(-demi - 2.0, 40, 0))
	_mur_invisible(limites, Vector3(2, 140, taille_terrain), Vector3(demi + 2.0, 40, 0))
	_mur_invisible(limites, Vector3(taille_terrain, 140, 2), Vector3(0, 40, -demi))
	_mur_invisible(limites, Vector3(taille_terrain, 30, 2), Vector3(0, 8, BERGE_Z + 10.0))
	# La route du bac : fermée tant que l'histoire n'y mène pas.
	_mur_e = _mur_invisible(limites, Vector3(2, 14, 30), Vector3(SORTIE_E.x - 5.0, hauteur(SORTIE_E.x, SORTIE_E.y) + 6.0, SORTIE_E.y - 6.0))


# --- Personnages et objets de la quête ----------------------------------------------------------

func _objet(dossier: Node3D, id: String, p: Vector2, forme := "", invite := "", groupe := "", portee := 2.4) -> Node3D:
	var o := ObjetMayence.new()
	o.name = id.to_pascal_case()
	o.identifiant = id
	o.forme = forme
	o.groupe = groupe
	o.invite = invite
	o.portee = portee
	o.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
	dossier.add_child(o)
	return o


func _scelle(dossier: Node3D, id_pnj: String, id_objet: String, groupe: String, p: Vector2, angle: float) -> void:
	var pnj := _pnj(dossier, id_pnj, p, angle)
	var o := _objet(dossier, id_objet, p, "", "[F] Composer la phrase qui libère", groupe, 2.2)
	o.set_meta("pnj_lie", id_pnj)
	if p.y > QUAI.position.y:
		pnj.position.y = Y_QUAI
		o.position.y = Y_QUAI


func _construire_quete() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quete"
	_contenu.add_child(dossier)
	_dossier_quete = dossier
	# Le port : Jakob le batelier, les deux grutiers Scellés, la roue de la grue.
	var jakob := _pnj(dossier, "jakob_batelier", JAKOB, PI * 0.9)
	jakob.position.y = Y_QUAI
	for k in SCELLES_GRUE.size():
		_scelle(dossier, "scelle_grutier_%d" % (k + 1), "liberer_grutier_%d" % k, "scelles_grue", SCELLES_GRUE[k], PI * (0.2 + k * 0.7))
	var marche := _objet(dossier, "marcher_grue", GRUE + Vector2(1.6, 0), "", "[F] Marcher dans la roue de la grue", "", 3.0)
	marche.position.y = Y_QUAI
	# Le moulin : Greta, la vanne du bief, la cuve.
	_pnj(dossier, "greta_papetiere", GRETA, PI * 0.6)
	var vanne := _objet(dossier, "vanne_bief", VANNE, "vanne", "[F] Lever la vanne du bief")
	vanne.rotation.y = -PI / 2
	vanne.position.y = niveau_ruisseau(VANNE.y) - 0.2
	var cuve := _objet(dossier, "cuve_greta", CUVE, "cuve_papier", "[F] Plonger la forme dans la cuve")
	cuve.rotation.y = PI / 2
	# Les séchoirs qui prendront feu (cachés jusqu'à l'attaque des hommes de Sceau).
	for k in SECHOIRS.size():
		var s := _objet(dossier, "feu_sechoir_%d" % k, SECHOIRS[k] + Vector2(0, 0.6), "sechoir_papier", "[F] Éteindre le séchoir en feu", "feu_sechoir_rhin", 3.0)
		s.add_to_group("decor_quete")
		s.set_meta("identifiant", "feu_sechoir_%d" % k)
		s.visible = false
	# La forêt : les rames de papier perdues, la lettre de Sceau, la faille.
	for k in RAMES.size():
		_objet(dossier, "rame_papier_%d" % k, RAMES[k], "rame_papier", "[F] Ramasser la rame de papier", "rames_greta")
	var lettre := _objet(dossier, "lettre_sceau", LETTRE, "lettre_cachetee", "[F] Lire la lettre cachetée")
	lettre.rotation.y = PI * 0.3
	var faille := Faille.new()
	faille.name = "Faille"
	faille.identifiant = "faille_rhin"
	faille.position = Vector3(FAILLE.x, hauteur(FAILLE.x, FAILLE.y), FAILLE.y)
	dossier.add_child(faille)
	_construire_secondaires(dossier)
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.DANGER, "Faille", FAILLE)
	repere.call(MarqueurCarte.Type.LIEU, "Le port d'Eltville et sa grue", PORT)
	repere.call(MarqueurCarte.Type.LIEU, "Le château de l'archevêque", BURG)
	repere.call(MarqueurCarte.Type.LIEU, "Le moulin à papier de Greta", MOULIN)
	repere.call(MarqueurCarte.Type.LIEU, "Le camp de Sceau", CAMP)
	repere.call(MarqueurCarte.Type.LIEU, "Le bac de Mayence", BAC)
	repere.call(MarqueurCarte.Type.LIEU, "Route du Rheingau", SORTIE_O)


## Les personnages des quêtes secondaires (plus tard).
func _construire_secondaires(_dossier: Node3D) -> void:
	pass


# --- La roue, les maillets, l'eau, les bateaux, les sorties ------------------------------------

var _attente := 0.0
var _route_ouverte := false
var _vitesse_grue := 0.0
var _moulin_tourne := false
var _horloge_moulin := 0.0


func _process(delta: float) -> void:
	super._process(delta)
	_horloge_moulin += delta
	for n in _nefs:
		if is_instance_valid(n):
			n.position.x += delta * 1.2
			if n.position.x > 1200.0:
				n.position.x = -1200.0
	if _eau_ruisseau != null:
		_eau_ruisseau.uv1_offset.y -= delta * 0.35
	if _roue != null and is_instance_valid(_roue) and _vitesse_grue > 0.0:
		_roue.get_node("Roue").rotation.x += delta * _vitesse_grue
	if _moulin_tourne and _roue_moulin != null and is_instance_valid(_roue_moulin):
		_roue_moulin.rotation.x -= delta * 0.9
		# Les maillets se lèvent et retombent l'un après l'autre (l'arbre à cames).
		for k in _maillets.size():
			var phase := fposmod(_horloge_moulin * 1.6 + k * 0.37, 1.0)
			_maillets[k].rotation.x = -0.32 * smoothstep(0.0, 0.7, phase) * (1.0 - smoothstep(0.85, 1.0, phase))
	if Engine.is_editor_hint():
		return
	_attente -= delta
	if _attente > 0.0:
		return
	_attente = 0.3
	var quete := get_tree().get_first_node_in_group("quete")
	if quete == null or not quete.has_method("etape_atteinte"):
		return
	_vitesse_grue = 0.35 if quete.etape_atteinte("grue") else 0.0
	_moulin_tourne = quete.etape_atteinte("vanne")
	if not _route_ouverte and quete.etape_atteinte("vers_mayence"):
		_route_ouverte = true
		if _mur_e != null and is_instance_valid(_mur_e):
			_mur_e.queue_free()
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return
	var p := Vector2(joueur.global_position.x, joueur.global_position.z)
	if p.distance_to(SORTIE_O) < 7.0 and quete.donnees.get("zones", {}).has("rheingau"):
		Reseau.set_meta("arrivee_mayence", "rhin")
		quete.changer_de_zone("rheingau")
	elif _route_ouverte and p.distance_to(SORTIE_E) < 7.0 and quete.donnees.get("zones", {}).has("ville"):
		Reseau.set_meta("arrivee_mayence", "rhin")
		quete.changer_de_zone("ville")
