@tool
extends "res://scripts/monde/chine/ile_chine.gd"
## Base commune des zones de l'île du Moyen Âge (la Beauce, les carrières de Berchères,
## Chartres, le chantier de la cathédrale, la crypte…).
##
## L'été 1194, quelques semaines après l'incendie de Chartres. On réutilise ce qui sert déjà
## ailleurs (charrettes, meules de paille, rochers, arbres réalistes) et on y ajoute ce qui est
## propre au Moyen Âge de la Beauce : les maisons à pans de bois et torchis, les chaumières
## de pierre, l'église de village et son clocher, le moulin à vent sur pivot, les dolmens au
## bord des champs, le gibet, les champs de blé mûr et les gerbes.
##
## Les textures Poly Haven du Moyen Âge iront dans assets/moyen_age/ ; en attendant, on prend
## celles des autres îles (torchis, chaume, pierre, bois).

const DOSSIER_MOYEN_AGE := "res://assets/moyen_age/"

## L'or du blé mûr, la pierre blonde de Berchères, le bois de chêne des colombages.
const OR_BLE := Color(0.86, 0.7, 0.36)
const PIERRE_BLONDE := Color(0.84, 0.77, 0.62)
const CHENE_SOMBRE := Color(0.24, 0.17, 0.11)
## Les couleurs vives des habits (on évite le Moyen Âge tout gris).
const TEINTURES := [Color(0.62, 0.14, 0.1), Color(0.18, 0.3, 0.56), Color(0.32, 0.46, 0.22),
		Color(0.78, 0.6, 0.24), Color(0.5, 0.28, 0.42), Color(0.82, 0.78, 0.68)]


# --- Ressources : d'abord le Moyen Âge, puis la Chine, Rome, la Grèce, l'Égypte… ----------------

## Pas de mer au Moyen Âge (la Beauce, les carrières, Chartres) : le fond d'une
## carrière est sous le « niveau de la mer » de la Grèce, il ne faut pas renvoyer le
## joueur « sur la rive ».
func _surveiller_eau_profonde(_delta: float) -> void:
	pass


## Le plan lointain (la plaine jusqu'à l'horizon), mais seulement AUTOUR du terrain de la
## zone : un plan plein cacherait tout ce qui descend plus bas que lui (le fond de la
## carrière de Berchères, le lit de l'Eure à Chartres).
func _plan_lointain_autour(y: float, couleur: Color) -> void:
	var demi := taille_terrain * 0.5 - 3.0
	var loin := 2500.0
	for r in [Rect2(-loin, -loin, loin * 2.0, loin - demi), Rect2(-loin, demi, loin * 2.0, loin - demi),
			Rect2(-loin, -demi, loin - demi, demi * 2.0), Rect2(demi, -demi, loin - demi, demi * 2.0)]:
		var c: Vector2 = (r as Rect2).get_center()
		_plan_lointain(Vector3(c.x, y, c.y), (r as Rect2).size, couleur)


func _texture(id: String, carte: String) -> Texture2D:
	var chemin: String = DOSSIER_MOYEN_AGE + "textures/%s/%s_%s.jpg" % [id, id, carte]
	if ResourceLoader.exists(chemin):
		return load(chemin)
	return super._texture(id, carte)


# --- Matériaux ---------------------------------------------------------------------------------

## Le calcaire blond des carrières de Berchères, taillé en moellons.
func _mat_calcaire() -> StandardMaterial3D:
	var cle := "calcaire_berchères"
	if not _materiaux.has(cle):
		var m := _mat_choix(["old_stone_wall", "stacked_stone_wall", "white_sandstone_blocks_02"], PIERRE_BLONDE, 0.92, 2.2).duplicate()
		_materiaux[cle] = m
	return _materiaux[cle]


## Le bois de chêne des colombages, sombre, passé à l'huile.
func _mat_colombage() -> StandardMaterial3D:
	var cle := "colombage"
	if not _materiaux.has(cle):
		var m := _mat_choix(["dark_wooden_planks", "rough_wood", "weathered_planks"], Color(0.42, 0.32, 0.24), 0.85, 1.2).duplicate()
		m.albedo_color = m.albedo_color * Color(0.7, 0.66, 0.62)
		_materiaux[cle] = m
	return _materiaux[cle]


## Le torchis blanchi à la chaux, entre les pièces de bois.
func _mat_torchis_chaux() -> StandardMaterial3D:
	var cle := "torchis_chaux"
	if not _materiaux.has(cle):
		var m := _mat_choix(["white_plaster_rough_01", "white_rough_plaster", "clay_plaster"], Color(0.9, 0.86, 0.76), 0.95, 2.0).duplicate()
		_materiaux[cle] = m
	return _materiaux[cle]


## Le chaume épais des toits de Beauce (paille de seigle).
func _mat_chaume_beauce() -> StandardMaterial3D:
	var cle := "chaume_beauce"
	if not _materiaux.has(cle):
		var m := _mat_choix(["reed_roof_04", "riet_01"], Color(0.7, 0.6, 0.42), 0.98, 1.2).duplicate()
		_materiaux[cle] = m
	return _materiaux[cle]


## Les petites tuiles plates de terre cuite (les maisons des plus riches, l'église).
func _mat_tuiles_plates() -> StandardMaterial3D:
	var cle := "tuiles_plates"
	if not _materiaux.has(cle):
		var m := _mat_choix(["clay_roof_tiles_02"], Color(0.62, 0.36, 0.26), 0.85, 1.0).duplicate()
		m.albedo_color = m.albedo_color * Color(0.85, 0.8, 0.8)
		_materiaux[cle] = m
	return _materiaux[cle]


func _mat_uni_ma(couleur: Color, rugosite := 0.85) -> StandardMaterial3D:
	var cle := "uni_%s_%.2f" % [couleur.to_html(), rugosite]
	if not _materiaux.has(cle):
		var m := StandardMaterial3D.new()
		m.albedo_color = couleur
		m.roughness = rugosite
		_materiaux[cle] = m
	return _materiaux[cle]


# --- Toits ---------------------------------------------------------------------------------------

## Un toit à deux pans très pentus (le chaume ou les tuiles plates de la France du Nord),
## avec ses pignons. « centre » = milieu du haut des murs.
func _toit_pentu(parent: Node3D, centre: Vector3, largeur: float, longueur: float, materiau: Material,
		pignon: Material, pente := 0.9, epaisseur := 0.3) -> float:
	var demi := largeur * 0.5 + 0.4
	var haut := demi * tan(pente)
	for cote: float in [-1.0, 1.0]:
		var pan := _boite(Vector3(demi / cos(pente) + 0.1, epaisseur, longueur + 0.7),
				centre + Vector3(cote * demi * 0.5, haut * 0.5, 0), materiau, parent, false)
		pan.rotation.z = -cote * pente
	for bout: float in [-1.0, 1.0]:
		var p := MeshInstance3D.new()
		var prisme := PrismMesh.new()
		prisme.size = Vector3(largeur, haut - 0.1, 0.22)
		p.mesh = prisme
		p.material_override = pignon
		p.position = centre + Vector3(0, (haut - 0.1) * 0.5, bout * longueur * 0.5)
		parent.add_child(p)
	# Le faîtage.
	_boite(Vector3(0.36, 0.3, longueur + 0.8), centre + Vector3(0, haut + 0.05, 0), materiau, parent, false)
	return haut


# --- Bâtiments --------------------------------------------------------------------------------

## Une maison à pans de bois : un socle de pierre, des murs de torchis blanc tenus par des
## poteaux, des sablières et des croix de Saint-André en chêne sombre, un toit très pentu.
## taille.x = largeur (pignon), taille.z = longueur (façade), taille.y = hauteur des murs.
func _maison_pans_de_bois(parent: Node3D, centre: Vector2, taille: Vector3, angle := 0.0, chaume := true) -> Node3D:
	var m := Node3D.new()
	m.name = "MaisonPansDeBois%d" % parent.get_child_count()
	m.position = Vector3(centre.x, hauteur(centre.x, centre.y) - 0.25, centre.y)
	m.rotation.y = angle
	parent.add_child(m)
	var bois := _mat_colombage()
	var socle := 0.7
	_boite(Vector3(taille.x + 0.2, socle, taille.z + 0.2), Vector3(0, socle * 0.5, 0), _mat_calcaire(), m)
	var h := taille.y - socle
	_boite(Vector3(taille.x, h, taille.z), Vector3(0, socle + h * 0.5, 0), _mat_torchis_chaux(), m, true)
	# Les pièces de bois, posées juste devant le torchis, sur les quatre faces.
	var e := 0.16
	for face in 4:
		var long_face := taille.z if face < 2 else taille.x
		var normale := Vector3(1, 0, 0) if face == 0 else (Vector3(-1, 0, 0) if face == 1 else (Vector3(0, 0, 1) if face == 2 else Vector3(0, 0, -1)))
		var dist := (taille.x if face < 2 else taille.z) * 0.5 + e * 0.3
		var le_long := Vector3(0, 0, 1) if face < 2 else Vector3(1, 0, 0)
		var base := normale * dist
		# Sablières basse et haute, et une lisse à mi-hauteur.
		for y in [socle + 0.08, socle + h * 0.52, socle + h - 0.08]:
			_boite(Vector3(e, 0.16, long_face) if face < 2 else Vector3(long_face, 0.16, e), base + Vector3(0, y, 0), bois, m, false)
		# Les poteaux, environ tous les 1,4 m, et une croix entre deux poteaux sur trois.
		var nb := maxi(2, int(long_face / 1.4))
		for k in nb + 1:
			var t := -long_face * 0.5 + k * long_face / nb
			_boite(Vector3(e, h, e), base + le_long * t + Vector3(0, socle + h * 0.5, 0), bois, m, false)
			if k < nb and k % 3 == 1:
				var milieu := base + le_long * (t + long_face / nb * 0.5)
				var pas := long_face / nb
				var diag := sqrt(pas * pas + (h * 0.48) * (h * 0.48))
				var inclinaison := atan2(h * 0.48, pas)
				for sens: float in [-1.0, 1.0]:
					var croix := _boite(Vector3(e * 0.8, diag, e * 0.8), milieu + Vector3(0, socle + h * 0.26, 0), bois, m, false)
					if face < 2:
						croix.rotation.x = sens * (PI / 2 - inclinaison)
					else:
						croix.rotation.z = sens * (PI / 2 - inclinaison)
	# La porte (planches) et deux petites fenêtres à volets, sur la façade (+z).
	var sombre := _mat_uni_ma(Color(0.05, 0.04, 0.035), 1.0)
	_boite(Vector3(1.0, 1.9, 0.06), Vector3(-taille.x * 0.15, socle + 0.95, taille.z * 0.5 + 0.06), bois, m, false)
	for fx: float in [0.2, 0.38]:
		_boite(Vector3(0.6, 0.55, 0.05), Vector3(taille.x * fx, socle + h * 0.7, taille.z * 0.5 + 0.06), sombre, m, false)
		_boite(Vector3(0.32, 0.6, 0.05), Vector3(taille.x * fx - 0.48, socle + h * 0.7, taille.z * 0.5 + 0.08), bois, m, false)
	# Le toit pentu, tourné pour que le faîtage suive la longueur.
	var toit := Node3D.new()
	toit.position = Vector3(0, taille.y, 0)
	m.add_child(toit)
	_toit_pentu(toit, Vector3.ZERO, taille.x, taille.z, _mat_chaume_beauce() if chaume else _mat_tuiles_plates(),
			_mat_torchis_chaux(), 0.95 if chaume else 0.85, 0.42 if chaume else 0.16)
	return m


## Une chaumière de paysan : murs bas de moellons, un gros toit de chaume qui descend presque
## jusqu'au sol, une seule porte.
func _chaumiere(parent: Node3D, centre: Vector2, taille: Vector3, angle := 0.0) -> Node3D:
	var m := Node3D.new()
	m.name = "Chaumiere%d" % parent.get_child_count()
	m.position = Vector3(centre.x, hauteur(centre.x, centre.y) - 0.25, centre.y)
	m.rotation.y = angle
	parent.add_child(m)
	_boite(Vector3(taille.x, taille.y, taille.z), Vector3(0, taille.y * 0.5, 0), _mat_calcaire(), m)
	var toit := Node3D.new()
	toit.position = Vector3(0, taille.y - 0.3, 0)
	m.add_child(toit)
	_toit_pentu(toit, Vector3.ZERO, taille.x + 0.6, taille.z, _mat_chaume_beauce(), _mat_calcaire(), 0.92, 0.5)
	_boite(Vector3(0.95, 1.7, 0.08), Vector3(0.4, 0.85, taille.z * 0.5 + 0.03), _mat_colombage(), m, false)
	return m


## L'église du village : une nef de pierre, un chœur arrondi (l'abside) à l'est, un clocher
## carré coiffé d'une flèche d'ardoise du côté ouest, des fenêtres étroites en plein cintre.
## L'entrée (le portail) regarde vers « angle » + PI (l'ouest si angle = 0).
func _eglise_village(parent: Node3D, centre: Vector2, angle := 0.0) -> Node3D:
	var m := Node3D.new()
	m.name = "EgliseVillage"
	m.position = Vector3(centre.x, hauteur(centre.x, centre.y) - 0.3, centre.y)
	m.rotation.y = angle
	parent.add_child(m)
	var pierre := _mat_calcaire()
	var nef := Vector3(16.0, 7.0, 8.0)
	_boite(Vector3(nef.x, nef.y, nef.z), Vector3(0, nef.y * 0.5, 0), pierre, m)
	# Les contreforts.
	for k in 4:
		for cote: float in [-1.0, 1.0]:
			_boite(Vector3(0.8, nef.y * 0.8, 0.7), Vector3(-6.0 + k * 4.0, nef.y * 0.4, cote * (nef.z * 0.5 + 0.35)), pierre, m)
	var abside := MeshInstance3D.new()
	abside.mesh = _cylindre(3.6, 3.6, 6.0, 16)
	abside.material_override = pierre
	abside.position = Vector3(nef.x * 0.5, 3.0, 0)
	m.add_child(abside)
	var cone := MeshInstance3D.new()
	cone.mesh = _cylindre(0.2, 4.0, 2.6, 16)
	cone.material_override = _mat_tuiles_plates()
	cone.position = Vector3(nef.x * 0.5, 7.3, 0)
	m.add_child(cone)
	var toit := Node3D.new()
	toit.position = Vector3(0, nef.y, 0)
	toit.rotation.y = PI / 2
	m.add_child(toit)
	_toit_pentu(toit, Vector3.ZERO, nef.z, nef.x, _mat_tuiles_plates(), pierre, 0.8, 0.2)
	# Le clocher : une tour carrée et sa flèche (une pyramide à quatre pans).
	var tour := Vector3(5.0, 14.0, 5.0)
	_boite(tour, Vector3(-nef.x * 0.5 - tour.x * 0.5 + 0.4, tour.y * 0.5, 0), pierre, m)
	var fleche := MeshInstance3D.new()
	fleche.mesh = _cylindre(0.05, 3.7, 9.0, 4)
	fleche.material_override = _mat_uni_ma(Color(0.26, 0.28, 0.32), 0.6)
	fleche.position = Vector3(-nef.x * 0.5 - tour.x * 0.5 + 0.4, tour.y + 4.5, 0)
	fleche.rotation.y = PI / 4
	m.add_child(fleche)
	# Les baies du clocher et les fenêtres de la nef (sombres).
	var sombre := _mat_uni_ma(Color(0.04, 0.035, 0.04), 1.0)
	for cote: float in [-1.0, 1.0]:
		for k in 3:
			_boite(Vector3(0.7, 2.0, 0.1), Vector3(-4.0 + k * 4.0, 4.2, cote * (nef.z * 0.5 + 0.02)), sombre, m, false)
		_boite(Vector3(0.1, 1.8, 0.8), Vector3(-nef.x * 0.5 - tour.x * 0.5 + 0.4 + cote * (tour.x * 0.5 + 0.02), 11.5, 0), sombre, m, false)
	# Le portail, sous le clocher.
	_boite(Vector3(0.12, 3.0, 1.8), Vector3(-nef.x * 0.5 - tour.x + 0.36, 1.5, 0), _mat_colombage(), m, false)
	return m


## Un moulin à vent sur pivot (un « moulin chandelier ») : une cabane de planches posée sur
## un gros pivot de chêne, que le meunier tourne face au vent avec la longue queue ; quatre
## ailes de toile sur des lattes. Les ailes sont dans le nœud « Ailes » (pour les faire tourner).
func _moulin_a_vent(parent: Node3D, p: Vector2, angle := 0.0) -> Node3D:
	var m := Node3D.new()
	m.name = "MoulinAVent"
	m.position = Vector3(p.x, hauteur(p.x, p.y) - 0.2, p.y)
	m.rotation.y = angle
	parent.add_child(m)
	var bois := _mat_colombage()
	var planches := _mat_choix(["weathered_planks", "wooden_rough_planks", "wood_planks"], Color(0.56, 0.46, 0.34), 0.9, 1.2)
	# Le piètement : deux poutres en croix sur des dés de pierre, et le pivot.
	for r in [0.0, PI / 2]:
		var poutre := _boite(Vector3(7.0, 0.5, 0.5), Vector3(0, 0.5, 0), bois, m)
		poutre.rotation.y = r
	for k in 4:
		var a := k * PI / 2
		_boite(Vector3(0.9, 0.6, 0.9), Vector3(cos(a) * 3.2, 0.3, sin(a) * 3.2), _mat_calcaire(), m)
		var jambe := _boite(Vector3(0.3, 3.6, 0.3), Vector3(cos(a) * 1.6, 2.0, sin(a) * 1.6), bois, m, false)
		jambe.rotation = Vector3(sin(a) * 0.6, 0, -cos(a) * 0.6)
	var pivot := MeshInstance3D.new()
	pivot.mesh = _cylindre(0.4, 0.45, 4.5, 10)
	pivot.material_override = bois
	pivot.position = Vector3(0, 2.25, 0)
	m.add_child(pivot)
	# La cabane.
	_boite(Vector3(4.2, 5.0, 3.4), Vector3(0, 6.9, 0), planches, m)
	var toit := Node3D.new()
	toit.position = Vector3(0, 9.4, 0)
	m.add_child(toit)
	_toit_pentu(toit, Vector3.ZERO, 3.4, 4.2, planches, planches, 0.55, 0.14)
	# L'échelle et la queue (vers l'arrière, -z).
	var queue := _boite(Vector3(0.24, 0.24, 7.0), Vector3(0, 3.0, -4.6), bois, m, false)
	queue.rotation.x = -0.42
	for k in 9:
		_boite(Vector3(0.9, 0.08, 0.14), Vector3(0, 0.5 + k * 0.48, -2.0 - k * 0.22), bois, m, false)
	# Les ailes, sur l'arbre qui sort à l'avant (+z).
	var ailes := Node3D.new()
	ailes.name = "Ailes"
	ailes.position = Vector3(0, 8.0, 2.1)
	m.add_child(ailes)
	var toile := _mat_uni_ma(Color(0.84, 0.8, 0.7), 1.0)
	var toile2 := toile.duplicate() as StandardMaterial3D
	toile2.cull_mode = BaseMaterial3D.CULL_DISABLED
	var moyeu := MeshInstance3D.new()
	moyeu.mesh = _cylindre(0.3, 0.3, 0.6, 8)
	moyeu.material_override = bois
	moyeu.rotation.x = PI / 2
	ailes.add_child(moyeu)
	for k in 4:
		var bras := Node3D.new()
		bras.rotation.z = k * PI / 2 + 0.3
		ailes.add_child(bras)
		_boite(Vector3(0.22, 8.4, 0.18), Vector3(0, 4.2, 0.2), bois, bras, false)
		var voile := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.6, 6.4)
		voile.mesh = q
		voile.material_override = toile2
		voile.position = Vector3(0.9, 5.0, 0.26)
		bras.add_child(voile)
		for t in 7:
			_boite(Vector3(1.8, 0.06, 0.06), Vector3(0.9, 2.0 + t, 0.22), bois, bras, false)
	return m


## Un dolmen au bord d'un champ : trois pierres dressées et une grande table posée dessus.
func _dolmen(parent: Node3D, p: Vector2, angle := 0.0) -> Node3D:
	var m := Node3D.new()
	m.name = "Dolmen"
	m.position = Vector3(p.x, hauteur(p.x, p.y) - 0.3, p.y)
	m.rotation.y = angle
	m.scale = Vector3.ONE * 1.7
	parent.add_child(m)
	var roche := _mat_choix(["rock_boulder_dry", "rock_wall_10", "cliff_side"], Color(0.6, 0.58, 0.54), 0.95, 1.5)
	for d in [[Vector3(-1.4, 0.9, -0.6), Vector3(0.6, 1.9, 1.8), 0.08], [Vector3(1.4, 0.9, -0.4), Vector3(0.6, 1.8, 2.0), -0.06],
			[Vector3(0.0, 0.9, -1.5), Vector3(2.4, 1.8, 0.5), 0.03]]:
		var pierre := _boite(d[1], d[0], roche, m)
		pierre.rotation.z = d[2]
	var table := _boite(Vector3(4.2, 0.7, 3.2), Vector3(0.1, 2.1, -0.4), roche, m)
	table.rotation = Vector3(0.05, 0.2, -0.04)
	return m


## Le gibet seigneurial, sur une butte : deux piliers de pierre et une poutre. (On n'y voit
## personne : on comprend.)
func _gibet(parent: Node3D, p: Vector2, angle := 0.0) -> Node3D:
	var m := Node3D.new()
	m.name = "Gibet"
	m.position = Vector3(p.x, hauteur(p.x, p.y) - 0.2, p.y)
	m.rotation.y = angle
	parent.add_child(m)
	_boite(Vector3(4.6, 0.6, 2.6), Vector3(0, 0.3, 0), _mat_calcaire(), m)
	for cote: float in [-1.0, 1.0]:
		_boite(Vector3(0.7, 4.6, 0.7), Vector3(cote * 1.8, 2.6, 0), _mat_calcaire(), m)
	_boite(Vector3(4.4, 0.35, 0.35), Vector3(0, 4.8, 0), _mat_colombage(), m, false)
	for k in 2:
		_boite(Vector3(0.04, 1.0, 0.04), Vector3(-0.8 + k * 1.6, 4.1, 0), _mat_uni_ma(Color(0.52, 0.44, 0.3), 1.0), m, false)
	return m


## Un puits de village : une margelle ronde de pierre, deux montants et un treuil.
func _puits(parent: Node3D, p: Vector2) -> Node3D:
	var m := Node3D.new()
	m.name = "Puits"
	m.position = Vector3(p.x, hauteur(p.x, p.y) - 0.1, p.y)
	parent.add_child(m)
	var margelle := MeshInstance3D.new()
	margelle.mesh = _cylindre(1.0, 1.05, 0.9, 14)
	margelle.material_override = _mat_calcaire()
	margelle.position = Vector3(0, 0.45, 0)
	m.add_child(margelle)
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.05
	cyl.height = 0.9
	forme.shape = cyl
	forme.position = Vector3(0, 0.45, 0)
	corps.add_child(forme)
	m.add_child(corps)
	var eau := MeshInstance3D.new()
	eau.mesh = _cylindre(0.85, 0.85, 0.02, 14)
	eau.material_override = _mat_uni_ma(Color(0.03, 0.04, 0.05), 0.1)
	eau.position = Vector3(0, 0.6, 0)
	m.add_child(eau)
	for cote: float in [-1.0, 1.0]:
		_boite(Vector3(0.16, 1.8, 0.16), Vector3(cote * 0.9, 1.6, 0), _mat_colombage(), m, false)
	var treuil := MeshInstance3D.new()
	treuil.mesh = _cylindre(0.12, 0.12, 1.8, 8)
	treuil.material_override = _mat_colombage()
	treuil.rotation.z = PI / 2
	treuil.position = Vector3(0, 2.3, 0)
	m.add_child(treuil)
	return m


## Une haie basse de prunelliers et d'aubépines le long d'une ligne (des buissons serrés).
func _haie(parent: Node3D, a: Vector2, b: Vector2, hasard: RandomNumberGenerator) -> void:
	var longueur := a.distance_to(b)
	var nb := int(longueur / 2.4)
	for k in nb:
		var p := a.lerp(b, (k + 0.5) / nb) + Vector2(hasard.randf_range(-0.5, 0.5), hasard.randf_range(-0.5, 0.5))
		_arbre_realiste(parent, p, "buisson", hasard, hasard.randf_range(0.8, 1.3), null, 0.1, false)


# --- Le blé ---------------------------------------------------------------------------------------

## Un champ de blé mûr : des milliers d'épis dorés (des touffes hautes, comme l'herbe, qui
## ondulent au vent). Seulement à l'écran : le serveur n'en a pas besoin. Les rectangles sont
## tournés de « angle » autour de leur centre.
func _champ_ble(parent: Node3D, r: Rect2, angle := 0.0, densite := 5.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var brin := _maillage_touffe()
	var materiau := ShaderMaterial.new()
	materiau.shader = SHADER_HERBE
	materiau.set_shader_parameter("couleur_base", Color(0.5, 0.4, 0.18))
	materiau.set_shader_parameter("couleur_pointe", Color(0.96, 0.8, 0.44))
	materiau.set_shader_parameter("couleur_givre", Color(0.9, 0.78, 0.48))
	materiau.set_shader_parameter("force_vent", 0.8)
	brin.surface_set_material(0, materiau)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(r)
	var centre := r.get_center()
	var base := Basis(Vector3.UP, angle)
	var facteur := minf(facteur_densite(), 2.2)
	# Par blocs de 16 m, pour que seuls les blocs proches soient dessinés.
	const BLOC := 16.0
	var bx := int(ceil(r.size.x / BLOC))
	var bz := int(ceil(r.size.y / BLOC))
	for j in bz:
		for i in bx:
			var transformations: Array[Transform3D] = []
			var w := minf(BLOC, r.size.x - i * BLOC)
			var d := minf(BLOC, r.size.y - j * BLOC)
			var nb := int(w * d * densite * facteur)
			for n in nb:
				var local := Vector3(r.position.x - centre.x + i * BLOC + hasard.randf() * w, 0,
						r.position.y - centre.y + j * BLOC + hasard.randf() * d)
				var q := base * local
				var x := centre.x + q.x
				var z := centre.y + q.z
				var s := hasard.randf_range(0.85, 1.15)
				transformations.append(Transform3D(Basis(Vector3.UP, hasard.randf() * TAU).scaled(Vector3(s * 0.8, s * 2.6, s * 0.8)),
						Vector3(x, hauteur(x, z) - 0.05, z)))
			if transformations.is_empty():
				continue
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.use_custom_data = true
			multi.mesh = brin
			multi.instance_count = transformations.size()
			for k in transformations.size():
				multi.set_instance_transform(k, transformations[k])
				multi.set_instance_custom_data(k, Color(hasard.randf(), 0, 0, 0))
			var instance := MultiMeshInstance3D.new()
			instance.name = "Ble"
			instance.multimesh = multi
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			instance.visibility_range_end = 90.0 + 15.0 * facteur
			instance.visibility_range_end_margin = 12.0
			instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			parent.add_child(instance)


## Des gerbes de blé dressées en « dizeaux » (dix gerbes appuyées les unes aux autres) sur
## un champ moissonné.
func _dizeau(parent: Node3D, p: Vector2, hasard: RandomNumberGenerator) -> void:
	var y := hauteur(p.x, p.y)
	var paille := _mat_uni_ma(OR_BLE, 0.95)
	for k in 6:
		var a := k * TAU / 6.0 + hasard.randf_range(-0.2, 0.2)
		var g := MeshInstance3D.new()
		g.mesh = _cylindre(0.12, 0.2, 1.2, 6)
		g.material_override = paille
		g.position = Vector3(p.x + cos(a) * 0.25, y + 0.55, p.y + sin(a) * 0.25)
		g.rotation = Vector3(-sin(a) * 0.3, 0, cos(a) * 0.3)
		parent.add_child(g)


# --- Végétation propre à la Beauce ----------------------------------------------------------------

func _essence_buisson() -> String:
	return "buisson"


func _teinte_litiere() -> Color:
	return Color(1.0, 0.95, 0.82)
