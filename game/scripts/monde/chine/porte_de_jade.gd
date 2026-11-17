@tool
extends "res://scripts/monde/chine/ile_chine.gd"
## Île de la Chine, zone 1 : la Porte de Jade (niveaux 40-42).
##
## L'hiver de l'an 105, au bout ouest de l'empire des Han, là où commence la route de la
## soie. Au nord, la Grande Muraille des Han, en terre damée et en lits de roseaux, file
## d'est en ouest dans le désert, avec ses tours à fanaux et leurs meules de combustible ;
## derrière elle, les dunes. Au sud de la muraille : la route des caravanes, le fort carré
## de la Porte de Jade (le poste de garde de Ban Yong) et, de l'autre côté de la route, le
## relais où font halte les caravanes (tentes, chameaux, ballots de soie). Au sud-est, un
## lac salé gelé, bordé de tamaris et de peupliers. Le portail de la Vigie s'est ouvert au
## sud-ouest, au pied d'une vieille tour de guet en ruine : Damien Roche y attend.
##
## Tout est construit par le code (voir ile_chine.gd). Le bouton « Reconstruire » de
## l'Inspecteur refait tout. Repères : le nord est vers -Z.

const Faille := preload("res://scripts/monde/prehistoire/faille.gd")
const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const ObjetChine := preload("res://scripts/monde/chine/objet_chine.gd")

## La Grande Muraille des Han, d'ouest en est.
const MURAILLE := [Vector2(-170, -74), Vector2(-100, -80), Vector2(-40, -72), Vector2(20, -82), Vector2(80, -76), Vector2(170, -84)]
## Les trois tours dont il faut rallumer le fanal (chapitre 1), et une quatrième au loin.
const TOURS := [Vector2(-100, -66), Vector2(-20, -60), Vector2(60, -64)]
const TOUR_EST := Vector2(130, -70)
## Les meules à allumer, au pied des tours (côté sud).
const FANAUX := [Vector2(-96, -56), Vector2(-16, -50), Vector2(64, -54)]
## La route des caravanes, d'ouest (le désert, les royaumes de l'Ouest) en est (la Chine).
const ROUTE := [Vector2(-170, -30), Vector2(-110, -34), Vector2(-60, -28), Vector2(-10, -16), Vector2(20, -6),
		Vector2(60, 8), Vector2(110, 10), Vector2(170, 6)]
## Le portail de la Vigie, au pied d'une tour de guet en ruine, et le feu de Masque.
const PORTAIL := Vector2(-70, 82)
const TOUR_PORTAIL := Vector2(-72, 96)
const FEU_MASQUE := Vector2(-62, 74)
const MASQUE := Vector2(-59.5, 76.0)
const RADIO := Vector2(-63.5, 71.5)
## Le sentier du portail jusqu'à la route.
const SENTIER := [Vector2(-70, 76), Vector2(-72, 44), Vector2(-76, 12), Vector2(-80, -22)]
## La caravane de soie attaquée sur la route, et ceux qui la mènent.
const CARAVANE := Vector2(-84, -30)
const WANG_BA := Vector2(-79, -25)
const MARCHANDS := [Vector2(-88, -24), Vector2(-76, -34), Vector2(-91, -34)]
const BAN_YONG_ROUTE := Vector2(-72, -24)
## Les pillards qui attaquent la caravane.
const PILLARDS := Vector2(-104, -42)
## L'escorte : de la caravane jusqu'au relais.
const ESCORTE := [Vector2(-84, -30), Vector2(-60, -28), Vector2(-30, -22), Vector2(-10, -16), Vector2(20, -6),
		Vector2(52, 6), Vector2(70, 12)]
## Le fort carré de la Porte de Jade : sa porte à l'ouest.
const FORT := Rect2(14, -36, 26, 26)
const PORTE_FORT := Vector2(14, -23)
const BAN_YONG := Vector2(10.5, -19.5)
## Les Figés, dans la cour du fort.
const FIGES := [Vector2(21, -30), Vector2(33, -29), Vector2(22, -17), Vector2(33, -16)]
## Le relais des caravanes, au sud de la route : son entrée au nord.
const RELAIS := Rect2(56, 18, 36, 28)
const PORTE_RELAIS := Vector2(74, 18)
const GAN_YING := Vector2(80, 30)
const SCRIBE := Vector2(64, 26)
const LATTES := [Vector2(62, 31), Vector2(66, 36), Vector2(70, 32)]
## Le lac salé gelé, au sud-est, la faille et le campement du chef des pillards.
const LAC := Vector2(104, 98)
const RAYON_LAC := 34.0
const FAILLE := Vector2(112, 62)
const CHEF := Vector2(90, 66)
## Les sorties : vers l'est (le Fleuve Jaune, ouverte plus tard) ; l'ouest est le désert.
const SORTIE_EST := Vector2(152, 6)

var _mur_est: StaticBody3D
var _est_ouvert := false
var _attente_sortie := 0.0


func _init() -> void:
	identifiant_zone = "porte_de_jade"
	taille_terrain = 340
	graine = 105
	point_apparition = PORTAIL + Vector2(1, -6)
	nombre_touffes = 14000
	fertilite_sols = Vector3(0.2, 0.05, 0.05)
	neige_qui_tombe = false
	sols = {
		# Rouge : le gravier noir et gris du désert (le « gobi »).
		"galets": ["dry_ground_rocks", "dry_ground_01", "mud_cracked_dry_03"],
		# Vert : le sable des dunes et des congères de sable au pied des murs.
		"neige": ["sand_01", "dense_sand", "sand_02"],
		# Bleu : la terre tassée de la route, du fort et du relais.
		"sol": ["mud_cracked_dry_03", "dry_ground_01", "dry_ground_rocks"],
		"roche": ["sandstone_cracks", "cliff_side", "quarry_wall"],
	}
	reglages_terrain = {"sol_saturation": 0.7, "sol_motif": 5.0, "galets_motif": 3.5, "neige_motif": 8.0,
			"sol_teinte": Color(1.0, 0.92, 0.82), "roche_teinte": Color(1.0, 0.9, 0.78), "roche_saturation": 0.8,
			"neige_eclat": 1.0, "neige_paillettes": 0.0, "roche_motif": 12.0,
			# La « neige » est ici le sable pâle des dunes de Dunhuang.
			"neige_teinte": Color(1.08, 0.94, 0.76), "neige_max": Vector3(0.86, 0.72, 0.52), "neige_simple": Color(0.78, 0.66, 0.48),
			"givre": 0.0, "neige_translucide": 0.0}
	reglages_herbe = {"couleur_base": Color(0.3, 0.26, 0.16), "couleur_pointe": Color(0.7, 0.62, 0.42),
			"couleur_givre": Color(0.66, 0.6, 0.44), "force_vent": 0.45}
	piste = SENTIER.duplicate()


func _ready() -> void:
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_chine", "") != "":
		Reseau.remove_meta("arrivee_chine")
		# Retour du Fleuve Jaune : on arrive à l'est, sur la route.
		point_apparition = SORTIE_EST + Vector2(-12, 2)
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	if zone == "porte_de_jade":
		return Vector2.INF
	return SORTIE_EST


# --- Relief -----------------------------------------------------------------------------

func _preparer_bruits() -> void:
	super._preparer_bruits()
	_relief.frequency = 0.007


## Distance à une ligne brisée.
func _distance_ligne(p: Vector2, ligne: Array) -> float:
	var meilleure := INF
	for i in ligne.size() - 1:
		meilleure = minf(meilleure, _distance_segment(p, ligne[i], ligne[i + 1]))
	return meilleure


func distance_route(p: Vector2) -> float:
	return _distance_ligne(p, ROUTE)


func distance_muraille(p: Vector2) -> float:
	return _distance_ligne(p, MURAILLE)


## Le point de la muraille à une abscisse x donnée.
func point_muraille(x: float) -> Vector2:
	for i in MURAILLE.size() - 1:
		var a: Vector2 = MURAILLE[i]
		var b: Vector2 = MURAILLE[i + 1]
		if x >= a.x and x <= b.x:
			return a.lerp(b, inverse_lerp(a.x, b.x, x))
	return MURAILLE[0] if x < MURAILLE[0].x else MURAILLE[MURAILLE.size() - 1]


## Profondeur des dunes (0 au sud de la muraille, 1 loin au nord).
func _dunes(x: float, z: float) -> float:
	var mur := point_muraille(x)
	return smoothstep(mur.y - 14.0, mur.y - 60.0, z)


func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	var bruit := _relief.get_noise_2d(x, z)
	var fin := _details.get_noise_2d(x * 3.0, z * 3.0)
	var p := Vector2(x, z)
	# Le désert de gravier : presque plat, de longues ondulations.
	var h := 3.0 + bruit * 1.6 + fin * 0.08
	# Au nord de la muraille, les dunes : des crêtes en croissant poussées par le vent d'ouest.
	var d := _dunes(x, z)
	if d > 0.0:
		var crete := 0.5 + 0.5 * sin(x * 0.045 + z * 0.02 + bruit * 3.0)
		crete = pow(crete, 1.6)
		h += d * (3.0 + crete * 9.0 + bruit * 3.0)
	# Une colline basse au sud-ouest, où se dresse la tour du portail.
	h += 2.2 * (1.0 - smoothstep(18.0, 46.0, p.distance_to(TOUR_PORTAIL + Vector2(0, 6))))
	# Le lac salé : une cuvette plate, un peu plus basse.
	var d_lac := p.distance_to(LAC) + bruit * 6.0
	h = lerpf(h, 1.4, 1.0 - smoothstep(RAYON_LAC - 4.0, RAYON_LAC + 10.0, d_lac))
	# La route : un ruban tassé, régulier.
	var d_route := distance_route(p)
	var h_route := 3.0 + bruit * 1.2
	h = lerpf(h, h_route, (1.0 - smoothstep(4.0, 12.0, d_route)) * 0.85)
	# Le pied de la muraille, aplani des deux côtés.
	h = lerpf(h, 3.2 + bruit * 1.0, (1.0 - smoothstep(4.0, 10.0, distance_muraille(p))) * 0.9)
	# Le terre-plein du fort et celui du relais.
	h = lerpf(h, 3.1, _dans_rect(FORT.grow(8.0), x, z, 6.0))
	h = lerpf(h, 3.05, _dans_rect(RELAIS.grow(6.0), x, z, 6.0))
	# Le replat devant le portail, et le pied des tours à fanaux.
	h = lerpf(h, 5.0 + fin * 0.04, 1.0 - smoothstep(9.0, 15.0, p.distance_to(PORTAIL + Vector2(2, -4))))
	for t: Vector2 in TOURS:
		h = lerpf(h, 3.2 + bruit * 1.0, 1.0 - smoothstep(9.0, 14.0, p.distance_to(t + Vector2(2, 6))))
	# Le sentier du portail.
	var d_sentier := _distance_piste(p)
	h = lerpf(h, h - 0.1, 1.0 - smoothstep(2.5, 6.0, d_sentier))
	return h


## Rouge : gravier du désert ; vert : sable ; bleu : terre tassée de la route et des enclos.
func _parts_sol(x: float, z: float, h: float) -> Color:
	var p := Vector2(x, z)
	var n := _relief.get_noise_2d(x * 2.0 + 60.0, z * 2.0)
	var sable := maxf(_dunes(x, z), 0.0)
	# Des congères de sable au pied de la muraille et dans les creux.
	sable = maxf(sable, (1.0 - smoothstep(2.0, 9.0 + n * 4.0, distance_muraille(p))) * 0.6)
	sable = maxf(sable, smoothstep(0.25, 0.6, n) * 0.7)
	var tasse := 1.0 - smoothstep(3.0, 7.0 + n * 2.0, distance_route(p))
	tasse = maxf(tasse, 1.0 - smoothstep(1.2, 3.0, _distance_piste(p)))
	tasse = maxf(tasse, _dans_rect(FORT.grow(5.0), x, z, 3.0))
	tasse = maxf(tasse, _dans_rect(RELAIS.grow(4.0), x, z, 3.0))
	sable *= 1.0 - tasse
	var gravier := maxf(0.0, 1.0 - sable - tasse)
	return Color(gravier + 0.001, sable, tasse, 1.0)


# --- Construction -------------------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_construire_terrain()
	_construire_muraille()
	_construire_fort()
	_construire_relais()
	_construire_route()
	_construire_lac()
	_construire_vegetation()
	_construire_rochers()
	_construire_touffes()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_appliquer_ciel()


func _construire_muraille() -> void:
	var dossier := Node3D.new()
	dossier.name = "GrandeMuraille"
	_contenu.add_child(dossier)
	_muraille_han(dossier, MURAILLE, 3.9, 3.2, [2])
	var tours := Node3D.new()
	tours.name = "Tours"
	dossier.add_child(tours)
	for t: Vector2 in TOURS:
		_tour_fanal(tours, t, 8.5, 7.0)
	_tour_fanal(tours, TOUR_EST, 8.0, 6.5)
	# Les meules de réserve au pied de chaque tour (on en allumait une, deux ou trois
	# selon le nombre d'ennemis vus).
	for t: Vector2 in TOURS + [TOUR_EST]:
		for k in 4:
			var q: Vector2 = t + Vector2(-8.0 + k * 2.8, 8.0 + (k % 2) * 1.5)
			if _deja_pris(q):
				continue
			_meule(tours, q, 0.6)
	_fusionner(dossier)


## Les fanaux à allumer gardent leur place (on ne pose pas de meule de décor dessus).
func _deja_pris(q: Vector2) -> bool:
	for f: Vector2 in FANAUX:
		if q.distance_to(f) < 3.0:
			return true
	return false


func _construire_fort() -> void:
	var dossier := Node3D.new()
	dossier.name = "PorteDeJade"
	_contenu.add_child(dossier)
	_fort_carre(dossier, FORT, 9.5, ["ouest", "nord"], 4.0)
	var y := hauteur(FORT.get_center().x, FORT.get_center().y)
	# Dans la cour : un auvent de garde, des râteliers d'armes, des jarres d'eau, un mât.
	_auvent(dossier, Vector2(FORT.end.x - 6.0, FORT.get_center().y), Vector2(4.0, 10.0), 2.6, Color(0.5, 0.42, 0.32))
	for k in 4:
		_jarre(dossier, Vector3(FORT.position.x + 5.0 + k * 1.1, y, FORT.end.y - 4.5), 1.0, k)
	var bois := _mat_bois()
	var mat := MeshInstance3D.new()
	mat.mesh = _cylindre(0.1, 0.14, 9.0, 8)
	mat.material_override = bois
	mat.position = Vector3(FORT.get_center().x, y + 4.5, FORT.get_center().y)
	dossier.add_child(mat)
	# La bannière rouge des Han au sommet du mât.
	var banniere := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 2.4)
	banniere.mesh = q
	var soie := _mat_soie(ROUGE_LAQUE).duplicate() as StandardMaterial3D
	soie.cull_mode = BaseMaterial3D.CULL_DISABLED
	banniere.material_override = soie
	banniere.position = Vector3(FORT.get_center().x + 0.85, y + 7.6, FORT.get_center().y)
	dossier.add_child(banniere)
	for k in 3:
		_boite(Vector3(0.12, 1.6, 2.0), Vector3(FORT.position.x + 4.0, y + 0.8, FORT.position.y + 6.0 + k * 3.0), bois, dossier)
	_fusionner(dossier)


func _construire_relais() -> void:
	var dossier := Node3D.new()
	dossier.name = "Relais"
	_contenu.add_child(dossier)
	var r := RELAIS
	var y := hauteur(r.get_center().x, r.get_center().y)
	var terre := _mat_terre_damee()
	# Un muret de terre autour de l'enclos, ouvert au nord sur la route.
	var largeur_porte := 6.0
	var gauche := PORTE_RELAIS.x - largeur_porte * 0.5 - r.position.x
	var droite := r.end.x - (PORTE_RELAIS.x + largeur_porte * 0.5)
	_boite(Vector3(gauche, 2.2, 0.9), Vector3(r.position.x + gauche * 0.5, y + 1.0, r.position.y), terre, dossier)
	_boite(Vector3(droite, 2.2, 0.9), Vector3(r.end.x - droite * 0.5, y + 1.0, r.position.y), terre, dossier)
	_boite(Vector3(r.size.x, 2.2, 0.9), Vector3(r.get_center().x, y + 1.0, r.end.y), terre, dossier)
	_boite(Vector3(0.9, 2.2, r.size.y), Vector3(r.position.x, y + 1.0, r.get_center().y), terre, dossier)
	_boite(Vector3(0.9, 2.2, r.size.y), Vector3(r.end.x, y + 1.0, r.get_center().y), terre, dossier)
	# La maison du relais (la poste de la frontière), au fond, avec son toit de roseaux.
	var maison := _maison(dossier, Vector2(r.end.x - 8.0, r.end.y - 5.0), Vector3(12, 3.4, 7), 0.0)
	maison.name = "MaisonRelais"
	_fusionner(dossier)
	# Les tentes, les chameaux couchés, les ballots de soie.
	var vie := Node3D.new()
	vie.name = "Caravaniers"
	_contenu.add_child(vie)
	_tente(vie, Vector2(r.position.x + 6.0, r.end.y - 6.0), 0.2, Color(0.62, 0.54, 0.44))
	_tente(vie, Vector2(r.position.x + 14.0, r.end.y - 5.0), -0.1, Color(0.48, 0.4, 0.34))
	_tente(vie, Vector2(r.end.x - 6.0, r.position.y + 9.0), 1.5, Color(0.7, 0.64, 0.56))
	for k in 4:
		_chameau(vie, Vector2(r.get_center().x - 4.0 + k * 3.4, r.get_center().y + 2.0 + (k % 2) * 2.5), 0.4 + k * 0.5, true, k % 2 == 0)
	for k in 3:
		_ballots_soie(vie, Vector2(r.position.x + 4.0 + k * 3.0, r.position.y + 4.0), 0.1 * k)
	# Le feu de camp des caravaniers.
	_feu_de_camp(vie, Vector2(r.get_center().x + 6.0, r.get_center().y - 2.0))


## Un petit feu de camp : un rond de pierres, des braises et des flammes, et sa lumière.
func _feu_de_camp(parent: Node3D, p: Vector2) -> void:
	var y := hauteur(p.x, p.y)
	for k in 8:
		var a := k * TAU / 8.0
		var pierre := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.18
		s.height = 0.24
		s.radial_segments = 6
		s.rings = 3
		pierre.mesh = s
		pierre.material_override = _mat_tuf()
		pierre.position = Vector3(p.x + cos(a) * 0.6, y + 0.06, p.y + sin(a) * 0.6)
		parent.add_child(pierre)
	var feu := StandardMaterial3D.new()
	feu.albedo_color = Color(1.0, 0.5, 0.15, 0.85)
	feu.emission_enabled = true
	feu.emission = Color(1.0, 0.45, 0.12)
	feu.emission_energy_multiplier = 4.0
	feu.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	feu.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for k in 3:
		var flamme := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = 0.18
		c.height = 0.6
		c.radial_segments = 6
		flamme.mesh = c
		flamme.material_override = feu
		flamme.position = Vector3(p.x + (k - 1) * 0.15, y + 0.32, p.y + (k % 2) * 0.12)
		parent.add_child(flamme)
	var lumiere := OmniLight3D.new()
	lumiere.light_color = Color(1.0, 0.6, 0.3)
	lumiere.light_energy = 2.0
	lumiere.omni_range = 7.0
	lumiere.position = Vector3(p.x, y + 1.0, p.y)
	parent.add_child(lumiere)


func _construire_route() -> void:
	# La route n'est pas pavée : une piste tassée, creusée d'ornières (on la voit au sol) ;
	# des bornes de bois marquent les relais, et une charrette abandonnée.
	var dossier := Node3D.new()
	dossier.name = "Route"
	_contenu.add_child(dossier)
	var bois := _mat_bois()
	for x in range(-150, 160, 40):
		var c := Vector2(float(x), 0.0)
		var meilleur := INF
		for i in ROUTE.size() - 1:
			var a: Vector2 = ROUTE[i]
			var b: Vector2 = ROUTE[i + 1]
			if c.x >= a.x and c.x <= b.x:
				c.y = lerpf(a.y, b.y, inverse_lerp(a.x, b.x, c.x))
				meilleur = 0.0
		if meilleur > 0.0:
			continue
		var borne := MeshInstance3D.new()
		borne.mesh = _cylindre(0.12, 0.14, 1.4, 6)
		borne.material_override = bois
		borne.position = Vector3(c.x, hauteur(c.x, c.y - 5.0) + 0.7, c.y - 5.0)
		dossier.add_child(borne)
	_charrette(dossier, Vector2(-128, -40), 0.7, false)


func _construire_lac() -> void:
	# Le lac salé gelé : une croûte blanche et craquelée, un peu de glace bleutée au milieu.
	var lac := MeshInstance3D.new()
	lac.name = "LacSale"
	var disque := CylinderMesh.new()
	disque.top_radius = RAYON_LAC
	disque.bottom_radius = RAYON_LAC
	disque.height = 0.05
	disque.radial_segments = 48
	lac.mesh = disque
	var sel := _mat_choix(["white_plaster_rough_01", "mud_cracked_dry_03"], Color(0.92, 0.92, 0.88), 0.7, 4.0).duplicate() as StandardMaterial3D
	lac.material_override = sel
	lac.position = Vector3(LAC.x, 1.45, LAC.y)
	_contenu.add_child(lac)
	var glace := MeshInstance3D.new()
	var d2 := CylinderMesh.new()
	d2.top_radius = RAYON_LAC * 0.45
	d2.bottom_radius = RAYON_LAC * 0.45
	d2.height = 0.04
	d2.radial_segments = 32
	glace.mesh = d2
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.66, 0.78, 0.84)
	m.roughness = 0.12
	m.metallic_specular = 0.9
	glace.material_override = m
	glace.position = Vector3(LAC.x + 4.0, 1.49, LAC.y + 6.0)
	_contenu.add_child(glace)


func _construire_vegetation() -> void:
	var arbres := Node3D.new()
	arbres.name = "Arbres"
	_contenu.add_child(arbres)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 60
	# Des peupliers de l'Euphrate autour du lac (l'oasis), et quelques-uns isolés.
	var plantes := 0
	var essais := 0
	while plantes < 30 and essais < 600:
		essais += 1
		var a := hasard.randf() * TAU
		var p := LAC + Vector2(cos(a), sin(a)) * hasard.randf_range(RAYON_LAC + 4.0, RAYON_LAC + 24.0)
		if absf(p.x) > 160.0 or absf(p.y) > 160.0 or p.distance_to(FAILLE) < 9.0 or p.distance_to(CHEF) < 9.0 \
				or _dans_rect(RELAIS.grow(6.0), p.x, p.y, 0.1) > 0.5:
			continue
		_peuplier_desert(arbres, p, hasard, hasard.randf_range(0.85, 1.25))
		plantes += 1
	# Des touffes de tamaris partout dans le désert de gravier.
	var buissons := Node3D.new()
	buissons.name = "Tamaris"
	_contenu.add_child(buissons)
	essais = 0
	plantes = 0
	while plantes < 160 and essais < 2500:
		essais += 1
		var p := Vector2(hasard.randf_range(-160.0, 160.0), hasard.randf_range(-70.0, 160.0))
		if distance_route(p) < 8.0 or distance_muraille(p) < 8.0 or _dans_rect(FORT.grow(8.0), p.x, p.y, 0.1) > 0.5 \
				or _dans_rect(RELAIS.grow(6.0), p.x, p.y, 0.1) > 0.5 or p.distance_to(PORTAIL) < 14.0 \
				or p.distance_to(LAC) < RAYON_LAC + 2.0 or _distance_piste(p) < 4.0 or p.distance_to(CARAVANE) < 12.0:
			continue
		_tamaris(buissons, p, hasard, hasard.randf_range(0.6, 1.3))
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
	# Des blocs de grès érodés (des « yardangs » en miniature) au sud du désert.
	while poses < 45 and essais < 900:
		essais += 1
		var x := hasard.randf_range(-160.0, 160.0)
		var z := hasard.randf_range(40.0, 160.0)
		var p := Vector2(x, z)
		if p.distance_to(PORTAIL) < 14.0 or p.distance_to(LAC) < RAYON_LAC + 6.0 or _distance_piste(p) < 5.0 \
				or _dans_rect(RELAIS.grow(8.0), x, z, 0.1) > 0.5:
			continue
		_placer_rocher(dossier, x, z, hasard.randf_range(0.6, 2.4))
		poses += 1


# --- Paysage lointain ----------------------------------------------------------------------

func _construire_lointain() -> void:
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.8
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 70
	# Le désert qui continue tout autour, les grandes dunes au nord, et au sud les monts
	# Qilian, couverts de neige.
	_plan_lointain(Vector3(0, 2.6, 0), Vector2(4000, 4000), Color(0.6, 0.4, 0))
	for m in [[Vector3(-600, -10, 1500), Vector3(1400, 420, 500)], [Vector3(900, -10, 1700), Vector3(1200, 520, 600)],
			[Vector3(200, -10, -1400), Vector3(1600, 90, 700)], [Vector3(-1500, -10, -500), Vector3(600, 70, 900)]]:
		bruit.seed = graine + hasard.randi()
		var montagne := MeshInstance3D.new()
		var neige := 0.6 if m[1].y > 300.0 else 0.0
		montagne.mesh = _maillage_bosse(bruit, m[1], 1.4, 0.3, 28, Color(0.2, neige, 0.2))
		montagne.material_override = _mat_lointain()
		montagne.position = m[0]
		montagne.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(montagne)
	# La muraille qui continue à perte de vue, et ses tours, des deux côtés.
	var lointain := Node3D.new()
	lointain.name = "MurailleLointaine"
	_contenu.add_child(lointain)
	var terre := _mat_terre_damee()
	for cote: float in [-1.0, 1.0]:
		var depart: Vector2 = MURAILLE[0] if cote < 0.0 else MURAILLE[MURAILLE.size() - 1]
		for k in 40:
			var x := depart.x + cote * (k * 22.0 + 11.0)
			var z := depart.y + sin(k * 0.4) * 6.0 - k * 0.6
			_boite(Vector3(22.5, 3.6, 3.0), Vector3(x, 2.6 + 1.6, z), terre, lointain, false)
			if k % 6 == 3:
				_boite(Vector3(6.0, 8.0, 6.0), Vector3(x, 2.6 + 4.0, z + 9.0), terre, lointain, false)
	_fusionner(lointain)
	# Les fanaux lointains qui répondent quand on a rallumé les trois premiers (chapitre 1).
	var fanaux := Node3D.new()
	fanaux.name = "FanauxLointains"
	fanaux.add_to_group("decor_quete")
	fanaux.set_meta("identifiant", "fanaux_lointains")
	fanaux.visible = false
	_contenu.add_child(fanaux)
	var feu := StandardMaterial3D.new()
	feu.albedo_color = Color(1.0, 0.55, 0.2)
	feu.emission_enabled = true
	feu.emission = Color(1.0, 0.5, 0.15)
	feu.emission_energy_multiplier = 6.0
	feu.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var fumee := StandardMaterial3D.new()
	fumee.albedo_color = Color(0.1, 0.09, 0.08, 0.5)
	fumee.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fumee.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for k in 6:
		var x: float = MURAILLE[MURAILLE.size() - 1].x + (k * 6 + 3) * 22.0
		var z: float = MURAILLE[MURAILLE.size() - 1].y + sin((k * 6 + 3) * 0.4) * 6.0 - (k * 6 + 3) * 0.6 + 9.0
		var flamme := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 1.2
		s.height = 2.4
		flamme.mesh = s
		flamme.material_override = feu
		flamme.position = Vector3(x, 2.6 + 9.2, z)
		fanaux.add_child(flamme)
		var colonne := MeshInstance3D.new()
		colonne.mesh = _cylindre(2.5, 1.0, 40.0, 8)
		colonne.material_override = fumee
		colonne.position = Vector3(x + 6.0, 2.6 + 30.0, z)
		colonne.rotation.z = -0.15
		colonne.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fanaux.add_child(colonne)


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
	# La route de l'est, vers le Fleuve Jaune : fermée jusqu'à la fin du chapitre 2.
	_mur_est = _mur_invisible(limites, Vector3(2, 14, 30), Vector3(SORTIE_EST.x - 4.0, hauteur(SORTIE_EST.x, SORTIE_EST.y) + 6.0, SORTIE_EST.y))


# --- Personnages et objets de la quête ----------------------------------------------------------

func _construire_quete() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quete"
	_contenu.add_child(dossier)
	_construire_secondaires(dossier)
	_dossier_quete = dossier
	_construire_portail(dossier, PORTAIL, PI)
	# La vieille tour de guet du portail, en ruine, et le feu de Masque.
	var ruine := _tour_fanal(dossier, TOUR_PORTAIL, 7.0, 6.5, true)
	ruine.name = "TourDuPortail"
	_feu_de_camp(dossier, FEU_MASQUE)
	_pnj(dossier, "masque_jade", MASQUE, -PI * 0.25)
	for r in [["allier_masque", "[F] « D'accord. On cherche le même homme. »", Vector2(-2.2, -2.4)],
			["mefier_masque", "[F] « Je ne te fais pas confiance, Roche. »", Vector2(2.4, -2.0)]]:
		var reponse := ObjetChine.new()
		reponse.name = String(r[0]).to_pascal_case()
		reponse.identifiant = r[0]
		reponse.invite = r[1]
		reponse.portee = 2.0
		var q: Vector2 = MASQUE + r[2]
		reponse.position = Vector3(q.x, hauteur(q.x, q.y), q.y)
		dossier.add_child(reponse)
	# La radio que Vera a laissée pour toi sur une pierre, près du feu.
	var radio := ObjetChine.new()
	radio.name = "RadioVera"
	radio.identifiant = "radio_vera"
	radio.forme = "radio_vigie"
	radio.invite = "[F] Prendre la radio qui grésille"
	radio.position = Vector3(RADIO.x, hauteur(RADIO.x, RADIO.y), RADIO.y)
	dossier.add_child(radio)
	# La caravane de soie attaquée : des chameaux chargés, des ballots, Wang Ba et les siens.
	var caravane := Node3D.new()
	caravane.name = "CaravaneSoie"
	caravane.position = Vector3(CARAVANE.x, hauteur(CARAVANE.x, CARAVANE.y), CARAVANE.y)
	caravane.set_meta("identifiant", "caravane_soie")
	caravane.add_to_group("decor_quete")
	dossier.add_child(caravane)
	# Les chameaux de la caravane sont posés autour de son centre (ils la suivent).
	for k in 3:
		var c := _chameau(caravane, Vector2.ZERO, 0.0, false, true)
		c.position = Vector3(-2.6 + k * 3.0, 0, (k % 2) * 1.4)
		c.rotation.y = 0.1
	var ballots := _ballots_soie(caravane, Vector2.ZERO, 0.4, 4)
	ballots.position = Vector3(1.5, 0, -2.2)
	_pnj(dossier, "wang_ba", WANG_BA, PI * 0.8)
	for k in MARCHANDS.size():
		_pnj(dossier, "caravanier_%d" % (k + 1), MARCHANDS[k], PI * (0.4 + k * 0.4))
	# Ban Yong : d'abord sur la route (il arrive avec ses soldats), puis à la porte du fort.
	var ban_yong_route := _pnj(dossier, "ban_yong_route", BAN_YONG_ROUTE, -PI * 0.7)
	ban_yong_route.add_to_group("decor_quete")
	ban_yong_route.set_meta("identifiant", "ban_yong_route")
	ban_yong_route.visible = false
	_pnj(dossier, "ban_yong", BAN_YONG, -PI / 2)
	# Les fanaux éteints au pied des trois tours.
	for k in FANAUX.size():
		var p: Vector2 = FANAUX[k]
		var fanal := ObjetChine.new()
		fanal.name = "Fanal%d" % k
		fanal.identifiant = "fanal_%d" % k
		fanal.groupe = "fanal"
		fanal.forme = "fanal"
		fanal.invite = "[F] Rallumer le fanal"
		fanal.portee = 3.2
		fanal.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
		dossier.add_child(fanal)
	# Les Figés de la cour du fort, et un objet invisible sur chacun pour leur rendre
	# la mémoire (calligraphie).
	var ids_figes := ["fige_soldat", "fige_arbaletrier", "fige_cuisinier", "fige_marchand"]
	for k in FIGES.size():
		var p: Vector2 = FIGES[k]
		_pnj(dossier, ids_figes[k], p, TAU * k / FIGES.size() + 0.4)
		var memoire := ObjetChine.new()
		memoire.name = "Memoire%d" % k
		memoire.identifiant = "memoire_%d" % k
		memoire.groupe = "fige_fort"
		memoire.invite = "[F] Rendre la mémoire (tracer un caractère)"
		memoire.portee = 2.2
		memoire.set_meta("pnj_lie", ids_figes[k])
		memoire.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
		dossier.add_child(memoire)
	# Au relais : le scribe de la poste, Gan Ying, et les lattes qui brûlent.
	_pnj(dossier, "scribe_jade", SCRIBE, PI * 0.3)
	_pnj(dossier, "gan_ying", GAN_YING, -PI * 0.2)
	for k in LATTES.size():
		var p: Vector2 = LATTES[k]
		var lattes := ObjetChine.new()
		lattes.name = "Lattes%d" % k
		lattes.identifiant = "lattes_%d" % k
		lattes.groupe = "lattes"
		lattes.forme = "lattes"
		lattes.invite = "[F] Étouffer les flammes"
		lattes.portee = 2.6
		lattes.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
		dossier.add_child(lattes)
	var faille := Faille.new()
	faille.name = "Faille"
	faille.identifiant = "faille_jade"
	faille.position = Vector3(FAILLE.x, hauteur(FAILLE.x, FAILLE.y), FAILLE.y)
	dossier.add_child(faille)
	# Le campement du chef des pillards, au bord du lac.
	_tente(dossier, CHEF + Vector2(-4, 6), 0.8, Color(0.3, 0.26, 0.22))
	_feu_de_camp(dossier, CHEF + Vector2(3, 3))
	# Repères de la carte.
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.PORTAIL, "Portail de la Vigie", PORTAIL)
	repere.call(MarqueurCarte.Type.DANGER, "Faille", FAILLE)
	repere.call(MarqueurCarte.Type.LIEU, "Fort de la Porte de Jade", FORT.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Relais des caravanes", RELAIS.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Grande Muraille des Han", MURAILLE[2])
	repere.call(MarqueurCarte.Type.LIEU, "Lac salé", LAC)
	repere.call(MarqueurCarte.Type.LIEU, "Route de la soie, vers l'est et le Fleuve Jaune", SORTIE_EST)


# --- La route de l'est ------------------------------------------------------------------------

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
	if not _est_ouvert:
		if not quete.etape_atteinte("vers_fleuve"):
			return
		_est_ouvert = true
		if _mur_est != null and is_instance_valid(_mur_est):
			_mur_est.queue_free()
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return
	var p := Vector2(joueur.global_position.x, joueur.global_position.z)
	if p.distance_to(SORTIE_EST) < 6.0 and quete.donnees.get("zones", {}).has("fleuve_jaune"):
		quete.changer_de_zone("fleuve_jaune")


## Les personnages des quêtes secondaires (data/chine_secondaires.json).
func _construire_secondaires(dossier: Node3D) -> void:
	_pnj(dossier, "sergent_cuju", Vector2(38, 18), PI * 0.8)
