extends Node
## Porte la fiche du personnage (apparence, classe, origine) d'un joueur dans la partie.
##
## C'est le SERVEUR qui la remplit (après l'avoir vérifiée) ; le synchroniseur
## enfant la recopie chez tous les joueurs, qui voient ainsi le bon visage,
## la bonne tenue et la bonne arme.

signal changee

var donnees: Dictionary = {}:
	set(valeur):
		donnees = valeur
		changee.emit()
