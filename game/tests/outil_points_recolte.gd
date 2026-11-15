extends SceneTree
## Outil (pas un test) : cherche de bons emplacements pour les points de récolte d'une zone
## et affiche une ligne « POINTS zone [...] » à recopier dans data/recolte.json (« zones »).
##   godot --headless --path game -s res://tests/outil_points_recolte.gd -- --zone=steppe
## Il regarde le vrai terrain construit : sol plat et dégagé (rayons lancés d'en haut :
## pas de rocher, de maison ou d'arbre dessus), pas trop loin des chemins, et pour la pêche
## de l'eau assez profonde avec une rive praticable à quelques mètres.
## Ensuite on peut déplacer les points à la main dans le fichier.

const Metiers := preload("res://scripts/objets/metiers.gd")

const SCENES := {
	"cote_gelee": "res://scenes/monde/prehistoire/cote_gelee.tscn",
	"steppe": "res://scenes/monde/prehistoire/steppe.tscn",
	"foret": "res://scenes/monde/prehistoire/foret.tscn",
	"falaises": "res://scenes/monde/prehistoire/falaises.tscn",
	"port_des_marais": "res://scenes/monde/egypte/port_des_marais.tscn",
	"carrieres_toura": "res://scenes/monde/egypte/carrieres_toura.tscn",
	"village_batisseurs": "res://scenes/monde/egypte/village_batisseurs.tscn",
	"desert_rouge": "res://scenes/monde/egypte/desert_rouge.tscn",
}

## Ce qu'on pose dans chaque zone : source -> nombre de points.
const PLAN := {
	"cote_gelee": {"lichen_des_rennes": 5, "affleurement_silex": 4, "banc_ombles": 4},
	"steppe": {"lichen_des_rennes": 3, "achillee": 4, "affleurement_silex": 3, "veine_ocre": 3, "banc_saumons": 4},
	"foret": {"bouleau_ecorce": 5, "amadouvier": 4, "rognon_pyrite": 3, "banc_saumons": 2, "brochet": 4},
	"falaises": {"achillee": 3, "veine_ocre": 4, "rognon_pyrite": 3, "geode_cristal": 4},
	"port_des_marais": {"papyrus": 5, "lotus_bleu": 4, "banc_tilapias": 4, "poissons_chats": 3, "perche_du_nil": 2},
	"carrieres_toura": {"bloc_calcaire": 6, "papyrus": 2, "banc_tilapias": 2, "poissons_chats": 2, "perche_du_nil": 2},
	"village_batisseurs": {"lin": 7, "bloc_calcaire": 3, "lotus_bleu": 2, "banc_tilapias": 3},
	"desert_rouge": {"croute_natron": 5, "filon_malachite": 4, "filon_turquoise": 3, "acacia": 4},
}

var _zone := ""
var _terrain: Node3D
var _espace: PhysicsDirectSpaceState3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--zone="):
			_zone = a.substr(7)
	_lancer.call_deferred()


func _lancer() -> void:
	if not SCENES.has(_zone):
		print("Zone inconnue : ", _zone)
		quit(1)
		return
	Profil.activer("_outil_recolte")
	var scene: Node = load(SCENES[_zone]).instantiate()
	root.add_child(scene)
	current_scene = scene
	_terrain = scene
	for i in 90:
		await physics_frame
	_espace = scene.get_world_3d().direct_space_state
	var resultat := _choisir()
	# Une ligne à recopier dans data/recolte.json (« zones »), lue par tools/recolte_points.py.
	print("POINTS %s %s" % [_zone, JSON.stringify(resultat)])
	quit(0)


func _h(x: float, z: float) -> float:
	return _terrain.hauteur(x, z)


## Hauteur de ce qu'on touche en lançant un rayon d'en haut (sol, rocher, toit…).
func _dessus(x: float, z: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 300, z), Vector3(x, -50, z))
	var r := _espace.intersect_ray(q)
	return r["position"].y if not r.is_empty() else -INF


## Sol nu, plat et dégagé sur « rayon » mètres.
func _degage(x: float, z: float, rayon: float, minimum := 0.35) -> bool:
	var h := _h(x, z)
	if h < minimum:
		return false
	for d in [Vector2.ZERO, Vector2(rayon, 0), Vector2(-rayon, 0), Vector2(0, rayon), Vector2(0, -rayon),
			Vector2(rayon, rayon) * 0.7, Vector2(-rayon, rayon) * 0.7, Vector2(rayon, -rayon) * 0.7, Vector2(-rayon, -rayon) * 0.7]:
		var hx := _h(x + d.x, z + d.y)
		if absf(hx - h) > rayon * 0.45 or hx < minimum - 0.1:
			return false
		var dessus := _dessus(x + d.x, z + d.y)
		if dessus == -INF or absf(dessus - hx) > 0.35:
			return false
	return true


func _distance_chemin(x: float, z: float) -> float:
	if _terrain.has_method("_distance_piste") and not (_terrain.get("piste") as Array).is_empty():
		return _terrain._distance_piste(Vector2(x, z))
	return 10.0


## Pour la pêche : de l'eau profonde ici, et une rive praticable entre 3 et 7 m.
func _rive(x: float, z: float) -> bool:
	if _h(x, z) > -0.4:
		return false
	for k in 12:
		var a := k * TAU / 12.0
		for r in [3.0, 4.5, 6.0, 7.5]:
			var p: Vector2 = Vector2(x, z) + Vector2(cos(a), sin(a)) * r
			if _degage(p.x, p.y, 1.0, 0.15):
				return true
	return false


func _choisir() -> Array:
	var demi := float(_terrain.get("taille_terrain")) / 2.0 - 15.0
	var hasard := RandomNumberGenerator.new()
	hasard.seed = hash(_zone)
	var terre: Array[Vector2] = []
	var eau: Array[Vector2] = []
	var pas := 6.0
	var x := -demi
	while x <= demi:
		var z := -demi
		while z <= demi:
			var p := Vector2(x + hasard.randf_range(-2, 2), z + hasard.randf_range(-2, 2))
			var dc := _distance_chemin(p.x, p.y)
			if dc < 55.0 and dc > 3.0 and _degage(p.x, p.y, 1.6):
				terre.append(p)
			elif dc < 90.0 and _rive(p.x, p.y):
				eau.append(p)
			z += pas
		x += pas
	print("%s : %d places sur la terre ferme, %d places de pêche" % [_zone, terre.size(), eau.size()])
	var pris: Array[Vector2] = []
	var resultat: Array = []
	var plan: Dictionary = PLAN[_zone]
	for id_source in plan:
		var fiche := Metiers.source(root.get_node("Donnees").recolte, id_source)
		var peche := String(fiche.get("metier", "")) == "peche" or bool(fiche.get("sur_l_eau", false))
		var candidats: Array[Vector2] = (eau if peche else terre).duplicate()
		candidats.shuffle()
		var poses := 0
		for ecart in [40.0, 28.0, 18.0, 10.0]:
			for c in candidats:
				if poses >= int(plan[id_source]):
					break
				var loin := true
				for q in pris:
					if q.distance_to(c) < ecart:
						loin = false
						break
				if loin:
					pris.append(c)
					resultat.append([id_source, snappedf(c.x, 0.5), snappedf(c.y, 0.5)])
					poses += 1
		if poses < int(plan[id_source]):
			print("  %s : seulement %d / %d points" % [id_source, poses, plan[id_source]])
	return resultat
