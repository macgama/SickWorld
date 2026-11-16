extends SceneTree
## Test automatique de la vie ambiante (data/vie_ambiante.json) : pour chaque zone,
## on charge la scène et on vérifie que les oiseaux, insectes, figurants et objets
## semés sont bien là, que les figurants marchent et qu'ils restent sur le sol.
## Lancement : godot --headless --path game -s res://tests/test_vie_ambiante.gd [-- zone1 zone2 …]

const ZONES := {
	"steppe": "res://scenes/monde/prehistoire/steppe.tscn",
	"cote_gelee": "res://scenes/monde/prehistoire/cote_gelee.tscn",
	"foret": "res://scenes/monde/prehistoire/foret.tscn",
	"falaises": "res://scenes/monde/prehistoire/falaises.tscn",
	"port_des_marais": "res://scenes/monde/egypte/port_des_marais.tscn",
	"carrieres_toura": "res://scenes/monde/egypte/carrieres_toura.tscn",
	"village_batisseurs": "res://scenes/monde/egypte/village_batisseurs.tscn",
	"desert_rouge": "res://scenes/monde/egypte/desert_rouge.tscn",
	"le_piree": "res://scenes/monde/grece/le_piree.tscn",
	"hikari_bay": "res://scenes/monde/hikari_bay.tscn",
}
const VieAmbiante := preload("res://scripts/monde/vie/vie_ambiante.gd")

var _echecs := 0


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


func _lancer() -> void:
	var choix := Array(OS.get_cmdline_user_args())
	var donnees := VieAmbiante.donnees()
	_verifier(not donnees.is_empty(), "data/vie_ambiante.json se lit")
	# Chaque figurant utilise un modèle connu.
	var modeles: Dictionary = donnees.get("modeles_figurants", {})
	for zone in donnees:
		if not donnees[zone] is Dictionary or zone == "modeles_figurants":
			continue
		for f: Dictionary in donnees[zone].get("figurants", []):
			if not modeles.has(f.get("comme", "")):
				_verifier(false, "%s : modèle de figurant inconnu « %s »" % [zone, f.get("comme", "")])
	for zone: String in ZONES:
		if not choix.is_empty() and not zone in choix:
			continue
		await _tester_zone(zone, ZONES[zone])
	print("\n%s" % ("TOUT EST BON" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	quit(1 if _echecs > 0 else 0)


func _tester_zone(zone: String, chemin: String) -> void:
	print("\n== ", zone)
	var fichier := "user://test_vie_%s_%d.cfg" % [zone, OS.get_process_id()]
	var scene: Node = load(chemin).instantiate()
	var quete := scene.get_node_or_null("Quete")
	if quete != null:
		quete.voyage_reel = false
		quete.fichier_progression = fichier
	root.add_child(scene)
	current_scene = scene
	await _attendre(20)
	var vie := scene.get_node_or_null("VieAmbiante")
	_verifier(vie != null, "%s : vie ambiante installée" % zone)
	if vie == null:
		scene.queue_free()
		await _attendre(2)
		return
	var fiche: Dictionary = VieAmbiante.donnees()[zone]
	var oiseaux := vie.find_children("Oiseaux_*", "", false, false)
	_verifier(oiseaux.size() == fiche.get("oiseaux", []).size(), "%s : %d volées d'oiseaux" % [zone, oiseaux.size()])
	var figurants := vie.find_children("Figurant*", "", false, false)
	_verifier(figurants.size() == fiche.get("figurants", []).size(), "%s : %d figurants" % [zone, figurants.size()])
	if fiche.has("disperser"):
		_verifier(vie.objets_semes > 0, "%s : %d objets semés" % [zone, vie.objets_semes])
	# Les marcheurs avancent et restent au niveau du sol.
	var depart := {}
	for g: Node3D in figurants:
		depart[g] = g.global_position
	await _attendre(150)
	var bougent := 0
	var marcheurs := 0
	var au_sol := true
	for g: Node3D in figurants:
		if (g.get("chemin") as PackedVector2Array).size() >= 2:
			marcheurs += 1
			if g.global_position.distance_to(depart[g]) > 0.2:
				bougent += 1
		if scene.has_method("hauteur") and absf(g.global_position.y - scene.hauteur(g.global_position.x, g.global_position.z)) > 0.05:
			au_sol = false
	_verifier(marcheurs == 0 or bougent > 0, "%s : %d marcheurs sur %d ont bougé" % [zone, bougent, marcheurs])
	_verifier(au_sol, "%s : les figurants marchent sur le sol" % zone)
	if fiche.has("bateaux"):
		var ville := vie.get_node_or_null("Ville")
		_verifier(ville != null and ville.find_children("Bateau_*", "", false, false).size() == fiche["bateaux"].size(), "%s : bateaux dans la baie" % zone)
	scene.queue_free()
	await _attendre(5)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fichier))
