@tool
class_name MarqueurCarte
extends Node3D
## Un repère sur la carte : quête, personnage, portail, marchand, lieu, danger.
##
## Pose ce nœud dans une scène (ou ajoute-le par le code avec
## MarqueurCarte.creer(...)). Il apparaît sur la carte une fois que le joueur a
## découvert l'endroit, ou tout de suite si « toujours_visible » est coché.
##
## Les personnages (groupe « pnj »), les portails actifs (« portail_actif ») et
## les balises de la Vigie (« balises ») apparaissent aussi sans marqueur.

enum Type { LIEU, QUETE, QUETE_A_RENDRE, PNJ, MARCHAND, PORTAIL, DANGER, BALISE }

## Sorte de repère (change l'icône et la couleur).
@export var type := Type.LIEU
## Texte affiché à côté de l'icône sur la grande carte.
@export var libelle := ""
## Visible même dans le brouillard (une quête qu'on vient d'accepter, par exemple).
@export var toujours_visible := false
## Afficher aussi sur la mini-carte (sinon : seulement sur la grande carte).
@export var sur_mini_carte := true


func _ready() -> void:
	add_to_group("marqueur_carte")


## Crée un marqueur par le code et l'ajoute à « parent ».
static func creer(parent: Node, type_marqueur: Type, texte: String, position_locale: Vector3,
		visible_toujours := false) -> Node3D:
	var m: Node3D = load("res://scripts/carte/marqueur_carte.gd").new()
	m.type = type_marqueur
	m.libelle = texte
	m.toujours_visible = visible_toujours
	m.position = position_locale
	m.name = "Marqueur_" + texte.validate_node_name().replace(" ", "_")
	parent.add_child(m)
	return m
