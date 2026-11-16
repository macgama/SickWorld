@tool
extends "res://scripts/monde/rome/ile_rome.gd"
## Île de Rome : la Cloaca Maxima (donjon à 5 joueurs, niveau 40, chapitre 8).
##
## Le grand égout de Rome, creusé par les rois il y a sept cents ans. On y descend par la
## bouche qui s'ouvre au bord du Forum. Un long couloir voûté de tuf, un canal d'eau noire
## au milieu et deux trottoirs ; des serpents fracturés dans l'eau. Puis la grande citerne,
## une forêt de piliers de brique, où les trois vannes commandent les canaux qui inondent
## l'arène pour les batailles navales : il faut les ouvrir pour vider le canal, pendant
## que les prétoriens de Janus attaquent. Le canal remonte enfin vers l'amphithéâtre ; un
## rétiaire fracturé en garde le pied. Au bout, la herse de l'arène : le Colosse attend.
##
## Comme à l'Acropole, pas de relief : chaque salle est une boîte, et hauteur() lit le sol
## de la salle où l'on est. On entre au nord (-Z) ; l'arène est au sud (+Z).

const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const ObjetRome := preload("res://scripts/monde/rome/objet_rome.gd")

const ENTREE := Vector2(0, -81)
## Les salles : [nom, Rect2 (x, z), sol au début (z min), sol au bout (z max), hauteur sous plafond].
const ESPACES := [
	["escalier", Rect2(-1.8, -84, 3.6, 16), 0.0, -8.0, 3.4],
	["egout", Rect2(-4.5, -68, 9, 60), -8.0, -9.0, 6.0],
	["citerne", Rect2(-16, -8, 32, 26), -9.0, -9.0, 9.0],
	["canal", Rect2(-2.5, 18, 5, 40), -9.0, -1.0, 4.5],
	["herse", Rect2(-6, 58, 12, 8), -1.0, -1.0, 5.0],
]
## Le canal d'eau au milieu du grand égout (un mètre plus bas que les trottoirs).
const RIGOLE := Rect2(-1.6, -66, 3.2, 56)
const PROFONDEUR_RIGOLE := 1.0
## Les trois vannes de la citerne (ouest, est, sud-ouest), et la grille du canal.
const VANNES := [Vector2(-15.4, 0), Vector2(15.4, 0), Vector2(-8, 17.4)]
const GRILLE := Vector2(0, 18.6)
const PILIERS := [Vector2(-9, -1), Vector2(9, -1), Vector2(-9, 10), Vector2(9, 10), Vector2(0, 4)]
const SORTIE := Vector2(0, 64)
const RETIAIRE := Vector2(0, 34)

var _attente_sortie := 0.0
var _lampe_joueur: OmniLight3D
var _lumieres_torches: Array[OmniLight3D] = []
var _grille: Node3D
var _eau_canal: Node3D


func _init() -> void:
	identifiant_zone = "cloaca"
	taille_terrain = 200
	graine = 616
	point_apparition = ENTREE
	nombre_touffes = 0
	neige_qui_tombe = false
	ambiance_grandiose = false
	ciel = ""


func _ready() -> void:
	# Un donjon : pas de monture à l'intérieur (voir le script des montures).
	add_to_group("donjon")
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_rome", "") != "":
		var venu_de := String(Reseau.get_meta("arrivee_rome"))
		Reseau.remove_meta("arrivee_rome")
		point_apparition = SORTIE + Vector2(0, -7) if venu_de == "colisee" else ENTREE
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	if zone == "cloaca":
		return Vector2.INF
	return SORTIE if zone == "colisee" else ENTREE + Vector2(0, -2)


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
	if RIGOLE.has_point(p):
		h -= PROFONDEUR_RIGOLE
	return h


# --- Construction --------------------------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_lumieres_torches.clear()
	_construire_salles()
	_construire_egout()
	_construire_citerne()
	_construire_canal()
	_construire_quete()
	_construire_limites()
	_eclairer()


func _dossier(nom: String) -> Node3D:
	var d := Node3D.new()
	d.name = nom
	_contenu.add_child(d)
	return d


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


## Les salles : sol de dalles, voûte de tuf, murs de brique, avec un passage vers chaque voisine.
func _construire_salles() -> void:
	var d := _dossier("Salles")
	var mur := _mat_tuf()
	var sol := _mat_choix(["cobblestone_floor_04", "stacked_stone_wall"], Color(0.5, 0.48, 0.44), 0.9, 2.5)
	for i in ESPACES.size():
		var e: Array = ESPACES[i]
		var r: Rect2 = e[1]
		var h := float(e[4])
		var g := Node3D.new()
		g.name = String(e[0]).capitalize().replace(" ", "")
		d.add_child(g)
		if String(e[0]) == "egout":
			# Deux trottoirs de part et d'autre de la rigole.
			for cote: float in [-1.0, 1.0]:
				var largeur := (r.size.x - RIGOLE.size.x) * 0.5
				var x := cote * (RIGOLE.size.x * 0.5 + largeur * 0.5)
				var trottoir := _dalle(g, [e[0], Rect2(x - largeur * 0.5, r.position.y, largeur, r.size.y), e[2], e[3]], 0.0, 1.0, sol)
				trottoir.name = "Trottoir"
			var fond := _dalle(g, [e[0], Rect2(RIGOLE.position.x, r.position.y, RIGOLE.size.x, r.size.y), float(e[2]) - PROFONDEUR_RIGOLE,
					float(e[3]) - PROFONDEUR_RIGOLE], 0.0, 1.0, mur)
			fond.name = "FondRigole"
		else:
			_dalle(g, e, 0.0, 1.0, sol)
		_dalle(g, e, h, 1.0, mur, false, 1.0)
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
	# Des marches dans l'escalier et dans la remontée du canal (sans collision : la pente suffit).
	for i in [0, 3]:
		var e: Array = ESPACES[i]
		var r: Rect2 = e[1]
		var n := int(r.size.y / 0.6)
		for k in n:
			var z := r.position.y + (k + 0.5) * r.size.y / n
			_boite(Vector3(r.size.x, 0.12, 0.25), Vector3(r.get_center().x, _sol_espace(e, z) + 0.04, z), mur, d, false)


func _mat_eau_noire() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.03, 0.05, 0.04, 0.88)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.04
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


## Le grand égout : les arcs de la voûte, l'eau noire de la rigole, les torches.
func _construire_egout() -> void:
	var d := _dossier("Egout")
	var e: Array = ESPACES[1]
	var r: Rect2 = e[1]
	var z := r.position.y + 3.0
	var k := 0
	while z < r.end.y - 1.0:
		var sol := _sol_espace(e, z)
		var arche := MeshInstance3D.new()
		arche.mesh = _maillage_arche(r.size.x - 0.2, 0.7, 2.2)
		arche.material_override = _mat_deux_faces(_mat_brique())
		arche.position = Vector3(0, sol + float(e[4]) - 2.4, z)
		arche.rotation.y = PI * 0.5
		d.add_child(arche)
		if k % 3 == 0:
			_torche(d, Vector3(-r.size.x * 0.5 + 0.2 if k % 2 == 0 else r.size.x * 0.5 - 0.2, sol + 2.3, z + 1.5))
		k += 1
		z += 4.0
	var eau := MeshInstance3D.new()
	eau.name = "EauEgout"
	var plan := PlaneMesh.new()
	plan.size = Vector2(RIGOLE.size.x, RIGOLE.size.y)
	eau.mesh = plan
	eau.material_override = _mat_eau_noire()
	eau.position = Vector3(RIGOLE.get_center().x, (float(e[2]) + float(e[3])) * 0.5 - 0.55, RIGOLE.get_center().y)
	eau.rotation.x = _pente(e)[0]
	d.add_child(eau)
	# Les bouches des égouts secondaires, dans les murs : des trous noirs d'où coule un filet.
	for i in 6:
		var zz := r.position.y + 6.0 + i * 9.0
		var x := -r.size.x * 0.5 - 0.05 if i % 2 == 0 else r.size.x * 0.5 + 0.05
		_boite(Vector3(0.2, 1.0, 1.2), Vector3(x, _sol_espace(e, zz) + 0.9, zz), _mat_pbr("", Color(0.02, 0.02, 0.02), 1.0), d, false)


## La grande citerne : des piliers de brique, l'eau qui dort, les trois vannes.
func _construire_citerne() -> void:
	var d := _dossier("Citerne")
	var e: Array = ESPACES[2]
	var sol := float(e[2])
	for p: Vector2 in PILIERS:
		_boite(Vector3(1.4, float(e[4]), 1.4), Vector3(p.x, sol + float(e[4]) * 0.5, p.y), _mat_brique(), d)
	for i in 6:
		var a := Vector2(-12 + (i % 3) * 12, -4 + (i / 3) * 18)
		_torche(d, Vector3(a.x, sol + 3.0, a.y))
	# Des flaques d'eau noire sur les dalles.
	for i in 5:
		var flaque := MeshInstance3D.new()
		var plan := PlaneMesh.new()
		plan.size = Vector2(3.0 + i, 2.0 + i * 0.5)
		flaque.mesh = plan
		flaque.material_override = _mat_eau_noire()
		flaque.position = Vector3(-10 + i * 5, sol + 0.02, 6 - (i % 2) * 8)
		d.add_child(flaque)
	_fusionner(d)


## La remontée du canal vers l'arène : l'eau qui le noie (tant que les vannes sont
## fermées), la grille qui le ferme, et la herse au bout.
func _construire_canal() -> void:
	var d := _dossier("Canal")
	var e: Array = ESPACES[3]
	var r: Rect2 = e[1]
	_eau_canal = Node3D.new()
	_eau_canal.name = "EauCanal"
	_eau_canal.add_to_group("decor_quete")
	_eau_canal.set_meta("identifiant", "eau_canal")
	d.add_child(_eau_canal)
	var eau := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(r.size.x, 14.0)
	eau.mesh = plan
	eau.material_override = _mat_eau_noire()
	eau.position = Vector3(0, -7.4, r.position.y + 7.0)
	_eau_canal.add_child(eau)
	_grille = Node3D.new()
	_grille.name = "GrilleCanal"
	_grille.add_to_group("decor_quete")
	_grille.set_meta("identifiant", "grille_canal")
	_grille.position = Vector3(GRILLE.x, float(e[2]), GRILLE.y)
	d.add_child(_grille)
	var fer := StandardMaterial3D.new()
	fer.albedo_color = Color(0.14, 0.11, 0.09)
	fer.metallic = 0.6
	fer.roughness = 0.6
	for i in 9:
		_boite(Vector3(0.08, 4.4, 0.08), Vector3(-2.2 + i * 0.55, 2.2, 0), fer, _grille, false)
	for y: float in [0.6, 2.2, 3.8]:
		_boite(Vector3(5.0, 0.1, 0.1), Vector3(0, y, 0), fer, _grille, false)
	var corps := StaticBody3D.new()
	corps.name = "Collision"
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(5.2, 5.0, 0.4)
	forme.shape = boite
	forme.position = Vector3(0, 2.5, 0)
	corps.add_child(forme)
	_grille.add_child(corps)
	_grille.visibility_changed.connect(func(): forme.set_deferred("disabled", not _grille.visible))
	# La herse de l'arène, au bout : levée, et la lumière du jour qui tombe d'en haut.
	var h: Array = ESPACES[4]
	var hr: Rect2 = h[1]
	for i in 11:
		_boite(Vector3(0.1, 1.2, 0.1), Vector3(-5 + i, float(h[2]) + 4.3, hr.end.y - 0.4), fer, d, false)
	var jour := OmniLight3D.new()
	jour.light_color = Color(1.0, 0.94, 0.82)
	jour.light_energy = 3.0
	jour.omni_range = 16.0
	jour.position = Vector3(0, float(h[2]) + 3.5, hr.end.y - 1.0)
	d.add_child(jour)
	var z := r.position.y + 6.0
	while z < r.end.y:
		_torche(d, Vector3(-r.size.x * 0.5 + 0.15 if int(z) % 2 == 0 else r.size.x * 0.5 - 0.15, _sol_espace(e, z) + 2.2, z))
		z += 10.0


func _construire_limites() -> void:
	var limites := _dossier("Limites")
	var demi := taille_terrain * 0.5 - 2.0
	_mur_invisible(limites, Vector3(2, 160, taille_terrain), Vector3(-demi, 0, 0))
	_mur_invisible(limites, Vector3(2, 160, taille_terrain), Vector3(demi, 0, 0))
	_mur_invisible(limites, Vector3(taille_terrain, 160, 2), Vector3(0, 0, -demi))
	_mur_invisible(limites, Vector3(taille_terrain, 160, 2), Vector3(0, 0, demi))


# --- La quête ------------------------------------------------------------------------------------

func _construire_quete() -> void:
	var dossier := _dossier("Quete")
	_dossier_quete = dossier
	for i in VANNES.size():
		var p: Vector2 = VANNES[i]
		var vanne := ObjetRome.new()
		vanne.name = "Vanne%d" % i
		vanne.identifiant = "vanne_%d" % i
		vanne.groupe = "vanne"
		vanne.forme = "vanne"
		vanne.invite = "[F] Tourner la roue de la vanne"
		vanne.portee = 2.6
		vanne.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
		if absf(p.x) > 15.0:
			vanne.rotation.y = PI * 0.5 if p.x < 0.0 else -PI * 0.5
		else:
			vanne.rotation.y = PI
		dossier.add_child(vanne)
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.LIEU, "Grand égout", Vector2(0, -40))
	repere.call(MarqueurCarte.Type.LIEU, "Citerne des vannes", Vector2(0, 5))
	repere.call(MarqueurCarte.Type.LIEU, "Vers l'arène", SORTIE)
	repere.call(MarqueurCarte.Type.LIEU, "Retour au Forum", ENTREE)


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
	env.background_color = Color(0.01, 0.012, 0.01)
	env.sky = null
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.36, 0.3)
	env.ambient_light_energy = 0.35
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.25
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.04, 0.05, 0.04)
	env.fog_density = 0.02
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
	# La grille du canal ne bloque que tant qu'elle est baissée (visible).
	if _grille != null:
		var forme := _grille.get_node("Collision").get_child(0) as CollisionShape3D
		if forme.disabled == _grille.visible:
			forme.disabled = not _grille.visible
	_attente_sortie -= delta
	if _attente_sortie > 0.0:
		return
	_attente_sortie = 0.3
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	var quete := get_tree().get_first_node_in_group("quete")
	if joueur == null or quete == null or not quete.has_method("changer_de_zone"):
		return
	var p := Vector2(joueur.global_position.x, joueur.global_position.z)
	if p.y < ENTREE.y - 2.2:
		quete.changer_de_zone("rome")
	elif p.y > SORTIE.y - 1.0 and quete.etape_atteinte("vers_arene"):
		quete.changer_de_zone("colisee")


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
