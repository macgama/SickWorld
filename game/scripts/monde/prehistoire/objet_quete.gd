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
	elif COULEURS_TAS.has(forme):
		_construire_tas(COULEURS_TAS[forme])
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
	if quete == null:
		return
	get_viewport().set_input_as_handled()
	quete.utiliser_objet(self)


## Fait disparaître l'objet (ramassé).
func cacher() -> void:
	actif = false
	if _visuel != null:
		_visuel.visible = false
