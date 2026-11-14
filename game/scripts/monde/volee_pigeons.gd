extends Node3D
## Une petite volée de pigeons de Hikari Bay. Ils picorent au sol ; quand le
## joueur s'approche, ils s'envolent tous ensemble et vont se poser sur leur
## perchoir (rebord de la fontaine, garde-corps…). Ils redescendent picorer
## quand le joueur s'est éloigné.
## Les volées sont décrites dans data/hub_vie.json (modifiable sans code).

## Au-delà de cette distance de la caméra, la volée est cachée et ne calcule rien.
const DISTANCE_VISIBLE := 60.0
## Distance du joueur qui fait s'envoler les pigeons posés au sol.
const DISTANCE_PEUR := 4.0
## Distance du joueur au coin de picorage pour que les pigeons y redescendent.
const DISTANCE_RETOUR := 9.0
const RAYON_SOL := 1.8

enum Etat { SOL, VOL, PERCHE }

## Centre du coin où ils picorent (y = hauteur du sol).
var sol := Vector3.ZERO
## Milieu du perchoir, et demi-longueur du perchoir (vecteur horizontal).
var perchoir := Vector3(0, 1, 0)
var etendue_perchoir := Vector3(1, 0, 0)
var nombre := 7

var etat := Etat.SOL
var _oiseaux: Array[Dictionary] = []
var _attente := 0.0

static var _maillages := {}


func _ready() -> void:
	add_to_group("pigeons")
	_preparer_maillages()
	for i in nombre:
		var o := _creer_oiseau(i)
		add_child(o["noeud"])
		_oiseaux.append(o)
		o["noeud"].global_position = _point_sol()
		o["noeud"].rotation.y = randf() * TAU
		o["but"] = o["noeud"].global_position


## Les pigeons sont-ils tous posés (au sol ou sur le perchoir) ?
func poses() -> bool:
	return etat != Etat.VOL


func _point_sol() -> Vector3:
	var a := randf() * TAU
	var r := sqrt(randf()) * RAYON_SOL
	return sol + Vector3(cos(a) * r, 0, sin(a) * r)


func _point_perchoir(i: int) -> Vector3:
	var t := 0.0 if nombre <= 1 else lerpf(-1.0, 1.0, float(i) / float(nombre - 1))
	return perchoir + etendue_perchoir * (t + randf_range(-0.08, 0.08))


func _physics_process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var proche := camera.global_position.distance_to(sol) < DISTANCE_VISIBLE
		if visible != proche:
			visible = proche
		if not proche and etat != Etat.VOL:
			return
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	match etat:
		Etat.SOL:
			if joueur != null and _plus_proche(joueur.global_position) < DISTANCE_PEUR:
				_envol(true)
			else:
				for o in _oiseaux:
					_picorer(o, delta)
		Etat.PERCHE:
			_attente -= delta
			var loin := joueur == null or joueur.global_position.distance_to(sol) > DISTANCE_RETOUR
			if _attente <= 0.0 and loin:
				_envol(false)
			for o in _oiseaux:
				_au_repos(o, delta)
		Etat.VOL:
			var tous := true
			for o in _oiseaux:
				if not _voler(o, delta):
					tous = false
			if tous:
				etat = Etat.PERCHE if _vers_perchoir else Etat.SOL
				_attente = randf_range(12.0, 25.0)


var _vers_perchoir := false


func _plus_proche(p: Vector3) -> float:
	var d := INF
	for o in _oiseaux:
		d = minf(d, (o["noeud"] as Node3D).global_position.distance_to(p))
	return d


func _envol(vers_perchoir: bool) -> void:
	_vers_perchoir = vers_perchoir
	etat = Etat.VOL
	for i in _oiseaux.size():
		var o := _oiseaux[i]
		o["depart"] = (o["noeud"] as Node3D).global_position
		o["arrivee"] = _point_perchoir(i) if vers_perchoir else _point_sol()
		var longueur: float = (o["arrivee"] - o["depart"]).length()
		o["duree"] = clampf(longueur / 6.0, 1.2, 4.0) * randf_range(0.9, 1.15)
		o["t"] = -randf_range(0.0, 0.35) # pas tous en même temps
		o["hauteur"] = clampf(longueur * 0.25, 1.5, 4.0)


## Fait avancer un oiseau en vol. Renvoie true quand il est posé.
func _voler(o: Dictionary, delta: float) -> bool:
	var n: Node3D = o["noeud"]
	o["t"] += delta / float(o["duree"])
	var t := clampf(float(o["t"]), 0.0, 1.0)
	var depart: Vector3 = o["depart"]
	var arrivee: Vector3 = o["arrivee"]
	# Montée franche au départ, descente planée à la fin.
	var s := 1.0 - pow(1.0 - t, 1.6)
	var p := depart.lerp(arrivee, s)
	p.y += sin(t * PI) * float(o["hauteur"])
	var dir := p - n.global_position
	n.global_position = p
	if Vector2(dir.x, dir.z).length() > 0.001:
		n.rotation.y = atan2(-dir.x, -dir.z)
	n.rotation.x = clampf(dir.y / maxf(delta * 6.0, 0.001), -0.5, 0.6) * 0.5 if t < 1.0 else 0.0
	# Battements rapides, ailes tendues en fin de descente (vol plané).
	var battement := 0.0
	if t > 0.0 and t < 0.8:
		battement = sin(float(o["t"]) * float(o["duree"]) * 38.0) * 1.1
	elif t >= 0.8 and t < 1.0:
		battement = -0.25
	_ailes(o, 1.0 if t > 0.0 and t < 1.0 else 0.0, battement)
	if t >= 1.0:
		n.rotation.x = 0.0
		o["but"] = n.global_position
		return true
	return false


func _ailes(o: Dictionary, ouverture: float, battement: float) -> void:
	# ouverture 0 : ailes repliées ; 1 : ailes ouvertes.
	var g: Node3D = o["aile_g"]
	var d: Node3D = o["aile_d"]
	g.rotation.z = lerpf(-0.45, 0.0, ouverture) + battement * ouverture
	d.rotation.z = -g.rotation.z
	# Repliées, les ailes se confondent avec le corps : on ne montre que lui.
	g.visible = ouverture > 0.0
	d.visible = g.visible


func _picorer(o: Dictionary, delta: float) -> void:
	var n: Node3D = o["noeud"]
	var tete: Node3D = o["tete"]
	o["pas"] = float(o.get("pas", 0.0)) - delta
	var but: Vector3 = o["but"]
	var vers := but - n.global_position
	vers.y = 0.0
	if vers.length() > 0.05:
		# Petits pas pressés, la tête qui avance et recule.
		var v := minf(0.45 * delta, vers.length())
		n.global_position += vers.normalized() * v
		n.rotation.y = lerp_angle(n.rotation.y, atan2(-vers.x, -vers.z), 8.0 * delta)
		o["cycle"] = float(o.get("cycle", 0.0)) + delta * 9.0
		tete.position.z = -0.115 + sin(float(o["cycle"])) * 0.02
		tete.rotation.x = 0.0
	elif float(o["pas"]) <= 0.0:
		o["pas"] = randf_range(0.6, 2.8)
		if randf() < 0.55:
			o["but"] = sol + (n.global_position - sol).limit_length(RAYON_SOL) \
					+ Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
			o["but"].y = sol.y
		else:
			o["picore"] = 0.5
	if float(o.get("picore", 0.0)) > 0.0:
		o["picore"] = float(o["picore"]) - delta
		tete.rotation.x = -absf(sin(float(o["picore"]) * TAU * 2.0)) * 1.1
	_ailes(o, 0.0, 0.0)


func _au_repos(o: Dictionary, delta: float) -> void:
	var tete: Node3D = o["tete"]
	o["pas"] = float(o.get("pas", 0.0)) - delta
	if float(o["pas"]) <= 0.0:
		o["pas"] = randf_range(1.0, 4.0)
		o["regard"] = randf_range(-0.8, 0.8)
	tete.rotation.y = lerp_angle(tete.rotation.y, float(o.get("regard", 0.0)), 5.0 * delta)
	tete.rotation.x = 0.0
	tete.position.z = -0.115
	_ailes(o, 0.0, 0.0)


# --- Apparence ---------------------------------------------------------------

static func _preparer_maillages() -> void:
	if not _maillages.is_empty():
		return
	var plumage := StandardMaterial3D.new()
	plumage.albedo_color = Color(0.3, 0.32, 0.38)
	plumage.roughness = 0.85
	var sombre := StandardMaterial3D.new()
	sombre.albedo_color = Color(0.13, 0.13, 0.16)
	sombre.roughness = 0.85
	var cou := StandardMaterial3D.new()
	cou.albedo_color = Color(0.2, 0.32, 0.28)
	cou.metallic = 0.4
	cou.roughness = 0.35
	var bec := StandardMaterial3D.new()
	bec.albedo_color = Color(0.15, 0.13, 0.12)
	var pattes := StandardMaterial3D.new()
	pattes.albedo_color = Color(0.7, 0.28, 0.25)
	var oeil := StandardMaterial3D.new()
	oeil.albedo_color = Color(0.9, 0.45, 0.1)
	oeil.roughness = 0.2

	var corps := SphereMesh.new()
	corps.radius = 0.075
	corps.height = 0.15
	corps.radial_segments = 12
	corps.rings = 6
	corps.material = plumage
	var gorge := SphereMesh.new()
	gorge.radius = 0.042
	gorge.height = 0.084
	gorge.radial_segments = 10
	gorge.rings = 5
	gorge.material = cou
	var tete := SphereMesh.new()
	tete.radius = 0.032
	tete.height = 0.064
	tete.radial_segments = 10
	tete.rings = 5
	tete.material = plumage
	var b := CylinderMesh.new()
	b.top_radius = 0.003
	b.bottom_radius = 0.008
	b.height = 0.03
	b.radial_segments = 6
	b.material = bec
	var queue := BoxMesh.new()
	queue.size = Vector3(0.055, 0.012, 0.09)
	queue.material = sombre
	var aile := BoxMesh.new()
	aile.size = Vector3(0.2, 0.012, 0.17)
	aile.material = plumage
	var barre := BoxMesh.new()
	barre.size = Vector3(0.13, 0.014, 0.025)
	barre.material = sombre
	var bande := BoxMesh.new()
	bande.size = Vector3(0.006, 0.04, 0.014)
	bande.material = sombre
	var patte := CylinderMesh.new()
	patte.top_radius = 0.005
	patte.bottom_radius = 0.005
	patte.height = 0.06
	patte.radial_segments = 4
	patte.material = pattes
	var o := SphereMesh.new()
	o.radius = 0.005
	o.height = 0.01
	o.radial_segments = 6
	o.rings = 3
	o.material = oeil
	_maillages = {"corps": corps, "gorge": gorge, "tete": tete, "bec": b, "queue": queue,
			"aile": aile, "barre": barre, "bande": bande, "patte": patte, "oeil": o}


func _morceau(nom: String, parent: Node3D, p: Vector3, echelle := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _maillages[nom]
	mi.position = p
	mi.scale = echelle
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _creer_oiseau(i: int) -> Dictionary:
	var n := Node3D.new()
	n.name = "Pigeon%d" % i
	var s := randf_range(0.9, 1.08)
	n.scale = Vector3.ONE * s
	# Le corps est allongé, un peu penché vers l'avant ; -Z = l'avant.
	_morceau("corps", n, Vector3(0, 0.1, 0.01), Vector3(0.85, 0.9, 1.75), Vector3(-0.22, 0, 0))
	_morceau("gorge", n, Vector3(0, 0.15, -0.08), Vector3(0.9, 1.1, 1.0))
	_morceau("queue", n, Vector3(0, 0.095, 0.16), Vector3.ONE, Vector3(0.2, 0, 0))
	# Les deux barres sombres des ailes repliées, sur les flancs.
	for cote in [1.0, -1.0]:
		_morceau("bande", n, Vector3(0.058 * cote, 0.12, 0.03), Vector3.ONE, Vector3(0, 0, 0.5 * cote))
		_morceau("bande", n, Vector3(0.056 * cote, 0.117, 0.06), Vector3.ONE, Vector3(0, 0, 0.5 * cote))
	_morceau("patte", n, Vector3(0.025, 0.03, 0.0))
	_morceau("patte", n, Vector3(-0.025, 0.03, 0.0))
	var tete := Node3D.new()
	tete.position = Vector3(0, 0.195, -0.115)
	n.add_child(tete)
	_morceau("tete", tete, Vector3.ZERO)
	_morceau("bec", tete, Vector3(0, -0.004, -0.04), Vector3.ONE, Vector3(-PI / 2, 0, 0))
	_morceau("oeil", tete, Vector3(0.024, 0.008, -0.012))
	_morceau("oeil", tete, Vector3(-0.024, 0.008, -0.012))
	var ailes := []
	for cote in [1.0, -1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.03 * cote, 0.145, 0.0)
		n.add_child(pivot)
		# Rotation z du pivot : aile ouverte à 0, repliée sur le dos et le flanc à ∓0,45.
		var a := _morceau("aile", pivot, Vector3(0.095 * cote, 0, 0.04), Vector3.ONE, Vector3(-0.12, 0, 0))
		_morceau("barre", a, Vector3(0.01 * cote, 0.002, 0.0))
		_morceau("barre", a, Vector3(0.01 * cote, 0.002, 0.035))
		ailes.append(pivot)
	return {"noeud": n, "tete": tete, "aile_g": ailes[0], "aile_d": ailes[1]}
