@tool
extends "res://scripts/monde/egypte/ile_egypte.gd"
## Île d'Égypte, zone 4 : le Désert Rouge (niveaux 16-19).
##
## À l'ouest du plateau de Gizeh. Pour les Égyptiens, c'est Deshret, « la Terre
## Rouge », le pays des morts, par opposition à Kemet, « la Terre Noire » du Nil. On
## arrive à l'est par la passe des tombes. D'abord le grand cimetière des nobles : des
## rangées de mastabas (des tombes en forme de banc géant) le long de rues de sable.
## Au sud, un ouadi (un lit de rivière à sec) serpente ; les nomades campent sur sa
## rive. À l'ouest, des dunes. Au nord-ouest, sur un éperon rocheux, une grande tombe
## abandonnée : le repaire de l'Effaceuse.
##
## Repères : le nord est vers -Z, le plateau et le village à l'est (+X).

const Faille := preload("res://scripts/monde/prehistoire/faille.gd")
const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")

## La passe des tombes (retour vers le Village des Bâtisseurs).
const ENTREE := Vector2(150, -30)
## Le cimetière des nobles : rangées de mastabas.
const CIMETIERE := Rect2(30, -100, 100, 140)
## Les empreintes de la prêtresse, entre les tombes.
const TRACES := [Vector2(96, -42), Vector2(58, -58), Vector2(18, -66)]
## Le repaire de l'Effaceuse : une grande tombe sur un éperon rocheux.
const REPAIRE := Vector2(-78, -70)
const COUR := Rect2(-92, -80, 24, 20)
const H_REPAIRE := 13.0
const VERA := Vector2(-86, -70)
const FAILLE := Vector2(-90.5, -70)
## L'ouadi (lit de rivière à sec), qui serpente au sud.
const OUADI := [Vector2(-160, 40), Vector2(-100, 70), Vector2(-40, 64), Vector2(10, 92), Vector2(80, 86), Vector2(160, 120)]
## Le campement des nomades, au bord de l'ouadi.
const NOMADES := Vector2(-34, 88)

var _sable: FastNoiseLite


func _init() -> void:
	identifiant_zone = "desert_rouge"
	taille_terrain = 320
	graine = 2563
	point_apparition = ENTREE + Vector2(-10, 0)
	nombre_touffes = 3000
	neige_qui_tombe = false
	sols = {
		# Rouge : les graviers de l'ouadi.
		"galets": ["dry_ground_rocks", "brown_mud_rocks_01", "dry_ground_01"],
		# Vert : le sable rouge des dunes.
		"neige": ["sand_01", "dense_sand", "sand_02"],
		# Bleu : le sol dur, caillouteux, des rues du cimetière.
		"sol": ["dry_ground_01", "mud_cracked_dry_03", "dry_ground_rocks"],
		"roche": ["sandstone_cracks", "cliff_side", "quarry_wall"],
	}
	reglages_terrain = {"sol_saturation": 0.95, "sol_motif": 5.0, "galets_motif": 3.0, "neige_motif": 7.0,
			"sol_teinte": Color(1.08, 0.94, 0.82), "roche_teinte": Color(1.1, 0.9, 0.74), "roche_saturation": 1.0,
			"neige_eclat": 1.0, "neige_paillettes": 0.0, "roche_motif": 12.0,
			# Le sable rouge du Deshret.
			"neige_teinte": Color(1.18, 0.88, 0.68), "neige_max": Vector3(0.9, 0.62, 0.44), "neige_simple": Color(0.82, 0.55, 0.36),
			"givre": 0.0, "neige_translucide": 0.0}
	reglages_herbe = {"couleur_base": Color(0.24, 0.2, 0.08), "couleur_pointe": Color(0.62, 0.52, 0.26),
			"couleur_givre": Color(0.6, 0.55, 0.3), "force_vent": 0.2}
	# La rue principale du cimetière, puis le chemin vers le repaire.
	piste = [Vector2(156, -30), Vector2(124, -32), Vector2(96, -40), Vector2(60, -54), Vector2(20, -64),
			Vector2(-20, -66), Vector2(-50, -68), Vector2(-66, -70)]


func _ready() -> void:
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_egypte", "") != "":
		Reseau.remove_meta("arrivee_egypte")
		point_apparition = ENTREE + Vector2(-10, 0)
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	return ENTREE if zone != "desert_rouge" else Vector2.INF


# --- Relief -----------------------------------------------------------------------------

func _preparer_bruits() -> void:
	super._preparer_bruits()
	_relief.frequency = 0.011
	_sable = FastNoiseLite.new()
	_sable.seed = graine + 9
	_sable.noise_type = FastNoiseLite.TYPE_PERLIN
	_sable.frequency = 0.018


## Distance au lit de l'ouadi.
func _distance_ouadi(p: Vector2) -> float:
	var d := INF
	for k in OUADI.size() - 1:
		d = minf(d, _distance_segment(p, OUADI[k], OUADI[k + 1]))
	return d


func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	var bruit := _relief.get_noise_2d(x, z)
	var fin := _details.get_noise_2d(x * 3.0, z * 3.0)
	# Le désert descend doucement du plateau (est) vers l'ouest.
	var h := 6.0 + smoothstep(40.0, 160.0, x) * 4.0 + bruit * 1.5 + fin * 0.08
	# Les dunes : des crêtes allongées, plus hautes vers l'ouest et le sud-ouest.
	var dune := absf(_sable.get_noise_2d(x * 0.7 + z * 0.4, z * 1.1))
	h += (1.0 - dune) * 9.0 * smoothstep(-20.0, -120.0, x) * (1.0 - smoothstep(-40.0, -100.0, z))
	h += (1.0 - dune) * 3.0 * smoothstep(40.0, 120.0, z)
	# Le cimetière des nobles : un sol dur et presque plat.
	h = lerpf(h, 9.0 + smoothstep(30.0, 130.0, x) * 1.5 + fin * 0.04, _dans_rect(CIMETIERE, x, z, 14.0))
	# L'éperon rocheux du repaire, au nord-ouest, et sa rampe d'accès par l'est.
	var eperon := _dans_rect(Rect2(-120, -110, 60, 70), x, z, 16.0 + bruit * 6.0)
	h = lerpf(h, H_REPAIRE + absf(bruit) * 4.0 + fin * 0.3, eperon)
	var rampe := 1.0 - smoothstep(4.0, 8.0, absf(z - REPAIRE.y))
	var montee := lerpf(9.0, H_REPAIRE, smoothstep(-20.0, -60.0, x))
	h = lerpf(h, montee, rampe * smoothstep(0.0, -18.0, x) * smoothstep(-80.0, -62.0, x))
	# La cour de la tombe : taillée à plat dans le rocher.
	h = lerpf(h, H_REPAIRE, _dans_rect(COUR.grow(2.0), x, z, 2.0))
	# L'ouadi : un lit creusé de 3 m, au fond plat et caillouteux.
	var lit := 1.0 - smoothstep(5.0, 13.0, _distance_ouadi(Vector2(x, z)) + bruit * 3.0)
	h -= lit * 3.2
	return h


## Rouge : graviers de l'ouadi ; vert : sable rouge ; bleu : sol dur du cimetière.
func _parts_sol(x: float, z: float, h: float) -> Color:
	var n := _relief.get_noise_2d(x * 2.0 + 90.0, z * 2.0)
	var lit := 1.0 - smoothstep(4.0, 9.0, _distance_ouadi(Vector2(x, z)) + n * 2.0)
	var dur := _dans_rect(CIMETIERE.grow(-4.0), x, z, 8.0 + n * 4.0)
	dur = maxf(dur, (1.0 - smoothstep(2.0, 5.0, _distance_piste(Vector2(x, z)))) * 0.6)
	dur = maxf(dur, _dans_rect(COUR.grow(4.0), x, z, 3.0))
	return Color(lit, (1.0 - lit) * (1.0 - dur), dur * (1.0 - lit), 1.0)


# --- Construction -------------------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_flotteurs.clear()
	_a_liberer.clear()
	_liberes = 0
	_construire_terrain()
	_construire_mastabas()
	_construire_repaire()
	_construire_nomades()
	_construire_rochers()
	_construire_touffes()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_appliquer_ciel()
	var balise := get_node_or_null("BaliseVigie") as Node3D
	if balise != null:
		balise.position = Vector3(ENTREE.x - 6.0, hauteur(ENTREE.x - 6.0, ENTREE.y + 6.0), ENTREE.y + 6.0)


func _dossier(nom: String) -> Node3D:
	var d := Node3D.new()
	d.name = nom
	_contenu.add_child(d)
	return d


# --- Le cimetière des nobles ---------------------------------------------------------------

## Une mastaba : un gros bloc aux murs inclinés, avec une chapelle et une « fausse porte »
## à l'est, par où l'âme du mort sort chercher ses offrandes.
func _mastaba(parent: Node3D, centre: Vector2, longueur: float, largeur: float, haut: float, materiau: Material) -> void:
	var y := hauteur(centre.x, centre.y) - 0.4
	var m := Node3D.new()
	m.position = Vector3(centre.x, y, centre.y)
	parent.add_child(m)
	# Le corps : un tronc de pyramide très plat (murs inclinés vers l'intérieur).
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := 0.82
	var bas := [Vector3(-largeur, 0, -longueur), Vector3(largeur, 0, -longueur), Vector3(largeur, 0, longueur), Vector3(-largeur, 0, longueur)]
	var hautc := [Vector3(-largeur * r, haut, -longueur * 0.94), Vector3(largeur * r, haut, -longueur * 0.94),
			Vector3(largeur * r, haut, longueur * 0.94), Vector3(-largeur * r, haut, longueur * 0.94)]
	for k in 4:
		var k2 := (k + 1) % 4
		var l := (bas[k] as Vector3).distance_to(bas[k2]) / 3.0
		outil.set_uv(Vector2(0, haut / 3.0)); outil.add_vertex(bas[k])
		outil.set_uv(Vector2(l, 0)); outil.add_vertex(hautc[k2])
		outil.set_uv(Vector2(l, haut / 3.0)); outil.add_vertex(bas[k2])
		outil.set_uv(Vector2(0, haut / 3.0)); outil.add_vertex(bas[k])
		outil.set_uv(Vector2(0, 0)); outil.add_vertex(hautc[k])
		outil.set_uv(Vector2(l, 0)); outil.add_vertex(hautc[k2])
	outil.set_uv(Vector2(0, 0)); outil.add_vertex(hautc[0])
	outil.set_uv(Vector2(1, 1)); outil.add_vertex(hautc[2])
	outil.set_uv(Vector2(1, 0)); outil.add_vertex(hautc[1])
	outil.set_uv(Vector2(0, 0)); outil.add_vertex(hautc[0])
	outil.set_uv(Vector2(0, 1)); outil.add_vertex(hautc[3])
	outil.set_uv(Vector2(1, 1)); outil.add_vertex(hautc[2])
	outil.generate_normals()
	var corps := MeshInstance3D.new()
	corps.mesh = outil.commit()
	corps.material_override = materiau
	m.add_child(corps)
	var statique := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(largeur * 1.8, haut, longueur * 1.9)
	forme.shape = boite
	forme.position.y = haut * 0.5
	statique.add_child(forme)
	m.add_child(statique)
	# La niche de la fausse porte, côté est (+X), avec une table d'offrandes.
	var noir := _mat_pbr("", Color(0.08, 0.06, 0.05), 1.0, 1.0)
	_boite(Vector3(0.1, 2.2, 1.0), Vector3(largeur * 0.92, 1.3, longueur * 0.4), noir, m, false)
	_boite(Vector3(0.6, 0.35, 0.9), Vector3(largeur + 0.4, 0.55, longueur * 0.4), _mat_calcaire(), m, false)


func _construire_mastabas() -> void:
	var c := _dossier("Mastabas")
	var calcaire := _mat_choix(["white_sandstone_blocks_02", "sandstone_blocks_08", "cliff_side"], Color(0.88, 0.8, 0.66), 0.85, 3.0)
	var briques := _mat_briques()
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 20
	# Les rangées, nord-sud, séparées par des rues de 7 m (on évite la rue principale).
	var x := CIMETIERE.position.x + 8.0
	while x < CIMETIERE.end.x - 6.0:
		var z := CIMETIERE.position.y + 10.0
		while z < CIMETIERE.end.y - 8.0:
			var longueur := hasard.randf_range(6.0, 10.0)
			var p := Vector2(x + hasard.randf_range(-0.6, 0.6), z + longueur)
			var loin_piste := _distance_piste(p) > longueur + 5.0
			var loin_traces := true
			for t in TRACES:
				if p.distance_to(t) < longueur + 4.0:
					loin_traces = false
			if loin_piste and loin_traces and hasard.randf() < 0.85:
				_mastaba(c, p, longueur, hasard.randf_range(3.5, 5.0), hasard.randf_range(3.5, 6.0),
						calcaire if hasard.randf() < 0.7 else briques)
			z += longueur * 2.0 + 6.0
		x += 17.0
	# Quelques jarres d'offrandes brisées et des stèles renversées dans les rues.
	for k in 30:
		var p := Vector2(hasard.randf_range(CIMETIERE.position.x, CIMETIERE.end.x), hasard.randf_range(CIMETIERE.position.y, CIMETIERE.end.y))
		_jarre(c, Vector3(p.x, hauteur(p.x, p.y) - 0.15, p.y), hasard.randf_range(0.6, 0.9), hasard.randf() * TAU)


# --- Le repaire de l'Effaceuse ---------------------------------------------------------------

func _construire_repaire() -> void:
	var r := _dossier("Repaire")
	var pierre := _mat_choix(["sandstone_blocks_08", "large_sandstone_blocks", "cliff_side"], Color(0.78, 0.62, 0.48), 0.95, 3.0)
	var y := H_REPAIRE
	# Les murs de la cour, taillés dans le rocher, ouverts à l'est.
	_boite(Vector3(COUR.size.x, 5.0, 1.6), Vector3(COUR.get_center().x, y + 1.8, COUR.position.y), pierre, r)
	_boite(Vector3(COUR.size.x, 5.0, 1.6), Vector3(COUR.get_center().x, y + 1.8, COUR.end.y), pierre, r)
	_boite(Vector3(1.6, 6.0, COUR.size.y + 1.6), Vector3(COUR.position.x, y + 2.3, COUR.get_center().y), pierre, r)
	for cote in [-1.0, 1.0]:
		_boite(Vector3(1.6, 5.0, 6.0), Vector3(COUR.end.x, y + 1.8, COUR.get_center().y + cote * 7.0), pierre, r)
	# La façade de la tombe au fond : une porte noire, deux piliers.
	var noir := _mat_pbr("", Color(0.05, 0.04, 0.04), 1.0, 1.0)
	_boite(Vector3(0.2, 3.2, 2.0), Vector3(COUR.position.x + 0.9, y + 1.6, COUR.get_center().y - 5.0), noir, r, false)
	for cote in [-1.0, 1.0]:
		_boite(Vector3(0.8, 4.5, 0.8), Vector3(COUR.position.x + 1.6, y + 2.25, COUR.get_center().y - 5.0 + cote * 1.8), pierre, r)
	# Le camp de Vera Lind : une tente de lin blanc... et ce qui n'a rien à faire ici.
	_auvent(r, Vector2(COUR.position.x + 6.0, COUR.end.y - 5.0), Vector2(5, 4), 2.5, Color(0.96, 0.94, 0.9))
	var plastique := _mat_pbr("", Color(0.12, 0.13, 0.14), 0.35, 1.0)
	var caisse := _boite(Vector3(1.2, 0.6, 0.8), Vector3(COUR.position.x + 6.0, y + 0.3, COUR.end.y - 5.0), plastique, r)
	caisse.name = "CaisseModerne"
	var ecran := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.32)
	ecran.mesh = q
	var lumiere := StandardMaterial3D.new()
	lumiere.albedo_color = Color(0.2, 0.8, 0.9)
	lumiere.emission_enabled = true
	lumiere.emission = Color(0.3, 0.9, 1.0)
	lumiere.emission_energy_multiplier = 2.0
	ecran.material_override = lumiere
	ecran.position = Vector3(COUR.position.x + 6.0, y + 0.85, COUR.end.y - 4.55)
	ecran.rotation.x = -0.35
	r.add_child(ecran)
	# Une antenne sur trépied, cachée derrière le mur.
	var metal := _mat_pbr("", Color(0.5, 0.5, 0.52), 0.4, 1.0)
	metal.metallic = 0.8
	var mat := MeshInstance3D.new()
	mat.mesh = _cylindre(0.03, 0.04, 4.0, 6)
	mat.material_override = metal
	mat.position = Vector3(COUR.position.x + 3.0, y + 2.0, COUR.position.y + 2.5)
	r.add_child(mat)
	var diode := MeshInstance3D.new()
	var sd := SphereMesh.new()
	sd.radius = 0.06
	sd.height = 0.12
	diode.mesh = sd
	var rouge := StandardMaterial3D.new()
	rouge.albedo_color = Color(1, 0.1, 0.05)
	rouge.emission_enabled = true
	rouge.emission = Color(1, 0.1, 0.05)
	rouge.emission_energy_multiplier = 4.0
	diode.material_override = rouge
	diode.position = mat.position + Vector3(0, 2.05, 0)
	r.add_child(diode)
	# Des jarres et des nattes : elle vit ici depuis des semaines.
	for k in 5:
		_jarre(r, Vector3(COUR.position.x + 3.0 + k * 0.9, y - 0.02, COUR.end.y - 2.2), 0.9, k)


# --- Le campement des nomades ------------------------------------------------------------------

func _construire_nomades() -> void:
	var n := _dossier("Nomades")
	# Des tentes basses en poil de chèvre noir, des jarres d'eau, un feu.
	var poil := _mat_pbr("", Color(0.16, 0.13, 0.11), 1.0, 1.0)
	var bois := _mat_choix(["rough_wood"], Color(0.5, 0.4, 0.3), 0.9, 1.0)
	for t in [[NOMADES + Vector2(-6, -3), 0.2], [NOMADES + Vector2(5, -5), -0.3], [NOMADES + Vector2(0, 6), 1.4]]:
		var p: Vector2 = t[0]
		var y := hauteur(p.x, p.y)
		var tente := Node3D.new()
		tente.position = Vector3(p.x, y, p.y)
		tente.rotation.y = t[1]
		n.add_child(tente)
		for cote in [-1.0, 1.0]:
			var pan := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(5.0, 0.05, 2.6)
			pan.mesh = b
			pan.material_override = poil
			pan.position = Vector3(0, 1.0, cote * 1.0)
			pan.rotation.x = cote * 0.75
			tente.add_child(pan)
		for cote in [-2.3, 0.0, 2.3]:
			var poteau := MeshInstance3D.new()
			poteau.mesh = _cylindre(0.04, 0.05, 1.9, 6)
			poteau.material_override = bois
			poteau.position = Vector3(cote, 0.95, 0)
			tente.add_child(poteau)
	_feu(n, NOMADES + Vector2(0, -1), 0.6)
	for k in 6:
		var p := NOMADES + Vector2(-3.0 + k * 0.9, 2.0)
		_jarre(n, Vector3(p.x, hauteur(p.x, p.y) - 0.02, p.y), 1.0, k)


# --- Rochers ---------------------------------------------------------------------------------

func _construire_rochers() -> void:
	var dossier := _dossier("Rochers")
	_preparer_rochers()
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 12
	# L'éperon rocheux : de gros blocs autour de la cour.
	for k in 70:
		var p := Vector2(hasard.randf_range(-125.0, -55.0), hasard.randf_range(-115.0, -35.0))
		if COUR.grow(5.0).has_point(p) or absf(p.y - REPAIRE.y) < 7.0 and p.x > COUR.end.x:
			continue
		_placer_rocher(dossier, p.x, p.y, hasard.randf_range(0.8, 3.2))
	# Les cailloux de l'ouadi.
	for k in 90:
		var t := hasard.randi_range(0, OUADI.size() - 2)
		var p: Vector2 = (OUADI[t] as Vector2).lerp(OUADI[t + 1], hasard.randf()) + Vector2(hasard.randf_range(-5, 5), hasard.randf_range(-5, 5))
		_placer_rocher(dossier, p.x, p.y, hasard.randf_range(0.2, 0.9))
	for id_k in 18:
		var x := hasard.randf_range(-150.0, 20.0)
		var z := hasard.randf_range(-20.0, 150.0)
		if Vector2(x, z).distance_to(NOMADES) < 14.0:
			continue
		var id: String = ["namaqualand_boulder_02", "namaqualand_boulder_03", "sand_rocks_small_01"][id_k % 3]
		_modele(id, Vector3(x, hauteur(x, z) - 0.2, z), hasard.randf() * TAU, hasard.randf_range(0.8, 2.0), dossier)


# --- Paysage lointain ----------------------------------------------------------------------

func _construire_lointain() -> void:
	# Le désert continue à perte de vue ; à l'est, la Grande Pyramide sur son plateau.
	_plan_lointain(Vector3(0, 7.0, 0), Vector2(4000, 4000), Color(0, 1, 0))
	_construire_pyramide(Vector3(420, 12.0, -120), 0.0)


# --- Limites de la zone -----------------------------------------------------------------------

func _construire_limites() -> void:
	var limites := _dossier("Limites")
	var demi := taille_terrain * 0.5 - 4.0
	_mur_invisible(limites, Vector3(2, 160, taille_terrain), Vector3(-demi, 60, 0))
	_mur_invisible(limites, Vector3(2, 160, taille_terrain), Vector3(demi, 60, 0))
	_mur_invisible(limites, Vector3(taille_terrain, 160, 2), Vector3(0, 60, -demi))
	_mur_invisible(limites, Vector3(taille_terrain, 160, 2), Vector3(0, 60, demi))


# --- Personnages et objets de la quête ----------------------------------------------------------

func _construire_quete() -> void:
	var dossier := _dossier("Quete")
	_dossier_quete = dossier
	_pnj(dossier, "vera_lind", VERA, PI / 2)
	# Lenoir arrive en courant après la fuite de Vera (caché jusque-là).
	var lenoir := _pnj(dossier, "lenoir_desert", Vector2(COUR.end.x - 3.0, REPAIRE.y + 2.0), -PI / 2)
	lenoir.add_to_group("decor_quete")
	lenoir.set_meta("identifiant", "lenoir_desert")
	lenoir.visible = false
	# Les empreintes de semelles crantées.
	for k in TRACES.size():
		var o := _objet(dossier, "Trace%d" % k, "trace_%d" % k, "traces_sablier", "empreinte_semelle", "[F] Examiner les empreintes", TRACES[k])
		o.rotation.y = -PI / 2 + 0.3
	# Les réponses à Vera Lind (le choix).
	_objet(dossier, "RepondrePain", "repondre_pain", "", "", "[F] Répondre : « On les nourrit, on les soigne »", VERA + Vector2(3.2, -1.4))
	_objet(dossier, "RepondreNoms", "repondre_noms", "", "", "[F] Répondre : « Tu leur as volé leur nom »", VERA + Vector2(3.2, 1.4))
	# La faille par où elle s'enfuit, et le carnet qu'elle laisse tomber.
	var faille := Faille.new()
	faille.name = "Faille"
	faille.identifiant = "faille_vera"
	faille.position = Vector3(FAILLE.x, H_REPAIRE, FAILLE.y)
	dossier.add_child(faille)
	var carnet := Node3D.new()
	carnet.name = "CarnetVera"
	carnet.set_meta("identifiant", "carnet_vera")
	carnet.add_to_group("decor_quete")
	carnet.visible = false
	carnet.position = Vector3(VERA.x + 0.8, H_REPAIRE, VERA.y)
	dossier.add_child(carnet)
	var cuir := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.16, 0.025, 0.22)
	cuir.mesh = b
	cuir.material_override = _mat_pbr("", Color(0.32, 0.2, 0.12), 0.7, 1.0)
	cuir.position.y = 0.013
	cuir.rotation.y = 0.4
	carnet.add_child(cuir)
	_objet(dossier, "RamasserCarnet", "carnet_vera", "", "", "[F] Ramasser le carnet", Vector2(carnet.position.x, carnet.position.z))
	# Repères de la carte.
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.LIEU, "Passe des tombes (vers le village)", ENTREE)
	repere.call(MarqueurCarte.Type.LIEU, "Cimetière des nobles", CIMETIERE.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "La grande tombe du rocher", REPAIRE)
	repere.call(MarqueurCarte.Type.LIEU, "Campement des nomades", NOMADES)
	repere.call(MarqueurCarte.Type.LIEU, "Ouadi", Vector2(10, 92))
	repere.call(MarqueurCarte.Type.DANGER, "Chacals", Vector2(-110, 40))


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


# --- Retour vers le Village des Bâtisseurs -------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	if Engine.is_editor_hint():
		return
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return
	if joueur.global_position.x > ENTREE.x + 1.0 and absf(joueur.global_position.z - ENTREE.y) < 16.0:
		var quete := get_tree().get_first_node_in_group("quete")
		if quete != null and quete.has_method("changer_de_zone"):
			quete.changer_de_zone("village_batisseurs")
