# Les montures

Sur les îles, ton agent peut appeler une **monture d'époque** pour traverser les zones
beaucoup plus vite.

## Comment ça marche dans le jeu

| Action | Touche |
|---|---|
| Appeler sa monture (il faut être immobile) | **V** |
| Descendre | **V** à nouveau |

- L'appel dure **1,5 seconde** (une barre s'affiche). Si tu bouges ou si tu es attaqué
  pendant ce temps, l'appel est annulé.
- En selle, tu cours **70 % plus vite** sur le renne, **60 %** sur l'âne.
- **Pas de roulade** à dos de monture.
- **Combat** : impossible d'appeler sa monture en combat. Si un ennemi te frappe, tu
  **tombes** de ta monture (et elle met 3 secondes à revenir). Lancer une compétence
  te fait aussi descendre.
- **Interdit** en ville (Hikari Bay) et dans les **donjons** (Grande Grotte…).
- Les autres joueurs te voient sur ta monture (elle passe par le serveur).

## Les montures de chaque époque

| Île | Monture | Remarque |
|---|---|---|
| Préhistoire | **Renne de la steppe** | Le renne des chasseurs de la toundra. |
| Égypte de Khéops | **Âne de bât** | La vraie monture de l'époque : ni cheval ni chameau en Égypte vers -2560. |

Pour l'instant, la monture de l'île est donnée à tout le monde pour que tu puisses
essayer. Plus tard (comme prévu dans le GDD), elles se gagneront avec la réputation :
cheval de Przewalski en Préhistoire, barque de papyrus en Égypte (monture aquatique).

**Modèles 3D** : les deux montures utilisent pour l'instant le modèle animé de l'élan
(Sketchfab, CC-BY, voir `game/assets/animaux/CREDITS.md`) : avec ses bois et un pelage gris
pour le renne, sans bois, plus petit, gris et avec de grandes oreilles pour l'âne. Un vrai
modèle d'âne (et de cheval) pourra le remplacer : il suffira de changer la ligne `modele`.

## Régler les montures (sans coder)

Tout est dans **`game/data/montures.json`** (s'ouvre avec le Bloc-notes) :

- `duree_invocation` : durée de l'appel (secondes).
- `recharge_apres_chute` : temps avant de pouvoir remonter après être tombé.
- Pour chaque monture :
  - `nom`, `description` : textes affichés ;
  - `epoque` : nom du dossier de l'île (`prehistoire`, `egypte`…) ;
  - `vitesse_pourcent` : vitesse en plus (70 = 70 % plus vite qu'à pied) ;
  - `echelle` : taille de la bête ;
  - `bois` : `true` pour garder les bois de l'élan, `false` pour les cacher ;
  - `oreilles` : taille des oreilles (1 = normale) ;
  - `selle` : hauteur où le personnage s'assoit (augmenter s'il s'enfonce dans le dos).

## Pour les développeurs

- `scripts/joueur/monture.gd` (nœud « Monture » du joueur) : règles, décision par le serveur,
  propriété `monture` recopiée chez tous les joueurs.
- `scripts/joueur/apparence_monture.gd` : la bête (modèle, pelage, allures Walk/Trot/Run/Sprint
  choisies selon la vitesse).
- `scripts/joueur/pose_cavalier.gd` : assoit le personnage Mixamo (jambes, bras) par-dessus son
  animation de repos.
- Une nouvelle zone de donjon : ajouter `add_to_group("donjon")` dans son script.
- Tests : `tests/test_montures.gd` (solo), `tests/test_reseau_montures.gd` (serveur + 2 clients),
  captures : `tests/capture_montures.gd`.
