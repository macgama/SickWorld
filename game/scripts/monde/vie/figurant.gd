extends Node3D
## Un figurant d'époque (vie ambiante des îles) : un villageois qui vaque à ses
## occupations. Il suit un chemin sur le terrain, s'arrête à certains points pour un
## geste (travailler, prier, discuter), porte parfois une jarre sur la tête, un panier
## ou un fagot sur l'épaule. On ne lui parle pas et il ne bloque pas le joueur.
## Décrit dans data/vie_ambiante.json (clé « figurants »), habillé comme les
## personnages de data/<île>_pnj.json (modele, taille_cm, peau, habits, tenue).
##
## Performances : au-delà de DISTANCE_VISIBLE de la caméra il est caché et ne fait
## qu'avancer ; au-delà de DISTANCE_ANIMATION il n'est animé qu'une image sur trois.

const SCENE_APPARENCE := "res://scenes/joueur/apparence_agent.tscn"
const HabitEpoque := preload("res://scripts/personnage/habit_epoque.gd")
const DISTANCE_VISIBLE := 85.0
const DISTANCE_ANIMATION := 35.0
## Geste demandé → animation Mixamo jouée en boucle pendant les pauses (si le fichier
## existe ; sinon on garde un geste de secours tiré des gestes de combat).
const POSES := {"travail": "creuser", "creuser": "creuser", "priere": "prier", "prier": "prier",
	"discute": "discuter", "discuter": "discuter", "lancer": "pecher", "pecher": "pecher",
	"assis": "assis", "a_genoux": "a_genoux", "telephone": "telephone", "regarder": "regarder"}
## Objet tenu en main pendant la pose : téléphone, canne à pêche, maillet.
const OUTILS := {"telephone": "telephone", "pecher": "canne", "creuser": "maillet"}

var fiche: Dictionary = {}
## Points [x, z] du chemin. Un seul point : il reste sur place.
var chemin: PackedVector2Array = []
## true : il fait le tour (dernier point → premier) ; false : aller-retour.
var boucle := false
var vitesse := 1.3
## Pause (secondes) à chaque point d'arrêt : [min, max].
var pause := Vector2(3.0, 9.0)
## Indices des points du chemin où il s'arrête (vide = seulement aux deux bouts).
var arrets: Array = []
## Geste pendant les pauses : « travail » (creuser), « priere », « discute », « lancer »
## (pêcher), « assis », « a_genoux », « telephone », « regarder », « ramasser », « » = rien.
var geste := ""
## Ce qu'il porte : « jarre » (sur la tête), « amphore » (sur l'épaule), « panier », « fagot », « sac », « lance », « ».
var porte := ""
## Orientation pendant les pauses (degrés, 0 = nord) ; NAN = garde son sens de marche.
var regarde := NAN
## Couleur du parapluie (alpha 0 : pas de parapluie) — pour les passants du hub.
var parapluie := Color(0, 0, 0, 0)
## Fonction hauteur(x, z) du terrain (la zone).
var ile: Node

var _apparence: Node3D
var _cible := 0
var _sens := 1
var _attente := 0.0
var _prochain_geste := 0.0
var _image := 0
var _pret := false
## Canne à pêche (pêcheurs) et la main qui la tient.
var _canne: Node3D
var _main: Node3D


func _ready() -> void:
	add_to_group("vie_ambiante")
	add_to_group("figurants")
	_apparence = (load(SCENE_APPARENCE) as PackedScene).instantiate()
	_apparence.set("modele", fiche.get("modele", "homme"))
	add_child(_apparence)
	_habiller.call_deferred()
	if chemin.size() > 0:
		_placer(chemin[0])
	_cible = mini(1, chemin.size() - 1)
	_attente = randf_range(0.0, 1.5)
	_prochain_geste = randf_range(0.5, 3.0)
	if not is_nan(regarde) and chemin.size() <= 1:
		rotation.y = -deg_to_rad(regarde)


func _habiller() -> void:
	if not is_instance_valid(_apparence):
		return
	var sexe := String(fiche.get("modele", "homme"))
	if _apparence.has_method("appliquer"):
		_apparence.appliquer({"sexe": sexe,
				"taille_cm": float(fiche.get("taille_cm", 172 if sexe == "homme" else 162)),
				"peau": Color.from_string(String(fiche.get("peau", "#9a6a48")), Color(0.6, 0.42, 0.3))})
	# Vrai habit d'époque (chiton, pagne, peaux…) ; sinon, ancienne méthode : la tenue
	# moderne teinte et une robe dessinée en code.
	var habille := HabitEpoque.depuis_fiche(_apparence, fiche)
	if not habille and fiche.has("habits") and _apparence.has_method("teindre_tenue"):
		_apparence.teindre_tenue(Color.from_string(String(fiche["habits"]), Color.WHITE))
		for n in _apparence.find_children("*", "MeshInstance3D", true, false):
			var m := (n as MeshInstance3D).material_override as StandardMaterial3D
			if m == null or m.subsurf_scatter_enabled or m.roughness < 0.2 \
					or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
			var cuir := m.duplicate() as StandardMaterial3D
			cuir.albedo_texture = null
			cuir.albedo_color = Color.from_string(String(fiche["habits"]), Color.WHITE).lerp(Color(0.4, 0.28, 0.18), 0.7)
			cuir.roughness = 0.9
			(n as MeshInstance3D).material_override = cuir
	if fiche.has("tenue") and _apparence.has_method("equiper"):
		var objets: Dictionary = _catalogue().get("objets", {})
		var visuels := {}
		for id in fiche["tenue"]:
			var o: Dictionary = objets.get(id, {})
			if o.has("visuel") and o.has("emplacement"):
				visuels[o["emplacement"]] = o["visuel"]
		_apparence.equiper(visuels)
	if fiche.has("antique") and not habille:
		_ajouter_drape(fiche["antique"])
	if porte != "":
		_ajouter_charge()
	# Pas de parapluie pour ceux qui prennent une pose (assis, téléphone…) : il traverserait le corps.
	if parapluie.a > 0.0 and not POSES.has(geste):
		_ajouter_parapluie()
	if OUTILS.has(POSES.get(geste, geste)):
		_ajouter_outil(OUTILS[POSES.get(geste, geste)])
	_pret = true


static var _objets := {}


static func _catalogue() -> Dictionary:
	if _objets.is_empty():
		var lu = JSON.parse_string(FileAccess.get_file_as_string("res://data/objets.json"))
		if lu is Dictionary:
			_objets = lu
	return _objets


## Habit antique (Grèce…) par-dessus la tenue moderne teinte : une robe (chiton ou péplos)
## qui descend des hanches, une ceinture, et un drapé sur les épaules (himation) qui cache
## en partie la veste. fiche « antique » : {"robe": longueur en m sous les hanches,
## "drape": couleur du manteau (facultatif), "ceinture": couleur (facultatif)}.
func _ajouter_drape(reglage: Dictionary) -> void:
	var squelette := _apparence.find_children("*", "Skeleton3D", true, false)
	if squelette.is_empty():
		return
	var s := squelette[0] as Skeleton3D
	var couleur := Color.from_string(String(fiche.get("habits", "#e4dac4")), Color(0.88, 0.85, 0.77))
	var tissu := _mat(couleur.lightened(0.05), 0.95)
	tissu.cull_mode = BaseMaterial3D.CULL_DISABLED
	var echelle := 1.0
	var femme := String(fiche.get("modele", "homme")) == "femme"
	var accrocher := func(os: String) -> Node3D:
		if s.find_bone(os) < 0:
			return null
		var a := BoneAttachment3D.new()
		a.bone_name = os
		s.add_child(a)
		var n := Node3D.new()
		a.add_child(n)
		echelle = 1.0 / maxf(0.001, s.global_transform.basis.get_scale().x / _apparence.global_transform.basis.get_scale().x)
		n.scale = Vector3.ONE * echelle
		return n
	# La robe : un tube de tissu évasé, des hanches jusqu'aux genoux ou aux chevilles.
	var bassin: Node3D = accrocher.call("mixamorig_Hips")
	if bassin != null:
		var longueur := float(reglage.get("robe", 0.75 if femme else 0.55))
		var robe := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.17 if femme else 0.18
		c.bottom_radius = 0.17 + longueur * 0.12
		c.height = longueur + 0.18
		c.cap_top = false
		c.cap_bottom = false
		c.radial_segments = 14
		robe.mesh = c
		robe.material_override = tissu
		robe.position = Vector3(0, 0.12 - c.height * 0.5, 0.0)
		robe.scale = Vector3(1.0, 1.0, 0.8)
		bassin.add_child(robe)
		# Les plis : quelques bandes verticales un peu plus sombres.
		var pli := _mat(couleur.darkened(0.12), 0.95)
		for k in 6:
			var a := TAU * (k + 0.5) / 6.0
			var bande := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.03, c.height * 0.9, 0.012)
			bande.mesh = b
			bande.material_override = pli
			var r := (c.top_radius + c.bottom_radius) * 0.5 + 0.004
			bande.position = Vector3(sin(a) * r, robe.position.y, cos(a) * r * 0.8)
			bande.rotation.y = a
			bande.rotation.x = -atan((c.bottom_radius - c.top_radius) / c.height) * cos(a)
			bande.rotation.z = atan((c.bottom_radius - c.top_radius) / c.height) * sin(a)
			bassin.add_child(bande)
	# La ceinture, à la taille.
	var taille: Node3D = accrocher.call("mixamorig_Spine")
	if taille != null:
		var t := TorusMesh.new()
		t.inner_radius = 0.15
		t.outer_radius = 0.175
		var ceinture := MeshInstance3D.new()
		ceinture.mesh = t
		ceinture.material_override = _mat(Color.from_string(String(reglage.get("ceinture", "#6a4a30")), Color(0.4, 0.29, 0.19)), 0.9)
		ceinture.scale = Vector3(1.0, 1.0, 0.78)
		taille.add_child(ceinture)
	# Le pan de l'himation, en écharpe sur la poitrine.
	var buste: Node3D = accrocher.call("mixamorig_Spine2")
	if buste != null:
		var drape := _mat(Color.from_string(String(reglage.get("drape", "")), couleur.darkened(0.08)), 0.95)
		drape.cull_mode = BaseMaterial3D.CULL_DISABLED
		# Le pan qui passe en écharpe de l'épaule gauche à la hanche droite.
		var echarpe := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.16, 0.62, 0.02)
		echarpe.mesh = bx
		echarpe.material_override = drape
		echarpe.position = Vector3(0.0, -0.08, 0.125)
		echarpe.rotation.z = 0.6
		buste.add_child(echarpe)


func _ajouter_charge() -> void:
	var squelette := _apparence.find_children("*", "Skeleton3D", true, false)
	if squelette.is_empty():
		return
	var s := squelette[0] as Skeleton3D
	var os := "mixamorig_Head" if porte == "jarre" else "mixamorig_RightShoulder"
	if porte == "lance":
		os = "mixamorig_RightHand"
	if s.find_bone(os) < 0:
		return
	var accroche := BoneAttachment3D.new()
	accroche.bone_name = os
	s.add_child(accroche)
	var objet := Node3D.new()
	accroche.add_child(objet)
	# Le squelette Mixamo est à l'échelle 0,01 dans certains imports : on compense.
	var echelle := 1.0 / maxf(0.001, s.global_transform.basis.get_scale().x / _apparence.global_transform.basis.get_scale().x)
	objet.scale = Vector3.ONE * echelle
	var terre := _mat(Color(0.62, 0.42, 0.28), 0.85)
	var osier := _mat(Color(0.66, 0.52, 0.32), 0.95)
	var bois := _mat(Color(0.36, 0.26, 0.17), 0.9)
	match porte:
		"jarre":
			objet.position = Vector3(0, 0.2, 0.02) * echelle
			_piece(objet, _cyl(0.06, 0.13, 0.28), terre, Vector3(0, 0.14, 0))
			_piece(objet, _cyl(0.05, 0.06, 0.05), terre, Vector3(0, 0.3, 0))
			_piece(objet, _cyl(0.1, 0.1, 0.03), _mat(Color(0.85, 0.8, 0.68), 1.0), Vector3(0, 0.0, 0))
		"panier":
			objet.position = Vector3(0.05, 0.12, 0.0) * echelle
			_piece(objet, _cyl(0.2, 0.15, 0.22), osier, Vector3(0, 0.11, 0))
		"fagot":
			objet.position = Vector3(0.0, 0.1, -0.05) * echelle
			for i in 5:
				var b := _piece(objet, _cyl(0.025, 0.03, 1.3), bois, Vector3(0.04 * (i - 2), 0.04 * (i % 2), 0))
				b.rotation = Vector3(PI / 2, 0, 0.05 * (i - 2))
		"sac":
			objet.position = Vector3(0.0, 0.12, 0.1) * echelle
			var sac := MeshInstance3D.new()
			var sph := SphereMesh.new()
			sph.radius = 0.2
			sph.height = 0.34
			sac.mesh = sph
			sac.material_override = _mat(Color(0.78, 0.72, 0.58), 1.0)
			objet.add_child(sac)
		"lance":
			_piece(objet, _cyl(0.015, 0.018, 1.9), bois, Vector3(0, 0.5, 0))
		"amphore":
			# Une amphore grecque couchée sur l'épaule (vin, huile), le col vers l'avant.
			objet.position = Vector3(-0.02, 0.2, 0.0) * echelle
			objet.rotation = Vector3(PI / 2 - 0.25, 0, 0)
			_piece(objet, _cyl(0.15, 0.06, 0.42), terre, Vector3(0, 0, 0))
			_piece(objet, _cyl(0.06, 0.15, 0.12), terre, Vector3(0, 0.27, 0))
			_piece(objet, _cyl(0.04, 0.045, 0.14), terre, Vector3(0, 0.39, 0))
			_piece(objet, _cyl(0.0, 0.05, 0.1), terre, Vector3(0, -0.26, 0)).rotation.x = PI


## Un objet dans la main droite (le squelette Mixamo : l'axe Y de la main suit les doigts).
func _ajouter_outil(sorte: String) -> void:
	var squelette := _apparence.find_children("*", "Skeleton3D", true, false)
	if squelette.is_empty():
		return
	var s := squelette[0] as Skeleton3D
	if s.find_bone("mixamorig_RightHand") < 0:
		return
	var accroche := BoneAttachment3D.new()
	accroche.name = "Outil"
	accroche.bone_name = "mixamorig_RightHand"
	s.add_child(accroche)
	var objet := Node3D.new()
	accroche.add_child(objet)
	var echelle := 1.0 / maxf(0.001, s.global_transform.basis.get_scale().x / _apparence.global_transform.basis.get_scale().x)
	objet.scale = Vector3.ONE * echelle
	var bois := _mat(Color(0.36, 0.26, 0.17), 0.9)
	match sorte:
		"telephone":
			var boite := BoxMesh.new()
			boite.size = Vector3(0.07, 0.145, 0.009)
			var ecran := _mat(Color(0.05, 0.05, 0.06), 0.25)
			ecran.emission_enabled = true
			ecran.emission = Color(0.35, 0.5, 0.75)
			ecran.emission_energy_multiplier = 0.6
			_piece(objet, boite, ecran, Vector3(0.0, 0.08, 0.03))
		"canne":
			# La canne ne suit pas l'orientation de la main (trop variable dans l'animation) :
			# elle part du poing vers l'avant, 30° au-dessus de l'horizontale (voir _physics_process).
			_canne = Node3D.new()
			_canne.top_level = true
			accroche.add_child(_canne)
			var canne := _piece(_canne, _cyl(0.006, 0.016, 2.8), bois, Vector3(0, 1.2, 0))
			canne.rotation = Vector3.ZERO
			_main = accroche
		"maillet":
			# Un maillet de tailleur de pierre (court : il ne traverse pas les blocs).
			var manche := _piece(objet, _cyl(0.014, 0.016, 0.36), bois, Vector3(0, 0.08, 0.03))
			manche.rotation = Vector3(0, 0, PI / 2)
			var tete := _piece(objet, _cyl(0.05, 0.05, 0.16), _mat(Color(0.42, 0.3, 0.2), 0.9), Vector3(-0.17, 0.08, 0.03))
			tete.rotation = Vector3(PI / 2, 0, 0)


func _ajouter_parapluie() -> void:
	var taille := float(fiche.get("taille_cm", 170.0)) / 175.0
	var pivot := Node3D.new()
	pivot.name = "Parapluie"
	pivot.position = Vector3(0.24, 0.0, -0.08) * taille
	pivot.rotation.z = 0.12
	add_child(pivot)
	var toile := CylinderMesh.new()
	toile.top_radius = 0.02
	toile.bottom_radius = 0.5
	toile.height = 0.28
	toile.radial_segments = 10
	toile.rings = 1
	var m := StandardMaterial3D.new()
	m.albedo_color = parapluie
	m.roughness = 0.3
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_piece(pivot, toile, m, Vector3(0, 2.0 * taille, 0))
	_piece(pivot, _cyl(0.012, 0.012, 1.15), _mat(Color(0.08, 0.08, 0.08), 0.5), Vector3(0, 1.43 * taille, 0))


func _piece(parent: Node3D, m: Mesh, mat: Material, p: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = p
	parent.add_child(mi)
	return mi


static func _cyl(haut: float, bas: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = haut
	c.bottom_radius = bas
	c.height = h
	c.radial_segments = 12
	c.rings = 2
	return c


static func _mat(c: Color, r: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = r
	return m


func _placer(p: Vector2) -> void:
	var y := 0.0
	if ile != null and ile.has_method("hauteur"):
		y = ile.hauteur(p.x, p.y)
	position = Vector3(p.x, y, p.y)


func _physics_process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var distance := camera.global_position.distance_to(global_position) if camera != null else 0.0
	visible = distance < DISTANCE_VISIBLE
	var deplacement := Vector3.ZERO
	if chemin.size() >= 2:
		if _attente > 0.0:
			_attente -= delta
			_geste_en_pause(delta)
		else:
			var ici := Vector2(position.x, position.z)
			var vers := chemin[_cible] - ici
			var pas := vitesse * delta
			if vers.length() <= pas:
				_placer(chemin[_cible])
				_suivant()
			else:
				var d := vers.normalized()
				_placer(ici + d * pas)
				deplacement = Vector3(d.x, 0, d.y) * vitesse
				rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.y), clampf(5.0 * delta, 0.0, 1.0))
	elif _pret:
		_geste_en_pause(delta)
	if not _pret or _apparence == null or not _apparence.has_method("animer"):
		return
	if _canne != null and visible:
		_canne.global_transform = Transform3D(global_basis * Basis(Vector3.RIGHT, deg_to_rad(-60.0)),
				_main.global_position)
	_image += 1
	if not visible:
		# Caché : on met quand même sa pose en place de temps en temps (pas de fondu visible
		# quand on arrive près de lui).
		if _image % 30 == 0:
			_apparence.animer(0.5, global_transform.basis.inverse() * deplacement, true, -1.0, Vector3.ZERO)
		return
	if distance > DISTANCE_ANIMATION and _image % 3 != 0:
		return
	var pas_temps := delta * (3.0 if distance > DISTANCE_ANIMATION else 1.0)
	var locale := global_transform.basis.inverse() * deplacement
	_apparence.animer(pas_temps, locale, true, -1.0, Vector3.ZERO)


func _geste_en_pause(delta: float) -> void:
	if not is_nan(regarde):
		rotation.y = lerp_angle(rotation.y, -deg_to_rad(regarde), clampf(3.0 * delta, 0.0, 1.0))
	if geste == "" or not _pret:
		return
	# Vraie animation Mixamo en boucle (assis, creuser, prier…) si elle existe.
	var pose: String = POSES.get(geste, "")
	if pose != "" and _apparence.has_method("a_animation") and _apparence.a_animation(pose):
		_apparence.pose_repos = pose
		return
	_prochain_geste -= delta
	if _prochain_geste > 0.0:
		return
	match geste:
		"travail":
			_apparence.attaquer("", 1.1)
			_prochain_geste = randf_range(1.3, 2.2)
		"priere":
			_apparence.attaquer("incantation", 2.5)
			_prochain_geste = randf_range(5.0, 9.0)
		"lancer":
			_apparence.attaquer("lancer", 1.2)
			_prochain_geste = randf_range(3.0, 6.0)
		"ramasser":
			_apparence.attaquer("ramasser", 0.0)
			_prochain_geste = randf_range(5.0, 9.0)
		"discute":
			# Un petit geste de la main de temps en temps.
			_apparence.attaquer("sort", 1.4)
			_prochain_geste = randf_range(4.0, 10.0)
		_:
			_prochain_geste = 999.0


## Point suivant, avec une pause aux arrêts (ou aux deux bouts d'un aller-retour).
func _suivant() -> void:
	var arrive := _cible
	var prochain := _cible + _sens
	var bout := false
	if prochain >= chemin.size():
		if boucle:
			prochain = 0
		else:
			_sens = -1
			prochain = _cible - 1
			bout = true
	elif prochain < 0:
		_sens = 1
		prochain = 1
		bout = true
	var s_arrete := arrive in arrets or (arrets.is_empty() and (bout or (boucle and arrive == 0)))
	if s_arrete:
		_attente = randf_range(pause.x, pause.y)
		_prochain_geste = randf_range(0.3, 1.0)
	_cible = prochain
