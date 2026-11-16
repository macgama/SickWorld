@tool
extends "res://scripts/monde/rome/ile_rome.gd"
## Île de Rome, zone 4 : Pompéi sous la cendre (niveaux 37-40).
##
## Un an après l'éruption, au bout de la voie Appienne : une ville entière enfouie sous
## six mètres de cendre grise. Seuls dépassent le faîte des toits, le haut des colonnes du
## Forum, le fronton du temple de Jupiter, le bord de l'amphithéâtre et les tours du
## rempart. Des pilleurs creusent des puits pour descendre dans les maisons. Au sud-est, le
## Vésuve fume encore, et une cendre fine tombe sans arrêt. Gris, silencieux, inquiétant.
##
## On arrive au nord, par la route de Rome. Deux fouilles : la maison de Caecilia (la
## marchande de vin réfugiée, au chapitre 1) et le dessous du Forum, où dort le vieux
## matériel de Damien Roche, perdu il y a dix ans.
##
## Tout est construit par le code (voir ile_rome.gd). Repères : le nord est vers -Z.

const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const ObjetRome := preload("res://scripts/monde/rome/objet_rome.gd")

const SOCLE := 8.0
## La cendre recouvre tout jusqu'à cette hauteur (au-dessus des rues d'avant l'éruption).
const CENDRE := 6.0
const ROUTE := [Vector2(0, -162), Vector2(4, -120), Vector2(2, -80), Vector2(-6, -30)]
const ENTREE := Vector2(0, -146)
const SORTIE_NORD := Vector2(0, -156)
## Les fouilles : on y descend par des pentes de cendre, jusqu'aux rues de 79.
const MAISON := Rect2(-52, -66, 30, 26)
const FORUM_FOSSE := Rect2(14, 2, 36, 30)
const PENTE := 11.0
## Le Forum (sous la cendre) et ce qui en dépasse.
const FORUM := Rect2(0, -20, 70, 36)
const TEMPLE_JUPITER := Vector2(34, -26)
const AMPHITHEATRE := Vector2(110, 70)
const AMPHI_AXES := Vector2(40, 30)
const VESUVE := Vector3(900, 0, -1500)

const PLINE := ENTREE + Vector2(4, 8)
const PILLEURS := Vector2(-36, -80)
const MARQUE := Vector2(-48.5, -50)
const SECOUSSE := Vector2(10, -6)
const MATERIEL := Vector2(40, 22)
const MASQUE := MATERIEL + Vector2(-6, -3)
const VERA := Vector2(30, 6)
const PLINE_FORUM := Vector2(22, 8)

var _attente_sortie := 0.0
var _hasard := RandomNumberGenerator.new()


func _init() -> void:
	identifiant_zone = "pompei"
	taille_terrain = 320
	graine = 79
	point_apparition = ENTREE + Vector2(0, 4)
	nombre_touffes = 3000
	neige_qui_tombe = true
	sols = {
		"galets": ["cobblestone_floor_04", "dry_ground_rocks", "dry_ground_01"],
		"neige": ["dry_ground_01", "brown_mud_02", "dry_ground_rocks"],
		"sol": ["dry_ground_01", "mud_cracked_dry_03", "brown_mud_02"],
		"roche": ["rock_boulder_dry", "cliff_side", "rock_wall_10"],
	}
	reglages_terrain = {"sol_saturation": 0.08, "sol_motif": 3.0, "galets_motif": 3.0, "neige_motif": 5.0,
			"sol_teinte": Color(0.78, 0.77, 0.75), "roche_teinte": Color(0.7, 0.68, 0.66), "roche_saturation": 0.15,
			"neige_eclat": 1.0, "neige_paillettes": 0.0, "roche_motif": 8.0,
			"neige_teinte": Color(0.66, 0.65, 0.63), "neige_max": Vector3(0.4, 0.4, 0.39), "neige_simple": Color(0.45, 0.44, 0.43),
			"givre": 0.0, "neige_translucide": 0.0}
	reglages_herbe = {"couleur_base": Color(0.3, 0.3, 0.26), "couleur_pointe": Color(0.5, 0.5, 0.42),
			"couleur_givre": Color(0.55, 0.55, 0.5), "force_vent": 0.2}
	piste = ROUTE.duplicate()


func _ready() -> void:
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_rome", "") != "":
		Reseau.remove_meta("arrivee_rome")
		point_apparition = ENTREE + Vector2(0, 4)
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	return Vector2.INF if zone == "pompei" else SORTIE_NORD + Vector2(0, 6)


# --- Relief -----------------------------------------------------------------------------

func _preparer_bruits() -> void:
	super._preparer_bruits()
	_relief.frequency = 0.012


func distance_route(p: Vector2) -> float:
	var meilleure := INF
	for i in ROUTE.size() - 1:
		meilleure = minf(meilleure, _distance_segment(p, ROUTE[i], ROUTE[i + 1]))
	return meilleure


## De 0 (sur la cendre) à 1 (au fond d'une fouille, sur les dalles de 79).
func fouille(x: float, z: float) -> float:
	return maxf(_dans_rect(MAISON, x, z, PENTE), _dans_rect(FORUM_FOSSE, x, z, PENTE))


func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	var bruit := _relief.get_noise_2d(x, z)
	var fin := _details.get_noise_2d(x * 3.0, z * 3.0)
	var p := Vector2(x, z)
	# La cendre : des dunes molles, soufflées par le vent du volcan.
	var h := CENDRE + bruit * 1.6 + fin * 0.15
	# La route de Rome, tassée par les charrettes des pilleurs.
	h = lerpf(h, CENDRE + 0.2 + bruit * 0.4, 1.0 - smoothstep(3.0, 8.0, distance_route(p)))
	# Les fouilles des pilleurs : des pentes de cendre jusqu'aux rues d'avant.
	h = lerpf(h, 0.2 + fin * 0.05, fouille(x, z))
	return h + SOCLE


func _parts_sol(x: float, z: float, h: float) -> Color:
	var fond := smoothstep(0.75, 0.95, fouille(x, z))
	var route := (1.0 - smoothstep(2.5, 5.0, distance_route(Vector2(x, z)))) * (1.0 - fond)
	return Color(fond, route * 0.6, maxf(0.001, 1.0 - fond - route * 0.6), 1.0)


# --- Construction -------------------------------------------------------------------------

func reconstruire() -> void:
	_hasard.seed = graine
	_commencer()
	_construire_terrain()
	_construire_toits()
	_construire_forum()
	_construire_maison()
	_construire_fosse_forum()
	_construire_amphitheatre()
	_construire_rempart()
	_construire_touffes()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_construire_cendre_qui_tombe()
	_appliquer_ciel()


## Une cendre fine qui tombe tout le temps : la neige de la Préhistoire, en gris et plus lente.
func _construire_cendre_qui_tombe() -> void:
	_construire_neige_qui_tombe()
	if _neige == null:
		return
	_neige.name = "Cendre"
	_neige.amount = 4000
	var flocon := _neige.draw_pass_1 as QuadMesh
	var m := flocon.material as StandardMaterial3D
	m.albedo_color = Color(0.55, 0.54, 0.52, 0.7)
	var processus := _neige.process_material as ParticleProcessMaterial
	processus.initial_velocity_min = 0.3
	processus.initial_velocity_max = 0.7
	processus.gravity = Vector3(0.3, -0.5, 0.1)


## Le faîte des toits qui dépasse de la cendre, à perte de vue, en îlots réguliers.
func _construire_toits() -> void:
	var toits := Node3D.new()
	toits.name = "ToitsEnsevelis"
	_contenu.add_child(toits)
	var tuiles := _mat_tuiles()
	var x := -148.0
	while x < 148.0:
		var z := -148.0
		while z < 148.0:
			var p := Vector2(x + _hasard.randf_range(-2.0, 2.0), z + _hasard.randf_range(-2.0, 2.0))
			z += 18.0
			if distance_route(p) < 9.0 or fouille(p.x, p.y) > 0.0 or _dans_rect(FORUM.grow(6.0), p.x, p.y, 0.1) > 0.5 \
					or _dans_ellipse(p, AMPHITHEATRE, AMPHI_AXES + Vector2(8, 8)) or _hasard.randf() < 0.3:
				continue
			# Un toit à deux pans dont seul le faîte sort de la cendre.
			var largeur := _hasard.randf_range(8.0, 12.0)
			var longueur := _hasard.randf_range(9.0, 14.0)
			var t := Node3D.new()
			t.position = Vector3(p.x, hauteur(p.x, p.y) - _hasard.randf_range(1.2, 2.2), p.y)
			t.rotation.y = (PI / 2 if _hasard.randf() < 0.5 else 0.0) + _hasard.randf_range(-0.06, 0.06)
			toits.add_child(t)
			_toit(t, Vector3.ZERO, largeur, longueur, 0.42)
			# Parfois, le haut d'un mur peint, ou une cheminée de pilleur (un trou noir étayé).
			if _hasard.randf() < 0.25:
				_boite(Vector3(largeur * 0.8, 0.6, 0.4), Vector3(p.x, hauteur(p.x, p.y) + 0.1, p.y + longueur * 0.5), _mat_enduit_peint(Color(0.62, 0.16, 0.12)), toits, false)
		x += 18.0
	_fusionner(toits)


func _dans_ellipse(p: Vector2, centre: Vector2, axes: Vector2) -> bool:
	var d := p - centre
	return (d.x * d.x) / (axes.x * axes.x) + (d.y * d.y) / (axes.y * axes.y) <= 1.0


## Le Forum sous la cendre : le haut des colonnes du portique, et le temple de Jupiter
## dont le fronton dépasse, avec le Vésuve derrière.
func _construire_forum() -> void:
	var forum := Node3D.new()
	forum.name = "Forum"
	_contenu.add_child(forum)
	var marbre := _mat_travertin()
	# Les colonnes du portique, tout autour de la place : seul le chapiteau dépasse.
	var f := FORUM
	for k in 16:
		for bord in [f.position.y, f.end.y]:
			var x := f.position.x + 3.0 + k * (f.size.x - 6.0) / 15.0
			if fouille(x, bord) > 0.0:
				continue
			var c := MeshInstance3D.new()
			c.mesh = _cylindre(0.38, 0.42, 2.2, 10)
			c.material_override = marbre
			c.position = Vector3(x, hauteur(x, bord) + 0.4, bord)
			forum.add_child(c)
			_boite(Vector3(1.0, 0.35, 1.0), Vector3(x, hauteur(x, bord) + 1.6, bord), marbre, forum, false)
	# Le temple de Jupiter : enterré jusqu'au haut des colonnes. On voit l'entablement et
	# le fronton, à ras de cendre.
	var t := TEMPLE_JUPITER
	var y := hauteur(t.x, t.y)
	_boite(Vector3(17.0, 1.4, 30.0), Vector3(t.x, y + 0.3, t.y), marbre, forum)
	var fronton := MeshInstance3D.new()
	var prisme := PrismMesh.new()
	prisme.size = Vector3(17.2, 3.6, 0.8)
	fronton.mesh = prisme
	fronton.material_override = marbre
	fronton.position = Vector3(t.x, y + 2.8, t.y + 15.0)
	forum.add_child(fronton)
	var toit := Node3D.new()
	toit.position = Vector3(t.x, y + 1.0, t.y)
	forum.add_child(toit)
	_toit(toit, Vector3.ZERO, 17.4, 30.0, atan(0.42))
	for k in 6:
		var x := t.x - 7.0 + k * 2.8
		var c := MeshInstance3D.new()
		c.mesh = _cylindre(0.5, 0.55, 1.4, 12)
		c.material_override = marbre
		c.position = Vector3(x, y - 0.4, t.y + 15.6)
		forum.add_child(c)
	_fusionner(forum)


## La maison de Caecilia, la marchande de vin : un atrium avec son bassin, des murs peints
## en rouge pompéien, des amphores encore alignées, et la mosaïque du chien à l'entrée.
func _construire_maison() -> void:
	var maison := Node3D.new()
	maison.name = "MaisonCaecilia"
	_contenu.add_child(maison)
	var r := MAISON
	var y := 0.2 + SOCLE
	var rouge := _mat_enduit_peint(Color(0.6, 0.14, 0.1))
	var ocre := _mat_enduit_peint(Color(0.82, 0.6, 0.26))
	var haut := 3.6
	var c := r.get_center()
	# Les murs : un rectangle avec une porte au nord (côté de la pente des pilleurs).
	var murs := [
		[Vector3(r.size.x, haut, 0.5), Vector3(c.x, y + haut * 0.5, r.end.y), rouge],
		[Vector3(0.5, haut, r.size.y), Vector3(r.position.x, y + haut * 0.5, c.y), rouge],
		[Vector3(0.5, haut, r.size.y), Vector3(r.end.x, y + haut * 0.5, c.y), ocre],
		[Vector3(r.size.x * 0.4, haut, 0.5), Vector3(r.position.x + r.size.x * 0.2, y + haut * 0.5, r.position.y), rouge],
		[Vector3(r.size.x * 0.4, haut, 0.5), Vector3(r.end.x - r.size.x * 0.2, y + haut * 0.5, r.position.y), rouge],
	]
	for m in murs:
		_boite(m[0], m[1], m[2], maison)
	# Des cloisons intérieures (les chambres autour de l'atrium).
	_boite(Vector3(0.4, haut, 8.0), Vector3(r.position.x + 8.0, y + haut * 0.5, r.end.y - 4.0), ocre, maison)
	_boite(Vector3(0.4, haut, 8.0), Vector3(r.end.x - 8.0, y + haut * 0.5, r.end.y - 4.0), ocre, maison)
	# Une bande noire au bas des murs et une frise, comme sur les vraies fresques.
	_boite(Vector3(r.size.x - 0.2, 0.6, 0.54), Vector3(c.x, y + 0.3, r.end.y), _mat_pbr("", Color(0.08, 0.06, 0.05), 0.9), maison, false)
	_boite(Vector3(r.size.x - 0.2, 0.25, 0.54), Vector3(c.x, y + haut - 0.6, r.end.y), _mat_enduit_peint(Color(0.9, 0.82, 0.6)), maison, false)
	# L'atrium : le bassin (impluvium) au milieu, sec et plein de cendre.
	var bassin := _boite(Vector3(4.0, 0.3, 3.0), Vector3(c.x, y + 0.15, c.y), _mat_marbre(), maison)
	bassin.name = "Impluvium"
	_boite(Vector3(3.4, 0.05, 2.4), Vector3(c.x, y + 0.31, c.y), _mat_pbr("", Color(0.55, 0.54, 0.52), 1.0), maison, false)
	# La mosaïque « Cave canem » devant la porte : un chien noir sur fond blanc.
	_boite(Vector3(3.0, 0.04, 2.0), Vector3(c.x, y + 0.02, r.position.y + 1.6), _mat_pbr("", Color(0.86, 0.84, 0.78), 0.8), maison, false)
	_boite(Vector3(1.6, 0.05, 0.7), Vector3(c.x, y + 0.03, r.position.y + 1.6), _mat_pbr("", Color(0.08, 0.08, 0.08), 0.8), maison, false)
	# Les amphores de vin de Caecilia, alignées contre le mur du fond.
	for k in 9:
		_amphore(maison, Vector3(r.position.x + 3.0 + k * 1.1, y, r.end.y - 1.0))
	# Les étais des pilleurs : des poutres qui retiennent la cendre au bord du trou.
	for k in 4:
		var poteau := _boite(Vector3(0.25, 4.0, 0.25), Vector3(r.position.x + 4.0 + k * 7.0, y + 2.0, r.position.y - 2.0), _mat_bois(), maison)
		poteau.rotation.x = 0.25
	_fusionner(maison)


## Sous le Forum : le grand trou des pilleurs, une salle voûtée à moitié dégagée (le
## trésor de la ville, croient-ils), et le recoin où Roche s'était réfugié il y a dix ans.
func _construire_fosse_forum() -> void:
	var fosse := Node3D.new()
	fosse.name = "FosseForum"
	_contenu.add_child(fosse)
	var r := FORUM_FOSSE
	var y := 0.2 + SOCLE
	var tuf := _mat_tuf()
	var c := r.get_center()
	# Les piliers et les arches du portique enterré.
	for k in 6:
		var x := r.position.x + 3.0 + k * (r.size.x - 6.0) / 5.0
		_boite(Vector3(1.2, 5.0, 1.2), Vector3(x, y + 2.5, r.end.y - 2.0), _mat_travertin(), fosse)
	_boite(Vector3(r.size.x - 4.0, 1.0, 1.6), Vector3(c.x, y + 5.5, r.end.y - 2.0), _mat_travertin(), fosse, false)
	# Les murs de tuf de la salle du fond, et des blocs tombés.
	_boite(Vector3(r.size.x, 4.5, 0.8), Vector3(c.x, y + 2.25, r.end.y + 0.4), tuf, fosse)
	for k in 7:
		var b := _boite(Vector3(_hasard.randf_range(0.8, 1.8), _hasard.randf_range(0.5, 1.2), _hasard.randf_range(0.8, 1.6)),
				Vector3(_hasard.randf_range(r.position.x + 6.0, r.end.x - 6.0), y + 0.4, _hasard.randf_range(r.position.y + 8.0, r.end.y - 5.0)),
				_mat_travertin(), fosse)
		b.rotation = Vector3(_hasard.randf_range(-0.2, 0.2), _hasard.randf() * TAU, _hasard.randf_range(-0.2, 0.2))
	# Le recoin de Roche : un abri de fortune, une couverture brûlée, une lampe de la Vigie.
	var m := MATERIEL
	_boite(Vector3(2.4, 0.08, 1.6), Vector3(m.x - 1.5, y + 0.04, m.y + 1.0), _mat_pbr("", Color(0.18, 0.2, 0.22), 0.9), fosse, false)
	var lampe := _boite(Vector3(0.18, 0.3, 0.18), Vector3(m.x + 1.4, y + 0.15, m.y + 0.6), _mat_pbr("", Color(0.2, 0.22, 0.24), 0.5), fosse, false)
	lampe.name = "LampeVigie"
	_fusionner(fosse)


## L'amphithéâtre de Pompéi, à l'est : seul le haut de son mur d'enceinte sort de la cendre.
func _construire_amphitheatre() -> void:
	var amphi := Node3D.new()
	amphi.name = "Amphitheatre"
	_contenu.add_child(amphi)
	var n := 48
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := AMPHITHEATRE + Vector2(cos(a0) * AMPHI_AXES.x, sin(a0) * AMPHI_AXES.y)
		var p1 := AMPHITHEATRE + Vector2(cos(a1) * AMPHI_AXES.x, sin(a1) * AMPHI_AXES.y)
		var d := p1 - p0
		var m := (p0 + p1) * 0.5
		var mur := _boite(Vector3(1.4, 2.2, d.length() + 0.1), Vector3(m.x, hauteur(m.x, m.y) + 0.6, m.y), _mat_tuf(), amphi)
		mur.rotation.y = atan2(d.x, d.y)
		if i % 4 == 0:
			var arche := MeshInstance3D.new()
			arche.mesh = _maillage_arche(2.2, 1.4, 1.0)
			arche.material_override = _mat_deux_faces(_mat_tuf())
			arche.position = Vector3(m.x, hauteur(m.x, m.y) + 0.6, m.y)
			arche.rotation.y = atan2(d.x, d.y) - PI / 2
			amphi.add_child(arche)
	_fusionner(amphi)


## Le rempart du nord, avec ses tours, à demi enterré ; la route passe par une porte.
func _construire_rempart() -> void:
	var rempart := Node3D.new()
	rempart.name = "Rempart"
	_contenu.add_child(rempart)
	var z := -128.0
	var x := -150.0
	while x < 150.0:
		if absf(x - 4.0) > 10.0:
			var y := hauteur(x, z)
			_boite(Vector3(12.0, 2.0, 2.4), Vector3(x + 6.0, y + 0.5, z), _mat_tuf(), rempart)
		x += 12.0
	for tx in [-110.0, -60.0, 60.0, 110.0]:
		var y := hauteur(tx, z)
		_boite(Vector3(6.0, 5.0, 6.0), Vector3(tx, y + 1.5, z), _mat_tuf(), rempart)
		_boite(Vector3(0.7, 1.2, 0.1), Vector3(tx, y + 2.6, z + 3.02), _mat_pbr("", Color(0.05, 0.05, 0.05), 1.0), rempart, false)
	# La porte de la ville (la porte d'Herculanum) : deux piles et le haut de l'arche.
	for c in [-1.0, 1.0]:
		var px: float = 4.0 + c * 6.0
		_boite(Vector3(3.0, 4.0, 3.0), Vector3(px, hauteur(px, z) + 1.0, z), _mat_travertin(), rempart)
	var arche := MeshInstance3D.new()
	arche.mesh = _maillage_arche(9.0, 3.0, 2.2)
	arche.material_override = _mat_deux_faces(_mat_travertin())
	arche.position = Vector3(4.0, hauteur(4.0, z) + 3.0, z)
	arche.rotation.y = 0.0
	rempart.add_child(arche)
	_fusionner(rempart)


# --- Paysage lointain : le Vésuve et la baie --------------------------------------------------

func _construire_lointain() -> void:
	for bande: Array in [[Vector3(0, 2.8 + SOCLE, -1075), Vector2(4000, 1850)], [Vector3(0, 2.8 + SOCLE, 1075), Vector2(4000, 1850)],
			[Vector3(-1075, 2.8 + SOCLE, 0), Vector2(1850, 300)], [Vector3(1075, 2.8 + SOCLE, 0), Vector2(1850, 300)]]:
		_plan_lointain(bande[0], bande[1], Color(0, 0, 1))
	# Le Vésuve : un grand cône éventré, gris sombre, qui fume encore.
	var vesuve := MeshInstance3D.new()
	vesuve.name = "Vesuve"
	var cone := CylinderMesh.new()
	cone.top_radius = 140.0
	cone.bottom_radius = 900.0
	cone.height = 520.0
	cone.radial_segments = 48
	vesuve.mesh = cone
	# Assez loin pour que la brume de cendre l'avale : on le peint déjà « brumeux »
	# et il ignore le brouillard, pour qu'on voie toujours sa silhouette.
	var mat_vesuve: StandardMaterial3D = _mat_pbr("", Color(0.24, 0.23, 0.23), 1.0)
	mat_vesuve.disable_fog = true
	vesuve.material_override = mat_vesuve
	vesuve.position = VESUVE + Vector3(0, 250.0, 0)
	vesuve.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_contenu.add_child(vesuve)
	var panache := CPUParticles3D.new()
	panache.name = "Panache"
	panache.amount = 40
	panache.lifetime = 30.0
	panache.preprocess = 30.0
	panache.position = VESUVE + Vector3(0, 520.0, 0)
	panache.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	panache.emission_sphere_radius = 60.0
	panache.direction = Vector3(0, 1, 0)
	panache.spread = 15.0
	panache.gravity = Vector3(-4.0, 3.0, 2.0)
	panache.initial_velocity_min = 6.0
	panache.initial_velocity_max = 10.0
	var taille := Curve.new()
	taille.max_value = 4.0
	taille.add_point(Vector2(0, 1.0))
	taille.add_point(Vector2(1, 3.5))
	panache.scale_amount_curve = taille
	var teinte := Gradient.new()
	teinte.set_color(0, Color(0.3, 0.29, 0.28, 0.6))
	teinte.set_color(1, Color(0.6, 0.58, 0.56, 0.0))
	panache.color_ramp = teinte
	var boule := SphereMesh.new()
	boule.radius = 50.0
	boule.height = 80.0
	boule.radial_segments = 10
	boule.rings = 5
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	boule.material = mat
	panache.mesh = boule
	panache.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_contenu.add_child(panache)


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

func _construire_quete() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quete"
	_contenu.add_child(dossier)
	_dossier_quete = dossier
	_pnj(dossier, "pline", PLINE, PI)
	var masque := _pnj(dossier, "masque_pompei", MASQUE, PI * 0.25)
	masque.add_to_group("decor_quete")
	masque.set_meta("identifiant", "masque_pompei")
	masque.visible = false
	var vera := _pnj(dossier, "vera_pompei", VERA, PI * 0.8)
	vera.add_to_group("decor_quete")
	vera.set_meta("identifiant", "vera_pompei")
	vera.visible = false
	var marque := ObjetRome.new()
	marque.name = "MarqueVigie"
	marque.identifiant = "marque_vigie"
	marque.invite = "[F] Regarder les signes gravés dans l'enduit"
	marque.portee = 2.4
	marque.position = Vector3(MARQUE.x, hauteur(MARQUE.x, MARQUE.y) + 1.4, MARQUE.y)
	dossier.add_child(marque)
	# Les signes : un symbole de la Vigie gravé, qui brille un peu, cyan.
	var signe := MeshInstance3D.new()
	var plaque := BoxMesh.new()
	plaque.size = Vector3(0.05, 0.6, 0.6)
	signe.mesh = plaque
	var lueur := StandardMaterial3D.new()
	lueur.albedo_color = Color(0.3, 0.85, 1.0)
	lueur.emission_enabled = true
	lueur.emission = Color(0.3, 0.85, 1.0)
	lueur.emission_energy_multiplier = 1.5
	signe.material_override = lueur
	signe.position = Vector3(MAISON.position.x + 0.3, hauteur(MARQUE.x, MARQUE.y) + 1.6, MARQUE.y)
	dossier.add_child(signe)
	var materiel := ObjetRome.new()
	materiel.name = "MaterielRoche"
	materiel.identifiant = "materiel_roche"
	materiel.forme = "sac_voyage"
	materiel.invite = "[F] Dégager le sac de la cendre"
	materiel.portee = 2.4
	materiel.position = Vector3(MATERIEL.x, hauteur(MATERIEL.x, MATERIEL.y), MATERIEL.y)
	dossier.add_child(materiel)
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.LIEU, "Maison de Caecilia (fouille)", MAISON.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Forum (fouille)", FORUM_FOSSE.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Temple de Jupiter", TEMPLE_JUPITER)
	repere.call(MarqueurCarte.Type.LIEU, "Amphithéâtre", AMPHITHEATRE)
	repere.call(MarqueurCarte.Type.LIEU, "Vers la voie Appienne et Rome", SORTIE_NORD)


# --- La sortie : la route de Rome, au nord ---------------------------------------------------

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
	if p.y < SORTIE_NORD.y + 4.0 and absf(p.x - SORTIE_NORD.x) < 12.0:
		quete.changer_de_zone("voie_appienne")
