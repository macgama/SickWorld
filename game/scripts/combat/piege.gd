extends Node3D
## Piège à collet du Traqueur : posé au sol, il attend qu'un ennemi marche dessus,
## le blesse et l'immobilise, puis disparaît.
##
## Le vrai piège existe sur le serveur (lanceur renseigné) ; les joueurs reçoivent
## une copie seulement visuelle, retirée quand le piège se referme.

var lanceur: Combattant
var reglages: Dictionary
var combat_joueur: Node

var _fin := 0.0
var _arme := 0.0
var _visuel: Node3D


func _ready() -> void:
	add_to_group("pieges")
	_fin = Regles.maintenant() + float(reglages.get("duree", 30))
	# Il faut une demi-seconde pour que le piège soit armé.
	_arme = Regles.maintenant() + 0.5
	if DisplayServer.get_name() != "headless":
		_construire()


func _process(_delta: float) -> void:
	var t := Regles.maintenant()
	if t >= _fin:
		queue_free()
		return
	if lanceur == null or not is_instance_valid(lanceur) or t < _arme:
		return
	var proies := Regles.hostiles_autour(lanceur, global_position, float(reglages.get("rayon", 1.8)))
	if proies.is_empty():
		return
	var victime: Combattant = proies[0]
	Regles.infliger(lanceur, victime, Donnees.entre(reglages.get("degats", [0, 0])))
	if victime.est_vivant():
		var duree := victime.ajouter_controle("immobilise", float(reglages.get("immobilise", 5)), lanceur)
		if duree <= 0.0:
			Regles.afficher_nombre(victime, "Insensible", Color(0.8, 0.8, 0.8), false)
	if combat_joueur != null and is_instance_valid(combat_joueur):
		combat_joueur.piege_declenche(self, victime)
	lanceur = null
	_fin = t + 0.6


## Le piège se referme (animation), puis disparaît.
func refermer() -> void:
	lanceur = null
	_fin = minf(_fin, Regles.maintenant() + 0.6)
	if _visuel != null:
		var t := _visuel.create_tween()
		t.tween_property(_visuel, "scale", Vector3(0.4, 1.6, 0.4), 0.15)
		t.tween_property(_visuel, "scale", Vector3(0.01, 0.01, 0.01), 0.4)


func _construire() -> void:
	_visuel = Node3D.new()
	add_child(_visuel)
	var bois := StandardMaterial3D.new()
	bois.albedo_color = Color(0.36, 0.26, 0.16)
	bois.roughness = 0.9
	var corde := StandardMaterial3D.new()
	corde.albedo_color = Color(0.7, 0.6, 0.4)
	corde.roughness = 1.0
	# Une boucle de corde posée au sol…
	var boucle := MeshInstance3D.new()
	var tore := TorusMesh.new()
	tore.inner_radius = 0.55
	tore.outer_radius = 0.6
	tore.rings = 24
	tore.ring_segments = 6
	boucle.mesh = tore
	boucle.material_override = corde
	boucle.position.y = 0.04
	_visuel.add_child(boucle)
	# … tenue par quatre piquets taillés.
	for i in 4:
		var piquet := MeshInstance3D.new()
		var forme := CylinderMesh.new()
		forme.top_radius = 0.0
		forme.bottom_radius = 0.035
		forme.height = 0.35
		piquet.mesh = forme
		piquet.material_override = bois
		var a := TAU * i / 4.0 + PI / 4.0
		piquet.position = Vector3(cos(a) * 0.62, 0.15, sin(a) * 0.62)
		piquet.rotation = Vector3(0.25 * sin(a), 0, -0.25 * cos(a))
		_visuel.add_child(piquet)
	# Un léger cercle doré pour que le joueur voie où il l'a posé.
	var repere := MeshInstance3D.new()
	var disque := CylinderMesh.new()
	var r := float(reglages.get("rayon", 1.8))
	disque.top_radius = r
	disque.bottom_radius = r
	disque.height = 0.02
	repere.mesh = disque
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.75, 0.3, 0.12)
	repere.material_override = mat
	repere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	repere.position.y = 0.03
	_visuel.add_child(repere)
