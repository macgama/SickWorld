extends RefCounted
## L'Arène (sud-est de Hikari Bay, au bord de l'eau), voir docs/HUB.md, section 3.
##
## Un stade circulaire posé sur une plateforme dans la baie, en pleine
## rénovation : il accueillera plus tard les combats entre joueurs (JcJ).
## On peut déjà entrer sur le terrain, au milieu des échafaudages.
##
## Plan (le nord est vers -Z, la mer est au sud) :
##   - Quai de l'Arène : x de 70 à 100, z de 74 à 82 (depuis le bout de la promenade) ;
##   - Plateforme : x de 100 à 150, z de 74 à 130 ;
##   - Stade : centre (125, 102), terrain de rayon 17, mur extérieur de rayon 22,
##     entrée à l'ouest.

const Marche := preload("res://scripts/monde/quartier_marche.gd")
const FrontDeMer := preload("res://scripts/monde/quartier_front_de_mer.gd")

const QUAI_ARENE := Rect2(70, 74, 30, 8)
const PLATEFORME := Rect2(100, 74, 50, 56)
const CENTRE := Vector3(125, 0, 102)
const RAYON_TERRAIN := 17.0
const RAYON_MUR := 22.0
const HAUTEUR_MUR := 11.0
## Demi-ouverture de l'entrée (radians), côté ouest.
const ENTREE := 0.2

const ROUGE := Color(1.0, 0.25, 0.2)
const ORANGE := Color(1.0, 0.6, 0.15)
const BLANC := Color(0.95, 0.97, 1.0)
const CYAN := Color(0.3, 0.9, 1.0)


static func construire(hub: HikariBay) -> void:
	_construire_quai(hub)
	_construire_stade(hub)
	_construire_tribunes(hub)
	_construire_projecteurs(hub)
	_construire_chantier(hub)
	_construire_habitants(hub)


# --- Quai et plateforme --------------------------------------------------------------

static func _construire_quai(hub: HikariBay) -> void:
	var planches := hub._mat_pbr("wood_planks", 3.0, "bois", Color(0.45, 0.38, 0.32))
	var q := QUAI_ARENE
	hub._bloc(q.position.x, q.position.y, q.end.x, q.end.y, -1.2, 0.0, planches)
	var p := PLATEFORME
	hub._bloc(p.position.x, p.position.y, p.end.x, p.end.y, -1.5, 0.0, hub._mat_pbr("concrete_pavement", 3.0, "beton", Color(0.55, 0.55, 0.55)))
	FrontDeMer._garde_corps(hub, Vector2(q.position.x, q.end.y), Vector2(q.end.x, q.end.y))
	FrontDeMer._garde_corps(hub, Vector2(p.position.x, q.end.y), Vector2(p.position.x, p.end.y))
	FrontDeMer._garde_corps(hub, Vector2(p.position.x, p.end.y), Vector2(p.end.x, p.end.y))
	FrontDeMer._garde_corps(hub, Vector2(p.end.x, p.position.y), Vector2(p.end.x, p.end.y))
	FrontDeMer._garde_corps(hub, Vector2(q.end.x, p.position.y), Vector2(p.end.x, p.position.y))
	# Panneau d'entrée sur le quai.
	var metal := hub._mat("metal")
	for z in [74.4, 81.6]:
		hub._boite(Vector3(0.3, 5.0, 0.3), Vector3(72.0, 2.5, z), metal)
	hub._boite(Vector3(0.4, 1.2, 7.6), Vector3(72.0, 5.2, 78.0), hub._mat("metal"), false)
	hub._texte("闘技場 · ARÈNE DE LA BAIE · Arena", Vector3(71.75, 5.2, 78.0), ROUGE, 44, -PI / 2, 3.0)
	for x in [78.0, 88.0, 98.0]:
		hub._cylindre(0.07, 0.1, 4.0, Vector3(x, 2.0, 81.4), metal)
		hub._lumiere(Vector3(x, 3.8, 81.4), ORANGE, 1.6, 12.0)
		hub._boite(Vector3(0.4, 0.12, 0.4), Vector3(x, 4.05, 81.4), hub._neon(ORANGE, 3.0), false)


## Pose une boîte tournée autour de l'axe vertical (avec collision si demandé).
static func _boite_tournee(hub: HikariBay, taille: Vector3, centre: Vector3, angle: float, mat: Material, collision: bool) -> void:
	var b := hub._boite(taille, centre, mat, false)
	b.rotation.y = angle
	if collision:
		hub._collision_boite(taille, Transform3D(Basis(Vector3.UP, angle), centre))


# --- Le stade : mur circulaire, terrain, écran ----------------------------------------------

static func _construire_stade(hub: HikariBay) -> void:
	var beton := hub._mat_pbr("brushed_concrete", 3.0, "beton", Color(0.7, 0.7, 0.72))
	var segments := 40
	for i in segments:
		var a := (i + 0.5) * TAU / segments
		# a = PI : côté ouest (x négatif) -> entrée.
		if absf(wrapf(a - PI, -PI, PI)) < ENTREE:
			continue
		var p := CENTRE + Vector3(cos(a), 0, sin(a)) * RAYON_MUR
		var largeur := TAU * RAYON_MUR / segments + 0.15
		_boite_tournee(hub, Vector3(1.0, HAUTEUR_MUR, largeur), p + Vector3(0, HAUTEUR_MUR * 0.5, 0), -a, beton, true)
		# Bandeau lumineux en haut du mur, une couleur sur deux.
		var couleur := ROUGE if i % 2 == 0 else BLANC
		_boite_tournee(hub, Vector3(1.05, 0.3, largeur), p + Vector3(0, HAUTEUR_MUR - 0.6, 0), -a, hub._neon(couleur, 2.5), false)
	# Portique de l'entrée.
	var entree := CENTRE + Vector3(-RAYON_MUR, 0, 0)
	hub._boite(Vector3(1.4, 1.2, 10.0), entree + Vector3(0, 6.8, 0), beton, false)
	hub._texte("ENTRÉE · 入口", entree + Vector3(-0.75, 6.8, 0), BLANC, 50, -PI / 2, 2.5)
	# Terrain en sable, avec les marques du centre.
	var sable := StandardMaterial3D.new()
	sable.albedo_color = Color(0.62, 0.52, 0.38)
	sable.roughness = 1.0
	var terrain := hub._cylindre(RAYON_TERRAIN, RAYON_TERRAIN, 0.05, CENTRE + Vector3(0, 0.025, 0), sable, false)
	terrain.name = "TerrainArene"
	var anneau := MeshInstance3D.new()
	var tore := TorusMesh.new()
	tore.inner_radius = 4.0
	tore.outer_radius = 4.15
	anneau.mesh = tore
	anneau.material_override = hub._neon(CYAN, 1.5)
	anneau.position = CENTRE + Vector3(0, 0.06, 0)
	anneau.scale = Vector3(1, 0.05, 1)
	hub._contenu.add_child(anneau)
	# Grand écran au-dessus des tribunes est.
	var ecran := hub._boite(Vector3(0.3, 6.0, 12.0), CENTRE + Vector3(RAYON_MUR + 0.8, HAUTEUR_MUR + 4.0, 0), hub._neon(Color(0.05, 0.05, 0.1), 0.0), false)
	ecran.name = "EcranArene"
	hub._texte("ARÈNE · アリーナ\nCombats JcJ · ouverture prochaine\n— en rénovation —",
			CENTRE + Vector3(RAYON_MUR + 0.6, HAUTEUR_MUR + 4.0, 0), ROUGE, 70, -PI / 2, 3.5)


# --- Tribunes (gradins circulaires) -----------------------------------------------------------

static func _construire_tribunes(hub: HikariBay) -> void:
	var siege := hub._mat_pbr("metal_plate", 2.0, "metal", Color(0.6, 0.12, 0.12))
	var marche := hub._mat_pbr("brushed_concrete", 3.0, "beton", Color(0.55, 0.55, 0.58))
	var segments := 36
	for rang in 4:
		var r := RAYON_TERRAIN + 0.6 + rang * 1.0
		var h := 0.7 + rang * 0.7
		for i in segments:
			var a := (i + 0.5) * TAU / segments
			if absf(wrapf(a - PI, -PI, PI)) < ENTREE + 0.12:
				continue
			var p := CENTRE + Vector3(cos(a), 0, sin(a)) * r
			var largeur := TAU * r / segments + 0.1
			_boite_tournee(hub, Vector3(1.0, h, largeur), p + Vector3(0, h * 0.5, 0), -a, marche, rang == 0)
			_boite_tournee(hub, Vector3(0.45, 0.12, largeur - 0.3), p + Vector3(0, h + 0.06, 0), -a, siege, false)


# --- Projecteurs (quatre tours) -------------------------------------------------------------------

static func _construire_projecteurs(hub: HikariBay) -> void:
	var metal := hub._mat("metal")
	for k in 4:
		var a := PI * 0.25 + k * PI * 0.5
		var p := CENTRE + Vector3(cos(a), 0, sin(a)) * (RAYON_MUR + 2.5)
		hub._cylindre(0.35, 0.5, 24.0, p + Vector3(0, 12.0, 0), metal)
		var panneau := hub._boite(Vector3(3.0, 2.0, 0.4), p + Vector3(0, 24.5, 0), metal, false)
		panneau.look_at_from_position(p + Vector3(0, 24.5, 0), CENTRE, Vector3.UP)
		var face := hub._boite(Vector3(2.8, 1.8, 0.05), Vector3.ZERO, hub._neon(BLANC, 3.0), false)
		face.look_at_from_position(p.lerp(CENTRE, 0.012) + Vector3(0, 24.5, 0), CENTRE, Vector3.UP)
		var spot := SpotLight3D.new()
		spot.light_color = BLANC
		spot.light_energy = 4.0
		spot.spot_range = 50.0
		spot.spot_angle = 30.0
		hub._contenu.add_child(spot)
		spot.look_at_from_position(p + Vector3(0, 23.5, 0), CENTRE, Vector3.UP)


# --- Chantier de rénovation -----------------------------------------------------------------------

static func _construire_chantier(hub: HikariBay) -> void:
	var metal := hub._mat_pbr("metal_plate", 1.0, "metal", Color(0.75, 0.55, 0.15))
	# Échafaudages contre le mur nord-est (à l'intérieur).
	for i in 4:
		var a := -0.9 + i * 0.18
		var p := CENTRE + Vector3(cos(a), 0, sin(a)) * (RAYON_TERRAIN - 1.0)
		for niveau in 3:
			_boite_tournee(hub, Vector3(1.4, 0.08, 2.2), p + Vector3(0, 2.0 + niveau * 2.0, 0), -a, metal, false)
		for dx in [-0.6, 0.6]:
			for dz in [-1.0, 1.0]:
				var q := p + Vector3(cos(a) * dx - sin(a) * dz, 0, sin(a) * dx + cos(a) * dz)
				hub._cylindre(0.04, 0.04, 6.4, q + Vector3(0, 3.2, 0), metal, false)
	# Caisses, barrières, bâches.
	hub._modele("concrete_road_barrier", CENTRE + Vector3(-12.0, 0, 8.0), 0.4, 1.0)
	hub._modele("concrete_road_barrier", CENTRE + Vector3(-11.0, 0, 10.5), 0.2, 1.0)
	hub._modele("plastic_crate_01", CENTRE + Vector3(10.0, 0, -9.0), 0.5, 1.2)
	hub._modele("cardboard_box_01", CENTRE + Vector3(10.8, 0, -8.2), 1.2, 1.2)
	var bache := StandardMaterial3D.new()
	bache.albedo_color = Color(0.15, 0.3, 0.6)
	bache.roughness = 0.8
	hub._boite(Vector3(3.0, 1.2, 2.0), CENTRE + Vector3(8.0, 0.6, 11.0), bache)
	# Panneau du chantier près de l'entrée.
	hub._texte("工事中 · CHANTIER · Rénovation de l'Arène\nOuverture : bientôt", CENTRE + Vector3(-RAYON_MUR - 0.8, 3.0, 6.5),
			ORANGE, 30, -PI / 2, 2.5)
	hub._lumiere(CENTRE + Vector3(0, 6.0, 0), BLANC, 2.0, 26.0)


# --- Habitants -------------------------------------------------------------------------------------

static func _construire_habitants(hub: HikariBay) -> void:
	Marche._pnj(hub, "chef_chantier", Vector3(104.0, 0, 80.0), PI / 2)
	Marche._pnj(hub, "ouvrier_arene", CENTRE + Vector3(9.0, 0, -6.0), PI / 2)
	Marche._pnj(hub, "championne", CENTRE + Vector3(0.0, 0, 3.0), PI)
	Marche._pnj(hub, "commentateur", Vector3(88.0, 0, 78.0), -PI / 2)
