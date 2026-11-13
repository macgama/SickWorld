extends Node
## Lit les fichiers de données du jeu (dossier data/) au démarrage.
## Ces fichiers se modifient avec un simple éditeur de texte, sans toucher au code.

var competences: Dictionary = {}
var joueur: Dictionary = {}
var ennemis: Dictionary = {}


func _ready() -> void:
	competences = _lire("res://data/competences.json")
	joueur = _lire("res://data/joueur.json")
	ennemis = _lire("res://data/ennemis.json")


func competence(id: String) -> Dictionary:
	return competences.get(id, {})


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
