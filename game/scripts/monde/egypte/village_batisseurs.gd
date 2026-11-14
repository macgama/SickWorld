@tool
extends "res://scripts/monde/egypte/ile_egypte.gd"
## Île d'Égypte, zone 3 : le Village des Bâtisseurs et le chantier de Gizeh (niveaux 14-17).
##
## Au pied du plateau de Gizeh, la ville des ouvriers (les archéologues l'appellent
## Heit el-Ghourab, « le mur du corbeau »). On arrive à l'est par la route qui monte du
## port. Au centre, la grande place ; autour, les dortoirs des haleurs (de longues
## galeries), la boulangerie-brasserie de Méret, la maison de soins de Pésèshet, l'enclos
## des bœufs et l'atelier d'Ouni. À l'ouest, sur la pente, le cimetière des ouvriers et
## ses petites tombes. Au nord, un mur de pierre géant ferme la ville ; sa porte ouvre
## sur la montée du plateau, le chantier, et la Grande Pyramide presque finie.
##
## Repères : le nord est vers -Z, le plateau au nord, le canal du port au sud.

const Faille := preload("res://scripts/monde/prehistoire/faille.gd")
const Traineau := preload("res://scripts/monde/egypte/traineau.gd")
const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")

## La route qui descend vers le Port des Marais (à l'est).
const ENTREE := Vector2(146, 60)
## La grande place, la pierre où l'on peut briser les amulettes, et Nebi.
const PLACE := Vector2(14, 44)
const NEBI := Vector2(10, 40)
## La maison de soins de Pésèshet et ses trois ouvriers sans nom.
const SOINS := Vector2(58, 74)
const PESECHET := Vector2(52, 70)
const BLESSES := [Vector2(53, 77), Vector2(58, 78), Vector2(63, 77)]
## La boulangerie et la brasserie de Méret.
const BOULANGERIE := Vector2(-10, 64)
const MERET := Vector2(-6, 58)
## Les dortoirs des haleurs : trois longues galeries (centre z de chacune).
const DORTOIRS := [12.0, 24.0, 36.0]
const DORTOIRS_X := Vector2(-66, -22)
## L'enclos des bœufs.
const ENCLOS := Rect2(66, 14, 22, 16)
## L'atelier d'Ouni.
const ATELIER := Vector2(-30, 86)
const OUNI := Vector2(-26, 80)
const PANIERS := [Vector2(-34, 86.8), Vector2(-31.5, 87.0), Vector2(-29, 87.0), Vector2(-26.5, 86.8)]
## Les amulettes de la prêtresse : brasserie, dortoirs, enclos.
const AMULETTES := [Vector2(-13.5, 67.4), Vector2(-50, 18), Vector2(74, 21)]
## Là où l'on échange les amulettes en secret (entre deux dortoirs).
const ECHANGE := Vector2(-36, 30)
## Le cimetière des ouvriers, sur la pente ouest.
const CIMETIERE := Vector2(-100, 34)
## Le mur du Corbeau, et sa porte.
const MUR_Z := -8.0
const MUR_DEMI := 112.0
const PORTE_DEMI := 4.5
## Le plateau et le chantier.
const H_VILLAGE := 3.0
const H_PLATEAU := 14.0
const CHANTIER := Vector2(-6, -100)
## Les bâtisseurs libérés au cimetière, et où ils se retrouvent ensuite.
const LIBERES := [Vector2(19, 40), Vector2(20, 48)]
const NOMS_LIBERES := ["batisseur_kai", "batisseur_hetepi"]

var _blesses: Array[Node3D] = []


func _init() -> void:
	identifiant_zone = "village_batisseurs"
	noms_liberes = NOMS_LIBERES
	places_liberes = LIBERES
	taille_terrain = 320
	graine = 2562
	point_apparition = ENTREE + Vector2(-10, 0)
	nombre_touffes = 14000
	neige_qui_tombe = false
	sols = {
		# Rouge : le limon noir des champs et du canal.
		"galets": ["brown_mud_02", "brown_mud_03", "mud_cracked_dry_riverbed_002"],
		# Vert : le sable du plateau et du cimetière.
		"neige": ["sand_01", "dense_sand", "dry_ground_rocks"],
		# Bleu : la terre battue des rues.
		"sol": ["dry_ground_01", "mud_cracked_dry_03", "dry_ground_rocks"],
		"roche": ["sandstone_cracks", "quarry_wall", "cliff_side"],
	}
	reglages_terrain = {"sol_saturation": 0.9, "sol_motif": 5.0, "galets_motif": 3.0, "neige_motif": 6.0,
			"sol_teinte": Color(1.0, 0.96, 0.9), "roche_teinte": Color(1.02, 0.98, 0.9), "roche_saturation": 0.9,
			"neige_eclat": 1.0, "neige_paillettes": 0.0, "roche_motif": 12.0,
			"neige_teinte": Color(1.04, 1.0, 0.94), "neige_max": Vector3(0.86, 0.76, 0.62), "neige_simple": Color(0.8, 0.68, 0.5),
			"givre": 0.0, "neige_translucide": 0.0}
	reglages_herbe = {"couleur_base": Color(0.16, 0.22, 0.06), "couleur_pointe": Color(0.5, 0.58, 0.22),
			"couleur_givre": Color(0.6, 0.58, 0.3), "force_vent": 0.15}
	# La route du port, la grande place, la porte du mur, puis la montée au chantier.
	piste = [Vector2(156, 62), Vector2(124, 58), Vector2(92, 54), Vector2(60, 50), Vector2(32, 46), PLACE,
			Vector2(4, 28), Vector2(0, 10), Vector2(0, -6), Vector2(0, -30), Vector2(-3, -60), CHANTIER]


func _ready() -> void:
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_egypte", "") != "":
		Reseau.remove_meta("arrivee_egypte")
		point_apparition = ENTREE + Vector2(-10, 0)
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	return ENTREE if zone != "village_batisseurs" else Vector2.INF


# --- Relief -----------------------------------------------------------------------------

func _preparer_bruits() -> void:
	super._preparer_bruits()
	_relief.frequency = 0.013


func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	var bruit := _relief.get_noise_2d(x, z)
	var fin := _details.get_noise_2d(x * 3.0, z * 3.0)
	# Le fond de vallée où s'étend le village, qui descend doucement vers le port (est).
	var h := H_VILLAGE + bruit * 0.5 + fin * 0.06 - smoothstep(60.0, 160.0, x) * 1.2
	# Le plateau de Gizeh, au nord du mur : une montée raide, puis le haut plat.
	var montee := smoothstep(MUR_Z - 6.0, -48.0, z + bruit * 4.0)
	h = lerpf(h, H_PLATEAU + bruit * 1.2 + fin * 0.1, montee)
	# Le chemin du chantier : une rampe régulière qui passe la porte du mur.
	var chemin := 1.0 - smoothstep(5.0, 11.0, absf(x - 1.0))
	var rampe := lerpf(H_VILLAGE, H_PLATEAU, smoothstep(MUR_Z + 2.0, -50.0, z))
	h = lerpf(h, rampe, chemin * smoothstep(20.0, 10.0, z) * smoothstep(-70.0, -55.0, z))
	# La pente ouest, vers le désert : le cimetière est dessus.
	h += smoothstep(-62.0, -150.0, x + bruit * 6.0) * (6.0 + bruit * 1.5) * (1.0 - montee)
	# Le canal du port, au sud : il passe sous l'eau.
	var canal := smoothstep(116.0, 128.0, z + bruit * 3.0)
	h = lerpf(h, -1.4 + fin * 0.1, canal)
	# Les terrasses aplanies du village (place, maisons) : terre battue.
	h = lerpf(h, H_VILLAGE + fin * 0.04, _dans_rect(Rect2(-72, 4, 156, 92), x, z, 10.0) * (1.0 - canal))
	return h


## Rouge : limon des champs ; vert : sable ; bleu : terre battue des rues.
func _parts_sol(x: float, z: float, h: float) -> Color:
	var n := _relief.get_noise_2d(x * 2.0 + 90.0, z * 2.0)
	var champs := smoothstep(96.0, 104.0, z + n * 4.0) * (1.0 - smoothstep(-64.0, -76.0, x))
	var sable := maxf(smoothstep(-6.0, -24.0, z + n * 6.0), smoothstep(-66.0, -84.0, x + n * 8.0))
	var rue := (1.0 - smoothstep(2.0, 4.5, _distance_piste(Vector2(x, z)))) * 0.8
	sable = maxf(0.0, sable - rue)
	champs = maxf(champs, 1.0 - smoothstep(-0.2, 0.8, h))
	return Color(champs, sable * (1.0 - champs), (1.0 - sable) * (1.0 - champs), 1.0)


# --- Construction -------------------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_flotteurs.clear()
	_a_liberer.clear()
	_blesses.clear()
	_liberes = 0
	_construire_terrain()
	_construire_eau()
	_construire_place()
	_construire_dortoirs()
	_construire_quartiers()
	_construire_boulangerie()
	_construire_soins()
	_construire_enclos()
	_construire_atelier()
	_construire_cimetiere()
	_construire_mur()
	_construire_chantier()
	_construire_vegetation()
	_construire_rochers()
	_construire_touffes()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_appliquer_ciel()
	var balise := get_node_or_null("BaliseVigie") as Node3D
	if balise != null:
		balise.position = Vector3(ENTREE.x - 6.0, hauteur(ENTREE.x - 6.0, ENTREE.y - 6.0), ENTREE.y - 6.0)


func _dossier(nom: String) -> Node3D:
	var d := Node3D.new()
	d.name = nom
	_contenu.add_child(d)
	return d


# --- La grande place ------------------------------------------------------------------------

func _construire_place() -> void:
	var place := _dossier("Place")
	# La pierre de la place : un gros bloc de granite où l'on bat le grain et où l'on parle.
	var granite := _mat_pbr("", Color(0.38, 0.32, 0.3), 0.7, 1.0)
	var y := hauteur(PLACE.x, PLACE.y)
	_boite(Vector3(2.4, 0.8, 1.6), Vector3(PLACE.x, y + 0.4, PLACE.y), granite, place)
	# Un puits (un trou rond bordé de briques) et des jarres d'eau.
	var briques := _mat_briques()
	var puits := MeshInstance3D.new()
	puits.mesh = _cylindre(1.1, 1.2, 0.8, 16)
	puits.material_override = briques
	puits.position = Vector3(PLACE.x + 8.0, hauteur(PLACE.x + 8.0, PLACE.y - 6.0) + 0.4, PLACE.y - 6.0)
	place.add_child(puits)
	var eau := MeshInstance3D.new()
	eau.mesh = _cylindre(0.9, 0.9, 0.05, 16)
	eau.material_override = _mat_pbr("", Color(0.05, 0.06, 0.05), 0.05, 1.0)
	eau.position = puits.position + Vector3(0, 0.38, 0)
	place.add_child(eau)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 10
	for k in 6:
		var p := PLACE + Vector2(8.0, -6.0) + Vector2(hasard.randf_range(-2.6, 2.6), hasard.randf_range(1.4, 2.6))
		_jarre(place, Vector3(p.x, hauteur(p.x, p.y) - 0.02, p.y), hasard.randf_range(0.8, 1.1), hasard.randf() * TAU)
	# Les auvents des marchands : poissons séchés, oignons, lin.
	_auvent(place, PLACE + Vector2(-9, 4), Vector2(4, 3), 2.4, Color(0.92, 0.88, 0.78))
	_auvent(place, PLACE + Vector2(-8, -6), Vector2(3.5, 3), 2.3, Color(0.86, 0.8, 0.66))
	for p in [PLACE + Vector2(-9, 4), PLACE + Vector2(-8, -6)]:
		for id in ["wicker_basket_01", "wooden_bowl_01", "wooden_bucket_01"]:
			if _modele(id, Vector3(p.x + hasard.randf_range(-1.2, 1.2), hauteur(p.x, p.y), p.y + hasard.randf_range(-0.8, 0.8)),
					hasard.randf() * TAU, 1.0, place) == null:
				break


# --- Les dortoirs des haleurs ----------------------------------------------------------------

func _construire_dortoirs() -> void:
	var dortoirs := _dossier("Dortoirs")
	# De longues galeries à colonnes : une salle commune où dorment les équipes, une
	# cuisine au bout. Les archéologues en ont trouvé quatre rangées à Gizeh.
	var longueur := DORTOIRS_X.y - DORTOIRS_X.x
	var centre_x := (DORTOIRS_X.x + DORTOIRS_X.y) * 0.5
	var bois := _mat_choix(["palm_tree_bark", "rough_wood"], Color(0.5, 0.42, 0.32), 0.95, 0.5)
	for z in DORTOIRS:
		var y := hauteur(centre_x, z)
		# Mur du fond (nord), murs des bouts, toit plat ; la façade sud est une colonnade.
		_boite(Vector3(longueur, 3.4, 0.6), Vector3(centre_x, y + 1.7, z - 2.2), _mat_enduit(), dortoirs)
		for cote in [-1.0, 1.0]:
			_boite(Vector3(0.6, 3.4, 5.0), Vector3(centre_x + cote * longueur * 0.5, y + 1.7, z), _mat_enduit(), dortoirs)
		_boite(Vector3(longueur + 0.4, 0.3, 5.4), Vector3(centre_x, y + 3.55, z), _mat_briques(), dortoirs, false)
		var colonne := 0.0
		while colonne <= longueur:
			var poteau := MeshInstance3D.new()
			poteau.mesh = _cylindre(0.16, 0.18, 3.4, 8)
			poteau.material_override = bois
			poteau.position = Vector3(DORTOIRS_X.x + colonne, y + 1.7, z + 2.3)
			dortoirs.add_child(poteau)
			colonne += 3.2
		# Les nattes de couchage alignées, et une banquette de briques le long du mur.
		_boite(Vector3(longueur - 1.0, 0.45, 1.0), Vector3(centre_x, y + 0.22, z - 1.4), _mat_briques(), dortoirs, false)
		var natte := _mat_lin(Color(0.78, 0.7, 0.5))
		var x := DORTOIRS_X.x + 1.5
		while x < DORTOIRS_X.y - 1.0:
			_boite(Vector3(0.8, 0.04, 1.9), Vector3(x, y + 0.03, z + 0.4), natte, dortoirs, false)
			x += 1.4
		# Un foyer de cuisine devant le bout est, et des jarres.
		_feu(dortoirs, Vector2(DORTOIRS_X.y + 3.0, z + 1.0), 0.6)


# --- Les maisons du village ------------------------------------------------------------------

func _construire_quartiers() -> void:
	var quartier := _dossier("Maisons")
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 20
	# Des rangées de maisons le long des rues, entre la place et la route de l'est.
	var rangees := [
		[Vector2(24, 30), Vector2(54, 30), 0.0], [Vector2(24, 58), Vector2(44, 58), PI],
		[Vector2(30, 88), Vector2(56, 88), PI], [Vector2(70, 40), Vector2(96, 40), 0.0],
		[Vector2(70, 66), Vector2(100, 66), PI], [Vector2(-8, 84), Vector2(10, 84), PI],
		[Vector2(-60, 54), Vector2(-26, 54), PI], [Vector2(-60, 70), Vector2(-32, 70), 0.0],
	]
	for r in rangees:
		var debut: Vector2 = r[0]
		var fin: Vector2 = r[1]
		var x := debut.x
		while x < fin.x:
			var largeur := hasard.randf_range(4.0, 6.5)
			var taille := Vector3(largeur, hasard.randf_range(2.4, 3.0), hasard.randf_range(4.0, 5.5))
			var z: float = debut.y + hasard.randf_range(-0.4, 0.4)
			_maison(quartier, Vector2(x + largeur * 0.5, z), taille, r[2])
			# Devant certaines portes : une jarre, un panier, un four à pain domestique.
			if hasard.randf() < 0.5:
				var devant := 1.0 if r[2] == 0.0 else -1.0
				var p := Vector2(x + largeur * 0.5 + hasard.randf_range(-1.5, 1.5), z + devant * (taille.z * 0.5 + 0.8))
				_jarre(quartier, Vector3(p.x, hauteur(p.x, p.y) - 0.02, p.y), hasard.randf_range(0.7, 1.0), hasard.randf() * TAU)
			x += largeur + hasard.randf_range(0.0, 0.6)


# --- La boulangerie et la brasserie de Méret ---------------------------------------------------

func _construire_boulangerie() -> void:
	var b := _dossier("Boulangerie")
	# Une cour fermée par un muret, une maison, des fours et des moules à pain.
	_maison(b, BOULANGERIE + Vector2(0, -2), Vector3(7, 2.8, 5), PI)
	var y := hauteur(BOULANGERIE.x, BOULANGERIE.y)
	var briques := _mat_briques()
	_boite(Vector3(14, 1.2, 0.5), Vector3(BOULANGERIE.x, y + 0.6, BOULANGERIE.y + 8.0), briques, b)
	_boite(Vector3(0.5, 1.2, 9.0), Vector3(BOULANGERIE.x - 7.0, y + 0.6, BOULANGERIE.y + 3.5), briques, b)
	# Les fours : des dômes de terre noircis.
	var terre := _mat_pbr("", Color(0.42, 0.3, 0.22), 1.0, 1.0)
	for k in 3:
		var four := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.8
		s.height = 1.2
		s.is_hemisphere = true
		four.mesh = s
		four.material_override = terre
		four.position = Vector3(BOULANGERIE.x + 3.5, hauteur(BOULANGERIE.x + 3.5, BOULANGERIE.y + 2.0 + k * 1.9), BOULANGERIE.y + 2.0 + k * 1.9)
		b.add_child(four)
	_feu(b, BOULANGERIE + Vector2(1.8, 4.0), 0.5)
	# Les moules à pain coniques (bedja), empilés, et les pains qui refroidissent.
	var ceramique := _mat_pbr("", Color(0.62, 0.38, 0.26), 0.95, 1.0)
	var pain := _mat_pbr("", Color(0.72, 0.52, 0.3), 0.9, 1.0)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 30
	for k in 14:
		var moule := MeshInstance3D.new()
		moule.mesh = _cylindre(0.16, 0.02, 0.42, 8)
		moule.material_override = ceramique if k % 3 != 0 else pain
		var p := BOULANGERIE + Vector2(-2.5 + (k % 5) * 0.45, 3.0 + (k / 5) * 0.5)
		moule.position = Vector3(p.x, hauteur(p.x, p.y) + 0.21, p.y)
		moule.rotation.z = PI if k % 3 != 0 else 0.0
		b.add_child(moule)
	# La brasserie : de grandes jarres alignées où fermente la bière d'orge.
	for k in 10:
		var p := Vector2(BOULANGERIE.x - 5.5 + (k % 5) * 1.0, BOULANGERIE.y + 5.0 + (k / 5) * 1.1)
		_jarre(b, Vector3(p.x, hauteur(p.x, p.y) - 0.02, p.y), hasard.randf_range(1.1, 1.3), hasard.randf() * TAU)
	_auvent(b, MERET + Vector2(0, 1.5), Vector2(3.5, 2.5), 2.4, Color(0.9, 0.85, 0.72))


# --- La maison de soins de Pésèshet ------------------------------------------------------------

func _construire_soins() -> void:
	var s := _dossier("Soins")
	_maison(s, SOINS + Vector2(4, -9), Vector3(9, 3.0, 5), 0.0)
	# Un grand auvent sur la cour, et les nattes des malades.
	_auvent(s, SOINS + Vector2(0, 3.5), Vector2(14, 6), 2.6, Color(0.95, 0.93, 0.86))
	var natte := _mat_lin(Color(0.8, 0.72, 0.52))
	for p in BLESSES:
		_boite(Vector3(1.0, 0.04, 2.1), Vector3(p.x, hauteur(p.x, p.y) + 0.03, p.y), natte, s, false)
	# Ses remèdes : des pots de miel, de natron, des bandes de lin sur une table basse.
	var bois := _mat_choix(["weathered_planks", "rough_wood"], Color(0.5, 0.4, 0.3), 0.9, 1.0)
	var table := PESECHET + Vector2(-2.2, 0.4)
	var y := hauteur(table.x, table.y)
	_boite(Vector3(1.6, 0.06, 0.7), Vector3(table.x, y + 0.6, table.y), bois, s)
	for k in 4:
		var pot := MeshInstance3D.new()
		pot.mesh = _cylindre(0.07, 0.09, 0.16, 8)
		pot.material_override = _mat_pbr("", [Color(0.75, 0.55, 0.2), Color(0.9, 0.9, 0.85), Color(0.6, 0.4, 0.3), Color(0.8, 0.75, 0.6)][k], 0.5, 1.0)
		pot.position = Vector3(table.x - 0.55 + k * 0.36, y + 0.71, table.y)
		s.add_child(pot)


# --- L'enclos des bœufs ---------------------------------------------------------------------------

func _construire_enclos() -> void:
	var e := _dossier("Enclos")
	var briques := _mat_briques()
	var r := ENCLOS
	var y := hauteur(r.get_center().x, r.get_center().y)
	# Un muret de briques, avec une entrée au sud.
	_boite(Vector3(r.size.x, 1.2, 0.5), Vector3(r.get_center().x, y + 0.6, r.position.y), briques, e)
	_boite(Vector3(0.5, 1.2, r.size.y), Vector3(r.position.x, y + 0.6, r.get_center().y), briques, e)
	_boite(Vector3(0.5, 1.2, r.size.y), Vector3(r.end.x, y + 0.6, r.get_center().y), briques, e)
	for cote in [-1.0, 1.0]:
		var largeur := r.size.x * 0.5 - 2.0
		_boite(Vector3(largeur, 1.2, 0.5), Vector3(r.get_center().x + cote * (2.0 + largeur * 0.5), y + 0.6, r.end.y), briques, e)
	# Des mangeoires de pierre, de la paille.
	var paille := _mat_pbr("", Color(0.78, 0.66, 0.38), 1.0, 1.0)
	for k in 3:
		_boite(Vector3(2.4, 0.5, 0.7), Vector3(r.position.x + 4.0 + k * 6.0, y + 0.25, r.position.y + 1.4), _mat_calcaire(), e, false)
		_boite(Vector3(2.2, 0.15, 0.5), Vector3(r.position.x + 4.0 + k * 6.0, y + 0.52, r.position.y + 1.4), paille, e, false)


# --- L'atelier d'Ouni l'Ancien ---------------------------------------------------------------------

func _construire_atelier() -> void:
	var a := _dossier("Atelier")
	_maison(a, ATELIER + Vector2(0, 5), Vector3(8, 2.8, 4), PI)
	_auvent(a, ATELIER + Vector2(0, -1), Vector2(7, 4), 2.5, Color(0.88, 0.84, 0.72))
	# Les étagères où sèchent les paniers d'amulettes, des blocs en cours de taille.
	var bois := _mat_choix(["weathered_planks", "rough_wood"], Color(0.5, 0.4, 0.3), 0.9, 1.0)
	var y := hauteur(ATELIER.x, ATELIER.y + 2.6)
	_boite(Vector3(9.0, 0.08, 0.7), Vector3(ATELIER.x, y + 0.9, ATELIER.y + 2.7), bois, a, false)
	for k in 4:
		var pied := MeshInstance3D.new()
		pied.mesh = _cylindre(0.05, 0.05, 0.9, 6)
		pied.material_override = bois
		pied.position = Vector3(ATELIER.x - 4.3 + k * 2.86, y + 0.45, ATELIER.y + 2.7)
		a.add_child(pied)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 40
	for k in 3:
		var p := ATELIER + Vector2(-2.5 + k * 2.5, -3.0)
		_bloc_calcaire(a, Vector3(p.x, hauteur(p.x, p.y) + 0.4, p.y), Vector3(1.0, 0.8, 0.8), hasard.randf_range(-0.3, 0.3))


# --- Le cimetière des ouvriers -------------------------------------------------------------------

func _construire_cimetiere() -> void:
	var c := _dossier("Cimetiere")
	var briques := _mat_briques()
	var enduit := _mat_enduit()
	var calcaire := _mat_calcaire()
	var noir := _mat_pbr("", Color(0.05, 0.04, 0.03), 1.0, 1.0)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 50
	# Des petites tombes : pyramides de briques, dômes, chapelles avec une « fausse porte ».
	for k in 46:
		var p := CIMETIERE + Vector2(hasard.randf_range(-26.0, 26.0), hasard.randf_range(-24.0, 24.0))
		if p.distance_to(CIMETIERE) < 7.0:
			continue
		var y := hauteur(p.x, p.y)
		match k % 3:
			0:
				var taille := hasard.randf_range(1.4, 3.2)
				var pyr := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.0
				cm.bottom_radius = taille * 0.7
				cm.height = taille
				cm.radial_segments = 4
				cm.rings = 1
				pyr.mesh = cm
				pyr.material_override = briques if hasard.randf() < 0.6 else enduit
				pyr.position = Vector3(p.x, y + taille * 0.5 - 0.1, p.y)
				pyr.rotation.y = PI / 4
				c.add_child(pyr)
			1:
				var dome := MeshInstance3D.new()
				var s := SphereMesh.new()
				s.radius = hasard.randf_range(0.8, 1.4)
				s.height = s.radius * 1.6
				s.is_hemisphere = true
				dome.mesh = s
				dome.material_override = briques
				dome.position = Vector3(p.x, y - 0.05, p.y)
				c.add_child(dome)
			_:
				var t := Vector3(hasard.randf_range(1.6, 2.6), hasard.randf_range(1.2, 1.8), hasard.randf_range(1.6, 2.4))
				_boite(t, Vector3(p.x, y + t.y * 0.5 - 0.1, p.y), enduit, c)
				# La « fausse porte » tournée vers l'est, par où l'âme sort chercher ses offrandes.
				_boite(Vector3(0.05, t.y * 0.7, 0.5), Vector3(p.x + t.x * 0.5 + 0.02, y + t.y * 0.4, p.y), noir, c, false)
				_boite(Vector3(0.3, 0.1, 0.4), Vector3(p.x + t.x * 0.5 + 0.3, y + 0.05, p.y), calcaire, c, false)
	# Le petit autel du cimetière, avec des pains et des jarres d'offrande.
	var y0 := hauteur(CIMETIERE.x, CIMETIERE.y)
	_boite(Vector3(1.6, 0.9, 1.0), Vector3(CIMETIERE.x, y0 + 0.45, CIMETIERE.y), calcaire, c)
	for k in 3:
		_jarre(c, Vector3(CIMETIERE.x - 0.6 + k * 0.6, y0 + 0.9, CIMETIERE.y), 0.45, k)


# --- Le mur du Corbeau --------------------------------------------------------------------------

func _construire_mur() -> void:
	var m := _dossier("MurDuCorbeau")
	# Un mur de pierre colossal (10 m de haut, 200 m de long) qui sépare la ville du
	# plateau sacré. Au centre, une porte couverte, comme un tunnel.
	var pierre := _mat_choix(["sandstone_blocks_08", "large_sandstone_blocks", "cliff_side"], Color(0.78, 0.68, 0.52), 0.95, 3.0)
	var haut := 9.5
	for cote in [-1.0, 1.0]:
		var longueur := MUR_DEMI - PORTE_DEMI
		var cx: float = cote * (PORTE_DEMI + longueur * 0.5)
		var base: float = minf(hauteur(cx, MUR_Z), hauteur(cote * PORTE_DEMI, MUR_Z)) - 2.0
		_boite(Vector3(longueur, haut + 6.0, 6.0), Vector3(cx, base + (haut + 6.0) * 0.5, MUR_Z), pierre, m)
	var y_porte := hauteur(0.0, MUR_Z)
	_boite(Vector3(PORTE_DEMI * 2.0 + 0.4, 3.2, 6.0), Vector3(0, y_porte + 5.0 + 1.6, MUR_Z), pierre, m)


# --- Le chantier de Gizeh -------------------------------------------------------------------------

func _construire_chantier() -> void:
	var ch := _dossier("Chantier")
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 60
	var bois := _mat_bois()
	# Des rangées de blocs arrivés de Toura, marqués à l'ocre par leur équipe.
	for k in 70:
		var p := CHANTIER + Vector2(hasard.randf_range(-60.0, 60.0), hasard.randf_range(-40.0, 30.0))
		if absf(p.x - 1.0) < 9.0 or p.distance_to(CHANTIER + Vector2(18, -6)) < 7.0:
			continue
		var y := hauteur(p.x, p.y)
		_bloc_calcaire(ch, Vector3(p.x, y + 0.5, p.y), Vector3(1.5, 1.0, 1.0), hasard.randf_range(-0.1, 0.1) + (PI / 2 if k % 2 == 0 else 0.0))
		if hasard.randf() < 0.35:
			_bloc_calcaire(ch, Vector3(p.x, y + 1.5, p.y), Vector3(1.4, 1.0, 1.0), hasard.randf_range(-0.15, 0.15))
	# Des traîneaux chargés qui attendent leurs haleurs.
	for k in 4:
		var t := Traineau.new()
		t.name = "Traineau%d" % k
		var p := CHANTIER + Vector2(-26.0 + k * 16.0, -30.0 + (k % 2) * 8.0)
		t.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
		t.rotation.y = hasard.randf_range(-0.3, 0.3)
		t.materiau_bloc = _mat_calcaire()
		t.materiau_bois = bois
		ch.add_child(t)
	# La grande rampe de briques et de gravats qui monte vers la pyramide (au nord).
	var rampe := _mat_choix(["dry_ground_01", "dry_ground_rocks"], Color(0.62, 0.5, 0.36), 1.0, 4.0)
	var y0 := hauteur(CHANTIER.x, CHANTIER.y - 40.0)
	var longueur := 40.0
	var montee := 10.0
	var corps := _boite(Vector3(10.0, 1.0, longueur), Vector3(CHANTIER.x, y0 + montee * 0.5, CHANTIER.y - 40.0 - longueur * 0.5), rampe, ch)
	corps.rotation.x = atan2(montee, longueur)
	# Les murets de soutènement de la rampe.
	for cote in [-1.0, 1.0]:
		var muret := _boite(Vector3(0.8, 2.0, longueur), Vector3(CHANTIER.x + cote * 5.4, y0 + montee * 0.5 + 0.6, CHANTIER.y - 40.0 - longueur * 0.5), _mat_briques(), ch)
		muret.rotation.x = corps.rotation.x
	# L'abri des scribes qui comptent les blocs, et leurs jarres d'eau.
	var scribes := CHANTIER + Vector2(18, -6)
	_auvent(ch, scribes, Vector2(5, 4), 2.6)
	for k in 5:
		_jarre(ch, Vector3(scribes.x - 2.0 + k * 0.9, hauteur(scribes.x, scribes.y + 2.6) - 0.02, scribes.y + 2.6), 1.0, k)
	_feu(ch, CHANTIER + Vector2(-20, 6), 0.7)


# --- Végétation et rochers --------------------------------------------------------------------------

func _construire_vegetation() -> void:
	# Des papyrus au bord du canal, des palmiers dans les cours et le long de la route.
	_semer_papyrus(500, Rect2(-160, 110, 320, 40), func(x: float, z: float) -> bool:
		var h := hauteur(x, z)
		return h > -0.6 and h < 0.4, graine + 5)
	var points: Array = []
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 7
	for k in 140:
		var x := hasard.randf_range(-70.0, 150.0)
		var z := hasard.randf_range(0.0, 115.0)
		var p := Vector2(x, z)
		var h := hauteur(x, z)
		if h < 1.0 or _distance_piste(p) < 4.0 or _occupe(p):
			continue
		points.append(p)
	_planter_palmiers(points, graine + 8)


## Vrai si un bâtiment ou un lieu de la quête est là (pour ne pas y planter d'arbre).
func _occupe(p: Vector2) -> bool:
	if p.distance_to(PLACE) < 14.0 or p.distance_to(SOINS) < 12.0 or p.distance_to(BOULANGERIE) < 11.0:
		return true
	if p.distance_to(ATELIER) < 9.0 or p.distance_to(ENTREE) < 8.0 or ENCLOS.grow(3.0).has_point(p):
		return true
	if Rect2(DORTOIRS_X.x - 3.0, DORTOIRS[0] - 5.0, DORTOIRS_X.y - DORTOIRS_X.x + 8.0, DORTOIRS[-1] - DORTOIRS[0] + 10.0).has_point(p):
		return true
	# Les rangées de maisons.
	for r in [Rect2(22, 26, 36, 8), Rect2(22, 54, 26, 8), Rect2(28, 84, 32, 8), Rect2(68, 36, 32, 8),
			Rect2(68, 62, 36, 8), Rect2(-10, 80, 24, 8), Rect2(-62, 50, 40, 8), Rect2(-62, 66, 34, 8)]:
		if r.has_point(p):
			return true
	return false


func _construire_rochers() -> void:
	var dossier := _dossier("Rochers")
	_preparer_rochers()
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 12
	# Des pierres sur le plateau et la pente du désert.
	for k in 120:
		var x := hasard.randf_range(-155.0, 155.0)
		var z := hasard.randf_range(-155.0, 20.0)
		if z > -20.0 and x > -70.0:
			continue
		if absf(x - 1.0) < 10.0 or Vector2(x, z).distance_to(CIMETIERE) < 26.0:
			continue
		_placer_rocher(dossier, x, z, hasard.randf_range(0.3, 1.6))
	for id_k in 14:
		var x := hasard.randf_range(-150.0, -80.0)
		var z := hasard.randf_range(-150.0, 110.0)
		if Vector2(x, z).distance_to(CIMETIERE) < 28.0:
			continue
		var id: String = ["namaqualand_boulder_02", "namaqualand_boulder_03", "sand_rocks_small_01"][id_k % 3]
		_modele(id, Vector3(x, hauteur(x, z) - 0.2, z), hasard.randf() * TAU, hasard.randf_range(0.8, 1.6), dossier)


# --- Paysage lointain ----------------------------------------------------------------------

func _construire_lointain() -> void:
	# Le plateau du désert continue au nord et à l'ouest ; la Grande Pyramide le domine.
	_plan_lointain(Vector3(-900, H_PLATEAU + 2.0, -600), Vector2(1500, 2400), Color(0, 1, 0))
	_plan_lointain(Vector3(0, H_PLATEAU - 0.4, -900), Vector2(3200, 1400), Color(0, 1, 0))
	_construire_pyramide(Vector3(-10, H_PLATEAU - 1.0, -320), 0.0)
	# Les trois petites pyramides des reines, à l'est de la grande.
	var calcaire := _mat_choix(["white_sandstone_blocks_02", "cliff_side"], Color(0.9, 0.86, 0.76), 0.7, 4.0)
	for k in 3:
		var reine := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 32.0
		cm.height = 30.0
		cm.radial_segments = 4
		cm.rings = 1
		reine.mesh = cm
		reine.material_override = calcaire
		reine.position = Vector3(160.0, H_PLATEAU - 1.0 + 15.0, -240.0 + k * 52.0)
		reine.rotation.y = PI / 4
		reine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(reine)
	# À l'est et au sud : la plaine inondée, avec des palmeraies.
	_plan_lointain(Vector3(1000, 0.4, 300), Vector2(1400, 3200), Color(0.6, 0, 0.4))
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 71
	var variantes: Array[ArrayMesh] = []
	for k in 3:
		variantes.append(_maillage_palmier(hasard, hasard.randf_range(9.0, 12.0)))
	for k in 140:
		var mi := MeshInstance3D.new()
		mi.mesh = variantes[k % variantes.size()]
		var angle := hasard.randf_range(-0.6, PI * 0.6)
		var distance := hasard.randf_range(200.0, 520.0)
		mi.position = Vector3(cos(angle) * distance, 0.6, 120.0 + sin(angle) * distance * 0.6)
		mi.rotation.y = hasard.randf() * TAU
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(mi)


# --- Limites de la zone -----------------------------------------------------------------------

func _construire_limites() -> void:
	var limites := _dossier("Limites")
	var demi := taille_terrain * 0.5 - 4.0
	_mur_invisible(limites, Vector3(2, 160, taille_terrain), Vector3(-demi, 60, 0))
	_mur_invisible(limites, Vector3(2, 160, taille_terrain), Vector3(demi, 60, 0))
	_mur_invisible(limites, Vector3(taille_terrain, 160, 2), Vector3(0, 60, -demi))
	# Le canal du port, au sud : on n'y entre pas.
	_mur_invisible(limites, Vector3(taille_terrain, 12, 1.0), Vector3(0, 2, 117.0))


# --- Personnages et objets de la quête ----------------------------------------------------------

func _construire_quete() -> void:
	var dossier := _dossier("Quete")
	_dossier_quete = dossier
	_pnj(dossier, "pesechet", PESECHET, PI)
	_pnj(dossier, "nebi", NEBI, PI * 0.25)
	_pnj(dossier, "meret", MERET, PI)
	_pnj(dossier, "ouni", OUNI, PI)
	_pnj(dossier, "villageoise_1", PLACE + Vector2(-9, 6.5), PI)
	_pnj(dossier, "villageois_2", CHANTIER + Vector2(16, -3), PI * 0.8)
	_pnj(dossier, "haleur_1", CHANTIER + Vector2(-26, -36), 0.2)
	_pnj(dossier, "haleur_2", CHANTIER + Vector2(6, -24), -0.4)
	# Les trois ouvriers sans nom, allongés chez Pésèshet.
	for k in BLESSES.size():
		var n := _pnj(dossier, "ouvrier_amnesique_%d" % (k + 1), BLESSES[k], PI)
		n.set("blesse", true)
		_blesses.append(n)
		_objet(dossier, "Examiner%d" % k, "examiner_%d" % k, "ouvrier_examine", "", "[F] Examiner l'ouvrier", BLESSES[k] + Vector2(0.9, 0))
	# Les amulettes de la prêtresse.
	for k in AMULETTES.size():
		_objet(dossier, "Amulette%d" % k, "amulette_village_%d" % k, "amulette_village", "amulette", "[F] Ramasser l'amulette", AMULETTES[k])
	# Le choix : briser les amulettes sur la pierre de la place, ou les confier à Méret.
	_objet(dossier, "BriserAmulettes", "briser_amulettes", "", "", "[F] Briser les amulettes sur la pierre", PLACE + Vector2(0, 1.4))
	_objet(dossier, "EchangerAmulettes", "echanger_amulettes", "", "", "[F] Confier les amulettes à Méret", MERET + Vector2(0, 1.6))
	for k in PANIERS.size():
		# Les paniers sont proches les uns des autres : on ne prend que celui devant soi.
		_objet(dossier, "Panier%d" % k, "panier_%d" % k, "panier_amulettes", "panier", "[F] Prendre le panier d'amulettes", PANIERS[k]).set("portee", 1.6)
	_objet(dossier, "DortoirEchange", "dortoir_echange", "", "", "[F] Échanger les amulettes des dormeurs", ECHANGE)
	if not Engine.is_editor_hint():
		_reprendre_etat.call_deferred()
	# Repères de la carte.
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.LIEU, "Route du Port", ENTREE)
	repere.call(MarqueurCarte.Type.LIEU, "Grande place", PLACE)
	repere.call(MarqueurCarte.Type.LIEU, "Maison de soins", SOINS)
	repere.call(MarqueurCarte.Type.LIEU, "Boulangerie de Méret", BOULANGERIE)
	repere.call(MarqueurCarte.Type.LIEU, "Dortoirs des haleurs", Vector2(-44, 24))
	repere.call(MarqueurCarte.Type.LIEU, "Atelier d'Ouni", ATELIER)
	repere.call(MarqueurCarte.Type.LIEU, "Cimetière des ouvriers", CIMETIERE)
	repere.call(MarqueurCarte.Type.LIEU, "Porte du Mur du Corbeau", Vector2(0, MUR_Z))
	repere.call(MarqueurCarte.Type.LIEU, "Chantier de la pyramide", CHANTIER)
	repere.call(MarqueurCarte.Type.DANGER, "Chacals", Vector2(-128, -30))


func _objet(parent: Node3D, nom_noeud: String, id: String, groupe_o: String, forme_o: String, texte: String, p: Vector2) -> Node3D:
	var o := ObjetEgypte.new()
	o.name = nom_noeud
	o.identifiant = id
	o.groupe = groupe_o
	o.forme = forme_o
	o.invite = texte
	o.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
	parent.add_child(o)
	return o


## L'état du village selon l'avancée de la quête (bâtisseurs libérés, malades guéris).
func _reprendre_etat() -> void:
	var quete := get_tree().get_first_node_in_group("quete")
	if quete == null or not quete.has_method("etape_atteinte"):
		return
	if quete.etape_atteinte("retour_nebi"):
		for k in NOMS_LIBERES.size():
			_pnj(_dossier_quete, NOMS_LIBERES[k], LIBERES[k], PI * 0.5 + k * 0.8)
		_liberes = NOMS_LIBERES.size()
	if quete.etape < 0:
		for n in _blesses:
			if is_instance_valid(n):
				n.set("blesse", false)


# --- Retour vers le Port des Marais ------------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	if Engine.is_editor_hint():
		return
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return
	if joueur.global_position.x > ENTREE.x + 4.0 and absf(joueur.global_position.z - ENTREE.y) < 16.0:
		var quete := get_tree().get_first_node_in_group("quete")
		if quete != null and quete.has_method("changer_de_zone"):
			quete.changer_de_zone("port_des_marais")
