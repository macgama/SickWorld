# SickWorld

MMORPG en 3D (vue à la troisième personne) où le joueur incarne un voyageur temporel chargé de réparer l'histoire, île après île, époque après époque.

- Moteur : Godot 4.7
- Outils : Blender, MakeHuman, Poly Haven, Mixamo, Fab (100 % gratuits)

## Organisation du dépôt

```
docs/      Documents de conception et guides pas à pas
game/      Le projet Godot (ouvrir game/project.godot)
  assets/    Modèles 3D, textures, sons, animations
  data/      Données de jeu (compétences, quêtes, objets)
  scenes/    Les zones, le personnage, l'interface
  scripts/   Le code (GDScript)
  shaders/   Les matériaux programmés (herbe, terrain…)
  tests/     Tests automatiques
```

![Étape 1 : la colline de test](docs/images/etape-1-colline.jpg)

## Guides

- [Ouvrir et tester le projet](docs/guides/ouvrir-et-tester-le-projet.md)
- [Créer le personnage avec MakeHuman et Mixamo](docs/guides/personnage-makehuman-mixamo.md)
- [Régler le combat sans coder](docs/guides/regler-le-combat.md)

## Tests automatiques

```
godot --headless --path game -s res://tests/test_deplacement.gd
godot --headless --path game -s res://tests/test_combat.gd
```
