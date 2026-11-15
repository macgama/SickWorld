@tool
extends "res://scripts/monde/egypte/ile_egypte.gd"
## Île d'Égypte, zone 5 : le Cœur de la Pyramide (donjon à 5 joueurs, niveau 20).
##
## L'intérieur de la Grande Pyramide, d'après le vrai plan (agrandi pour qu'un groupe
## puisse s'y battre) : le vestibule du passage des ouvriers, le couloir descendant, la
## chambre souterraine jamais finie (taillée dans la roche), le couloir ascendant, le
## carrefour, le passage et la chambre « de la Reine », la Grande Galerie et sa voûte en
## encorbellement, l'antichambre aux trois herses de granit, puis la chambre du Roi, toute
## en granit rouge d'Assouan, avec le sarcophage vide. La fracture majeure s'y est logée :
## Isfet, le Serpent du Désordre, sort de ses murs.
##
## Ici, pas de relief : chaque salle est une boîte de pierre (sol, murs, plafond) et
## hauteur() lit le sol de la salle où l'on est. Pas de soleil : des lampes à huile,
## la lampe du joueur, et la lueur violette de la faille.
## Repères : on entre au nord (-Z) ; la chambre du Roi est au sud (+Z), 18 m plus haut.

const Faille := preload("res://scripts/monde/prehistoire/faille.gd")
const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")

## Le passage des ouvriers (retour vers le chantier de Gizeh).
const ENTREE := Vector2(0, -110)
## Les salles : [nom, Rect2 (x, z), sol au début (z min), sol au bout (z max), hauteur sous plafond, pierre].
const ESPACES := [
	["vestibule", Rect2(-6, -114, 12, 16), 0.0, 0.0, 6.0, "calcaire"],
	["descendant", Rect2(-2.2, -98, 4.4, 40), 0.0, -12.0, 4.4, "calcaire"],
	["souterraine", Rect2(-15, -58, 30, 22), -12.0, -12.0, 7.5, "roche"],
	["ascendant", Rect2(-2.2, -36, 4.4, 30), -12.0, 0.0, 4.4, "calcaire"],
	["carrefour", Rect2(-4, -6, 8, 8), 0.0, 0.0, 5.0, "calcaire"],
	["passage_reine", Rect2(4, -4, 22, 4), 0.0, 0.0, 3.8, "calcaire"],
	["reine", Rect2(26, -9, 16, 14), 0.0, 0.0, 8.0, "calcaire"],
	["galerie", Rect2(-3.5, 2, 7, 52), 0.0, 18.0, 12.0, "calcaire"],
	["palier", Rect2(-3.5, 54, 7, 4), 18.0, 18.0, 6.0, "calcaire"],
	["antichambre", Rect2(-2.5, 58, 5, 6), 18.0, 18.0, 5.0, "granit"],
	["roi", Rect2(-18, 64, 36, 24), 18.0, 18.0, 13.0, "granit"],
]
const SOUTERRAINE := Vector2(0, -47)
const REINE := Vector2(34, -2)
const GALERIE := Vector2(0, 28)
const ANTICHAMBRE := Vector2(0, 61)
const ROI := Vector2(0, 76)
const H_ROI := 18.0
## Le bouchon de granit qui ferme le bas de la Grande Galerie.
const BOUCHON := Vector2(0, 3.5)
## Les trois herses de l'antichambre (z).
const HERSES := [59.2, 61.0, 62.8]
## Les bouches d'où Isfet sort des murs : position (à 3,5 m du mur) et direction du regard.
const BOUCHES := [
	[Vector2(-14.5, 68), -PI / 2], [Vector2(-14.5, 84), -PI / 2],
	[Vector2(14.5, 70), PI / 2], [Vector2(14.5, 82), PI / 2],
]
## Les cartouches gravés où l'on rend leur nom aux alliés (phase 2).
const CARTOUCHES := [Vector2(-11, 64.45), Vector2(11, 64.45), Vector2(-11, 87.55), Vector2(11, 87.55)]
## Le balcon d'où Vera Lind regarde la chambre se remplir de sable.
const BALCON := Vector3(0, H_ROI + 7.0, 86.6)
const SARCOPHAGE := Vector2(-13, 76)

# --- Le combat contre Isfet (le serveur décide, tout le monde voit) ---
## Durée du sablier de la phase 3 (secondes).
const DUREE_SABLE := 75.0
var _boss: Node3D
var _phase := 0
var _prochaine_plongee := 0.0
var _plongee_fin := 0.0
var _prochain_eboulement := 0.0
var _prochain_effacement := 0.0
var _fin_sable := 0.0
var _sable: MeshInstance3D
var _sable_depart := 0.0
var _sable_fin := 0.0
var _cartouches: Array[Node3D] = []
var _cartouche_pret := {}
var _herses: Array[Node3D] = []
var _herses_levees := {}
var _lampe_joueur: OmniLight3D
var _lumieres_lampes: Array[OmniLight3D] = []
var _vera_balcon: Node3D
var _mat_granit: StandardMaterial3D


func _init() -> void:
	identifiant_zone = "coeur_pyramide"
	taille_terrain = 240
	graine = 2564
	point_apparition = ENTREE + Vector2(0, 4)
	nombre_touffes = 0
	neige_qui_tombe = false
	ambiance_grandiose = false
	ciel = ""


func _ready() -> void:
	# Un donjon : pas de monture à l'intérieur (voir le script des montures).
	add_to_group("donjon")
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	return ENTREE if zone != "coeur_pyramide" else Vector2.INF


# --- Le sol des salles -------------------------------------------------------------------------

func _sol_espace(e: Array, z: float) -> float:
	var r: Rect2 = e[1]
	var t := clampf((z - r.position.y) / r.size.y, 0.0, 1.0)
	return lerpf(float(e[2]), float(e[3]), t)


## Le sol de la salle où l'on se trouve (ou de la plus proche).
func hauteur(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var meilleur := -INF
	var plus_proche := INF
	var repli := 0.0
	for e in ESPACES:
		var r: Rect2 = e[1]
		if r.grow(0.05).has_point(p):
			meilleur = maxf(meilleur, _sol_espace(e, z))
		else:
			var d := Vector2(clampf(x, r.position.x, r.end.x), clampf(z, r.position.y, r.end.y)).distance_to(p)
			if d < plus_proche:
				plus_proche = d
				repli = _sol_espace(e, z)
	return meilleur if meilleur > -INF else repli


## Isfet sort du mur le plus proche : son corps reste perpendiculaire à la pierre.
func lacet_mur(p: Vector3) -> float:
	var meilleur := 0.0
	var d := INF
	for b in BOUCHES:
		var ecart := (b[0] as Vector2).distance_to(Vector2(p.x, p.z))
		if ecart < d:
			d = ecart
			meilleur = b[1]
	return meilleur


# --- Construction --------------------------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_feux.clear()
	_cartouches.clear()
	_herses.clear()
	_lumieres_lampes.clear()
	_mat_granit = null
	_construire_salles()
	_construire_galerie()
	_construire_souterraine()
	_construire_reine()
	_construire_roi()
	_construire_lampes()
	_construire_quete()
	_construire_limites()
	_eclairer()


func _dossier(nom: String) -> Node3D:
	var d := Node3D.new()
	d.name = nom
	_contenu.add_child(d)
	return d


func _pierre(nom: String) -> Material:
	match nom:
		"granit":
			return _granit()
		"roche":
			return _mat_choix(["quarry_wall", "sandstone_cracks", "cliff_side"], Color(0.82, 0.74, 0.62), 0.95, 3.0)
	return _mat_choix(["white_sandstone_blocks_02", "large_sandstone_blocks", "cliff_side"], Color(0.9, 0.86, 0.76), 0.85, 2.2)


## Le granit rose d'Assouan : des grains roses, gris et noirs, poli par les bâtisseurs.
func _granit() -> StandardMaterial3D:
	if _mat_granit != null:
		return _mat_granit
	var bruit := FastNoiseLite.new()
	bruit.noise_type = FastNoiseLite.TYPE_CELLULAR
	bruit.frequency = 0.08
	bruit.cellular_jitter = 1.0
	var degrade := Gradient.new()
	degrade.offsets = PackedFloat32Array([0.0, 0.35, 0.55, 0.8, 1.0])
	degrade.colors = PackedColorArray([Color(0.1, 0.08, 0.08), Color(0.52, 0.3, 0.27), Color(0.66, 0.42, 0.38),
			Color(0.58, 0.5, 0.48), Color(0.86, 0.78, 0.74)])
	var tex := NoiseTexture2D.new()
	tex.noise = bruit
	tex.color_ramp = degrade
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	var relief := NoiseTexture2D.new()
	relief.noise = bruit
	relief.seamless = true
	relief.as_normal_map = true
	relief.bump_strength = 1.5
	relief.width = 256
	relief.height = 256
	_mat_granit = StandardMaterial3D.new()
	_mat_granit.albedo_texture = tex
	_mat_granit.normal_enabled = true
	_mat_granit.normal_texture = relief
	_mat_granit.normal_scale = 0.3
	_mat_granit.roughness = 0.42
	_mat_granit.uv1_triplanar = true
	_mat_granit.uv1_scale = Vector3.ONE * 0.9
	return _mat_granit


## Pente d'une salle : angle (autour de X) et normale au sol.
func _pente(e: Array) -> Array:
	var r: Rect2 = e[1]
	var dy := float(e[3]) - float(e[2])
	var angle := -atan2(dy, r.size.y)
	return [angle, Vector3(0, cos(angle), sin(angle)), sqrt(r.size.y * r.size.y + dy * dy)]


## Un point au-dessus du sol de la salle, au milieu de sa longueur (mesuré perpendiculairement au sol).
func _au_dessus(e: Array, x: float, decalage: float) -> Vector3:
	var r: Rect2 = e[1]
	var normale: Vector3 = _pente(e)[1]
	return Vector3(x, (float(e[2]) + float(e[3])) * 0.5, r.get_center().y) + normale * decalage


## Une dalle (sol ou plafond) qui suit la pente de la salle.
func _dalle(parent: Node3D, e: Array, decalage: float, epaisseur: float, materiau: Material, collision := true,
		marge := 0.0) -> MeshInstance3D:
	var r: Rect2 = e[1]
	var pente := _pente(e)
	var centre := _au_dessus(e, r.get_center().x, decalage + (epaisseur * 0.5 if decalage > 0.0 else -epaisseur * 0.5))
	var dalle := _boite(Vector3(r.size.x + marge * 2.0, epaisseur, float(pente[2]) + 0.4), centre, materiau, parent, collision)
	dalle.rotation.x = pente[0]
	return dalle


## Un pan de mur, de « bas » à « haut » au-dessus du sol, sur une salle qui peut être en pente.
func _pan(parent: Node3D, e: Array, a: Vector2, b: Vector2, bas: float, haut: float, materiau: Material) -> void:
	var r: Rect2 = e[1]
	var plat := float(e[2]) == float(e[3])
	if absf(a.x - b.x) < 0.01:
		# Le long de Z : il suit la pente.
		var z0 := minf(a.y, b.y)
		var z1 := maxf(a.y, b.y)
		var y0 := _sol_espace(e, z0)
		var y1 := _sol_espace(e, z1)
		var longueur := sqrt((z1 - z0) * (z1 - z0) + (y1 - y0) * (y1 - y0))
		var angle := -atan2(y1 - y0, z1 - z0)
		var normale := Vector3(0, cos(angle), sin(angle))
		var x := a.x + (0.5 if a.x >= r.end.x - 0.01 else -0.5)
		var centre := Vector3(x, (y0 + y1) * 0.5, (z0 + z1) * 0.5) + normale * (bas + haut) * 0.5
		var pan := _boite(Vector3(1.0, haut - bas, longueur + (1.0 if plat else 0.0)), centre, materiau, parent)
		pan.rotation.x = angle
	else:
		var x0 := minf(a.x, b.x)
		var x1 := maxf(a.x, b.x)
		var y := _sol_espace(e, a.y)
		var z := a.y + (0.5 if a.y >= r.end.y - 0.01 else -0.5)
		_boite(Vector3(x1 - x0 + 2.0, haut - bas, 1.0), Vector3((x0 + x1) * 0.5, y + (bas + haut) * 0.5, z), materiau, parent)


## Les ouvertures d'un bord de salle vers les salles voisines : [début, fin, hauteur].
func _ouvertures(i: int, bord: String) -> Array:
	var r: Rect2 = ESPACES[i][1]
	var liste: Array = []
	for j in ESPACES.size():
		if j == i:
			continue
		var autre: Rect2 = ESPACES[j][1]
		var h := minf(float(ESPACES[i][4]), float(ESPACES[j][4]))
		match bord:
			"x-":
				if absf(autre.end.x - r.position.x) < 0.1 and autre.position.y < r.end.y and autre.end.y > r.position.y:
					liste.append([maxf(autre.position.y, r.position.y), minf(autre.end.y, r.end.y), h])
			"x+":
				if absf(autre.position.x - r.end.x) < 0.1 and autre.position.y < r.end.y and autre.end.y > r.position.y:
					liste.append([maxf(autre.position.y, r.position.y), minf(autre.end.y, r.end.y), h])
			"z-":
				if absf(autre.end.y - r.position.y) < 0.1 and autre.position.x < r.end.x and autre.end.x > r.position.x:
					liste.append([maxf(autre.position.x, r.position.x), minf(autre.end.x, r.end.x), h])
			"z+":
				if absf(autre.position.y - r.end.y) < 0.1 and autre.position.x < r.end.x and autre.end.x > r.position.x:
					liste.append([maxf(autre.position.x, r.position.x), minf(autre.end.x, r.end.x), h])
	liste.sort_custom(func(p, q): return p[0] < q[0])
	return liste


func _construire_salles() -> void:
	var salles := _dossier("Salles")
	for i in ESPACES.size():
		var e: Array = ESPACES[i]
		var r: Rect2 = e[1]
		var h := float(e[4])
		var d := Node3D.new()
		d.name = String(e[0]).capitalize().replace(" ", "")
		salles.add_child(d)
		var mat := _pierre(e[5])
		# Le sol, un peu plus clair et lisse (les pieds des ouvriers l'ont poli).
		_dalle(d, e, 0.0, 1.0, mat)
		_dalle(d, e, h, 1.0, mat, false, 1.0)
		# Les quatre murs, percés là où une autre salle commence.
		for bord: String in ["x-", "x+", "z-", "z+"]:
			var long := bord.begins_with("x")
			var debut := r.position.y if long else r.position.x
			var fin := r.end.y if long else r.end.x
			var fixe := (r.position.x if bord == "x-" else r.end.x) if long else (r.position.y if bord == "z-" else r.end.y)
			var curseur := debut
			for o in _ouvertures(i, bord):
				if o[0] > curseur + 0.05:
					_pan(d, e, _point_bord(long, fixe, curseur), _point_bord(long, fixe, o[0]), -0.5, h + 0.5, mat)
				# Le linteau au-dessus du passage.
				if float(o[2]) < h - 0.05:
					_pan(d, e, _point_bord(long, fixe, o[0]), _point_bord(long, fixe, o[1]), float(o[2]), h + 0.5, mat)
				curseur = o[1]
			if fin > curseur + 0.05:
				_pan(d, e, _point_bord(long, fixe, curseur), _point_bord(long, fixe, fin), -0.5, h + 0.5, mat)


func _point_bord(long: bool, fixe: float, t: float) -> Vector2:
	return Vector2(fixe, t) if long else Vector2(t, fixe)


## La Grande Galerie : huit assises qui avancent chacune un peu au-dessus du vide
## (l'encorbellement), et deux banquettes le long des murs, percées d'encoches.
func _construire_galerie() -> void:
	var d := _dossier("GrandeGalerie")
	var e: Array = ESPACES[7]
	var r: Rect2 = e[1]
	var mat := _pierre("calcaire")
	var pente := _pente(e)
	var angle: float = pente[0]
	var longueur: float = pente[2]
	for k in 7:
		var avance := 0.24 * (k + 1)
		var y := 4.6 + k * 1.05
		for cote: float in [-1.0, 1.0]:
			var x := cote * (r.size.x * 0.5 - avance * 0.5)
			var assise := _boite(Vector3(avance, 1.05, longueur), _au_dessus(e, x, y + 0.525), mat, d, false)
			assise.rotation.x = angle
	# Les banquettes, de chaque côté de la rampe centrale.
	for cote: float in [-1.0, 1.0]:
		var x := cote * (r.size.x * 0.5 - 0.35)
		var banc := _boite(Vector3(0.7, 0.6, longueur), _au_dessus(e, x, 0.3), mat, d)
		banc.rotation.x = angle
		# Les encoches (pour des poutres de bois, disent les archéologues).
		var sombre := _mat_pbr("", Color(0.2, 0.17, 0.13), 1.0)
		for k in 24:
			var z := r.position.y + 1.5 + k * 2.1
			var trou := _boite(Vector3(0.3, 0.05, 0.4), Vector3(x, _sol_espace(e, z) + 0.61, z), sombre, d, false)
			trou.rotation.x = angle


## La chambre souterraine : jamais finie, taillée en gradins dans la roche, avec un puits.
func _construire_souterraine() -> void:
	var d := _dossier("ChambreSouterraine")
	var roche := _pierre("roche")
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 3
	var y := -12.0
	# Les gradins de roche que les tailleurs n'ont jamais aplanis (côté ouest).
	for k in 6:
		var hauteur_bloc := hasard.randf_range(1.0, 3.2)
		_boite(Vector3(hasard.randf_range(2.5, 4.0), hauteur_bloc, hasard.randf_range(3.0, 5.0)),
				Vector3(-12.5 + hasard.randf_range(-0.6, 0.6), y + hauteur_bloc * 0.5, -54.0 + k * 3.2), roche, d)
	# Le puits carré au milieu : il ne mène nulle part.
	var bord := _mat_pbr("", Color(0.08, 0.07, 0.06), 1.0)
	_boite(Vector3(2.2, 0.06, 2.2), Vector3(5, y + 0.03, -44), bord, d, false)
	for k in 4:
		var a := k * PI / 2
		var muret := _boite(Vector3(2.6, 0.5, 0.25), Vector3(5 + cos(a) * 1.2, y + 0.25, -44 + sin(a) * 1.2), roche, d)
		muret.rotation.y = a + PI / 2
	# Des gravats et des outils abandonnés.
	for k in 14:
		var p := Vector2(hasard.randf_range(-13, 13), hasard.randf_range(-57, -37))
		if p.distance_to(Vector2(0, -47)) < 5.0:
			continue
		var caillou := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = hasard.randf_range(0.15, 0.45)
		s.height = s.radius * 1.3
		caillou.mesh = s
		caillou.material_override = roche
		caillou.position = Vector3(p.x, y + s.radius * 0.4, p.y)
		d.add_child(caillou)


## La chambre « de la Reine » : un toit en double pente et une niche en encorbellement.
func _construire_reine() -> void:
	var d := _dossier("ChambreReine")
	var r: Rect2 = ESPACES[6][1]
	var mat := _pierre("calcaire")
	for cote: float in [-1.0, 1.0]:
		var pan := _boite(Vector3(r.size.x + 1.0, 0.8, r.size.y * 0.62), Vector3(r.get_center().x, 6.6, r.get_center().y + cote * r.size.y * 0.25), mat, d, false)
		pan.rotation.x = cote * 0.42
	# La niche dans le mur est : des assises qui se resserrent.
	for k in 4:
		var largeur := 3.2 - k * 0.55
		_boite(Vector3(0.6, 1.1, (r.size.y - largeur) * 0.5), Vector3(r.end.x - 0.25, 0.55 + k * 1.1, r.position.y + (r.size.y - largeur) * 0.25), mat, d, false)
		_boite(Vector3(0.6, 1.1, (r.size.y - largeur) * 0.5), Vector3(r.end.x - 0.25, 0.55 + k * 1.1, r.end.y - (r.size.y - largeur) * 0.25), mat, d, false)


## La chambre du Roi : granit rouge, sarcophage vide, cartouches et balcon.
func _construire_roi() -> void:
	var d := _dossier("ChambreRoi")
	var granit := _granit()
	# Le sarcophage, sans couvercle, contre le mur ouest.
	var cuve := Node3D.new()
	cuve.name = "Sarcophage"
	cuve.position = Vector3(SARCOPHAGE.x, H_ROI, SARCOPHAGE.y)
	d.add_child(cuve)
	_boite(Vector3(2.3, 0.25, 4.6), Vector3(0, 0.12, 0), granit, cuve)
	for donnees in [[Vector3(0.25, 1.3, 4.6), Vector3(-1.02, 0.9, 0)], [Vector3(0.25, 1.3, 4.6), Vector3(1.02, 0.9, 0)],
			[Vector3(2.3, 1.3, 0.25), Vector3(0, 0.9, -2.18)], [Vector3(2.3, 1.3, 0.25), Vector3(0, 0.9, 2.18)]]:
		_boite(donnees[0], donnees[1], granit, cuve)
	# Les cartouches : un ovale de corde gravé, où l'on écrit un nom pour qu'il dure.
	for k in CARTOUCHES.size():
		var p: Vector2 = CARTOUCHES[k]
		var face := 1.0 if p.y < ROI.y else -1.0
		var c := _cartouche(d, Vector3(p.x, H_ROI + 1.7, p.y), face)
		c.name = "Cartouche%d" % k
		_cartouches.append(c)
		var o := ObjetEgypte.new()
		o.name = "GraverCartouche%d" % k
		o.identifiant = "cartouche_%d" % k
		o.invite = "[F] Graver les noms de tes alliés"
		o.portee = 3.2
		o.set_meta("donjon", true)
		o.position = Vector3(p.x, H_ROI, p.y + face * 1.0)
		d.add_child(o)
		o.actif = false
	# Les bouches des murs : des trous sombres bordés de cristal, d'où sort le serpent.
	var noir := _mat_pbr("", Color(0.02, 0.015, 0.03), 1.0)
	var cristal := _lumineux(Color(0.55, 0.3, 1.0), 2.0)
	for b in BOUCHES:
		var p: Vector2 = b[0]
		var x_mur := -18.0 if p.x < 0.0 else 18.0
		var trou := _boite(Vector3(0.1, 2.8, 2.6), Vector3(x_mur + (0.04 if p.x < 0.0 else -0.04), H_ROI + 1.4, p.y), noir, d, false)
		trou.name = "Bouche"
		var lueur := OmniLight3D.new()
		lueur.light_color = Color(0.6, 0.35, 1.0)
		lueur.light_energy = 1.4
		lueur.omni_range = 9.0
		lueur.position = Vector3(x_mur + (1.0 if p.x < 0.0 else -1.0), H_ROI + 1.6, p.y)
		d.add_child(lueur)
		for k in 6:
			var eclat := MeshInstance3D.new()
			eclat.mesh = _cylindre(0.0, 0.1, 0.7, 5)
			eclat.material_override = cristal
			var a := k * TAU / 6.0
			eclat.position = Vector3(x_mur + (0.2 if p.x < 0.0 else -0.2), H_ROI + 1.4 + sin(a) * 1.5, p.y + cos(a) * 1.4)
			eclat.rotation = Vector3(a, 0, PI / 2 * (1.0 if p.x < 0.0 else -1.0))
			d.add_child(eclat)
	# Le balcon de Vera : une ouverture haute dans le mur sud, avec une rambarde moderne.
	var balcon := Node3D.new()
	balcon.name = "Balcon"
	balcon.position = BALCON
	d.add_child(balcon)
	_boite(Vector3(5.0, 0.3, 2.4), Vector3(0, -0.15, 0.2), granit, balcon)
	var acier := _mat_pbr("", Color(0.3, 0.32, 0.35), 0.4)
	acier.metallic = 0.8
	_boite(Vector3(5.0, 0.06, 0.06), Vector3(0, 1.0, -0.95), acier, balcon, false)
	for k in 5:
		_boite(Vector3(0.05, 1.0, 0.05), Vector3(-2.4 + k * 1.2, 0.5, -0.95), acier, balcon, false)
	# Le sable de Vera : il monte quand le sablier se vide (phase 3).
	_sable = MeshInstance3D.new()
	_sable.name = "SableQuiMonte"
	var plan := BoxMesh.new()
	plan.size = Vector3(36, 0.2, 24)
	_sable.mesh = plan
	_sable.material_override = _mat_choix(["sand_01", "dense_sand", "red_sand"], Color(0.92, 0.78, 0.58), 1.0, 3.0)
	_sable.position = Vector3(0, H_ROI - 0.3, ROI.y)
	_sable.visible = false
	d.add_child(_sable)
	# La fracture majeure, derrière le sarcophage.
	var faille := Faille.new()
	faille.name = "FractureMajeure"
	faille.identifiant = "fracture_isfet"
	faille.position = Vector3(SARCOPHAGE.x - 2.6, H_ROI, SARCOPHAGE.y)
	faille.rotation.y = PI / 2
	faille.scale = Vector3.ONE * 2.4
	d.add_child(faille)
	# Les conduits « stellaires » : deux petits trous carrés qui visent les étoiles.
	for p in [Vector3(-6, H_ROI + 1.1, 63.6), Vector3(6, H_ROI + 1.1, 88.4)]:
		_boite(Vector3(0.22, 0.22, 0.1), p, noir, d, false)


func _cartouche(parent: Node3D, p: Vector3, face: float) -> Node3D:
	var c := Node3D.new()
	c.position = p
	c.rotation.y = 0.0 if face > 0.0 else PI
	parent.add_child(c)
	var ocre := _mat_pbr("", Color(0.62, 0.18, 0.1), 0.8)
	var corde := MeshInstance3D.new()
	var tore := TorusMesh.new()
	tore.inner_radius = 0.55
	tore.outer_radius = 0.66
	corde.mesh = tore
	corde.material_override = ocre
	corde.rotation.x = PI / 2
	corde.scale = Vector3(0.75, 1.0, 1.5)
	c.add_child(corde)
	var noeud := _boite(Vector3(0.7, 0.1, 0.06), Vector3(0, -1.05, 0), ocre, c, false)
	noeud.name = "Noeud"
	# Les signes à l'intérieur : quatre petits glyphes peints (ils brillent quand un nom s'efface).
	var lueur := StandardMaterial3D.new()
	lueur.albedo_color = Color(0.62, 0.18, 0.1)
	lueur.emission_enabled = true
	lueur.emission = Color(0.6, 0.3, 1.0)
	lueur.emission_energy_multiplier = 0.0
	for k in 4:
		var signe := _boite(Vector3(0.28, 0.16, 0.04), Vector3(0, 0.55 - k * 0.36, 0.0), lueur, c, false)
		signe.rotation.z = 0.3 * ((k % 2) * 2 - 1)
	c.set_meta("lueur", lueur)
	return c


## Des lampes à huile en terre cuite, posées le long du chemin par l'équipe d'Ânkhkhaf.
func _construire_lampes() -> void:
	var d := _dossier("Lampes")
	var points := [Vector2(-4.5, -100), Vector2(4.5, -110), Vector2(1.6, -80), Vector2(-1.6, -64),
			Vector2(-10, -40), Vector2(10, -54), Vector2(-9, -56), Vector2(12, -38), Vector2(-3, -46), Vector2(1.6, -24), Vector2(-3, -3), Vector2(14, -2),
			Vector2(38, -7), Vector2(38, 3), Vector2(-2.8, 14), Vector2(2.8, 30), Vector2(-2.8, 46),
			Vector2(2.5, 56), Vector2(-16, 66), Vector2(16, 86), Vector2(-16, 86), Vector2(16, 66)]
	for p in points:
		_lampe(d, Vector3(p.x, hauteur(p.x, p.y), p.y))


func _lampe(parent: Node3D, p: Vector3) -> void:
	var lampe := Node3D.new()
	lampe.position = p
	parent.add_child(lampe)
	var terre := _mat_pbr("", Color(0.55, 0.35, 0.22), 0.9)
	var coupe := MeshInstance3D.new()
	coupe.mesh = _tour([[0.0, 0.05], [0.05, 0.12], [0.09, 0.14], [0.1, 0.12]], 10)
	coupe.material_override = terre
	lampe.add_child(coupe)
	var flamme := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.035
	s.height = 0.12
	flamme.mesh = s
	flamme.material_override = _lumineux(Color(1.0, 0.62, 0.22), 6.0)
	flamme.position = Vector3(0.08, 0.16, 0)
	lampe.add_child(flamme)
	var lumiere := OmniLight3D.new()
	lumiere.light_color = Color(1.0, 0.64, 0.34)
	lumiere.light_energy = 1.6
	lumiere.omni_range = 9.0
	lumiere.omni_attenuation = 1.4
	lumiere.position = Vector3(0, 0.5, 0)
	lumiere.shadow_enabled = _lumieres_lampes.size() % 3 == 0
	lampe.add_child(lumiere)
	_lumieres_lampes.append(lumiere)


func _construire_limites() -> void:
	var limites := _dossier("Limites")
	var demi := taille_terrain * 0.5 - 2.0
	_mur_invisible(limites, Vector3(2, 160, taille_terrain), Vector3(-demi, 20, 0))
	_mur_invisible(limites, Vector3(2, 160, taille_terrain), Vector3(demi, 20, 0))
	_mur_invisible(limites, Vector3(taille_terrain, 160, 2), Vector3(0, 20, -demi))
	_mur_invisible(limites, Vector3(taille_terrain, 160, 2), Vector3(0, 20, demi))


## Un décor de quête (masquer / montrer) qui bloque le passage tant qu'il est visible.
func _bloquant(parent: Node3D, nom: String, id: String, taille: Vector3, centre: Vector3, materiau: Material) -> MeshInstance3D:
	var bloc := _boite(taille, centre, materiau, parent)
	bloc.name = nom
	bloc.set_meta("identifiant", id)
	bloc.add_to_group("decor_quete")
	var corps := bloc.get_child(0) as StaticBody3D
	bloc.visibility_changed.connect(func():
		for f in corps.get_children():
			(f as CollisionShape3D).set_deferred("disabled", not bloc.visible))
	return bloc


func _construire_quete() -> void:
	var dossier := _dossier("Quete")
	_dossier_quete = dossier
	noms_liberes = ["emmure_sekhem", "emmure_tjeti", "emmure_henout"]
	places_liberes = [REINE + Vector2(-4, -3), REINE + Vector2(-4, 0), REINE + Vector2(-4, 3)]
	# Le bouchon de granit au pied de la Grande Galerie, calé par des coins de bois.
	_bloquant(dossier, "BouchonGalerie", "bouchon_galerie", Vector3(6.6, 4.8, 3.0), Vector3(BOUCHON.x, 2.4, BOUCHON.y + 0.3), _granit())
	var coins := _mat_bois()
	for x in [-2.6, 2.6]:
		var coin := _boite(Vector3(0.5, 0.4, 0.6), Vector3(x, 0.2, BOUCHON.y - 1.4), coins, dossier, false)
		coin.set_meta("identifiant", "bouchon_galerie")
		coin.add_to_group("decor_quete")
	_objet(dossier, "RetirerCoins", "coins_bouchon", "", "", "[F] Retirer les coins de bois du bouchon", BOUCHON + Vector2(0, -2.4))
	# Les trois herses de granit de l'antichambre, à lever une par une.
	for k in HERSES.size():
		var z: float = HERSES[k]
		var herse := _boite(Vector3(5.2, 5.0, 0.5), Vector3(0, H_ROI + 2.5, z), _granit(), dossier)
		herse.name = "Herse%d" % k
		_herses.append(herse)
		var o := _objet(dossier, "LeverHerse%d" % k, "herse_%d" % k, "herses", "", "[F] Lever la herse de granit", Vector2(1.2 if k % 2 == 0 else -1.2, z - 1.7))
		o.portee = 1.9
	# Vera Lind, au balcon (cachée jusqu'à la phase du sablier).
	_vera_balcon = Pnj.new()
	_vera_balcon.name = "VeraBalcon"
	_vera_balcon.identifiant = "vera_pyramide"
	_vera_balcon.position = BALCON + Vector3(0, 0, 0.3)
	_vera_balcon.rotation.y = 0.0
	_vera_balcon.visible = false
	dossier.add_child(_vera_balcon)
	# Merer et Ânkhkhaf attendent le groupe au vestibule.
	_pnj(dossier, "ankhkhaf_pyramide", ENTREE + Vector2(-3.5, 6), -0.3)
	# Repères de la carte.
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.LIEU, "Passage des ouvriers (vers le chantier)", ENTREE)
	repere.call(MarqueurCarte.Type.DANGER, "Chambre souterraine", SOUTERRAINE)
	repere.call(MarqueurCarte.Type.LIEU, "Chambre de la Reine", REINE)
	repere.call(MarqueurCarte.Type.LIEU, "Grande Galerie", GALERIE)
	repere.call(MarqueurCarte.Type.LIEU, "Antichambre", ANTICHAMBRE)
	repere.call(MarqueurCarte.Type.DANGER, "Chambre du Roi", ROI)


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


## Dans la pyramide : noir complet, quelques lampes, une poussière dorée dans l'air.
func _eclairer() -> void:
	var soleil := get_node_or_null("Soleil") as DirectionalLight3D
	if soleil != null:
		soleil.visible = false
	var environnement := get_node_or_null("Environnement") as WorldEnvironment
	if environnement == null or environnement.environment == null:
		return
	var env := environnement.environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0)
	env.sky = null
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.36, 0.3)
	env.ambient_light_energy = 0.42
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.15
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.06, 0.045, 0.03)
	env.fog_density = 0.025
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = DisplayServer.get_name() != "headless"
	env.volumetric_fog_density = 0.02
	env.volumetric_fog_albedo = Color(0.9, 0.8, 0.62)
	env.volumetric_fog_length = 40.0


# --- Chaque image -------------------------------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	if Engine.is_editor_hint():
		return
	for k in _lumieres_lampes.size():
		var l := _lumieres_lampes[k]
		if is_instance_valid(l):
			l.light_energy = 1.6 + sin(_temps * 9.0 + k * 1.3) * 0.18 + sin(_temps * 21.0 + k) * 0.1
	_porter_la_lampe()
	_animer_herses(delta)
	_animer_sable()
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur != null and joueur.global_position.z < ENTREE.y - 1.5:
		var quete := get_tree().get_first_node_in_group("quete")
		if quete != null and quete.has_method("changer_de_zone"):
			quete.changer_de_zone("village_batisseurs")
	if multiplayer.is_server():
		_diriger_isfet()


## Chaque agent porte une petite lampe de la Vigie à l'épaule.
func _porter_la_lampe() -> void:
	if _lampe_joueur != null and is_instance_valid(_lampe_joueur):
		return
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return
	_lampe_joueur = OmniLight3D.new()
	_lampe_joueur.name = "LampeVigie"
	_lampe_joueur.light_color = Color(1.0, 0.86, 0.68)
	_lampe_joueur.light_energy = 2.2
	_lampe_joueur.omni_range = 13.0
	_lampe_joueur.shadow_enabled = true
	_lampe_joueur.position = Vector3(0.35, 2.1, 0.3)
	joueur.add_child(_lampe_joueur)


## Une herse levée remonte doucement dans sa rainure et ne bloque plus le passage.
## On les lève dans l'ordre, de la première à la dernière, quel que soit le levier utilisé.
func _animer_herses(delta: float) -> void:
	var quete := get_tree().get_first_node_in_group("quete")
	var levees := 0
	for k in _herses.size():
		var o := _dossier_quete.get_node_or_null("LeverHerse%d" % k) if _dossier_quete != null else null
		if o != null and o.get("ramasse"):
			levees += 1
	if quete != null and quete.etape_atteinte("isfet"):
		levees = _herses.size()
	for k in _herses.size():
		var herse := _herses[k]
		if not is_instance_valid(herse) or k >= levees:
			continue
		if not _herses_levees.get(k, false):
			_herses_levees[k] = true
			var corps := herse.get_child(0) as StaticBody3D
			for f in corps.get_children():
				(f as CollisionShape3D).set_deferred("disabled", true)
		herse.position.y = move_toward(herse.position.y, H_ROI + 2.5 + 4.6, delta * 1.5)


# --- Isfet, le Serpent du Désordre -------------------------------------------------------------

func _trouver_boss() -> Node3D:
	if _boss != null and is_instance_valid(_boss):
		return _boss
	_boss = null
	for bete in get_tree().get_nodes_in_group("loups"):
		if String(bete.get("type_ennemi")).begins_with("isfet"):
			_boss = bete
	return _boss


func _joueurs_dans_la_chambre() -> Array:
	var liste: Array = []
	var chambre: Rect2 = ESPACES[10][1]
	for j in get_tree().get_nodes_in_group("joueur"):
		var c = j.get_node_or_null("Combat")
		if c != null and c.est_vivant() and chambre.grow(1.0).has_point(Vector2(j.global_position.x, j.global_position.z)):
			liste.append(j)
	return liste


## Le serveur fait vivre le combat : plongées dans les murs, éboulements de sable,
## noms effacés, puis le sablier de Vera.
func _diriger_isfet() -> void:
	var boss := _trouver_boss()
	if boss == null:
		if _phase != 0:
			_finir_combat(true)
		return
	var combat = boss.combat
	var t := Regles.maintenant()
	if not combat.est_vivant():
		if _phase != 0:
			_finir_combat(true)
		return
	# En combat tant qu'il poursuit quelqu'un (même hors de portée de ses crocs).
	if int(boss.get("etat")) != 1 or _joueurs_dans_la_chambre().is_empty():
		# Le groupe est tombé (ou parti) : tout recommence.
		if _phase != 0 and combat.pv >= combat.pv_max * 0.99:
			_finir_combat(false)
		return
	var part: float = combat.pv / combat.pv_max
	var phase := 1 if part > 0.66 else (2 if part > 0.33 else 3)
	if phase != _phase:
		_entrer_phase(phase, t)
	# Les plongées : il rentre dans la pierre, et ressort par une autre bouche.
	if _plongee_fin > 0.0 and t >= _plongee_fin:
		_plongee_fin = 0.0
		_changer_de_bouche(boss)
	elif _plongee_fin <= 0.0 and t >= _prochaine_plongee and _phase < 3:
		_plongee_fin = t + 2.2
		_prochaine_plongee = t + (16.0 if _phase == 1 else 24.0)
		combat.ajouter_effet("enfoui", 3.4)
		combat.ajouter_effet("evite", 3.4)
	# Les éboulements : du sable tombe du plafond sur un joueur (cercle au sol, puis coup).
	if t >= _prochain_eboulement:
		_prochain_eboulement = t + (9.0 if _phase < 3 else 6.0)
		var cibles := _joueurs_dans_la_chambre()
		if not cibles.is_empty():
			var j: Node3D = cibles[randi() % cibles.size()]
			_annoncer_eboulement.rpc(j.global_position)
			var ou: Vector3 = j.global_position
			get_tree().create_timer(2.2).timeout.connect(func(): _eboulement(ou))
	# Les noms effacés (à partir de la phase 2).
	if _phase >= 2 and t >= _prochain_effacement:
		_prochain_effacement = t + 17.0
		var cibles := _joueurs_dans_la_chambre()
		if not cibles.is_empty():
			var j: Node3D = cibles[randi() % cibles.size()]
			j.get_node("Combat").ajouter_effet("nom_efface", 40.0)
			_nom_efface.rpc(j.get_path())
	# Le sablier : s'il se vide avant la fin du serpent, le sable engloutit la chambre.
	if _phase == 3 and _fin_sable > 0.0 and t >= _fin_sable:
		_fin_sable = 0.0
		for j in _joueurs_dans_la_chambre():
			Regles.infliger(null, j.get_node("Combat"), 1.0e9, "periodique")


func _entrer_phase(phase: int, t: float) -> void:
	_phase = phase
	if phase == 1:
		_prochaine_plongee = t + 12.0
		_prochain_eboulement = t + 6.0
	elif phase == 2:
		_prochain_effacement = t + 3.0
		_cartouches_actifs.rpc(true)
	elif phase == 3:
		_fin_sable = t + DUREE_SABLE
		_sablier.rpc(true, DUREE_SABLE)


func _changer_de_bouche(boss: Node3D) -> void:
	var ici := Vector2(boss.global_position.x, boss.global_position.z)
	var choix: Array = []
	for b in BOUCHES:
		if (b[0] as Vector2).distance_to(ici) > 2.0:
			choix.append(b)
	var b: Array = choix[randi() % choix.size()]
	var p: Vector2 = b[0]
	var dest := Vector3(p.x, H_ROI + 0.4, p.y)
	boss.global_position = dest
	boss.reset_physics_interpolation()
	boss.camp = dest
	boss.position_reseau = dest
	boss.rotation.y = b[1]


func _finir_combat(victoire: bool) -> void:
	_phase = 0
	_fin_sable = 0.0
	_plongee_fin = 0.0
	_cartouches_actifs.rpc(false)
	_sablier.rpc(false, 0.0)
	for j in get_tree().get_nodes_in_group("joueur"):
		var c = j.get_node_or_null("Combat")
		if c != null:
			c.retirer_effet("nom_efface")
	if victoire:
		_vera_s_enfuit.rpc()


func _eboulement(ou: Vector3) -> void:
	_effet_eboulement.rpc(ou)
	for j in get_tree().get_nodes_in_group("joueur"):
		var c = j.get_node_or_null("Combat")
		if c != null and c.est_vivant() and Vector2(j.global_position.x - ou.x, j.global_position.z - ou.z).length() < 3.5:
			Regles.infliger(_boss.combat if _boss != null and is_instance_valid(_boss) else null, c, randf_range(70.0, 95.0))


## Appelé par un cartouche (F) : on grave les noms, et les alliés retrouvent les leurs.
func utiliser_objet(objet: Node3D) -> void:
	var k := _cartouches.find(objet.get_parent().get_node_or_null(String(objet.name).replace("GraverCartouche", "Cartouche")))
	if k < 0:
		return
	if Regles.maintenant() < float(_cartouche_pret.get(k, 0.0)):
		return
	Regles.au_serveur(self, "_graver_cartouche", [k])


@rpc("any_peer", "call_remote", "reliable")
func _graver_cartouche(k: int) -> void:
	if not multiplayer.is_server() or _phase < 2:
		return
	if Regles.maintenant() < float(_cartouche_pret.get(k, 0.0)):
		return
	var rendus := 0
	for j in get_tree().get_nodes_in_group("joueur"):
		var c = j.get_node_or_null("Combat")
		if c != null and c.effets.has("nom_efface"):
			c.retirer_effet("nom_efface")
			rendus += 1
	_cartouche_grave.rpc(k, rendus)


@rpc("authority", "call_local", "reliable")
func _cartouche_grave(k: int, rendus: int) -> void:
	_cartouche_pret[k] = Regles.maintenant() + 12.0
	if k < _cartouches.size():
		var lueur: StandardMaterial3D = _cartouches[k].get_meta("lueur")
		lueur.emission_energy_multiplier = 3.0
		var anim := create_tween()
		anim.tween_property(lueur, "emission_energy_multiplier", 0.0, 2.0)
	var quete := get_tree().get_first_node_in_group("quete")
	if quete != null and rendus > 0:
		quete.annoncer("Les noms sont rendus", "Gravés dans la pierre, ils ne s'effaceront plus.")


@rpc("authority", "call_local", "reliable")
func _cartouches_actifs(actifs: bool) -> void:
	for k in CARTOUCHES.size():
		var o := _cartouches[k].get_parent().get_node_or_null("GraverCartouche%d" % k) if k < _cartouches.size() else null
		if o != null:
			o.actif = actifs


@rpc("authority", "call_local", "reliable")
func _nom_efface(chemin: NodePath) -> void:
	var j := get_node_or_null(chemin)
	if j == null or not j.is_in_group("joueur_local"):
		return
	var quete := get_tree().get_first_node_in_group("quete")
	if quete != null:
		quete.annoncer("Ton nom s'efface", "Tes compétences d'époque sont bloquées : grave les noms sur un cartouche (F).")


@rpc("authority", "call_local", "reliable")
func _sablier(actif: bool, duree: float) -> void:
	if _sable == null:
		return
	_sable.visible = actif
	_sable_depart = Regles.maintenant()
	_sable_fin = _sable_depart + duree if actif else 0.0
	_sable.position.y = H_ROI - 0.3
	if _vera_balcon != null:
		_vera_balcon.visible = actif
	var quete := get_tree().get_first_node_in_group("quete")
	if actif and quete != null:
		quete.annoncer("Vera Lind, au balcon", "« Dommage. Il était si beau, ce désordre. » Elle retourne son sablier : la chambre se remplit de sable !")


func _animer_sable() -> void:
	if _sable == null or not _sable.visible or _sable_fin <= 0.0:
		return
	var t := clampf((Regles.maintenant() - _sable_depart) / maxf(_sable_fin - _sable_depart, 0.1), 0.0, 1.0)
	_sable.position.y = H_ROI - 0.3 + t * 1.6


@rpc("authority", "call_local", "reliable")
func _vera_s_enfuit() -> void:
	if _vera_balcon == null:
		return
	var etait_la := _vera_balcon.visible
	if _sable != null:
		var anim := create_tween()
		anim.tween_property(_sable, "position:y", H_ROI - 0.4, 3.0)
		anim.tween_callback(func(): _sable.visible = false)
	_sable_fin = 0.0
	if not etait_la:
		return
	var quete := get_tree().get_first_node_in_group("quete")
	if quete != null:
		quete.annoncer("Vera Lind s'enfuit", "« On se reverra, agent. L'Histoire est longue. » Une faille s'ouvre derrière elle, et se referme.")
	get_tree().create_timer(4.0).timeout.connect(func(): _vera_balcon.visible = false)


@rpc("authority", "call_local", "reliable")
func _annoncer_eboulement(ou: Vector3) -> void:
	var cercle := MeshInstance3D.new()
	var disque := CylinderMesh.new()
	disque.top_radius = 3.5
	disque.bottom_radius = 3.5
	disque.height = 0.04
	cercle.mesh = disque
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.3, 0.15, 0.0)
	cercle.material_override = m
	cercle.position = Vector3(ou.x, hauteur(ou.x, ou.z) + 0.05, ou.z)
	_contenu.add_child(cercle)
	var anim := create_tween()
	anim.tween_property(m, "albedo_color:a", 0.45, 2.0)
	anim.tween_callback(cercle.queue_free)


@rpc("authority", "call_local", "reliable")
func _effet_eboulement(ou: Vector3) -> void:
	# Un rideau de sable qui tombe du plafond.
	var colonne := MeshInstance3D.new()
	colonne.mesh = _cylindre(1.6, 3.4, 12.0, 16)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.86, 0.72, 0.52, 0.75)
	m.roughness = 1.0
	colonne.material_override = m
	colonne.position = Vector3(ou.x, hauteur(ou.x, ou.z) + 6.0, ou.z)
	_contenu.add_child(colonne)
	var anim := create_tween()
	anim.tween_property(m, "albedo_color:a", 0.0, 1.2)
	anim.tween_callback(colonne.queue_free)
