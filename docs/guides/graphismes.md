# Les graphismes de Hikari Bay

## Changer la qualité (touche F10)

En jeu, appuie sur **F10** : la qualité passe à **Bas → Moyen → Haut → Ultra** (un message s'affiche en haut de l'écran). Le choix est gardé pour la prochaine fois.

| Niveau | Pour qui | Ce qui est activé |
|---|---|---|
| **Bas** | PC portable, petite carte graphique | Pluie légère, pas de brouillard en volume, pas de reflets à l'écran, image calculée à 75 % puis agrandie (FSR) |
| **Moyen** | Carte graphique d'entrée de gamme | Reflets sur le sol mouillé, brouillard en volume léger, toits qui arrêtent la pluie, finition « cinéma » |
| **Haut** (par défaut) | Carte graphique récente | Tout ce qui précède en mieux + éclairage indirect à l'écran, éclaboussures, ombres des projecteurs, anticrénelage 2× |
| **Ultra** | Grosse carte graphique | + Éclairage global (les néons colorent les murs et le sol, SDFGI), brouillard très fin, anticrénelage 4× |

Si le jeu saccade, descends d'un niveau.

## Ce qui rend la ville « grandiose »

- **Façades** : les fenêtres ne sont pas des images. Derrière chaque vitre allumée, une vraie pièce est simulée (plafond éclairé, murs, meubles) : elle bouge avec la caméra. Trois styles : tours de bureaux vitrées, vieux béton, logements avec balcons. Quelques télés clignotent.
- **Immeubles** : soubassement + tour en retrait pour les plus hauts, corniches, toits équipés (climatiseurs, châteaux d'eau, locaux techniques), antennes avec feux rouges clignotants, couronnes lumineuses au sommet des gratte-ciel.
- **Horizon** : plus de 150 gratte-ciel, dont 4 tours géantes, et les lumières de l'autre rive de la baie.
- **Enseignes verticales** à la japonaise dans les rues autour de la place.
- **Vitrines** : on voit l'intérieur des boutiques en profondeur (rayonnages, plafond lumineux).
- **Ciel** : nuages bas éclairés par-dessous par la ville, et **éclairs** de temps en temps.
- **Pluie** : elle suit la caméra, s'éclaire près des néons, s'arrête sous les toits et les auvents, fait des ronds dans les flaques et dans la mer.
- **Brouillard en volume** : halos autour des néons et des lampadaires.
- **Reflets** : sol mouillé et flaques miroirs, mer qui reflète la grande roue.

## Pour les curieux (fichiers)

- `scripts/autoload/qualite_graphique.gd` : les 4 niveaux de qualité.
- `scripts/monde/immeubles_hikari.gd` : immeubles, horizon, enseignes verticales.
- `scripts/monde/ambiance_hikari.gd` : pluie, éclairs, projecteurs de la place, reflets.
- `shaders/` : `facade_nuit`, `vitrine`, `ciel_nuit`, `pluie`, `sol_mouille`, `eau`, `post_traitement`, `balise_aviation`.
- Les réglages de lumière, brouillard et couleurs sont dans le nœud **Environnement** de `scenes/monde/hikari_bay.tscn` (Inspecteur).
