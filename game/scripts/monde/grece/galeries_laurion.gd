@tool
extends "res://scripts/monde/grece/ile_grece.gd"
## Île de Grèce, zone 5 : les galeries du Laurion (sous la colline des puits).
##
## Des boyaux taillés au pic dans le marbre et le schiste, si bas qu'on y avance courbé,
## étayés de poutres. Des lampes à huile dans des niches, de plus en plus rares. Des
## esclaves y travaillent dix heures d'affilée, couchés sur le côté pour attaquer le
## filon. Masque a caché ses machines au fond : des pompes modernes, prêtes à renvoyer
## l'eau de la citerne dans les galeries pour les noyer.
##
## Comme dans la pyramide d'Égypte, pas de relief : chaque galerie est une boîte de roche
## (sol, murs, plafond) et hauteur() lit le sol de la galerie où l'on est.
## On entre au nord (par l'entrée de la mine) ; on ressort au sud-est, par la vieille
## descenderie qui remonte vers le flanc est de la colline.

const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const ObjetGrece := preload("res://scripts/monde/grece/objet_grece.gd")

## L'entrée (depuis l'entrée de la mine) et le haut de la descenderie.
const ENTREE := Vector2(0, -58)
const SORTIE := Vector2(45, 52)
## Les galeries : [nom, Rect2 (x, z), sol au début (z min), sol au bout (z max), hauteur sous plafond].
const ESPACES := [
	["entree", Rect2(-2, -60, 4, 14), 0.0, -4.0, 3.4],
	["carrefour", Rect2(-5, -46, 10, 10), -4.0, -4.0, 4.0],
	["galerie_ouest", Rect2(-35, -43, 30, 4), -4.0, -4.0, 2.7],
	["chantier_ouest", Rect2(-49, -50, 14, 16), -4.0, -4.0, 5.0],
	["galerie_sud", Rect2(-2, -36, 4, 34), -4.0, -8.0, 3.0],
	["salle_sud", Rect2(-9, -2, 18, 14), -8.0, -8.0, 6.0],
	["galerie_est", Rect2(9, 3, 30, 4), -8.0, -8.0, 2.8],
	["salle_est", Rect2(39, -4, 16, 18), -8.0, -8.0, 6.0],
	["descenderie", Rect2(43, 14, 4, 40), -8.0, 4.0, 3.2],
]
## Les trois machines de Masque.
const MACHINES := [Vector2(-43, -42), Vector2(3, 6), Vector2(49, 2)]
## L'éboulement qui ferme la galerie du sud derrière le joueur.
const EBOULIS_Z := -26.0

var _lampe_joueur: OmniLight3D
var _lumieres_lampes: Array[OmniLight3D] = []
var _attente_sortie := 0.0


func _init() -> void:
	identifiant_zone = "galeries_laurion"
	taille_terrain = 200
	graine = 4384
	point_apparition = ENTREE + Vector2(0, 3)
	nombre_touffes = 0
	neige_qui_tombe = false
	ambiance_grandiose = false
	ciel = ""


func _ready() -> void:
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_grece", "") != "":
		Reseau.remove_meta("arrivee_grece")
		var par := String(Reseau.get_meta("galeries_par", ""))
		Reseau.remove_meta("galeries_par")
		point_apparition = SORTIE + Vector2(0, -4) if par == "descenderie" else ENTREE + Vector2(0, 3)
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	return ENTREE if zone != "galeries_laurion" else Vector2.INF


# --- Le sol des galeries -----------------------------------------------------------------------

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
	_lumieres_lampes.clear()
	_construire_galeries()
	_construire_etais()
	_construire_lampes()
	_construire_quete()
	_construire_limites()
	_eclairer()


func _dossier(nom: String) -> Node3D:
	var d := Node3D.new()
	d.name = nom
	_contenu.add_child(d)
	return d


func _roche() -> StandardMaterial3D:
	return _mat_choix(["rock_wall_10", "cliff_side", "rock_boulder_dry"], Color(0.5, 0.48, 0.46), 0.95, 2.5)


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


## Les ouvertures d'un bord de galerie vers ses voisines : [début, fin, hauteur].
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


func _construire_galeries() -> void:
	var d := _dossier("Galeries")
	var mat := _roche()
	for i in ESPACES.size():
		var e: Array = ESPACES[i]
		var r: Rect2 = e[1]
		var h := float(e[4])
		var g := Node3D.new()
		g.name = String(e[0]).capitalize().replace(" ", "")
		d.add_child(g)
		_dalle(g, e, 0.0, 1.0, mat)
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
	# Le filon : des veines sombres et brillantes dans la roche des deux chantiers.
	var filon := _mat_pbr("", Color(0.16, 0.17, 0.2), 0.3)
	filon.metallic = 0.7
	for c in [[Vector2(-49, -42), 0.0], [Vector2(-9, 5), 0.0], [Vector2(55, 5), 0.0]]:
		var p: Vector2 = c[0]
		for k in 4:
			var veine := _boite(Vector3(0.12, 0.35, 3.0 + k), Vector3(p.x + (0.45 if p.x < 0 else -0.45), hauteur(p.x, p.y) + 1.0 + k * 0.9, p.y + k * 0.6 - 1.2), filon, d, false)
			veine.rotation.x = 0.2 * (k - 1.5)
	# Des paniers de minerai, des pics abandonnés.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 1
	var osier := _mat_choix(["brown_planks_03"], Color(0.5, 0.38, 0.22), 0.95, 1.0)
	for p: Vector2 in [Vector2(-40, -47), Vector2(-46, -36), Vector2(-6, 9), Vector2(6, 0), Vector2(52, 10), Vector2(41, -2)]:
		var panier := MeshInstance3D.new()
		panier.mesh = _cylindre(0.32, 0.24, 0.45, 10)
		panier.material_override = osier
		panier.position = Vector3(p.x, hauteur(p.x, p.y) + 0.22, p.y)
		d.add_child(panier)
		var minerai := MeshInstance3D.new()
		minerai.mesh = SphereMesh.new()
		(minerai.mesh as SphereMesh).radius = 0.28
		(minerai.mesh as SphereMesh).height = 0.3
		minerai.material_override = _mat_pbr("", Color(0.3, 0.3, 0.32), 0.9)
		minerai.position = panier.position + Vector3(0, 0.22, 0)
		d.add_child(minerai)


## Les étais : un cadre de poutres tous les trois mètres dans les galeries étroites.
func _construire_etais() -> void:
	var d := _dossier("Etais")
	var bois := _mat_bois()
	for e in ESPACES:
		var r: Rect2 = e[1]
		var h := float(e[4])
		if r.size.x > 6.0 and r.size.y > 6.0:
			continue
		var long_z := r.size.y > r.size.x
		var longueur := r.size.y if long_z else r.size.x
		var n := int(longueur / 3.0)
		for k in n:
			var t := (k + 0.5) / n
			var p := Vector2(r.get_center().x, lerpf(r.position.y, r.end.y, t)) if long_z else Vector2(lerpf(r.position.x, r.end.x, t), r.get_center().y)
			var y := hauteur(p.x, p.y)
			var demi := (r.size.x if long_z else r.size.y) * 0.5 - 0.15
			for cote: float in [-1.0, 1.0]:
				var poteau := Vector3(p.x + cote * demi, y + h * 0.5 - 0.05, p.y) if long_z else Vector3(p.x, y + h * 0.5 - 0.05, p.y + cote * demi)
				_boite(Vector3(0.2, h - 0.1, 0.2), poteau, bois, d, false)
			var chapeau := Vector3(demi * 2.0 + 0.3, 0.22, 0.24) if long_z else Vector3(0.24, 0.22, demi * 2.0 + 0.3)
			_boite(chapeau, Vector3(p.x, y + h - 0.2, p.y), bois, d, false)


func _construire_lampes() -> void:
	var d := _dossier("Lampes")
	var points := [Vector2(1.6, -56), Vector2(-1.6, -50), Vector2(4.5, -44), Vector2(-4.5, -38), Vector2(-20, -40.4),
			Vector2(-48.4, -48), Vector2(-36, -36), Vector2(1.6, -30), Vector2(-1.6, -16), Vector2(-8.4, 10),
			Vector2(8.4, -1), Vector2(24, 6.6), Vector2(54.4, -3), Vector2(39.6, 12), Vector2(46.6, 30), Vector2(43.4, 46),
			# Les grandes salles : des lampes dans chaque coin.
			Vector2(-48.4, -36), Vector2(-35.6, -48), Vector2(8.4, 10), Vector2(-8.4, -1),
			Vector2(54.4, 12), Vector2(39.6, -3)]
	for p in points:
		_lampe(d, Vector3(p.x, hauteur(p.x, p.y) + 1.4, p.y))


## Une lampe à huile en terre cuite posée dans une niche de la paroi.
func _lampe(parent: Node3D, p: Vector3) -> void:
	var lampe := Node3D.new()
	lampe.position = p
	parent.add_child(lampe)
	var coupe := MeshInstance3D.new()
	coupe.mesh = _tour([[0.0, 0.05], [0.05, 0.12], [0.09, 0.14], [0.1, 0.12]], 10)
	coupe.material_override = _mat_pbr("", Color(0.55, 0.35, 0.22), 0.9)
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
	lumiere.light_energy = 1.4
	lumiere.omni_range = 8.0
	lumiere.omni_attenuation = 1.4
	lumiere.position = Vector3(0, 0.4, 0)
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


func _construire_quete() -> void:
	var dossier := _dossier("Quete")
	_dossier_quete = dossier
	# Deux mineurs, au travail ou à bout de forces.
	_pnj(dossier, "mineur_galerie", Vector2(-44, -38), PI * 0.6)
	_pnj(dossier, "mineur_enfant", Vector2(-4, -1), PI * 0.25)
	for k in MACHINES.size():
		var p: Vector2 = MACHINES[k]
		var machine := ObjetGrece.new()
		machine.name = "Machine%d" % k
		machine.identifiant = "machine_%d" % k
		machine.groupe = "machine_masque"
		machine.forme = "machine"
		machine.invite = "[F] Saboter la machine"
		machine.portee = 2.2
		machine.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
		dossier.add_child(machine)
		# La lueur violette de l'éclat de faille qui alimente la machine.
		var lueur := OmniLight3D.new()
		lueur.light_color = Color(0.62, 0.36, 1.0)
		lueur.light_energy = 1.6
		lueur.omni_range = 6.0
		lueur.position = Vector3(0, 1.4, 0)
		machine.add_child(lueur)
	# L'éboulement : caché, il apparaît (et bloque la galerie) quand les machines sont sabotées.
	var eboulis := Node3D.new()
	eboulis.name = "Eboulis"
	eboulis.set_meta("identifiant", "eboulis_galerie")
	eboulis.add_to_group("decor_quete")
	eboulis.position = Vector3(0, hauteur(0, EBOULIS_Z), EBOULIS_Z)
	dossier.add_child(eboulis)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 9
	var roche := _roche()
	for k in 9:
		var bruit := FastNoiseLite.new()
		bruit.seed = hasard.randi()
		bruit.frequency = 0.9
		var bloc := MeshInstance3D.new()
		var t := hasard.randf_range(0.6, 1.2)
		bloc.mesh = _maillage_bosse(bruit, Vector3(t, t * 0.8, t), 1.6, 0.3, 12)
		bloc.material_override = roche
		bloc.position = Vector3(hasard.randf_range(-1.4, 1.4), hasard.randf_range(0.3, 2.2), hasard.randf_range(-1.2, 1.2))
		eboulis.add_child(bloc)
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(4.0, 3.2, 2.0)
	forme.shape = boite
	forme.position.y = 1.6
	corps.add_child(forme)
	eboulis.add_child(corps)
	eboulis.visibility_changed.connect(func(): forme.set_deferred("disabled", not eboulis.visible))
	eboulis.visible = false
	forme.disabled = true
	# Repères de la carte.
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.LIEU, "Entrée de la mine", ENTREE)
	repere.call(MarqueurCarte.Type.LIEU, "Chantier de l'ouest", Vector2(-42, -42))
	repere.call(MarqueurCarte.Type.LIEU, "Salle du sud", Vector2(0, 5))
	repere.call(MarqueurCarte.Type.LIEU, "Salle de l'est", Vector2(47, 5))
	repere.call(MarqueurCarte.Type.LIEU, "Vieille descenderie", SORTIE)


## Sous terre : noir complet, des lampes à huile, de la poussière dans l'air.
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
	env.ambient_light_color = Color(0.4, 0.36, 0.32)
	env.ambient_light_energy = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.15
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.05, 0.045, 0.04)
	env.fog_density = 0.03
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = DisplayServer.get_name() != "headless"
	env.volumetric_fog_density = 0.025
	env.volumetric_fog_albedo = Color(0.8, 0.76, 0.7)
	env.volumetric_fog_length = 30.0


# --- Chaque image -------------------------------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	if Engine.is_editor_hint():
		return
	for k in _lumieres_lampes.size():
		var l := _lumieres_lampes[k]
		if is_instance_valid(l):
			l.light_energy = 1.4 + sin(_temps * 9.0 + k * 1.3) * 0.16 + sin(_temps * 21.0 + k) * 0.08
	_porter_la_lampe()
	_attente_sortie -= delta
	if _attente_sortie > 0.0:
		return
	_attente_sortie = 0.3
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	var quete := get_tree().get_first_node_in_group("quete")
	if joueur == null or quete == null or not quete.has_method("changer_de_zone"):
		return
	if joueur.global_position.z < ENTREE.y - 0.8:
		Reseau.set_meta("laurion_par", "puits")
		quete.changer_de_zone("laurion")
	elif joueur.global_position.z > SORTIE.y + 0.5:
		Reseau.set_meta("laurion_par", "descenderie")
		quete.changer_de_zone("laurion")


## La lampe à huile que Daos a donnée au joueur, accrochée à la ceinture.
func _porter_la_lampe() -> void:
	if _lampe_joueur != null and is_instance_valid(_lampe_joueur):
		return
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return
	_lampe_joueur = OmniLight3D.new()
	_lampe_joueur.name = "LampeMineur"
	_lampe_joueur.light_color = Color(1.0, 0.72, 0.42)
	_lampe_joueur.light_energy = 2.0
	_lampe_joueur.omni_range = 11.0
	_lampe_joueur.shadow_enabled = true
	_lampe_joueur.position = Vector3(0.35, 1.6, 0.3)
	joueur.add_child(_lampe_joueur)
