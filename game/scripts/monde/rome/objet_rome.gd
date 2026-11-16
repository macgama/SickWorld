@tool
extends "res://scripts/monde/grece/objet_grece.gd"
## Objets de quête de l'île de Rome (en plus de ceux de la Grèce, de l'Égypte et de la
## Préhistoire) :
## - « radio_vigie » : la petite radio de la Vigie laissée par l'agent Livia Conti ;
## - « milliaire » : une borne milliaire renversée, fendue d'un éclat violet. Une fois
##   redressée (cacher()), elle reste debout au lieu de disparaître.
## Un Égaré à « renouer » n'a pas de forme : l'objet est invisible, posé sur le personnage.

var _debout: Node3D


## Une radio de terrain : un boîtier gris, son antenne et sa diode cyan.
func _construire_radio_vigie() -> void:
	var gris := _mat_uni(Color(0.2, 0.22, 0.24), 0.6, 0.3)
	var b := BoxMesh.new()
	b.size = Vector3(0.22, 0.3, 0.1)
	_morceau(b, gris, Vector3(0, 0.15, 0), Vector3(0, 0.5, 0))
	var antenne := CylinderMesh.new()
	antenne.top_radius = 0.006
	antenne.bottom_radius = 0.01
	antenne.height = 0.4
	_morceau(antenne, gris, Vector3(0.06, 0.48, 0.0), Vector3(0, 0, 0.15))
	var diode := SphereMesh.new()
	diode.radius = 0.02
	diode.height = 0.04
	_morceau(diode, _emissif(Color(0.3, 0.9, 1.0), 4.0), Vector3(-0.05, 0.26, 0.05))


## Une borne milliaire romaine couchée dans l'herbe, fendue d'une lueur violette ; et la
## même, debout, cachée jusqu'à ce qu'on la redresse.
func _construire_milliaire() -> void:
	var tuf := _mat_uni(Color(0.6, 0.56, 0.45), 0.95)
	var travertin := _mat_uni(Color(0.84, 0.8, 0.7), 0.85)
	var couchee := Node3D.new()
	couchee.rotation = Vector3(0, 0.6, 1.45)
	couchee.position = Vector3(0, 0.34, 0)
	_visuel.add_child(couchee)
	var fut := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.3
	c.bottom_radius = 0.34
	c.height = 1.9
	fut.mesh = c
	fut.material_override = travertin
	couchee.add_child(fut)
	var fente := MeshInstance3D.new()
	var f := BoxMesh.new()
	f.size = Vector3(0.05, 1.6, 0.66)
	fente.mesh = f
	fente.material_override = _emissif(Color(0.62, 0.3, 1.0), 3.0)
	couchee.add_child(fente)
	var socle := BoxMesh.new()
	socle.size = Vector3(0.8, 0.5, 0.8)
	_morceau(socle, tuf, Vector3(0.9, 0.2, 0.4), Vector3(0, 0.3, 0.1))
	_trace_violette()
	_debout = Node3D.new()
	_debout.name = "Debout"
	_debout.visible = false
	add_child(_debout)
	var s2 := MeshInstance3D.new()
	s2.mesh = socle
	s2.material_override = tuf
	s2.position.y = 0.15
	_debout.add_child(s2)
	var f2 := MeshInstance3D.new()
	f2.mesh = c
	f2.material_override = travertin
	f2.position.y = 1.35
	_debout.add_child(f2)


func cacher() -> void:
	super.cacher()
	if _debout != null:
		_debout.visible = true


## Un gros sac de toile plein de blé, ficelé en haut, avec un peu de grain renversé.
func _construire_sac() -> void:
	var toile := _mat_uni(Color(0.72, 0.62, 0.44), 0.95)
	var corps := SphereMesh.new()
	corps.radius = 0.3
	corps.height = 0.75
	_morceau(corps, toile, Vector3(0, 0.36, 0))
	var col := CylinderMesh.new()
	col.top_radius = 0.1
	col.bottom_radius = 0.07
	col.height = 0.16
	_morceau(col, toile, Vector3(0, 0.76, 0))
	var lien := TorusMesh.new()
	lien.inner_radius = 0.06
	lien.outer_radius = 0.085
	_morceau(lien, _mat_uni(Color(0.4, 0.3, 0.18), 0.9), Vector3(0, 0.7, 0))
	var grain := CylinderMesh.new()
	grain.top_radius = 0.18
	grain.bottom_radius = 0.26
	grain.height = 0.05
	_morceau(grain, _mat_uni(Color(0.86, 0.72, 0.4), 0.9), Vector3(0.32, 0.02, 0.1))
