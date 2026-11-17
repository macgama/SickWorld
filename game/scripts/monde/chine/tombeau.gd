@tool
extends "res://scripts/monde/chine/ile_chine.gd"
## Île de la Chine : le tombeau du Premier Empereur (donjon à 5 joueurs, niveau 50,
## chapitre 8).
##
## Tel que l'historien Sima Qian l'a décrit, cent ans avant notre an 105 : on descend par la
## galerie que Cinabre a creusée sous le mont Li. D'abord la galerie des arbalètes, que des
## mécanismes de bronze font tirer toutes seules sur les pilleurs ; puis la salle des fleuves
## de mercure, où l'argent liquide coule dans des canaux, comme le Fleuve Jaune et le Yangzi
## en miniature ; enfin le palais souterrain, sous un plafond d'étoiles en perles, éclairé par
## des lampes qui ne s'éteignent jamais. Au fond, sur le cercueil, la fracture majeure a
## réveillé l'Empereur d'argile : un géant de quinze mètres fait de son armée.
##
## Le combat (le serveur décide ; chacun voit l'état reçu par _etat_tombeau) :
## - phase 1, les arbalètes : des volées de flèches balaient le palais en lignes (une bande
##   rouge s'allume au sol avant le tir) et des soldats sortent des piédestaux ;
## - phase 2, les fleuves de mercure : deux paires de canaux se remplissent tour à tour ;
## - phase 3, le grand autodafé : Cinabre, sur la tête du géant, allume quatre bûchers de
##   livres. Près d'un bûcher, la fumée empêche d'utiliser ses compétences ; tant que trois
##   bûchers brûlent, l'Empereur ne craint rien. On les éteint (F) avec le papier mouillé de
##   Cai Lun ; ils se rallument au bout d'un moment. Masque tient la porte du palais.
##
## Comme à la Cloaca : pas de relief, chaque salle est une boîte, et hauteur() lit le sol de la
## salle où l'on est. On entre au nord (-Z) ; le cercueil est au sud (+Z).

const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const ObjetChine := preload("res://scripts/monde/chine/objet_chine.gd")
const Faille := preload("res://scripts/monde/prehistoire/faille.gd")

const ENTREE := Vector2(0, -98)
const SOL := -10.0
## Les salles : [nom, Rect2 (x, z), sol au début (z min), sol au bout (z max), hauteur sous plafond].
const ESPACES := [
	["descente", Rect2(-2, -102, 4, 22), 0.0, -10.0, 4.0],
	["galerie", Rect2(-5, -80, 10, 40), -10.0, -10.0, 6.0],
	["fleuves", Rect2(-20, -40, 40, 30), -10.0, -10.0, 10.0],
	["couloir", Rect2(-3, -10, 6, 12), -10.0, -10.0, 6.0],
	["palais", Rect2(-30, 2, 60, 56), -10.0, -10.0, 18.0],
]
const GALERIE := Rect2(-5, -80, 10, 40)
## Les quatre mécanismes d'arbalètes de la galerie (F pour les bloquer).
const MECANISMES := [Vector2(-4.4, -72), Vector2(4.4, -64), Vector2(-4.4, -56), Vector2(4.4, -48)]
const INTERVALLE_VOLEE := 3.2
const PREAVIS_VOLEE := 1.5
const LARGEUR_VOLEE := 3.0
## Les fleuves de mercure de la salle du même nom (un peu plus bas que le sol) et leurs ponts.
const FLEUVES := [Rect2(-20, -34, 40, 3), Rect2(-20, -21, 40, 3)]
const PONTS := [Rect2(-2, -40, 4, 30), Rect2(-15, -40, 3, 30), Rect2(12, -40, 3, 30)]
const PROFONDEUR_FLEUVE := 0.7
## Le palais souterrain.
const PALAIS := Rect2(-30, 2, 60, 56)
const COEUR := Vector2(0, 44)
const STATUE := Vector2(0, 52)
const PILIERS := [Vector2(-12, 14), Vector2(12, 14), Vector2(-20, 28), Vector2(20, 28), Vector2(-12, 34), Vector2(12, 34)]
const PIEDESTAUX := [Vector2(-24, 10), Vector2(24, 10), Vector2(-24, 46), Vector2(24, 46)]
const BUCHERS := [Vector2(-15, 20), Vector2(15, 20), Vector2(-15, 38), Vector2(15, 38)]
const PORTE_PALAIS := Vector2(0, 4)
## Phase 2 : les deux paires de canaux de mercure du palais (bandes en travers, en z).
const MERCURE_A := [Vector2(10, 16), Vector2(24, 30)]
const MERCURE_B := [Vector2(17, 23), Vector2(32, 39)]
const DUREE_FLEUVE := 9.0
const PREAVIS_FLEUVE := 2.5
const RALLUMAGE := 22.0
const RAYON_FUMEE := 6.0
const RENFORTS := 16.0

var _attente_sortie := 0.0
var _lampe_joueur: OmniLight3D
var _lumieres: Array[OmniLight3D] = []

# L'état du donjon (le serveur décide ; chacun voit l'état reçu par _etat_tombeau).
var _boss: Node3D
var _phase := 0
var _desarmes := 0
var _volee_galerie := 0.0
var _volee_galerie_z := 0.0
var _prochaine_volee_galerie := 0.0
var _volee := 0.0
var _volee_z := 0.0
var _prochaine_volee := 0.0
var _jeu_mercure := 0
var _bascule_mercure := 0.0
var _buchers := 0
var _rallumer: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _prochains_renforts := 0.0
var _prochain_tic := 0.0
var _prochain_envoi := 0.0
var _victoire := false
var _boss_vu := false
## Le géant s'est effondré pour ce joueur (sa quête a passé le combat : voir effondrer()).
var _effondre := false
# Les pièces du décor.
var _mecanismes: Array[Node3D] = []
var _buchers_objets: Array[Node3D] = []
var _bande_galerie: MeshInstance3D
var _bande_palais: MeshInstance3D
var _canaux: Array[MeshInstance3D] = []
var _statue: Node3D
var _gravats: Node3D
var _cinabre_tete: Node3D
var _masque_porte: Node3D


func _init() -> void:
	identifiant_zone = "tombeau"
	taille_terrain = 240
	graine = 1250
	point_apparition = ENTREE
	nombre_touffes = 0
	neige_qui_tombe = false
	ambiance_grandiose = false
	ciel = ""


func _ready() -> void:
	# Un donjon : pas de monture à l'intérieur (voir le script des montures).
	add_to_group("donjon")
	# La quête appelle effondrer() sur la zone elle-même (« appeler » : empereur_argile).
	add_to_group("decor_quete")
	set_meta("identifiant", "empereur_argile")
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_chine", "") != "":
		Reseau.remove_meta("arrivee_chine")
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	if zone == "tombeau":
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
	var h := meilleur if meilleur > -INF else repli
	if dans_le_mercure(x, z):
		h -= PROFONDEUR_FLEUVE
	return h


## Dans un fleuve de mercure de la salle des fleuves (et pas sur un pont).
func dans_le_mercure(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	for f: Rect2 in FLEUVES:
		if f.has_point(p):
			for pont: Rect2 in PONTS:
				if pont.has_point(p):
					return false
			return true
	return false


# --- Construction --------------------------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_lumieres.clear()
	_mecanismes.clear()
	_buchers_objets.clear()
	_canaux.clear()
	_construire_salles()
	_construire_galerie()
	_construire_fleuves()
	_construire_palais()
	_construire_statue()
	_construire_quete()
	_construire_limites()
	_eclairer()


func _dossier(nom: String) -> Node3D:
	var d := Node3D.new()
	d.name = nom
	_contenu.add_child(d)
	return d


func _mat_pierre_tombeau() -> StandardMaterial3D:
	return _mat_choix(["stacked_stone_wall", "old_stone_wall"], Color(0.42, 0.38, 0.36), 0.95, 2.5)


func _mat_bronze() -> StandardMaterial3D:
	var m := _mat_pbr("", Color(0.36, 0.4, 0.28), 0.4)
	m.metallic = 0.7
	return m


func _mat_mercure() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.78, 0.8, 0.84)
	m.metallic = 1.0
	m.roughness = 0.06
	m.emission_enabled = true
	m.emission = Color(0.35, 0.3, 0.5)
	m.emission_energy_multiplier = 0.4
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


## Les salles : sol de dalles, plafond, murs de pierre, avec un passage vers chaque voisine.
## La salle des fleuves a un sol découpé : les canaux de mercure sont plus bas.
func _construire_salles() -> void:
	var d := _dossier("Salles")
	var mur := _mat_pierre_tombeau()
	var sol := _mat_choix(["cobblestone_floor_04", "stacked_stone_wall"], Color(0.4, 0.37, 0.34), 0.9, 2.5)
	var plafond := _mat_pbr("", Color(0.06, 0.06, 0.1), 1.0)
	for i in ESPACES.size():
		var e: Array = ESPACES[i]
		var r: Rect2 = e[1]
		var h := float(e[4])
		var g := Node3D.new()
		g.name = String(e[0]).capitalize().replace(" ", "")
		d.add_child(g)
		if String(e[0]) == "fleuves":
			# Le sol par bandes : la terre ferme entre les canaux, et le fond des canaux.
			var bornes := [r.position.y]
			for f: Rect2 in FLEUVES:
				bornes.append(f.position.y)
				bornes.append(f.end.y)
			bornes.append(r.end.y)
			for k in range(0, bornes.size() - 1):
				var z0: float = bornes[k]
				var z1: float = bornes[k + 1]
				var canal := k % 2 == 1
				var y := SOL - (PROFONDEUR_FLEUVE if canal else 0.0)
				_boite(Vector3(r.size.x, 1.0, z1 - z0), Vector3(r.get_center().x, y - 0.5, (z0 + z1) * 0.5), mur if canal else sol, g)
			# Les ponts de pierre au-dessus des canaux.
			for f: Rect2 in FLEUVES:
				for pont: Rect2 in PONTS:
					_boite(Vector3(pont.size.x, PROFONDEUR_FLEUVE, f.size.y), Vector3(pont.get_center().x, SOL - PROFONDEUR_FLEUVE * 0.5, f.get_center().y), sol, g)
		else:
			_dalle(g, e, 0.0, 1.0, sol)
		_dalle(g, e, h, 1.0, plafond if String(e[0]) == "palais" else mur, false, 1.0)
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
	# Des marches dans la descente (sans collision : la pente suffit).
	var e0: Array = ESPACES[0]
	var r0: Rect2 = e0[1]
	var n := int(r0.size.y / 0.6)
	for k in n:
		var z := r0.position.y + (k + 0.5) * r0.size.y / n
		_boite(Vector3(r0.size.x, 0.12, 0.25), Vector3(r0.get_center().x, _sol_espace(e0, z) + 0.04, z), mur, d, false)
	# Les poutres de soutènement que Cinabre a posées dans sa galerie.
	var bois := _mat_bois()
	var z := r0.position.y + 2.0
	while z < r0.end.y:
		var y := _sol_espace(e0, z)
		for c: float in [-1.0, 1.0]:
			_boite(Vector3(0.25, 3.8, 0.25), Vector3(c * 1.8, y + 1.9, z), bois, d, false)
		_boite(Vector3(4.0, 0.25, 0.3), Vector3(0, y + 3.8, z), bois, d, false)
		z += 4.0
	_fusionner(d)


## Une lampe « qui ne s'éteint jamais » (Sima Qian : de la graisse de « poisson-homme ») :
## une coupe de bronze sur un pied, une flamme, une lumière chaude.
func _lampe(parent: Node3D, p: Vector3, haute := true) -> void:
	var pied := MeshInstance3D.new()
	pied.mesh = _cylindre(0.05, 0.12, 1.4 if haute else 0.3, 8)
	pied.material_override = _mat_bronze()
	pied.position = p + Vector3(0, (1.4 if haute else 0.3) * 0.5, 0)
	parent.add_child(pied)
	var y := (1.4 if haute else 0.3)
	var coupe := MeshInstance3D.new()
	coupe.mesh = _cylindre(0.28, 0.12, 0.16, 10)
	coupe.material_override = _mat_bronze()
	coupe.position = p + Vector3(0, y + 0.08, 0)
	parent.add_child(coupe)
	var flamme := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.1
	s.height = 0.3
	flamme.mesh = s
	flamme.material_override = _lumineux(Color(1.0, 0.62, 0.26), 6.0)
	flamme.position = p + Vector3(0, y + 0.28, 0)
	parent.add_child(flamme)
	var lumiere := OmniLight3D.new()
	lumiere.light_color = Color(1.0, 0.62, 0.32)
	lumiere.light_energy = 1.7
	lumiere.omni_range = 10.0
	lumiere.omni_attenuation = 1.3
	lumiere.position = p + Vector3(0, y + 0.6, 0)
	lumiere.shadow_enabled = _lumieres.size() % 4 == 0
	parent.add_child(lumiere)
	_lumieres.append(lumiere)


## Une bande au sol (avertissement d'une volée, ou un canal de mercure du palais).
func _bande(parent: Node3D, taille: Vector2, couleur: Color, energie: float) -> MeshInstance3D:
	var bande := MeshInstance3D.new()
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


## La galerie des arbalètes : des niches dans les deux murs, chacune avec son arbalète de
## bronze pointée vers le couloir ; les quatre mécanismes qui les commandent.
func _construire_galerie() -> void:
	var d := _dossier("Galerie")
	var bronze := _mat_bronze()
	var bois := _mat_pbr("", Color(0.22, 0.12, 0.07), 0.6)
	var z := GALERIE.position.y + 3.0
	var k := 0
	while z < GALERIE.end.y - 2.0:
		for c: float in [-1.0, 1.0]:
			var x := c * (GALERIE.size.x * 0.5 - 0.15)
			# La niche (un trou noir), l'arbalète couchée, l'arc de bronze.
			_boite(Vector3(0.2, 0.9, 1.4), Vector3(x, SOL + 1.6, z), _mat_pbr("", Color(0.02, 0.02, 0.02), 1.0), d, false)
			_boite(Vector3(0.9, 0.12, 0.14), Vector3(x - c * 0.45, SOL + 1.5, z), bois, d, false)
			_boite(Vector3(0.08, 0.06, 1.1), Vector3(x - c * 0.8, SOL + 1.55, z), bronze, d, false)
		if k % 3 == 1:
			_lampe(d, Vector3(GALERIE.position.x + 0.8 if k % 2 == 0 else GALERIE.end.x - 0.8, SOL, z + 1.5), true)
		z += 3.0
		k += 1
	_bande_galerie = _bande(d, Vector2(GALERIE.size.x - 0.4, LARGEUR_VOLEE), Color(1.0, 0.15, 0.08, 0.35), 2.0)
	_bande_galerie.name = "VoleeGalerie"
	_fusionner(d)


## La salle des fleuves : le mercure dans ses canaux, les chars de bronze sur les rives, les
## lampes, et la vapeur qui monte.
func _construire_fleuves() -> void:
	var d := _dossier("Fleuves")
	var e: Array = ESPACES[2]
	var r: Rect2 = e[1]
	for f: Rect2 in FLEUVES:
		var surface := MeshInstance3D.new()
		var plan := PlaneMesh.new()
		plan.size = f.size
		surface.mesh = plan
		surface.material_override = _mat_mercure()
		surface.position = Vector3(f.get_center().x, SOL - 0.25, f.get_center().y)
		d.add_child(surface)
		_vapeur_mercure(d, Vector3(f.get_center().x - 10, SOL - 0.1, f.get_center().y), 2.0)
		_vapeur_mercure(d, Vector3(f.get_center().x + 10, SOL - 0.1, f.get_center().y), 2.0)
	# Des chars de bronze à quatre chevaux (comme ceux qu'on a retrouvés au mont Li), à l'arrêt.
	var bronze := _mat_bronze()
	for q: Vector2 in [Vector2(-10, -27.5), Vector2(10, -27.5), Vector2(-10, -14)]:
		_boite(Vector3(1.4, 0.5, 1.2), Vector3(q.x, SOL + 0.9, q.y), bronze, d)
		var parasol := MeshInstance3D.new()
		parasol.mesh = _cylindre(0.05, 1.0, 0.25, 16)
		parasol.material_override = bronze
		parasol.position = Vector3(q.x, SOL + 2.4, q.y)
		d.add_child(parasol)
		for c: float in [-1.0, 1.0]:
			var roue := MeshInstance3D.new()
			roue.mesh = _cylindre(0.55, 0.55, 0.08, 16)
			roue.material_override = bronze
			roue.position = Vector3(q.x + c * 0.8, SOL + 0.55, q.y)
			roue.rotation.z = PI / 2
			d.add_child(roue)
		for k in 2:
			_cheval_argile(d, Vector3(q.x - 0.5 + k, SOL, q.y - 2.8), PI)
	for k in 6:
		_lampe(d, Vector3(r.position.x + 1.0 if k % 2 == 0 else r.end.x - 1.0, SOL, r.position.y + 3.0 + (k / 2) * 12.0))
	_fusionner(d)


## Le palais souterrain : le plafond d'étoiles, les piliers laqués, les piédestaux vides, les
## lampes, et les bandes des volées et des canaux de mercure.
func _construire_palais() -> void:
	var d := _dossier("Palais")
	var r := PALAIS
	var h := float(ESPACES[4][4])
	var laque := _mat_laque()
	for p: Vector2 in PILIERS:
		_boite(Vector3(1.6, h, 1.6), Vector3(p.x, SOL + h * 0.5, p.y), laque, d)
		_boite(Vector3(2.2, 0.5, 2.2), Vector3(p.x, SOL + 0.25, p.y), _mat_pierre_tombeau(), d, false)
	for p: Vector2 in PIEDESTAUX:
		_boite(Vector3(2.0, 0.8, 2.0), Vector3(p.x, SOL + 0.4, p.y), _mat_pierre_tombeau(), d)
	# Le cercueil de pierre, au pied du géant, fendu par la fracture.
	_boite(Vector3(4.0, 1.4, 2.4), Vector3(COEUR.x, SOL + 0.7, COEUR.y + 3.0), _mat_pierre_tombeau(), d)
	for k in 10:
		var x := r.position.x + 1.0 if k % 2 == 0 else r.end.x - 1.0
		_lampe(d, Vector3(x, SOL, r.position.y + 4.0 + (k / 2) * 11.0))
	_fusionner(d)
	# Le plafond d'étoiles : des perles qui brillent (une seule MultiMesh).
	var etoiles := MultiMeshInstance3D.new()
	etoiles.name = "Etoiles"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var perle := SphereMesh.new()
	perle.radius = 0.06
	perle.height = 0.12
	perle.radial_segments = 6
	perle.rings = 3
	mm.mesh = perle
	mm.instance_count = 900
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine
	for i in mm.instance_count:
		var t := Transform3D(Basis().scaled(Vector3.ONE * hasard.randf_range(0.6, 1.8)),
				Vector3(hasard.randf_range(r.position.x + 1, r.end.x - 1), SOL + h - 0.08, hasard.randf_range(r.position.y + 1, r.end.y - 1)))
		mm.set_instance_transform(i, t)
	etoiles.multimesh = mm
	etoiles.material_override = _lumineux(Color(0.92, 0.9, 1.0), 3.5)
	etoiles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_contenu.add_child(etoiles)
	# Les bandes : la volée de flèches (phase 1) et les canaux de mercure (phase 2).
	var bandes := _dossier("BandesPalais")
	_bande_palais = _bande(bandes, Vector2(r.size.x - 1.0, LARGEUR_VOLEE), Color(1.0, 0.15, 0.08, 0.35), 2.0)
	_bande_palais.name = "VoleePalais"
	for jeu in [MERCURE_A, MERCURE_B]:
		for z: Vector2 in jeu:
			var canal := _bande(bandes, Vector2(r.size.x - 1.0, z.y - z.x), Color(0.8, 0.82, 0.88, 0.85), 0.5)
			var m := canal.material_override as StandardMaterial3D
			m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			m.metallic = 1.0
			m.roughness = 0.06
			canal.position = Vector3(r.get_center().x, SOL + 0.05, (z.x + z.y) * 0.5)
			_canaux.append(canal)


## L'Empereur d'argile : un géant de quinze mètres fait des soldats de son armée, assis sur
## son trône au fond du palais, la coiffe impériale à rideau de perles, le corps fendu de
## cristal violet et de veines de mercure. Il tombe en morceaux quand le cœur est brisé.
func _construire_statue() -> void:
	_statue = Node3D.new()
	_statue.name = "EmpereurArgile"

	_statue.position = Vector3(STATUE.x, SOL, STATUE.y)
	_statue.rotation.y = PI
	_contenu.add_child(_statue)
	var argile := _mat_terre_cuite_grise()
	var sombre := _mat_pbr("", Color(0.38, 0.32, 0.28), 0.95)
	var violet := _lumineux(Color(0.62, 0.3, 1.0), 4.0)
	var mercure := _mat_mercure()
	# Le trône et les jambes.
	_boite(Vector3(10.0, 4.0, 5.0), Vector3(0, 2.0, 0.5), sombre, _statue)
	for c: float in [-1.0, 1.0]:
		var cuisse := MeshInstance3D.new()
		cuisse.mesh = _cylindre(1.0, 1.1, 4.0, 10)
		cuisse.material_override = argile
		cuisse.position = Vector3(c * 1.6, 4.6, -1.4)
		cuisse.rotation.x = PI / 2
		_statue.add_child(cuisse)
		var tibia := MeshInstance3D.new()
		tibia.mesh = _cylindre(0.9, 1.0, 4.6, 10)
		tibia.material_override = argile
		tibia.position = Vector3(c * 1.6, 2.3, -3.4)
		_statue.add_child(tibia)
	# Le torse, en rangées de lamelles (des soldats fondus), la ceinture.
	var torse := MeshInstance3D.new()
	torse.mesh = _cylindre(2.4, 2.9, 5.2, 12)
	torse.material_override = argile
	torse.position = Vector3(0, 7.6, 0.4)
	_statue.add_child(torse)
	for k in 6:
		var rang := MeshInstance3D.new()
		rang.mesh = _cylindre(2.5 + k * 0.08, 2.5 + k * 0.08, 0.18, 12)
		rang.material_override = sombre
		rang.position = Vector3(0, 5.6 + k * 0.7, 0.4)
		_statue.add_child(rang)
	# Les bras posés sur les genoux, les mains qui tiennent une épée de bronze.
	for c: float in [-1.0, 1.0]:
		var bras := MeshInstance3D.new()
		bras.mesh = _cylindre(0.7, 0.8, 4.4, 10)
		bras.material_override = argile
		bras.position = Vector3(c * 3.0, 7.4, -0.6)
		bras.rotation = Vector3(0.6, 0, c * 0.25)
		_statue.add_child(bras)
		var main := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.8
		s.height = 1.4
		main.mesh = s
		main.material_override = argile
		main.position = Vector3(c * 1.0, 5.6, -2.8)
		_statue.add_child(main)
	_boite(Vector3(0.3, 7.0, 0.2), Vector3(0, 3.6, -3.4), _mat_bronze(), _statue, false)
	# La tête et la coiffe impériale (le « mianguan ») : une planche plate, des rideaux de perles.
	var tete := MeshInstance3D.new()
	var t := SphereMesh.new()
	t.radius = 1.4
	t.height = 3.0
	tete.mesh = t
	tete.material_override = argile
	tete.position = Vector3(0, 11.6, 0.2)
	_statue.add_child(tete)
	_boite(Vector3(1.4, 0.9, 1.4), Vector3(0, 13.2, 0.2), sombre, _statue, false)
	_boite(Vector3(2.6, 0.12, 4.0), Vector3(0, 13.7, 0.2), _mat_laque(), _statue, false)
	var perle := _lumineux(Color(0.95, 0.85, 0.6), 1.2)
	for sens: float in [-1.0, 1.0]:
		for k in 9:
			var fil := MeshInstance3D.new()
			fil.mesh = _cylindre(0.035, 0.035, 1.3, 4)
			fil.material_override = perle
			fil.position = Vector3(-1.1 + k * 0.275, 13.0, 0.2 + sens * 1.95)
			_statue.add_child(fil)
	for c: float in [-1.0, 1.0]:
		var oeil := MeshInstance3D.new()
		var o := SphereMesh.new()
		o.radius = 0.16
		o.height = 0.2
		oeil.mesh = o
		oeil.material_override = violet
		oeil.position = Vector3(c * 0.5, 11.9, -1.15)
		_statue.add_child(oeil)
	# Les fissures de cristal violet et les veines de mercure qui coulent.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 7
	for k in 14:
		var fente := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.12, hasard.randf_range(0.8, 2.4), 0.12)
		fente.mesh = b
		fente.material_override = violet if k % 2 == 0 else mercure
		var a := hasard.randf() * TAU
		fente.position = Vector3(cos(a) * 2.7, hasard.randf_range(5.6, 10.0), 0.4 + sin(a) * 2.7)
		fente.rotation = Vector3(hasard.randf_range(-0.5, 0.5), 0, hasard.randf_range(-0.6, 0.6))
		_statue.add_child(fente)
	var lueur := OmniLight3D.new()
	lueur.light_color = Color(0.6, 0.35, 1.0)
	lueur.light_energy = 3.0
	lueur.omni_range = 16.0
	lueur.position = Vector3(0, 8.0, -3.0)
	_statue.add_child(lueur)
	# Cinabre, debout sur la tête du géant pendant le grand autodafé (phase 3).
	_cinabre_tete = Node3D.new()
	_cinabre_tete.name = "CinabreSurLaTete"
	_cinabre_tete.position = Vector3(0, 13.8, 0.2)
	_cinabre_tete.visible = false
	_statue.add_child(_cinabre_tete)
	var manteau := MeshInstance3D.new()
	manteau.mesh = _cylindre(0.18, 0.4, 1.5, 10)
	manteau.material_override = _mat_pbr("", Color(0.55, 0.08, 0.06), 0.8)
	manteau.position.y = 0.75
	_cinabre_tete.add_child(manteau)
	var visage := MeshInstance3D.new()
	var v := SphereMesh.new()
	v.radius = 0.13
	v.height = 0.28
	visage.mesh = v
	visage.material_override = _mat_pbr("", Color(0.88, 0.76, 0.66), 0.7)
	visage.position.y = 1.65
	_cinabre_tete.add_child(visage)
	var torche := OmniLight3D.new()
	torche.light_color = Color(1.0, 0.45, 0.2)
	torche.light_energy = 2.5
	torche.omni_range = 8.0
	torche.position = Vector3(0.4, 1.9, 0)
	_cinabre_tete.add_child(torche)
	# Une collision simple : on ne traverse pas le trône.
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(10.0, 14.0, 6.0)
	forme.shape = boite
	forme.position = Vector3(0, 7.0, 0.0)
	corps.add_child(forme)
	_statue.add_child(corps)
	# Les gravats, quand le géant s'effondre.
	_gravats = Node3D.new()
	_gravats.name = "Gravats"
	_gravats.position = _statue.position
	_gravats.visible = false
	_contenu.add_child(_gravats)
	for k in 26:
		var morceau := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(hasard.randf_range(0.6, 2.2), hasard.randf_range(0.4, 1.4), hasard.randf_range(0.6, 2.2))
		morceau.mesh = m
		morceau.material_override = argile if k % 3 != 0 else sombre
		morceau.position = Vector3(hasard.randf_range(-6, 6), m.size.y * 0.4, hasard.randf_range(-5, 3))
		morceau.rotation = Vector3(hasard.randf() * 0.6, hasard.randf() * TAU, hasard.randf() * 0.6)
		_gravats.add_child(morceau)
	_boite(Vector3(10.0, 4.0, 5.0), Vector3(0, 2.0, 0.5), sombre, _gravats)


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


func _construire_quete() -> void:
	var dossier := _dossier("Quete")
	_dossier_quete = dossier
	# Les mécanismes de la galerie : un mécanisme de boss (la zone s'en occupe).
	for k in MECANISMES.size():
		var p: Vector2 = MECANISMES[k]
		var o := ObjetChine.new()
		o.name = "Mecanisme%d" % k
		o.identifiant = "mecanisme_%d" % k
		o.forme = "mecanisme_arbalete"
		o.invite = "[F] Bloquer le mécanisme des arbalètes"
		o.portee = 2.4
		o.position = Vector3(p.x, SOL, p.y)
		o.rotation.y = PI / 2 if p.x < 0.0 else -PI / 2
		o.set_meta("donjon", true)
		dossier.add_child(o)
		_mecanismes.append(o)
	# Les bûchers de livres du grand autodafé (phase 3).
	for k in BUCHERS.size():
		var p: Vector2 = BUCHERS[k]
		var o := ObjetChine.new()
		o.name = "Bucher%d" % k
		o.identifiant = "bucher_%d" % k
		o.forme = "bucher_livres"
		o.invite = "[F] Étouffer le bûcher sous le papier mouillé de Cai Lun"
		o.portee = 3.0
		o.position = Vector3(p.x, SOL, p.y)
		o.set_meta("donjon", true)
		o.visible = false
		dossier.add_child(o)
		_buchers_objets.append(o)
	# La fracture majeure, dans le cercueil fendu.
	var faille := Faille.new()
	faille.name = "FractureEmpereur"
	faille.identifiant = "fracture_empereur"
	faille.position = Vector3(COEUR.x, SOL, COEUR.y + 1.2)
	dossier.add_child(faille)
	# Après la victoire : Cinabre à genoux, et Masque.
	_pnj_cache(dossier, "cinabre_tombeau", COEUR + Vector2(-4, -4), PI)
	_pnj_cache(dossier, "masque_carnet", COEUR + Vector2(4, -5), PI * 1.2)
	_objet_carnet(dossier)
	# Masque tient la porte du palais pendant le grand autodafé.
	_masque_porte = _pnj(dossier, "masque_porte_palais", PORTE_PALAIS, 0.0)
	_masque_porte.visible = false
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.LIEU, "Galerie des arbalètes", GALERIE.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Salle des fleuves de mercure", Vector2(0, -25))
	repere.call(MarqueurCarte.Type.LIEU, "Palais souterrain", Vector2(0, 26))
	repere.call(MarqueurCarte.Type.LIEU, "Sortie (mont Li)", ENTREE)


## Le carnet de l'Éditeur, tombé de la poche de Cinabre (si l'on se méfiait de Masque,
## c'est le joueur qui le ramasse).
func _objet_carnet(dossier: Node3D) -> void:
	var o := ObjetChine.new()
	o.name = "CarnetEditeur"
	o.identifiant = "carnet_editeur"
	o.forme = "carnet"
	o.invite = "[F] Ramasser le carnet de l'Éditeur"
	o.portee = 2.4
	o.position = Vector3(COEUR.x - 2.0, SOL, COEUR.y - 6.0)
	o.add_to_group("decor_quete")
	o.set_meta("identifiant", "carnet_editeur")
	o.visible = false
	dossier.add_child(o)


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
	env.background_color = Color(0.008, 0.008, 0.014)
	env.sky = null
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.37, 0.44)
	env.ambient_light_energy = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.3
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.06, 0.05, 0.08)
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
			l.light_energy = 1.7 + sin(_temps * 7.0 + k * 1.3) * 0.15 + sin(_temps * 17.0 + k) * 0.08
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
		quete.changer_de_zone("mont_li")


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
		if String(bete.get("type_ennemi")) == "coeur_empereur":
			_boss = bete
	return _boss


func _joueurs_vivants(r: Rect2) -> Array:
	var liste: Array = []
	for j in get_tree().get_nodes_in_group("joueur"):
		var c = j.get_node_or_null("Combat")
		if c != null and c.est_vivant() and r.has_point(Vector2(j.global_position.x, j.global_position.z)):
			liste.append(j)
	return liste


## Le nombre de bûchers allumés.
func buchers_allumes() -> int:
	var n := 0
	for k in BUCHERS.size():
		if _buchers & (1 << k):
			n += 1
	return n


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
		_etat_tombeau.rpc(_phase, _desarmes, _volee_galerie_z if _volee_galerie > 0.0 else INF,
				_volee_z if _volee > 0.0 else INF, _jeu_mercure, _buchers, _victoire)


## La galerie des arbalètes : tant qu'un mécanisme marche, des volées balaient le couloir.
func _diriger_galerie(t: float) -> void:
	if _desarmes == (1 << MECANISMES.size()) - 1:
		_volee_galerie = 0.0
		return
	var joueurs := _joueurs_vivants(GALERIE)
	if joueurs.is_empty():
		_volee_galerie = 0.0
		return
	if _volee_galerie <= 0.0 and t >= _prochaine_volee_galerie:
		var cible: Node3D = joueurs[Regles.aleatoire.randi() % joueurs.size()]
		_volee_galerie_z = clampf(cible.global_position.z + Regles.aleatoire.randf_range(-1.0, 1.0), GALERIE.position.y + 1.5, GALERIE.end.y - 1.5)
		_volee_galerie = t + PREAVIS_VOLEE
	elif _volee_galerie > 0.0 and t >= _volee_galerie:
		_volee_galerie = 0.0
		_prochaine_volee_galerie = t + INTERVALLE_VOLEE
		for j in joueurs:
			if absf(j.global_position.z - _volee_galerie_z) < LARGEUR_VOLEE * 0.5:
				var c = j.get_node("Combat")
				Regles.infliger(null, c, c.pv_max * 0.22, "periodique")
		_tirer.rpc(_volee_galerie_z, true)


func _diriger_boss(boss: Node3D, t: float) -> void:
	var combat = boss.combat
	var joueurs := _joueurs_vivants(PALAIS)
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
	# Phase 1 : les volées d'arbalètes en lignes, et des soldats qui sortent des piédestaux.
	if _phase == 1:
		if _volee <= 0.0 and t >= _prochaine_volee:
			var cible: Node3D = joueurs[Regles.aleatoire.randi() % joueurs.size()]
			_volee_z = clampf(cible.global_position.z + Regles.aleatoire.randf_range(-1.5, 1.5), PALAIS.position.y + 3.0, PALAIS.end.y - 8.0)
			_volee = t + PREAVIS_VOLEE + 0.4
		elif _volee > 0.0 and t >= _volee:
			_volee = 0.0
			_prochaine_volee = t + INTERVALLE_VOLEE + 1.5
			for j in joueurs:
				if absf(j.global_position.z - _volee_z) < LARGEUR_VOLEE * 0.5:
					var c = j.get_node("Combat")
					Regles.infliger(combat, c, c.pv_max * 0.28, "periodique")
			_tirer.rpc(_volee_z, false)
	if _phase < 3 and t >= _prochains_renforts:
		_prochains_renforts = t + RENFORTS
		_renforts(2)
	# Phase 2 : les canaux de mercure se remplissent tour à tour.
	if _phase == 2 and t >= _bascule_mercure:
		_bascule_mercure = t + DUREE_FLEUVE
		_jeu_mercure = 2 if _jeu_mercure == 1 else 1
	# Phase 3 : les bûchers se rallument ; l'Empereur ne craint rien tant que trois brûlent.
	if _phase == 3:
		for k in BUCHERS.size():
			if not (_buchers & (1 << k)) and _rallumer[k] > 0.0 and t >= _rallumer[k]:
				_buchers |= 1 << k
				_rallumer[k] = 0.0
		if buchers_allumes() >= 3:
			combat.ajouter_effet("evite", 1.0)
		elif combat.effets.has("evite"):
			combat.retirer_effet("evite")


## Ce qui fait mal chaque seconde : le mercure (salle des fleuves et canaux du palais) et la
## fumée des bûchers (plus de compétences).
func _tic_degats() -> void:
	var boss := _trouver_boss()
	var source = boss.combat if boss != null and is_instance_valid(boss) else null
	for j in get_tree().get_nodes_in_group("joueur"):
		var c = j.get_node_or_null("Combat")
		if c == null or not c.est_vivant():
			continue
		var p := Vector2(j.global_position.x, j.global_position.z)
		if dans_le_mercure(p.x, p.y) and j.global_position.y < SOL - 0.2:
			Regles.infliger(null, c, c.pv_max * 0.06, "periodique")
		if not PALAIS.has_point(p):
			continue
		# Un canal qui vient de se remplir ne fait mal qu'après un court préavis.
		var depuis := Regles.maintenant() - (_bascule_mercure - DUREE_FLEUVE)
		if _phase == 2 and _jeu_mercure > 0 and depuis >= PREAVIS_FLEUVE:
			for z: Vector2 in (MERCURE_A if _jeu_mercure == 1 else MERCURE_B):
				if p.y >= z.x and p.y <= z.y:
					Regles.infliger(source, c, c.pv_max * 0.08, "periodique")
		if _phase == 3:
			for k in BUCHERS.size():
				if _buchers & (1 << k) and p.distance_to(BUCHERS[k]) < RAYON_FUMEE:
					c.ajouter_effet("fumee_autodafe", 1.3)


func _entrer_phase(phase: int, t: float) -> void:
	_phase = phase
	if phase == 1:
		_prochaine_volee = t + 4.0
		_prochains_renforts = t + 8.0
		_annonce.rpc("Les arbalètes du tombeau", "L'Empereur d'argile ouvre les yeux. Dans les murs, des arbalètes se tendent : quand une bande rouge s'allume au sol, sors-en vite ! Et brisez les soldats qui sortent des piédestaux.")
	elif phase == 2:
		_volee = 0.0
		_jeu_mercure = 1
		_bascule_mercure = t + DUREE_FLEUVE
		_annonce.rpc("Les fleuves de mercure", "Le géant frappe le sol : le mercure jaillit et coule en fleuves dans le palais. Les canaux se remplissent tour à tour : ne reste pas dedans !")
	elif phase == 3:
		_jeu_mercure = 0
		_buchers = (1 << BUCHERS.size()) - 1
		for k in BUCHERS.size():
			_rallumer[k] = 0.0
		_annonce.rpc("Le grand autodafé", "Cinabre est montée sur la tête du géant et jette des torches : quatre bûchers de livres s'allument ! Leur fumée bloque vos compétences, et tant que trois brûlent, l'Empereur ne craint rien. Étouffez-les (F) avec le papier mouillé de Cai Lun ! Masque tient la porte.")


func _renforts(nombre: int) -> void:
	var dossier := get_tree().get_first_node_in_group("dossier_loups")
	var quete := get_tree().get_first_node_in_group("quete")
	if dossier == null or quete == null:
		return
	var vivants := 0
	for bete in get_tree().get_nodes_in_group("loups"):
		if String(bete.get("type_ennemi")) == "soldat_argile_piedestal" and bete.combat.est_vivant():
			vivants += 1
	for i in mini(nombre, 4 - vivants):
		var p: Vector2 = PIEDESTAUX[Regles.aleatoire.randi() % PIEDESTAUX.size()]
		var position := Vector3(p.x, SOL + 1.0, p.y)
		var soldat = quete.SCENE_LOUP.instantiate()
		soldat.name = "Renfort_%d_%d" % [Time.get_ticks_msec() % 100000, i]
		soldat.type_ennemi = "soldat_argile_piedestal"
		soldat.position = position
		soldat.camp = position
		soldat.position_reseau = position
		soldat.set_meta("unique", true)
		dossier.add_child(soldat, true)


## Fin du combat : victoire (le cœur est brisé) ou défaite (tout le monde est tombé).
func _finir(victoire: bool) -> void:
	_phase = 0
	_volee = 0.0
	_jeu_mercure = 0
	_buchers = 0
	if victoire:
		_victoire = true
	else:
		var boss := _trouver_boss()
		if boss != null and boss.combat.effets.has("evite"):
			boss.combat.retirer_effet("evite")
	_etat_tombeau.rpc(_phase, _desarmes, INF, INF, 0, 0, _victoire)


## Appelé par un mécanisme de la galerie ou un bûcher (F) : le serveur décide.
func utiliser_objet(objet: Node3D) -> void:
	Regles.au_serveur(self, "_utiliser", [String(objet.name)])


@rpc("any_peer", "call_remote", "reliable")
func _utiliser(nom: String) -> void:
	if not multiplayer.is_server():
		return
	if nom.begins_with("Mecanisme"):
		var k := int(nom.substr(9))
		if not (_desarmes & (1 << k)):
			_desarmes |= 1 << k
			var reste := MECANISMES.size() - _compter(_desarmes)
			_annonce.rpc("Un mécanisme bloqué", "Le mécanisme grince et se fige. Plus que %d." % reste if reste > 0
					else "Le dernier mécanisme se fige. Les arbalètes de la galerie se taisent.")
	elif nom.begins_with("Bucher") and _phase == 3:
		var k := int(nom.substr(6))
		if _buchers & (1 << k):
			_buchers &= ~(1 << k)
			_rallumer[k] = Regles.maintenant() + RALLUMAGE
	_etat_tombeau.rpc(_phase, _desarmes, _volee_galerie_z if _volee_galerie > 0.0 else INF,
			_volee_z if _volee > 0.0 else INF, _jeu_mercure, _buchers, _victoire)


func _compter(masque: int) -> int:
	var n := 0
	while masque > 0:
		n += masque & 1
		masque >>= 1
	return n


# --- Ce que tout le monde voit -------------------------------------------------------------------

@rpc("authority", "call_local", "unreliable_ordered")
func _etat_tombeau(phase: int, desarmes: int, galerie_z: float, palais_z: float, mercure: int, buchers: int, victoire: bool) -> void:
	if not multiplayer.is_server():
		_phase = phase
		_desarmes = desarmes
		_jeu_mercure = mercure
		_buchers = buchers
		_victoire = victoire
	for k in _mecanismes.size():
		var o = _mecanismes[k]
		var bloque := (desarmes & (1 << k)) != 0
		o.actif = not bloque
		var fige := o.get_node_or_null("Eteint") as Node3D
		if fige != null:
			fige.visible = bloque
		if o._visuel != null:
			o._visuel.visible = not bloque
	if _bande_galerie != null:
		_bande_galerie.visible = galerie_z != INF
		if galerie_z != INF:
			_bande_galerie.position = Vector3(0, SOL + 0.06, galerie_z)
	if _bande_palais != null:
		_bande_palais.visible = palais_z != INF and phase == 1
		if palais_z != INF:
			_bande_palais.position = Vector3(PALAIS.get_center().x, SOL + 0.06, palais_z)
	var jeu := MERCURE_A.size()
	for k in _canaux.size():
		var actif := (mercure == 1 and k < jeu) or (mercure == 2 and k >= jeu)
		_canaux[k].visible = phase == 2 and actif
	for k in _buchers_objets.size():
		var o = _buchers_objets[k]
		var allume := phase == 3 and (buchers & (1 << k)) != 0
		o.visible = phase == 3 or victoire
		o.actif = allume
		if o._visuel != null:
			o._visuel.visible = allume
		var eteint := o.get_node_or_null("Eteint") as Node3D
		if eteint != null:
			eteint.visible = not allume
	if _cinabre_tete != null:
		_cinabre_tete.visible = phase == 3
	if _masque_porte != null:
		_masque_porte.visible = phase == 3
	_montrer_statue(victoire or _effondre)


func _montrer_statue(tombee: bool) -> void:
	if _statue != null and _statue.visible == tombee:
		_statue.visible = not tombee
		for corps in _statue.find_children("*", "StaticBody3D", false, false):
			(corps.get_child(0) as CollisionShape3D).set_deferred("disabled", tombee)
	if _gravats != null:
		_gravats.visible = tombee


## Appelé par la quête (« appeler » : empereur_argile, methode : effondrer) : pour qui a déjà
## vaincu l'Empereur, le géant reste en morceaux, même dans une nouvelle copie du donjon.
func effondrer(_anime := true) -> void:
	_effondre = true
	_montrer_statue(true)


## Le tir d'une volée : un éclair de flèches (une ligne de petits traits) le long de la bande.
@rpc("authority", "call_local", "reliable")
func _tirer(z: float, galerie: bool) -> void:
	var largeur := GALERIE.size.x if galerie else PALAIS.size.x
	var fleches := Node3D.new()
	fleches.position = Vector3(0, SOL + 1.2, z)
	_contenu.add_child(fleches)
	var bronze := _lumineux(Color(1.0, 0.7, 0.4), 2.0)
	for k in 14:
		var fleche := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(1.2, 0.03, 0.03)
		fleche.mesh = b
		fleche.material_override = bronze
		fleche.position = Vector3(-largeur * 0.5 + (k + 0.5) * largeur / 14.0, randf_range(-0.6, 0.8), randf_range(-1.2, 1.2))
		fleches.add_child(fleche)
	get_tree().create_timer(0.35).timeout.connect(fleches.queue_free)


@rpc("authority", "call_local", "reliable")
func _annonce(titre: String, texte: String) -> void:
	var quete := get_tree().get_first_node_in_group("quete")
	if quete != null:
		quete.annoncer(titre, texte)
