# Mode admin (pour tester)

Le mode admin sert à tester le jeu sans tout refaire depuis le début.

## L'activer

1. Ouvre le projet dans **Godot** et lance le jeu (F5).
2. Dans le menu, choisis **Jouer seul** et entre en jeu.
3. Appuie sur **F9** : le panneau « Mode admin » s'ouvre en haut à droite. F9 ou Échap le referme.

## Ce qu'on peut faire

- **Aller dans une zone** : choisis Hikari Bay ou une île, puis la zone, et clique sur « Y aller ».
  Toutes les îles sont ouvertes, même sans avoir fini les précédentes ni l'intro.
- **Commencer un chapitre** : choisis l'île et le chapitre. Le jeu t'y emmène et la quête
  reprend au début de ce chapitre (les chapitres d'avant comptent comme faits).
- **Niveau** : choisis un niveau (1 à 70) avec les flèches et clique sur « Appliquer ».
  Les boutons 1, 11, 21… donnent directement le niveau de début de chaque île.
- **Invincible**, **Tuer en un coup**, **Courir 3 fois plus vite** : des cases à cocher.
  Elles restent actives d'une zone à l'autre, jusqu'à la fermeture du jeu.

## Qui peut s'en servir

Seulement toi : le panneau n'existe que quand le jeu est lancé **depuis Godot** (ou une version
« debug ») **et en solo**. La version publique (export « release ») et les parties en ligne ne
l'ont pas, et le serveur ignore tout de ces raccourcis.

Attention : changer de chapitre ou de niveau modifie ta sauvegarde de test (celle du profil
hors ligne sur ton PC).

Code : `game/scripts/autoload/admin.gd`. Test : `tests/test_admin.gd`.
