# Ranger / sortir son arme

- **R** : ranger l'arme (dans le dos ou à la ceinture) ou la sortir. La touche se change dans Options > Touches.
- En entrant en combat, l'arme sort toute seule. Attaquer avec l'arme rangée la sort aussi, immédiatement.
- Après un combat, l'arme se range toute seule au bout de 4 secondes (réglage « Délai rangement auto » du nœud Joueur, groupe « Arme » ; 0 = jamais).
- Au départ (hub, arrivée sur une île), l'arme est rangée.

## Où va chaque arme

Réglé dans `game/scripts/objets/visuel_equipement.gd`, tableau `RANGEMENT` :

| Arme | Place |
|---|---|
| Lame, lance, propulseur | dans le dos, en diagonale (poignée au-dessus de l'épaule droite) |
| Massue, dague, couteau | à la ceinture, sur la hanche |

Une arme tenue en main gauche (arme secondaire) se range de l'autre côté.

## Le geste

Le bras va chercher l'arme par-dessus l'épaule (dos) ou à la hanche, puis revient : c'est un geste calculé (`scripts/joueur/geste_arme.gd`), qui ne bouge que les bras, donc on peut ranger son arme en courant. Une vraie animation Mixamo (« Sheathing Sword » / « Draw Sword ») pourra le remplacer plus tard.
