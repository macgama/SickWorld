# Visiter la Préhistoire : la Côte Gelée

La première zone de l'île de la Préhistoire est jouable : **la Côte Gelée** (niveaux 1 à 3), il y a environ 17 000 ans, en pleine période glaciaire. C'est là que mène le portail de la Préhistoire du QG de la Vigie.

On y trouve une crique de galets entre deux falaises de calcaire, une mer glaciale où flottent des plaques de glace et des icebergs, un plateau enneigé couvert d'herbe sèche qui monte vers le nord, des rochers et du bois mort, le squelette d'un mammouth à moitié enfoui, et le camp de la Vigie autour du portail (tente arrachée, caisses renversées, projecteurs). Au nord du camp, une **faille** violette déchire l'air.

Les textures (galets, neige, terre gelée, falaises), les rochers scannés, le bois mort et le ciel viennent de **Poly Haven** (gratuits, licence CC0). Le reste (relief, mer, glace, squelette, faille) est fabriqué par le code.

## L'ouvrir

1. Dans GitHub Desktop, sur la branche **main** : **Fetch origin** puis **Pull origin** (Claude le fait pour toi quand il le peut).
2. **Ferme Godot et rouvre-le** si il était ouvert pendant la mise à jour (ou menu **Projet → Recharger le projet actuel**). La première ouverture importe les nouvelles images : ça peut prendre une ou deux minutes.
3. **Par le jeu** : F5, **Jouer seul**, puis au QG de la Vigie, traverse le portail de la Préhistoire.
4. **Directement** : double-clique sur `scenes/monde/prehistoire/cote_gelee.tscn` puis **F6**.

Pour revenir à Hikari Bay : éloigne-toi un peu du portail, puis retraverse-le. Tu arrives devant le portail du QG.

## Le chapitre 1 : « Arrivée dans le froid »

Un **objectif** en haut de l'écran et une **flèche dorée** te guident :

1. retrouver l'**agent Lenoir**, blessé près du portail (touche **F** pour parler) ;
2. ramasser la **trousse de soin** près des caisses renversées ;
3. **soigner Lenoir** (F, puis rester immobile 3 secondes) ; il explique les règles et le combat ;
4. éliminer les **4 loups fracturés** (veines violettes) qui rôdent autour du camp : **Tab** pour viser, **1 à 5** pour frapper ;
5. retourner voir Lenoir ;
6. **refermer la faille** (F, rester immobile 5 secondes, sans se faire toucher) : deux loups en sortent, il faut d'abord s'en occuper ;
7. faire son rapport à Lenoir.

Le chapitre 2 commence : suivre la piste jusqu'au **col**, au nord. La Steppe des Mammouths, derrière, arrive dans une prochaine mise à jour. Des loups sauvages vivent aussi sur le plateau.

L'avancement est gardé : si tu quittes le jeu, tu reprends là où tu en étais. Pour recommencer la quête : clique sur le nœud **Quete** de la scène et coche **Toujours recommencer**.

## Ce que tu peux régler toi-même

- **Les textes** (objectifs, dialogues de Lenoir, arrivée) : `game/data/prehistoire_quete.json` et `game/data/prehistoire_pnj.json`.
- **Les camps d'ennemis** (position, nombre, type) : section `camps` de `game/data/prehistoire_quete.json`.
- **Les loups fracturés** (vie, dégâts, vitesse, réapparition) : `game/data/ennemis.json`, entrées `loup_fracture` et `loup_fracture_faille`.
- Dans l'**Inspecteur**, nœud **CoteGelee** : la **graine** (autre relief), le **nombre de touffes** d'herbe (à baisser si le jeu rame), la **neige qui tombe**, et le **ciel** (essaie `table_mountain_1_puresky` pour une aube nuageuse ou `snow_field_2_puresky` pour un ciel couvert). Le bouton **Reconstruire l'île** refait tout.

## Le tester automatiquement

```
godot --headless --path game -s res://tests/test_cote_gelee.gd
```

Le test parcourt tout le chapitre 1 (Lenoir, trousse, soins, fracturés, faille, rapport), vérifie que l'avancement est gardé et que le portail ramène au hub.

## Ce qui viendra ensuite

- La **Steppe des Mammouths** (zone 2) et le **clan du Bison** (chapitres 2 et 3).
- De vrais modèles animés pour les loups (pour l'instant des silhouettes simples) et des habitants du clan.
- Des sons : vent, vagues, craquements de la glace.
