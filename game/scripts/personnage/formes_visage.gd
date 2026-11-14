class_name FormesVisage
extends RefCounted
## Fabrique les « formes » (blend shapes) du visage du vrai personnage MakeHuman.
##
## Chaque curseur de l'écran de création (data/creation_personnage.json, liste
## « visage ») devient une forme du même nom sur tous les maillages de la tête
## (peau, yeux, sourcils, cils, cheveux). Une forme réglée à 1 déplace les points
## du visage d'environ quelques millimètres ; à -1, dans l'autre sens.
##
## Les formes sont calculées une seule fois par modèle (homme / femme), au premier
## affichage, à partir de repères trouvés automatiquement sur le maillage (centre
## des yeux, bout du nez, menton…). Tous les personnages du même modèle partagent
## ensuite les mêmes maillages : chacun règle seulement l'intensité des formes.
##
## Même chose pour les masques de barbe (dessinés dans la texture de la peau).

const CURSEURS := ["largeur_visage", "longueur_visage", "machoire", "menton", "pommettes",
	"ecart_yeux", "taille_yeux", "hauteur_yeux", "inclinaison_yeux",
	"hauteur_sourcils", "epaisseur_sourcils",
	"longueur_nez", "largeur_nez", "bosse_nez",
	"largeur_bouche", "epaisseur_levres", "taille_oreilles"]

## Taille des modèles en cm (pieds-sommet du crâne), pour convertir les cm en unités du maillage.
const TAILLE_CM := {"homme": 178.0, "femme": 168.0}

## Maillages déjà préparés : "modele/nom" -> ArrayMesh avec formes.
static var _maillages := {}
## Repères du visage par modèle.
static var _reperes := {}
## Masques de barbe par modèle et par style : "modele/style" -> ImageTexture.
static var _masques := {}


enum Sorte { PEAU, YEUX, SOURCILS, CILS, CHEVEUX, AUTRE }


## Remplace les maillages de la tête du personnage par des versions avec formes.
## « sortes » : MeshInstance3D -> Sorte.
static func preparer(modele: String, sortes: Dictionary) -> void:
	var reperes := _reperes_de(modele, sortes)
	if reperes.is_empty():
		return
	for mi in sortes:
		var sorte: int = sortes[mi]
		if sorte == Sorte.AUTRE:
			continue
		var cle := "%s/%s" % [modele, mi.name]
		if not _maillages.has(cle):
			_maillages[cle] = _avec_formes(mi.mesh, sorte, reperes)
		mi.mesh = _maillages[cle]


## Règle l'intensité des formes (valeurs de -1 à 1, par identifiant de curseur).
static func regler(mi: MeshInstance3D, visage: Dictionary) -> void:
	if mi.mesh == null:
		return
	for i in mi.mesh.get_blend_shape_count():
		var nom := String(mi.mesh.get_blend_shape_name(i))
		mi.set_blend_shape_value(i, clampf(float(visage.get(nom, 0.0)), -1.0, 1.0))


# ---------------------------------------------------------------------------
# Repères du visage
# ---------------------------------------------------------------------------
static func _reperes_de(modele: String, sortes: Dictionary) -> Dictionary:
	if _reperes.has(modele):
		return _reperes[modele]
	var peau := PackedVector3Array()
	var yeux := PackedVector3Array()
	var sourcils := PackedVector3Array()
	var bas := INF
	var haut := -INF
	for mi in sortes:
		var v: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		if sortes[mi] != Sorte.CHEVEUX:   # la taille se mesure sans les cheveux
			for p in v:
				bas = minf(bas, p.y)
				haut = maxf(haut, p.y)
		match sortes[mi]:
			Sorte.PEAU:
				peau.append_array(v)
			Sorte.YEUX:
				yeux.append_array(v)
			Sorte.SOURCILS:
				sourcils.append_array(v)
	if peau.is_empty() or yeux.is_empty():
		push_warning("FormesVisage : peau ou yeux introuvables pour " + modele)
		return {}
	# Une unité « cm » dans l'espace du maillage.
	var u := (haut - bas) / float(TAILLE_CM.get(modele, 175.0))
	var oeil_g := Vector3.ZERO
	var oeil_d := Vector3.ZERO
	var ng := 0
	var nd := 0
	for p in yeux:
		if p.x > 0.0:
			oeil_g += p
			ng += 1
		else:
			oeil_d += p
			nd += 1
	oeil_g /= maxi(ng, 1)
	oeil_d /= maxi(nd, 1)
	var milieu := (oeil_g + oeil_d) / 2.0
	var r := {
		"u": u, "peau": peau, "milieu": milieu,
		"yeux": [oeil_g, oeil_d],
	}
	# Sourcils : centre de chaque sourcil.
	var sg := Vector3.ZERO
	var sd := Vector3.ZERO
	var nsg := 0
	var nsd := 0
	for p in sourcils:
		if p.x > 0.0:
			sg += p
			nsg += 1
		else:
			sd += p
			nsd += 1
	r["sourcils"] = [sg / nsg if nsg > 0 else oeil_g + Vector3(0, 2.0 * u, 0),
			sd / nsd if nsd > 0 else oeil_d + Vector3(0, 2.0 * u, 0)]
	# Points de la ligne médiane, plaqués sur l'avant du visage.
	r["nez"] = _devant(r, 0.0, -4.6)
	r["arete"] = _devant(r, 0.0, -2.3)
	r["levre_haut"] = _devant(r, 0.0, -6.4)
	r["levre_bas"] = _devant(r, 0.0, -7.7)
	r["menton"] = _devant(r, 0.0, -11.0) + Vector3(0, 0, -0.8 * u)
	r["narines"] = [_devant(r, 1.5, -4.3) + Vector3(0, 0, -0.5 * u), _devant(r, -1.5, -4.3) + Vector3(0, 0, -0.5 * u)]
	r["coins_bouche"] = [_devant(r, 2.4, -7.0), _devant(r, -2.4, -7.0)]
	r["pommettes"] = [_devant(r, 4.3, -2.6) + Vector3(0, 0, -0.4 * u), _devant(r, -4.3, -2.6) + Vector3(0, 0, -0.4 * u)]
	r["machoire"] = [milieu + Vector3(5.4, -8.6, -5.5) * u, milieu + Vector3(-5.4, -8.6, -5.5) * u]
	r["oreilles"] = [_oreille(r, 1.0), _oreille(r, -1.0)]
	_reperes[modele] = r
	return r


## Point de la peau le plus en avant près de (x, y) cm autour du milieu des yeux.
static func _devant(r: Dictionary, x_cm: float, y_cm: float) -> Vector3:
	var u: float = r["u"]
	var m: Vector3 = r["milieu"]
	var cible := Vector2(m.x + x_cm * u, m.y + y_cm * u)
	var meilleur := m + Vector3(x_cm * u, y_cm * u, 0.0)
	var z := -INF
	for p in r["peau"]:
		if absf(p.x - cible.x) < 0.7 * u and absf(p.y - cible.y) < 0.7 * u and p.z > z and p.z < m.z + 4.0 * u:
			z = p.z
			meilleur = p
	return meilleur


## Centre de l'oreille : le point le plus écarté sur le côté de la tête, un peu en dedans.
static func _oreille(r: Dictionary, cote: float) -> Vector3:
	var u: float = r["u"]
	var m: Vector3 = r["milieu"]
	var meilleur := m + Vector3(cote * 7.0, -2.0, -8.5) * u
	var ecart := -INF
	for p in r["peau"]:
		if p.y < m.y - 5.0 * u or p.y > m.y + 1.0 * u:
			continue
		if p.z > m.z - 5.0 * u or p.z < m.z - 13.0 * u:
			continue
		if p.x * cote > ecart:
			ecart = p.x * cote
			meilleur = p
	return Vector3(meilleur.x - cote * 0.7 * u, m.y - 2.0 * u, meilleur.z)


# ---------------------------------------------------------------------------
# Construction des formes
# ---------------------------------------------------------------------------
static func _avec_formes(source: Mesh, sorte: int, r: Dictionary) -> ArrayMesh:
	var tableaux := source.surface_get_arrays(0)
	var base: PackedVector3Array = tableaux[Mesh.ARRAY_VERTEX]
	var formes := []
	var maillage := ArrayMesh.new()
	maillage.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_RELATIVE
	for nom in CURSEURS:
		var v := PackedVector3Array()
		v.resize(base.size())
		for i in base.size():
			# Mode « relatif » : on donne le déplacement de chaque point, pas sa position.
			v[i] = _deplacement(nom, base[i], sorte, r)
		var forme := []
		forme.resize(Mesh.ARRAY_MAX)
		forme[Mesh.ARRAY_VERTEX] = v
		# Les normales et tangentes, elles, sont données telles quelles (le moteur les compresse).
		forme[Mesh.ARRAY_NORMAL] = tableaux[Mesh.ARRAY_NORMAL]
		forme[Mesh.ARRAY_TANGENT] = tableaux[Mesh.ARRAY_TANGENT]
		formes.append(forme)
		maillage.add_blend_shape(nom)
	var drapeaux: int = source.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	maillage.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tableaux, formes, {}, drapeaux)
	return maillage


static func _g(p: Vector3, centre: Vector3, rayon: float) -> float:
	return exp(-p.distance_squared_to(centre) / (rayon * rayon))


## Déplacement d'un point pour un curseur réglé à 1.
static func _deplacement(nom: String, p: Vector3, sorte: int, r: Dictionary) -> Vector3:
	var u: float = r["u"]
	var m: Vector3 = r["milieu"]
	# Rien ne bouge sous le menton (le cou et les épaules restent en place).
	var tete := smoothstep(m.y - 14.0 * u, m.y - 11.0 * u, p.y)
	if tete <= 0.0:
		return Vector3.ZERO
	var cote := 0 if p.x >= 0.0 else 1     # 0 = côté gauche du personnage (x > 0)
	var signe := 1.0 if p.x >= 0.0 else -1.0
	var rigide := sorte == Sorte.YEUX or sorte == Sorte.CILS
	var oeil: Vector3 = r["yeux"][cote]
	var g_oeil := 1.0 if rigide else _g(p, oeil, 2.0 * u) * tete
	match nom:
		"largeur_visage":
			return Vector3((p.x - m.x) * 0.07, 0, 0) * tete
		"longueur_visage":
			if p.y >= m.y:
				return Vector3.ZERO
			return Vector3(0, (p.y - m.y) * 0.08, 0) * smoothstep(m.y - 14.5 * u, m.y - 10.5 * u, p.y)
		"machoire":
			return Vector3(signe * 0.9 * u, 0, 0) * _g(p, r["machoire"][cote], 3.5 * u) * tete
		"menton":
			return Vector3(0, -0.2 * u, 0.9 * u) * _g(p, r["menton"], 2.6 * u) * tete
		"pommettes":
			return Vector3(signe * 0.35 * u, 0.1 * u, 0.35 * u) * _g(p, r["pommettes"][cote], 2.0 * u) * tete
		"ecart_yeux":
			return Vector3(signe * 0.35 * u, 0, 0) * g_oeil
		"taille_yeux":
			return (p - oeil) * 0.13 * (1.0 if rigide else _g(p, oeil, 1.8 * u) * tete)
		"hauteur_yeux":
			return Vector3(0, 0.4 * u, 0) * g_oeil
		"inclinaison_yeux":
			var angle := 0.12 * (1.0 if oeil.x >= m.x else -1.0)
			var rel := p - oeil
			var tourne := Vector3(rel.x * cos(angle) - rel.y * sin(angle), rel.x * sin(angle) + rel.y * cos(angle), rel.z)
			return (tourne - rel) * g_oeil
		"hauteur_sourcils":
			var sourcil: Vector3 = r["sourcils"][cote]
			var g := 1.0 if sorte == Sorte.SOURCILS else _g(p, sourcil, 2.2 * u) * tete
			return Vector3(0, 0.45 * u, 0) * g
		"epaisseur_sourcils":
			if sorte != Sorte.SOURCILS:
				return Vector3.ZERO
			var centre: Vector3 = r["sourcils"][cote]
			return Vector3(0, (p.y - centre.y) * 0.7, 0)
		"longueur_nez":
			return Vector3(0, -0.45 * u, 0.15 * u) * _g(p, r["nez"], 1.8 * u) * tete
		"largeur_nez":
			return Vector3(signe * 0.3 * u, 0, 0) * _g(p, r["narines"][cote], 1.3 * u) * tete
		"bosse_nez":
			return Vector3(0, 0, 0.3 * u) * _g(p, r["arete"], 1.2 * u) * tete
		"largeur_bouche":
			return Vector3(signe * 0.35 * u, 0, 0) * _g(p, r["coins_bouche"][cote], 1.2 * u) * tete
		"epaisseur_levres":
			return (Vector3(0, 0.12 * u, 0.2 * u) * _g(p, r["levre_haut"], 1.0 * u)
					+ Vector3(0, -0.15 * u, 0.22 * u) * _g(p, r["levre_bas"], 1.1 * u)) * tete
		"taille_oreilles":
			var oreille: Vector3 = r["oreilles"][cote]
			return (p - oreille) * 0.25 * _g(p, oreille, 2.8 * u) * tete
	return Vector3.ZERO


# ---------------------------------------------------------------------------
# Barbe : un masque peint dans l'espace de texture (UV) de la peau
# ---------------------------------------------------------------------------
const TAILLE_MASQUE := 1024


## Masque de barbe (blanc = poils) pour un style : trois_jours, barbe_courte,
## barbe_longue, moustache, bouc. Renvoie null pour « aucune ».
static func masque_barbe(modele: String, peau: MeshInstance3D, style: String) -> Texture2D:
	if style == "aucune" or style == "" or not _reperes.has(modele):
		return null
	var cle := "%s/%s" % [modele, style]
	if _masques.has(cle):
		return _masques[cle]
	var r: Dictionary = _reperes[modele]
	var tableaux := peau.mesh.surface_get_arrays(0)
	var sommets: PackedVector3Array = tableaux[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = tableaux[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = tableaux[Mesh.ARRAY_INDEX]
	var poids := PackedFloat32Array()
	poids.resize(sommets.size())
	for i in sommets.size():
		poids[i] = _poids_barbe(style, sommets[i], r)
	var image := Image.create(TAILLE_MASQUE, TAILLE_MASQUE, false, Image.FORMAT_L8)
	var bruit := FastNoiseLite.new()
	bruit.frequency = 0.6
	bruit.fractal_octaves = 2
	bruit.seed = 7
	var densite: float = {"trois_jours": 0.5, "barbe_courte": 0.8, "barbe_longue": 0.95, "moustache": 0.85, "bouc": 0.85}.get(style, 0.9)
	for t in range(0, indices.size(), 3):
		var a := indices[t]
		var b := indices[t + 1]
		var c := indices[t + 2]
		if poids[a] <= 0.01 and poids[b] <= 0.01 and poids[c] <= 0.01:
			continue
		_peindre_triangle(image, uvs[a], uvs[b], uvs[c], poids[a], poids[b], poids[c], bruit, densite)
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_masques[cle] = texture
	return texture


static func _poids_barbe(style: String, p: Vector3, r: Dictionary) -> float:
	var u: float = r["u"]
	var m: Vector3 = r["milieu"]
	var y := (p.y - m.y) / u          # cm sous les yeux (négatif)
	var z := (p.z - m.z) / u          # cm devant (positif) / derrière les yeux
	var x := absf(p.x - m.x) / u
	var bouche := ((r["levre_haut"] as Vector3).y - m.y) / u
	var dans_le_visage := smoothstep(-10.5, -7.5, z)          # pas derrière les oreilles
	var levres := 1.0 - smoothstep(0.9, 1.3, Vector2(x / 1.9, (y - (bouche - 0.6)) / 0.9).length())
	match style:
		"moustache":
			return (1.0 - smoothstep(0.8, 1.15, Vector2(x / 2.6, (y - (bouche + 0.9)) / 0.8).length())) * (1.0 - levres)
		"bouc":
			var menton := 1.0 - smoothstep(0.8, 1.15, Vector2(x / 2.0, (y + 10.0) / 2.4).length())
			var moust := 1.0 - smoothstep(0.8, 1.15, Vector2(x / 2.6, (y - (bouche + 0.9)) / 0.8).length())
			return maxf(menton, moust) * (1.0 - levres)
		_:
			# Barbe : joues basses, mâchoire, menton et lèvre supérieure ; plus bas sous le menton si longue.
			var bas := -14.5 if style == "barbe_longue" else -13.0
			var haut := -3.6 - x * 0.12
			var zone := smoothstep(bas - 0.8, bas + 0.8, y) * (1.0 - smoothstep(haut - 0.8, haut + 0.4, y))
			return zone * dans_le_visage * (1.0 - levres)


static func _peindre_triangle(image: Image, a: Vector2, b: Vector2, c: Vector2, pa: float, pb: float,
		pc: float, bruit: FastNoiseLite, densite: float) -> void:
	var t := float(TAILLE_MASQUE)
	var A := Vector2(a.x * t, a.y * t)
	var B := Vector2(b.x * t, b.y * t)
	var C := Vector2(c.x * t, c.y * t)
	var mini := Vector2(minf(A.x, minf(B.x, C.x)), minf(A.y, minf(B.y, C.y))).floor()
	var maxi := Vector2(maxf(A.x, maxf(B.x, C.x)), maxf(A.y, maxf(B.y, C.y))).ceil()
	var aire := (B - A).cross(C - A)
	if absf(aire) < 1e-6:
		return
	for py in range(maxi(0, int(mini.y)), mini(TAILLE_MASQUE, int(maxi.y) + 1)):
		for px in range(maxi(0, int(mini.x)), mini(TAILLE_MASQUE, int(maxi.x) + 1)):
			var q := Vector2(px + 0.5, py + 0.5)
			var w0 := (B - q).cross(C - q) / aire
			var w1 := (C - q).cross(A - q) / aire
			var w2 := 1.0 - w0 - w1
			if w0 < -0.02 or w1 < -0.02 or w2 < -0.02:
				continue
			var poids := clampf(w0 * pa + w1 * pb + w2 * pc, 0.0, 1.0)
			# Poils : un grain irrégulier, plus clairsemé sur les bords.
			var grain := bruit.get_noise_2d(px, py) * 0.5 + 0.5
			var valeur := clampf((poids * densite - (1.0 - grain) * 0.55) * 1.6, 0.0, 0.92)
			if valeur > image.get_pixel(px, py).r:
				image.set_pixel(px, py, Color(valeur, valeur, valeur))
