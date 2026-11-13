class_name Combattant
extends Node
## Tout ce qui peut se battre (joueur, loups…) possède un nœud Combattant.
## Il gère les points de vie, les effets (saignement, ralentissement…) et la menace.
##
## Ces règles sont regroupées ici pour pouvoir, à l'étape 3 (multijoueur),
## les faire tourner sur le serveur sans tout réécrire.

signal pv_changes(pv: float, pv_max: float)
signal degats_recus(montant: float, source: Combattant)
signal mort(tueur: Combattant)
signal reanime

## Nom affiché au-dessus de la tête et dans le cadre de cible.
@export var nom_affiche := "?"
@export var niveau := 1
@export var pv_max := 100.0
## Deux combattants de factions différentes sont ennemis.
@export var faction := "ennemi"
## Hauteur du « centre » du corps (pour les lignes de vue et les nombres de dégâts).
@export var hauteur_centre := 1.0

var pv := 100.0
## id de l'effet -> { fin, source, données… }
var effets := {}
## Combattant -> quantité de menace
var menace := {}
var dernier_moment_de_combat := -1000.0

## Copie simplifiée des effets, envoyée par le serveur aux joueurs pour l'affichage :
## id de l'effet -> secondes restantes.
var effets_affiches := {}
## Ralentissement actuel, envoyé par le serveur (les joueurs n'ont pas le détail des effets).
var vitesse_synchro := 1.0


func _ready() -> void:
	if multiplayer.is_server():
		pv = pv_max
	acteur().add_to_group("combattants")


func acteur() -> Node3D:
	return get_parent() as Node3D


func centre() -> Vector3:
	return acteur().global_position + Vector3.UP * hauteur_centre


func est_vivant() -> bool:
	return pv > 0.0


func est_hostile(autre: Combattant) -> bool:
	return autre != null and autre.faction != faction


func en_combat() -> bool:
	return Regles.maintenant() - dernier_moment_de_combat < 5.0


func noter_combat() -> void:
	dernier_moment_de_combat = Regles.maintenant()


func pourcentage_pv() -> float:
	return 100.0 * pv / pv_max


## Retire des points de vie. Renvoie les dégâts réellement subis.
func subir(montant: float, source: Combattant) -> float:
	if not est_vivant() or a_effet("evite"):
		return 0.0
	for effet in effets.values():
		montant *= 1.0 - float(effet.get("reduction_degats_subis", 0.0))
	montant = maxf(1.0, roundf(montant))
	pv = maxf(0.0, pv - montant)
	noter_combat()
	if source != null and is_instance_valid(source):
		source.noter_combat()
		menace[source] = menace.get(source, 0.0) + montant
	pv_changes.emit(pv, pv_max)
	degats_recus.emit(montant, source)
	if pv <= 0.0:
		effets.clear()
		mort.emit(source)
	return montant


func soigner(montant: float) -> float:
	if not est_vivant():
		return 0.0
	var avant := pv
	pv = minf(pv_max, pv + roundf(montant))
	pv_changes.emit(pv, pv_max)
	return pv - avant


func reanimer(pourcentage := 100.0) -> void:
	pv = roundf(pv_max * pourcentage / 100.0)
	effets.clear()
	menace.clear()
	pv_changes.emit(pv, pv_max)
	reanime.emit()


func ajouter_effet(id: String, duree: float, donnees: Dictionary = {}, source: Combattant = null) -> void:
	if not est_vivant():
		return
	var effet := donnees.duplicate()
	effet["fin"] = Regles.maintenant() + duree
	effet["source"] = source
	effet["prochain_tic"] = Regles.maintenant() + 1.0
	effets[id] = effet


func retirer_effet(id: String) -> void:
	effets.erase(id)


func a_effet(id: String) -> bool:
	if not multiplayer.is_server():
		return effets_affiches.has(id)
	return effets.has(id)


## Ralentissements : on garde le plus fort.
func multiplicateur_vitesse() -> float:
	if not multiplayer.is_server():
		return vitesse_synchro
	var m := 1.0
	for effet in effets.values():
		m = minf(m, float(effet.get("vitesse", 1.0)))
	return m


func multiplicateur_degats() -> float:
	var m := 1.0
	for effet in effets.values():
		m *= float(effet.get("degats_infliges", 1.0))
	return m


## Le combattant le plus menaçant encore en vie (c'est lui qu'un ennemi attaque).
func plus_menacant() -> Combattant:
	var meilleur: Combattant = null
	var max_menace := -1.0
	for autre in menace.keys():
		if not is_instance_valid(autre) or not autre.est_vivant():
			continue
		if menace[autre] > max_menace:
			max_menace = menace[autre]
			meilleur = autre
	return meilleur


func _process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	_publier_effets()
	if effets.is_empty():
		return
	var t := Regles.maintenant()
	for id in effets.keys():
		if not effets.has(id):
			continue
		var effet: Dictionary = effets[id]
		if t >= float(effet["prochain_tic"]):
			effet["prochain_tic"] = float(effet["prochain_tic"]) + 1.0
			var source = effet.get("source")
			if not is_instance_valid(source):
				source = null
			if effet.has("degats_par_seconde"):
				Regles.infliger(source, self, float(effet["degats_par_seconde"]), "periodique")
			if effet.has("soin_par_seconde"):
				Regles.soigner(source, self, float(effet["soin_par_seconde"]))
		if effets.has(id) and t >= float(effet["fin"]):
			effets.erase(id)


## Prépare la version simplifiée des effets envoyée aux joueurs.
func _publier_effets() -> void:
	var t := Regles.maintenant()
	var resume := {}
	for id in effets:
		resume[id] = int(ceil(float(effets[id]["fin"]) - t))
	if resume != effets_affiches:
		effets_affiches = resume
	var v := multiplicateur_vitesse()
	if not is_equal_approx(v, vitesse_synchro):
		vitesse_synchro = v
