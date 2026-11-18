extends Node3D
## La Maison des guildes, en jeu : le COFFRE de la guilde (banque partagée) et le
## TABLEAU des contrats de la semaine. On les utilise avec F, ce qui ouvre la fenêtre
## Guilde (touche G) sur le bon onglet. Le coffre sert aussi au serveur : on ne peut
## déposer ou prendre des objets qu'à côté de lui (groupe « coffre_guilde »).
## La géométrie est construite par quartier_residences.gd, la fondation par appartement.gd.

const Residences := preload("res://scripts/monde/quartier_residences.gd")
const PointInteraction := preload("res://scripts/monde/point_interaction.gd")
const AfficheActivite := preload("res://scripts/interface/affiche_activite.gd")
const Fenetre := preload("res://scripts/interface/fenetre_guilde.gd")


func _ready() -> void:
	var coffre := Node3D.new()
	coffre.name = "CoffreGuilde"
	coffre.position = Residences.COFFRE + Vector3(0.4, 1.0, 0.0)
	coffre.add_to_group("coffre_guilde")
	add_child(coffre)
	_point("Ouvrir le coffre de la guilde", Residences.COFFRE + Vector3(1.2, 0, 0), Fenetre.ONGLET_BANQUE)
	_point("Lire les contrats de guilde de la semaine", Residences.TABLEAU_CONTRATS + Vector3(0, 0, -1.3), Fenetre.ONGLET_CONTRATS)


func _point(texte: String, p: Vector3, onglet: int) -> void:
	var b := Node3D.new()
	b.set_script(PointInteraction)
	b.texte = texte
	b.portee = 2.2
	b.position = p
	add_child(b)
	b.utilise.connect(func():
		# La première fois, l'affiche des guildes (ce qu'on y gagne, bande-annonce).
		if not AfficheActivite.deja_vue("guildes") \
				and AfficheActivite.ouvrir(get_tree(), "guildes", Guildes.ouvrir_fenetre.bind(onglet)) != null:
			return
		Guildes.ouvrir_fenetre(onglet))
