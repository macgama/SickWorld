extends RefCounted
## Habits d'époque (chiton, péplos, pagne de lin, robe de peau…) portés par les
## figurants et les PNJ des îles, à la place de la tenue moderne du personnage de base.
##
## Chaque habit est un maillage déjà attaché au squelette Mixamo (corps complet + tissus),
## fabriqué hors du jeu par tools/personnages/habits_epoque.py puis habits_vers_godot.gd :
##   res://assets/personnages/vetements/<homme|femme>/<habit>.res
## Le corps d'origine (incomplet sous la tenue), la tenue moderne et les chaussures sont
## cachés ; la tête, les yeux, les cils et les cheveux restent ceux du personnage.
## Guide : docs/guides/habits-d-epoque.md

const DOSSIER := "res://assets/personnages/vetements/"
const NOM_NOEUD := "HabitEpoque"
## Matières : texture (tons clairs, teintée par la couleur), relief, taille d'un motif en mètres.
const MATIERES := {
	"lin": {"albedo": "textures/lin_albedo.webp", "normale": "textures/lin_normal.webp", "motif": 0.12,
			"rugosite": 0.92, "relief": 0.3},
	"laine": {"albedo": "textures/laine_albedo.webp", "normale": "textures/laine_normal.webp", "motif": 0.16,
			"rugosite": 0.97, "relief": 0.45},
	"fourrure": {"albedo": "textures/fourrure_albedo.webp", "normale": "textures/fourrure_normal.webp",
			"motif": 0.22, "rugosite": 1.0, "relief": 1.0},
	"cuir": {"albedo": "res://assets/prehistoire/textures/brown_leather/brown_leather_Diffuse.jpg",
			"normale": "res://assets/prehistoire/textures/brown_leather/brown_leather_nor_gl.jpg", "motif": 0.5,
			"rugosite": 0.8, "relief": 0.8, "deja_colore": true},
	"corde": {"albedo": "textures/laine_albedo.webp", "normale": "textures/laine_normal.webp", "motif": 0.05,
			"rugosite": 1.0, "relief": 1.0},
}
## Couleurs par défaut de chaque rôle (si la fiche ne les donne pas).
const COULEURS := {"principal": Color("#e6dcc6"), "drape": Color("#7a6a52"), "ceinture": Color("#6a4a30"),
		"fourrure": Color("#8a6a4a"), "chaussures": Color("#6a4a32")}

static var _maillages := {}
static var _textures := {}


## Existe-t-il cet habit pour ce sexe ?
static func existe(sexe: String, habit: String) -> bool:
	return habit != "" and ResourceLoader.exists("%s%s/%s.res" % [DOSSIER, sexe, habit])


## Habille le squelette avec l'habit. couleurs : {rôle: Color} (principal, drape, ceinture,
## fourrure, chaussures). materiau_peau : la matière de peau du personnage (teinte, barbe).
## Rend le nœud créé (null si l'habit n'existe pas pour ce sexe).
static func habiller(squelette: Skeleton3D, sexe: String, habit: String, couleurs: Dictionary,
		materiau_peau: Material) -> MeshInstance3D:
	retirer(squelette)
	if squelette == null or not existe(sexe, habit):
		return null
	var mesh := _maillage(sexe, habit)
	if mesh == null:
		return null
	# On cache le corps d'origine (troué sous la tenue), la tenue moderne et les chaussures.
	for n in squelette.get_children():
		if n is MeshInstance3D and _a_cacher(String(n.name)):
			if materiau_peau == null and (String(n.name).contains("1591") or String(n.name).contains("1605")):
				materiau_peau = (n as MeshInstance3D).material_override
			(n as MeshInstance3D).visible = false
	var mi := MeshInstance3D.new()
	mi.name = NOM_NOEUD
	mi.mesh = mesh
	var skin := Skin.new()
	var os: PackedStringArray = mesh.get_meta("os", PackedStringArray())
	for nom in os:
		var i := squelette.find_bone(nom)
		# Les sommets sont dans le repère du squelette, à la pose de repos.
		skin.add_named_bind(nom, squelette.get_bone_global_rest(i).affine_inverse() if i >= 0 else Transform3D.IDENTITY)
	mi.skin = skin
	squelette.add_child(mi)
	mi.skeleton = mi.get_path_to(squelette)
	for s in mesh.get_surface_count():
		var nom_surface := String(mesh.surface_get_name(s))
		var matiere := nom_surface.get_slice(":", 0)
		var role := nom_surface.get_slice(":", 1)
		if matiere == "peau":
			mi.set_surface_override_material(s, materiau_peau)
		else:
			var c: Color = couleurs.get(role, COULEURS.get(role, Color.WHITE))
			mi.set_surface_override_material(s, materiau(matiere, c))
	return mi


## Enlève l'habit et rend la tenue d'origine.
static func retirer(squelette: Skeleton3D) -> void:
	if squelette == null:
		return
	var ancien := squelette.get_node_or_null(NOM_NOEUD)
	if ancien == null:
		return
	ancien.queue_free()
	ancien.name = NOM_NOEUD + "_ancien"
	for n in squelette.get_children():
		if n is MeshInstance3D and _a_cacher(String(n.name)):
			(n as MeshInstance3D).visible = true


static func _a_cacher(nom: String) -> bool:
	return nom.contains("1591") or nom.contains("1605") or nom.contains("suit") or nom.contains("shoes")


static func _maillage(sexe: String, habit: String) -> ArrayMesh:
	var cle := sexe + "/" + habit
	if not _maillages.has(cle):
		_maillages[cle] = load("%s%s/%s.res" % [DOSSIER, sexe, habit])
	return _maillages[cle]


## Matière de tissu teintée (partagée entre tous les figurants de même couleur).
static func materiau(matiere: String, couleur: Color) -> StandardMaterial3D:
	var cle := "%s/%s" % [matiere, couleur.to_html(false)]
	if _textures.has(cle):
		return _textures[cle]
	var def: Dictionary = MATIERES.get(matiere, MATIERES["lin"])
	var m := StandardMaterial3D.new()
	m.albedo_texture = _texture(def["albedo"])
	# Le cuir a déjà sa couleur : on la mélange seulement à la teinte demandée.
	m.albedo_color = couleur
	if def.get("deja_colore", false):
		# La texture de cuir est sombre : on l'éclaircit pour garder la teinte demandée lisible.
		var c := couleur.lerp(Color.WHITE, 0.3)
		m.albedo_color = Color(minf(c.r * 1.9, 2.0), minf(c.g * 1.9, 2.0), minf(c.b * 1.9, 2.0))
	m.normal_enabled = true
	m.normal_texture = _texture(def["normale"])
	m.normal_scale = float(def["relief"])
	m.roughness = float(def["rugosite"])
	m.metallic_specular = 0.25
	var echelle := 1.0 / float(def["motif"])
	m.uv1_scale = Vector3(echelle, echelle, 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	# Un peu de lumière qui traverse le tissu (lin fin au soleil).
	if matiere == "lin":
		m.backlight_enabled = true
		m.backlight = couleur.darkened(0.55)
	_textures[cle] = m
	return m


static func _texture(chemin: String) -> Texture2D:
	if not chemin.begins_with("res://"):
		chemin = DOSSIER + chemin
	if not _textures.has(chemin):
		_textures[chemin] = load(chemin) if ResourceLoader.exists(chemin) else null
	return _textures[chemin]


## Habille une apparence d'après une fiche de figurant ou de PNJ :
## « habit » (nom), « habits » (couleur principale), « couleurs » ({rôle: "#rrggbb"})
## et, pour les anciennes fiches grecques, « antique.drape » / « antique.ceinture ».
## Rend true si l'habit est porté (sinon on garde l'ancienne méthode de teinture).
static func depuis_fiche(apparence: Node, fiche: Dictionary) -> bool:
	var habit := String(fiche.get("habit", ""))
	var sexe := String(fiche.get("modele", "homme"))
	if not existe(sexe, habit) or not apparence.has_method("porter_habit"):
		return false
	var couleurs := {}
	if fiche.has("habits"):
		couleurs["principal"] = Color.from_string(String(fiche["habits"]), COULEURS["principal"])
	var antique: Dictionary = fiche.get("antique", {})
	for role in ["drape", "ceinture"]:
		if antique.has(role):
			couleurs[role] = Color.from_string(String(antique[role]), COULEURS[role])
	var en_plus: Dictionary = fiche.get("couleurs", {})
	for role in en_plus:
		couleurs[role] = Color.from_string(String(en_plus[role]), COULEURS.get(role, Color.WHITE))
	return apparence.porter_habit(habit, couleurs)
