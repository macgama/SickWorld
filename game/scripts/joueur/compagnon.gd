extends Node3D
## Le petit compagnon d'un personnage : Glaukê, la chouette de Néra (île de Grèce), Bise, le
## faucon pèlerin de dame Héloïse (Moyen Âge), ou
## l'oie du Capitole (île de Rome), qui marche en se dandinant derrière soi et crie quand un
## prétorien de Janus ou un Effaceur approche (comme les oies qui ont sauvé Rome des Gaulois).
## Il apparaît quand on porte l'objet qui a la clé « compagnon » (data/objets.json) :
## la chouette se tient sur l'épaule droite quand on marche ou qu'on attend, et s'envole
## au-dessus de soi quand on court ou qu'on se bat, en battant des ailes.
## Ajouté et retiré par l'inventaire (voir inventaire.gd, _habiller).

var espece := "chouette"

var _joueur: Node3D
var _squelette: Skeleton3D
var _os_epaule := -1
var _corps: Node3D
var _ailes: Array[Node3D] = []
var _tete: Node3D
var _temps := 0.0
var _vol := 0.0
var _derniere := Vector3.ZERO
var _vitesse := 0.0
var _regard := 0.0
var _cou: Node3D
var _cri := 0.0
var _attente_cri := 0.0
var _pattes: Array[Node3D] = []


func _ready() -> void:
	top_level = true
	_joueur = get_parent() as Node3D
	_construire()
	if _joueur != null:
		global_position = _joueur.global_position + (Vector3(0.6, 0, 1.1) if espece in ["oie", "panda"] else Vector3(0.2, 1.6, 0))
		_derniere = _joueur.global_position


func _mat(couleur: Color, rugosite := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = rugosite
	return m


func _boule(parent: Node3D, rayon: float, haut: float, mat: Material, p: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = rayon
	s.height = haut
	mi.mesh = s
	mi.material_override = mat
	mi.position = p
	parent.add_child(mi)
	return mi


## Une chevêche : 22 cm, brune tachetée de blanc, grosse tête ronde, yeux jaunes.
func _construire() -> void:
	if espece == "panda":
		_construire_panda()
		return
	if espece == "oie":
		_construire_oie()
		return
	# Le faucon pèlerin de dame Héloïse (Moyen Âge) : même silhouette, plus fine, gris ardoise
	# dessus, poitrine claire, la « moustache » noire et les yeux sombres cerclés de jaune.
	var faucon := espece == "faucon"
	var plume := _mat(Color(0.3, 0.32, 0.36) if faucon else Color(0.45, 0.34, 0.24))
	var clair := _mat(Color(0.88, 0.84, 0.76) if faucon else Color(0.82, 0.76, 0.66))
	var jaune := _mat(Color(1.0, 0.8, 0.25), 0.3)
	jaune.emission_enabled = true
	jaune.emission = Color(1.0, 0.75, 0.2)
	jaune.emission_energy_multiplier = 0.5
	var noir := _mat(Color(0.02, 0.02, 0.02), 0.2)
	_corps = Node3D.new()
	add_child(_corps)
	if faucon:
		_corps.scale = Vector3(0.85, 1.15, 1.1)
	_boule(_corps, 0.065, 0.16, plume, Vector3(0, 0.08, 0))
	_boule(_corps, 0.05, 0.12, clair, Vector3(0, 0.075, -0.025))
	# Les taches blanches du dos.
	for k in 5:
		_boule(_corps, 0.008, 0.016, clair, Vector3(sin(k * 1.3) * 0.03, 0.06 + k * 0.012, 0.058))
	_tete = Node3D.new()
	_tete.position = Vector3(0, 0.17, 0)
	_corps.add_child(_tete)
	_boule(_tete, 0.05, 0.095, plume, Vector3.ZERO)
	for c in [-1.0, 1.0]:
		_boule(_tete, 0.015 if not faucon else 0.012, 0.028 if not faucon else 0.022, jaune, Vector3(c * 0.02, 0.005, -0.042))
		_boule(_tete, 0.007 if not faucon else 0.01, 0.014 if not faucon else 0.02, noir, Vector3(c * 0.02, 0.005, -0.05 if faucon else -0.056))
		if faucon:
			_boule(_tete, 0.008, 0.035, noir, Vector3(c * 0.028, -0.02, -0.036))
		else:
			_boule(_tete, 0.012, 0.01, clair, Vector3(c * 0.022, 0.024, -0.04))
	var bec := MeshInstance3D.new()
	var p := PrismMesh.new()
	p.size = Vector3(0.014, 0.02, 0.014)
	bec.mesh = p
	bec.material_override = _mat(Color(0.75, 0.7, 0.5))
	bec.position = Vector3(0, -0.014, -0.05)
	bec.rotation.x = PI
	_tete.add_child(bec)
	for c in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(c * 0.055, 0.11, 0.01)
		_corps.add_child(pivot)
		var aile := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.17, 0.012, 0.08) if faucon else Vector3(0.13, 0.012, 0.09)
		aile.mesh = b
		aile.material_override = plume
		aile.position = Vector3(c * 0.06, 0, 0)
		pivot.add_child(aile)
		_ailes.append(pivot)
	var queue := MeshInstance3D.new()
	var q := BoxMesh.new()
	q.size = Vector3(0.045, 0.01, 0.09) if faucon else Vector3(0.05, 0.01, 0.05)
	queue.mesh = q
	queue.material_override = plume
	queue.position = Vector3(0, 0.02, 0.06)
	queue.rotation.x = 0.5
	_corps.add_child(queue)


## Une oie domestique blanche (comme celles de Junon) : 80 cm, long cou, bec et pattes orange.
func _construire_oie() -> void:
	var blanc := _mat(Color(0.95, 0.94, 0.9), 0.8)
	var gris := _mat(Color(0.78, 0.78, 0.76), 0.8)
	var orange := _mat(Color(0.95, 0.5, 0.12), 0.5)
	var noir := _mat(Color(0.02, 0.02, 0.02), 0.2)
	_corps = Node3D.new()
	add_child(_corps)
	var ventre := _boule(_corps, 0.17, 0.3, blanc, Vector3(0, 0.32, 0.02))
	ventre.scale = Vector3(1.0, 1.0, 1.55)
	var dos := _boule(_corps, 0.13, 0.2, gris, Vector3(0, 0.4, 0.1))
	dos.scale = Vector3(1.05, 0.6, 1.5)
	var queue := _boule(_corps, 0.07, 0.1, gris, Vector3(0, 0.42, 0.3))
	queue.scale = Vector3(1.2, 0.6, 1.4)
	for c in [-1.0, 1.0]:
		var aile := _boule(_corps, 0.12, 0.16, gris, Vector3(c * 0.13, 0.38, 0.06))
		aile.scale = Vector3(0.35, 0.8, 1.6)
		var pivot := Node3D.new()
		pivot.position = Vector3(c * 0.07, 0.2, 0.02)
		_corps.add_child(pivot)
		var patte := MeshInstance3D.new()
		var tige := CylinderMesh.new()
		tige.top_radius = 0.014
		tige.bottom_radius = 0.012
		tige.height = 0.2
		patte.mesh = tige
		patte.material_override = orange
		patte.position.y = -0.1
		pivot.add_child(patte)
		var palme := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.07, 0.012, 0.09)
		palme.mesh = b
		palme.material_override = orange
		palme.position = Vector3(0, -0.2, -0.03)
		pivot.add_child(palme)
		_pattes.append(pivot)
	# Le cou (long, un peu courbé) et la tête : c'est le cou qui se tend quand elle crie.
	_cou = Node3D.new()
	_cou.position = Vector3(0, 0.42, -0.2)
	_corps.add_child(_cou)
	var cou := MeshInstance3D.new()
	var c3 := CylinderMesh.new()
	c3.top_radius = 0.035
	c3.bottom_radius = 0.06
	c3.height = 0.3
	cou.mesh = c3
	cou.material_override = blanc
	cou.position = Vector3(0, 0.14, -0.03)
	cou.rotation.x = -0.25
	_cou.add_child(cou)
	_tete = Node3D.new()
	_tete.position = Vector3(0, 0.3, -0.08)
	_cou.add_child(_tete)
	var crane := _boule(_tete, 0.055, 0.1, blanc, Vector3.ZERO)
	crane.scale = Vector3(0.9, 1.0, 1.3)
	var bec := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.004
	cone.bottom_radius = 0.026
	cone.height = 0.09
	bec.mesh = cone
	bec.material_override = orange
	bec.position = Vector3(0, -0.01, -0.09)
	bec.rotation.x = -PI * 0.5
	_tete.add_child(bec)
	for c in [-1.0, 1.0]:
		_boule(_tete, 0.009, 0.018, noir, Vector3(c * 0.04, 0.015, -0.025))


## Un bébé panda des monts Qinling : une boule de poils noire et blanche de 40 cm, qui
## trottine à quatre pattes en roulant des épaules. Il se dresse et couine quand un soldat
## d'argile ou un homme de Cinabre approche.
func _construire_panda() -> void:
	var blanc := _mat(Color(0.93, 0.91, 0.86), 1.0)
	var noir := _mat(Color(0.06, 0.055, 0.05), 1.0)
	var luisant := _mat(Color(0.02, 0.02, 0.02), 0.2)
	_corps = Node3D.new()
	add_child(_corps)
	var ventre := _boule(_corps, 0.2, 0.36, blanc, Vector3(0, 0.26, 0.04))
	ventre.scale = Vector3(1.0, 0.95, 1.3)
	var epaules := _boule(_corps, 0.17, 0.26, noir, Vector3(0, 0.3, -0.1))
	epaules.scale = Vector3(1.15, 0.9, 0.7)
	# Quatre pattes noires, courtes et rondes.
	for k in 4:
		var c := -1.0 if k % 2 == 0 else 1.0
		var avant := k < 2
		var pivot := Node3D.new()
		pivot.position = Vector3(c * 0.11, 0.2, -0.14 if avant else 0.16)
		_corps.add_child(pivot)
		var patte := _boule(pivot, 0.07, 0.22, noir, Vector3(0, -0.1, 0))
		patte.scale = Vector3(1.0, 1.0, 1.1)
		_pattes.append(pivot)
	_cou = Node3D.new()
	_cou.position = Vector3(0, 0.36, -0.22)
	_corps.add_child(_cou)
	_tete = Node3D.new()
	_tete.position = Vector3(0, 0.04, -0.06)
	_cou.add_child(_tete)
	var crane := _boule(_tete, 0.14, 0.24, blanc, Vector3.ZERO)
	crane.scale = Vector3(1.1, 0.95, 1.0)
	for c in [-1.0, 1.0]:
		_boule(_tete, 0.05, 0.06, noir, Vector3(c * 0.1, 0.1, 0.02))
		var tache := _boule(_tete, 0.04, 0.05, noir, Vector3(c * 0.055, 0.01, -0.11))
		tache.scale = Vector3(0.8, 1.2, 0.5)
		tache.rotation.z = c * 0.5
		_boule(_tete, 0.012, 0.02, luisant, Vector3(c * 0.055, 0.015, -0.135))
	var museau := _boule(_tete, 0.05, 0.07, blanc, Vector3(0, -0.04, -0.12))
	museau.scale = Vector3(1.2, 0.8, 1.0)
	_boule(_tete, 0.018, 0.022, luisant, Vector3(0, -0.02, -0.17))


## L'oie : elle trottine derrière soi, au sol, et crie quand un ennemi de Janus approche.
func _suivre_au_sol(delta: float) -> void:
	var derriere := _joueur.global_transform * Vector3(0.6, 0.0, 1.1)
	var ecart := Vector2(derriere.x - global_position.x, derriere.z - global_position.z)
	var marche := ecart.length() > 0.35
	if ecart.length() > 12.0:
		global_position = derriere
	elif marche:
		var pas := minf(ecart.length(), maxf(_vitesse, 2.0) * 1.15 * delta)
		var d := ecart.normalized() * pas
		global_position += Vector3(d.x, 0, d.y)
		rotation.y = lerp_angle(rotation.y, atan2(-ecart.x, -ecart.y), minf(1.0, delta * 8.0))
	global_position.y = lerpf(global_position.y, _joueur.global_position.y, minf(1.0, delta * 10.0))
	# Le dandinement : le corps roule d'un côté à l'autre, les pattes alternent.
	var t := _temps * 11.0
	var amplitude := 1.0 if marche else 0.0
	_corps.rotation.z = 0.12 * sin(t) * amplitude
	for k in _pattes.size():
		_pattes[k].rotation.x = 0.5 * sin(t + PI * k) * amplitude
	# Un prétorien de Janus ou un Effaceur à moins de 18 m : elle tend le cou et crie.
	_attente_cri -= delta
	if _attente_cri <= 0.0:
		_attente_cri = 0.5
		if _danger_proche():
			_cri = 1.4
	_cri = maxf(0.0, _cri - delta)
	var tendu := clampf(_cri, 0.0, 1.0)
	_cou.rotation.x = lerpf(0.0, -0.7, tendu) + 0.05 * sin(_temps * 2.0)
	_tete.rotation.x = 0.4 * sin(_temps * 30.0) * tendu


func _danger_proche() -> bool:
	for bete in get_tree().get_nodes_in_group("loups"):
		var type := String(bete.get("type_ennemi"))
		var ennemi_du_compagnon := type.begins_with("pretorien") or type.contains("effaceur") or type.begins_with("masque")
		if espece == "panda":
			ennemi_du_compagnon = type.contains("argile") or type.contains("cinabre") or type.contains("effaceur")
		if not ennemi_du_compagnon:
			continue
		var c = bete.get("combat")
		if c != null and c.est_vivant() and (bete as Node3D).global_position.distance_to(_joueur.global_position) < 18.0:
			return true
	return false


## Vrai pendant que l'oie crie (pour les tests et les sons).
func crie() -> bool:
	return _cri > 0.0


func _point_epaule() -> Vector3:
	if _squelette == null or not is_instance_valid(_squelette):
		_squelette = null
		var trouves := _joueur.find_children("*", "Skeleton3D", true, false)
		if not trouves.is_empty():
			_squelette = trouves[0]
			_os_epaule = _squelette.find_bone("mixamorig_RightShoulder")
	if _squelette != null and _os_epaule >= 0:
		var t := _squelette.global_transform * _squelette.get_bone_global_pose(_os_epaule)
		return t.origin + _joueur.global_transform.basis * Vector3(-0.06, 0.07, 0.02)
	return _joueur.global_transform * Vector3(-0.2, 1.52, 0.0)


func _process(delta: float) -> void:
	if _joueur == null or not is_instance_valid(_joueur):
		queue_free()
		return
	_temps += delta
	var deplacement := _joueur.global_position - _derniere
	_derniere = _joueur.global_position
	_vitesse = lerpf(_vitesse, Vector2(deplacement.x, deplacement.z).length() / maxf(delta, 0.001), 0.1)
	if espece == "oie" or espece == "panda":
		_suivre_au_sol(delta)
		return
	var combat = _joueur.get_node_or_null("Combat")
	var en_vol: bool = _vitesse > 4.5 or (combat != null and combat.has_method("en_combat") and combat.en_combat())
	_vol = move_toward(_vol, 1.0 if en_vol else 0.0, delta * 2.0)
	var perche := _point_epaule()
	var en_l_air := _joueur.global_transform * Vector3(0.5 * sin(_temps * 0.7), 2.4 + 0.15 * sin(_temps * 2.3), 0.9)
	var cible := perche.lerp(en_l_air, _vol)
	if _vol < 0.02:
		global_position = cible
	else:
		global_position = global_position.lerp(cible, minf(1.0, delta * 6.0))
	var face := _joueur.global_rotation.y
	rotation = Vector3(0, face, 0)
	# Battements d'ailes en vol ; au repos, la tête tourne de temps en temps (comme une vraie chouette).
	var battement := sin(_temps * 22.0) * 1.1 * _vol
	for k in _ailes.size():
		_ailes[k].rotation.z = (battement + 0.1 * (1.0 - _vol)) * (1.0 if k == 0 else -1.0)
	if fmod(_temps, 6.0) < delta:
		_regard = randf_range(-1.6, 1.6)
	if fmod(_temps, 6.0) > 2.2:
		_regard = move_toward(_regard, 0.0, delta * 2.0)
	_tete.rotation.y = lerp_angle(_tete.rotation.y, _regard, minf(1.0, delta * 5.0))
	_corps.rotation.x = -0.5 * _vol
