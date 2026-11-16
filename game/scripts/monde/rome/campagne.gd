@tool
extends "res://scripts/monde/rome/ile_rome.gd"
## Île de Rome, zone 2 : la Campagne et les aqueducs (niveaux 32-35).
##
## Au nord de la voie Appienne, la campagne romaine s'ouvre, large et lumineuse. Les
## arches de l'aqueduc de Claude arrivent du sud-est (des monts Albains et de la vallée
## de l'Anio) et filent vers la ville, à vingt mètres de haut. On peut monter dessus par
## l'échafaudage des fontainiers et marcher sur le canal. Au nord, la Porta Maggiore :
## une double arche de travertin, où l'aqueduc enjambe les routes à l'entrée de Rome. À
## l'ouest, une villa et ses vignes ; à l'est, une carrière de tuf.
##
## Tout est construit par le code (voir ile_rome.gd). Repères : le nord est vers -Z.

const Faille := preload("res://scripts/monde/prehistoire/faille.gd")
const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const ObjetRome := preload("res://scripts/monde/rome/objet_rome.gd")

## La route du sud (qui vient de la voie Appienne) jusqu'à la Porta Maggiore, au nord.
const ROUTE := [Vector2(0, 162), Vector2(-4, 100), Vector2(-6, 40), Vector2(-2, -40), Vector2(2, -100), Vector2(3, -162)]
const ENTREE := Vector2(0, 148)
## L'aqueduc de Claude : il arrive du sud-est, tourne et passe au-dessus de la porte.
const AQUEDUC := [Vector2(178, 112), Vector2(80, 40), Vector2(40, -80), Vector2(10, -128), Vector2(-60, -128), Vector2(-178, -128)]
## Le dessus du canal (on y marche).
## Toute la zone est surélevée de SOCLE mètres, pour que le fond de la carrière reste
## au-dessus de zéro.
const SOCLE := 8.0
const Y_CANAL := 30.0
## La Porta Maggiore : deux arches pour deux routes, l'aqueduc passe au-dessus.
const PORTE := Vector2(-2, -128)
const PORTE_RECT := Rect2(-13, -132, 22, 8)
## L'échafaudage des fontainiers (on monte au sud-est), et celui de l'ouest (on descend).
const ECHAFAUDAGE_EST := 0.15
const ECHAFAUDAGE_OUEST := Vector2(-44, -128)
## La cabane des fontainiers (la « statio aquarum ») et Sextus.
const STATIO := Vector2(96, 30)
const SEXTUS := Vector2(88, 20)
const AQUARII := [Vector2(91, 14), Vector2(94, 22)]
## Où l'on retrouve l'agent Livia, au pied des arches.
const LIVIA := Vector2(62, 52)
## Les trois failles qui boivent l'eau du canal.
const FAILLES := [Vector2(58, -26), Vector2(28, -99.2), Vector2(-28, -128)]
## Sextus attend à la porte quand l'eau revient.
const SEXTUS_PORTE := Vector2(10, -118)
## La carrière de tuf à l'est (l'ours y a sa tanière) et la villa à l'ouest.
const CARRIERE := Rect2(100, -74, 40, 36)
const OURS := Vector2(122, -58)
const PROFONDEUR_CARRIERE := 9.0
const VILLA := Rect2(-96, 6, 34, 26)
## Le chemin de la route à la cabane des fontainiers.
const CHEMIN := [Vector2(-5, 60), Vector2(30, 56), Vector2(60, 46), Vector2(90, 28)]
const SORTIE_SUD := Vector2(0, 156)
const SORTIE_NORD := Vector2(3, -150)

var _mur_nord: StaticBody3D
var _attente_sortie := 0.0


func _init() -> void:
	identifiant_zone = "campagne"
	taille_terrain = 320
	graine = 81
	point_apparition = ENTREE + Vector2(0, -4)
	nombre_touffes = 70000
	neige_qui_tombe = false
	sols = {
		"galets": ["dry_ground_01", "mud_cracked_dry_03", "dry_ground_rocks"],
		"neige": ["brown_mud_02", "dry_ground_rocks", "dry_ground_01"],
		"sol": ["dry_ground_01", "brown_mud_02", "mud_cracked_dry_03"],
		"roche": ["rock_boulder_dry", "cliff_side", "rock_wall_10"],
	}
	reglages_terrain = {"sol_saturation": 0.85, "sol_motif": 4.0, "galets_motif": 3.0, "neige_motif": 5.0,
			"sol_teinte": Color(1.0, 0.95, 0.86), "roche_teinte": Color(0.98, 0.92, 0.8), "roche_saturation": 0.7,
			"neige_eclat": 1.0, "neige_paillettes": 0.0, "roche_motif": 8.0,
			"neige_teinte": Color(0.95, 0.88, 0.7), "neige_max": Vector3(0.5, 0.44, 0.3), "neige_simple": Color(0.5, 0.45, 0.3),
			"givre": 0.0, "neige_translucide": 0.0}
	reglages_herbe = {"couleur_base": Color(0.24, 0.26, 0.1), "couleur_pointe": Color(0.7, 0.64, 0.36),
			"couleur_givre": Color(0.64, 0.6, 0.36), "force_vent": 0.3}
	piste = CHEMIN.duplicate()


func _ready() -> void:
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_rome", "") != "":
		var venu := String(Reseau.get_meta("arrivee_rome"))
		Reseau.remove_meta("arrivee_rome")
		# Retour de Rome : on arrive au nord, devant la porte.
		if venu == "rome":
			point_apparition = PORTE + Vector2(5, 12)
		else:
			point_apparition = ENTREE + Vector2(0, -4)
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	if zone == "campagne":
		return Vector2.INF
	return SORTIE_NORD if zone == "rome" else SORTIE_SUD + Vector2(0, -4)


## Un point de l'aqueduc : « t » va de 0 à 1 sur le tronçon « i ».
func point_aqueduc(i: int, t: float) -> Vector2:
	return (AQUEDUC[i] as Vector2).lerp(AQUEDUC[i + 1], t)


func distance_aqueduc(p: Vector2) -> float:
	var meilleure := INF
	for i in AQUEDUC.size() - 1:
		meilleure = minf(meilleure, _distance_segment(p, AQUEDUC[i], AQUEDUC[i + 1]))
	return meilleure


func distance_route(p: Vector2) -> float:
	var meilleure := INF
	for i in ROUTE.size() - 1:
		meilleure = minf(meilleure, _distance_segment(p, ROUTE[i], ROUTE[i + 1]))
	return meilleure


## Le pied de l'échafaudage du sud-est : le point de l'aqueduc, sa direction et le côté.
func echafaudage_est() -> Array:
	var a: Vector2 = AQUEDUC[1]
	var b: Vector2 = AQUEDUC[2]
	var t := (b - a).normalized()
	var n := Vector2(-t.y, t.x)
	if n.x < 0.0:
		n = -n
	return [a.lerp(b, ECHAFAUDAGE_EST), t, n]


# --- Relief -----------------------------------------------------------------------------

func _preparer_bruits() -> void:
	super._preparer_bruits()
	_relief.frequency = 0.007


func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	var bruit := _relief.get_noise_2d(x, z)
	var fin := _details.get_noise_2d(x * 3.0, z * 3.0)
	var p := Vector2(x, z)
	# De longues collines douces, qui montent vers les monts Albains au sud-est.
	var h := 3.0 + bruit * 3.2 + fin * 0.12
	h += smoothstep(40.0, 160.0, x) * smoothstep(-40.0, 160.0, z) * 5.0
	h += smoothstep(-80.0, -160.0, x) * (2.0 + bruit * 2.0)
	# La route, sur un remblai régulier.
	var h_route := 3.4 + z * 0.002
	h = lerpf(h, h_route, 1.0 - smoothstep(5.0, 15.0, distance_route(p)))
	# Le pied de la porte, plat.
	h = lerpf(h, h_route, 1.0 - smoothstep(12.0, 22.0, p.distance_to(PORTE)))
	# Le pied de l'échafaudage et la cabane des fontainiers : un terre-plein.
	var e := echafaudage_est()
	var pied: Vector2 = e[0] + e[2] * 3.8
	h = lerpf(h, 4.2, 1.0 - smoothstep(10.0, 18.0, p.distance_to(pied)))
	h = lerpf(h, 4.2, 1.0 - smoothstep(7.0, 13.0, p.distance_to(STATIO)))
	h = lerpf(h, h_route, 1.0 - smoothstep(10.0, 18.0, p.distance_to(ECHAFAUDAGE_OUEST + Vector2(0, 3.8))))
	# La villa sur son terre-plein.
	h = lerpf(h, 4.0 + bruit * 0.3, _dans_rect(VILLA.grow(5.0), x, z, 6.0))
	# La carrière : un grand trou à fond plat, aux parois taillées à pic. On y descend par
	# une rampe de charroi, à l'ouest.
	var fosse := PROFONDEUR_CARRIERE * _dans_rect(CARRIERE, x, z, 2.5)
	var cz := CARRIERE.get_center().y
	var couloir := 1.0 - smoothstep(3.0, 5.0, absf(z - cz))
	var depart_rampe := CARRIERE.position.x - 18.0
	if couloir > 0.0 and x > depart_rampe - 2.0 and x < CARRIERE.position.x + 6.0:
		var t := clampf((x - depart_rampe) / 24.0, 0.0, 1.0)
		fosse = lerpf(fosse, PROFONDEUR_CARRIERE * t, couloir)
	h -= fosse
	# Le chemin de la cabane.
	h = lerpf(h, minf(h, 4.4), (1.0 - smoothstep(2.0, 5.0, _distance_piste(p))) * 0.5)
	return h + SOCLE


func _parts_sol(x: float, z: float, h: float) -> Color:
	var p := Vector2(x, z)
	var n := _relief.get_noise_2d(x * 2.0 + 60.0, z * 2.0)
	var bord := 1.0 - smoothstep(3.5, 7.5 + n * 2.0, distance_route(p))
	bord = maxf(bord, 1.0 - smoothstep(1.2, 3.0, _distance_piste(p)))
	var carriere := _dans_rect(CARRIERE.grow(2.0), x, z, 4.0)
	var tasse := maxf(_dans_rect(VILLA.grow(3.0), x, z, 3.0), 1.0 - smoothstep(6.0, 10.0, p.distance_to(STATIO)))
	tasse = maxf(tasse, 1.0 - smoothstep(3.0, 5.0, distance_aqueduc(p)))
	# Le fond de la carrière : de la terre tassée, mêlée de poussière de tuf.
	tasse = maxf(tasse, carriere)
	var pres := (1.0 - bord) * (1.0 - tasse)
	return Color(bord * (1.0 - tasse), pres, tasse, 1.0)


# --- Construction -------------------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_construire_terrain()
	_construire_route()
	_construire_aqueduc()
	_construire_porte()
	_construire_statio()
	_construire_villa()
	_construire_carriere()
	_construire_vegetation()
	_construire_rochers()
	_construire_touffes()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_appliquer_ciel()


func _construire_route() -> void:
	var route := Node3D.new()
	route.name = "Route"
	_contenu.add_child(route)
	_voie(route, ROUTE, 4.6)
	_milliaire(route, Vector2(-8.0, 70), 0.0)
	_milliaire(route, Vector2(-5.5, -60), 0.0)
	# Quelques tombeaux le long de la route, comme sur la voie Appienne.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 10
	var tombeaux := Node3D.new()
	tombeaux.name = "Tombeaux"
	route.add_child(tombeaux)
	var z := 140.0
	while z > -100.0:
		var cote := -1.0 if hasard.randf() < 0.5 else 1.0
		var p := Vector2(-4.0 + cote * hasard.randf_range(10.0, 15.0), z)
		if p.distance_to(LIVIA) > 20.0 and _distance_piste(p) > 7.0 and _dans_rect(VILLA.grow(12.0), p.x, p.y, 0.1) < 0.5:
			if hasard.randf() < 0.5:
				_tombeau_edicule(tombeaux, p, -PI / 2 * cote, hasard.randf_range(0.8, 1.0))
			else:
				_tombeau_autel(tombeaux, p, -PI / 2 * cote)
		z -= hasard.randf_range(22.0, 34.0)


# --- L'aqueduc de Claude ---------------------------------------------------------------------

func _construire_aqueduc() -> void:
	var dossier := Node3D.new()
	dossier.name = "AqueducClaudia"
	_contenu.add_child(dossier)
	_aqueduc_praticable(dossier, AQUEDUC, Y_CANAL, [PORTE_RECT])
	# L'échafaudage des fontainiers (pour monter) et celui de l'ouest (pour redescendre).
	var e := echafaudage_est()
	_echafaudage(dossier, e[0], e[1], e[2], Y_CANAL, "EchafaudageEst")
	_echafaudage(dossier, ECHAFAUDAGE_OUEST, Vector2(1, 0), Vector2(0, 1), Y_CANAL, "EchafaudageOuest")
	# Les regards : des trappes de pierre sur le canal, pour descendre le nettoyer.
	var regards := Node3D.new()
	regards.name = "Regards"
	dossier.add_child(regards)
	var pierre := _mat_tuf()
	for i in AQUEDUC.size() - 1:
		var d: Vector2 = (AQUEDUC[i + 1] as Vector2) - (AQUEDUC[i] as Vector2)
		for t: float in [0.2, 0.45, 0.7, 0.9]:
			var p := point_aqueduc(i, t)
			var loin := PORTE_RECT.grow(2.0).has_point(p) == false
			for f: Vector2 in FAILLES:
				loin = loin and p.distance_to(f) > 6.0
			if loin and absf(p.x) < 150.0 and absf(p.y) < 150.0:
				var trappe := _boite(Vector3(1.0, 0.1, 1.2), Vector3(p.x, Y_CANAL + 0.05, p.y), pierre, regards, false)
				trappe.rotation.y = atan2(d.x, d.y)
	_fusionner(regards)


## La Porta Maggiore : un massif de travertin percé de deux grandes arches pour les deux
## routes (la Labicane et la Prénestine). L'aqueduc passe au-dessus, dans l'attique.
func _construire_porte() -> void:
	var porte := Node3D.new()
	porte.name = "PortaMaggiore"
	_contenu.add_child(porte)
	var travertin := _mat_travertin()
	var cintre := _mat_deux_faces(travertin)
	var y0 := hauteur(PORTE.x, PORTE.y) - 0.5
	var profondeur := 7.0
	var y_attique := Y_CANAL - 2.0
	var naissance := y0 + 10.5
	var portee := 6.0
	# Les trois piles (ouest, milieu, est) et les deux arches.
	var piles := [[-11.5, 3.0], [-2.0, 4.0], [7.5, 3.0]]
	for pile in piles:
		var x: float = PORTE.x + pile[0]
		var l: float = pile[1]
		_boite(Vector3(l, naissance - y0, profondeur), Vector3(x, (y0 + naissance) * 0.5, PORTE.y), travertin, porte)
		# Les petites colonnes engagées et le fronton qui décorent chaque pile.
		for cote: float in [-1.0, 1.0]:
			var colonne := MeshInstance3D.new()
			colonne.mesh = _cylindre(0.35, 0.4, 7.0, 12)
			colonne.material_override = travertin
			colonne.position = Vector3(x + cote * (l * 0.5 - 0.5), y0 + 3.8, PORTE.y + profondeur * 0.5 + 0.3)
			porte.add_child(colonne)
	# Au-dessus des piles, entre les arches : le plein de la maçonnerie, jusqu'à l'attique.
	for pile in piles:
		_boite(Vector3(float(pile[1]) - 0.2, y_attique - naissance, profondeur), Vector3(PORTE.x + float(pile[0]), (naissance + y_attique) * 0.5, PORTE.y), travertin, porte, false)
	for x_arche: float in [-7.0, 3.0]:
		var arche := MeshInstance3D.new()
		arche.mesh = _maillage_arche(portee + 0.5, profondeur, y_attique - naissance)
		arche.material_override = cintre
		arche.position = Vector3(PORTE.x + x_arche, naissance, PORTE.y)
		porte.add_child(arche)
	# L'attique : trois bandes de pierre, une par canal (Claudia en bas, Anio Novus au-dessus),
	# avec les grandes inscriptions de Claude, de Vespasien et de Titus.
	_boite(Vector3(23.0, 1.2, profondeur + 0.4), Vector3(PORTE.x - 2.0, y_attique - 0.6, PORTE.y), travertin, porte, false)
	_boite(Vector3(23.0, 2.6, 2.0), Vector3(PORTE.x - 2.0, Y_CANAL + 1.3, PORTE.y - 2.7), travertin, porte)
	var plaque := Label3D.new()
	plaque.text = "TI · CLAVDIVS · DRVSI · F · CAISAR · AVGVSTVS\nIMP · T · CAESAR · DIVI · F · VESPASIANVS · AVGVSTVS"
	plaque.font_size = 64
	plaque.pixel_size = 0.006
	plaque.modulate = Color(0.32, 0.28, 0.22)
	plaque.outline_size = 0
	plaque.position = Vector3(PORTE.x - 2.0, y_attique - 0.6, PORTE.y + profondeur * 0.5 + 0.25)
	porte.add_child(plaque)
	# Le dessus de l'attique (Anio Novus) n'est pas praticable : on marche sur le canal
	# du bas, qui passe devant, côté campagne.
	_fusionner(porte)


## La cabane des fontainiers : un petit bâtiment de brique, des outils, des tuyaux de plomb.
func _construire_statio() -> void:
	var dossier := Node3D.new()
	dossier.name = "StatioAquarum"
	_contenu.add_child(dossier)
	var cabane := _batiment_romain(dossier, STATIO, Vector3(8, 4.0, 6), 0.3, Color(0.82, 0.66, 0.46))
	cabane.name = "Cabane"
	var y := hauteur(STATIO.x, STATIO.y)
	# Des tuyaux de plomb (les « fistulae ») empilés, des seaux, une pioche.
	var plomb := StandardMaterial3D.new()
	plomb.albedo_color = Color(0.42, 0.43, 0.46)
	plomb.roughness = 0.6
	plomb.metallic = 0.5
	for k in 5:
		var tuyau := MeshInstance3D.new()
		tuyau.mesh = _cylindre(0.12, 0.12, 3.0, 10)
		tuyau.material_override = plomb
		tuyau.rotation.z = PI / 2
		tuyau.position = Vector3(STATIO.x - 6.0, y + 0.14 + (k / 3) * 0.24, STATIO.y + 2.0 + (k % 3) * 0.26)
		dossier.add_child(tuyau)
	for k in 3:
		_amphore(dossier, Vector3(STATIO.x - 4.5 + k * 0.7, y, STATIO.y - 4.0), 0.8, k)
	_boite(Vector3(2.4, 0.8, 1.0), Vector3(STATIO.x - 3.0, y + 0.4, STATIO.y - 5.5), _mat_bois(), dossier)
	_auvent(dossier, STATIO + Vector2(-5.0, -1.0), Vector2(3.6, 4.0), 2.6, Color(0.68, 0.52, 0.34))


## La villa de campagne : la maison du maître autour d'une cour, le pressoir, les vignes.
func _construire_villa() -> void:
	var villa := Node3D.new()
	villa.name = "Villa"
	_contenu.add_child(villa)
	var r := VILLA
	var c := r.get_center()
	var maison := _batiment_romain(villa, Vector2(c.x, r.position.y + 5.0), Vector3(r.size.x, 5.0, 10), 0.0, Color(0.9, 0.78, 0.6))
	maison.name = "Maison"
	_batiment_romain(villa, Vector2(r.position.x + 4.0, c.y + 6.0), Vector3(8, 4.0, 12), 0.0, Color(0.86, 0.7, 0.5))
	_batiment_romain(villa, Vector2(r.end.x - 4.0, c.y + 6.0), Vector3(8, 4.0, 12), 0.0, Color(0.86, 0.7, 0.5))
	# Le pressoir à vin (le « torcularium ») : une grande poutre de chêne et sa pierre.
	var y := hauteur(c.x, c.y + 6.0)
	var bois := _mat_bois()
	_boite(Vector3(2.4, 0.5, 2.4), Vector3(c.x, y + 0.25, c.y + 8.0), _mat_tuf(), villa)
	var poutre := _boite(Vector3(0.5, 0.5, 9.0), Vector3(c.x, y + 1.6, c.y + 6.0), bois, villa, false)
	poutre.rotation.x = 0.12
	_boite(Vector3(0.4, 2.6, 0.4), Vector3(c.x, y + 1.3, c.y + 2.0), bois, villa, false)
	for k in 6:
		_amphore(villa, Vector3(c.x + 3.0 + (k % 3) * 0.7, y, c.y + 9.0 + (k / 3) * 0.7), 1.0, k)
	# Les vignes, en rangs, au sud de la villa.
	var vignes := Node3D.new()
	vignes.name = "Vignes"
	villa.add_child(vignes)
	var feuille := _mat_feuillage(Color(0.32, 0.4, 0.14))
	for rang in 10:
		var x := -128.0 + rang * 4.5
		var z := 46.0
		while z < 104.0:
			var yv := hauteur(x, z)
			var cep := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 0.7
			s.height = 1.1
			s.radial_segments = 8
			s.rings = 4
			cep.mesh = s
			cep.material_override = feuille
			cep.position = Vector3(x, yv + 0.9, z)
			vignes.add_child(cep)
			var echalas := MeshInstance3D.new()
			echalas.mesh = _cylindre(0.03, 0.04, 1.6, 5)
			echalas.material_override = bois
			echalas.position = Vector3(x, yv + 0.8, z + 0.5)
			vignes.add_child(echalas)
			z += 2.4
	_fusionner(villa)


## La carrière de tuf : des parois taillées en gradins, des blocs prêts à partir.
func _construire_carriere() -> void:
	var carriere := Node3D.new()
	carriere.name = "Carriere"
	_contenu.add_child(carriere)
	var tuf := _mat_tuf()
	var r := CARRIERE
	var fond := hauteur(r.get_center().x, r.get_center().y)
	# Les parois taillées à pic tout autour, en trois gradins (la rampe passe à l'ouest).
	var haut_gradin := PROFONDEUR_CARRIERE / 3.0 + 0.2
	var cz := r.get_center().y
	for k in 3:
		var retrait := k * 1.6
		var y := fond + haut_gradin * (k + 0.5)
		var longueur_x := r.size.x - retrait * 2.0
		var longueur_z := r.size.y - retrait * 2.0
		_boite(Vector3(longueur_x, haut_gradin, 1.6), Vector3(r.get_center().x, y, r.position.y + retrait - 0.8), tuf, carriere)
		_boite(Vector3(longueur_x, haut_gradin, 1.6), Vector3(r.get_center().x, y, r.end.y - retrait + 0.8), tuf, carriere)
		_boite(Vector3(1.6, haut_gradin, longueur_z), Vector3(r.end.x - retrait + 0.8, y, cz), tuf, carriere)
		# À l'ouest, la paroi est coupée par la rampe.
		var demi := (longueur_z * 0.5 - 5.0)
		for cote: float in [-1.0, 1.0]:
			_boite(Vector3(1.6, haut_gradin, demi), Vector3(r.position.x + retrait - 0.8, y, cz + cote * (5.0 + demi * 0.5)), tuf, carriere)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 30
	for k in 10:
		var p := Vector2(hasard.randf_range(r.position.x + 6.0, r.end.x - 8.0), hasard.randf_range(r.position.y + 6.0, r.end.y - 6.0))
		if p.distance_to(OURS) < 6.0:
			continue
		var bloc := _boite(Vector3(1.6, 0.9, 0.9), Vector3(p.x, hauteur(p.x, p.y) + 0.45, p.y), tuf, carriere)
		bloc.rotation.y = hasard.randf() * PI
	# Une grue de bois (une chèvre à trois pieds) au bord de la carrière.
	var bois := _mat_bois()
	for k in 3:
		var a := TAU * k / 3.0
		var pied := _boite(Vector3(0.18, 7.0, 0.18), Vector3(r.position.x + 3.0 + cos(a) * 1.0, hauteur(r.position.x, r.position.y) + 3.3, r.position.y - 2.0 + sin(a) * 1.0), bois, carriere, false)
		pied.rotation = Vector3(sin(a) * 0.15, 0, -cos(a) * 0.15)
	_fusionner(carriere)


# --- Arbres et rochers ---------------------------------------------------------------------

func _construire_vegetation() -> void:
	var arbres := Node3D.new()
	arbres.name = "Arbres"
	_contenu.add_child(arbres)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 60
	# Les pins parasols et les cyprès le long de la route.
	var z := 150.0
	while z > -110.0:
		for cote: float in [-1.0, 1.0]:
			if hasard.randf() < 0.5:
				continue
			var p := Vector2(-3.0 + cote * hasard.randf_range(6.5, 9.0), z + hasard.randf_range(-2.0, 2.0))
			if _distance_piste(p) < 3.0 or distance_aqueduc(p) < 5.0:
				continue
			if hasard.randf() < 0.6:
				_pin_parasol(arbres, p, hasard, hasard.randf_range(0.85, 1.15))
			else:
				_cypres(arbres, p, hasard)
		z -= hasard.randf_range(8.0, 13.0)
	# Des pins isolés et des oliviers dans la campagne.
	var e := echafaudage_est()
	var plantes := 0
	var essais := 0
	while plantes < 70 and essais < 900:
		essais += 1
		var p := Vector2(hasard.randf_range(-150.0, 150.0), hasard.randf_range(-150.0, 150.0))
		if distance_route(p) < 12.0 or distance_aqueduc(p) < 8.0 or _dans_rect(VILLA.grow(8.0), p.x, p.y, 0.1) > 0.5 \
				or _dans_rect(CARRIERE.grow(10.0), p.x, p.y, 0.1) > 0.5 or p.distance_to(STATIO) < 14.0 \
				or p.distance_to(e[0]) < 14.0 or p.distance_to(PORTE) < 24.0 or _distance_piste(p) < 4.0 \
				or (p.x < -56.0 and p.x > -132.0 and p.y > 40.0 and p.y < 108.0):
			continue
		if hasard.randf() < 0.55:
			_pin_parasol(arbres, p, hasard, hasard.randf_range(0.8, 1.2))
		else:
			_olivier(arbres, p, hasard, hasard.randf_range(0.8, 1.2))
		plantes += 1


func _construire_rochers() -> void:
	var dossier := Node3D.new()
	dossier.name = "Rochers"
	_contenu.add_child(dossier)
	_preparer_rochers()
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 12
	var poses := 0
	var essais := 0
	while poses < 40 and essais < 900:
		essais += 1
		var x := hasard.randf_range(60.0, 155.0)
		var z := hasard.randf_range(-150.0, -20.0)
		var p := Vector2(x, z)
		if distance_aqueduc(p) < 8.0 or _dans_rect(CARRIERE.grow(-4.0), x, z, 0.1) > 0.5 or p.distance_to(OURS) < 8.0:
			continue
		_placer_rocher(dossier, x, z, hasard.randf_range(0.6, 2.0))
		poses += 1


# --- Paysage lointain ----------------------------------------------------------------------

func _construire_lointain() -> void:
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.8
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 70
	# Le plan lointain fait le tour de la zone sans la couvrir (la carrière descend plus bas).
	for bande: Array in [[Vector3(0, 2.8 + SOCLE, -1075), Vector2(4000, 1850)], [Vector3(0, 2.8 + SOCLE, 1075), Vector2(4000, 1850)],
			[Vector3(-1075, 2.8 + SOCLE, 0), Vector2(1850, 300)], [Vector3(1075, 2.8 + SOCLE, 0), Vector2(1850, 300)]]:
		_plan_lointain(bande[0], bande[1], Color(0, 1, 0))
	# Les monts Albains au sud-est, les monts Sabins et Tibur au nord-est.
	for m in [[Vector3(1300, -10, 1100), Vector3(1000, 300, 800)], [Vector3(1900, -10, -900), Vector3(800, 340, 900)]]:
		bruit.seed = graine + hasard.randi()
		var montagne := MeshInstance3D.new()
		montagne.mesh = _maillage_bosse(bruit, m[1], 1.4, 0.3, 28, Color(0, 0.6, 0.4))
		montagne.material_override = _mat_lointain()
		montagne.position = m[0]
		montagne.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(montagne)
	var lointain := Node3D.new()
	lointain.name = "RomeLointaine"
	_contenu.add_child(lointain)
	# L'aqueduc continue vers le sud-est, jusqu'aux montagnes, et vers l'ouest, dans la ville.
	_arches_aqueduc(lointain, Vector3(178, 2.8 + SOCLE, 112), Vector3(900, 2.8 + SOCLE, 640), 24.0, 7.0)
	_arches_aqueduc(lointain, Vector3(-178, 2.8 + SOCLE, -128), Vector3(-520, 2.8 + SOCLE, -180), 24.0, 7.0)
	# Rome, au nord : des toits de tuiles à perte de vue, des immeubles, des temples sur
	# les collines, et le Colisée tout neuf.
	var enduit := _mat_enduit_peint(Color(0.84, 0.66, 0.46))
	var tuiles := _mat_tuiles()
	for k in 220:
		var x := hasard.randf_range(-900.0, 700.0)
		var z := hasard.randf_range(-260.0, -1300.0)
		var t := Vector3(hasard.randf_range(10.0, 30.0), hasard.randf_range(6.0, 18.0), hasard.randf_range(10.0, 26.0))
		var bloc := _boite(t, Vector3(x, 2.8 + SOCLE + t.y * 0.5, z), enduit, lointain, false)
		bloc.rotation.y = hasard.randf() * 0.4
		var toit := _boite(Vector3(t.x + 1.0, 0.8, t.z + 1.0), Vector3(x, 2.8 + SOCLE + t.y + 0.4, z), tuiles, lointain, false)
		toit.rotation.y = bloc.rotation.y
	var colisee := MeshInstance3D.new()
	var anneau := CylinderMesh.new()
	anneau.top_radius = 94.0
	anneau.bottom_radius = 96.0
	anneau.height = 48.0
	anneau.radial_segments = 48
	colisee.mesh = anneau
	colisee.material_override = _mat_travertin()
	colisee.scale = Vector3(1.0, 1.0, 0.82)
	colisee.position = Vector3(-380, 26.0 + SOCLE, -1050)
	lointain.add_child(colisee)
	for mi in lointain.get_children():
		if mi is MeshInstance3D:
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fusionner(lointain)


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
	# Derrière la porte, la ville : fermée tant que Rome n'est pas prête (chapitre 4).
	_mur_nord = _mur_invisible(limites, Vector3(40, 14, 2), Vector3(PORTE.x, hauteur(PORTE.x, PORTE.y) + 6.0, PORTE.y - 8.0))


# --- Personnages et objets de la quête ----------------------------------------------------------

func _construire_quete() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quete"
	_contenu.add_child(dossier)
	_dossier_quete = dossier
	var e := echafaudage_est()
	var regard_p: Vector2 = e[0] - (e[1] as Vector2) * 1.0
	_pnj(dossier, "livia", LIVIA, PI * 0.7)
	_pnj(dossier, "sextus", SEXTUS, -PI * 0.6)
	# Les fontainiers ont fui l'ours : ils reviennent quand il est abattu.
	for k in AQUARII.size():
		var ouvrier := _pnj(dossier, "aquarius_%d" % (k + 1), AQUARII[k], PI * (0.3 + k * 0.5))
		ouvrier.add_to_group("decor_quete")
		ouvrier.set_meta("identifiant", "aquarius_%d" % (k + 1))
		ouvrier.visible = false
	# En haut de l'échafaudage, le regard du canal : on l'ouvre pour voir ce qui se passe.
	var regard := ObjetRome.new()
	regard.name = "RegardSommet"
	regard.identifiant = "regard_sommet"
	regard.invite = "[F] Ouvrir le regard du canal"
	regard.portee = 2.8
	regard.position = Vector3(regard_p.x, Y_CANAL, regard_p.y)
	dossier.add_child(regard)
	# Les failles qui boivent l'eau, sur le canal.
	for k in FAILLES.size():
		var p: Vector2 = FAILLES[k]
		var faille := Faille.new()
		faille.name = "FailleCanal%d" % k
		faille.identifiant = "faille_canal_%d" % k
		faille.groupe = "faille_canal"
		faille.position = Vector3(p.x, Y_CANAL, p.y)
		dossier.add_child(faille)
	# Repères de la carte.
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.LIEU, "Porta Maggiore, vers Rome", PORTE)
	repere.call(MarqueurCarte.Type.LIEU, "Cabane des fontainiers", STATIO)
	repere.call(MarqueurCarte.Type.LIEU, "Échafaudage des fontainiers", e[0])
	repere.call(MarqueurCarte.Type.LIEU, "Villa et vignes", VILLA.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Carrière de tuf", CARRIERE.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Voie Appienne", SORTIE_SUD)
	for p: Vector2 in FAILLES:
		repere.call(MarqueurCarte.Type.DANGER, "Faille", p)


# --- Les sorties : la voie Appienne au sud, Rome au nord -------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	if Engine.is_editor_hint():
		return
	_attente_sortie -= delta
	if _attente_sortie > 0.0:
		return
	_attente_sortie = 0.3
	var quete := get_tree().get_first_node_in_group("quete")
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if quete == null or joueur == null or not quete.has_method("changer_de_zone"):
		return
	var p := Vector2(joueur.global_position.x, joueur.global_position.z)
	# Au sud, la route redescend vers la voie Appienne.
	if p.y > 152.0 and absf(p.x) < 12.0:
		quete.changer_de_zone("voie_appienne")
	# Au nord, par la porte, la ville (quand elle sera construite).
	if quete.donnees.get("zones", {}).has("rome") and quete.etape_atteinte("vers_rome"):
		if _mur_nord != null and is_instance_valid(_mur_nord):
			_mur_nord.queue_free()
		if p.y < PORTE.y - 10.0:
			quete.changer_de_zone("rome")
