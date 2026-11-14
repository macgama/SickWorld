@tool
extends "res://scripts/monde/egypte/ile_egypte.gd"
## Île d'Égypte, zone 2 : les Carrières de Toura (niveaux 12-15).
##
## Sur la rive est du Nil, en face de Gizeh. On débarque à l'ouest, sur une plage
## de limon, au pied d'une longue pente de sable qui monte vers l'est jusqu'à une
## falaise de calcaire blanc éblouissant. La falaise est taillée en gradins géants :
## c'est la carrière à ciel ouvert. Au sud-est, une rampe d'éboulis monte les
## gradins ; au nord-est, la « galerie neuve » s'enfonce dans la montagne, là où la
## pierre est la plus fine. Entre le fleuve et la falaise, le campement des carriers.
##
## Repères : le nord est vers -Z, le Nil à l'ouest (-X), la falaise à l'est (+X).

const Pnj := preload("res://scripts/monde/prehistoire/pnj_epoque.gd")
const Faille := preload("res://scripts/monde/prehistoire/faille.gd")
const ObjetEgypte := preload("res://scripts/monde/egypte/objet_egypte.gd")
const Traineau := preload("res://scripts/monde/egypte/traineau.gd")
const Passeur := preload("res://scripts/monde/egypte/passeur.gd")
const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")

## Le débarcadère et le passeur (retour vers le Port des Marais).
const PASSEUR := Vector2(-88, 6)
const DEBARCADERE := Vector2(-84, 9)
## Le campement des carriers.
const CAMP := Vector2(-36, -2)
const IRY := Vector2(-31, 4)
const MERER := Vector2(-43, 6)
## Hauteur du pied de la falaise (le sol de la carrière et de la galerie).
const H_PIED := 6.2
## La carrière à ciel ouvert : gradins taillés dans la falaise.
const CARRIERE := Rect2(36, -50, 62, 72)
## La rampe d'éboulis qui monte les gradins, au sud de la carrière.
const RAMPE_GRADINS := Rect2(36, 14, 62, 8)
## La galerie neuve : un couloir dans la montagne, puis une salle.
const COULOIR := Rect2(34, -74, 52, 8)
const SALLE := Rect2(84, -79, 18, 18)
const ENTREE_GALERIE := Vector2(42, -70)
const FAILLE := Vector2(95, -70)
## Les fragments d'encre, devant l'entrée de la galerie.
const ENCRE := [Vector2(30, -64), Vector2(34, -78), Vector2(24, -71), Vector2(38, -60)]
## Là où les carriers libérés se retrouvent ensuite.
const LIBERES := [Vector2(-28, -6), Vector2(-26, -2), Vector2(-30, -9)]
const NOMS_LIBERES := ["carrier_senedjem", "carrier_khoufouankh", "carrier_nefer"]
## Hauteur des gradins, et nombre de gradins.
const GRADIN := 4.3
const NB_GRADINS := 6

var _rive: FastNoiseLite
# Oubliés à terre : chaque objet « rendre son nom » et l'oublié qui va avec.
var _a_liberer: Array = []
var _liberes := 0
var _dossier_quete: Node3D
var _attente_liberes := 0.0


func _init() -> void:
	identifiant_zone = "carrieres_toura"
	taille_terrain = 320
	graine = 2561
	point_apparition = DEBARCADERE
	nombre_touffes = 18000
	neige_qui_tombe = false
	sols = {
		# Rouge : le limon de la berge.
		"galets": ["brown_mud_03", "mud_cracked_dry_riverbed_002", "brown_mud_02"],
		# Vert : le sable de la pente.
		"neige": ["sand_02", "sand_01", "dry_ground_rocks"],
		# Bleu : la poussière de calcaire de la carrière et du campement.
		"sol": ["dry_ground_01", "mud_cracked_dry_03", "dry_ground_rocks"],
		# Les fronts de taille : calcaire blanc.
		"roche": ["quarry_wall", "quarry_wall_02", "sandstone_cracks", "cliff_side"],
	}
	reglages_terrain = {"sol_saturation": 0.8, "sol_motif": 5.0, "galets_motif": 3.0, "neige_motif": 6.0,
			"sol_teinte": Color(1.08, 1.05, 0.98), "roche_teinte": Color(1.18, 1.15, 1.08), "roche_saturation": 0.55,
			"neige_eclat": 1.0, "neige_paillettes": 0.0, "roche_motif": 12.0,
			"neige_teinte": Color(1.04, 1.0, 0.94), "neige_max": Vector3(0.86, 0.76, 0.62), "neige_simple": Color(0.8, 0.68, 0.5),
			"givre": 0.0, "neige_translucide": 0.0}
	reglages_herbe = {"couleur_base": Color(0.2, 0.2, 0.08), "couleur_pointe": Color(0.6, 0.55, 0.28),
			"couleur_givre": Color(0.62, 0.58, 0.32), "force_vent": 0.12}
	# Le chemin des carriers : du débarcadère au campement, puis à la carrière.
	piste = [Vector2(-82, 8), Vector2(-60, 4), Vector2(-40, 0), Vector2(-10, -6), Vector2(20, -10), Vector2(36, -12)]


func _ready() -> void:
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_egypte", "") != "":
		Reseau.remove_meta("arrivee_egypte")
		point_apparition = DEBARCADERE
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	return PASSEUR if zone != "carrieres_toura" else Vector2.INF


# --- Relief -----------------------------------------------------------------------------

func _preparer_bruits() -> void:
	super._preparer_bruits()
	_relief.frequency = 0.014
	_rive = FastNoiseLite.new()
	_rive.seed = graine + 3
	_rive.frequency = 0.02
	_rive.fractal_octaves = 2


## La rive du Nil : position x du bord de l'eau pour une position z.
func rive_nil(z: float) -> float:
	if _rive == null:
		_preparer_bruits()
	return -98.0 + _rive.get_noise_1d(z) * 7.0 + sin(z * 0.013) * 5.0


## Le pied de la falaise : position x où la paroi commence.
func pied_falaise(z: float) -> float:
	if _rive == null:
		_preparer_bruits()
	return 41.0 + _rive.get_noise_1d(z * 1.7 + 300.0) * 5.0


## Un escalier « doux » : les marches montent vite (contremarche presque verticale).
static func _marches(t: float) -> float:
	var f: float = t - floor(t)
	return floor(t) + smoothstep(0.82, 1.0, f)


func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	var bruit := _relief.get_noise_2d(x, z)
	var fin := _details.get_noise_2d(x * 3.0, z * 3.0)
	var rive := rive_nil(z)
	var pied := pied_falaise(z)
	# La pente de sable, du fleuve au pied de la falaise.
	var t := clampf((x - rive) / (pied - rive), 0.0, 1.0)
	var h := 0.7 + pow(t, 1.3) * (H_PIED - 0.7) + bruit * 0.6 * t + fin * 0.07
	# La falaise de calcaire, et le plateau au-dessus.
	var falaise := smoothstep(pied, pied + 9.0, x + fin * 1.5)
	h += falaise * (28.0 + bruit * 4.0 + absf(fin) * 1.2)
	# La carrière : des gradins taillés dans la falaise.
	var gradins := H_PIED + minf(_marches(maxf(x - 40.0, 0.0) / 9.0), NB_GRADINS) * GRADIN + fin * 0.05
	h = lerpf(h, minf(h, gradins), _dans_rect(CARRIERE, x, z, 3.0))
	# La rampe d'éboulis qui monte jusqu'au dernier gradin.
	var rampe := H_PIED + clampf((x - 38.0) / 56.0, 0.0, 1.0) * NB_GRADINS * GRADIN + fin * 0.15
	h = lerpf(h, rampe, _dans_rect(RAMPE_GRADINS, x, z, 2.0) * smoothstep(34.0, 40.0, x))
	# Le parvis de la galerie et la galerie elle-même (sol plat, taillé).
	h = lerpf(h, H_PIED + fin * 0.04, _dans_rect(Rect2(22, -82, 18, 24), x, z, 8.0))
	h = lerpf(h, H_PIED, maxf(_dans_rect(COULOIR, x, z, 0.6), _dans_rect(SALLE, x, z, 0.6)))
	# Le campement : un replat de terre battue.
	h = lerpf(h, 2.6 + fin * 0.05, _dans_rect(Rect2(CAMP.x - 18, CAMP.y - 16, 36, 30), x, z, 10.0))
	# La berge : elle plonge sous l'eau trouble.
	var berge := rive - x
	h = lerpf(h, minf(h, -0.4 - berge * 0.3), smoothstep(-3.0, 3.0, berge))
	h = maxf(h, -4.5) if berge > 0.0 else h
	# Le débarcadère : la berge est aplanie là où l'on décharge.
	h = lerpf(h, 0.75, _dans_rect(Rect2(DEBARCADERE.x - 6, DEBARCADERE.y - 10, 12, 18), x, z, 6.0) * smoothstep(-6.0, 0.0, -berge))
	return h


## Rouge : limon de la berge ; vert : sable ; bleu : poussière de calcaire.
func _parts_sol(x: float, z: float, h: float) -> Color:
	var n := _relief.get_noise_2d(x * 2.0 + 90.0, z * 2.0)
	var humide := 1.0 - smoothstep(0.6, 1.6, h + n * 0.4)
	var calcaire := smoothstep(4.0, 22.0, x + n * 10.0)
	calcaire = maxf(calcaire, _dans_rect(Rect2(CAMP.x - 16, CAMP.y - 14, 32, 26), x, z, 6.0) * 0.8)
	calcaire = maxf(calcaire, (1.0 - smoothstep(2.0, 4.0, _distance_piste(Vector2(x, z)))) * 0.7)
	var sable := (1.0 - calcaire) * (1.0 - humide)
	return Color(humide, sable, calcaire * (1.0 - humide), 1.0)


# --- Construction -------------------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_flotteurs.clear()
	_a_liberer.clear()
	_liberes = 0
	_construire_terrain()
	_construire_eau()
	_construire_debarcadere()
	_construire_campement()
	_construire_carriere()
	_construire_galerie()
	_construire_vegetation()
	_construire_rochers()
	_construire_touffes()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_appliquer_ciel()
	var balise := get_node_or_null("BaliseVigie") as Node3D
	if balise != null:
		balise.position = Vector3(DEBARCADERE.x + 4.0, hauteur(DEBARCADERE.x + 4.0, DEBARCADERE.y - 5.0), DEBARCADERE.y - 5.0)


# --- Le débarcadère -------------------------------------------------------------------------

func _construire_debarcadere() -> void:
	var port := Node3D.new()
	port.name = "Debarcadere"
	_contenu.add_child(port)
	var bois := _mat_bois()
	# Un ponton de planches sur pilotis, qui avance dans le fleuve.
	var rive := rive_nil(DEBARCADERE.y)
	var debut := DEBARCADERE.x - 2.0
	var fin := rive - 12.0
	var longueur := debut - fin
	_boite(Vector3(longueur, 0.2, 3.0), Vector3((debut + fin) * 0.5, 0.65, DEBARCADERE.y - 2.0), bois, port)
	for k in int(longueur / 2.5) + 1:
		for cote in [-1.3, 1.3]:
			var pieu := MeshInstance3D.new()
			pieu.mesh = _cylindre(0.12, 0.14, 4.0, 7)
			pieu.material_override = bois
			pieu.position = Vector3(fin + k * 2.5, -1.2, DEBARCADERE.y - 2.0 + cote)
			port.add_child(pieu)
	# Les cargos qui attendent leur chargement, et la barque de Merer.
	_barque(port, Vector3(fin + 4.0, -0.1, DEBARCADERE.y - 6.5), PI / 2 + 0.05, 15.0, true)
	_barque(port, Vector3(fin + 2.0, -0.1, DEBARCADERE.y + 3.0), PI / 2 - 0.08, 11.0, false)
	_barque(port, Vector3(rive - 6.0, -0.1, DEBARCADERE.y + 22.0), PI / 2 + 0.3, 15.0, true)
	_barque(port, Vector3(rive - 5.0, -0.1, DEBARCADERE.y - 28.0), PI / 2 - 0.2, 13.0, false)
	# Les blocs prêts à partir, alignés sur la berge, numérotés à l'ocre.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 30
	for rangee in 3:
		for k in 8:
			var x := DEBARCADERE.x + 9.0 + rangee * 2.2
			var z := DEBARCADERE.y - 26.0 + k * 1.8 + (rangee % 2) * 0.6
			if absf(z - DEBARCADERE.y) < 4.0:
				continue
			_bloc_calcaire(port, Vector3(x, hauteur(x, z) + 0.45, z), Vector3(1.5, 1.0, 1.0),
					hasard.randf_range(-0.06, 0.06) + PI / 2)
	# Un traîneau chargé, prêt à descendre vers le ponton.
	var traineau := Traineau.new()
	traineau.name = "TraineauBerge"
	traineau.position = Vector3(DEBARCADERE.x + 14.0, hauteur(DEBARCADERE.x + 14.0, DEBARCADERE.y + 10.0), DEBARCADERE.y + 10.0)
	traineau.rotation.y = PI / 2
	traineau.materiau_bloc = _mat_calcaire()
	traineau.materiau_bois = bois
	port.add_child(traineau)


# --- Le campement des carriers --------------------------------------------------------------

func _construire_campement() -> void:
	var camp := Node3D.new()
	camp.name = "Campement"
	_contenu.add_child(camp)
	# Des cabanes de briques crues et des abris de roseaux.
	var cabanes := [
		[CAMP + Vector2(-10, -8), Vector3(6, 2.6, 4.5), 0.1], [CAMP + Vector2(2, -10), Vector3(5, 2.4, 4), -0.05],
		[CAMP + Vector2(10, 6), Vector3(7, 2.6, 4), PI / 2], [CAMP + Vector2(-12, 7), Vector3(4.5, 2.3, 4), PI],
	]
	for c in cabanes:
		_maison(camp, c[0], c[1], c[2])
	_auvent(camp, IRY + Vector2(0, -2.5), Vector2(4.5, 3.5), 2.6, Color(0.86, 0.8, 0.66))
	_auvent(camp, CAMP + Vector2(-2, 2), Vector2(6, 4), 2.4, Color(0.9, 0.86, 0.74))
	_feu(camp, CAMP + Vector2(-3, 1), 0.8)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 40
	for groupe in [CAMP + Vector2(-8, -4), CAMP + Vector2(5, -5), IRY + Vector2(2, -3)]:
		for k in hasard.randi_range(4, 7):
			var p: Vector2 = groupe + Vector2(hasard.randf_range(-1.6, 1.6), hasard.randf_range(-0.8, 0.8))
			_jarre(camp, Vector3(p.x, hauteur(p.x, p.y) - 0.02, p.y), hasard.randf_range(0.7, 1.1), hasard.randf() * TAU)
	for p in [CAMP + Vector2(-6, -3), IRY + Vector2(-2, -3), CAMP + Vector2(6, 3)]:
		for id in ["wicker_basket_01", "wooden_bucket_01", "wooden_bowl_01"]:
			var o := _modele(id, Vector3(p.x + hasard.randf_range(-1.2, 1.2), hauteur(p.x, p.y), p.y + hasard.randf_range(-0.8, 0.8)),
					hasard.randf() * TAU, 1.0, camp)
			if o == null:
				break
	# L'établi d'Iry : maillets de dolérite, ciseaux de cuivre, coins de bois.
	var bois := _mat_choix(["weathered_planks", "rough_wood"], Color(0.5, 0.4, 0.3), 0.9, 1.0)
	var etabli := IRY + Vector2(-1.2, -3.0)
	var y := hauteur(etabli.x, etabli.y)
	_boite(Vector3(2.0, 0.08, 0.8), Vector3(etabli.x, y + 0.8, etabli.y), bois, camp)
	var cuivre := _mat_pbr("", Color(0.72, 0.42, 0.22), 0.35, 1.0)
	cuivre.metallic = 0.8
	var dolerite := _mat_pbr("", Color(0.16, 0.16, 0.17), 0.6, 1.0)
	for k in 3:
		var ciseau := MeshInstance3D.new()
		ciseau.mesh = _cylindre(0.015, 0.02, 0.28, 6)
		ciseau.material_override = cuivre
		ciseau.rotation.z = PI / 2
		ciseau.position = Vector3(etabli.x - 0.6 + k * 0.2, y + 0.86, etabli.y - 0.1)
		camp.add_child(ciseau)
	for k in 2:
		var maillet := MeshInstance3D.new()
		maillet.mesh = _sphere_simple(0.12)
		maillet.material_override = dolerite
		maillet.position = Vector3(etabli.x + 0.4 + k * 0.4, y + 0.94, etabli.y + 0.1)
		camp.add_child(maillet)


static func _sphere_simple(rayon: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = rayon
	s.height = rayon * 1.8
	s.radial_segments = 10
	s.rings = 5
	return s


# --- La carrière à ciel ouvert ----------------------------------------------------------------

func _construire_carriere() -> void:
	var carriere := Node3D.new()
	carriere.name = "Carriere"
	_contenu.add_child(carriere)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 50
	var bois := _mat_bois()
	# Sur chaque gradin : des blocs à moitié détachés (saignées), et d'autres prêts à descendre.
	for niveau in NB_GRADINS:
		var x_marche := 40.0 + niveau * 9.0
		var y := H_PIED + niveau * GRADIN
		for k in 5:
			var z := hasard.randf_range(CARRIERE.position.y + 4.0, CARRIERE.end.y - 6.0)
			if z > RAMPE_GRADINS.position.y - 3.0:
				continue
			var x := x_marche + hasard.randf_range(2.0, 6.5)
			if hauteur(x, z) < y - 0.5 or hauteur(x, z) > y + 0.5:
				continue
			_bloc_calcaire(carriere, Vector3(x, y + 0.5, z), Vector3(1.5, 1.0, 1.0), hasard.randf_range(-0.15, 0.15) + PI / 2)
			if hasard.randf() < 0.4:
				_bloc_calcaire(carriere, Vector3(x + hasard.randf_range(-0.3, 0.3), y + 1.5, z), Vector3(1.4, 1.0, 1.0),
						hasard.randf_range(-0.2, 0.2) + PI / 2)
		# Les coins de bois enfoncés au pied du front de taille (on les mouille pour fendre la pierre).
		for k in 6:
			var z := hasard.randf_range(CARRIERE.position.y + 4.0, RAMPE_GRADINS.position.y - 4.0)
			var coin := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.12, 0.35, 0.25)
			coin.mesh = b
			coin.material_override = bois
			coin.position = Vector3(x_marche + 9.0 - 0.15, y + GRADIN * 0.35 + 0.1, z)
			carriere.add_child(coin)
	# Des traîneaux et des leviers abandonnés près de la rampe.
	for k in 3:
		var t := Traineau.new()
		t.name = "Traineau%d" % k
		var x := 46.0 + k * 16.0
		var z := RAMPE_GRADINS.get_center().y + hasard.randf_range(-1.0, 1.0)
		t.position = Vector3(x, hauteur(x, z), z)
		t.rotation.y = -PI / 2 + hasard.randf_range(-0.1, 0.1)
		t.materiau_bloc = _mat_calcaire()
		t.materiau_bois = bois
		carriere.add_child(t)
	# Les marques des équipes, peintes à l'ocre rouge sur le front de taille du bas.
	var ocre := _mat_pbr("", Color(0.62, 0.2, 0.1), 0.95, 1.0)
	for k in 7:
		var z := CARRIERE.position.y + 6.0 + k * 8.0
		if z > RAMPE_GRADINS.position.y - 3.0:
			break
		var marque := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.2, 0.6)
		marque.mesh = q
		marque.material_override = ocre
		marque.rotation.y = -PI / 2
		marque.position = Vector3(49.0 - 0.6, H_PIED + 2.4, z)
		carriere.add_child(marque)


# --- La galerie neuve ---------------------------------------------------------------------

func _construire_galerie() -> void:
	var galerie := Node3D.new()
	galerie.name = "Galerie"
	_contenu.add_child(galerie)
	var pierre := _mat_calcaire()
	var haut := 5.5
	var sommet := H_PIED + 32.0
	# Le couloir : deux parois, un plafond, et la montagne au-dessus (pour boucher le
	# creux du terrain). On entre par l'ouest, au pied de la falaise.
	var x0 := ENTREE_GALERIE.x - 2.0
	var x1 := SALLE.position.x
	var longueur := x1 - x0
	var cx := (x0 + x1) * 0.5
	_boite(Vector3(longueur, haut + 0.5, 3.0), Vector3(cx, H_PIED + haut * 0.5, COULOIR.position.y - 1.0), pierre, galerie)
	_boite(Vector3(longueur, haut + 0.5, 3.0), Vector3(cx, H_PIED + haut * 0.5, COULOIR.end.y + 1.0), pierre, galerie)
	_boite(Vector3(longueur, 1.0, COULOIR.size.y + 6.0), Vector3(cx, H_PIED + haut + 0.5, COULOIR.get_center().y), pierre, galerie)
	_boite(Vector3(longueur, sommet - H_PIED - haut - 1.0, COULOIR.size.y + 6.0),
			Vector3(cx, (H_PIED + haut + 1.0 + sommet) * 0.5, COULOIR.get_center().y), pierre, galerie, false)
	# La salle du fond, plus large et plus haute.
	var hs := 7.0
	var s := SALLE
	_boite(Vector3(1.6, hs, s.size.y + 3.2), Vector3(s.end.x + 0.8, H_PIED + hs * 0.5, s.get_center().y), pierre, galerie)
	for cote in [s.position.y - 0.8, s.end.y + 0.8]:
		_boite(Vector3(s.size.x + 1.6, hs, 1.6), Vector3(s.get_center().x, H_PIED + hs * 0.5, cote), pierre, galerie)
	for bord in [[s.position.y, COULOIR.position.y], [COULOIR.end.y, s.end.y]]:
		var largeur: float = bord[1] - bord[0]
		_boite(Vector3(1.6, hs, largeur), Vector3(s.position.x - 0.8, H_PIED + hs * 0.5, (bord[0] + bord[1]) * 0.5), pierre, galerie)
	_boite(Vector3(s.size.x + 3.2, 1.0, s.size.y + 3.2), Vector3(s.get_center().x, H_PIED + hs + 0.5, s.get_center().y), pierre, galerie)
	_boite(Vector3(s.size.x + 3.2, sommet - H_PIED - hs - 1.0, s.size.y + 3.2),
			Vector3(s.get_center().x, (H_PIED + hs + 1.0 + sommet) * 0.5, s.get_center().y), pierre, galerie, false)
	# L'entrée : un linteau de pierre, et des traces d'outils autour.
	_boite(Vector3(1.2, 1.2, COULOIR.size.y + 2.0), Vector3(x0 + 0.6, H_PIED + haut + 0.2, COULOIR.get_center().y), pierre, galerie, false)
	# Des lampes à huile posées dans des niches, de plus en plus rares vers le fond.
	for k in 6:
		var x := x0 + 4.0 + k * 8.0
		var lampe := OmniLight3D.new()
		lampe.light_color = Color(1.0, 0.62, 0.3)
		lampe.light_energy = 1.6 - k * 0.2
		lampe.omni_range = 7.0
		lampe.shadow_enabled = k < 2
		lampe.position = Vector3(x, H_PIED + 2.4, COULOIR.position.y + 0.6 if k % 2 == 0 else COULOIR.end.y - 0.6)
		galerie.add_child(lampe)
		var flamme := MeshInstance3D.new()
		flamme.mesh = _sphere_simple(0.06)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.7, 0.3)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.55, 0.2)
		m.emission_energy_multiplier = 4.0
		flamme.material_override = m
		flamme.position = lampe.position + Vector3(0, -0.2, 0)
		galerie.add_child(flamme)
	# Une lueur violette au fond : la faille.
	var lueur := OmniLight3D.new()
	lueur.light_color = Color(0.6, 0.35, 1.0)
	lueur.light_energy = 2.5
	lueur.omni_range = 14.0
	lueur.position = Vector3(FAILLE.x - 2.0, H_PIED + 3.0, FAILLE.y)
	galerie.add_child(lueur)
	# Des blocs à moitié dégagés dans le sol de la salle.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 60
	for k in 5:
		var p := Vector2(hasard.randf_range(s.position.x + 2.0, s.end.x - 5.0), hasard.randf_range(s.position.y + 2.0, s.end.y - 2.0))
		if p.distance_to(FAILLE) < 4.0:
			continue
		_bloc_calcaire(galerie, Vector3(p.x, H_PIED + 0.35, p.y), Vector3(1.5, 0.7, 1.0), hasard.randf_range(-0.1, 0.1))


# --- Végétation et rochers ---------------------------------------------------------------------

func _construire_vegetation() -> void:
	# Papyrus le long de la berge, palmiers sur la pente basse et au campement.
	_semer_papyrus(900, Rect2(-160, -150, 90, 300), func(x: float, z: float) -> bool:
		var h := hauteur(x, z)
		var p := Vector2(x, z)
		if p.distance_to(DEBARCADERE) < 16.0 or absf(z - DEBARCADERE.y) < 8.0:
			return false
		return h > -0.6 and h < 0.5, graine + 5)
	var points: Array = []
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 7
	for k in 60:
		var x := hasard.randf_range(-90.0, -10.0)
		var z := hasard.randf_range(-140.0, 140.0)
		var h := hauteur(x, z)
		var p := Vector2(x, z)
		if h < 0.8 or h > 4.5 or _distance_piste(p) < 3.0 or p.distance_to(IRY) < 6.0 or p.distance_to(MERER) < 5.0:
			continue
		if _dans_rect(Rect2(CAMP.x - 16, CAMP.y - 14, 32, 26), x, z, 0.1) > 0.5 and hasard.randf() < 0.7:
			continue
		if absf(z - DEBARCADERE.y) < 14.0 and x < DEBARCADERE.x + 16.0:
			continue
		points.append(p)
	_planter_palmiers(points, graine + 8)


func _construire_rochers() -> void:
	var dossier := Node3D.new()
	dossier.name = "Rochers"
	_contenu.add_child(dossier)
	_preparer_rochers()
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 12
	# Éboulis au pied de la falaise (hors carrière et hors galerie).
	for k in 110:
		var z := hasard.randf_range(-150.0, 150.0)
		var x := pied_falaise(z) + hasard.randf_range(-6.0, 3.0)
		if _dans_rect(CARRIERE.grow(4.0), x, z, 0.1) > 0.5 or _dans_rect(Rect2(20, -86, 30, 32), x, z, 0.1) > 0.5:
			continue
		if _dans_rect(RAMPE_GRADINS.grow(3.0), x, z, 0.1) > 0.5:
			continue
		_placer_rocher(dossier, x, z, hasard.randf_range(0.4, 2.4) * (1.7 if hasard.randf() < 0.1 else 1.0))
	# Des éclats de taille partout dans la carrière.
	for k in 70:
		var x := hasard.randf_range(CARRIERE.position.x + 2.0, CARRIERE.end.x)
		var z := hasard.randf_range(CARRIERE.position.y, CARRIERE.end.y)
		_placer_rocher(dossier, x, z, hasard.randf_range(0.2, 0.6))
	for id_k in 10:
		var z := hasard.randf_range(-140.0, 140.0)
		var x := hasard.randf_range(-60.0, 30.0)
		if Vector2(x, z).distance_to(CAMP) < 22.0 or _distance_piste(Vector2(x, z)) < 4.0:
			continue
		var id: String = ["namaqualand_boulder_02", "namaqualand_boulder_03", "sand_rocks_small_01"][id_k % 3]
		_modele(id, Vector3(x, hauteur(x, z) - 0.2, z), hasard.randf() * TAU, hasard.randf_range(0.8, 1.6), dossier)


# --- Paysage lointain ----------------------------------------------------------------------

func _construire_lointain() -> void:
	# Le plateau du Mokattam continue vers l'est, au-dessus de la falaise.
	var haut_plateau := hauteur(159.0, 0.0)
	_plan_lointain(Vector3(860, haut_plateau - 0.4, 0), Vector2(1400, 3200), Color(0, 0.4, 0.6))
	# L'autre rive, à l'ouest : la plaine inondée, des palmeraies, et la pyramide.
	_plan_lointain(Vector3(-1050, 0.4, 0), Vector2(300, 3200), Color(0.6, 0, 0.4))
	_construire_pyramide(Vector3(-1500, 30.0, -600), deg_to_rad(8.0))
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 71
	var variantes: Array[ArrayMesh] = []
	for k in 3:
		variantes.append(_maillage_palmier(hasard, hasard.randf_range(9.0, 12.0)))
	for k in 160:
		var mi := MeshInstance3D.new()
		mi.mesh = variantes[k % variantes.size()]
		mi.position = Vector3(-920.0 + hasard.randf_range(-20.0, 40.0), 0.6, hasard.randf_range(-1400.0, 1400.0))
		mi.rotation.y = hasard.randf() * TAU
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(mi)


# --- Limites de la zone -----------------------------------------------------------------------

func _construire_limites() -> void:
	var limites := Node3D.new()
	limites.name = "Limites"
	_contenu.add_child(limites)
	# Le Nil : on ne s'aventure pas là où l'on n'a plus pied.
	var pas := 6.0
	var z := -160.0
	while z < 160.0:
		var x1 := rive_nil(z) - 7.0
		var x2 := rive_nil(z + pas) - 7.0
		var centre := Vector3((x1 + x2) * 0.5, 0.0, z + pas * 0.5)
		_mur_invisible(limites, Vector3(1.0, 12.0, pas + 1.0), centre, atan2(x2 - x1, pas))
		z += pas
	var demi := taille_terrain * 0.5 - 4.0
	_mur_invisible(limites, Vector3(2, 160, taille_terrain), Vector3(demi, 60, 0))
	_mur_invisible(limites, Vector3(taille_terrain, 160, 2), Vector3(0, 60, -demi))
	_mur_invisible(limites, Vector3(taille_terrain, 160, 2), Vector3(0, 60, demi))


# --- Personnages et objets de la quête ----------------------------------------------------------

func _construire_quete() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quete"
	_contenu.add_child(dossier)
	_dossier_quete = dossier
	_pnj(dossier, "iry", IRY, PI)
	_pnj(dossier, "merer_toura", MERER, PI * 0.8).name = "MererToura"
	var hapi := _pnj(dossier, "passeur", PASSEUR + Vector2(1.4, -1.0), -PI / 2)
	hapi.name = "Hapi"
	var passeur := Passeur.new()
	passeur.name = "Passeur"
	passeur.destination = "port_des_marais"
	passeur.nom_destination = "le Port des Marais"
	passeur.position = Vector3(PASSEUR.x, hauteur(PASSEUR.x, PASSEUR.y), PASSEUR.y)
	dossier.add_child(passeur)
	# Les fragments d'encre, devant la galerie.
	for k in ENCRE.size():
		var e := ObjetEgypte.new()
		e.name = "Encre%d" % k
		e.identifiant = "encre_%d" % k
		e.groupe = "fragments_encre"
		e.forme = "encre"
		e.invite = "[F] Ramasser la poussière d'encre"
		e.position = Vector3(ENCRE[k].x, hauteur(ENCRE[k].x, ENCRE[k].y), ENCRE[k].y)
		dossier.add_child(e)
	# La faille au fond de la galerie, et ce qu'elle laisse en se refermant.
	var faille := Faille.new()
	faille.name = "Faille"
	faille.identifiant = "faille_toura"
	faille.position = Vector3(FAILLE.x, H_PIED, FAILLE.y)
	dossier.add_child(faille)
	var amulette := Node3D.new()
	amulette.name = "AmuletteGalerie"
	amulette.set_meta("identifiant", "amulette_galerie")
	amulette.add_to_group("decor_quete")
	amulette.visible = false
	amulette.position = Vector3(FAILLE.x - 1.5, H_PIED, FAILLE.y)
	dossier.add_child(amulette)
	var scarabee := MeshInstance3D.new()
	scarabee.mesh = _sphere_simple(0.07)
	scarabee.scale = Vector3(1.0, 0.6, 1.4)
	var faience := StandardMaterial3D.new()
	faience.albedo_color = Color(0.2, 0.55, 0.7)
	faience.roughness = 0.2
	faience.emission_enabled = true
	faience.emission = Color(0.55, 0.3, 1.0)
	faience.emission_energy_multiplier = 1.2
	scarabee.material_override = faience
	scarabee.position.y = 0.06
	amulette.add_child(scarabee)
	var lumiere := OmniLight3D.new()
	lumiere.light_color = Color(0.6, 0.4, 1.0)
	lumiere.light_energy = 0.8
	lumiere.omni_range = 2.5
	lumiere.position.y = 0.4
	amulette.add_child(lumiere)
	var ramasser := ObjetEgypte.new()
	ramasser.name = "RamasserAmulette"
	ramasser.identifiant = "amulette_galerie"
	ramasser.invite = "[F] Ramasser l'objet qui brille"
	ramasser.position = amulette.position
	dossier.add_child(ramasser)
	# Les carriers déjà libérés (quand on revient plus tard).
	if not Engine.is_editor_hint():
		_placer_liberes.call_deferred()
	# Repères de la carte.
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.LIEU, "Passeur vers le Port", PASSEUR)
	repere.call(MarqueurCarte.Type.LIEU, "Campement des carriers", CAMP)
	repere.call(MarqueurCarte.Type.LIEU, "Carrière à ciel ouvert", CARRIERE.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Galerie neuve", ENTREE_GALERIE)
	repere.call(MarqueurCarte.Type.DANGER, "Babouins", Vector2(60, 0))


func _pnj(parent: Node3D, id: String, p: Vector2, angle: float) -> Node3D:
	var n := Pnj.new()
	n.name = id.capitalize().replace(" ", "")
	n.identifiant = id
	n.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
	n.rotation.y = angle
	parent.add_child(n)
	return n


## Si la quête a déjà dépassé l'étape des oubliés, les trois carriers sont là, guéris.
func _placer_liberes() -> void:
	var quete := get_tree().get_first_node_in_group("quete")
	if quete == null or not quete.has_method("etape_atteinte") or not quete.etape_atteinte("rapport_iry"):
		return
	for k in NOMS_LIBERES.size():
		_pnj(_dossier_quete, NOMS_LIBERES[k], LIBERES[k], PI * 0.5 + k * 0.6)
	_liberes = NOMS_LIBERES.size()


# --- Les Oubliés : on les met à terre, puis on leur rend leur nom -----------------------------

func _process(delta: float) -> void:
	super._process(delta)
	if Engine.is_editor_hint() or _dossier_quete == null:
		return
	_attente_liberes -= delta
	if _attente_liberes > 0.0:
		return
	_attente_liberes = 0.25
	var quete := get_tree().get_first_node_in_group("quete")
	var etape: Dictionary = quete.etape_actuelle() if quete != null else {}
	# Un oublié vient d'être mis à terre : on peut lui rendre son nom (F).
	for bete in get_tree().get_nodes_in_group("loups"):
		if not String(bete.get("type_ennemi")).begins_with("oublie") or bete.has_meta("objet_nom"):
			continue
		if bete.combat.est_vivant():
			continue
		var objet := ObjetEgypte.new()
		objet.name = "RendreNom%d" % _a_liberer.size()
		objet.identifiant = "nom_rendu_%d" % _a_liberer.size()
		objet.groupe = "nom_rendu"
		objet.invite = "[F] Rendre son nom"
		objet.portee = 2.6
		_dossier_quete.add_child(objet)
		objet.global_position = bete.global_position
		objet.actif = etape.get("recolter", "") == "nom_rendu"
		bete.set_meta("objet_nom", objet)
		_a_liberer.append([objet, bete])
	# Un nom rendu : l'oublié se relève, guéri, et rejoint le campement.
	for paire in _a_liberer.duplicate():
		var objet = paire[0]
		var bete = paire[1]
		if not is_instance_valid(objet) or not objet.get("ramasse"):
			continue
		_a_liberer.erase(paire)
		var ou: Vector3 = bete.global_position if is_instance_valid(bete) else objet.global_position
		if is_instance_valid(bete):
			bete.queue_free()
		if _liberes < NOMS_LIBERES.size():
			var libere := _pnj(_dossier_quete, NOMS_LIBERES[_liberes], Vector2(ou.x, ou.z), randf() * TAU)
			libere.global_position = ou
			# Un peu plus tard, il a rejoint ses camarades au campement.
			var cible: Vector2 = LIBERES[_liberes]
			var aller := create_tween()
			aller.tween_interval(20.0)
			aller.tween_callback(func():
				if is_instance_valid(libere):
					libere.global_position = Vector3(cible.x, hauteur(cible.x, cible.y), cible.y))
			_liberes += 1
