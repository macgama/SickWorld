extends Node3D
## Un point de récolte : une touffe de lichen, un filon de pyrite, un banc de saumons…
## Il se construit tout seul en code (maquette en formes simples, comme l'équipement).
## On s'en approche et on appuie sur F : c'est le serveur qui décide (voir recolte.gd).
##
## Formes : "touffe", "fleurs", "ecorce", "champignon", "roseaux", "lin", "buisson",
## "filon" (pierre veinée), "cristaux" (pierre hérissée de cristaux), "banc" (poissons dans l'eau).

const Metiers := preload("res://scripts/objets/metiers.gd")

## Type de source (clé de « sources » dans data/recolte.json).
var source := ""
## Numéro du point dans la zone (sert aux échanges avec le serveur).
var numero := -1
## Le nœud Recolte qui gère les demandes.
var recolte: Node

var _visuel: Node3D
var _etiquette: Label3D
var _scintillement: MeshInstance3D
var _bouchon: Node3D
var _ronds: Array[MeshInstance3D] = []
var _poissons: Array[Node3D] = []
var _temps := 0.0
## Heure (Regles.maintenant) à laquelle la source repousse ; 0 = disponible.
var _repousse := 0.0
var _peche_fin := 0.0
var _hasard := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("points_recolte")
	_hasard.seed = hash(source + str(numero))
	_construire()


func fiche() -> Dictionary:
	return Metiers.source(Donnees.recolte, source)


func disponible() -> bool:
	return _repousse <= 0.0 or Regles.maintenant() >= _repousse


func est_peche() -> bool:
	return String(fiche().get("metier", "")) == "peche"


# --- Construction ------------------------------------------------------------------

func _construire() -> void:
	var f := fiche()
	var v: Dictionary = f.get("visuel", {})
	var couleur := Color.from_string(String(v.get("couleur", "#7a8a5a")), Color.OLIVE)
	var accent := Color.from_string(String(v.get("accent", "#e8e0c0")), Color.WHITE)
	_visuel = Node3D.new()
	_visuel.name = "Visuel"
	add_child(_visuel)
	var forme := String(v.get("forme", "touffe"))
	if has_method("_forme_" + forme):
		call("_forme_" + forme, couleur, accent)
	else:
		_forme_touffe(couleur, accent)
	_visuel.rotation.y = _hasard.randf() * TAU

	# Une petite étincelle qui aide à repérer la source de loin (comme dans les MMORPG).
	_scintillement = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	_scintillement.mesh = quad
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _texture_etoile()
	m.albedo_color = Color(1.0, 0.93, 0.7, 0.9) if not est_peche() else Color(0.75, 0.95, 1.0, 0.9)
	m.no_depth_test = false
	_scintillement.material_override = m
	_scintillement.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scintillement.position = Vector3(0, float(v.get("hauteur_etincelle", 1.0)), 0)
	add_child(_scintillement)

	_etiquette = Label3D.new()
	_etiquette.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_etiquette.font_size = 34
	_etiquette.pixel_size = 0.005
	_etiquette.outline_size = 10
	_etiquette.no_depth_test = true
	_etiquette.position = Vector3(0, float(v.get("hauteur_etincelle", 1.0)) + 0.45, 0)
	_etiquette.visible = false
	add_child(_etiquette)


func _mat(couleur: Color, rugosite := 0.9, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = rugosite
	m.metallic = metal
	return m


func _piece(maillage: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, echelle := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = maillage
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = echelle
	_visuel.add_child(mi)
	return mi


func _sphere(rayon: float, segments := 10) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = rayon
	s.height = rayon * 2.0
	s.radial_segments = segments
	s.rings = maxi(4, segments / 2)
	return s


func _cylindre(haut: float, bas: float, hauteur: float, segments := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = haut
	c.bottom_radius = bas
	c.height = hauteur
	c.radial_segments = segments
	c.rings = 1
	return c


## Une pierre irrégulière (plusieurs boules aplaties qui se chevauchent).
func _pierre(couleur: Color, taille: float) -> void:
	var m := _mat(couleur, 0.95)
	for k in 4:
		var a := _hasard.randf() * TAU
		var r := taille * _hasard.randf_range(0.45, 0.7)
		_piece(_sphere(r, 9), m, Vector3(cos(a), 0.0, sin(a)) * taille * 0.35 + Vector3(0, r * 0.45, 0),
				Vector3(_hasard.randf(), _hasard.randf() * TAU, _hasard.randf()),
				Vector3(_hasard.randf_range(0.9, 1.4), _hasard.randf_range(0.55, 0.85), _hasard.randf_range(0.9, 1.3)))


## Lichen des rennes : des coussins pâles et ramifiés posés sur une pierre plate.
func _forme_touffe(couleur: Color, accent: Color) -> void:
	_pierre(Color(0.42, 0.42, 0.4), 0.5)
	var m := _mat(couleur, 1.0)
	var m2 := _mat(accent, 1.0)
	for k in 14:
		var a := _hasard.randf() * TAU
		var d := _hasard.randf_range(0.1, 0.75)
		var r := _hasard.randf_range(0.07, 0.16)
		_piece(_sphere(r, 7), m if k % 3 else m2, Vector3(cos(a) * d, r * 0.6 + (0.18 if d < 0.4 else 0.03), sin(a) * d),
				Vector3.ZERO, Vector3(1.2, 0.75, 1.2))


## Achillée : des tiges fines coiffées d'ombelles de petites fleurs blanches.
func _forme_fleurs(couleur: Color, accent: Color) -> void:
	var tige := _mat(couleur, 0.9)
	var fleur := _mat(accent, 0.8)
	for k in 9:
		var a := _hasard.randf() * TAU
		var d := _hasard.randf_range(0.0, 0.4)
		var h := _hasard.randf_range(0.35, 0.7)
		var base := Vector3(cos(a) * d, 0, sin(a) * d)
		var penche := Vector3(_hasard.randf_range(-0.15, 0.15), 0, _hasard.randf_range(-0.15, 0.15))
		_piece(_cylindre(0.008, 0.012, h, 5), tige, base + Vector3(0, h / 2.0, 0), penche)
		var tete := base + Vector3(sin(penche.z) * -h, h, sin(penche.x) * h)
		_piece(_cylindre(0.07, 0.04, 0.03, 9), fleur, tete)
		# Feuilles plumeuses au pied.
		_piece(_sphere(0.06, 6), tige, base + Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(1.6, 0.4, 0.7))


## Bouleau abattu : un tronc blanc strié de noir, l'écorce qui se décolle en rouleaux.
func _forme_ecorce(couleur: Color, accent: Color) -> void:
	var blanc := _mat(couleur, 0.75)
	var noir := _mat(Color(0.1, 0.09, 0.08), 0.9)
	var tronc := _piece(_cylindre(0.2, 0.24, 2.2, 12), blanc, Vector3(0, 0.22, 0), Vector3(0, 0, PI / 2))
	for k in 9:
		var x := _hasard.randf_range(-0.95, 0.95)
		var a := _hasard.randf() * TAU
		_piece(BoxMesh.new(), noir, Vector3(x, 0.22 + sin(a) * 0.215, cos(a) * 0.215), Vector3(a, 0, 0),
				Vector3(0.02, 0.025, _hasard.randf_range(0.08, 0.2)))
	var rouleau := _mat(accent, 0.8)
	rouleau.cull_mode = BaseMaterial3D.CULL_DISABLED
	for k in 3:
		_piece(_cylindre(0.05, 0.05, 0.22, 8), rouleau, Vector3(_hasard.randf_range(-0.7, 0.7), 0.46, _hasard.randf_range(-0.08, 0.08)),
				Vector3(0, _hasard.randf() * PI, PI / 2))
	tronc.name = "Tronc"


## Amadouvier : des champignons en sabot de cheval sur une souche de bouleau.
func _forme_champignon(couleur: Color, accent: Color) -> void:
	var blanc := _mat(Color(0.86, 0.84, 0.78), 0.8)
	var noir := _mat(Color(0.12, 0.1, 0.08), 0.9)
	_piece(_cylindre(0.26, 0.32, 0.9, 12), blanc, Vector3(0, 0.45, 0))
	_piece(_cylindre(0.2, 0.26, 0.04, 12), _mat(Color(0.55, 0.45, 0.3), 1.0), Vector3(0, 0.91, 0))
	for k in 5:
		var a := _hasard.randf() * TAU
		_piece(BoxMesh.new(), noir, Vector3(cos(a) * 0.28, _hasard.randf_range(0.15, 0.8), sin(a) * 0.28), Vector3(0, -a, 0),
				Vector3(0.03, 0.02, 0.12))
	var chapeau := _mat(couleur, 0.95)
	var bord := _mat(accent, 0.95)
	for k in 3:
		var a := k * 2.1 + _hasard.randf_range(-0.3, 0.3)
		var y := 0.3 + k * 0.2
		var mi := _piece(_sphere(0.16, 10), chapeau, Vector3(cos(a) * 0.3, y, sin(a) * 0.3), Vector3(0, -a, 0), Vector3(0.7, 0.45, 1.0))
		mi.name = "Sabot%d" % k
		_piece(_cylindre(0.13, 0.15, 0.025, 10), bord, Vector3(cos(a) * 0.32, y - 0.06, sin(a) * 0.32), Vector3(0, -a, 0), Vector3(0.7, 1, 1.0))


## Lotus bleu : de larges feuilles rondes posées sur l'eau, et des fleurs bleues dressées.
func _forme_lotus(couleur: Color, accent: Color) -> void:
	var feuille := _mat(couleur, 0.6)
	for k in 6:
		var a := _hasard.randf() * TAU
		var d := _hasard.randf_range(0.2, 0.9)
		var r := _hasard.randf_range(0.18, 0.3)
		var mi := _piece(_cylindre(r, r, 0.01, 14), feuille, Vector3(cos(a) * d, 0.02, sin(a) * d))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var petale := _mat(accent, 0.6)
	var coeur := _mat(Color(0.98, 0.85, 0.35), 0.6)
	for k in 3:
		var a := _hasard.randf() * TAU
		var base := Vector3(cos(a), 0, sin(a)) * _hasard.randf_range(0.1, 0.6)
		var h := _hasard.randf_range(0.15, 0.35)
		_piece(_cylindre(0.008, 0.01, h, 5), _mat(Color(0.3, 0.45, 0.25)), base + Vector3(0, h / 2.0, 0))
		for i in 7:
			var b := i * TAU / 7.0
			_piece(_sphere(0.045, 6), petale, base + Vector3(cos(b) * 0.04, h + 0.03, sin(b) * 0.04),
					Vector3(0.0, -b, 0.5), Vector3(0.45, 0.3, 1.3))
		_piece(_sphere(0.025, 6), coeur, base + Vector3(0, h + 0.03, 0))


## Papyrus : une touffe de hautes tiges vertes coiffées de plumets.
func _forme_roseaux(couleur: Color, accent: Color) -> void:
	var tige := _mat(couleur, 0.8)
	var plumet := _mat(accent, 0.9)
	for k in 13:
		var a := _hasard.randf() * TAU
		var d := _hasard.randf_range(0.0, 0.45)
		var h := _hasard.randf_range(1.4, 2.4)
		var penche := Vector3(_hasard.randf_range(-0.12, 0.12), 0, _hasard.randf_range(-0.12, 0.12))
		var base := Vector3(cos(a) * d, 0, sin(a) * d)
		_piece(_cylindre(0.012, 0.025, h, 5), tige, base + Vector3(0, h / 2.0, 0), penche)
		var tete := base + Vector3(-sin(penche.z) * h, h * cos(penche.x), sin(penche.x) * h)
		_piece(_cylindre(0.16, 0.01, 0.2, 9), plumet, tete + Vector3(0, 0.08, 0), penche)


## Lin : des tiges fines et droites, de petites fleurs bleues au sommet.
func _forme_lin(couleur: Color, accent: Color) -> void:
	var tige := _mat(couleur, 0.9)
	var fleur := _mat(accent, 0.7)
	for k in 22:
		var a := _hasard.randf() * TAU
		var d := _hasard.randf_range(0.0, 0.55)
		var h := _hasard.randf_range(0.6, 0.95)
		var base := Vector3(cos(a) * d, 0, sin(a) * d)
		var penche := Vector3(_hasard.randf_range(-0.08, 0.08), 0, _hasard.randf_range(-0.08, 0.08))
		_piece(_cylindre(0.005, 0.008, h, 4), tige, base + Vector3(0, h / 2.0, 0), penche)
		if k % 2 == 0:
			_piece(_cylindre(0.03, 0.01, 0.015, 6), fleur, base + Vector3(-sin(penche.z) * h, h, sin(penche.x) * h))


## Acacia du désert : un petit arbre tordu, la couronne aplatie, des larmes de gomme sur le tronc.
func _forme_buisson(couleur: Color, accent: Color) -> void:
	var bois := _mat(Color(0.32, 0.24, 0.17), 0.95)
	_piece(_cylindre(0.06, 0.11, 1.5, 7), bois, Vector3(0.05, 0.75, 0), Vector3(0, 0, -0.12))
	_piece(_cylindre(0.035, 0.05, 0.9, 6), bois, Vector3(0.35, 1.35, 0.1), Vector3(0.2, 0, -0.9))
	_piece(_cylindre(0.035, 0.05, 0.8, 6), bois, Vector3(-0.2, 1.4, -0.1), Vector3(-0.2, 0, 0.8))
	var feuilles := _mat(couleur, 1.0)
	for k in 6:
		var a := _hasard.randf() * TAU
		_piece(_sphere(_hasard.randf_range(0.35, 0.55), 8), feuilles,
				Vector3(cos(a) * 0.55, 1.75 + _hasard.randf_range(-0.1, 0.1), sin(a) * 0.55), Vector3.ZERO, Vector3(1.3, 0.35, 1.3))
	var gomme := _mat(accent, 0.25)
	gomme.emission_enabled = true
	gomme.emission = accent * 0.25
	for k in 4:
		var y := _hasard.randf_range(0.3, 1.2)
		var a := _hasard.randf() * TAU
		_piece(_sphere(0.035, 6), gomme, Vector3(0.05 - y * 0.12 + cos(a) * 0.09, y, sin(a) * 0.09), Vector3.ZERO, Vector3(1, 1.5, 1))


## Filon : un gros bloc de roche traversé de veines colorées (silex, ocre, natron, malachite…).
func _forme_filon(couleur: Color, accent: Color) -> void:
	_pierre(couleur, 0.85)
	var veine := _mat(accent, 0.55, 0.15)
	for k in 9:
		var a := _hasard.randf() * TAU
		var r := _hasard.randf_range(0.35, 0.6)
		_piece(_sphere(_hasard.randf_range(0.07, 0.14), 6), veine,
				Vector3(cos(a) * r, _hasard.randf_range(0.15, 0.55), sin(a) * r),
				Vector3(_hasard.randf(), _hasard.randf(), _hasard.randf()), Vector3(1.6, 0.5, 0.9))


## Cristaux : une roche hérissée de prismes brillants (pyrite, cristal de roche, turquoise).
func _forme_cristaux(couleur: Color, accent: Color) -> void:
	_pierre(couleur, 0.7)
	var cristal := _mat(accent, 0.15, 0.35)
	cristal.emission_enabled = true
	cristal.emission = accent * 0.12
	for k in 8:
		var a := _hasard.randf() * TAU
		var h := _hasard.randf_range(0.18, 0.45)
		var r := _hasard.randf_range(0.15, 0.4)
		var penche := Vector3(cos(a), 0, sin(a)) * _hasard.randf_range(0.2, 0.6)
		_piece(_cylindre(0.0, _hasard.randf_range(0.04, 0.08), h, 6), cristal,
				Vector3(cos(a) * r, 0.35 + h * 0.4, sin(a) * r), Vector3(penche.z, 0, -penche.x))


## Banc de poissons : des ronds dans l'eau et des dos qui affleurent.
func _forme_banc(couleur: Color, accent: Color) -> void:
	var rond := StandardMaterial3D.new()
	rond.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rond.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rond.albedo_color = Color(0.9, 0.95, 1.0, 0.35)
	for k in 3:
		var t := TorusMesh.new()
		t.inner_radius = 0.9
		t.outer_radius = 1.0
		t.rings = 24
		t.ring_segments = 4
		var mi := _piece(t, rond.duplicate(), Vector3(0, 0.03, 0), Vector3.ZERO, Vector3(1, 0.05, 1))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ronds.append(mi)
	var corps := _mat(couleur, 0.4, 0.1)
	var nageoire := _mat(accent, 0.6)
	for k in 4:
		var poisson := Node3D.new()
		_visuel.add_child(poisson)
		var c := MeshInstance3D.new()
		c.mesh = _sphere(0.12, 8)
		c.material_override = corps
		c.scale = Vector3(0.45, 0.5, 2.0)
		poisson.add_child(c)
		var q := MeshInstance3D.new()
		q.mesh = BoxMesh.new()
		q.material_override = nageoire
		q.scale = Vector3(0.02, 0.12, 0.1)
		q.position = Vector3(0, 0.02, 0.26)
		poisson.add_child(q)
		poisson.set_meta("phase", _hasard.randf() * TAU)
		poisson.set_meta("rayon", _hasard.randf_range(0.5, 1.6))
		_poissons.append(poisson)
	# Le bouchon de la ligne, visible pendant la pêche.
	_bouchon = Node3D.new()
	_bouchon.visible = false
	_visuel.add_child(_bouchon)
	var rouge := MeshInstance3D.new()
	rouge.mesh = _sphere(0.07, 8)
	rouge.material_override = _mat(Color(0.85, 0.15, 0.1), 0.5)
	_bouchon.add_child(rouge)
	var blanc := MeshInstance3D.new()
	blanc.mesh = _cylindre(0.012, 0.012, 0.16, 5)
	blanc.material_override = _mat(Color(0.95, 0.95, 0.9), 0.5)
	blanc.position.y = 0.1
	_bouchon.add_child(blanc)


func _texture_etoile() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var dx := (x - 15.5) / 15.5
			var dy := (y - 15.5) / 15.5
			var r := sqrt(dx * dx + dy * dy)
			var croix := maxf(0.0, 1.0 - absf(dx) * 9.0) * maxf(0.0, 1.0 - absf(dy)) + maxf(0.0, 1.0 - absf(dy) * 9.0) * maxf(0.0, 1.0 - absf(dx))
			var a := clampf(maxf(pow(maxf(0.0, 1.0 - r), 3.0), croix * 0.8), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


# --- Chaque image ---------------------------------------------------------------

func _joueur_local() -> Node3D:
	return get_tree().get_first_node_in_group("joueur_local") as Node3D


func joueur_proche() -> bool:
	var joueur := _joueur_local()
	if joueur == null:
		return false
	var ecart := joueur.global_position - global_position
	return Vector2(ecart.x, ecart.z).length() < Metiers.portee(Donnees.recolte, source) and absf(ecart.y) < 4.0


func _etat_local() -> Dictionary:
	var joueur := _joueur_local()
	var inv := joueur.get_node_or_null("Inventaire") if joueur != null else null
	return inv.etat if inv != null else {}


func _process(delta: float) -> void:
	_temps += delta
	var dispo := disponible()
	if _repousse > 0.0 and dispo:
		_repousse = 0.0
		_visuel.visible = true
	_scintillement.visible = dispo
	if dispo:
		var s := 0.55 + 0.25 * sin(_temps * 2.3 + numero)
		_scintillement.scale = Vector3.ONE * s
	var proche := dispo and joueur_proche()
	var dialogue := get_tree().get_first_node_in_group("dialogue")
	var occupe: bool = dialogue != null and dialogue.est_ouvert()
	_etiquette.visible = proche and not occupe
	if _etiquette.visible:
		var f := fiche()
		var rec: Dictionary = Donnees.recolte
		var m := Metiers.metier(rec, String(f.get("metier", "")))
		var etat := _etat_local()
		_etiquette.text = "[F] %s : %s\n%s niv. %d" % [m.get("verbe", "Récolter"), f.get("nom", source),
				m.get("nom", ""), int(f.get("niveau", 1))]
		_etiquette.modulate = Metiers.couleur(rec, etat, source) if not etat.is_empty() else Color.WHITE
	# Les poissons tournent doucement, les ronds s'élargissent.
	for i in _ronds.size():
		var t := fmod(_temps * 0.45 + i / 3.0, 1.0)
		_ronds[i].scale = Vector3(0.3 + t * 1.5, 0.05, 0.3 + t * 1.5)
		(_ronds[i].material_override as StandardMaterial3D).albedo_color.a = 0.4 * (1.0 - t) if dispo else 0.0
	for p in _poissons:
		var phase: float = p.get_meta("phase") + _temps * 0.6
		var r: float = p.get_meta("rayon")
		p.position = Vector3(cos(phase) * r, -0.12 + 0.05 * sin(_temps * 2.0 + phase), sin(phase) * r)
		p.rotation.y = -phase
	if _bouchon != null and _bouchon.visible:
		var reste := _peche_fin - Regles.maintenant()
		# Le bouchon flotte… puis plonge quand ça mord.
		_bouchon.position = Vector3(0.3, 0.02 + 0.03 * sin(_temps * 4.0) - (0.12 if reste < 0.6 else 0.0), 0.2)
		if reste < -0.5:
			_bouchon.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interagir") or not disponible() or not joueur_proche():
		return
	var dialogue := get_tree().get_first_node_in_group("dialogue")
	if dialogue != null and dialogue.est_ouvert():
		return
	if recolte == null:
		return
	get_viewport().set_input_as_handled()
	recolte.demander(numero)


# --- Appelé par Recolte (chez le joueur) -------------------------------------------

## Le joueur commence à récolter ici : il se tourne vers la source, la ligne est lancée.
func commencer(duree: float) -> void:
	var joueur := _joueur_local()
	if joueur != null:
		var d := global_position - joueur.global_position
		if Vector2(d.x, d.z).length() > 0.2:
			joueur.rotation.y = atan2(-d.x, -d.z)
	if _bouchon != null:
		_peche_fin = Regles.maintenant() + duree
		_bouchon.visible = true


func arreter() -> void:
	if _bouchon != null:
		_bouchon.visible = false


## La source est épuisée pour ce joueur : elle disparaît et repousse dans « duree » secondes.
func epuiser(duree: float) -> void:
	_repousse = Regles.maintenant() + duree
	_visuel.visible = false
	_etiquette.visible = false
	if _bouchon != null:
		_bouchon.visible = false
