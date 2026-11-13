@tool
extends "res://scripts/monde/prehistoire/ile_prehistoire.gd"
## Île de la Préhistoire, zone 1 : la Côte Gelée (niveaux 1-3).
##
## Il y a environ 17 000 ans, en pleine période glaciaire. Une crique de galets
## entre deux falaises de calcaire, une mer froide où flottent des blocs de
## glace, un plateau enneigé qui monte vers le col de la Steppe des Mammouths
## (au nord). Le portail de la Vigie est installé sur la plage.
##
## Tout est construit par le code au lancement (voir ile_prehistoire.gd).
## Le bouton « Reconstruire » de l'Inspecteur refait tout.
##
## Repères : le nord est vers -Z, la mer au sud (+Z).

const Pnj := preload("res://scripts/monde/prehistoire/pnj_epoque.gd")
const Faille := preload("res://scripts/monde/prehistoire/faille.gd")
const ObjetQuete := preload("res://scripts/monde/prehistoire/objet_quete.gd")
const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const SHADER_MER := preload("res://shaders/prehistoire_mer.gdshader")

## Le portail de la Vigie, sur la plage.
const PORTAIL := Vector2(0, 47)
## L'agent Lenoir, blessé contre un rocher.
const LENOIR := Vector2(-7, 36)
## Les caisses renversées où se trouve la trousse de soin.
const CAISSES := Vector2(13, 27)
## La faille ouverte au nord du camp.
const FAILLE := Vector2(3, 0)
## Le col qui mène à la Steppe des Mammouths.
const COL := Vector2(10, -138)
## Le squelette de mammouth, sur le plateau.
const MAMMOUTH := Vector2(-34, -34)

var _rivage: FastNoiseLite
var _voile_portail: MeshInstance3D
var _zone_portail: Area3D
var _portail_arme := false


func _init() -> void:
	identifiant_zone = "cote_gelee"
	point_apparition = Vector2(0, 41)
	# La piste qui monte du camp vers le col (les pas ont tassé la neige).
	piste = [Vector2(0, 42), Vector2(3, 14), Vector2(-4, -20), Vector2(-2, -60), Vector2(6, -100), Vector2(10, -140)]


func _ready() -> void:
	# On arrive par le col quand on revient de la Steppe.
	if not Engine.is_editor_hint() and Reseau.get_meta("arrivee_prehistoire", "") == "steppe":
		Reseau.remove_meta("arrivee_prehistoire")
		point_apparition = COL + Vector2(0, 14)
	super._ready()


func _chaque_image(_delta: float) -> void:
	if _voile_portail != null and is_instance_valid(_voile_portail):
		_voile_portail.rotation.z = _temps * 0.4
	if Engine.is_editor_hint():
		return
	_surveiller_portail()
	_surveiller_col()


func sortie_vers(zone: String) -> Vector2:
	# Toutes les autres zones de l'île passent par le col et la steppe.
	return COL + Vector2(0, 8) if zone != "cote_gelee" else Vector2.INF


# --- Relief ----------------------------------------------------------------

func _preparer_bruits() -> void:
	super._preparer_bruits()
	_rivage = FastNoiseLite.new()
	_rivage.seed = graine + 2
	_rivage.frequency = 0.012
	_rivage.fractal_octaves = 3


## Position (z) du bord de l'eau pour une position x : une crique au centre.
func ligne_rivage(x: float) -> float:
	if _rivage == null:
		_preparer_bruits()
	return 68.0 - 9.0 * exp(-pow(x / 55.0, 2.0)) + _rivage.get_noise_1d(x) * 7.0


## Hauteur du sol (mètres) à une position x, z du monde.
func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	# Distance au rivage : positive dans les terres, négative sous l'eau.
	var s := ligne_rivage(x) - z
	var h: float
	if s < 0.0:
		h = maxf(s * 0.16, -9.0)
	else:
		# Plage de galets en pente douce, puis plateau qui monte vers le nord.
		h = s * 0.06 + smoothstep(22.0, 75.0, s) * 4.5 + smoothstep(80.0, 200.0, s) * 7.5
	var terres := smoothstep(6.0, 40.0, s)
	h += _relief.get_noise_2d(x, z) * 3.2 * terres
	# Congères : bosses allongées par le vent.
	h += absf(_details.get_noise_2d(x * 0.6, z * 1.4)) * 0.9 * terres
	h += _details.get_noise_2d(x * 4.0, z * 4.0) * 0.08
	# Falaises de calcaire à l'ouest et à l'est (elles plongent dans la mer).
	var bord := absf(x) + _relief.get_noise_2d(z * 0.9, 300.0) * 12.0 + _details.get_noise_2d(z * 0.6, 40.0) * 3.0
	var limite := 98.0 if x < 0.0 else 106.0
	var falaise := smoothstep(limite - 4.0, limite + 3.0, bord)
	var haut_falaise := (23.0 if x < 0.0 else 29.0) + _relief.get_noise_2d(x * 1.5, z * 1.5) * 5.0 \
			+ (1.0 - absf(_details.get_noise_2d(x * 0.3, z * 0.3))) * 6.0
	h = lerpf(h, maxf(h, haut_falaise), falaise)
	# Montagnes au nord, sauf le col qui mène à la Steppe.
	var col := exp(-pow((x - COL.x) / 14.0, 2.0))
	var nord := smoothstep(-108.0, -150.0, z + _relief.get_noise_2d(x * 0.8, 77.0) * 10.0)
	# Des crêtes découpées plutôt que des dunes arrondies.
	var crete := 1.0 - absf(_relief.get_noise_2d(x * 2.2, z * 2.2 + 500.0))
	h += nord * (26.0 + crete * crete * 26.0) * (1.0 - col * 0.8)
	# Bords du terrain : de hautes crêtes pour ne jamais voir le vide.
	h += smoothstep(138.0, 158.0, absf(x)) * (18.0 + crete * 14.0)
	return h


## Part de chaque sol (galets, neige, terre) à une position : rouge, vert, bleu.
func _parts_sol(x: float, z: float, h: float) -> Color:
	var s := ligne_rivage(x) - z
	var n := _relief.get_noise_2d(x * 2.0 + 90.0, z * 2.0)
	var galets := 1.0 - smoothstep(14.0, 28.0, s + n * 9.0)
	var neige := smoothstep(16.0, 46.0, s + n * 22.0) + smoothstep(10.0, 18.0, h) * 0.8
	# Autour du camp de la Vigie et sur la piste, la neige est tassée et fondue.
	var camp := exp(-Vector2(x, z).distance_squared_to(Vector2(2, 34)) / 260.0)
	var sur_piste := exp(-pow(_distance_piste(Vector2(x, z)) / 2.6, 2.0))
	neige *= 1.0 - maxf(camp * 0.85, sur_piste * 0.7)
	return Color(galets, clampf(neige, 0.0, 1.0), 1.0 - galets, 1.0)




# --- Construction ------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_construire_terrain()
	_construire_mer()
	_construire_glace()
	_construire_rochers()
	_construire_bois_flotte()
	_construire_touffes()
	_construire_camp_vigie()
	_construire_squelette_mammouth()
	_construire_lointain()
	_construire_limites()
	_construire_quete()
	_construire_neige_qui_tombe()
	_appliquer_ciel()


# --- Ressources Poly Haven -----------------------------------------------------













# --- Terrain ---------------------------------------------------------------------



# --- Mer et glace ------------------------------------------------------------------

func _construire_mer() -> void:
	var plan := PlaneMesh.new()
	plan.size = Vector2(2400, 2000)
	plan.subdivide_width = 120
	plan.subdivide_depth = 100
	var m := ShaderMaterial.new()
	m.shader = SHADER_MER
	m.set_shader_parameter("vagues_a", _texture_vagues(graine + 30, 0.02))
	m.set_shader_parameter("vagues_b", _texture_vagues(graine + 31, 0.05))
	m.set_shader_parameter("bruit_ecume", _bruit())
	var mer := MeshInstance3D.new()
	mer.name = "Mer"
	mer.mesh = plan
	mer.material_override = m
	mer.position = Vector3(0, NIVEAU_MER, 700)
	mer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_contenu.add_child(mer)












func _construire_glace() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 40
	var dossier := Node3D.new()
	dossier.name = "Glace"
	_contenu.add_child(dossier)
	# Plaques de glace dérivantes près du rivage.
	var places := 0
	var essais := 0
	while places < 46 and essais < 600:
		essais += 1
		var x := hasard.randf_range(-150.0, 150.0)
		var z := hasard.randf_range(70.0, 260.0)
		if hauteur(x, z) > -1.5:
			continue
		var rayon := hasard.randf_range(1.5, 6.0) * (1.0 + (z - 70.0) / 200.0)
		var plaque := MeshInstance3D.new()
		plaque.mesh = _maillage_banquise(hasard, rayon, hasard.randf_range(0.35, 0.8))
		plaque.position = Vector3(x, NIVEAU_MER + hasard.randf_range(-0.05, 0.08), z)
		plaque.rotation.y = hasard.randf() * TAU
		dossier.add_child(plaque)
		places += 1
	# Icebergs au large.
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.7
	for k in 7:
		bruit.seed = graine + 50 + k
		var taille := hasard.randf_range(8.0, 22.0)
		var berg := MeshInstance3D.new()
		berg.mesh = _maillage_bosse(bruit, Vector3(taille, taille * hasard.randf_range(0.5, 0.9), taille * 0.8), 1.6, 0.45, 20)
		berg.material_override = _mat_glace()
		berg.position = Vector3(hasard.randf_range(-260.0, 260.0), -taille * 0.25, hasard.randf_range(170.0, 520.0))
		berg.rotation.y = hasard.randf() * TAU
		dossier.add_child(berg)
	# Glace collée au pied des falaises.
	for k in 40:
		var cote := -1.0 if k % 2 == 0 else 1.0
		var x := cote * hasard.randf_range(75.0, 115.0)
		var z := ligne_rivage(x) + hasard.randf_range(-2.0, 14.0)
		if hauteur(x, z) > NIVEAU_MER - 0.2:
			continue
		var bloc := MeshInstance3D.new()
		bloc.mesh = _maillage_banquise(hasard, hasard.randf_range(2.0, 4.0), hasard.randf_range(0.6, 1.4))
		bloc.position = Vector3(x, NIVEAU_MER + 0.05, z)
		bloc.rotation = Vector3(hasard.randf_range(-0.15, 0.15), hasard.randf() * TAU, hasard.randf_range(-0.15, 0.15))
		dossier.add_child(bloc)


# --- Rochers ---------------------------------------------------------------------

func _construire_rochers() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 12
	var dossier := Node3D.new()
	dossier.name = "Rochers"
	_contenu.add_child(dossier)
	_preparer_rochers()
	var placer := func(x: float, z: float, taille: float, enfoui := 0.35) -> void:
		_placer_rocher(dossier, x, z, taille, enfoui)
	# Éboulis au pied des falaises : on cherche, sur chaque ligne, où la pente commence.
	for k in 150:
		var cote := -1.0 if k % 2 == 0 else 1.0
		var z := hasard.randf_range(-110.0, 75.0)
		var x := cote * 70.0
		while absf(x) < 130.0 and hauteur(x + cote, z) - hauteur(x, z) < 0.6:
			x += cote
		x -= cote * hasard.randf_range(0.0, 7.0)
		placer.call(x, z, hasard.randf_range(0.8, 4.2) * (1.6 if hasard.randf() < 0.15 else 1.0))
	# Pans de roche scannés plaqués contre les falaises.
	for k in 36:
		var cote := -1.0 if k % 2 == 0 else 1.0
		var z := hasard.randf_range(-105.0, 70.0)
		var x := cote * 70.0
		while absf(x) < 130.0 and hauteur(x + cote, z) - hauteur(x, z) < 0.8:
			x += cote
		var id := "rock_face_01" if hasard.randf() < 0.5 else "rock_face_02"
		var pan := _modele(id, Vector3(x + cote * 1.5, hauteur(x, z) - 1.0, z), (PI / 2 if cote > 0 else -PI / 2) + hasard.randf_range(-0.4, 0.4),
				hasard.randf_range(3.5, 6.5), dossier)
		if pan != null:
			pan.rotation.x = hasard.randf_range(-0.1, 0.1)
	# Amas de gros rochers sur le plateau (on s'en sert pour se repérer).
	for k in 16:
		var cx := hasard.randf_range(-80.0, 85.0)
		var cz := hasard.randf_range(-115.0, 20.0)
		if Vector2(cx, cz).distance_to(FAILLE) < 14.0 or _distance_piste(Vector2(cx, cz)) < 8.0:
			continue
		for r in hasard.randi_range(2, 5):
			placer.call(cx + hasard.randf_range(-5.0, 5.0), cz + hasard.randf_range(-5.0, 5.0), hasard.randf_range(1.2, 3.8))
	# Rochers épars sur la plage et le plateau.
	var places := 0
	var essais := 0
	while places < 240 and essais < 3000:
		essais += 1
		var x := hasard.randf_range(-95.0, 100.0)
		var z := hasard.randf_range(-130.0, 72.0)
		var p := Vector2(x, z)
		# On garde dégagés le camp, la piste et la faille.
		if p.distance_to(Vector2(2, 38)) < 16.0 or _distance_piste(p) < 4.0 or p.distance_to(FAILLE) < 8.0:
			continue
		var grand := hasard.randf() < 0.18
		placer.call(x, z, hasard.randf_range(1.4, 3.2) if grand else hasard.randf_range(0.25, 0.9))
		places += 1
	# Le rocher contre lequel Lenoir s'est abrité.
	placer.call(LENOIR.x - 1.6, LENOIR.y - 1.2, 1.5, 0.3)


# --- Bois flotté et bois mort ---------------------------------------------------

func _construire_bois_flotte() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 60
	var dossier := Node3D.new()
	dossier.name = "BoisFlotte"
	_contenu.add_child(dossier)
	var bois := _mat_pbr("rough_wood", Color(0.72, 0.68, 0.62), 0.95, 1.5)
	var modeles: Array[String] = []
	for id in MODELES_BOIS:
		if ResourceLoader.exists(DOSSIER + "modeles/%s/%s.gltf" % [id, id]):
			modeles.append(id)
	for k in 34:
		var x := hasard.randf_range(-85.0, 90.0)
		var z := ligne_rivage(x) - hasard.randf_range(3.0, 16.0)
		if Vector2(x, z).distance_to(PORTAIL) < 9.0:
			continue
		var y := hauteur(x, z)
		var angle := hasard.randf() * TAU
		if not modeles.is_empty() and hasard.randf() < 0.5:
			var m := _modele(modeles[hasard.randi() % modeles.size()], Vector3(x, y - 0.1, z), angle,
					hasard.randf_range(0.6, 1.1), dossier)
			if m != null:
				continue
		# Tronc blanchi par le sel et le gel.
		var longueur := hasard.randf_range(1.5, 5.5)
		var tronc := MeshInstance3D.new()
		var cylindre := CylinderMesh.new()
		cylindre.top_radius = hasard.randf_range(0.06, 0.12)
		cylindre.bottom_radius = hasard.randf_range(0.14, 0.26)
		cylindre.height = longueur
		cylindre.radial_segments = 9
		tronc.mesh = cylindre
		tronc.material_override = bois
		tronc.position = Vector3(x, y + 0.1, z)
		tronc.rotation = Vector3(PI / 2 + hasard.randf_range(-0.08, 0.08), angle, 0)
		dossier.add_child(tronc)


# --- Herbe sèche ------------------------------------------------------------------





# --- Camp de la Vigie et portail ---------------------------------------------------







func _construire_camp_vigie() -> void:
	var camp := Node3D.new()
	camp.name = "CampVigie"
	_contenu.add_child(camp)
	var cyan := Color(0.3, 0.85, 1.0)
	# --- Le portail : un anneau dressé sur un socle, tourné vers les terres.
	var sol := hauteur(PORTAIL.x, PORTAIL.y)
	var portail := Node3D.new()
	portail.name = "Portail"
	portail.position = Vector3(PORTAIL.x, sol, PORTAIL.y)
	camp.add_child(portail)
	var socle := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 3.0
	cyl.bottom_radius = 3.3
	cyl.height = 0.8
	socle.mesh = cyl
	socle.material_override = _metal()
	socle.position.y = 0.1
	portail.add_child(socle)
	var anneau := MeshInstance3D.new()
	var tore := TorusMesh.new()
	tore.inner_radius = 2.1
	tore.outer_radius = 2.5
	tore.rings = 48
	anneau.mesh = tore
	anneau.material_override = _metal()
	anneau.rotation.x = PI / 2
	anneau.position.y = 3.0
	portail.add_child(anneau)
	var lisere := MeshInstance3D.new()
	var tore2 := TorusMesh.new()
	tore2.inner_radius = 2.08
	tore2.outer_radius = 2.16
	tore2.rings = 48
	lisere.mesh = tore2
	lisere.material_override = _lumineux(cyan, 4.0)
	lisere.rotation.x = PI / 2
	lisere.position.y = 3.0
	portail.add_child(lisere)
	# Voile tourbillonnant (une faille apprivoisée, en bleu).
	_voile_portail = MeshInstance3D.new()
	var disque := QuadMesh.new()
	disque.size = Vector2(4.3, 4.3)
	_voile_portail.mesh = disque
	var voile := ShaderMaterial.new()
	voile.shader = preload("res://shaders/prehistoire_portail.gdshader")
	voile.set_shader_parameter("bruit", _bruit())
	_voile_portail.material_override = voile
	_voile_portail.position.y = 3.0
	_voile_portail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	portail.add_child(_voile_portail)
	var lumiere := OmniLight3D.new()
	lumiere.light_color = cyan
	lumiere.light_energy = 2.5
	lumiere.omni_range = 14.0
	lumiere.position = Vector3(0, 3.0, -1.5)
	portail.add_child(lumiere)
	# Collision des montants (on ne traverse pas l'anneau par les côtés).
	for cote in [-1.0, 1.0]:
		_boite(Vector3(0.5, 5.2, 0.6), Vector3(cote * 2.3, 2.7, 0), _metal(), portail).visible = false
	# Zone de retour vers Hikari Bay, au centre de l'anneau.
	_zone_portail = Area3D.new()
	_zone_portail.name = "RetourHub"
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(3.2, 3.5, 0.8)
	forme.shape = boite
	_zone_portail.add_child(forme)
	_zone_portail.position = Vector3(0, 2.4, 0)
	_zone_portail.collision_mask = 2
	_zone_portail.monitoring = true
	portail.add_child(_zone_portail)
	_zone_portail.body_entered.connect(_sur_portail)
	# Câbles et générateur.
	var generateur := _boite(Vector3(1.4, 1.0, 0.9), Vector3(PORTAIL.x + 4.5, sol + 0.5, PORTAIL.y + 1.5),
			_mat_pbr("", Color(0.28, 0.29, 0.29), 0.55), camp)
	generateur.rotation.y = 0.3
	_boite(Vector3(0.9, 0.06, 0.5), Vector3(0, 0.53, 0), _lumineux(cyan, 2.0), generateur, false)
	# --- Tente de la Vigie (un dôme de toile technique), arrachée par les fracturés.
	var t := Vector2(10, 37)
	var tente := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 1.9
	dome.height = 1.9
	dome.is_hemisphere = true
	dome.radial_segments = 24
	dome.rings = 8
	tente.mesh = dome
	var toile := _mat_pbr("", Color(0.36, 0.39, 0.37), 0.75)
	toile.uv1_triplanar = false
	tente.material_override = toile
	tente.position = Vector3(t.x, hauteur(t.x, t.y) - 0.05, t.y)
	tente.rotation = Vector3(0.0, 0.7, 0.08)
	tente.scale = Vector3(1.0, 0.85, 1.15)
	camp.add_child(tente)
	# Arceaux de la tente.
	for k in 2:
		var arceau := MeshInstance3D.new()
		var cerceau := TorusMesh.new()
		cerceau.inner_radius = 1.88
		cerceau.outer_radius = 1.95
		cerceau.rings = 32
		arceau.mesh = cerceau
		arceau.material_override = _metal()
		arceau.rotation = Vector3(PI / 2, 0, PI / 4 + k * PI / 2)
		tente.add_child(arceau)
	# Toile déchirée : l'entrée est ouverte.
	var entree := MeshInstance3D.new()
	var ouverture := QuadMesh.new()
	ouverture.size = Vector2(1.0, 1.1)
	entree.mesh = ouverture
	entree.material_override = _mat_pbr("", Color(0.04, 0.04, 0.05), 1.0)
	entree.position = Vector3(0, 0.55, 1.75)
	entree.rotation.x = -0.35
	tente.add_child(entree)
	# --- Projecteurs sur trépied.
	for p in [Vector2(-6, 44), Vector2(7, 43), Vector2(-3, 30)]:
		_projecteur(camp, p, cyan)
	# --- Caisses (renversées là où se trouve la trousse).
	var caisses := [
		[Vector2(CAISSES.x - 1.2, CAISSES.y), 0.4, 0.0], [Vector2(CAISSES.x + 0.9, CAISSES.y + 0.8), 1.2, 1.4],
		[Vector2(CAISSES.x + 0.3, CAISSES.y - 1.4), 2.4, 1.57], [Vector2(-4, 46), 0.1, 0.0],
		[Vector2(-4.2, 47.2), 0.3, 0.0], [Vector2(5, 49), 2.0, 0.0],
	]
	for c in caisses:
		var p: Vector2 = c[0]
		var y := hauteur(p.x, p.y)
		var m := _modele_hub("plastic_crate_01", Vector3(p.x, y, p.y), c[1], camp)
		if m == null:
			m = _boite(Vector3(0.6, 0.4, 0.4), Vector3(p.x, y + 0.2, p.y), _mat_pbr("", Color(0.2, 0.3, 0.38), 0.6), camp)
		m.rotation.z = c[2]
		if c[2] != 0.0:
			m.position.y += 0.2




func _projecteur(parent: Node3D, p: Vector2, couleur: Color) -> void:
	var y := hauteur(p.x, p.y)
	var pied := Node3D.new()
	pied.position = Vector3(p.x, y, p.y)
	parent.add_child(pied)
	for k in 3:
		var jambe := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.025
		c.bottom_radius = 0.03
		c.height = 2.1
		jambe.mesh = c
		jambe.material_override = _metal()
		var a := TAU * k / 3.0
		jambe.position = Vector3(cos(a) * 0.35, 1.0, sin(a) * 0.35)
		jambe.rotation = Vector3(sin(a) * 0.17, 0, -cos(a) * 0.17)
		pied.add_child(jambe)
	var tete := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.45, 0.3, 0.2)
	tete.mesh = b
	tete.material_override = _metal()
	tete.position.y = 2.1
	pied.add_child(tete)
	var vitre := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.38, 0.22)
	vitre.mesh = q
	vitre.material_override = _lumineux(Color(1.0, 0.95, 0.85), 6.0)
	vitre.position = Vector3(0, 2.1, -0.11)
	vitre.rotation.y = PI
	pied.add_child(vitre)
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.95, 0.88)
	spot.light_energy = 3.0
	spot.spot_range = 22.0
	spot.spot_angle = 38.0
	spot.position = Vector3(0, 2.1, -0.2)
	spot.rotation.x = -0.35
	spot.add_to_group("lumiere_secondaire")
	pied.add_child(spot)
	# Le projecteur éclaire le camp (vers son centre).
	var centre := Vector3(2, y, 36)
	var vers := centre - pied.position
	pied.rotation.y = atan2(-vers.x, -vers.z)


# --- Squelette de mammouth ----------------------------------------------------------

func _construire_squelette_mammouth() -> void:
	var os := _mat_pbr("", Color(0.80, 0.76, 0.66), 0.85)
	var y := hauteur(MAMMOUTH.x, MAMMOUTH.y)
	var squelette := Node3D.new()
	squelette.name = "SqueletteMammouth"
	squelette.position = Vector3(MAMMOUTH.x, y - 0.4, MAMMOUTH.y)
	squelette.rotation = Vector3(0, 0.9, 0.08)
	_contenu.add_child(squelette)
	# Colonne vertébrale.
	for k in 16:
		var v := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.16 - k * 0.004
		s.height = s.radius * 2.0
		v.mesh = s
		v.material_override = os
		v.position = Vector3(0, 1.3 - pow(k / 15.0 - 0.3, 2.0) * 0.8, -1.8 + k * 0.28)
		squelette.add_child(v)
	# Côtes : des arcs à moitié enfouis dans la neige.
	for k in 9:
		for cote in [-1.0, 1.0]:
			var cote_os := MeshInstance3D.new()
			var tore := TorusMesh.new()
			var r := 1.0 - absf(k - 3.0) * 0.07
			tore.inner_radius = r
			tore.outer_radius = r + 0.09
			tore.rings = 20
			tore.ring_segments = 6
			cote_os.mesh = tore
			cote_os.material_override = os
			cote_os.position = Vector3(cote * 0.15, 1.25 - r * 0.2, -1.2 + k * 0.32)
			cote_os.rotation = Vector3(0, 0, PI / 2 + cote * 0.25)
			cote_os.scale = Vector3(1.0, 1.0, 0.6)
			squelette.add_child(cote_os)
	# Crâne.
	var crane := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 1.1
	crane.mesh = sphere
	crane.material_override = os
	crane.position = Vector3(0, 1.1, -2.6)
	crane.scale = Vector3(1.0, 1.15, 0.9)
	squelette.add_child(crane)
	# Défenses : longues, recourbées en spirale.
	for cote in [-1.0, 1.0]:
		var precedent := Vector3(cote * 0.28, 0.85, -2.95)
		for k in 14:
			var t := (k + 1) / 14.0
			var point := Vector3(cote * (0.28 + sin(t * 2.4) * 0.9), 0.85 - sin(t * 1.6) * 0.55 + t * t * 1.2,
					-2.95 - sin(t * 2.0) * 2.0)
			var segment := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.13 * (1.0 - t * 0.75)
			c.bottom_radius = 0.13 * (1.0 - (t - 1.0 / 14.0) * 0.75)
			c.height = precedent.distance_to(point) + 0.02
			c.radial_segments = 8
			segment.mesh = c
			segment.material_override = os
			squelette.add_child(segment)
			segment.position = (precedent + point) * 0.5
			var direction := (point - precedent).normalized()
			segment.basis = Basis(Quaternion(Vector3.UP, direction))
			precedent = point
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(2.2, 2.0, 5.0)
	forme.shape = boite
	forme.position = Vector3(0, 1.0, -0.6)
	corps.add_child(forme)
	squelette.add_child(corps)


# --- Paysage lointain ---------------------------------------------------------------

func _construire_lointain() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 70
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.8
	bruit.fractal_octaves = 4
	# Glaciers et montagnes au nord, derrière le col.
	for k in 9:
		bruit.seed = graine + 200 + k
		var largeur := hasard.randf_range(110.0, 220.0)
		var montagne := MeshInstance3D.new()
		montagne.mesh = _maillage_bosse(bruit, Vector3(largeur, hasard.randf_range(70.0, 140.0), largeur * 0.6),
				1.4, 0.35, 28, Color(0, 0.8, 0.2))
		montagne.material_override = _mat_lointain()
		montagne.position = Vector3(-500.0 + k * 125.0 + hasard.randf_range(-30.0, 30.0), -10.0,
				hasard.randf_range(-480.0, -360.0))
		montagne.set_instance_shader_parameter("neige_en_plus", 0.85)
		montagne.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(montagne)
	# Les falaises se prolongent le long de la côte, à l'est et à l'ouest.
	for k in 6:
		bruit.seed = graine + 300 + k
		var cote := -1.0 if k % 2 == 0 else 1.0
		var cap := MeshInstance3D.new()
		cap.mesh = _maillage_bosse(bruit, Vector3(70.0, 45.0, 60.0), 1.2, 0.3, 24, Color(0, 0.6, 0.4))
		cap.material_override = _mat_lointain()
		cap.position = Vector3(cote * (210.0 + k * 40.0), -6.0, 40.0 + k * 50.0)
		cap.set_instance_shader_parameter("neige_en_plus", 0.6)
		cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contenu.add_child(cap)


# --- Limites de la zone ---------------------------------------------------------------

func _construire_limites() -> void:
	var limites := Node3D.new()
	limites.name = "Limites"
	_contenu.add_child(limites)
	var mur := func(taille: Vector3, centre: Vector3, angle := 0.0) -> void:
		var corps := StaticBody3D.new()
		corps.position = centre
		corps.rotation.y = angle
		var forme := CollisionShape3D.new()
		var boite := BoxShape3D.new()
		boite.size = taille
		forme.shape = boite
		corps.add_child(forme)
		limites.add_child(corps)
	# Dans l'eau : on ne va pas plus loin qu'une profondeur d'environ un mètre.
	var pas := 6.0
	var x := -150.0
	while x < 150.0:
		var z1 := ligne_rivage(x) + 7.0
		var z2 := ligne_rivage(x + pas) + 7.0
		var centre := Vector3(x + pas * 0.5, 0.0, (z1 + z2) * 0.5)
		var angle := -atan2(z2 - z1, pas)
		mur.call(Vector3(pas + 1.0, 12.0, 1.0), centre, angle)
		x += pas
	# Bords du terrain.
	var demi := taille_terrain * 0.5 - 4.0
	mur.call(Vector3(2, 120, taille_terrain), Vector3(-demi, 40, 0))
	mur.call(Vector3(2, 120, taille_terrain), Vector3(demi, 40, 0))
	mur.call(Vector3(taille_terrain, 120, 2), Vector3(0, 40, -demi))
	# Le col : au-delà, on passe dans la Steppe des Mammouths (voir _surveiller_col).
	mur.call(Vector3(60, 80, 2), Vector3(COL.x, hauteur(COL.x, COL.y) + 30.0, COL.y - 10.0))


# --- Personnages et objets de la quête ------------------------------------------------

func _construire_quete() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quete"
	_contenu.add_child(dossier)
	# L'agent Lenoir, blessé, adossé à un rocher.
	var lenoir := Pnj.new()
	lenoir.name = "Lenoir"
	lenoir.identifiant = "lenoir"
	lenoir.blesse = true
	lenoir.position = Vector3(LENOIR.x, hauteur(LENOIR.x, LENOIR.y), LENOIR.y)
	lenoir.rotation.y = 0.6
	dossier.add_child(lenoir)
	# Point de soin (le même endroit que Lenoir).
	var soin := ObjetQuete.new()
	soin.name = "SoinLenoir"
	soin.identifiant = "soin_lenoir"
	soin.invite = "[F] Soigner l'agent Lenoir"
	soin.position = lenoir.position
	dossier.add_child(soin)
	# La trousse de soin tombée près des caisses renversées.
	var trousse := ObjetQuete.new()
	trousse.name = "Trousse"
	trousse.identifiant = "trousse"
	trousse.invite = "[F] Ramasser la trousse de soin"
	trousse.forme = "trousse"
	trousse.position = Vector3(CAISSES.x + 0.3, hauteur(CAISSES.x + 0.3, CAISSES.y + 0.6), CAISSES.y + 0.6)
	dossier.add_child(trousse)
	# La faille.
	var faille := Faille.new()
	faille.name = "Faille"
	faille.identifiant = "faille_cote"
	faille.position = Vector3(FAILLE.x, hauteur(FAILLE.x, FAILLE.y), FAILLE.y)
	dossier.add_child(faille)
	# Repères de la carte.
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.PORTAIL, "Portail de la Vigie", PORTAIL)
	repere.call(MarqueurCarte.Type.DANGER, "Faille", FAILLE)
	repere.call(MarqueurCarte.Type.LIEU, "Col de la Steppe", COL + Vector2(0, 12))
	repere.call(MarqueurCarte.Type.LIEU, "Squelette de mammouth", MAMMOUTH)
	repere.call(MarqueurCarte.Type.LIEU, "Camp de la Vigie", Vector2(2, 36))
	repere.call(MarqueurCarte.Type.DANGER, "Tanière des loups", Vector2(-46, -58))
	repere.call(MarqueurCarte.Type.DANGER, "Tanière des loups", Vector2(48, -72))


# --- Neige qui tombe ---------------------------------------------------------------------



# --- Ciel -------------------------------------------------------------------------------



# --- Créatures fracturées -------------------------------------------------------------



# --- Retour vers Hikari Bay ---------------------------------------------------------------

## Le portail ne renvoie le joueur que s'il s'en est d'abord éloigné (à l'arrivée,
## on apparaît juste devant).
func _surveiller_portail() -> void:
	if _portail_arme or _zone_portail == null:
		return
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur != null and Vector2(joueur.global_position.x, joueur.global_position.z).distance_to(PORTAIL) > 8.0:
		_portail_arme = true


func _sur_portail(corps: Node3D) -> void:
	if not _portail_arme or not corps.is_in_group("joueur_local"):
		return
	_portail_arme = false
	var quete := get_tree().get_first_node_in_group("quete")
	if quete != null and quete.has_method("rentrer_au_hub"):
		quete.rentrer_au_hub()


# --- Passage vers la Steppe des Mammouths ------------------------------------------------

func _surveiller_col() -> void:
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return
	var p := Vector2(joueur.global_position.x, joueur.global_position.z)
	if p.y < COL.y - 2.0 and absf(p.x - COL.x) < 20.0:
		var quete := get_tree().get_first_node_in_group("quete")
		if quete != null and quete.has_method("changer_de_zone"):
			quete.changer_de_zone("steppe")
