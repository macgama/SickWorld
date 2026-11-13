class_name Partie
extends Node3D
## Gère la partie en cours : ouvre la connexion réseau, fait apparaître
## le personnage de chaque joueur qui arrive et le retire quand il part.
##
## Les nœuds « Joueurs » et « Loups » contiennent les personnages et les loups.
## Les « Spawner » recopient automatiquement leur contenu chez tous les joueurs.

const SCENE_JOUEUR := preload("res://scenes/joueur/joueur.tscn")

@onready var joueurs: Node3D = $Joueurs
@onready var loups: Node3D = $Loups


func _ready() -> void:
	add_to_group("partie")
	loups.add_to_group("dossier_loups")
	if Engine.is_editor_hint():
		return
	if Reseau.demarrer() != OK:
		Reseau.quitter.call_deferred()
		return
	if multiplayer.is_server() and Reseau.a_un_joueur_local():
		# On attend que le terrain soit construit pour connaître la hauteur du sol.
		ajouter_joueur.call_deferred(1, Reseau.nom_joueur)


## Serveur : crée le personnage d'un joueur qui vient d'arriver.
func ajouter_joueur(id: int, nom: String) -> void:
	if joueurs.has_node(str(id)):
		return
	var joueur: Joueur = SCENE_JOUEUR.instantiate()
	joueur.name = str(id)
	joueur.nom = nom
	var depart := point_de_depart(joueurs.get_child_count())
	joueur.position = depart
	joueur.position_reseau = depart
	joueur.lacet_reseau = _orientation_depart()
	joueur.rotation.y = joueur.lacet_reseau
	joueurs.add_child(joueur)
	# Le joueur déplace lui-même son personnage : on lui indique où commencer.
	if id != multiplayer.get_unique_id():
		get_tree().create_timer(0.5).timeout.connect(func():
			if is_instance_valid(joueur):
				Regles.chez(id, joueur, "teleporter", [depart, joueur.lacet_reseau]))


func retirer_joueur(id: int) -> void:
	var joueur := joueurs.get_node_or_null(str(id))
	if joueur != null:
		joueur.queue_free()


## Point de départ près de la balise de la Vigie (décalé pour ne pas empiler les joueurs).
func point_de_depart(numero: int) -> Vector3:
	var terrain := get_parent()
	var base := Vector2(0, 55)
	if "point_apparition" in terrain:
		base = terrain.point_apparition
	var angle := numero * 2.4
	var p := base + Vector2(cos(angle), sin(angle)) * (0.0 if numero == 0 else 2.5)
	var y := 5.0
	if terrain.has_method("hauteur"):
		y = terrain.hauteur(p.x, p.y) + 0.2
	return Vector3(p.x, y, p.y)


func _orientation_depart() -> float:
	var terrain := get_parent()
	var base := Vector2(0, 55)
	if "point_apparition" in terrain:
		base = terrain.point_apparition
	return atan2(base.x, base.y)
