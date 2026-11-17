# Visiter la Chine des Han : la Porte de Jade

La première zone de l'île de la Chine est jouable : **la Porte de Jade** (niveaux 40 à 42). Nous sommes à l'hiver de l'an 105 après J.-C., sous l'empereur He de la dynastie Han, l'année où Cai Lun invente le papier. C'est là que mène le portail **Chine des Han** du QG de la Vigie (le cinquième en partant de la gauche). La conception de toute l'île est dans [ILE-5-CHINE.md](../ILE-5-CHINE.md).

On y trouve :

- **la vieille tour de guet en ruine** où l'on arrive par le portail, sur une petite colline, avec le feu de camp de Damien Roche ;
- **la Grande Muraille des Han**, au nord : pas en briques (celle-là viendra 1 300 ans plus tard), mais en **terre damée**, tassée couche par couche avec des **lits de roseaux** tous les 30 cm, comme les vrais restes de la muraille près de Dunhuang ;
- **les tours à fanaux**, de terre elles aussi, avec leur mât à signaux et, à leurs pieds, **les meules de combustible** (roseaux, branches et crottin) qu'on allumait pour donner l'alerte ;
- derrière la muraille, **les dunes** ; au sud, le désert de gravier semé de **tamaris** ;
- **le fort carré de la Porte de Jade**, haut de près de 10 m, avec ses deux portes, sa cour et la bannière rouge des Han ;
- **le relais des caravanes**, avec ses tentes de feutre, ses **chameaux de Bactriane** (à deux bosses), ses ballots de soie et la maison de la poste ;
- **la route de la soie**, une piste de terre tassée qui file d'ouest en est ;
- **un lac salé gelé** au sud-est, bordé de **peupliers de l'Euphrate**, les arbres des oasis ;
- au loin, la muraille qui continue à perte de vue, et au sud **les monts Qilian** enneigés.

Tout est fabriqué par le code. Les chameaux sont pour l'instant des décors en volumes simples (ils ne marchent pas) ; on pourra télécharger un vrai modèle gratuit sur Sketchfab plus tard, comme pour les autres animaux. Les habitants portent encore les habits d'époque déjà faits pour la Grèce et l'Égypte (tunique courte, robe longue, robe de nomade) : de vrais habits des Han viendront avec Luoyang.

## L'ouvrir

1. Dans GitHub Desktop, sur la branche **main** : **Fetch origin** puis **Pull origin** (Claude le fait pour toi quand il le peut).
2. **Ferme Godot et rouvre-le** s'il était ouvert pendant la mise à jour.
3. **Par le jeu** : F5, **Jouer seul**, puis au QG de la Vigie, traverse le portail **Chine des Han**.
4. **Directement** : double-clique sur `scenes/monde/chine/porte_de_jade.tscn` puis **F6**.

Pour revenir à Hikari Bay : éloigne-toi un peu du portail, puis retraverse-le.

## Le chapitre 1 : « La Porte de Jade »

1. Au pied de la tour en ruine, **Damien Roche, « Masque »**, t'attend près d'un feu. Il chasse maintenant l'Éditeur et te propose une alliance.
2. **Ton choix** : approche-toi d'une des deux réponses et appuie sur **F**. Accepter l'alliance, ou refuser parce que tu ne lui fais pas confiance. Les deux permettent de continuer, mais le jeu s'en souviendra à la fin de l'île.
3. Ramasser **la radio** qui grésille près du feu : c'est **Vera Lind** qui te parle, comme elle l'avait promis à Pompéi.
4. Suivre le sentier vers le nord jusqu'à la route, et chasser **les pillards fracturés** qui attaquent la caravane de soie.
5. Parler à **Ban Yong**, le commandant de la Porte de Jade (le fils du général Ban Chao, un vrai personnage).
6. **Rallumer les trois fanaux** au pied des tours de la muraille (appuie sur F et reste immobile). Quand le troisième flambe, regarde vers l'est : les autres tours répondent, jusqu'au bout de la muraille.
7. Parler à **Wang Ba**, le chef de la caravane, puis **escorter la caravane** jusqu'au relais (reste près d'elle : des loups descendent des dunes en chemin).
8. Retrouver Ban Yong devant la porte ouest du fort.

## Le chapitre 2 : « Les Figés »

1. Entrer dans la cour du fort : quatre hommes se sont **figés en argile**, comme des statues de terre cuite. Ils ont perdu la mémoire.
2. **Rendre la mémoire aux quatre Figés** : approche-toi de chacun et appuie sur **F**. Une feuille de calligraphie s'ouvre, avec un caractère chinois dessiné en gris et des **pastilles rouges numérotées** sur ses traits. Clique les pastilles (ou tape leur numéro) **dans l'ordre où le pinceau doit passer**. La règle : de haut en bas, de gauche à droite, et le trait horizontal avant le trait vertical qui le croise. Une erreur efface l'encre et il faut recommencer ; après deux erreurs, le trait suivant s'allume en orange pour t'aider. **Échap** referme la feuille. Les quatre caractères sont 人 (l'homme), 木 (l'arbre), 山 (la montagne) et 大 (grand).
3. Au relais, **étouffer les flammes** des trois tas de lattes de bois du scribe (les registres et les lettres des soldats).
4. Parler à **Gan Ying**, l'homme qui a essayé d'aller jusqu'à Rome en l'an 97 (lui aussi a vraiment existé) : il reconnaît les objets romains de ton sac.
5. Au bord du **lac salé**, abattre **le chef des pillards fracturés** (un ennemi d'élite), puis **refermer la faille**.
6. Retourner voir Ban Yong (récompense : **l'épée de Ban Chao** et un manteau de la frontière), puis montrer le sceau du chef à Gan Ying. Il te donne **une lettre pour l'historienne Ban Zhao**, à Luoyang.

La suite (les terres de lœss et le Fleuve Jaune) arrive bientôt : la route de l'est s'ouvre à la fin du chapitre 2.

## Les ennemis

| Ennemi | Niveau | Où |
|---|---|---|
| Loup du désert fracturé | 40 | Dans les dunes, au nord de la muraille, et au sud-ouest |
| Pillard du désert fracturé | 41 | Autour de la route et du désert de gravier |
| Chef des pillards fracturé (élite) | 42 | Au bord du lac salé (chapitre 2) |

## Pour changer des choses (sans coder)

- **Les dialogues et les étapes** : `data/chine_quete.json` (entre guillemets).
- **Les personnages** (noms, couleur de peau et d'habits, Figés ou non) : `data/chine_pnj.json`.
- **Les caractères à tracer** : la liste « calligraphie » de l'étape « figes », dans `data/chine_quete.json`. Les caractères connus sont 人 大 山 木 天 火 文 中 水.
- **Les ennemis** (vie, dégâts) : `data/ennemis.json` ; **les objets** : `data/objets.json`.
