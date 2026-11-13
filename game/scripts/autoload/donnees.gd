extends Node
## Lit les fichiers de données du jeu (dossier data/) au démarrage.
## Ces fichiers se modifient avec un simple éditeur de texte, sans toucher au code.

var competences: Dictionary = {}
var joueur: Dictionary = {}
var ennemis: Dictionary = {}
## Choix possibles à la création du personnage (classes, origines, visages…).
var creation: Dictionary = {}
## Objets, ensembles d'époque, butin et règles de l'inventaire (voir Objets).
var objets: Dictionary = {}
## Les 4 classes : vie, compétences 1 à 5, attaque automatique, ressource (voir classes.json).
var classes: Dictionary = {}
## Recettes des artisans du hub (voir scripts/objets/artisanat.gd).
var artisanat: Dictionary = {}


func _ready() -> void:
	competences = _lire("res://data/competences.json")
	joueur = _lire("res://data/joueur.json")
	ennemis = _lire("res://data/ennemis.json")
	creation = _lire("res://data/creation_personnage.json")
	objets = _lire("res://data/objets.json")
	classes = _lire("res://data/classes.json")
	artisanat = _lire("res://data/artisanat.json")


func competence(id: String) -> Dictionary:
	return competences.get(id, {})


## Réglages d'une classe (la Lame si la classe est inconnue).
func classe(id: String) -> Dictionary:
	var c = classes.get(id)
	if c is Dictionary:
		return c
	return classes.get("lame", {})


func ennemi(id: String) -> Dictionary:
	return ennemis.get(id, {})


func _lire(chemin: String) -> Dictionary:
	var texte := FileAccess.get_file_as_string(chemin)
	var resultat = JSON.parse_string(texte)
	if resultat is Dictionary:
		return resultat
	push_error("Impossible de lire %s : vérifie qu'il ne manque pas une virgule ou un guillemet." % chemin)
	return {}


## Tire un nombre au hasard entre les deux valeurs d'une liste [min, max].
static func entre(valeurs) -> float:
	if valeurs is Array and valeurs.size() == 2:
		return randf_range(float(valeurs[0]), float(valeurs[1]))
	return float(valeurs) if valeurs != null else 0.0
