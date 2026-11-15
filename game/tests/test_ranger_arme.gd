extends SceneTree
## Test : ranger / sortir l'arme (touche R, sortie en combat, rangement après le combat,
## sortie immédiate pour attaquer).
## Lancement : godot --headless --path game -s res://tests/test_ranger_arme.gd

var _echecs := 0


func _verifier(condition: bool, message: String) -> void:
	print("  OK   " if condition else "  ÉCHEC ", message)
	if not condition:
		_echecs += 1


func _attendre(images: int) -> void:
	for i in images:
		await physics_frame


func _initialize() -> void:
	_lancer.call_deferred()


func _appuyer_r() -> void:
	Input.action_press("ranger_arme")
	await _attendre(2)
	Input.action_release("ranger_arme")


func _attache(squelette: Skeleton3D, nom: String) -> Node3D:
	return squelette.get_node_or_null(nom) as Node3D


func _lancer() -> void:
	var scene: Node = load("res://scenes/monde/colline_de_test.tscn").instantiate()
	root.add_child(scene)
	await _attendre(30)
	var joueur = get_first_node_in_group("joueur_local")
	var apparence = joueur.get_node("Apparence")
	var combat = joueur.get_node("Combat")
	print("Test : ranger / sortir l'arme")
	apparence.equiper({
		"arme_principale": {"forme": "lame", "couleur": "#9aa0a6"},
		"arme_secondaire": {"forme": "dague", "couleur": "#9aa0a6"},
	})
	await _attendre(5)
	var squelette: Skeleton3D = apparence.find_children("*", "Skeleton3D", true, false)[0]
	var devant: Vector3 = -joueur.global_transform.basis.z
	var droite: Vector3 = joueur.global_transform.basis.x

	_verifier(joueur.arme_rangee, "l'arme est rangée au départ (hub, exploration)")
	var dos := _attache(squelette, "Rangement_arme_principale")
	var ceinture := _attache(squelette, "Rangement_arme_secondaire")
	_verifier(dos != null and ceinture != null, "la lame et la dague sont accrochées au corps")
	if dos != null and ceinture != null:
		var lame: Node3D = dos.get_child(0)
		var poignee: Vector3 = lame.global_position - joueur.global_position
		_verifier(poignee.dot(devant) < -0.05, "la lame est dans le dos (%.2f m derrière)" % -poignee.dot(devant))
		_verifier(poignee.y > 1.35, "sa poignée dépasse au-dessus de l'épaule (%.2f m)" % poignee.y)
		_verifier(poignee.dot(droite) > 0.0, "côté épaule droite")
		var pointe: Vector3 = lame.global_transform * Vector3(0, 0.7, 0) - joueur.global_position
		_verifier(pointe.y < poignee.y - 0.4 and pointe.dot(droite) < poignee.dot(droite),
				"la lame descend en diagonale vers la hanche gauche")
		var dague: Vector3 = (ceinture.get_child(0) as Node3D).global_position - joueur.global_position
		_verifier(dague.y > 0.75 and dague.y < 1.15 and dague.dot(droite) > 0.08,
				"la dague (main gauche) est à la ceinture, hanche droite (hauteur %.2f m)" % dague.y)

	# Touche R : le bras va chercher l'arme dans le dos, puis la tient en main.
	# Une attache sur la main suit la pose finale (après le geste).
	var suivi := BoneAttachment3D.new()
	suivi.bone_name = "mixamorig_RightHand"
	squelette.add_child(suivi)
	await _attendre(3)
	var main_repos := suivi.global_position
	await _appuyer_r()
	_verifier(not joueur.arme_rangee, "R : le joueur sort son arme")
	await _attendre(18)
	var geste: SkeletonModifier3D = squelette.get_node("GesteArme")
	_verifier(geste.influence > 0.5, "le geste du bras est en cours (%.2f)" % geste.influence)
	_verifier(geste.animation != null, "c'est la vraie animation Mixamo qui est jouée")
	var monte := suivi.global_position.y - main_repos.y
	var recule: float = -(suivi.global_position - joueur.global_position).dot(devant)
	print("       main pendant le geste : hauteur %.2f m, %.2f m derrière le corps" %
			[suivi.global_position.y - joueur.global_position.y, recule])
	_verifier(monte > 0.35, "la main monte chercher l'arme par-dessus l'épaule (+%.2f m)" % monte)
	await _attendre(60)
	_verifier(geste.influence == 0.0, "le geste est fini")
	_verifier(_attache(squelette, "Main_arme_principale") != null and _attache(squelette, "Rangement_arme_principale") == null,
			"la lame est maintenant dans la main")
	_verifier(_attache(squelette, "Main_arme_secondaire") != null, "la dague aussi (main gauche)")

	await _appuyer_r()
	await _attendre(60)
	_verifier(joueur.arme_rangee and _attache(squelette, "Rangement_arme_principale") != null,
			"R encore : l'arme est rangée")

	# Entrer en combat sort l'arme tout seul.
	combat.noter_combat()
	await _attendre(60)
	_verifier(not joueur.arme_rangee and _attache(squelette, "Main_arme_principale") != null,
			"en combat, l'arme sort toute seule")
	# Fin du combat : rangée après le délai.
	combat.dernier_moment_de_combat = -1000.0
	await _attendre(30)
	_verifier(not joueur.arme_rangee, "juste après le combat, l'arme reste en main")
	await _attendre(int((joueur.delai_rangement_auto + 1.2) * 60))
	_verifier(joueur.arme_rangee and _attache(squelette, "Rangement_arme_principale") != null,
			"%.0f s après le combat, elle se range toute seule" % joueur.delai_rangement_auto)

	# Attaquer arme rangée : elle sort immédiatement.
	apparence.attaquer()
	await _attendre(2)
	_verifier(not joueur.arme_rangee and _attache(squelette, "Main_arme_principale") != null,
			"attaquer sort l'arme immédiatement")

	# Sans arme : la touche ne casse rien.
	apparence.equiper({})
	await _appuyer_r()
	await _attendre(5)
	_verifier(squelette.get_node("GesteArme").influence == 0.0, "sans arme, pas de geste")

	# Les autres armes ont toutes une place.
	for forme in ["lance", "massue", "couteau", "propulseur"]:
		apparence.equiper({"arme_principale": {"forme": forme, "couleur": "#806040"}})
		joueur.arme_rangee = true
		await _attendre(60)
		_verifier(_attache(squelette, "Rangement_arme_principale") != null, "%s : se range" % forme)
		joueur.arme_rangee = false
		await _attendre(60)

	# En courant : les jambes continuent de courir pendant qu'on sort l'arme.
	apparence.equiper({"arme_principale": {"forme": "massue", "couleur": "#806040"}})
	joueur.arme_rangee = true
	await _attendre(90)
	Input.action_press("avancer")
	await _attendre(20)
	joueur.arme_rangee = false
	await _attendre(25)
	_verifier(squelette.get_node("GesteArme").animation != null and apparence._actuelle == "courir",
			"on sort la massue (animation de la ceinture) sans arrêter de courir")
	await _attendre(70)
	Input.action_release("avancer")
	_verifier(_attache(squelette, "Main_arme_principale") != null, "la massue est en main")

	print("Résultat : %s" % ("tout est bon" if _echecs == 0 else "%d échec(s)" % _echecs))
	quit(1 if _echecs > 0 else 0)
