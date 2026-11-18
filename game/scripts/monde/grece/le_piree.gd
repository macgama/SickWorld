@tool
extends "res://scripts/monde/grece/ile_grece.gd"
## Île de Grèce, zone 1 : le Pirée (niveaux 20-22).
##
## L'été -438, le port d'Athènes, à 6 km de la ville. Au sud-ouest, la presqu'île
## rocheuse de l'Akté : le portail de la Vigie s'est ouvert dans une crique, où l'on
## arrive avec de l'eau jusqu'aux genoux. À l'est, le grand bassin du Kantharos : à
## l'ouest du bassin, les loges des trières (les hangars de la flotte de guerre), au
## nord le grand portique du commerce et ses amphores. Au nord-ouest, la ville du
## Pirée, tracée en damier par l'architecte Hippodamos. Tout au nord, la porte des
## Longs Murs : la route fortifiée qui mène à Athènes (ouverte au chapitre 3). Sur la
## colline de Mounichia, à l'est, le petit temple d'Artémis.
##
## Tout est construit par le code (voir ile_grece.gd). Le bouton « Reconstruire » de
## l'Inspecteur refait tout. Repères : le nord est vers -Z.

const Faille := preload("res://scripts/monde/prehistoire/faille.gd")
const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const TriereCadence := preload("res://scripts/monde/grece/triere_cadence.gd")
const ObjetGrece := preload("res://scripts/monde/grece/objet_grece.gd")

## Le portail de la Vigie, sur un rocher plat au milieu de la crique.
const PORTAIL := Vector2(-62, 124)
## Le creux d'eau peu profonde de la crique.
const CRIQUE := Vector2(-60, 128)
## Glaukos, le vieux pêcheur, sur la plage de la crique, et sa barque tirée au sec.
const GLAUKOS := Vector2(-50, 109)
const BARQUE_GLAUKOS := Vector2(-42, 113)
## Le sac de l'agent Markos, coincé dans les rochers.
const SAC_MARKOS := Vector2(-80, 107)
## Là où l'on plante la balise de la Vigie.
const BALISE := Vector2(-55, 106)
## Le haut-fond de la crique où le poulpe fracturé a pris les filets de Glaukos.
const POULPE := Vector2(-53, 135)
## La faille, dans les rochers de l'Akté.
const FAILLE := Vector2(-92, 94)
## Le chemin côtier, de la crique jusqu'au port.
const CHEMIN := [Vector2(-56, 104), Vector2(-48, 84), Vector2(-40, 62), Vector2(-32, 42), Vector2(-20, 28)]
## Le bassin du Kantharos (x, z, largeur, profondeur), sa passe vers la mer, la hauteur des quais.
const BASSIN := Rect2(22, -52, 88, 100)
const PASSE := Rect2(56, 40, 26, 40)
const QUAI := 1.8
## Les loges des trières : 6 hangars de 8 m côte à côte, qui descendent dans l'eau.
const LOGES := Rect2(-24, -38, 50, 48)
const LARGEUR_LOGE := 8.0
## L'agent Markos, retenu dans l'enclos des archers scythes, et son gardien.
const MARKOS := Vector2(-42, 22)
const ARCHER := Vector2(-37, 27)
## Lysimaque le rameur, devant les loges ; Phormion, le stratège, au fond de l'arsenal.
const LYSIMAQUE := Vector2(-4, 16)
const PHORMION := Vector2(-14, -46)
## La Paralos, la trière sacrée, amarrée au quai ouest du bassin, et le tour du bassin.
const TRIERE := Vector2(33, 26)
const EMBARQUER := Vector2(20.5, 26)
const TOUR_BASSIN := [Vector2(33, 26), Vector2(33, 0), Vector2(42, -30), Vector2(70, -40), Vector2(97, -24),
		Vector2(98, 10), Vector2(80, 32), Vector2(52, 37), Vector2(36, 32), Vector2(33, 26)]
## Les rameurs de la Paralos et l'aulète (le joueur de flûte qui donne la cadence).
const RAMEURS := [Vector2(16, 22), Vector2(15, 30), Vector2(18, 33), Vector2(14, 25)]
const AULETE := Vector2(17, 19)
## Le grand portique du commerce, au nord du bassin (milieu de la façade).
const EMPORION := Vector2(66, -63)
## La ville en damier, sa petite agora, et la porte des Longs Murs (vers Athènes).
const VILLE := Rect2(-140, -142, 112, 76)
const AGORA := Vector2(-86, -106)
const PORTE := Vector2(-50, -144)
## Le temple d'Artémis, sur la colline de Mounichia.
const TEMPLE := Vector2(142, -96)

var _mur_porte: StaticBody3D
var _porte_ouverte := false
var _attente_porte := 0.0


func _init() -> void:
	identifiant_zone = "le_piree"
	taille_terrain = 320
	graine = 438
	point_apparition = PORTAIL + Vector2(0, -6)
	nombre_touffes = 50000
	fertilite_sols = Vector3(0.1, 0.95, 0.0)
	reglages_couvre_sol = {"cailloux": 6.0, "fleurs": [Color(0.82, 0.1, 0.06), Color(0.95, 0.78, 0.12), Color(0.93, 0.91, 0.86)], "densite_fleurs": 1.0}
	neige_qui_tombe = false
	sols = {
		# Rouge : les galets et le sable des criques.
		"galets": ["damp_beach_sand", "clean_pebbles", "dry_river_pebbles", "damp_sand"],
		# Vert : la terre sèche et rouge de l'Attique, avec ses cailloux.
		"neige": ["dry_ground_rocks", "dry_ground_01", "red_sand"],
		# Bleu : la terre tassée des rues et des quais.
		"sol": ["dry_ground_rocks", "dry_ground_01", "mud_cracked_dry_03"],
		"roche": ["rock_boulder_dry", "cliff_side", "rock_wall_10"],
	}
	reglages_terrain = {"sol_saturation": 0.62, "sol_motif": 4.0, "galets_motif": 2.0, "neige_motif": 5.0,
			"sol_teinte": Color(1.0, 0.94, 0.86), "roche_teinte": Color(0.98, 0.95, 0.9), "roche_saturation": 0.7,
			"neige_eclat": 1.0, "neige_paillettes": 0.0, "roche_motif": 10.0,
			# La « neige » est ici la terre rouge et sèche de l'Attique.
			"neige_teinte": Color(1.05, 0.88, 0.72), "neige_max": Vector3(0.66, 0.52, 0.4), "neige_simple": Color(0.62, 0.48, 0.36),
			"givre": 0.0, "neige_translucide": 0.0}
	reglages_herbe = {"couleur_base": Color(0.26, 0.24, 0.1), "couleur_pointe": Color(0.72, 0.64, 0.36),
			"couleur_givre": Color(0.7, 0.62, 0.36), "force_vent": 0.25}
	piste = CHEMIN.duplicate()


func _ready() -> void:
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_grece", "") != "":
		Reseau.remove_meta("arrivee_grece")
		# Retour d'Athènes par les Longs Murs : on arrive devant la porte.
		point_apparition = PORTE + Vector2(0, 8)
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	return PORTE if zone != "le_piree" else Vector2.INF


# --- Relief -----------------------------------------------------------------------------

func _preparer_bruits() -> void:
	super._preparer_bruits()
	_relief.frequency = 0.011


func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	var bruit := _relief.get_noise_2d(x, z)
	var fin := _details.get_noise_2d(x * 3.0, z * 3.0)
	# La terre ferme au nord (la côte vers z = 62) et la presqu'île de l'Akté au sud-ouest.
	var cote := 62.0 + _relief.get_noise_1d(x * 0.7) * 10.0
	var terre := 1.0 - smoothstep(cote - 6.0, cote + 6.0, z)
	var d_akte := Vector2((x + 88.0) / 62.0, (z - 96.0) / 58.0).length() + _relief.get_noise_2d(x * 0.8, z * 0.8) * 0.12
	terre = maxf(terre, 1.0 - smoothstep(0.85, 1.0, d_akte))
	# L'isthme qui relie l'Akté au reste du Pirée.
	terre = maxf(terre, _dans_rect(Rect2(-72, 30, 58, 84), x, z, 10.0))
	# Autour de la faille (ch. 1), le flanc rocheux est lissé : sur les bosses, le
	# joueur glissait trop loin pour la refermer (il faut rester immobile 5 s).
	var lisse := 1.0 - 0.9 * (1.0 - smoothstep(4.0, 8.0, Vector2(x, z).distance_to(FAILLE)))
	var h_terre := 1.8 + bruit * 1.4 + fin * 0.08 * lisse
	# La colline rocheuse de l'Akté.
	h_terre += pow(maxf(0.0, 1.0 - d_akte / 0.78), 1.4) * 15.0 * (1.0 + fin * 0.25 * lisse)
	# La colline de Mounichia, à l'est.
	h_terre += smoothstep(112.0, 152.0, x) * (11.0 + bruit * 6.0) * (1.0 - smoothstep(20.0, 60.0, z))
	# La ville monte doucement vers le nord.
	h_terre += smoothstep(-40.0, -150.0, z) * 2.5
	var h := lerpf(-7.0 + fin * 0.3, h_terre, terre)
	# Les quais et l'arsenal : un grand terre-plein aplani autour du bassin.
	h = lerpf(h, QUAI + fin * 0.03, _dans_rect(Rect2(-34, -74, 150, 130), x, z, 8.0))
	# Le bassin du Kantharos, et la passe qui le relie au large.
	h = lerpf(h, -3.2, _dans_rect(BASSIN, x, z, 1.0))
	h = lerpf(h, -3.2, _dans_rect(PASSE, x, z, 1.0))
	# Les cales des loges : une pente douce qui descend des hangars jusque dans l'eau.
	var t_cale := clampf(inverse_lerp(LOGES.position.x, LOGES.end.x, x), 0.0, 1.0)
	h = lerpf(h, lerpf(QUAI + 0.1, -1.6, t_cale), _dans_rect(LOGES, x, z, 0.5))
	# La crique du portail : de l'eau aux genoux, une plage de galets au nord.
	var d_crique := Vector2(x, z).distance_to(CRIQUE)
	h = lerpf(h, -0.45 + fin * 0.04, 1.0 - smoothstep(13.0, 19.0, d_crique))
	h = lerpf(h, minf(h, -1.4), _dans_rect(Rect2(-70, 140, 20, 40), x, z, 4.0))
	# Le haut-fond du poulpe, et le rocher plat du portail.
	h = lerpf(h, -0.8, 1.0 - smoothstep(3.0, 6.0, Vector2(x, z).distance_to(POULPE)))
	h = lerpf(h, maxf(h, 0.35), 1.0 - smoothstep(3.5, 5.5, Vector2(x, z).distance_to(PORTAIL)))
	# Le chemin côtier, qui contourne l'Akté par l'est.
	var d_chemin := _distance_piste(Vector2(x, z))
	h = lerpf(h, minf(h, 2.6 + fin * 0.05), (1.0 - smoothstep(3.0, 7.0, d_chemin)) * smoothstep(-0.3, 0.6, h))
	# La route de la porte des Longs Murs.
	h = lerpf(h, 4.3, (1.0 - smoothstep(8.0, 14.0, absf(x - PORTE.x))) * smoothstep(-128.0, -142.0, z))
	return maxf(h, -7.5)


## Rouge : galets des criques ; vert : terre rouge ; bleu : terre tassée des rues.
func _parts_sol(x: float, z: float, h: float) -> Color:
	var n := _relief.get_noise_2d(x * 2.0 + 60.0, z * 2.0)
	var plage := 1.0 - smoothstep(0.5, 1.4, h + n * 0.3)
	var rues := maxf(_dans_rect(Rect2(-34, -74, 150, 130), x, z, 6.0), _dans_rect(VILLE, x, z, 4.0))
	var rouge := (1.0 - plage) * (1.0 - rues)
	return Color(plage, rouge, (1.0 - plage) * rues, 1.0)


# --- Construction -------------------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_flotteurs.clear()
	_construire_terrain()
	_construire_eau()
	_construire_crique()
	_construire_quais()
	_construire_loges()
	_construire_emporion()
	_construire_ville()
	_construire_longs_murs()
	_construire_mounichia()
	_construire_vegetation()
	_construire_rochers_akte()
	_construire_touffes()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_appliquer_ciel()


# --- La crique de l'Akté --------------------------------------------------------------------

func _construire_crique() -> void:
	var crique := Node3D.new()
	crique.name = "Crique"
	_contenu.add_child(crique)
	# La barque de Glaukos tirée sur les galets, ses filets qui sèchent sur des perches.
	var barque := _barque(crique, Vector3(BARQUE_GLAUKOS.x, hauteur(BARQUE_GLAUKOS.x, BARQUE_GLAUKOS.y) + 0.05,
			BARQUE_GLAUKOS.y), 0.9, 6.0, false, false)
	barque.rotation.z = 0.12
	var bois := _mat_bois()
	for k in 3:
		var p := GLAUKOS + Vector2(-4.0 + k * 2.2, -3.0)
		var perche := MeshInstance3D.new()
		perche.mesh = _cylindre(0.04, 0.05, 2.2, 6)
		perche.material_override = bois
		perche.position = Vector3(p.x, hauteur(p.x, p.y) + 1.1, p.y)
		crique.add_child(perche)
	var filet := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(4.4, 1.6)
	filet.mesh = plan
	var m := _mat_lin(Color(0.55, 0.5, 0.4))
	filet.material_override = m
	filet.rotation.x = PI / 2
	filet.position = Vector3(GLAUKOS.x - 1.8, hauteur(GLAUKOS.x, GLAUKOS.y - 3.0) + 1.4, GLAUKOS.y - 3.0)
	crique.add_child(filet)
	# Des paniers à poissons et une amphore d'eau sur la plage.
	for k in 3:
		_amphore(crique, Vector3(GLAUKOS.x + 2.0 + k * 0.5, hauteur(GLAUKOS.x + 2.0, GLAUKOS.y) - 0.05, GLAUKOS.y + 1.0 + k * 0.3), 0.8, k * 1.3, k == 2)
	_feu(crique, GLAUKOS + Vector2(1.5, 3.5), 0.5)


# --- Le port : quais et bassin -----------------------------------------------------------------

func _construire_quais() -> void:
	var port := Node3D.new()
	port.name = "Quais"
	_contenu.add_child(port)
	var pierre := _mat_pierre()
	var r := BASSIN
	var fond := -3.2
	var haut := QUAI + 0.05
	var e := 1.6
	var milieu := (haut + fond) * 0.5
	var h_mur := haut - fond
	# Ouest (au nord et au sud des loges), nord, est, et sud de part et d'autre de la passe.
	var murs := [
		[Vector3(e, h_mur, r.end.y - LOGES.end.y), Vector3(r.position.x - e * 0.5, milieu, (LOGES.end.y + r.end.y) * 0.5)],
		[Vector3(e, h_mur, LOGES.position.y - r.position.y), Vector3(r.position.x - e * 0.5, milieu, (r.position.y + LOGES.position.y) * 0.5)],
		[Vector3(r.size.x + e * 2.0, h_mur, e), Vector3(r.get_center().x, milieu, r.position.y - e * 0.5)],
		[Vector3(e, h_mur, r.size.y + e * 2.0), Vector3(r.end.x + e * 0.5, milieu, r.get_center().y)],
		[Vector3(PASSE.position.x - r.position.x, h_mur, e), Vector3((r.position.x + PASSE.position.x) * 0.5, milieu, r.end.y + e * 0.5)],
		[Vector3(r.end.x - PASSE.end.x, h_mur, e), Vector3((PASSE.end.x + r.end.x) * 0.5, milieu, r.end.y + e * 0.5)],
	]
	for mur in murs:
		_boite(mur[0], mur[1], pierre, port)
	# Les deux jetées de la passe, qui avancent dans la mer et portent une tour chacune.
	for x: float in [PASSE.position.x - 0.8, PASSE.end.x + 0.8]:
		_boite(Vector3(1.6, h_mur, 22.0), Vector3(x, milieu, r.end.y + 11.0), pierre, port)
		_boite(Vector3(4.0, 7.0, 4.0), Vector3(x, QUAI + 3.5, r.end.y + 21.0), pierre, port)
	# Les bornes d'amarrage, et des trières de commerce (plus rondes, à voile) au mouillage.
	for k in 9:
		_boite(Vector3(0.4, 0.6, 0.4), Vector3(r.position.x + 0.6, QUAI + 0.3, LOGES.end.y + 4.0 + k * 4.0), pierre, port, false)
		_boite(Vector3(0.4, 0.6, 0.4), Vector3(r.position.x + 8.0 + k * 9.0, QUAI + 0.3, r.position.y + 0.6), pierre, port, false)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 21
	for k in 4:
		var p := Vector3(hasard.randf_range(60.0, 100.0), -0.1, hasard.randf_range(-40.0, 30.0))
		var cargo := _barque(port, p, hasard.randf() * TAU, hasard.randf_range(12.0, 16.0), false)
		var mat := MeshInstance3D.new()
		mat.mesh = _cylindre(0.1, 0.14, 9.0, 6)
		mat.material_override = _mat_bois()
		mat.position.y = 4.8
		cargo.add_child(mat)
	# Au large, d'autres navires (vus de loin).
	for k in 6:
		var a := hasard.randf_range(0.3, 2.6)
		var p := Vector3(cos(a) * hasard.randf_range(260.0, 600.0), -0.1, 160.0 + sin(a) * hasard.randf_range(120.0, 500.0))
		_barque(port, p, hasard.randf() * TAU, hasard.randf_range(10.0, 16.0), false)


# --- Les loges des trières (neosoikoi) ---------------------------------------------------------

func _construire_loges() -> void:
	var loges := Node3D.new()
	loges.name = "Loges"
	_contenu.add_child(loges)
	var pierre := _mat_pierre()
	var n := int(LOGES.size.y / LARGEUR_LOGE)
	var haut := 6.5
	# Les rangées de colonnes entre les loges (piliers de pierre), et le mur du fond.
	for k in n + 1:
		var z := LOGES.position.y + k * LARGEUR_LOGE
		for j in 8:
			var x := LOGES.position.x + 2.0 + j * 6.0
			if x > BASSIN.position.x - 1.0:
				break
			var y := hauteur(x, z)
			var pilier := _boite(Vector3(0.7, haut - (y - QUAI), 0.7), Vector3(x, (y + QUAI + haut) * 0.5, z), pierre, loges)
			pilier.name = "Pilier"
		_boite(Vector3(LOGES.size.x - 4.0, 0.45, 0.6), Vector3(LOGES.get_center().x - 2.0, QUAI + haut, z), _mat_bois(), loges, false)
	_boite(Vector3(1.0, haut + 1.0, LOGES.size.y + 1.0), Vector3(LOGES.position.x - 0.5, QUAI + haut * 0.5, LOGES.get_center().y), _mat_chaux(), loges)
	# Un toit à deux pentes au-dessus de chaque loge (le faîte va vers la mer).
	for k in n:
		var z := LOGES.position.y + (k + 0.5) * LARGEUR_LOGE
		var toit := Node3D.new()
		toit.position = Vector3(LOGES.get_center().x - 2.0, QUAI + haut + 0.2, z)
		toit.rotation.y = PI / 2
		loges.add_child(toit)
		_toit(toit, Vector3.ZERO, LARGEUR_LOGE, LOGES.size.x - 4.0, 0.3)
		# Une trière au sec sur sa cale dans quatre loges sur six (la proue vers l'eau).
		if k in [0, 1, 3, 4]:
			var x := LOGES.get_center().x - 3.0
			var t := _triere(loges, Vector3(x, hauteur(x, z) + 0.35, z), -PI / 2, 34.0, k != 4)
			t.rotation.x = -0.07
			t.name = "TriereAuSec%d" % k
	# La loge où l'on répare une trière : la coque sans ses rames, des planches, un échafaudage.
	var z_rep := LOGES.position.y + 4.5 * LARGEUR_LOGE
	for j in 5:
		_boite(Vector3(0.15, 3.0, 0.15), Vector3(-12.0 + j * 4.0, hauteur(-12.0 + j * 4.0, z_rep + 3.4) + 1.5, z_rep + 3.4), _mat_bois(), loges, false)
	for j in 6:
		_boite(Vector3(4.0, 0.08, 0.3), Vector3(-6.0 + (j % 3) * 0.5, QUAI + 0.05 + j * 0.08, z_rep - 3.8), _mat_bois(), loges, false)
	# La maison des agrès (les voiles, les cordages et les rames), au fond de l'arsenal.
	_maison_grecque(loges, Vector2(-8, -48), Vector3(18, 5.5, 7))
	for k in 6:
		_amphore(loges, Vector3(-19.0 + k * 0.6, QUAI, -43.5), 0.9, k)
	# L'enclos des archers scythes (la police de la cité), où Markos est retenu.
	var enclos := Node3D.new()
	enclos.name = "EnclosArchers"
	loges.add_child(enclos)
	_maison_grecque(enclos, MARKOS + Vector2(-5.5, 0), Vector3(6, 4.0, 7), PI / 2)
	var c := MARKOS
	for cote in [[Vector3(6.0, 1.8, 0.2), Vector3(c.x, QUAI + 0.9, c.y - 3.0)],
			[Vector3(6.0, 1.8, 0.2), Vector3(c.x, QUAI + 0.9, c.y + 3.0)],
			[Vector3(0.2, 1.8, 6.0), Vector3(c.x + 3.0, QUAI + 0.9, c.y)]]:
		_boite(cote[0], cote[1], _mat_bois(), enclos)
	for k in 11:
		var barreau := MeshInstance3D.new()
		barreau.mesh = _cylindre(0.05, 0.05, 2.4, 6)
		barreau.material_override = _mat_bois()
		barreau.position = Vector3(c.x + 3.0, QUAI + 1.2, c.y - 2.7 + k * 0.55)
		enclos.add_child(barreau)


# --- Le grand portique du commerce (l'emporion) ------------------------------------------------

func _construire_emporion() -> void:
	var emporion := Node3D.new()
	emporion.name = "Emporion"
	_contenu.add_child(emporion)
	_portique(emporion, EMPORION, 72.0, 9.0, 0.0)
	# Des piles d'amphores devant le portique : vin de Chios, huile, poisson salé.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 30
	for groupe: Vector2 in [Vector2(40, -56), Vector2(55, -55.5), Vector2(80, -56), Vector2(94, -55.5)]:
		for k in hasard.randi_range(6, 11):
			var p: Vector2 = groupe + Vector2(hasard.randf_range(-2.5, 2.5), hasard.randf_range(-1.0, 1.0))
			_amphore(emporion, Vector3(p.x, QUAI, p.y), hasard.randf_range(0.85, 1.05), hasard.randf() * TAU, hasard.randf() < 0.25)
	# Les étals des marchands, sous des auvents de toile.
	for k in 4:
		var p := Vector2(34.0 + k * 18.0, -57.5)
		_auvent(emporion, p, Vector2(3.4, 2.4), 2.5, [Color(0.85, 0.8, 0.7), Color(0.72, 0.3, 0.2), Color(0.86, 0.82, 0.72), Color(0.3, 0.4, 0.6)][k])
		_boite(Vector3(2.6, 0.9, 1.0), Vector3(p.x, QUAI + 0.45, p.y + 0.4), _mat_bois(), emporion)


# --- La ville d'Hippodamos -------------------------------------------------------------------

func _construire_ville() -> void:
	var ville := Node3D.new()
	ville.name = "Ville"
	_contenu.add_child(ville)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 40
	# Les îlots du damier : des rues droites de 6 m tous les 24 m.
	var ilot := 24.0
	var x := VILLE.position.x + 4.0
	while x < VILLE.end.x - 8.0:
		var z := VILLE.position.y + 4.0
		while z < VILLE.end.y - 6.0:
			var centre := Vector2(x + 9.0, z + 9.0)
			# La place de l'agora et la grand-rue qui monte à la porte restent dégagées.
			if centre.distance_to(AGORA) > 16.0 and absf(centre.x - PORTE.x) > 12.0:
				for k in 4:
					var p := centre + Vector2((k % 2) * 9.0 - 4.5, (k / 2) * 9.0 - 4.5)
					var taille := Vector3(hasard.randf_range(6.5, 8.0), hasard.randf_range(3.6, 4.6), hasard.randf_range(6.5, 8.0))
					_maison_grecque(ville, p, taille, [0.0, PI / 2, PI, -PI / 2][hasard.randi() % 4])
			z += ilot
		x += ilot
	# La petite agora du Pirée : un autel, une borne de pierre, une fontaine.
	_boite(Vector3(2.4, 1.1, 1.6), Vector3(AGORA.x, hauteur(AGORA.x, AGORA.y) + 0.55, AGORA.y), _mat_marbre(), ville)
	_boite(Vector3(2.6, 0.2, 1.8), Vector3(AGORA.x, hauteur(AGORA.x, AGORA.y) + 1.15, AGORA.y), _mat_peint(ROUGE_GREC), ville, false)
	var borne := MeshInstance3D.new()
	borne.mesh = _cylindre(0.25, 0.3, 1.2, 10)
	borne.material_override = _mat_marbre()
	borne.position = Vector3(AGORA.x + 8.0, hauteur(AGORA.x + 8.0, AGORA.y) + 0.6, AGORA.y - 6.0)
	ville.add_child(borne)
	_portique(ville, AGORA + Vector2(0, -12), 30.0, 6.0, 0.0, 4.2)
	_feu(ville, AGORA + Vector2(-7, 5), 0.6)


# --- La porte des Longs Murs -----------------------------------------------------------------

func _construire_longs_murs() -> void:
	var murs := Node3D.new()
	murs.name = "LongsMurs"
	_contenu.add_child(murs)
	var pierre := _mat_pierre()
	var y := hauteur(PORTE.x, PORTE.y)
	# Les deux murailles parallèles, qui partent vers le nord jusqu'à Athènes.
	for cote: float in [-1.0, 1.0]:
		var x := PORTE.x + cote * 13.0
		_boite(Vector3(3.0, 8.0, 40.0), Vector3(x, y + 4.0, PORTE.y - 16.0), pierre, murs)
		_boite(Vector3(3.0, 8.0, 1400.0), Vector3(x, y + 3.0, PORTE.y - 740.0), pierre, murs, false)
		# Les tours carrées de la porte.
		_boite(Vector3(6.0, 11.0, 6.0), Vector3(PORTE.x + cote * 8.0, y + 5.5, PORTE.y), pierre, murs)
		# Le mur de la ville qui part de chaque tour, vers l'est et vers l'ouest.
		_boite(Vector3(90.0, 7.0, 2.6), Vector3(PORTE.x + cote * 56.0, y + 3.5, PORTE.y + 1.0), pierre, murs)
	# Les vantaux de bois de la porte (fermés jusqu'au chapitre 3).
	for cote: float in [-1.0, 1.0]:
		var vantail := _boite(Vector3(4.6, 6.0, 0.4), Vector3(PORTE.x + cote * 2.4, y + 3.0, PORTE.y), _mat_bois(), murs, false)
		vantail.name = "Vantail" + ("G" if cote < 0.0 else "D")
		vantail.set_meta("identifiant", "vantail_" + ("g" if cote < 0.0 else "d"))
		vantail.add_to_group("decor_quete")
	_boite(Vector3(10.0, 1.2, 6.0), Vector3(PORTE.x, y + 6.6, PORTE.y), pierre, murs, false)


# --- La colline de Mounichia et le temple d'Artémis -------------------------------------------

func _construire_mounichia() -> void:
	var temple := Node3D.new()
	temple.name = "TempleArtemis"
	# Le temple est sur le sommet en pente : on le pose au point le plus bas de son
	# emprise, et un soubassement de pierre rattrape la pente (sinon il flotte).
	var y_min := hauteur(TEMPLE.x, TEMPLE.y)
	var y_max := y_min
	for dx: float in [-9.0, 0.0, 9.0]:
		for dz: float in [-5.5, 0.0, 5.5]:
			var h := hauteur(TEMPLE.x + dx, TEMPLE.y + dz)
			y_min = minf(y_min, h)
			y_max = maxf(y_max, h)
	temple.position = Vector3(TEMPLE.x, y_max - 0.1, TEMPLE.y)
	temple.rotation.y = PI / 2
	_contenu.add_child(temple)
	var marbre := _mat_marbre()
	var socle := y_max - y_min + 1.0
	_boite(Vector3(10.6, socle, 17.6), Vector3(0, -socle * 0.5 + 0.05, 0), _mat_pierre(), temple)
	for k in 3:
		_boite(Vector3(10.0 - k * 0.6, 0.3, 17.0 - k * 0.6), Vector3(0, 0.15 + k * 0.3, 0), marbre, temple)
	_boite(Vector3(6.4, 5.0, 10.0), Vector3(0, 0.9 + 2.5, -1.5), _mat_chaux(), temple)
	for k in 4:
		_colonne(temple, Vector3(-3.3 + k * 2.2, 0.9, 5.8), 5.0, 0.34, marbre)
	_boite(Vector3(9.0, 0.5, 15.5), Vector3(0, 6.15, 0), marbre, temple, false)
	_frise(temple, Vector3(0, 6.7, 7.0), 8.8, 0.6)
	_toit(temple, Vector3(0, 7.0, 0), 9.0, 15.0, 0.25)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 50
	for k in 8:
		var a := TAU * k / 8.0
		_cypres(_contenu, TEMPLE + Vector2(cos(a), sin(a)) * hasard.randf_range(14.0, 20.0), hasard)


# --- Végétation ------------------------------------------------------------------------------

func _construire_vegetation() -> void:
	var arbres := Node3D.new()
	arbres.name = "Arbres"
	_contenu.add_child(arbres)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 60
	var plantes := 0
	var essais := 0
	while plantes < 70 and essais < 900:
		essais += 1
		var p := Vector2(hasard.randf_range(-155.0, 155.0), hasard.randf_range(-155.0, 150.0))
		var h := hauteur(p.x, p.y)
		if h < 1.2 or h > 14.0:
			continue
		if _dans_rect(Rect2(-36, -76, 154, 134), p.x, p.y, 0.1) > 0.5 or _dans_rect(VILLE.grow(-6.0), p.x, p.y, 0.1) > 0.5:
			continue
		if _distance_piste(p) < 4.0 or p.distance_to(GLAUKOS) < 6.0 or p.distance_to(SAC_MARKOS) < 4.0 \
				or p.distance_to(FAILLE) < 6.0 or p.distance_to(TEMPLE) < 12.0 or absf(p.x - PORTE.x) < 14.0 and p.y < -120.0:
			continue
		_olivier(arbres, p, hasard, hasard.randf_range(0.8, 1.3))
		plantes += 1
	# Quelques cyprès le long de la grand-rue et autour de l'agora.
	for k in 6:
		_cypres(arbres, Vector2(PORTE.x + (-9.0 if k % 2 == 0 else 9.0), -128.0 + k * 8.0), hasard)
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		_cypres(arbres, AGORA + Vector2(cos(a), sin(a)) * 12.0, hasard)


func _construire_rochers_akte() -> void:
	var dossier := Node3D.new()
	dossier.name = "Rochers"
	_contenu.add_child(dossier)
	_preparer_rochers()
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 12
	var poses := 0
	var essais := 0
	while poses < 110 and essais < 1500:
		essais += 1
		var x := hasard.randf_range(-158.0, -20.0)
		var z := hasard.randf_range(40.0, 158.0)
		var h := hauteur(x, z)
		if h < -0.2 or Vector2(x, z).distance_to(PORTAIL) < 8.0 or Vector2(x, z).distance_to(GLAUKOS) < 5.0 \
				or _distance_piste(Vector2(x, z)) < 4.5 or Vector2(x, z).distance_to(BALISE) < 4.0:
			continue
		_placer_rocher(dossier, x, z, hasard.randf_range(0.5, 2.4) * (1.8 if hasard.randf() < 0.1 else 1.0))
		poses += 1
	# Les rochers qui coincent le sac de Markos, et ceux qui ferment la crique.
	for k in 4:
		var a := TAU * k / 4.0
		_placer_rocher(dossier, SAC_MARKOS.x + cos(a) * 1.8, SAC_MARKOS.y + sin(a) * 1.6, 1.1)
	for k in 12:
		var a := lerpf(-0.4, PI + 0.4, float(k) / 11.0)
		var p := CRIQUE + Vector2(cos(a), -sin(a)) * 21.0
		if _distance_piste(p) > 5.0:
			_placer_rocher(dossier, p.x, p.y, hasard.randf_range(1.6, 3.0))


# --- Paysage lointain ----------------------------------------------------------------------

func _construire_lointain() -> void:
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.8
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 70
	# La plaine d'Attique qui continue au nord, et les montagnes : le Parnès au nord,
	# l'Hymette à l'est, l'Aigaléos au nord-ouest.
	_plan_lointain(Vector3(0, 3.2, -1621), Vector2(3600, 2938), Color(0, 1, 0))
	for m in [[Vector3(-500, -10, -2900), Vector3(900, 260, 200)], [Vector3(1500, -10, -1400), Vector3(240, 230, 900)],
			[Vector3(-1100, -10, -1500), Vector3(300, 150, 500)]]:
		bruit.seed = graine + hasard.randi()
		var montagne := MeshInstance3D.new()
		montagne.mesh = _maillage_bosse(bruit, m[1], 1.4, 0.3, 28, Color(0, 0.6, 0.4))
		montagne.material_override = _mat_lointain()
		montagne.position = m[0]
		montagne.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(montagne)
	# Les îles du golfe Saronique : Salamine à l'ouest, Égine au sud.
	for ile in [[Vector3(-1500, -6, 300), Vector3(500, 120, 700)], [Vector3(300, -6, 2300), Vector3(500, 160, 400)]]:
		bruit.seed = graine + hasard.randi()
		var terre := MeshInstance3D.new()
		terre.mesh = _maillage_bosse(bruit, ile[1], 1.4, 0.3, 24, Color(0.2, 0.6, 0.2))
		terre.material_override = _mat_lointain()
		terre.position = ile[0]
		terre.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(terre)
	# Au bout des Longs Murs, l'Acropole d'Athènes et son Parthénon (on la voit de partout).
	_construire_acropole_lointaine(Vector3(-210, 0, -1800))


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
	# Le Parthénon : 70 m de long, 31 m de large, ses colonnes blanches et son toit.
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
	_mur_invisible(limites, Vector3(2, 120, taille_terrain), Vector3(-demi, 40, 0))
	_mur_invisible(limites, Vector3(2, 120, taille_terrain), Vector3(demi, 40, 0))
	_mur_invisible(limites, Vector3(taille_terrain, 120, 2), Vector3(0, 40, -demi))
	_mur_invisible(limites, Vector3(taille_terrain, 120, 2), Vector3(0, 40, demi))
	# La porte des Longs Murs : fermée jusqu'au chapitre 3.
	_mur_porte = _mur_invisible(limites, Vector3(12, 14, 2), Vector3(PORTE.x, hauteur(PORTE.x, PORTE.y) + 6.0, PORTE.y - 1.0))
	# Un muret invisible au bord des quais : on ne tombe pas dans le bassin profond.
	_mur_invisible(limites, Vector3(1.0, 4.0, BASSIN.end.y - LOGES.end.y), Vector3(BASSIN.position.x + 0.2, QUAI + 1.5, (LOGES.end.y + BASSIN.end.y) * 0.5))
	_mur_invisible(limites, Vector3(BASSIN.size.x, 4.0, 1.0), Vector3(BASSIN.get_center().x, QUAI + 1.5, BASSIN.position.y + 0.2))


# --- Personnages et objets de la quête ----------------------------------------------------------

func _construire_quete() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quete"
	_contenu.add_child(dossier)
	_dossier_quete = dossier
	_construire_portail(dossier, PORTAIL, 0.0)
	_pnj(dossier, "glaukos", GLAUKOS, 2.6)
	_pnj(dossier, "lysimaque", LYSIMAQUE, 1.2)
	_pnj(dossier, "phormion", PHORMION, 0.0)
	_pnj(dossier, "markos", MARKOS + Vector2(1.4, 0), -PI / 2)
	_pnj(dossier, "archer_scythe", ARCHER, 0.8)
	_pnj(dossier, "aulete", AULETE, -1.6)
	for k in RAMEURS.size():
		_pnj(dossier, "rameur_%d" % (k + 1), RAMEURS[k], -1.4 + k * 0.5)
	_pnj(dossier, "marchande_huile", Vector2(52, -56), 0.0)
	_pnj(dossier, "marchand_vin", Vector2(88, -56), 0.0)
	# Quête secondaire « Les derniers de Marathon » : un vieux rameur, sur la petite agora.
	_pnj(dossier, "veteran_diphilos", Vector2(-80, -100), PI * 0.25)
	# Le sac de Markos, coincé dans les rochers.
	var sac := ObjetGrece.new()
	sac.name = "SacMarkos"
	sac.identifiant = "sac_markos"
	sac.forme = "sac_voyage"
	sac.invite = "[F] Dégager le sac de la Vigie"
	sac.position = Vector3(SAC_MARKOS.x, hauteur(SAC_MARKOS.x, SAC_MARKOS.y), SAC_MARKOS.y)
	dossier.add_child(sac)
	var balise := ObjetGrece.new()
	balise.name = "PointBalise"
	balise.identifiant = "installer_balise"
	balise.forme = "balise"
	balise.invite = "[F] Installer la balise de la Vigie"
	balise.position = Vector3(BALISE.x, hauteur(BALISE.x, BALISE.y), BALISE.y)
	dossier.add_child(balise)
	_balise_installee(dossier, balise.position)
	# Les filets de Glaukos, pris par le poulpe sur le haut-fond (montrés après le combat).
	var filets := ObjetGrece.new()
	filets.name = "FiletsGlaukos"
	filets.identifiant = "filets_glaukos"
	filets.forme = "filet"
	filets.invite = "[F] Récupérer les filets de Glaukos"
	filets.position = Vector3(POULPE.x, NIVEAU_MER - 0.05, POULPE.y)
	dossier.add_child(filets)
	var faille := Faille.new()
	faille.name = "Faille"
	faille.identifiant = "faille_akte"
	faille.position = Vector3(FAILLE.x, hauteur(FAILLE.x, FAILLE.y), FAILLE.y)
	dossier.add_child(faille)
	# La Paralos : la trière sacrée de la cité, au quai ouest du bassin.
	var triere := TriereCadence.new()
	triere.name = "Paralos"
	triere.chemin = TOUR_BASSIN
	triere.paroles = [
		[0.2, "Lysimaque", "« Écoute la flûte, Xénos ! La rame tombe avec la note, pas avant ! »"],
		[0.55, "L'aulète", "La flûte siffle plus vite. Cent soixante-dix rames frappent l'eau ensemble, comme un seul bras."],
		[0.85, "Phormion, depuis le quai", "« Pas mal, pour un étranger. Encore un effort ! »"],
	]
	triere.position = Vector3(TRIERE.x, -0.15, TRIERE.y)
	dossier.add_child(triere)
	triere.navire = _triere(triere, Vector3.ZERO, 0.0, 37.0)
	var monter := ObjetGrece.new()
	monter.name = "MonterTriere"
	monter.identifiant = "monter_triere"
	monter.invite = "[F] Monter à bord de la Paralos"
	monter.portee = 4.0
	monter.position = Vector3(EMBARQUER.x, QUAI, EMBARQUER.y)
	dossier.add_child(monter)
	# Une passerelle du quai jusqu'au pont (pour le décor).
	var passerelle := _boite(Vector3(9.0, 0.15, 1.2), Vector3((BASSIN.position.x + TRIERE.x - 3.0) * 0.5, QUAI + 0.3, EMBARQUER.y), _mat_bois(), dossier, false)
	passerelle.rotation.z = -0.06
	# Repères de la carte.
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.PORTAIL, "Portail de la Vigie", PORTAIL)
	repere.call(MarqueurCarte.Type.DANGER, "Faille", FAILLE)
	repere.call(MarqueurCarte.Type.LIEU, "Crique de l'Akté", CRIQUE + Vector2(0, -16))
	repere.call(MarqueurCarte.Type.LIEU, "Loges des trières", LOGES.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Bassin du Kantharos", BASSIN.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Grand portique du commerce", EMPORION)
	repere.call(MarqueurCarte.Type.LIEU, "Agora du Pirée", AGORA)
	repere.call(MarqueurCarte.Type.LIEU, "Porte des Longs Murs (vers Athènes)", PORTE)
	repere.call(MarqueurCarte.Type.LIEU, "Temple d'Artémis", TEMPLE)
	repere.call(MarqueurCarte.Type.DANGER, "Chiens errants", Vector2(-72, 86))


## La balise une fois montée : un trépied et un fanal cyan (caché jusque-là).
func _balise_installee(dossier: Node3D, ou: Vector3) -> void:
	var installee := Node3D.new()
	installee.name = "BaliseInstallee"
	installee.set_meta("identifiant", "balise_installee")
	installee.add_to_group("decor_quete")
	installee.visible = false
	installee.position = ou
	dossier.add_child(installee)
	for k in 3:
		var pied := MeshInstance3D.new()
		pied.mesh = _cylindre(0.03, 0.045, 2.3, 6)
		pied.material_override = _metal()
		var a := TAU * k / 3.0
		pied.position = Vector3(cos(a) * 0.32, 1.1, sin(a) * 0.32)
		pied.rotation = Vector3(sin(a) * 0.14, 0.0, -cos(a) * 0.14)
		installee.add_child(pied)
	var fanal := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.14
	sphere.height = 0.28
	fanal.mesh = sphere
	fanal.material_override = _lumineux(Color(0.3, 0.9, 1.0), 3.0)
	fanal.position.y = 2.3
	installee.add_child(fanal)
	var lampe := OmniLight3D.new()
	lampe.light_color = Color(0.4, 0.9, 1.0)
	lampe.light_energy = 1.4
	lampe.omni_range = 7.0
	lampe.position.y = 2.3
	installee.add_child(lampe)


# --- La porte des Longs Murs ---------------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	if Engine.is_editor_hint():
		return
	_attente_porte -= delta
	if _attente_porte > 0.0:
		return
	_attente_porte = 0.3
	var quete := get_tree().get_first_node_in_group("quete")
	if quete == null or not quete.has_method("etape_atteinte"):
		return
	# Partie reprise au milieu du tour du bassin : on remonte à bord de la Paralos.
	if quete.etape_actuelle().get("id", "") == "triere_cadence":
		var triere := find_child("Paralos", true, false)
		if triere != null and not triere.en_route:
			triere.partir(true)
	if not _porte_ouverte:
		if not quete.etape_atteinte("vers_athenes"):
			return
		_porte_ouverte = true
		if _mur_porte != null and is_instance_valid(_mur_porte):
			_mur_porte.queue_free()
		for n in get_tree().get_nodes_in_group("decor_quete"):
			if String(n.get_meta("identifiant", "")).begins_with("vantail_"):
				n.rotation.y = (1.4 if String(n.get_meta("identifiant")).ends_with("g") else -1.4)
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return
	var p := Vector2(joueur.global_position.x, joueur.global_position.z)
	if p.distance_to(PORTE + Vector2(0, -12)) < 5.0 and quete.donnees.get("zones", {}).has("oliveraies"):
		quete.changer_de_zone("oliveraies")
