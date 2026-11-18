@tool
extends "res://scripts/monde/mayence/ile_mayence.gd"
## Île de Mayence, zone 1 : les vignes du Rheingau (niveaux 60-62).
##
## Octobre 1450, le temps des vendanges. Un long coteau exposé plein sud descend jusqu'au
## Rhin : des terrasses de vigne tenues par des murets de schiste, chaque cep sur son
## échalas, chargé de grappes noires. En bas, au bord du fleuve, un village à colombages,
## son église de grès rouge et la grande halle du pressoir à vis. En haut, dans une petite
## vallée boisée de châtaigniers et de hêtres roux, l'abbaye cistercienne d'Eberbach et son
## scriptorium. Au nord-est, à la lisière de la forêt du Taunus, un camp de brigands et la
## faille. Le Rhin, très large, coule au sud avec ses bateaux ; à l'est, au bout de la route
## du fleuve, Mayence. Le portail de la Vigie s'est ouvert dans une petite chapelle de
## vignerons, à l'ouest, au bord de la route.
##
## Tout est construit par le code (voir ile_mayence.gd). Repères : le nord est vers -Z.

const Faille := preload("res://scripts/monde/prehistoire/faille.gd")
const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const ObjetMayence := preload("res://scripts/monde/mayence/objet_mayence.gd")

## Le Rhin : la berge, le niveau de l'eau.
const BERGE_Z := 136.0
const NIVEAU_RHIN := 0.4
## La chapelle du portail, à l'ouest, au bord de la route.
const CHAPELLE := Vector2(-136, 110)
const PORTAIL := Vector2(-126, 104)
const RADIO := Vector2(-121, 101)
## La route du Rhin, d'ouest en est (vers Mayence).
const ROUTE := [Vector2(-170, 124), Vector2(-120, 118), Vector2(-60, 116), Vector2(-10, 112), Vector2(30, 110),
		Vector2(80, 116), Vector2(130, 122), Vector2(170, 126)]
## Le village : la place, l'église, la halle du pressoir, les maisons.
const PLACE := Vector2(26, 98)
const EGLISE := Vector2(54, 84)
const HALLE := Vector2(-4, 88)
const MAISONS := [[Vector2(10, 106), 0.0, Color(0.94, 0.9, 0.8)], [Vector2(20, 84), PI, Color(0.92, 0.78, 0.62)],
		[Vector2(36, 108), 0.05, Color(0.9, 0.86, 0.72)], [Vector2(42, 100), -PI / 2, Color(0.86, 0.66, 0.6)],
		[Vector2(-20, 104), 0.1, Color(0.95, 0.92, 0.84)], [Vector2(70, 102), -0.1, Color(0.9, 0.82, 0.66)],
		[Vector2(-30, 92), PI / 2, Color(0.88, 0.84, 0.76)], [Vector2(84, 92), PI, Color(0.92, 0.8, 0.7)]]
const LIESEL := Vector2(18, 98)
const KEFFER := Vector2(4, 96)
const OTT := Vector2(-4, 93)
## Les vendangeurs Scellés, dans les rangs au-dessus du village.
const SCELLES_VIGNE := [Vector2(-44, 36), Vector2(-16, 22), Vector2(16, 42)]
const SANGLIERS := Vector2(-70, 8)
## Le chemin des vignes, du village jusqu'à l'abbaye.
const CHEMIN := [Vector2(18, 92), Vector2(10, 64), Vector2(-8, 32), Vector2(-28, 2), Vector2(-48, -34),
		Vector2(-64, -70), Vector2(-76, -92)]
## Le vignoble (les rangs suivent l'axe x) et ses terrasses (un muret tous les 20 m).
const VIGNOBLE := Rect2(-154, -72, 308, 134)
const TERRASSE := 20.0
## L'abbaye d'Eberbach : l'église (nef est-ouest), le cloître au sud, le scriptorium.
const ABBAYE := Vector2(-92, -118)
const CLOITRE := Rect2(-104, -110, 22, 20)
const WENDELIN := Vector2(-76, -100)
const MOINES := [Vector2(-98, -104), Vector2(-88, -96), Vector2(-96, -94)]
const MESSAGE_MASQUE := Vector2(-110, -96)
const LOUPS := Vector2(-30, -128)
## Le camp des brigands, la faille, la feuille de l'Éditeur.
const CAMP := Vector2(104, -80)
const CHEF := Vector2(116, -90)
const FEUILLE := Vector2(110, -84)
const FAILLE := Vector2(132, -102)
## La sortie : la route du Rhin vers Mayence, à l'est.
const SORTIE_E := Vector2(164, 125)

var _vis_pressoir: Node3D
var _mur_e: StaticBody3D
var _nefs: Array[Node3D] = []


func _init() -> void:
	identifiant_zone = "rheingau"
	taille_terrain = 340
	graine = 1450
	point_apparition = PORTAIL + Vector2(4, 0)
	nombre_touffes = 30000
	fertilite_sols = Vector3(0.08, 0.35, 1.0)
	neige_qui_tombe = false
	sols = {
		# Rouge : la terre battue des chemins, la route, les galets de la berge.
		"galets": ["brown_mud_02", "dry_river_pebbles", "dry_ground_rocks"],
		# Vert : la terre caillouteuse des vignes (schiste).
		"neige": ["dry_ground_rocks", "brown_mud_rocks_01", "rock_wall_10"],
		# Bleu : les prés, les talus et le sol de la forêt.
		"sol": ["withered_grass", "brown_mud_02", "dry_ground_01"],
		"roche": ["rock_wall_10", "cliff_side", "stacked_stone_wall"],
	}
	reglages_terrain = {"sol_saturation": 1.18, "sol_motif": 6.0, "galets_motif": 4.0, "neige_motif": 4.0,
			"sol_teinte": Color(0.7, 0.8, 0.46), "roche_teinte": Color(0.82, 0.78, 0.74), "roche_saturation": 0.8,
			"neige_eclat": 1.0, "neige_paillettes": 0.0, "roche_motif": 8.0,
			"neige_teinte": Color(0.86, 0.76, 0.66), "neige_max": Vector3(0.66, 0.56, 0.46), "neige_simple": Color(0.5, 0.42, 0.34),
			"givre": 0.0, "neige_translucide": 0.0}
	reglages_herbe = {"couleur_base": Color(0.2, 0.27, 0.1), "couleur_pointe": Color(0.66, 0.66, 0.3),
			"couleur_givre": Color(0.76, 0.62, 0.34), "force_vent": 0.5}
	reglages_couvre_sol = {"cailloux": 3.0, "fleurs": [Color(0.62, 0.36, 0.86), Color(0.96, 0.82, 0.2), Color(0.95, 0.92, 0.85)],
			"densite_fleurs": 2.0, "buissons": 0.4}
	piste = CHEMIN.duplicate()


func _ready() -> void:
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_mayence", "") == "rhin":
		Reseau.remove_meta("arrivee_mayence")
		# Retour du Rhin : on arrive à l'est, sur la route du fleuve.
		point_apparition = SORTIE_E + Vector2(-10, -3)
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	if zone == "rheingau":
		return Vector2.INF
	return SORTIE_E


# --- Relief -----------------------------------------------------------------------------

func _preparer_bruits() -> void:
	super._preparer_bruits()
	_relief.frequency = 0.006


func _distance_ligne(p: Vector2, ligne: Array) -> float:
	var meilleure := INF
	for i in ligne.size() - 1:
		meilleure = minf(meilleure, _distance_segment(p, ligne[i], ligne[i + 1]))
	return meilleure


func distance_route(p: Vector2) -> float:
	return _distance_ligne(p, ROUTE)


## Dans le vignoble (0 à 1), avec un fondu sur les bords.
func dans_vignoble(x: float, z: float) -> float:
	var v := _dans_rect(VIGNOBLE, x, z, 8.0)
	# Pas de vigne au nord-est (le camp, la lisière) ni autour de l'abbaye.
	v *= smoothstep(30.0, 46.0, Vector2(x, z).distance_to(CAMP + Vector2(10, -6)))
	return v


## Le coteau sans les terrasses ni les replats : il monte du Rhin (sud) vers le Taunus (nord).
func _coteau(x: float, z: float) -> float:
	var bruit := _relief.get_noise_2d(x, z)
	var h := 3.0 + (BERGE_Z - z) * 0.16 + bruit * 3.5
	# Une petite vallée (celle de l'abbaye), creusée au nord-ouest.
	var vallee := 1.0 - smoothstep(20.0, 70.0, absf(x - ABBAYE.x + (z - ABBAYE.y) * 0.25))
	h -= vallee * 7.0 * smoothstep(-20.0, -110.0, z)
	# La berge descend sous l'eau.
	h = lerpf(h, -2.5, smoothstep(BERGE_Z - 8.0, BERGE_Z + 8.0, z))
	return h


func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	var p := Vector2(x, z)
	var h := _coteau(x, z)
	var fin := _details.get_noise_2d(x * 3.0, z * 3.0)
	h += fin * 0.08
	# Les terrasses : dans chaque bande de 20 m, la pente est faible, puis on descend d'un
	# coup (le muret) au bas de la bande.
	var vigne := dans_vignoble(x, z)
	if vigne > 0.0:
		var f := fposmod(z, TERRASSE) / TERRASSE
		var marche := (f - 0.5) * TERRASSE * 0.16 * 0.62
		var saut := smoothstep(0.84, 1.0, f) * TERRASSE * 0.16 * 0.62
		h += (-marche + saut) * vigne
	# La route, un peu creusée ; le replat du village et celui de l'abbaye ; la chapelle.
	h = lerpf(h, _coteau(x, z) - 0.15, (1.0 - smoothstep(3.0, 8.0, distance_route(p))) * 0.85)
	h = lerpf(h, 6.2 + _relief.get_noise_2d(x, z) * 0.6, 1.0 - smoothstep(36.0, 60.0, p.distance_to(PLACE + Vector2(10, -4))))
	h = lerpf(h, _coteau(ABBAYE.x, ABBAYE.y + 8.0), 1.0 - smoothstep(26.0, 40.0, p.distance_to(ABBAYE + Vector2(0, 8))))
	h = lerpf(h, _coteau(CHAPELLE.x, CHAPELLE.y), 1.0 - smoothstep(8.0, 14.0, p.distance_to(CHAPELLE + Vector2(6, -3))))
	h = lerpf(h, _coteau(CAMP.x, CAMP.y), 1.0 - smoothstep(10.0, 20.0, p.distance_to(CAMP)))
	var d_chemin := _distance_piste(p)
	h = lerpf(h, h - 0.08, 1.0 - smoothstep(2.0, 4.0, d_chemin))
	return h


## Rouge : terre battue et galets ; vert : terre des vignes ; bleu : prés et forêt.
func _parts_sol(x: float, z: float, h: float) -> Color:
	var p := Vector2(x, z)
	var n := _relief.get_noise_2d(x * 2.0 + 60.0, z * 2.0)
	var terre := 1.0 - smoothstep(2.5, 5.5 + n * 1.5, distance_route(p))
	terre = maxf(terre, 1.0 - smoothstep(1.2, 2.8, _distance_piste(p)))
	terre = maxf(terre, 1.0 - smoothstep(18.0, 26.0, p.distance_to(PLACE + Vector2(-6, -2))))
	terre = maxf(terre, smoothstep(BERGE_Z - 10.0, BERGE_Z - 2.0, z))
	terre = maxf(terre, 1.0 - smoothstep(6.0, 11.0, p.distance_to(CAMP)))
	terre = maxf(terre, _dans_rect(CLOITRE.grow(3.0), x, z, 2.0))
	var vigne := dans_vignoble(x, z) * (1.0 - terre)
	# Une bande d'herbe au pied de chaque muret.
	vigne *= 1.0 - 0.6 * smoothstep(0.78, 0.86, fposmod(z, TERRASSE) / TERRASSE)
	var pre := maxf(0.0, 1.0 - vigne - terre)
	return Color(terre + 0.001, vigne, pre, 1.0)


# --- Construction -------------------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_construire_terrain()
	_construire_rhin()
	_construire_vignoble()
	_construire_village()
	_construire_abbaye()
	_construire_camp()
	_construire_chapelle()
	_construire_vegetation()
	_construire_touffes()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_appliquer_ciel()


## Libre pour un cep (ni chemin, ni personnage, ni muret, ni maison) ?
func _cep_libre(p: Vector2) -> bool:
	if dans_vignoble(p.x, p.y) < 0.6 or _distance_piste(p) < 2.6 or distance_route(p) < 6.0:
		return false
	var f := fposmod(p.y, TERRASSE) / TERRASSE
	if f > 0.8 or f < 0.04:
		return false
	for c: Vector2 in SCELLES_VIGNE:
		if p.distance_to(c) < 3.0:
			return false
	if p.distance_to(SANGLIERS) < 9.0 or p.distance_to(PLACE) < 40.0 or p.distance_to(EGLISE) < 16.0:
		return false
	return true


func _construire_vignoble() -> void:
	var dossier := Node3D.new()
	dossier.name = "Vignoble"
	_contenu.add_child(dossier)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 3
	_vignoble(dossier, VIGNOBLE, _cep_libre, hasard, 2.3, 1.35)
	# Les murets des terrasses, avec des passages (le chemin, et un tous les 50 m environ).
	var murets := Node3D.new()
	murets.name = "Murets"
	dossier.add_child(murets)
	var z := ceilf(VIGNOBLE.position.y / TERRASSE) * TERRASSE
	while z <= VIGNOBLE.end.y:
		var zm := z - TERRASSE * 0.07
		var x := VIGNOBLE.position.x + 4.0
		var debut := x
		while x <= VIGNOBLE.end.x - 4.0:
			var p := Vector2(x, zm)
			var trou := _distance_piste(p) < 3.5 or dans_vignoble(x, zm) < 0.7 or fposmod(x + 170.0 + z * 0.7, 52.0) < 3.5
			if trou:
				if x - debut > 2.0:
					_muret_sec(murets, Vector2(debut, zm), Vector2(x - 1.0, zm), 1.4)
				debut = x + 1.0
			x += 1.0
		if x - debut > 2.0:
			_muret_sec(murets, Vector2(debut, zm), Vector2(x, zm), 1.4)
		z += TERRASSE
	_fusionner(murets)
	# Des cabanes de vigneron (pierre sèche, toit d'ardoise) et des hottes posées au bout des rangs.
	for c: Vector2 in [Vector2(-120, -10), Vector2(70, 30), Vector2(-90, 46), Vector2(120, -30)]:
		var cabane := _chaumiere(dossier, c, Vector3(3.2, 2.2, 3.6), hasard.randf_range(-0.3, 0.3))
		cabane.name = "Cabane%d" % dossier.get_child_count()


func _construire_village() -> void:
	var dossier := Node3D.new()
	dossier.name = "Village"
	_contenu.add_child(dossier)
	var eglise := _eglise_village(dossier, EGLISE, 0.0)
	# L'église du Rhin est en grès rouge, et son clocher a une flèche d'ardoise.
	for mi in eglise.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D)
		if m.material_override == _mat_calcaire():
			m.material_override = _mat_gres_rouge()
		elif m.material_override == _mat_tuiles_plates():
			m.material_override = _mat_ardoise()
	for k in MAISONS.size():
		var m: Array = MAISONS[k]
		_maison_rhenane(dossier, m[0], Vector3(6.0 + (k % 3) * 0.8, 6.6 + (k % 2) * 1.0, 8.0), m[1], m[2])
	_puits(dossier, PLACE + Vector2(2, 2))
	_charrette(dossier, PLACE + Vector2(-8, 8), 0.6, true)
	_auvent(dossier, PLACE + Vector2(10, -6), Vector2(4.0, 3.0), 2.4, Color(0.2, 0.36, 0.6))
	_fusionner(dossier)
	# La halle du pressoir et le grand pressoir à vis (la « Vis » tourne quand Ott presse).
	var halle := Node3D.new()
	halle.name = "Pressoir"
	_contenu.add_child(halle)
	_halle_pressoir(halle, HALLE, Vector2(12.0, 8.0), 0.0)
	var pressoir := _pressoir_a_vis(halle, HALLE + Vector2(0, -0.5), 0.0, 1.0)
	_vis_pressoir = pressoir.get_node("Vis")
	# Les cuves et les tonneaux de la vendange.
	for k in 5:
		var c := HALLE + Vector2(-4.5 + k * 2.2, 2.6)
		var cuve := MeshInstance3D.new()
		cuve.mesh = _cylindre(0.7, 0.6, 1.1, 16)
		cuve.material_override = _mat_chene_clair()
		cuve.position = Vector3(c.x, hauteur(c.x, c.y) + 0.55, c.y)
		halle.add_child(cuve)
		if k % 2 == 0:
			var raisin := MeshInstance3D.new()
			raisin.mesh = _cylindre(0.62, 0.62, 0.05, 16)
			raisin.material_override = _mat_uni_ma(RAISIN_NOIR, 0.4)
			raisin.position = cuve.position + Vector3(0, 0.5, 0)
			halle.add_child(raisin)
	# Les tonneaux, empilés contre le mur du fond.
	for k in 6:
		var t := MeshInstance3D.new()
		t.mesh = _cylindre(0.42, 0.42, 1.0, 12)
		t.material_override = _mat_chene_clair()
		t.rotation.x = PI / 2
		var c := HALLE + Vector2(-5.0 + (k % 3) * 1.0, -3.0)
		t.position = Vector3(c.x, hauteur(c.x, c.y) + 0.45 + (k / 3) * 0.82, c.y)
		halle.add_child(t)
	# Le ponton du village sur le Rhin.
	var ponton := Node3D.new()
	ponton.name = "Ponton"
	_contenu.add_child(ponton)
	var bois := _mat_colombage()
	_boite(Vector3(3.0, 0.25, 16.0), Vector3(30, NIVEAU_RHIN + 0.8, BERGE_Z + 2.0), bois, ponton)
	for k in 5:
		for cote: float in [-1.0, 1.0]:
			var pieu := MeshInstance3D.new()
			pieu.mesh = _cylindre(0.12, 0.14, 3.0, 8)
			pieu.material_override = bois
			pieu.position = Vector3(30 + cote * 1.4, NIVEAU_RHIN - 0.5, BERGE_Z - 5.0 + k * 3.5)
			ponton.add_child(pieu)


func _construire_rhin() -> void:
	# Le Rhin, très large : l'autre rive est à 800 m.
	_eau_du_rhin(Vector3(0, NIVEAU_RHIN, BERGE_Z + 420.0), Vector2(5200, 860))
	var dossier := Node3D.new()
	dossier.name = "Bateaux"
	_contenu.add_child(dossier)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 7
	for k in 4:
		var b := _barque_rhin(dossier, Vector3(-80 + k * 50 + hasard.randf_range(-6, 6), NIVEAU_RHIN + 0.1, BERGE_Z + 8.0 + hasard.randf_range(0, 6)),
				hasard.randf_range(0.8, 2.2))
		b.name = "Barque%d" % k
	# Les nefs du Rhin, chargées de tonneaux, qui descendent ou remontent le fleuve.
	for k in 3:
		var n := _nef_du_rhin(dossier, Vector3(-200 + k * 220, NIVEAU_RHIN + 0.2, BERGE_Z + 70.0 + k * 60.0), PI / 2,
				[Color(0.88, 0.82, 0.7), Color(0.74, 0.3, 0.22), Color(0.86, 0.84, 0.78)][k])
		_nefs.append(n)


func _construire_chapelle() -> void:
	var dossier := Node3D.new()
	dossier.name = "Chapelle"
	_contenu.add_child(dossier)
	# Une petite chapelle de vignerons en grès rouge, ouverte sur la route.
	var c := Node3D.new()
	c.position = Vector3(CHAPELLE.x, hauteur(CHAPELLE.x, CHAPELLE.y) - 0.2, CHAPELLE.y)
	c.rotation.y = -0.3
	dossier.add_child(c)
	var gres := _mat_gres_rouge()
	_boite(Vector3(5.0, 4.2, 0.6), Vector3(0, 2.1, -3.0), gres, c)
	for cote: float in [-1.0, 1.0]:
		_boite(Vector3(0.6, 4.2, 6.0), Vector3(cote * 2.5, 2.1, 0), gres, c)
		_boite(Vector3(0.9, 0.9, 0.9), Vector3(cote * 2.5, 0.45, 3.0), _mat_schiste(), c, false)
	var toit := Node3D.new()
	toit.position = Vector3(0, 4.2, 0)
	c.add_child(toit)
	_toit_pentu(toit, Vector3.ZERO, 5.6, 6.4, _mat_ardoise(), gres, 0.9, 0.16)
	# Le petit autel et la croix.
	_boite(Vector3(1.6, 1.0, 0.7), Vector3(0, 0.5, -2.3), gres, c)
	_boite(Vector3(0.1, 0.8, 0.1), Vector3(0, 1.4, -2.4), _mat_colombage(), c, false)
	_boite(Vector3(0.5, 0.1, 0.1), Vector3(0, 1.6, -2.4), _mat_colombage(), c, false)
	# Une croix de chemin en grès, au bord de la route.
	var croix := Vector2(-110, 116)
	var y := hauteur(croix.x, croix.y)
	_boite(Vector3(0.7, 0.5, 0.7), Vector3(croix.x, y + 0.25, croix.y), gres, dossier)
	_boite(Vector3(0.24, 2.2, 0.24), Vector3(croix.x, y + 1.5, croix.y), gres, dossier, false)
	_boite(Vector3(0.9, 0.22, 0.22), Vector3(croix.x, y + 2.1, croix.y), gres, dossier, false)


func _construire_abbaye() -> void:
	var dossier := Node3D.new()
	dossier.name = "Abbaye"
	_contenu.add_child(dossier)
	var y := hauteur(ABBAYE.x, ABBAYE.y + 8.0)
	var gres := _mat_gres_rouge()
	var crepi := _mat_crepi(Color(0.9, 0.86, 0.78))
	# L'église cistercienne : une longue nef sobre, sans clocher (un petit clocheton de bois sur
	# le toit), un chevet plat à l'est, des fenêtres hautes en plein cintre.
	var e := Node3D.new()
	e.name = "EgliseAbbatiale"
	e.position = Vector3(ABBAYE.x, y - 0.3, ABBAYE.y)
	dossier.add_child(e)
	var nef := Vector3(40.0, 12.0, 12.0)
	_boite(nef, Vector3(0, nef.y * 0.5, 0), crepi, e)
	_boite(Vector3(nef.x + 0.4, 1.0, nef.z + 0.4), Vector3(0, 0.5, 0), gres, e, false)
	_boite(Vector3(nef.x + 0.3, 0.3, nef.z + 0.3), Vector3(0, nef.y - 0.15, 0), gres, e, false)
	# Les bas-côtés et le transept.
	for cote: float in [-1.0, 1.0]:
		_boite(Vector3(nef.x - 10.0, 6.0, 4.0), Vector3(-3.0, 3.0, cote * (nef.z * 0.5 + 2.0)), crepi, e)
		var t := Node3D.new()
		t.position = Vector3(-3.0, 6.0, cote * (nef.z * 0.5 + 2.0))
		e.add_child(t)
		var pan := _boite(Vector3(nef.x - 9.6, 0.2, 4.8), Vector3(0, 0.9, 0), _mat_ardoise(), t, false)
		pan.rotation.x = -cote * 0.42
	_boite(Vector3(8.0, 12.0, nef.z + 16.0), Vector3(nef.x * 0.5 - 6.0, 6.0, 0), crepi, e)
	# Les chaînages de grès aux angles, les contreforts, et les fenêtres.
	var sombre := _mat_uni_ma(Color(0.05, 0.05, 0.06), 1.0)
	for k in 6:
		for cote: float in [-1.0, 1.0]:
			_boite(Vector3(0.8, 7.0, 0.8), Vector3(-17.0 + k * 5.4, 3.5, cote * (nef.z * 0.5 + 4.2)), gres, e)
			_boite(Vector3(1.0, 2.6, 0.1), Vector3(-17.0 + k * 5.4 + 2.7, 9.0, cote * (nef.z * 0.5 + 0.03)), sombre, e, false)
	for k in 3:
		_boite(Vector3(0.1, 4.0, 1.2), Vector3(nef.x * 0.5 - 1.95, 6.0 + (k % 2) * 1.0, -3.0 + k * 3.0), sombre, e, false)
	var toit := Node3D.new()
	toit.position = Vector3(0, nef.y, 0)
	toit.rotation.y = PI / 2
	e.add_child(toit)
	_toit_pentu(toit, Vector3.ZERO, nef.z, nef.x, _mat_ardoise(), crepi, 0.78, 0.18)
	var toit_t := Node3D.new()
	toit_t.position = Vector3(nef.x * 0.5 - 6.0, 12.0, 0)
	e.add_child(toit_t)
	_toit_pentu(toit_t, Vector3.ZERO, 8.0, nef.z + 16.0, _mat_ardoise(), crepi, 0.78, 0.18)
	# Le clocheton de bois sur la croisée.
	var clocheton := Vector3(nef.x * 0.5 - 6.0, 12.0 + 4.4, 0)
	_boite(Vector3(1.4, 2.0, 1.4), clocheton + Vector3(0, 1.0, 0), _mat_colombage(), e, false)
	var fl := MeshInstance3D.new()
	fl.mesh = _cylindre(0.02, 1.1, 3.2, 8)
	fl.material_override = _mat_ardoise()
	fl.position = clocheton + Vector3(0, 3.6, 0)
	e.add_child(fl)
	# Le portail de l'ouest (grès, plein cintre).
	_boite(Vector3(0.16, 4.0, 2.6), Vector3(-nef.x * 0.5 - 0.05, 2.0, 0), _mat_colombage(), e, false)
	_boite(Vector3(0.5, 5.0, 3.6), Vector3(-nef.x * 0.5 - 0.2, 2.5, 0), gres, e, false)
	# Le cloître : quatre galeries d'arcades autour du préau, et les bâtiments des moines.
	var r := CLOITRE
	var yc := hauteur(r.get_center().x, r.get_center().y)
	var cl := Node3D.new()
	cl.name = "Cloitre"
	dossier.add_child(cl)
	for face in 4:
		var horizontal := face < 2
		var longueur := r.size.x if horizontal else r.size.y
		var z0 := r.position.y if face == 0 else r.end.y
		var x0 := r.position.x if face == 2 else r.end.x
		# Le toit de la galerie (appentis d'ardoise) sur le mur des bâtiments.
		var c := Vector3(r.get_center().x, yc, z0) if horizontal else Vector3(x0, yc, r.get_center().y)
		var dehors := Vector3(0, 0, -1 if face == 0 else 1) if horizontal else Vector3(-1 if face == 2 else 1, 0, 0)
		var appentis := _boite(Vector3(longueur + 3.0, 0.18, 3.4) if horizontal else Vector3(3.4, 0.18, longueur + 3.0),
				c + dehors * 1.6 + Vector3(0, 3.3, 0), _mat_ardoise(), cl, false)
		if horizontal:
			appentis.rotation.x = 0.3 * (1.0 if face == 0 else -1.0)
		else:
			appentis.rotation.z = 0.3 * (1.0 if face == 3 else -1.0) * -1.0
		# Les colonnettes de grès et le muret bas des arcades.
		var nb := int(longueur / 1.6)
		for k in nb + 1:
			var t := -longueur * 0.5 + k * longueur / nb
			var pos := c + (Vector3(t, 0, 0) if horizontal else Vector3(0, 0, t))
			_boite(Vector3(0.26, 2.6, 0.26), pos + Vector3(0, 1.3, 0), gres, cl, false)
		_boite(Vector3(longueur, 0.7, 0.4) if horizontal else Vector3(0.4, 0.7, longueur), c + Vector3(0, 0.35, 0), gres, cl, face != 0)
		_boite(Vector3(longueur + 0.4, 0.4, 0.5) if horizontal else Vector3(0.5, 0.4, longueur + 0.4), c + Vector3(0, 2.75, 0), gres, cl, false)
	# Le bâtiment des moines (le dortoir au-dessus, le scriptorium en bas), à l'est du cloître.
	var bat := _maison_rhenane(dossier, Vector2(r.end.x + 6.0, r.get_center().y), Vector3(9.0, 8.0, 16.0), -PI / 2, Color(0.9, 0.86, 0.78))
	bat.name = "Scriptorium"
	# Le jardin des simples dans le préau, et le puits.
	_puits(dossier, r.get_center() + Vector2(4, 3))
	# Le mur d'enceinte de l'abbaye (bas, en schiste), avec la porterie au sud.
	for seg in [[Vector2(-130, -140), Vector2(-50, -140)], [Vector2(-130, -140), Vector2(-130, -84)],
			[Vector2(-50, -140), Vector2(-50, -84)], [Vector2(-130, -84), Vector2(-82, -84)], [Vector2(-70, -84), Vector2(-50, -84)]]:
		_muret_sec(dossier, seg[0], seg[1], 1.8)
	_fusionner(cl)


func _construire_camp() -> void:
	var dossier := Node3D.new()
	dossier.name = "CampBrigands"
	_contenu.add_child(dossier)
	_tente(dossier, CAMP + Vector2(-8, -2), 0.3, Color(0.38, 0.3, 0.24))
	_tente(dossier, CAMP + Vector2(6, -8), -0.6, Color(0.3, 0.3, 0.26))
	_charrette(dossier, CAMP + Vector2(-10, 8), 1.2, true)
	# Des tonneaux de vin volés et un feu.
	for k in 4:
		var t := MeshInstance3D.new()
		t.mesh = _cylindre(0.42, 0.42, 1.0, 12)
		t.material_override = _mat_chene_clair()
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


## Libre pour planter un arbre ?
func _libre(p: Vector2, marge := 6.0) -> bool:
	if distance_route(p) < 7.0 or _distance_piste(p) < 4.0 or dans_vignoble(p.x, p.y) > 0.05:
		return false
	if p.distance_to(PLACE) < 50.0 or p.y > BERGE_Z - 6.0:
		return false
	if _dans_rect(Rect2(-134, -144, 88, 64), p.x, p.y, 0.1) > 0.5:
		return false
	for c: Vector2 in [PORTAIL, CHAPELLE, CAMP, FAILLE, CHEF, EGLISE, HALLE, LOUPS]:
		if p.distance_to(c) < marge + 8.0:
			return false
	return true


func _construire_vegetation() -> void:
	var arbres := Node3D.new()
	arbres.name = "Arbres"
	_contenu.add_child(arbres)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 60
	# La forêt du Taunus au nord : châtaigniers, hêtres roux, chênes ; elle descend un peu
	# dans les vallons. Quelques noyers et un grand tilleul près du village.
	var plantes := 0
	var essais := 0
	while plantes < 230 and essais < 8000:
		essais += 1
		var p := Vector2(hasard.randf_range(-165.0, 165.0), hasard.randf_range(-165.0, -60.0))
		if not _libre(p, 2.0):
			continue
		var essences := ["chataignier", "hetre_automne", "chene", "chataignier", "hetre_automne"]
		_arbre_realiste(arbres, p, essences[hasard.randi() % essences.size()], hasard, hasard.randf_range(0.8, 1.2))
		plantes += 1
	# Des noyers isolés entre les vignes et le village, et le long de la route.
	plantes = 0
	essais = 0
	while plantes < 22 and essais < 3000:
		essais += 1
		var p := Vector2(hasard.randf_range(-160.0, 160.0), hasard.randf_range(60.0, BERGE_Z - 10.0))
		if not _libre(p, 4.0):
			continue
		_arbre_realiste(arbres, p, "noyer", hasard, hasard.randf_range(0.85, 1.2))
		plantes += 1
	# Les saules de la berge.
	for k in 14:
		var p := Vector2(-160 + k * 24 + hasard.randf_range(-6, 6), BERGE_Z - 3.0 + hasard.randf_range(-2, 1))
		if absf(p.x - 30.0) < 8.0 or distance_route(p) < 5.0:
			continue
		_arbre_realiste(arbres, p, "saule", hasard, hasard.randf_range(0.8, 1.1))
	var haies := Node3D.new()
	haies.name = "Haies"
	_contenu.add_child(haies)
	_haie(haies, Vector2(-150, 70), Vector2(-60, 74), hasard)
	_haie(haies, Vector2(90, 70), Vector2(160, 66), hasard)


# --- Paysage lointain ----------------------------------------------------------------------

func _construire_lointain() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 70
	_plan_lointain_autour(-3.0, Color(0.1, 0.1, 0.8))
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.8
	# Les collines du Taunus au nord (boisées), et l'autre rive du Rhin au sud (des coteaux bas).
	for m in [[Vector3(0, -10, -900), Vector3(3200, 160, 600)], [Vector3(-1400, -10, -500), Vector3(1400, 120, 500)],
			[Vector3(1500, -10, -600), Vector3(1500, 110, 500)], [Vector3(0, -12, 1250), Vector3(4200, 45, 500)]]:
		bruit.seed = graine + hasard.randi()
		var colline := MeshInstance3D.new()
		colline.mesh = _maillage_bosse(bruit, m[1], 1.4, 0.3, 24, Color(0.2, 0.0, 0.6))
		colline.material_override = _mat_lointain()
		colline.position = m[0]
		colline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(colline)
	# Mayence au loin, à l'est, sur l'autre rive : les remparts, les toits, et les tours rouges
	# de la cathédrale Saint-Martin.
	var ville := Node3D.new()
	ville.name = "MayenceLointaine"
	_contenu.add_child(ville)
	var c := Vector3(2300, 0, 900)
	var gres := _mat_uni_ma(GRES_ROUGE.darkened(0.1), 0.9)
	for k in 18:
		_boite(Vector3(hasard.randf_range(20, 46), hasard.randf_range(10, 18), hasard.randf_range(20, 40)),
				c + Vector3(-300 + k * 34, 6, hasard.randf_range(-60, 60)), _mat_uni_ma(Color(0.5, 0.46, 0.44), 0.9), ville, false)
	for t in [[Vector3(-30, 0, 0), 80.0], [Vector3(30, 0, 0), 64.0], [Vector3(0, 0, 0), 92.0]]:
		_boite(Vector3(16, t[1], 16), c + t[0] + Vector3(0, t[1] * 0.5, 0), gres, ville, false)
		var f := MeshInstance3D.new()
		f.mesh = _cylindre(0.5, 10.0, 26.0, 8)
		f.material_override = _mat_uni_ma(ARDOISE, 0.6)
		f.position = c + t[0] + Vector3(0, t[1] + 13.0, 0)
		ville.add_child(f)
	_boite(Vector3(30, 26, 120), c + Vector3(0, 13, 60), gres, ville, false)
	# Des villages et leurs clochers au loin, sur les deux rives.
	for p in [Vector3(-1500, 0, -60), Vector3(-900, 0, 980), Vector3(900, 0, 1100), Vector3(1300, 0, -120)]:
		_boite(Vector3(5, 16, 5), p + Vector3(0, 8, 0), gres, ville, false)
		var f := MeshInstance3D.new()
		f.mesh = _cylindre(0.1, 3.6, 9.0, 4)
		f.material_override = _mat_uni_ma(ARDOISE, 0.7)
		f.position = p + Vector3(0, 20.5, 0)
		ville.add_child(f)


# --- Limites de la zone -----------------------------------------------------------------------

func _construire_limites() -> void:
	var limites := Node3D.new()
	limites.name = "Limites"
	_contenu.add_child(limites)
	var demi := taille_terrain * 0.5 - 4.0
	_mur_invisible(limites, Vector3(2, 140, taille_terrain), Vector3(-demi, 40, 0))
	_mur_invisible(limites, Vector3(2, 140, taille_terrain), Vector3(demi, 40, 0))
	_mur_invisible(limites, Vector3(taille_terrain, 140, 2), Vector3(0, 40, -demi))
	# Le Rhin : on ne se baigne pas (au bout du ponton non plus).
	_mur_invisible(limites, Vector3(taille_terrain, 30, 2), Vector3(0, 8, BERGE_Z + 10.0))
	# La route de Mayence : fermée tant que l'histoire n'y mène pas.
	_mur_e = _mur_invisible(limites, Vector3(2, 14, 30), Vector3(SORTIE_E.x - 4.0, hauteur(SORTIE_E.x, SORTIE_E.y) + 6.0, SORTIE_E.y - 6.0))


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


## Un Scellé et l'objet invisible posé sur lui pour le délivrer (le petit jeu de la composition).
func _scelle(dossier: Node3D, id_pnj: String, id_objet: String, groupe: String, p: Vector2, angle: float) -> void:
	_pnj(dossier, id_pnj, p, angle)
	var o := _objet(dossier, id_objet, p, "", "[F] Composer la phrase qui libère", groupe, 2.2)
	o.set_meta("pnj_lie", id_pnj)


func _construire_quete() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quete"
	_contenu.add_child(dossier)
	_dossier_quete = dossier
	_construire_portail(dossier, PORTAIL, PI)
	_objet(dossier, "radio_vera_mayence", RADIO, "radio_vigie", "[F] Prendre la radio qui grésille")
	# Le village : Liesel, Heinrich Keffer (le compagnon de Gutenberg), maître Ott au pressoir.
	_pnj(dossier, "liesel", LIESEL, PI * 0.8)
	_pnj(dossier, "heinrich_keffer", KEFFER, PI * 0.2)
	_scelle(dossier, "maitre_ott", "liberer_ott", "scelle_ott", OTT, PI)
	_objet(dossier, "barre_pressoir", HALLE + Vector2(1.9, 0.6), "", "[F] Pousser la barre du pressoir")
	_objet(dossier, "casse_keffer", KEFFER + Vector2(1.6, -1.2), "casse_plomb", "[F] Regarder la casse de lettres")
	# Les vendangeurs Scellés dans les vignes.
	for k in SCELLES_VIGNE.size():
		_scelle(dossier, "scelle_vendangeur_%d" % (k + 1), "liberer_vendangeur_%d" % k, "scelles_vigne", SCELLES_VIGNE[k], PI * (0.3 + k * 0.6))
	# L'abbaye : frère Wendelin, les moines Scellés du cloître, le message de Masque.
	_pnj(dossier, "frere_wendelin", WENDELIN, -PI * 0.5)
	for k in MOINES.size():
		_scelle(dossier, "scelle_moine_%d" % (k + 1), "liberer_moine_%d" % k, "scelles_cloitre", MOINES[k], PI * (0.1 + k * 0.7))
	var craie := _objet(dossier, "craie_masque_mayence", MESSAGE_MASQUE, "craie", "[F] Lire le message à la craie")
	craie.set_meta("texte_craie", "IL PARLE À GUTENBERG.\nDEPUIS DES SEMAINES.\n— M.")
	craie.rotation.y = PI * 0.5
	# Le camp des brigands : la feuille de l'Éditeur, la faille.
	_objet(dossier, "feuille_editeur", FEUILLE, "feuille_imprimee", "[F] Ramasser la feuille imprimée")
	var faille := Faille.new()
	faille.name = "Faille"
	faille.identifiant = "faille_rheingau"
	faille.position = Vector3(FAILLE.x, hauteur(FAILLE.x, FAILLE.y), FAILLE.y)
	dossier.add_child(faille)
	_construire_secondaires(dossier)
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.PORTAIL, "Portail de la Vigie (la chapelle des vignerons)", PORTAIL)
	repere.call(MarqueurCarte.Type.DANGER, "Faille", FAILLE)
	repere.call(MarqueurCarte.Type.LIEU, "Le village et le pressoir", PLACE)
	repere.call(MarqueurCarte.Type.LIEU, "Abbaye d'Eberbach", ABBAYE)
	repere.call(MarqueurCarte.Type.LIEU, "Camp des brigands", CAMP)
	repere.call(MarqueurCarte.Type.LIEU, "Route du Rhin, vers Mayence", SORTIE_E)


## Les personnages des quêtes secondaires (plus tard).
func _construire_secondaires(_dossier: Node3D) -> void:
	pass


# --- Le pressoir tourne, les bateaux passent, la route s'ouvre -------------------------------------

var _attente := 0.0
var _route_ouverte := false
var _presse := false


func _process(delta: float) -> void:
	super._process(delta)
	for n in _nefs:
		if is_instance_valid(n):
			n.position.x += delta * 1.2
			if n.position.x > 1200.0:
				n.position.x = -1200.0
	if _presse and _vis_pressoir != null and is_instance_valid(_vis_pressoir):
		_vis_pressoir.rotation.y += delta * 0.5
	if Engine.is_editor_hint():
		return
	_attente -= delta
	if _attente > 0.0:
		return
	_attente = 0.3
	var quete := get_tree().get_first_node_in_group("quete")
	if quete == null or not quete.has_method("etape_atteinte"):
		return
	if not _presse and quete.etape_atteinte("ott_presse"):
		_presse = true
	if not _route_ouverte:
		if not quete.etape_atteinte("vers_rhin"):
			return
		_route_ouverte = true
		if _mur_e != null and is_instance_valid(_mur_e):
			_mur_e.queue_free()
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return
	var p := Vector2(joueur.global_position.x, joueur.global_position.z)
	if p.distance_to(SORTIE_E) < 6.0 and quete.donnees.get("zones", {}).has("rhin"):
		quete.changer_de_zone("rhin")
