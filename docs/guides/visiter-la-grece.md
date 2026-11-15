# Visiter la Grèce : le Pirée

La première zone de l'île de Grèce est jouable : **le Pirée** (niveaux 20 à 22), le port d'Athènes, pendant l'été 438 av. J.-C., au temps de Périclès. C'est là que mène le portail **Grèce antique** du QG de la Vigie (le troisième en partant de la gauche). La conception de toute l'île est dans [ILE-3-GRECE.md](../ILE-3-GRECE.md).

On y trouve, du sud au nord :

- **la crique de l'Akté**, où l'on arrive par le portail, avec de l'eau claire jusqu'aux genoux, la plage de galets du pêcheur Glaukos, sa barque et ses filets ;
- **la colline rocheuse de l'Akté**, ses oliviers et ses rochers (le sac de l'agent Markos y est coincé, et une faille brille sur son flanc) ;
- **le chemin de la côte**, qui contourne la colline jusqu'au port ;
- **les loges des trières** : six grands hangars à toit de tuiles, dont les cales descendent jusque dans l'eau, avec des trières noires au sec (l'œil peint à la proue, l'éperon de bronze) ;
- **le bassin du Kantharos**, ses quais de pierre, ses navires de commerce, et **la Paralos**, la trière sacrée, amarrée au quai ouest ;
- **le grand portique du commerce**, avec ses colonnes doriques, sa frise peinte en rouge et bleu (les monuments grecs étaient peints !) et ses piles d'amphores ;
- **la ville en damier** dessinée par l'architecte Hippodamos, ses maisons blanchies à la chaux et sa petite agora ;
- **la porte des Longs Murs**, tout au nord : la route fortifiée vers Athènes (elle s'ouvrira au chapitre 3) ;
- **la colline de Mounichia**, à l'est, et son petit temple d'Artémis entouré de cyprès.

Au loin, au bout des Longs Murs, on voit **l'Acropole et le Parthénon** tout neuf. À l'ouest, l'île de Salamine ; au sud, Égine.

Tout est fabriqué par le code : le terrain, les bâtiments, les colonnes, les trières, les oliviers, les chiens (le modèle du loup recoloré) et le poulpe. Les textures viennent de **Poly Haven** (gratuites, licence CC0) ; celles qui sont propres à la Grèce (marbre, tuiles) seront ajoutées plus tard, en attendant on réutilise celles de l'Égypte.

## L'ouvrir

1. Dans GitHub Desktop, sur la branche **main** : **Fetch origin** puis **Pull origin** (Claude le fait pour toi quand il le peut).
2. **Ferme Godot et rouvre-le** s'il était ouvert pendant la mise à jour.
3. **Par le jeu** : F5, **Jouer seul**, puis au QG de la Vigie, traverse le portail **Grèce antique**.
4. **Directement** : double-clique sur `scenes/monde/grece/le_piree.tscn` puis **F6**.

Pour revenir à Hikari Bay : éloigne-toi un peu du portail, puis retraverse-le.

On ne nage pas encore : si tu t'avances trop loin dans la mer, tu es ramené sur la rive.

## Le chapitre 1 : « Le naufragé »

1. Parler à **Glaukos**, le vieux pêcheur, sur la plage (touche **F**). Il t'accueille selon la loi de l'hospitalité.
2. **Dégager le sac** de l'agent Markos, coincé dans les rochers à l'ouest de la crique : sa radio grésille.
3. Éliminer **4 chiens errants fracturés** sur l'Akté.
4. **Planter la balise** de la Vigie sur la plage, près du portail (rester immobile 4 secondes).
5. Retourner voir Glaukos, puis affronter **le poulpe fracturé** sur le haut-fond, au sud de la crique (un ennemi d'élite, avec huit bras).
6. **Récupérer les filets** de Glaukos, puis **refermer la faille** sur le flanc de l'Akté (deux chiens en sortent).
7. Glaukos t'envoie au port, chez son neveu Lysimaque.

## Le chapitre 2 : « Le Xénos »

1. Suivre **le chemin de la côte** jusqu'aux loges des trières.
2. Parler à **Lysimaque**, le rameur, puis à **l'agent Théo Markos** à travers les barreaux de l'enclos des archers scythes (on l'a pris pour un espion de Sparte).
3. Parler à **Phormion**, le stratège, au fond de l'arsenal : pour faire libérer Markos, il faut ramer sur la Paralos.
4. **Monter à bord** de la Paralos (F sur le quai ouest du bassin) et **ramer en cadence** : une jauge se remplit au rythme de la flûte ; appuie sur **F** quand elle est pleine. Un coup en cadence fait bien avancer la trière, un coup à contretemps presque pas. Au bout d'un tour du bassin, l'épreuve est réussie.
5. Chasser **les chiens** entrés dans les loges, puis abattre **le molosse fracturé** (un ennemi d'élite).
6. Phormion fait libérer Markos. **Lysimaque** t'offre le **xiphos** de son père (une épée courte de bronze) et le **bandeau de rameur** de la Paralos.
7. Markos parle des **masques de théâtre** qui rendent muets. La suite (les Oliveraies d'Attique et Athènes) arrive bientôt.

## Les ennemis

| Ennemi | Niveau | Où | Particularité |
|---|---|---|---|
| Chien errant fracturé | 20-21 | L'Akté, les loges | En meute, rapide |
| Poulpe fracturé | 21 (élite) | Haut-fond de la crique | 3 000 points de vie, frappe avec ses bras |
| Molosse fracturé | 22 (élite) | Le fond des loges | 2 600 points de vie, très fort |

Le niveau maximum passe de 20 à 30 avec cette île.

## Pour les curieux

- Le code de la zone : `scripts/monde/grece/le_piree.gd` (et `ile_grece.gd` pour ce qui sera commun à toute l'île : colonnes, portiques peints, maisons, amphores, trières, oliviers, cyprès).
- La trière où l'on rame : `scripts/monde/grece/triere_cadence.gd` (le rythme de la flûte, la marge pour un coup en cadence et la distance gagnée se règlent en haut du fichier).
- Les textes de la quête : `data/grece_quete.json` ; les personnages : `data/grece_pnj.json`.
- Le test automatique : `tests/test_le_piree.gd`.
