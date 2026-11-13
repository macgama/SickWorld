@tool
extends "res://scripts/monde/prehistoire/ile_prehistoire.gd"
## Île de la Préhistoire, zone 4 : les Falaises Peintes (niveaux 7-10).
##
## Une vallée enneigée fermée au nord par une longue falaise de calcaire. Au
## pied de la falaise, un abri sous roche sert d'abri d'hiver au clan du Bison :
## ses parois sont couvertes de peintures (bisons, chevaux, mains). Plus à l'est
## s'ouvre la Grande Grotte, où se cache la fracture majeure (le donjon).
## On arrive par le sud, depuis la passe du nord de la Steppe.
## Repères : le nord est vers -Z.

const Pnj := preload("res://scripts/monde/prehistoire/pnj_epoque.gd")
const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const ObjetQuete := preload("res://scripts/monde/prehistoire/objet_quete.gd")

## L'entrée de la vallée, depuis la passe du nord de la Steppe.
const ENTREE := Vector2(0, 138)
## L'abri sous roche du clan (au fond d'une anse de la falaise).
const ABRI := Vector2(0, -52)
## L'entrée de la Grande Grotte (le donjon).
const GROTTE := Vector2(78, -46)
## Les troncs morts où l'on gratte la résine des torches (chapitre 7).
const RESINE := [Vector2(-46, 28), Vector2(38, 52), Vector2(-72, 84)]

var _falaise: FastNoiseLite


func _init() -> void:
	identifiant_zone = "falaises"
	taille_terrain = 320
	point_apparition = ENTREE + Vector2(0, -12)
	nombre_touffes = 50000
	neige_qui_tombe = true
	ciel = "snow_field_2_puresky"
	sols = {
		"galets": ["dry_river_pebbles", "brown_mud_rocks_01"],
		"neige": ["snow_02", "snow_03"],
		"sol": ["withered_grass", "dry_ground_rocks"],
		"roche": ["cliff_side", "rock_wall_10", "rock_boulder_dry"],
	}
	# Calcaire clair et beige.
	reglages_terrain = {"sol_saturation": 0.7, "sol_motif": 3.0, "sol_teinte": Color(1.0, 0.95, 0.85),
			"roche_motif": 12.0, "roche_teinte": Color(0.98, 0.97, 0.94), "roche_saturation": 0.12}
	reglages_herbe = {"couleur_base": Color(0.2, 0.16, 0.08), "couleur_pointe": Color(0.72, 0.6, 0.38)}
	piste = [ENTREE, Vector2(4, 100), Vector2(-6, 40), Vector2(0, -10), ABRI + Vector2(0, 10)]


func _ready() -> void:
	# On ressort de la Grande Grotte devant son entrée.
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_prehistoire", "") == "grotte":
		Reseau.remove_meta("arrivee_prehistoire")
		point_apparition = Vector2(GROTTE.x, pied_falaise(GROTTE.x) + 14.0)
	super._ready()


func _chaque_image(_delta: float) -> void:
	for k in _feux.size():
		var feu := _feux[k]
		if is_instance_valid(feu):
			feu.light_energy = 3.2 + sin(_temps * 11.0 + k) * 0.4 + sin(_temps * 23.0 + k * 2.0) * 0.3
	if Engine.is_editor_hint():
		return
	_surveiller_sortie()


func sortie_vers(zone: String) -> Vector2:
	# Toutes les autres zones de l'île passent par la steppe, au sud.
	if zone == "grotte":
		return Vector2(GROTTE.x, pied_falaise(GROTTE.x) + 1.5)
	return ENTREE + Vector2(0, -4) if zone != "falaises" else Vector2.INF


# --- Relief ----------------------------------------------------------------

func _preparer_bruits() -> void:
	super._preparer_bruits()
	_relief.frequency = 0.007
	_falaise = FastNoiseLite.new()
	_falaise.seed = graine + 21
	_falaise.frequency = 0.02
	_falaise.fractal_octaves = 3


## Position (z) du pied de la falaise pour une position x. Elle recule en anse
## autour de l'abri et devant la Grande Grotte.
func pied_falaise(x: float) -> float:
	if _falaise == null:
		_preparer_bruits()
	var z := -36.0 + sin(x * 0.017) * 12.0 + _falaise.get_noise_1d(x) * 9.0
	# L'anse de l'abri : la paroi recule à 10 m derrière le camp.
	z = lerpf(z, ABRI.y - 10.0, exp(-pow((x - ABRI.x) / 16.0, 2.0)))
	z = lerpf(z, GROTTE.y - 6.0, exp(-pow((x - GROTTE.x) / 10.0, 2.0)))
	return z


func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	# Fond de vallée doucement vallonné.
	var h := 3.0 + _relief.get_noise_2d(x, z) * 4.0 + absf(_details.get_noise_2d(x * 0.5, z * 0.5)) * 0.7
	h += _details.get_noise_2d(x * 3.0, z * 3.0) * 0.06
	# Éboulis au pied de la falaise, puis la paroi presque verticale et le plateau.
	var dz := pied_falaise(x) - z
	h += smoothstep(-10.0, 0.0, dz) * 1.5
	var paroi := smoothstep(0.0, 7.0, dz + _falaise.get_noise_2d(x * 2.0, z * 2.0) * 1.5)
	# La falaise a des gradins (bancs de calcaire).
	var bancs := 0.0
	for k in 4:
		bancs += smoothstep(0.0, 1.2, dz - 1.0 - k * 1.6) * 0.25
	h += (paroi * 0.6 + bancs * 0.4) * (32.0 + _relief.get_noise_2d(x * 2.0, 40.0) * 6.0)
	# Montagnes à l'est, à l'ouest et au sud, sauf l'entrée de la vallée.
	var crete := 1.0 - absf(_relief.get_noise_2d(x * 3.0, z * 3.0 + 500.0))
	h += smoothstep(120.0, 152.0, absf(x) + _relief.get_noise_2d(z, 30.0) * 8.0) * (20.0 + crete * crete * 18.0)
	var entree := exp(-pow((x - ENTREE.x) / 14.0, 2.0))
	h += smoothstep(128.0, 156.0, z + _relief.get_noise_2d(x, 60.0) * 8.0) * (20.0 + crete * crete * 18.0) * (1.0 - entree * 0.85)
	return h


func _parts_sol(x: float, z: float, h: float) -> Color:
	var n := _relief.get_noise_2d(x * 3.0 + 90.0, z * 3.0)
	# Éboulis de calcaire (galets) au pied de la falaise.
	var eboulis := smoothstep(-12.0, -1.0, pied_falaise(x) - z) * (1.0 - smoothstep(4.0, 9.0, pied_falaise(x) - z))
	var neige := smoothstep(-0.3, 0.4, n) * 0.8 + smoothstep(20.0, 30.0, h)
	var sur_piste := exp(-pow(_distance_piste(Vector2(x, z)) / 1.6, 2.0))
	neige *= 1.0 - sur_piste * 0.4
	var galets := clampf(eboulis * 0.8, 0.0, 1.0)
	return Color(galets, clampf(neige * (1.0 - galets), 0.0, 1.0), 1.0 - galets, 1.0)


# --- Construction ------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_feux.clear()
	_construire_terrain()
	_construire_rochers()
	_construire_touffes()
	_construire_vegetation()
	_construire_abri()
	_construire_grotte()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_construire_neige_qui_tombe()
	_appliquer_ciel()


func _degage(p: Vector2, marge := 0.0) -> bool:
	if p.distance_to(ABRI) < 22.0 + marge or p.distance_to(GROTTE) < 14.0 + marge:
		return false
	if p.distance_to(ENTREE) < 14.0 + marge or _distance_piste(p) < 2.5 + marge:
		return false
	return true


func _construire_rochers() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 12
	var dossier := Node3D.new()
	dossier.name = "Rochers"
	_contenu.add_child(dossier)
	_preparer_rochers()
	# Blocs de calcaire tombés de la falaise.
	var places := 0
	var essais := 0
	while places < 90 and essais < 1500:
		essais += 1
		var x := hasard.randf_range(-130.0, 130.0)
		var z := pied_falaise(x) + hasard.randf_range(1.0, 16.0)
		if not _degage(Vector2(x, z), 1.0):
			continue
		_placer_rocher(dossier, x, z, hasard.randf_range(0.6, 3.2) * (1.6 if hasard.randf() < 0.1 else 1.0))
		places += 1
	# Quelques rochers isolés dans la vallée.
	places = 0
	essais = 0
	while places < 60 and essais < 1500:
		essais += 1
		var p := Vector2(hasard.randf_range(-130.0, 130.0), hasard.randf_range(-20.0, 130.0))
		if not _degage(p, 2.0) or p.y < pied_falaise(p.x) + 14.0:
			continue
		_placer_rocher(dossier, p.x, p.y, hasard.randf_range(0.4, 2.2))
		places += 1
	# De grands pans de roche scannés contre la paroi (elle paraît moins lisse).
	for k in 26:
		var x := -125.0 + k * 10.0 + hasard.randf_range(-3.0, 3.0)
		if absf(x - ABRI.x) < 12.0 or absf(x - GROTTE.x) < 9.0:
			continue
		var z := pied_falaise(x) - 1.0
		var pan := _modele("rock_face_0%d" % (1 + k % 2), Vector3(x, hauteur(x, z) - 1.5, z),
				hasard.randf_range(-0.4, 0.4), hasard.randf_range(2.5, 4.0), dossier)
		if pan != null:
			_teinter(pan, Color(0.95, 0.9, 0.8), 0.5)


func _construire_vegetation() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 40
	var dossier := Node3D.new()
	dossier.name = "Vegetation"
	_contenu.add_child(dossier)
	for groupe in [["searsia_lucida", 30, 0.8, 1.4], ["wild_rooibos_bush", 50, 0.7, 1.3],
			["dead_tree_trunk", 8, 0.9, 1.3], ["tree_stump_01", 8, 0.8, 1.2], ["dry_branches_medium_01", 20, 0.8, 1.4]]:
		var places := 0
		var essais := 0
		while places < int(groupe[1]) and essais < 400:
			essais += 1
			var p := Vector2(hasard.randf_range(-125.0, 125.0), hasard.randf_range(-20.0, 125.0))
			if not _degage(p, 1.5) or p.y < pied_falaise(p.x) + 8.0:
				continue
			var objet := _modele(groupe[0], Vector3(p.x, hauteur(p.x, p.y) - 0.05, p.y), hasard.randf() * TAU,
					hasard.randf_range(groupe[2], groupe[3]), dossier)
			if objet == null:
				break
			if groupe[0] != "dead_tree_trunk" and groupe[0] != "tree_stump_01":
				_teinter(objet, Color(0.85, 0.68, 0.4))
			places += 1


# --- L'abri sous roche du clan -------------------------------------------------------------

## Un creux sombre dans la paroi (entrée d'abri ou de grotte).
func _bouche(parent: Node3D, p: Vector2, largeur: float, haut: float, profondeur: float, trou := true) -> void:
	var noir := StandardMaterial3D.new()
	noir.albedo_color = Color(0.04, 0.035, 0.03)
	noir.roughness = 1.0
	noir.cull_mode = BaseMaterial3D.CULL_FRONT
	var creux := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.is_hemisphere = true
	creux.mesh = sphere
	creux.material_override = noir
	creux.scale = Vector3(largeur * 0.5, haut, profondeur)
	var z := pied_falaise(p.x)
	creux.position = Vector3(p.x, hauteur(p.x, z + 1.0) - 0.3, z + 0.5)
	parent.add_child(creux)
	if not trou:
		_voute(parent, p, largeur, haut, z, creux.position.y)
		return
	# Le noir de l'entrée : un voile opaque en demi-ellipse, sans lumière.
	var ombre := MeshInstance3D.new()
	var disque := SphereMesh.new()
	disque.radius = 1.0
	disque.height = 2.0
	disque.is_hemisphere = true
	ombre.mesh = disque
	var nuit := StandardMaterial3D.new()
	nuit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nuit.albedo_color = Color(0.01, 0.01, 0.012)
	ombre.material_override = nuit
	ombre.scale = Vector3(largeur * 0.47, haut * 0.92, 0.05)
	ombre.position = creux.position + Vector3(0, 0.25, 1.2)
	ombre.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ombre.set_meta("bouche", true)
	parent.add_child(ombre)
	_voute(parent, p, largeur, haut, z, creux.position.y)


## Une voûte de roche au-dessus d'une ouverture.
func _voute(parent: Node3D, p: Vector2, largeur: float, haut: float, z: float, y: float) -> void:
	for k in 3:
		var bloc := _modele("rock_face_0%d" % (1 + k % 2), Vector3(p.x - largeur * 0.4 + k * largeur * 0.4,
				y + haut * 0.95, z + 0.5), PI + (k - 1) * 0.3, largeur * 0.32, parent)
		if bloc != null:
			_teinter(bloc, Color(0.95, 0.9, 0.8), 0.5)


func _construire_abri() -> void:
	var abri := Node3D.new()
	abri.name = "Abri"
	_contenu.add_child(abri)
	_bouche(abri, ABRI, 16.0, 6.0, 7.0, false)
	var bois := _mat_pbr("rough_wood", Color(0.55, 0.45, 0.35), 0.9, 1.0)
	var fond := pied_falaise(ABRI.x)
	# Le feu au milieu de l'abri, des peaux tendues contre le vent.
	_feu(abri, ABRI + Vector2(0, -2), 1.1)
	var peau := _mat_peau()
	for k in 5:
		var cote := -1.0 if k < 3 else 1.0
		var x := ABRI.x + cote * (6.5 + (k % 3) * 1.6)
		var z := fond + 4.0 + (k % 3) * 2.8
		var pare_vent := Node3D.new()
		pare_vent.position = Vector3(x, hauteur(x, z), z)
		pare_vent.rotation.y = cote * 1.2
		abri.add_child(pare_vent)
		for c in [-1.0, 1.0]:
			var perche := MeshInstance3D.new()
			perche.mesh = _cylindre(0.04, 0.05, 2.6, 6)
			perche.material_override = bois
			perche.position = Vector3(c * 1.5, 1.2, 0)
			perche.rotation.x = -0.25
			pare_vent.add_child(perche)
		var tendue := MeshInstance3D.new()
		var plan := BoxMesh.new()
		plan.size = Vector3(3.0, 2.0, 0.03)
		tendue.mesh = plan
		tendue.material_override = peau
		tendue.position = Vector3(0, 1.2, 0.1)
		tendue.rotation.x = -0.25
		pare_vent.add_child(tendue)
	# Des couches de fourrures autour du feu.
	for k in 6:
		var a := k * TAU / 6.0 + 0.3
		var fourrure := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(1.4, 0.06, 0.9)
		fourrure.mesh = b
		fourrure.material_override = peau
		var p := ABRI + Vector2(0, -2) + Vector2(cos(a), sin(a)) * 3.0
		fourrure.position = Vector3(p.x, hauteur(p.x, p.y) + 0.04, p.y)
		fourrure.rotation.y = -a
		abri.add_child(fourrure)
	# Les peintures des ancêtres sur la paroi du fond.
	var fresque := Decal.new()
	fresque.name = "Fresque"
	fresque.size = Vector3(11.0, 6.0, 4.0)
	fresque.texture_albedo = _texture_fresque()
	# Ocre mate : sombre et peu saturée, mêlée à la roche.
	fresque.modulate = Color(0.42, 0.17, 0.09)
	fresque.albedo_mix = 0.85
	fresque.emission_energy = 0.0
	fresque.position = Vector3(ABRI.x, hauteur(ABRI.x, fond + 1.0) + 2.6, fond - 1.0)
	fresque.look_at_from_position(fresque.position, fresque.position + Vector3(0, 0, -1), Vector3.UP)
	fresque.rotate_object_local(Vector3.RIGHT, -PI / 2)
	fresque.add_to_group("decor_quete")
	fresque.set_meta("identifiant", "fresque_abri")
	abri.add_child(fresque)
	# Fin de l'île : Aïna repeint la paroi, avec le Venu-du-Brouillard parmi les bêtes.
	var finale := fresque.duplicate() as Decal
	finale.name = "FresqueVoyageur"
	finale.texture_albedo = _texture_fresque(true)
	finale.modulate = Color(0.48, 0.18, 0.09)
	finale.set_meta("identifiant", "fresque_voyageur")
	finale.visible = false
	abri.add_child(finale)


# --- La Grande Grotte -------------------------------------------------------------------------

func _construire_grotte() -> void:
	var grotte := Node3D.new()
	grotte.name = "GrandeGrotte"
	_contenu.add_child(grotte)
	_bouche(grotte, GROTTE, 9.0, 5.0, 9.0)
	# Un souffle violet sort de la grotte : la fracture majeure est au fond.
	var lueur := OmniLight3D.new()
	lueur.light_color = Color(0.6, 0.25, 1.0)
	lueur.light_energy = 2.0
	lueur.omni_range = 9.0
	var z := pied_falaise(GROTTE.x)
	lueur.position = Vector3(GROTTE.x, hauteur(GROTTE.x, z + 2.0) + 1.5, z + 1.0)
	grotte.add_child(lueur)


# --- Paysage lointain et limites -----------------------------------------------------------

func _construire_lointain() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 70
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.8
	bruit.fractal_octaves = 4
	for k in 14:
		bruit.seed = graine + 400 + k
		var a := k * TAU / 14.0 + hasard.randf_range(-0.1, 0.1)
		var distance := hasard.randf_range(340.0, 430.0)
		var largeur := hasard.randf_range(150.0, 240.0)
		var montagne := MeshInstance3D.new()
		montagne.mesh = _maillage_bosse(bruit, Vector3(largeur, hasard.randf_range(60.0, 130.0), largeur * 0.6),
				1.4, 0.35, 28, Color(0, 0.7, 0.3))
		montagne.material_override = _mat_lointain()
		montagne.position = Vector3(cos(a) * distance, -8.0, sin(a) * distance)
		montagne.rotation.y = -a + PI / 2
		montagne.set_instance_shader_parameter("neige_en_plus", 0.85)
		montagne.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(montagne)


func _construire_limites() -> void:
	var limites := Node3D.new()
	limites.name = "Limites"
	_contenu.add_child(limites)
	var demi := taille_terrain * 0.5 - 6.0
	for donnees in [[Vector3(2, 140, taille_terrain), Vector3(-demi, 40, 0)], [Vector3(2, 140, taille_terrain), Vector3(demi, 40, 0)],
			[Vector3(taille_terrain, 140, 2), Vector3(0, 40, -demi)], [Vector3(taille_terrain, 140, 2), Vector3(0, 40, demi)]]:
		var corps := StaticBody3D.new()
		corps.position = donnees[1]
		var forme := CollisionShape3D.new()
		var boite := BoxShape3D.new()
		boite.size = donnees[0]
		forme.shape = boite
		corps.add_child(forme)
		limites.add_child(corps)


# --- Quête : le clan à l'abri d'hiver ----------------------------------------------------------

func _construire_quete() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quete"
	_contenu.add_child(dossier)
	# Le clan arrive au chapitre 6 (caché jusque-là).
	var pnj := func(id: String, nom_noeud: String, p: Vector2, angle: float) -> void:
		var n := Pnj.new()
		n.name = nom_noeud
		n.identifiant = id
		n.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
		n.rotation.y = angle
		n.add_to_group("decor_quete")
		n.set_meta("identifiant", "clan_abri")
		n.visible = false
		dossier.add_child(n)
	pnj.call("aina", "Aina", ABRI + Vector2(-3, 0), 0.4)
	pnj.call("vieille_mere", "VieilleMere", ABRI + Vector2(2.5, -4), -0.3)
	pnj.call("toran", "Toran", ABRI + Vector2(5, 7), 0.0)
	pnj.call("chasseur_ulm", "Ulm", ABRI + Vector2(-7, 8), 0.3)
	pnj.call("chasseuse_naya", "Naya", ABRI + Vector2(8, 3), -0.6)
	pnj.call("keo", "Keo", ABRI + Vector2(-5, -4), 0.8)
	# Chapitre 7 : la résine des troncs morts, pour les torches.
	var k := 0
	for p in RESINE:
		var tronc := _modele("dead_tree_trunk", Vector3(p.x + 1.2, hauteur(p.x + 1.2, p.y) - 0.1, p.y), k * 1.7, 1.2, dossier)
		if tronc == null:
			_placer_rocher(dossier, p.x + 1.2, p.y, 0.8)
		var o := ObjetQuete.new()
		o.name = "Resine%d" % k
		o.identifiant = "resine%d" % k
		o.groupe = "resine"
		o.forme = "resine"
		o.invite = "[F] Gratter la résine"
		o.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
		dossier.add_child(o)
		k += 1
	# Repères de la carte.
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.LIEU, "Passe (vers la Steppe)", ENTREE + Vector2(0, -6))
	repere.call(MarqueurCarte.Type.LIEU, "Abri d'hiver du clan", ABRI)
	repere.call(MarqueurCarte.Type.DANGER, "La Grande Grotte (donjon)", GROTTE)


func _surveiller_sortie() -> void:
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return
	var p := Vector2(joueur.global_position.x, joueur.global_position.z)
	var quete := get_tree().get_first_node_in_group("quete")
	if quete == null or not quete.has_method("changer_de_zone"):
		return
	if p.y > ENTREE.y + 4.0 and absf(p.x - ENTREE.x) < 16.0:
		quete.changer_de_zone("steppe")
	elif p.distance_to(Vector2(GROTTE.x, pied_falaise(GROTTE.x) + 1.0)) < 3.0:
		quete.changer_de_zone("grotte")
