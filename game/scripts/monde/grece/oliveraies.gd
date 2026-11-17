@tool
extends "res://scripts/monde/grece/ile_grece.gd"
## Île de Grèce, zone 2 : les Oliveraies d'Attique (niveaux 22-25).
##
## La campagne entre le Pirée et Athènes. Les Longs Murs la traversent du sud au nord :
## deux murailles parallèles, et la route entre elles. On arrive au sud, du Pirée. Deux
## poternes (des petites portes dans la muraille) mènent dehors : à l'est, la ferme de
## Myrtô l'apicultrice, ses ruches, et les pentes du mont Hymette où rôdent les
## sangliers ; à l'ouest, les vieilles oliveraies et le sanctuaire des oliviers sacrés
## d'Athéna. Tout au nord, les Longs Murs butent sur le rempart d'Athènes et sa porte.
## Au-dessus du rempart, on voit déjà l'Acropole et le Parthénon.
##
## Tout est construit par le code (voir ile_grece.gd). Repères : le nord est vers -Z.

const Faille := preload("res://scripts/monde/prehistoire/faille.gd")
const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const ObjetGrece := preload("res://scripts/monde/grece/objet_grece.gd")

## L'arrivée du Pirée, au sud, entre les deux Longs Murs.
const ENTREE := Vector2(0, 150)
## Les Longs Murs : x = ±MURS, du sud de la zone jusqu'au rempart d'Athènes.
const MURS := 13.0
const RAMPART_Z := -140.0
## Les poternes : la petite porte de l'est (vers la ferme) et celle de l'ouest (vers le sanctuaire).
const POTERNE_EST := Vector2(13, 40)
const POTERNE_OUEST := Vector2(-13, -30)
## La ferme de Myrtô, ses ruches sur la pente de l'Hymette.
const FERME := Vector2(70, 34)
const MYRTO := Vector2(62, 44)
const NERA := Vector2(65, 47)
const RUCHES := Vector2(96, 22)
const MASQUE := Vector2(91, 30)
## Le sanctuaire des oliviers sacrés (un enclos de pierre), la Moria (le plus vieil
## olivier), son autel, la prêtresse et la faille entre les racines.
const SANCTUAIRE := Rect2(-100, -66, 40, 30)
const MORIA := Vector2(-82, -54)
const AUTEL := Vector2(-80, -42)
const PRETRESSE := Vector2(-74, -44)
const FAILLE := Vector2(-86, -58)
## La porte d'Athènes, au bout des Longs Murs, et l'hermès du carrefour de la poterne est.
const PORTE_ATHENES := Vector2(0, -140)
const HERMES := Vector2(22, 46)
## Les hameaux : quelques fermes à l'est et à l'ouest des murs.
const HAMEAU_EST := Vector2(44, 104)
const HAMEAU_OUEST := Vector2(-60, 98)
## La route du Laurion, qui part du hameau de l'est vers le sud (les mines d'argent).
const ROUTE_LAURION := Vector2(60, 154)
## L'agent Markos, qui fait la route avec le joueur.
const MARKOS := Vector2(5, 132)

var _attente_sortie := 0.0
var _porte_ouverte := false
var _mur_porte: StaticBody3D


func _init() -> void:
	identifiant_zone = "oliveraies"
	taille_terrain = 320
	graine = 4381
	point_apparition = ENTREE + Vector2(0, -6)
	nombre_touffes = 60000
	reglages_couvre_sol = {"cailloux": 6.0, "fleurs": [Color(0.82, 0.1, 0.06), Color(0.95, 0.78, 0.12), Color(0.93, 0.91, 0.86)], "densite_fleurs": 2.0}
	neige_qui_tombe = false
	sols = {
		# Rouge : les cailloux du flanc de l'Hymette.
		"galets": ["dry_ground_rocks", "rocky_terrain_02", "dry_river_pebbles"],
		# Vert : la terre rouge et labourée des oliveraies.
		"neige": ["dry_ground_01", "red_sand", "dry_ground_rocks"],
		# Bleu : la terre battue de la route et des cours de ferme.
		"sol": ["dry_ground_01", "mud_cracked_dry_03", "dry_ground_rocks"],
		"roche": ["rock_boulder_dry", "cliff_side", "rock_wall_10"],
	}
	reglages_terrain = {"sol_saturation": 0.85, "sol_motif": 4.0, "galets_motif": 3.0, "neige_motif": 5.0,
			"sol_teinte": Color(1.0, 0.94, 0.86), "roche_teinte": Color(0.98, 0.95, 0.9), "roche_saturation": 0.7,
			"neige_eclat": 1.0, "neige_paillettes": 0.0, "roche_motif": 10.0,
			"neige_teinte": Color(1.02, 0.86, 0.7), "neige_max": Vector3(0.64, 0.5, 0.38), "neige_simple": Color(0.6, 0.46, 0.34),
			"givre": 0.0, "neige_translucide": 0.0}
	reglages_herbe = {"couleur_base": Color(0.24, 0.24, 0.1), "couleur_pointe": Color(0.66, 0.62, 0.34),
			"couleur_givre": Color(0.66, 0.6, 0.34), "force_vent": 0.25}
	# La route entre les murs, puis les chemins vers la ferme et le sanctuaire.
	piste = [Vector2(0, 160), Vector2(0, 40), Vector2(0, -30), Vector2(0, -136)]


func _ready() -> void:
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_grece", "") != "":
		var venu := String(Reseau.get_meta("arrivee_grece"))
		Reseau.remove_meta("arrivee_grece")
		# Retour d'Athènes : on arrive devant la porte, côté campagne.
		if venu == "athenes":
			point_apparition = PORTE_ATHENES + Vector2(0, 10)
		elif venu == "laurion":
			point_apparition = ROUTE_LAURION + Vector2(0, -10)
		else:
			point_apparition = ENTREE + Vector2(0, -6)
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	if zone == "oliveraies":
		return Vector2.INF
	if zone == "laurion":
		return ROUTE_LAURION + Vector2(0, -8)
	return PORTE_ATHENES + Vector2(0, 4) if zone == "athenes" else ENTREE + Vector2(0, 4)


# --- Relief -----------------------------------------------------------------------------

func _preparer_bruits() -> void:
	super._preparer_bruits()
	_relief.frequency = 0.012


## Distance aux chemins de terre (route des murs, chemins de la ferme et du sanctuaire).
func _distance_chemins(p: Vector2) -> float:
	var d := _distance_segment(p, POTERNE_EST, Vector2(40, 44))
	d = minf(d, _distance_segment(p, Vector2(40, 44), FERME + Vector2(-6, 6)))
	d = minf(d, _distance_segment(p, FERME + Vector2(-6, 6), RUCHES))
	d = minf(d, _distance_segment(p, POTERNE_OUEST, Vector2(-44, -36)))
	d = minf(d, _distance_segment(p, Vector2(-44, -36), AUTEL + Vector2(6, 2)))
	d = minf(d, _distance_segment(p, POTERNE_EST + Vector2(4, 4), HAMEAU_EST + Vector2(-12, 6)))
	d = minf(d, _distance_segment(p, HAMEAU_EST + Vector2(-12, 6), ROUTE_LAURION + Vector2(0, 6)))
	return d


func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	var bruit := _relief.get_noise_2d(x, z)
	var fin := _details.get_noise_2d(x * 3.0, z * 3.0)
	# Une plaine qui monte doucement vers Athènes (au nord), ondulée à l'ouest.
	var h := 4.0 + smoothstep(150.0, -150.0, z) * 5.0 + bruit * 2.2 + fin * 0.1
	# Le mont Hymette, à l'est : une pente de plus en plus raide.
	h += pow(smoothstep(60.0, 165.0, x), 1.5) * (26.0 + bruit * 8.0)
	# La route entre les Longs Murs : plate, sans bosses.
	var route := 4.0 + smoothstep(150.0, -150.0, z) * 5.0
	h = lerpf(h, route + fin * 0.03, 1.0 - smoothstep(MURS - 3.0, MURS + 6.0, absf(x)))
	# Les chemins de terre battue : on adoucit les bosses.
	var d_chemin := _distance_chemins(Vector2(x, z))
	h = lerpf(h, h * 0.6 + (4.0 + smoothstep(150.0, -150.0, z) * 5.0 + pow(smoothstep(60.0, 165.0, x), 1.5) * 26.0) * 0.4,
			1.0 - smoothstep(2.0, 5.0, d_chemin))
	# La cour de la ferme et l'enclos du sanctuaire : aplanis.
	h = lerpf(h, hauteur_plate(FERME), _dans_rect(Rect2(FERME.x - 16, FERME.y - 14, 32, 26), x, z, 6.0))
	h = lerpf(h, hauteur_plate(MORIA), _dans_rect(SANCTUAIRE, x, z, 6.0))
	return h


## La hauteur d'un terrain aplani autour d'un point (sans les bosses fines).
func hauteur_plate(p: Vector2) -> float:
	return 4.0 + smoothstep(150.0, -150.0, p.y) * 5.0 + _relief.get_noise_2d(p.x, p.y) * 2.2 \
			+ pow(smoothstep(60.0, 165.0, p.x), 1.5) * (26.0 + _relief.get_noise_2d(p.x, p.y) * 8.0)


## Rouge : cailloux de l'Hymette ; vert : terre rouge des oliveraies ; bleu : route et cours.
func _parts_sol(x: float, z: float, h: float) -> Color:
	var n := _relief.get_noise_2d(x * 2.0 + 60.0, z * 2.0)
	var cailloux := smoothstep(95.0, 130.0, x + n * 15.0)
	var battu := maxf(1.0 - smoothstep(MURS - 4.0, MURS - 1.0, absf(x)), 1.0 - smoothstep(1.5, 3.5, _distance_chemins(Vector2(x, z))))
	battu = maxf(battu, _dans_rect(Rect2(FERME.x - 12, FERME.y - 10, 24, 18), x, z, 3.0))
	battu = maxf(battu, _dans_rect(SANCTUAIRE.grow(-6.0), x, z, 3.0) * 0.6)
	var rouge := (1.0 - cailloux) * (1.0 - battu)
	return Color(cailloux * (1.0 - battu), rouge, battu, 1.0)


# --- Construction -------------------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_flotteurs.clear()
	_construire_terrain()
	_construire_longs_murs()
	_construire_rempart_athenes()
	_construire_ferme()
	_construire_sanctuaire()
	_construire_hameaux()
	_construire_oliveraies()
	_construire_rochers_hymette()
	_construire_touffes()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_appliquer_ciel()


# --- Les Longs Murs ------------------------------------------------------------------------

func _construire_longs_murs() -> void:
	var murs := Node3D.new()
	murs.name = "LongsMurs"
	_contenu.add_child(murs)
	var pierre := _mat_pierre()
	# Des tronçons de 12 m qui suivent la pente ; une ouverture à chaque poterne.
	for cote: float in [-1.0, 1.0]:
		var poterne := POTERNE_EST if cote > 0.0 else POTERNE_OUEST
		var z := 162.0
		while z > RAMPART_Z + 2.0:
			var z2 := maxf(z - 12.0, RAMPART_Z + 2.0)
			var milieu := (z + z2) * 0.5
			var long_troncon := z - z2
			# On laisse une ouverture de 4 m à la poterne.
			if absf(milieu - poterne.y) < 6.0:
				for bout: float in [-1.0, 1.0]:
					var zb := poterne.y + bout * 4.0
					var lb := 4.0
					var yb := hauteur(cote * MURS, zb)
					_boite(Vector3(3.0, 8.0, lb), Vector3(cote * MURS, yb + 3.5, zb), pierre, murs)
				# Le linteau et deux montants de la poterne.
				var yp := hauteur(cote * MURS, poterne.y)
				_boite(Vector3(3.2, 2.2, 4.4), Vector3(cote * MURS, yp + 6.4, poterne.y), pierre, murs, false)
			else:
				var y := hauteur(cote * MURS, milieu)
				_boite(Vector3(3.0, 8.0, long_troncon + 0.05), Vector3(cote * MURS, y + 3.5, milieu), pierre, murs)
				# Un chemin de ronde et des créneaux, un sur deux.
				_boite(Vector3(3.4, 0.4, long_troncon + 0.05), Vector3(cote * MURS, y + 7.6, milieu), pierre, murs, false)
				for k in 3:
					_boite(Vector3(0.6, 0.9, 1.4), Vector3(cote * (MURS + 1.3), y + 8.2, z - 2.0 - k * 4.0), pierre, murs, false)
			z = z2
		# Une tour carrée tous les 60 m.
		for k in 5:
			var zt := 130.0 - k * 60.0
			if absf(zt - poterne.y) < 10.0:
				continue
			var yt := hauteur(cote * MURS, zt)
			_boite(Vector3(6.0, 11.0, 6.0), Vector3(cote * (MURS + 1.5), yt + 5.0, zt), pierre, murs)


## Le rempart d'Athènes : il barre tout le nord, avec la grande porte au bout de la route.
func _construire_rempart_athenes() -> void:
	var rempart := Node3D.new()
	rempart.name = "RempartAthenes"
	_contenu.add_child(rempart)
	var pierre := _mat_pierre()
	var x := -160.0
	while x < 160.0:
		var x2 := minf(x + 16.0, 160.0)
		var milieu := (x + x2) * 0.5
		if absf(milieu) > 9.0:
			var y := hauteur(milieu, RAMPART_Z)
			_boite(Vector3(x2 - x + 0.05, 10.0, 4.0), Vector3(milieu, y + 4.0, RAMPART_Z - 2.0), pierre, rempart)
		x = x2
	var y0 := hauteur(0.0, RAMPART_Z)
	for cote: float in [-1.0, 1.0]:
		_boite(Vector3(7.0, 14.0, 7.0), Vector3(cote * 8.0, y0 + 6.0, RAMPART_Z - 2.0), pierre, rempart)
	_boite(Vector3(10.0, 3.0, 4.4), Vector3(0, y0 + 9.5, RAMPART_Z - 2.0), pierre, rempart, false)
	# Les deux battants de la porte, fermés (ils s'ouvriront avec la suite de l'histoire).
	for cote: float in [-1.0, 1.0]:
		var vantail := Node3D.new()
		vantail.name = "Vantail"
		vantail.set_meta("identifiant", "porte_athenes_" + ("g" if cote < 0.0 else "d"))
		vantail.add_to_group("decor_quete")
		vantail.position = Vector3(cote * 4.5, y0, RAMPART_Z - 0.4)
		rempart.add_child(vantail)
		_boite(Vector3(4.4, 7.6, 0.4), Vector3(-cote * 2.2, 3.8, 0), _mat_bois(), vantail, false)
		for k in 3:
			_boite(Vector3(4.4, 0.18, 0.5), Vector3(-cote * 2.2, 1.2 + k * 2.5, 0.05), _mat_bronze(), vantail, false)


# --- La ferme de Myrtô et ses ruches ---------------------------------------------------------

func _construire_ferme() -> void:
	var ferme := Node3D.new()
	ferme.name = "Ferme"
	_contenu.add_child(ferme)
	_maison_grecque(ferme, FERME + Vector2(4, -6), Vector3(8, 4.2, 6), 0.0)
	_maison_grecque(ferme, FERME + Vector2(-8, -5), Vector3(5, 3.4, 4), 0.3)
	# Le muret de pierres sèches qui ferme la cour.
	var pierre := _mat_pierre()
	for k in 9:
		var a := lerpf(0.4, PI - 0.4, float(k) / 8.0)
		var p := FERME + Vector2(cos(a) * 15.0, sin(a) * 10.0 + 2.0)
		if p.distance_to(Vector2(56, 44)) < 5.0:
			continue
		var bloc := _boite(Vector3(4.2, 1.0, 0.7), Vector3(p.x, hauteur(p.x, p.y) + 0.4, p.y), pierre, ferme)
		bloc.rotation.y = -a + PI / 2
	# La cour : une jarre, un pressoir à huile (une meule de pierre dans son bac), un âne attaché.
	_amphore(ferme, Vector3(FERME.x + 6, hauteur(FERME.x + 6, FERME.y + 1), FERME.y + 1), 1.0, 0.2)
	_amphore(ferme, Vector3(FERME.x + 7, hauteur(FERME.x + 7, FERME.y + 2), FERME.y + 2), 0.8, 1.4, true)
	var bac := MeshInstance3D.new()
	bac.mesh = _cylindre(1.4, 1.5, 0.6, 18)
	bac.material_override = pierre
	bac.position = Vector3(FERME.x - 4, hauteur(FERME.x - 4, FERME.y + 4) + 0.3, FERME.y + 4)
	ferme.add_child(bac)
	var meule := MeshInstance3D.new()
	meule.mesh = _cylindre(0.7, 0.7, 0.4, 16)
	meule.material_override = pierre
	meule.rotation.z = PI / 2
	meule.position = bac.position + Vector3(0.3, 0.75, 0)
	ferme.add_child(meule)
	# Les ruches : des tubes de terre cuite couchés en rangées sur des banquettes de pierre
	# (les Grecs élevaient leurs abeilles dans des ruches horizontales en argile).
	var argile := _mat_terre_cuite()
	for rang in 3:
		for k in 6:
			var p := RUCHES + Vector2(-8.0 + k * 3.0, -5.0 + rang * 4.5)
			var y := hauteur(p.x, p.y)
			_boite(Vector3(2.4, 0.5, 1.2), Vector3(p.x, y + 0.25, p.y), pierre, ferme)
			var ruche := MeshInstance3D.new()
			ruche.mesh = _cylindre(0.32, 0.36, 1.1, 12)
			ruche.material_override = argile
			ruche.rotation.x = PI / 2
			ruche.position = Vector3(p.x, y + 0.82, p.y)
			ferme.add_child(ruche)
	# Le thym en fleur autour des ruches (de petites boules mauves).
	var thym := _mat_feuillage(Color(0.42, 0.42, 0.36))
	var fleurs := _mat_feuillage(Color(0.55, 0.42, 0.6))
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 21
	for k in 40:
		var p := RUCHES + Vector2(hasard.randf_range(-18, 18), hasard.randf_range(-14, 16))
		var touffe := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = hasard.randf_range(0.18, 0.32)
		s.height = s.radius * 1.1
		s.radial_segments = 8
		s.rings = 4
		touffe.mesh = s
		touffe.material_override = fleurs if k % 4 == 0 else thym
		touffe.position = Vector3(p.x, hauteur(p.x, p.y) + s.radius * 0.4, p.y)
		ferme.add_child(touffe)


# --- Le sanctuaire des oliviers sacrés --------------------------------------------------------

func _construire_sanctuaire() -> void:
	var sanctuaire := Node3D.new()
	sanctuaire.name = "Sanctuaire"
	_contenu.add_child(sanctuaire)
	var pierre := _mat_pierre()
	var marbre := _mat_marbre()
	# L'enclos (le téménos) : un muret de pierre, ouvert à l'est.
	var r := SANCTUAIRE.grow(-3.0)
	var y := hauteur_plate(MORIA)
	for cote in 4:
		var horizontal := cote < 2
		var longueur := r.size.x if horizontal else r.size.y
		var centre := Vector2(r.get_center().x, r.position.y if cote == 0 else r.end.y) if horizontal \
				else Vector2(r.position.x if cote == 2 else r.end.x, r.get_center().y)
		if cote == 3:
			# L'entrée, à l'est : deux tronçons de part et d'autre.
			for bout: float in [-1.0, 1.0]:
				_boite(Vector3(0.8, 1.4, longueur * 0.5 - 3.0), Vector3(centre.x, y + 0.5, centre.y + bout * (longueur * 0.25 + 1.5)), pierre, sanctuaire)
			for bout: float in [-1.0, 1.0]:
				_colonne(sanctuaire, Vector3(centre.x, y, centre.y + bout * 2.6), 3.2, 0.26, marbre)
			continue
		_boite(Vector3(longueur, 1.4, 0.8) if horizontal else Vector3(0.8, 1.4, longueur), Vector3(centre.x, y + 0.5, centre.y), pierre, sanctuaire)
	# L'autel d'Athéna, peint, et ses offrandes.
	_boite(Vector3(2.4, 1.1, 1.4), Vector3(AUTEL.x, y + 0.55, AUTEL.y), marbre, sanctuaire)
	_boite(Vector3(2.6, 0.18, 1.6), Vector3(AUTEL.x, y + 1.2, AUTEL.y), _mat_peint(ROUGE_GREC, 0.6), sanctuaire, false)
	_amphore(sanctuaire, Vector3(AUTEL.x + 1.8, y, AUTEL.y + 0.6), 0.9, 0.4)
	_amphore(sanctuaire, Vector3(AUTEL.x - 1.8, y, AUTEL.y + 0.5), 0.8, 1.1)
	# La Moria : un olivier immense, tordu, plusieurs fois centenaire.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 31
	var moria := _olivier(sanctuaire, MORIA, hasard, 2.3)
	moria.name = "Moria"
	# Les autres oliviers sacrés, en cercle dans l'enclos.
	for k in 7:
		var a := TAU * k / 7.0 + 0.3
		var p := MORIA + Vector2(cos(a) * 10.0, sin(a) * 7.5)
		if p.distance_to(AUTEL) < 4.0 or p.distance_to(PRETRESSE) < 3.0:
			continue
		_olivier(sanctuaire, p, hasard, hasard.randf_range(1.3, 1.7))


# --- Hameaux, oliveraies et cailloux ---------------------------------------------------------

func _construire_hameaux() -> void:
	var hameaux := Node3D.new()
	hameaux.name = "Hameaux"
	_contenu.add_child(hameaux)
	_maison_grecque(hameaux, HAMEAU_EST, Vector3(7, 4.0, 6), 0.2)
	_maison_grecque(hameaux, HAMEAU_EST + Vector2(12, 6), Vector3(6, 3.6, 5), -0.3)
	_maison_grecque(hameaux, HAMEAU_OUEST, Vector3(7, 4.0, 6), -0.2)
	_maison_grecque(hameaux, HAMEAU_OUEST + Vector2(-10, -8), Vector3(5, 3.4, 5), 0.5)
	# L'hermès du carrefour : un pilier de pierre surmonté d'une tête barbue (le dieu
	# Hermès protège les routes et les voyageurs).
	var y := hauteur(HERMES.x, HERMES.y)
	_boite(Vector3(0.45, 1.5, 0.4), Vector3(HERMES.x, y + 0.75, HERMES.y), _mat_marbre(), hameaux)
	var tete := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.22
	s.height = 0.5
	tete.mesh = s
	tete.material_override = _mat_marbre()
	tete.position = Vector3(HERMES.x, y + 1.72, HERMES.y)
	hameaux.add_child(tete)
	var barbe := MeshInstance3D.new()
	barbe.mesh = _cylindre(0.05, 0.16, 0.3, 8)
	barbe.material_override = _mat_peint(Color(0.3, 0.2, 0.12))
	barbe.position = Vector3(HERMES.x, y + 1.52, HERMES.y + 0.12)
	barbe.rotation.x = PI
	hameaux.add_child(barbe)


## Les oliveraies : des rangées régulières d'oliviers, à l'ouest et au sud-est.
func _construire_oliveraies() -> void:
	var arbres := Node3D.new()
	arbres.name = "Oliveraies"
	_contenu.add_child(arbres)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 40
	var parcelles := [Rect2(-150, -128, 120, 60), Rect2(-150, -20, 110, 70), Rect2(-140, 60, 90, 90),
			Rect2(26, 70, 60, 80), Rect2(30, -120, 60, 70)]
	for parcelle in parcelles:
		var r: Rect2 = parcelle
		var pas := 11.0
		var x := r.position.x + 4.0
		while x < r.end.x:
			var z := r.position.y + 4.0
			while z < r.end.y:
				var p := Vector2(x + hasard.randf_range(-1.2, 1.2), z + hasard.randf_range(-1.2, 1.2))
				z += pas
				if absf(p.x) < MURS + 6.0 or _distance_chemins(p) < 4.0 or _dans_rect(SANCTUAIRE.grow(4.0), p.x, p.y, 0.1) > 0.5:
					continue
				if p.distance_to(HAMEAU_EST) < 12.0 or p.distance_to(HAMEAU_OUEST) < 14.0 or p.distance_to(FERME) < 20.0:
					continue
				if hasard.randf() < 0.12:
					continue
				_olivier(arbres, p, hasard, hasard.randf_range(0.85, 1.25))
			x += pas
	# Des cyprès le long de la route, de chaque côté des murs, et autour de la ferme.
	for k in 10:
		var z := 120.0 - k * 26.0
		_cypres(arbres, Vector2(-MURS - 5.0, z + 6.0), hasard)
		_cypres(arbres, Vector2(MURS + 5.0, z - 7.0), hasard)
	for k in 3:
		_cypres(arbres, FERME + Vector2(-14.0 + k * 3.0, -14.0), hasard)


func _construire_rochers_hymette() -> void:
	var dossier := Node3D.new()
	dossier.name = "Rochers"
	_contenu.add_child(dossier)
	_preparer_rochers()
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 12
	var poses := 0
	var essais := 0
	while poses < 90 and essais < 1200:
		essais += 1
		var x := hasard.randf_range(95.0, 158.0)
		var z := hasard.randf_range(-150.0, 150.0)
		if Vector2(x, z).distance_to(RUCHES) < 14.0 or _distance_chemins(Vector2(x, z)) < 4.0:
			continue
		_placer_rocher(dossier, x, z, hasard.randf_range(0.6, 2.6) * (1.8 if hasard.randf() < 0.12 else 1.0))
		poses += 1
	# Les rochers des vipères, autour du sanctuaire.
	for k in 14:
		var p := Vector2(hasard.randf_range(-150.0, -40.0), hasard.randf_range(-100.0, -70.0))
		if _dans_rect(SANCTUAIRE.grow(3.0), p.x, p.y, 0.1) > 0.5:
			continue
		_placer_rocher(dossier, p.x, p.y, hasard.randf_range(0.8, 1.8))


# --- Paysage lointain ----------------------------------------------------------------------

func _construire_lointain() -> void:
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.8
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 70
	# La plaine qui continue tout autour (quatre bandes, sans recouvrir la zone).
	_plan_lointain(Vector3(0, 9.0, -1080), Vector2(4000, 1840), Color(0, 1, 0))
	_plan_lointain(Vector3(0, 3.0, 1080), Vector2(4000, 1840), Color(0, 1, 0))
	_plan_lointain(Vector3(-1080, 5.0, 0), Vector2(1840, 320), Color(0, 1, 0))
	_plan_lointain(Vector3(1080, 20.0, 0), Vector2(1840, 320), Color(0, 1, 0))
	# Le mont Hymette qui continue à l'est, le Parnès au nord, l'Aigaléos à l'ouest.
	for m in [[Vector3(700, -10, -100), Vector3(500, 330, 1400)], [Vector3(-200, -10, -1900), Vector3(1200, 300, 300)],
			[Vector3(-1100, -10, -500), Vector3(300, 160, 800)]]:
		bruit.seed = graine + hasard.randi()
		var montagne := MeshInstance3D.new()
		montagne.mesh = _maillage_bosse(bruit, m[1], 1.4, 0.3, 28, Color(0, 0.6, 0.4))
		montagne.material_override = _mat_lointain()
		montagne.position = m[0]
		montagne.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(montagne)
	# Athènes derrière son rempart : des toits, la colline de l'Acropole et le Parthénon.
	var ville := Node3D.new()
	ville.name = "AthenesLointaine"
	_contenu.add_child(ville)
	for k in 150:
		var p := Vector2(hasard.randf_range(-170, 150), hasard.randf_range(-300, -165))
		var maison := Node3D.new()
		maison.position = Vector3(p.x, 8.6, p.y)
		maison.rotation.y = hasard.randf_range(-0.2, 0.2)
		ville.add_child(maison)
		var taille := Vector3(hasard.randf_range(6, 10), hasard.randf_range(4, 6), hasard.randf_range(6, 9))
		_boite(taille, Vector3(0, taille.y * 0.5, 0), _mat_chaux(), maison, false)
		_toit(maison, Vector3(0, taille.y, 0), taille.x, taille.z)
	_construire_acropole_lointaine(Vector3(-40, 0, -520))


## Écrase le haut d'une bosse : des flancs raides et un sommet plat, comme l'Acropole.
func _rocher_plateau(maillage: ArrayMesh, sommet: float) -> ArrayMesh:
	var tableaux := maillage.surface_get_arrays(0)
	var sommets: PackedVector3Array = tableaux[Mesh.ARRAY_VERTEX]
	for k in sommets.size():
		var v := sommets[k]
		v.y = minf(v.y, sommet + absf(sin(v.x * 0.07 + v.z * 0.05)) * 1.5)
		sommets[k] = v
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	outil.set_color(Color(0, 0.2, 0.8))
	for v in sommets:
		outil.add_vertex(v)
	outil.generate_normals()
	return outil.commit()


func _construire_acropole_lointaine(centre: Vector3) -> void:
	var acropole := Node3D.new()
	acropole.name = "AcropoleLointaine"
	acropole.position = centre
	_contenu.add_child(acropole)
	var bruit := FastNoiseLite.new()
	bruit.seed = graine + 90
	bruit.frequency = 0.9
	var rocher := MeshInstance3D.new()
	rocher.mesh = _rocher_plateau(_maillage_bosse(bruit, Vector3(300, 220, 150), 1.6, 0.18, 28, Color(0, 0.2, 0.8)), 64.0)
	rocher.material_override = _mat_lointain()
	rocher.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	acropole.add_child(rocher)
	var temple := Node3D.new()
	temple.position = Vector3(10, 63, 0)
	acropole.add_child(temple)
	var marbre := _mat_marbre()
	_boite(Vector3(72, 3, 33), Vector3(0, 1.5, 0), marbre, temple, false)
	for k in 17:
		for cote: float in [-1.0, 1.0]:
			var c := MeshInstance3D.new()
			c.mesh = _cylindre(0.9, 1.0, 10.5, 8)
			c.material_override = marbre
			c.position = Vector3(-34 + k * 4.25, 8.2, cote * 14.5)
			temple.add_child(c)
	_boite(Vector3(60, 10, 20), Vector3(0, 8, 0), _mat_chaux(), temple, false)
	_boite(Vector3(72, 2.4, 33), Vector3(0, 14.6, 0), marbre, temple, false)
	_frise(temple, Vector3(0, 13.4, 16.6), 72.0, 1.6)
	var fronton := Node3D.new()
	fronton.position = Vector3(0, 15.8, 0)
	fronton.rotation.y = PI / 2
	temple.add_child(fronton)
	_toit(fronton, Vector3.ZERO, 33.0, 72.0, 0.22)


# --- Limites de la zone -----------------------------------------------------------------------

func _construire_limites() -> void:
	var limites := Node3D.new()
	limites.name = "Limites"
	_contenu.add_child(limites)
	var demi := taille_terrain * 0.5 - 4.0
	_mur_invisible(limites, Vector3(2, 160, taille_terrain), Vector3(-demi, 40, 0))
	_mur_invisible(limites, Vector3(2, 160, taille_terrain), Vector3(demi, 40, 0))
	_mur_invisible(limites, Vector3(taille_terrain, 160, 2), Vector3(0, 40, demi))
	# La porte d'Athènes, fermée jusqu'à ce que Socrate convainque le garde.
	_mur_porte = _mur_invisible(limites, Vector3(10, 14, 2), Vector3(0, hauteur(0, RAMPART_Z) + 6.0, RAMPART_Z + 0.5))


# --- Personnages et objets de la quête ----------------------------------------------------------

func _construire_quete() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quete"
	_contenu.add_child(dossier)
	_dossier_quete = dossier
	_pnj(dossier, "markos", MARKOS, 0.3)
	_pnj(dossier, "myrto", MYRTO, -2.4)
	_pnj(dossier, "nera", NERA, -2.8)
	_pnj(dossier, "pretresse", PRETRESSE, 1.4)
	_pnj(dossier, "paysan_ktesippe", HAMEAU_EST + Vector2(-5, 6), 2.6)
	_pnj(dossier, "garde_porte", PORTE_ATHENES + Vector2(4, 4), 0.0)
	# Quête secondaire « Les derniers de Marathon » : Épizélos, devant sa ferme du hameau.
	_pnj(dossier, "veteran_epizelos", HAMEAU_OUEST + Vector2(4, -6), PI * 0.6)
	# Socrate revient du Pirée : il attend derrière le rempart, puis arrive à la porte.
	_pnj(dossier, "socrate", PORTE_ATHENES + Vector2(-4, -12), 0.0)
	# Le masque de théâtre que Néra a ramassé près des ruches.
	var masque := ObjetGrece.new()
	masque.name = "MasqueNera"
	masque.identifiant = "masque_nera"
	masque.forme = "masque"
	masque.invite = "[F] Examiner le masque"
	masque.position = Vector3(MASQUE.x, hauteur(MASQUE.x, MASQUE.y), MASQUE.y)
	dossier.add_child(masque)
	# La faille entre les racines de la Moria.
	var faille := Faille.new()
	faille.name = "Faille"
	faille.identifiant = "faille_moria"
	faille.position = Vector3(FAILLE.x, hauteur(FAILLE.x, FAILLE.y), FAILLE.y)
	dossier.add_child(faille)
	# Repères de la carte.
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.LIEU, "Route du Pirée", ENTREE)
	repere.call(MarqueurCarte.Type.LIEU, "Porte d'Athènes", PORTE_ATHENES + Vector2(0, 6))
	repere.call(MarqueurCarte.Type.LIEU, "Ferme de Myrtô", FERME)
	repere.call(MarqueurCarte.Type.LIEU, "Ruches de l'Hymette", RUCHES)
	repere.call(MarqueurCarte.Type.LIEU, "Sanctuaire des oliviers sacrés", MORIA + Vector2(0, 8))
	repere.call(MarqueurCarte.Type.LIEU, "Poterne de l'est", POTERNE_EST)
	repere.call(MarqueurCarte.Type.LIEU, "Poterne de l'ouest", POTERNE_OUEST)
	repere.call(MarqueurCarte.Type.LIEU, "Route du Laurion", ROUTE_LAURION + Vector2(0, -6))
	repere.call(MarqueurCarte.Type.DANGER, "Sangliers", Vector2(116, 30))
	repere.call(MarqueurCarte.Type.DANGER, "Loups", Vector2(-70, 40))
	repere.call(MarqueurCarte.Type.DANGER, "Faille", FAILLE)


# --- Sorties : le Pirée au sud, Athènes au nord -------------------------------------------------

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
	# Au sud, la route redescend vers le Pirée.
	if p.y > 151.0 and absf(p.x) < MURS:
		quete.changer_de_zone("le_piree")
	# Au sud-est, après le hameau, la route poussiéreuse du Laurion.
	if p.y > 151.0 and absf(p.x - ROUTE_LAURION.x) < 6.0 and quete.donnees.get("zones", {}).has("laurion"):
		quete.changer_de_zone("laurion")
	# Au nord, la porte d'Athènes s'ouvre quand Socrate a convaincu le garde.
	if not _porte_ouverte and quete.etape_atteinte("entrer_athenes"):
		_ouvrir_porte()
	if _porte_ouverte and p.y < RAMPART_Z + 1.0 and absf(p.x) < 5.0 and quete.donnees.get("zones", {}).has("athenes"):
		quete.changer_de_zone("athenes")


func _ouvrir_porte() -> void:
	_porte_ouverte = true
	if _mur_porte != null and is_instance_valid(_mur_porte):
		_mur_porte.queue_free()
	for n in get_tree().get_nodes_in_group("decor_quete"):
		var id := String(n.get_meta("identifiant", ""))
		if id.begins_with("porte_athenes_"):
			n.rotation.y = 1.4 if id.ends_with("g") else -1.4
