extends RefCounted
## Le Marché de nuit (nord-ouest de Hikari Bay), voir docs/HUB.md, section 3.
##
## L'esprit des ruelles de Tokyo : trois ruelles étroites (4 à 6 m), des stands
## de nourriture, des lanternes rouges et des enseignes empilées.
## Deux bâtiments se visitent : le restaurant de ramen « Kaminari » et la salle
## Tsukimi (le futur hôtel des ventes).
##
## Plan (le nord est vers -Z) :
##   - Ruelle principale (Yokochō Hikari) : x de -23 à -17, de z = -70 à -133 ;
##   - Ruelle des lanternes : z de -102 à -97, de x = -52 à -23 ;
##   - Ruelle de la fumée : x de -52 à -48, de z = -128 à -97 ;
##   - Ruelle de derrière : z de -133 à -128, de x = -52 à -17.
## Les volumes des immeubles sont dans HikariBay.IMMEUBLES ; ce fichier ajoute
## les intérieurs, les boutiques, les stands, les lanternes et les personnages.

const Pnj := preload("res://scripts/monde/pnj.gd")

const ROUGE := Color(1.0, 0.25, 0.18)
const ROSE := Color(1.0, 0.3, 0.7)
const ORANGE := Color(1.0, 0.6, 0.2)
const CYAN := Color(0.3, 1.0, 0.95)
const VERT := Color(0.35, 1.0, 0.55)
const BLEU := Color(0.3, 0.65, 1.0)
const CHAUD := Color(1.0, 0.78, 0.5)

## Intérieurs : [x1, z1, x2, z2] (sol à y = 0, plafond à 4.2 m).
const RAMEN := Rect2(-31, -116, 8, 12)
const SALLE_TSUKIMI := Rect2(-48, -126, 12, 14)
const HAUTEUR_SALLE := 4.2


static func construire(hub: HikariBay) -> void:
	# Étages au-dessus des deux salles qui se visitent (le reste est dans IMMEUBLES).
	hub._bloc(RAMEN.position.x - 0.3, RAMEN.position.y - 0.3, RAMEN.end.x + 0.3, RAMEN.end.y + 0.3,
			HAUTEUR_SALLE + 0.3, 9.0, hub._facade(31, 0.45))
	hub._bloc(SALLE_TSUKIMI.position.x - 0.3, SALLE_TSUKIMI.position.y - 0.3, SALLE_TSUKIMI.end.x + 0.3,
			SALLE_TSUKIMI.end.y + 0.3, HAUTEUR_SALLE + 0.3, 10.0, hub._facade(32, 0.3))
	_construire_entree(hub)
	_construire_ramen(hub)
	_construire_tsukimi(hub)
	_construire_boutiques(hub)
	_construire_stands(hub)
	_construire_lanternes(hub)
	_construire_enseignes(hub)
	_construire_encombrement(hub)
	_construire_habitants(hub)


# --- Outils ----------------------------------------------------------------

static func _pnj(hub: HikariBay, id: String, p: Vector3, angle: float) -> Pnj:
	var pnj := Pnj.new()
	pnj.identifiant = id
	pnj.name = "Pnj_" + id
	pnj.position = p
	pnj.rotation.y = angle
	hub._contenu.add_child(pnj)
	return pnj


## Matériau émissif doux (papier des lanternes, rideaux éclairés).
static func _papier(hub: HikariBay, couleur: Color, energie := 2.0) -> StandardMaterial3D:
	var cle := "papier_%s_%s" % [couleur.to_html(), energie]
	if hub._materiaux.has(cle):
		return hub._materiaux[cle]
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.emission_enabled = true
	m.emission = couleur
	m.emission_energy_multiplier = energie
	m.roughness = 0.8
	hub._materiaux[cle] = m
	return m


static func _bois(hub: HikariBay) -> Material:
	return hub._mat_pbr("painted_metal_shutter", 1.0, "bois", Color(0.55, 0.38, 0.25))


## Une pièce fermée (murs, sol, plafond) avec des ouvertures [côté, début, fin].
static func _piece(hub: HikariBay, r: Rect2, mur: Material, sol: Material, ouvertures: Array, hauteur := HAUTEUR_SALLE, hauteur_porte := 2.6) -> void:
	var x1 := r.position.x
	var x2 := r.end.x
	var z1 := r.position.y
	var z2 := r.end.y
	var e := 0.3
	hub._bloc(x1, z1, x2, z2, 0.0, 0.04, sol, false)
	hub._bloc(x1 - e, z1 - e, x2 + e, z2 + e, hauteur, hauteur + 0.3, hub._mat("beton"))
	for cote in ["nord", "sud", "ouest", "est"]:
		var debut := x1 if cote in ["nord", "sud"] else z1
		var fin := x2 if cote in ["nord", "sud"] else z2
		var curseur := debut
		var morceaux := []
		for o in ouvertures.filter(func(o): return o[0] == cote):
			morceaux.append([curseur, o[1], 0.0])
			# Linteau au-dessus de la porte.
			morceaux.append([o[1], o[2], hauteur_porte])
			curseur = o[2]
		morceaux.append([curseur, fin, 0.0])
		for m in morceaux:
			if m[1] - m[0] < 0.01:
				continue
			match cote:
				"nord": hub._bloc(m[0], z1 - e, m[1], z1, m[2], hauteur, mur)
				"sud": hub._bloc(m[0], z2, m[1], z2 + e, m[2], hauteur, mur)
				"ouest": hub._bloc(x1 - e, m[0], x1, m[1], m[2], hauteur, mur)
				"est": hub._bloc(x2, m[0], x2 + e, m[1], m[2], hauteur, mur)


## Rideau « noren » en tissu devant une porte (bandes qui ne bloquent pas le passage).
static func _noren(hub: HikariBay, centre: Vector3, largeur: float, angle: float, couleur: Color, texte: String) -> void:
	var pivot := Node3D.new()
	pivot.position = centre
	pivot.rotation.y = angle
	hub._contenu.add_child(pivot)
	var bandes := 4
	var tissu := StandardMaterial3D.new()
	tissu.albedo_color = couleur
	tissu.roughness = 0.9
	tissu.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in bandes:
		var x := -largeur * 0.5 + (i + 0.5) * largeur / bandes
		hub._boite(Vector3(largeur / bandes - 0.06, 0.9, 0.02), Vector3(x, 2.15, 0), tissu, false, pivot)
	var l := hub._texte(texte, Vector3.ZERO, Color(1, 1, 1), 70, angle, 1.2)
	l.position = centre + Vector3(0, 2.2, 0) + Vector3(sin(angle), 0, cos(angle)) * 0.03


## Lanterne en papier (sphère étirée) ; avec une lumière si demandé.
static func _lanterne(hub: HikariBay, p: Vector3, couleur: Color, lumiere := false, taille := 0.32) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = taille
	s.height = taille * 2.6
	s.radial_segments = 12
	s.rings = 6
	mi.mesh = s
	mi.material_override = _papier(hub, couleur, 2.4)
	mi.position = p
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hub._contenu.add_child(mi)
	if lumiere:
		hub._lumiere(p + Vector3(0, -0.4, 0), couleur.lerp(CHAUD, 0.4), 1.6, 9.0)


## Enseigne verticale (caractères empilés) sur un panneau sombre.
static func _enseigne_verticale(hub: HikariBay, p: Vector3, angle: float, texte: String, couleur: Color) -> void:
	var lignes := texte.length()
	var hauteur := lignes * 0.62 + 0.4
	var avant := Vector3(sin(angle), 0, cos(angle))
	var fond := hub._boite(Vector3(0.75, hauteur, 0.12), p, hub._mat("metal"), false)
	fond.rotation.y = angle
	var vertical := ""
	for i in lignes:
		vertical += texte[i] + ("\n" if i < lignes - 1 else "")
	var l := hub._texte(vertical, p + avant * 0.08, couleur, 52, angle, 3.5)
	l.line_spacing = -6


# --- Entrée du marché --------------------------------------------------------

static func _construire_entree(hub: HikariBay) -> void:
	# Portique rouge à l'entrée de la ruelle (z = -70), façon torii moderne.
	var rouge := hub._mat_pbr("metal_plate", 1.5, "metal", Color(0.75, 0.12, 0.08))
	for x in [-25.4, -14.6]:
		hub._boite(Vector3(0.5, 6.0, 0.5), Vector3(x, 3.0, -69.5), rouge)
	hub._boite(Vector3(12.6, 0.45, 0.7), Vector3(-20, 6.1, -69.5), rouge, false)
	hub._boite(Vector3(11.0, 0.3, 0.5), Vector3(-20, 5.2, -69.5), rouge, false)
	hub._texte("夜市 · NIGHT MARKET · Marché de nuit", Vector3(-20, 5.65, -69.1), CHAUD, 64, 0.0, 3.0)
	for i in 7:
		_lanterne(hub, Vector3(-24.5 + i * 1.5 + 0.5, 4.6, -69.5), ROUGE, i == 3)


# --- Restaurant de ramen « Kaminari » (on y entre) ----------------------------

static func _construire_ramen(hub: HikariBay) -> void:
	var r := RAMEN
	var mur := hub._mat_pbr("white_rough_plaster", 2.0, "beton", Color(0.85, 0.78, 0.68))
	var sol := hub._mat_pbr("terrazzo_tiles", 2.0, "carrelage", Color(0.7, 0.62, 0.55))
	# Porte côté est (sur la ruelle principale), entre z = -111 et z = -108.
	_piece(hub, r, mur, sol, [["est", -111.0, -108.0]])
	var bois := _bois(hub)
	# Façade : grand rideau, lanternes, enseigne.
	_noren(hub, Vector3(r.end.x + 0.35, 0, -109.5), 3.0, PI / 2, Color(0.15, 0.15, 0.35), "雷")
	_lanterne(hub, Vector3(r.end.x + 0.6, 2.9, -112.0), ROUGE, true, 0.38)
	_lanterne(hub, Vector3(r.end.x + 0.6, 2.9, -107.0), ROUGE, false, 0.38)
	hub._texte("ラーメン 雷 KAMINARI", Vector3(r.end.x + 0.36, 3.6, -109.5), ROSE, 80, PI / 2, 4.0)
	var vitre := hub._boite(Vector3(0.06, 1.6, 2.4), Vector3(r.end.x + 0.33, 1.6, -105.6), hub._vitrine(CHAUD), false)
	vitre.name = "VitreRamen"
	# Comptoir en L le long du mur ouest, cuisine derrière.
	var x_comptoir := r.position.x + 2.6
	hub._bloc(x_comptoir - 0.35, r.position.y + 1.0, x_comptoir + 0.35, r.end.y - 2.5, 0, 1.05, bois)
	hub._bloc(x_comptoir - 0.45, r.position.y + 1.0, x_comptoir + 0.5, r.end.y - 2.5, 1.05, 1.12, hub._mat_pbr("granite_tile", 1.0, "pierre", Color(0.3, 0.3, 0.32)), false)
	# Tabourets.
	for i in 6:
		var z := r.position.y + 2.0 + i * 1.3
		hub._cylindre(0.22, 0.18, 0.7, Vector3(x_comptoir + 1.1, 0.35, z), hub._mat("metal"), false)
		hub._cylindre(0.26, 0.26, 0.08, Vector3(x_comptoir + 1.1, 0.74, z), _papier(hub, Color(0.6, 0.08, 0.06), 0.2), false)
		# Bols sur le comptoir, devant certains tabourets.
		if i % 2 == 0:
			hub._cylindre(0.16, 0.1, 0.12, Vector3(x_comptoir + 0.25, 1.18, z), _papier(hub, Color(0.9, 0.88, 0.8), 0.1), false)
	# Cuisine : marmites fumantes, étagères, hotte.
	for i in 3:
		var z := r.position.y + 2.5 + i * 2.2
		hub._cylindre(0.35, 0.35, 0.6, Vector3(r.position.x + 0.8, 1.35, z), hub._mat("metal"), false)
		_vapeur(hub, Vector3(r.position.x + 0.8, 1.7, z))
	hub._bloc(r.position.x, r.position.y + 1.0, r.position.x + 1.3, r.end.y - 2.5, 0, 1.05, hub._mat("metal"))
	hub._bloc(r.position.x, r.position.y + 1.5, r.position.x + 1.0, r.end.y - 3.0, 3.0, 3.6, hub._mat("metal"), false)
	# Menus accrochés au mur nord.
	var menus := ["醤油 Shōyu 850¥", "味噌 Miso 900¥", "豚骨 Tonkotsu 980¥", "餃子 Gyōza 450¥"]
	for i in menus.size():
		var x := r.position.x + 1.4 + i * 1.6
		hub._boite(Vector3(1.3, 0.5, 0.04), Vector3(x, 2.9, r.position.y + 0.04), _papier(hub, Color(0.95, 0.9, 0.75), 0.35), false)
		hub._texte(menus[i], Vector3(x, 2.9, r.position.y + 0.08), Color(0.1, 0.05, 0.03), 18, 0.0, 1.0)
	# Petite table pour deux près de la vitrine.
	hub._cylindre(0.45, 0.45, 0.06, Vector3(r.end.x - 1.4, 0.75, r.end.y - 1.6), bois, false)
	hub._cylindre(0.06, 0.06, 0.75, Vector3(r.end.x - 1.4, 0.37, r.end.y - 1.6), hub._mat("metal"))
	# Lumière chaude.
	for z in [r.position.y + 3.5, r.end.y - 3.5]:
		_lanterne(hub, Vector3(x_comptoir + 0.6, 3.5, z), Color(1.0, 0.85, 0.6), false, 0.25)
		hub._lumiere(Vector3(x_comptoir + 1.0, 3.3, z), CHAUD, 1.8, 8.0)
	_pnj(hub, "chef_goro", Vector3(r.position.x + 1.6, 0, r.position.y + 5.0), -PI / 2)
	_pnj(hub, "client_ramen", Vector3(x_comptoir + 1.1, 0, r.position.y + 7.2), PI / 2)


static func _vapeur(hub: HikariBay, p: Vector3) -> void:
	var gp := GPUParticles3D.new()
	gp.amount = 10
	gp.lifetime = 2.2
	gp.position = p
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0, 0.05, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var courbe := Curve.new()
	courbe.add_point(Vector2(0, 0.3))
	courbe.add_point(Vector2(1, 1.0))
	var ct := CurveTexture.new()
	ct.curve = courbe
	pm.scale_curve = ct
	var degrade := Gradient.new()
	degrade.set_color(0, Color(1, 1, 1, 0.18))
	degrade.set_color(1, Color(1, 1, 1, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = degrade
	pm.color_ramp = gt
	gp.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.4, 0.4)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.9, 0.9, 0.9)
	q.material = m
	gp.draw_pass_1 = q
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hub._contenu.add_child(gp)


# --- Salle Tsukimi (futur hôtel des ventes, on y entre) -----------------------

static func _construire_tsukimi(hub: HikariBay) -> void:
	var r := SALLE_TSUKIMI
	var mur := hub._mat_pbr("square_tiled_wall", 1.5, "carrelage", Color(0.35, 0.3, 0.4))
	var sol := hub._mat_pbr("concrete_pavement", 2.0, "beton", Color(0.4, 0.38, 0.42))
	# Porte côté ouest, sur la ruelle de la fumée (x = -48), entre z = -121 et z = -118.
	_piece(hub, r, mur, sol, [["ouest", -121.0, -118.0]])
	var bois := _bois(hub)
	_noren(hub, Vector3(r.position.x - 0.35, 0, -119.5), 3.0, -PI / 2, Color(0.3, 0.05, 0.25), "月見")
	hub._texte("月見 TSUKIMI · Salle des ventes", Vector3(r.position.x - 0.36, 3.5, -119.5), CYAN, 56, -PI / 2, 3.5)
	_lanterne(hub, Vector3(r.position.x - 0.6, 2.9, -122.2), Color(0.9, 0.85, 0.4), true, 0.3)
	# Guichet du fond, tableau des enchères, tables de jeu.
	hub._bloc(r.end.x - 2.2, r.position.y + 3.0, r.end.x - 1.4, r.end.y - 3.0, 0, 1.1, bois)
	var tableau := hub._boite(Vector3(0.06, 1.8, 5.0), Vector3(r.end.x - 0.05, 2.4, r.get_center().y), hub._neon(Color(0.05, 0.18, 0.2), 1.0), false)
	tableau.name = "TableauEncheres"
	var lots := ["LOT 07 · Silex taillé ......... 120 ¥", "LOT 12 · Collier d'ivoire .... 900 ¥",
			"LOT 15 · Fourrure de loup ... 450 ¥", "Les enchères ouvrent bientôt"]
	for i in lots.size():
		hub._texte(lots[i], Vector3(r.end.x - 0.1, 3.0 - i * 0.38, r.get_center().y), CYAN, 22, -PI / 2, 2.5)
	for t in [Vector2(-44.5, -115.5), Vector2(-40.5, -115.5), Vector2(-44.5, -122.5)]:
		hub._cylindre(0.7, 0.7, 0.06, Vector3(t.x, 0.78, t.y), _papier(hub, Color(0.05, 0.3, 0.12), 0.15), false)
		hub._cylindre(0.08, 0.08, 0.78, Vector3(t.x, 0.39, t.y), hub._mat("metal"))
		hub._lumiere(Vector3(t.x, 2.8, t.y), Color(1.0, 0.85, 0.6), 1.4, 5.0)
		var abat := hub._cylindre(0.35, 0.05, 0.3, Vector3(t.x, 3.0, t.y), _papier(hub, Color(0.9, 0.7, 0.3), 1.5), false)
		abat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pnj(hub, "courtiere", Vector3(r.end.x - 0.8, 0, r.get_center().y - 1.0), PI / 2)
	_pnj(hub, "joueur_cartes", Vector3(-44.5, 0, -114.4), 0.0)


# --- Boutiques le long des ruelles ------------------------------------------

static func _construire_boutiques(hub: HikariBay) -> void:
	# [centre au sol, angle (face vers la ruelle), couleur, ouverte ?]
	var boutiques := [
		# Ruelle principale, côté est (façades à x = -17, face à l'ouest).
		[Vector3(-17.0, 0, -76), -PI / 2, CHAUD, true],
		[Vector3(-17.0, 0, -84), -PI / 2, CYAN, true],
		[Vector3(-17.0, 0, -92), -PI / 2, Color(), false],
		[Vector3(-17.0, 0, -106), -PI / 2, ORANGE, true],
		[Vector3(-17.0, 0, -114), -PI / 2, ROSE, true],
		[Vector3(-17.0, 0, -122), -PI / 2, Color(), false],
		# Ruelle principale, côté ouest (façades à x = -23, face à l'est).
		[Vector3(-23.0, 0, -78), PI / 2, VERT, true],
		[Vector3(-23.0, 0, -88), PI / 2, CHAUD, true],
		[Vector3(-23.0, 0, -122), PI / 2, Color(), false],
		# Ruelle des lanternes (façades à z = -97, face au nord ; z = -102, face au sud).
		[Vector3(-34.0, 0, -97), PI, ORANGE, true],
		[Vector3(-44.0, 0, -97), PI, Color(), false],
		[Vector3(-40.0, 0, -102), 0.0, BLEU, true],
	]
	for b in boutiques:
		var centre: Vector3 = b[0]
		var angle: float = b[1]
		var avant := Vector3(sin(angle), 0, cos(angle))
		if b[3]:
			var vitre := hub._boite(Vector3(4.0, 2.6, 0.08), centre + avant * 0.03 + Vector3(0, 1.4, 0), hub._vitrine(b[2]), false)
			vitre.rotation.y = angle
			var auvent := hub._boite(Vector3(4.6, 0.1, 1.0), centre + avant * 0.5 + Vector3(0, 2.95, 0), _papier(hub, b[2] * 0.6, 0.6), false)
			auvent.rotation.y = angle
		else:
			var rideau := hub._modele("rollershutter_window_01", centre + avant * 0.05, angle, 0.85)
			if rideau == null:
				var f := hub._boite(Vector3(4.0, 2.6, 0.08), centre + avant * 0.03 + Vector3(0, 1.4, 0), hub._mat("metal"), false)
				f.rotation.y = angle


# --- Stands de nourriture -----------------------------------------------------

static func _construire_stands(hub: HikariBay) -> void:
	# [position, angle (face au client), couleur du toit, enseigne, personnage (ou "")]
	var stands := [
		[Vector3(-21.6, 0, -80.5), PI / 2, ROUGE, "焼き鳥 Yakitori", "vendeur_yakitori"],
		[Vector3(-18.4, 0, -95.0), -PI / 2, ORANGE, "たこ焼き Takoyaki", ""],
		[Vector3(-30.0, 0, -99.8), 0.0, VERT, "野菜 Légumes Okada", "mme_okada"],
		[Vector3(-18.4, 0, -118.0), -PI / 2, BLEU, "おでん Oden", ""],
		[Vector3(-50.9, 0, -108.0), PI / 2, ROSE, "団子 Dango", ""],
	]
	var bois := _bois(hub)
	for s in stands:
		var p: Vector3 = s[0]
		var angle: float = s[1]
		var pivot := Node3D.new()
		pivot.position = p
		pivot.rotation.y = angle
		hub._contenu.add_child(pivot)
		var avant := Vector3(sin(angle), 0, cos(angle))
		var cote := Vector3(cos(angle), 0, -sin(angle))
		# Comptoir (avec collision), toit penché, poteaux.
		hub._boite(Vector3(2.2, 1.0, 0.8), Vector3(0, 0.5, 0), bois, false, pivot)
		hub._collision_boite(Vector3(2.2, 1.0, 0.8), pivot.transform.translated_local(Vector3(0, 0.5, 0)))
		var toit := hub._boite(Vector3(2.6, 0.08, 1.6), Vector3(0, 2.45, -0.2), _papier(hub, s[2] * 0.7, 0.5), false, pivot)
		toit.rotation.x = -0.18
		for x in [-1.05, 1.05]:
			hub._boite(Vector3(0.08, 2.4, 0.08), Vector3(x, 1.2, -0.55), hub._mat("metal"), false, pivot)
		# Bandeau en tissu avec le nom du stand.
		hub._boite(Vector3(2.4, 0.4, 0.03), Vector3(0, 2.15, 0.48), _papier(hub, Color(0.95, 0.92, 0.85), 0.5), false, pivot)
		var l := hub._texte(s[3], p + avant * 0.52 + Vector3(0, 2.15, 0), Color(0.1, 0.05, 0.05), 34, angle, 1.0)
		l.double_sided = true
		_lanterne(hub, p + avant * 0.5 + cote * 1.1 + Vector3(0, 1.75, 0), ROUGE, true, 0.24)
		_vapeur(hub, p + Vector3(0, 1.15, 0) - avant * 0.1)
		if s[4] != "":
			_pnj(hub, s[4], p - avant * 0.9, angle + PI)


# --- Guirlandes de lanternes au-dessus des ruelles ------------------------------

static func _construire_lanternes(hub: HikariBay) -> void:
	# [début, fin, couleur]
	var guirlandes := [
		[Vector3(-23, 4.6, -75), Vector3(-17, 4.6, -75), ROUGE],
		[Vector3(-23, 4.8, -86), Vector3(-17, 4.8, -86), ORANGE],
		[Vector3(-23, 4.6, -97), Vector3(-17, 4.6, -97), ROUGE],
		[Vector3(-23, 4.8, -110), Vector3(-17, 4.8, -110), ROSE],
		[Vector3(-23, 4.6, -125), Vector3(-17, 4.6, -125), ROUGE],
		[Vector3(-23, 4.5, -99.5), Vector3(-52, 4.5, -99.5), ROUGE],
		[Vector3(-52, 4.2, -112), Vector3(-48, 4.2, -112), ORANGE],
		[Vector3(-52, 4.2, -124), Vector3(-48, 4.2, -124), ROUGE],
		[Vector3(-48, 4.3, -130.5), Vector3(-17, 4.3, -130.5), ROSE],
	]
	var fil := hub._mat("metal")
	var avec_lumiere := 0
	for g in guirlandes:
		var a: Vector3 = g[0]
		var b: Vector3 = g[1]
		var longueur := a.distance_to(b)
		var cable := hub._boite(Vector3(0.02, 0.02, longueur), (a + b) * 0.5, fil, false)
		cable.look_at_from_position((a + b) * 0.5, b, Vector3.UP)
		var n := int(longueur / 1.4)
		for i in n:
			var t := (i + 0.5) / n
			# Le câble pend un peu au milieu.
			var p := a.lerp(b, t) + Vector3(0, -0.35 - sin(t * PI) * 0.4, 0)
			var lumiere := i == n / 2 and avec_lumiere < 7
			if lumiere:
				avec_lumiere += 1
			_lanterne(hub, p, g[2] if i % 3 != 1 else Color(1.0, 0.85, 0.55), lumiere, 0.2)


# --- Enseignes ---------------------------------------------------------------

static func _construire_enseignes(hub: HikariBay) -> void:
	# Enseignes verticales empilées sur les façades de la ruelle principale.
	var verticales := [
		[Vector3(-17.4, 5.6, -79), -PI / 2, "居酒屋", ROSE],
		[Vector3(-17.4, 6.2, -88), -PI / 2, "カラオケ", CYAN],
		[Vector3(-17.4, 5.8, -103), -PI / 2, "焼肉", ORANGE],
		[Vector3(-17.4, 6.0, -117), -PI / 2, "スナック", ROSE],
		[Vector3(-22.6, 5.6, -83), PI / 2, "寿司", CYAN],
		[Vector3(-22.6, 6.4, -92), PI / 2, "ホテル", BLEU],
		[Vector3(-22.6, 6.0, -126), PI / 2, "麻雀", VERT],
	]
	for v in verticales:
		_enseigne_verticale(hub, v[0], v[1], v[2], v[3])
	# Enseignes horizontales (JP / EN / FR mélangés, comme dans toute la ville).
	var horizontales := [
		["居酒屋 IZAKAYA Chez Momo", Vector3(-17.05, 3.4, -76), -PI / 2, ROSE, 46],
		["電気 ÉLECTRONIQUE 24h", Vector3(-17.05, 3.4, -84), -PI / 2, CYAN, 46],
		["焼肉 BBQ Yaki-Ya", Vector3(-17.05, 3.4, -106), -PI / 2, ORANGE, 46],
		["BAR Lune Rouge", Vector3(-17.05, 3.4, -114), -PI / 2, ROSE, 46],
		["薬局 Pharmacie", Vector3(-22.95, 3.4, -78), PI / 2, VERT, 46],
		["本 Librairie d'occasion", Vector3(-22.95, 3.4, -88), PI / 2, CHAUD, 46],
		["喫茶 Café Kissa", Vector3(-34, 3.4, -97.05), PI, ORANGE, 46],
		["ゲーム GAMES Retro", Vector3(-40, 3.4, -101.95), 0.0, BLEU, 46],
	]
	for h in horizontales:
		hub._texte(h[0], h[1], h[3], h[4], h[2], 3.5)
	# Quelques lumières colorées pour les reflets sur le sol mouillé.
	hub._lumiere(Vector3(-20, 4.0, -80), ROSE, 1.5, 10.0)
	hub._lumiere(Vector3(-20, 4.0, -104), ORANGE, 1.5, 10.0)
	hub._lumiere(Vector3(-20, 4.0, -120), CYAN, 1.2, 10.0)
	hub._lumiere(Vector3(-50, 3.5, -116), ROSE, 1.2, 8.0)
	hub._lumiere(Vector3(-36, 3.5, -130.5), ORANGE, 1.2, 9.0)
	# Fond de la ruelle de derrière : un petit sanctuaire avec deux lanternes de pierre.
	var pierre := hub._mat_pbr("granite_tile", 1.0, "pierre", Color(0.55, 0.55, 0.55))
	hub._bloc(-21.5, -133.0, -18.5, -132.2, 0, 1.6, hub._mat_pbr("metal_plate", 1.5, "metal", Color(0.7, 0.15, 0.1)))
	hub._texte("稲荷 · Petit sanctuaire", Vector3(-20, 1.9, -132.1), CHAUD, 30, 0.0, 2.0)
	for x in [-22.4, -17.6]:
		hub._bloc(x - 0.25, -132.6, x + 0.25, -132.1, 0, 1.3, pierre)
		_lanterne(hub, Vector3(x, 1.5, -132.35), CHAUD, false, 0.14)


# --- Petits objets qui rendent les ruelles vivantes ------------------------------

static func _construire_encombrement(hub: HikariBay) -> void:
	var objets := [
		["plastic_crate_01", Vector3(-22.4, 0, -91.5), 0.3],
		["plastic_crate_01", Vector3(-22.5, 0.32, -91.6), 1.1],
		["cardboard_box_01", Vector3(-17.6, 0, -99.5), 0.6],
		["trashbag", Vector3(-17.5, 0, -125.0), 0.0],
		["trashbag", Vector3(-17.7, 0, -125.8), 1.2],
		["metal_trash_can", Vector3(-51.4, 0, -126.5), 0.0],
		["exterior_aircon_unit", Vector3(-48.3, 2.6, -105.0), PI / 2],
		["exterior_aircon_unit", Vector3(-22.7, 3.2, -96.0), PI / 2],
		["exterior_aircon_unit", Vector3(-17.3, 3.0, -110.5), -PI / 2],
		["utility_box_01", Vector3(-51.6, 0, -98.4), PI / 2],
		["cardboard_box_01", Vector3(-30.0, 0, -132.4), 0.2],
		["plastic_crate_01", Vector3(-41.0, 0, -132.3), 0.0],
	]
	for o in objets:
		hub._modele(o[0], o[1], o[2], 1.0)
	# Vélos stationnés (formes simples).
	for i in 3:
		var z := -73.0 - i * 0.7
		hub._boite(Vector3(0.05, 0.7, 1.6), Vector3(-17.6, 0.45, z), hub._mat("metal"), false)


# --- Habitants -------------------------------------------------------------------

static func _construire_habitants(hub: HikariBay) -> void:
	_pnj(hub, "passante_marche", Vector3(-22.0, 0, -86.5), -PI / 2)
	_pnj(hub, "musicien", Vector3(-25.0, 0, -99.6), PI / 2)
