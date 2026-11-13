# Visiter la Place Hikari (hub, maquette de blocs)

La première partie du hub Hikari Bay est jouable : la **Place Hikari**, l'escalier de la **station Asahi** qui descend vers la porte du QG, la rue qui mène au **front de mer**. Le plan complet de la ville est dans [docs/HUB.md](../HUB.md).

Les décors deviennent réalistes : sol pavé mouillé avec des flaques, façades en béton, mobilier urbain (lampadaires, bacs plantés, bornes à incendie, climatiseurs, rideaux de fer, blocs de béton de chantier) et enseignes en japonais, anglais et français. Les textures et modèles viennent de **Poly Haven** (gratuits, licence CC0). Les immeubles restent des volumes simples avec des fenêtres calculées : ils seront détaillés plus tard.

![La Place Hikari](../images/hub-place-hikari.jpg)

## L'ouvrir

1. Dans GitHub Desktop, sur la branche **main**, clique sur **Fetch origin** puis **Pull origin** (Claude le fait pour toi quand il le peut).
2. Ouvre le projet dans Godot (version standard, pas « mono »).
3. Dans le panneau **Système de fichiers** (en bas à gauche), double-clique sur `scenes/monde/hikari_bay.tscn`.
4. Appuie sur **F6** (« Lancer la scène actuelle »). Tu arrives sur la place, face à la statue et à l'écran géant.

Le menu de départ du jeu mène toujours à la colline de test : le hub sera relié au menu et au portail de la Préhistoire à l'étape 6.

## Ce qu'on peut y faire

- Se promener sur la place, sous la pluie, au milieu des néons.
- Descendre l'escalier de la **station Asahi** (coin sud-ouest de la place) jusqu'à la porte blindée de la Vigie.
- Descendre la rue du sud jusqu'au **front de mer** : la grande roue, et au large, la lumière de l'île de la Préhistoire.
- Les autres rues sont fermées par des barrières de chantier (Marché de nuit, Artisans, Musée, Résidences).

## Ce que tu peux régler toi-même

Clique sur le nœud **HikariBay** (tout en haut de la liste des nœuds) et regarde l'**Inspecteur** à droite :

| Réglage | Effet |
|---|---|
| **Prehistoire Reparee** | Coche-le : les éclats de fracture autour de la statue disparaissent. C'est un premier essai de « la ville qui change ». |
| **Pluie** | Décoche-le si le jeu rame. |
| **Gouttes** | Nombre de gouttes de pluie. |
| **Reconstruire la place** | Bouton qui refait toute la maquette. |

Pour les couleurs du ciel, du brouillard et de la lumière ambiante : nœud **Environnement**, puis la ressource *Environment* dans l'Inspecteur.
