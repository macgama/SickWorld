@tool
extends "res://scripts/monde/mayence/ile_mayence.gd"
## Île de Mayence, zone 4 : la foire de Francfort (niveaux 67-69).
##
## La foire d'automne, au bord du Main (le fleuve coule au sud, d'est en ouest). On arrive
## par la nef de Fust, au ponton de l'ouest. Le long du quai du Main, les étals des
## libraires et des marchands ; la grue du port ; le Saalhof, le vieux palais royal au bord
## de l'eau. Au centre, la place du Römerberg : les maisons de marchands aux pignons à
## gradins, la petite église Saint-Nicolas, et le bûcher que Sceau a fait dresser. À l'est,
## la grande église Saint-Barthélemy en grès rouge, dont la tour est encore en chantier
## (échafaudages, grue de bois). Au sud-est, la tête du Vieux Pont et sa tour, qui traverse
## vers Sachsenhausen. À l'est encore, le pré de la foire : tentes, chariots, chevaux.
## Au nord, le rempart et la haute tour ronde de l'Eschenheimer Turm.
##
## Tout est construit par le code (voir ile_mayence.gd). Repères : le nord est vers -Z.

const Faille := preload("res://scripts/monde/prehistoire/faille.gd")
const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const ObjetMayence := preload("res://scripts/monde/mayence/objet_mayence.gd")

## Le Main, au sud : la berge, le niveau de l'eau.
const BERGE_Z := 114.0
const NIVEAU_MAIN := 0.4
## Le ponton de l'arrivée (la nef de Fust), à l'ouest.
const PONTON := Vector2(-132, 120)
const ARRIVEE := Vector2(-132, 104)
const SORTIE_O := Vector2(-132, 126)
## Les rues : le quai du Main, la montée au Römerberg, la rue de la cathédrale, la rue du nord.
const QUAI := [Vector2(-168, 100), Vector2(-120, 100), Vector2(-60, 98), Vector2(0, 98), Vector2(60, 98), Vector2(168, 100)]
const RUE_ROMER := [Vector2(-8, 98), Vector2(-6, 60), Vector2(-2, 30)]
const RUE_DOM := [Vector2(24, 8), Vector2(46, -2), Vector2(100, -4), Vector2(150, -6)]
const RUE_NORD := [Vector2(-14, -12), Vector2(-20, -70), Vector2(-30, -150)]
const RUE_PONT := [Vector2(40, 98), Vector2(40, 108)]
## La place du Römerberg (la foire, le bûcher), Saint-Nicolas.
const ROMER := Rect2(-30, -12, 56, 42)
const BUCHER := Vector2(-2, 6)
const NICOLAS := Vector2(16, 40)
## La cathédrale Saint-Barthélemy (la tour en chantier à l'ouest), le Saalhof, le pont.
const DOM := Rect2(50, -40, 52, 22)
const SAALHOF := Vector2(-70, 84)
const PONT := Vector2(40, 112)
## Le pré de la foire, à l'est.
const PRE := Rect2(112, -110, 50, 190)
## Le rempart du nord et de l'ouest, l'Eschenheimer Turm.
const REMPARTS := [Vector2(168, -154), Vector2(-154, -154), Vector2(-154, 92)]
const ESCHENHEIM := Vector2(-30, -154)
## Les étals des libraires (le long du quai), l'étal de Fust.
const ETALS := [Vector2(-96, 90), Vector2(-74, 90), Vector2(-44, 90), Vector2(-24, 90), Vector2(14, 90), Vector2(30, 90)]
const ETAL_FUST := Vector2(-24, 90)
const FUST := Vector2(-24, 86.5)
const KEFFER := Vector2(-20, 87)
const PICCOLOMINI := Vector2(-28, 86)
const LIBRAIRES := [Vector2(-74, 86.5), Vector2(-44, 86.5), Vector2(14, 86.5)]
## La tête du pont : le colporteur, les charrettes de Sceau, les caisses, le message de Masque.
const COLPORTEUR := Vector2(52, 86)
const CHARRETTES := Vector2(40, 82)
const CAISSES := [Vector2(34, 78), Vector2(44, 76), Vector2(48, 84)]
const CRAIE := Vector2(46.2, 104)
## Sceau, et la faille près de la cathédrale.
const SCEAU := Vector2(-2, -4)
const FAILLE := Vector2(92, -54)
const MAISONS_COULEURS := [Color(0.94, 0.9, 0.8), Color(0.92, 0.78, 0.62), Color(0.9, 0.86, 0.72), Color(0.86, 0.68, 0.6),
		Color(0.95, 0.92, 0.84), Color(0.9, 0.82, 0.66), Color(0.88, 0.84, 0.76), Color(0.84, 0.74, 0.58)]

var _nefs: Array[Node3D] = []
var _rues: Array = []
var _feu_bucher: Node3D


func _init() -> void:
	identifiant_zone = "francfort"
	taille_terrain = 340
	graine = 1454
	point_apparition = ARRIVEE
	nombre_touffes = 16000
	fertilite_sols = Vector3(0.0, 0.25, 1.0)
	neige_qui_tombe = false
	sols = {
		# Rouge : les pavés, la terre battue des rues et du quai.
		"galets": ["cobblestone_floor_04", "brown_mud_02", "dry_river_pebbles"],
		# Vert : la terre piétinée du pré de la foire et des cours.
		"neige": ["brown_mud_02", "brown_mud_rocks_01", "brown_mud_02"],
		# Bleu : l'herbe.
		"sol": ["withered_grass", "brown_mud_02", "dry_ground_01"],
		"roche": ["rock_wall_10", "stacked_stone_wall", "cliff_side"],
	}
	reglages_terrain = {"sol_saturation": 1.15, "sol_motif": 6.0, "galets_motif": 3.0, "neige_motif": 5.0,
			"sol_teinte": Color(0.68, 0.82, 0.46), "roche_teinte": Color(0.82, 0.78, 0.74), "roche_saturation": 0.8,
			"neige_eclat": 1.0, "neige_paillettes": 0.0, "roche_motif": 8.0,
			"neige_teinte": Color(0.78, 0.66, 0.52), "neige_max": Vector3(0.56, 0.44, 0.32), "neige_simple": Color(0.4, 0.3, 0.22),
			"givre": 0.0, "neige_translucide": 0.0}
	reglages_herbe = {"couleur_base": Color(0.18, 0.27, 0.1), "couleur_pointe": Color(0.62, 0.66, 0.3),
			"couleur_givre": Color(0.74, 0.62, 0.36), "force_vent": 0.45}
	reglages_couvre_sol = {"cailloux": 2.0, "fleurs": [Color(0.95, 0.92, 0.85), Color(0.96, 0.8, 0.2)],
			"densite_fleurs": 1.0, "buissons": 0.3, "litiere": 1.5}
	_rues = [QUAI, RUE_ROMER, RUE_DOM, RUE_NORD, RUE_PONT]
	piste = RUE_ROMER.duplicate()


func _ready() -> void:
	if not Engine.is_editor_hint() and Reseau.has_meta("arrivee_mayence"):
		Reseau.remove_meta("arrivee_mayence")
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	if zone == "ville":
		return SORTIE_O
	return Vector2.INF


# --- Relief -----------------------------------------------------------------------------

func _preparer_bruits() -> void:
	super._preparer_bruits()
	_relief.frequency = 0.008


func _distance_ligne(p: Vector2, ligne: Array) -> float:
	var meilleure := INF
	for i in ligne.size() - 1:
		meilleure = minf(meilleure, _distance_segment(p, ligne[i], ligne[i + 1]))
	return meilleure


func distance_rues(p: Vector2) -> float:
	var d := INF
	for r in _rues:
		d = minf(d, _distance_ligne(p, r))
	return d


## Presque plat ; le sol monte un peu vers le nord, et la berge plonge dans le Main.
func _base(x: float, z: float) -> float:
	var h := 3.0 + (BERGE_Z - z) * 0.01 + _relief.get_noise_2d(x, z) * 0.7
	return lerpf(h, -2.5, smoothstep(BERGE_Z - 6.0, BERGE_Z + 8.0, z))


func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	var p := Vector2(x, z)
	var h := _base(x, z) + _details.get_noise_2d(x * 3.0, z * 3.0) * 0.05
	var d := distance_rues(p)
	h = lerpf(h, _base(x, z) - 0.06, 1.0 - smoothstep(3.0, 6.0, d))
	h = lerpf(h, _base(ROMER.get_center().x, ROMER.get_center().y), _dans_rect(ROMER, x, z, 8.0))
	h = lerpf(h, _base(DOM.get_center().x, DOM.get_center().y), _dans_rect(DOM.grow(8.0), x, z, 8.0))
	# Le quai, plat jusqu'au bord de l'eau.
	h = lerpf(h, _base(x, 98.0), smoothstep(86.0, 94.0, z) * (1.0 - smoothstep(BERGE_Z - 6.0, BERGE_Z - 2.0, z)))
	return h


## Rouge : rues, quai, places ; vert : le pré piétiné et les cours ; bleu : herbe.
func _parts_sol(x: float, z: float, _h: float) -> Color:
	var p := Vector2(x, z)
	var n := _relief.get_noise_2d(x * 2.0 + 30.0, z * 2.0)
	var rue := 1.0 - smoothstep(3.2, 5.0 + n, distance_rues(p))
	rue = maxf(rue, _dans_rect(ROMER, x, z, 3.0))
	rue = maxf(rue, _dans_rect(DOM.grow(6.0), x, z, 3.0))
	rue = maxf(rue, smoothstep(88.0, 92.0, z))
	var pre := _dans_rect(PRE, x, z, 10.0) * (1.0 - rue) * (0.6 + n * 0.3)
	var cour := maxf(pre, (0.5 if x > -150.0 and x < 110.0 and z > -150.0 else 0.0) * (1.0 - rue))
	var herbe := maxf(0.0, 1.0 - rue - cour)
	return Color(rue + 0.001, cour, herbe, 1.0)


# --- Construction -------------------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_construire_terrain()
	_construire_main()
	_construire_quai()
	_construire_remparts()
	_construire_romer()
	_construire_dom()
	_construire_pont()
	_construire_pre()
	_construire_maisons()
	_construire_vegetation()
	_construire_touffes()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_appliquer_ciel()


## Une place occupée (bâtiment ou lieu de la quête) ?
func _occupe(p: Vector2, marge := 3.0) -> bool:
	if ROMER.grow(6.0 + marge).has_point(p) or DOM.grow(10.0 + marge).has_point(p) or PRE.grow(marge).has_point(p):
		return true
	if p.distance_to(SAALHOF) < 16.0 + marge or p.distance_to(ESCHENHEIM) < 10.0 + marge or p.distance_to(FAILLE) < 10.0 + marge:
		return true
	if p.distance_to(CHARRETTES) < 14.0 + marge or p.distance_to(PONT) < 12.0 + marge or p.distance_to(NICOLAS) < 10.0 + marge:
		return true
	if p.y > 80.0:
		return true
	return distance_rues(p) < 4.2 + marge * 0.2


func _construire_main() -> void:
	var eau := _eau_du_rhin(Vector3(0, NIVEAU_MAIN, BERGE_Z + 420.0), Vector2(5200, 860))
	eau.name = "Main"
	var dossier := Node3D.new()
	dossier.name = "Bateaux"
	_contenu.add_child(dossier)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 7
	for k in 6:
		var b := _barque_rhin(dossier, Vector3(-150 + k * 50 + hasard.randf_range(-6, 6), NIVEAU_MAIN + 0.1, BERGE_Z + 3.0 + hasard.randf_range(0, 2)),
				PI * 0.5 + hasard.randf_range(-0.2, 0.2))
		b.name = "Barque%d" % k
	# La nef de Fust, amarrée au ponton de l'ouest, et deux nefs de marchands près de la grue.
	var fust := _nef_du_rhin(dossier, Vector3(PONTON.x + 8.0, NIVEAU_MAIN + 0.2, PONTON.y + 6.0), PI / 2, Color(0.74, 0.3, 0.22))
	fust.name = "NefDeFust"
	for k in 2:
		var n := _nef_du_rhin(dossier, Vector3(-20 + k * 30, NIVEAU_MAIN + 0.2, BERGE_Z + 8.0), PI / 2, [Color(0.88, 0.84, 0.76), Color(0.86, 0.82, 0.7)][k])
		n.name = "NefMarchand%d" % k
	for k in 2:
		var n := _nef_du_rhin(dossier, Vector3(-500 + k * 700, NIVEAU_MAIN + 0.2, BERGE_Z + 70.0 + k * 40.0), PI / 2, Color(0.86, 0.84, 0.78))
		_nefs.append(n)
	# Le ponton de l'arrivée.
	var bois := _mat_colombage()
	_boite(Vector3(4.0, 0.25, 16.0), Vector3(PONTON.x, NIVEAU_MAIN + 0.9, PONTON.y - 2.0), bois, dossier)
	for k in 5:
		for cote: float in [-1.0, 1.0]:
			var pieu := MeshInstance3D.new()
			pieu.mesh = _cylindre(0.12, 0.14, 3.2, 8)
			pieu.material_override = bois
			pieu.position = Vector3(PONTON.x + cote * 1.9, NIVEAU_MAIN - 0.4, PONTON.y - 9.0 + k * 3.6)
			dossier.add_child(pieu)


## Le quai du Main : le mur de quai en pierre, la grue, les ballots et les tonneaux, les
## étals des libraires, le Saalhof.
func _construire_quai() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quai"
	_contenu.add_child(dossier)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 5
	# Le mur de quai, de grès, le long de l'eau (coupé au ponton et au pont).
	for seg in [[-168.0, PONTON.x - 4.0], [PONTON.x + 4.0, PONT.x - 7.0], [PONT.x + 7.0, 168.0]]:
		var l: float = seg[1] - seg[0]
		var c: float = (seg[0] + seg[1]) * 0.5
		_boite(Vector3(l, 3.6, 1.4), Vector3(c, hauteur(c, BERGE_Z - 4.0) - 1.6, BERGE_Z - 3.4), _mat_gres_rouge(), dossier, false)
	var g := _roue_ecureuil(dossier, Vector2(-4, 106), PI)
	g.name = "GrueMain"
	var ballot := g.find_child("BlocPendu", true, false) as MeshInstance3D
	if ballot != null:
		ballot.material_override = _mat_uni_ma(Color(0.74, 0.68, 0.56), 1.0)
	var toile := _mat_uni_ma(Color(0.74, 0.68, 0.56), 1.0)
	for k in 36:
		var c := Vector2(hasard.randf_range(-160.0, 160.0), hasard.randf_range(100.0, 108.0))
		if c.distance_to(ARRIVEE) < 10.0 or absf(c.x - PONT.x) < 10.0 or absf(c.x + 4.0) < 6.0 or c.distance_to(CRAIE) < 6.0:
			continue
		if k % 3 == 0:
			var t := MeshInstance3D.new()
			t.mesh = _cylindre(0.42, 0.42, 1.0, 12)
			t.material_override = _mat_chene_clair()
			t.rotation.x = PI / 2 if k % 2 == 0 else 0.0
			t.position = Vector3(c.x, hauteur(c.x, c.y) + 0.45, c.y)
			dossier.add_child(t)
		else:
			var b := _boite(Vector3(1.2, 0.8, 0.9), Vector3(c.x, hauteur(c.x, c.y) + 0.4, c.y), toile, dossier, false)
			b.rotation.y = hasard.randf() * TAU
	# Les étals des libraires : un auvent, une table couverte de livres ouverts et de cahiers.
	var etals := Node3D.new()
	etals.name = "EtalsLibraires"
	_contenu.add_child(etals)
	for q: Vector2 in ETALS:
		_etal_livres(etals, q, hasard)
	# Le Saalhof, le vieux palais du roi au bord du Main : un gros logis de pierre, sa chapelle.
	var s := _maison_rhenane(dossier, SAALHOF, Vector3(22.0, 12.0, 14.0), 0.0, Color(0.9, 0.84, 0.74))
	s.name = "Saalhof"
	var tour := MeshInstance3D.new()
	tour.mesh = _cylindre(4.0, 4.2, 22.0, 4)
	tour.rotation.y = PI / 4
	tour.material_override = _mat_gres_rouge()
	tour.position = Vector3(SAALHOF.x - 14.0, hauteur(SAALHOF.x, SAALHOF.y) + 10.5, SAALHOF.y + 2.0)
	dossier.add_child(tour)
	var flc := MeshInstance3D.new()
	flc.mesh = _cylindre(0.2, 4.4, 8.0, 4)
	flc.rotation.y = PI / 4
	flc.material_override = _mat_ardoise()
	flc.position = tour.position + Vector3(0, 15.0, 0)
	dossier.add_child(flc)
	_fusionner(dossier)


## Un étal de libraire : l'auvent rayé, la table, les livres reliés de cuir, les cahiers.
func _etal_livres(parent: Node3D, q: Vector2, hasard: RandomNumberGenerator) -> void:
	var couleurs := [Color(0.72, 0.24, 0.2), Color(0.2, 0.36, 0.6), Color(0.86, 0.8, 0.62), Color(0.3, 0.5, 0.3)]
	_auvent(parent, q, Vector2(4.2, 3.0), 2.5, couleurs[hasard.randi() % couleurs.size()])
	var y := hauteur(q.x, q.y)
	_boite(Vector3(3.6, 0.1, 1.3), Vector3(q.x, y + 0.85, q.y), _mat_chene_clair(), parent, false)
	_boite(Vector3(3.4, 0.8, 1.1), Vector3(q.x, y + 0.4, q.y), _mat_chene_clair(), parent)
	var cuirs := [Color(0.42, 0.2, 0.12), Color(0.28, 0.16, 0.1), Color(0.5, 0.32, 0.18), Color(0.32, 0.12, 0.1)]
	for k in 9:
		var livre := _boite(Vector3(0.28, 0.08 + hasard.randf() * 0.06, 0.38), Vector3(q.x - 1.5 + k * 0.37, y + 0.94, q.y + hasard.randf_range(-0.3, 0.3)),
				_mat_uni_ma(cuirs[k % cuirs.size()], 0.7), parent, false)
		livre.rotation.y = hasard.randf_range(-0.3, 0.3)
	# Un livre ouvert au milieu, pages claires.
	_boite(Vector3(0.5, 0.03, 0.36), Vector3(q.x + 0.2, y + 1.0, q.y - 0.2), _mat_uni_ma(Color(0.92, 0.88, 0.76), 0.9), parent, false)


# --- Les remparts et l'Eschenheimer Turm -----------------------------------------------------

func _tour_ronde(parent: Node3D, p: Vector2, haut: float, rayon: float) -> void:
	var y := hauteur(p.x, p.y) - 0.5
	var t := MeshInstance3D.new()
	t.mesh = _cylindre(rayon, rayon + 0.3, haut, 14)
	t.material_override = _mat_gres_rouge()
	t.position = Vector3(p.x, y + haut * 0.5, p.y)
	parent.add_child(t)
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = rayon
	cyl.height = haut
	forme.shape = cyl
	corps.add_child(forme)
	corps.position = t.position
	parent.add_child(corps)
	var toit := MeshInstance3D.new()
	toit.mesh = _cylindre(0.1, rayon + 0.8, rayon * 1.8, 14)
	toit.material_override = _mat_ardoise()
	toit.position = Vector3(p.x, y + haut + rayon * 0.9, p.y)
	parent.add_child(toit)


func _mur_rempart(parent: Node3D, a: Vector2, b: Vector2, haut := 8.0) -> void:
	var d := b - a
	var l := d.length()
	var c := (a + b) * 0.5
	var y := hauteur(c.x, c.y)
	var mur := _boite(Vector3(l, haut, 2.2), Vector3(c.x, y + haut * 0.5 - 0.6, c.y), _mat_schiste(), parent)
	mur.rotation.y = -atan2(d.y, d.x)
	var dir := d / l
	var normale := Vector2(-dir.y, dir.x)
	for k in int(l / 2.4):
		var q := a + dir * (1.2 + k * 2.4) + normale * 1.1
		var cr := _boite(Vector3(1.2, 1.0, 0.5), Vector3(q.x, y + haut + 0.3, q.y), _mat_schiste(), parent, false)
		cr.rotation.y = mur.rotation.y


func _construire_remparts() -> void:
	var dossier := Node3D.new()
	dossier.name = "Remparts"
	_contenu.add_child(dossier)
	for i in REMPARTS.size() - 1:
		_mur_rempart(dossier, REMPARTS[i], REMPARTS[i + 1], 8.0)
	for p: Vector2 in [Vector2(-154, -154), Vector2(-154, -60), Vector2(-154, 30), Vector2(60, -154), Vector2(130, -154)]:
		_tour_ronde(dossier, p, 12.0, 3.2)
	# L'Eschenheimer Turm : une haute tour ronde de pierre grise, quatre échauguettes et une
	# flèche d'ardoise au sommet. Elle a vingt-cinq ans.
	var t := Node3D.new()
	t.name = "EschenheimerTurm"
	t.position = Vector3(ESCHENHEIM.x, hauteur(ESCHENHEIM.x, ESCHENHEIM.y) - 0.4, ESCHENHEIM.y)
	dossier.add_child(t)
	var pierre := _mat_crepi(Color(0.78, 0.74, 0.68))
	var fut := MeshInstance3D.new()
	fut.mesh = _cylindre(5.0, 5.4, 40.0, 18)
	fut.material_override = pierre
	fut.position = Vector3(0, 20.0, 0)
	t.add_child(fut)
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 5.2
	cyl.height = 40.0
	forme.shape = cyl
	corps.add_child(forme)
	corps.position = Vector3(0, 20.0, 0)
	t.add_child(corps)
	var sombre := _mat_uni_ma(Color(0.05, 0.05, 0.06), 1.0)
	for k in 5:
		var a := k * TAU / 5.0
		var b := _boite(Vector3(0.9, 1.6, 0.1), Vector3(cos(a) * 5.1, 12.0 + k * 5.0, sin(a) * 5.1), sombre, t, false)
		b.rotation.y = -a + PI / 2
	_boite(Vector3(4.0, 6.0, 0.4), Vector3(0, 3.0, 5.2), sombre, t, false)
	var couronne := MeshInstance3D.new()
	couronne.mesh = _cylindre(5.8, 5.4, 1.2, 18)
	couronne.material_override = pierre
	couronne.position = Vector3(0, 40.6, 0)
	t.add_child(couronne)
	for k in 4:
		var a := k * TAU / 4.0 + PI / 4.0
		var e := MeshInstance3D.new()
		e.mesh = _cylindre(1.0, 1.0, 3.4, 10)
		e.material_override = pierre
		e.position = Vector3(cos(a) * 5.4, 42.4, sin(a) * 5.4)
		t.add_child(e)
		var ct := MeshInstance3D.new()
		ct.mesh = _cylindre(0.05, 1.3, 3.0, 10)
		ct.material_override = _mat_ardoise()
		ct.position = e.position + Vector3(0, 3.2, 0)
		t.add_child(ct)
	var fleche := MeshInstance3D.new()
	fleche.mesh = _cylindre(0.2, 4.4, 12.0, 12)
	fleche.material_override = _mat_ardoise()
	fleche.position = Vector3(0, 47.0, 0)
	t.add_child(fleche)


# --- Le Römerberg ------------------------------------------------------------------------------

## Une maison de marchand à pignon à gradins, face à la place : rez de pierre à arcades,
## étages à colombages, et le grand pignon de grès en escalier.
func _maison_gradins(parent: Node3D, q: Vector2, angle: float, largeur: float, couleur: Color, haut := 9.0) -> void:
	var m := _maison_rhenane(parent, q, Vector3(largeur, haut, 12.0), angle, couleur)
	var gres := _mat_gres_rouge()
	# Le pignon à gradins, côté place (l'avant de la maison est vers +Z local).
	var marches := 5
	for k in marches:
		var l := largeur * (1.0 - float(k) / marches)
		_boite(Vector3(l, 1.6, 0.6), Vector3(0, haut + 0.6 + k * 1.6, 6.1), gres, m, false)
	var sombre := _mat_uni_ma(Color(0.06, 0.06, 0.07), 1.0)
	for k in 3:
		_boite(Vector3(1.0, 1.5, 0.1), Vector3(-largeur * 0.3 + k * largeur * 0.3, haut + 2.0, 6.42), sombre, m, false)
	# Les arcades du rez-de-chaussée.
	for k in 3:
		_boite(Vector3(1.8, 2.4, 0.1), Vector3(-largeur * 0.3 + k * largeur * 0.3, 1.2, 6.03), sombre, m, false)


func _construire_romer() -> void:
	var dossier := Node3D.new()
	dossier.name = "Romerberg"
	_contenu.add_child(dossier)
	# À l'ouest, la rangée des maisons à gradins (le Römer), face à l'est.
	for k in 5:
		_maison_gradins(dossier, Vector2(ROMER.position.x - 7.0 - (k % 2) * 1.2, ROMER.position.y + 4.0 + k * 8.6), PI / 2, 8.0,
				MAISONS_COULEURS[(k * 3) % MAISONS_COULEURS.size()], [9.0, 11.0, 8.2, 10.4, 9.4][k])
	# Au nord, d'autres maisons à colombages, face au sud ; à l'est, deux maisons.
	for k in 5:
		_maison_rhenane(dossier, Vector2(ROMER.position.x + 6.0 + k * 9.0, ROMER.position.y - 7.0 - (k % 2) * 1.0), Vector3(8.0, [8.4, 10.0, 7.6, 9.2, 8.8][k], 11.0), 0.0,
				MAISONS_COULEURS[(k * 5 + 1) % MAISONS_COULEURS.size()])
	for k in 2:
		_maison_gradins(dossier, Vector2(ROMER.end.x + 7.0, ROMER.position.y + 22.0 + k * 9.0), -PI / 2, 8.0, MAISONS_COULEURS[k + 2], [10.0, 8.4][k])
	# Saint-Nicolas, au sud-est de la place.
	var e := _eglise_village(dossier, NICOLAS, 0.0)
	e.name = "SaintNicolas"
	for mi in e.find_children("*", "MeshInstance3D", true, false):
		var mm := mi as MeshInstance3D
		if mm.material_override == _mat_calcaire():
			mm.material_override = _mat_gres_rouge()
		elif mm.material_override == _mat_tuiles_plates():
			mm.material_override = _mat_ardoise()
	# Des étals de foire autour de la place (drap, épices, cuivre).
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 12
	for k in 6:
		var q := Vector2(ROMER.position.x + 4.0 + (k % 3) * 22.0, ROMER.position.y + 6.0 + (k / 3) * 30.0)
		if q.distance_to(BUCHER) < 9.0:
			continue
		_auvent(dossier, q, Vector2(3.4, 2.6), 2.4, [Color(0.72, 0.24, 0.2), Color(0.2, 0.36, 0.6), Color(0.86, 0.8, 0.62)][k % 3])
		_boite(Vector3(2.8, 0.9, 1.1), Vector3(q.x, hauteur(q.x, q.y) + 0.45, q.y), _mat_chene_clair(), dossier)
	_fusionner(dossier)
	_construire_bucher()


## Le bûcher de Sceau, au milieu de la place : un poteau, des fagots, et dessus des
## centaines de livres jetés en tas. Le feu (caché) s'allume quand Sceau lève la main.
func _construire_bucher() -> void:
	var b := Node3D.new()
	b.name = "Bucher"
	b.position = Vector3(BUCHER.x, hauteur(BUCHER.x, BUCHER.y), BUCHER.y)
	_contenu.add_child(b)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 13
	var bois := _mat_uni_ma(Color(0.36, 0.26, 0.16), 0.95)
	var poteau := MeshInstance3D.new()
	poteau.mesh = _cylindre(0.18, 0.22, 6.0, 8)
	poteau.material_override = bois
	poteau.position = Vector3(0, 3.0, 0)
	b.add_child(poteau)
	for k in 40:
		var a := hasard.randf() * TAU
		var r := hasard.randf_range(0.4, 3.0)
		var f := MeshInstance3D.new()
		f.mesh = _cylindre(0.12, 0.14, hasard.randf_range(1.4, 2.2), 6)
		f.material_override = bois
		f.position = Vector3(cos(a) * r, 0.3 + (3.0 - r) * 0.45, sin(a) * r)
		f.rotation = Vector3(hasard.randf_range(0.8, 1.6), a, 0)
		b.add_child(f)
	var cuirs := [Color(0.42, 0.2, 0.12), Color(0.28, 0.16, 0.1), Color(0.5, 0.32, 0.18), Color(0.86, 0.82, 0.7)]
	for k in 70:
		var a := hasard.randf() * TAU
		var r := hasard.randf_range(0.6, 2.6)
		var l := _boite(Vector3(0.3, 0.1, 0.4), Vector3(cos(a) * r, 0.6 + (2.8 - r) * 0.55 + hasard.randf() * 0.3, sin(a) * r),
				_mat_uni_ma(cuirs[k % cuirs.size()], 0.8), b, false)
		l.rotation = Vector3(hasard.randf_range(-0.6, 0.6), hasard.randf() * TAU, hasard.randf_range(-0.6, 0.6))
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 2.8
	cyl.height = 2.0
	forme.shape = cyl
	corps.add_child(forme)
	corps.position = Vector3(0, 1.0, 0)
	b.add_child(corps)
	# Le feu : des flammes lumineuses et une grande lumière orange.
	_feu_bucher = Node3D.new()
	_feu_bucher.name = "FeuBucher"
	_feu_bucher.add_to_group("decor_quete")
	_feu_bucher.set_meta("identifiant", "feu_bucher")
	_feu_bucher.visible = false
	b.add_child(_feu_bucher)
	var flamme := StandardMaterial3D.new()
	flamme.albedo_color = Color(1.0, 0.6, 0.2)
	flamme.emission_enabled = true
	flamme.emission = Color(1.0, 0.45, 0.1)
	flamme.emission_energy_multiplier = 6.0
	flamme.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flamme.albedo_color.a = 0.8
	flamme.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for k in 9:
		var a := k * TAU / 9.0
		var fl := MeshInstance3D.new()
		fl.mesh = _cylindre(0.02, 0.5, hasard.randf_range(1.6, 3.0), 6)
		fl.material_override = flamme
		fl.position = Vector3(cos(a) * 1.4, 2.4, sin(a) * 1.4)
		fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_feu_bucher.add_child(fl)
	var lumiere := OmniLight3D.new()
	lumiere.light_color = Color(1.0, 0.55, 0.25)
	lumiere.light_energy = 4.0
	lumiere.omni_range = 18.0
	lumiere.position = Vector3(0, 3.0, 0)
	_feu_bucher.add_child(lumiere)


# --- La cathédrale Saint-Barthélemy ----------------------------------------------------------

## Gothique, en grès rouge : la nef, le grand transept, le chœur à l'est ; à l'ouest, la
## tour commencée en 1415, haute d'une trentaine de mètres seulement, avec ses échafaudages
## et une grue de bois tout en haut.
func _construire_dom() -> void:
	var d := Node3D.new()
	d.name = "Cathedrale"
	_contenu.add_child(d)
	var gres := _mat_gres_rouge()
	var sombre := _mat_uni_ma(Color(0.04, 0.04, 0.05), 1.0)
	var c := DOM.get_center()
	var y := hauteur(c.x, c.y) - 0.3
	var o := Vector3(c.x, y, c.y)
	var nef := Vector3(DOM.size.x - 16.0, 22.0, 14.0)
	_boite(nef, o + Vector3(4.0, nef.y * 0.5, 0), gres, d)
	_boite(Vector3(12.0, 22.0, DOM.size.y + 12.0), o + Vector3(6.0, 11.0, 0), gres, d)
	for cote: float in [-1.0, 1.0]:
		for k in 6:
			var x := -nef.x * 0.5 + 6.0 + k * 6.0
			_boite(Vector3(2.0, 9.0, 0.1), o + Vector3(x, 11.0, cote * (nef.z * 0.5 + 0.03)), sombre, d, false)
			_boite(Vector3(1.0, 16.0, 1.4), o + Vector3(x + 3.0, 8.0, cote * (nef.z * 0.5 + 0.7)), gres, d, false)
	for t: Array in [[o + Vector3(4.0, nef.y, 0), nef.x, nef.z], [o + Vector3(6.0, 22.0, 0), DOM.size.y + 12.0, 12.0]]:
		var toit := Node3D.new()
		toit.position = t[0]
		toit.rotation.y = PI / 2 if t[1] == nef.x else 0.0
		d.add_child(toit)
		_toit_pentu(toit, Vector3.ZERO, t[2] + 0.6, t[1], _mat_ardoise(), gres, 0.95, 0.2)
	var choeur := MeshInstance3D.new()
	choeur.mesh = _cylindre(7.0, 7.2, 20.0, 10)
	choeur.material_override = gres
	choeur.position = o + Vector3(nef.x * 0.5 + 6.0, 10.0, 0)
	d.add_child(choeur)
	# La tour en chantier, à l'ouest.
	var tx := o + Vector3(-nef.x * 0.5 - 4.0, 0, 0)
	_boite(Vector3(13.0, 34.0, 13.0), tx + Vector3(0, 17.0, 0), gres, d)
	_boite(Vector3(3.0, 9.0, 0.1), tx + Vector3(-6.53, 8.0, 0), sombre, d, false)
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			_boite(Vector3(1.6, 36.0, 1.6), tx + Vector3(cx * 6.8, 18.0, cz * 6.8), gres, d, false)
	# Les échafaudages : des perches et des planchers de bois tout autour du haut de la tour.
	var perche := _mat_uni_ma(Color(0.5, 0.4, 0.28), 0.95)
	for k in 12:
		var a := k * TAU / 12.0
		var p := MeshInstance3D.new()
		p.mesh = _cylindre(0.08, 0.1, 16.0, 6)
		p.material_override = perche
		p.position = tx + Vector3(cos(a) * 8.4, 34.0, sin(a) * 8.4)
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		d.add_child(p)
	for h in [28.0, 33.0, 38.0]:
		for cote: float in [-1.0, 1.0]:
			_boite(Vector3(17.0, 0.12, 1.2), tx + Vector3(0, h, cote * 8.0), perche, d, false)
			_boite(Vector3(1.2, 0.12, 17.0), tx + Vector3(cote * 8.0, h, 0), perche, d, false)
	# La grue du chantier, sur le haut de la tour.
	var grue := Node3D.new()
	grue.position = tx + Vector3(0, 34.0, 0)
	d.add_child(grue)
	_boite(Vector3(0.6, 8.0, 0.6), Vector3(0, 4.0, 0), perche, grue, false)
	var fleche := _boite(Vector3(10.0, 0.4, 0.4), Vector3(3.5, 7.6, 0), perche, grue, false)
	fleche.rotation.z = 0.2
	var corde := _boite(Vector3(0.04, 14.0, 0.04), Vector3(8.0, 1.6, 0), _mat_uni_ma(Color(0.7, 0.62, 0.45), 1.0), grue, false)
	corde.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_boite(Vector3(0.8, 0.6, 0.6), Vector3(8.0, -5.6, 0), gres, grue, false)
	# Des blocs taillés en attente au pied de la tour.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 21
	for k in 12:
		var q := Vector2(tx.x - 12.0 + hasard.randf_range(-4, 4), tx.z + hasard.randf_range(-10, 10))
		var b := _boite(Vector3(1.2, 0.6, 0.7), Vector3(q.x, hauteur(q.x, q.y) + 0.3 + (k % 3) * 0.6, q.y), gres, d, false)
		b.rotation.y = hasard.randf_range(-0.2, 0.2)
	_fusionner(d)


# --- Le Vieux Pont ----------------------------------------------------------------------------

## Le pont de pierre sur le Main, vers Sachsenhausen : une tour-porte sur la rive, puis
## des arches qui s'en vont vers le sud.
func _construire_pont() -> void:
	var d := Node3D.new()
	d.name = "VieuxPont"
	_contenu.add_child(d)
	var gres := _mat_gres_rouge()
	var pierre := _mat_schiste()
	# La tour du pont, sur la rive.
	var y := hauteur(PONT.x, PONT.y - 6.0)
	_boite(Vector3(10.0, 18.0, 8.0), Vector3(PONT.x, y + 9.0, PONT.y - 4.0), gres, d)
	_boite(Vector3(4.0, 5.0, 8.4), Vector3(PONT.x, y + 2.5, PONT.y - 4.0), _mat_uni_ma(Color(0.05, 0.05, 0.06), 1.0), d, false)
	var toit := Node3D.new()
	toit.position = Vector3(PONT.x, y + 18.0, PONT.y - 4.0)
	d.add_child(toit)
	_toit_pentu(toit, Vector3.ZERO, 8.6, 10.6, _mat_ardoise(), gres, 1.0, 0.18)
	# Le tablier et les piles, dans l'eau.
	var tablier := 7.0
	_boite(Vector3(tablier, 1.2, 300.0), Vector3(PONT.x, 5.4, PONT.y + 150.0), pierre, d, false)
	for cote: float in [-1.0, 1.0]:
		_boite(Vector3(0.5, 1.0, 300.0), Vector3(PONT.x + cote * (tablier * 0.5 - 0.25), 6.5, PONT.y + 150.0), gres, d, false)
	for k in 10:
		var z := PONT.y + 14.0 + k * 28.0
		_boite(Vector3(tablier + 1.0, 8.0, 5.0), Vector3(PONT.x, 1.0, z), pierre, d, false)
		var bec := MeshInstance3D.new()
		bec.mesh = _cylindre(0.1, 3.6, 8.0, 4)
		bec.material_override = pierre
		bec.rotation.y = PI / 4
		bec.position = Vector3(PONT.x, 1.0, z)
		d.add_child(bec)
	# Au milieu du pont, le petit moulin et le crucifix (la « Brickegickel ») : un mât.
	var mat := MeshInstance3D.new()
	mat.mesh = _cylindre(0.12, 0.14, 5.0, 6)
	mat.material_override = _mat_colombage()
	mat.position = Vector3(PONT.x + 2.6, 8.5, PONT.y + 120.0)
	d.add_child(mat)


# --- Le pré de la foire -----------------------------------------------------------------------

func _construire_pre() -> void:
	var dossier := Node3D.new()
	dossier.name = "PreFoire"
	_contenu.add_child(dossier)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 40
	var couleurs := [Color(0.86, 0.82, 0.7), Color(0.72, 0.26, 0.2), Color(0.3, 0.4, 0.6), Color(0.8, 0.7, 0.4), Color(0.5, 0.56, 0.4)]
	for k in 16:
		var q := Vector2(PRE.position.x + 8.0 + (k % 3) * 16.0 + hasard.randf_range(-3, 3), PRE.position.y + 10.0 + (k / 3) * 34.0 + hasard.randf_range(-4, 4))
		if not PRE.has_point(q) or q.distance_to(FAILLE) < 14.0:
			continue
		_tente(dossier, q, hasard.randf_range(-0.4, 0.4), couleurs[k % couleurs.size()], hasard.randf_range(1.0, 1.4))
	for k in 8:
		var q := Vector2(hasard.randf_range(PRE.position.x + 4.0, PRE.end.x - 4.0), hasard.randf_range(PRE.position.y + 6.0, PRE.end.y - 6.0))
		_charrette(dossier, q, hasard.randf() * TAU, k % 2 == 0)


# --- Les maisons -------------------------------------------------------------------------------

func _trop_pres(dossier: Node3D, q: Vector2, distance: float) -> bool:
	for n in dossier.get_children():
		if n is Node3D and Vector2((n as Node3D).position.x, (n as Node3D).position.z).distance_to(q) < distance:
			return true
	return false


func _construire_maisons() -> void:
	var dossier := Node3D.new()
	dossier.name = "Maisons"
	_contenu.add_child(dossier)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 30
	for rue in _rues:
		for i in rue.size() - 1:
			var a: Vector2 = rue[i]
			var b: Vector2 = rue[i + 1]
			var dir := (b - a).normalized()
			var normale := Vector2(-dir.y, dir.x)
			var longueur := a.distance_to(b)
			var t := 5.0
			while t < longueur - 4.0:
				for cote: float in [-1.0, 1.0]:
					var q := a + dir * t + normale * cote * 8.8
					if q.x < -150.0 or q.x > 98.0 or q.y < -150.0 or _occupe(q, 0.0) or _trop_pres(dossier, q, 6.5):
						continue
					var n := -normale * cote
					_maison_rhenane(dossier, q, Vector3(hasard.randf_range(5.6, 7.0), hasard.randf_range(6.4, 8.2), 8.0), atan2(n.x, n.y),
							MAISONS_COULEURS[hasard.randi() % MAISONS_COULEURS.size()])
				t += hasard.randf_range(7.0, 8.5)
	var poses := 0
	var essais := 0
	while poses < 50 and essais < 3000:
		essais += 1
		var q := Vector2(hasard.randf_range(-146.0, 96.0), hasard.randf_range(-146.0, 76.0))
		if _occupe(q, 3.0) or _trop_pres(dossier, q, 11.0):
			continue
		_maison_rhenane(dossier, q, Vector3(hasard.randf_range(6.0, 7.6), hasard.randf_range(6.4, 8.4), hasard.randf_range(7.0, 9.0)),
				(hasard.randi() % 4) * PI / 2 + hasard.randf_range(-0.1, 0.1), MAISONS_COULEURS[hasard.randi() % MAISONS_COULEURS.size()])
		poses += 1
	_fusionner(dossier)


func _construire_vegetation() -> void:
	var arbres := Node3D.new()
	arbres.name = "Arbres"
	_contenu.add_child(arbres)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 60
	var plantes := 0
	var essais := 0
	while plantes < 34 and essais < 4000:
		essais += 1
		var p := Vector2(hasard.randf_range(-148.0, 160.0), hasard.randf_range(-148.0, 80.0))
		if (_occupe(p, 2.0) and not PRE.has_point(p)) or _trop_pres(_contenu.get_node("Maisons"), p, 7.0) or _trop_pres(arbres, p, 10.0):
			continue
		if PRE.has_point(p) and (p.x > PRE.position.x + 6.0 and p.x < PRE.end.x - 6.0):
			continue
		_arbre_realiste(arbres, p, ["chene", "noyer", "hetre_automne"][plantes % 3], hasard, hasard.randf_range(0.75, 1.05))
		plantes += 1
	for k in 12:
		var p := Vector2(-160 + k * 28 + hasard.randf_range(-5, 5), BERGE_Z - 2.0)
		if absf(p.x - PONTON.x) < 10.0 or absf(p.x - PONT.x) < 12.0 or absf(p.x + 4.0) < 10.0:
			continue
		_arbre_realiste(arbres, p, "saule", hasard, hasard.randf_range(0.8, 1.0))
	for k in 40:
		var p := Vector2(hasard.randf_range(-170, -160), hasard.randf_range(-165, 90)) if k % 2 == 0 \
				else Vector2(hasard.randf_range(-160, 165), hasard.randf_range(-170, -160))
		_arbre_realiste(arbres, p, ["chene", "noyer", "hetre_automne"][k % 3], hasard, hasard.randf_range(0.9, 1.2))


# --- Paysage lointain ----------------------------------------------------------------------

func _construire_lointain() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 70
	_plan_lointain_autour(-3.0, Color(0.1, 0.1, 0.8))
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.8
	# Le Taunus au nord-ouest, les collines de Sachsenhausen au sud, la plaine à l'est.
	for m in [[Vector3(-900, -10, -1300), Vector3(3000, 180, 700)], [Vector3(0, -10, 1350), Vector3(3600, 70, 600)],
			[Vector3(1400, -10, 0), Vector3(900, 50, 3000)], [Vector3(-1400, -10, 200), Vector3(900, 60, 3000)]]:
		bruit.seed = graine + hasard.randi()
		var colline := MeshInstance3D.new()
		colline.mesh = _maillage_bosse(bruit, m[1], 1.4, 0.3, 24, Color(0.2, 0.0, 0.6))
		colline.material_override = _mat_lointain()
		colline.position = m[0]
		colline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(colline)
	# Sachsenhausen, sur l'autre rive : des toits, une église, la tour du bout du pont.
	var loin := Node3D.new()
	loin.name = "Sachsenhausen"
	_contenu.add_child(loin)
	for k in 28:
		var c := Vector3(hasard.randf_range(-300, 300), 0, hasard.randf_range(440, 560))
		_boite(Vector3(hasard.randf_range(10, 18), hasard.randf_range(8, 13), hasard.randf_range(10, 16)), c + Vector3(0, 5, 0),
				_mat_uni_ma(Color(0.6, 0.52, 0.46), 0.9), loin, false)
	_boite(Vector3(10, 22, 10), Vector3(PONT.x, 11, 452), _mat_uni_ma(GRES_ROUGE.darkened(0.1), 0.9), loin, false)


# --- Limites de la zone -----------------------------------------------------------------------

func _construire_limites() -> void:
	var limites := Node3D.new()
	limites.name = "Limites"
	_contenu.add_child(limites)
	var demi := taille_terrain * 0.5 - 4.0
	_mur_invisible(limites, Vector3(2, 140, taille_terrain), Vector3(-demi, 40, 0))
	_mur_invisible(limites, Vector3(2, 140, taille_terrain), Vector3(demi, 40, 0))
	_mur_invisible(limites, Vector3(taille_terrain, 140, 2), Vector3(0, 40, -demi))
	# On ne se baigne pas dans le Main (sauf par le ponton).
	for x: Array in [[-170.0, PONTON.x - 2.6], [PONTON.x + 2.6, 170.0]]:
		var l: float = x[1] - x[0]
		_mur_invisible(limites, Vector3(l, 30, 2), Vector3((x[0] + x[1]) * 0.5, 8, BERGE_Z - 1.0))


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
	_pnj(dossier, id_pnj, p, angle)
	var o := _objet(dossier, id_objet, p, "", "[F] Composer la phrase qui libère", groupe, 2.2)
	o.set_meta("pnj_lie", id_pnj)


func _pnj_cache(dossier: Node3D, id: String, p: Vector2, angle: float) -> Node3D:
	var n := _pnj(dossier, id, p, angle)
	n.add_to_group("decor_quete")
	n.set_meta("identifiant", id)
	n.visible = false
	return n


func _construire_quete() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quete"
	_contenu.add_child(dossier)
	_dossier_quete = dossier
	# Le quai : Fust à son étal, Keffer, l'évêque italien, les libraires Scellés.
	_pnj(dossier, "johann_fust", FUST, 0.0)
	_pnj(dossier, "heinrich_keffer", KEFFER, -0.3)
	_pnj(dossier, "eneas_piccolomini", PICCOLOMINI, 0.4)
	for k in LIBRAIRES.size():
		_scelle(dossier, "scelle_libraire_%d" % k, "liberer_libraire_%d" % k, "scelles_libraires", LIBRAIRES[k], 0.0)
	# La tête du pont : le colporteur, les charrettes de livres, les caisses, la craie.
	_pnj(dossier, "colporteur_matthis", COLPORTEUR, -PI * 0.6)
	_charrette(dossier, CHARRETTES + Vector2(-6, 0), 0.3, true)
	_charrette(dossier, CHARRETTES + Vector2(6, -3), -0.2, true)
	for k in CAISSES.size():
		_objet(dossier, "caisse_livres_%d" % k, CAISSES[k], "caisse_livres", "[F] Reprendre la caisse de livres", "caisses_livres")
	var craie := _objet(dossier, "craie_masque_foire", CRAIE, "craie", "[F] Lire le message à la craie")
	craie.rotation.y = -PI / 2
	# Le Römerberg : Sceau (cachée jusqu'à ce qu'on arrive), le bûcher à éteindre.
	_pnj_cache(dossier, "sceau", SCEAU, 0.0)
	_objet(dossier, "bucher_romer", BUCHER + Vector2(0, 3.6), "", "[F] Jeter les seaux d'eau sur le bûcher", "", 3.2)
	var faille := Faille.new()
	faille.name = "Faille"
	faille.identifiant = "faille_francfort"
	faille.position = Vector3(FAILLE.x, hauteur(FAILLE.x, FAILLE.y), FAILLE.y)
	dossier.add_child(faille)
	_construire_secondaires(dossier)
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.DANGER, "Faille", FAILLE)
	repere.call(MarqueurCarte.Type.LIEU, "Le Römerberg", ROMER.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Les libraires du quai", ETAL_FUST)
	repere.call(MarqueurCarte.Type.LIEU, "Saint-Barthélemy", DOM.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Le Vieux Pont", PONT)
	repere.call(MarqueurCarte.Type.LIEU, "Le pré de la foire", PRE.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "L'Eschenheimer Turm", ESCHENHEIM)
	repere.call(MarqueurCarte.Type.LIEU, "La nef de Fust, vers Mayence", PONTON)


## Les personnages des quêtes secondaires (plus tard).
## La donneuse de quête secondaire : maître Ulrike, la relieuse, à son étal du quai.
func _construire_secondaires(dossier: Node3D) -> void:
	_pnj(dossier, "relieur_francfort", Vector2(-96, 86.5), 0.0)


# --- Les bateaux, la sortie ---------------------------------------------------------------------

var _attente := 0.0


func _process(delta: float) -> void:
	super._process(delta)
	for n in _nefs:
		if is_instance_valid(n):
			n.position.x += delta * 1.2
			if n.position.x > 1200.0:
				n.position.x = -1200.0
	if _feu_bucher != null and _feu_bucher.visible:
		var t := Time.get_ticks_msec() * 0.001
		for k in _feu_bucher.get_child_count():
			var f := _feu_bucher.get_child(k) as Node3D
			if f is MeshInstance3D:
				f.scale.y = 0.8 + 0.3 * sin(t * 7.0 + k * 1.7)
			elif f is OmniLight3D:
				(f as OmniLight3D).light_energy = 3.6 + 0.6 * sin(t * 11.0)
	if Engine.is_editor_hint():
		return
	_attente -= delta
	if _attente > 0.0:
		return
	_attente = 0.3
	var quete := get_tree().get_first_node_in_group("quete")
	if quete == null or not quete.has_method("etape_atteinte"):
		return
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return
	var p := Vector2(joueur.global_position.x, joueur.global_position.z)
	if p.distance_to(SORTIE_O) < 4.0 and quete.donnees.get("zones", {}).has("ville"):
		Reseau.set_meta("arrivee_mayence", "francfort")
		quete.changer_de_zone("ville")
