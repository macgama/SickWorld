@tool
extends "res://scripts/monde/moyen_age/objet_moyen_age.gd"
## Objets de quête de l'île de Mayence (en plus de ceux du Moyen Âge et des autres îles) :
## - « casse_plomb » : une petite casse de voyage (un casier de bois à compartiments) pleine
##   de lettres de plomb grises, et un composteur posé en travers.
## - « feuille_imprimee » : une feuille de papier blanc trop blanc, couverte de lignes noires
##   parfaitement régulières (imprimée en 2026), posée sur une pierre ; ramassée, elle
##   disparaît.
## - « hotte » : la hotte d'osier d'un vendangeur, pleine de grappes noires.
## - un Scellé que l'on délivre n'a pas de forme : l'objet est invisible, posé sur le
##   personnage (meta « pnj_lie ») ; quand il est compté, le sceau de cire se brise.


func _construire_casse_plomb() -> void:
	var bois := _mat_uni(Color(0.42, 0.28, 0.16), 0.85)
	var plomb := _mat_uni(Color(0.56, 0.57, 0.6), 0.45, 0.7)
	var fond := BoxMesh.new()
	fond.size = Vector3(0.9, 0.08, 0.6)
	_morceau(fond, bois, Vector3(0, 0.74, 0))
	# Le tréteau qui porte la casse.
	var pied := BoxMesh.new()
	pied.size = Vector3(0.06, 0.72, 0.06)
	for x: float in [-0.38, 0.38]:
		for z: float in [-0.24, 0.24]:
			_morceau(pied, bois, Vector3(x, 0.36, z))
	# Les cloisons du casier.
	var cloison := BoxMesh.new()
	cloison.size = Vector3(0.9, 0.06, 0.02)
	for k in 5:
		_morceau(cloison, bois, Vector3(0, 0.8, -0.3 + k * 0.15))
	var montant := BoxMesh.new()
	montant.size = Vector3(0.02, 0.06, 0.6)
	for k in 7:
		_morceau(montant, bois, Vector3(-0.45 + k * 0.15, 0.8, 0))
	# Les lettres de plomb, en petits tas dans les compartiments.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(identifiant)
	var lettre := BoxMesh.new()
	lettre.size = Vector3(0.018, 0.024, 0.024)
	for k in 70:
		var cx := hasard.randi_range(0, 5)
		var cz := hasard.randi_range(0, 3)
		_morceau(lettre, plomb, Vector3(-0.375 + cx * 0.15 + hasard.randf_range(-0.05, 0.05), 0.8,
				-0.225 + cz * 0.15 + hasard.randf_range(-0.05, 0.05)), Vector3(0, hasard.randf() * 0.4, 0))
	# Le composteur posé en travers, avec une ligne commencée.
	var reglette := BoxMesh.new()
	reglette.size = Vector3(0.36, 0.03, 0.06)
	_morceau(reglette, _mat_uni(Color(0.3, 0.3, 0.32), 0.4, 0.8), Vector3(0.1, 0.85, 0.12), Vector3(0, 0.3, 0))
	for k in 6:
		_morceau(lettre, plomb, Vector3(0.0 + k * 0.022, 0.875, 0.12 - k * 0.006), Vector3(0, 0.3, 0))


func _construire_feuille_imprimee() -> void:
	var pierre := BoxMesh.new()
	pierre.size = Vector3(0.8, 0.4, 0.6)
	_morceau(pierre, _mat_uni(Color(0.48, 0.45, 0.42), 1.0), Vector3(0, 0.2, 0), Vector3(0.05, 0.3, 0))
	var feuille := BoxMesh.new()
	feuille.size = Vector3(0.21, 0.003, 0.297)
	var f := _morceau(feuille, _mat_uni(Color(0.98, 0.98, 0.97), 0.6), Vector3(0, 0.405, 0), Vector3(0, 0.5, 0))
	# Des lignes de texte noires, trop régulières pour avoir été écrites à la main.
	var ligne := BoxMesh.new()
	ligne.size = Vector3(0.16, 0.002, 0.006)
	for k in 22:
		var l := MeshInstance3D.new()
		l.mesh = ligne
		l.material_override = _mat_uni(Color(0.04, 0.04, 0.04), 0.9)
		l.position = Vector3(0, 0.003, -0.12 + k * 0.011)
		f.add_child(l)


func _construire_hotte() -> void:
	var osier := _mat_uni(Color(0.62, 0.48, 0.3), 0.95)
	var raisin := _mat_uni(Color(0.2, 0.08, 0.22), 0.35)
	var corps := CylinderMesh.new()
	corps.top_radius = 0.28
	corps.bottom_radius = 0.18
	corps.height = 0.7
	_morceau(corps, osier, Vector3(0, 0.35, 0))
	var grain := SphereMesh.new()
	grain.radius = 0.05
	grain.height = 0.1
	grain.radial_segments = 6
	grain.rings = 3
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(identifiant)
	for k in 30:
		var a := hasard.randf() * TAU
		var r := sqrt(hasard.randf()) * 0.22
		_morceau(grain, raisin, Vector3(cos(a) * r, 0.7 + hasard.randf_range(0.0, 0.08), sin(a) * r))
