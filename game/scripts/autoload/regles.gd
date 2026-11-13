extends Node
## Règles communes du combat : calcul des dégâts, soins, ligne de vue,
## et affichage des nombres qui s'envolent au-dessus des personnages.

const COUCHE_MONDE := 1
const COUCHE_PERSONNAGES := 2

var aleatoire := RandomNumberGenerator.new()
## Temps de jeu écoulé (secondes). On compte le temps du jeu plutôt que l'horloge
## de l'ordinateur : si le jeu ralentit, les combats ralentissent avec lui.
var _temps := 0.0


func _ready() -> void:
	aleatoire.randomize()
	process_priority = -100


func _process(delta: float) -> void:
	_temps += delta


func maintenant() -> float:
	return _temps


## Inflige des dégâts de la part de « source » (peut être nul) à « cible ».
## type : "normal", "periodique" ou "critique" (change l'affichage).
func infliger(source: Combattant, cible: Combattant, montant: float, type := "normal") -> float:
	if cible == null or not cible.est_vivant():
		return 0.0
	if source != null:
		montant *= source.multiplicateur_degats()
	var chance_critique := 0.1 + (source.bonus_critique / 100.0 if source != null else 0.0)
	var critique := type == "normal" and aleatoire.randf() < chance_critique
	if critique:
		montant *= 1.5
	var subi := cible.subir(montant, source)
	if subi > 0.0:
		var couleur := Color(1, 0.95, 0.6)
		if cible.faction == "joueur":
			couleur = Color(1, 0.3, 0.25)
		elif type == "periodique":
			couleur = Color(0.95, 0.75, 0.4)
		afficher_nombre(cible, str(int(subi)) + ("!" if critique else ""), couleur, critique)
	elif cible.a_effet("evite"):
		afficher_nombre(cible, "Évité", Color(0.8, 0.8, 0.8), false)
	return subi


func soigner(source: Combattant, cible: Combattant, montant: float) -> float:
	var soin := cible.soigner(montant)
	if soin > 0.0:
		afficher_nombre(cible, "+" + str(int(soin)), Color(0.4, 1.0, 0.45), false)
	return soin


## Vrai si rien du décor ne se trouve entre les deux combattants.
func ligne_de_vue(a: Combattant, b: Combattant) -> bool:
	var espace := a.acteur().get_world_3d().direct_space_state
	# On regarde « au niveau des yeux », un peu au-dessus du centre, pour être tolérant avec les bosses du terrain.
	var requete := PhysicsRayQueryParameters3D.create(a.centre() + Vector3.UP * 0.5,
			b.centre() + Vector3.UP * 0.5, COUCHE_MONDE)
	return espace.intersect_ray(requete).is_empty()


func distance(a: Combattant, b: Combattant) -> float:
	var pa := a.acteur().global_position
	var pb := b.acteur().global_position
	return Vector2(pa.x - pb.x, pa.z - pb.z).length()


## Tous les combattants vivants hostiles à « pour », à moins de « rayon » mètres de « centre ».
func hostiles_autour(pour: Combattant, centre: Vector3, rayon: float) -> Array[Combattant]:
	var liste: Array[Combattant] = []
	for acteur in get_tree().get_nodes_in_group("combattants"):
		var c := acteur.get_node_or_null("Combat") as Combattant
		if c == null or not c.est_vivant() or not pour.est_hostile(c):
			continue
		var p: Vector3 = acteur.global_position
		if Vector2(p.x - centre.x, p.z - centre.z).length() <= rayon:
			liste.append(c)
	return liste


func allies_autour(pour: Combattant, centre: Vector3, rayon: float) -> Array[Combattant]:
	var liste: Array[Combattant] = []
	for acteur in get_tree().get_nodes_in_group("combattants"):
		var c := acteur.get_node_or_null("Combat") as Combattant
		if c == null or not c.est_vivant() or pour.est_hostile(c):
			continue
		var p: Vector3 = acteur.global_position
		if Vector2(p.x - centre.x, p.z - centre.z).length() <= rayon:
			liste.append(c)
	return liste


## Nombre (dégâts, soins…) qui monte et disparaît au-dessus d'un combattant.
## Décidé par le serveur, affiché chez tous les joueurs.
func afficher_nombre(cible: Combattant, texte: String, couleur: Color, gros: bool) -> void:
	if not multiplayer.is_server() or not cible.is_inside_tree():
		return
	_nombre.rpc(cible.get_path(), texte, couleur, gros)


@rpc("authority", "call_local", "unreliable")
func _nombre(chemin: NodePath, texte: String, couleur: Color, gros: bool) -> void:
	var cible := get_node_or_null(chemin) as Combattant
	var scene := get_tree().current_scene
	if cible == null or scene == null or DisplayServer.get_name() == "headless":
		return
	var etiquette := Label3D.new()
	etiquette.text = texte
	etiquette.modulate = couleur
	etiquette.outline_modulate = Color(0, 0, 0, 0.8)
	etiquette.outline_size = 8
	etiquette.font_size = 44 if gros else 32
	etiquette.pixel_size = 0.0006
	etiquette.fixed_size = true
	etiquette.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etiquette.no_depth_test = true
	etiquette.render_priority = 10
	scene.add_child(etiquette)
	var depart := cible.centre() + Vector3(aleatoire.randf_range(-0.4, 0.4), 0.9, aleatoire.randf_range(-0.4, 0.4))
	etiquette.global_position = depart
	var animation := etiquette.create_tween().set_parallel()
	animation.tween_property(etiquette, "global_position", depart + Vector3.UP * 1.4, 1.1)
	animation.tween_property(etiquette, "modulate:a", 0.0, 0.5).set_delay(0.6)
	animation.chain().tween_callback(etiquette.queue_free)


## Exécute une méthode sur le serveur (directement si on EST le serveur).
func au_serveur(noeud: Node, methode: StringName, arguments: Array = []) -> void:
	if multiplayer.is_server():
		noeud.callv(methode, arguments)
	else:
		noeud.callv("rpc_id", [1, methode] + arguments)


## Exécute une méthode chez un joueur précis (directement si c'est nous).
func chez(id: int, noeud: Node, methode: StringName, arguments: Array = []) -> void:
	if id == multiplayer.get_unique_id():
		noeud.callv(methode, arguments)
	elif multiplayer.is_server() and id in multiplayer.get_peers():
		noeud.callv("rpc_id", [id, methode] + arguments)


## Identifiant de celui qui a envoyé la demande en cours (nous-même si appel direct).
func expediteur() -> int:
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()
