@tool
extends "res://scripts/monde/grece/ile_grece.gd"
## Île de Grèce, zone 6 : l'Acropole (donjon à 5 joueurs, niveau 30).
##
## On entre par l'escalier secret taillé dans le pied ouest du rocher (un vrai passage
## de l'époque des rois, oublié des Athéniens). Il monte jusqu'à une grotte où coule une
## vieille fontaine, gardée par des statues que la fracture a réveillées. Une fissure
## remonte ensuite jusqu'au plateau, la nuit : les blocs du chantier, les torches, le
## Parthénon tout neuf. Dans la salle du temple se dresse l'Athéna Parthénos de Phidias,
## douze mètres d'or et d'ivoire. La fracture majeure s'est logée dans la tête de
## Gorgone de son bouclier : Méduse, la Gorgone de l'égide.
##
## Comme dans la pyramide d'Égypte, pas de relief : chaque salle est une boîte (sol, murs,
## plafond, sauf le plateau, à ciel ouvert) et hauteur() lit le sol de la salle où l'on est.
## On entre au nord (-Z) ; le Parthénon est au sud (+Z), 24 m plus haut.

const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const ObjetGrece := preload("res://scripts/monde/grece/objet_grece.gd")
const Faille := preload("res://scripts/monde/prehistoire/faille.gd")

## Le bas de l'escalier secret (on revient à Athènes en redescendant).
const ENTREE := Vector2(0, -94)
## Les salles : [nom, Rect2 (x, z), sol au début (z min), sol au bout (z max), hauteur sous plafond].
const ESPACES := [
	["escalier", Rect2(-1.6, -96, 3.2, 30), 0.0, 12.0, 3.2],
	["grotte", Rect2(-14, -66, 28, 24), 12.0, 12.0, 9.0],
	["fissure", Rect2(-1.6, -42, 3.2, 22), 12.0, 24.0, 3.6],
	["plateau", Rect2(-40, -20, 80, 104), 24.0, 24.0, 40.0],
]
const H_PLATEAU := 24.0
const GROTTE := Vector2(0, -54)
const FONTAINE := Vector2(-8, -60)
## Le Parthénon : le soubassement (stylobate), la rampe d'accès au nord, la salle (cella).
const STYLOBATE := Rect2(-14, 30, 28, 50)
const RAMPE := Rect2(-5, 26, 10, 4)
const H_TEMPLE := H_PLATEAU + 1.2
const CELLA := Rect2(-9, 38, 18, 36)
const STATUE := Vector2(0, 69)
const BOUCLIER := Vector2(4.6, 66.5)
const MEDUSE := Vector2(3.2, 63.5)
const FAILLE_MEDUSE := Vector2(-4.5, 67)
const BOUCLIERS_POLIS := [Vector2(-7.4, 47), Vector2(7.4, 47)]
const PHIDIAS := Vector2(-6, 20)
const HERODOTE := Vector2(-3, 44)

## Le combat contre Méduse (décidé par le serveur).
const INTERVALLE_REGARD := 15.0
const PREAVIS_REGARD := 2.6
const DUREE_PETRIFICATION := 4.0
const DUREE_RENVOI := 8.0
const RECHARGE_BOUCLIER := 12.0
const DUREE_MASQUE := 45.0

var _boss: Node3D
var _phase := 0
var _prochain_regard := 0.0
var _regard_a := 0.0
var _fenetre_fin := 0.0
var _bouclier_pret := {}
var _masque_arrive := false
var _masque_fin := 0.0
var _masque_parti := false
var _lampe_joueur: OmniLight3D
var _lumieres_torches: Array[OmniLight3D] = []
var _attente_sortie := 0.0


func _init() -> void:
	identifiant_zone = "acropole"
	taille_terrain = 240
	graine = 4385
	point_apparition = ENTREE + Vector2(0, 3)
	nombre_touffes = 0
	neige_qui_tombe = false
	ambiance_grandiose = false
	ciel = ""


func _ready() -> void:
	# Un donjon : pas de monture à l'intérieur (voir le script des montures).
	add_to_group("donjon")
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_grece", "") != "":
		Reseau.remove_meta("arrivee_grece")
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	return ENTREE if zone != "acropole" else Vector2.INF


# --- Le sol -------------------------------------------------------------------------------------

func _sol_espace(e: Array, z: float) -> float:
	var r: Rect2 = e[1]
	var t := clampf((z - r.position.y) / r.size.y, 0.0, 1.0)
	return lerpf(float(e[2]), float(e[3]), t)


func hauteur(x: float, z: float) -> float:
	var p := Vector2(x, z)
	if STYLOBATE.has_point(p):
		return H_TEMPLE
	if RAMPE.has_point(p):
		return H_PLATEAU + 1.2 * (z - RAMPE.position.y) / RAMPE.size.y
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


# --- Construction --------------------------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_lumieres_torches.clear()
	_construire_salles()
	_construire_grotte()
	_construire_plateau()
	_construire_parthenon()
	_construire_quete()
	_construire_limites()
	_eclairer()


func _dossier(nom: String) -> Node3D:
	var d := Node3D.new()
	d.name = nom
	_contenu.add_child(d)
	return d


func _roche() -> StandardMaterial3D:
	return _mat_choix(["rock_wall_10", "cliff_side", "rock_boulder_dry"], Color(0.62, 0.6, 0.56), 0.95, 2.5)


func _pente(e: Array) -> Array:
	var r: Rect2 = e[1]
	var dy := float(e[3]) - float(e[2])
	var angle := -atan2(dy, r.size.y)
	return [angle, Vector3(0, cos(angle), sin(angle)), sqrt(r.size.y * r.size.y + dy * dy)]


func _au_dessus(e: Array, x: float, decalage: float) -> Vector3:
	var r: Rect2 = e[1]
	var normale: Vector3 = _pente(e)[1]
	return Vector3(x, (float(e[2]) + float(e[3])) * 0.5, r.get_center().y) + normale * decalage


func _dalle(parent: Node3D, e: Array, decalage: float, epaisseur: float, materiau: Material, collision := true,
		marge := 0.0) -> MeshInstance3D:
	var r: Rect2 = e[1]
	var pente := _pente(e)
	var centre := _au_dessus(e, r.get_center().x, decalage + (epaisseur * 0.5 if decalage > 0.0 else -epaisseur * 0.5))
	var dalle := _boite(Vector3(r.size.x + marge * 2.0, epaisseur, float(pente[2]) + 0.4), centre, materiau, parent, collision)
	dalle.rotation.x = pente[0]
	return dalle


func _pan(parent: Node3D, e: Array, a: Vector2, b: Vector2, bas: float, haut: float, materiau: Material) -> void:
	var r: Rect2 = e[1]
	var plat := float(e[2]) == float(e[3])
	if absf(a.x - b.x) < 0.01:
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


## Les ouvertures d'un bord de salle vers ses voisines : [début, fin, hauteur].
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


func _point_bord(long: bool, fixe: float, t: float) -> Vector2:
	return Vector2(fixe, t) if long else Vector2(t, fixe)


## Les salles de roche : sol, plafond et murs, avec un passage vers chaque voisine.
## Le plateau est à ciel ouvert : son bord est un parapet de rocher.
func _construire_salles() -> void:
	var d := _dossier("Salles")
	var mat := _roche()
	var dallage := _mat_choix(["stacked_stone_wall", "rock_wall_10"], Color(0.7, 0.68, 0.64), 0.9, 3.0)
	for i in ESPACES.size():
		var e: Array = ESPACES[i]
		var r: Rect2 = e[1]
		var plateau := String(e[0]) == "plateau"
		var h := 1.4 if plateau else float(e[4])
		var g := Node3D.new()
		g.name = String(e[0]).capitalize().replace(" ", "")
		d.add_child(g)
		_dalle(g, e, 0.0, 1.0, dallage if plateau else mat)
		if not plateau:
			_dalle(g, e, h, 1.0, mat, false, 1.0)
		for bord: String in ["x-", "x+", "z-", "z+"]:
			var long := bord.begins_with("x")
			var debut := r.position.y if long else r.position.x
			var fin := r.end.y if long else r.end.x
			var fixe := (r.position.x if bord == "x-" else r.end.x) if long else (r.position.y if bord == "z-" else r.end.y)
			var curseur := debut
			for o in _ouvertures(i, bord):
				if o[0] > curseur + 0.05:
					_pan(g, e, _point_bord(long, fixe, curseur), _point_bord(long, fixe, o[0]), -0.5, h + 0.5, mat)
				if float(o[2]) < h - 0.05:
					_pan(g, e, _point_bord(long, fixe, o[0]), _point_bord(long, fixe, o[1]), float(o[2]), h + 0.5, mat)
				curseur = o[1]
			if fin > curseur + 0.05:
				_pan(g, e, _point_bord(long, fixe, curseur), _point_bord(long, fixe, fin), -0.5, h + 0.5, mat)
	# Des marches taillées dans l'escalier et dans la fissure (sans collision : la pente suffit).
	for i in [0, 2]:
		var e: Array = ESPACES[i]
		var r: Rect2 = e[1]
		var n := int(r.size.y / 0.6)
		for k in n:
			var z := r.position.y + (k + 0.5) * r.size.y / n
			_boite(Vector3(r.size.x, 0.12, 0.25), Vector3(0, _sol_espace(e, z) + 0.04, z), mat, d, false)


## La grotte de la fontaine : un bassin d'eau noire, des stalactites, des torches.
func _construire_grotte() -> void:
	var d := _dossier("Grotte")
	var roche := _roche()
	var y := _sol_espace(ESPACES[1], GROTTE.y)
	# Le bassin de la vieille fontaine (au temps des rois, on venait y puiser en cas de siège).
	for c in [[Vector3(6.4, 0.6, 0.5), Vector3(0, 0.3, -2.6)], [Vector3(6.4, 0.6, 0.5), Vector3(0, 0.3, 2.6)],
			[Vector3(0.5, 0.6, 5.7), Vector3(-3.0, 0.3, 0)], [Vector3(0.5, 0.6, 5.7), Vector3(3.0, 0.3, 0)]]:
		_boite(c[0], Vector3(FONTAINE.x, y, FONTAINE.y) + c[1], _mat_pierre(), d)
	var eau := _boite(Vector3(5.4, 0.05, 4.7), Vector3(FONTAINE.x, y + 0.42, FONTAINE.y), _mat_eau(), d, false)
	eau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 3
	var r: Rect2 = ESPACES[1][1]
	for k in 26:
		var x := hasard.randf_range(r.position.x + 1.0, r.end.x - 1.0)
		var z := hasard.randf_range(r.position.y + 1.0, r.end.y - 1.0)
		var long := hasard.randf_range(0.6, 2.4)
		var stalactite := MeshInstance3D.new()
		stalactite.mesh = _cylindre(hasard.randf_range(0.15, 0.4), 0.02, long, 7)
		stalactite.material_override = roche
		stalactite.position = Vector3(x, y + float(ESPACES[1][4]) - long * 0.5, z)
		d.add_child(stalactite)
	for p: Vector2 in [Vector2(-13.4, -60), Vector2(13.4, -48), Vector2(13.4, -62), Vector2(-13.4, -46)]:
		_torche(d, Vector3(p.x, y + 2.4, p.y))
	for p: Vector2 in [Vector2(1.4, -80), Vector2(-1.4, -70), Vector2(1.4, -32), Vector2(-1.4, -24)]:
		var e: Array = ESPACES[0] if p.y < -66 else ESPACES[2]
		_torche(d, Vector3(p.x, _sol_espace(e, p.y) + 2.0, p.y))


func _mat_eau() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.02, 0.04, 0.06, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.02
	m.metallic_specular = 1.0
	return m


## Une torche fixée à la paroi : une flamme et une lumière qui vacille.
func _torche(parent: Node3D, p: Vector3) -> void:
	var manche := MeshInstance3D.new()
	manche.mesh = _cylindre(0.04, 0.05, 0.6, 6)
	manche.material_override = _mat_bois()
	manche.position = p + Vector3(0, -0.3, 0)
	parent.add_child(manche)
	var flamme := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.09
	s.height = 0.26
	flamme.mesh = s
	flamme.material_override = _lumineux(Color(1.0, 0.58, 0.22), 6.0)
	flamme.position = p
	parent.add_child(flamme)
	var lumiere := OmniLight3D.new()
	lumiere.light_color = Color(1.0, 0.6, 0.32)
	lumiere.light_energy = 1.8
	lumiere.omni_range = 11.0
	lumiere.omni_attenuation = 1.3
	lumiere.position = p + Vector3(0, 0.3, 0)
	lumiere.shadow_enabled = _lumieres_torches.size() % 3 == 0
	parent.add_child(lumiere)
	_lumieres_torches.append(lumiere)


## Le plateau la nuit : les blocs du chantier des Propylées, la grande Athéna de bronze,
## des braseros, et au loin le vide (Athènes dort en bas).
func _construire_plateau() -> void:
	var d := _dossier("Plateau")
	var marbre := _mat_marbre()
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 5
	# Les blocs et tambours de colonnes du chantier, couchés sur le plateau.
	for k in 14:
		var x := hasard.randf_range(-36.0, 36.0)
		var z := hasard.randf_range(-14.0, 24.0)
		if absf(x) < 8.0:
			continue
		if k % 2 == 0:
			var tambour := MeshInstance3D.new()
			tambour.mesh = _cylindre(0.85, 0.85, 1.2, 18)
			tambour.material_override = marbre
			tambour.rotation.z = PI / 2
			tambour.rotation.y = hasard.randf() * PI
			tambour.position = Vector3(x, H_PLATEAU + 0.85, z)
			d.add_child(tambour)
		else:
			_boite(Vector3(hasard.randf_range(1.5, 2.6), 1.0, hasard.randf_range(1.0, 1.6)), Vector3(x, H_PLATEAU + 0.5, z), marbre, d)
	# L'Athéna Promachos, la grande statue de bronze qui regarde la mer.
	var bronze := _mat_bronze()
	var socle := Vector3(-22, H_PLATEAU, 8)
	_boite(Vector3(3.0, 2.4, 3.0), socle + Vector3(0, 1.2, 0), marbre, d)
	var corps := MeshInstance3D.new()
	corps.mesh = _cylindre(0.6, 1.1, 6.0, 14)
	corps.material_override = bronze
	corps.position = socle + Vector3(0, 5.4, 0)
	d.add_child(corps)
	var tete := MeshInstance3D.new()
	tete.mesh = SphereMesh.new()
	(tete.mesh as SphereMesh).radius = 0.5
	(tete.mesh as SphereMesh).height = 1.1
	tete.material_override = bronze
	tete.position = socle + Vector3(0, 8.9, 0)
	d.add_child(tete)
	var lance := MeshInstance3D.new()
	lance.mesh = _cylindre(0.06, 0.06, 10.0, 6)
	lance.material_override = bronze
	lance.position = socle + Vector3(1.0, 6.5, 0)
	d.add_child(lance)
	# Les braseros du chemin vers le temple.
	for p: Vector2 in [Vector2(-5, -6), Vector2(5, -6), Vector2(-5, 10), Vector2(5, 10), Vector2(-7, 24), Vector2(7, 24)]:
		var vasque := MeshInstance3D.new()
		vasque.mesh = _cylindre(0.45, 0.15, 0.4, 12)
		vasque.material_override = bronze
		vasque.position = Vector3(p.x, H_PLATEAU + 1.1, p.y)
		d.add_child(vasque)
		var pied := MeshInstance3D.new()
		pied.mesh = _cylindre(0.06, 0.12, 0.9, 6)
		pied.material_override = bronze
		pied.position = Vector3(p.x, H_PLATEAU + 0.45, p.y)
		d.add_child(pied)
		_torche(d, Vector3(p.x, H_PLATEAU + 1.45, p.y))


func _mat_bronze() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	# Peu de métal : sans ciel à refléter (la nuit), un métal pur paraîtrait noir.
	m.albedo_color = Color(0.5, 0.38, 0.22)
	m.metallic = 0.45
	m.roughness = 0.42
	return m


func _mat_or() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.72, 0.3)
	m.metallic = 0.5
	m.roughness = 0.3
	m.emission_enabled = true
	m.emission = Color(0.5, 0.32, 0.08)
	m.emission_energy_multiplier = 0.25
	return m


## Le Parthénon : soubassement, colonnade dorique, la salle (cella) et ses deux rangs de
## colonnes intérieures, le toit, et l'Athéna Parthénos de Phidias au fond.
func _construire_parthenon() -> void:
	var d := _dossier("Parthenon")
	var marbre := _mat_marbre()
	var s := STYLOBATE
	# Le soubassement et la rampe d'accès.
	_boite(Vector3(s.size.x, 1.2, s.size.y), Vector3(s.get_center().x, H_PLATEAU + 0.6, s.get_center().y), marbre, d)
	var rampe := _boite(Vector3(RAMPE.size.x, 0.4, sqrt(RAMPE.size.y * RAMPE.size.y + 1.44) + 0.2),
			Vector3(RAMPE.get_center().x, H_PLATEAU + 0.6 - 0.2, RAMPE.get_center().y), marbre, d)
	rampe.rotation.x = -atan2(1.2, RAMPE.size.y)
	# La colonnade : 8 colonnes en façade, 17 sur les côtés (on en met un peu moins).
	var colonnes := Node3D.new()
	colonnes.name = "Colonnes"
	d.add_child(colonnes)
	var haut_col := 10.4
	for k in 8:
		for z in [s.position.y + 1.2, s.end.y - 1.2]:
			_colonne_temple(colonnes, Vector3(s.position.x + 1.4 + k * (s.size.x - 2.8) / 7.0, H_TEMPLE, z), haut_col, marbre)
	for k in range(1, 12):
		for x in [s.position.x + 1.4, s.end.x - 1.4]:
			_colonne_temple(colonnes, Vector3(x, H_TEMPLE, s.position.y + 1.2 + k * (s.size.y - 2.4) / 12.0), haut_col, marbre)
	# L'entablement et le toit, au-dessus de tout le temple.
	_boite(Vector3(s.size.x, 1.6, s.size.y), Vector3(s.get_center().x, H_TEMPLE + haut_col + 0.8, s.get_center().y), marbre, d, false)
	var tuiles := _mat_peint(Color(0.5, 0.45, 0.4), 0.8)
	for cote: float in [-1.0, 1.0]:
		var pan := _boite(Vector3(s.size.x * 0.56, 0.4, s.size.y + 0.6),
				Vector3(cote * s.size.x * 0.25, H_TEMPLE + haut_col + 2.4, s.get_center().y), tuiles, d, false)
		pan.rotation.z = -cote * 0.24
	# La frise peinte (bleu et rouge) au-dessus des colonnes, sur la façade.
	for k in 14:
		_boite(Vector3(1.6, 1.0, 0.1), Vector3(s.position.x + 1.4 + k * 1.95, H_TEMPLE + haut_col + 0.5, s.position.y - 0.05),
				_mat_peint(Color(0.18, 0.28, 0.55) if k % 2 == 0 else Color(0.55, 0.16, 0.12), 0.7), d, false)
	# La cella : quatre murs (porte au nord), le sol de marbre et les colonnes intérieures.
	var c := CELLA
	var h := 10.4
	_boite(Vector3(c.size.x + 1.0, h, 1.0), Vector3(c.get_center().x, H_TEMPLE + h * 0.5, c.end.y + 0.5), marbre, d)
	for cote: float in [-1.0, 1.0]:
		_boite(Vector3(1.0, h, c.size.y + 1.0), Vector3(cote * (c.size.x * 0.5 + 0.5), H_TEMPLE + h * 0.5, c.get_center().y), marbre, d)
		# La façade nord, de part et d'autre de la grande porte.
		_boite(Vector3(c.size.x * 0.5 - 2.5, h, 1.0), Vector3(cote * (c.size.x * 0.25 + 1.25), H_TEMPLE + h * 0.5, c.position.y - 0.5), marbre, d)
	_boite(Vector3(5.0, h - 7.0, 1.0), Vector3(0, H_TEMPLE + 7.0 + (h - 7.0) * 0.5, c.position.y - 0.5), marbre, d)
	_boite(Vector3(c.size.x + 1.0, 0.6, c.size.y + 1.0), Vector3(c.get_center().x, H_TEMPLE + h + 0.3, c.get_center().y), _mat_peint(Color(0.12, 0.1, 0.09), 0.9), d, false)
	for k in 7:
		for x in [-6.0, 6.0]:
			_colonne_temple(colonnes, Vector3(x, H_TEMPLE, c.position.y + 4.0 + k * 4.0), 7.6, marbre, 0.42)
	# Le bassin d'eau devant la statue (il gardait l'ivoire humide), et quelques lampes.
	_boite(Vector3(6.0, 0.1, 5.0), Vector3(0, H_TEMPLE + 0.05, 58.5), _mat_eau(), d, false)
	for p: Vector2 in [Vector2(-8.3, 42), Vector2(8.3, 42), Vector2(-8.3, 56), Vector2(8.3, 56), Vector2(-8.3, 70), Vector2(8.3, 70)]:
		_torche(d, Vector3(p.x, H_TEMPLE + 2.6, p.y))
	_construire_athena(d)


func _colonne_temple(parent: Node3D, base: Vector3, haut: float, materiau: Material, rayon := 0.85) -> void:
	var fut := MeshInstance3D.new()
	fut.mesh = _cylindre(rayon * 0.8, rayon, haut, 16)
	fut.material_override = materiau
	fut.position = base + Vector3(0, haut * 0.5, 0)
	parent.add_child(fut)
	_boite(Vector3(rayon * 2.4, 0.4, rayon * 2.4), base + Vector3(0, haut - 0.2, 0), materiau, parent, false)
	# La colonne arrête les joueurs (et cache du regard de Méduse).
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = rayon
	cyl.height = haut
	forme.shape = cyl
	corps.add_child(forme)
	corps.position = base + Vector3(0, haut * 0.5, 0)
	parent.add_child(corps)


## L'Athéna Parthénos : douze mètres d'or et d'ivoire. Une robe d'or, le visage et les bras
## d'ivoire, le casque à triple cimier, la Victoire dans la main droite, et le grand
## bouclier posé à sa gauche, avec la tête de Gorgone au centre.
func _construire_athena(d: Node3D) -> void:
	var or_m := _mat_or()
	var ivoire := _mat_peint(Color(0.93, 0.88, 0.76), 0.35)
	var base := Vector3(STATUE.x, H_TEMPLE, STATUE.y)
	_boite(Vector3(5.0, 1.4, 3.4), base + Vector3(0, 0.7, 0), _mat_marbre(), d)
	var robe := MeshInstance3D.new()
	robe.mesh = _cylindre(1.15, 1.6, 6.2, 18)
	robe.material_override = or_m
	robe.position = base + Vector3(0, 1.4 + 3.1, 0)
	d.add_child(robe)
	var buste := MeshInstance3D.new()
	buste.mesh = _cylindre(0.9, 1.0, 2.2, 16)
	buste.material_override = or_m
	buste.position = base + Vector3(0, 1.4 + 6.2 + 1.1, 0)
	d.add_child(buste)
	var tete := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 1.4
	tete.mesh = sphere
	tete.material_override = ivoire
	tete.position = base + Vector3(0, 10.5, 0)
	d.add_child(tete)
	var casque := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 0.68
	dome.height = 0.9
	casque.mesh = dome
	casque.material_override = or_m
	casque.position = base + Vector3(0, 11.0, 0.05)
	d.add_child(casque)
	for x in [-0.35, 0.0, 0.35]:
		_boite(Vector3(0.08, 0.7, 1.2), base + Vector3(x, 11.6, 0.1), or_m, d, false)
	# Le bras droit tendu, et la petite Victoire (Niké) dans la main.
	var bras := _boite(Vector3(2.4, 0.4, 0.4), base + Vector3(-1.9, 8.2, -0.6), ivoire, d, false)
	bras.rotation.y = 0.3
	var nike := MeshInstance3D.new()
	nike.mesh = _cylindre(0.15, 0.35, 1.6, 10)
	nike.material_override = or_m
	nike.position = base + Vector3(-3.0, 9.2, -0.9)
	d.add_child(nike)
	var lance := MeshInstance3D.new()
	lance.mesh = _cylindre(0.08, 0.08, 11.0, 6)
	lance.material_override = or_m
	lance.position = base + Vector3(2.2, 6.9, 0.4)
	d.add_child(lance)
	# Le bouclier, debout contre sa jambe gauche, face à la salle.
	var bouclier := Node3D.new()
	bouclier.name = "BouclierAthena"
	bouclier.position = Vector3(BOUCLIER.x, H_TEMPLE + 1.4 + 2.2, BOUCLIER.y)
	d.add_child(bouclier)
	var disque := MeshInstance3D.new()
	disque.mesh = _cylindre(2.2, 2.2, 0.25, 32)
	disque.material_override = or_m
	disque.rotation.x = PI / 2
	bouclier.add_child(disque)
	var gorgoneion := MeshInstance3D.new()
	var visage := SphereMesh.new()
	visage.radius = 0.55
	visage.height = 0.6
	gorgoneion.mesh = visage
	gorgoneion.material_override = _lumineux(Color(0.6, 0.32, 1.0), 2.4)
	gorgoneion.position = Vector3(0, 0, -0.2)
	bouclier.add_child(gorgoneion)
	# Deux grandes lampes à huile au pied de la déesse, pour faire briller l'or.
	for cote: float in [-1.0, 1.0]:
		var lampe := OmniLight3D.new()
		lampe.light_color = Color(1.0, 0.72, 0.42)
		lampe.light_energy = 2.2
		lampe.omni_range = 14.0
		lampe.position = base + Vector3(cote * 4.0, 3.0, -4.0)
		d.add_child(lampe)
	var lueur := OmniLight3D.new()
	lueur.light_color = Color(0.62, 0.36, 1.0)
	lueur.light_energy = 2.4
	lueur.omni_range = 12.0
	lueur.position = Vector3(0, 0, -1.2)
	bouclier.add_child(lueur)


func _construire_limites() -> void:
	var limites := _dossier("Limites")
	var demi := taille_terrain * 0.5 - 2.0
	_mur_invisible(limites, Vector3(2, 160, taille_terrain), Vector3(-demi, 20, 0))
	_mur_invisible(limites, Vector3(2, 160, taille_terrain), Vector3(demi, 20, 0))
	_mur_invisible(limites, Vector3(taille_terrain, 160, 2), Vector3(0, 20, -demi))
	_mur_invisible(limites, Vector3(taille_terrain, 160, 2), Vector3(0, 20, demi))
	# Le bord du plateau : on ne saute pas dans le vide.
	var r: Rect2 = ESPACES[3][1]
	_mur_invisible(limites, Vector3(1, 30, r.size.y), Vector3(r.position.x - 0.5, H_PLATEAU + 10, r.get_center().y))
	_mur_invisible(limites, Vector3(1, 30, r.size.y), Vector3(r.end.x + 0.5, H_PLATEAU + 10, r.get_center().y))
	_mur_invisible(limites, Vector3(r.size.x, 30, 1), Vector3(r.get_center().x, H_PLATEAU + 10, r.end.y + 0.5))


# --- La quête ------------------------------------------------------------------------------------

func _construire_quete() -> void:
	var dossier := _dossier("Quete")
	_dossier_quete = dossier
	noms_liberes = []
	places_liberes = []
	_pnj(dossier, "phidias_acropole", PHIDIAS, PI * 0.9)
	var herodote := _pnj(dossier, "herodote_acropole", HERODOTE, PI)
	herodote.add_to_group("decor_quete")
	herodote.set_meta("identifiant", "herodote_acropole")
	herodote.visible = false
	# Les portes de bronze de la cella, fermées jusqu'à ce qu'on les force.
	var portes := Node3D.new()
	portes.name = "PortesParthenon"
	portes.set_meta("identifiant", "portes_parthenon")
	portes.add_to_group("decor_quete")
	portes.position = Vector3(0, H_TEMPLE, CELLA.position.y - 0.5)
	dossier.add_child(portes)
	var bronze := _mat_bronze()
	for cote: float in [-1.0, 1.0]:
		_boite(Vector3(2.45, 7.0, 0.3), Vector3(cote * 1.25, 3.5, 0), bronze, portes, false)
		for k in 4:
			_boite(Vector3(0.12, 0.12, 0.1), Vector3(cote * 1.25, 1.2 + k * 1.6, -0.2), _mat_or(), portes, false)
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(5.0, 7.0, 0.6)
	forme.shape = boite
	forme.position.y = 3.5
	corps.add_child(forme)
	portes.add_child(corps)
	portes.visibility_changed.connect(func(): forme.set_deferred("disabled", not portes.visible))
	var porte := ObjetGrece.new()
	porte.name = "PorteParthenon"
	porte.identifiant = "porte_parthenon"
	porte.invite = "[F] Pousser les portes de bronze"
	porte.portee = 2.6
	porte.position = Vector3(0, H_TEMPLE, CELLA.position.y - 2.0)
	dossier.add_child(porte)
	# Les deux boucliers de bronze poli (des offrandes) : on renvoie à Méduse son regard.
	for k in BOUCLIERS_POLIS.size():
		var p: Vector2 = BOUCLIERS_POLIS[k]
		var b := ObjetGrece.new()
		b.name = "BouclierPoli%d" % k
		b.identifiant = "bouclier_poli_%d" % k
		b.forme = "bouclier_poli"
		b.invite = "[F] Lever le bouclier poli vers Méduse"
		b.portee = 2.2
		b.set_meta("donjon", true)
		b.position = Vector3(p.x, H_TEMPLE, p.y)
		dossier.add_child(b)
	# La faille derrière la statue (la fracture majeure, à refermer après le combat).
	var faille := Faille.new()
	faille.name = "FractureMeduse"
	faille.identifiant = "fracture_meduse"
	faille.position = Vector3(FAILLE_MEDUSE.x, H_TEMPLE + 0.5, FAILLE_MEDUSE.y)
	dossier.add_child(faille)
	# Repères de la carte.
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.LIEU, "Escalier secret (vers Athènes)", ENTREE)
	repere.call(MarqueurCarte.Type.DANGER, "Grotte de la fontaine", GROTTE)
	repere.call(MarqueurCarte.Type.LIEU, "Plateau de l'Acropole", Vector2(0, 0))
	repere.call(MarqueurCarte.Type.DANGER, "Parthénon", Vector2(0, 56))


## La nuit : une lune froide, le ciel noir, les torches et la lueur violette du bouclier.
func _eclairer() -> void:
	var soleil := get_node_or_null("Soleil") as DirectionalLight3D
	if soleil != null:
		soleil.light_color = Color(0.62, 0.7, 0.95)
		soleil.light_energy = 0.32
		soleil.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(150.0), 0)
		soleil.shadow_enabled = true
	var environnement := get_node_or_null("Environnement") as WorldEnvironment
	if environnement == null or environnement.environment == null:
		return
	var env := environnement.environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.018, 0.04)
	env.sky = null
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.36, 0.55)
	env.ambient_light_energy = 0.42
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.2
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.03, 0.04, 0.08)
	env.fog_density = 0.012
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = false


# --- Chaque image -------------------------------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	if Engine.is_editor_hint():
		return
	for k in _lumieres_torches.size():
		var l := _lumieres_torches[k]
		if is_instance_valid(l):
			l.light_energy = 1.8 + sin(_temps * 8.0 + k * 1.3) * 0.2 + sin(_temps * 19.0 + k) * 0.1
	_porter_la_lampe()
	if multiplayer.is_server():
		_diriger_meduse()
	_attente_sortie -= delta
	if _attente_sortie > 0.0:
		return
	_attente_sortie = 0.3
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	var quete := get_tree().get_first_node_in_group("quete")
	if joueur == null or quete == null or not quete.has_method("changer_de_zone"):
		return
	if joueur.global_position.z < ENTREE.y - 1.2:
		quete.changer_de_zone("athenes")


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
	_lampe_joueur.light_energy = 1.6
	_lampe_joueur.omni_range = 11.0
	_lampe_joueur.shadow_enabled = true
	_lampe_joueur.position = Vector3(0.35, 2.1, 0.3)
	joueur.add_child(_lampe_joueur)


# --- Méduse, la Gorgone de l'égide -------------------------------------------------------------

func _trouver_boss() -> Node3D:
	if _boss != null and is_instance_valid(_boss):
		return _boss
	_boss = null
	for bete in get_tree().get_nodes_in_group("loups"):
		if String(bete.get("type_ennemi")).begins_with("meduse"):
			_boss = bete
	return _boss


func _trouver_masque() -> Node3D:
	for bete in get_tree().get_nodes_in_group("loups"):
		if String(bete.get("type_ennemi")) == "masque_acropole" and bete.combat.est_vivant():
			return bete
	return null


func joueurs_dans_la_cella() -> Array:
	var liste: Array = []
	for j in get_tree().get_nodes_in_group("joueur"):
		var c = j.get_node_or_null("Combat")
		if c != null and c.est_vivant() and CELLA.grow(1.0).has_point(Vector2(j.global_position.x, j.global_position.z)):
			liste.append(j)
	return liste


## Un joueur regarde-t-il Méduse ? (Il lui fait face, à moins de 60° de chaque côté.)
func regarde_meduse(j: Node3D, boss: Node3D) -> bool:
	var vers := boss.global_position - j.global_position
	vers.y = 0.0
	if vers.length() < 0.1:
		return true
	var avant := -j.global_transform.basis.z
	avant.y = 0.0
	return avant.normalized().dot(vers.normalized()) > 0.5


## Le serveur fait vivre le combat : le regard qui pétrifie (phase 1 et suivantes), l'égide
## (phase 2 : seul un bouclier poli lui renvoie son regard), puis Masque (phase 3).
func _diriger_meduse() -> void:
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
	if int(boss.get("etat")) != 1 or joueurs_dans_la_cella().is_empty():
		if _phase != 0 and combat.pv >= combat.pv_max * 0.99:
			_finir_combat(false)
		return
	var part: float = combat.pv / combat.pv_max
	var phase := 1 if part > 0.66 else (2 if part > 0.33 else 3)
	if phase != _phase:
		_entrer_phase(phase, t)
	# Le regard : ses yeux s'allument, puis ceux qui la regardent sont changés en pierre.
	if _regard_a <= 0.0 and t >= _prochain_regard and t >= _fenetre_fin:
		_regard_a = t + PREAVIS_REGARD
		_annoncer_regard.rpc(boss.get_path())
	elif _regard_a > 0.0 and t >= _regard_a:
		_regard_a = 0.0
		_prochain_regard = t + INTERVALLE_REGARD
		for j in joueurs_dans_la_cella():
			if regarde_meduse(j, boss):
				petrifier(j)
		_eteindre_regard.rpc(boss.get_path())
	# L'égide la protège (phase 2) sauf quand un bouclier poli lui renvoie son regard ;
	# en phase 3, tant que Masque est là, elle est protégée aussi.
	var protegee := false
	if _phase == 2 and t >= _fenetre_fin:
		protegee = true
	if _phase == 3:
		var masque := _trouver_masque()
		if masque != null and not _masque_parti:
			protegee = true
			if masque.combat.pv < masque.combat.pv_max * 0.3:
				_masque_s_enfuit(masque, true)
			elif t >= _masque_fin:
				_masque_s_enfuit(masque, false)
				combat.soigner(combat.pv_max * 0.15)
	if protegee:
		combat.ajouter_effet("evite", 1.0)
	elif combat.effets.has("evite") and _phase >= 2:
		combat.retirer_effet("evite")


## Pétrifié par le regard : on ne bouge plus et on ne frappe plus pendant quelques secondes.
func petrifier(j: Node3D) -> void:
	var c = j.get_node_or_null("Combat")
	if c == null:
		return
	c.ajouter_effet("regard_gorgone", DUREE_PETRIFICATION, {"vitesse": 0.0, "degats_infliges": 0.0})
	_petrifie.rpc(j.get_path())


func _entrer_phase(phase: int, t: float) -> void:
	_phase = phase
	if phase == 1:
		_prochain_regard = t + 6.0
	elif phase == 2:
		_boucliers_actifs.rpc(true)
	elif phase == 3 and not _masque_arrive:
		_masque_arrive = true
		_masque_fin = t + DUREE_MASQUE
		var quete := get_tree().get_first_node_in_group("quete")
		if quete != null and quete.has_method("_faire_apparaitre"):
			quete._faire_apparaitre({"type": "masque_acropole", "position": [FAILLE_MEDUSE.x, FAILLE_MEDUSE.y - 2.0],
					"nombre": 1, "rayon": 0.01, "attaque": true}, true)
		_annonce.rpc("Masque !", "Chassé d'Athènes, il surgit de la faille pour emporter la tête de la Gorgone. Tant qu'il est là, elle est protégée !")


func _masque_s_enfuit(masque: Node3D, battu: bool) -> void:
	_masque_parti = true
	masque.queue_free()
	if battu:
		_annonce.rpc("Masque s'enfuit", "Blessé, il plonge dans la faille sans la tête de la Gorgone. Elle n'est plus protégée : achevez-la !")
	else:
		_annonce.rpc("Masque s'enfuit", "Il disparaît dans la faille... et la Gorgone a repris des forces.")


func _finir_combat(victoire: bool) -> void:
	_phase = 0
	_boucliers_actifs.rpc(false)
	_regard_a = 0.0
	_fenetre_fin = 0.0
	if not victoire:
		_masque_arrive = false
		_masque_parti = false
		var masque := _trouver_masque()
		if masque != null:
			masque.queue_free()


## Appelé par un bouclier poli (F) : on lève le bronze vers Méduse.
func utiliser_objet(objet: Node3D) -> void:
	Regles.au_serveur(self, "_lever_bouclier", [String(objet.name)])


@rpc("any_peer", "call_remote", "reliable")
func _lever_bouclier(nom: String) -> void:
	if not multiplayer.is_server():
		return
	var t := Regles.maintenant()
	if t < float(_bouclier_pret.get(nom, 0.0)):
		return
	var boss := _trouver_boss()
	if boss == null or not boss.combat.est_vivant() or _phase < 2:
		return
	_bouclier_pret[nom] = t + RECHARGE_BOUCLIER
	_fenetre_fin = t + DUREE_RENVOI
	boss.combat.retirer_effet("evite")
	boss.combat.ajouter_effet("regard_renvoye", DUREE_RENVOI, {"degats_infliges": 0.0})
	_annonce.rpc("Son propre regard !", "Le bronze poli lui renvoie son regard : Méduse est pétrifiée un instant. Frappez tous !")


@rpc("authority", "call_local", "reliable")
func _annonce(titre: String, texte: String) -> void:
	var quete := get_tree().get_first_node_in_group("quete")
	if quete != null:
		quete.annoncer(titre, texte)


@rpc("authority", "call_local", "reliable")
func _annoncer_regard(chemin: NodePath) -> void:
	var boss := get_node_or_null(chemin)
	var app = boss.get_node_or_null("Apparence") if boss != null else null
	var delegue = app.get("_delegue") if app != null else null
	if delegue != null and delegue.has_method("regard"):
		delegue.regard(true)
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur != null and CELLA.grow(1.0).has_point(Vector2(joueur.global_position.x, joueur.global_position.z)):
		var quete := get_tree().get_first_node_in_group("quete")
		if quete != null:
			quete.annoncer("Ses yeux s'allument", "Tourne-lui le dos, vite !")


@rpc("authority", "call_local", "reliable")
func _eteindre_regard(chemin: NodePath) -> void:
	var boss := get_node_or_null(chemin)
	var app = boss.get_node_or_null("Apparence") if boss != null else null
	var delegue = app.get("_delegue") if app != null else null
	if delegue != null and delegue.has_method("regard"):
		delegue.regard(false)


@rpc("authority", "call_local", "reliable")
func _petrifie(chemin: NodePath) -> void:
	var j := get_node_or_null(chemin)
	if j == null or not j.is_in_group("joueur_local"):
		return
	var quete := get_tree().get_first_node_in_group("quete")
	if quete != null:
		quete.annoncer("Pétrifié !", "Tu as croisé son regard : tu ne peux plus bouger ni frapper pendant quelques secondes.")


## Les boucliers polis ne servent (F) qu'à partir de la phase 2, quand l'égide se referme.
@rpc("authority", "call_local", "reliable")
func _boucliers_actifs(actifs: bool) -> void:
	for k in BOUCLIERS_POLIS.size():
		var o = _dossier_quete.get_node_or_null("BouclierPoli%d" % k) if _dossier_quete != null else null
		if o != null:
			o.actif = actifs
