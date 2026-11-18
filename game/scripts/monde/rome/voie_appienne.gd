@tool
extends "res://scripts/monde/rome/ile_rome.gd"
## Île de Rome, zone 1 : la Voie Appienne (niveaux 30-32).
##
## L'été de l'an 80, à quelques milles au sud de Rome. La « reine des routes » file
## tout droit du sud (vers Capoue et la Campanie, où le Vésuve a enseveli Pompéi l'an
## dernier) au nord (vers la campagne, les aqueducs et Rome). Elle est bordée de
## tombeaux (les Romains enterrent leurs morts le long des routes, hors des villes),
## dont le grand tombeau rond de Caecilia Metella, de pins parasols et de cyprès. À
## l'est de la route : le relais de poste (la « mansio ») de Petronius, une auberge,
## des vignes. Le portail de la Vigie s'est ouvert devant un tombeau abandonné, à l'ouest.
##
## Tout est construit par le code (voir ile_rome.gd). Le bouton « Reconstruire » de
## l'Inspecteur refait tout. Repères : le nord est vers -Z.

const Faille := preload("res://scripts/monde/prehistoire/faille.gd")
const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const ObjetRome := preload("res://scripts/monde/rome/objet_rome.gd")

## La voie Appienne, du sud (Campanie) au nord (Rome).
const VOIE := [Vector2(10, 162), Vector2(6, 100), Vector2(2, 40), Vector2(0, -20), Vector2(-3, -90), Vector2(-8, -162)]
## Le portail de la Vigie, devant un vieux tombeau abandonné à l'ouest de la route.
const PORTAIL := Vector2(-40, 112)
const TOMBEAU_PORTAIL := Vector2(-40, 124)
## La radio laissée par l'agent Livia Conti sur les marches du tombeau.
const RADIO := Vector2(-34, 107)
## Le sentier qui mène du tombeau à la route.
const SENTIER := [Vector2(-40, 106), Vector2(-26, 100), Vector2(-12, 96), Vector2(5, 94)]
## Le convoi des réfugiés de Pompéi, attaqué sur la route.
const CONVOI := Vector2(7, 70)
const CAECILIA := Vector2(10, 74)
const FAUSTA := Vector2(13.5, 77.0)
const REFUGIES := [Vector2(4, 72), Vector2(12, 67), Vector2(3, 66)]
## La meute et le lion évadé, qui attaquent le convoi.
const MEUTE := Vector2(18, 58)
const LION := Vector2(-6, 56)
## L'escorte : du convoi jusqu'au relais de Petronius.
const ESCORTE := [Vector2(6, 70), Vector2(4, 44), Vector2(2, 16), Vector2(1, -8), Vector2(4, -18)]
## Le relais de poste (la mansio) : une cour fermée, à l'est de la route.
const MANSIO := Rect2(12, -40, 26, 24)
const PORTE_MANSIO := Vector2(12, -28)
const PETRONIUS := Vector2(9.5, -26)
## Dans la cour : les Égarés qui ne se comprennent plus, et la place de l'agent Livia.
const EGARES := [Vector2(18, -33), Vector2(22, -24), Vector2(28, -31), Vector2(32, -22)]
const LIVIA := Vector2(16, -21)
## L'auberge (la taberna) de l'autre côté de la cour.
const AUBERGE := Vector2(26, -6)
## Les bornes milliaires renversées au nord du relais, et la faille.
const MILLIAIRES := [Vector2(3.5, -52), Vector2(-5.5, -86), Vector2(-1.0, -118)]
const FAILLE := Vector2(-18, -104)
## Le grand tombeau rond de Caecilia Metella, à l'ouest de la route.
const CAECILIA_METELLA := Vector2(-34, -58)
## Les sorties : vers Rome au nord (ouverte plus tard), vers Pompéi au sud (fermée).
const SORTIE_NORD := Vector2(-8, -150)
const SORTIE_SUD := Vector2(10, 150)

var _mur_nord: StaticBody3D
var _mur_sud: StaticBody3D
var _sud_ouvert := false
var _nord_ouvert := false
var _attente_sortie := 0.0


func _init() -> void:
	identifiant_zone = "voie_appienne"
	taille_terrain = 320
	graine = 80
	point_apparition = PORTAIL + Vector2(2, -6)
	nombre_touffes = 60000
	fertilite_sols = Vector3(0.3, 1.0, 0.05)
	reglages_couvre_sol = {"cailloux": 6.0, "fleurs": [Color(0.82, 0.1, 0.06), Color(0.95, 0.78, 0.12), Color(0.58, 0.38, 0.75)], "densite_fleurs": 2.0}
	neige_qui_tombe = false
	sols = {
		# Rouge : la terre battue des bas-côtés et des chemins.
		"galets": ["dry_ground_01", "mud_cracked_dry_03", "dry_ground_rocks"],
		# Vert : les prés secs et la terre brune du Latium.
		"neige": ["brown_mud_02", "dry_ground_rocks", "dry_ground_01"],
		# Bleu : la terre tassée autour du relais et de la route.
		"sol": ["dry_ground_rocks", "dry_ground_01", "mud_cracked_dry_03"],
		"roche": ["rock_boulder_dry", "cliff_side", "rock_wall_10"],
	}
	reglages_terrain = {"sol_saturation": 0.85, "sol_motif": 4.0, "galets_motif": 3.0, "neige_motif": 5.0,
			"sol_teinte": Color(1.0, 0.95, 0.86), "roche_teinte": Color(0.95, 0.92, 0.86), "roche_saturation": 0.7,
			"neige_eclat": 1.0, "neige_paillettes": 0.0, "roche_motif": 10.0,
			# La « neige » est ici la terre brune des prés.
			"neige_teinte": Color(0.95, 0.86, 0.7), "neige_max": Vector3(0.5, 0.42, 0.3), "neige_simple": Color(0.48, 0.42, 0.3),
			"givre": 0.0, "neige_translucide": 0.0}
	reglages_herbe = {"couleur_base": Color(0.22, 0.24, 0.1), "couleur_pointe": Color(0.66, 0.62, 0.34),
			"couleur_givre": Color(0.62, 0.58, 0.34), "force_vent": 0.25}
	piste = SENTIER.duplicate()


func _ready() -> void:
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_rome", "") != "":
		var venu := String(Reseau.get_meta("arrivee_rome"))
		Reseau.remove_meta("arrivee_rome")
		# Retour de la campagne : on arrive au nord, sur la route ; de Pompéi, au sud.
		point_apparition = SORTIE_SUD + Vector2(-2, -12) if venu == "pompei" else SORTIE_NORD + Vector2(2, 10)
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	if zone == "voie_appienne":
		return Vector2.INF
	return SORTIE_SUD + Vector2(0, -8) if zone == "pompei" else SORTIE_NORD


# --- Relief -----------------------------------------------------------------------------

func _preparer_bruits() -> void:
	super._preparer_bruits()
	_relief.frequency = 0.008


## Distance à la voie Appienne (en mètres).
func distance_voie(p: Vector2) -> float:
	var meilleure := INF
	for i in VOIE.size() - 1:
		meilleure = minf(meilleure, _distance_segment(p, VOIE[i], VOIE[i + 1]))
	return meilleure


func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	var bruit := _relief.get_noise_2d(x, z)
	var fin := _details.get_noise_2d(x * 3.0, z * 3.0)
	# La campagne : de larges ondulations, une petite crête de tuf à l'ouest.
	var h := 3.0 + bruit * 2.6 + fin * 0.1
	h += smoothstep(-60.0, -150.0, x) * (5.0 + bruit * 4.0)
	h += smoothstep(70.0, 150.0, x) * 2.0 * (1.0 + bruit)
	# La route : posée sur un remblai régulier, qui monte doucement vers le nord.
	var p := Vector2(x, z)
	var d_voie := distance_voie(p)
	var h_route := 3.2 + (-z) * 0.006
	h = lerpf(h, h_route, 1.0 - smoothstep(5.0, 16.0, d_voie))
	# La cour du relais et l'auberge : un terre-plein.
	h = lerpf(h, h_route + 0.1, _dans_rect(MANSIO.grow(6.0).merge(Rect2(AUBERGE - Vector2(8, 6), Vector2(16, 12))), x, z, 5.0))
	# Le replat devant le tombeau du portail.
	h = lerpf(h, 3.6 + fin * 0.04, 1.0 - smoothstep(9.0, 15.0, p.distance_to(PORTAIL + Vector2(0, 4))))
	# Le sentier du tombeau.
	var d_sentier := _distance_piste(p)
	h = lerpf(h, minf(h, 3.6), (1.0 - smoothstep(2.5, 6.0, d_sentier)) * 0.6)
	return h


## Rouge : terre battue des bas-côtés ; vert : prés ; bleu : terre tassée du relais.
func _parts_sol(x: float, z: float, h: float) -> Color:
	var p := Vector2(x, z)
	var n := _relief.get_noise_2d(x * 2.0 + 60.0, z * 2.0)
	var bord := 1.0 - smoothstep(3.5, 7.5 + n * 2.0, distance_voie(p))
	bord = maxf(bord, 1.0 - smoothstep(1.2, 3.0, _distance_piste(p)))
	var cour := _dans_rect(MANSIO.grow(4.0), x, z, 3.0)
	var pres := (1.0 - bord) * (1.0 - cour)
	return Color(bord * (1.0 - cour), pres, cour, 1.0)


# --- Construction -------------------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_construire_terrain()
	_construire_route()
	_construire_tombeaux()
	_construire_mansio()
	_construire_vignes()
	_construire_vegetation()
	_construire_rochers()
	_construire_touffes()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_appliquer_ciel()


func _construire_route() -> void:
	var route := Node3D.new()
	route.name = "VoieAppienne"
	_contenu.add_child(route)
	_voie(route, VOIE, 4.8)
	# Les bornes milliaires encore debout, tous les mille pas (environ 1,5 km : on en met
	# quelques-unes, plus rapprochées, pour le décor).
	_milliaire(route, Vector2(10.5, 128), 0.0)
	_milliaire(route, Vector2(-6.5, 18), 0.0)


# --- Les tombeaux --------------------------------------------------------------------------

func _construire_tombeaux() -> void:
	var tombeaux := Node3D.new()
	tombeaux.name = "Tombeaux"
	_contenu.add_child(tombeaux)
	# Le grand tombeau rond de Caecilia Metella.
	var cm := _tombeau_tambour(tombeaux, CAECILIA_METELLA, 10.0, 11.0)
	cm.name = "TombeauCaeciliaMetella"
	# Le tombeau abandonné du portail : un édicule en ruine, envahi d'herbe.
	var abandonne := _tombeau_edicule(tombeaux, TOMBEAU_PORTAIL, PI, 1.3, true)
	abandonne.name = "TombeauDuPortail"
	# Un muret effondré qui entourait l'enclos du tombeau.
	for k in 7:
		var a := lerpf(0.4, PI - 0.4, float(k) / 6.0)
		var p := TOMBEAU_PORTAIL + Vector2(cos(a) * 12.0, sin(a) * -2.0 + 2.0)
		if k == 3:
			continue
		_boite(Vector3(3.2, 0.6 + 0.4 * (k % 2), 0.6), Vector3(p.x, hauteur(p.x, p.y) + 0.25, p.y), _mat_tuf(), tombeaux)
	# Les tombeaux le long de la route, des deux côtés.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 10
	var z := 140.0
	while z > -150.0:
		for cote: float in [-1.0, 1.0]:
			if hasard.randf() < 0.35:
				continue
			var centre_voie := _point_voie(z)
			var p := Vector2(centre_voie.x + cote * hasard.randf_range(10.0, 16.0), z + hasard.randf_range(-3.0, 3.0))
			if p.distance_to(CAECILIA_METELLA) < 18.0 or p.distance_to(TOMBEAU_PORTAIL) < 16.0 \
					or _dans_rect(MANSIO.grow(10.0), p.x, p.y, 0.1) > 0.5 or p.distance_to(AUBERGE) < 12.0 \
					or p.distance_to(CONVOI) < 12.0 or p.distance_to(LION) < 6.0 or p.distance_to(FAILLE) < 8.0 \
					or _distance_piste(p) < 6.0:
				continue
			var angle := -PI / 2 * cote
			match hasard.randi() % 3:
				0:
					_tombeau_edicule(tombeaux, p, angle, hasard.randf_range(0.8, 1.1))
				1:
					_tombeau_autel(tombeaux, p, angle)
				_:
					_tombeau_tambour(tombeaux, p, hasard.randf_range(2.6, 4.2), hasard.randf_range(3.0, 5.0))
		z -= hasard.randf_range(12.0, 18.0)


## Le point de la voie à une profondeur z donnée.
func _point_voie(z: float) -> Vector2:
	for i in VOIE.size() - 1:
		var a: Vector2 = VOIE[i]
		var b: Vector2 = VOIE[i + 1]
		if (z <= a.y and z >= b.y):
			return a.lerp(b, inverse_lerp(a.y, b.y, z))
	return VOIE[0] if z > VOIE[0].y else VOIE[VOIE.size() - 1]


# --- Le relais de poste (mansio) et l'auberge ----------------------------------------------

func _construire_mansio() -> void:
	var mansio := Node3D.new()
	mansio.name = "Mansio"
	_contenu.add_child(mansio)
	var r := MANSIO
	var y := hauteur(r.get_center().x, r.get_center().y)
	var haut := 4.2
	var brique := _mat_brique()
	var enduit := _mat_enduit_peint(Color(0.88, 0.76, 0.56))
	# Les quatre ailes autour de la cour : des pièces sous un toit de tuiles qui penche
	# vers la cour (chambres, écuries, réserve). La porte charretière à l'ouest.
	var aile := 5.0
	var ailes := [
		[Vector2(r.get_center().x, r.position.y + aile * 0.5), Vector3(r.size.x, haut, aile)],
		[Vector2(r.get_center().x, r.end.y - aile * 0.5), Vector3(r.size.x, haut, aile)],
		[Vector2(r.end.x - aile * 0.5, r.get_center().y), Vector3(aile, haut, r.size.y - aile * 2.0)],
	]
	for a in ailes:
		var c: Vector2 = a[0]
		var t: Vector3 = a[1]
		_boite(Vector3(t.x, t.y * 0.4, t.z), Vector3(c.x, y + t.y * 0.2, c.y), enduit, mansio)
		_boite(Vector3(t.x - 0.04, t.y * 0.6, t.z - 0.04), Vector3(c.x, y + t.y * 0.7, c.y), brique, mansio)
		_toit_aile(mansio, Vector3(c.x, y + t.y, c.y), t)
	# Le mur ouest, coupé par la grande porte (pour les charrettes et les chevaux de poste).
	var largeur_porte := 4.4
	var nord := (PORTE_MANSIO.y - largeur_porte * 0.5) - (r.position.y + aile)
	var sud := (r.end.y - aile) - (PORTE_MANSIO.y + largeur_porte * 0.5)
	_boite(Vector3(0.8, haut * 0.8, nord), Vector3(r.position.x, y + haut * 0.4, r.position.y + aile + nord * 0.5), brique, mansio)
	_boite(Vector3(0.8, haut * 0.8, sud), Vector3(r.position.x, y + haut * 0.4, r.end.y - aile - sud * 0.5), brique, mansio)
	for cote: float in [-1.0, 1.0]:
		_boite(Vector3(1.2, haut + 0.6, 1.2), Vector3(r.position.x, y + (haut + 0.6) * 0.5, PORTE_MANSIO.y + cote * (largeur_porte * 0.5 + 0.6)), _mat_tuf(), mansio)
	_boite(Vector3(1.4, 0.8, largeur_porte + 2.4), Vector3(r.position.x, y + haut + 0.6, PORTE_MANSIO.y), _mat_tuf(), mansio, false)
	# Un portique de bois devant les chambres (aile est), un puits au milieu de la cour,
	# un abreuvoir, des charrettes dételées.
	for k in 4:
		var poteau := MeshInstance3D.new()
		poteau.mesh = _cylindre(0.12, 0.14, 2.8, 8)
		poteau.material_override = _mat_bois()
		poteau.position = Vector3(r.end.x - aile - 1.6, y + 1.4, r.position.y + aile + 2.5 + k * 3.5)
		mansio.add_child(poteau)
	var c := r.get_center()
	var puits := MeshInstance3D.new()
	puits.mesh = _cylindre(0.8, 0.85, 0.9, 16)
	puits.material_override = _mat_tuf()
	puits.position = Vector3(c.x, y + 0.45, c.y)
	mansio.add_child(puits)
	_boite(Vector3(0.12, 2.0, 0.12), Vector3(c.x - 0.7, y + 1.0, c.y), _mat_bois(), mansio, false)
	_boite(Vector3(0.12, 2.0, 0.12), Vector3(c.x + 0.7, y + 1.0, c.y), _mat_bois(), mansio, false)
	_boite(Vector3(1.6, 0.12, 0.12), Vector3(c.x, y + 2.0, c.y), _mat_bois(), mansio, false)
	_boite(Vector3(3.0, 0.6, 0.8), Vector3(r.position.x + 4.0, y + 0.3, r.end.y - aile - 1.0), _mat_tuf(), mansio)
	_charrette(mansio, Vector2(r.end.x - aile - 4.0, r.end.y - aile - 2.5), 1.3, false)
	_charrette(mansio, Vector2(r.position.x + 6.0, r.position.y + aile + 2.0), -0.4, true)
	for k in 5:
		_amphore(mansio, Vector3(r.end.x - aile - 0.6, y, r.position.y + aile + 1.0 + k * 0.6), 0.9, k)
	# L'enseigne peinte au-dessus de la porte.
	_boite(Vector3(0.08, 0.7, 2.4), Vector3(r.position.x - 0.45, y + haut - 0.2, PORTE_MANSIO.y), _mat_enduit_peint(ROUGE_POMPEIEN), mansio, false)
	# L'auberge, de l'autre côté de la cour au sud, avec son comptoir sur la rue.
	var auberge := _batiment_romain(mansio, AUBERGE, Vector3(12, 4.6, 8), 0.0, Color(0.8, 0.58, 0.38))
	auberge.name = "Auberge"
	_boite(Vector3(4.0, 1.1, 0.8), Vector3(AUBERGE.x - 7.0, hauteur(AUBERGE.x, AUBERGE.y) + 0.55, AUBERGE.y + 2.0), _mat_travertin(), mansio)
	_auvent(mansio, AUBERGE + Vector2(-7.5, 2.0), Vector2(4.6, 2.6), 2.6, Color(0.7, 0.32, 0.2))
	_fusionner_simple(mansio)


## Un toit d'aile : une seule pente de tuiles, qui descend vers la cour.
func _toit_aile(parent: Node3D, sommet: Vector3, t: Vector3) -> void:
	var largeur := t.z if t.x > t.z else t.x
	var longueur := t.x if t.x > t.z else t.z
	var pan := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(longueur + 0.6, 0.16, largeur + 1.0)
	pan.mesh = b
	pan.material_override = _mat_tuiles()
	pan.position = sommet + Vector3(0, 0.45, 0)
	var vers_cour := (MANSIO.get_center() - Vector2(sommet.x, sommet.z))
	if t.x > t.z:
		pan.rotation.x = -0.28 * signf(vers_cour.y)
	else:
		pan.rotation.y = PI / 2
		pan.rotation.x = 0.28 * signf(vers_cour.x)
	parent.add_child(pan)


## Fusionne les boîtes, sauf ce qui doit rester à part (les charrettes et les amphores).
func _fusionner_simple(dossier: Node3D) -> void:
	_fusionner(dossier)


# --- Vignes, arbres, rochers ---------------------------------------------------------------

func _construire_vignes() -> void:
	var vignes := Node3D.new()
	vignes.name = "Vignes"
	_contenu.add_child(vignes)
	var feuille := _mat_feuillage(Color(0.3, 0.38, 0.14))
	var bois := _mat_bois()
	# Des rangs de vigne sur échalas, à l'est du relais.
	for rang in 9:
		var x := 62.0 + rang * 4.0
		var z := -40.0
		while z < 40.0:
			var y := hauteur(x, z)
			var cep := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 0.7
			s.height = 1.1
			s.radial_segments = 8
			s.rings = 4
			cep.mesh = s
			cep.material_override = feuille
			cep.position = Vector3(x, y + 0.9, z)
			vignes.add_child(cep)
			var echalas := MeshInstance3D.new()
			echalas.mesh = _cylindre(0.03, 0.04, 1.6, 5)
			echalas.material_override = bois
			echalas.position = Vector3(x, y + 0.8, z + 0.5)
			vignes.add_child(echalas)
			z += 2.2
	_fusionner(vignes)


func _construire_vegetation() -> void:
	var arbres := Node3D.new()
	arbres.name = "Arbres"
	_contenu.add_child(arbres)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 60
	# Les pins parasols et les cyprès qui bordent la route, comme aujourd'hui encore.
	var z := 150.0
	while z > -150.0:
		var c := _point_voie(z)
		for cote: float in [-1.0, 1.0]:
			if hasard.randf() < 0.45:
				continue
			var p := Vector2(c.x + cote * hasard.randf_range(6.5, 9.0), z + hasard.randf_range(-2.0, 2.0))
			if _dans_rect(MANSIO.grow(4.0), p.x, p.y, 0.1) > 0.5 or p.distance_to(CONVOI) < 8.0 \
					or p.distance_to(PETRONIUS) < 5.0 or _distance_piste(p) < 3.0:
				continue
			if hasard.randf() < 0.6:
				_pin_parasol(arbres, p, hasard, hasard.randf_range(0.85, 1.15))
			else:
				_cypres(arbres, p, hasard)
		z -= hasard.randf_range(7.0, 12.0)
	# Des pins isolés et des oliviers dans la campagne.
	var plantes := 0
	var essais := 0
	while plantes < 60 and essais < 800:
		essais += 1
		var p := Vector2(hasard.randf_range(-150.0, 150.0), hasard.randf_range(-150.0, 150.0))
		if distance_voie(p) < 14.0 or _dans_rect(MANSIO.grow(10.0), p.x, p.y, 0.1) > 0.5 \
				or p.distance_to(CAECILIA_METELLA) < 16.0 or p.distance_to(PORTAIL) < 14.0 or p.distance_to(TOMBEAU_PORTAIL) < 10.0 \
				or p.distance_to(FAILLE) < 8.0 or (p.x > 56.0 and p.x < 100.0 and absf(p.y) < 44.0) or _distance_piste(p) < 4.0:
			continue
		if hasard.randf() < 0.55:
			_pin_parasol(arbres, p, hasard, hasard.randf_range(0.8, 1.2))
		else:
			_olivier(arbres, p, hasard, hasard.randf_range(0.8, 1.2))
		plantes += 1
	# Trois cyprès près du tombeau du portail.
	for k in 3:
		_cypres(arbres, TOMBEAU_PORTAIL + Vector2(-9.0 + k * 9.0, 6.0), hasard)


func _construire_rochers() -> void:
	var dossier := Node3D.new()
	dossier.name = "Rochers"
	_contenu.add_child(dossier)
	_preparer_rochers()
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 12
	var poses := 0
	var essais := 0
	# Des blocs de tuf qui affleurent sur la petite crête de l'ouest.
	while poses < 60 and essais < 900:
		essais += 1
		var x := hasard.randf_range(-155.0, -70.0)
		var z := hasard.randf_range(-155.0, 155.0)
		if Vector2(x, z).distance_to(PORTAIL) < 14.0:
			continue
		_placer_rocher(dossier, x, z, hasard.randf_range(0.6, 2.2))
		poses += 1


# --- Paysage lointain ----------------------------------------------------------------------

func _construire_lointain() -> void:
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.8
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 70
	# La campagne qui continue tout autour, puis les monts Albains au sud-est et les
	# monts Sabins au nord-est.
	_plan_lointain(Vector3(0, 2.6, 0), Vector2(4000, 4000), Color(0, 1, 0))
	for m in [[Vector3(1400, -10, 900), Vector3(900, 260, 700)], [Vector3(1800, -10, -1400), Vector3(700, 300, 900)],
			[Vector3(-1600, -10, 300), Vector3(500, 80, 900)]]:
		bruit.seed = graine + hasard.randi()
		var montagne := MeshInstance3D.new()
		montagne.mesh = _maillage_bosse(bruit, m[1], 1.4, 0.3, 28, Color(0, 0.6, 0.4))
		montagne.material_override = _mat_lointain()
		montagne.position = m[0]
		montagne.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(montagne)
	# Les arches des aqueducs (l'Aqua Claudia), qui filent des monts vers Rome, au nord-est.
	var lointain := Node3D.new()
	lointain.name = "AqueducsLointains"
	_contenu.add_child(lointain)
	_arches_aqueduc(lointain, Vector3(900, 2.6, 300), Vector3(260, 2.6, -700), 26.0, 9.0)
	_arches_aqueduc(lointain, Vector3(260, 2.6, -700), Vector3(80, 2.6, -1300), 26.0, 9.0)
	# Et, plus près, une ligne d'arches plus basses (l'Aqua Marcia).
	_arches_aqueduc(lointain, Vector3(600, 2.6, 520), Vector3(200, 2.6, -360), 16.0, 6.5)


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
	# La route du nord, vers la campagne et Rome : fermée jusqu'au chapitre 3.
	_mur_nord = _mur_invisible(limites, Vector3(30, 14, 2), Vector3(SORTIE_NORD.x, hauteur(SORTIE_NORD.x, SORTIE_NORD.y) + 6.0, SORTIE_NORD.y + 4.0))
	# La route du sud, vers Pompéi : fermée (chapitre 6).
	_mur_sud = _mur_invisible(limites, Vector3(30, 14, 2), Vector3(SORTIE_SUD.x, hauteur(SORTIE_SUD.x, SORTIE_SUD.y) + 6.0, SORTIE_SUD.y - 4.0))


# --- Personnages et objets de la quête ----------------------------------------------------------

func _construire_quete() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quete"
	_contenu.add_child(dossier)
	_dossier_quete = dossier
	_construire_portail(dossier, PORTAIL, PI)
	# La radio de la Vigie, laissée par l'agent Livia Conti sur les marches du tombeau.
	var radio := ObjetRome.new()
	radio.name = "RadioVigie"
	radio.identifiant = "radio_livia"
	radio.forme = "radio_vigie"
	radio.invite = "[F] Prendre la radio de la Vigie"
	radio.position = Vector3(RADIO.x, hauteur(RADIO.x, RADIO.y), RADIO.y)
	dossier.add_child(radio)
	# Le convoi des réfugiés de Pompéi : la charrette, Caecilia, Fausta et les autres.
	var charrette := _charrette(dossier, CONVOI, 0.1, true)
	charrette.name = "CharretteRefugies"
	charrette.set_meta("identifiant", "charrette_refugies")
	charrette.add_to_group("decor_quete")
	_pnj(dossier, "caecilia", CAECILIA, PI * 0.8)
	_pnj(dossier, "fausta", FAUSTA, PI * 0.9)
	for k in REFUGIES.size():
		_pnj(dossier, "refugie_%d" % (k + 1), REFUGIES[k], PI * (0.6 + k * 0.3))
	# Au relais : Petronius devant la porte, l'agent Livia Conti (montrée à la fin du ch. 2).
	_pnj(dossier, "petronius", PETRONIUS, -PI / 2)
	var livia := _pnj(dossier, "livia", LIVIA, -PI * 0.6)
	livia.add_to_group("decor_quete")
	livia.set_meta("identifiant", "livia")
	livia.visible = false
	_pnj(dossier, "aubergiste", AUBERGE + Vector2(-7.0, 3.4), PI)
	# Quêtes secondaires : l'agent Lenoir, du service Nettoyage de la Vigie.
	_pnj(dossier, "lenoir_appia", Vector2(-28, 104), PI * 0.3)
	# Les Égarés de la cour : des gens qui ne se comprennent plus. Un objet invisible sur
	# chacun : on le « renoue » en remettant sa phrase dans l'ordre.
	var ids_egares := ["egare_muletier", "egare_refugie", "egare_servante", "egare_marchand"]
	for k in EGARES.size():
		var p: Vector2 = EGARES[k]
		_pnj(dossier, ids_egares[k], p, TAU * k / EGARES.size())
		var renouer := ObjetRome.new()
		renouer.name = "Renouer%d" % k
		renouer.identifiant = "renouer_%d" % k
		renouer.groupe = "egare_relais"
		renouer.invite = "[F] Renouer (remettre ses mots dans l'ordre)"
		renouer.portee = 2.2
		renouer.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
		dossier.add_child(renouer)
	# Les bornes milliaires renversées au nord du relais.
	for k in MILLIAIRES.size():
		var p: Vector2 = MILLIAIRES[k]
		var borne := ObjetRome.new()
		borne.name = "Milliaire%d" % k
		borne.identifiant = "milliaire_%d" % k
		borne.groupe = "milliaire"
		borne.forme = "milliaire"
		borne.invite = "[F] Redresser la borne milliaire"
		borne.portee = 2.6
		borne.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
		dossier.add_child(borne)
	var faille := Faille.new()
	faille.name = "Faille"
	faille.identifiant = "faille_voie"
	faille.position = Vector3(FAILLE.x, hauteur(FAILLE.x, FAILLE.y), FAILLE.y)
	dossier.add_child(faille)
	# Repères de la carte.
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.PORTAIL, "Portail de la Vigie", PORTAIL)
	repere.call(MarqueurCarte.Type.DANGER, "Faille", FAILLE)
	repere.call(MarqueurCarte.Type.LIEU, "Relais de poste de Petronius", MANSIO.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Tombeau de Caecilia Metella", CAECILIA_METELLA)
	repere.call(MarqueurCarte.Type.LIEU, "Voie Appienne, vers Rome", SORTIE_NORD)
	repere.call(MarqueurCarte.Type.LIEU, "Voie Appienne, vers Capoue et Pompéi", SORTIE_SUD)
	repere.call(MarqueurCarte.Type.LIEU, "Auberge", AUBERGE)


# --- La route du nord ------------------------------------------------------------------------

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
	if not _nord_ouvert:
		if not quete.etape_atteinte("vers_campagne"):
			return
		_nord_ouvert = true
		if _mur_nord != null and is_instance_valid(_mur_nord):
			_mur_nord.queue_free()
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return
	var p := Vector2(joueur.global_position.x, joueur.global_position.z)
	if p.distance_to(SORTIE_NORD) < 6.0 and quete.donnees.get("zones", {}).has("campagne"):
		quete.changer_de_zone("campagne")
	# Au sud, la route de Pompéi : ouverte au chapitre 6.
	if not _sud_ouvert and quete.donnees.get("zones", {}).has("pompei") and quete.etape_atteinte("vers_pompei"):
		_sud_ouvert = true
		if _mur_sud != null and is_instance_valid(_mur_sud):
			_mur_sud.queue_free()
	if _sud_ouvert and p.distance_to(SORTIE_SUD) < 6.0:
		quete.changer_de_zone("pompei")
