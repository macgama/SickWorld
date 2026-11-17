# L'Arsenal des époques : l'équipement de chaque île

Plus on avance dans le temps, plus les ennemis sont coriaces. Le niveau seul ne suffit pas : il faut **s'équiper sur chaque île**. L'Arsenal des époques donne, pour chaque île, **trois panoplies de 7 pièces** (arme, torse, jambes, tête, mains, pieds, bijou) :

- **Assaut** : pour la Lame et le Traqueur (dégâts et coups critiques) ;
- **Garde** : pour le Rempart (vie et protection) ;
- **Harmonie** : pour le Tisseur (soins, vie et un peu de dégâts).

Chaque panoplie a des **bonus d'ensemble** à 3, 5 et 7 pièces (normales et renforcées comptent ensemble).

## Où et comment

- Va voir **Inès, la soudeuse**, dans le **quartier des Artisans** du hub (près de la forge Hinode). Parle-lui : son établi s'ouvre, avec un onglet par île.
- Une pièce **normale** (bleue, « rare ») demande des **éclats de fracture** (ils tombent sur presque tous les ennemis « fracturés ») et des **matériaux de l'île**.
- Une pièce **renforcée** (violette, « épique », 35 % plus forte) demande la pièce normale, des éclats et le **trophée du boss du donjon de l'île** (fourrure de l'Ours sans mémoire, écaille d'Isfet, œil de la Gorgone, bronze du Colosse). En Chine, en attendant le boss final, ce sont des plaquettes de laque.
- Chaque pièce demande un **niveau** : 6 / 10 en Préhistoire, 16 / 20 en Égypte, 26 / 30 en Grèce, 36 / 40 à Rome, 46 / 50 en Chine (normale / renforcée). On peut la fabriquer avant, mais pas la porter.
- Comme pour les autres améliorations, la pièce à renforcer doit être **dans les sacs** (pas portée), et la version renforcée la remplace aussi dans les tenues de mission.

![L'atelier d'Inès](../images/arsenal-ines.jpg)

## Pourquoi c'est important (l'équilibre)

Sans équipement d'île, à partir de la Grèce, un ennemi ordinaire met plus de temps à tomber qu'il n'en faut pour te mettre à terre. Avec la panoplie de l'île (renforcée), une Lame tue un ennemi ordinaire de fin d'île en 18 à 28 secondes et tiendrait plus d'une minute contre lui. Le test `tests/test_arsenal.gd` vérifie ces chiffres pour chaque île.

## Tout régler sans code

Le fichier `game/data/arsenal.json` est **fabriqué par un script** : `python3 tools/progression/generer_arsenal.py`. Pour changer la puissance, les noms, les couleurs ou les matériaux, ou **ajouter une nouvelle île** (une ligne de plus dans la liste `ILES`, palier 6 pour l'île 50-60), modifie le script puis relance-le, puis `python3 tools/progression/ecrire_guides.py` pour refaire les tableaux ci-dessous. Les icônes se refont avec `godot --path game -s res://tests/generer_icones.gd -- --manquantes`.

<!-- tableaux -->

## Préhistoire (niveau 6, renforcé niveau 10)

- Armures : 3 × Éclat de fracture, 3 × Peau de loup, 2 × Tendon séché.
- Arme et bijou : 3 × Éclat de fracture, 3 × Silex, 1 × Bois de renne.
- Renforcer une pièce : 5 × Éclat de fracture, 1 × Fourrure de l'Ours Sans Mémoire.

**Croc de la steppe** — Assaut (Lame, Traqueur)

| Pièce | Nom | Normale | Renforcée |
|---|---|---|---|
| Arme | Lance du croc | +10 % dégâts, +1 % critiques, +15 vie | +14 % dégâts, +2 % critiques, +20 vie |
| Torse | Cape du croc | +6 % dégâts, +1 % critiques, +35 vie | +8 % dégâts, +1 % critiques, +50 vie |
| Jambes | Jambières du croc | +5 % dégâts, +1 % critiques, +30 vie | +6 % dégâts, +1 % critiques, +35 vie |
| Tête | Capuche du croc | +4 % dégâts, +25 vie | +5 % dégâts, +1 % critiques, +30 vie |
| Mains | Brassards du croc | +3 % dégâts, +20 vie | +4 % dégâts, +25 vie |
| Pieds | Bottes du croc | +3 % dégâts, +20 vie | +4 % dégâts, +25 vie |
| Bijou | Collier de crocs | +3 % dégâts, +20 vie | +4 % dégâts, +30 vie |

Bonus d'ensemble : 3 pièces : +4 % de dégâts ; 5 pièces : +2 % de coups critiques ; 7 pièces : +3 % de dégâts et 2 % de vol de vie.

**Peau d'aurochs** — Garde (Rempart)

| Pièce | Nom | Normale | Renforcée |
|---|---|---|---|
| Arme | Massue d'aurochs | +4 % dégâts, +30 vie | +5 % dégâts, +40 vie |
| Torse | Manteau d'aurochs | +2 % dégâts, +1 % protection, +65 vie | +3 % dégâts, +2 % protection, +85 vie |
| Jambes | Jambières d'aurochs | +2 % dégâts, +1 % protection, +50 vie | +3 % dégâts, +1 % protection, +65 vie |
| Tête | Bandeau d'aurochs | +2 % dégâts, +1 % protection, +40 vie | +2 % dégâts, +1 % protection, +55 vie |
| Mains | Brassards d'aurochs | +1 % dégâts, +1 % protection, +35 vie | +2 % dégâts, +1 % protection, +50 vie |
| Pieds | Bottes d'aurochs | +1 % dégâts, +1 % protection, +35 vie | +2 % dégâts, +1 % protection, +50 vie |
| Bijou | Collier de cornes | +1 % dégâts, +40 vie | +1 % dégâts, +50 vie |

Bonus d'ensemble : 3 pièces : +40 points de vie ; 5 pièces : +2 % de protection ; 7 pièces : +60 points de vie et les contrôles durent 18 % de moins sur toi.

**Esprit du clan** — Harmonie (Tisseur)

| Pièce | Nom | Normale | Renforcée |
|---|---|---|---|
| Arme | Bâton des esprits | +3 % soins, +7 % dégâts, +20 vie | +4 % soins, +9 % dégâts, +1 % critiques, +25 vie |
| Torse | Cape des esprits | +2 % soins, +4 % dégâts, +45 vie | +2 % soins, +5 % dégâts, +60 vie |
| Jambes | Jambières des esprits | +1 % soins, +3 % dégâts, +35 vie | +2 % soins, +4 % dégâts, +45 vie |
| Tête | Bandeau d'ocre | +1 % soins, +3 % dégâts, +25 vie | +1 % soins, +4 % dégâts, +35 vie |
| Mains | Brassards des esprits | +1 % soins, +2 % dégâts, +25 vie | +1 % soins, +3 % dégâts, +30 vie |
| Pieds | Bottes des esprits | +1 % soins, +2 % dégâts, +25 vie | +1 % soins, +3 % dégâts, +30 vie |
| Bijou | Collier d'ambre | +1 % soins, +2 % dégâts, +25 vie | +1 % soins, +2 % dégâts, +35 vie |

Bonus d'ensemble : 3 pièces : +4 % de soins donnés ; 5 pièces : +2 % de coups critiques ; 7 pièces : +3 % de soins donnés et +40 points de vie.

## Égypte (niveau 16, renforcé niveau 20)

- Armures : 4 × Éclat de fracture, 4 × Lin, 2 × Écaille de crocodile.
- Arme et bijou : 4 × Éclat de fracture, 2 × Calcaire fin de Toura, 2 × Malachite.
- Renforcer une pièce : 6 × Éclat de fracture, 1 × Écaille d'Isfet.

**Lame du Nil** — Assaut (Lame, Traqueur)

| Pièce | Nom | Normale | Renforcée |
|---|---|---|---|
| Arme | Khopesh du Nil | +16 % dégâts, +2 % critiques, +30 vie | +21 % dégâts, +2 % critiques, +40 vie |
| Torse | Tunique du Nil | +9 % dégâts, +1 % critiques, +70 vie | +12 % dégâts, +1 % critiques, +90 vie |
| Jambes | Pagne du Nil | +7 % dégâts, +1 % critiques, +55 vie | +10 % dégâts, +1 % critiques, +70 vie |
| Tête | Coiffe du Nil | +6 % dégâts, +1 % critiques, +45 vie | +8 % dégâts, +1 % critiques, +60 vie |
| Mains | Brassards du Nil | +5 % dégâts, +1 % critiques, +35 vie | +7 % dégâts, +1 % critiques, +50 vie |
| Pieds | Sandales du Nil | +5 % dégâts, +35 vie | +6 % dégâts, +1 % critiques, +50 vie |
| Bijou | Scarabée du Nil | +4 % dégâts, +40 vie | +6 % dégâts, +1 % critiques, +55 vie |

Bonus d'ensemble : 3 pièces : +6 % de dégâts ; 5 pièces : +3 % de coups critiques ; 7 pièces : +6 % de dégâts et 3 % de vol de vie.

**Garde du pharaon** — Garde (Rempart)

| Pièce | Nom | Normale | Renforcée |
|---|---|---|---|
| Arme | Masse du pharaon | +6 % dégâts, +1 % protection, +55 vie | +8 % dégâts, +1 % protection, +75 vie |
| Torse | Corselet du pharaon | +4 % dégâts, +2 % protection, +125 vie | +5 % dégâts, +2 % protection, +165 vie |
| Jambes | Pagne de la garde | +3 % dégâts, +1 % protection, +95 vie | +4 % dégâts, +2 % protection, +130 vie |
| Tête | Némès de la garde | +2 % dégâts, +1 % protection, +80 vie | +3 % dégâts, +2 % protection, +105 vie |
| Mains | Brassards de la garde | +2 % dégâts, +1 % protection, +65 vie | +3 % dégâts, +1 % protection, +90 vie |
| Pieds | Sandales de la garde | +2 % dégâts, +1 % protection, +65 vie | +3 % dégâts, +1 % protection, +90 vie |
| Bijou | Ousekh de la garde | +2 % dégâts, +1 % protection, +75 vie | +2 % dégâts, +1 % protection, +100 vie |

Bonus d'ensemble : 3 pièces : +80 points de vie ; 5 pièces : +3 % de protection ; 7 pièces : +120 points de vie et les contrôles durent 21 % de moins sur toi.

**Souffle de Maât** — Harmonie (Tisseur)

| Pièce | Nom | Normale | Renforcée |
|---|---|---|---|
| Arme | Sceptre de Maât | +4 % soins, +11 % dégâts, +1 % critiques, +35 vie | +6 % soins, +15 % dégâts, +1 % critiques, +50 vie |
| Torse | Robe de Maât | +3 % soins, +6 % dégâts, +80 vie | +3 % soins, +8 % dégâts, +1 % critiques, +110 vie |
| Jambes | Pagne de lin de Maât | +2 % soins, +5 % dégâts, +65 vie | +3 % soins, +7 % dégâts, +85 vie |
| Tête | Bandeau à la plume | +2 % soins, +4 % dégâts, +50 vie | +2 % soins, +6 % dégâts, +70 vie |
| Mains | Bracelets de Maât | +1 % soins, +4 % dégâts, +45 vie | +2 % soins, +5 % dégâts, +60 vie |
| Pieds | Sandales de Maât | +1 % soins, +3 % dégâts, +45 vie | +2 % soins, +4 % dégâts, +60 vie |
| Bijou | Amulette d'Ânkh | +1 % soins, +3 % dégâts, +50 vie | +2 % soins, +4 % dégâts, +65 vie |

Bonus d'ensemble : 3 pièces : +6 % de soins donnés ; 5 pièces : +3 % de coups critiques ; 7 pièces : +6 % de soins donnés et +80 points de vie.

## Grèce (niveau 26, renforcé niveau 30)

- Armures : 5 × Éclat de fracture, 3 × Soies de sanglier, 2 × Peau de vipère.
- Arme et bijou : 5 × Éclat de fracture, 3 × Croc de chien errant, 1 × Défense de sanglier.
- Renforcer une pièce : 7 × Éclat de fracture, 1 × Œil de Gorgone.

**Peltaste d'Athènes** — Assaut (Lame, Traqueur)

| Pièce | Nom | Normale | Renforcée |
|---|---|---|---|
| Arme | Javeline de peltaste | +21 % dégâts, +2 % critiques, +55 vie | +28 % dégâts, +3 % critiques, +70 vie |
| Torse | Exomis de peltaste | +12 % dégâts, +1 % critiques, +115 vie, +1 % protection | +16 % dégâts, +2 % critiques, +160 vie, +1 % protection |
| Jambes | Cnémides de peltaste | +10 % dégâts, +1 % critiques, +90 vie | +13 % dégâts, +1 % critiques, +120 vie, +1 % protection |
| Tête | Pétase de peltaste | +8 % dégâts, +1 % critiques, +75 vie | +11 % dégâts, +1 % critiques, +100 vie |
| Mains | Brassards de peltaste | +7 % dégâts, +1 % critiques, +65 vie | +10 % dégâts, +1 % critiques, +85 vie |
| Pieds | Sandales de peltaste | +6 % dégâts, +1 % critiques, +65 vie | +9 % dégâts, +1 % critiques, +85 vie |
| Bijou | Fibule de peltaste | +6 % dégâts, +1 % critiques, +70 vie | +8 % dégâts, +1 % critiques, +95 vie |

Bonus d'ensemble : 3 pièces : +8 % de dégâts ; 5 pièces : +4 % de coups critiques ; 7 pièces : +9 % de dégâts et 3 % de vol de vie.

**Phalange d'Athéna** — Garde (Rempart)

| Pièce | Nom | Normale | Renforcée |
|---|---|---|---|
| Arme | Kopis de la phalange | +8 % dégâts, +1 % protection, +95 vie | +11 % dégâts, +1 % protection, +130 vie |
| Torse | Linothorax de la phalange | +5 % dégâts, +3 % protection, +210 vie | +6 % dégâts, +4 % protection, +285 vie |
| Jambes | Cnémides de bronze | +4 % dégâts, +2 % protection, +165 vie | +5 % dégâts, +3 % protection, +220 vie |
| Tête | Casque corinthien | +3 % dégâts, +2 % protection, +135 vie | +5 % dégâts, +2 % protection, +180 vie |
| Mains | Brassards de la phalange | +3 % dégâts, +1 % protection, +115 vie | +4 % dégâts, +2 % protection, +155 vie |
| Pieds | Sandales de la phalange | +3 % dégâts, +1 % protection, +115 vie | +3 % dégâts, +2 % protection, +155 vie |
| Bijou | Chouette de la phalange | +2 % dégâts, +1 % protection, +125 vie | +3 % dégâts, +1 % protection, +170 vie |

Bonus d'ensemble : 3 pièces : +120 points de vie ; 5 pièces : +4 % de protection ; 7 pièces : +180 points de vie et les contrôles durent 24 % de moins sur toi.

**Disciple d'Asclépios** — Harmonie (Tisseur)

| Pièce | Nom | Normale | Renforcée |
|---|---|---|---|
| Arme | Bâton d'Asclépios | +6 % soins, +15 % dégâts, +1 % critiques, +65 vie | +8 % soins, +20 % dégâts, +1 % critiques, +85 vie |
| Torse | Himation du disciple | +4 % soins, +8 % dégâts, +1 % critiques, +140 vie | +5 % soins, +11 % dégâts, +1 % critiques, +190 vie |
| Jambes | Chiton du disciple | +3 % soins, +7 % dégâts, +110 vie | +4 % soins, +9 % dégâts, +1 % critiques, +145 vie |
| Tête | Couronne de laurier | +2 % soins, +6 % dégâts, +90 vie | +3 % soins, +8 % dégâts, +120 vie |
| Mains | Bracelets du disciple | +2 % soins, +5 % dégâts, +75 vie | +3 % soins, +7 % dégâts, +105 vie |
| Pieds | Sandales du disciple | +2 % soins, +4 % dégâts, +75 vie | +3 % soins, +6 % dégâts, +105 vie |
| Bijou | Serpent d'argent | +2 % soins, +4 % dégâts, +85 vie | +2 % soins, +5 % dégâts, +110 vie |

Bonus d'ensemble : 3 pièces : +8 % de soins donnés ; 5 pièces : +4 % de coups critiques ; 7 pièces : +9 % de soins donnés et +120 points de vie.

## Rome (niveau 36, renforcé niveau 40)

- Armures : 6 × Éclat de fracture, 2 × Crinière de lion, 1 × Fourrure de l'ours du vivarium, 1 × Gilet de kevlar d'un prétorien.
- Arme et bijou : 6 × Éclat de fracture, 3 × Pioche de pilleur, 1 × Griffe de léopard.
- Renforcer une pièce : 8 × Éclat de fracture, 1 × Bronze du Colosse.

**Glaive de Mars** — Assaut (Lame, Traqueur)

| Pièce | Nom | Normale | Renforcée |
|---|---|---|---|
| Arme | Glaive de Mars | +27 % dégâts, +2 % critiques, +75 vie | +36 % dégâts, +3 % critiques, +100 vie |
| Torse | Lorica de Mars | +15 % dégâts, +1 % critiques, +165 vie, +1 % protection | +20 % dégâts, +2 % critiques, +220 vie, +1 % protection |
| Jambes | Braies de Mars | +12 % dégâts, +1 % critiques, +125 vie, +1 % protection | +17 % dégâts, +2 % critiques, +170 vie, +1 % protection |
| Tête | Casque de Mars | +11 % dégâts, +1 % critiques, +105 vie | +14 % dégâts, +1 % critiques, +140 vie, +1 % protection |
| Mains | Manicae de Mars | +9 % dégâts, +1 % critiques, +90 vie | +12 % dégâts, +1 % critiques, +120 vie, +1 % protection |
| Pieds | Caligae de Mars | +8 % dégâts, +1 % critiques, +90 vie | +11 % dégâts, +1 % critiques, +120 vie |
| Bijou | Phalère de Mars | +7 % dégâts, +1 % critiques, +95 vie | +10 % dégâts, +1 % critiques, +130 vie |

Bonus d'ensemble : 3 pièces : +10 % de dégâts ; 5 pièces : +5 % de coups critiques ; 7 pièces : +12 % de dégâts et 4 % de vol de vie.

**Tortue prétorienne** — Garde (Rempart)

| Pièce | Nom | Normale | Renforcée |
|---|---|---|---|
| Arme | Spatha prétorienne | +11 % dégâts, +1 % protection, +135 vie | +14 % dégâts, +1 % protection, +180 vie |
| Torse | Lorica segmentata | +6 % dégâts, +3 % protection, +295 vie | +8 % dégâts, +4 % protection, +395 vie |
| Jambes | Braies prétoriennes | +5 % dégâts, +3 % protection, +225 vie | +7 % dégâts, +4 % protection, +305 vie |
| Tête | Galea prétorien | +4 % dégâts, +2 % protection, +185 vie | +6 % dégâts, +3 % protection, +250 vie |
| Mains | Manicae prétoriennes | +4 % dégâts, +2 % protection, +160 vie | +5 % dégâts, +2 % protection, +215 vie |
| Pieds | Caligae prétoriennes | +3 % dégâts, +2 % protection, +160 vie | +4 % dégâts, +2 % protection, +215 vie |
| Bijou | Torque prétorien | +3 % dégâts, +1 % protection, +175 vie | +4 % dégâts, +1 % protection, +235 vie |

Bonus d'ensemble : 3 pièces : +160 points de vie ; 5 pièces : +5 % de protection ; 7 pièces : +240 points de vie et les contrôles durent 27 % de moins sur toi.

**Flamme de Vesta** — Harmonie (Tisseur)

| Pièce | Nom | Normale | Renforcée |
|---|---|---|---|
| Arme | Bâton de Vesta | +8 % soins, +19 % dégâts, +1 % critiques, +90 vie | +11 % soins, +25 % dégâts, +2 % critiques, +120 vie |
| Torse | Stola de Vesta | +5 % soins, +11 % dégâts, +1 % critiques, +195 vie | +6 % soins, +14 % dégâts, +1 % critiques, +265 vie |
| Jambes | Tunique de Vesta | +4 % soins, +9 % dégâts, +1 % critiques, +150 vie | +5 % soins, +12 % dégâts, +1 % critiques, +205 vie |
| Tête | Voile de Vesta | +3 % soins, +7 % dégâts, +125 vie | +4 % soins, +10 % dégâts, +1 % critiques, +170 vie |
| Mains | Bracelets de Vesta | +3 % soins, +6 % dégâts, +105 vie | +4 % soins, +8 % dégâts, +145 vie |
| Pieds | Sandales de Vesta | +2 % soins, +6 % dégâts, +105 vie | +3 % soins, +8 % dégâts, +145 vie |
| Bijou | Bulla de Vesta | +2 % soins, +5 % dégâts, +115 vie | +3 % soins, +7 % dégâts, +155 vie |

Bonus d'ensemble : 3 pièces : +10 % de soins donnés ; 5 pièces : +5 % de coups critiques ; 7 pièces : +12 % de soins donnés et +160 points de vie.

## Chine (niveau 46, renforcé niveau 50)

- Armures : 7 × Éclat de fracture, 3 × Soie grège, 2 × Pelage de loup du désert.
- Arme et bijou : 7 × Éclat de fracture, 2 × Plaquette d'armure laquée, 2 × Écorce de mûrier.
- Renforcer une pièce : 9 × Éclat de fracture, 1 × Perle de la coiffe impériale.

**Arbalétrier des Han** — Assaut (Lame, Traqueur)

| Pièce | Nom | Normale | Renforcée |
|---|---|---|---|
| Arme | Jian de l'arbalétrier | +32 % dégâts, +3 % critiques, +100 vie | +44 % dégâts, +4 % critiques, +135 vie |
| Torse | Cuirasse laquée | +18 % dégâts, +2 % critiques, +220 vie, +1 % protection | +25 % dégâts, +2 % critiques, +295 vie, +1 % protection |
| Jambes | Pantalon de l'arbalétrier | +15 % dégâts, +1 % critiques, +170 vie, +1 % protection | +20 % dégâts, +2 % critiques, +230 vie, +1 % protection |
| Tête | Bonnet de l'arbalétrier | +13 % dégâts, +1 % critiques, +140 vie, +1 % protection | +17 % dégâts, +2 % critiques, +190 vie, +1 % protection |
| Mains | Brassards laqués | +11 % dégâts, +1 % critiques, +120 vie | +14 % dégâts, +1 % critiques, +160 vie, +1 % protection |
| Pieds | Bottes de l'arbalétrier | +10 % dégâts, +1 % critiques, +120 vie | +13 % dégâts, +1 % critiques, +160 vie, +1 % protection |
| Bijou | Jade de l'arbalétrier | +9 % dégâts, +1 % critiques, +130 vie | +12 % dégâts, +1 % critiques, +175 vie |

Bonus d'ensemble : 3 pièces : +12 % de dégâts ; 5 pièces : +6 % de coups critiques ; 7 pièces : +15 % de dégâts et 4 % de vol de vie.

**Garde de la Muraille** — Garde (Rempart)

| Pièce | Nom | Normale | Renforcée |
|---|---|---|---|
| Arme | Dao de la Muraille | +13 % dégâts, +1 % protection, +180 vie | +17 % dégâts, +2 % protection, +245 vie |
| Torse | Armure d'écailles de la Muraille | +7 % dégâts, +4 % protection, +395 vie | +10 % dégâts, +6 % protection, +535 vie |
| Jambes | Jambières de la Muraille | +6 % dégâts, +3 % protection, +305 vie | +8 % dégâts, +4 % protection, +415 vie |
| Tête | Casque de la Muraille | +5 % dégâts, +2 % protection, +250 vie | +7 % dégâts, +3 % protection, +340 vie |
| Mains | Gantelets de la Muraille | +4 % dégâts, +2 % protection, +215 vie | +6 % dégâts, +3 % protection, +290 vie |
| Pieds | Bottes de la Muraille | +4 % dégâts, +2 % protection, +215 vie | +5 % dégâts, +3 % protection, +290 vie |
| Bijou | Sceau de la Muraille | +3 % dégâts, +1 % protection, +235 vie | +5 % dégâts, +2 % protection, +315 vie |

Bonus d'ensemble : 3 pièces : +200 points de vie ; 5 pièces : +6 % de protection ; 7 pièces : +300 points de vie et les contrôles durent 30 % de moins sur toi.

**Lettré de Luoyang** — Harmonie (Tisseur)

| Pièce | Nom | Normale | Renforcée |
|---|---|---|---|
| Arme | Pinceau-bâton du lettré | +10 % soins, +23 % dégâts, +1 % critiques, +120 vie | +13 % soins, +31 % dégâts, +2 % critiques, +160 vie |
| Torse | Robe de soie du lettré | +6 % soins, +13 % dégâts, +1 % critiques, +265 vie | +7 % soins, +17 % dégâts, +1 % critiques, +355 vie |
| Jambes | Pantalon de soie | +5 % soins, +11 % dégâts, +1 % critiques, +205 vie | +6 % soins, +14 % dégâts, +1 % critiques, +275 vie |
| Tête | Bonnet du lettré | +4 % soins, +9 % dégâts, +1 % critiques, +170 vie | +5 % soins, +12 % dégâts, +1 % critiques, +225 vie |
| Mains | Manchettes du lettré | +3 % soins, +8 % dégâts, +145 vie | +4 % soins, +10 % dégâts, +1 % critiques, +195 vie |
| Pieds | Chaussons du lettré | +3 % soins, +7 % dégâts, +145 vie | +4 % soins, +9 % dégâts, +1 % critiques, +195 vie |
| Bijou | Bi de jade du lettré | +3 % soins, +6 % dégâts, +155 vie | +4 % soins, +8 % dégâts, +210 vie |

Bonus d'ensemble : 3 pièces : +12 % de soins donnés ; 5 pièces : +6 % de coups critiques ; 7 pièces : +15 % de soins donnés et +200 points de vie.

