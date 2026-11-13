extends RefCounted
## Immeubles réalistes de Hikari Bay et gratte-ciel de l'horizon.
##
## Chaque immeuble n'est plus un simple bloc : soubassement et tour en retrait
## pour les plus hauts, corniche, toit équipé (climatiseurs, château d'eau,
## local technique, antenne avec feu rouge clignotant), façade calculée par le
## shader facade_nuit (bureaux vitrés, béton ancien ou logements).
##
## Utilisation depuis le hub (ou un nouveau quartier) :
##   const Immeubles := preload("res://scripts/monde/immeubles_hikari.gd")
##   Immeubles.batiment(hub, x1, z1, x2, z2, hauteur, part_allumee, graine)

const SHADER_FACADE := preload("res://shaders/facade_nuit.gdshader")
const SHADER_BALISE := preload("res://shaders/balise_aviation.gdshader")
const POLICE := preload("res://assets/polices/NotoSansJP-Bold-hub.ttf")
const TEXTURES_FACADES := ["concrete_tile_facade", "rectangular_facade_tiles", "concrete_wall_008",
		"brushed_concrete", "white_rough_plaster"]

enum Style { BETON, VERRE, LOGEMENTS }


## Matériau de façade partagé (un par style et par texture de mur).
static func materiau_facade(hub: Node3D, style: int, texture: int) -> ShaderMaterial:
	var cle := "facade2_%d_%d" % [style, texture]
	if hub._materiaux.has(cle):
		return hub._materiaux[cle]
	var m := ShaderMaterial.new()
	m.shader = SHADER_FACADE
	m.set_shader_parameter("style", style)
	var id: String = TEXTURES_FACADES[texture % TEXTURES_FACADES.size()]
	var couleur: Texture2D = hub._texture(id, "Diffuse")
	if couleur != null:
		m.set_shader_parameter("avec_texture", true)
		m.set_shader_parameter("texture_mur", couleur)
		m.set_shader_parameter("relief_mur", hub._texture(id, "nor_gl"))
		var teintes := [Color(0.16, 0.16, 0.17), Color(0.22, 0.2, 0.19), Color(0.2, 0.21, 0.23), Color(0.24, 0.22, 0.21)]
		m.set_shader_parameter("couleur_mur", teintes[texture % teintes.size()])
	hub._materiaux[cle] = m
	return m


static func _mat_simple(hub: Node3D, cle: String, couleur: Color, rugosite := 0.6, metal := 0.0) -> StandardMaterial3D:
	if hub._materiaux.has(cle):
		return hub._materiaux[cle]
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = rugosite
	m.metallic = metal
	hub._materiaux[cle] = m
	return m


static func _mat_balise(hub: Node3D) -> ShaderMaterial:
	if hub._materiaux.has("balise"):
		return hub._materiaux["balise"]
	var m := ShaderMaterial.new()
	m.shader = SHADER_BALISE
	hub._materiaux["balise"] = m
	return m


## Un volume de façade (boîte) avec ses paramètres d'instance pour le shader.
static func _volume(hub: Node3D, x1: float, z1: float, x2: float, z2: float, y1: float, y2: float,
		style: int, texture: int, part: float, graine: float, collision: bool, parent: Node3D) -> MeshInstance3D:
	var mi: MeshInstance3D = hub._boite(Vector3(x2 - x1, y2 - y1, z2 - z1),
			Vector3((x1 + x2) * 0.5, (y1 + y2) * 0.5, (z1 + z2) * 0.5),
			materiau_facade(hub, style, texture), collision, parent)
	mi.set_instance_shader_parameter("bornes", Vector4(x1, z1, x2, z2))
	mi.set_instance_shader_parameter("hauteur_toit", y2)
	mi.set_instance_shader_parameter("graine", graine)
	mi.set_instance_shader_parameter("allumage", part)
	mi.set_instance_shader_parameter("style_instance", style)
	return mi


## Corniche (léger débord) au sommet d'un volume.
static func _corniche(hub: Node3D, x1: float, z1: float, x2: float, z2: float, y: float, parent: Node3D) -> void:
	var beton := _mat_simple(hub, "corniche", Color(0.13, 0.13, 0.14), 0.5)
	hub._boite(Vector3(x2 - x1 + 0.6, 0.45, z2 - z1 + 0.6), Vector3((x1 + x2) * 0.5, y - 0.2, (z1 + z2) * 0.5), beton, false, parent)
	# Muret (acrotère) autour du toit.
	var e := 0.3
	for c in [[x1, z1, x2, z1 + e], [x1, z2 - e, x2, z2], [x1, z1, x1 + e, z2], [x2 - e, z1, x2, z2]]:
		hub._boite(Vector3(c[2] - c[0], 1.0, c[3] - c[1]), Vector3((c[0] + c[2]) * 0.5, y + 0.5, (c[1] + c[3]) * 0.5), beton, false, parent)


## Équipements du toit : local technique, climatiseurs, château d'eau, antenne.
static func _toit(hub: Node3D, x1: float, z1: float, x2: float, z2: float, y: float, hasard: RandomNumberGenerator,
		detaille: bool, parent: Node3D) -> void:
	var cx := (x1 + x2) * 0.5
	var cz := (z1 + z2) * 0.5
	var lx := x2 - x1
	var lz := z2 - z1
	var gris := _mat_simple(hub, "toit_gris", Color(0.16, 0.16, 0.17), 0.7)
	var metal := _mat_simple(hub, "toit_metal", Color(0.3, 0.31, 0.33), 0.4, 0.8)
	if detaille:
		# Local technique (cage d'ascenseur).
		var lt := Vector3(minf(6.0, lx * 0.3), 3.2, minf(5.0, lz * 0.3))
		hub._boite(lt, Vector3(cx + hasard.randf_range(-0.2, 0.2) * lx, y + lt.y * 0.5, cz + hasard.randf_range(-0.2, 0.2) * lz), gris, false, parent)
		# Climatiseurs alignés.
		for i in hasard.randi_range(2, 6):
			var p := Vector3(x1 + 2.0 + hasard.randf() * (lx - 4.0), y, z1 + 2.0 + hasard.randf() * (lz - 4.0))
			if hub._modele("exterior_aircon_unit", p, hasard.randf_range(0, 4) * PI / 2, 1.6, parent, ["rusted"]) == null:
				hub._boite(Vector3(1.4, 1.1, 0.8), p + Vector3(0, 0.55, 0), metal, false, parent)
		# Château d'eau sur pieds (très courant sur les toits de Tokyo).
		if hasard.randf() < 0.6:
			var p := Vector3(x1 + 3.0 + hasard.randf() * (lx - 6.0), y, z1 + 3.0 + hasard.randf() * (lz - 6.0))
			for d in [Vector2(-0.9, -0.9), Vector2(0.9, -0.9), Vector2(-0.9, 0.9), Vector2(0.9, 0.9)]:
				hub._boite(Vector3(0.15, 2.0, 0.15), p + Vector3(d.x, 1.0, d.y), metal, false, parent)
			var cuve := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 1.5
			cyl.bottom_radius = 1.5
			cyl.height = 2.4
			cuve.mesh = cyl
			cuve.material_override = _mat_simple(hub, "cuve", Color(0.42, 0.44, 0.46), 0.45, 0.6)
			cuve.position = p + Vector3(0, 3.2, 0)
			parent.add_child(cuve)
	# Antenne et feu d'obstacle rouge (clignote, visible de loin).
	if y > 35.0:
		var h := hasard.randf_range(4.0, 12.0) * (1.0 if y < 120.0 else 2.2)
		var p := Vector3(cx + hasard.randf_range(-0.25, 0.25) * lx, y, cz + hasard.randf_range(-0.25, 0.25) * lz)
		hub._boite(Vector3(0.3, h, 0.3), p + Vector3(0, h * 0.5, 0), metal, false, parent)
		_balise(hub, p + Vector3(0, h, 0), parent, hasard.randf())
		# Feux aux coins des plus grands toits.
		if y > 70.0:
			for c in [Vector3(x1 + 0.5, y + 1.2, z1 + 0.5), Vector3(x2 - 0.5, y + 1.2, z2 - 0.5)]:
				_balise(hub, c, parent, hasard.randf())


static func _balise(hub: Node3D, p: Vector3, parent: Node3D, decalage: float) -> void:
	var b := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.45
	s.height = 0.9
	s.radial_segments = 8
	s.rings = 4
	b.mesh = s
	b.material_override = _mat_balise(hub)
	b.set_instance_shader_parameter("decalage", decalage * 0.3)
	b.position = p
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(b)


## Un immeuble complet entre (x1, z1) et (x2, z2).
## part = part des fenêtres allumées. retrait = les grandes tours ont un
## soubassement puis une tour plus étroite (désactiver si des enseignes sont
## accrochées haut sur la façade).
static func batiment(hub: Node3D, x1: float, z1: float, x2: float, z2: float, hauteur_b: float, part: float,
		graine: int, collision := true, style := -1, retrait := true, parent: Node3D = null) -> Node3D:
	var racine := Node3D.new()
	racine.name = "Immeuble_%d" % graine
	(parent if parent != null else hub._contenu).add_child(racine)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine * 7919 + 13
	if style < 0:
		if hauteur_b >= 60.0:
			style = Style.VERRE if hasard.randf() < 0.75 else Style.BETON
		else:
			style = [Style.BETON, Style.LOGEMENTS, Style.BETON, Style.VERRE][hasard.randi() % 4]
	var texture := hasard.randi() % TEXTURES_FACADES.size()
	var lx := x2 - x1
	var lz := z2 - z1
	var detaille := collision # les immeubles proches ont des toits détaillés
	if retrait and hauteur_b >= 50.0 and minf(lx, lz) > 16.0:
		# Soubassement (avec collision) puis tour en retrait.
		var h1 := maxf(18.0, roundf(hauteur_b * hasard.randf_range(0.25, 0.4)))
		_volume(hub, x1, z1, x2, z2, 0.0, h1, style if style != Style.VERRE else Style.BETON, texture, part, graine, collision, racine)
		_corniche(hub, x1, z1, x2, z2, h1, racine)
		var r := minf(minf(lx, lz) * 0.15, 4.0)
		_volume(hub, x1 + r, z1 + r, x2 - r, z2 - r, h1, hauteur_b, style, texture, part, graine + 0.5, false, racine)
		x1 += r
		z1 += r
		x2 -= r
		z2 -= r
		# Couronne éclairée au sommet des plus hautes tours.
		if hauteur_b >= 80.0 and hasard.randf() < 0.7:
			var r2 := minf(x2 - x1, z2 - z1) * 0.18
			var hc := hasard.randf_range(6.0, 14.0)
			_volume(hub, x1 + r2, z1 + r2, x2 - r2, z2 - r2, hauteur_b, hauteur_b + hc, style, texture, 0.0, graine + 0.7, false, racine)
			var couleurs := [Color(0.5, 0.8, 1.0), Color(1.0, 0.85, 0.6), Color(1.0, 0.4, 0.75), Color(0.6, 1.0, 0.9)]
			var c: Color = couleurs[hasard.randi() % couleurs.size()]
			hub._boite(Vector3(x2 - x1 - 2 * r2 + 0.3, 0.35, z2 - z1 - 2 * r2 + 0.3),
					Vector3((x1 + x2) * 0.5, hauteur_b + hc - 0.5, (z1 + z2) * 0.5), hub._neon(c, 4.0), false, racine)
			hub._boite(Vector3(x2 - x1 + 0.2, 0.25, z2 - z1 + 0.2),
					Vector3((x1 + x2) * 0.5, hauteur_b - 0.4, (z1 + z2) * 0.5), hub._neon(c, 2.5), false, racine)
			x1 += r2
			z1 += r2
			x2 -= r2
			z2 -= r2
			hauteur_b += hc
		else:
			_corniche(hub, x1, z1, x2, z2, hauteur_b, racine)
	else:
		_volume(hub, x1, z1, x2, z2, 0.0, hauteur_b, style, texture, part, graine, collision, racine)
		_corniche(hub, x1, z1, x2, z2, hauteur_b, racine)
	_toit(hub, x1, z1, x2, z2, hauteur_b, hasard, detaille, racine)
	return racine


## La ville au loin : une couronne de gratte-ciel (sans collision), surtout au
## nord, et quelques tours géantes qui dessinent la silhouette de Hikari Bay.
## rayon_min laisse la place aux futurs quartiers du hub.
static func horizon(hub: Node3D, rayon_min := 190.0, rayon_max := 520.0, nombre := 110) -> void:
	var parent := Node3D.new()
	parent.name = "Horizon"
	hub._contenu.add_child(parent)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 2026
	for i in nombre:
		var angle := hasard.randf_range(-PI * 1.08, PI * 0.08) # pas sur la mer (au sud)
		var distance := hasard.randf_range(rayon_min, rayon_max)
		var p := Vector2(cos(angle), sin(angle)) * distance
		var lx := hasard.randf_range(18.0, 40.0)
		var lz := hasard.randf_range(18.0, 40.0)
		# Plus on s'éloigne, plus les tours peuvent être hautes (quartier d'affaires).
		var h := hasard.randf_range(40.0, 120.0) + hasard.randf() * distance * 0.25
		batiment(hub, p.x - lx * 0.5, p.y - lz * 0.5, p.x + lx * 0.5, p.y + lz * 0.5, h,
				hasard.randf_range(0.2, 0.45), 100 + i, false, -1, true, parent)
	# Sur l'autre rive de la baie, au sud : les lumières d'une autre partie de la ville.
	for i in 45:
		var x := hasard.randf_range(-1100.0, 1100.0)
		var z := hasard.randf_range(820.0, 1050.0)
		var l := hasard.randf_range(20.0, 45.0)
		var h := hasard.randf_range(25.0, 140.0)
		batiment(hub, x - l * 0.5, z - l * 0.5, x + l * 0.5, z + l * 0.5, h, hasard.randf_range(0.3, 0.5),
				200 + i, false, -1, false, parent)
	# Tours géantes (repères visibles depuis toute la ville).
	var geantes := [[Vector2(-150, -330), 300.0], [Vector2(120, -380), 360.0], [Vector2(-330, -160), 240.0], [Vector2(300, -240), 270.0]]
	var n := 0
	for g in geantes:
		var p: Vector2 = g[0]
		var h: float = g[1]
		var l := 44.0
		batiment(hub, p.x - l * 0.5, p.y - l * 0.5, p.x + l * 0.5, p.y + l * 0.5, h, 0.45, 300 + n, false, Style.VERRE, true, parent)
		# Flèche au sommet.
		var metal := _mat_simple(hub, "toit_metal", Color(0.3, 0.31, 0.33), 0.4, 0.8)
		var fleche := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.2
		cone.bottom_radius = 1.6
		cone.height = h * 0.15
		fleche.mesh = cone
		fleche.material_override = metal
		fleche.position = Vector3(p.x, h + 14.0 + h * 0.075, p.y)
		parent.add_child(fleche)
		_balise(hub, Vector3(p.x, h + 14.0 + h * 0.15, p.y), parent, 0.0)
		n += 1


## Enseignes verticales accrochées perpendiculairement aux façades (comme dans
## les rues de Tokyo) : lisibles des deux côtés en remontant la rue.
## [position du pied de l'enseigne (sur la façade), direction vers la rue, texte, couleur]
const ENSEIGNES_VERTICALES := [
	[Vector3(-29.0, 5.5, -34.0), Vector3(0, 0, 1), "スナック", Color(1.0, 0.3, 0.75)],
	[Vector3(29.0, 5.5, -34.0), Vector3(0, 0, 1), "カフェ", Color(1.0, 0.65, 0.25)],
	[Vector3(-34.0, 5.0, -8.0), Vector3(1, 0, 0), "マッサージ", Color(0.4, 1.0, 0.6)],
	[Vector3(34.0, 5.0, -31.0), Vector3(-1, 0, 0), "ゲーム", Color(0.35, 0.75, 1.0)],
	[Vector3(-8.0, 5.0, 34.0), Vector3(0, 0, -1), "ラーメン", Color(1.0, 0.35, 0.25)],
	[Vector3(9.0, 5.0, 34.0), Vector3(0, 0, -1), "駐車場", Color(0.4, 0.6, 1.0)],
	[Vector3(-6.0, 5.0, 42.0), Vector3(1, 0, 0), "カラオケ", Color(0.95, 0.35, 1.0)],
	[Vector3(6.0, 5.0, 46.0), Vector3(-1, 0, 0), "寿司", Color(1.0, 0.85, 0.4)],
	[Vector3(-6.0, 5.0, 55.0), Vector3(1, 0, 0), "喫茶", Color(0.4, 1.0, 0.95)],
	[Vector3(6.0, 5.0, 58.0), Vector3(-1, 0, 0), "バー", Color(1.0, 0.3, 0.5)],
]


static func enseignes_verticales(hub: Node3D, liste: Array = ENSEIGNES_VERTICALES) -> void:
	var fond := _mat_simple(hub, "fond_enseigne", Color(0.02, 0.02, 0.025), 0.3, 0.2)
	for e in liste:
		var pied: Vector3 = e[0]
		var dir: Vector3 = e[1]
		var texte: String = e[2]
		var couleur: Color = e[3]
		var n := texte.length()
		var hauteur_e := n * 1.05 + 0.7
		var centre := pied + dir * 1.0 + Vector3(0, hauteur_e * 0.5, 0)
		var pivot := Node3D.new()
		pivot.position = centre
		# Le panneau est dans le plan (direction vers la rue, vertical).
		pivot.rotation.y = atan2(dir.x, dir.z)
		hub._contenu.add_child(pivot)
		hub._boite(Vector3(0.18, hauteur_e, 1.3), Vector3.ZERO, fond, false, pivot)
		# Liseré lumineux.
		for s in [-1.0, 1.0]:
			hub._boite(Vector3(0.2, hauteur_e, 0.06), Vector3(0, 0, s * 0.65), hub._neon(couleur, 3.0), false, pivot)
			hub._boite(Vector3(0.2, 0.06, 1.3), Vector3(0, s * hauteur_e * 0.5, 0), hub._neon(couleur, 3.0), false, pivot)
		# Support accroché au mur.
		for s in [-0.4, 0.4]:
			hub._boite(Vector3(0.08, 0.08, 0.5), Vector3(0, hauteur_e * s, -0.85), fond, false, pivot)
		var lettres := PackedStringArray()
		for i in n:
			lettres.append(texte[i])
		var vertical := "\n".join(lettres)
		for s in [-1.0, 1.0]:
			var l := Label3D.new()
			l.text = vertical
			l.font = POLICE
			l.font_size = 100
			l.pixel_size = 0.01
			l.line_spacing = -18.0
			l.modulate = Color(couleur.r * 3.5, couleur.g * 3.5, couleur.b * 3.5)
			l.shaded = false
			l.double_sided = false
			l.position = Vector3(s * 0.1, 0, 0)
			l.rotation.y = s * PI / 2
			pivot.add_child(l)
		var lumiere: OmniLight3D = hub._lumiere(centre + dir * 0.5, couleur, 1.6, 9.0)
		lumiere.add_to_group("lumiere_secondaire")
