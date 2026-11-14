@tool
extends "res://scripts/monde/egypte/ile_egypte.gd"
## Île d'Égypte, zone 1 : le Port des Marais (niveaux 10-12).
##
## Vers -2560, 27e année du règne de Khéops, en pleine crue du Nil. Au sud, des
## marais de papyrus où le portail de la Vigie est caché ; au centre, une levée de
## terre qui traverse les champs inondés ; au nord, le bassin du port de Gizeh et
## ses quais en briques crues, où l'équipe de Merer décharge les blocs de calcaire
## venus de Toura ; à l'est, le Nil, si large en crue qu'il ressemble à une mer ;
## à l'ouest, le plateau du désert, et au loin la Grande Pyramide presque achevée.
##
## Tout est construit par le code (voir ile_egypte.gd). Le bouton « Reconstruire »
## de l'Inspecteur refait tout.
##
## Repères : le nord est vers -Z, le Nil à l'est (+X).

const Pnj := preload("res://scripts/monde/prehistoire/pnj_epoque.gd")
const Faille := preload("res://scripts/monde/prehistoire/faille.gd")
const ObjetEgypte := preload("res://scripts/monde/egypte/objet_egypte.gd")
const Traineau := preload("res://scripts/monde/egypte/traineau.gd")
const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")

## Le portail de la Vigie, caché dans les papyrus.
const PORTAIL := Vector2(-34, 92)
## L'agent Farouk, trempée, à côté du portail.
const FAROUK := Vector2(-27, 83)
## Sa barque renversée par l'hippopotame, dans l'eau.
const BARQUE_FAROUK := Vector2(-14, 104)
## Le matériel de la Vigie qui flotte dans les roseaux.
const CAISSES := [Vector2(-7, 95), Vector2(-46, 109), Vector2(-21, 116)]
## Là où l'on installe la balise de la Vigie.
const BALISE := Vector2(-40, 80)
## La faille ouverte dans le marais.
const FAILLE := Vector2(-60, 56)
## Le bassin du port (rectangle x, z, largeur, profondeur) et la hauteur des quais.
const BASSIN := Rect2(-6, -62, 56, 48)
const QUAI := 1.3
## Le chenal qui relie le bassin au Nil.
const CHENAL := Rect2(48, -46, 40, 16)
## Merer et ses bateliers, sur le quai ouest.
const MERER := Vector2(-10, -22)
const BATELIERS := [Vector2(-11, -31), Vector2(-9, -36), Vector2(-14, -28), Vector2(-12, -41)]
## Ânkhkhaf, sous son auvent, devant les magasins.
const ANKHKHAF := Vector2(-28, -30)
## Le bloc à haler, sur son traîneau, et le chemin jusqu'au pied de la rampe.
const TRAINEAU := Vector2(-11, -52)
const HALAGE := [Vector2(-11, -52), Vector2(-24, -58), Vector2(-40, -64), Vector2(-54, -73), Vector2(-66, -86)]
## La rampe du plateau, vers le Village des Bâtisseurs (zone 3, à venir).
const RAMPE := Vector2(-74, -98)
## Là où l'hippopotame fracturé bloque le chenal.
const HIPPOPOTAME := Vector2(62, -38)

var _rive: FastNoiseLite


func _init() -> void:
	identifiant_zone = "port_des_marais"
	taille_terrain = 320
	graine = 2560
	point_apparition = PORTAIL + Vector2(0, -6)
	nombre_touffes = 60000
	neige_qui_tombe = false
	sols = {
		# Rouge : le limon noir et humide de la crue (Kemet, « la Terre Noire »).
		"galets": ["brown_mud_02", "brown_mud_03", "brown_mud_rocks_01"],
		# Vert : le sable du désert (plateau).
		"neige": ["sand_01", "dense_sand", "dry_ground_rocks"],
		# Bleu : la terre sèche, craquelée, des levées et des quais.
		"sol": ["mud_cracked_dry_03", "dry_ground_01", "dry_ground_rocks"],
		"roche": ["sandstone_cracks", "quarry_wall", "cliff_side"],
	}
	reglages_terrain = {"sol_saturation": 0.95, "sol_motif": 4.0, "galets_motif": 3.0, "neige_motif": 5.0,
			"sol_teinte": Color(1.0, 0.95, 0.86), "roche_teinte": Color(1.0, 0.94, 0.82), "roche_saturation": 0.8,
			"neige_eclat": 1.0, "neige_paillettes": 0.0, "roche_motif": 14.0}
	reglages_herbe = {"couleur_base": Color(0.17, 0.2, 0.07), "couleur_pointe": Color(0.55, 0.56, 0.24),
			"couleur_givre": Color(0.6, 0.58, 0.3), "force_vent": 0.15}
	# La levée de terre : du portail aux quais, à travers les champs inondés.
	piste = [Vector2(-34, 88), Vector2(-31, 62), Vector2(-25, 32), Vector2(-19, 6), Vector2(-14, -10)]


func _ready() -> void:
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_egypte", "") != "":
		Reseau.remove_meta("arrivee_egypte")
		point_apparition = RAMPE + Vector2(6, 10)
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	return RAMPE + Vector2(4, 6) if zone != "port_des_marais" else Vector2.INF


# --- Relief -----------------------------------------------------------------------------

func _preparer_bruits() -> void:
	super._preparer_bruits()
	_relief.frequency = 0.012
	_rive = FastNoiseLite.new()
	_rive.seed = graine + 3
	_rive.frequency = 0.02
	_rive.fractal_octaves = 2


## La rive du Nil : position x du bord de l'eau pour une position z.
func rive_nil(z: float) -> float:
	if _rive == null:
		_preparer_bruits()
	return 74.0 + _rive.get_noise_1d(z) * 8.0 + sin(z * 0.012) * 6.0


func _dans_rect(r: Rect2, x: float, z: float, fondu: float) -> float:
	var dx := maxf(r.position.x - x, x - r.end.x)
	var dz := maxf(r.position.y - z, z - r.end.y)
	return 1.0 - smoothstep(0.0, fondu, maxf(dx, dz))


func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	var bruit := _relief.get_noise_2d(x, z)
	var fin := _details.get_noise_2d(x * 3.0, z * 3.0)
	# La plaine inondée : des champs juste au ras de l'eau, des îlots de terre.
	var h := 0.18 + bruit * 0.45 + fin * 0.06
	# Les marais du sud : plus bas, l'eau partout entre les touffes de papyrus.
	h = lerpf(h, -0.32 + bruit * 0.5 + fin * 0.05, smoothstep(10.0, 40.0, z))
	# La terrasse des quais et des magasins, au-dessus de la crue.
	var terrasse := _dans_rect(Rect2(-66, -104, 62, 98), x, z, 10.0)
	h = lerpf(h, QUAI + fin * 0.05, terrasse)
	# Le plateau du désert à l'ouest : une pente de sable puis l'escarpement rocheux.
	var ouest := -x + _relief.get_noise_2d(z * 0.5, 40.0) * 10.0
	var plateau := smoothstep(70.0, 132.0, ouest)
	var falaise := smoothstep(112.0, 124.0, ouest)
	h += plateau * 6.0 + falaise * 10.0 + plateau * absf(_details.get_noise_2d(x * 0.4, z * 0.4)) * 2.5
	# La rampe qui monte du port vers le plateau (au nord-ouest).
	var d_rampe := _distance_segment(Vector2(x, z), Vector2(-62, -84), Vector2(-112, -140))
	var t_rampe := clampf(inverse_lerp(-62.0, -112.0, x), 0.0, 1.0)
	h = lerpf(h, QUAI + t_rampe * 15.5, (1.0 - smoothstep(4.0, 7.0, d_rampe)) * smoothstep(0.0, 0.05, t_rampe + 0.04))
	# La levée de terre, un peu au-dessus de l'eau.
	var d_levee := _distance_piste(Vector2(x, z))
	h = lerpf(h, maxf(h, 0.75 + fin * 0.04), 1.0 - smoothstep(2.5, 5.0, d_levee))
	# Le monticule du portail.
	h = lerpf(h, maxf(h, 0.55), 1.0 - smoothstep(7.0, 12.0, Vector2(x, z).distance_to(PORTAIL)))
	# Le bassin du port et son chenal : creusés, à fond plat.
	h = lerpf(h, -2.3, _dans_rect(BASSIN, x, z, 1.2))
	h = lerpf(h, -2.0, _dans_rect(Rect2(CHENAL.position.x, CHENAL.position.y, rive_nil(z) - CHENAL.position.x + 6.0,
			CHENAL.size.y), x, z, 2.0))
	# Le Nil : la berge plonge vite sous l'eau trouble.
	var berge := x - rive_nil(z)
	h = lerpf(h, minf(h, -0.4 - berge * 0.2), smoothstep(-6.0, 4.0, berge))
	h = maxf(h, -5.0) if berge > 0.0 else h
	# Au nord et au sud, la terre s'enfonce sous la crue (au-delà, l'eau à perte de vue).
	h = lerpf(h, minf(h, -0.8), smoothstep(128.0, 150.0, absf(z)) * (1.0 - plateau))
	return h


func _distance_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
	return p.distance_to(a + (b - a) * t)


## Rouge : limon mouillé ; vert : sable ; bleu : terre sèche craquelée.
func _parts_sol(x: float, z: float, h: float) -> Color:
	var n := _relief.get_noise_2d(x * 2.0 + 90.0, z * 2.0)
	var humide := 1.0 - smoothstep(0.35, 0.9, h + n * 0.3)
	var ouest := -x + _relief.get_noise_2d(z * 0.5, 40.0) * 10.0
	var sable := smoothstep(62.0, 82.0, ouest + n * 8.0) * (1.0 - humide)
	# Sur la levée et les quais, la terre est tassée et sèche.
	return Color(humide, sable, 1.0 - humide, 1.0)


# --- Construction -------------------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_flotteurs.clear()
	_construire_terrain()
	_construire_eau()
	_construire_quais()
	_construire_magasins()
	_construire_barques()
	_construire_vegetation()
	_construire_rochers_desert()
	_construire_touffes()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_appliquer_ciel()


# --- Le port --------------------------------------------------------------------------------

func _construire_quais() -> void:
	var port := Node3D.new()
	port.name = "Port"
	_contenu.add_child(port)
	var briques := _mat_briques()
	var r := BASSIN
	var fond := -2.3
	var haut := QUAI + 0.05
	var epaisseur := 1.6
	# Les murs du bassin en briques crues (ouest, nord, sud), et l'angle du chenal.
	var murs := [
		[Vector3(epaisseur, haut - fond, r.size.y + epaisseur * 2.0), Vector3(r.position.x - epaisseur * 0.5, (haut + fond) * 0.5, r.get_center().y)],
		[Vector3(r.size.x, haut - fond, epaisseur), Vector3(r.get_center().x, (haut + fond) * 0.5, r.position.y - epaisseur * 0.5)],
		[Vector3(r.size.x, 0.9 - fond, epaisseur), Vector3(r.get_center().x, (0.9 + fond) * 0.5, r.end.y + epaisseur * 0.5)],
	]
	for m in murs:
		_boite(m[0], m[1], briques, port)
	# Un parement de grosses pierres au pied du quai principal (là où accostent les cargos).
	for k in 14:
		var z := r.position.y + 2.0 + k * 3.2
		_bloc_calcaire(port, Vector3(r.position.x + 0.55, -0.3, z), Vector3(0.9, 1.6, 3.0), 0.0, false)
	# Les escaliers qui descendent à l'eau.
	for k in 6:
		_boite(Vector3(2.4, 0.3, 0.55), Vector3(r.position.x + 1.2, QUAI - 0.3 - k * 0.3, -18.0 + k * 0.0 - k * 0.55),
				briques, port)
	# Les pieux d'amarrage en bois.
	var bois := _mat_bois()
	for k in 8:
		var pieu := MeshInstance3D.new()
		pieu.mesh = _cylindre(0.12, 0.14, 2.4, 8)
		pieu.material_override = bois
		pieu.position = Vector3(r.position.x + 0.6, QUAI + 0.4, r.position.y + 4.0 + k * 5.6)
		port.add_child(pieu)
	# Des blocs de Toura déjà débarqués, empilés et numérotés à l'ocre (marques d'équipe).
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 80
	for k in 16:
		var x := hasard.randf_range(-22.0, -9.0)
		var z := hasard.randf_range(-92.0, -60.0)
		var etage := 1 if hasard.randf() < 0.25 else 0
		_bloc_calcaire(port, Vector3(x, QUAI + 0.5 + etage, z), Vector3(1.5, 1.0, 1.0), hasard.randf_range(-0.1, 0.1) + (PI / 2 if k % 3 == 0 else 0.0))
	# Le chenal : deux digues basses en briques qui le bordent jusqu'au fleuve.
	for cote in [CHENAL.position.y - 0.8, CHENAL.end.y + 0.8]:
		_boite(Vector3(CHENAL.size.x - 6.0, 1.2, 1.4), Vector3(CHENAL.position.x + (CHENAL.size.x - 6.0) * 0.5, 0.1, cote), briques, port)


func _construire_magasins() -> void:
	var village := Node3D.new()
	village.name = "Magasins"
	_contenu.add_child(village)
	# Les magasins du port : longs bâtiments à toit-terrasse, le long de la terrasse.
	var places := [
		[Vector2(-38, -14), Vector3(14, 3.2, 6), 0.0], [Vector2(-52, -26), Vector3(6, 3.0, 12), 0.0],
		[Vector2(-44, -44), Vector3(10, 3.4, 7), PI], [Vector2(-56, -50), Vector3(6, 2.8, 8), PI / 2],
		[Vector2(-30, -78), Vector3(12, 3.0, 6), 0.0], [Vector2(-46, -92), Vector3(8, 3.2, 6), PI],
		[Vector2(-22, -8), Vector3(7, 2.6, 5), 0.0],
	]
	for p in places:
		_maison(village, p[0], p[1], p[2])
	# L'auvent d'Ânkhkhaf, avec sa table de scribe, ses jarres et ses rouleaux.
	_auvent(village, ANKHKHAF + Vector2(-1, 0), Vector2(5, 4), 2.7)
	var bois := _mat_choix(["rough_wood"], Color(0.5, 0.4, 0.3), 0.9, 1.0)
	_boite(Vector3(1.6, 0.06, 0.8), Vector3(ANKHKHAF.x - 2.0, QUAI + 0.75, ANKHKHAF.y - 0.8), bois, village)
	for k in 4:
		var pied := MeshInstance3D.new()
		pied.mesh = _cylindre(0.03, 0.03, 0.72, 5)
		pied.material_override = bois
		pied.position = Vector3(ANKHKHAF.x - 2.7 + (k % 2) * 1.4, QUAI + 0.36, ANKHKHAF.y - 1.1 + (k / 2) * 0.6)
		village.add_child(pied)
	for k in 3:
		var rouleau := MeshInstance3D.new()
		rouleau.mesh = _cylindre(0.035, 0.035, 0.32, 8)
		rouleau.material_override = _mat_lin(Color(0.86, 0.8, 0.62))
		rouleau.rotation.z = PI / 2
		rouleau.position = Vector3(ANKHKHAF.x - 2.3 + k * 0.3, QUAI + 0.82, ANKHKHAF.y - 0.7)
		village.add_child(rouleau)
	# Jarres de grain et de bière, alignées contre les murs.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 90
	for groupe in [Vector2(-31, -20), Vector2(-48, -36), Vector2(-24, -72), Vector2(-16, -12), Vector2(-25, -33)]:
		for k in hasard.randi_range(4, 8):
			var p: Vector2 = groupe + Vector2(hasard.randf_range(-1.8, 1.8), hasard.randf_range(-0.8, 0.8))
			_jarre(village, Vector3(p.x, hauteur(p.x, p.y) - 0.02, p.y), hasard.randf_range(0.8, 1.2), hasard.randf() * TAU)
	# Paniers et poteries de Poly Haven, s'ils sont téléchargés.
	for p in [Vector2(-33, -19), Vector2(-26, -74), Vector2(-15, -14)]:
		for id in ["wicker_basket_01", "ceramic_vase_02", "wicker_basket_02"]:
			var o := _modele(id, Vector3(p.x + hasard.randf_range(-1.5, 1.5), hauteur(p.x, p.y), p.y + hasard.randf_range(-1.0, 1.0)),
					hasard.randf() * TAU, 1.0, village)
			if o == null:
				break
	# Des feux de cuisine entre les magasins (le pain et la bière des équipes).
	_feu(village, Vector2(-34, -24), 0.7)
	_feu(village, Vector2(-38, -84), 0.7)


func _construire_barques() -> void:
	var flotte := Node3D.new()
	flotte.name = "Barques"
	_contenu.add_child(flotte)
	# Les cargos de Merer, amarrés au quai, chargés de blocs de Toura.
	for k in 3:
		_barque(flotte, Vector3(BASSIN.position.x + 4.2, -0.1, -26.0 - k * 12.0), 0.02 * k, 15.0, k != 1)
	# D'autres barques dans le bassin et sur le Nil.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 33
	for k in 5:
		var p := Vector3(hasard.randf_range(10.0, 44.0), -0.1, hasard.randf_range(-56.0, -20.0))
		_barque(flotte, p, hasard.randf() * TAU, hasard.randf_range(6.0, 10.0), hasard.randf() < 0.3)
	for k in 6:
		var z := hasard.randf_range(-140.0, 140.0)
		var p := Vector3(rive_nil(z) + hasard.randf_range(20.0, 160.0), -0.1, z)
		_barque(flotte, p, PI / 2 + hasard.randf_range(-0.3, 0.3), hasard.randf_range(8.0, 16.0), hasard.randf() < 0.5)
	# La barque de l'agent Farouk, retournée par l'hippopotame, la quille en l'air.
	var renversee := _barque(flotte, Vector3(BARQUE_FAROUK.x, 0.15, BARQUE_FAROUK.y), 0.7, 6.0, false, false)
	renversee.rotation.z = PI
	renversee.position.y = 0.55


# --- Végétation --------------------------------------------------------------------------------

func _construire_vegetation() -> void:
	# Le papyrus pousse dans l'eau peu profonde des marais et le long des berges.
	_semer_papyrus(2600, Rect2(-158, -150, 316, 300), func(x: float, z: float) -> bool:
		var h := hauteur(x, z)
		if h > 0.35 or h < -1.1:
			return false
		var p := Vector2(x, z)
		if _distance_piste(p) < 4.0 or p.distance_to(PORTAIL) < 9.0 or p.distance_to(FAILLE) < 6.0 \
				or p.distance_to(FAROUK) < 4.0:
			return false
		for c in CAISSES:
			if p.distance_to(c) < 3.0:
				return false
		# Moins dense dans les champs inondés (au centre) que dans les vrais marais.
		return z > 18.0 or x > rive_nil(z) - 8.0 or randf() < 0.25, graine + 5)
	_semer_lotus(260, Rect2(-150, 10, 300, 140), func(x: float, z: float) -> bool:
		return hauteur(x, z) < -0.15 and Vector2(x, z).distance_to(PORTAIL) > 8.0, graine + 6)
	# Palmiers dattiers : sur la levée, autour des magasins, et en bosquets sur les îlots.
	var points: Array = []
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 7
	for k in 70:
		var x := hasard.randf_range(-150.0, 70.0)
		var z := hasard.randf_range(-140.0, 120.0)
		var h := hauteur(x, z)
		if h < 0.5 or h > 6.0:
			continue
		var p := Vector2(x, z)
		if _dans_rect(BASSIN.grow(4.0), x, z, 0.1) > 0.5 or _distance_piste(p) < 3.0 or p.distance_to(ANKHKHAF) < 7.0:
			continue
		if _distance_segment(p, HALAGE[0], HALAGE[-1]) < 6.0 or p.distance_to(MERER) < 6.0:
			continue
		points.append(p)
	# Une rangée le long de la levée, comme on en plante pour tenir la terre.
	for k in 12:
		var t := float(k) / 11.0
		var i := mini(int(t * (piste.size() - 1)), piste.size() - 2)
		var p: Vector2 = (piste[i] as Vector2).lerp(piste[i + 1], t * (piste.size() - 1) - i)
		var cote := Vector2(4.2 if k % 2 == 0 else -4.2, 0)
		if p.distance_to(PORTAIL) > 10.0:
			points.append(p + cote)
	_planter_palmiers(points, graine + 8)


func _construire_rochers_desert() -> void:
	var dossier := Node3D.new()
	dossier.name = "Rochers"
	_contenu.add_child(dossier)
	_preparer_rochers()
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 12
	# Éboulis au pied de l'escarpement et blocs sur la pente de sable.
	for k in 90:
		var z := hasard.randf_range(-150.0, 150.0)
		var x := hasard.randf_range(-158.0, -96.0)
		if absf(_distance_segment(Vector2(x, z), Vector2(-62, -84), Vector2(-112, -140))) < 9.0:
			continue
		_placer_rocher(dossier, x, z, hasard.randf_range(0.5, 2.6) * (1.8 if hasard.randf() < 0.12 else 1.0))
	for id_k in 18:
		var z := hasard.randf_range(-140.0, 140.0)
		var x := hasard.randf_range(-150.0, -105.0)
		var id: String = ["namaqualand_boulder_02", "namaqualand_boulder_03", "namaqualand_boulder_05"][id_k % 3]
		_modele(id, Vector3(x, hauteur(x, z) - 0.3, z), hasard.randf() * TAU, hasard.randf_range(1.0, 2.2), dossier)


# --- Paysage lointain ----------------------------------------------------------------------

## Un grand plan de terrain coloré (pour prolonger le plateau au-delà de la zone).
func _plan_lointain(centre: Vector3, taille: Vector2, couleur: Color) -> MeshInstance3D:
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	outil.set_color(couleur)
	outil.set_normal(Vector3.UP)
	var d := taille * 0.5
	var coins := [Vector3(-d.x, 0, -d.y), Vector3(d.x, 0, -d.y), Vector3(d.x, 0, d.y), Vector3(-d.x, 0, d.y)]
	for i in [0, 1, 2, 0, 2, 3]:
		outil.add_vertex(coins[i])
	var mi := MeshInstance3D.new()
	mi.mesh = outil.commit()
	mi.material_override = _mat_lointain()
	mi.position = centre
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_contenu.add_child(mi)
	return mi


func _construire_lointain() -> void:
	# Le plateau du désert continue vers l'ouest, et la Grande Pyramide s'y dresse.
	var haut_plateau := hauteur(-159.0, -100.0)
	_plan_lointain(Vector3(-860, haut_plateau - 0.3, 0), Vector2(1400, 3200), Color(0, 1, 0))
	_construire_pyramide(Vector3(-560, haut_plateau - 1.0, -250), deg_to_rad(8.0))
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 70
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.8
	# Les falaises blanches de Toura, de l'autre côté du Nil (à l'est).
	for k in 9:
		bruit.seed = graine + 200 + k
		var falaise := MeshInstance3D.new()
		falaise.mesh = _maillage_bosse(bruit, Vector3(hasard.randf_range(160, 260), hasard.randf_range(55, 85), 90),
				1.2, 0.25, 28, Color(0, 0.35, 0.65))
		falaise.material_override = _mat_lointain()
		falaise.position = Vector3(1050 + hasard.randf_range(-40, 60), -20, -1100 + k * 260)
		falaise.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(falaise)
	# L'autre rive : une bande de terre basse, avec des palmeraies.
	_plan_lointain(Vector3(1000, 0.4, 0), Vector2(300, 3200), Color(0.6, 0, 0.4))
	# Des îlots de palmiers et de villages qui émergent de la crue, au nord et au sud.
	var ilots: Array = []
	for k in 22:
		var angle := hasard.randf_range(-PI, PI)
		var distance := hasard.randf_range(240.0, 700.0)
		var p := Vector2(cos(angle), sin(angle)) * distance
		if p.x < -170.0:
			continue
		bruit.seed = graine + 400 + k
		var ilot := MeshInstance3D.new()
		var r := hasard.randf_range(14.0, 40.0)
		ilot.mesh = _maillage_bosse(bruit, Vector3(r, 2.0, r * hasard.randf_range(0.6, 1.0)), 1.5, 0.3, 16, Color(0.7, 0, 0.3))
		ilot.material_override = _mat_lointain()
		ilot.position = Vector3(p.x, -0.9, p.y)
		ilot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(ilot)
		for j in hasard.randi_range(3, 9):
			ilots.append([p + Vector2(hasard.randf_range(-r, r), hasard.randf_range(-r, r)) * 0.6, r])
	# Les palmiers des îlots (on les pose au-dessus de l'eau, sans le relief du terrain).
	var hasard_p := RandomNumberGenerator.new()
	hasard_p.seed = graine + 71
	var variantes: Array[ArrayMesh] = []
	for k in 3:
		variantes.append(_maillage_palmier(hasard_p, hasard_p.randf_range(8.0, 12.0)))
	for i in ilots:
		var mi := MeshInstance3D.new()
		mi.mesh = variantes[hasard_p.randi() % variantes.size()]
		mi.position = Vector3(i[0].x, 0.6, i[0].y)
		mi.rotation.y = hasard_p.randf() * TAU
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(mi)


# --- Limites de la zone -----------------------------------------------------------------------

func _construire_limites() -> void:
	var limites := Node3D.new()
	limites.name = "Limites"
	_contenu.add_child(limites)
	# Le Nil : on ne s'aventure pas là où l'on n'a plus pied (barrière le long de la rive).
	var pas := 6.0
	var z := -160.0
	while z < 160.0:
		var x1 := rive_nil(z) + 7.0
		var x2 := rive_nil(z + pas) + 7.0
		# On laisse passer le chenal (fermé plus loin, au bord du fleuve).
		var centre := Vector3((x1 + x2) * 0.5, 0.0, z + pas * 0.5)
		_mur_invisible(limites, Vector3(1.0, 12.0, pas + 1.0), centre, atan2(x2 - x1, pas))
		z += pas
	# Le bassin et le chenal sont profonds : un muret invisible au bord des quais
	# empêche d'y tomber, sauf par l'escalier.
	_mur_invisible(limites, Vector3(1.0, 4.0, 30.0), Vector3(BASSIN.position.x + 0.2, QUAI + 1.5, -47.0))
	_mur_invisible(limites, Vector3(BASSIN.size.x, 4.0, 1.0), Vector3(BASSIN.get_center().x, QUAI + 1.5, BASSIN.position.y + 0.2))
	# Bords de la zone.
	var demi := taille_terrain * 0.5 - 4.0
	_mur_invisible(limites, Vector3(2, 120, taille_terrain), Vector3(-demi, 40, 0))
	_mur_invisible(limites, Vector3(taille_terrain, 120, 2), Vector3(0, 40, -demi))
	_mur_invisible(limites, Vector3(taille_terrain, 120, 2), Vector3(0, 40, demi))
	# Le haut de la rampe : le Village des Bâtisseurs n'est pas encore ouvert.
	_mur_invisible(limites, Vector3(16, 12, 1.5), Vector3(RAMPE.x - 6.0, hauteur(RAMPE.x, RAMPE.y) + 4.0, RAMPE.y - 6.0), deg_to_rad(-45.0))


# --- Personnages et objets de la quête ----------------------------------------------------------

func _construire_quete() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quete"
	_contenu.add_child(dossier)
	_construire_portail(dossier, PORTAIL, 0.0)
	var pnj := func(id: String, p: Vector2, angle: float) -> Node3D:
		var n := Pnj.new()
		n.name = id.capitalize().replace(" ", "")
		n.identifiant = id
		n.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
		n.rotation.y = angle
		dossier.add_child(n)
		return n
	pnj.call("farouk", FAROUK, 2.4)
	pnj.call("merer", MERER, -1.4)
	pnj.call("ankhkhaf", ANKHKHAF, -1.2)
	for k in BATELIERS.size():
		pnj.call("batelier_%d" % (k + 1), BATELIERS[k], -1.6 + k * 0.4)
	# Le matériel de la Vigie qui flotte dans les roseaux (dont la balise).
	for k in CAISSES.size():
		var c := ObjetEgypte.new()
		c.name = "Caisse%d" % k
		c.identifiant = "caisse_farouk_%d" % k
		c.groupe = "materiel_farouk"
		c.forme = "caisse_flottante"
		c.invite = "[F] Repêcher le matériel de la Vigie"
		c.portee = 3.2
		c.position = Vector3(CAISSES[k].x, NIVEAU_MER, CAISSES[k].y)
		dossier.add_child(c)
	var balise := ObjetEgypte.new()
	balise.name = "PointBalise"
	balise.identifiant = "installer_balise"
	balise.forme = "balise"
	balise.invite = "[F] Installer la balise de la Vigie"
	balise.position = Vector3(BALISE.x, hauteur(BALISE.x, BALISE.y), BALISE.y)
	dossier.add_child(balise)
	# La balise une fois montée : un trépied de roseau et un fanal cyan (caché jusque-là).
	var installee := Node3D.new()
	installee.name = "BaliseInstallee"
	installee.set_meta("identifiant", "balise_installee")
	installee.add_to_group("decor_quete")
	installee.visible = false
	installee.position = balise.position
	dossier.add_child(installee)
	var bois := _mat_bois()
	for k in 3:
		var pied := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.03
		cyl.bottom_radius = 0.045
		cyl.height = 2.3
		pied.mesh = cyl
		pied.material_override = bois
		var a := TAU * k / 3.0
		pied.position = Vector3(cos(a) * 0.32, 1.1, sin(a) * 0.32)
		pied.rotation = Vector3(sin(a) * 0.14, 0.0, -cos(a) * 0.14)
		installee.add_child(pied)
	var fanal := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.14
	sphere.height = 0.28
	fanal.mesh = sphere
	var lueur := StandardMaterial3D.new()
	lueur.albedo_color = Color(0.4, 0.95, 1.0)
	lueur.emission_enabled = true
	lueur.emission = Color(0.3, 0.9, 1.0)
	lueur.emission_energy_multiplier = 3.0
	fanal.material_override = lueur
	fanal.position.y = 2.3
	installee.add_child(fanal)
	var lampe := OmniLight3D.new()
	lampe.light_color = Color(0.4, 0.9, 1.0)
	lampe.light_energy = 1.4
	lampe.omni_range = 7.0
	lampe.position.y = 2.3
	installee.add_child(lampe)
	var faille := Faille.new()
	faille.name = "Faille"
	faille.identifiant = "faille_marais"
	faille.position = Vector3(FAILLE.x, maxf(hauteur(FAILLE.x, FAILLE.y), NIVEAU_MER), FAILLE.y)
	dossier.add_child(faille)
	# Le bloc sur son traîneau, prêt à être halé.
	var traineau := Traineau.new()
	traineau.name = "Traineau"
	traineau.set_meta("identifiant", "traineau_quai")
	traineau.add_to_group("decor_quete")
	traineau.position = Vector3(TRAINEAU.x, hauteur(TRAINEAU.x, TRAINEAU.y), TRAINEAU.y)
	traineau.rotation.y = atan2(-(HALAGE[1] - HALAGE[0]).x, -(HALAGE[1] - HALAGE[0]).y)
	traineau.materiau_bloc = _mat_calcaire()
	traineau.materiau_bois = _mat_bois()
	dossier.add_child(traineau)
	# Repères de la carte.
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.PORTAIL, "Portail de la Vigie", PORTAIL)
	repere.call(MarqueurCarte.Type.DANGER, "Faille", FAILLE)
	repere.call(MarqueurCarte.Type.LIEU, "Port de Gizeh", Vector2(BASSIN.get_center().x, BASSIN.get_center().y))
	repere.call(MarqueurCarte.Type.LIEU, "Rampe du plateau", RAMPE)
	repere.call(MarqueurCarte.Type.LIEU, "Levée de terre", Vector2(-25, 32))
	repere.call(MarqueurCarte.Type.DANGER, "Crocodiles", Vector2(-12, 70))
	repere.call(MarqueurCarte.Type.DANGER, "Crocodiles", Vector2(rive_nil(30.0) - 6.0, 30))
