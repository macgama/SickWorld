extends SceneTree
## Outil (pas un test) : pour une liste de points (x, z) d'une zone, dit si l'endroit est
## dégagé (rien dans une sphère de 0,6 m à 1 m du sol, pente douce) et sinon propose le
## point dégagé le plus proche. Sert à poser les objets et personnages des quêtes.
## Lancement : godot --headless --path game -s res://tests/outil_sonde_positions.gd -- --zone=grece/athenes --points=x,z;x,z

func _initialize() -> void:
	_lancer.call_deferred()


func _libre(espace: PhysicsDirectSpaceState3D, ile: Node, x: float, z: float) -> bool:
	var h: float = ile.hauteur(x, z)
	for d: Vector2 in [Vector2(1.2, 0), Vector2(-1.2, 0), Vector2(0, 1.2), Vector2(0, -1.2)]:
		if absf(ile.hauteur(x + d.x, z + d.y) - h) > 0.6:
			return false
	var q := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.6
	q.shape = s
	q.transform = Transform3D(Basis(), Vector3(x, h + 1.0, z))
	return espace.intersect_shape(q, 1).is_empty()


func _lancer() -> void:
	var zone := ""
	var points := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--zone="):
			zone = a.substr(7)
		elif a.begins_with("--points="):
			points = a.substr(9)
	var scene: Node = load("res://scenes/monde/%s.tscn" % zone).instantiate()
	scene.get_node("Quete").set("fichier_progression", "user://outil_sonde.cfg")
	root.add_child(scene)
	for i in 30:
		await physics_frame
	var espace := (scene as Node3D).get_world_3d().direct_space_state
	for p in points.split(";"):
		var xz := p.split(",")
		var x := float(xz[0])
		var z := float(xz[1])
		if _libre(espace, scene, x, z):
			print("SONDE %s,%s libre h=%.1f" % [xz[0], xz[1], scene.hauteur(x, z)])
			continue
		var trouve := false
		for r in range(1, 13):
			for k in 16:
				var a := TAU * k / 16.0
				var nx := roundf(x + cos(a) * r)
				var nz := roundf(z + sin(a) * r)
				if _libre(espace, scene, nx, nz):
					print("SONDE %s,%s BLOQUE -> %d,%d h=%.1f" % [xz[0], xz[1], nx, nz, scene.hauteur(nx, nz)])
					trouve = true
					break
			if trouve:
				break
		if not trouve:
			print("SONDE %s,%s BLOQUE (rien à 12 m)" % [xz[0], xz[1]])
	quit(0)
