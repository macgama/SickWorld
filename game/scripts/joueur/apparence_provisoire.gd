@tool
extends Node3D
## Silhouette provisoire du personnage, construite avec des formes simples.
##
## Elle sert en attendant le vrai personnage MakeHuman animé avec Mixamo
## (voir docs/guides/personnage-makehuman-mixamo.md). Les membres sont animés
## par le code : balancement des bras et des jambes, saut, roulade.

const HAUTEUR_HANCHES := 0.95

@export var couleur_peau := Color(0.80, 0.62, 0.50)
@export var couleur_veste := Color(0.15, 0.19, 0.26)
@export var couleur_pantalon := Color(0.11, 0.11, 0.13)
@export var couleur_insigne := Color(0.25, 0.85, 0.9)

var _centre: Node3D
var _buste: Node3D
var _hanche_g: Node3D
var _hanche_d: Node3D
var _epaule_g: Node3D
var _epaule_d: Node3D
var _phase := 0.0
var _temps := 0.0


func _ready() -> void:
	for enfant in get_children():
		enfant.queue_free()
	_construire()


func _materiau(couleur: Color, rugosite := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = rugosite
	return m


func _forme(parent: Node3D, maillage: Mesh, materiau: Material, position_locale: Vector3,
		echelle := Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = maillage
	instance.material_override = materiau
	instance.position = position_locale
	instance.scale = echelle
	parent.add_child(instance)
	return instance


func _capsule(rayon: float, hauteur: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = rayon
	c.height = hauteur
	return c


func _articulation(parent: Node3D, position_locale: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = position_locale
	parent.add_child(n)
	return n


func _construire() -> void:
	var peau := _materiau(couleur_peau, 0.6)
	var veste := _materiau(couleur_veste)
	var pantalon := _materiau(couleur_pantalon)
	var insigne := _materiau(couleur_insigne, 0.3)
	insigne.emission_enabled = true
	insigne.emission = couleur_insigne
	insigne.emission_energy_multiplier = 2.0
	var sombre := _materiau(Color(0.05, 0.05, 0.06), 0.3)

	# Le « centre » est au niveau des hanches : c'est autour de lui qu'on fait la roulade.
	_centre = _articulation(self, Vector3(0, HAUTEUR_HANCHES, 0))
	_buste = _articulation(_centre, Vector3.ZERO)

	_forme(_buste, _capsule(0.2, 0.7), veste, Vector3(0, 0.33, 0), Vector3(1.15, 1.0, 0.75))
	_forme(_buste, _capsule(0.055, 0.2), peau, Vector3(0, 0.68, 0))
	var tete := SphereMesh.new()
	tete.radius = 0.12
	tete.height = 0.27
	_forme(_buste, tete, peau, Vector3(0, 0.82, 0))
	# Visière et insigne de la Vigie : ils montrent où regarde le personnage (vers l'avant, -Z).
	var visiere := BoxMesh.new()
	visiere.size = Vector3(0.18, 0.045, 0.04)
	_forme(_buste, visiere, sombre, Vector3(0, 0.85, -0.105))
	var badge := BoxMesh.new()
	badge.size = Vector3(0.07, 0.07, 0.02)
	_forme(_buste, badge, insigne, Vector3(0.09, 0.47, -0.16))

	_epaule_g = _articulation(_buste, Vector3(-0.27, 0.57, 0))
	_epaule_d = _articulation(_buste, Vector3(0.27, 0.57, 0))
	for epaule in [_epaule_g, _epaule_d]:
		_forme(epaule, _capsule(0.06, 0.62), veste, Vector3(0, -0.29, 0))
		var main := SphereMesh.new()
		main.radius = 0.055
		main.height = 0.11
		_forme(epaule, main, peau, Vector3(0, -0.62, 0))

	_hanche_g = _articulation(_centre, Vector3(-0.1, 0, 0))
	_hanche_d = _articulation(_centre, Vector3(0.1, 0, 0))
	for hanche in [_hanche_g, _hanche_d]:
		_forme(hanche, _capsule(0.085, 0.9), pantalon, Vector3(0, -0.45, 0))
		var chaussure := BoxMesh.new()
		chaussure.size = Vector3(0.12, 0.08, 0.26)
		_forme(hanche, chaussure, sombre, Vector3(0, -0.91, -0.05))


## Appelée par le Joueur à chaque image physique.
## vitesse_locale : vitesse dans le repère du personnage (-Z = devant).
## progression_esquive : -1 hors roulade, sinon de 0 à 1.
func animer(delta: float, vitesse_locale: Vector3, au_sol: bool, progression_esquive: float,
		direction_esquive: Vector3) -> void:
	if _centre == null:
		return
	_temps += delta
	var vitesse := vitesse_locale.length()
	var allure := clampf(vitesse / 7.0, 0.0, 1.0)
	# On avance la « phase » du pas selon la vitesse (en marche arrière, elle recule).
	var sens := -1.0 if vitesse_locale.z > 0.1 else 1.0
	_phase += delta * (2.0 + vitesse * 1.5) * sens

	var balancement := sin(_phase) * 0.75 * allure
	var jambe_g := balancement
	var jambe_d := -balancement
	var bras_g := -balancement * 0.8
	var bras_d := balancement * 0.8
	var respiration := sin(_temps * 2.0) * 0.015 * (1.0 - allure)

	if not au_sol:
		jambe_g = -0.5
		jambe_d = 0.2
		bras_g = -0.6
		bras_d = -0.6

	# Pas de côté : on écarte un peu les jambes au lieu de les balancer d'avant en arrière.
	var cote := clampf(vitesse_locale.x / 7.0, -1.0, 1.0)
	_hanche_g.rotation = Vector3(-jambe_g * (1.0 - absf(cote) * 0.6), 0, sin(_phase) * 0.25 * cote)
	_hanche_d.rotation = Vector3(-jambe_d * (1.0 - absf(cote) * 0.6), 0, -sin(_phase) * 0.25 * cote)
	_epaule_g.rotation = Vector3(-bras_g, 0, -0.08)
	_epaule_d.rotation = Vector3(-bras_d, 0, 0.08)
	# Penché légèrement vers l'avant quand on court.
	_buste.rotation = Vector3(-0.12 * allure * (1.0 if sens > 0.0 else -0.5), 0, 0)
	_buste.scale = Vector3(1.0, 1.0 + respiration, 1.0)

	if progression_esquive >= 0.0:
		# Roulade : le corps se recroqueville et fait un tour complet dans la direction de l'esquive.
		var d := Vector3(direction_esquive.x, 0.0, direction_esquive.z).normalized()
		if d == Vector3.ZERO:
			d = Vector3.FORWARD
		var axe := Vector3.UP.cross(d).normalized()
		_centre.transform.basis = Basis(axe, TAU * progression_esquive)
		_centre.position = Vector3(0, HAUTEUR_HANCHES - 0.45 * sin(PI * progression_esquive), 0)
		_hanche_g.rotation = Vector3(1.4, 0, 0)
		_hanche_d.rotation = Vector3(1.4, 0, 0)
		_epaule_g.rotation = Vector3(1.2, 0, 0)
		_epaule_d.rotation = Vector3(1.2, 0, 0)
	else:
		_centre.transform.basis = Basis.IDENTITY
		_centre.position = Vector3(0, HAUTEUR_HANCHES + absf(sin(_phase)) * 0.04 * allure, 0)
