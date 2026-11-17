@tool
extends "res://scripts/monde/egypte/ile_egypte.gd"
## Base commune des zones de l'île de Grèce (le Pirée, les Oliveraies d'Attique, Athènes…).
##
## L'été -438, à Athènes, au temps de Périclès. On réutilise les outils des îles
## précédentes (terrain, rochers, herbe, eau, portail de la Vigie, personnages), et on
## y ajoute ce qui est propre à la Grèce classique : la mer Égée turquoise, les maisons
## blanchies à la chaux aux toits de tuiles, les colonnes doriques, les portiques
## peints de couleurs vives (les temples n'étaient pas blancs !), les amphores, les
## oliviers et les cyprès, et les trières.
##
## Les textures Poly Haven de la Grèce iront dans assets/grece/ ; tant qu'elles ne sont
## pas téléchargées, on prend celles de l'Égypte et de la Préhistoire, puis des couleurs.

const DOSSIER_GRECE := "res://assets/grece/"

## Les couleurs des peintures grecques (frises, triglyphes, boucliers, yeux des trières).
const ROUGE_GREC := Color(0.62, 0.13, 0.09)
const BLEU_GREC := Color(0.12, 0.24, 0.5)
const OCRE_GREC := Color(0.78, 0.55, 0.2)
const NOIR_POIX := Color(0.06, 0.055, 0.05)

static var _texture_tuiles: Texture2D


# --- Ressources : d'abord la Grèce, puis l'Égypte et la Préhistoire --------------------------

func _texture(id: String, carte: String) -> Texture2D:
	for dossier in [DOSSIER_GRECE, DOSSIER_EGYPTE, DOSSIER]:
		var chemin: String = dossier + "textures/%s/%s_%s.jpg" % [id, id, carte]
		if ResourceLoader.exists(chemin):
			return load(chemin)
	return null


func _modele(id: String, position_m: Vector3, angle_y := 0.0, echelle := 1.0, parent: Node3D = null) -> Node3D:
	for dossier in [DOSSIER_GRECE, DOSSIER_EGYPTE, DOSSIER]:
		var chemin: String = dossier + "modeles/%s/%s.gltf" % [id, id]
		if ResourceLoader.exists(chemin):
			var instance := (load(chemin) as PackedScene).instantiate() as Node3D
			instance.position = position_m
			instance.rotation.y = angle_y
			instance.scale = Vector3.ONE * echelle
			(parent if parent != null else _contenu).add_child(instance)
			return instance
	return null


func _premiere_texture(ids: Array) -> String:
	for id in ids:
		if _texture(id, "Diffuse") != null or _texture(id, "diff") != null:
			return id
	return super._premiere_texture(ids)


# --- Matériaux ---------------------------------------------------------------------------------

## Couleur moyenne (sRGB) des textures : la couleur demandée devient la couleur
## réellement vue (sinon la chaux blanche sortait beige foncé).
const MOYENNES_TEXTURES := {
	"white_plaster_rough_01": Color(0.49, 0.44, 0.34),
	"clay_plaster": Color(0.45, 0.35, 0.23),
	"large_sandstone_blocks": Color(0.34, 0.33, 0.29),
	"sandstone_blocks_08": Color(0.65, 0.57, 0.46),
	"rock_wall_10": Color(0.31, 0.23, 0.15),
	"white_sandstone_blocks_02": Color(0.7, 0.64, 0.56),
	"white_sandstone_bricks": Color(0.54, 0.5, 0.43),
	"weathered_planks": Color(0.31, 0.26, 0.23),
	"rough_wood": Color(0.42, 0.38, 0.34),
	"brown_mud_02": Color(0.3, 0.27, 0.22),
	"bark_willow_02": Color(0.52, 0.46, 0.41),
	"marble_01": Color(0.7, 0.62, 0.48),
	"marble_tiles": Color(0.55, 0.51, 0.45),
	"white_plaster_02": Color(0.56, 0.53, 0.48),
	"plastered_stone_wall": Color(0.27, 0.25, 0.22),
	"stacked_stone_wall": Color(0.37, 0.27, 0.19),
	"old_stone_wall": Color(0.53, 0.47, 0.39),
	"stone_wall_04": Color(0.44, 0.4, 0.37),
	"seaworn_stone_tiles": Color(0.53, 0.48, 0.42),
	"cobblestone_floor_04": Color(0.54, 0.49, 0.38),
	"terracotta_floor_tiles": Color(0.3, 0.15, 0.1),
	"wooden_rough_planks": Color(0.43, 0.4, 0.19),
	"tree_bark_03": Color(0.56, 0.53, 0.4),
	"clay_roof_tiles_02": Color(0.57, 0.31, 0.17),
}


func _mat_choix(ids: Array, couleur: Color, rugosite := 0.9, taille_motif := 2.0) -> StandardMaterial3D:
	var id := _premiere_texture(ids)
	if MOYENNES_TEXTURES.has(id):
		var moyenne: Color = MOYENNES_TEXTURES[id]
		# 0.8 : on garde un peu de marge pour les taches et les joints plus clairs.
		couleur = Color(minf(couleur.r / moyenne.r * 0.8, 2.5), minf(couleur.g / moyenne.g * 0.8, 2.5),
				minf(couleur.b / moyenne.b * 0.8, 2.5))
	return _mat_pbr(id, couleur, rugosite, taille_motif)

## Le marbre du Pentélique : blanc chaud, légèrement doré (il prend une patine au soleil).
func _mat_marbre() -> StandardMaterial3D:
	return _mat_choix(["marble_01", "white_sandstone_blocks_02", "white_sandstone_bricks"], Color(0.95, 0.93, 0.88), 0.55, 2.0)


## Les murs des maisons : de la brique crue sur un socle de pierre, enduite à la chaux.
func _mat_chaux() -> StandardMaterial3D:
	return _mat_choix(["white_plaster_02", "plastered_stone_wall", "white_plaster_rough_01", "clay_plaster"], Color(0.94, 0.92, 0.86), 0.95, 3.0)


## Le calcaire gris de l'Akté (murs du port, socles, quais).
func _mat_pierre() -> StandardMaterial3D:
	var cle := "pierre_grece"
	if not _materiaux.has(cle):
		var m := _mat_choix(["stacked_stone_wall", "old_stone_wall", "large_sandstone_blocks", "sandstone_blocks_08", "rock_wall_10"], Color(0.7, 0.66, 0.6), 0.9, 2.5).duplicate()
		# Le calcaire du Pirée est plus gris que le grès égyptien.
		m.albedo_color = m.albedo_color * Color(0.86, 0.86, 0.88)
		_materiaux[cle] = m
	return _materiaux[cle]


## Les toits de tuiles de terre cuite : des rangées ondulées, rouge-orangé, un peu passées.
func _mat_tuiles() -> StandardMaterial3D:
	var cle := "tuiles_grece"
	if not _materiaux.has(cle) and _texture("clay_roof_tiles_02", "Diffuse") != null:
		# Les vraies tuiles de terre cuite (Poly Haven), avec leur relief.
		_materiaux[cle] = _mat_choix(["clay_roof_tiles_02"], Color(0.74, 0.4, 0.25), 0.85, 1.6)
	if not _materiaux.has(cle):
		var m := StandardMaterial3D.new()
		m.albedo_texture = _tuiles()
		m.albedo_color = Color(1.0, 1.0, 1.0)
		m.roughness = 0.85
		m.uv1_scale = Vector3(1.0, 1.0, 1.0)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(0.6, 0.6, 0.6)
		_materiaux[cle] = m
	return _materiaux[cle]


static func _tuiles() -> Texture2D:
	if _texture_tuiles != null:
		return _texture_tuiles
	# Une texture faite à la main : des bandes de tuiles creuses et couvre-joints.
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var bande := 0.5 + 0.5 * cos(x / 64.0 * TAU * 2.0)
			var rang := fmod(y / 16.0, 1.0)
			var ombre := 0.78 + 0.22 * bande - (0.18 if rang > 0.88 else 0.0)
			var variation := 0.92 + 0.08 * sin(float(x * 7 + y * 13))
			image.set_pixel(x, y, Color(0.72, 0.36, 0.22) * ombre * variation)
	_texture_tuiles = ImageTexture.create_from_image(image)
	return _texture_tuiles


## Une peinture vive et mate (frises, triglyphes, coques, boucliers).
## Le bois des quais, des loges et des trières : planches brutes, grisées par le sel.
func _mat_bois() -> StandardMaterial3D:
	return _mat_choix(["wooden_rough_planks", "weathered_planks", "rough_wood"], Color(0.5, 0.42, 0.34), 0.85, 1.5)


func _mat_peint(couleur: Color, rugosite := 0.8) -> StandardMaterial3D:
	var cle := "peint_%s" % couleur.to_html()
	if not _materiaux.has(cle):
		var m := StandardMaterial3D.new()
		m.albedo_color = couleur
		m.roughness = rugosite
		_materiaux[cle] = m
	return _materiaux[cle]


func _mat_bronze() -> StandardMaterial3D:
	var cle := "bronze_grece"
	if not _materiaux.has(cle):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.62, 0.42, 0.2)
		m.metallic = 0.85
		m.roughness = 0.38
		_materiaux[cle] = m
	return _materiaux[cle]


func _mat_terre_cuite() -> StandardMaterial3D:
	var cle := "terre_cuite"
	if not _materiaux.has(cle):
		_materiaux[cle] = _mat_choix(["terracotta_floor_tiles", "clay_plaster", "brown_mud_02"], Color(0.86, 0.5, 0.32), 0.85, 0.6)
	return _materiaux[cle]


# --- L'eau : la mer Égée -------------------------------------------------------------------------

## La mer : turquoise sur les fonds clairs, bleu profond au large, assez claire pour voir le fond.
func _construire_eau(centre := Vector3.ZERO, taille := Vector2(4000, 4000)) -> void:
	super._construire_eau(centre, taille)
	var eau := _contenu.get_node_or_null("Nil") as MeshInstance3D
	if eau == null:
		return
	eau.name = "Mer"
	var m := eau.material_override as ShaderMaterial
	m.set_shader_parameter("couleur_profonde", Color(0.02, 0.1, 0.19))
	m.set_shader_parameter("couleur_claire", Color(0.12, 0.48, 0.52))
	m.set_shader_parameter("couleur_ecume", Color(0.9, 0.95, 0.96))
	m.set_shader_parameter("transparence", 0.55)
	m.set_shader_parameter("largeur_ecume", 0.5)
	m.set_shader_parameter("vitesse", 0.02)
	m.set_shader_parameter("hauteur_houle", 0.06)


# --- Architecture --------------------------------------------------------------------------------

## Une colonne dorique : un fût cannelé (20 cannelures) qui s'amincit vers le haut,
## un chapiteau (l'échine arrondie puis l'abaque carré). « haut » = hauteur totale.
func _colonne(parent: Node3D, pied: Vector3, haut := 5.0, rayon := 0.4, materiau: Material = null) -> Node3D:
	var m := materiau if materiau != null else _mat_marbre()
	var c := Node3D.new()
	c.position = pied
	parent.add_child(c)
	var fut := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = rayon * 0.78
	cyl.bottom_radius = rayon
	cyl.height = haut * 0.88
	cyl.radial_segments = 20
	cyl.rings = 1
	fut.mesh = cyl
	fut.material_override = m
	fut.position.y = haut * 0.44
	c.add_child(fut)
	var echine := MeshInstance3D.new()
	var e := CylinderMesh.new()
	e.top_radius = rayon * 1.25
	e.bottom_radius = rayon * 0.8
	e.height = haut * 0.05
	e.radial_segments = 20
	echine.mesh = e
	echine.material_override = m
	echine.position.y = haut * 0.905
	c.add_child(echine)
	_boite(Vector3(rayon * 2.7, haut * 0.07, rayon * 2.7), Vector3(0, haut * 0.965, 0), m, c, false)
	# Collision : un simple pilier.
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var f := CylinderShape3D.new()
	f.radius = rayon * 0.9
	f.height = haut
	forme.shape = f
	forme.position.y = haut * 0.5
	corps.add_child(forme)
	c.add_child(corps)
	return c


## Une frise peinte : alternance de triglyphes bleus et de métopes rouges, posée sur
## l'architrave (comme sur les temples de l'époque, avant que la peinture ne s'efface).
func _frise(parent: Node3D, centre: Vector3, longueur: float, haut := 0.7, angle := 0.0) -> void:
	var f := Node3D.new()
	f.position = centre
	f.rotation.y = angle
	parent.add_child(f)
	var n := maxi(2, int(longueur / 1.4))
	var pas := longueur / n
	for k in n:
		var x := -longueur * 0.5 + pas * (k + 0.5)
		_boite(Vector3(pas * 0.42, haut, 0.12), Vector3(x - pas * 0.29, 0, 0), _mat_peint(BLEU_GREC), f, false)
		_boite(Vector3(pas * 0.58, haut, 0.1), Vector3(x + pas * 0.21, 0, -0.01), _mat_peint(ROUGE_GREC), f, false)
	# Le bandeau ocre au-dessus.
	_boite(Vector3(longueur, haut * 0.22, 0.16), Vector3(0, haut * 0.6, 0), _mat_peint(OCRE_GREC), f, false)


## Un toit à deux pentes en tuiles (le faîte suit l'axe Z local), avec son épaisseur.
func _toit(parent: Node3D, centre: Vector3, largeur: float, longueur: float, pente := 0.32) -> void:
	var tuiles := _mat_tuiles()
	var demi := largeur * 0.5 + 0.35
	var haut := demi * tan(pente)
	for cote: float in [-1.0, 1.0]:
		var pan := _boite(Vector3(demi / cos(pente), 0.18, longueur + 0.6),
				centre + Vector3(cote * demi * 0.5, haut * 0.5, 0), tuiles, parent, false)
		pan.rotation.z = -cote * pente
	# Les pignons (les triangles des bouts), enduits.
	for bout: float in [-1.0, 1.0]:
		var pignon := MeshInstance3D.new()
		var prisme := PrismMesh.new()
		prisme.size = Vector3(largeur, haut, 0.2)
		pignon.mesh = prisme
		pignon.material_override = _mat_chaux()
		pignon.position = centre + Vector3(0, haut * 0.5, bout * longueur * 0.5)
		parent.add_child(pignon)


## Une maison grecque : socle de pierre, murs blanchis, petites fenêtres hautes, porte
## de bois, toit de tuiles. (Les maisons ordinaires étaient simples : c'est la cité qui
## dépensait pour les temples.)
func _maison_grecque(parent: Node3D, centre: Vector2, taille: Vector3, angle := 0.0) -> Node3D:
	var m := Node3D.new()
	m.position = Vector3(centre.x, hauteur(centre.x, centre.y) - 0.3, centre.y)
	m.rotation.y = angle
	parent.add_child(m)
	_boite(Vector3(taille.x + 0.2, 0.9, taille.z + 0.2), Vector3(0, 0.45, 0), _mat_pierre(), m)
	_boite(Vector3(taille.x, taille.y - 0.6, taille.z), Vector3(0, 0.6 + (taille.y - 0.6) * 0.5, 0), _mat_chaux(), m, false)
	_toit(m, Vector3(0, taille.y, 0), taille.x, taille.z)
	var sombre := _mat_pbr("", Color(0.05, 0.045, 0.04), 1.0)
	var porte := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 2.0)
	porte.mesh = q
	porte.material_override = _mat_bois()
	porte.position = Vector3(0, 1.3, taille.z * 0.5 + 0.02)
	m.add_child(porte)
	for k in 2:
		var fenetre := MeshInstance3D.new()
		var qf := QuadMesh.new()
		qf.size = Vector2(0.5, 0.45)
		fenetre.mesh = qf
		fenetre.material_override = sombre
		fenetre.position = Vector3((-1.0 if k == 0 else 1.0) * taille.x * 0.3, taille.y - 1.0, taille.z * 0.5 + 0.02)
		m.add_child(fenetre)
	return m


## Un portique (stoa) : un long mur au fond, une rangée de colonnes doriques devant,
## une architrave, la frise peinte et un toit de tuiles à une pente.
## « origine » = milieu de la façade ; la façade regarde vers +Z local.
func _portique(parent: Node3D, origine: Vector2, longueur: float, profondeur := 7.0, angle := 0.0, haut := 5.0) -> Node3D:
	var s := Node3D.new()
	s.name = "Portique"
	s.position = Vector3(origine.x, hauteur(origine.x, origine.y), origine.y)
	s.rotation.y = angle
	parent.add_child(s)
	var marbre := _mat_marbre()
	# Le soubassement à trois marches.
	for k in 3:
		_boite(Vector3(longueur + 2.0 - k * 0.6, 0.22, profondeur + 1.6 - k * 0.6),
				Vector3(0, 0.11 + k * 0.22, 0), _mat_pierre() if k == 0 else marbre, s, k == 0)
	var sol := 0.66
	# Le mur du fond, enduit et peint en rouge à mi-hauteur (comme le Portique peint d'Athènes).
	_boite(Vector3(longueur, haut, 0.6), Vector3(0, sol + haut * 0.5, -profondeur * 0.5 + 0.3), _mat_chaux(), s)
	_boite(Vector3(longueur - 0.2, haut * 0.45, 0.05), Vector3(0, sol + haut * 0.32, -profondeur * 0.5 + 0.63), _mat_peint(ROUGE_GREC.lightened(0.15), 0.9), s, false)
	for bout: float in [-1.0, 1.0]:
		_boite(Vector3(0.6, haut, profondeur), Vector3(bout * (longueur * 0.5 - 0.3), sol + haut * 0.5, 0), _mat_chaux(), s)
	var n := maxi(3, int(longueur / 3.2) + 1)
	for k in n:
		var x := lerpf(-longueur * 0.5 + 0.9, longueur * 0.5 - 0.9, float(k) / (n - 1))
		_colonne(s, Vector3(x, sol, profondeur * 0.5 - 0.6), haut, 0.36, marbre)
	# L'architrave, la frise, la corniche.
	_boite(Vector3(longueur, 0.55, 1.0), Vector3(0, sol + haut + 0.27, profondeur * 0.5 - 0.6), marbre, s, false)
	_frise(s, Vector3(0, sol + haut + 0.9, profondeur * 0.5 - 0.5), longueur, 0.65)
	_boite(Vector3(longueur + 0.4, 0.2, 1.5), Vector3(0, sol + haut + 1.38, profondeur * 0.5 - 0.6), marbre, s, false)
	# Le toit à une pente, du mur du fond vers la colonnade.
	var toit := _boite(Vector3(longueur + 0.6, 0.18, profondeur + 1.0), Vector3(0, sol + haut + 1.7, 0), _mat_tuiles(), s, false)
	toit.rotation.x = -0.14
	return s


## Une amphore de terre cuite (fond en pointe, deux anses) : huile, vin, poisson salé.
func _amphore(parent: Node3D, p: Vector3, taille := 1.0, angle := 0.0, couchee := false) -> void:
	if not _materiaux.has("forme_amphore"):
		_materiaux["forme_amphore"] = _tour([[0.0, 0.0], [0.05, 0.03], [0.2, 0.09], [0.45, 0.17], [0.68, 0.19],
				[0.82, 0.15], [0.9, 0.07], [1.02, 0.05], [1.06, 0.065], [1.08, 0.05]], 14)
	var mi := MeshInstance3D.new()
	mi.mesh = _materiaux["forme_amphore"]
	mi.material_override = _mat_terre_cuite()
	mi.position = p
	mi.rotation.y = angle
	if couchee:
		mi.rotation.x = PI / 2 - 0.15
		mi.position.y += 0.18 * taille
	mi.scale = Vector3.ONE * taille
	parent.add_child(mi)
	for cote: float in [-1.0, 1.0]:
		var anse := MeshInstance3D.new()
		var tore := TorusMesh.new()
		tore.inner_radius = 0.06
		tore.outer_radius = 0.085
		anse.mesh = tore
		anse.material_override = _mat_terre_cuite()
		anse.position = Vector3(cote * 0.1, 0.92, 0)
		anse.rotation.z = PI / 2
		anse.scale = Vector3(1.0, 1.0, 0.5)
		mi.add_child(anse)


# --- Les trières ---------------------------------------------------------------------------------

## Une trière athénienne (environ 37 m de long) : coque noire de poix, éperon de bronze
## à la proue (vers -Z), un grand œil peint de chaque côté, la caisse de nage où sont
## assis les 170 rameurs sur trois rangs, les rames qui sortent par les sabords, la
## poupe recourbée comme une queue de scorpion. Renvoie le nœud ; ses rames sont
## rangées dans la méta « rames » pour qu'on puisse les animer.
func _triere(parent: Node3D, p: Vector3, angle := 0.0, longueur := 37.0, avec_rames := true) -> Node3D:
	var t := Node3D.new()
	t.name = "Triere"
	t.position = p
	t.rotation.y = angle
	parent.add_child(t)
	var demi := longueur * 0.5
	var large := 2.7
	var sections := []
	for k in 15:
		var f := float(k) / 14.0
		var z := lerpf(-demi, demi, f)
		var forme := sin(f * PI)
		# La proue est basse et pointue (l'éperon), la poupe se relève très haut.
		var releve := pow(maxf(f - 0.75, 0.0) * 4.0, 2.2) * 3.0
		sections.append([z, maxf(large * pow(forme, 0.45), 0.08), maxf(1.6 * pow(forme, 0.35), 0.1), 1.3 + releve])
	var coque := MeshInstance3D.new()
	coque.mesh = _loft(sections, 14, true)
	coque.material_override = _mat_peint(NOIR_POIX, 0.55)
	t.add_child(coque)
	# La caisse de nage (le haut de la coque) peinte, avec la galerie des rameurs du haut.
	# Elle suit la forme de la coque : des tranches qui s'affinent vers la proue et la poupe.
	var caisse := _mat_peint(Color(0.32, 0.18, 0.1), 0.7)
	var bande := _mat_peint(ROUGE_GREC, 0.7)
	var tranches := 16
	for k in tranches:
		var f := lerpf(0.1, 0.86, (k + 0.5) / tranches)
		var largeur := 2.0 * large * pow(sin(f * PI), 0.45) * 1.03
		var long_tranche := longueur * 0.76 / tranches + 0.02
		var z := lerpf(-demi, demi, f)
		_boite(Vector3(largeur, 0.95, long_tranche), Vector3(0, 1.72, z), caisse, t, false)
		_boite(Vector3(largeur + 0.1, 0.12, long_tranche), Vector3(0, 2.2, z), bande, t, false)
	# Le pont : on peut y marcher.
	_boite(Vector3(large * 1.5, 0.1, longueur * 0.72), Vector3(0, 2.3, -0.5), _mat_bois(), t, false)
	# L'éperon de bronze, à fleur d'eau, et les yeux peints de la proue.
	var eperon := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.45
	cone.height = 2.6
	cone.radial_segments = 4
	eperon.mesh = cone
	eperon.material_override = _mat_bronze()
	eperon.rotation.x = -PI / 2
	eperon.position = Vector3(0, 0.35, -demi - 0.9)
	t.add_child(eperon)
	for cote: float in [-1.0, 1.0]:
		var oeil := MeshInstance3D.new()
		var disque := CylinderMesh.new()
		disque.top_radius = 0.38
		disque.bottom_radius = 0.38
		disque.height = 0.04
		oeil.mesh = disque
		oeil.material_override = _mat_peint(Color(0.92, 0.9, 0.84))
		oeil.rotation.z = PI / 2
		oeil.position = Vector3(cote * 0.62, 1.55, -demi + 2.4)
		t.add_child(oeil)
		var pupille := MeshInstance3D.new()
		var d2 := CylinderMesh.new()
		d2.top_radius = 0.18
		d2.bottom_radius = 0.18
		d2.height = 0.05
		pupille.mesh = d2
		pupille.material_override = _mat_peint(Color(0.05, 0.05, 0.06))
		pupille.rotation.z = PI / 2
		pupille.position = Vector3(cote * 0.64, 1.55, -demi + 2.35)
		t.add_child(pupille)
	# La poupe recourbée.
	var queue := MeshInstance3D.new()
	queue.mesh = _cylindre(0.12, 0.3, 3.2, 8)
	queue.material_override = _mat_peint(NOIR_POIX, 0.55)
	queue.position = Vector3(0, 4.6, demi - 0.6)
	queue.rotation.x = -0.55
	t.add_child(queue)
	# Les deux rames-gouvernails, à l'arrière.
	for cote: float in [-1.0, 1.0]:
		var gouvernail := MeshInstance3D.new()
		gouvernail.mesh = _cylindre(0.07, 0.07, 6.0, 6)
		gouvernail.material_override = _mat_bois()
		gouvernail.position = Vector3(cote * 2.1, 1.0, demi - 3.0)
		gouvernail.rotation = Vector3(-0.9, 0, cote * 0.3)
		t.add_child(gouvernail)
	# Les rames : trois rangs de chaque côté (on en montre 3 × 22, une sur trois en vrai).
	var rames: Array = []
	if avec_rames:
		var bois := _mat_choix(["rough_wood"], Color(0.66, 0.54, 0.38), 0.9, 1.0)
		var maillage := _cylindre(0.035, 0.05, 4.4, 5)
		for rang in 3:
			for k in 22:
				for cote: float in [-1.0, 1.0]:
					var pivot := Node3D.new()
					pivot.position = Vector3(cote * (large + 0.05 + rang * 0.12), 0.95 + rang * 0.42, -demi * 0.62 + k * 1.0 + rang * 0.33)
					t.add_child(pivot)
					var rame := MeshInstance3D.new()
					rame.mesh = maillage
					rame.material_override = bois
					rame.rotation.z = cote * (1.0 + rang * 0.12)
					rame.position = Vector3(cote * 2.0, -0.8 - rang * 0.1, 0)
					pivot.add_child(rame)
					pivot.set_meta("cote", cote)
					rames.append(pivot)
	t.set_meta("rames", rames)
	return t


# --- Arbres de l'Attique -----------------------------------------------------------------------

## Une fumée grise qui monte doucement (four, autel, forge).
func _fumee(parent: Node3D, p: Vector3) -> void:
	var fumee := GPUParticles3D.new()
	fumee.amount = 24
	fumee.lifetime = 6.0
	fumee.position = p
	var processus := ParticleProcessMaterial.new()
	processus.direction = Vector3(0.2, 1, 0)
	processus.spread = 12.0
	processus.initial_velocity_min = 0.5
	processus.initial_velocity_max = 0.9
	processus.gravity = Vector3(0.15, 0.1, 0)
	processus.scale_min = 0.6
	processus.scale_max = 1.4
	var courbe := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(1, 1.6))
	courbe.curve = c
	processus.scale_curve = courbe
	fumee.process_material = processus
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.53, 0.5, 0.25)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = _texture_flamme()
	quad.material = m
	fumee.draw_pass_1 = quad
	parent.add_child(fumee)


## Un olivier : un tronc court et tordu, gris, et une couronne de feuillage gris-vert.
func _olivier(parent: Node3D, p: Vector2, hasard: RandomNumberGenerator, taille := 1.0) -> Node3D:
	var ecorce := _mat_choix(["tree_bark_03", "bark_willow_02", "rough_wood"], Color(0.5, 0.47, 0.42), 0.95, 0.8)
	return _arbre_realiste(parent, p, "olivier", hasard, taille, ecorce)


## Un cyprès : une flamme vert sombre, haute et fine.
func _cypres(parent: Node3D, p: Vector2, hasard: RandomNumberGenerator) -> void:
	var ecorce := _mat_choix(["tree_bark_03", "bark_willow_02", "rough_wood"], Color(0.42, 0.36, 0.3), 0.95, 0.8)
	_arbre_realiste(parent, p, "cypres", hasard, 1.0, ecorce)


func _mat_feuillage(couleur: Color) -> StandardMaterial3D:
	var cle := "feuillage_%s" % couleur.to_html()
	if not _materiaux.has(cle):
		var m := StandardMaterial3D.new()
		m.albedo_color = couleur
		m.roughness = 0.95
		# Le relief des feuilles : une carte de bruit en guise de normales.
		var bruit := NoiseTexture2D.new()
		bruit.width = 128
		bruit.height = 128
		bruit.seamless = true
		bruit.as_normal_map = true
		bruit.bump_strength = 6.0
		var n := FastNoiseLite.new()
		n.frequency = 0.2
		bruit.noise = n
		m.normal_enabled = true
		m.normal_texture = bruit
		m.uv1_scale = Vector3(3, 3, 3)
		m.backlight_enabled = true
		m.backlight = Color(0.2, 0.24, 0.12)
		_materiaux[cle] = m
	return _materiaux[cle]


# --- L'eau profonde ----------------------------------------------------------------------------

## Le joueur n'a plus pied : on le remet sur la terre ferme (on ne nage pas encore).
var _dernier_sol_sur := Vector3.INF
var _attente_eau := 0.0
## Profondeur d'eau au-delà de laquelle on est ramené au bord.
var profondeur_max := 1.25


func _surveiller_eau_profonde(delta: float) -> void:
	_attente_eau -= delta
	if _attente_eau > 0.0:
		return
	_attente_eau = 0.2
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	if joueur == null or joueur.has_meta("a_bord"):
		return
	var p := joueur.global_position
	var fond := hauteur(p.x, p.z)
	if fond > NIVEAU_MER - profondeur_max:
		if fond > NIVEAU_MER - 0.6:
			_dernier_sol_sur = p
		return
	if _dernier_sol_sur == Vector3.INF:
		return
	if joueur.has_method("teleporter"):
		joueur.teleporter(_dernier_sol_sur + Vector3(0, 0.3, 0), joueur.rotation.y)
	var quete := get_tree().get_first_node_in_group("quete")
	if quete != null and quete.has_method("_annoncer"):
		quete._annoncer("Trop profond", "Tu n'as plus pied : tu regagnes la rive.")


func _process(delta: float) -> void:
	super._process(delta)
	if not Engine.is_editor_hint():
		_surveiller_eau_profonde(delta)


## Regroupe toutes les boîtes d'un dossier en un seul maillage par matériau : des
## centaines de maisons s'affichent alors aussi vite qu'une seule. Les collisions restent.
func _fusionner(dossier: Node3D) -> void:
	var outils := {}
	for n in dossier.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.material_override == null:
			continue
		var t := Transform3D.IDENTITY
		var noeud: Node = mi
		while noeud != null and noeud != dossier:
			if noeud is Node3D:
				t = (noeud as Node3D).transform * t
			noeud = noeud.get_parent()
		var m := mi.material_override
		if not outils.has(m):
			var outil := SurfaceTool.new()
			outil.begin(Mesh.PRIMITIVE_TRIANGLES)
			outils[m] = outil
		(outils[m] as SurfaceTool).append_from(mi.mesh, 0, t)
		mi.mesh = null
	for m in outils:
		var fusion := MeshInstance3D.new()
		fusion.mesh = (outils[m] as SurfaceTool).commit()
		fusion.material_override = m
		dossier.add_child(fusion)


## Buisson bas de l'île (couvre-sol, voir ile_prehistoire._construire_couvre_sol).
func _essence_buisson() -> String:
	return "buisson"


func _teinte_litiere() -> Color:
	return Color(1.0, 0.95, 0.85)
