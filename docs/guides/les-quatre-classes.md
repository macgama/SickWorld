# Les quatre classes en combat

Chaque classe a 5 compétences (touches 1 à 5), une ressource et une attaque automatique.
Les touches 6 à 8 restent les compétences d'époque et l'ultime (voir les tenues de mission).

Pour essayer une classe : crée un personnage de cette classe dans le menu (ou change la classe à l'étape « Classe »), puis entre dans le jeu.

## Rempart (tank) — ressource : Ténacité

La Ténacité se remplit quand tu reçois des coups (et un peu avec tes attaques). Elle redescend hors combat. Le Rempart génère deux fois plus de menace que les autres.

| Touche | Compétence | Effet |
|---|---|---|
| 1 | Coup de bouclier | Petite attaque, +12 Ténacité, beaucoup de menace. |
| 2 | Provocation | Jusqu'à 25 m : l'ennemi est forcé de t'attaquer pendant 4 s. |
| 3 | Mur de bouclier | -60 % de dégâts reçus pendant 6 s. |
| 4 | Charge protectrice | Bondis vers un allié ciblé : tu encaisses son prochain coup (8 s). |
| 5 | Onde de choc | Ennemis à moins de 6 m : dégâts, étourdis 2 s, se tournent vers toi. |

## Traqueur (distance) — ressource : Concentration

La Concentration commence pleine et se remplit toute seule (8 par seconde). L'attaque automatique tire des flèches jusqu'à 30 m.

| Touche | Compétence | Effet |
|---|---|---|
| 1 | Tir rapide | Flèche rapide (35 m). |
| 2 | Flèche empoisonnée | Poison : 5 dégâts par seconde pendant 12 s. |
| 3 | Tir visé | 1,5 s de préparation, gros dégâts. |
| 4 | Piège à collet | Posé à tes pieds (30 s, 2 au maximum) : le premier ennemi qui passe est blessé et immobilisé 5 s. |
| 5 | Repli | Saut de 10 m en arrière, ralentit les ennemis proches de 50 %. |

## Tisseur (soins et soutien) — ressource : Flux

Le Flux commence plein et se remplit tout seul (5 par seconde). Les soins visent l'allié ciblé ; sans allié en cible, ils te soignent toi.

| Touche | Compétence | Effet |
|---|---|---|
| 1 | Fil de vie | 1,5 s de préparation, gros soin. |
| 2 | Éclat temporel | Projectile qui blesse l'ennemi ciblé. |
| 3 | Retour en arrière | Remet la vie au niveau d'il y a 5 s (au moins +15 %). |
| 4 | Bulle lente | Bulle de 6 m pendant 6 s : les ennemis dedans bougent 60 % moins vite et attaquent plus lentement. |
| 5 | Accélération | +30 % de vitesse et 6 points de vie par seconde pendant 10 s. |

## Lame (corps à corps) — ressource : Élan

Inchangée : Taille rapide, Entaille, Frappe tournoyante, Bond, Exécution.

## Contrôles et résistance

Étourdir et immobiliser ont un temps de résistance : un même ennemi contrôlé deux fois en moins de 10 secondes ne l'est que moitié moins longtemps. Les boss (l'Ours Sans Mémoire) y sont insensibles (`"insensible_controles": true` dans `ennemis.json`), mais la Provocation marche sur eux.

## Régler les chiffres

- `game/data/classes.json` : vie, compétences, attaque automatique et ressource de chaque classe.
- `game/data/competences.json` : dégâts, soins, recharges, coûts (`cout`) et gains (`gain`) de ressource.

Test automatique : `godot --headless --path game -s res://tests/test_classes.gd` (il affiche aussi un petit bilan d'équilibrage : chaque classe seule contre 2 loups).
