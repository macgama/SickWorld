@tool
extends "res://scripts/monde/moyen_age/ile_moyen_age.gd"
## Île du Moyen Âge, zone 4 : le chantier de la cathédrale (niveaux 57-59).
##
## On entre par le Portail royal, depuis le parvis de Chartres. Dedans :
## - la nef brûlée, à ciel ouvert : les murs noircis, les moignons des piliers, les
##   nouvelles bases de piliers en pierre blonde, les échafaudages de bois, une grue à roue ;
## - le transept et le chœur, encombrés de poutres calcinées ; au bout du bras nord du
##   transept, l'escalier et la porte de fer de la crypte (le donjon, plus tard) ;
## - au sud, la cour du chantier : la loge des tailleurs de pierre (les établis, les plans
##   de maître Gautier), les tas de pierres marquées, le beffroi de charpente et sa cloche,
##   la forge ;
## - au nord, l'atelier des verriers : les fours, le sable, les cendres de fougère.
## Le soir, le chantier s'éclaire aux braseros.
##
## Tout est construit par le code. Repères : le nord est vers -Z, la façade à l'ouest.

const Faille := preload("res://scripts/monde/prehistoire/faille.gd")
const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const ObjetMoyenAge := preload("res://scripts/monde/moyen_age/objet_moyen_age.gd")

const SOL := 6.0
const FACADE_X := -76.0
const NEF := Rect2(-76, -17, 96, 34)
const TRANSEPT := Rect2(20, -44, 22, 88)
const CHOEUR := Rect2(42, -17, 34, 34)
const ABSIDE := Vector2(76, 0)
const RAYON_ABSIDE := 17.0
## Les ouvertures dans les murs de la nef (vers les cours) : x des portes.
const PORTES_NEF := [-44.0, -4.0]
const ARRIVEE := Vector2(-64, 0)
const SORTIE_CHARTRES := Vector2(-73.5, 0)
## La cour sud : la loge, les pierres, le beffroi, la forge.
const LOGE := Rect2(-44, 34, 30, 14)
const GAUTIER := Vector2(-28, 30)
const PLANS := Vector2(-36, 40)
const BEFFROI := Vector2(40, 64)
const FORGE := Vector2(72, 44)
const PIERRES := Vector2(10, 56)
## Les bases des nouveaux piliers, à poser (chapitre 6).
const BASES := [Vector2(-50, -7), Vector2(-41, -7), Vector2(-32, -7)]
const GRUE := Vector2(-14, 9)
## La cour nord : l'atelier des verriers.
const ATELIER := Rect2(-46, -74, 28, 16)
const AUDE := Vector2(-30, -54)
const FOUR := Vector2(-34, -66)
const CENDRES := [Vector2(-54, -52), Vector2(-12, -70), Vector2(-50, -82)]
## La crypte : l'escalier au bout du bras nord du transept.
const CRYPTE := Vector2(31, -50)
## Chapitre 7 : les échafaudages sabotés, le cortège du roi.
const ETAIS := [Vector2(-22, 14), Vector2(4, -13), Vector2(31, 30)]
const ROI := Vector2(-60, 3)
const CORTEGE := [Vector2(-62, 0), Vector2(-40, 0), Vector2(-10, 0), Vector2(20, 0), Vector2(40, 0), Vector2(58, 0)]
const PLOMB := Vector2(31, -38)

var _roue: Node3D
var _cloche: Node3D


func _init() -> void:
	identifiant_zone = "chantier"
	taille_terrain = 280
	graine = 1197
	point_apparition = ARRIVEE
	nombre_touffes = 6000
	fertilite_sols = Vector3(0.05, 0.3, 1.0)
	neige_qui_tombe = false
	sols = {
		# Rouge : la terre battue du chantier, la poussière de calcaire.
		"galets": ["dry_ground_rocks", "brown_mud_02", "dry_ground_01"],
		# Vert : la cendre de l'incendie, dans la nef.
		"neige": ["brown_mud_03", "dry_river_pebbles", "brown_mud_02"],
		# Bleu : l'herbe des cours.
		"sol": ["withered_grass", "brown_mud_02", "dry_ground_01"],
		"roche": ["quarry_wall", "quarry_wall_02", "white_sandstone_blocks_02"],
	}
	reglages_terrain = {"sol_saturation": 1.05, "sol_motif": 6.0, "galets_motif": 4.0, "neige_motif": 5.0,
			"sol_teinte": Color(0.64, 0.8, 0.44), "roche_teinte": Color(1.1, 1.02, 0.86), "roche_saturation": 0.75,
			"neige_eclat": 1.0, "neige_paillettes": 0.0, "roche_motif": 8.0,
			"neige_teinte": Color(0.4, 0.37, 0.35), "neige_max": Vector3(0.3, 0.28, 0.26), "neige_simple": Color(0.2, 0.19, 0.18),
			"givre": 0.0, "neige_translucide": 0.0}
	reglages_herbe = {"couleur_base": Color(0.18, 0.26, 0.1), "couleur_pointe": Color(0.56, 0.68, 0.3),
			"couleur_givre": Color(0.7, 0.68, 0.4), "force_vent": 0.3}
	reglages_couvre_sol = {"cailloux": 5.0, "fleurs": [Color(0.95, 0.92, 0.85)], "densite_fleurs": 0.5,
			"buissons": 0.2, "litiere": 0.5}
	piste = []


func sortie_vers(zone: String) -> Vector2:
	if zone == "chartres":
		return SORTIE_CHARTRES
	return Vector2.INF


# --- Relief : le sommet de la butte, presque plat -------------------------------------------------

func _preparer_bruits() -> void:
	super._preparer_bruits()
	_relief.frequency = 0.01


func dans_la_cathedrale(p: Vector2) -> bool:
	return NEF.has_point(p) or TRANSEPT.has_point(p) or CHOEUR.has_point(p) or p.distance_to(ABSIDE) < RAYON_ABSIDE


func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	var bruit := _relief.get_noise_2d(x, z)
	var fin := _details.get_noise_2d(x * 3.0, z * 3.0)
	var p := Vector2(x, z)
	var h := SOL + bruit * 0.5 + fin * 0.06
	# Dans la cathédrale : le dallage (en partie couvert de cendre), bien plat.
	var dedans := maxf(maxf(_dans_rect(NEF, x, z, 4.0), _dans_rect(TRANSEPT, x, z, 4.0)), maxf(_dans_rect(CHOEUR, x, z, 4.0),
			1.0 - smoothstep(RAYON_ABSIDE - 2.0, RAYON_ABSIDE + 2.0, p.distance_to(ABSIDE))))
	h = lerpf(h, SOL + fin * 0.02, dedans)
	# Loin de la cathédrale, la butte commence à descendre.
	h -= smoothstep(90.0, 140.0, maxf(absf(x), absf(z))) * 4.0
	return h


## Rouge : terre du chantier ; vert : cendre dans la nef ; bleu : herbe.
func _parts_sol(x: float, z: float, _h: float) -> Color:
	var p := Vector2(x, z)
	var cendre := 0.0
	if dans_la_cathedrale(p):
		var n := _relief.get_noise_2d(x * 4.0, z * 4.0)
		cendre = smoothstep(-0.2, 0.3, n)
	var terre := 0.0
	if not dans_la_cathedrale(p):
		terre = 1.0 - smoothstep(60.0, 90.0, maxf(absf(x - 0.0), absf(z)))
		var n2 := _relief.get_noise_2d(x * 2.0 + 40.0, z * 2.0)
		terre *= smoothstep(-0.5, 0.2, n2)
	else:
		terre = 1.0 - cendre
	return Color(terre + 0.001, cendre, maxf(0.0, 1.0 - terre - cendre), 1.0)


# --- Construction -------------------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_construire_terrain()
	_construire_cathedrale()
	_construire_echafaudages()
	_construire_cour_sud()
	_construire_cour_nord()
	_construire_palissade()
	_construire_touffes()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_appliquer_ciel()


# --- La cathédrale brûlée -------------------------------------------------------------------------

func _construire_cathedrale() -> void:
	var dossier := Node3D.new()
	dossier.name = "Cathedrale"
	_contenu.add_child(dossier)
	var pierre := _mat_calcaire()
	var noir := _mat_pierre_brulee()
	var sombre := _mat_uni_ma(Color(0.03, 0.03, 0.035), 1.0)
	var y := SOL - 0.3
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 11
	# La façade ouest, vue de dedans : les deux tours, le mur, les trois portes.
	for cote: float in [-1.0, 1.0]:
		_boite(Vector3(12.0, 44.0, 12.0), Vector3(FACADE_X - 6.0, y + 22.0, cote * 13.0), pierre, dossier)
	_boite(Vector3(2.4, 30.0, 14.0), Vector3(FACADE_X - 1.2, y + 15.0, 0), pierre, dossier)
	for k in 3:
		var z := (k - 1) * 4.2
		_boite(Vector3(0.2, 6.0 if k == 1 else 5.0, 3.0 if k == 1 else 2.2), Vector3(FACADE_X + 0.02, y + (3.0 if k == 1 else 2.5), z), sombre, dossier, false)
		var bleu := _mat_uni_ma(Color(0.1, 0.22, 0.6), 0.3)
		bleu.emission_enabled = true
		bleu.emission = Color(0.14, 0.3, 0.95)
		bleu.emission_energy_multiplier = 1.4
		_boite(Vector3(0.2, 9.0, 2.0), Vector3(FACADE_X + 0.05, y + 16.0, z), bleu, dossier, false)
	var fleche := MeshInstance3D.new()
	fleche.mesh = _cylindre(0.4, 6.0, 40.0, 8)
	fleche.material_override = pierre
	fleche.position = Vector3(FACADE_X - 6.0, y + 64.0, 13.0)
	dossier.add_child(fleche)
	# Les murs de la nef, noircis, à moitié écroulés, percés de deux passages vers les cours.
	for cote: float in [-1.0, 1.0]:
		var z := cote * (NEF.size.y * 0.5)
		var x := NEF.position.x + 2.0
		while x < NEF.end.x - 2.0:
			var porte := false
			for px: float in PORTES_NEF:
				porte = porte or absf(x + 4.5 - px) < 4.0
			if not porte:
				var haut := hasard.randf_range(5.0, 13.0)
				_boite(Vector3(9.0, haut, 1.6), Vector3(x + 4.5, y + haut * 0.5, z), noir if hasard.randf() < 0.55 else pierre, dossier)
				_boite(Vector3(1.8, haut + 2.5, 2.6), Vector3(x + 9.0, y + (haut + 2.5) * 0.5, z + cote * 1.0), pierre, dossier)
				# Les baies hautes, vides.
				if haut > 9.0:
					_boite(Vector3(2.0, 3.6, 1.7), Vector3(x + 4.5, y + haut - 3.0, z), sombre, dossier, false)
			x += 9.0
	# Les murs du transept et du chœur, et l'abside en demi-cercle.
	for seg in [[Vector2(20, -17), Vector2(20, -44)], [Vector2(42, -44), Vector2(42, -17)], [Vector2(20, 17), Vector2(20, 44)],
			[Vector2(42, 44), Vector2(42, 17)], [Vector2(42, -17), Vector2(76, -17)], [Vector2(42, 17), Vector2(76, 17)]]:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var haut := hasard.randf_range(6.0, 12.0)
		var mur := _boite(Vector3(a.distance_to(b), haut, 1.6), Vector3((a.x + b.x) * 0.5, y + haut * 0.5, (a.y + b.y) * 0.5), noir, dossier)
		mur.rotation.y = -(b - a).angle()
	for k in 9:
		var a := -PI / 2 + k * PI / 8
		var q := ABSIDE + Vector2(cos(a), sin(a)) * RAYON_ABSIDE
		var haut := hasard.randf_range(4.0, 11.0)
		var pan := _boite(Vector3(7.0, haut, 1.6), Vector3(q.x, y + haut * 0.5, q.y), noir if k % 2 == 0 else pierre, dossier)
		pan.rotation.y = -a + PI / 2
	# Le bout sud du transept : un mur ; le bout nord : l'entrée de la crypte (escalier, porte).
	_boite(Vector3(22.0, 9.0, 1.6), Vector3(31.0, y + 4.5, 44.0), noir, dossier)
	for cote: float in [-1.0, 1.0]:
		_boite(Vector3(8.0, 9.0, 1.6), Vector3(31.0 + cote * 7.0, y + 4.5, -44.0), noir, dossier)
	_boite(Vector3(6.0, 2.0, 1.8), Vector3(31.0, y + 7.0, -44.0), pierre, dossier)
	for k in 5:
		_boite(Vector3(5.0, 0.3, 1.0), Vector3(31.0, y + 0.15 - k * 0.3, -46.0 - k * 1.0), pierre, dossier, false)
	var porte_crypte := _boite(Vector3(4.0, 3.0, 0.3), Vector3(31.0, y + 0.5, -51.2), _mat_uni_ma(Color(0.18, 0.16, 0.15), 0.4), dossier)
	porte_crypte.name = "PorteCrypte"
	for cote: float in [-1.0, 1.0]:
		_boite(Vector3(1.0, 4.0, 6.0), Vector3(31.0 + cote * 3.0, y + 0.5, -48.0), pierre, dossier)
	# Les moignons des piliers brûlés, et les poutres calcinées par terre.
	for k in 8:
		for cote: float in [-1.0, 1.0]:
			var q := Vector2(NEF.position.x + 17.0 + k * 9.0, cote * 7.0)
			var neuf := false
			for b: Vector2 in BASES:
				neuf = neuf or q.distance_to(b) < 1.0
			if neuf:
				continue
			var pilier := MeshInstance3D.new()
			var haut := hasard.randf_range(1.5, 7.0)
			pilier.mesh = _cylindre(0.9, 1.0, haut, 10)
			pilier.material_override = noir
			pilier.position = Vector3(q.x, y + haut * 0.5, q.y)
			dossier.add_child(pilier)
	for k in 18:
		var q := Vector2(hasard.randf_range(NEF.position.x + 14.0, 70.0), hasard.randf_range(-14.0, 14.0))
		if q.distance_to(GRUE) < 7.0 or q.distance_to(ARRIVEE) < 8.0 or absf(q.y) < 3.0:
			continue
		var poutre := _boite(Vector3(0.5, 0.5, hasard.randf_range(4.0, 9.0)), Vector3(q.x, y + 0.5, q.y), noir, dossier, false)
		poutre.rotation = Vector3(hasard.randf_range(-0.2, 0.2), hasard.randf() * PI, hasard.randf_range(-0.15, 0.15))
	_fusionner(dossier)
	# Un peu de fumée qui monte encore du chœur.
	var fumee := StandardMaterial3D.new()
	fumee.albedo_color = Color(0.32, 0.3, 0.3, 0.08)
	fumee.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fumee.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var colonne := MeshInstance3D.new()
	colonne.mesh = _cylindre(10.0, 3.0, 60.0, 10)
	colonne.material_override = fumee
	colonne.position = Vector3(60, y + 32.0, 0)
	colonne.rotation.z = -0.2
	colonne.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_contenu.add_child(colonne)


# --- Les échafaudages, la grue, les bases des piliers ----------------------------------------------

## Un échafaudage de perches et de planches (comme au Moyen Âge : des perches liées, des
## boulins enfoncés dans les murs, des claies pour marcher).
func _echafaudage_bois(parent: Node3D, p: Vector2, angle: float, haut := 9.0, large := 6.0) -> Node3D:
	var m := Node3D.new()
	m.name = "Echafaudage%d" % parent.get_child_count()
	m.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
	m.rotation.y = angle
	parent.add_child(m)
	var bois := _mat_colombage()
	for c in 4:
		var poteau := MeshInstance3D.new()
		poteau.mesh = _cylindre(0.08, 0.1, haut, 6)
		poteau.material_override = bois
		poteau.position = Vector3(-large * 0.5 if c < 2 else large * 0.5, haut * 0.5, -0.9 if c % 2 == 0 else 0.9)
		m.add_child(poteau)
	var etages := int(haut / 2.5)
	for e in etages:
		var y := 2.5 * (e + 1)
		_boite(Vector3(large + 0.4, 0.08, 1.9), Vector3(0, y, 0), bois, m, false)
		for c: float in [-1.0, 1.0]:
			_boite(Vector3(large, 0.08, 0.08), Vector3(0, y + 0.9, c * 0.9), bois, m, false)
	for c: float in [-1.0, 1.0]:
		var diag := _boite(Vector3(0.08, haut * 1.05, 0.08), Vector3(0, haut * 0.5, c * 0.9), bois, m, false)
		diag.rotation.z = atan2(large, haut) * c
	var echelle := _boite(Vector3(0.5, haut, 0.08), Vector3(large * 0.5 + 0.4, haut * 0.5, 0), bois, m, false)
	echelle.rotation.z = 0.12
	return m


func _construire_echafaudages() -> void:
	var dossier := Node3D.new()
	dossier.name = "Echafaudages"
	_contenu.add_child(dossier)
	# Contre les murs de la nef, et autour des trois échafaudages sabotés (chapitre 7).
	for k in 4:
		_echafaudage_bois(dossier, Vector2(NEF.position.x + 22.0 + k * 20.0, 13.5), 0.0, 10.0)
		_echafaudage_bois(dossier, Vector2(NEF.position.x + 30.0 + k * 20.0, -13.5), 0.0, 8.0)
	for q: Vector2 in ETAIS:
		_echafaudage_bois(dossier, q + Vector2(0, -1.6 if q.y > 0.0 else 1.6), 0.0, 12.0, 5.0)
	_fusionner(dossier)
	# Les bases des nouveaux piliers : un socle de pierre blonde, et une pile de blocs prêts.
	var bases := Node3D.new()
	bases.name = "Bases"
	_contenu.add_child(bases)
	for q: Vector2 in BASES:
		var socle := MeshInstance3D.new()
		socle.mesh = _cylindre(1.3, 1.4, 0.8, 16)
		socle.material_override = _mat_calcaire()
		socle.position = Vector3(q.x, SOL + 0.1, q.y)
		bases.add_child(socle)
	# Le pilier qui monte quand on pose les blocs (« PilierN », caché au début).
	for k in BASES.size():
		var q: Vector2 = BASES[k]
		var pilier := MeshInstance3D.new()
		pilier.name = "Pilier%d" % k
		pilier.mesh = _cylindre(0.95, 1.05, 2.4, 16)
		pilier.material_override = _mat_calcaire()
		pilier.position = Vector3(q.x, SOL + 1.6, q.y)
		pilier.add_to_group("decor_quete")
		pilier.set_meta("identifiant", "pilier_%d" % k)
		pilier.visible = false
		_contenu.add_child(pilier)
	# La grue à roue d'écureuil, dans la nef.
	_roue = _roue_ecureuil(_contenu, GRUE, PI / 2)


# --- La cour sud : la loge, les pierres marquées, le beffroi, la forge ------------------------------

func _construire_cour_sud() -> void:
	var dossier := Node3D.new()
	dossier.name = "CourSud"
	_contenu.add_child(dossier)
	var bois := _mat_colombage()
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 20
	# La loge des tailleurs : un long appentis ouvert vers le nord, des établis.
	var r := LOGE
	var y := hauteur(r.get_center().x, r.get_center().y)
	_boite(Vector3(r.size.x, 4.0, 0.5), Vector3(r.get_center().x, y + 2.0, r.end.y), _mat_torchis_chaux(), dossier)
	for c: float in [-1.0, 1.0]:
		_boite(Vector3(0.5, 4.0, r.size.y), Vector3(r.get_center().x + c * r.size.x * 0.5, y + 2.0, r.get_center().y), _mat_torchis_chaux(), dossier)
	for k in 6:
		var poteau := MeshInstance3D.new()
		poteau.mesh = _cylindre(0.12, 0.14, 3.2, 6)
		poteau.material_override = bois
		poteau.position = Vector3(r.position.x + 2.0 + k * (r.size.x - 4.0) / 5.0, y + 1.6, r.position.y)
		dossier.add_child(poteau)
	var toit := _boite(Vector3(r.size.x + 1.0, 0.25, r.size.y + 2.0), Vector3(r.get_center().x, y + 3.8, r.get_center().y), _mat_tuiles_plates(), dossier, false)
	toit.rotation.x = -0.16
	for k in 4:
		var q := Vector2(r.position.x + 5.0 + k * 6.5, r.get_center().y + 1.0)
		_boite(Vector3(2.4, 0.9, 1.2), Vector3(q.x, y + 0.45, q.y), bois, dossier)
		_boite(Vector3(0.8, 0.5, 0.6), Vector3(q.x + 0.3, y + 1.15, q.y), _mat_calcaire(), dossier, false)
	# La table des plans : une planche de plâtre où Gautier dessine.
	_boite(Vector3(2.6, 0.9, 1.6), Vector3(PLANS.x, hauteur(PLANS.x, PLANS.y) + 0.45, PLANS.y), bois, dossier)
	var platre := _boite(Vector3(2.2, 0.05, 1.3), Vector3(PLANS.x, hauteur(PLANS.x, PLANS.y) + 0.93, PLANS.y), _mat_uni_ma(Color(0.92, 0.9, 0.84), 0.9), dossier, false)
	platre.rotation.y = 0.05
	# Les tas de pierres taillées, marquées, prêtes à monter.
	for k in 14:
		var q := PIERRES + Vector2(hasard.randf_range(-14.0, 14.0), hasard.randf_range(-8.0, 8.0))
		var b := _boite(Vector3(1.4, 0.7, 0.9), Vector3(q.x, hauteur(q.x, q.y) + 0.35 + (k % 3) * 0.7, q.y), _mat_calcaire(), dossier)
		b.rotation.y = hasard.randf_range(-0.2, 0.2)
	# Le beffroi : une tour de charpente, et la cloche fêlée (nœud « Cloche »).
	var yb := hauteur(BEFFROI.x, BEFFROI.y)
	for c in 4:
		var q := BEFFROI + Vector2(-2.0 if c < 2 else 2.0, -2.0 if c % 2 == 0 else 2.0)
		_boite(Vector3(0.35, 10.0, 0.35), Vector3(q.x, yb + 5.0, q.y), bois, dossier)
	for h: float in [3.0, 6.5, 9.8]:
		_boite(Vector3(4.4, 0.25, 4.4), Vector3(BEFFROI.x, yb + h, BEFFROI.y), bois, dossier, false)
	var toit_b := MeshInstance3D.new()
	toit_b.mesh = _cylindre(0.1, 3.4, 3.0, 4)
	toit_b.material_override = _mat_tuiles_plates()
	toit_b.position = Vector3(BEFFROI.x, yb + 11.5, BEFFROI.y)
	toit_b.rotation.y = PI / 4
	dossier.add_child(toit_b)
	_cloche = Node3D.new()
	_cloche.name = "Cloche"
	_cloche.position = Vector3(BEFFROI.x, yb + 9.6, BEFFROI.y)
	_contenu.add_child(_cloche)
	var bronze := _mat_uni_ma(Color(0.5, 0.38, 0.2), 0.35)
	bronze.metallic = 0.85
	var cloche := MeshInstance3D.new()
	cloche.mesh = _cylindre(0.55, 0.95, 1.3, 16)
	cloche.material_override = bronze
	cloche.position = Vector3(0, -0.7, 0)
	_cloche.add_child(cloche)
	# La forge : un appentis, l'enclume, le foyer.
	_chaumiere(dossier, FORGE + Vector2(6, 0), Vector3(5.0, 2.8, 7.0), PI / 2)
	_boite(Vector3(0.6, 0.8, 0.4), Vector3(FORGE.x, hauteur(FORGE.x, FORGE.y) + 0.4, FORGE.y), _mat_uni_ma(Color(0.15, 0.15, 0.16), 0.4), dossier)
	_brasero(dossier, FORGE + Vector2(-2.5, 1.5))
	for q: Vector2 in [Vector2(-50, 24), Vector2(-6, 24), Vector2(22, 50), Vector2(-20, 60)]:
		_brasero(dossier, q)
	_fusionner(dossier)


## Un brasero : une corbeille de fer sur trois pieds, des braises, une lueur.
func _brasero(parent: Node3D, p: Vector2) -> void:
	var y := hauteur(p.x, p.y)
	var fer := _mat_uni_ma(Color(0.14, 0.13, 0.13), 0.5)
	for k in 3:
		var a := k * TAU / 3.0
		var pied := _boite(Vector3(0.06, 1.1, 0.06), Vector3(p.x + cos(a) * 0.3, y + 0.5, p.y + sin(a) * 0.3), fer, parent, false)
		pied.rotation = Vector3(sin(a) * 0.25, 0, -cos(a) * 0.25)
	var corbeille := MeshInstance3D.new()
	corbeille.mesh = _cylindre(0.45, 0.25, 0.4, 10)
	corbeille.material_override = fer
	corbeille.position = Vector3(p.x, y + 1.1, p.y)
	parent.add_child(corbeille)
	var braise := StandardMaterial3D.new()
	braise.albedo_color = Color(1.0, 0.45, 0.12)
	braise.emission_enabled = true
	braise.emission = Color(1.0, 0.4, 0.1)
	braise.emission_energy_multiplier = 3.0
	var dessus := MeshInstance3D.new()
	dessus.mesh = _cylindre(0.4, 0.4, 0.06, 10)
	dessus.material_override = braise
	dessus.position = Vector3(p.x, y + 1.3, p.y)
	parent.add_child(dessus)
	var lumiere := OmniLight3D.new()
	lumiere.light_color = Color(1.0, 0.6, 0.3)
	lumiere.light_energy = 1.6
	lumiere.omni_range = 8.0
	lumiere.position = Vector3(p.x, y + 1.8, p.y)
	parent.add_child(lumiere)


# --- La cour nord : l'atelier des verriers -----------------------------------------------------------

func _construire_cour_nord() -> void:
	var dossier := Node3D.new()
	dossier.name = "CourNord"
	_contenu.add_child(dossier)
	var r := ATELIER
	var y := hauteur(r.get_center().x, r.get_center().y)
	# Un grand appentis de bois ouvert au sud.
	_boite(Vector3(r.size.x, 4.6, 0.5), Vector3(r.get_center().x, y + 2.3, r.position.y), _mat_torchis_chaux(), dossier)
	for c: float in [-1.0, 1.0]:
		_boite(Vector3(0.5, 4.6, r.size.y), Vector3(r.get_center().x + c * r.size.x * 0.5, y + 2.3, r.get_center().y), _mat_torchis_chaux(), dossier)
	var toit := _boite(Vector3(r.size.x + 1.0, 0.25, r.size.y + 2.0), Vector3(r.get_center().x, y + 4.4, r.get_center().y), _mat_tuiles_plates(), dossier, false)
	toit.rotation.x = 0.16
	# Les deux fours : des dômes de terre cuite, une gueule qui rougeoie.
	var terre := _mat_uni_ma(Color(0.5, 0.32, 0.22), 1.0)
	var feu := StandardMaterial3D.new()
	feu.albedo_color = Color(1.0, 0.55, 0.15)
	feu.emission_enabled = true
	feu.emission = Color(1.0, 0.5, 0.12)
	feu.emission_energy_multiplier = 4.0
	for q: Vector2 in [FOUR, FOUR + Vector2(12, 0)]:
		var dome := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 1.8
		sphere.height = 2.8
		dome.mesh = sphere
		dome.material_override = terre
		dome.position = Vector3(q.x, y + 0.6, q.y)
		dossier.add_child(dome)
		var gueule := _boite(Vector3(0.8, 0.6, 0.1), Vector3(q.x, y + 0.9, q.y + 1.72), feu, dossier, false)
		gueule.name = "Gueule"
		var lumiere := OmniLight3D.new()
		lumiere.light_color = Color(1.0, 0.55, 0.25)
		lumiere.light_energy = 2.0
		lumiere.omni_range = 7.0
		lumiere.position = Vector3(q.x, y + 1.2, q.y + 2.4)
		dossier.add_child(lumiere)
	# L'établi des verriers : des plaques de verre de couleur, les cannes, le sable.
	var bois := _mat_colombage()
	_boite(Vector3(3.0, 0.9, 1.2), Vector3(r.position.x + 6.0, y + 0.45, r.end.y - 3.0), bois, dossier)
	var couleurs := [Color(0.1, 0.22, 0.75), Color(0.7, 0.1, 0.08), Color(0.8, 0.62, 0.1), Color(0.1, 0.5, 0.22)]
	for k in 4:
		var verre := _mat_uni_ma(couleurs[k], 0.15)
		verre.emission_enabled = true
		verre.emission = couleurs[k]
		verre.emission_energy_multiplier = 0.5
		_boite(Vector3(0.5, 0.02, 0.4), Vector3(r.position.x + 4.8 + k * 0.7, y + 0.92, r.end.y - 3.0), verre, dossier, false)
	var tas := MeshInstance3D.new()
	tas.mesh = _cylindre(0.1, 1.4, 0.8, 12)
	tas.material_override = _mat_uni_ma(Color(0.86, 0.8, 0.66), 1.0)
	tas.position = Vector3(r.end.x - 4.0, y + 0.4, r.end.y - 4.0)
	dossier.add_child(tas)
	_brasero(dossier, AUDE + Vector2(4, 2))
	_fusionner(dossier)


# --- La palissade du chantier, le paysage -------------------------------------------------------------

func _construire_palissade() -> void:
	var dossier := Node3D.new()
	dossier.name = "Palissade"
	_contenu.add_child(dossier)
	var bois := _mat_colombage()
	var d := 104.0
	for seg in [[Vector2(-d, -d), Vector2(d, -d)], [Vector2(d, -d), Vector2(d, d)], [Vector2(d, d), Vector2(-d, d)],
			[Vector2(-d, d), Vector2(FACADE_X - 12.0, 20.0)], [Vector2(FACADE_X - 12.0, -20.0), Vector2(-d, -d)]]:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var n := int(a.distance_to(b) / 0.6)
		for k in n:
			var q := a.lerp(b, (k + 0.5) / n)
			_boite(Vector3(0.36, 3.2 + 0.3 * ((k * 7) % 3), 0.36), Vector3(q.x, hauteur(q.x, q.y) + 1.4, q.y), bois, dossier, false)
		var mur := _mur_invisible(dossier, Vector3(a.distance_to(b), 6.0, 0.8), Vector3((a.x + b.x) * 0.5, SOL + 2.0, (a.y + b.y) * 0.5))
		mur.rotation.y = -(b - a).angle()
	_fusionner(dossier)
	# Au-delà de la palissade : les toits de la ville, plus bas.
	var toits := Node3D.new()
	toits.name = "Ville"
	_contenu.add_child(toits)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 50
	for k in 40:
		var a := hasard.randf() * TAU
		var q := Vector2(cos(a), sin(a)) * hasard.randf_range(114.0, 136.0)
		_maison_pans_de_bois(toits, q, Vector3(6.0, hasard.randf_range(5.0, 7.0), 8.0), a + PI / 2, false)
	_fusionner(toits)


func _construire_lointain() -> void:
	_plan_lointain_autour(SOL - 6.0, Color(0.05, 0.4, 0.55))


func _construire_limites() -> void:
	var limites := Node3D.new()
	limites.name = "Limites"
	_contenu.add_child(limites)
	var demi := taille_terrain * 0.5 - 4.0
	_mur_invisible(limites, Vector3(2, 120, taille_terrain), Vector3(-demi, 40, 0))
	_mur_invisible(limites, Vector3(2, 120, taille_terrain), Vector3(demi, 40, 0))
	_mur_invisible(limites, Vector3(taille_terrain, 120, 2), Vector3(0, 40, -demi))
	_mur_invisible(limites, Vector3(taille_terrain, 120, 2), Vector3(0, 40, demi))


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
	# Chapitre 6 : Gautier, les bases des piliers, la grue, Aude et le premier bleu.
	_pnj(dossier, "maitre_gautier", GAUTIER, 0.0)
	for k in BASES.size():
		_objet(dossier, "bloc_pilier_%d" % k, BASES[k] + Vector2(0, 2.2), "", "[F] Graver ta marque et poser le bloc", "bloc_pilier", 2.4)
	_objet(dossier, "grue_chantier", GRUE + Vector2(0, 2.2), "", "[F] Marcher dans la roue de la grue", "", 3.0)
	_pnj(dossier, "aude", AUDE, PI)
	for k in CENDRES.size():
		_objet(dossier, "cendres_fougere_%d" % k, CENDRES[k], "sac_farine", "[F] Prendre le sac de cendres de fougère", "cendres_fougere")
	_objet(dossier, "four_verrier", FOUR + Vector2(0, 2.6), "", "[F] Souffler le verre avec Aude", "", 2.6)
	_objet(dossier, "plans_corriges", PLANS + Vector2(0, 1.2), "", "[F] Regarder les plans sur la planche de plâtre", "", 2.2)
	# Les tailleurs et les maçons du chantier.
	for k in 4:
		_pnj(dossier, "tailleur_%d" % (k + 1), Vector2(LOGE.position.x + 5.0 + k * 6.5, LOGE.get_center().y - 0.8), PI)
	_pnj(dossier, "fondeur_cloche", BEFFROI + Vector2(-3, -4), PI * 0.8)
	# Chapitre 7 : le roi, le chroniqueur, les gardes, les échafaudages sabotés, Plomb.
	_pnj_cache(dossier, "philippe_auguste", ROI, PI / 2)
	_pnj_cache(dossier, "guillaume_le_breton", ROI + Vector2(-2, 3), PI / 2)
	_pnj_cache(dossier, "garde_roi_1", ROI + Vector2(-4, -2), PI / 2)
	_pnj_cache(dossier, "garde_roi_2", ROI + Vector2(-5, 2), PI / 2)
	for k in ETAIS.size():
		var e := _objet(dossier, "etai_sabote_%d" % k, ETAIS[k], "larme_plomb", "[F] Arracher le plomb fondu coulé dans les attaches", "etai_sabote")
		e.add_to_group("decor_quete")
		e.set_meta("identifiant", "etai_sabote_%d" % k)
		e.visible = false
	_pnj_cache(dossier, "plomb_demasquee", PLOMB + Vector2(0, -3), PI)
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.LIEU, "Portail royal (vers le parvis)", SORTIE_CHARTRES)
	repere.call(MarqueurCarte.Type.LIEU, "Nef", Vector2(-30, 0))
	repere.call(MarqueurCarte.Type.LIEU, "Chœur", Vector2(60, 0))
	repere.call(MarqueurCarte.Type.LIEU, "Loge des tailleurs", LOGE.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Atelier des verriers", ATELIER.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Beffroi", BEFFROI)
	repere.call(MarqueurCarte.Type.DANGER, "Crypte", CRYPTE)


# --- La roue, la cloche, la sortie ------------------------------------------------------------------

var _attente := 0.0
var _vitesse_roue := 0.0
var _temps_chantier := 0.0


func _process(delta: float) -> void:
	super._process(delta)
	_temps_chantier += delta
	if _roue != null and is_instance_valid(_roue) and _vitesse_roue > 0.0:
		_roue.get_node("Roue").rotation.x += delta * _vitesse_roue
	if _cloche != null and is_instance_valid(_cloche):
		_cloche.rotation.z = sin(_temps_chantier * 1.4) * 0.05
	if Engine.is_editor_hint():
		return
	_attente -= delta
	if _attente > 0.0:
		return
	_attente = 0.3
	var quete := get_tree().get_first_node_in_group("quete")
	if quete == null or not quete.has_method("etape_atteinte"):
		return
	_vitesse_roue = 0.35 if quete.etape_atteinte("aude_atelier") else 0.0
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return
	var p := Vector2(joueur.global_position.x, joueur.global_position.z)
	if p.distance_to(SORTIE_CHARTRES) < 2.5 and quete.donnees.get("zones", {}).has("chartres"):
		Reseau.set_meta("arrivee_moyen_age", "chantier")
		quete.changer_de_zone("chartres")
