@tool
extends "res://scripts/monde/grece/ile_grece.gd"
## Base commune des zones de l'île de Rome (la voie Appienne, la campagne et ses
## aqueducs, Rome, Pompéi…).
##
## L'été de l'an 80, sous l'empereur Titus. On réutilise tout ce qui sert déjà en Grèce
## (colonnes, tuiles, enduits, amphores, cyprès, portiques) et on y ajoute ce qui est
## propre à Rome : la brique et le tuf, le travertin, les pavés polygonaux de basalte des
## grandes voies, les pins parasols, les tombeaux, les bornes milliaires et les arches
## des aqueducs.
##
## Les textures Poly Haven de Rome iront dans assets/rome/ ; en attendant, la brique et
## les pavés sont dessinés par le code, et le reste vient de la Grèce et de l'Égypte.

const DOSSIER_ROME := "res://assets/rome/"

## Le rouge des enduits (le fameux « rouge pompéien ») et l'ocre jaune des façades.
const ROUGE_POMPEIEN := Color(0.55, 0.12, 0.08)
const OCRE_ROMAIN := Color(0.8, 0.6, 0.3)
const BRIQUE := Color(0.62, 0.32, 0.2)

static var _texture_briques: Texture2D
static var _texture_paves: Texture2D


# --- Ressources : d'abord Rome, puis la Grèce, l'Égypte et la Préhistoire --------------------

func _texture(id: String, carte: String) -> Texture2D:
	var chemin: String = DOSSIER_ROME + "textures/%s/%s_%s.jpg" % [id, id, carte]
	if ResourceLoader.exists(chemin):
		return load(chemin)
	return super._texture(id, carte)


# --- Matériaux ---------------------------------------------------------------------------------

## La brique romaine (opus testaceum) : de longues briques plates, joints de mortier épais.
func _mat_brique() -> StandardMaterial3D:
	var cle := "brique_rome"
	if not _materiaux.has(cle):
		var m := StandardMaterial3D.new()
		m.albedo_texture = _briques()
		m.roughness = 0.92
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(0.45, 0.45, 0.45)
		_materiaux[cle] = m
	return _materiaux[cle]


## Le tuf volcanique gris-jaune des monts Albains (les blocs des vieux murs et des tombeaux).
func _mat_tuf() -> StandardMaterial3D:
	var cle := "tuf_rome"
	if not _materiaux.has(cle):
		var m := _mat_choix(["large_sandstone_blocks", "sandstone_blocks_08", "old_stone_wall"], Color(0.62, 0.58, 0.46), 0.95, 2.2).duplicate()
		_materiaux[cle] = m
	return _materiaux[cle]


## Le travertin de Tibur : blanc crème, piqué de petits trous (le Colisée, les grands tombeaux).
func _mat_travertin() -> StandardMaterial3D:
	var cle := "travertin_rome"
	if not _materiaux.has(cle):
		var m := _mat_choix(["white_sandstone_blocks_02", "marble_tiles", "white_sandstone_bricks"], Color(0.86, 0.82, 0.72), 0.8, 2.0).duplicate()
		_materiaux[cle] = m
	return _materiaux[cle]


## Les pavés polygonaux de basalte (le « silex » des Romains), lisses et gris-noir.
func _mat_paves() -> StandardMaterial3D:
	var cle := "paves_rome"
	if not _materiaux.has(cle):
		var m := StandardMaterial3D.new()
		m.albedo_texture = _paves()
		m.roughness = 0.62
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(0.32, 0.32, 0.32)
		_materiaux[cle] = m
	return _materiaux[cle]


## Un enduit peint (rouge pompéien, ocre, blanc).
func _mat_enduit_peint(couleur: Color) -> StandardMaterial3D:
	var cle := "enduit_%s" % couleur.to_html()
	if not _materiaux.has(cle):
		var m := _mat_choix(["white_plaster_02", "plastered_stone_wall", "white_plaster_rough_01"], couleur, 0.9, 3.0).duplicate()
		_materiaux[cle] = m
	return _materiaux[cle]


static func _briques() -> Texture2D:
	if _texture_briques != null:
		return _texture_briques
	var image := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 80
	var teintes := []
	for k in 64:
		teintes.append(hasard.randf_range(0.82, 1.12))
	for y in 128:
		var rang := y / 8
		var dans_rang := y % 8
		for x in 128:
			var decale := x + (16 if rang % 2 == 1 else 0)
			var dans_brique := decale % 32
			var joint := dans_rang >= 6 or dans_brique >= 30
			var c: Color
			if joint:
				c = Color(0.72, 0.68, 0.6) * (0.9 + 0.1 * sin(float(x * 3 + y * 5)))
			else:
				var t: float = teintes[(rang * 5 + decale / 32) % 64]
				c = BRIQUE * t * (0.94 + 0.06 * sin(float(x * 11 + y * 7)))
			image.set_pixel(x, y, c)
	image.generate_mipmaps()
	_texture_briques = ImageTexture.create_from_image(image)
	return _texture_briques


## Des pavés polygonaux : un diagramme de Voronoï (chaque pierre est la zone la plus
## proche d'un germe), avec des joints sombres entre les pierres.
static func _paves() -> Texture2D:
	if _texture_paves != null:
		return _texture_paves
	var taille := 128
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 312
	var germes: Array[Vector2] = []
	var teintes: Array[float] = []
	var n := 7
	for gy in n:
		for gx in n:
			germes.append(Vector2((gx + hasard.randf_range(0.15, 0.85)) * taille / n, (gy + hasard.randf_range(0.15, 0.85)) * taille / n))
			teintes.append(hasard.randf_range(0.8, 1.15))
	var image := Image.create(taille, taille, false, Image.FORMAT_RGB8)
	for y in taille:
		for x in taille:
			var p := Vector2(x, y)
			var d1 := 1e9
			var d2 := 1e9
			var meilleur := 0
			for i in germes.size():
				for dx: int in [-1, 0, 1]:
					for dy: int in [-1, 0, 1]:
						var g := germes[i] + Vector2(dx * taille, dy * taille)
						var d := p.distance_squared_to(g)
						if d < d1:
							d2 = d1
							d1 = d
							meilleur = i
						elif d < d2:
							d2 = d
			var bord := sqrt(d2) - sqrt(d1)
			var c := Color(0.26, 0.26, 0.27) * teintes[meilleur]
			if bord < 1.6:
				c = Color(0.36, 0.33, 0.28) * 0.7
			elif bord < 3.0:
				c = c * 0.82
			image.set_pixel(x, y, c)
	image.generate_mipmaps()
	_texture_paves = ImageTexture.create_from_image(image)
	return _texture_paves


# --- La route pavée ------------------------------------------------------------------------------

## Une grande voie : une bande de pavés de basalte qui suit le terrain, bordée de deux
## trottoirs de terre battue et de bordures de pierre (les « crepidines »).
func _voie(parent: Node3D, points: Array, largeur := 4.6) -> Node3D:
	var voie := Node3D.new()
	voie.name = "Voie"
	parent.add_child(voie)
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pas := 1.5
	var echantillons: Array[Vector2] = []
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var n := maxi(1, int(a.distance_to(b) / pas))
		for k in n:
			echantillons.append(a.lerp(b, float(k) / n))
	echantillons.append(points[points.size() - 1])
	var gauche: Array[Vector3] = []
	var droite: Array[Vector3] = []
	for i in echantillons.size():
		var p := echantillons[i]
		var avant := echantillons[maxi(i - 1, 0)]
		var apres := echantillons[mini(i + 1, echantillons.size() - 1)]
		var dir := (apres - avant).normalized()
		var cote := dir.orthogonal() * largeur * 0.5
		var pg := p + cote
		var pd := p - cote
		gauche.append(Vector3(pg.x, hauteur(pg.x, pg.y) + 0.06, pg.y))
		droite.append(Vector3(pd.x, hauteur(pd.x, pd.y) + 0.06, pd.y))
	for i in echantillons.size() - 1:
		outil.set_normal(Vector3.UP)
		outil.add_vertex(gauche[i])
		outil.add_vertex(droite[i])
		outil.add_vertex(gauche[i + 1])
		outil.add_vertex(droite[i])
		outil.add_vertex(droite[i + 1])
		outil.add_vertex(gauche[i + 1])
	outil.generate_normals()
	var chaussee := MeshInstance3D.new()
	chaussee.name = "Chaussee"
	chaussee.mesh = outil.commit()
	chaussee.material_override = _mat_paves()
	chaussee.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	voie.add_child(chaussee)
	# Les bordures de pierre, de chaque côté (des blocs de 1,5 m posés bout à bout).
	var bordures := Node3D.new()
	bordures.name = "Bordures"
	voie.add_child(bordures)
	var pierre := _mat_tuf()
	for i in echantillons.size() - 1:
		for cote: Array in [[gauche, 1.0], [droite, -1.0]]:
			var liste: Array = cote[0]
			var a: Vector3 = liste[i]
			var b: Vector3 = liste[i + 1]
			var milieu := (a + b) * 0.5
			var d := b - a
			var bloc := _boite(Vector3(0.38, 0.32, d.length() + 0.04), milieu + Vector3(0, 0.05, 0), pierre, bordures, false)
			bloc.rotation.y = atan2(d.x, d.z)
	_fusionner(bordures)
	return voie


# --- Arbres ---------------------------------------------------------------------------------------

## Un pin parasol (pin pignon) : un long tronc nu, un peu penché, et une couronne large et
## plate tout en haut. L'arbre de la campagne romaine.
func _pin_parasol(parent: Node3D, p: Vector2, hasard: RandomNumberGenerator, taille := 1.0) -> Node3D:
	var arbre := Node3D.new()
	arbre.name = "PinParasol"
	arbre.position = Vector3(p.x, hauteur(p.x, p.y) - 0.1, p.y)
	arbre.rotation.y = hasard.randf() * TAU
	arbre.scale = Vector3.ONE * taille
	parent.add_child(arbre)
	var haut := hasard.randf_range(9.0, 13.0)
	var penche := hasard.randf_range(0.04, 0.16)
	var ecorce := _mat_choix(["tree_bark_03", "bark_willow_02", "rough_wood"], Color(0.42, 0.32, 0.25), 0.95, 0.8)
	var tronc := MeshInstance3D.new()
	tronc.mesh = _cylindre(0.2, 0.38, haut, 8)
	tronc.material_override = ecorce
	tronc.position = Vector3(sin(penche) * haut * 0.5, haut * 0.5, 0)
	tronc.rotation.z = -penche
	arbre.add_child(tronc)
	var sommet := Vector3(sin(penche) * haut, haut, 0)
	# Deux ou trois branches maîtresses qui s'écartent, puis la couronne plate.
	for k in 3:
		var a := TAU * k / 3.0 + hasard.randf_range(-0.3, 0.3)
		var branche := MeshInstance3D.new()
		branche.mesh = _cylindre(0.08, 0.16, 2.6, 6)
		branche.material_override = ecorce
		branche.position = sommet + Vector3(cos(a) * 0.7, -0.3, sin(a) * 0.7)
		branche.rotation = Vector3(sin(a) * 0.8, 0.0, -cos(a) * 0.8)
		arbre.add_child(branche)
	var feuillage := _mat_feuillage(Color(0.2, 0.3, 0.16))
	var largeur := hasard.randf_range(4.2, 6.0)
	for k in 6:
		var touffe := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = hasard.randf_range(1.6, 2.4)
		s.height = s.radius * 0.7
		s.radial_segments = 12
		s.rings = 5
		touffe.mesh = s
		touffe.material_override = feuillage
		var a := TAU * k / 6.0 + hasard.randf_range(-0.3, 0.3)
		var r := largeur * 0.45 if k > 0 else 0.0
		touffe.position = sommet + Vector3(cos(a) * r, 1.0 + hasard.randf_range(-0.2, 0.3), sin(a) * r)
		arbre.add_child(touffe)
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = 0.4
	c.height = 3.0
	forme.shape = c
	forme.position.y = 1.5
	corps.add_child(forme)
	arbre.add_child(corps)
	return arbre


# --- Monuments --------------------------------------------------------------------------------

## Un grand tombeau rond, comme celui de Caecilia Metella : un socle carré de blocs, un
## énorme tambour revêtu de travertin, une frise sculptée (bucranes et guirlandes) en haut.
func _tombeau_tambour(parent: Node3D, centre: Vector2, rayon := 10.0, haut := 11.0) -> Node3D:
	var tombeau := Node3D.new()
	tombeau.name = "TombeauRond"
	var y := hauteur(centre.x, centre.y)
	for dx: float in [-rayon, rayon]:
		for dz: float in [-rayon, rayon]:
			y = minf(y, hauteur(centre.x + dx, centre.y + dz))
	tombeau.position = Vector3(centre.x, y, centre.y)
	parent.add_child(tombeau)
	var socle := rayon * 2.3
	_boite(Vector3(socle, 5.0, socle), Vector3(0, 2.0, 0), _mat_tuf(), tombeau)
	var tambour := MeshInstance3D.new()
	tambour.mesh = _cylindre(rayon, rayon, haut, 40)
	tambour.material_override = _mat_travertin()
	tambour.position.y = 4.5 + haut * 0.5
	tombeau.add_child(tambour)
	var frise := MeshInstance3D.new()
	frise.mesh = _cylindre(rayon + 0.12, rayon + 0.12, 1.2, 40)
	frise.material_override = _mat_marbre()
	frise.position.y = 4.5 + haut - 1.0
	tombeau.add_child(frise)
	# Les bucranes (crânes de bœuf sculptés) le long de la frise.
	for k in 24:
		var a := TAU * k / 24.0
		var b := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.28
		s.height = 0.5
		b.mesh = s
		b.material_override = _mat_marbre()
		b.position = Vector3(cos(a) * (rayon + 0.25), 4.5 + haut - 1.0, sin(a) * (rayon + 0.25))
		tombeau.add_child(b)
	var corniche := MeshInstance3D.new()
	corniche.mesh = _cylindre(rayon + 0.4, rayon + 0.3, 0.4, 40)
	corniche.material_override = _mat_travertin()
	corniche.position.y = 4.5 + haut + 0.2
	tombeau.add_child(corniche)
	# Un tumulus de terre et d'herbe sur le dessus (comme à l'origine).
	var tertre := MeshInstance3D.new()
	var t := SphereMesh.new()
	t.radius = rayon * 0.95
	t.height = rayon * 0.8
	tertre.mesh = t
	tertre.material_override = _mat_feuillage(Color(0.3, 0.32, 0.16))
	tertre.position.y = 4.5 + haut + 0.3
	tombeau.add_child(tertre)
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = rayon
	c.height = haut
	forme.shape = c
	forme.position.y = 4.5 + haut * 0.5
	corps.add_child(forme)
	tombeau.add_child(corps)
	return tombeau


## Un petit tombeau en forme de temple (édicule) : un podium, une petite cella de brique
## enduite, un fronton, deux colonnes devant, une plaque gravée.
func _tombeau_edicule(parent: Node3D, centre: Vector2, angle := 0.0, taille := 1.0, ruine := false) -> Node3D:
	var tombeau := Node3D.new()
	tombeau.name = "TombeauEdicule"
	var y := hauteur(centre.x, centre.y)
	for dx: float in [-3.0, 3.0]:
		for dz: float in [-4.0, 4.0]:
			y = minf(y, hauteur(centre.x + dx * taille, centre.y + dz * taille))
	tombeau.position = Vector3(centre.x, y, centre.y)
	tombeau.rotation.y = angle
	tombeau.scale = Vector3.ONE * taille
	parent.add_child(tombeau)
	_boite(Vector3(5.0, 1.8, 7.0), Vector3(0, 0.6, 0), _mat_tuf(), tombeau)
	_boite(Vector3(4.0, 3.6, 4.6), Vector3(0, 1.5 + 1.8, -0.8), _mat_brique() if ruine else _mat_enduit_peint(Color(0.9, 0.86, 0.76)), tombeau)
	for x: float in [-1.5, 1.5]:
		_colonne(tombeau, Vector3(x, 1.5, 2.2), 3.6 if not ruine or x < 0.0 else 2.2, 0.24, _mat_travertin())
	if not ruine:
		_boite(Vector3(4.4, 0.4, 6.6), Vector3(0, 5.3, 0), _mat_travertin(), tombeau, false)
		var fronton := Node3D.new()
		fronton.position = Vector3(0, 5.5, 0)
		fronton.rotation.y = PI / 2
		tombeau.add_child(fronton)
		_toit(fronton, Vector3.ZERO, 4.6, 6.8, 0.28)
	# La plaque gravée (le nom du défunt et « D·M », aux dieux mânes).
	_boite(Vector3(1.6, 0.8, 0.06), Vector3(0, 3.6, 1.52), _mat_marbre(), tombeau, false)
	return tombeau


## Un tombeau-autel : un gros bloc de tuf, couronné de deux volutes.
func _tombeau_autel(parent: Node3D, centre: Vector2, angle := 0.0) -> void:
	var y := hauteur(centre.x, centre.y)
	var autel := Node3D.new()
	autel.name = "TombeauAutel"
	autel.position = Vector3(centre.x, y - 0.2, centre.y)
	autel.rotation.y = angle
	parent.add_child(autel)
	_boite(Vector3(2.6, 0.5, 2.0), Vector3(0, 0.25, 0), _mat_tuf(), autel)
	_boite(Vector3(2.0, 2.0, 1.5), Vector3(0, 1.5, 0), _mat_travertin(), autel)
	_boite(Vector3(2.4, 0.35, 1.8), Vector3(0, 2.65, 0), _mat_travertin(), autel, false)
	for x: float in [-0.9, 0.9]:
		var volute := MeshInstance3D.new()
		volute.mesh = _cylindre(0.28, 0.28, 1.8, 10)
		volute.material_override = _mat_travertin()
		volute.rotation.x = PI / 2
		volute.position = Vector3(x, 3.0, 0)
		autel.add_child(volute)


## Une borne milliaire : une colonne trapue sur un socle carré, avec son chiffre gravé.
func _milliaire(parent: Node3D, p: Vector2, angle := 0.0) -> Node3D:
	var borne := Node3D.new()
	borne.name = "Milliaire"
	borne.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
	borne.rotation.y = angle
	parent.add_child(borne)
	_boite(Vector3(0.8, 0.5, 0.8), Vector3(0, 0.15, 0), _mat_tuf(), borne)
	var fut := MeshInstance3D.new()
	fut.mesh = _cylindre(0.3, 0.34, 1.9, 14)
	fut.material_override = _mat_travertin()
	fut.position.y = 1.35
	borne.add_child(fut)
	return borne


## Une charrette à deux roues pleines, tirée par une mule (la mule n'est pas faite ici).
func _charrette(parent: Node3D, p: Vector2, angle := 0.0, chargee := true) -> Node3D:
	var c := Node3D.new()
	c.name = "Charrette"
	c.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
	c.rotation.y = angle
	parent.add_child(c)
	var bois := _mat_bois()
	_boite(Vector3(1.6, 0.12, 2.6), Vector3(0, 0.95, 0), bois, c)
	for x: float in [-0.8, 0.8]:
		_boite(Vector3(0.08, 0.45, 2.6), Vector3(x, 1.2, 0), bois, c, false)
		var roue := MeshInstance3D.new()
		roue.mesh = _cylindre(0.62, 0.62, 0.14, 14)
		roue.material_override = bois
		roue.rotation.z = PI / 2
		roue.position = Vector3(x * 1.12, 0.62, 0.2)
		c.add_child(roue)
	# Le timon, vers l'avant.
	_boite(Vector3(0.1, 0.1, 2.2), Vector3(0, 0.85, -2.3), bois, c, false)
	if chargee:
		var hasard := RandomNumberGenerator.new()
		hasard.seed = hash(p)
		for k in 5:
			var ballot := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(hasard.randf_range(0.5, 0.8), hasard.randf_range(0.3, 0.5), hasard.randf_range(0.5, 0.8))
			ballot.mesh = b
			ballot.material_override = _mat_lin([Color(0.75, 0.68, 0.55), Color(0.55, 0.42, 0.3), Color(0.62, 0.3, 0.22)][k % 3])
			ballot.position = Vector3(hasard.randf_range(-0.4, 0.4), 1.25 + (0.35 if k > 2 else 0.0), hasard.randf_range(-0.9, 0.9))
			ballot.rotation.y = hasard.randf() * 0.6
			c.add_child(ballot)
		_amphore(c, Vector3(0.45, 1.0, 1.0), 0.7, 0.3)
	return c


## Un bâtiment romain simple : murs de brique enduits à mi-hauteur, toit de tuiles.
func _batiment_romain(parent: Node3D, centre: Vector2, taille: Vector3, angle := 0.0, enduit := Color(0.86, 0.72, 0.52)) -> Node3D:
	var b := Node3D.new()
	b.name = "Batiment"
	var y := hauteur(centre.x, centre.y)
	b.position = Vector3(centre.x, y, centre.y)
	b.rotation.y = angle
	parent.add_child(b)
	_boite(Vector3(taille.x, taille.y * 0.45, taille.z), Vector3(0, taille.y * 0.225 - 0.3, 0), _mat_enduit_peint(enduit), b)
	_boite(Vector3(taille.x - 0.05, taille.y * 0.6, taille.z - 0.05), Vector3(0, taille.y * 0.7 - 0.3, 0), _mat_brique(), b)
	_toit(b, Vector3(0, taille.y - 0.3, 0), taille.x + 0.6, taille.z + 0.6, 0.32)
	return b


## Les arches d'un aqueduc, vues de loin : des piliers de tuf et de brique et le canal en haut.
func _arches_aqueduc(parent: Node3D, depart: Vector3, arrivee: Vector3, haut := 22.0, travee := 7.0) -> Node3D:
	var aqueduc := Node3D.new()
	aqueduc.name = "Aqueduc"
	parent.add_child(aqueduc)
	var d := arrivee - depart
	d.y = 0.0
	var longueur := d.length()
	var angle := atan2(d.x, d.z)
	var n := int(longueur / travee)
	var pierre := _mat_tuf()
	for k in n + 1:
		var p := depart.lerp(arrivee, float(k) / n)
		var pilier := _boite(Vector3(2.2, haut, 2.0), Vector3(p.x, p.y + haut * 0.5 - 2.0, p.z), pierre, aqueduc, false)
		pilier.rotation.y = angle
	# Le haut : le cintre des arches (une bande pleine) et le canal (le « specus »).
	var milieu := (depart + arrivee) * 0.5
	var haut_arches := _boite(Vector3(2.0, 3.2, longueur), Vector3(milieu.x, milieu.y + haut - 1.6 - 2.0, milieu.z), pierre, aqueduc, false)
	haut_arches.rotation.y = angle
	var canal := _boite(Vector3(2.4, 1.6, longueur), Vector3(milieu.x, milieu.y + haut + 0.8 - 2.0, milieu.z), _mat_brique(), aqueduc, false)
	canal.rotation.y = angle
	for mi in aqueduc.get_children():
		if mi is MeshInstance3D:
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return aqueduc


## Le cintre d'une arche : un panneau de pierre de largeur « portee » et d'épaisseur
## « epaisseur », percé en bas d'un demi-cercle (l'arche elle-même). L'origine est au
## milieu de la base (la naissance de l'arche) ; le panneau monte jusqu'à « haut ».
var _arches_cache := {}


func _maillage_arche(portee: float, epaisseur: float, haut: float, segments := 14) -> ArrayMesh:
	var cle := "%.2f_%.2f_%.2f" % [portee, epaisseur, haut]
	if _arches_cache.has(cle):
		return _arches_cache[cle]
	var r := portee * 0.5
	var outil := SurfaceTool.new()
	outil.begin(Mesh.PRIMITIVE_TRIANGLES)
	var e := epaisseur * 0.5
	var quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2, uv_d: Vector2) -> void:
		outil.set_uv(uv_a)
		outil.add_vertex(a)
		outil.set_uv(uv_b)
		outil.add_vertex(b)
		outil.set_uv(uv_c)
		outil.add_vertex(c)
		outil.set_uv(uv_a)
		outil.add_vertex(a)
		outil.set_uv(uv_c)
		outil.add_vertex(c)
		outil.set_uv(uv_d)
		outil.add_vertex(d)
	for i in segments:
		var a0 := PI * float(i) / segments
		var a1 := PI * float(i + 1) / segments
		var p0 := Vector2(r * cos(a0), r * sin(a0))
		var p1 := Vector2(r * cos(a1), r * sin(a1))
		var h0 := Vector2(p0.x, haut)
		var h1 := Vector2(p1.x, haut)
		for face: float in [-1.0, 1.0]:
			var z := e * face
			if face > 0.0:
				quad.call(Vector3(p0.x, p0.y, z), Vector3(h0.x, h0.y, z), Vector3(h1.x, h1.y, z), Vector3(p1.x, p1.y, z),
						p0 / 2.0, h0 / 2.0, h1 / 2.0, p1 / 2.0)
			else:
				quad.call(Vector3(p0.x, p0.y, z), Vector3(p1.x, p1.y, z), Vector3(h1.x, h1.y, z), Vector3(h0.x, h0.y, z),
						p0 / 2.0, p1 / 2.0, h1 / 2.0, h0 / 2.0)
		# L'intrados : le dessous courbe de l'arche.
		var l0 := float(i) / segments * PI * r / 2.0
		var l1 := float(i + 1) / segments * PI * r / 2.0
		quad.call(Vector3(p0.x, p0.y, -e), Vector3(p0.x, p0.y, e), Vector3(p1.x, p1.y, e), Vector3(p1.x, p1.y, -e),
				Vector2(l0, 0), Vector2(l0, epaisseur / 2.0), Vector2(l1, epaisseur / 2.0), Vector2(l1, 0))
	outil.generate_normals()
	outil.generate_tangents()
	var m := outil.commit()
	_arches_cache[cle] = m
	return m


## Une pierre qui se voit des deux côtés (pour les cintres des arches).
func _mat_deux_faces(m: StandardMaterial3D) -> StandardMaterial3D:
	var cle := "deux_faces_%d" % m.get_instance_id()
	if not _materiaux.has(cle):
		var d := m.duplicate() as StandardMaterial3D
		d.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materiaux[cle] = d
	return _materiaux[cle]


## Un aqueduc sur lequel on peut marcher : des piliers de tuf, des arches, et en haut le
## canal (le « specus ») couvert d'un dallage, avec la rigole où coule l'eau. « y_canal »
## est la hauteur du dessus du canal (on marche dessus). Les piliers ne sont pas posés
## dans les rectangles « sans_piliers » (une porte, par exemple). Renvoie le nœud de l'eau
## (caché : on le montre quand l'eau revient).
func _aqueduc_praticable(parent: Node3D, points: Array, y_canal: float, sans_piliers: Array = [], travee := 7.0) -> Node3D:
	var aqueduc := Node3D.new()
	aqueduc.name = "Aqueduc"
	parent.add_child(aqueduc)
	var pierre := _mat_tuf()
	var cintre := _mat_deux_faces(pierre)
	var brique := _mat_brique()
	var largeur_pilier := 2.4
	var epaisseur := 3.0
	var largeur_canal := 3.4
	var haut_canal := 2.0
	var eau := Node3D.new()
	eau.name = "EauAqueduc"
	eau.set_meta("identifiant", "eau_aqueduc")
	eau.add_to_group("decor_quete")
	eau.visible = false
	# L'eau n'est pas dans le nœud de l'aqueduc : celui-ci est fusionné en un seul maillage.
	parent.add_child(eau)
	var mat_eau := StandardMaterial3D.new()
	mat_eau.albedo_color = Color(0.16, 0.36, 0.4, 0.94)
	mat_eau.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_eau.roughness = 0.04
	mat_eau.metallic = 0.25
	var mat_limon := _mat_choix(["mud_cracked_dry_03", "dry_ground_01"], Color(0.5, 0.44, 0.34), 0.95, 1.5)
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var d := b - a
		var longueur := d.length()
		var angle := atan2(d.x, d.y)
		var milieu := (a + b) * 0.5
		# Le canal : deux banquettes de pierre et la rigole entre elles. On marche sur un
		# dallage plat (la collision couvre toute la largeur).
		var y_bas := y_canal - haut_canal
		var allonge := longueur + largeur_pilier
		var corps := _boite(Vector3(largeur_canal, haut_canal - 0.5, allonge), Vector3(milieu.x, y_bas + (haut_canal - 0.5) * 0.5, milieu.y), brique, aqueduc, false)
		corps.rotation.y = angle
		for cote: float in [-1.0, 1.0]:
			var decale := Vector2(cos(angle), -sin(angle)) * cote * (largeur_canal * 0.5 - 0.6)
			var banquette := _boite(Vector3(1.2, 0.5, allonge), Vector3(milieu.x + decale.x, y_canal - 0.25, milieu.y + decale.y), pierre, aqueduc, false)
			banquette.rotation.y = angle
		var fond := _boite(Vector3(1.0, 0.06, allonge), Vector3(milieu.x, y_canal - 0.47, milieu.y), mat_limon, aqueduc, false)
		fond.rotation.y = angle
		var nappe := _boite(Vector3(0.98, 0.04, allonge), Vector3(milieu.x, y_canal - 0.08, milieu.y), mat_eau, eau, false)
		nappe.rotation.y = angle
		# Le dallage où l'on marche : une collision seule (la rigole reste visible).
		var sol := StaticBody3D.new()
		var forme_sol := CollisionShape3D.new()
		var boite_sol := BoxShape3D.new()
		boite_sol.size = Vector3(largeur_canal, 0.3, allonge)
		forme_sol.shape = boite_sol
		sol.add_child(forme_sol)
		sol.position = Vector3(milieu.x, y_canal - 0.15, milieu.y)
		sol.rotation.y = angle
		aqueduc.add_child(sol)
		# Les piliers et les arches.
		var n := maxi(1, roundi(longueur / travee))
		var pas := longueur / n
		var portee := pas - largeur_pilier
		var r := portee * 0.5
		var naissance := y_bas - 1.2 - r
		for k in n + 1:
			if k == n and i < points.size() - 2:
				continue
			var p := a.lerp(b, float(k) / n)
			var libre := true
			for rect: Rect2 in sans_piliers:
				if rect.has_point(p):
					libre = false
			if libre:
				var sol_p := hauteur(p.x, p.y)
				var h_pilier := naissance - sol_p + 1.5
				if h_pilier > 0.5:
					var pilier := _boite(Vector3(epaisseur, h_pilier, largeur_pilier), Vector3(p.x, sol_p - 1.5 + h_pilier * 0.5, p.y), pierre, aqueduc)
					pilier.rotation.y = angle
					# Le petit ressaut de l'imposte, sous la naissance des arches.
					var imposte := _boite(Vector3(epaisseur + 0.3, 0.35, largeur_pilier + 0.3), Vector3(p.x, naissance - 0.17, p.y), pierre, aqueduc, false)
					imposte.rotation.y = angle
				# Au-dessus du pilier, entre deux cintres : le plein de maçonnerie.
				var plein := _boite(Vector3(epaisseur, y_bas - naissance, largeur_pilier), Vector3(p.x, (naissance + y_bas) * 0.5, p.y), pierre, aqueduc, false)
				plein.rotation.y = angle
			if k < n:
				var c := a.lerp(b, (k + 0.5) / n)
				var dans_porte := false
				for rect: Rect2 in sans_piliers:
					if rect.has_point(c):
						dans_porte = true
				var bande := y_bas - naissance
				if not dans_porte:
					var arche := MeshInstance3D.new()
					arche.mesh = _maillage_arche(portee, epaisseur, bande)
					arche.material_override = cintre
					arche.position = Vector3(c.x, naissance, c.y)
					arche.rotation.y = angle - PI / 2
					aqueduc.add_child(arche)
	_fusionner(aqueduc)
	return eau


## Un échafaudage de bois des fontainiers, collé contre un aqueduc : des rampes en
## zigzag qui montent du sol jusqu'au canal (« y_haut »). « base » est le point de l'axe
## de l'aqueduc où il s'appuie, « tangente » la direction de l'aqueduc et « normale » le
## côté où il est construit. Renvoie le point (3D) du palier du haut.
func _echafaudage(parent: Node3D, base: Vector2, tangente: Vector2, normale: Vector2, y_haut: float, nom := "Echafaudage") -> Vector3:
	var echafaudage := Node3D.new()
	echafaudage.name = nom
	parent.add_child(echafaudage)
	var bois := _mat_bois()
	var longueur := 8.0
	var palier := 2.0
	var y0 := hauteur(base.x + normale.x * 3.8, base.y + normale.y * 3.8)
	var vols := ceili((y_haut - y0) / 4.4)
	var dh := (y_haut - y0) / vols
	var t3 := Vector3(tangente.x, 0, tangente.y)
	var n3 := Vector3(normale.x, 0, normale.y)
	var origine := Vector3(base.x, 0, base.y)
	var haut := Vector3.ZERO
	for k in vols + 1:
		var bout := -1.0 if k % 2 == 0 else 1.0
		var y := y0 + k * dh
		if k > 0:
			var centre := origine + t3 * bout * (longueur * 0.5 + palier * 0.5) + n3 * 3.8
			centre.y = y - 0.1
			var planche := _boite(Vector3(4.4, 0.2, palier), centre, bois, echafaudage)
			planche.rotation.y = atan2(t3.x, t3.z)
			haut = Vector3(centre.x, y, centre.z)
		if k < vols:
			# La rampe du vol k, d'un bout à l'autre, dans le couloir extérieur ou intérieur.
			var couloir := 4.9 if k % 2 == 0 else 2.7
			var depart := origine + t3 * bout * longueur * 0.5 + n3 * couloir
			depart.y = y
			var arrivee := origine - t3 * bout * longueur * 0.5 + n3 * couloir
			arrivee.y = y + dh
			var dir := (arrivee - depart)
			var rampe := _boite(Vector3(2.0, 0.2, dir.length() + 0.3), (depart + arrivee) * 0.5 - Vector3(0, 0.1, 0), bois, echafaudage)
			var z := dir.normalized()
			var x := n3
			var yv := z.cross(x)
			if yv.y < 0.0:
				x = -x
				yv = z.cross(x)
			rampe.basis = Basis(x, yv, z)
			# Des tasseaux cloués en travers, pour ne pas glisser.
			for j in 6:
				var q := depart.lerp(arrivee, (j + 0.5) / 6.0)
				var tasseau := _boite(Vector3(1.9, 0.06, 0.08), q + yv * 0.02, bois, echafaudage, false)
				tasseau.basis = Basis(x, yv, z)
	# Les montants : de longues perches plantées dans le sol, liées par des traverses.
	for t: float in [-(longueur * 0.5 + palier), -longueur * 0.5, longueur * 0.5, longueur * 0.5 + palier]:
		for o: float in [1.75, 3.8, 5.95]:
			var p := origine + t3 * t + n3 * o
			var sol := hauteur(p.x, p.z)
			var perche := MeshInstance3D.new()
			perche.mesh = _cylindre(0.08, 0.1, y_haut + 1.2 - sol, 6)
			perche.material_override = bois
			perche.position = Vector3(p.x, (sol + y_haut + 1.2) * 0.5, p.z)
			echafaudage.add_child(perche)
	# Une rambarde le long du bord extérieur, pour ne pas tomber.
	for k in vols:
		var y := y0 + (k + 0.5) * dh + 0.9
		var p := origine + n3 * 6.0
		var garde := _boite(Vector3(0.08, 0.08, longueur + palier * 2.0), Vector3(p.x, y, p.z), bois, echafaudage, false)
		garde.rotation.y = atan2(t3.x, t3.z)
	_fusionner(echafaudage)
	return haut
