# Le son : musiques, ambiances, bruitages

## Ce que tu entends en jeu

| Où | Musique | Ambiance |
|---|---|---|
| Menu et création du personnage | Piano calme (« Beginning ») | — |
| Hikari Bay | Lo-fi de nuit, une piste au hasard puis un silence, comme dans WoW | Pluie sur la ville, circulation lointaine, foule, vagues ; de temps en temps un klaxon, un train, le tonnerre |
| Côte Gelée | « Quiet Village » | Vent arctique, vagues, corbeaux, hurlements de loups au loin |
| Steppe des Mammouths | idem | Vent dans les herbes, oiseaux, loups au loin |
| Forêt des Bouleaux | idem | Forêt, chouette, corbeaux, loups |
| Falaises | idem | Vent, rivière, corbeaux |
| Grotte | Drones sombres (« Caves ») | Souffle grave, gouttes d'eau, **écho** sur tous les bruitages |

- **Sous un toit** (station, auvent, QG, appartement) la pluie et la ville sont étouffées, comme à travers un mur.
- **Pas** : béton dans la ville (bois en intérieur), et dans la Préhistoire la surface est lue sur le terrain : neige, terre, herbe.
- **Personnage** : saut, réception, roulade d'esquive, cri quand on prend un coup ou qu'on meurt (voix d'homme ou de femme selon ton agent).
- **Combat** : élan de chaque attaque, coups reçus, sagaie qui siffle et se plante, feu qui crépite.
- **Bêtes** : le loup gronde quand il te repère, grogne en mordant, gémit en mourant. Ours et rennes ont aussi leurs cris.
- **Feux de camp** : chaque feu crépite quand tu t'en approches.
- **Interface** : chaque bouton fait « clic » et réagit au survol ; petit jingle quand une quête est acceptée, avance ou se termine, et au passage d'un portail.

Les volumes (général, musique, ambiance, effets, interface) se règlent dans l'écran **Options**.

## Changer un son ou un volume sans coder

Tout est dans `game/data/audio.json` (s'ouvre avec le Bloc-notes) :

- `volume_db` : 0 = volume du fichier ; **-6 = deux fois moins fort**, +6 = deux fois plus fort.
- `musiques` : la liste des pistes de chaque lieu et la durée du silence entre deux pistes.
- `scenes` : pour chaque lieu, ses ambiances, ses sons « ponctuels » (`intervalle` en secondes, `distance` en mètres) et la surface des pas.
- `effets`, `betes`, `interface` : les bruitages.

Pour **remplacer un son** : mets ton fichier `.ogg` dans `game/audio/<dossier>/` avec le même nom (par exemple `ambiances/pluie_ville.ogg`). Pour **ajouter des variantes** jouées au hasard, numérote-les : `pas/neige_course_1.ogg`, `_2`, `_3`… Pour une nouvelle musique, ajoute le fichier dans `musique/` et son nom dans la liste du lieu.

Pense à noter dans `docs/CREDITS.md` d'où vient chaque nouveau son (licence CC0 ou CC-BY de préférence).

## Pour le code

- `Audio.effet("coup", position)` joue un bruitage de la section `effets`.
- `Audio.interface("valider")` joue un son d'interface.
- `Audio.jouer_3d("combat/lame", position, volume_db)` joue n'importe quel fichier.
- `Audio.musique("hub")` change de liste de musiques (fait tout seul selon la scène).
- Un bouton qui ne doit pas cliquer : `bouton.set_meta("sans_son", true)` avant de l'ajouter.
- Test automatique : `godot --headless --path game -s res://tests/test_audio.gd`.
