@tool
extends "res://scripts/monde/grece/ile_grece.gd"
## Île de Grèce, zone 4 : les Mines du Laurion (niveaux 27-30).
##
## Au sud-est de l'Attique, des collines pelées, sans un arbre : on a tout coupé pour
## nourrir les fours. C'est ici qu'Athènes trouve l'argent qui paie sa flotte, ses
## rameurs et ses temples. Et ce sont des esclaves qui le sortent de la terre.
## On arrive au nord par la route des Oliveraies. Au nord-ouest, l'atelier de lavage du
## minerai (l'ergastérion) et sa citerne ; à l'ouest, les cabanes des mineurs ; au
## nord-est, les fours et leurs tas de scories ; à l'est, la grande citerne que les
## mercenaires de Masque ont détournée vers les puits, et leur camp. Au sud, la colline
## des puits : l'entrée de la mine (vers les galeries) et, sur son flanc est, la vieille
## descenderie par où l'on ressort.
##
## Tout est construit par le code (voir ile_grece.gd). Repères : le nord est vers -Z.

const Faille := preload("res://scripts/monde/prehistoire/faille.gd")
const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const ObjetGrece := preload("res://scripts/monde/grece/objet_grece.gd")

## L'arrivée par la route des Oliveraies, au nord.
const ENTREE := Vector2(0, -150)
## Hauteur de la plaine.
const H_PLAINE := 10.0
## L'atelier de lavage (ergastérion), sa citerne et ses tables.
const ERGASTERION := Rect2(-74, -84, 46, 32)
const CITERNE_LAVAGE := Vector2(-36, -60)
const SOSIAS := Vector2(-44, -60)
## Les cabanes des mineurs, et Daos.
const CABANES := Rect2(-112, -36, 46, 38)
const DAOS := Vector2(-76, -12)
## Les fours de réduction et leurs scories.
const FOURS := Rect2(28, -100, 44, 30)
const FOURS_CENTRE := Vector2(50, -84)
## La grande citerne détournée, sa vanne, le canal vers les puits, le camp de Masque.
const CITERNE := Rect2(84, -46, 26, 18)
const VANNE := Vector2(97, -26)
const CAMP := Vector2(74, -4)
const OSTRAKA := Vector2(70, -1)
## La colline des puits (une ellipse), l'entrée de la mine et la vieille descenderie.
const COLLINE := Vector2(10, 108)
const COLLINE_RAYONS := Vector2(56, 46)
const COLLINE_HAUT := 30.0
const PUITS := Vector2(0, 62)
const DESCENDERIE := Vector2(66, 108)
const VERA := Vector2(76, 102)

var _attente_sortie := 0.0


func _init() -> void:
	identifiant_zone = "laurion"
	taille_terrain = 320
	graine = 4383
	point_apparition = ENTREE + Vector2(0, 8)
	nombre_touffes = 14000
	neige_qui_tombe = false
	sols = {
		# Rouge : la roche nue et grise des collines pelées.
		"galets": ["rock_boulder_dry", "rocky_terrain_02", "dry_ground_rocks"],
		# Vert : la terre sèche, grise de poussière de minerai.
		"neige": ["dry_ground_rocks", "dry_ground_01", "red_sand"],
		# Bleu : les chemins et les aires de travail, tassés et noircis.
		"sol": ["mud_cracked_dry_03", "dry_ground_rocks", "dry_ground_01"],
		"roche": ["rock_boulder_dry", "cliff_side", "rock_wall_10"],
	}
	reglages_terrain = {"sol_saturation": 0.55, "sol_motif": 4.0, "galets_motif": 3.0, "neige_motif": 5.0,
			"sol_teinte": Color(0.86, 0.84, 0.8), "roche_teinte": Color(0.9, 0.88, 0.86), "roche_saturation": 0.45,
			"neige_eclat": 1.0, "neige_paillettes": 0.0, "roche_motif": 10.0,
			"neige_teinte": Color(0.9, 0.82, 0.72), "neige_max": Vector3(0.56, 0.5, 0.44), "neige_simple": Color(0.52, 0.47, 0.42),
			"givre": 0.0, "neige_translucide": 0.0}
	reglages_herbe = {"couleur_base": Color(0.22, 0.2, 0.1), "couleur_pointe": Color(0.58, 0.52, 0.3),
			"couleur_givre": Color(0.58, 0.52, 0.3), "force_vent": 0.3}
	piste = [Vector2(0, -160), Vector2(0, -96), Vector2(-8, -60), Vector2(0, -20), Vector2(0, 56)]


func _ready() -> void:
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_grece", "") != "":
		var venu := String(Reseau.get_meta("arrivee_grece"))
		Reseau.remove_meta("arrivee_grece")
		if venu == "galeries_laurion":
			var par := String(Reseau.get_meta("laurion_par", ""))
			Reseau.remove_meta("laurion_par")
			point_apparition = DESCENDERIE + Vector2(7, 0) if par == "descenderie" else PUITS + Vector2(0, -7)
		else:
			point_apparition = ENTREE + Vector2(0, 8)
	super._ready()


func sortie_vers(zone: String) -> Vector2:
	match zone:
		"laurion":
			return Vector2.INF
		"galeries_laurion":
			return PUITS
	return ENTREE + Vector2(0, 4)


# --- Relief -----------------------------------------------------------------------------

func _preparer_bruits() -> void:
	super._preparer_bruits()
	_relief.frequency = 0.014


## Distance aux chemins de terre battue.
func _distance_chemins(p: Vector2) -> float:
	var d := INF
	for k in piste.size() - 1:
		d = minf(d, _distance_segment(p, piste[k], piste[k + 1]))
	d = minf(d, _distance_segment(p, Vector2(-8, -60), ERGASTERION.get_center()))
	d = minf(d, _distance_segment(p, Vector2(-4, -40), DAOS))
	d = minf(d, _distance_segment(p, Vector2(0, -96), FOURS_CENTRE))
	d = minf(d, _distance_segment(p, Vector2(0, -20), CAMP))
	d = minf(d, _distance_segment(p, CAMP, VANNE))
	d = minf(d, _distance_segment(p, CAMP, Vector2(70, 60)))
	d = minf(d, _distance_segment(p, Vector2(70, 60), DESCENDERIE + Vector2(8, 0)))
	return d


## 0 hors de la colline des puits, 1 en son cœur.
func _dans_colline(x: float, z: float) -> float:
	var n := Vector2((x - COLLINE.x) / COLLINE_RAYONS.x, (z - COLLINE.y) / COLLINE_RAYONS.y).length()
	return smoothstep(1.02, 0.6, n)


func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	var bruit := _relief.get_noise_2d(x, z)
	var fin := _details.get_noise_2d(x * 3.0, z * 3.0)
	# Des collines pelées tout autour, plus hautes à l'ouest et à l'est.
	var h := H_PLAINE + bruit * 4.5 + fin * 0.15
	h += pow(smoothstep(85.0, 160.0, absf(x)), 1.4) * (22.0 + bruit * 8.0)
	h += pow(smoothstep(80.0, 160.0, -z), 1.6) * 6.0 * (1.0 - smoothstep(10.0, 30.0, absf(x)))
	# La colline des puits, au sud.
	h += _dans_colline(x, z) * (COLLINE_HAUT + bruit * 6.0)
	# Les chemins : on adoucit les bosses.
	var d_chemin := _distance_chemins(Vector2(x, z))
	h = lerpf(h, h * 0.5 + (H_PLAINE + bruit * 1.5) * 0.5, (1.0 - smoothstep(2.0, 5.0, d_chemin)) * (1.0 - _dans_colline(x, z)))
	# Les aires de travail : aplanies.
	for r: Rect2 in [ERGASTERION, CABANES, FOURS, Rect2(CITERNE.position.x - 6, CITERNE.position.y - 4, CITERNE.size.x + 12, CITERNE.size.y + 30)]:
		h = lerpf(h, _plat(r.get_center()), _dans_rect(r, x, z, 6.0))
	# Le parvis de l'entrée de la mine et celui de la descenderie.
	h = lerpf(h, _plat(PUITS + Vector2(0, -6)), _dans_rect(Rect2(PUITS.x - 8, PUITS.y - 16, 16, 18), x, z, 5.0))
	h = lerpf(h, _plat(DESCENDERIE + Vector2(8, 0)), _dans_rect(Rect2(DESCENDERIE.x - 2, DESCENDERIE.y - 9, 20, 18), x, z, 5.0))
	return h


## La hauteur aplanie d'une aire de travail (sans les collines).
func _plat(p: Vector2) -> float:
	return H_PLAINE + _relief.get_noise_2d(p.x, p.y) * 1.5


## Rouge : roche des collines ; vert : terre grise ; bleu : chemins et aires tassées.
func _parts_sol(x: float, z: float, h: float) -> Color:
	var p := Vector2(x, z)
	var n := _relief.get_noise_2d(x * 2.0 + 40.0, z * 2.0)
	var roche := maxf(smoothstep(H_PLAINE + 6.0, H_PLAINE + 14.0, h + n * 4.0), _dans_colline(x, z) * 0.8)
	var battu := 1.0 - smoothstep(1.8, 3.8, _distance_chemins(p))
	for r: Rect2 in [ERGASTERION, CABANES, FOURS]:
		battu = maxf(battu, _dans_rect(r.grow(-3.0), x, z, 3.0))
	roche *= 1.0 - battu
	return Color(roche, (1.0 - roche) * (1.0 - battu), battu, 1.0)


# --- Construction -------------------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_flotteurs.clear()
	_construire_terrain()
	_construire_ergasterion()
	_construire_cabanes()
	_construire_fours()
	_construire_citerne()
	_construire_camp()
	_construire_entrees_mine()
	_construire_rochers()
	_construire_touffes()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_appliquer_ciel()


func _dossier(nom: String) -> Node3D:
	var d := Node3D.new()
	d.name = nom
	_contenu.add_child(d)
	return d


func _mat_eau() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.24, 0.24, 0.92)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.06
	m.metallic = 0.3
	return m


func _mat_minerai() -> StandardMaterial3D:
	return _mat_choix(["dry_ground_rocks", "rocky_terrain_02"], Color(0.36, 0.36, 0.38), 0.95, 1.5)


func _mat_scories() -> StandardMaterial3D:
	return _mat_choix(["rock_boulder_dry", "dry_ground_rocks"], Color(0.13, 0.12, 0.12), 0.7, 1.5)


## Un tas (minerai, scories, déblais) : une bosse de cailloux posée au sol.
func _tas(parent: Node3D, p: Vector2, taille: Vector3, materiau: Material, hasard: RandomNumberGenerator) -> void:
	var bruit := FastNoiseLite.new()
	bruit.seed = hasard.randi()
	bruit.frequency = 0.9
	var tas := MeshInstance3D.new()
	tas.mesh = _maillage_bosse(bruit, taille, 1.6, 0.25, 16)
	tas.material_override = materiau
	tas.position = Vector3(p.x, hauteur(p.x, p.y) - taille.y * 0.35, p.y)
	tas.rotation.y = hasard.randf() * TAU
	parent.add_child(tas)


## L'ergastérion : on y lave le minerai broyé. L'eau de la citerne coule en mince filet
## sur des tables de pierre inclinées ; le minerai d'argent, plus lourd, reste au fond
## des rigoles, la terre part avec l'eau. Ici, chaque goutte compte : il ne pleut presque jamais.
func _construire_ergasterion() -> void:
	var d := _dossier("Ergasterion")
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 1
	var pierre := _mat_pierre()
	var h := _plat(ERGASTERION.get_center())
	# Le muret de l'enclos.
	var r := ERGASTERION
	for cote in [[Vector3(r.size.x, 1.2, 0.6), Vector3(r.get_center().x, h + 0.6, r.position.y)],
			[Vector3(r.size.x, 1.2, 0.6), Vector3(r.get_center().x, h + 0.6, r.end.y)],
			[Vector3(0.6, 1.2, r.size.y), Vector3(r.position.x, h + 0.6, r.get_center().y)]]:
		_boite(cote[0], cote[1], pierre, d)
	# Les tables de lavage : un plan incliné, une rigole, un bassin de décantation au bout.
	for k in 4:
		var x := r.position.x + 7.0 + k * 9.0
		var z := r.get_center().y - 2.0
		var table := _boite(Vector3(3.2, 0.3, 9.0), Vector3(x, h + 0.9, z), _mat_chaux(), d)
		table.rotation.x = 0.08
		_boite(Vector3(3.6, 0.7, 0.4), Vector3(x, h + 0.35, z - 4.6), pierre, d)
		_boite(Vector3(3.6, 0.6, 2.2), Vector3(x, h + 0.3, z + 5.8), pierre, d)
		var eau := _boite(Vector3(3.0, 0.05, 1.8), Vector3(x, h + 0.58, z + 5.8), _mat_eau(), d, false)
		eau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for j in 3:
			_tas(d, Vector2(x + hasard.randf_range(-1.2, 1.2), z - 7.0 - j * 0.6), Vector3(1.0, 0.6, 1.0), _mat_minerai(), hasard)
	# La citerne ronde, enduite de mortier, et ses marches.
	var c := CITERNE_LAVAGE
	var bord := MeshInstance3D.new()
	bord.mesh = _cylindre(4.4, 4.6, 1.4, 28)
	bord.material_override = pierre
	bord.position = Vector3(c.x, h + 0.7, c.y)
	d.add_child(bord)
	var eau := MeshInstance3D.new()
	eau.mesh = _cylindre(4.0, 4.0, 0.05, 28)
	eau.material_override = _mat_eau()
	eau.position = Vector3(c.x, h + 1.25, c.y)
	d.add_child(eau)
	_mur_invisible(d, Vector3(9.0, 3.0, 9.0), Vector3(c.x, h + 1.5, c.y))
	# Des paniers de minerai broyé et des amphores d'eau.
	for k in 6:
		_amphore(d, Vector3(r.end.x - 3.0, h, r.position.y + 3.0 + k * 1.2), 0.9)
	_fusionner(d)


## Les cabanes des mineurs : des pièces de pierre sèche sans fenêtre, un toit de
## branchages. On y dort à vingt. Les esclaves des mines vivent rarement vieux.
func _construire_cabanes() -> void:
	var d := _dossier("Cabanes")
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 2
	var pierre := _mat_pierre()
	var branches := _mat_choix(["bark_brown_02", "brown_planks_03"], Color(0.36, 0.3, 0.22), 0.95, 1.5)
	var r := CABANES
	for i in 4:
		for j in 3:
			var p := Vector2(r.position.x + 6.0 + i * 11.0 + hasard.randf_range(-1, 1), r.position.y + 6.0 + j * 12.0)
			var h := hauteur(p.x, p.y)
			var t := Vector3(hasard.randf_range(6.5, 8.0), 2.3, hasard.randf_range(4.5, 5.5))
			var cabane := Node3D.new()
			cabane.position = Vector3(p.x, h, p.y)
			cabane.rotation.y = hasard.randf_range(-0.08, 0.08)
			d.add_child(cabane)
			_boite(Vector3(t.x, t.y, 0.5), Vector3(0, t.y * 0.5, -t.z * 0.5), pierre, cabane)
			_boite(Vector3(0.5, t.y, t.z), Vector3(-t.x * 0.5, t.y * 0.5, 0), pierre, cabane)
			_boite(Vector3(0.5, t.y, t.z), Vector3(t.x * 0.5, t.y * 0.5, 0), pierre, cabane)
			_boite(Vector3(t.x * 0.35, t.y, 0.5), Vector3(-t.x * 0.32, t.y * 0.5, t.z * 0.5), pierre, cabane)
			_boite(Vector3(t.x * 0.35, t.y, 0.5), Vector3(t.x * 0.32, t.y * 0.5, t.z * 0.5), pierre, cabane)
			var toit := _boite(Vector3(t.x + 0.8, 0.25, t.z + 0.8), Vector3(0, t.y + 0.2, 0), branches, cabane, false)
			toit.rotation.x = 0.06
	# Un foyer commun et une grande jarre d'eau.
	var f := Vector2(r.get_center().x, r.end.y + 3.0)
	_fumee(d, Vector3(f.x, hauteur(f.x, f.y) + 0.3, f.y))
	_amphore(d, Vector3(f.x + 3.0, hauteur(f.x + 3.0, f.y), f.y), 1.3)
	_fusionner(d)


## Les fours : on y fond le minerai lavé avec du plomb, au charbon de bois. L'argent
## coule, le reste devient scories, noires et vitreuses, en tas énormes.
func _construire_fours() -> void:
	var d := _dossier("Fours")
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 3
	var argile := _mat_terre_cuite()
	for k in 3:
		var p := FOURS_CENTRE + Vector2(-9.0 + k * 9.0, -2.0 if k == 1 else 2.0)
		var h := hauteur(p.x, p.y)
		var four := MeshInstance3D.new()
		four.mesh = _cylindre(1.0, 1.8, 3.6, 18)
		four.material_override = argile
		four.position = Vector3(p.x, h + 1.8, p.y)
		d.add_child(four)
		_boite(Vector3(3.8, 3.6, 3.8), Vector3(p.x, h + 1.8, p.y), argile, d).visible = false
		var bouche := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.8, 0.7)
		bouche.mesh = q
		bouche.material_override = _lumineux(Color(1.0, 0.45, 0.12), 4.0)
		bouche.position = Vector3(p.x, h + 0.5, p.y + 1.72)
		d.add_child(bouche)
		var braise := OmniLight3D.new()
		braise.light_color = Color(1.0, 0.5, 0.2)
		braise.light_energy = 1.4
		braise.omni_range = 6.0
		braise.position = Vector3(p.x, h + 0.8, p.y + 2.4)
		d.add_child(braise)
		_fumee(d, Vector3(p.x, h + 3.8, p.y))
		# Les soufflets de cuir et le tas de charbon.
		_tas(d, p + Vector2(3.0, 2.0), Vector3(1.4, 0.8, 1.4), _mat_scories(), hasard)
	# Les tas de scories derrière les fours.
	for k in 5:
		var p := Vector2(FOURS.position.x + 4.0 + k * 9.0, FOURS.position.y - 6.0 + hasard.randf_range(-2, 2))
		_tas(d, p, Vector3(hasard.randf_range(4.0, 6.0), hasard.randf_range(2.5, 4.0), hasard.randf_range(3.5, 5.0)), _mat_scories(), hasard)
	# Un abri de bois pour le charbon.
	var abri := FOURS_CENTRE + Vector2(0, 10)
	var ha := hauteur(abri.x, abri.y)
	for x in [-4.0, 4.0]:
		for z in [-2.0, 2.0]:
			_boite(Vector3(0.25, 2.6, 0.25), Vector3(abri.x + x, ha + 1.3, abri.y + z), _mat_bois(), d)
	_boite(Vector3(9.0, 0.2, 5.0), Vector3(abri.x, ha + 2.7, abri.y), _mat_bois(), d, false)
	_tas(d, abri, Vector3(3.5, 1.2, 1.8), _mat_scories(), hasard)


## La grande citerne de l'est : un bassin carré, enduit, où l'on garde l'eau des rares
## pluies de l'hiver. Les hommes de Masque y ont ouvert une vanne et creusé un canal
## qui descend vers les puits : de quoi noyer les galeries.
func _construire_citerne() -> void:
	var d := _dossier("Citerne")
	var r := CITERNE
	var h := _plat(Vector2(r.get_center().x, r.get_center().y + 10.0))
	var pierre := _mat_pierre()
	for cote in [[Vector3(r.size.x + 1.2, 1.6, 0.6), Vector3(r.get_center().x, h + 0.8, r.position.y)],
			[Vector3(0.6, 1.6, r.size.y), Vector3(r.position.x, h + 0.8, r.get_center().y)],
			[Vector3(0.6, 1.6, r.size.y), Vector3(r.end.x, h + 0.8, r.get_center().y)],
			[Vector3(VANNE.x - 1.6 - r.position.x, 1.6, 0.6), Vector3((r.position.x + VANNE.x - 1.6) * 0.5, h + 0.8, r.end.y)],
			[Vector3(r.end.x - VANNE.x - 1.6, 1.6, 0.6), Vector3((r.end.x + VANNE.x + 1.6) * 0.5, h + 0.8, r.end.y)]]:
		_boite(cote[0], cote[1], pierre, d)
	var eau := _boite(Vector3(r.size.x - 0.6, 0.05, r.size.y - 0.6), Vector3(r.get_center().x, h + 1.2, r.get_center().y), _mat_eau(), d, false)
	eau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mur_invisible(d, Vector3(r.size.x, 3.0, r.size.y), Vector3(r.get_center().x, h + 1.5, r.get_center().y))
	# La vanne : deux montants et une planche qu'on peut faire glisser.
	for x in [-1.4, 1.4]:
		_boite(Vector3(0.35, 2.4, 0.35), Vector3(VANNE.x + x, h + 1.2, r.end.y), _mat_bois(), d)
	_boite(Vector3(3.2, 0.3, 0.3), Vector3(VANNE.x, h + 2.4, r.end.y), _mat_bois(), d, false)
	var planche := _boite(Vector3(2.5, 1.4, 0.12), Vector3(VANNE.x, h + 2.0, r.end.y), _mat_bois(), d, false)
	planche.name = "PlancheVanne"
	planche.set_meta("identifiant", "planche_vanne")
	# Le canal : une tranchée boisée qui descend vers la colline des puits, et l'eau qui y court.
	var depart := Vector2(VANNE.x, r.end.y + 1.0)
	var arrivee := PUITS + Vector2(8.0, -4.0)
	var canal := Node3D.new()
	canal.name = "EauCanal"
	canal.set_meta("identifiant", "eau_canal")
	canal.add_to_group("decor_quete")
	d.add_child(canal)
	var n := 24
	for k in n:
		var a := depart.lerp(arrivee, float(k) / n)
		var b := depart.lerp(arrivee, float(k + 1) / n)
		var m := (a + b) * 0.5
		var longueur := a.distance_to(b) + 0.2
		var angle := atan2(b.x - a.x, b.y - a.y)
		var ym := hauteur(m.x, m.y)
		var lit := _boite(Vector3(1.4, 0.1, longueur), Vector3(m.x, ym + 0.05, m.y), _mat_bois(), d, false)
		lit.rotation.y = angle
		var filet := _boite(Vector3(1.0, 0.04, longueur), Vector3(m.x, ym + 0.13, m.y), _mat_eau(), canal, false)
		filet.rotation.y = angle
		filet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Le camp des mercenaires de Masque : des tentes de cuir, des caisses, un feu. Sous
## une toile, des sacs pleins de tessons de poterie gravés.
func _construire_camp() -> void:
	var d := _dossier("Camp")
	var cuir := _mat_choix(["brown_leather"], Color(0.42, 0.3, 0.2), 0.85, 1.5)
	for k in 3:
		var p := CAMP + Vector2(-6.0 + k * 6.5, -3.0 if k == 1 else 2.0)
		var h := hauteur(p.x, p.y)
		var tente := Node3D.new()
		tente.position = Vector3(p.x, h, p.y)
		tente.rotation.y = 0.2 * (k - 1)
		d.add_child(tente)
		for cote: float in [-1.0, 1.0]:
			var pan := _boite(Vector3(0.06, 2.9, 4.2), Vector3(cote * 1.05, 1.1, 0), cuir, tente, false)
			pan.rotation.z = cote * 0.62
		_boite(Vector3(0.12, 2.4, 0.12), Vector3(0, 1.2, 2.0), _mat_bois(), tente)
	for k in 5:
		var p := CAMP + Vector2(8.0 + (k % 2) * 1.2, -4.0 + k * 1.1)
		_boite(Vector3(1.0, 0.8, 0.9), Vector3(p.x, hauteur(p.x, p.y) + 0.4, p.y), _mat_bois(), d)
	_fumee(d, Vector3(CAMP.x, hauteur(CAMP.x, CAMP.y + 6.0) + 0.2, CAMP.y + 6.0))
	# Une radio moderne, mal cachée sous une couverture : le voyant rouge clignote.
	var radio := _boite(Vector3(0.4, 0.25, 0.2), Vector3(CAMP.x + 8.6, hauteur(CAMP.x + 8.6, CAMP.y) + 0.95, CAMP.y), _metal(), d, false)
	_boite(Vector3(0.04, 0.04, 0.02), Vector3(0.12, 0.06, 0.11), _lumineux(Color(1.0, 0.1, 0.05), 4.0), radio, false)


## L'entrée de la mine (au pied de la colline, face au nord) et la vieille descenderie
## (sur le flanc est) : un cadre de poutres, la bouche noire de la galerie.
func _construire_entrees_mine() -> void:
	var d := _dossier("EntreesMine")
	_bouche_mine(d, PUITS, 0.0)
	_bouche_mine(d, DESCENDERIE, -PI / 2)
	# Le treuil du grand puits, à côté de l'entrée.
	var t := PUITS + Vector2(6, -4)
	var ht := hauteur(t.x, t.y)
	_boite(Vector3(2.4, 0.5, 2.4), Vector3(t.x, ht + 0.25, t.y), _mat_pierre(), d)
	for x in [-1.0, 1.0]:
		_boite(Vector3(0.2, 1.8, 0.2), Vector3(t.x + x, ht + 1.2, t.y), _mat_bois(), d)
	var axe := MeshInstance3D.new()
	axe.mesh = _cylindre(0.15, 0.15, 2.2, 10)
	axe.material_override = _mat_bois()
	axe.rotation.z = PI / 2
	axe.position = Vector3(t.x, ht + 1.9, t.y)
	d.add_child(axe)


func _bouche_mine(parent: Node3D, p: Vector2, angle: float) -> void:
	var h := hauteur(p.x, p.y)
	var n := Node3D.new()
	n.position = Vector3(p.x, h, p.y)
	n.rotation.y = angle
	parent.add_child(n)
	var bois := _mat_bois()
	var roche := _mat_choix(["rock_boulder_dry", "cliff_side"], Color(0.62, 0.6, 0.57), 0.95, 2.0)
	# Le front de taille : un bloc de roche dans lequel s'ouvre la galerie.
	_boite(Vector3(4.0, 7.0, 6.0), Vector3(-3.6, 2.5, 2.0), roche, n)
	_boite(Vector3(4.0, 7.0, 6.0), Vector3(3.6, 2.5, 2.0), roche, n)
	_boite(Vector3(11.2, 4.0, 6.0), Vector3(0, 4.9, 2.0), roche, n)
	var noir := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(3.2, 3.0)
	noir.mesh = q
	noir.material_override = _mat_pbr("", Color(0.0, 0.0, 0.0), 1.0)
	noir.position = Vector3(0, 1.5, 1.2)
	noir.rotation.y = PI
	n.add_child(noir)
	for x in [-1.5, 1.5]:
		_boite(Vector3(0.3, 2.9, 0.3), Vector3(x, 1.45, -0.6), bois, n)
	_boite(Vector3(3.6, 0.35, 0.35), Vector3(0, 3.0, -0.6), bois, n)
	var lampe := OmniLight3D.new()
	lampe.light_color = Color(1.0, 0.62, 0.3)
	lampe.light_energy = 1.2
	lampe.omni_range = 5.0
	lampe.position = Vector3(1.2, 2.4, -1.2)
	n.add_child(lampe)


func _construire_rochers() -> void:
	var d := _dossier("Rochers")
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 5
	var roche := _mat_choix(["rock_boulder_dry", "cliff_side"], Color(0.62, 0.6, 0.57), 0.95, 2.0)
	for k in 70:
		var p := Vector2(hasard.randf_range(-150, 150), hasard.randf_range(-150, 150))
		if _distance_chemins(p) < 6.0 or p.distance_to(PUITS) < 14.0 or p.distance_to(DESCENDERIE) < 14.0:
			continue
		var dans := false
		for r: Rect2 in [ERGASTERION, CABANES, FOURS, CITERNE.grow(8.0), Rect2(CAMP.x - 14, CAMP.y - 10, 28, 20)]:
			if r.grow(4.0).has_point(p):
				dans = true
		if dans:
			continue
		_tas(d, p, Vector3(hasard.randf_range(0.8, 2.6), hasard.randf_range(0.6, 1.8), hasard.randf_range(0.8, 2.4)), roche, hasard)
	# Les déblais des vieux puits, sur la colline.
	for k in 8:
		var a := hasard.randf() * TAU
		var p := COLLINE + Vector2(cos(a) * COLLINE_RAYONS.x * 0.55, sin(a) * COLLINE_RAYONS.y * 0.55)
		_tas(d, p, Vector3(3.0, 1.4, 3.0), _mat_minerai(), hasard)


func _construire_lointain() -> void:
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.8
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 70
	_plan_lointain(Vector3(0, 8.0, -1080), Vector2(4000, 1840), Color(0, 1, 0))
	_plan_lointain(Vector3(0, 8.0, 1080), Vector2(4000, 1840), Color(0, 1, 0))
	_plan_lointain(Vector3(-1080, 8.0, 0), Vector2(1840, 320), Color(0, 1, 0))
	_plan_lointain(Vector3(1080, 8.0, 0), Vector2(1840, 320), Color(0, 1, 0))
	# Des collines pelées partout, et la mer au sud-est (le cap Sounion, plus loin).
	for m in [[Vector3(-500, -10, 200), Vector3(400, 160, 600)], [Vector3(600, -10, -300), Vector3(500, 180, 700)],
			[Vector3(0, -10, -900), Vector3(1200, 220, 300)], [Vector3(-300, -10, -500), Vector3(300, 140, 300)]]:
		bruit.seed = graine + hasard.randi()
		var montagne := MeshInstance3D.new()
		montagne.mesh = _maillage_bosse(bruit, m[1], 1.4, 0.3, 28, Color(1, 0.0, 0.0))
		montagne.material_override = _mat_lointain()
		montagne.position = m[0]
		montagne.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(montagne)


func _construire_limites() -> void:
	var limites := _dossier("Limites")
	var demi := taille_terrain * 0.5 - 4.0
	_mur_invisible(limites, Vector3(2, 160, taille_terrain), Vector3(-demi, 40, 0))
	_mur_invisible(limites, Vector3(2, 160, taille_terrain), Vector3(demi, 40, 0))
	_mur_invisible(limites, Vector3(taille_terrain, 160, 2), Vector3(0, 40, demi))
	_mur_invisible(limites, Vector3(taille_terrain, 160, 2), Vector3(0, 40, ENTREE.y - 4.0))
	# On ne grimpe pas sur la colline des puits : elle est percée de partout.
	for k in 32:
		var a := TAU * k / 32.0
		var p := COLLINE + Vector2(cos(a) * (COLLINE_RAYONS.x * 0.9), sin(a) * (COLLINE_RAYONS.y * 0.9))
		_mur_invisible(limites, Vector3(12, 80, 2), Vector3(p.x, hauteur(p.x, p.y) + 30.0, p.y),
				-atan2(sin(a) * COLLINE_RAYONS.x, cos(a) * COLLINE_RAYONS.y) + PI / 2)


# --- Personnages et objets de la quête ----------------------------------------------------------

func _construire_quete() -> void:
	var dossier := _dossier("Quete")
	_dossier_quete = dossier
	_pnj(dossier, "sosias", SOSIAS, PI * 0.5)
	_pnj(dossier, "daos", DAOS, PI)
	_pnj(dossier, "mineur_thrace", DAOS + Vector2(-5, 2), PI * 0.8)
	_pnj(dossier, "mineuse_laveuse", ERGASTERION.get_center() + Vector2(-8, 4), 0.4)
	var vera := _pnj(dossier, "vera_laurion", VERA, -PI / 2)
	vera.add_to_group("decor_quete")
	vera.set_meta("identifiant", "vera_laurion")
	vera.visible = false
	var vanne := ObjetGrece.new()
	vanne.name = "Vanne"
	vanne.identifiant = "vanne_citerne"
	vanne.invite = "[F] Refermer la vanne"
	vanne.portee = 2.5
	vanne.position = Vector3(VANNE.x, hauteur(VANNE.x, VANNE.y), VANNE.y)
	dossier.add_child(vanne)
	var sac := ObjetGrece.new()
	sac.name = "SacOstraka"
	sac.identifiant = "sac_ostraka"
	sac.forme = "ostraka"
	sac.invite = "[F] Fouiller les sacs"
	sac.portee = 2.0
	sac.position = Vector3(OSTRAKA.x, hauteur(OSTRAKA.x, OSTRAKA.y), OSTRAKA.y)
	dossier.add_child(sac)
	# Repères de la carte.
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.LIEU, "Route des Oliveraies", ENTREE + Vector2(0, 6))
	repere.call(MarqueurCarte.Type.LIEU, "Atelier de lavage", ERGASTERION.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Cabanes des mineurs", CABANES.get_center())
	repere.call(MarqueurCarte.Type.LIEU, "Fours", FOURS_CENTRE)
	repere.call(MarqueurCarte.Type.LIEU, "Grande citerne", CITERNE.get_center())
	repere.call(MarqueurCarte.Type.DANGER, "Camp des mercenaires", CAMP)
	repere.call(MarqueurCarte.Type.LIEU, "Entrée de la mine", PUITS + Vector2(0, -4))
	repere.call(MarqueurCarte.Type.LIEU, "Vieille descenderie", DESCENDERIE + Vector2(6, 0))


# --- Sorties : les Oliveraies au nord, la mine au sud -------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	if Engine.is_editor_hint():
		return
	_attente_sortie -= delta
	if _attente_sortie > 0.0:
		return
	_attente_sortie = 0.3
	var quete := get_tree().get_first_node_in_group("quete")
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if quete == null or joueur == null or not quete.has_method("changer_de_zone"):
		return
	var p := Vector2(joueur.global_position.x, joueur.global_position.z)
	if p.y < ENTREE.y - 1.0 and absf(p.x) < 8.0:
		quete.changer_de_zone("oliveraies")
	elif absf(p.x - PUITS.x) < 1.6 and p.y > PUITS.y - 0.2 and p.y < PUITS.y + 3.0:
		Reseau.set_meta("galeries_par", "puits")
		quete.changer_de_zone("galeries_laurion")
	elif absf(p.y - DESCENDERIE.y) < 1.6 and p.x < DESCENDERIE.x + 0.2 and p.x > DESCENDERIE.x - 3.0:
		Reseau.set_meta("galeries_par", "descenderie")
		quete.changer_de_zone("galeries_laurion")
