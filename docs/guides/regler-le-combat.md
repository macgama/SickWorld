# Régler le combat sans coder

Les compétences, le personnage et les loups sont décrits dans trois fichiers texte du dossier `game/data/`. Tu peux les modifier pour rendre le combat plus amusant, plus dur ou plus facile.

## Comment modifier un fichier

1. Dans Godot, panneau **Système de fichiers** (en bas à gauche), ouvre le dossier `data`.
2. Double-clique sur le fichier : il s'ouvre dans l'éditeur de texte de Godot.
   (Tu peux aussi l'ouvrir avec le Bloc-notes de Windows.)
3. Change un nombre, enregistre (**Ctrl+S**), puis lance le jeu (**F5**).

**Attention aux virgules et aux guillemets :** ne supprime que des chiffres ou du texte entre guillemets. Si le jeu affiche « Impossible de lire… » dans le panneau Sortie, c'est qu'une virgule ou un guillemet a sauté : annule avec **Ctrl+Z**.

## `competences.json` : les 8 compétences

Chaque compétence a les réglages suivants (seuls ceux qui la concernent sont présents) :

| Réglage | Signification |
|---|---|
| `nom`, `description` | Ce qui s'affiche dans la barre et au survol de la souris. |
| `degats` | Dégâts minimum et maximum, par exemple `[14, 18]`. |
| `portee` | Distance maximum en mètres (3,5 = corps à corps). |
| `recharge` | Secondes avant de pouvoir la réutiliser. |
| `cout_elan` / `gain_elan` | Élan consommé ou gagné. |
| `incantation` | Secondes de préparation (sans bouger). |
| `saignement`, `ralenti` | Effets ajoutés à la cible et leur durée. |
| `rayon`, `duree` | Taille et durée des zones (Frappe tournoyante, Feu des ancêtres). |
| `couleur` | Couleur de la case dans la barre (code couleur web, par exemple `#c0392b`). |

## `joueur.json` : le personnage

- `points_de_vie` : la vie du personnage.
- `barre` : l'ordre des compétences sur les touches 1 à 8. Tu peux échanger deux lignes pour changer leur place.
- `attaque_automatique` : les coups donnés automatiquement quand on est au contact d'une cible attaquée.
- `temps_de_recharge_global` : la pause après chaque compétence (1 seconde, comme dans WoW).
- `penalite_reapparition` : la pénalité après être retourné à la balise.

## `ennemis.json` : les loups

- `points_de_vie`, `degats`, `intervalle_attaque` : la force du loup.
- `vitesse_course` : le joueur court à 7. Au-dessus de 7, on ne peut plus fuir les loups.
- `distance_detection` : à quelle distance un loup te repère.
- `distance_laisse` : à quelle distance de son camp il abandonne la poursuite.
- `entraide` : les loups de camps à moins de cette distance viennent s'aider.
- `temps_reapparition` : secondes avant qu'un loup tué ne revienne.

`loup_allie` règle les loups invoqués par « Appel de la meute ».

## Déplacer les camps de loups

Dans la scène `colline_de_test.tscn`, les nœuds **CampNord**, **CampOuest**… sont les camps. Sélectionne-en un et déplace-le avec les flèches de couleur dans la vue 3D, ou change **Nombre** dans l'Inspecteur. Tu peux aussi en dupliquer un (**Ctrl+D**).
