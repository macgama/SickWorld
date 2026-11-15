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
| Massue, dague, couteau | à la ceinture, sur la hanche gauche (on la dégaine en croisant) |

Une arme tenue en main gauche (arme secondaire) se range de l'autre côté (hanche droite).

## Le geste

Ce sont de vraies animations Mixamo, jouées seulement sur le haut du corps (les jambes continuent de courir) :

| Fichier (dans `game/assets/personnages/<homme|femme>/`) | Animation Mixamo |
|---|---|
| `sortir_arme_dos.fbx` | Draw A Great Sword 2 |
| `ranger_arme_dos.fbx` | Sheath A Great Sword 2 |
| `sortir_arme_hanche.fbx` | Withdrawing Sword |
| `ranger_arme_hanche.fbx` | Sheathing Sword |

Le rythme (partie jouée, vitesse, moment où la main attrape l'arme) se règle dans le tableau `ANIMS_ARME` de `game/scripts/joueur/apparence_agent.gd`. Si un fichier manque, un geste calculé le remplace (`scripts/joueur/geste_arme.gd`).
