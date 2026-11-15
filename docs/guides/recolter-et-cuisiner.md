# Récolter et cuisiner

Ce guide explique comment essayer les trois métiers de récolte (**Cueillette**, **Minage**, **Pêche**) et la cuisine du Chef Goro, et comment changer les sources sans coder.

## Essayer en jeu

1. Lance le jeu, va au QG de la Vigie et prends le portail de la **Préhistoire** (ou de l'Égypte).
2. Regarde autour de toi : de **petites étincelles** signalent les sources. Une touffe pâle sur une pierre (lichen), un bouleau abattu, des fleurs blanches (achillée), une pierre veinée (silex, ocre), une roche hérissée de cristaux (pyrite), des **ronds dans l'eau** (un banc de poissons).
3. Approche-toi : le nom de la source et le niveau qu'il faut s'affichent. La couleur te dit si c'est pour toi :
   - **rouge** : ton niveau est trop bas ;
   - **jaune** : parfait, beaucoup d'expérience ;
   - **vert** : moitié moins d'expérience ;
   - **gris** : tu n'apprends plus rien ici (mais tu récoltes quand même).
4. Appuie sur **F**, puis **ne bouge plus** pendant la barre d'action (2 s pour cueillir, 3 s pour miner, 5 s pour pêcher). Si tu bouges ou si un loup t'attaque, c'est interrompu.
5. Les matériaux vont dans tes sacs, et ton métier gagne de l'expérience. La source disparaît **pour toi seul** et repousse au bout d'une à deux minutes (les autres joueurs ont leurs propres sources).

**La pêche** se fait **depuis la rive** : place-toi au bord de l'eau, à quelques mètres des ronds (jusqu'à 9 m). Un bouchon rouge apparaît sur l'eau, puis plonge quand ça mord.

Tes niveaux sont dans l'écran **Personnage** (touche **C**), sous les caractéristiques. Chaque métier va du niveau 1 au niveau 10. La Préhistoire te fait monter jusqu'au niveau 4 ou 5 ; l'Égypte demande les niveaux 4 à 8.

## Que faire des matériaux ?

Va au **Quartier des Artisans** de Hikari Bay :
- **Forge Hinode** (Maître Tetsuo, Mika) : haches de silex et de cuivre, pendentif de cristal, collier de turquoises, amulette de faïence, nécessaire à feu, palette à fard.
- **Fil & Fibre** (Léa, Kofi) : gants et bottes en peau de poisson, tunique de lin, coiffe au lotus, sandales et paniers (des sacs plus grands).

Et au **marché de nuit**, le **Chef Goro** (Ramen Kaminari) cuisine tes poissons : parle-lui (F), son menu s'ouvre. Chaque recette donne **2 plats**.

**Manger** : clique sur un plat dans ton sac (hors combat). Tu gagnes un bonus pendant **30 minutes** (points de vie, dégâts, coups critiques ou protection). Un seul repas à la fois : en manger un autre remplace le premier. Le repas en cours s'affiche dans l'écran Personnage.

Survole un matériau dans ton sac : sa description raconte son histoire (c'est toujours vrai !).

## Changer les sources sans coder

Tout est dans `game/data/recolte.json`, à ouvrir avec un éditeur de texte :

- **`metiers`** : la durée de l'action (`duree`), le temps avant que les sources repoussent (`reapparition`, en secondes), la portée (`portee`, en mètres).
- **`paliers`** : l'expérience à atteindre pour chaque niveau.
- **`sources`** : chaque type de source. `niveau` = le niveau qu'il faut ; `donne` = ce qu'elle donne (`quantite` [min, max] et `chance` de 0 à 1) ; `visuel` = son apparence et ses couleurs.
- **`zones`** : les points de chaque zone, une ligne par point : `["achillee", 69.5, -45.0]` = une achillée à x = 69,5 et z = -45. Pour en ajouter une, copie une ligne et change les nombres. Pour connaître une position : dans Godot, déplace ton personnage à l'endroit voulu et lis sa position dans l'inspecteur (pendant que le jeu tourne, onglet « Distant »).

Les recettes (y compris celles du Chef Goro, artisan `cuisine`) sont dans `game/data/artisanat.json`, et les objets dans `game/data/objets.json` (les plats ont le type `consommable` et une partie `repas`).

Pour replacer automatiquement les points d'une zone (sol plat, loin des maisons et des rochers, rive praticable pour la pêche) : `tests/outil_points_recolte.gd -- --zone=steppe`, puis `python tools/recolte_points.py journal.log`.
