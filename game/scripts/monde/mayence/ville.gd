@tool
extends "res://scripts/monde/mayence/ile_mayence.gd"
## Île de Mayence, zone 3 : la ville de Mayence (niveaux 65-68).
##
## Automne 1450. La ville libre de Mayence, sur la rive gauche du Rhin (le fleuve coule ici
## à l'est, du sud vers le nord). On arrive par le bac, sur la rive, entre le mur du Rhin et
## l'eau : des grues de bois, des tonneaux, des nefs amarrées. On entre par le Holzturm, la
## haute tour-porte de grès rouge. Dedans : le marché, la grande cathédrale romane
## Saint-Martin (grès rouge, deux chœurs, des tours à chaque bout), les rues de maisons à
## colombages, le quartier des orfèvres à l'ouest, et au nord, près de l'église
## Saint-Christophe, la cour Humbrecht : l'atelier de Gutenberg (la presse, les casses, la
## fonderie). Des remparts et des tours rondes ferment la ville ; la faille s'est ouverte dans
## les jardins, au nord-ouest, contre le mur.
##
## Tout est construit par le code (voir ile_mayence.gd). Repères : le nord est vers -Z.

const Faille := preload("res://scripts/monde/prehistoire/faille.gd")
const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const ObjetMayence := preload("res://scripts/monde/mayence/objet_mayence.gd")

## Le Rhin, à l'est : la berge, le niveau de l'eau ; le mur du Rhin.
const BERGE_X := 134.0
const NIVEAU_RHIN := 0.4
const MUR_RHIN_X := 112.0
## Le bac (l'arrivée), la tour-porte du Holzturm, la porte des Pêcheurs.
const BAC := Vector2(142, 58)
const ARRIVEE := Vector2(126, 58)
const SORTIE_E := Vector2(146, 58)
const HOLZTURM := Vector2(112, 58)
const FISCHTOR := Vector2(112, -62)
## Le ponton de la nef de Fust, devant la porte des Pêcheurs : le départ pour Francfort.
const PONTON_FUST := Vector2(142, -76)
const SORTIE_N := Vector2(146, -76)
## Les rues.
const RUE_HOLZTURM := [Vector2(126, 58), Vector2(112, 58), Vector2(86, 50), Vector2(64, 40)]
const RUE_CHRISTOPHE := [Vector2(64, 40), Vector2(58, 2), Vector2(46, -40), Vector2(30, -72), Vector2(14, -80)]
const RUE_ORFEVRES := [Vector2(58, 2), Vector2(14, -16), Vector2(-40, -26), Vector2(-104, -46)]
const RUE_FISCHTOR := [Vector2(112, -62), Vector2(82, -54), Vector2(46, -40)]
const RUE_SUD := [Vector2(64, 40), Vector2(40, 74), Vector2(-20, 86), Vector2(-90, 90)]
const RIVE := [Vector2(124, -150), Vector2(124, 150)]
## La cathédrale Saint-Martin (nef est-ouest) et la place du marché.
const DOM := Rect2(-86, 12, 104, 30)
const MARCHE := Rect2(36, 8, 44, 40)
## La cour Humbrecht : l'atelier de Gutenberg, et l'église Saint-Christophe.
const COUR := Rect2(-6, -112, 38, 30)
const PORCHE := Vector2(14, -82)
const ATELIER := Vector2(10, -102)
const PRESSE := Vector2(6, -102)
const CASSE := Vector2(15, -99)
const FONDERIE := Vector2(26, -94)
const CHRISTOPHE := Vector2(60, -96)
const GUTENBERG := Vector2(4, -96)
const KEFFER := Vector2(16, -88)
const SCHOEFFER := Vector2(18, -101)
const HANS := Vector2(26, -90)
const FUST := Vector2(-2, -88)
const COFFRE := Vector2(0, -106)
const CHAT := Vector2(12, -96)
## La nuit de l'Éditeur (chapitre 6) : Marchal et sa machine, les deux réponses, l'affiche.
const MARCHAL := Vector2(10.4, -96.2)
const MACHINE := Vector2(8.4, -97.4)
const REPONSES := [Vector2(2.0, -93.8), Vector2(6.4, -93.8)]
const AFFICHE := Vector2(15, -87)
## Le chapitre 8 : la porte de la crypte de Saint-Martin, sur le flanc sud de la nef (on y
## descend vers la fonderie), et le portail de la Vigie qui s'ouvre dans la cour Humbrecht.
const DESCENTE_FONDERIE := Vector2(-34, 44.5)
const PORTAIL_QG := Vector2(24, -106)
const ETAPES_NUIT := ["lumiere", "marchal", "gutenberg_hesite", "convaincre", "marchal_ouvriers", "marchal_apprendre", "torches_sceau"]
## Le quartier des orfèvres, le syndic, les indices de l'enquête.
const ORFEVRES := Vector2(-60, -34)
const HENNEN := Vector2(-66, -40)
const HUMERY := Vector2(54, 18)
const INDICES := [Vector2(-50, -42), Vector2(70, 34), Vector2(120, 20)]
## Les hommes de Sceau devant le Holzturm, le receleur sur la rive, les poinçons.
const RECELEUR := Vector2(124, 14)
const POINCONS := Vector2(127, 8)
## Les jardins du nord-ouest et la faille, contre le rempart.
const JARDINS := Rect2(-150, -150, 70, 50)
const FAILLE := Vector2(-136, -138)
## Les remparts : ouest, nord, sud (le mur du Rhin est à part).
const REMPARTS := [Vector2(MUR_RHIN_X, -158), Vector2(-158, -158), Vector2(-158, 150), Vector2(MUR_RHIN_X, 150)]
const MAISONS_COULEURS := [Color(0.94, 0.9, 0.8), Color(0.92, 0.78, 0.62), Color(0.9, 0.86, 0.72), Color(0.86, 0.68, 0.6),
		Color(0.95, 0.92, 0.84), Color(0.9, 0.82, 0.66), Color(0.88, 0.84, 0.76), Color(0.84, 0.74, 0.58)]

var _mur_e: StaticBody3D
var _nefs: Array[Node3D] = []
var _rues: Array = []
var _nuit := false
var _mur_fust: StaticBody3D
var _route_francfort := false
var _lumieres_nuit: Node3D
var _portail_qg: Node3D
var _grille_crypte: Node3D
var _crypte_ouverte := false


func _init() -> void:
	identifiant_zone = "ville"
	taille_terrain = 340
	graine = 1452
	point_apparition = ARRIVEE
	nombre_touffes = 14000
	fertilite_sols = Vector3(0.0, 0.2, 1.0)
	neige_qui_tombe = false
	sols = {
		# Rouge : les pavés et la terre battue des rues, la rive.
		"galets": ["cobblestone_floor_04", "brown_mud_02", "dry_river_pebbles"],
		# Vert : les cours et les jardins (terre, feuilles).
		"neige": ["brown_mud_02", "brown_mud_rocks_01", "brown_mud_02"],
		# Bleu : l'herbe des jardins et des fossés.
		"sol": ["withered_grass", "brown_mud_02", "dry_ground_01"],
		"roche": ["rock_wall_10", "stacked_stone_wall", "cliff_side"],
	}
	reglages_terrain = {"sol_saturation": 1.15, "sol_motif": 6.0, "galets_motif": 3.0, "neige_motif": 5.0,
			"sol_teinte": Color(0.68, 0.82, 0.46), "roche_teinte": Color(0.82, 0.78, 0.74), "roche_saturation": 0.8,
			"neige_eclat": 1.0, "neige_paillettes": 0.0, "roche_motif": 8.0,
			"neige_teinte": Color(0.78, 0.66, 0.52), "neige_max": Vector3(0.56, 0.44, 0.32), "neige_simple": Color(0.4, 0.3, 0.22),
			"givre": 0.0, "neige_translucide": 0.0}
	reglages_herbe = {"couleur_base": Color(0.18, 0.27, 0.1), "couleur_pointe": Color(0.6, 0.66, 0.3),
			"couleur_givre": Color(0.74, 0.62, 0.36), "force_vent": 0.4}
	reglages_couvre_sol = {"cailloux": 2.0, "fleurs": [Color(0.95, 0.92, 0.85), Color(0.96, 0.8, 0.2)],
			"densite_fleurs": 1.0, "buissons": 0.3, "litiere": 1.5}
	_rues = [RUE_HOLZTURM, RUE_CHRISTOPHE, RUE_ORFEVRES, RUE_FISCHTOR, RUE_SUD]
	piste = RUE_CHRISTOPHE.duplicate()


func _ready() -> void:
	if not Engine.is_editor_hint() and Reseau.has_meta("arrivee_mayence"):
		if Reseau.get_meta("arrivee_mayence") == "francfort":
			# Retour de Francfort : on débarque au ponton de la nef de Fust.
			point_apparition = PONTON_FUST + Vector2(-14, 0)
		elif Reseau.get_meta("arrivee_mayence") == "fonderie":
			# On remonte de la fonderie par la porte de la crypte.
			point_apparition = DESCENTE_FONDERIE + Vector2(0, 5)
		Reseau.remove_meta("arrivee_mayence")
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	if zone == "rhin":
		return SORTIE_E
	if zone == "francfort":
		return SORTIE_N
	if zone == "fonderie":
		return DESCENTE_FONDERIE
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


func dans_la_ville(p: Vector2) -> bool:
	return p.x > -152.0 and p.x < MUR_RHIN_X - 4.0 and p.y > -152.0 and p.y < 144.0


## La ville est presque plate ; le sol descend doucement vers le Rhin, puis la rive plonge.
func _base(x: float, z: float) -> float:
	var h := 3.0 + (BERGE_X - x) * 0.012 + _relief.get_noise_2d(x, z) * 0.8
	return lerpf(h, -2.5, smoothstep(BERGE_X - 6.0, BERGE_X + 8.0, x))


func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	var p := Vector2(x, z)
	var h := _base(x, z) + _details.get_noise_2d(x * 3.0, z * 3.0) * 0.05
	# Les rues, un peu creusées et lissées.
	var d := distance_rues(p)
	h = lerpf(h, _base(x, z) - 0.06, 1.0 - smoothstep(3.0, 6.0, d))
	# Le parvis de la cathédrale et la place du marché, plats.
	h = lerpf(h, _base(DOM.get_center().x, DOM.get_center().y), _dans_rect(DOM.grow(10.0), x, z, 10.0))
	h = lerpf(h, _base(MARCHE.get_center().x, MARCHE.get_center().y), _dans_rect(MARCHE, x, z, 8.0))
	h = lerpf(h, _base(COUR.get_center().x, COUR.get_center().y), _dans_rect(COUR.grow(4.0), x, z, 6.0))
	return h


## Rouge : rues et rive ; vert : cours et jardins ; bleu : herbe.
func _parts_sol(x: float, z: float, _h: float) -> Color:
	var p := Vector2(x, z)
	var n := _relief.get_noise_2d(x * 2.0 + 30.0, z * 2.0)
	var rue := 1.0 - smoothstep(3.2, 5.0 + n, distance_rues(p))
	rue = maxf(rue, _dans_rect(MARCHE, x, z, 3.0))
	rue = maxf(rue, _dans_rect(DOM.grow(8.0), x, z, 3.0))
	rue = maxf(rue, smoothstep(MUR_RHIN_X + 2.0, MUR_RHIN_X + 6.0, x))
	var cour := _dans_rect(COUR, x, z, 3.0) * (1.0 - rue)
	var ville := 1.0 if dans_la_ville(p) else 0.0
	cour = maxf(cour, ville * 0.65 * (1.0 - rue) * (1.0 - _dans_rect(JARDINS, x, z, 8.0)))
	var herbe := maxf(0.0, 1.0 - rue - cour)
	return Color(rue + 0.001, cour, herbe, 1.0)


# --- Construction -------------------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_construire_terrain()
	_construire_rhin()
	_construire_rive()
	_construire_remparts()
	_construire_dom()
	_construire_marche()
	_construire_cour_humbrecht()
	_construire_maisons()
	_construire_vegetation()
	_construire_touffes()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_appliquer_ciel()


## Une place occupée (bâtiment ou lieu de la quête) ?
func _occupe(p: Vector2, marge := 3.0) -> bool:
	if DOM.grow(10.0 + marge).has_point(p) or MARCHE.grow(marge).has_point(p) or COUR.grow(marge + 2.0).has_point(p):
		return true
	if JARDINS.grow(marge).has_point(p) or p.distance_to(CHRISTOPHE) < 16.0 + marge or p.distance_to(HOLZTURM) < 12.0 + marge:
		return true
	if p.distance_to(ORFEVRES) < 6.0 + marge or p.distance_to(HUMERY) < 5.0 + marge or p.distance_to(FISCHTOR) < 10.0 + marge:
		return true
	for q: Vector2 in INDICES:
		if p.distance_to(q) < 4.0 + marge:
			return true
	return distance_rues(p) < 4.2 + marge * 0.2


func _construire_rhin() -> void:
	var eau := _eau_du_rhin(Vector3(BERGE_X + 430.0, NIVEAU_RHIN, 0), Vector2(860, 5200))
	eau.name = "Rhin"
	var dossier := Node3D.new()
	dossier.name = "Bateaux"
	_contenu.add_child(dossier)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 7
	for k in 4:
		var b := _barque_rhin(dossier, Vector3(BERGE_X + 3.0 + hasard.randf_range(0, 2), NIVEAU_RHIN + 0.1, -100 + k * 46 + hasard.randf_range(-4, 4)),
				hasard.randf_range(-0.2, 0.2))
		b.name = "Barque%d" % k
	for k in 2:
		var amarree := _nef_du_rhin(dossier, Vector3(BERGE_X + 8.0, NIVEAU_RHIN + 0.2, -40 + k * 56), 0.0,
				[Color(0.88, 0.84, 0.76), Color(0.74, 0.3, 0.22)][k])
		amarree.name = "NefAmarree%d" % k
	for k in 3:
		var n := _nef_du_rhin(dossier, Vector3(BERGE_X + 80.0 + k * 60.0, NIVEAU_RHIN + 0.2, -300 + k * 260), 0.0,
				[Color(0.86, 0.84, 0.78), Color(0.88, 0.82, 0.7), Color(0.74, 0.3, 0.22)][k])
		_nefs.append(n)
	# Le ponton du bac.
	var bois := _mat_colombage()
	_boite(Vector3(14.0, 0.25, 4.0), Vector3(BAC.x, NIVEAU_RHIN + 0.9, BAC.y), bois, dossier)
	for k in 4:
		for cote: float in [-1.0, 1.0]:
			var pieu := MeshInstance3D.new()
			pieu.mesh = _cylindre(0.12, 0.14, 3.2, 8)
			pieu.material_override = bois
			pieu.position = Vector3(BAC.x - 6.0 + k * 3.6, NIVEAU_RHIN - 0.4, BAC.y + cote * 1.9)
			dossier.add_child(pieu)
	var bac := _nef_du_rhin(dossier, Vector3(BAC.x + 10.0, NIVEAU_RHIN + 0.2, BAC.y - 6.0), PI / 2 + 0.1, Color(0.86, 0.82, 0.72))
	bac.name = "NefDuBac"
	# Le ponton de la nef de Fust (le départ pour la foire de Francfort, par le Main).
	_boite(Vector3(14.0, 0.25, 4.0), Vector3(PONTON_FUST.x, NIVEAU_RHIN + 0.9, PONTON_FUST.y), bois, dossier)
	for k in 4:
		for cote: float in [-1.0, 1.0]:
			var pieu := MeshInstance3D.new()
			pieu.mesh = _cylindre(0.12, 0.14, 3.2, 8)
			pieu.material_override = bois
			pieu.position = Vector3(PONTON_FUST.x - 6.0 + k * 3.6, NIVEAU_RHIN - 0.4, PONTON_FUST.y + cote * 1.9)
			dossier.add_child(pieu)
	var nef_fust := _nef_du_rhin(dossier, Vector3(PONTON_FUST.x + 10.0, NIVEAU_RHIN + 0.2, PONTON_FUST.y + 6.0), PI / 2, Color(0.74, 0.3, 0.22))
	nef_fust.name = "NefDeFust"


## La rive : entre le mur du Rhin et l'eau, les grues, les tonneaux, les ballots.
func _construire_rive() -> void:
	var dossier := Node3D.new()
	dossier.name = "Rive"
	_contenu.add_child(dossier)
	for c: Vector2 in [Vector2(126, -22), Vector2(126, 92)]:
		var g := _roue_ecureuil(dossier, c, -PI / 2)
		g.name = "GrueRhin%d" % dossier.get_child_count()
		var ballot := g.find_child("BlocPendu", true, false) as MeshInstance3D
		if ballot != null:
			ballot.material_override = _mat_uni_ma(Color(0.74, 0.68, 0.56), 1.0)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 5
	var toile := _mat_uni_ma(Color(0.74, 0.68, 0.56), 1.0)
	for k in 30:
		var c := Vector2(hasard.randf_range(116.0, 128.0), hasard.randf_range(-140.0, 140.0))
		if c.distance_to(ARRIVEE) < 8.0 or c.distance_to(RECELEUR) < 6.0 or c.distance_to(HOLZTURM) < 8.0 \
				or c.distance_to(INDICES[2]) < 4.0 or c.distance_to(FISCHTOR) < 8.0 or absf(c.y - PONTON_FUST.y) < 5.0:
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
	# Le camp du receleur : des caisses et une petite tente contre le mur.
	_tente(dossier, RECELEUR + Vector2(-6, -6), PI / 2, Color(0.3, 0.28, 0.28))
	_charrette(dossier, RECELEUR + Vector2(-4, 8), 0.2, true)


## Une tour ronde de rempart, en grès, avec un toit conique d'ardoise.
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
	var chemin := _boite(Vector3(l, 0.4, 2.8), Vector3(c.x, y + haut - 0.4, c.y), _mat_gres_rouge(), parent, false)
	chemin.rotation.y = mur.rotation.y
	# Les créneaux.
	var n := int(l / 2.4)
	var dir := d / l
	var normale := Vector2(-dir.y, dir.x)
	for k in n:
		var q := a + dir * (1.2 + k * 2.4) + normale * 1.1
		var cr := _boite(Vector3(1.2, 1.0, 0.5), Vector3(q.x, y + haut + 0.3, q.y), _mat_schiste(), parent, false)
		cr.rotation.y = mur.rotation.y


func _construire_remparts() -> void:
	var dossier := Node3D.new()
	dossier.name = "Remparts"
	_contenu.add_child(dossier)
	# Ouest, nord, sud.
	for i in REMPARTS.size() - 1:
		_mur_rempart(dossier, REMPARTS[i], REMPARTS[i + 1], 8.0)
	for k in REMPARTS.size():
		_tour_ronde(dossier, REMPARTS[k], 13.0, 3.6)
	for p: Vector2 in [Vector2(-60, -158), Vector2(30, -158), Vector2(-158, -60), Vector2(-158, 40), Vector2(-40, 150), Vector2(40, 150)]:
		_tour_ronde(dossier, p, 11.0, 3.0)
	# Le mur du Rhin, coupé par le Holzturm et la porte des Pêcheurs.
	var coupes := [Vector2(MUR_RHIN_X, -158), Vector2(MUR_RHIN_X, FISCHTOR.y - 4.0), Vector2(MUR_RHIN_X, FISCHTOR.y + 4.0),
			Vector2(MUR_RHIN_X, HOLZTURM.y - 4.5), Vector2(MUR_RHIN_X, HOLZTURM.y + 4.5), Vector2(MUR_RHIN_X, 150)]
	for i in [0, 2, 4]:
		_mur_rempart(dossier, coupes[i], coupes[i + 1], 7.0)
	_tour_porte(dossier, HOLZTURM, 28.0, "Holzturm")
	_tour_porte(dossier, FISCHTOR, 16.0, "Fischtor")


## Une tour-porte de grès rouge : deux piles, le passage voûté, l'étage, le toit en bâtière.
func _tour_porte(parent: Node3D, p: Vector2, haut: float, nom: String) -> void:
	var t := Node3D.new()
	t.name = nom
	t.position = Vector3(p.x, hauteur(p.x, p.y) - 0.4, p.y)
	parent.add_child(t)
	var gres := _mat_gres_rouge()
	var largeur := 9.0
	var passage := 4.4
	var pile := (largeur - passage) * 0.5
	for cote: float in [-1.0, 1.0]:
		_boite(Vector3(9.0, 6.0, pile), Vector3(0, 3.0, cote * (passage * 0.5 + pile * 0.5)), gres, t)
	_boite(Vector3(9.0, haut - 6.0, largeur), Vector3(0, 6.0 + (haut - 6.0) * 0.5, 0), gres, t)
	_boite(Vector3(9.4, 0.6, largeur + 0.4), Vector3(0, 6.0, 0), _mat_schiste(), t, false)
	var sombre := _mat_uni_ma(Color(0.05, 0.05, 0.06), 1.0)
	for k in int((haut - 8.0) / 5.0):
		for cote: float in [-1.0, 1.0]:
			_boite(Vector3(0.1, 1.6, 0.9), Vector3(cote * 4.52, 9.0 + k * 5.0, 0), sombre, t, false)
	var toit := Node3D.new()
	toit.position = Vector3(0, haut, 0)
	t.add_child(toit)
	_toit_pentu(toit, Vector3.ZERO, 9.6, largeur + 0.6, _mat_ardoise(), gres, 1.0, 0.18)
	# Les échauguettes aux quatre coins.
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			var e := MeshInstance3D.new()
			e.mesh = _cylindre(0.9, 0.9, 3.0, 10)
			e.material_override = gres
			e.position = Vector3(cx * 4.6, haut - 1.5, cz * 4.6)
			t.add_child(e)
			var ct := MeshInstance3D.new()
			ct.mesh = _cylindre(0.05, 1.2, 2.4, 10)
			ct.material_override = _mat_ardoise()
			ct.position = Vector3(cx * 4.6, haut + 1.2, cz * 4.6)
			t.add_child(ct)


## La cathédrale Saint-Martin : romane, en grès rouge, deux chœurs (est et ouest), une
## grosse tour de croisée à l'ouest, une tour plus basse à l'est, des tourelles d'escalier.
func _construire_dom() -> void:
	var d := Node3D.new()
	d.name = "Cathedrale"
	_contenu.add_child(d)
	var gres := _mat_gres_rouge()
	var clair := _mat_crepi(Color(0.86, 0.62, 0.52))
	var sombre := _mat_uni_ma(Color(0.04, 0.04, 0.05), 1.0)
	var c := DOM.get_center()
	var y := hauteur(c.x, c.y) - 0.3
	var o := Vector3(c.x, y, c.y)
	# La nef et les bas-côtés.
	var nef := Vector3(DOM.size.x - 28.0, 26.0, 14.0)
	_boite(nef, o + Vector3(0, nef.y * 0.5, 0), clair, d)
	for cote: float in [-1.0, 1.0]:
		_boite(Vector3(nef.x, 13.0, 8.0), o + Vector3(0, 6.5, cote * 11.0), clair, d)
		var pan := _boite(Vector3(nef.x + 0.4, 0.25, 9.0), o + Vector3(0, 14.2, cote * 10.6), _mat_ardoise(), d, false)
		pan.rotation.x = -cote * 0.4
		# Les fenêtres hautes et basses, les lésènes de grès.
		for k in 8:
			var x := -nef.x * 0.5 + 4.0 + k * (nef.x - 8.0) / 7.0
			_boite(Vector3(1.2, 3.2, 0.1), o + Vector3(x, 20.0, cote * (nef.z * 0.5 + 0.03)), sombre, d, false)
			_boite(Vector3(1.0, 2.6, 0.1), o + Vector3(x, 7.0, cote * 15.03), sombre, d, false)
			_boite(Vector3(0.7, 13.0, 0.5), o + Vector3(x + 3.0, 6.5, cote * 15.2), gres, d, false)
	_boite(Vector3(nef.x + 0.4, 0.5, nef.z + 0.4), o + Vector3(0, nef.y, 0), gres, d, false)
	var toit := Node3D.new()
	toit.position = o + Vector3(0, nef.y, 0)
	toit.rotation.y = PI / 2
	d.add_child(toit)
	_toit_pentu(toit, Vector3.ZERO, nef.z + 0.6, nef.x, _mat_ardoise(), clair, 0.7, 0.2)
	# Les deux chœurs : à l'ouest le grand transept et la tour de croisée octogonale ; à l'est
	# une abside ronde et une tour plus basse.
	for bout: float in [-1.0, 1.0]:
		var x := bout * (nef.x * 0.5 + 7.0)
		var haut_tour := 58.0 if bout < 0.0 else 42.0
		_boite(Vector3(14.0, 26.0, DOM.size.y + (6.0 if bout < 0.0 else 0.0)), o + Vector3(x, 13.0, 0), gres, d)
		var tour := MeshInstance3D.new()
		tour.mesh = _cylindre(7.0, 7.4, haut_tour - 26.0, 8)
		tour.material_override = gres
		tour.position = o + Vector3(x, 26.0 + (haut_tour - 26.0) * 0.5, 0)
		d.add_child(tour)
		var galerie := MeshInstance3D.new()
		galerie.mesh = _cylindre(7.6, 7.6, 1.0, 8)
		galerie.material_override = _mat_schiste()
		galerie.position = o + Vector3(x, haut_tour - 3.0, 0)
		d.add_child(galerie)
		for k in 8:
			var a := k * TAU / 8.0 + PI / 8.0
			var baie := _boite(Vector3(0.1, 4.0, 1.4), o + Vector3(x + cos(a) * 7.05, haut_tour - 8.0, sin(a) * 7.05), sombre, d, false)
			baie.rotation.y = -a
		var fleche := MeshInstance3D.new()
		fleche.mesh = _cylindre(0.3, 7.2, 14.0 if bout < 0.0 else 10.0, 8)
		fleche.material_override = _mat_ardoise()
		fleche.position = o + Vector3(x, haut_tour + (7.0 if bout < 0.0 else 5.0), 0)
		d.add_child(fleche)
		# Les tourelles d'escalier rondes, de part et d'autre du chœur.
		for cote: float in [-1.0, 1.0]:
			var t := MeshInstance3D.new()
			t.mesh = _cylindre(2.6, 2.8, 38.0, 12)
			t.material_override = gres
			t.position = o + Vector3(x + bout * 6.0, 19.0, cote * (DOM.size.y * 0.5 + 1.5))
			d.add_child(t)
			var ct := MeshInstance3D.new()
			ct.mesh = _cylindre(0.1, 3.0, 6.0, 12)
			ct.material_override = _mat_ardoise()
			ct.position = t.position + Vector3(0, 22.0, 0)
			d.add_child(ct)
		var abside := MeshInstance3D.new()
		abside.mesh = _cylindre(6.5, 6.8, 18.0, 16)
		abside.material_override = gres
		abside.position = o + Vector3(x + bout * 7.0, 9.0, 0)
		d.add_child(abside)
	# Le grand portail de bronze (au nord, côté marché) : les portes de Willigis.
	_boite(Vector3(4.0, 6.0, 0.3), o + Vector3(10.0, 3.0, -15.2), _mat_uni_ma(Color(0.45, 0.32, 0.16), 0.4), d, false)
	_boite(Vector3(6.0, 8.0, 1.0), o + Vector3(10.0, 4.0, -15.6), gres, d, false)
	# Une collision simple pour tout le corps de l'église.
	_fusionner(d)


func _etal(parent: Node3D, q: Vector2, angle: float, hasard: RandomNumberGenerator) -> void:
	var couleurs := [Color(0.72, 0.24, 0.2), Color(0.2, 0.36, 0.6), Color(0.86, 0.8, 0.62), Color(0.3, 0.5, 0.3)]
	_auvent(parent, q, Vector2(3.4, 2.6), 2.4, couleurs[hasard.randi() % couleurs.size()])
	var table := _boite(Vector3(2.8, 0.1, 1.2), Vector3(q.x, hauteur(q.x, q.y) + 0.85, q.y), _mat_chene_clair(), parent, false)
	table.rotation.y = angle
	for k in 5:
		var m := _boite(Vector3(0.3, 0.2, 0.3), table.position + Vector3(-1.0 + k * 0.5, 0.15, 0), _mat_uni_ma(
				[Color(0.8, 0.3, 0.2), Color(0.86, 0.7, 0.3), Color(0.5, 0.6, 0.3), Color(0.6, 0.4, 0.6)][k % 4], 0.8), parent, false)
		m.rotation.y = hasard.randf() * TAU


func _construire_marche() -> void:
	var dossier := Node3D.new()
	dossier.name = "Marche"
	_contenu.add_child(dossier)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 12
	for k in 10:
		var q := Vector2(MARCHE.position.x + 6.0 + (k % 5) * 8.0, MARCHE.position.y + 10.0 + (k / 5) * 20.0)
		if q.distance_to(HUMERY) < 5.0 or q.distance_to(INDICES[1]) < 4.0:
			continue
		_etal(dossier, q, 0.0, hasard)
	_puits(dossier, MARCHE.get_center() + Vector2(0, 2))
	_charrette(dossier, MARCHE.position + Vector2(4, 36), 0.6, true)


func _construire_cour_humbrecht() -> void:
	var dossier := Node3D.new()
	dossier.name = "CourHumbrecht"
	_contenu.add_child(dossier)
	# La maison noble du Humbrecht au nord de la cour, les communs à l'ouest et à l'est.
	var maison := _maison_rhenane(dossier, Vector2(COUR.get_center().x, COUR.position.y - 3.0), Vector3(10.0, 9.0, 22.0), PI / 2, Color(0.94, 0.88, 0.78))
	maison.name = "MaisonHumbrecht"
	_maison_rhenane(dossier, Vector2(COUR.position.x - 4.0, COUR.get_center().y + 4.0), Vector3(7.0, 7.0, 12.0), 0.0, Color(0.9, 0.82, 0.68))
	_maison_rhenane(dossier, Vector2(COUR.end.x + 5.0, COUR.get_center().y - 4.0), Vector3(7.0, 7.4, 12.0), PI, Color(0.92, 0.86, 0.74))
	# Le mur de la cour au sud, avec le porche.
	_muret_sec(dossier, Vector2(COUR.position.x, COUR.end.y), Vector2(PORCHE.x - 2.6, COUR.end.y), 3.0)
	_muret_sec(dossier, Vector2(PORCHE.x + 2.6, COUR.end.y), Vector2(COUR.end.x, COUR.end.y), 3.0)
	var gres := _mat_gres_rouge()
	for cote: float in [-1.0, 1.0]:
		_boite(Vector3(0.8, 4.2, 0.8), Vector3(PORCHE.x + cote * 2.8, hauteur(PORCHE.x, PORCHE.y) + 2.1, PORCHE.y + 2.0), gres, dossier)
	_boite(Vector3(6.4, 0.8, 0.9), Vector3(PORCHE.x, hauteur(PORCHE.x, PORCHE.y) + 4.4, PORCHE.y + 2.0), gres, dossier, false)
	# L'atelier : une halle ouverte (on voit tout de la cour), la presse, les casses, les
	# feuilles imprimées qui sèchent sur des cordes.
	var atelier := _halle_pressoir(dossier, ATELIER, Vector2(18.0, 10.0), 0.0)
	atelier.name = "AtelierGutenberg"
	var presse := _pressoir_a_vis(dossier, PRESSE, 0.0, 0.8)
	presse.name = "PresseGutenberg"
	var papier := _mat_uni_ma(Color(0.95, 0.93, 0.86), 0.95)
	var noir := _mat_uni_ma(Color(0.06, 0.06, 0.06), 0.9)
	var corde := _mat_uni_ma(Color(0.7, 0.62, 0.45), 1.0)
	var yc := hauteur(ATELIER.x, ATELIER.y)
	for r in 2:
		var z := ATELIER.y - 3.4 + r * 1.2
		_boite(Vector3(10.0, 0.02, 0.02), Vector3(ATELIER.x + 3.0, yc + 3.4, z), corde, dossier, false)
		for k in 14:
			var x := ATELIER.x - 1.6 + k * 0.66
			_boite(Vector3(0.5, 0.7, 0.01), Vector3(x, yc + 3.02, z), papier, dossier, false)
			# Deux colonnes de texte noir sur chaque feuille.
			for col: float in [-0.11, 0.11]:
				_boite(Vector3(0.17, 0.52, 0.004), Vector3(x + col, yc + 3.02, z + 0.008), _mat_uni_ma(Color(0.28, 0.28, 0.28), 1.0), dossier, false)
	# Les casses de lettres sur leurs tréteaux, et les tables des compositeurs.
	for k in 3:
		var c := Vector2(ATELIER.x + 1.0 + k * 2.2, ATELIER.y + 3.0)
		var plateau := _boite(Vector3(1.6, 0.06, 0.9), Vector3(c.x, yc + 1.05, c.y), _mat_chene_clair(), dossier, false)
		plateau.rotation.x = -0.3
		_boite(Vector3(1.6, 1.0, 0.8), Vector3(c.x, yc + 0.5, c.y), _mat_chene_clair(), dossier)
	# Les balles à encrer et le marbre où l'on pose la forme.
	_boite(Vector3(1.6, 0.9, 1.0), Vector3(PRESSE.x - 3.0, yc + 0.45, PRESSE.y), _mat_schiste(), dossier)
	for k in 2:
		var balle := MeshInstance3D.new()
		balle.mesh = SphereMesh.new()
		(balle.mesh as SphereMesh).radius = 0.15
		(balle.mesh as SphereMesh).height = 0.22
		balle.material_override = noir
		balle.position = Vector3(PRESSE.x - 3.3 + k * 0.5, yc + 1.0, PRESSE.y)
		dossier.add_child(balle)
	# La fonderie : un fourneau de briques, sa hotte, la lueur du métal fondu.
	var f := Node3D.new()
	f.name = "Fonderie"
	f.position = Vector3(FONDERIE.x, hauteur(FONDERIE.x, FONDERIE.y), FONDERIE.y)
	dossier.add_child(f)
	var brique := _mat_uni_ma(Color(0.56, 0.28, 0.2), 0.9)
	_boite(Vector3(2.4, 1.2, 2.0), Vector3(0, 0.6, 0), brique, f)
	_boite(Vector3(1.6, 3.6, 1.4), Vector3(0, 3.0, -0.2), brique, f, false)
	var hotte := MeshInstance3D.new()
	hotte.mesh = _cylindre(0.5, 1.4, 1.2, 4)
	hotte.material_override = brique
	hotte.rotation.y = PI / 4
	hotte.position = Vector3(0, 1.9, 0)
	f.add_child(hotte)
	var lueur := OmniLight3D.new()
	lueur.light_color = Color(1.0, 0.55, 0.2)
	lueur.light_energy = 2.4
	lueur.omni_range = 6.0
	lueur.position = Vector3(0, 1.6, 0.8)
	f.add_child(lueur)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(1.0, 0.6, 0.2)
	metal.emission_enabled = true
	metal.emission = Color(1.0, 0.45, 0.1)
	metal.emission_energy_multiplier = 3.0
	var creuset := MeshInstance3D.new()
	creuset.mesh = _cylindre(0.32, 0.26, 0.04, 12)
	creuset.material_override = metal
	creuset.position = Vector3(0, 1.24, 0.3)
	f.add_child(creuset)
	# L'église Saint-Christophe, à l'est de la cour.
	var eglise := _eglise_village(dossier, CHRISTOPHE, PI / 2)
	eglise.name = "SaintChristophe"
	for mi in eglise.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D)
		if m.material_override == _mat_calcaire():
			m.material_override = _mat_gres_rouge()
		elif m.material_override == _mat_tuiles_plates():
			m.material_override = _mat_ardoise()


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
					var largeur := hasard.randf_range(5.6, 7.0)
					var q := a + dir * t + normale * cote * (4.8 + 4.0)
					if not dans_la_ville(q) or _occupe(q, 0.0) or _trop_pres(dossier, q, 6.5):
						continue
					var n := -normale * cote
					_maison_rhenane(dossier, q, Vector3(largeur, hasard.randf_range(6.4, 8.2), 8.0), atan2(n.x, n.y),
							MAISONS_COULEURS[hasard.randi() % MAISONS_COULEURS.size()])
				t += hasard.randf_range(7.0, 8.5)
	var poses := 0
	var essais := 0
	while poses < 60 and essais < 3000:
		essais += 1
		var q := Vector2(hasard.randf_range(-148.0, 104.0), hasard.randf_range(-148.0, 140.0))
		if not dans_la_ville(q) or _occupe(q, 3.0) or _trop_pres(dossier, q, 11.0):
			continue
		_maison_rhenane(dossier, q, Vector3(hasard.randf_range(6.0, 7.6), hasard.randf_range(6.4, 8.4), hasard.randf_range(7.0, 9.0)),
				(hasard.randi() % 4) * PI / 2 + hasard.randf_range(-0.1, 0.1), MAISONS_COULEURS[hasard.randi() % MAISONS_COULEURS.size()])
		poses += 1
	# Les échoppes des orfèvres : des auvents et des établis le long de la rue.
	var orf := Node3D.new()
	orf.name = "Orfevres"
	_contenu.add_child(orf)
	for k in 4:
		var q: Vector2 = (RUE_ORFEVRES[2] as Vector2).lerp(RUE_ORFEVRES[3], 0.15 + k * 0.2) + Vector2(0, -4.2)
		_auvent(orf, q, Vector2(3.4, 2.2), 2.3, Color(0.3, 0.3, 0.42))
		_boite(Vector3(2.2, 0.9, 0.8), Vector3(q.x, hauteur(q.x, q.y) + 0.45, q.y), _mat_chene_clair(), orf)
	_fusionner(dossier)


func _construire_vegetation() -> void:
	var arbres := Node3D.new()
	arbres.name = "Arbres"
	_contenu.add_child(arbres)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 60
	# Les jardins du nord-ouest : des noyers, des tilleuls (chênes), un verger.
	var plantes := 0
	var essais := 0
	while plantes < 26 and essais < 2000:
		essais += 1
		var p := Vector2(hasard.randf_range(JARDINS.position.x + 4.0, JARDINS.end.x - 4.0), hasard.randf_range(JARDINS.position.y + 4.0, JARDINS.end.y - 4.0))
		if p.distance_to(FAILLE) < 10.0 or _trop_pres(arbres, p, 6.0):
			continue
		_arbre_realiste(arbres, p, ["noyer", "chene", "chataignier"][plantes % 3], hasard, hasard.randf_range(0.8, 1.1))
		plantes += 1
	# Quelques arbres isolés dans les cours, sur la place de la cathédrale et le long de la rive.
	plantes = 0
	essais = 0
	while plantes < 30 and essais < 4000:
		essais += 1
		var p := Vector2(hasard.randf_range(-148.0, 104.0), hasard.randf_range(-148.0, 140.0))
		if not dans_la_ville(p) or _occupe(p, 3.0) or _trop_pres(_contenu.get_node("Maisons"), p, 7.0) or _trop_pres(arbres, p, 10.0):
			continue
		_arbre_realiste(arbres, p, ["noyer", "chene", "hetre_automne"][plantes % 3], hasard, hasard.randf_range(0.7, 1.0))
		plantes += 1
	for k in 10:
		var p := Vector2(BERGE_X - 2.0, -150 + k * 30 + hasard.randf_range(-5, 5))
		if absf(p.y - BAC.y) < 10.0 or absf(p.y - RECELEUR.y) < 10.0:
			continue
		_arbre_realiste(arbres, p, "saule", hasard, hasard.randf_range(0.8, 1.0))
	# Des arbres hors les murs, à l'ouest et au sud (on les voit par-dessus le rempart).
	for k in 40:
		var p := Vector2(hasard.randf_range(-170, -162), hasard.randf_range(-165, 165)) if k % 2 == 0 \
				else Vector2(hasard.randf_range(-160, 100), hasard.randf_range(156, 168))
		_arbre_realiste(arbres, p, ["chene", "noyer", "hetre_automne"][k % 3], hasard, hasard.randf_range(0.9, 1.2))


# --- Paysage lointain ----------------------------------------------------------------------

func _construire_lointain() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 70
	_plan_lointain_autour(-3.0, Color(0.1, 0.1, 0.8))
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.8
	# Les collines du Taunus au nord-est (de l'autre côté du Rhin), le plateau à l'ouest.
	for m in [[Vector3(1300, -10, -1100), Vector3(3000, 160, 700)], [Vector3(-1300, -10, 0), Vector3(900, 70, 3000)],
			[Vector3(0, -10, 1300), Vector3(3000, 60, 600)], [Vector3(0, -10, -1300), Vector3(3000, 80, 600)]]:
		bruit.seed = graine + hasard.randi()
		var colline := MeshInstance3D.new()
		colline.mesh = _maillage_bosse(bruit, m[1], 1.4, 0.3, 24, Color(0.2, 0.0, 0.6))
		colline.material_override = _mat_lointain()
		colline.position = m[0]
		colline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(colline)
	# Des toits et des clochers de la ville qui continue au sud et au nord, hors de la zone.
	var loin := Node3D.new()
	loin.name = "VilleLointaine"
	_contenu.add_child(loin)
	for k in 30:
		var c := Vector3(hasard.randf_range(-400, 100), 0, hasard.randf_range(220, 420) * (1.0 if k % 2 == 0 else -1.0))
		_boite(Vector3(hasard.randf_range(10, 20), hasard.randf_range(8, 14), hasard.randf_range(10, 18)), c + Vector3(0, 5, 0),
				_mat_uni_ma(Color(0.52, 0.46, 0.44), 0.9), loin, false)


# --- Limites de la zone -----------------------------------------------------------------------

func _construire_limites() -> void:
	var limites := Node3D.new()
	limites.name = "Limites"
	_contenu.add_child(limites)
	var demi := taille_terrain * 0.5 - 4.0
	_mur_invisible(limites, Vector3(2, 140, taille_terrain), Vector3(-demi, 40, 0))
	_mur_invisible(limites, Vector3(2, 140, taille_terrain), Vector3(demi, 40, 0))
	_mur_invisible(limites, Vector3(taille_terrain, 140, 2), Vector3(0, 40, -demi))
	_mur_invisible(limites, Vector3(taille_terrain, 140, 2), Vector3(0, 40, demi))
	# On ne se baigne pas dans le Rhin (sauf par le ponton du bac).
	for z: Array in [[-170.0, PONTON_FUST.y - 3.0], [PONTON_FUST.y + 3.0, BAC.y - 3.0], [BAC.y + 3.0, 170.0]]:
		var l: float = z[1] - z[0]
		_mur_invisible(limites, Vector3(2, 30, l), Vector3(BERGE_X + 2.0, 8, (z[0] + z[1]) * 0.5))
	# Le ponton de Fust : fermé tant que l'histoire n'y mène pas.
	_mur_fust = _mur_invisible(limites, Vector3(2, 30, 6), Vector3(BERGE_X + 2.0, 8, PONTON_FUST.y))


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


func _construire_quete() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quete"
	_contenu.add_child(dossier)
	_dossier_quete = dossier
	# L'atelier : Gutenberg, Keffer, Schöffer, Hans le fondeur, Fust (Scellé sur son coffre).
	_pnj(dossier, "gutenberg", GUTENBERG, PI * 0.9)
	_pnj(dossier, "heinrich_keffer", KEFFER, PI)
	_pnj(dossier, "peter_schoeffer", SCHOEFFER, PI * 0.8)
	var hans := _pnj(dossier, "hans_fondeur", HANS, -PI * 0.7)
	# Chapitre 8 : Hans descend dans la fonderie (masqué), puis remonte (montré).
	hans.add_to_group("decor_quete")
	hans.set_meta("identifiant", "hans_fondeur")
	_scelle(dossier, "johann_fust", "liberer_fust", "", FUST, PI * 0.6)
	_objet(dossier, "moule_atelier", FONDERIE + Vector2(0, 1.6), "", "[F] Couler une lettre avec Hans")
	_objet(dossier, "casse_atelier", CASSE, "casse_plomb", "[F] Composer une ligne")
	_objet(dossier, "presse_atelier", PRESSE + Vector2(1.6, 0.8), "", "[F] Tirer le barreau de la presse")
	var coffre := _objet(dossier, "coffre_poincons", COFFRE, "coffret", "[F] Ouvrir le coffre des poinçons")
	coffre.rotation.y = PI
	var chat := _objet(dossier, "chat_atelier", CHAT, "chat", "")
	chat.actif = false
	# L'enquête : le syndic Humery au marché, les indices, l'orfèvre Hennen (Scellé).
	_pnj(dossier, "konrad_humery", HUMERY, PI)
	_objet(dossier, "indice_orfevres", INDICES[0], "empreinte_cire", "[F] Examiner la tache de cire", "indices_poincons")
	_objet(dossier, "indice_marche", INDICES[1], "empreinte_cire", "[F] Examiner la tache de cire", "indices_poincons")
	_objet(dossier, "indice_rive", INDICES[2], "empreinte_cire", "[F] Examiner la tache de cire", "indices_poincons")
	_scelle(dossier, "orfevre_hennen", "liberer_hennen", "", HENNEN, PI * 0.5)
	_objet(dossier, "poincons_gutenberg", POINCONS, "poincons", "[F] Reprendre les poinçons")
	# La nuit de l'Éditeur : Marchal, sa machine de 2026, les deux réponses, l'affiche de Sceau.
	var marchal := _pnj(dossier, "etienne_marchal", MARCHAL, -PI * 0.6)
	marchal.add_to_group("decor_quete")
	marchal.set_meta("identifiant", "etienne_marchal")
	marchal.visible = false
	_construire_machine(dossier)
	_objet(dossier, "dire_ouvriers", REPONSES[0], "", "[F] « Ta presse appartient à ceux qui la font. »", "", 2.0)
	_objet(dossier, "dire_apprendre", REPONSES[1], "", "[F] « Le monde doit apprendre par lui-même. »", "", 2.0)
	_objet(dossier, "affiche_sceau", AFFICHE, "affiche_roulee", "[F] Ramasser l'affiche roulée")
	_construire_lumieres_nuit(dossier)
	_construire_porte_crypte(dossier)
	# Chapitre 8 : le portail de la Vigie, dans la cour Humbrecht, pour ramener Sceau au QG.
	_construire_portail(dossier, PORTAIL_QG, PI / 2)
	_portail_qg = dossier.get_node("Portail") as Node3D
	_portail_qg.name = "PortailVigie"
	_portail_qg.add_to_group("decor_quete")
	_portail_qg.set_meta("identifiant", "portail_qg")
	_portail_qg.visible = false
	_zone_portail.monitoring = false
	var faille := Faille.new()
	faille.name = "Faille"
	faille.identifiant = "faille_ville"
	faille.position = Vector3(FAILLE.x, hauteur(FAILLE.x, FAILLE.y), FAILLE.y)
	dossier.add_child(faille)
	_construire_secondaires(dossier)
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.DANGER, "Faille", FAILLE)
	repere.call(MarqueurCarte.Type.LIEU, "La cathédrale Saint-Martin", DOM.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "La cour Humbrecht (l'atelier de Gutenberg)", PORCHE)
	repere.call(MarqueurCarte.Type.LIEU, "Le marché", MARCHE.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Les orfèvres", ORFEVRES)
	repere.call(MarqueurCarte.Type.LIEU, "Le Holzturm", HOLZTURM)
	repere.call(MarqueurCarte.Type.LIEU, "La porte de la crypte (vers la fonderie)", DESCENTE_FONDERIE)
	repere.call(MarqueurCarte.Type.LIEU, "Le bac, vers le Rhin et le moulin", BAC)


## La porte de la crypte de Saint-Martin, contre le bas-côté sud : un encadrement de grès
## rouge, un escalier qui s'enfonce dans le noir, une grille de fer fermée (elle s'ouvre au
## chapitre 8). Une lueur rouge monte d'en bas.
func _construire_porte_crypte(dossier: Node3D) -> void:
	var d := Node3D.new()
	d.name = "PorteCrypte"
	var p := DESCENTE_FONDERIE
	var y := hauteur(p.x, p.y)
	d.position = Vector3(p.x, y, p.y)
	dossier.add_child(d)
	var gres := _mat_gres_rouge()
	var noir := _mat_uni_ma(Color(0.02, 0.015, 0.015), 1.0)
	var fer := _mat_uni_ma(Color(0.1, 0.1, 0.11), 0.5)
	fer.metallic = 0.7
	# L'avant-corps : deux jambages, un linteau, un petit toit d'ardoise.
	for c: float in [-1.0, 1.0]:
		_boite(Vector3(1.0, 4.6, 3.0), Vector3(c * 2.4, 2.3, -1.2), gres, d)
	_boite(Vector3(5.8, 1.2, 3.2), Vector3(0, 5.2, -1.2), gres, d)
	var toit := _boite(Vector3(6.4, 0.25, 3.8), Vector3(0, 6.0, -1.0), _mat_ardoise(), d, false)
	toit.rotation.x = 0.25
	# Le trou noir de l'escalier, et les premières marches qui descendent.
	_boite(Vector3(3.8, 4.0, 0.2), Vector3(0, 2.0, -2.6), noir, d, false)
	for k in 4:
		_boite(Vector3(3.8, 0.3, 0.8), Vector3(0, -0.1 - k * 0.3, -1.9 + k * 0.1), _mat_schiste(), d, false)
	var lueur := OmniLight3D.new()
	lueur.light_color = Color(1.0, 0.4, 0.15)
	lueur.light_energy = 1.4
	lueur.omni_range = 5.0
	lueur.position = Vector3(0, 0.6, -1.8)
	d.add_child(lueur)
	# La grille de fer : des barreaux, fermée tant que l'histoire n'y mène pas.
	_grille_crypte = Node3D.new()
	_grille_crypte.name = "Grille"
	_grille_crypte.position = Vector3(0, 0, 0.1)
	d.add_child(_grille_crypte)
	for k in 9:
		_boite(Vector3(0.08, 4.0, 0.08), Vector3(-1.7 + k * 0.42, 2.0, 0), fer, _grille_crypte, false)
	for h: float in [0.4, 2.2, 3.9]:
		_boite(Vector3(3.6, 0.1, 0.1), Vector3(0, h, 0), fer, _grille_crypte, false)


## La machine de l'Éditeur : une petite presse électrique grise de 2026, posée sur un
## établi, avec son écran allumé et une pile de feuilles trop blanches. Elle éclaire l'atelier
## d'une lumière froide. Cachée jusqu'au chapitre 6.
func _construire_machine(dossier: Node3D) -> void:
	var m := Node3D.new()
	m.name = "MachineMarchal"
	m.add_to_group("decor_quete")
	m.set_meta("identifiant", "machine_marchal")
	m.visible = false
	m.position = Vector3(MACHINE.x, hauteur(MACHINE.x, MACHINE.y), MACHINE.y)
	m.rotation.y = -0.3
	dossier.add_child(m)
	_boite(Vector3(1.4, 0.08, 0.8), Vector3(0, 0.86, 0), _mat_chene_clair(), m)
	for c in [Vector2(-0.6, -0.32), Vector2(0.6, -0.32), Vector2(-0.6, 0.32), Vector2(0.6, 0.32)]:
		_boite(Vector3(0.08, 0.82, 0.08), Vector3(c.x, 0.41, c.y), _mat_chene_clair(), m, false)
	var plastique := _mat_uni_ma(Color(0.62, 0.63, 0.65), 0.4)
	var sombre := _mat_uni_ma(Color(0.16, 0.17, 0.19), 0.5)
	_boite(Vector3(0.62, 0.3, 0.46), Vector3(0, 1.05, 0), plastique, m, false)
	_boite(Vector3(0.5, 0.03, 0.3), Vector3(0, 1.21, -0.02), sombre, m, false)
	_boite(Vector3(0.4, 0.02, 0.22), Vector3(0, 0.98, 0.32), sombre, m, false)
	var blanc := _mat_uni_ma(Color(0.98, 0.98, 0.97), 0.6)
	_boite(Vector3(0.21, 0.05, 0.297), Vector3(0.48, 0.92, 0.1), blanc, m, false)
	_boite(Vector3(0.21, 0.004, 0.297), Vector3(0, 1.0, 0.36), blanc, m, false)
	var ecran := StandardMaterial3D.new()
	ecran.albedo_color = Color(0.7, 0.85, 1.0)
	ecran.emission_enabled = true
	ecran.emission = Color(0.6, 0.8, 1.0)
	ecran.emission_energy_multiplier = 4.0
	var e := _boite(Vector3(0.16, 0.08, 0.01), Vector3(0.18, 1.12, 0.231), ecran, m, false)
	e.rotation.x = -0.4
	_boite(Vector3(0.02, 0.02, 0.01), Vector3(-0.22, 1.12, 0.232), ecran, m, false)
	var froide := OmniLight3D.new()
	froide.light_color = Color(0.78, 0.88, 1.0)
	froide.light_energy = 2.2
	froide.omni_range = 7.0
	froide.position = Vector3(0, 1.5, 0.4)
	m.add_child(froide)


## Les lanternes de la nuit : au porche, sous l'atelier, à la fonderie, devant Saint-Christophe.
## Allumées seulement pendant la nuit du chapitre 6 (peu de lumières, sans ombres : 60 i/s).
func _construire_lumieres_nuit(dossier: Node3D) -> void:
	_lumieres_nuit = Node3D.new()
	_lumieres_nuit.name = "LumieresNuit"
	_lumieres_nuit.visible = false
	dossier.add_child(_lumieres_nuit)
	var flamme := StandardMaterial3D.new()
	flamme.albedo_color = Color(1.0, 0.75, 0.4)
	flamme.emission_enabled = true
	flamme.emission = Color(1.0, 0.6, 0.25)
	flamme.emission_energy_multiplier = 5.0
	var fer := _mat_uni_ma(Color(0.12, 0.11, 0.1), 0.6)
	for l in [[PORCHE + Vector2(-2.8, 1.2), 3.4], [PORCHE + Vector2(2.8, 1.2), 3.4], [ATELIER + Vector2(-4, 2), 3.0],
			[ATELIER + Vector2(6, 2), 3.0], [GUTENBERG + Vector2(0, 1.5), 2.6], [CHRISTOPHE + Vector2(-8, 4), 3.0]]:
		var q: Vector2 = l[0]
		var y := hauteur(q.x, q.y) + float(l[1])
		_boite(Vector3(0.22, 0.3, 0.22), Vector3(q.x, y, q.y), fer, _lumieres_nuit, false)
		_boite(Vector3(0.14, 0.2, 0.14), Vector3(q.x, y, q.y), flamme, _lumieres_nuit, false)
		var o := OmniLight3D.new()
		o.light_color = Color(1.0, 0.68, 0.36)
		o.light_energy = 2.0
		o.omni_range = 9.0
		o.position = Vector3(q.x, y - 0.1, q.y)
		_lumieres_nuit.add_child(o)


## La nuit tombe pendant le chapitre 6 (de la lumière blanche jusqu'à l'aube).
func _mettre_nuit(nuit: bool) -> void:
	if nuit == _nuit:
		return
	_nuit = nuit
	if _lumieres_nuit != null:
		_lumieres_nuit.visible = nuit
	if ambiance_grandiose:
		AmbiancePrehistoire.appliquer(self, "ville_nuit" if nuit else identifiant_zone)


## Les personnages des quêtes secondaires (plus tard).
func _construire_secondaires(_dossier: Node3D) -> void:
	pass


# --- Les bateaux, la sortie ---------------------------------------------------------------------

var _attente := 0.0


func _process(delta: float) -> void:
	super._process(delta)
	for n in _nefs:
		if is_instance_valid(n):
			n.position.z -= delta * 1.2
			if n.position.z < -1200.0:
				n.position.z = 1200.0
	if Engine.is_editor_hint():
		return
	# Le portail de la Vigie ne ramène au QG qu'une fois ouvert.
	if _portail_qg != null and _zone_portail != null and _zone_portail.monitoring != _portail_qg.visible:
		_zone_portail.monitoring = _portail_qg.visible
	_attente -= delta
	if _attente > 0.0:
		return
	_attente = 0.3
	var quete := get_tree().get_first_node_in_group("quete")
	if quete == null or not quete.has_method("etape_atteinte"):
		return
	if not _crypte_ouverte and quete.etape_atteinte("vers_fonderie"):
		_crypte_ouverte = true
		if _grille_crypte != null and is_instance_valid(_grille_crypte):
			_grille_crypte.visible = false
	if not has_meta("nuit_forcee"):
		_mettre_nuit(String(quete.etape_actuelle().get("id", "")) in ETAPES_NUIT)
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return
	var p := Vector2(joueur.global_position.x, joueur.global_position.z)
	if not _route_francfort and quete.etape_atteinte("vers_francfort"):
		_route_francfort = true
		if _mur_fust != null and is_instance_valid(_mur_fust):
			_mur_fust.queue_free()
	if _crypte_ouverte and p.distance_to(DESCENTE_FONDERIE) < 2.5 and quete.donnees.get("zones", {}).has("fonderie"):
		Reseau.set_meta("arrivee_mayence", "ville")
		quete.changer_de_zone("fonderie")
		return
	if _route_francfort and p.distance_to(SORTIE_N) < 4.0 and quete.donnees.get("zones", {}).has("francfort"):
		Reseau.set_meta("arrivee_mayence", "ville")
		quete.changer_de_zone("francfort")
	elif p.distance_to(SORTIE_E) < 4.0 and quete.donnees.get("zones", {}).has("rhin"):
		Reseau.set_meta("arrivee_mayence", "ville")
		quete.changer_de_zone("rhin")
