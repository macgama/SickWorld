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


# --- Les terres de lœss et les villages des Han (zone 2, et plus tard Luoyang) -----------------

## Les tuiles grises des Han, cuites en atmosphère réduite (gris-bleu, pas rouges comme
## en Grèce ou à Rome).
func _mat_tuiles_han() -> StandardMaterial3D:
	var cle := "tuiles_han"
	if not _materiaux.has(cle):
		var m := _mat_choix(["clay_roof_tiles_02"], Color(0.34, 0.36, 0.38), 0.85, 1.2).duplicate()
		_materiaux[cle] = m
	return _materiaux[cle]


## L'enduit de terre des maisons de village, plus clair que la terre damée des murailles.
func _mat_torchis() -> StandardMaterial3D:
	var cle := "torchis_han"
	if not _materiaux.has(cle):
		var m := _mat_choix(["clay_plaster", "patterned_clay_plaster"], Color(0.86, 0.76, 0.6), 0.95, 2.0).duplicate()
		_materiaux[cle] = m
	return _materiaux[cle]


## Le chaume de roseaux ou de paille de millet des remises et des cabanes.
func _mat_chaume() -> StandardMaterial3D:
	return _mat_paille()


## Une petite maison de village des Han : murs de terre sur un socle bas, poteaux de bois
## aux angles, toit de tuiles grises à deux pans qui déborde largement (ou de chaume).
func _maison_han(parent: Node3D, centre: Vector2, taille: Vector3, angle := 0.0, chaume := false) -> Node3D:
	var m := Node3D.new()
	m.name = "MaisonHan%d" % parent.get_child_count()
	m.position = Vector3(centre.x, hauteur(centre.x, centre.y) - 0.2, centre.y)
	m.rotation.y = angle
	parent.add_child(m)
	var bois := _mat_bois()
	_boite(Vector3(taille.x + 0.4, 0.45, taille.z + 0.4), Vector3(0, 0.22, 0), _mat_terre_damee(), m)
	_boite(Vector3(taille.x, taille.y, taille.z), Vector3(0, 0.45 + taille.y * 0.5, 0), _mat_torchis(), m)
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			var poteau := MeshInstance3D.new()
			poteau.mesh = _cylindre(0.12, 0.13, taille.y, 8)
			poteau.material_override = bois
			poteau.position = Vector3(sx * taille.x, 0.45 + taille.y * 0.5, sz * taille.z + sz * 0.04)
			m.add_child(poteau)
	# La poutre faîtière, et le toit qui déborde de 60 cm sur les murs.
	var largeur := taille.z + 1.2
	var pente := 0.42 if chaume else 0.36
	var demi := largeur * 0.5
	var haut := demi * tan(pente)
	var y0 := 0.45 + taille.y
	var couvert := _mat_chaume() if chaume else _mat_tuiles_han()
	for cote: float in [-1.0, 1.0]:
		var pan := _boite(Vector3(taille.x + 1.2, 0.2 if not chaume else 0.35, demi / cos(pente)),
				Vector3(0, y0 + haut * 0.5, cote * demi * 0.5), couvert, m, false)
		pan.rotation.x = cote * pente
	var pignon := PrismMesh.new()
	pignon.size = Vector3(taille.z, haut, taille.x - 0.1)
	var tri := MeshInstance3D.new()
	tri.mesh = pignon
	tri.material_override = _mat_torchis()
	tri.rotation.y = PI / 2
	tri.position = Vector3(0, y0 + haut * 0.5 - 0.05, 0)
	m.add_child(tri)
	if not chaume:
		# L'arête du toit, un rang de tuiles plus épais, relevé aux deux bouts.
		_boite(Vector3(taille.x + 1.4, 0.24, 0.32), Vector3(0, y0 + haut + 0.08, 0), couvert, m, false)
		for bout: float in [-1.0, 1.0]:
			var corne := _boite(Vector3(0.4, 0.22, 0.3), Vector3(bout * (taille.x * 0.5 + 0.75), y0 + haut + 0.2, 0), couvert, m, false)
			corne.rotation.z = bout * 0.5
	# La porte (une ouverture sombre et un battant de bois), et une fenêtre de papier treillissée.
	var noir := _mat_pbr("", Color(0.05, 0.04, 0.035), 1.0)
	var porte := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.9)
	porte.mesh = q
	porte.material_override = noir
	porte.position = Vector3(-taille.x * 0.2, 0.45 + 0.95, taille.z * 0.5 + 0.02)
	m.add_child(porte)
	_boite(Vector3(0.5, 1.9, 0.06), Vector3(-taille.x * 0.2 - 0.6, 0.45 + 0.95, taille.z * 0.5 + 0.12), bois, m, false).rotation.y = 0.9
	_fenetre_treillis(m, Vector3(taille.x * 0.22, 0.45 + 1.5, taille.z * 0.5 + 0.03), Vector2(1.1, 0.8))
	return m


## Une fenêtre carrée tendue de papier, derrière un treillis de bois.
func _fenetre_treillis(parent: Node3D, p: Vector3, taille: Vector2, angle := 0.0) -> void:
	var f := Node3D.new()
	f.position = p
	f.rotation.y = angle
	parent.add_child(f)
	var papier := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = taille
	papier.mesh = q
	papier.material_override = _mat_pbr("", Color(0.86, 0.8, 0.66), 0.9)
	f.add_child(papier)
	var bois := _mat_bois()
	var n := 4
	for k in n + 1:
		var t := -0.5 + float(k) / n
		_boite(Vector3(0.04, taille.y, 0.04), Vector3(t * taille.x, 0, 0.02), bois, f, false)
		_boite(Vector3(taille.x, 0.04, 0.04), Vector3(0, t * taille.y, 0.02), bois, f, false)


## La façade d'une maison-grotte (« yaodong ») creusée dans la falaise de lœss : une
## grande voûte en arc, fermée par un mur de terre percé d'une porte et d'une large
## fenêtre de papier en demi-lune. « p » est le pied de la façade, tournée vers +Z
## avant la rotation.
func _facade_yaodong(parent: Node3D, p: Vector3, angle := 0.0, largeur := 3.4) -> Node3D:
	var g := Node3D.new()
	g.name = "Yaodong%d" % parent.get_child_count()
	g.position = p
	g.rotation.y = angle
	parent.add_child(g)
	var rayon := largeur * 0.5
	var pied := 2.0
	# Le creux sombre de la voûte (le fond de la grotte), un peu en retrait dans la falaise.
	var noir := _mat_pbr("", Color(0.07, 0.055, 0.04), 1.0)
	_boite(Vector3(largeur, pied, 0.2), Vector3(0, pied * 0.5, -0.5), noir, g, false)
	var voute := MeshInstance3D.new()
	var demi := CylinderMesh.new()
	demi.top_radius = rayon
	demi.bottom_radius = rayon
	demi.height = 0.2
	demi.radial_segments = 20
	voute.mesh = demi
	voute.material_override = noir
	voute.rotation.x = PI / 2
	voute.position = Vector3(0, pied, -0.5)
	g.add_child(voute)
	# Le mur de façade en terre, avec la porte à gauche et la fenêtre en arc au-dessus.
	var torchis := _mat_torchis()
	_boite(Vector3(largeur - 0.1, 0.25, 0.5), Vector3(0, 0.12, -0.15), _mat_terre_damee(), g)
	_boite(Vector3(largeur * 0.42, pied - 0.1, 0.3), Vector3(rayon * 0.5, pied * 0.5, -0.3), torchis, g)
	_boite(Vector3(0.2, pied, 0.3), Vector3(-rayon + 0.1, pied * 0.5, -0.3), torchis, g)
	var bois := _mat_bois()
	_boite(Vector3(0.9, 1.9, 0.08), Vector3(-rayon * 0.42, 0.95, -0.22), bois, g, false)
	# La fenêtre en demi-lune : un éventail de papier sous la voûte.
	var papier := MeshInstance3D.new()
	var disque := CylinderMesh.new()
	disque.top_radius = rayon - 0.15
	disque.bottom_radius = rayon - 0.15
	disque.height = 0.05
	disque.radial_segments = 20
	papier.mesh = disque
	papier.material_override = _mat_pbr("", Color(0.85, 0.78, 0.62), 0.9)
	papier.rotation.x = PI / 2
	papier.position = Vector3(0, pied, -0.36)
	g.add_child(papier)
	for k in 7:
		var a := PI * (k + 1) / 8.0
		var baguette := _boite(Vector3(0.04, rayon - 0.15, 0.04), Vector3(cos(a) * (rayon - 0.15) * 0.5, pied + sin(a) * (rayon - 0.15) * 0.5, -0.32), bois, g, false)
		baguette.rotation.z = a - PI / 2
	_boite(Vector3(largeur - 0.3, 0.08, 0.06), Vector3(0, pied + 0.02, -0.3), bois, g, false)
	# Le rebord de briques crues autour de l'arc.
	var briques := _mat_terre_damee()
	for k in 9:
		var a := PI * k / 8.0
		var b := _boite(Vector3(0.35, 0.5, 0.3), Vector3(cos(a) * (rayon + 0.12), pied + sin(a) * (rayon + 0.12), -0.25), briques, g, false)
		b.rotation.z = a - PI / 2
	for cote: float in [-1.0, 1.0]:
		_boite(Vector3(0.35, pied, 0.3), Vector3(cote * (rayon + 0.12), pied * 0.5, -0.25), briques, g, false)
	return g


## Un mûrier taillé en têtard, nu en hiver : un tronc court et noueux, couronné de
## rejets droits (on les coupait chaque année pour les feuilles des vers à soie).
func _murier(parent: Node3D, p: Vector2, hasard: RandomNumberGenerator, taille := 1.0) -> Node3D:
	var a := Node3D.new()
	a.name = "Murier%d" % parent.get_child_count()
	a.position = Vector3(p.x, hauteur(p.x, p.y) - 0.05, p.y)
	a.rotation.y = hasard.randf() * TAU
	a.scale = Vector3.ONE * taille
	parent.add_child(a)
	var ecorce := _mat_choix(["bark_willow_02", "tree_bark_03"], Color(0.5, 0.45, 0.4), 0.95, 0.6)
	var tronc := MeshInstance3D.new()
	tronc.mesh = _cylindre(0.24, 0.3, 1.7, 8)
	tronc.material_override = ecorce
	tronc.position.y = 0.85
	tronc.rotation.z = hasard.randf_range(-0.08, 0.08)
	a.add_child(tronc)
	var tete := MeshInstance3D.new()
	var boule := SphereMesh.new()
	boule.radius = 0.36
	boule.height = 0.55
	boule.radial_segments = 8
	boule.rings = 4
	tete.mesh = boule
	tete.material_override = ecorce
	tete.position.y = 1.75
	a.add_child(tete)
	var rameau := _cylindre(0.015, 0.045, 1.0, 4)
	for k in hasard.randi_range(9, 14):
		var r := MeshInstance3D.new()
		r.mesh = rameau
		r.material_override = ecorce
		var ang := hasard.randf() * TAU
		var inc := hasard.randf_range(0.15, 0.6)
		var l := hasard.randf_range(1.0, 2.0)
		r.scale = Vector3(1, l, 1)
		r.position = Vector3(cos(ang) * 0.2, 1.8, sin(ang) * 0.2) + Vector3(cos(ang) * sin(inc), cos(inc), sin(ang) * sin(inc)) * l * 0.5
		r.rotation = Vector3(sin(ang) * inc, 0, -cos(ang) * inc)
		a.add_child(r)
	return a


## Un peuplier nu en hiver, haut et droit (on en plantait le long des routes et des villages).
func _peuplier_hiver(parent: Node3D, p: Vector2, hasard: RandomNumberGenerator, taille := 1.0) -> Node3D:
	var a := Node3D.new()
	a.name = "Peuplier%d" % parent.get_child_count()
	a.position = Vector3(p.x, hauteur(p.x, p.y) - 0.05, p.y)
	a.rotation.y = hasard.randf() * TAU
	a.scale = Vector3.ONE * taille
	parent.add_child(a)
	var ecorce := _mat_choix(["bark_willow_02", "tree_bark_03"], Color(0.72, 0.7, 0.64), 0.9, 0.6)
	var haut := hasard.randf_range(9.0, 12.0)
	var tronc := MeshInstance3D.new()
	tronc.mesh = _cylindre(0.08, 0.28, haut, 8)
	tronc.material_override = ecorce
	tronc.position.y = haut * 0.5
	a.add_child(tronc)
	var rameau := _cylindre(0.02, 0.06, 1.0, 4)
	for k in 22:
		var t := hasard.randf_range(0.25, 0.92)
		var ang := hasard.randf() * TAU
		var inc := hasard.randf_range(0.25, 0.45)
		var l := (1.0 - t) * hasard.randf_range(2.0, 3.6) + 0.6
		var r := MeshInstance3D.new()
		r.mesh = rameau
		r.material_override = ecorce
		r.scale = Vector3(1, l, 1)
		r.position = Vector3(0, haut * t, 0) + Vector3(cos(ang) * sin(inc), cos(inc), sin(ang) * sin(inc)) * l * 0.5
		r.rotation = Vector3(sin(ang) * inc, 0, -cos(ang) * inc)
		a.add_child(r)
	return a


# --- Luoyang : palais, pavillons et enceintes ------------------------------------------------

## Le rouge des piliers laqués.
func _mat_laque() -> StandardMaterial3D:
	var cle := "laque_rouge"
	if not _materiaux.has(cle):
		var m := StandardMaterial3D.new()
		m.albedo_color = ROUGE_LAQUE
		m.roughness = 0.35
		m.metallic_specular = 0.6
		_materiaux[cle] = m
	return _materiaux[cle]


## Un toit à quatre pans (en croupe), légèrement relevé aux angles, posé à la hauteur y.
func _toit_croupe(parent: Node3D, centre: Vector3, largeur: float, profondeur: float, haut := 2.4) -> void:
	var tuiles := _mat_tuiles_han()
	var debord := 1.6
	var l := largeur + debord * 2.0
	var p := profondeur + debord * 2.0
	# Les deux grands pans (avant et arrière).
	var pente := atan2(haut, p * 0.5)
	for cote: float in [-1.0, 1.0]:
		var pan := _boite(Vector3(l - p * 0.5, 0.3, (p * 0.5) / cos(pente)), centre + Vector3(0, haut * 0.5, cote * p * 0.25), tuiles, parent, false)
		pan.rotation.x = cote * pente
	# Les deux petits pans (les croupes, sur les côtés).
	var pente2 := atan2(haut, p * 0.5)
	for cote: float in [-1.0, 1.0]:
		var croupe := MeshInstance3D.new()
		var prisme := PrismMesh.new()
		prisme.size = Vector3(p, haut, p * 0.5)
		croupe.mesh = prisme
		croupe.material_override = tuiles
		croupe.rotation.y = PI / 2 * cote
		croupe.position = centre + Vector3(cote * (l * 0.5 - p * 0.25), haut * 0.5, 0)
		parent.add_child(croupe)
	# L'arête faîtière et ses deux « queues de hibou » relevées.
	_boite(Vector3(l - p * 0.5 + 0.4, 0.4, 0.5), centre + Vector3(0, haut + 0.1, 0), tuiles, parent, false)
	for cote: float in [-1.0, 1.0]:
		var corne := _boite(Vector3(0.5, 0.9, 0.45), centre + Vector3(cote * (l * 0.5 - p * 0.25 + 0.2), haut + 0.5, 0), tuiles, parent, false)
		corne.rotation.z = -cote * 0.35
	# Le dessous du toit, sombre (les chevrons), pour qu'on ne voie pas le ciel au travers.
	_boite(Vector3(l, 0.12, p), centre + Vector3(0, 0.02, 0), _mat_pbr("", Color(0.22, 0.12, 0.08), 0.9), parent, false)


## Un pavillon de palais : une terrasse de terre damée parementée, un escalier, des piliers
## rouges, des murs de cloisons (ou rien : un pavillon ouvert) et un toit en croupe gris.
## « etages » = 1 ou 2. Rend le nœud (le dessus de la terrasse est à « haut_terrasse »).
func _pavillon_han(parent: Node3D, centre: Vector2, taille: Vector2, angle := 0.0, haut_terrasse := 1.6,
		etages := 1, ouvert := false, nom := "Pavillon") -> Node3D:
	var pav := Node3D.new()
	pav.name = nom
	pav.position = Vector3(centre.x, hauteur(centre.x, centre.y), centre.y)
	pav.rotation.y = angle
	parent.add_child(pav)
	var terre := _mat_terre_damee()
	var pierre := _mat_choix(["old_stone_wall", "stacked_stone_wall"], Color(0.7, 0.68, 0.64), 0.9, 1.0)
	var t := taille + Vector2(4.0, 4.0)
	_boite(Vector3(t.x, haut_terrasse, t.y), Vector3(0, haut_terrasse * 0.5 - 0.1, 0), terre, pav)
	_boite(Vector3(t.x + 0.2, 0.25, t.y + 0.2), Vector3(0, haut_terrasse - 0.05, 0), pierre, pav, false)
	# L'escalier (une rampe en marches) au milieu de la façade.
	var marches := int(ceil(haut_terrasse / 0.3))
	for k in marches:
		var h := haut_terrasse * (k + 1) / marches
		_boite(Vector3(5.0, h, 0.5), Vector3(0, h * 0.5 - 0.1, t.y * 0.5 + (marches - k) * 0.5 - 0.2), pierre, pav)
	var laque := _mat_laque()
	var y := haut_terrasse
	var haut_etage := 4.2
	for e in etages:
		var l := taille * (1.0 - e * 0.18)
		var nx := maxi(2, int(l.x / 3.4))
		var nz := maxi(2, int(l.y / 3.4))
		for i in nx + 1:
			for j in nz + 1:
				if i != 0 and i != nx and j != 0 and j != nz:
					continue
				var pilier := MeshInstance3D.new()
				pilier.mesh = _cylindre(0.26, 0.3, haut_etage, 10)
				pilier.material_override = laque
				pilier.position = Vector3(-l.x * 0.5 + l.x * i / nx, y + haut_etage * 0.5, -l.y * 0.5 + l.y * j / nz)
				pav.add_child(pilier)
				var corps := StaticBody3D.new()
				var forme := CollisionShape3D.new()
				var cyl := CylinderShape3D.new()
				cyl.radius = 0.3
				cyl.height = haut_etage
				forme.shape = cyl
				corps.add_child(forme)
				corps.position = pilier.position
				pav.add_child(corps)
		if not ouvert:
			# Les cloisons : des panneaux de bois clair en retrait des piliers, une porte au milieu.
			var cloison := _mat_torchis()
			_boite(Vector3(l.x - 0.6, haut_etage - 0.6, 0.25), Vector3(0, y + haut_etage * 0.5 - 0.3, -l.y * 0.5 + 0.6), cloison, pav)
			for cote: float in [-1.0, 1.0]:
				_boite(Vector3(0.25, haut_etage - 0.6, l.y - 1.2), Vector3(cote * (l.x * 0.5 - 0.6), y + haut_etage * 0.5 - 0.3, 0), cloison, pav)
				_boite(Vector3(l.x * 0.5 - 2.2, haut_etage - 0.6, 0.25), Vector3(cote * (l.x * 0.25 + 1.1), y + haut_etage * 0.5 - 0.3, l.y * 0.5 - 0.6), cloison, pav)
				_fenetre_treillis(pav, Vector3(cote * (l.x * 0.25 + 1.1), y + haut_etage * 0.55, l.y * 0.5 - 0.46), Vector2(minf(3.0, l.x * 0.3), 1.6))
		# La poutre (l'architrave) peinte, au-dessus des piliers.
		for cote: float in [-1.0, 1.0]:
			_boite(Vector3(l.x + 0.4, 0.5, 0.4), Vector3(0, y + haut_etage + 0.1, cote * l.y * 0.5), laque, pav, false)
			_boite(Vector3(0.4, 0.5, l.y + 0.4), Vector3(cote * l.x * 0.5, y + haut_etage + 0.1, 0), laque, pav, false)
		if e < etages - 1:
			# Un auvent (un toit de rive) entre les deux étages, et le plancher du haut.
			_toit_croupe(pav, Vector3(0, y + haut_etage + 0.35, 0), l.x, l.y, 1.2)
			y += haut_etage + 1.4
		else:
			_toit_croupe(pav, Vector3(0, y + haut_etage + 0.35, 0), l.x, l.y, maxf(2.4, l.y * 0.32))
	return pav


## Un mur d'enceinte de palais (ou de quartier) : de la terre damée enduite, coiffée d'un
## petit toit de tuiles. Les « portes » sont des positions (0 à 1) le long du mur où l'on passe.
func _mur_palais(parent: Node3D, a: Vector2, b: Vector2, haut := 4.0, portes: Array = [], largeur_porte := 5.0) -> void:
	var d := b - a
	var longueur := d.length()
	var dir := d / longueur
	var angle := atan2(-dir.y, dir.x)
	var coupes := [0.0]
	for p: float in portes:
		coupes.append(p * longueur - largeur_porte * 0.5)
		coupes.append(p * longueur + largeur_porte * 0.5)
	coupes.append(longueur)
	var enduit := _mat_choix(["white_plaster_02", "clay_plaster"], Color(0.84, 0.78, 0.7), 0.95, 2.0)
	for k in range(0, coupes.size(), 2):
		var l: float = coupes[k + 1] - coupes[k]
		if l <= 0.2:
			continue
		var m: Vector2 = a + dir * ((coupes[k] + coupes[k + 1]) * 0.5)
		var y := hauteur(m.x, m.y)
		_boite_orientee(Vector3(l, haut, 1.2), Vector3(m.x, y + haut * 0.5 - 0.3, m.y), angle, enduit, parent)
		_boite_orientee(Vector3(l + 0.2, 0.3, 1.9), Vector3(m.x, y + haut - 0.15, m.y), angle, _mat_tuiles_han(), parent, false)
		var faite := _boite_orientee(Vector3(l + 0.2, 0.25, 0.4), Vector3(m.x, y + haut + 0.1, m.y), angle, _mat_tuiles_han(), parent, false)
		faite.name = "Faite"
	# Les portes : deux piliers rouges et un petit toit.
	for p: float in portes:
		var m := a + dir * (p * longueur)
		var y := hauteur(m.x, m.y)
		for c: float in [-1.0, 1.0]:
			var q := m + dir * c * (largeur_porte * 0.5 + 0.2)
			var pilier := MeshInstance3D.new()
			pilier.mesh = _cylindre(0.28, 0.3, haut + 0.8, 10)
			pilier.material_override = _mat_laque()
			pilier.position = Vector3(q.x, y + (haut + 0.8) * 0.5 - 0.3, q.y)
			parent.add_child(pilier)
		var toit := Node3D.new()
		toit.position = Vector3(m.x, y + haut + 0.5, m.y)
		toit.rotation.y = angle
		parent.add_child(toit)
		_toit_croupe(toit, Vector3.ZERO, largeur_porte + 0.6, 1.6, 1.0)


## Une lanterne de papier rouge pendue à un poteau (ou à une poutre si « poteau » est faux).
func _lanterne(parent: Node3D, p: Vector3, poteau := true) -> void:
	var l := Node3D.new()
	l.position = p
	parent.add_child(l)
	if poteau:
		var bois := MeshInstance3D.new()
		bois.mesh = _cylindre(0.06, 0.07, 3.0, 6)
		bois.material_override = _mat_bois()
		bois.position.y = 1.5
		l.add_child(bois)
		_boite(Vector3(0.9, 0.08, 0.08), Vector3(0.4, 2.95, 0), _mat_bois(), l, false)
	var globe := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.28
	s.height = 0.5
	s.radial_segments = 12
	s.rings = 6
	globe.mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.15, 0.08)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.35, 0.12)
	m.emission_energy_multiplier = 1.2
	globe.material_override = m
	globe.position = Vector3(0.75 if poteau else 0.0, 2.55 if poteau else -0.4, 0)
	l.add_child(globe)
