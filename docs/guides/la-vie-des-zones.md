# La vie des zones

Les cartes ne sont plus vides : chaque zone a maintenant ses oiseaux, ses insectes,
ses habitants qui vaquent à leurs occupations et des milliers de petits objets posés
au sol. Le hub a sa foule, ses bateaux, son grand pont et ses avions.

Tout est décrit dans **un seul fichier** : `game/data/vie_ambiante.json`. Tu peux
le modifier avec n'importe quel éditeur de texte (Bloc-notes, VS Code…), sans code.

## Ce qu'il y a dans chaque zone

| Zone | Ce qui vit |
|---|---|
| **Côte Gelée** | goélands et mouettes sur la mer, corbeaux sur la faille, oies sauvages en V, galets, bois flotté |
| **Steppe des Mammouths** | corbeaux sur le camp, oies en V, un aigle, une nuée d'étourneaux, duvet dans le vent, étincelles du feu, moucherons sur la rivière, 5 membres du clan (porteuse d'eau, ramasseur de bois, tanneuse, sentinelle…), buissons, branches, souches |
| **Forêt des Bouleaux** | corbeaux, nuée de choucas, milans, un héron, libellules et moucherons sur la rivière, papillons dans la clairière, une cueilleuse et un porteur de fagot, beaucoup de bois mort et de mousse |
| **Falaises Peintes** | nuée de choucas devant la paroi, un aigle, étincelles du foyer de l'abri, 4 membres du clan, rochers au pied des falaises |
| **Port des Marais** | ibis et hérons sur le marais, milans, hirondelles sur les quais, vautours, libellules, porteurs de sacs, porteuse de jarre (sur la tête), un pêcheur qui lance son filet, papyrus et buissons, jarres et paniers |
| **Carrières de Toura** | vautours, choucas devant la falaise, ibis au bord du Nil, nuage de poussière de la carrière, 4 tailleurs de pierre au travail, porteurs entre la carrière et le débarcadère |
| **Village des Bâtisseurs** | hirondelles, pigeons, milans au-dessus du chantier, 12 habitants (porteuses d'eau qui montent au chantier, ouvriers qui redescendent, bavards sur la place, tailleurs de pierre, bouvier…), poussière du chantier, mouches de l'enclos, fumée du four |
| **Désert Rouge** | vautours qui tournent au-dessus des tombes, sable soulevé par le vent, le camp des nomades qui s'anime, un prêtre et son porteur sur la rue des mastabas |
| **Hikari Bay** | 28 passants de plus (sur la place, dans les rues, accoudés au garde-corps du front de mer), ferry, vedettes, voilier, bateaux de pêche, cargo au loin, **grand pont suspendu illuminé avec son flot de voitures**, avions et hélicoptère qui clignotent, distributeurs de boissons éclairés, vélos et scooters garés |

## Ajouter un oiseau, un habitant ou des cailloux

Ouvre `game/data/vie_ambiante.json`, trouve la section de la zone (par exemple
`"steppe"`), puis recopie une ligne existante et change les nombres.

- **Une volée d'oiseaux** : `{"espece": "corbeau", "centre": [28, -58], "altitude": 26, "rayon": 28, "nombre": 7}`
  - espèces : corbeau, choucas, goeland, mouette, oie, cygne, ibis, heron, vautour, milan, aigle, hirondelle, etourneau, pigeon
  - `"comportement": "formation"` = vol en V qui traverse le ciel ; `"nuee"` = nuée qui virevolte
- **Un habitant** : `{"comme": "egy_femme", "porte": "jarre", "chemin": [[30, 60], [14, 48]]}`
  - `comme` : un modèle de `modeles_figurants` (en haut du fichier)
  - `porte` : jarre, panier, fagot, sac, lance
  - `geste` (pendant ses pauses) : travail, priere, discute, lancer
  - un seul point dans `chemin` = il reste sur place ; `regarde` = son orientation (0 = nord, 90 = est)
- **Des insectes** : `{"sorte": "moucherons", "position": [24, -9, 1.0]}` — sortes : moucherons, mouches, papillons, libellules, poussiere, sable, duvet, lucioles, cendres
- **Des objets au sol** : `{"modele": "stone_01", "nombre": 900, "echelle": [0.25, 0.8]}` — on ne pose jamais rien sur un toit ou dans une maison.

Les positions sont en mètres, le nord est vers les `z` négatifs.

## Performances

- Tous les oiseaux d'une volée et tous les objets semés sont dessinés d'un coup
  (MultiMesh) : des milliers d'objets coûtent presque rien.
- Les insectes, la poussière et le sable sont calculés par la carte graphique.
- Un habitant loin de la caméra (plus de 85 m) est caché ; entre 35 et 85 m, il
  n'est animé qu'une image sur trois.
- En qualité **Bas** (touche F10), il y a moitié moins d'objets semés et d'insectes.
