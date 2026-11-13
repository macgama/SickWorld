extends SceneTree
## Test automatique de la carte : zones, brouillard qui se lève, repères,
## sauvegarde par personnage, grande carte (M), et zones des vraies scènes.
## Lancement : godot --headless --path game -s res://tests/test_carte.gd

var _echecs := 0
var cartographe


func _verifier(condition: bool, message: String) -> void:
	if condition:
		print("  OK   ", message)
	else:
		print("  ÉCHEC ", message)
		_echecs += 1


func _attendre(images: int) -> void:
	for i in images:
		await physics_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _boite(parent: Node, taille: Vector3, position: Vector3) -> void:
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = taille
	forme.shape = boite
	corps.add_child(forme)
	corps.position = position
	parent.add_child(corps)


func _zone(parent: Node, id: String, centre: Vector3, taille: Vector3) -> Node3D:
	var z: Node3D = load("res://scripts/carte/zone_carte.gd").new()
	z.identifiant = id
	z.nom_affiche = id.capitalize()
	z.taille = taille
	z.position = centre
	parent.add_child(z)
	return z


func _types(liste: Array) -> Array:
	return liste.map(func(r): return r["type"])


func _lancer() -> void:
	cartographe = root.get_node("/root/Cartographe")
	cartographe.vue_de_dessus = false
	cartographe.effacer_personnage("test_carte_a")
	cartographe.effacer_personnage("test_carte_b")
	cartographe.forcer_personnage("test_carte_a")
	print("Test de la carte")

	var monde := Node3D.new()
	root.add_child(monde)
	_boite(monde, Vector3(100, 1, 100), Vector3(0, -0.5, 0))       # sol
	_boite(monde, Vector3(10, 8, 10), Vector3(-20, 4, 0))          # un bâtiment
	_boite(monde, Vector3(20, 1, 20), Vector3(30, -15.5, 30))      # sol de la cave
	var zone_a := _zone(monde, "test_a", Vector3(0, 10, 0), Vector3(100, 40, 100))
	var zone_b := _zone(monde, "test_b", Vector3(30, -12, 30), Vector3(20, 10, 20))
	var MarqueurCarte = load("res://scripts/carte/marqueur_carte.gd")
	MarqueurCarte.creer(monde, 0, "Fontaine", Vector3(20, 0, 20))
	MarqueurCarte.creer(monde, 1, "Quête", Vector3(-40, 0, -40), true)

	var joueur := Node3D.new()
	joueur.add_to_group("joueur_local")
	joueur.add_to_group("joueur")
	monde.add_child(joueur)
	await _attendre(20)

	_verifier(cartographe.zone == zone_a, "le joueur est dans la zone A")
	_verifier(cartographe.texture_carte != null and cartographe.texture_relief != null,
			"la carte et le relief sont dessinés")
	var relief: Image = cartographe.texture_relief.get_image()
	var plat := relief.get_pixelv(relief.get_size() / 2 + Vector2i(10, 10)).r
	var bord_batiment := relief.get_pixel(int(relief.get_width() * 0.25), relief.get_height() / 2).r
	_verifier(absf(plat - 0.5) < 0.05 and absf(bord_batiment - plat) > 0.1,
			"le relief montre le bâtiment (sol %.2f, bord %.2f)" % [plat, bord_batiment])
	var exploree: float = cartographe.part_exploree()
	_verifier(exploree > 0.1 and exploree < 0.4, "le brouillard s'est levé autour du joueur (%d %%)" % roundi(exploree * 100))
	_verifier(cartographe.est_decouvert(Vector3.ZERO), "l'endroit du joueur est découvert")
	_verifier(not cartographe.est_decouvert(Vector3(45, 0, 45)), "un coin lointain est encore dans le brouillard")
	var types := _types(cartographe.marqueurs())
	_verifier(not types.has(0), "la fontaine (pas encore découverte) est cachée")
	_verifier(types.has(1), "la quête « toujours visible » est sur la carte")

	joueur.position = Vector3(20, 0, 20)
	await _attendre(20)
	_verifier(_types(cartographe.marqueurs()).has(0), "en s'approchant, la fontaine apparaît")
	_verifier(cartographe.part_exploree() > exploree, "la part explorée augmente")

	joueur.position = Vector3(30, -14, 30)
	await _attendre(20)
	_verifier(cartographe.zone == zone_b, "dans la cave, c'est la petite zone B qui s'affiche")
	joueur.position = Vector3(20, 0, 20)
	await _attendre(20)
	_verifier(cartographe.zone == zone_a and cartographe.est_decouvert(Vector3(20, 0, 20)),
			"de retour en zone A, le brouillard levé est gardé")

	cartographe.sauver()
	_verifier(FileAccess.file_exists(Profil.chemin("user://cartes/test_carte_a.cfg")), "la carte est enregistrée pour ce personnage")
	cartographe.forcer_personnage("test_carte_b")
	joueur.position = Vector3(-30, 0, -30)
	await _attendre(20)
	_verifier(not cartographe.est_decouvert(Vector3(20, 0, 20)), "un autre personnage a sa propre carte")
	cartographe.forcer_personnage("test_carte_a")
	await _attendre(20)
	_verifier(cartographe.est_decouvert(Vector3(20, 0, 20)) and not cartographe.est_decouvert(Vector3(45, 0, -45)),
			"le premier personnage retrouve sa carte")

	var interface = cartographe.get_child(0)
	_verifier(interface.visible, "la mini-carte est affichée")
	var touche := InputEventAction.new()
	touche.action = "carte"
	touche.pressed = true
	Input.parse_input_event(touche)
	await _attendre(5)
	_verifier(interface.grande_carte_ouverte(), "M ouvre la grande carte")
	Input.parse_input_event(touche)
	await _attendre(5)
	_verifier(not interface.grande_carte_ouverte(), "M la referme")

	cartographe.reveler_tout()
	_verifier(cartographe.part_exploree() > 0.99, "reveler_tout dévoile toute la zone")

	monde.queue_free()
	await _attendre(10)
	_verifier(cartographe.zone == null and not interface.visible, "sans zone (menu), la carte disparaît")
	cartographe.effacer_personnage("test_carte_a")
	cartographe.effacer_personnage("test_carte_b")

	# Les vraies scènes ont leurs zones.
	cartographe.forcer_personnage("test_carte_scenes")
	var colline: Node = load("res://scenes/monde/colline_de_test.tscn").instantiate()
	root.add_child(colline)
	await _attendre(40)
	_verifier(cartographe.zone != null and cartographe.zone.identifiant == "colline_de_test",
			"la colline de test a sa carte")
	_verifier(_types(cartographe.marqueurs()).has(7), "la balise de la Vigie, toute proche, est sur la carte")
	cartographe.reveler_tout()
	_verifier(_types(cartographe.marqueurs()).count(6) == 5, "les 5 camps de loups sont marqués une fois découverts")
	colline.queue_free()
	await _attendre(10)
	cartographe.effacer_personnage("test_carte_scenes")

	print("Résultat : ", "tout est bon" if _echecs == 0 else "%d échec(s)" % _echecs)
	quit(1 if _echecs > 0 else 0)
