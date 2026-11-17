@tool
extends "res://scripts/monde/rome/ile_rome.gd"
## Base commune des zones de l'île de la Chine des Han (la Porte de Jade, le Fleuve
## Jaune et les terres de lœss, Luoyang, le mont Li…).
##
## L'hiver de l'an 105, sous l'empereur He. On réutilise ce qui sert déjà ailleurs
## (charrettes, amphores devenues jarres, rochers, ciels) et on y ajoute ce qui est
## propre à la Chine des Han : la terre damée (« hangtu ») des murailles et des tours,
## tassée couche par couche avec des lits de roseaux, les fanaux de la frontière et leurs
## meules de combustible, les tentes et les chameaux de Bactriane des caravanes, les
## ballots de soie, les peupliers de l'Euphrate et les tamaris du désert.
##
## Les textures Poly Haven de la Chine iront dans assets/chine/ ; en attendant, on prend
## celles de l'Égypte (terre crue, roseaux, sable) et de la Grèce.

const DOSSIER_CHINE := "res://assets/chine/"

## Le rouge des laques et des piliers, le noir des tuiles vernissées, l'ocre de la terre.
const ROUGE_LAQUE := Color(0.55, 0.1, 0.07)
const OCRE_LOESS := Color(0.78, 0.64, 0.44)
const SOIES := [Color(0.62, 0.12, 0.1), Color(0.86, 0.68, 0.22), Color(0.16, 0.34, 0.46),
		Color(0.32, 0.46, 0.24), Color(0.84, 0.8, 0.7), Color(0.4, 0.16, 0.36)]


# --- Ressources : d'abord la Chine, puis Rome, la Grèce, l'Égypte et la Préhistoire ----------

func _texture(id: String, carte: String) -> Texture2D:
	var chemin: String = DOSSIER_CHINE + "textures/%s/%s_%s.jpg" % [id, id, carte]
	if ResourceLoader.exists(chemin):
		return load(chemin)
	return super._texture(id, carte)


# --- Matériaux ---------------------------------------------------------------------------------

## La terre damée : de la terre et du gravier tassés au pilon, beige-ocre, à grain fin.
func _mat_terre_damee() -> StandardMaterial3D:
	var cle := "terre_damee"
	if not _materiaux.has(cle):
		var m := _mat_choix(["clay_block_wall", "clay_plaster", "mud_cracked_dry_03"], Color(0.82, 0.7, 0.54), 0.97, 2.4).duplicate()
		_materiaux[cle] = m
	return _materiaux[cle]


## Les lits de roseaux et de branches de tamaris pris dans la muraille (on les voit
## encore aujourd'hui à Dunhuang, gris et secs, tous les 20 à 30 cm).
func _mat_roseaux() -> StandardMaterial3D:
	var cle := "roseaux_muraille"
	if not _materiaux.has(cle):
		var m := _mat_choix(["riet_01", "reed_roof_04"], Color(0.66, 0.6, 0.46), 0.95, 0.8).duplicate()
		_materiaux[cle] = m
	return _materiaux[cle]


## La paille et les fagots des meules des fanaux.
func _mat_paille() -> StandardMaterial3D:
	var cle := "paille_fanal"
	if not _materiaux.has(cle):
		var m := _mat_choix(["reed_roof_04", "riet_01"], Color(0.78, 0.68, 0.44), 0.98, 1.4).duplicate()
		_materiaux[cle] = m
	return _materiaux[cle]


## Le feutre et la toile des tentes des caravanes.
func _mat_feutre(couleur := Color(0.72, 0.64, 0.52)) -> StandardMaterial3D:
	var cle := "feutre_%s" % couleur.to_html()
	if not _materiaux.has(cle):
		var m := StandardMaterial3D.new()
		m.albedo_color = couleur
		m.roughness = 1.0
		var bruit := NoiseTexture2D.new()
		bruit.width = 64
		bruit.height = 64
		bruit.seamless = true
		var n := FastNoiseLite.new()
		n.frequency = 0.2
		bruit.noise = n
		m.detail_enabled = true
		m.detail_albedo = bruit
		m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.8, 0.8, 0.8)
		_materiaux[cle] = m
	return _materiaux[cle]


## Une soie teinte, un peu brillante.
func _mat_soie(couleur: Color) -> StandardMaterial3D:
	var cle := "soie_%s" % couleur.to_html()
	if not _materiaux.has(cle):
		var m := StandardMaterial3D.new()
		m.albedo_color = couleur
		m.roughness = 0.45
		m.metallic_specular = 0.7
		m.anisotropy_enabled = true
		m.anisotropy = 0.6
		_materiaux[cle] = m
	return _materiaux[cle]


## Le pelage laineux, brun-fauve, d'un chameau de Bactriane en hiver.
func _mat_chameau() -> StandardMaterial3D:
	var cle := "chameau"
	if not _materiaux.has(cle):
		var m := _mat_feutre(Color(0.56, 0.42, 0.28)).duplicate()
		m.roughness = 1.0
		_materiaux[cle] = m
	return _materiaux[cle]


# --- Petites briques de construction -------------------------------------------------------------

## Une boîte tournée autour de la verticale (angle en radians), avec sa collision.
func _boite_orientee(taille: Vector3, centre: Vector3, angle: float, materiau: Material, parent: Node3D, collision := true) -> MeshInstance3D:
	var mi := _boite(taille, centre, materiau, parent, collision)
	mi.rotation.y = angle
	return mi


## La muraille des Han le long d'une ligne de points (x, z) : un mur de terre damée et de
## gravier, plus large en bas qu'en haut, avec ses lits de roseaux qui dépassent un peu.
## « breches » = indices des segments à laisser effondrés (un tas bas qu'on enjambe).
func _muraille_han(parent: Node3D, points: Array, haut := 3.8, epaisseur := 3.2, breches: Array = []) -> Node3D:
	var mur := Node3D.new()
	mur.name = "Muraille"
	parent.add_child(mur)
	var terre := _mat_terre_damee()
	var roseaux := _mat_roseaux()
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var longueur := a.distance_to(b)
		var angle := -atan2(b.y - a.y, b.x - a.x)
		# On découpe chaque côté en tronçons de 8 m qui suivent le relief.
		var n := maxi(1, int(ceil(longueur / 8.0)))
		for k in n:
			var c := a.lerp(b, (k + 0.5) / n)
			var y := hauteur(c.x, c.y)
			var l := longueur / n + 0.3
			if i in breches and k % 3 != 0:
				# Un pan effondré : un bourrelet de terre.
				_boite_orientee(Vector3(l, 1.0, epaisseur * 1.3), Vector3(c.x, y + 0.2, c.y), angle, terre, mur)
				continue
			var h := haut * (0.92 + 0.08 * sin(c.x * 0.37 + c.y * 0.21))
			# Le pied, plus large, puis le corps du mur.
			_boite_orientee(Vector3(l, h * 0.4, epaisseur), Vector3(c.x, y + h * 0.2 - 0.3, c.y), angle, terre, mur)
			_boite_orientee(Vector3(l, h * 0.65, epaisseur * 0.78), Vector3(c.x, y + h * 0.4 + h * 0.3, c.y), angle, terre, mur)
			# Les lits de roseaux, tous les 30 cm environ.
			var z := 0.35
			while z < h - 0.1:
				var e := epaisseur * (1.0 if z < h * 0.4 else 0.78) + 0.1
				_boite_orientee(Vector3(l, 0.07, e), Vector3(c.x, y - 0.3 + z, c.y), angle, roseaux, mur, false)
				z += 0.32
	return mur


## Une tour à fanal (« feng sui ») : une tour carrée de terre damée qui se rétrécit en
## montant, un petit parapet en haut, et le grand mât où l'on hisse les signaux.
func _tour_fanal(parent: Node3D, p: Vector2, haut := 8.0, cote := 7.0, ruine := false) -> Node3D:
	var tour := Node3D.new()
	tour.name = "TourFanal"
	tour.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
	parent.add_child(tour)
	var terre := _mat_terre_damee()
	var roseaux := _mat_roseaux()
	var etages := 4
	var h := haut * (0.6 if ruine else 1.0)
	for k in etages:
		var t := float(k) / etages
		var c := cote * (1.0 - 0.28 * t)
		var hauteur_etage := h / etages
		_boite(Vector3(c, hauteur_etage + 0.05, c), Vector3(0, hauteur_etage * (k + 0.5) - 0.2, 0), terre, tour)
		_boite(Vector3(c + 0.08, 0.08, c + 0.08), Vector3(0, hauteur_etage * (k + 1) - 0.25, 0), roseaux, tour, false)
	if ruine:
		# Le haut s'est effondré : des blocs de terre au pied.
		for k in 5:
			var a := k * 1.3
			_boite_orientee(Vector3(1.6, 0.9, 1.2), Vector3(cos(a) * cote * 0.8, 0.3, sin(a) * cote * 0.8), a, terre, tour)
		return tour
	# Le parapet à créneaux du sommet.
	var c_haut := cote * 0.72
	for cote_k in 4:
		var a := cote_k * PI * 0.5
		var dir := Vector3(cos(a), 0, sin(a))
		for m in 3:
			var long := (m - 1) * c_haut * 0.34
			var pos := dir * (c_haut * 0.5) + Vector3(-dir.z, 0, dir.x) * long
			_boite(Vector3(0.6 if absf(dir.z) > 0.5 else 0.35, 0.8, 0.35 if absf(dir.z) > 0.5 else 0.6), pos + Vector3(0, h + 0.15, 0), terre, tour, false)
	# Le mât du signal : un poteau, une traverse et le panier de branches.
	var bois := _mat_bois()
	var mat := MeshInstance3D.new()
	mat.mesh = _cylindre(0.09, 0.12, 6.0, 8)
	mat.material_override = bois
	mat.position = Vector3(c_haut * 0.3, h + 3.0, -c_haut * 0.3)
	tour.add_child(mat)
	_boite(Vector3(2.0, 0.1, 0.1), Vector3(c_haut * 0.3, h + 5.4, -c_haut * 0.3), bois, tour, false)
	var panier := MeshInstance3D.new()
	panier.mesh = _cylindre(0.35, 0.2, 0.5, 8)
	panier.material_override = _mat_paille()
	panier.position = Vector3(c_haut * 0.3 + 0.9, h + 5.0, -c_haut * 0.3)
	tour.add_child(panier)
	return tour


## Une meule de combustible des fanaux : un tas conique de roseaux, de branches et de
## crottin (on en a retrouvé des dizaines au pied des tours de Dunhuang).
func _meule(parent: Node3D, p: Vector2, taille := 1.0) -> MeshInstance3D:
	var meule := MeshInstance3D.new()
	meule.mesh = _cylindre(0.15 * taille, 1.3 * taille, 1.6 * taille, 10)
	meule.material_override = _mat_paille()
	meule.position = Vector3(p.x, hauteur(p.x, p.y) + 0.75 * taille, p.y)
	parent.add_child(meule)
	return meule


## Une tente de caravane : un toit de feutre à deux pans, sur deux perches.
func _tente(parent: Node3D, p: Vector2, angle := 0.0, couleur := Color(0.7, 0.62, 0.5), taille := 1.0) -> Node3D:
	var tente := Node3D.new()
	tente.name = "Tente"
	tente.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
	tente.rotation.y = angle
	parent.add_child(tente)
	var feutre := _mat_feutre(couleur)
	var l := 3.6 * taille
	var larg := 1.9 * taille
	var haut := 2.0 * taille
	for cote: float in [-1.0, 1.0]:
		var pan := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(l, 0.06, sqrt(larg * larg + haut * haut))
		pan.mesh = b
		pan.material_override = feutre
		pan.position = Vector3(0, haut * 0.5, cote * larg * 0.5)
		pan.rotation.x = cote * (PI * 0.5 - atan2(haut, larg))
		tente.add_child(pan)
	var bois := _mat_bois()
	for x: float in [-l * 0.5, l * 0.5]:
		var perche := MeshInstance3D.new()
		perche.mesh = _cylindre(0.04, 0.05, haut + 0.2, 6)
		perche.material_override = bois
		perche.position = Vector3(x, (haut + 0.2) * 0.5, 0)
		tente.add_child(perche)
	# Une collision simple pour qu'on ne traverse pas la tente.
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(l, haut, larg * 1.6)
	forme.shape = boite
	forme.position.y = haut * 0.5
	corps.add_child(forme)
	tente.add_child(corps)
	return tente


## Une pile de ballots de soie roulée, ficelés, de toutes les couleurs.
func _ballots_soie(parent: Node3D, p: Vector2, angle := 0.0, nombre := 6) -> Node3D:
	var pile := Node3D.new()
	pile.name = "BallotsSoie"
	pile.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
	pile.rotation.y = angle
	parent.add_child(pile)
	var hasard := RandomNumberGenerator.new()
	hasard.seed = int(p.x * 13.0 + p.y * 7.0)
	for k in nombre:
		var rang := k / 3
		var place := k % 3
		var rouleau := MeshInstance3D.new()
		rouleau.mesh = _cylindre(0.2, 0.2, 1.1, 10)
		rouleau.material_override = _mat_soie(SOIES[hasard.randi() % SOIES.size()])
		rouleau.rotation.z = PI * 0.5
		rouleau.position = Vector3(0, 0.2 + rang * 0.38, (place - 1) * 0.41 + rang * 0.2)
		pile.add_child(rouleau)
	return pile


## Un chameau de Bactriane (deux bosses), couché ou debout, sculpté en volumes simples.
## C'est un décor : il ne marche pas.
func _chameau(parent: Node3D, p: Vector2, angle := 0.0, couche := false, bat := true) -> Node3D:
	var chameau := Node3D.new()
	chameau.name = "Chameau%d" % parent.get_child_count()
	chameau.position = Vector3(p.x, hauteur(p.x, p.y), p.y)
	chameau.rotation.y = angle
	parent.add_child(chameau)
	var poil := _mat_chameau()
	var y_corps := 0.75 if couche else 1.75
	var sphere := func(rayon: float, haut: float, pos: Vector3, echelle := Vector3.ONE) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = rayon
		s.height = haut
		s.radial_segments = 14
		s.rings = 8
		mi.mesh = s
		mi.material_override = poil
		mi.position = pos
		mi.scale = echelle
		chameau.add_child(mi)
		return mi
	# Le corps, les deux bosses et la laine longue du cou.
	sphere.call(0.75, 1.3, Vector3(0, y_corps, 0), Vector3(1.55, 1.0, 1.0))
	sphere.call(0.42, 0.7, Vector3(-0.45, y_corps + 0.72, 0), Vector3(0.9, 1.15, 0.9))
	sphere.call(0.42, 0.7, Vector3(0.5, y_corps + 0.72, 0), Vector3(0.9, 1.15, 0.9))
	var cou := MeshInstance3D.new()
	cou.mesh = _cylindre(0.2, 0.3, 1.3, 10)
	cou.material_override = poil
	cou.position = Vector3(1.3, y_corps + 0.25, 0)
	cou.rotation.z = -0.75
	chameau.add_child(cou)
	sphere.call(0.28, 0.5, Vector3(1.4, y_corps - 0.05, 0), Vector3(1.0, 1.2, 1.1))
	var tete := sphere.call(0.2, 0.36, Vector3(1.85, y_corps + 0.72, 0), Vector3(1.8, 0.95, 0.9)) as MeshInstance3D
	tete.rotation.z = -0.2
	if couche:
		# Les pattes repliées sous le ventre.
		for x: float in [-0.7, 0.7]:
			for z: float in [-0.45, 0.45]:
				sphere.call(0.22, 0.4, Vector3(x, 0.18, z), Vector3(1.6, 0.8, 1.0))
	else:
		for x: float in [-0.75, 0.8]:
			for z: float in [-0.32, 0.32]:
				var patte := MeshInstance3D.new()
				patte.mesh = _cylindre(0.08, 0.12, 1.25, 8)
				patte.material_override = poil
				patte.position = Vector3(x, 0.62, z)
				chameau.add_child(patte)
	if bat:
		# Le bât de bois entre les bosses, et deux ballots de soie de part et d'autre.
		_boite(Vector3(0.5, 0.18, 1.5), Vector3(0.03, y_corps + 0.62, 0), _mat_bois(), chameau, false)
		for z: float in [-0.75, 0.75]:
			var ballot := MeshInstance3D.new()
			ballot.mesh = _cylindre(0.26, 0.26, 0.9, 10)
			ballot.material_override = _mat_feutre(Color(0.62, 0.52, 0.4))
			ballot.rotation.z = PI * 0.5
			ballot.position = Vector3(0.03, y_corps + 0.25, z)
			chameau.add_child(ballot)
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(2.4, y_corps + 0.6, 1.1)
	forme.shape = boite
	forme.position.y = (y_corps + 0.6) * 0.5
	corps.add_child(forme)
	chameau.add_child(corps)
	return chameau


## Un peuplier de l'Euphrate (« hu yang »), l'arbre des oasis du désert : un tronc
## noueux et penché, des branches tordues, et en hiver quelques feuilles d'or qui restent.
func _peuplier_desert(parent: Node3D, p: Vector2, hasard: RandomNumberGenerator, taille := 1.0) -> Node3D:
	var arbre := Node3D.new()
	arbre.name = "Peuplier"
	arbre.position = Vector3(p.x, hauteur(p.x, p.y) - 0.1, p.y)
	arbre.rotation.y = hasard.randf() * TAU
	parent.add_child(arbre)
	var ecorce := _mat_choix(["bark_brown_02", "pine_bark", "palm_tree_bark"], Color(0.5, 0.44, 0.38), 0.95, 1.2)
	var tronc := MeshInstance3D.new()
	tronc.mesh = _cylindre(0.26 * taille, 0.42 * taille, 3.2 * taille, 9)
	tronc.material_override = ecorce
	tronc.position.y = 1.5 * taille
	tronc.rotation.z = hasard.randf_range(-0.18, 0.18)
	arbre.add_child(tronc)
	var feuilles := _mat_feuillage(Color(0.72, 0.56, 0.16))
	for k in 5:
		var a := k * TAU / 5.0 + hasard.randf_range(-0.3, 0.3)
		var branche := MeshInstance3D.new()
		var l := hasard.randf_range(1.6, 2.6) * taille
		branche.mesh = _cylindre(0.06 * taille, 0.14 * taille, l, 6)
		branche.material_override = ecorce
		var dir := Vector3(cos(a), 1.1, sin(a)).normalized()
		branche.position = Vector3(0, 3.0 * taille, 0) + dir * l * 0.5
		branche.look_at_from_position(branche.position, branche.position + dir, Vector3.RIGHT)
		branche.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		arbre.add_child(branche)
		if hasard.randf() < 0.7:
			var touffe := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = hasard.randf_range(0.6, 0.95) * taille
			s.height = s.radius * 1.3
			s.radial_segments = 8
			s.rings = 4
			touffe.mesh = s
			touffe.material_override = feuilles
			touffe.position = Vector3(0, 3.0 * taille, 0) + dir * l
			arbre.add_child(touffe)
	return arbre


## Une touffe de tamaris : des tiges fines et serrées, brun-rouge en hiver.
func _tamaris(parent: Node3D, p: Vector2, hasard: RandomNumberGenerator, taille := 1.0) -> void:
	var touffe := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = hasard.randf_range(0.7, 1.2) * taille
	s.height = s.radius * 1.4
	s.radial_segments = 8
	s.rings = 5
	touffe.mesh = s
	touffe.material_override = _mat_feuillage(Color(0.44, 0.26, 0.2))
	touffe.position = Vector3(p.x, hauteur(p.x, p.y) + s.radius * 0.45, p.y)
	touffe.scale = Vector3(1.0, 0.8, 1.0)
	parent.add_child(touffe)


## Un fort carré de terre damée (comme le « petit fort » de la Porte de Jade, haut de
## près de 10 m) : quatre murs, un chemin de ronde, et des portes (côtés « ouest »,
## « nord », « est », « sud »).
func _fort_carre(parent: Node3D, r: Rect2, haut := 9.0, portes: Array = ["ouest"], largeur_porte := 3.6) -> Node3D:
	var fort := Node3D.new()
	fort.name = "Fort"
	parent.add_child(fort)
	var terre := _mat_terre_damee()
	var roseaux := _mat_roseaux()
	var y := hauteur(r.get_center().x, r.get_center().y)
	var e := 3.0
	var cotes := {
		"nord": [Vector2(r.get_center().x, r.position.y + e * 0.5), Vector2(r.size.x, e), true],
		"sud": [Vector2(r.get_center().x, r.end.y - e * 0.5), Vector2(r.size.x, e), true],
		"ouest": [Vector2(r.position.x + e * 0.5, r.get_center().y), Vector2(e, r.size.y - e * 2.0), false],
		"est": [Vector2(r.end.x - e * 0.5, r.get_center().y), Vector2(e, r.size.y - e * 2.0), false],
	}
	for nom in cotes:
		var c: Vector2 = cotes[nom][0]
		var t: Vector2 = cotes[nom][1]
		var horizontal: bool = cotes[nom][2]
		var morceaux := []
		if nom in portes:
			var long := t.x if horizontal else t.y
			var reste := (long - largeur_porte) * 0.5
			var decal := (largeur_porte + reste) * 0.5
			morceaux.append([c + (Vector2(-decal, 0) if horizontal else Vector2(0, -decal)), reste])
			morceaux.append([c + (Vector2(decal, 0) if horizontal else Vector2(0, decal)), reste])
			# Le linteau de bois au-dessus de la porte, et le mur au-dessus.
			var dessus := Vector3(largeur_porte if horizontal else e, haut - 4.2, e if horizontal else largeur_porte)
			_boite(dessus, Vector3(c.x, y + 4.2 + dessus.y * 0.5, c.y), terre, fort)
			_boite(Vector3(largeur_porte + 0.6 if horizontal else e + 0.2, 0.3, e + 0.2 if horizontal else largeur_porte + 0.6),
					Vector3(c.x, y + 4.1, c.y), _mat_bois(), fort, false)
		else:
			morceaux.append([c, t.x if horizontal else t.y])
		for m in morceaux:
			var mc: Vector2 = m[0]
			var ml: float = m[1]
			var taille := Vector3(ml, haut, e) if horizontal else Vector3(e, haut, ml)
			_boite(taille, Vector3(mc.x, y + haut * 0.5 - 0.2, mc.y), terre, fort)
			var z := 0.4
			while z < haut - 0.2:
				_boite(taille * Vector3(1.0, 0.0, 1.0) + Vector3(0.06 if not horizontal else 0.0, 0.07, 0.06 if horizontal else 0.0),
						Vector3(mc.x, y - 0.2 + z, mc.y), roseaux, fort, false)
				z += 0.4
	# Le parapet du chemin de ronde, tout autour.
	for k in 4:
		var horizontal := k < 2
		var c := Vector2(r.get_center().x, r.position.y if k == 0 else r.end.y) if horizontal \
				else Vector2(r.position.x if k == 2 else r.end.x, r.get_center().y)
		var taille := Vector3(r.size.x, 1.0, 0.5) if horizontal else Vector3(0.5, 1.0, r.size.y)
		_boite(taille, Vector3(c.x, y + haut + 0.3, c.y), terre, fort, false)
	return fort
