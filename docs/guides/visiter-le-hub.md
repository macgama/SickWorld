# Visiter la Place Hikari (hub, maquette de blocs)

La première partie du hub Hikari Bay est jouable : la **Place Hikari**, l'escalier de la **station Asahi** qui descend vers la porte du QG, la rue qui mène au **front de mer**. Le plan complet de la ville est dans [docs/HUB.md](../HUB.md).

Les décors deviennent réalistes : sol pavé mouillé avec des flaques, façades en béton, mobilier urbain (lampadaires, bacs plantés, bornes à incendie, climatiseurs, rideaux de fer, blocs de béton de chantier) et enseignes en japonais, anglais et français. Les textures et modèles viennent de **Poly Haven** (gratuits, licence CC0). Les immeubles restent des volumes simples avec des fenêtres calculées : ils seront détaillés plus tard.

![La Place Hikari](../images/hub-place-hikari.jpg)

## L'ouvrir

1. Dans GitHub Desktop, sur la branche **main**, clique sur **Fetch origin** puis **Pull origin** (Claude le fait pour toi quand il le peut).
2. **Si Godot était ouvert pendant la mise à jour**, ferme-le et rouvre-le (ou menu **Projet → Recharger le projet actuel**) : sinon il ne connaît pas les nouveaux fichiers.
3. Appuie sur **F5** (« Lancer le projet »), puis **Jouer seul** : tu arrives à Hikari Bay.
4. Pour tester seulement la ville sans passer par le menu : double-clique sur `scenes/monde/hikari_bay.tscn` puis **F6**.

**Jouer à plusieurs** : un joueur clique sur **Héberger**, les autres sur **Rejoindre** avec son adresse. « Rejoindre » seul ne marche pas : il faut qu'une partie soit hébergée.

## L'introduction (environ 5 minutes)

La première fois, un écran noir présente Hikari Bay, puis un **objectif** en haut de l'écran et une **flèche dorée** te guident :

1. parler à **Kenji Duval**, près de la fontaine (touche **F**) ;
2. descendre l'escalier de la **station Asahi** ;
3. parler à la **commandante Morel** dans le Hall des opérations ;
4. parler à **Yuki Tanabe** dans la salle des portails ;
5. traverser le **portail de la Préhistoire** : tu pars sur l'île.

Ensuite l'intro ne se rejoue plus. Pour la revoir : clique sur le nœud **Intro** de la scène et coche **Toujours rejouer** dans l'Inspecteur. Tous les textes sont dans `game/data/hub_intro.json` (modifiables sans code). Le voyage par portail se fait en solo pour l'instant ; en groupe, il arrive bientôt.

## Le Marché de nuit et les missions secondaires

La rue du nord-ouest de la place mène au **Marché de nuit** : trois ruelles étroites avec des stands de nourriture, des lanternes rouges et des enseignes empilées. Deux bâtiments se visitent :
- le restaurant de ramen **Kaminari** (ruelle principale), avec le chef Goro et ses clients ;
- la **salle Tsukimi** (ruelle de la fumée), le futur hôtel des ventes.

Des habitants proposent des **missions secondaires** : un **« ! »** doré flotte au-dessus d'eux. Parle-leur avec **F**. La mission en cours s'affiche en haut à gauche, un **« ? »** montre qui aller voir, et des flèches dorées montrent les objets à trouver. La touche **J** ouvre le journal des missions.

| Mission | Où la trouver |
|---|---|
| Kuro a disparu | Madame Sato, sur la place (côté nord-ouest) |
| Un bol pour la route | Le chef Goro, dans le restaurant Kaminari |
| L'écran qui grésille | Nina, sous l'écran géant |

Tous les textes des missions sont dans `game/data/hub_quetes.json`, et ceux des habitants dans `game/data/hub_pnj.json`.

## Ce qu'on peut y faire

- Se promener sur la place, sous la pluie, au milieu des néons.
- Descendre l'escalier de la **station Asahi** (coin sud-ouest de la place) : la porte blindée s'ouvre sur le **QG de la Vigie** (hall, coffre, entraînement, portails).
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
