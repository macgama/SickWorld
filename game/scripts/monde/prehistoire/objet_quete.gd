@tool
extends Node3D
## Un objet ou un endroit avec lequel on interagit pendant une quête (F) :
## ramasser une trousse, soigner un blessé, refermer une faille…
## Il n'est utilisable que lorsque la quête en cours le demande (« actif »).
## La quête (groupe « quete ») gère la durée de l'action et la suite.

## Nom de l'objet dans data/prehistoire_quete.json (clé « objet » d'une étape).
@export var identifiant := ""
## Texte affiché quand on est assez près.
@export var invite := "[F] Utiliser"
## Apparence : "" (rien, un simple endroit), "trousse", ou un tas de pigment
## à récolter : "ocre", "charbon", "manganese".
@export var forme := "":
	set(valeur):
		forme = valeur
		if is_inside_tree():
			_construire()
## Distance (mètres) à laquelle on peut l'utiliser.
@export var portee := 3.0
## Pour une étape « recolter » : tous les objets du même groupe comptent
## (ex. « ocre » : trois tas d'ocre rouge le long de la rivière).
@export var groupe := ""

## Vrai quand l'objet a déjà été récolté.
var ramasse := false

## Vrai quand la quête attend qu'on utilise cet objet.
var actif := false:
	set(valeur):
		actif = valeur
		if _halo != null:
			_halo.visible = valeur
var _etiquette: Label3D
var _halo: OmniLight3D
var _visuel: Node3D
var _temps := 0.0


func _ready() -> void:
	add_to_group("objet_quete")
	_construire()


func _construire() -> void:
	for enfant in get_children():
		enfant.free()
	_visuel = Node3D.new()
	add_child(_visuel)
	if forme == "trousse":
		_construire_trousse()
	elif forme == "montre":
		_construire_montre()
	elif COULEURS_TAS.has(forme):
		_construire_tas(COULEURS_TAS[forme])
	elif forme != "" and has_method("_construire_" + forme):
		call("_construire_" + forme)
	_etiquette = Label3D.new()
	_etiquette.text = invite
	_etiquette.position = Vector3(0, 1.0, 0)
	_etiquette.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_etiquette.font_size = 36
	_etiquette.pixel_size = 0.005
	_etiquette.outline_size = 10
	_etiquette.visible = false
	add_child(_etiquette)
	_halo = OmniLight3D.new()
	_halo.light_color = Color(1.0, 0.82, 0.35)
	_halo.light_energy = 0.8
	_halo.omni_range = 2.5
	_halo.position = Vector3(0, 0.6, 0)
	_halo.visible = actif and forme != ""
	add_child(_halo)


const COULEURS_TAS := {
	"ocre": Color(0.62, 0.2, 0.08),
	"charbon": Color(0.05, 0.045, 0.04),
	"manganese": Color(0.13, 0.09, 0.12),
	"resine": Color(0.78, 0.45, 0.08),
}


## Un petit tas de pierres colorées (pigments de peinture des grottes).
func _construire_tas(couleur: Color) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = 0.95
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(identifiant + forme + str(position))
	for k in 9:
		var caillou := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = hasard.randf_range(0.06, 0.14)
		sphere.height = sphere.radius * hasard.randf_range(1.0, 1.6)
		sphere.radial_segments = 7
		sphere.rings = 4
		caillou.mesh = sphere
		caillou.material_override = m
		var a := hasard.randf() * TAU
		caillou.position = Vector3(cos(a), 0.0, sin(a)) * hasard.randf_range(0.0, 0.28) + Vector3(0, 0.05, 0)
		caillou.rotation = Vector3(hasard.randf(), hasard.randf() * TAU, hasard.randf())
		_visuel.add_child(caillou)
	# Une trace de poudre colorée sur le sol.
	var poudre := MeshInstance3D.new()
	var disque := CylinderMesh.new()
	disque.top_radius = 0.45
	disque.bottom_radius = 0.5
	disque.height = 0.02
	poudre.mesh = disque
	var mp := StandardMaterial3D.new()
	mp.albedo_color = couleur.lightened(0.1)
	mp.roughness = 1.0
	poudre.material_override = mp
	_visuel.add_child(poudre)


## Trousse de soin de la Vigie : une mallette blanche frappée d'une croix rouge.
## Une montre à gousset dorée, le verre fendu, à moitié dans la neige.
func _construire_montre() -> void:
	var or_mat := StandardMaterial3D.new()
	or_mat.albedo_color = Color(0.83, 0.66, 0.32)
	or_mat.metallic = 1.0
	or_mat.roughness = 0.3
	var verre := StandardMaterial3D.new()
	verre.albedo_color = Color(0.92, 0.9, 0.82)
	verre.roughness = 0.15
	var boitier := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.06
	c.bottom_radius = 0.06
	c.height = 0.018
	c.radial_segments = 24
	boitier.mesh = c
	boitier.material_override = or_mat
	boitier.position.y = 0.012
	_visuel.add_child(boitier)
	var cadran := MeshInstance3D.new()
	var d := CylinderMesh.new()
	d.top_radius = 0.05
	d.bottom_radius = 0.05
	d.height = 0.004
	cadran.mesh = d
	cadran.material_override = verre
	cadran.position.y = 0.022
	_visuel.add_child(cadran)
	var noir := StandardMaterial3D.new()
	noir.albedo_color = Color(0.05, 0.05, 0.05)
	for k in 2:
		var aiguille := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.003, 0.002, 0.04 if k == 0 else 0.028)
		aiguille.mesh = b
		aiguille.material_override = noir
		aiguille.position = Vector3(0, 0.025, 0)
		aiguille.rotation.y = 0.9 + k * 2.2
		aiguille.translate_object_local(Vector3(0, 0, -b.size.z * 0.5))
		_visuel.add_child(aiguille)
	# La bélière et un bout de chaîne.
	var anneau := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.008
	t.outer_radius = 0.016
	anneau.mesh = t
	anneau.material_override = or_mat
	anneau.position = Vector3(0, 0.012, -0.072)
	_visuel.add_child(anneau)
	for k in 8:
		var maillon := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.004
		tm.outer_radius = 0.009
		maillon.mesh = tm
		maillon.material_override = or_mat
		maillon.position = Vector3(sin(k * 0.5) * 0.03, 0.006, -0.09 - k * 0.014)
		maillon.rotation.z = PI / 2 if k % 2 == 0 else 0.0
		_visuel.add_child(maillon)
	_visuel.rotation = Vector3(0.12, 0.7, 0.05)


func _construire_trousse() -> void:
	var blanc := StandardMaterial3D.new()
	blanc.albedo_color = Color(0.9, 0.9, 0.88)
	blanc.roughness = 0.4
	var rouge := StandardMaterial3D.new()
	rouge.albedo_color = Color(0.8, 0.08, 0.06)
	rouge.emission_enabled = true
	rouge.emission = Color(0.8, 0.1, 0.05)
	rouge.emission_energy_multiplier = 0.4
	var boite := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.5, 0.18, 0.34)
	boite.mesh = b
	boite.material_override = blanc
	boite.position.y = 0.09
	_visuel.add_child(boite)
	for taille in [Vector3(0.22, 0.01, 0.07), Vector3(0.07, 0.01, 0.22)]:
		var croix := MeshInstance3D.new()
		var t := BoxMesh.new()
		t.size = taille
		croix.mesh = t
		croix.material_override = rouge
		croix.position.y = 0.185
		_visuel.add_child(croix)
	_visuel.rotation = Vector3(0.1, 0.8, 0.12)


func joueur_proche() -> bool:
	var joueur := get_tree().get_first_node_in_group("joueur_local") as Node3D
	return joueur != null and joueur.global_position.distance_to(global_position) < portee


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _etiquette == null:
		return
	_temps += delta
	var dialogue := get_tree().get_first_node_in_group("dialogue")
	var occupe: bool = dialogue != null and dialogue.est_ouvert()
	_etiquette.visible = actif and visible and joueur_proche() and not occupe
	if _halo != null and _halo.visible:
		_halo.light_energy = 0.6 + 0.3 * sin(_temps * 3.0)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not actif or not visible or not event.is_action_pressed("interagir"):
		return
	var dialogue := get_tree().get_first_node_in_group("dialogue")
	if (dialogue != null and dialogue.est_ouvert()) or not joueur_proche():
		return
	var quete := get_tree().get_first_node_in_group("quete")
	if has_meta("secondaire"):
		quete = get_tree().get_first_node_in_group("quetes_secondaires")
	elif has_meta("evenement"):
		quete = get_tree().get_first_node_in_group("evenements_publics")
	if quete == null:
		return
	get_viewport().set_input_as_handled()
	quete.utiliser_objet(self)


## Fait disparaître l'objet (ramassé).
func cacher() -> void:
	actif = false
	if _visuel != null:
		_visuel.visible = false


# --- Objets des quêtes secondaires -----------------------------------------------

func _mat(couleur: Color, rugosite := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = rugosite
	m.metallic = metal
	return m


func _piece(maillage: Mesh, materiau: Material, pos: Vector3, rot := Vector3.ZERO, echelle := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = maillage
	mi.material_override = materiau
	mi.position = pos
	mi.rotation = rot
	mi.scale = echelle
	_visuel.add_child(mi)
	return mi


## Un coquillage nacré (une coquille Saint-Jacques) posé sur les galets.
func _construire_coquillage() -> void:
	var nacre := _mat(Color(0.93, 0.85, 0.76), 0.35)
	var raie := _mat(Color(0.78, 0.52, 0.42), 0.4)
	for k in 7:
		var c := CylinderMesh.new()
		c.top_radius = 0.004
		c.bottom_radius = 0.03
		c.height = 0.16
		c.radial_segments = 6
		var a := -0.9 + k * 0.3
		_piece(c, nacre if k % 2 == 0 else raie, Vector3(sin(a) * 0.06, 0.02, -cos(a) * 0.06 + 0.04),
				Vector3(PI / 2 - 0.15, a, 0), Vector3(1, 1, 0.35))
	_visuel.rotation.y = hash(identifiant) % 7


## L'empreinte d'une grosse patte d'ours dans la terre, avec des griffes.
func _construire_empreinte_ours() -> void:
	var creux := _mat(Color(0.18, 0.13, 0.09), 1.0)
	var paume := CylinderMesh.new()
	paume.top_radius = 0.13
	paume.bottom_radius = 0.13
	paume.height = 0.02
	_piece(paume, creux, Vector3(0, 0.005, 0.03), Vector3.ZERO, Vector3(1.3, 1, 1))
	for k in 5:
		var doigt := CylinderMesh.new()
		doigt.top_radius = 0.04
		doigt.bottom_radius = 0.04
		doigt.height = 0.02
		var x := -0.14 + k * 0.07
		_piece(doigt, creux, Vector3(x, 0.006, -0.12 - absf(x) * -0.3))
		var griffe := BoxMesh.new()
		griffe.size = Vector3(0.012, 0.015, 0.06)
		_piece(griffe, creux, Vector3(x * 1.1, 0.006, -0.19))
	var seconde := _piece(paume, creux, Vector3(0.35, 0.005, 0.75), Vector3.ZERO, Vector3(1.2, 1, 0.9))
	seconde.rotation.y = 0.2


## Une canette de soda en aluminium, cabossée, tachée de violet.
func _construire_canette() -> void:
	var c := CylinderMesh.new()
	c.top_radius = 0.033
	c.bottom_radius = 0.033
	c.height = 0.12
	_piece(c, _mat(Color(0.75, 0.08, 0.1), 0.3, 0.8), Vector3(0, 0.035, 0), Vector3(PI / 2, 0.4, 0))
	var bout := CylinderMesh.new()
	bout.top_radius = 0.03
	bout.bottom_radius = 0.033
	bout.height = 0.01
	_piece(bout, _mat(Color(0.8, 0.8, 0.82), 0.25, 1.0), Vector3(0.024, 0.035, -0.052), Vector3(PI / 2, 0.4, 0))
	_trace_violette()


## Un téléphone portable, l'écran fendu.
func _construire_telephone() -> void:
	var b := BoxMesh.new()
	b.size = Vector3(0.075, 0.009, 0.155)
	_piece(b, _mat(Color(0.08, 0.08, 0.09), 0.3, 0.5), Vector3(0, 0.006, 0), Vector3(0, 0.7, 0.05))
	var ecran := BoxMesh.new()
	ecran.size = Vector3(0.068, 0.002, 0.145)
	var m := _mat(Color(0.1, 0.15, 0.25), 0.05)
	m.emission_enabled = true
	m.emission = Color(0.25, 0.35, 0.6)
	m.emission_energy_multiplier = 0.6
	_piece(ecran, m, Vector3(0, 0.0115, 0), Vector3(0, 0.7, 0.05))
	_trace_violette()


## Des lunettes de soleil modernes.
func _construire_lunettes() -> void:
	var noir := _mat(Color(0.03, 0.03, 0.035), 0.2, 0.3)
	for cote in [-1.0, 1.0]:
		var verre := CylinderMesh.new()
		verre.top_radius = 0.028
		verre.bottom_radius = 0.028
		verre.height = 0.004
		_piece(verre, noir, Vector3(cote * 0.035, 0.03, 0), Vector3(PI / 2 - 0.3, 0, 0))
		var branche := BoxMesh.new()
		branche.size = Vector3(0.004, 0.004, 0.12)
		_piece(branche, noir, Vector3(cote * 0.065, 0.02, 0.06), Vector3(0, cote * 0.1, 0))
	var pont := BoxMesh.new()
	pont.size = Vector3(0.02, 0.004, 0.004)
	_piece(pont, noir, Vector3(0, 0.04, 0))
	_visuel.rotation.y = 0.6
	_trace_violette()


## La marque des Effaceurs : une petite lueur violette sur le sol.
func _trace_violette() -> void:
	var lueur := OmniLight3D.new()
	lueur.light_color = Color(0.6, 0.25, 1.0)
	lueur.light_energy = 0.5
	lueur.omni_range = 1.4
	lueur.position = Vector3(0, 0.2, 0)
	_visuel.add_child(lueur)


## Un rognon de pyrite doré, à l'éclat métallique.
func _construire_pyrite() -> void:
	var m := _mat(Color(0.78, 0.66, 0.36), 0.3, 0.9)
	for k in 5:
		var b := BoxMesh.new()
		b.size = Vector3.ONE * (0.09 + k * 0.012)
		_piece(b, m, Vector3((k % 3 - 1) * 0.07, 0.05 + (k % 2) * 0.04, (k / 3 - 0.5) * 0.08), Vector3(k * 0.7, k * 1.3, k * 0.4))


## De l'amadou : des champignons en console sur un vieux tronc couché.
func _construire_amadou() -> void:
	var bois := _mat(Color(0.32, 0.26, 0.2), 0.95)
	var tronc := CylinderMesh.new()
	tronc.top_radius = 0.16
	tronc.bottom_radius = 0.2
	tronc.height = 1.8
	_piece(tronc, bois, Vector3(0, 0.15, 0), Vector3(0, 0.3, PI / 2))
	var champi := _mat(Color(0.55, 0.42, 0.28), 0.9)
	for k in 3:
		var c := SphereMesh.new()
		c.radius = 0.12
		c.height = 0.08
		_piece(c, champi, Vector3(-0.4 + k * 0.35, 0.3 + k * 0.02, 0.15), Vector3(0.3, 0, 0), Vector3(1, 0.6, 0.8))


## Un ancien foyer éteint : un cercle de pierres et des cendres.
func _construire_foyer() -> void:
	var pierre := _mat(Color(0.45, 0.43, 0.4), 0.95)
	for k in 10:
		var a := k * TAU / 10.0
		var s := SphereMesh.new()
		s.radius = 0.16
		s.height = 0.22
		_piece(s, pierre, Vector3(cos(a) * 0.6, 0.06, sin(a) * 0.6), Vector3(0, a, 0), Vector3(1.2, 1, 0.9))
	var cendres := CylinderMesh.new()
	cendres.top_radius = 0.48
	cendres.bottom_radius = 0.5
	cendres.height = 0.03
	_piece(cendres, _mat(Color(0.2, 0.19, 0.18), 1.0), Vector3(0, 0.01, 0))
