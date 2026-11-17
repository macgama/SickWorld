extends RefCounted
## Arbres réalistes fabriqués par le code (aucun téléchargement nécessaire).
##
## Chaque essence est décrite par une fiche (ESSENCES) : tronc, ramification,
## forme du houppier, feuilles. Le tronc et les branches sont de vrais tubes qui
## s'affinent et se courbent ; le feuillage est fait de centaines de « cartes »
## de rameaux découpés (texture dessinée ici même, avec transparence), comme dans
## les jeux AAA. Le vent fait bouger les branches et frémir les feuilles.
##
## Utilisation (depuis une zone) :
##   const Arbres := preload("res://scripts/monde/vegetation/arbres.gd")
##   var arbre := Arbres.planter(parent, Vector3(x, y, z), "olivier", hasard, 1.0, materiau_ecorce)
##
## Les maillages sont mis en cache : NB_VARIANTES formes par essence, réutilisées
## (avec rotation, taille et teinte différentes) pour tous les arbres de la zone.

const SHADER_FEUILLAGE := preload("res://shaders/feuillage.gdshader")
const NB_VARIANTES := 4
const TAILLE_TEXTURE := 512

## Fiches des essences.
## tronc : [hauteur min, hauteur max], rayon : rayon du pied (m)
## penche : inclinaison max du tronc (rad), torsion : ondulation du tronc
## forme : feuillu | conifere | colonne | parasol | palmier | buisson
## niveaux : profondeur de ramification ; branches : nombre d'enfants par niveau
## angle : écart des enfants (degrés) par niveau ; longueur : rapport de longueur par niveau
## debut : où commencent les branches sur le tronc (0-1) ; montee : redressement (+) ou retombée (-)
## feuille : motif de la texture ; cartes : cartes par rameau terminal ; carte : taille (m)
## couleur : teinte des feuilles ; variation : teinte d'un arbre sur deux
const ESSENCES := {
	"olivier": {
		"forme": "feuillu", "tronc": [1.1, 1.8], "rayon": 0.26, "penche": 0.25, "torsion": 0.22,
		"niveaux": 3, "branches": [4, 4, 3], "angle": [42, 38, 40], "longueur": [0.95, 0.62, 0.55],
		"longueur_branche": 2.2, "debut": 0.75, "montee": [0.15, 0.0, -0.1],
		"feuille": "olivier", "cartes": 7, "carte": 0.85,
		"couleur": Color(0.62, 0.68, 0.55), "variation": Color(0.9, 0.93, 0.88), "translucidite": 0.35,
	},
	"chene": {
		"forme": "feuillu", "tronc": [2.6, 3.6], "rayon": 0.36, "penche": 0.08, "torsion": 0.12,
		"niveaux": 3, "branches": [6, 4, 3], "angle": [48, 40, 38], "longueur": [0.85, 0.6, 0.5],
		"longueur_branche": 4.2, "debut": 0.6, "montee": [0.2, 0.05, -0.05],
		"feuille": "large", "cartes": 8, "carte": 1.2,
		"couleur": Color(0.62, 0.78, 0.45), "variation": Color(0.82, 0.92, 0.7), "translucidite": 0.55,
	},
	"murier": {
		"forme": "feuillu", "tronc": [1.6, 2.2], "rayon": 0.2, "penche": 0.12, "torsion": 0.15,
		"niveaux": 3, "branches": [5, 4, 3], "angle": [45, 40, 36], "longueur": [0.8, 0.6, 0.5],
		"longueur_branche": 2.4, "debut": 0.7, "montee": [0.3, 0.1, 0.0],
		"feuille": "large", "cartes": 7, "carte": 0.95,
		"couleur": Color(0.68, 0.86, 0.48), "variation": Color(0.86, 0.95, 0.75), "translucidite": 0.6,
	},
	"peuplier": {
		"forme": "colonne", "tronc": [9.0, 13.0], "rayon": 0.26, "penche": 0.04, "torsion": 0.05,
		"niveaux": 2, "branches": [26, 3], "angle": [22, 30], "longueur": [0.2, 0.5],
		"longueur_branche": 9.0, "debut": 0.12, "montee": [0.5, 0.3],
		"feuille": "large", "cartes": 6, "carte": 0.9,
		"couleur": Color(0.66, 0.8, 0.42), "variation": Color(0.95, 0.92, 0.6), "translucidite": 0.6,
	},
	"peuplier_hiver": {
		"forme": "colonne", "tronc": [8.0, 11.0], "rayon": 0.24, "penche": 0.05, "torsion": 0.06,
		"niveaux": 3, "branches": [24, 4, 3], "angle": [24, 32, 30], "longueur": [0.22, 0.5, 0.45],
		"longueur_branche": 8.0, "debut": 0.12, "montee": [0.5, 0.35, 0.3],
		"feuille": "", "cartes": 0, "carte": 0.0,
		"couleur": Color(1, 1, 1), "variation": Color(1, 1, 1), "translucidite": 0.0,
	},
	# Peuplier de l'Euphrate en hiver : tronc noueux, quelques feuilles d'or qui restent.
	"peuplier_desert": {
		"forme": "feuillu", "tronc": [2.2, 3.4], "rayon": 0.32, "penche": 0.3, "torsion": 0.3,
		"niveaux": 3, "branches": [4, 4, 3], "angle": [48, 44, 40], "longueur": [0.85, 0.6, 0.5],
		"longueur_branche": 2.8, "debut": 0.7, "montee": [0.25, 0.05, -0.1],
		"feuille": "olivier", "cartes": 3, "carte": 0.95, "dessin": Color(0.66, 0.46, 0.1),
		"couleur": Color(0.68, 0.66, 0.62), "variation": Color(1.0, 0.85, 0.7), "translucidite": 0.6,
	},
	# Mûrier taillé en têtard, nu en hiver : tronc court, couronne de rejets droits.
	"murier_tetard": {
		"forme": "feuillu", "tronc": [1.6, 1.9], "rayon": 0.27, "penche": 0.08, "torsion": 0.12,
		"niveaux": 2, "branches": [13, 3], "angle": [24, 30], "longueur": [1.0, 0.35],
		"longueur_branche": 1.7, "debut": 0.93, "montee": [0.35, 0.3],
		"feuille": "", "cartes": 0, "carte": 0.0,
		"couleur": Color(1, 1, 1), "variation": Color(1, 1, 1), "translucidite": 0.0,
	},
	"tamaris": {
		"forme": "buisson", "tronc": [0.6, 1.0], "rayon": 0.12, "penche": 0.35, "torsion": 0.3,
		"niveaux": 3, "branches": [5, 4, 3], "angle": [38, 34, 30], "longueur": [1.0, 0.65, 0.55],
		"longueur_branche": 1.8, "debut": 0.6, "montee": [0.45, 0.2, -0.05],
		"feuille": "plumeux", "cartes": 6, "carte": 0.8, "dessin": Color(0.42, 0.24, 0.18),
		"couleur": Color(0.68, 0.66, 0.64), "variation": Color(1.0, 0.85, 0.9), "translucidite": 0.5,
	},
	"bouleau": {
		"forme": "feuillu", "tronc": [6.0, 9.0], "rayon": 0.16, "penche": 0.06, "torsion": 0.08,
		"niveaux": 3, "branches": [9, 4, 3], "angle": [40, 38, 34], "longueur": [0.35, 0.6, 0.55],
		"longueur_branche": 6.0, "debut": 0.35, "montee": [0.25, -0.15, -0.35],
		"feuille": "petite", "cartes": 6, "carte": 0.9,
		"couleur": Color(0.7, 0.84, 0.45), "variation": Color(0.95, 0.92, 0.6), "translucidite": 0.65,
	},
	# Bouleau d'automne (forêt de la Préhistoire) : feuillage d'or.
	"bouleau_automne": {
		"forme": "feuillu", "tronc": [6.0, 9.0], "rayon": 0.16, "penche": 0.06, "torsion": 0.08,
		"niveaux": 3, "branches": [9, 4, 3], "angle": [40, 38, 34], "longueur": [0.35, 0.6, 0.55],
		"longueur_branche": 6.0, "debut": 0.35, "montee": [0.25, -0.15, -0.35],
		"feuille": "petite", "cartes": 6, "carte": 0.9, "dessin": Color(0.66, 0.5, 0.13),
		"couleur": Color(0.68, 0.66, 0.62), "variation": Color(1.05, 0.85, 0.7), "translucidite": 0.7,
	},
	# Buissons bas (couvre-sol) : vert, sec (steppe, désert), nu en hiver.
	"buisson": {
		"forme": "buisson", "tronc": [0.12, 0.3], "rayon": 0.05, "penche": 0.3, "torsion": 0.2,
		"niveaux": 2, "branches": [7, 4], "angle": [55, 40], "longueur": [1.0, 0.6],
		"longueur_branche": 0.9, "debut": 0.3, "montee": [0.45, 0.1],
		"feuille": "petite", "cartes": 5, "carte": 0.55,
		"couleur": Color(0.6, 0.74, 0.45), "variation": Color(0.88, 0.95, 0.7), "translucidite": 0.5,
	},
	"buisson_sec": {
		"forme": "buisson", "tronc": [0.1, 0.25], "rayon": 0.04, "penche": 0.3, "torsion": 0.25,
		"niveaux": 2, "branches": [8, 4], "angle": [55, 40], "longueur": [1.0, 0.6],
		"longueur_branche": 0.8, "debut": 0.25, "montee": [0.4, 0.1],
		"feuille": "plumeux", "cartes": 4, "carte": 0.5, "dessin": Color(0.48, 0.44, 0.28),
		"couleur": Color(0.66, 0.64, 0.6), "variation": Color(1.0, 0.92, 0.8), "translucidite": 0.35,
	},
	"buisson_hiver": {
		"forme": "buisson", "tronc": [0.1, 0.25], "rayon": 0.045, "penche": 0.3, "torsion": 0.25,
		"niveaux": 3, "branches": [7, 4, 3], "angle": [50, 40, 35], "longueur": [1.0, 0.6, 0.5],
		"longueur_branche": 0.9, "debut": 0.25, "montee": [0.45, 0.2, 0.1],
		"feuille": "", "cartes": 0, "carte": 0.0,
		"couleur": Color(1, 1, 1), "variation": Color(1, 1, 1), "translucidite": 0.0,
	},
	"pin": {
		"forme": "conifere", "tronc": [8.0, 12.0], "rayon": 0.24, "penche": 0.04, "torsion": 0.05,
		"niveaux": 2, "branches": [30, 4], "angle": [82, 40], "longueur": [0.3, 0.45],
		"longueur_branche": 8.0, "debut": 0.3, "montee": [-0.15, 0.1],
		"feuille": "aiguilles", "cartes": 6, "carte": 1.0,
		"couleur": Color(0.5, 0.62, 0.42), "variation": Color(0.88, 0.95, 0.85), "translucidite": 0.3,
	},
	"sapin": {
		"forme": "conifere", "tronc": [7.0, 11.0], "rayon": 0.22, "penche": 0.02, "torsion": 0.03,
		"niveaux": 2, "branches": [38, 4], "angle": [95, 45], "longueur": [0.36, 0.45],
		"longueur_branche": 7.0, "debut": 0.08, "montee": [-0.25, 0.0],
		"feuille": "aiguilles", "cartes": 7, "carte": 1.0,
		"couleur": Color(0.42, 0.55, 0.42), "variation": Color(0.85, 0.95, 0.9), "translucidite": 0.25,
	},
	"pin_parasol": {
		"forme": "parasol", "tronc": [7.0, 10.0], "rayon": 0.3, "penche": 0.18, "torsion": 0.1,
		"niveaux": 3, "branches": [5, 4, 4], "angle": [50, 42, 36], "longueur": [0.42, 0.6, 0.55],
		"longueur_branche": 8.0, "debut": 0.82, "montee": [0.1, -0.05, -0.15],
		"feuille": "aiguilles", "cartes": 9, "carte": 1.25,
		"couleur": Color(0.5, 0.62, 0.38), "variation": Color(0.9, 0.95, 0.8), "translucidite": 0.3,
	},
	"cypres": {
		"forme": "colonne", "tronc": [8.0, 11.5], "rayon": 0.2, "penche": 0.02, "torsion": 0.03,
		"niveaux": 2, "branches": [40, 3], "angle": [20, 25], "longueur": [0.13, 0.5],
		"longueur_branche": 9.0, "debut": 0.04, "montee": [0.6, 0.4],
		"feuille": "ecailles", "cartes": 8, "carte": 0.9,
		"couleur": Color(0.38, 0.5, 0.34), "variation": Color(0.9, 0.95, 0.85), "translucidite": 0.25,
	},
	"palmier": {
		"forme": "palmier", "tronc": [8.0, 12.0], "rayon": 0.22, "penche": 0.22, "torsion": 0.0,
		"palmes": 26, "longueur_palme": 3.8,
		"feuille": "palme", "cartes": 0, "carte": 0.0,
		"couleur": Color(0.6, 0.7, 0.42), "variation": Color(0.95, 0.88, 0.6), "translucidite": 0.45,
	},
	# Touffe de bambous : chaumes annelés qui s'arquent, feuilles longues et fines.
	"bambou": {
		"forme": "bambou", "tronc": [5.0, 9.0], "rayon": 0.045, "penche": 0.18, "torsion": 0.0,
		"chaumes": 16,
		"feuille": "bambou", "cartes": 24, "carte": 1.25,
		"couleur": Color(0.62, 0.74, 0.45), "variation": Color(0.92, 0.95, 0.75), "translucidite": 0.6,
	},
	# Touffe de papyrus : tiges triangulaires lisses, ombelles en plumeau (rayons fins).
	# Tiges et ombelles sont dans le feuillage : elles se balancent ensemble au vent.
	"papyrus": {
		"forme": "papyrus", "tronc": [2.0, 3.8], "rayon": 0.022, "penche": 0.4, "torsion": 0.0,
		"chaumes": 11,
		"feuille": "ombelle", "cartes": 6, "carte": 0.55,
		"couleur": Color(0.62, 0.74, 0.4), "variation": Color(0.95, 0.92, 0.7), "translucidite": 0.65,
	},
	"saule": {
		"forme": "feuillu", "tronc": [2.4, 3.2], "rayon": 0.34, "penche": 0.15, "torsion": 0.15,
		"niveaux": 3, "branches": [6, 5, 3], "angle": [45, 50, 40], "longueur": [0.85, 0.7, 0.7],
		"longueur_branche": 3.6, "debut": 0.75, "montee": [0.35, -0.4, -0.9],
		"feuille": "olivier", "cartes": 8, "carte": 1.1,
		"couleur": Color(0.7, 0.82, 0.48), "variation": Color(0.9, 0.95, 0.7), "translucidite": 0.6,
	},
}

static var _maillages := {}
static var _textures := {}
static var _feuillages := {}


## Plante un arbre : Node3D (posé en `position_pied`) avec le maillage et, si demandé,
## une collision au tronc. `taille` multiplie la taille de l'essence.
static func planter(parent: Node, position_pied: Vector3, essence: String, hasard: RandomNumberGenerator,
		taille := 1.0, ecorce: Material = null, collision := true) -> Node3D:
	var arbre := MeshInstance3D.new()
	arbre.name = "Arbre_%s" % essence
	var variante := hasard.randi() % NB_VARIANTES
	arbre.mesh = maillage(essence, variante, ecorce)
	arbre.position = position_pied
	arbre.rotation.y = hasard.randf() * TAU
	arbre.scale = Vector3.ONE * taille * hasard.randf_range(0.88, 1.12)
	arbre.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	arbre.visibility_range_end = 420.0
	parent.add_child(arbre)
	if collision:
		var fiche: Dictionary = ESSENCES[essence]
		var corps := StaticBody3D.new()
		var forme := CollisionShape3D.new()
		var c := CylinderShape3D.new()
		c.radius = float(fiche["rayon"]) * 1.1
		c.height = 2.4
		forme.shape = c
		forme.position.y = 1.2
		corps.add_child(forme)
		arbre.add_child(corps)
	return arbre


## Maillage (mis en cache) d'une essence : surface 0 = écorce, surface 1 = feuillage.
static func maillage(essence: String, variante: int, ecorce: Material = null) -> ArrayMesh:
	var cle := "%s_%d_%d" % [essence, variante, ecorce.get_instance_id() if ecorce != null else 0]
	if _maillages.has(cle):
		return _maillages[cle]
	var fiche: Dictionary = ESSENCES[essence]
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(essence) + variante * 7919
	var g := _Geometrie.new()
	if fiche["forme"] == "palmier":
		_palmier(g, fiche, hasard)
	elif fiche["forme"] == "bambou":
		_bambou(g, fiche, hasard)
	elif fiche["forme"] == "papyrus":
		_papyrus(g, fiche, hasard)
	else:
		_arbre(g, fiche, hasard)
	var m := ArrayMesh.new()
	if not g.ecorce.vide():
		g.ecorce.ajouter_a(m)
		if ecorce == null:
			ecorce = _ecorce_defaut()
		m.surface_set_material(0, ecorce)
	if not g.feuilles.vide():
		g.feuilles.normales_houppier()
		g.feuilles.ajouter_a(m)
		m.surface_set_material(m.get_surface_count() - 1, feuillage(essence))
	_maillages[cle] = m
	return m


## Matériau du feuillage d'une essence (partagé).
static func feuillage(essence: String) -> ShaderMaterial:
	if _feuillages.has(essence):
		return _feuillages[essence]
	var fiche: Dictionary = ESSENCES[essence]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_FEUILLAGE
	mat.set_shader_parameter("texture_feuilles", texture_feuilles(fiche["feuille"], fiche.get("dessin", Color(0, 0, 0, 0))))
	var c: Color = fiche["couleur"]
	mat.set_shader_parameter("teinte", Vector3(c.r, c.g, c.b) * 1.6)
	var v: Color = fiche["variation"]
	mat.set_shader_parameter("teinte_variation", Vector3(v.r, v.g, v.b))
	mat.set_shader_parameter("translucidite", fiche["translucidite"])
	mat.set_shader_parameter("taille_texture", float(TAILLE_TEXTURE))
	if fiche["feuille"] == "palme":
		mat.set_shader_parameter("seuil", 0.35)
	_feuillages[essence] = mat
	return mat


static func _ecorce_defaut() -> StandardMaterial3D:
	if _feuillages.has("_ecorce"):
		return _feuillages["_ecorce"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.36, 0.31, 0.26)
	m.roughness = 0.95
	_feuillages["_ecorce"] = m
	return m


## Une touffe de fleurs sauvages (trois cartes croisées) de la couleur donnée.
static func maillage_fleurs(couleur: Color) -> ArrayMesh:
	var cle := "fleurs_%s" % couleur.to_html()
	if _maillages.has(cle):
		return _maillages[cle]
	var s := _Surface.new()
	for k in 3:
		var a := PI * k / 3.0
		var cote := Vector3(cos(a), 0, sin(a))
		_carte(s, Vector3.ZERO - Vector3(0, 0.02, 0), Vector3.UP, cote, 0.5, 0.42, 0.6, float(k) / 3.0)
	for i in s.normales.size():
		s.normales[i] = Vector3.UP
	var m := ArrayMesh.new()
	s.ajouter_a(m)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_FEUILLAGE
	mat.set_shader_parameter("texture_feuilles", _texture_fleurs(couleur))
	mat.set_shader_parameter("teinte", Vector3.ONE)
	mat.set_shader_parameter("teinte_variation", Vector3(0.95, 0.95, 0.9))
	mat.set_shader_parameter("translucidite", 0.4)
	mat.set_shader_parameter("force_vent", 0.6)
	mat.set_shader_parameter("taille_texture", 256.0)
	m.surface_set_material(0, mat)
	_maillages[cle] = m
	return m


## Tapis d'herbe : trois cartes croisées couvertes de brins dessinés (cache le sol nu).
static func maillage_herbe(base: Color, pointe: Color) -> ArrayMesh:
	var cle := "herbe_%s_%s" % [base.to_html(), pointe.to_html()]
	if _maillages.has(cle):
		return _maillages[cle]
	var s := _Surface.new()
	for k in 3:
		var a := PI * k / 3.0 + 0.3
		_carte(s, Vector3.ZERO - Vector3(0, 0.03, 0), Vector3.UP, Vector3(cos(a), 0, sin(a)), 0.9, 0.42, 0.5, float(k) / 3.0)
	for i in s.normales.size():
		s.normales[i] = Vector3.UP
	var m := ArrayMesh.new()
	s.ajouter_a(m)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_FEUILLAGE
	mat.set_shader_parameter("texture_feuilles", _texture_herbe(base, pointe))
	mat.set_shader_parameter("teinte", Vector3.ONE)
	mat.set_shader_parameter("teinte_variation", Vector3(1.05, 0.95, 0.85))
	mat.set_shader_parameter("translucidite", 0.45)
	mat.set_shader_parameter("force_vent", 0.8)
	mat.set_shader_parameter("taille_texture", 256.0)
	mat.set_shader_parameter("seuil", 0.4)
	m.surface_set_material(0, mat)
	_maillages[cle] = m
	return m


static func _texture_herbe(base: Color, pointe: Color) -> Texture2D:
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 77
	var d := _Dessin.new(image)
	for i in 90:
		var x := hasard.randf_range(0.03, 0.97)
		var haut := hasard.randf_range(0.3, 0.97)
		var penche := hasard.randf_range(-0.18, 0.18)
		var precedent := Vector2(x, 1.0)
		var c := base.lerp(pointe, hasard.randf_range(0.2, 0.9)) * hasard.randf_range(0.8, 1.15)
		for e in 4:
			var t := float(e + 1) / 4.0
			var p := Vector2(x + penche * t * t, 1.0 - haut * t)
			d.segment(precedent, p, 0.009 * (1.0 - t * 0.7), base.lerp(c, t))
			precedent = p
	d.boucher_fond()
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## Litière : une plaque posée au sol (feuilles mortes, brindilles, gravillons) qui casse
## la répétition de la texture du terrain.
static func maillage_litiere(teinte: Color) -> ArrayMesh:
	var cle := "litiere_%s" % teinte.to_html()
	if _maillages.has(cle):
		return _maillages[cle]
	var s := _Surface.new()
	var c := Color(0.0, 0.0, 0.0)
	var i0 := s.sommet(Vector3(-0.8, 0.06, -0.8), Vector3.UP, Vector2(0, 0), c)
	var i1 := s.sommet(Vector3(0.8, 0.06, -0.8), Vector3.UP, Vector2(1, 0), c)
	var i2 := s.sommet(Vector3(0.8, 0.06, 0.8), Vector3.UP, Vector2(1, 1), c)
	var i3 := s.sommet(Vector3(-0.8, 0.06, 0.8), Vector3.UP, Vector2(0, 1), c)
	s.indices.append_array([i0, i2, i1, i0, i3, i2])
	var m := ArrayMesh.new()
	s.ajouter_a(m)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_FEUILLAGE
	mat.set_shader_parameter("texture_feuilles", _texture_litiere())
	mat.set_shader_parameter("teinte", Vector3(teinte.r, teinte.g, teinte.b))
	mat.set_shader_parameter("teinte_variation", Vector3(0.9, 0.85, 0.8))
	mat.set_shader_parameter("translucidite", 0.0)
	mat.set_shader_parameter("force_vent", 0.0)
	mat.set_shader_parameter("seuil", 0.5)
	m.surface_set_material(0, mat)
	_maillages[cle] = m
	return m


static func _texture_litiere() -> Texture2D:
	if _textures.has("_litiere"):
		return _textures["_litiere"]
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 911
	var d := _Dessin.new(image)
	var centre := Vector2(0.5, 0.5)
	for i in 70:
		# Plus dense au centre : la plaque se fond dans le sol sur les bords.
		var p := centre + Vector2.from_angle(hasard.randf() * TAU) * pow(hasard.randf(), 0.7) * 0.42
		var sorte := hasard.randf()
		if sorte < 0.55:
			var c := Color(0.45, 0.33, 0.2).lerp(Color(0.62, 0.5, 0.3), hasard.randf()) * hasard.randf_range(0.7, 1.1)
			d.feuille(p, hasard.randf() * TAU, hasard.randf_range(0.05, 0.09), hasard.randf_range(0.015, 0.03), c)
		elif sorte < 0.8:
			var a := hasard.randf() * TAU
			d.segment(p, p + Vector2.from_angle(a) * hasard.randf_range(0.06, 0.16), 0.006,
					Color(0.32, 0.25, 0.18) * hasard.randf_range(0.8, 1.2))
		else:
			d.segment(p, p + Vector2(0.001, 0), hasard.randf_range(0.008, 0.016),
					Color(0.55, 0.52, 0.48) * hasard.randf_range(0.7, 1.15))
	d.boucher_fond()
	image.generate_mipmaps()
	var tex := ImageTexture.create_from_image(image)
	_textures["_litiere"] = tex
	return tex


static func _texture_fleurs(couleur: Color) -> Texture2D:
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(couleur.to_html())
	var d := _Dessin.new(image)
	for k in 9:
		var pied := Vector2(hasard.randf_range(0.2, 0.8), 1.0)
		var tete := Vector2(pied.x + hasard.randf_range(-0.15, 0.15), hasard.randf_range(0.12, 0.55))
		d.segment(pied, tete, 0.012, Color(0.26, 0.36, 0.14) * hasard.randf_range(0.8, 1.2))
		# Quelques feuilles le long de la tige.
		for f in 2:
			var p := pied.lerp(tete, hasard.randf_range(0.2, 0.7))
			var cote := -1.0 if f == 0 else 1.0
			d.feuille(p, -PI * 0.5 + cote * 0.7, 0.12, 0.025, Color(0.28, 0.4, 0.15))
		# La fleur : des pétales en étoile autour d'un cœur.
		var nb_petales := 5 + hasard.randi() % 3
		var c := couleur * hasard.randf_range(0.85, 1.15)
		for pe in nb_petales:
			var a := TAU * pe / nb_petales + hasard.randf() * 0.3
			d.feuille(tete, a, 0.055, 0.03, c)
		d.segment(tete, tete + Vector2(0.001, 0), 0.016, Color(0.85, 0.7, 0.15) if couleur.r + couleur.g > 1.2 else Color(0.12, 0.1, 0.06))
	d.boucher_fond()
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


# --- Construction ------------------------------------------------------------

## Tampon de sommets d'une surface.
class _Surface:
	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()
	var uvs := PackedVector2Array()
	var couleurs := PackedColorArray()
	var indices := PackedInt32Array()

	func vide() -> bool:
		return indices.is_empty()

	func sommet(p: Vector3, n: Vector3, uv: Vector2, c: Color) -> int:
		sommets.append(p)
		normales.append(n)
		uvs.append(uv)
		couleurs.append(c)
		return sommets.size() - 1

	## Les cartes de feuilles prennent une normale tournée vers l'extérieur du houppier :
	## l'éclairage devient doux et volumineux au lieu de facettes plates.
	func normales_houppier() -> void:
		var centre := Vector3.ZERO
		for p in sommets:
			centre += p
		centre /= maxf(1.0, sommets.size())
		# Centre un peu bas : le dessus du houppier reçoit la lumière du ciel.
		centre.y -= 0.6
		for i in sommets.size():
			var dehors := (sommets[i] - centre)
			dehors.y *= 0.7
			normales[i] = (normales[i] * 0.35 + dehors.normalized() * 0.65).normalized()

	func ajouter_a(m: ArrayMesh) -> void:
		var tableaux := []
		tableaux.resize(Mesh.ARRAY_MAX)
		tableaux[Mesh.ARRAY_VERTEX] = sommets
		tableaux[Mesh.ARRAY_NORMAL] = normales
		tableaux[Mesh.ARRAY_TEX_UV] = uvs
		tableaux[Mesh.ARRAY_COLOR] = couleurs
		tableaux[Mesh.ARRAY_INDEX] = indices
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tableaux)


class _Geometrie:
	var ecorce := _Surface.new()
	var feuilles := _Surface.new()


## Un repère qui suit une courbe (transport parallèle) pour faire des tubes sans torsion.
static func _perpendiculaire(d: Vector3) -> Vector3:
	var a := Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT
	return d.cross(a).normalized()


## Tube qui suit `points`, de rayons `rayons`. `souplesse` : [début, fin] pour le vent.
static func _tube(s: _Surface, points: Array[Vector3], rayons: Array[float], cotes: int,
		souplesse: Vector2, phase: float) -> void:
	var n := points.size()
	if n < 2:
		return
	var depart := s.sommets.size()
	var d0 := (points[1] - points[0]).normalized()
	var x := _perpendiculaire(d0)
	var longueur := 0.0
	for i in n:
		var d: Vector3
		if i == 0:
			d = d0
		elif i == n - 1:
			d = (points[i] - points[i - 1]).normalized()
		else:
			d = (points[i + 1] - points[i - 1]).normalized()
		# Transport parallèle : on retire de x sa composante le long de d.
		x = (x - d * x.dot(d)).normalized()
		var y := d.cross(x)
		if i > 0:
			longueur += points[i].distance_to(points[i - 1])
		var t := float(i) / (n - 1)
		var c := Color(lerpf(souplesse.x, souplesse.y, t), phase, 0.0)
		for k in cotes + 1:
			var a := TAU * k / cotes
			var radial := x * cos(a) + y * sin(a)
			s.sommet(points[i] + radial * rayons[i], radial, Vector2(float(k) / cotes, longueur), c)
	for i in n - 1:
		for k in cotes:
			var a := depart + i * (cotes + 1) + k
			var b := a + cotes + 1
			s.indices.append_array([a, b, a + 1, a + 1, b, b + 1])


## Une carte de rameau : un quadrilatère dont le bas est accroché au point `base`.
static func _carte(s: _Surface, base: Vector3, direction: Vector3, cote: Vector3, largeur: float,
		longueur: float, souplesse: float, phase: float) -> void:
	var n := direction.cross(cote).normalized()
	var c := Color(souplesse, phase, 1.0)
	var c_base := Color(souplesse * 0.8, phase, 0.2)
	var g := cote * largeur * 0.5
	var h := direction * longueur
	var i0 := s.sommet(base - g, n, Vector2(0, 1), c_base)
	var i1 := s.sommet(base + g, n, Vector2(1, 1), c_base)
	var i2 := s.sommet(base + g + h, n, Vector2(1, 0), c)
	var i3 := s.sommet(base - g + h, n, Vector2(0, 0), c)
	s.indices.append_array([i0, i1, i2, i0, i2, i3])


## Point et direction le long d'une polyligne (t de 0 à 1).
static func _le_long(points: Array[Vector3], t: float) -> Array:
	var n := points.size() - 1
	var f := clampf(t, 0.0, 1.0) * n
	var i := mini(int(f), n - 1)
	var r := f - i
	var p := points[i].lerp(points[i + 1], r)
	var d := (points[i + 1] - points[i]).normalized()
	return [p, d]


## Fait tourner `v` autour de `axe`.
static func _tourner(v: Vector3, axe: Vector3, angle: float) -> Vector3:
	return v.rotated(axe.normalized(), angle)


static func _arbre(g: _Geometrie, fiche: Dictionary, hasard: RandomNumberGenerator) -> void:
	var forme: String = fiche["forme"]
	var hauteur_tronc := hasard.randf_range(fiche["tronc"][0], fiche["tronc"][1])
	var rayon: float = fiche["rayon"] * hasard.randf_range(0.9, 1.1)
	# Le tronc : légèrement penché, ondulé ; pour les conifères et colonnes il monte jusqu'en haut.
	var penche := hasard.randf_range(0.0, fiche["penche"])
	var cap := hasard.randf() * TAU
	var direction := Vector3(sin(cap) * sin(penche), cos(penche), cos(cap) * sin(penche)).normalized()
	var longueur_tronc := hauteur_tronc
	if forme in ["conifere", "colonne"]:
		longueur_tronc = fiche["longueur_branche"] * hasard.randf_range(0.9, 1.1) + hauteur_tronc * 0.1
	var points := _chemin(Vector3.ZERO, direction, longueur_tronc, 12, fiche["torsion"], 0.05, hasard)
	var rayons: Array[float] = []
	for i in points.size():
		var t := float(i) / (points.size() - 1)
		# Évasement du pied, puis affinement.
		var r := rayon * (1.0 - t * 0.55) * (1.0 + 0.45 * pow(1.0 - minf(1.0, t * 6.0), 2.0))
		if forme in ["conifere", "colonne"]:
			r = rayon * maxf(0.06, 1.0 - t * 0.95) * (1.0 + 0.4 * pow(1.0 - minf(1.0, t * 6.0), 2.0))
		rayons.append(r)
	_tube(g.ecorce, points, rayons, 10, Vector2(0.0, 0.15), hasard.randf())
	_branches(g, fiche, hasard, points, rayons, 0, fiche["longueur_branche"], 0.15)
	# Racines : quelques contreforts au pied.
	for k in 4:
		var a := TAU * k / 4.0 + hasard.randf_range(-0.4, 0.4)
		var dir := Vector3(cos(a), -0.35, sin(a)).normalized()
		var pr: Array[Vector3] = [Vector3(0, rayon * 0.9, 0), Vector3(cos(a), 0, sin(a)) * rayon * 1.2 + Vector3(0, 0.1, 0),
				Vector3(cos(a), 0, sin(a)) * rayon * 2.4 + dir * 0.2]
		var rr: Array[float] = [rayon * 0.5, rayon * 0.35, rayon * 0.1]
		_tube(g.ecorce, pr, rr, 6, Vector2.ZERO, 0.0)


## Chemin d'une branche : part de `depart` selon `direction`, se courbe (montee > 0 = vers le haut).
static func _chemin(depart: Vector3, direction: Vector3, longueur: float, segments: int,
		torsion: float, montee: float, hasard: RandomNumberGenerator) -> Array[Vector3]:
	var points: Array[Vector3] = [depart]
	var p := depart
	var d := direction.normalized()
	var pas := longueur / segments
	var bruit := Vector3(hasard.randf_range(-1, 1), 0, hasard.randf_range(-1, 1))
	for i in segments:
		var ondule := Vector3(sin(i * 0.9 + bruit.x * 3.0), 0, cos(i * 0.7 + bruit.z * 3.0)) * torsion
		d = (d + ondule * 0.35 + Vector3.UP * montee * 0.3).normalized()
		p += d * pas
		points.append(p)
	return points


static func _branches(g: _Geometrie, fiche: Dictionary, hasard: RandomNumberGenerator,
		parent: Array[Vector3], rayons_parent: Array[float], niveau: int, longueur_parent: float,
		souplesse_parent: float) -> void:
	var niveaux: int = fiche["niveaux"]
	var forme: String = fiche["forme"]
	if niveau >= niveaux:
		_rameaux(g, fiche, hasard, parent, souplesse_parent)
		return
	var nb: int = fiche["branches"][niveau]
	var debut: float = fiche["debut"] if niveau == 0 else 0.25
	var angle := deg_to_rad(fiche["angle"][niveau])
	var rapport: float = fiche["longueur"][niveau]
	var montee: float = fiche["montee"][niveau]
	var rotation := hasard.randf() * TAU
	for i in nb:
		var t := lerpf(debut, 0.97, (i + hasard.randf_range(0.0, 0.6)) / nb)
		if niveau == 0 and forme == "parasol":
			t = lerpf(debut, 1.0, hasard.randf())
		var lp := _le_long(parent, t)
		var base: Vector3 = lp[0]
		var dp: Vector3 = lp[1]
		rotation += deg_to_rad(137.5) + hasard.randf_range(-0.3, 0.3)
		var perp := _tourner(_perpendiculaire(dp), dp, rotation)
		var a := angle * hasard.randf_range(0.8, 1.2)
		var d := (dp * cos(a) + perp * sin(a)).normalized()
		# Longueur selon la forme du houppier.
		var enveloppe := 1.0
		var tt := inverse_lerp(debut, 1.0, t)
		match forme:
			"conifere":
				enveloppe = lerpf(1.0, 0.12, tt) if niveau == 0 else 1.0
			"colonne":
				enveloppe = pow(sin(PI * clampf(tt * 0.92 + 0.06, 0.0, 1.0)), 0.6) if niveau == 0 else 1.0
			"feuillu", "buisson":
				enveloppe = lerpf(1.0, 0.55, tt) if niveau > 0 else lerpf(1.0, 0.75, tt)
			"parasol":
				enveloppe = 1.0
		var longueur := longueur_parent * rapport * enveloppe * hasard.randf_range(0.8, 1.15)
		if longueur < 0.12:
			continue
		var r_base := _rayon_a(rayons_parent, t) * (0.62 if niveau == 0 and forme in ["feuillu", "parasol", "buisson"] else 0.45)
		if forme in ["conifere", "colonne"] and niveau == 0:
			r_base = minf(r_base, 0.05 + longueur * 0.02)
		var segments := 6 if niveau == 0 else 4
		var torsion := float(fiche["torsion"]) * (0.6 + niveau * 0.3)
		var points := _chemin(base - dp * r_base * 0.5, d, longueur, segments, torsion, montee, hasard)
		var rayons: Array[float] = []
		for k in points.size():
			var u := float(k) / (points.size() - 1)
			rayons.append(maxf(0.008, r_base * (1.0 - u * 0.8)))
		var souplesse := souplesse_parent + 0.25 + niveau * 0.15
		_tube(g.ecorce, points, rayons, 6 if niveau == 0 else 4, Vector2(souplesse_parent, souplesse), hasard.randf())
		_branches(g, fiche, hasard, points, rayons, niveau + 1, longueur, souplesse)


static func _rayon_a(rayons: Array[float], t: float) -> float:
	var f := clampf(t, 0.0, 1.0) * (rayons.size() - 1)
	var i := mini(int(f), rayons.size() - 2)
	return lerpf(rayons[i], rayons[i + 1], f - i)


## Les cartes de feuilles le long d'un rameau terminal.
static func _rameaux(g: _Geometrie, fiche: Dictionary, hasard: RandomNumberGenerator,
		points: Array[Vector3], souplesse: float) -> void:
	var nb: int = fiche["cartes"]
	var taille: float = fiche["carte"]
	if nb <= 0:
		return
	var forme: String = fiche["forme"]
	var phase := hasard.randf()
	for i in nb:
		var t := lerpf(0.25, 1.0, (i + hasard.randf()) / nb)
		var lp := _le_long(points, t)
		var base: Vector3 = lp[0]
		var d: Vector3 = lp[1]
		var perp := _tourner(_perpendiculaire(d), d, hasard.randf() * TAU)
		var direction := (d * 0.55 + perp * 0.6 + Vector3(0, hasard.randf_range(-0.2, 0.35), 0)).normalized()
		if forme in ["feuillu", "buisson"] and fiche["montee"][fiche["niveaux"] - 1] < -0.3:
			direction = (direction + Vector3.DOWN * 1.2).normalized()  # saule : rameaux retombants
		var cote := direction.cross(_tourner(Vector3.UP, direction, hasard.randf_range(-0.6, 0.6))).normalized()
		if forme in ["conifere", "parasol"]:
			# Conifères : des « plateaux » d'aiguilles presque à plat, dans le sens du rameau.
			var horiz := Vector3(d.x, 0.0, d.z)
			if horiz.length_squared() < 0.01:
				horiz = perp
			horiz = _tourner(horiz.normalized(), Vector3.UP, hasard.randf_range(-0.7, 0.7))
			direction = (horiz + Vector3(0, hasard.randf_range(-0.25, 0.15) + (0.12 if forme == "parasol" else 0.0), 0)).normalized()
			cote = direction.cross(Vector3.UP).normalized()
			cote = _tourner(cote, direction, hasard.randf_range(-0.35, 0.35))
		if cote.length_squared() < 0.01:
			cote = _perpendiculaire(direction)
		var s := taille * hasard.randf_range(0.75, 1.2)
		_carte(g.feuilles, base, direction, cote, s, s * 1.1, souplesse + 0.25, phase)
		# Une seconde carte croisée : plus de volume vu de côté.
		if hasard.randf() < 0.5:
			var cote2 := _tourner(cote, direction, PI * 0.5)
			_carte(g.feuilles, base, direction, cote2, s * 0.9, s, souplesse + 0.25, phase)


## Bambous : une douzaine de chaumes annelés, penchés et arqués, feuillus dans le haut.
static func _bambou(g: _Geometrie, fiche: Dictionary, hasard: RandomNumberGenerator) -> void:
	var nb: int = fiche["chaumes"]
	for k in nb:
		var h := hasard.randf_range(fiche["tronc"][0], fiche["tronc"][1])
		var a := hasard.randf() * TAU
		var depart := Vector3(cos(a), 0, sin(a)) * hasard.randf_range(0.0, 0.9)
		var penche := hasard.randf_range(0.02, fiche["penche"])
		var dir := (Vector3(cos(a), 0, sin(a)) * sin(penche) + Vector3.UP * cos(penche)).normalized()
		var points: Array[Vector3] = []
		var rayons: Array[float] = []
		var segments := 14
		var r0: float = fiche["rayon"] * hasard.randf_range(0.8, 1.25)
		for i in segments + 1:
			var t := float(i) / segments
			# L'arc : le haut retombe un peu sous le poids des feuilles.
			var p := depart + dir * h * t + Vector3(cos(a), 0, sin(a)) * h * 0.12 * t * t - Vector3.UP * h * 0.05 * t * t
			points.append(p)
			var noeud := 1.12 if i % 2 == 0 else 1.0
			rayons.append(r0 * (1.0 - t * 0.6) * noeud)
		_tube(g.ecorce, points, rayons, 6, Vector2(0.0, 0.7), hasard.randf())
		var phase := hasard.randf()
		for c in fiche["cartes"]:
			var t := hasard.randf_range(0.35, 1.0)
			var lp := _le_long(points, t)
			var base: Vector3 = lp[0]
			var d: Vector3 = lp[1]
			var perp := _tourner(_perpendiculaire(d), d, hasard.randf() * TAU)
			var direction := (perp * 0.8 + d * 0.3 + Vector3.DOWN * 0.25).normalized()
			var cote := direction.cross(Vector3.UP).normalized()
			if cote.length_squared() < 0.01:
				cote = _perpendiculaire(direction)
			var taille: float = fiche["carte"] * hasard.randf_range(0.75, 1.2)
			_carte(g.feuilles, base, direction, cote, taille, taille * 1.1, 0.4 + t * 0.5, phase)


## Papyrus : tiges fines (dans la surface du feuillage, UV sur la bande pleine à gauche
## de la texture) et, au sommet, une gerbe de cartes « ombelle » en éventail.
static func _papyrus(g: _Geometrie, fiche: Dictionary, hasard: RandomNumberGenerator) -> void:
	var nb: int = fiche["chaumes"] + hasard.randi_range(-2, 3)
	var s := g.feuilles
	for k in nb:
		var a := hasard.randf() * TAU
		var ecart := hasard.randf_range(0.0, 0.35)
		var base := Vector3(cos(a), 0, sin(a)) * ecart
		var h := hasard.randf_range(fiche["tronc"][0], fiche["tronc"][1])
		# Les tiges du bord penchent plus (la touffe s'ouvre en gerbe).
		var penche := hasard.randf_range(0.03, fiche["penche"]) * (0.4 + ecart * 2.0)
		var dehors := Vector3(cos(a), 0, sin(a))
		var phase := hasard.randf()
		var points: Array[Vector3] = []
		var rayons: Array[float] = []
		var segments := 5
		var r0: float = fiche["rayon"] * hasard.randf_range(0.85, 1.2)
		for i in segments + 1:
			var t := float(i) / segments
			points.append(base + Vector3.UP * h * t + dehors * h * sin(penche) * t * (0.4 + 0.6 * t))
			rayons.append(r0 * (1.0 - t * 0.5))
		var depart := s.sommets.size()
		_tube(s, points, rayons, 3, Vector2(0.0, 1.0), phase)
		for i in range(depart, s.sommets.size()):
			s.uvs[i] = Vector2(0.025, lerpf(0.9, 0.1, s.uvs[i].y / h))
		# L'ombelle : cartes en éventail autour du sommet, certaines dressées, d'autres
		# ouvertes vers l'extérieur ; les tiges courtes (jeunes) ont une ombelle plus petite.
		var sommet := points[-1]
		var axe := (points[-1] - points[-2]).normalized()
		var taille: float = fiche["carte"] * hasard.randf_range(0.7, 1.15) * clampf(h / 3.0, 0.7, 1.1)
		var cartes: int = fiche["cartes"]
		var tour := hasard.randf() * TAU
		for c in cartes:
			var angle := tour + PI * c / cartes * 2.0
			var rad := Vector3(cos(angle), 0, sin(angle))
			var ouvert := 0.25 if c % 2 == 0 else 0.85
			var direction := (axe * (1.0 - ouvert * 0.6) + rad * ouvert).normalized()
			var cote := rad.cross(Vector3.UP).normalized()
			var premier := s.sommets.size()
			_carte(s, sommet - axe * 0.03, direction, cote, taille * 2.0, taille, 1.25, phase)
			# Les cartes n'utilisent pas la bande des tiges (u < 0,06).
			for i in range(premier, s.sommets.size()):
				s.uvs[i].x = 0.06 + s.uvs[i].x * 0.94


## Palmier : stipe annelé et courbe, couronne de palmes arquées.
static func _palmier(g: _Geometrie, fiche: Dictionary, hasard: RandomNumberGenerator) -> void:
	var hauteur := hasard.randf_range(fiche["tronc"][0], fiche["tronc"][1])
	var penche := hasard.randf_range(0.04, fiche["penche"])
	var cap := hasard.randf() * TAU
	var points: Array[Vector3] = []
	var rayons: Array[float] = []
	var segments := 16
	var rayon: float = fiche["rayon"]
	for i in segments + 1:
		var t := float(i) / segments
		# Courbe douce : le stipe se redresse vers le haut.
		var ecart := sin(penche) * hauteur * (t * t * 0.6 + t * 0.4) * (1.0 - t * 0.35)
		points.append(Vector3(sin(cap) * ecart, t * hauteur, cos(cap) * ecart))
		var anneau := 1.0 + 0.06 * (1.0 if i % 2 == 0 else -1.0)
		rayons.append(rayon * (1.25 - t * 0.35) * anneau * (1.0 + 0.5 * pow(maxf(0.0, 1.0 - t * 8.0), 2.0)))
	_tube(g.ecorce, points, rayons, 10, Vector2(0.0, 0.25), hasard.randf())
	var sommet := points[-1]
	# Base des palmes (un renflement).
	var pr: Array[Vector3] = [sommet - Vector3(0, 0.5, 0), sommet + Vector3(0, 0.3, 0)]
	var rr: Array[float] = [rayon * 1.0, rayon * 0.5]
	_tube(g.ecorce, pr, rr, 8, Vector2(0.25, 0.3), 0.0)
	var nb: int = fiche["palmes"]
	var longueur: float = fiche["longueur_palme"]
	for k in nb:
		var a := TAU * k / nb + hasard.randf_range(-0.2, 0.2)
		var etage := float(k % 3)
		# Les palmes du haut se dressent, celles du bas retombent (et sèchent un peu).
		var leve := lerpf(0.95, -0.1, etage / 2.0) + hasard.randf_range(-0.15, 0.15)
		_palme(g.feuilles, sommet + Vector3(0, 0.2 - etage * 0.15, 0), a, leve,
				longueur * hasard.randf_range(0.8, 1.15), hasard.randf())


## Une palme : bande arquée, pliée en V le long de la nervure.
static func _palme(s: _Surface, base: Vector3, cap: float, leve: float, longueur: float, phase: float) -> void:
	var horiz := Vector3(cos(cap), 0, sin(cap))
	var cote := Vector3(-sin(cap), 0, cos(cap))
	var segments := 10
	var depart := s.sommets.size()
	for i in segments + 1:
		var t := float(i) / segments
		# Arc : monte puis retombe sous son poids.
		var angle := leve - t * t * 1.5
		var p := base + horiz * longueur * t * cos(clampf(angle * 0.5, -1.2, 1.2)) \
				+ Vector3.UP * longueur * (sin(leve) * t - t * t * 0.9)
		var largeur := longueur * 0.2 * sin(PI * minf(1.0, t * 1.1 + 0.08))
		var pli := Vector3.UP * largeur * 0.22
		var souple := 0.35 + t * 0.9
		var c := Color(souple, phase, t)
		var n := Vector3.UP
		s.sommet(p - cote * largeur + pli, (n - cote * 0.4).normalized(), Vector2(0, 1.0 - t), c)
		s.sommet(p, n, Vector2(0.5, 1.0 - t), c)
		s.sommet(p + cote * largeur + pli, (n + cote * 0.4).normalized(), Vector2(1, 1.0 - t), c)
	for i in segments:
		var a := depart + i * 3
		var b := a + 3
		s.indices.append_array([a, b, a + 1, a + 1, b, b + 1, a + 1, b + 1, a + 2, a + 2, b + 1, b + 2])


# --- Textures de feuillage (dessinées une fois) -------------------------------

static func dessin_couleur(defaut: Color, dessin: Color) -> Color:
	return defaut if dessin.a == 0.0 else Color(dessin.r, dessin.g, dessin.b)


## `dessin` : couleur des feuilles dessinées (alpha 0 = couleur par défaut du motif).
static func texture_feuilles(motif: String, teinte_dessin := Color(0, 0, 0, 0)) -> Texture2D:
	var cle := motif + teinte_dessin.to_html()
	if _textures.has(cle):
		return _textures[cle]
	var image := Image.create(TAILLE_TEXTURE, TAILLE_TEXTURE, false, Image.FORMAT_RGBA8)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(motif)
	var dessin := _Dessin.new(image)
	var defauts := {
		"large": Color(0.30, 0.42, 0.16), "petite": Color(0.34, 0.46, 0.17), "olivier": Color(0.36, 0.42, 0.28),
		"aiguilles": Color(0.18, 0.28, 0.13), "ecailles": Color(0.17, 0.27, 0.13), "plumeux": Color(0.36, 0.44, 0.27),
		"palme": Color(0.33, 0.43, 0.18), "bambou": Color(0.34, 0.46, 0.18),
		"ombelle": Color(0.38, 0.5, 0.17),
	}
	var c: Color = dessin_couleur(defauts.get(motif, Color(0.3, 0.4, 0.2)), teinte_dessin)
	match motif:
		"large":
			_dessiner_rameau(dessin, hasard, 16, 0.2, 0.09, 0.55, c)
		"petite":
			_dessiner_rameau(dessin, hasard, 30, 0.12, 0.06, 0.6, c)
		"olivier":
			_dessiner_rameau(dessin, hasard, 34, 0.17, 0.03, 0.5, c, true)
		"aiguilles":
			_dessiner_aiguilles(dessin, hasard, c)
		"ecailles":
			_dessiner_ecailles(dessin, hasard, c)
		"plumeux":
			_dessiner_plumeux(dessin, hasard, c)
		"palme":
			_dessiner_palme(dessin, hasard, c)
		"bambou":
			_dessiner_rameau(dessin, hasard, 16, 0.3, 0.032, 0.95, c)
		"ombelle":
			_dessiner_ombelle(dessin, hasard, c)
	dessin.boucher_fond()
	image.generate_mipmaps()
	var tex := ImageTexture.create_from_image(image)
	_textures[cle] = tex
	return tex


## Petit outil de dessin sur une Image (feuilles, tiges).
class _Dessin:
	var image: Image
	var taille: int
	var somme := Vector3.ZERO
	var compte := 0

	func _init(i: Image) -> void:
		image = i
		taille = i.get_width()

	## Segment épais de `a` à `b` (coordonnées 0-1).
	func segment(a: Vector2, b: Vector2, epaisseur: float, couleur: Color) -> void:
		var pa := a * taille
		var pb := b * taille
		var e := epaisseur * taille
		var mini := Vector2i((pa.min(pb) - Vector2.ONE * (e + 1)).floor())
		var maxi := Vector2i((pa.max(pb) + Vector2.ONE * (e + 1)).ceil())
		var ab := pb - pa
		var l2 := maxf(0.0001, ab.length_squared())
		for y in range(maxi(0, mini.y), mini(taille, maxi.y)):
			for x in range(maxi(0, mini.x), mini(taille, maxi.x)):
				var p := Vector2(x + 0.5, y + 0.5)
				var h := clampf((p - pa).dot(ab) / l2, 0.0, 1.0)
				var dist := p.distance_to(pa + ab * h)
				var largeur := e * (1.0 - h * 0.5)
				if dist < largeur:
					_poser(x, y, couleur * (0.85 + 0.15 * (1.0 - dist / largeur)))

	## Feuille en fuseau : de `base`, direction `angle`, longueur `l`, largeur `w`.
	func feuille(base: Vector2, angle: float, l: float, w: float, couleur: Color, dessous := false) -> void:
		var dir := Vector2(cos(angle), sin(angle))
		var perp := Vector2(-dir.y, dir.x)
		var pa := base * taille
		var L := l * taille
		var W := w * taille
		var bout := pa + dir * L
		var mini := Vector2i((pa.min(bout) - Vector2.ONE * (W + 2)).floor())
		var maxi := Vector2i((pa.max(bout) + Vector2.ONE * (W + 2)).ceil())
		for y in range(maxi(0, mini.y), mini(taille, maxi.y)):
			for x in range(maxi(0, mini.x), mini(taille, maxi.x)):
				var v := Vector2(x + 0.5, y + 0.5) - pa
				var le_long := v.dot(dir) / L
				if le_long < 0.0 or le_long > 1.0:
					continue
				var travers := v.dot(perp)
				var limite := W * pow(sin(PI * le_long), 0.75) * (1.0 - 0.25 * le_long)
				if absf(travers) > limite:
					continue
				var bord := absf(travers) / maxf(0.001, limite)
				var c := couleur
				# Une moitié plus claire (la lumière), nervure plus claire, bord plus sombre.
				c = c * (1.08 if travers > 0.0 else 0.9)
				c = c * (0.82 + 0.3 * le_long)
				if absf(travers) < maxf(0.8, W * 0.08):
					c = c.lightened(0.25)
				c = c.darkened(0.25 * bord * bord)
				if dessous and travers < 0.0:
					c = c.lerp(Color(0.62, 0.66, 0.6), 0.45)  # revers argenté (olivier)
				_poser(x, y, c)

	func _poser(x: int, y: int, c: Color) -> void:
		c.a = 1.0
		image.set_pixel(x, y, c)
		somme += Vector3(c.r, c.g, c.b)
		compte += 1

	## Les pixels transparents prennent la couleur moyenne : pas de liseré sombre au loin.
	func boucher_fond() -> void:
		var m := somme / maxf(1.0, compte)
		var fond := Color(m.x, m.y, m.z, 0.0)
		for y in taille:
			for x in taille:
				if image.get_pixel(x, y).a < 0.5:
					image.set_pixel(x, y, fond)


## Un rameau : tige du bas au haut, feuilles alternées (cartes « feuillus »).
static func _dessiner_rameau(d: _Dessin, hasard: RandomNumberGenerator, nb: int, longueur: float,
		largeur: float, ecart: float, couleur: Color, argente := false) -> void:
	# Image : y = 0 en haut ; la base du rameau est en bas au centre.
	var tiges: Array = []
	var base := Vector2(0.5, 0.98)
	var sommet := Vector2(0.5 + hasard.randf_range(-0.08, 0.08), 0.12)
	tiges.append([base, sommet])
	# Deux ou trois ramilles latérales.
	for k in 3:
		var t := 0.3 + k * 0.2
		var depart := base.lerp(sommet, t)
		var cote := -1.0 if k % 2 == 0 else 1.0
		tiges.append([depart, depart + Vector2(cote * 0.3, -0.28)])
	for tg in tiges:
		d.segment(tg[0], tg[1], 0.006, Color(0.3, 0.22, 0.14))
	for i in nb:
		var tg: Array = tiges[i % tiges.size()]
		var t := hasard.randf_range(0.1, 1.0)
		var p: Vector2 = (tg[0] as Vector2).lerp(tg[1], t)
		var axe: Vector2 = (tg[1] as Vector2) - (tg[0] as Vector2)
		var angle_tige := axe.angle()
		var cote := -1.0 if i % 2 == 0 else 1.0
		var angle := angle_tige + cote * ecart * hasard.randf_range(0.7, 1.4)
		var c := couleur * hasard.randf_range(0.82, 1.18)
		c = c.lerp(Color(0.45, 0.48, 0.15), hasard.randf_range(0.0, 0.25))
		d.feuille(p, angle, longueur * hasard.randf_range(0.75, 1.15), largeur * hasard.randf_range(0.8, 1.2), c, argente)


## Aiguilles de pin : des pinceaux denses de traits fins.
static func _dessiner_aiguilles(d: _Dessin, hasard: RandomNumberGenerator, couleur: Color) -> void:
	var base := Vector2(0.5, 0.98)
	var sommet := Vector2(0.5, 0.08)
	d.segment(base, sommet, 0.008, Color(0.32, 0.22, 0.14))
	for k in 4:
		var depart := base.lerp(sommet, 0.25 + k * 0.17)
		var cote := -1.0 if k % 2 == 0 else 1.0
		var bout := depart + Vector2(cote * 0.28, -0.22)
		d.segment(depart, bout, 0.005, Color(0.32, 0.22, 0.14))
		_pinceau(d, hasard, depart, bout, couleur, 70)
	_pinceau(d, hasard, base.lerp(sommet, 0.15), sommet, couleur, 160)


static func _pinceau(d: _Dessin, hasard: RandomNumberGenerator, a: Vector2, b: Vector2, couleur: Color, nb: int) -> void:
	var axe := (b - a)
	for i in nb:
		var t := hasard.randf()
		var p := a + axe * t
		var angle := axe.angle() + hasard.randf_range(-1.1, 1.1)
		var l := hasard.randf_range(0.05, 0.1)
		var c := couleur * hasard.randf_range(0.75, 1.3)
		d.segment(p, p + Vector2(cos(angle), sin(angle)) * l, 0.0035, c)


## Cyprès : des écailles serrées en éventails.
static func _dessiner_ecailles(d: _Dessin, hasard: RandomNumberGenerator, couleur: Color) -> void:
	for i in 260:
		var t := hasard.randf()
		var cx := 0.5 + hasard.randf_range(-0.38, 0.38) * sin(PI * t)
		var p := Vector2(cx, 0.08 + t * 0.88)
		var angle := -PI * 0.5 + hasard.randf_range(-0.7, 0.7)
		d.feuille(p, angle, hasard.randf_range(0.05, 0.09), 0.018, couleur * hasard.randf_range(0.75, 1.3))


## Tamaris : des plumets fins et légers.
static func _dessiner_plumeux(d: _Dessin, hasard: RandomNumberGenerator, couleur: Color) -> void:
	var base := Vector2(0.5, 0.98)
	for k in 7:
		var bout := Vector2(0.5 + hasard.randf_range(-0.4, 0.4), hasard.randf_range(0.05, 0.3))
		d.segment(base, bout, 0.004, Color(0.4, 0.3, 0.25))
		for i in 45:
			var p := base.lerp(bout, hasard.randf_range(0.2, 1.0))
			var a := (bout - base).angle() + hasard.randf_range(-0.9, 0.9)
			d.segment(p, p + Vector2(cos(a), sin(a)) * hasard.randf_range(0.02, 0.05), 0.004,
					couleur * hasard.randf_range(0.8, 1.25))


## Palme : nervure centrale (u = 0,5), folioles de part et d'autre.
static func _dessiner_palme(d: _Dessin, hasard: RandomNumberGenerator, couleur: Color) -> void:
	d.segment(Vector2(0.5, 1.0), Vector2(0.5, 0.0), 0.012, Color(0.5, 0.48, 0.3))
	var n := 85
	for i in n:
		var v := 0.02 + 0.96 * float(i) / n
		for cote: float in [-1.0, 1.0]:
			var base := Vector2(0.5, v)
			var angle := (-PI * 0.5) + cote * hasard.randf_range(0.95, 1.2)  # dirigées vers le bout (v=0)
			var l := 0.46 * hasard.randf_range(0.85, 1.05)
			var c := couleur * hasard.randf_range(0.8, 1.2)
			if v > 0.85:
				c = c.lerp(Color(0.55, 0.45, 0.25), 0.5)  # base des palmes : plus sèche
			d.feuille(base, angle, l, 0.011, c)


## Ombelle de papyrus : une bande pleine à gauche (la couleur des tiges), puis un éventail
## de rayons très fins qui partent du bas, s'arquent et portent de petites houppes au bout.
static func _dessiner_ombelle(d: _Dessin, hasard: RandomNumberGenerator, couleur: Color) -> void:
	var tige := couleur.darkened(0.12)
	for y in d.taille:
		for x in int(d.taille * 0.05):
			d._poser(x, y, tige * (0.92 + 0.08 * float(y) / d.taille))
	var base := Vector2(0.53, 0.97)
	for i in 150:
		var angle := -PI * 0.5 + hasard.randf_range(-1.38, 1.38)
		var l := hasard.randf_range(0.55, 0.9)
		var dir := Vector2(cos(angle), sin(angle))
		# Le rayon s'arque : il retombe un peu vers le bout (vers le bas de l'image).
		var milieu := base + dir * l * 0.55
		var bout := base + dir * l + Vector2(0, l * 0.12 * absf(dir.x))
		bout.x = clampf(bout.x, 0.07, 0.99)
		var c := couleur * hasard.randf_range(0.85, 1.25)
		d.segment(base, milieu, 0.0028, c)
		d.segment(milieu, bout, 0.0024, c)
		# Houppe au bout : quelques brins courts, plus clairs (les fleurs).
		for b in 4:
			var ab := angle + hasard.randf_range(-0.7, 0.7)
			var fin := bout + Vector2(cos(ab), sin(ab)) * hasard.randf_range(0.02, 0.045)
			fin.x = clampf(fin.x, 0.07, 0.99)
			d.segment(bout, fin, 0.0022, c.lerp(Color(0.62, 0.6, 0.32), 0.35))
