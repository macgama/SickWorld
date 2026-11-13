@tool
extends "res://scripts/monde/prehistoire/ile_prehistoire.gd"
## Île de la Préhistoire, zone 5 : la Grande Grotte (donjon, niveau 10).
##
## Un réseau de galeries qui descend sous les Falaises Peintes : la salle
## d'entrée, la galerie des peintures (qui s'effacent), la salle des cristaux
## violets, puis la grande salle où dort l'Ours Sans Mémoire, fusionné avec la
## fracture majeure. Pas de ciel : seulement des torches, les cristaux, et la
## lueur de la faille.
## Le sol est un relief comme dehors ; les parois montent en pente raide et une
## voûte (maillage à part) ferme le dessus. Repères : l'entrée est au sud (+Z).

const Pnj := preload("res://scripts/monde/prehistoire/pnj_epoque.gd")
const MarqueurCarte := preload("res://scripts/carte/marqueur_carte.gd")
const Faille := preload("res://scripts/monde/prehistoire/faille.gd")

## L'entrée, depuis les Falaises Peintes.
const ENTREE := Vector2(0, 104)
## Les salles : centre, rayon, hauteur de voûte.
const SALLES := [
	[Vector2(0, 62), 13.0, 9.0],      # 0 : salle d'entrée
	[Vector2(-34, 18), 15.0, 10.0],   # 1 : galerie des peintures
	[Vector2(14, -24), 13.0, 11.0],   # 2 : salle des cristaux
	[Vector2(0, -80), 24.0, 16.0],    # 3 : antre de l'Ours Sans Mémoire
]
## Les couloirs entre les salles (début, fin) et leur demi-largeur.
const COULOIRS := [
	[Vector2(0, 108), Vector2(0, 62), 3.5],
	[Vector2(0, 62), Vector2(-34, 18), 3.0],
	[Vector2(-34, 18), Vector2(14, -24), 3.0],
	[Vector2(14, -24), Vector2(0, -80), 3.6],
]
const ANTRE := Vector2(0, -80)

var _voute: FastNoiseLite
var _torche_joueur: OmniLight3D


func _init() -> void:
	identifiant_zone = "grotte"
	taille_terrain = 240
	point_apparition = ENTREE + Vector2(0, -8)
	nombre_touffes = 0
	neige_qui_tombe = false
	ambiance_grandiose = false
	ciel = ""
	sols = {
		"galets": ["dry_river_pebbles", "brown_mud_rocks_01"],
		"neige": ["brown_mud_02"],
		"sol": ["dry_ground_rocks", "brown_mud_rocks_01"],
		"roche": ["cliff_side", "rock_wall_10", "rock_boulder_dry"],
	}
	reglages_terrain = {"sol_saturation": 0.5, "sol_motif": 3.0, "sol_teinte": Color(0.8, 0.76, 0.7),
			"roche_motif": 6.0, "roche_teinte": Color(0.85, 0.82, 0.78), "roche_saturation": 0.15}


func _chaque_image(_delta: float) -> void:
	for k in _feux.size():
		var feu := _feux[k]
		if is_instance_valid(feu):
			feu.light_energy = 2.4 + sin(_temps * 11.0 + k) * 0.35 + sin(_temps * 23.0 + k * 2.0) * 0.25
	if Engine.is_editor_hint():
		return
	_porter_la_torche()
	_surveiller_sortie()


func sortie_vers(zone: String) -> Vector2:
	return ENTREE + Vector2(0, -2) if zone != "grotte" else Vector2.INF


# --- Relief ----------------------------------------------------------------

func _preparer_bruits() -> void:
	super._preparer_bruits()
	_relief.frequency = 0.03
	_voute = FastNoiseLite.new()
	_voute.seed = graine + 31
	_voute.frequency = 0.12
	_voute.fractal_octaves = 2


## Distance (signée) au réseau de galeries : négative à l'intérieur.
func distance_galeries(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := INF
	for s in SALLES:
		var bord: float = (s[1] as float) + _relief.get_noise_2d(x * 2.0, z * 2.0) * 2.0
		d = minf(d, p.distance_to(s[0]) - bord)
	for c in COULOIRS:
		var a: Vector2 = c[0]
		var b: Vector2 = c[1]
		var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		d = minf(d, p.distance_to(a + (b - a) * t) - (c[2] as float) - _relief.get_noise_2d(x * 3.0, z * 3.0) * 0.8)
	return d


## Hauteur du sol des galeries (il descend doucement vers l'antre).
func _sol(x: float, z: float) -> float:
	return 2.0 + smoothstep(100.0, -80.0, z) * -1.0 + _relief.get_noise_2d(x, z) * 0.7 \
			+ absf(_details.get_noise_2d(x * 1.5, z * 1.5)) * 0.35


func hauteur(x: float, z: float) -> float:
	if _relief == null:
		_preparer_bruits()
	var d := distance_galeries(x, z)
	var h := _sol(x, z)
	# Les parois montent d'un coup, irrégulières.
	h += smoothstep(-0.8, 2.2, d) * (28.0 + _voute.get_noise_2d(x, z) * 4.0)
	return h


## Hauteur de la voûte au-dessus du sol.
func hauteur_voute(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var haut := 4.5
	for s in SALLES:
		var f := 1.0 - smoothstep((s[1] as float) * 0.3, (s[1] as float) + 3.0, p.distance_to(s[0]))
		haut = maxf(haut, lerpf(4.5, s[2], f))
	return haut + _voute.get_noise_2d(x * 1.3, z * 1.3) * 1.2


func _parts_sol(x: float, z: float, h: float) -> Color:
	var n := _relief.get_noise_2d(x * 4.0 + 90.0, z * 4.0)
	var galets := smoothstep(0.1, 0.5, n)
	return Color(galets, 0.0, 1.0 - galets, 1.0)


# --- Construction ------------------------------------------------------------

func reconstruire() -> void:
	_commencer()
	_feux.clear()
	_construire_terrain()
	_construire_voute()
	_construire_decor()
	_construire_peintures()
	_construire_cristaux()
	_construire_antre()
	_construire_limites()
	_construire_quete()
	_eclairer()


## La voûte : un maillage au-dessus des galeries, vu par en dessous.
func _construire_voute() -> void:
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pas := 1.0
	var demi := taille_terrain * 0.5
	var y := func(x: float, z: float) -> float:
		return _sol(x, z) + hauteur_voute(x, z)
	var z0 := -demi
	while z0 < demi:
		var x0 := -demi
		while x0 < demi:
			if distance_galeries(x0 + 0.5, z0 + 0.5) < 7.0:
				var coins := [Vector2(x0, z0), Vector2(x0 + pas, z0), Vector2(x0 + pas, z0 + pas), Vector2(x0, z0 + pas)]
				for i in [0, 2, 1, 0, 3, 2]:
					var c: Vector2 = coins[i]
					outil.set_uv(c * 0.25)
					outil.add_vertex(Vector3(c.x, y.call(c.x, c.y), c.y))
			x0 += pas
		z0 += pas
	outil.generate_normals()
	var voute := MeshInstance3D.new()
	voute.name = "Voute"
	voute.mesh = outil.commit()
	voute.material_override = _mat_terrain()
	voute.set_instance_shader_parameter("roche_forcee", 1.0)
	_contenu.add_child(voute)


## Stalagmites, stalactites, éboulis, os.
func _construire_decor() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 50
	var dossier := Node3D.new()
	dossier.name = "Decor"
	_contenu.add_child(dossier)
	_preparer_rochers()
	var roche := _mat_terrain()
	var places := 0
	var essais := 0
	while places < 140 and essais < 4000:
		essais += 1
		var p := Vector2(hasard.randf_range(-70.0, 70.0), hasard.randf_range(-110.0, 110.0))
		var d := distance_galeries(p.x, p.y)
		if d > -0.5 or d < -5.0 or p.distance_to(ANTRE) < 12.0:
			continue
		var sol := _sol(p.x, p.y)
		var haut := hasard.randf_range(0.8, 3.2)
		# Une stalagmite au sol et, souvent, sa stalactite juste au-dessus.
		var cone := MeshInstance3D.new()
		var forme := CylinderMesh.new()
		forme.top_radius = 0.03
		forme.bottom_radius = haut * hasard.randf_range(0.18, 0.28)
		forme.height = haut
		forme.radial_segments = 7
		cone.mesh = forme
		cone.material_override = roche
		cone.set_instance_shader_parameter("roche_forcee", 1.0)
		cone.position = Vector3(p.x, sol + haut * 0.5 - 0.1, p.y)
		dossier.add_child(cone)
		if hasard.randf() < 0.7:
			var pendante := cone.duplicate() as MeshInstance3D
			var longueur := hasard.randf_range(0.6, 2.4)
			pendante.scale = Vector3.ONE * longueur / haut
			pendante.rotation.x = PI
			pendante.position = Vector3(p.x, sol + hauteur_voute(p.x, p.y) - longueur * 0.5 + 0.1, p.y)
			dossier.add_child(pendante)
		places += 1
	# Blocs effondrés.
	places = 0
	essais = 0
	while places < 50 and essais < 2000:
		essais += 1
		var p := Vector2(hasard.randf_range(-70.0, 70.0), hasard.randf_range(-110.0, 110.0))
		var d := distance_galeries(p.x, p.y)
		if d > 0.0 or d < -4.0:
			continue
		_placer_rocher(dossier, p.x, p.y, hasard.randf_range(0.5, 1.8))
		places += 1


## Les peintures de la galerie : elles s'effacent (la fracture les « mange »).
func _construire_peintures() -> void:
	var dossier := Node3D.new()
	dossier.name = "Peintures"
	_contenu.add_child(dossier)
	var salle: Array = SALLES[1]
	var texture := _texture_fresque()
	for k in 5:
		var a := -PI * 0.9 + k * 0.45
		var dir := Vector2(cos(a), sin(a))
		var p: Vector2 = (salle[0] as Vector2) + dir * ((salle[1] as float) - 1.0)
		var peinture := Decal.new()
		peinture.name = "Peinture%d" % k
		peinture.size = Vector3(8.0, 6.0, 3.5)
		peinture.texture_albedo = texture
		peinture.modulate = Color(0.42, 0.17, 0.09, 0.25 + 0.15 * (k % 3))
		peinture.albedo_mix = 0.85
		peinture.position = Vector3(p.x, _sol(p.x, p.y) + 3.0, p.y)
		peinture.look_at_from_position(peinture.position, peinture.position + Vector3(dir.x, 0, dir.y), Vector3.UP)
		peinture.rotate_object_local(Vector3.RIGHT, -PI / 2)
		dossier.add_child(peinture)
	# Des lampes à graisse posées au sol éclairent les peintures.
	for k in 3:
		var a := -PI * 0.9 + (k * 2) * 0.45
		var dir := Vector2(cos(a), sin(a))
		var p: Vector2 = (salle[0] as Vector2) + dir * ((salle[1] as float) - 4.0)
		var lampe := OmniLight3D.new()
		lampe.name = "Lampe%d" % k
		lampe.light_color = Color(1.0, 0.62, 0.32)
		lampe.light_energy = 2.2
		lampe.omni_range = 14.0
		lampe.position = Vector3(p.x, _sol(p.x, p.y) + 1.2, p.y)
		dossier.add_child(lampe)


## Des cristaux violets poussent là où la fracture suinte.
func _construire_cristaux() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 60
	var dossier := Node3D.new()
	dossier.name = "Cristaux"
	_contenu.add_child(dossier)
	var violet := StandardMaterial3D.new()
	violet.albedo_color = Color(0.45, 0.2, 0.8, 0.85)
	violet.emission_enabled = true
	violet.emission = Color(0.55, 0.2, 1.0)
	violet.emission_energy_multiplier = 2.2
	violet.roughness = 0.15
	violet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for salle in [SALLES[2], SALLES[3]]:
		var centre: Vector2 = salle[0]
		var rayon: float = salle[1]
		for k in 26:
			var a := hasard.randf() * TAU
			var p := centre + Vector2(cos(a), sin(a)) * hasard.randf_range(rayon * 0.55, rayon - 0.5)
			var touffe := Node3D.new()
			touffe.position = Vector3(p.x, _sol(p.x, p.y) - 0.1, p.y)
			dossier.add_child(touffe)
			for j in hasard.randi_range(2, 5):
				var prisme := MeshInstance3D.new()
				var forme := CylinderMesh.new()
				forme.top_radius = 0.0
				var r := hasard.randf_range(0.08, 0.3)
				forme.bottom_radius = r
				forme.height = r * hasard.randf_range(5.0, 9.0)
				forme.radial_segments = 6
				forme.rings = 1
				prisme.mesh = forme
				prisme.material_override = violet
				prisme.rotation = Vector3(hasard.randf_range(-0.6, 0.6), hasard.randf() * TAU, hasard.randf_range(-0.6, 0.6))
				prisme.position = prisme.basis.y * forme.height * 0.45
				touffe.add_child(prisme)
		for k in 3:
			var a := k * TAU / 3.0
			var lumiere := OmniLight3D.new()
			lumiere.light_color = Color(0.6, 0.3, 1.0)
			lumiere.light_energy = 2.0
			lumiere.omni_range = rayon * 0.9
			var p := centre + Vector2(cos(a), sin(a)) * rayon * 0.6
			lumiere.position = Vector3(p.x, _sol(p.x, p.y) + 2.5, p.y)
			dossier.add_child(lumiere)


## L'antre : la fracture majeure, une immense déchirure violette au fond.
func _construire_antre() -> void:
	var dossier := Node3D.new()
	dossier.name = "Antre"
	_contenu.add_child(dossier)
	var faille := Faille.new()
	faille.name = "FractureMajeure"
	faille.identifiant = "fracture_majeure"
	var p := ANTRE + Vector2(0, -16)
	faille.position = Vector3(p.x, _sol(p.x, p.y), p.y)
	faille.scale = Vector3.ONE * 2.6
	dossier.add_child(faille)
	# Des os autour : les proies de l'ours.
	var os := StandardMaterial3D.new()
	os.albedo_color = Color(0.82, 0.78, 0.68)
	os.roughness = 0.7
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 70
	for k in 30:
		var a := hasard.randf() * TAU
		var q := ANTRE + Vector2(cos(a), sin(a)) * hasard.randf_range(6.0, 20.0)
		var piece := MeshInstance3D.new()
		piece.mesh = _cylindre(0.04, 0.05, hasard.randf_range(0.4, 1.1), 6)
		piece.material_override = os
		piece.position = Vector3(q.x, _sol(q.x, q.y) + 0.05, q.y)
		piece.rotation = Vector3(PI / 2, hasard.randf() * TAU, 0)
		dossier.add_child(piece)


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


func _construire_quete() -> void:
	var dossier := Node3D.new()
	dossier.name = "Quete"
	_contenu.add_child(dossier)
	# Toran et Naya gardent la salle d'entrée.
	for donnees in [["toran", "Toran", Vector2(-4, 58), 0.4], ["chasseuse_naya", "Naya", Vector2(4, 57), -0.4]]:
		var n := Pnj.new()
		n.name = donnees[1]
		n.identifiant = donnees[0]
		var p: Vector2 = donnees[2]
		n.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
		n.rotation.y = donnees[3]
		dossier.add_child(n)
	# Feux des torches plantées par le clan le long du chemin.
	for p in [Vector2(3, 92), Vector2(-5, 66), Vector2(-20, 40), Vector2(-30, 24), Vector2(-44, 12), Vector2(-8, -4), Vector2(10, -40)]:
		_feu(dossier, p, 0.6)
	var repere := func(type: int, texte: String, p: Vector2) -> void:
		MarqueurCarte.creer(dossier, type, texte, Vector3(p.x, hauteur(p.x, p.y), p.y))
	repere.call(MarqueurCarte.Type.LIEU, "Sortie (vers les Falaises Peintes)", ENTREE)
	repere.call(MarqueurCarte.Type.LIEU, "Galerie des peintures", SALLES[1][0])
	repere.call(MarqueurCarte.Type.DANGER, "Salle des cristaux", SALLES[2][0])
	repere.call(MarqueurCarte.Type.DANGER, "Antre de l'Ours Sans Mémoire", ANTRE)


## Sous terre : pas de soleil, une faible lumière bleutée, du noir au loin.
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
	env.ambient_light_color = Color(0.32, 0.34, 0.45)
	env.ambient_light_energy = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.03, 0.03, 0.05)
	env.fog_density = 0.02
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = false


## Le joueur porte une torche de résine (une lumière chaude qui le suit).
func _porter_la_torche() -> void:
	if _torche_joueur != null and is_instance_valid(_torche_joueur):
		_torche_joueur.light_energy = 2.6 + sin(_temps * 13.0) * 0.25 + sin(_temps * 29.0) * 0.15
		return
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return
	_torche_joueur = OmniLight3D.new()
	_torche_joueur.name = "TorcheDeResine"
	_torche_joueur.light_color = Color(1.0, 0.62, 0.3)
	_torche_joueur.omni_range = 14.0
	_torche_joueur.shadow_enabled = true
	_torche_joueur.position = Vector3(0.4, 2.0, 0.2)
	joueur.add_child(_torche_joueur)


func _surveiller_sortie() -> void:
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null:
		return
	var p := Vector2(joueur.global_position.x, joueur.global_position.z)
	if p.y > ENTREE.y + 2.0 and absf(p.x - ENTREE.x) < 8.0:
		var quete := get_tree().get_first_node_in_group("quete")
		if quete != null and quete.has_method("changer_de_zone"):
			quete.changer_de_zone("falaises")
