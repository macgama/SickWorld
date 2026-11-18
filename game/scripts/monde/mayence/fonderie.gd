@tool
extends "res://scripts/monde/mayence/ile_mayence.gd"
## Île de Mayence : la fonderie sous la cathédrale (donjon à 5 joueurs, niveaux 69-70, chapitre 8).
##
## On descend par l'escalier de la crypte de Saint-Martin, sur le flanc sud de la cathédrale.
## D'abord les caves du chapitre : une longue galerie voûtée pleine de tonneaux, où des moules
## brisés, réveillés par la fracture, crachent du plomb fondu par les fissures de la voûte. On
## les bouche avec du sable (F), ou on passe entre les coulées. Puis la salle des casses : des
## casses de lettres grandes comme des maisons, gardées par des hommes de lettres de plomb, et
## Hans le fondeur, Scellé. Plus bas, la fonderie infinie : un lac de plomb, des montagnes de
## caractères, et le Typographe de plomb, un géant fait de millions de lettres.
##
## Le combat (le serveur décide ; chacun voit l'état reçu par _etat_crypte) :
## - phase 1, la pluie de caractères : des cercles rouges s'allument au sol sous les joueurs ;
##   une seconde et demie plus tard, des lettres brûlantes tombent dedans ;
## - phase 2, les lignes de plomb : de longues lignes de caractères tombent de la voûte et
##   barrent la salle par bandes, deux jeux tour à tour ;
## - phase 3, l'encre noire : tout le monde devient « las » (dégâts divisés par deux), sauf
##   près des quatre lanternes de la fonderie, qu'il faut rallumer (F) ; elles s'éteignent au
##   bout d'un moment. Sceau descend se battre à côté du Typographe.
##
## Comme à la crypte de Chartres : pas de relief, chaque salle est une boîte, et hauteur() lit
## le sol de la salle où l'on est. On entre au nord (-Z) ; le Typographe est au sud.

const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const ObjetMayence := preload("res://scripts/monde/mayence/objet_mayence.gd")
const Faille := preload("res://scripts/monde/prehistoire/faille.gd")

const ENTREE := Vector2(0, -98)
const SOL := -10.0
const SOL_LAC := -14.0
## Les salles : [nom, Rect2 (x, z), sol au début (z min), sol au bout (z max), hauteur sous plafond].
const ESPACES := [
	["escalier", Rect2(-2, -102, 4, 22), 0.0, -10.0, 4.0],
	["galerie", Rect2(-6, -80, 12, 40), -10.0, -10.0, 7.0],
	["puits", Rect2(-18, -40, 36, 28), -10.0, -10.0, 9.0],
	["descente", Rect2(-3, -12, 6, 14), -10.0, -14.0, 6.0],
	["lac", Rect2(-32, 2, 64, 58), -14.0, -14.0, 16.0],
]
const GALERIE := Rect2(-6, -80, 12, 40)
## Les quatre gouttières de plomb de la galerie (F pour les boucher de sable).
const GOUTTIERES := [Vector2(-5.3, -72), Vector2(5.3, -64), Vector2(-5.3, -56), Vector2(5.3, -48)]
const INTERVALLE_COULEE := 3.2
const PREAVIS_COULEE := 1.5
const LARGEUR_COULEE := 3.0
## La salle du puits des Saints-Forts.
const SALLE_PUITS := Rect2(-18, -40, 36, 28)
const PUITS := Vector2(0, -26)
const INSCRIPTION := Vector2(17.0, -31.0)
## La fonderie et le Typographe.
const LAC := Rect2(-32, 2, 64, 58)
const COEUR := Vector2(0, 46)
const BRASIER := Vector2(0, 53)
const PILIERS := [Vector2(-14, 14), Vector2(14, 14), Vector2(-20, 30), Vector2(20, 30), Vector2(-14, 40), Vector2(14, 40)]
const ARRIVEES_RENFORTS := [Vector2(-26, 8), Vector2(26, 8), Vector2(-26, 50), Vector2(26, 50)]
const VITRAUX := [Vector2(-31.2, 18), Vector2(31.2, 18), Vector2(-31.2, 38), Vector2(31.2, 38)]
## Phase 1 : la pluie de plomb.
const RAYON_GOUTTE := 3.0
const INTERVALLE_PLUIE := 3.6
const PREAVIS_PLUIE := 1.6
## Phase 2 : les deux jeux de poutres en feu (bandes en travers, en z).
const POUTRES_A := [Vector2(10, 16), Vector2(28, 34)]
const POUTRES_B := [Vector2(19, 25), Vector2(37, 43)]
const DUREE_POUTRES := 9.0
const PREAVIS_POUTRES := 2.5
## Phase 3 : la lumière des vitraux.
const RAYON_LUMIERE := 7.0
const DUREE_VITRAIL := 22.0
const RENFORTS := 18.0

var _attente_sortie := 0.0
var _lampe_joueur: OmniLight3D
var _lumieres: Array[OmniLight3D] = []

# L'état du donjon (le serveur décide ; chacun voit l'état reçu par _etat_crypte).
var _boss: Node3D
var _phase := 0
var _bouchees := 0
var _coulee := 0.0
var _coulee_z := 0.0
var _prochaine_coulee := 0.0
var _pluie := 0.0
var _gouttes := PackedVector2Array()
var _prochaine_pluie := 0.0
var _jeu_poutres := 0
var _bascule_poutres := 0.0
var _vitraux := 0
var _eteindre: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _plomb_venue := false
var _prochains_renforts := 0.0
var _prochain_tic := 0.0
var _prochain_envoi := 0.0
var _victoire := false
var _boss_vu := false
## Le Typographe est vaincu pour ce joueur (sa quête a passé le combat : voir eteindre()).
var _eteint := false
# Les pièces du décor.
var _gouttieres: Array[Node3D] = []
var _vitraux_objets: Array[Node3D] = []
var _bande_galerie: MeshInstance3D
var _cercles: Array[MeshInstance3D] = []
var _poutres: Array[Node3D] = []
var _brasier: Node3D
var _cendres: Node3D
var _fumee_grise: MeshInstance3D


func _init() -> void:
	identifiant_zone = "fonderie"
	taille_terrain = 240
	graine = 1455
	point_apparition = ENTREE
	nombre_touffes = 0
	neige_qui_tombe = false
	ambiance_grandiose = false
	ciel = ""


func _ready() -> void:
	# Un donjon : pas de monture à l'intérieur (voir le script des montures).
	add_to_group("donjon")
	# La quête appelle eteindre() sur la zone elle-même (« appeler » : typographe_plomb).
	add_to_group("decor_quete")
	set_meta("identifiant", "typographe_plomb")
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_mayence", "") != "":
		Reseau.remove_meta("arrivee_mayence")
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	if zone == "fonderie":
		return Vector2.INF
	return ENTREE + Vector2(0, -2)


# --- Le sol -------------------------------------------------------------------------------------

func _sol_espace(e: Array, z: float) -> float:
	var r: Rect2 = e[1]
	var t := clampf((z - r.position.y) / r.size.y, 0.0, 1.0)
	return lerpf(float(e[2]), float(e[3]), t)


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


# --- Construction --------------------------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_lumieres.clear()
	_gouttieres.clear()
	_vitraux_objets.clear()
	_cercles.clear()
	_poutres.clear()
	_construire_salles()
	_construire_galerie()
	_construire_salle_puits()
	_construire_lac()
	_construire_fond()
	_construire_brasier()
	_construire_quete()
	_construire_limites()
	_eclairer()


func _dossier(nom: String) -> Node3D:
	var d := Node3D.new()
	d.name = nom
	_contenu.add_child(d)
	return d


## Le grès des caves de la cathédrale : de gros moellons rouges, noircis par la fumée.
func _mat_pierre_crypte() -> StandardMaterial3D:
	return _mat_choix(["stacked_stone_wall", "old_stone_wall"], Color(0.56, 0.36, 0.3), 0.95, 2.5)


func _mat_plomb_fondu() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.45, 0.12)
	m.metallic = 0.6
	m.roughness = 0.25
	m.emission_enabled = true
	m.emission = Color(1.0, 0.36, 0.08)
	m.emission_energy_multiplier = 2.6
	return m


func _pente(e: Array) -> Array:
	var r: Rect2 = e[1]
	var dy := float(e[3]) - float(e[2])
	var angle := -atan2(dy, r.size.y)
	return [angle, Vector3(0, cos(angle), sin(angle)), sqrt(r.size.y * r.size.y + dy * dy)]


func _dalle(parent: Node3D, e: Array, decalage: float, epaisseur: float, materiau: Material, collision := true,
		marge := 0.0) -> MeshInstance3D:
	var r: Rect2 = e[1]
	var pente := _pente(e)
	var normale: Vector3 = pente[1]
	var centre := Vector3(r.get_center().x, (float(e[2]) + float(e[3])) * 0.5, r.get_center().y) \
			+ normale * (decalage + (epaisseur * 0.5 if decalage > 0.0 else -epaisseur * 0.5))
	var dalle := _boite(Vector3(r.size.x + marge * 2.0, epaisseur, float(pente[2]) + 0.4), centre, materiau, parent, collision)
	dalle.rotation.x = pente[0]
	return dalle


## Un pan de mur le long d'un bord de salle (de a à b), entre « bas » et « haut » au-dessus du sol.
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


## Les salles : sol de dalles, voûte, murs de pierre, avec un passage vers chaque voisine.
func _construire_salles() -> void:
	var d := _dossier("Salles")
	var mur := _mat_pierre_crypte()
	var sol := _mat_choix(["cobblestone_floor_04", "stacked_stone_wall"], Color(0.44, 0.4, 0.36), 0.9, 2.5)
	var voute := _mat_choix(["old_stone_wall", "stacked_stone_wall"], Color(0.3, 0.27, 0.25), 0.95, 3.0)
	for i in ESPACES.size():
		var e: Array = ESPACES[i]
		var r: Rect2 = e[1]
		var h := float(e[4])
		var g := Node3D.new()
		g.name = String(e[0]).capitalize().replace(" ", "")
		d.add_child(g)
		_dalle(g, e, 0.0, 1.0, sol)
		_dalle(g, e, h, 1.0, voute, false, 1.0)
		for bord: String in ["x-", "x+", "z-", "z+"]:
			var long := bord.begins_with("x")
			var debut := r.position.y if long else r.position.x
			var fin := r.end.y if long else r.end.x
			var fixe := (r.position.x if bord == "x-" else r.end.x) if long else (r.position.y if bord == "z-" else r.end.y)
			var curseur := debut
			for o in _ouvertures(i, bord):
				if o[0] > curseur + 0.05:
					_pan(g, e, _point_bord(long, fixe, curseur), _point_bord(long, fixe, o[0]), -1.5, h + 0.5, mur)
				if float(o[2]) < h - 0.05:
					_pan(g, e, _point_bord(long, fixe, o[0]), _point_bord(long, fixe, o[1]), float(o[2]), h + 0.5, mur)
				curseur = o[1]
			if fin > curseur + 0.05:
				_pan(g, e, _point_bord(long, fixe, curseur), _point_bord(long, fixe, fin), -1.5, h + 0.5, mur)
	# Des marches dans l'escalier et la descente (sans collision : la pente suffit).
	for i: int in [0, 3]:
		var e0: Array = ESPACES[i]
		var r0: Rect2 = e0[1]
		var n := int(r0.size.y / 0.6)
		for k in n:
			var z := r0.position.y + (k + 0.5) * r0.size.y / n
			_boite(Vector3(r0.size.x, 0.12, 0.25), Vector3(r0.get_center().x, _sol_espace(e0, z) + 0.04, z), mur, d, false)
	_fusionner(d)


## Une lampe à huile des caves, accrochée au mur ou posée sur un pied de fer : une flamme,
## une lumière chaude.
func _lampe(parent: Node3D, p: Vector3, haute := true) -> void:
	var fer := _mat_uni_ma(Color(0.12, 0.11, 0.1), 0.5)
	var y := 1.6 if haute else 0.3
	var pied := MeshInstance3D.new()
	pied.mesh = _cylindre(0.04, 0.1, y, 6)
	pied.material_override = fer
	pied.position = p + Vector3(0, y * 0.5, 0)
	parent.add_child(pied)
	var coupe := MeshInstance3D.new()
	coupe.mesh = _cylindre(0.22, 0.1, 0.14, 10)
	coupe.material_override = fer
	coupe.position = p + Vector3(0, y + 0.07, 0)
	parent.add_child(coupe)
	var flamme := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.09
	s.height = 0.26
	flamme.mesh = s
	flamme.material_override = _lumineux(Color(1.0, 0.62, 0.26), 6.0)
	flamme.position = p + Vector3(0, y + 0.24, 0)
	parent.add_child(flamme)
	var lumiere := OmniLight3D.new()
	lumiere.light_color = Color(1.0, 0.64, 0.34)
	lumiere.light_energy = 1.6
	lumiere.omni_range = 10.0
	lumiere.omni_attenuation = 1.3
	lumiere.position = p + Vector3(0, y + 0.6, 0)
	lumiere.shadow_enabled = _lumieres.size() % 4 == 0
	parent.add_child(lumiere)
	_lumieres.append(lumiere)


## Une bande ou un disque au sol (avertissement d'une coulée, d'une goutte, d'une poutre).
func _bande(parent: Node3D, taille: Vector2, couleur: Color, energie: float, disque := false) -> MeshInstance3D:
	var bande := MeshInstance3D.new()
	if disque:
		var c := CylinderMesh.new()
		c.top_radius = taille.x
		c.bottom_radius = taille.x
		c.height = 0.02
		c.radial_segments = 32
		bande.mesh = c
	else:
		var plan := PlaneMesh.new()
		plan.size = taille
		bande.mesh = plan
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(couleur.r, couleur.g, couleur.b)
	m.emission_energy_multiplier = energie
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bande.material_override = m
	bande.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bande.visible = false
	parent.add_child(bande)
	return bande


## Les caves du chapitre : des arcs en plein cintre, des tonneaux couchés le long des murs, et
## des coulées de plomb figé sur les dalles, sous les moules brisés de la voûte.
func _construire_galerie() -> void:
	var d := _dossier("Galerie")
	var pierre := _mat_pierre_crypte()
	var plomb := _mat_uni_ma(Color(0.36, 0.37, 0.4), 0.3)
	plomb.metallic = 0.8
	var chene := _mat_chene_clair()
	var cercle := _mat_uni_ma(Color(0.16, 0.15, 0.14), 0.5)
	var z := GALERIE.position.y + 2.0
	var k := 0
	while z < GALERIE.end.y - 1.0:
		for c: float in [-1.0, 1.0]:
			_boite(Vector3(0.7, 5.2, 0.8), Vector3(c * (GALERIE.size.x * 0.5 - 0.35), SOL + 2.6, z), pierre, d, false)
		var arc := MeshInstance3D.new()
		var tore := TorusMesh.new()
		tore.inner_radius = GALERIE.size.x * 0.5 - 0.7
		tore.outer_radius = GALERIE.size.x * 0.5
		tore.rings = 24
		tore.ring_segments = 6
		arc.mesh = tore
		arc.material_override = pierre
		arc.position = Vector3(0, SOL + 5.2 - 1.6, z)
		arc.rotation.x = PI / 2
		arc.scale = Vector3(1, 1, 0.55)
		d.add_child(arc)
		# Les tonneaux du chapitre, couchés sur leurs chantiers, contre un mur ou l'autre.
		var c2 := -1.0 if k % 2 == 0 else 1.0
		for l in 2:
			var t := MeshInstance3D.new()
			t.mesh = _cylindre(0.62, 0.62, 1.5, 14)
			t.material_override = chene
			t.rotation.z = PI / 2
			t.rotation.y = PI / 2
			t.position = Vector3(c2 * (GALERIE.size.x * 0.5 - 1.1), SOL + 0.75, z + 1.2 + l * 1.4)
			d.add_child(t)
			for b: float in [-0.5, 0.5]:
				var cc := MeshInstance3D.new()
				cc.mesh = _cylindre(0.64, 0.64, 0.08, 14)
				cc.material_override = cercle
				cc.rotation = t.rotation
				cc.position = t.position + Vector3(b * 1.2 * 0.0, 0, b * 1.2)
				d.add_child(cc)
		if k % 2 == 1:
			_lampe(d, Vector3(-c2 * (GALERIE.size.x * 0.5 - 0.9), SOL + 0.2, z + 2.0), false)
		var flaque := MeshInstance3D.new()
		flaque.mesh = _cylindre(0.6 + (k % 3) * 0.3, 0.7 + (k % 3) * 0.3, 0.04, 14)
		flaque.material_override = plomb
		flaque.position = Vector3(((k * 37) % 7 - 3) * 0.5, SOL + 0.02, z + 1.0)
		d.add_child(flaque)
		z += 4.0
		k += 1
	_bande_galerie = _bande(d, Vector2(GALERIE.size.x - 0.4, LARGEUR_COULEE), Color(1.0, 0.3, 0.05, 0.4), 2.2)
	_bande_galerie.name = "CouleeGalerie"
	_fusionner(d)


## Une casse de géant : un grand casier incliné, plein de compartiments, des lettres dedans.
func _casse_geante(parent: Node3D, p: Vector2, angle: float) -> void:
	var n := Node3D.new()
	n.position = Vector3(p.x, SOL, p.y)
	n.rotation.y = angle
	parent.add_child(n)
	var chene := _mat_chene_clair()
	var sombre := _mat_uni_ma(Color(0.14, 0.1, 0.07), 0.9)
	var plomb := _mat_uni_ma(Color(0.5, 0.52, 0.56), 0.35)
	plomb.metallic = 0.7
	_boite(Vector3(5.0, 2.4, 1.6), Vector3(0, 1.2, 0), chene, n)
	var plateau := Node3D.new()
	plateau.position = Vector3(0, 2.6, 0)
	plateau.rotation.x = -0.5
	n.add_child(plateau)
	_boite(Vector3(5.2, 0.2, 3.2), Vector3(0, 0, 0), chene, plateau, false)
	for i in 8:
		for j in 5:
			var q := Vector3(-2.2 + i * 0.63, 0.12, -1.2 + j * 0.6)
			_boite(Vector3(0.55, 0.06, 0.52), q, sombre, plateau, false)
			if (i + j) % 3 != 0:
				_boite(Vector3(0.18, 0.14, 0.18), q + Vector3(0.05 * (j % 2), 0.1, 0), plomb, plateau, false)


## La salle des casses : des casses de lettres grandes comme des maisons, des piles de
## formes liées, des piliers ; c'est là que Hans s'est fait prendre.
func _construire_salle_puits() -> void:
	var d := _dossier("SalleCasses")
	var pierre := _mat_pierre_crypte()
	var r := SALLE_PUITS
	_casse_geante(d, PUITS + Vector2(0, -2), 0.0)
	for k in 3:
		for c: float in [-1.0, 1.0]:
			var x := r.get_center().x + c * (r.size.x * 0.5 - 2.4)
			var z := r.position.y + 5.0 + k * 9.0
			if Vector2(x, z).distance_to(INSCRIPTION) < 4.0:
				continue
			_casse_geante(d, Vector2(x, z), c * PI / 2)
	for q: Vector2 in [Vector2(-8, -33), Vector2(8, -33), Vector2(-8, -19), Vector2(8, -19)]:
		_boite(Vector3(1.4, 9.0, 1.4), Vector3(q.x, SOL + 4.5, q.y), pierre, d)
	for k in 6:
		var x := r.position.x + 1.0 if k % 2 == 0 else r.end.x - 1.0
		_lampe(d, Vector3(x, SOL, r.position.y + 5.0 + (k / 2) * 9.0))
	_fusionner(d)


## La fonderie infinie : des montagnes de caractères, des lingots, des creusets, et le lac de
## plomb fondu qui coule au fond, derrière le Typographe.
func _construire_lac() -> void:
	var d := _dossier("Lac")
	var r := LAC
	var h := float(ESPACES[4][4])
	var pierre := _mat_pierre_crypte()
	var briques := _mat_choix(["clay_block_wall", "brown_mud_02"], Color(0.56, 0.32, 0.24), 0.95, 2.0)
	var plomb := _mat_uni_ma(Color(0.42, 0.43, 0.47), 0.35)
	plomb.metallic = 0.75
	for p: Vector2 in PILIERS:
		# Des fourneaux de briques, ronds, avec leur gueule rougeoyante.
		var col := MeshInstance3D.new()
		var cassee := int(p.x + p.y) % 3 == 0
		var haut := 5.0 if cassee else h
		col.mesh = _cylindre(0.9, 1.1, haut, 12)
		col.material_override = briques
		col.position = Vector3(p.x, SOL_LAC + haut * 0.5, p.y)
		d.add_child(col)
		var gueule := _boite(Vector3(0.7, 0.5, 0.1), Vector3(p.x, SOL_LAC + 0.8, p.y + (1.08 if p.y < 30.0 else -1.08)), _lumineux(Color(1.0, 0.4, 0.08), 2.4), d, false)
		gueule.rotation.y = 0.0
		var corps := StaticBody3D.new()
		var forme := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 1.1
		cyl.height = haut
		forme.shape = cyl
		corps.add_child(forme)
		corps.position = col.position
		d.add_child(corps)
	# Les montagnes de caractères, contre les murs : des tas de petites lettres de plomb.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 3
	var lettre := BoxMesh.new()
	lettre.size = Vector3(0.22, 0.3, 0.22)
	for tas: Vector3 in [Vector3(r.position.x + 5.0, 0, r.position.y + 8.0), Vector3(r.end.x - 5.0, 0, r.position.y + 10.0),
			Vector3(r.position.x + 6.0, 0, r.end.y - 14.0), Vector3(r.end.x - 6.0, 0, r.end.y - 12.0)]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = lettre
		mm.instance_count = 900
		for i in mm.instance_count:
			var a := hasard.randf() * TAU
			var rr := sqrt(hasard.randf()) * 4.5
			var y := maxf(0.0, (4.5 - rr) * 0.8) * hasard.randf_range(0.7, 1.0)
			var b := Basis.from_euler(Vector3(hasard.randf() * TAU, hasard.randf() * TAU, hasard.randf() * TAU))
			mm.set_instance_transform(i, Transform3D(b, Vector3(tas.x + cos(a) * rr, SOL_LAC + y, tas.z + sin(a) * rr)))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = plomb
		d.add_child(mi)
		var bosse := StaticBody3D.new()
		var forme := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 3.6
		cyl.height = 3.0
		forme.shape = cyl
		bosse.add_child(forme)
		bosse.position = Vector3(tas.x, SOL_LAC + 1.5, tas.z)
		d.add_child(bosse)
	# Des lingots empilés, des creusets, des louches.
	for k in 10:
		var q := Vector2(hasard.randf_range(r.position.x + 3.0, r.end.x - 3.0), hasard.randf_range(r.position.y + 4.0, r.position.y + 12.0))
		if absf(q.x) < 6.0:
			continue
		for l in 3:
			_boite(Vector3(0.8, 0.18, 0.3), Vector3(q.x, SOL_LAC + 0.09 + l * 0.18, q.y + (l % 2) * 0.1), plomb, d, false)
	# Les lampes.
	for k in 8:
		var x := r.position.x + 1.5 if k % 2 == 0 else r.end.x - 1.5
		var z := r.position.y + 6.0 + (k / 2) * 14.0
		if absf(z - 18.0) < 3.0 or absf(z - 38.0) < 3.0:
			z += 4.0
		_lampe(d, Vector3(x, SOL_LAC, z))
	_fusionner(d)


## Le fond de la fonderie : la rivière de plomb fondu, les bandes du combat, la brume d'encre.
func _construire_fond() -> void:
	var r := LAC
	# La rivière de plomb fondu, au fond, derrière le Typographe (on ne peut pas y aller).
	var riviere := MeshInstance3D.new()
	riviere.name = "RiviereDePlomb"
	var plan := PlaneMesh.new()
	plan.size = Vector2(r.size.x - 1.0, 3.0)
	riviere.mesh = plan
	riviere.material_override = _mat_plomb_fondu()
	riviere.position = Vector3(r.get_center().x, SOL_LAC + 0.04, r.end.y - 2.0)
	_contenu.add_child(riviere)
	var lueur := OmniLight3D.new()
	lueur.light_color = Color(1.0, 0.45, 0.15)
	lueur.light_energy = 3.0
	lueur.omni_range = 22.0
	lueur.position = Vector3(0, SOL_LAC + 2.0, r.end.y - 3.0)
	_contenu.add_child(lueur)
	_mur_invisible(_contenu, Vector3(r.size.x, 20, 1.0), Vector3(r.get_center().x, SOL_LAC + 10.0, r.end.y - 3.6))
	# Les bandes : les cercles de la pluie de plomb (phase 1) et les poutres (phase 2).
	var bandes := _dossier("BandesLac")
	for k in 4:
		var cercle := _bande(bandes, Vector2(RAYON_GOUTTE, RAYON_GOUTTE), Color(1.0, 0.2, 0.05, 0.4), 2.2, true)
		cercle.name = "Goutte%d" % k
		_cercles.append(cercle)
	# Les lignes de plomb : de longues barres de caractères fondus qui s'abattent en travers.
	var bois := _mat_uni_ma(Color(0.3, 0.31, 0.34), 0.35)
	bois.metallic = 0.85
	for jeu in [POUTRES_A, POUTRES_B]:
		for z: Vector2 in jeu:
			var p := Node3D.new()
			p.position = Vector3(r.get_center().x, SOL_LAC, (z.x + z.y) * 0.5)
			p.visible = false
			bandes.add_child(p)
			var avertissement := _bande(p, Vector2(r.size.x - 1.0, z.y - z.x), Color(1.0, 0.35, 0.05, 0.3), 1.6)
			avertissement.name = "Avertissement"
			avertissement.position.y = 0.05
			var poutre := Node3D.new()
			poutre.name = "Poutre"
			p.add_child(poutre)
			for k in 3:
				var b := _boite(Vector3(r.size.x - 4.0, 0.6, 0.6), Vector3(0, 0.3 + k * 0.1, (k - 1) * 1.6), bois, poutre, false)
				b.rotation.y = (k - 1) * 0.04
			var braise := _bande(poutre, Vector2(r.size.x - 2.0, z.y - z.x), Color(1.0, 0.4, 0.08, 0.55), 2.5)
			braise.position.y = 0.08
			braise.visible = true
			var feu := OmniLight3D.new()
			feu.light_color = Color(1.0, 0.5, 0.18)
			feu.light_energy = 2.0
			feu.omni_range = 9.0
			feu.position = Vector3(0, 1.2, 0)
			poutre.add_child(feu)
			_poutres.append(p)
	# L'encre noire de la phase 3 : une nappe d'encre qui monte sur toute la salle.
	_fumee_grise = MeshInstance3D.new()
	_fumee_grise.name = "EncreNoire"
	var voile := PlaneMesh.new()
	voile.size = r.size
	_fumee_grise.mesh = voile
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.02, 0.015, 0.04, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fumee_grise.material_override = m
	_fumee_grise.position = Vector3(r.get_center().x, SOL_LAC + 0.9, r.get_center().y)
	_fumee_grise.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fumee_grise.visible = false
	_contenu.add_child(_fumee_grise)


## Le Typographe de plomb : un géant fait de milliers de lettres de plomb agglutinées,
## un composteur à la main, deux yeux violets (la fracture). Quand le cœur est brisé,
## il s'effondre en un tas de caractères froids, éparpillés sur le sol.
func _construire_brasier() -> void:
	_brasier = Node3D.new()
	_brasier.name = "TypographeDePlomb"
	_brasier.position = Vector3(BRASIER.x, SOL_LAC, BRASIER.y)
	_brasier.rotation.y = PI
	_contenu.add_child(_brasier)
	var plomb_froid := _mat_uni_ma(Color(0.5, 0.51, 0.55), 0.35)
	plomb_froid.metallic = 0.6
	var plomb_sombre := _mat_uni_ma(Color(0.16, 0.16, 0.19), 0.5)
	plomb_sombre.metallic = 0.7
	var fondu := _mat_plomb_fondu()
	var violet := _lumineux(Color(0.62, 0.3, 1.0), 4.0)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 7
	# Le corps : des milliers de petites lettres (un MultiMesh), en jambes, torse et épaules.
	var lettre := BoxMesh.new()
	lettre.size = Vector3(0.22, 0.3, 0.22)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = lettre
	multi.instance_count = 2600
	for k in multi.instance_count:
		var y := hasard.randf_range(0.2, 11.0)
		var rayon := 1.2
		var cx := 0.0
		if y < 4.5:
			cx = -1.4 if k % 2 == 0 else 1.4
			rayon = 0.9
		elif y < 9.5:
			rayon = 2.2 + (y - 4.5) * 0.12
		else:
			rayon = 2.6 - (y - 9.5) * 1.2
		var ang := hasard.randf() * TAU
		var r := sqrt(hasard.randf()) * rayon
		var t := Transform3D(Basis.from_euler(Vector3(hasard.randf() * TAU, hasard.randf() * TAU, hasard.randf() * TAU)),
				Vector3(cx + cos(ang) * r, y, sin(ang) * r * 0.7))
		multi.set_instance_transform(k, t)
	var corps_lettres := MultiMeshInstance3D.new()
	corps_lettres.name = "Lettres"
	corps_lettres.multimesh = multi
	corps_lettres.material_override = plomb_froid
	_brasier.add_child(corps_lettres)
	# Un quart des lettres sont encore brûlantes : elles rougeoient dans la masse.
	var chaudes := MultiMesh.new()
	chaudes.transform_format = MultiMesh.TRANSFORM_3D
	chaudes.mesh = lettre
	chaudes.instance_count = 650
	for k in chaudes.instance_count:
		chaudes.set_instance_transform(k, multi.get_instance_transform(k * 4).translated_local(Vector3(0.05, 0.05, 0.05)))
	var lettres_chaudes := MultiMeshInstance3D.new()
	lettres_chaudes.name = "LettresChaudes"
	lettres_chaudes.multimesh = chaudes
	lettres_chaudes.material_override = _lumineux(Color(1.0, 0.42, 0.1), 1.8)
	_brasier.add_child(lettres_chaudes)
	# Le cœur : une masse sombre sous les lettres, avec des fentes de plomb fondu.
	var torse := MeshInstance3D.new()
	torse.mesh = _cylindre(1.9, 2.6, 5.0, 10)
	torse.material_override = plomb_sombre
	torse.position = Vector3(0, 7.0, 0)
	_brasier.add_child(torse)
	for k in 12:
		var ang := k * TAU / 12.0 + hasard.randf_range(-0.2, 0.2)
		var fente := _boite(Vector3(0.16, hasard.randf_range(1.2, 3.0), 0.16),
				Vector3(cos(ang) * 2.3, hasard.randf_range(5.0, 9.0), sin(ang) * 1.7), _lumineux(Color(1.0, 0.45, 0.1), 2.4), _brasier, false)
		fente.rotation = Vector3(hasard.randf_range(-0.4, 0.4), 0, hasard.randf_range(-0.5, 0.5))
	# Les bras : le droit tient un composteur géant (la réglette où l'on aligne les lettres),
	# le gauche laisse couler une ligne de plomb fondu.
	for c: float in [-1.0, 1.0]:
		var bras := MeshInstance3D.new()
		bras.mesh = _cylindre(0.6, 0.9, 6.0, 8)
		bras.material_override = plomb_sombre
		bras.position = Vector3(c * 3.8, 8.6, -0.4)
		bras.rotation = Vector3(0.3, 0, c * -0.7)
		_brasier.add_child(bras)
	var composteur := _boite(Vector3(0.5, 0.8, 5.5), Vector3(5.8, 6.2, -2.0), plomb_froid, _brasier, false)
	composteur.rotation = Vector3(0.5, 0.0, 0.2)
	for k in 9:
		_boite(Vector3(0.28, 0.35, 0.28), Vector3(5.8, 6.7 - k * 0.06, -4.0 + k * 0.5), plomb_sombre, _brasier, false)
	var coulee := MeshInstance3D.new()
	coulee.mesh = _cylindre(0.12, 0.25, 8.0, 6)
	coulee.material_override = fondu
	coulee.position = Vector3(-5.6, 4.0, -1.0)
	_brasier.add_child(coulee)
	# La tête : un bloc de lettres serrées, deux yeux violets (la fracture).
	var tete := _boite(Vector3(2.4, 2.6, 2.2), Vector3(0, 12.2, 0), plomb_sombre, _brasier, false)
	tete.rotation.y = 0.1
	for k in 40:
		_boite(Vector3(0.3, 0.38, 0.3), Vector3(hasard.randf_range(-1.2, 1.2), 12.2 + hasard.randf_range(-1.3, 1.3), hasard.randf_range(-1.1, 1.1)),
				plomb_froid, _brasier, false).rotation = Vector3(hasard.randf() * TAU, hasard.randf() * TAU, 0)
	for c: float in [-1.0, 1.0]:
		var oeil := MeshInstance3D.new()
		var o := SphereMesh.new()
		o.radius = 0.25
		o.height = 0.3
		oeil.mesh = o
		oeil.material_override = violet
		oeil.position = Vector3(c * 0.6, 12.5, -1.2)
		_brasier.add_child(oeil)
	var lueur := OmniLight3D.new()
	lueur.light_color = Color(1.0, 0.5, 0.2)
	lueur.light_energy = 5.0
	lueur.omni_range = 26.0
	lueur.position = Vector3(0, 7.0, -5.0)
	_brasier.add_child(lueur)
	var regard := OmniLight3D.new()
	regard.light_color = Color(0.6, 0.35, 1.0)
	regard.light_energy = 1.5
	regard.omni_range = 9.0
	regard.position = Vector3(0, 12.5, -2.5)
	_brasier.add_child(regard)
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(8.0, 14.0, 4.0)
	forme.shape = boite
	forme.position = Vector3(0, 7.0, 0)
	corps.add_child(forme)
	_brasier.add_child(corps)
	# Ce qui reste : un tas de caractères froids et une flaque de plomb figé.
	_cendres = Node3D.new()
	_cendres.name = "Cendres"
	_cendres.position = _brasier.position
	_cendres.visible = false
	_contenu.add_child(_cendres)
	var flaque := MeshInstance3D.new()
	flaque.mesh = _cylindre(5.0, 5.4, 0.12, 24)
	flaque.material_override = plomb_froid
	flaque.position.y = 0.06
	_cendres.add_child(flaque)
	var tas := MultiMesh.new()
	tas.transform_format = MultiMesh.TRANSFORM_3D
	tas.mesh = lettre
	tas.instance_count = 900
	for k in tas.instance_count:
		var ang := hasard.randf() * TAU
		var r := sqrt(hasard.randf()) * 5.0
		var h := maxf(0.1, (5.0 - r) * 0.35 * hasard.randf())
		tas.set_instance_transform(k, Transform3D(Basis.from_euler(Vector3(hasard.randf() * TAU, hasard.randf() * TAU, 0)),
				Vector3(cos(ang) * r, h, sin(ang) * r)))
	var tas_mi := MultiMeshInstance3D.new()
	tas_mi.multimesh = tas
	tas_mi.material_override = plomb_froid
	_cendres.add_child(tas_mi)


func _construire_limites() -> void:
	var limites := _dossier("Limites")
	var demi := taille_terrain * 0.5 - 2.0
	_mur_invisible(limites, Vector3(2, 160, taille_terrain), Vector3(-demi, 0, 0))
	_mur_invisible(limites, Vector3(2, 160, taille_terrain), Vector3(demi, 0, 0))
	_mur_invisible(limites, Vector3(taille_terrain, 160, 2), Vector3(0, 0, -demi))
	_mur_invisible(limites, Vector3(taille_terrain, 160, 2), Vector3(0, 0, demi))


# --- La quête ------------------------------------------------------------------------------------

func _pnj_cache(dossier: Node3D, id: String, p: Vector2, angle: float) -> Node3D:
	var n := _pnj(dossier, id, p, angle)
	n.add_to_group("decor_quete")
	n.set_meta("identifiant", id)
	n.visible = false
	return n


func _objet(dossier: Node3D, nom: String, id: String, p: Vector2, forme: String, invite: String, portee := 2.4, texte := "") -> Node3D:
	var o := ObjetMayence.new()
	if texte != "":
		o.set_meta("texte_craie", texte)
	o.name = nom
	o.identifiant = id
	o.forme = forme
	o.invite = invite
	o.portee = portee
	o.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
	dossier.add_child(o)
	return o


func _construire_quete() -> void:
	var dossier := _dossier("Quete")
	_dossier_quete = dossier
	# Les moules fissurés des caves : un mécanisme de donjon (la zone s'en occupe).
	for k in GOUTTIERES.size():
		var p: Vector2 = GOUTTIERES[k]
		var o := _objet(dossier, "Gouttiere%d" % k, "moule_fissure_%d" % k, p, "gouttiere_plomb", "[F] Boucher le moule avec un seau de sable")
		o.rotation.y = PI / 2 if p.x < 0.0 else -PI / 2
		o.set_meta("donjon", true)
		_gouttieres.append(o)
	# Les lanternes de Hans, dans la fonderie (phase 3) : il faut les rallumer.
	for k in VITRAUX.size():
		var p: Vector2 = VITRAUX[k]
		var o := _objet(dossier, "Lanterne%d" % k, "lanterne_fonderie_%d" % k, p + Vector2(-1.2 if p.x > 0.0 else 1.2, 0), "lanterne_fonderie",
				"[F] Rallumer la lanterne", 3.0)
		o.rotation.y = PI / 2 if p.x < 0.0 else -PI / 2
		o.set_meta("donjon", true)
		_vitraux_objets.append(o)
	# Masque, en bas de l'escalier (s'il est notre allié depuis la Chine) ; sinon, sa craie.
	_pnj_cache(dossier, "masque_fonderie", ENTREE + Vector2(1.0, 20.0), PI)
	var craie := _objet(dossier, "CraieMasqueFonderie", "craie_masque_fonderie", Vector2(-4.6, -78.5), "craie", "[F] Lire le message à la craie", 2.4,
			"SCEAU EN BAS.\nLE GÉANT AUSSI.\nBOUCHE LES MOULES.\n— M.")
	craie.rotation.y = PI / 2
	# Dans la salle des casses : Hans, Scellé contre une casse, et l'objet invisible qui le délivre.
	_pnj(dossier, "hans_scelle", INSCRIPTION, -PI / 2)
	var scelle := _objet(dossier, "LibererHans", "liberer_hans", INSCRIPTION, "", "[F] Composer la phrase qui libère", 2.4)
	scelle.set_meta("pnj_lie", "hans_scelle")
	# La fracture majeure, sous le Typographe.
	var faille := Faille.new()
	faille.name = "FractureTypographe"
	faille.identifiant = "fracture_typographe"
	faille.position = Vector3(COEUR.x, SOL_LAC, COEUR.y + 2.0)
	dossier.add_child(faille)
	# Après la victoire : Sceau arrêtée, Masque, le registre de Sceau.
	_pnj_cache(dossier, "sceau_arretee", COEUR + Vector2(-4, -5), PI)
	_pnj_cache(dossier, "masque_fonderie_fin", COEUR + Vector2(5, -7), PI * 1.2)
	var registre := _objet(dossier, "RegistreSceau", "registre_sceau", COEUR + Vector2(-2.5, -3.0), "carnet", "[F] Ramasser le registre de Sceau", 2.4)
	registre.add_to_group("decor_quete")
	registre.set_meta("identifiant", "registre_sceau")
	registre.visible = false
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.LIEU, "Les caves du chapitre", GALERIE.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "La salle des casses", PUITS)
	repere.call(MarqueurCarte.Type.LIEU, "La fonderie infinie", Vector2(0, 26))
	repere.call(MarqueurCarte.Type.LIEU, "Sortie (la cathédrale)", ENTREE)


func _eclairer() -> void:
	var soleil := get_node_or_null("Soleil") as DirectionalLight3D
	if soleil != null:
		soleil.light_energy = 0.0
		soleil.shadow_enabled = false
	var environnement := get_node_or_null("Environnement") as WorldEnvironment
	if environnement == null or environnement.environment == null:
		return
	var env := environnement.environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.008, 0.008)
	env.sky = null
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.46, 0.38, 0.34)
	env.ambient_light_energy = 1.05
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.3
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.08, 0.05, 0.04)
	env.fog_density = 0.012
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = false


# --- Chaque image -------------------------------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	if Engine.is_editor_hint():
		return
	for k in _lumieres.size():
		var l := _lumieres[k]
		if is_instance_valid(l):
			l.light_energy = 1.6 + sin(_temps * 7.0 + k * 1.3) * 0.15 + sin(_temps * 17.0 + k) * 0.08
	_porter_la_lampe()
	if multiplayer.is_server():
		_diriger()
	_attente_sortie -= delta
	if _attente_sortie > 0.0:
		return
	_attente_sortie = 0.3
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	var quete := get_tree().get_first_node_in_group("quete")
	if joueur == null or quete == null or not quete.has_method("changer_de_zone"):
		return
	var p := Vector2(joueur.global_position.x, joueur.global_position.z)
	if p.y < ENTREE.y - 3.0:
		Reseau.set_meta("arrivee_mayence", "fonderie")
		quete.changer_de_zone("ville")


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


# --- Le donjon (serveur) -------------------------------------------------------------------------

func _trouver_boss() -> Node3D:
	if _boss != null and is_instance_valid(_boss):
		return _boss
	_boss = null
	for bete in get_tree().get_nodes_in_group("loups"):
		if String(bete.get("type_ennemi")) == "coeur_typographe":
			_boss = bete
	return _boss


func _joueurs_vivants(r: Rect2) -> Array:
	var liste: Array = []
	for j in get_tree().get_nodes_in_group("joueur"):
		var c = j.get_node_or_null("Combat")
		if c != null and c.est_vivant() and r.has_point(Vector2(j.global_position.x, j.global_position.z)):
			liste.append(j)
	return liste


## Le nombre de vitraux allumés.
func vitraux_allumes() -> int:
	return _compter(_vitraux)


func _diriger() -> void:
	var t := Regles.maintenant()
	_diriger_galerie(t)
	var boss := _trouver_boss()
	if boss == null or not boss.combat.est_vivant():
		if _boss_vu and not _victoire:
			_finir(true)
	else:
		_boss_vu = true
		_diriger_boss(boss, t)
	if t >= _prochain_tic:
		_prochain_tic = t + 1.0
		_tic_degats()
	if t >= _prochain_envoi:
		_prochain_envoi = t + 0.2
		_envoyer()


func _envoyer() -> void:
	_etat_crypte.rpc(_phase, _bouchees, _coulee_z if _coulee > 0.0 else INF,
			_gouttes if _pluie > 0.0 else PackedVector2Array(), _jeu_poutres, _vitraux, _victoire)


## La galerie : tant qu'une gouttière coule, des coulées de plomb balaient le couloir.
func _diriger_galerie(t: float) -> void:
	if _bouchees == (1 << GOUTTIERES.size()) - 1:
		_coulee = 0.0
		return
	var joueurs := _joueurs_vivants(GALERIE)
	if joueurs.is_empty():
		_coulee = 0.0
		return
	if _coulee <= 0.0 and t >= _prochaine_coulee:
		var cible: Node3D = joueurs[Regles.aleatoire.randi() % joueurs.size()]
		_coulee_z = clampf(cible.global_position.z + Regles.aleatoire.randf_range(-1.0, 1.0), GALERIE.position.y + 1.5, GALERIE.end.y - 1.5)
		_coulee = t + PREAVIS_COULEE
	elif _coulee > 0.0 and t >= _coulee:
		_coulee = 0.0
		_prochaine_coulee = t + INTERVALLE_COULEE
		for j in joueurs:
			if absf(j.global_position.z - _coulee_z) < LARGEUR_COULEE * 0.5:
				var c = j.get_node("Combat")
				Regles.infliger(null, c, c.pv_max * 0.22, "periodique")
		_eclabousser.rpc(PackedVector2Array([Vector2(0, _coulee_z)]), true)


func _diriger_boss(boss: Node3D, t: float) -> void:
	var combat = boss.combat
	var joueurs := _joueurs_vivants(LAC)
	if joueurs.is_empty() or int(boss.get("etat")) != 1:
		if _phase != 0 and (joueurs.is_empty() or combat.pv >= combat.pv_max * 0.99):
			_finir(false)
		return
	var part: float = combat.pv / combat.pv_max
	var phase := 1 if part > 0.66 else (2 if part > 0.33 else 3)
	if phase < _phase:
		phase = _phase
	if phase > _phase:
		_entrer_phase(phase, t)
	# Phase 1 : la pluie de plomb, un cercle sous chaque joueur (quatre au plus).
	if _phase == 1:
		if _pluie <= 0.0 and t >= _prochaine_pluie:
			_gouttes = PackedVector2Array()
			for j in joueurs.slice(0, 4):
				_gouttes.append(Vector2(j.global_position.x, j.global_position.z) + Vector2(Regles.aleatoire.randf_range(-1, 1), Regles.aleatoire.randf_range(-1, 1)))
			_pluie = t + PREAVIS_PLUIE
		elif _pluie > 0.0 and t >= _pluie:
			_pluie = 0.0
			_prochaine_pluie = t + INTERVALLE_PLUIE
			for j in joueurs:
				var p := Vector2(j.global_position.x, j.global_position.z)
				for g: Vector2 in _gouttes:
					if p.distance_to(g) < RAYON_GOUTTE:
						var c = j.get_node("Combat")
						Regles.infliger(combat, c, c.pv_max * 0.26, "periodique")
						break
			_eclabousser.rpc(_gouttes, false)
	if _phase < 3 and t >= _prochains_renforts:
		_prochains_renforts = t + RENFORTS
		_renforts(2)
	# Phase 2 : les poutres tombent, un jeu puis l'autre.
	if _phase == 2 and t >= _bascule_poutres:
		_bascule_poutres = t + DUREE_POUTRES
		_jeu_poutres = 2 if _jeu_poutres == 1 else 1
	# Phase 3 : les lanternes s'éteignent au bout d'un moment ; Sceau descend.
	if _phase == 3:
		for k in VITRAUX.size():
			if _vitraux & (1 << k) and _eteindre[k] > 0.0 and t >= _eteindre[k]:
				_vitraux &= ~(1 << k)
				_eteindre[k] = 0.0
		if not _plomb_venue:
			_plomb_venue = true
			_faire_venir("masque_sceau_fonderie", COEUR + Vector2(-6, -6), "Sceau_fonderie")


## Ce qui fait mal chaque seconde : les poutres en feu (phase 2), et la fumée grise qui rend
## « las » loin de la lumière des vitraux (phase 3).
func _tic_degats() -> void:
	var boss := _trouver_boss()
	var source = boss.combat if boss != null and is_instance_valid(boss) else null
	for j in get_tree().get_nodes_in_group("joueur"):
		var c = j.get_node_or_null("Combat")
		if c == null or not c.est_vivant():
			continue
		var p := Vector2(j.global_position.x, j.global_position.z)
		if not LAC.has_point(p):
			continue
		var depuis := Regles.maintenant() - (_bascule_poutres - DUREE_POUTRES)
		if _phase == 2 and _jeu_poutres > 0 and depuis >= PREAVIS_POUTRES:
			for z: Vector2 in (POUTRES_A if _jeu_poutres == 1 else POUTRES_B):
				if p.y >= z.x and p.y <= z.y:
					Regles.infliger(source, c, c.pv_max * 0.09, "periodique")
		if _phase == 3 and not dans_la_lumiere(p):
			c.ajouter_effet("las", 1.3, {"degats_infliges": 0.5})


## Près d'une lanterne allumée, l'encre noire ne prend pas.
func dans_la_lumiere(p: Vector2) -> bool:
	for k in VITRAUX.size():
		if _vitraux & (1 << k) and p.distance_to(VITRAUX[k]) < RAYON_LUMIERE:
			return true
	return false


func _entrer_phase(phase: int, t: float) -> void:
	_phase = phase
	if phase == 1:
		_prochaine_pluie = t + 4.0
		_prochains_renforts = t + 8.0
		_annonce.rpc("La pluie de caractères", "Le Typographe plonge la main dans la montagne de lettres et la jette vers la voûte. Quand un cercle rouge s'allume sous tes pieds, sors-en vite : des lettres brûlantes vont y tomber ! Et arrêtez les hommes de lettres qui sortent du plomb.")
	elif phase == 2:
		_pluie = 0.0
		_jeu_poutres = 1
		_bascule_poutres = t + DUREE_POUTRES
		_annonce.rpc("Les lignes de plomb", "Le Typographe compose : de longues lignes de caractères, lourdes comme des poutres, tombent de la voûte et barrent la salle par bandes. Elles tombent tour à tour : ne reste pas dessous !")
	elif phase == 3:
		_jeu_poutres = 0
		_vitraux = 0
		for k in VITRAUX.size():
			_eteindre[k] = 0.0
		_annonce.rpc("L'encre noire", "Le Typographe renverse un baquet d'encre : une brume noire envahit la salle, chacun se sent las, ses coups ne portent plus. Seule la lumière des lanternes de Hans la chasse. Rallumez-les (F), et battez-vous dans leur lumière ! Sceau descend se battre à côté du Typographe.")


func _faire_venir(type: String, p: Vector2, nom: String) -> void:
	var dossier := get_tree().get_first_node_in_group("dossier_loups")
	var quete := get_tree().get_first_node_in_group("quete")
	if dossier == null or quete == null:
		return
	var position := Vector3(p.x, SOL_LAC + 1.0, p.y)
	var bete = quete.SCENE_LOUP.instantiate()
	bete.name = "%s_%d" % [nom, Time.get_ticks_msec() % 100000]
	bete.type_ennemi = type
	bete.position = position
	bete.camp = position
	bete.position_reseau = position
	bete.set_meta("unique", true)
	dossier.add_child(bete, true)


func _renforts(nombre: int) -> void:
	var vivants := 0
	for bete in get_tree().get_nodes_in_group("loups"):
		if String(bete.get("type_ennemi")) == "statue_lettres_plomb_renfort" and bete.combat.est_vivant():
			vivants += 1
	for i in mini(nombre, 4 - vivants):
		var p: Vector2 = ARRIVEES_RENFORTS[Regles.aleatoire.randi() % ARRIVEES_RENFORTS.size()]
		_faire_venir("statue_lettres_plomb_renfort", p, "Renfort_%d" % i)


## Fin du combat : victoire (le cœur est brisé) ou défaite (tout le monde est tombé).
func _finir(victoire: bool) -> void:
	_phase = 0
	_pluie = 0.0
	_jeu_poutres = 0
	_vitraux = 0
	if victoire:
		_victoire = true
	_envoyer()


## Appelé par un moule des caves ou une lanterne de la fonderie (F) : le serveur décide.
func utiliser_objet(objet: Node3D) -> void:
	Regles.au_serveur(self, "_utiliser", [String(objet.name)])


@rpc("any_peer", "call_remote", "reliable")
func _utiliser(nom: String) -> void:
	if not multiplayer.is_server():
		return
	if nom.begins_with("Gouttiere"):
		var k := int(nom.substr(9))
		if not (_bouchees & (1 << k)):
			_bouchees |= 1 << k
			var reste := GOUTTIERES.size() - _compter(_bouchees)
			_annonce.rpc("Un moule bouché", "Le sable grésille et fume, puis le plomb s'arrête de couler. Plus que %d." % reste if reste > 0
					else "Le dernier moule est bouché. Plus une goutte ne tombe dans les caves.")
	elif nom.begins_with("Lanterne") and _phase == 3:
		var k := int(nom.substr(8))
		if not (_vitraux & (1 << k)):
			_vitraux |= 1 << k
			_eteindre[k] = Regles.maintenant() + DUREE_VITRAIL
	_envoyer()


func _compter(masque: int) -> int:
	var n := 0
	while masque > 0:
		n += masque & 1
		masque >>= 1
	return n


# --- Ce que tout le monde voit -------------------------------------------------------------------

@rpc("authority", "call_local", "unreliable_ordered")
func _etat_crypte(phase: int, bouchees: int, galerie_z: float, gouttes: PackedVector2Array, poutres: int, vitraux: int, victoire: bool) -> void:
	if not multiplayer.is_server():
		_phase = phase
		_bouchees = bouchees
		_jeu_poutres = poutres
		_vitraux = vitraux
		_victoire = victoire
	for k in _gouttieres.size():
		var o = _gouttieres[k]
		var bouchee := (bouchees & (1 << k)) != 0
		o.actif = not bouchee
		var sable := o.get_node_or_null("Eteint") as Node3D
		if sable != null:
			sable.visible = bouchee
		if o._visuel != null:
			o._visuel.visible = not bouchee
	if _bande_galerie != null:
		_bande_galerie.visible = galerie_z != INF
		if galerie_z != INF:
			_bande_galerie.position = Vector3(0, SOL + 0.06, galerie_z)
	for k in _cercles.size():
		_cercles[k].visible = phase == 1 and k < gouttes.size()
		if k < gouttes.size():
			_cercles[k].position = Vector3(gouttes[k].x, SOL_LAC + 0.06, gouttes[k].y)
	var jeu := POUTRES_A.size()
	var depuis := Regles.maintenant() - (_bascule_poutres - DUREE_POUTRES)
	for k in _poutres.size():
		var actif := (poutres == 1 and k < jeu) or (poutres == 2 and k >= jeu)
		var p := _poutres[k]
		p.visible = phase == 2 and actif
		# Le préavis : la bande rougeoie d'abord, puis la poutre tombe.
		var tombee := not multiplayer.is_server() or depuis >= PREAVIS_POUTRES
		p.get_node("Poutre").visible = tombee
		p.get_node("Avertissement").visible = not tombee
	for k in _vitraux_objets.size():
		var o = _vitraux_objets[k]
		var allume := (vitraux & (1 << k)) != 0
		o.visible = true
		o.actif = phase == 3 and not allume
		var lumiere := o.get_node_or_null("Eteint") as Node3D
		if lumiere != null:
			lumiere.visible = allume or victoire or _eteint
		if o._visuel != null:
			o._visuel.visible = not (allume or victoire or _eteint)
	if _fumee_grise != null:
		_fumee_grise.visible = phase == 3
	_montrer_brasier(victoire or _eteint)


func _montrer_brasier(eteint: bool) -> void:
	if _brasier != null and _brasier.visible == eteint:
		_brasier.visible = not eteint
		for corps in _brasier.find_children("*", "StaticBody3D", false, false):
			(corps.get_child(0) as CollisionShape3D).set_deferred("disabled", eteint)
	if _cendres != null:
		_cendres.visible = eteint


## Appelé par la quête (« appeler » : typographe_plomb, methode : eteindre) : pour qui a déjà
## vaincu le Typographe, il reste effondré, même dans une nouvelle copie du donjon.
func eteindre(_anime := true) -> void:
	_eteint = true
	_montrer_brasier(true)


## Des gouttes de plomb qui tombent (une gerbe de petites gouttes brillantes) à chaque point.
@rpc("authority", "call_local", "reliable")
func _eclabousser(points: PackedVector2Array, galerie: bool) -> void:
	var plomb := _lumineux(Color(1.0, 0.5, 0.15), 3.0)
	var goutte := SphereMesh.new()
	goutte.radius = 0.08
	goutte.height = 0.3
	for q: Vector2 in points:
		var gerbe := Node3D.new()
		gerbe.position = Vector3(q.x, (SOL if galerie else SOL_LAC) + 0.2, q.y)
		_contenu.add_child(gerbe)
		for k in 16:
			var g := MeshInstance3D.new()
			g.mesh = goutte
			g.material_override = plomb
			var largeur := GALERIE.size.x * 0.5 if galerie else RAYON_GOUTTE
			g.position = Vector3(randf_range(-largeur, largeur), randf_range(0.0, 2.5), randf_range(-1.2, 1.2) if galerie else randf_range(-largeur, largeur))
			gerbe.add_child(g)
		get_tree().create_timer(0.4).timeout.connect(gerbe.queue_free)


@rpc("authority", "call_local", "reliable")
func _annonce(titre: String, texte: String) -> void:
	var quete := get_tree().get_first_node_in_group("quete")
	if quete != null:
		quete.annoncer(titre, texte)
