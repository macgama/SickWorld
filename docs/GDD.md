# SickWorld — Document de conception (GDD)

> **Version 0.1 — 13 novembre 2026**
> Document vivant : il sera complété au fil des décisions. Les passages marqués **[Proposition]** sont des idées à valider par Gaël ; tout le reste reprend des décisions déjà prises.

---

## Sommaire

1. [Vision du jeu](#1-vision-du-jeu)
2. [Scénario global](#2-scénario-global)
3. [Le hub : la ville moderne](#3-le-hub--la-ville-moderne)
4. [Structure d'une île](#4-structure-dune-île)
5. [Île n°1 : la Préhistoire (détaillée)](#5-île-n1--la-préhistoire)
6. [Classes et compétences](#6-classes-et-compétences)
7. [Combat](#7-combat)
8. [Progression](#8-progression)
9. [Direction artistique](#9-direction-artistique)
10. [Architecture technique](#10-architecture-technique)
11. [Plan du prototype](#11-plan-du-prototype)
12. [Questions ouvertes pour Gaël](#12-questions-ouvertes-pour-gaël)
13. [Glossaire](#13-glossaire)

---

## 1. Vision du jeu

### En une phrase

**SickWorld est un MMORPG en 3D où des voyageurs temporels partent d'une ville moderne pour réparer l'histoire de l'humanité, une époque à la fois, en combattant les « fractures » qui la déforment.**

### Les piliers (ce qui ne doit jamais être perdu de vue)

| Pilier | Ce que ça veut dire concrètement |
|---|---|
| **Voyager dans l'histoire** | Chaque île est une époque réelle. Le joueur doit sentir qu'il visite la Préhistoire, l'Égypte, le Moyen Âge… avec leurs paysages, leurs peuples, leurs objets. |
| **Collectionner et combiner** | Chaque époque donne des compétences et des récompenses uniques. Le plaisir vient de les combiner pour créer son propre style de jeu (comme dans Guild Wars). |
| **Jouer ensemble** | C'est un MMO : on croise d'autres joueurs, on fait des groupes, des événements publics, des donjons. |
| **Un mystère qui avance** | Les fractures ont une origine. Chaque île révèle un morceau de la vérité (ambiance enquête, comme The Secret World). |

### Références et ce qu'on leur emprunte

| Jeu | Ce qu'on garde |
|---|---|
| **World of Warcraft** | Combat par ciblage (Tab pour cibler, barre de sorts), rôles tank / soigneur / dégâts, donjons en groupe, sensation de monde ouvert. |
| **The Secret World** | Monde contemporain + mystère, organisation secrète, ambiance, quêtes d'enquête. |
| **Guild Wars** | Barre de compétences limitée qu'on compose soi-même, compétences à collectionner, zones instanciées, pas d'abonnement obligatoire. |

### Fiche technique

- **Genre :** MMORPG, aventure / action-RPG
- **Vue :** 3D, troisième personne (caméra derrière le personnage)
- **Style visuel :** réaliste
- **Plateforme :** PC Windows (d'autres plateformes plus tard, éventuellement)
- **Moteur :** Godot 4.7
- **Joueurs :** première version pour quelques dizaines de joueurs en même temps, architecture pensée pour monter à plusieurs milliers grâce à plusieurs serveurs.
- **Budget outils :** 0 € (uniquement des outils gratuits)

---

## 2. Scénario global

### Le monde

Nous sommes aujourd'hui. Le monde ressemble au nôtre, à un détail près : **l'histoire est malade**. Des déchirures invisibles, les **fractures**, apparaissent dans le passé et modifient des événements clés. À chaque fracture qui s'installe, le présent change un peu : un monument disparaît, une langue s'oublie, un souvenir collectif se brouille. Le nom du jeu vient de là : **SickWorld, le monde malade**.

Presque personne ne s'en rend compte, puisque pour les gens, la nouvelle version de l'histoire a « toujours » existé.

### L'organisation secrète

**[Proposition]** Une organisation discrète, **la Vigie** (nom provisoire), surveille la « santé » de l'histoire depuis des décennies. Elle a découvert un moyen d'envoyer des agents dans le passé grâce à des **ancres temporelles** : des lieux où le temps est plus « mince ». Le joueur est une nouvelle recrue de la Vigie.

Fonctionnement de la Vigie :
- Son quartier général est caché sous la ville du hub.
- Chaque époque accessible est représentée par une **île** : en réalité, c'est une « bulle » du passé stabilisée autour d'un lieu et d'un moment clé de l'histoire.
- Les agents ne doivent pas changer l'histoire eux-mêmes : ils doivent **remettre les choses comme elles étaient**. Cette règle crée des dilemmes intéressants dans les quêtes.

### Les fractures (les ennemis)

Les fractures sont à la fois **des lieux** et **des créatures** :

- **Les failles :** des déchirures dans le paysage, lumineuses et instables. Elles déforment les environs (objets anachroniques, végétation qui pousse à l'envers, ciel brisé).
- **Les fracturés :** des êtres ou animaux de l'époque contaminés par une faille. Ils gardent leur apparence d'origine mais avec des éclats « cristallins » et des mouvements saccadés, comme une vidéo qui saute.
- **Les anomalies :** des créatures qui n'ont rien à faire dans cette époque (par exemple un objet moderne vivant au milieu de la Préhistoire). Ce sont des ennemis plus rares et plus dangereux.

### Le fil rouge : qui cause les fractures ?

**[Proposition]** Les fractures ne sont pas un accident. Île après île, le joueur découvre des indices qui pointent vers **un autre groupe de voyageurs temporels**, surnommés **les Effaceurs**, qui veulent « réécrire » l'histoire pour créer un présent qui leur convient. Leur chef reste un mystère pendant longtemps. Révélations possibles au fil des îles :

1. **Préhistoire :** les fractures semblent naturelles… mais on trouve un objet fabriqué qui ne peut pas venir de cette époque.
2. **Antiquité :** première rencontre avec un Effaceur.
3. **Plus tard :** on découvre que certains Effaceurs sont d'anciens agents de la Vigie. La Vigie cache-t-elle quelque chose ?

Ce fil rouge reste ouvert : Gaël pourra le faire évoluer (voir questions ouvertes).

### L'ordre des îles

Les îles suivent l'ordre chronologique. **[Proposition]** de liste (à ajuster) :

| N° | Époque | Idée de moment clé à protéger |
|---|---|---|
| 1 | **Préhistoire** (environ -17 000 ans) | La naissance de l'art et l'amitié entre l'homme et le loup |
| 2 | Égypte antique | La construction d'une grande pyramide |
| 3 | Grèce / Rome antique | Les premiers Jeux, une bibliothèque, un sénat |
| 4 | Asie ancienne (Chine / Japon) | La route de la soie, un empire naissant |
| 5 | Moyen Âge européen | Les cathédrales, les croisades, la peste |
| 6 | Grandes découvertes / Renaissance | Les navigateurs, l'imprimerie, les artistes |
| 7 | Révolution industrielle | Vapeur, usines, grandes villes |
| 8 | XXe siècle | Les grands conflits et la conquête spatiale |

On commence par la Préhistoire, et **une seule île sera construite pour la première version**.

---

## 3. Le hub : la ville moderne

### Ambiance

**[Proposition]** La ville s'appelle **Hikari Bay** (nom provisoire). C'est une métropole d'aujourd'hui inspirée de **Tokyo** et **Singapour** :
- gratte-ciel, néons, écrans géants, enseignes lumineuses ;
- jardins suspendus et végétation partout (esprit Singapour) ;
- petites ruelles commerçantes, stands de nourriture, métro aérien (esprit Tokyo) ;
- un front de mer avec un port, d'où « partent » symboliquement les voyages vers les îles.

C'est un lieu **sûr** : pas de combat (sauf dans l'arène, voir plus bas). Les joueurs s'y retrouvent, discutent, échangent, préparent leur prochaine expédition.

### Les quartiers

| Quartier | Rôle pour le joueur |
|---|---|
| **Le QG de la Vigie** (sous une station de métro abandonnée) | Point de départ des quêtes principales, salle des portails vers les îles, entraîneurs de compétences. |
| **Le Marché de nuit** | Marchands, hôtel des ventes entre joueurs, nourriture (bonus temporaires). |
| **Le Quartier des Artisans** | Fabrication d'objets à partir des matériaux rapportés des époques. |
| **Le Musée** | Les objets historiques récupérés y sont exposés : c'est la « collection » du joueur, visible par tous. |
| **Les Résidences** | Plus tard : appartements personnels et sièges de guildes. |
| **L'Arène** | Plus tard : combats entre joueurs (JcJ) pour ceux qui le souhaitent. |

### Une idée forte : la ville qui change

**[Proposition]** Quand une époque est « malade », le hub en porte les traces : une statue manque sur une place, une fresque est effacée, un quartier est plongé dans le brouillard. Quand les joueurs réparent une époque, **la ville se « soigne » visiblement**. Cela donne un sens concret aux quêtes et montre les progrès de tout le serveur.

---

## 4. Structure d'une île

Chaque île suit le même modèle, pour que le contenu soit plus facile à produire.

### Contenu de chaque île

1. **La quête principale** (obligatoire pour continuer l'histoire) : 6 à 8 chapitres, se termine par un affrontement contre la fracture majeure de l'époque (souvent dans un donjon de groupe).
2. **Les quêtes secondaires** (optionnelles) : petites histoires sur les habitants de l'époque, elles donnent de l'expérience, de la réputation et des récompenses cosmétiques.
3. **Les quêtes d'events** : des événements publics qui se déclenchent dans le monde à intervalles réguliers. Tous les joueurs présents peuvent y participer sans former de groupe (comme les « événements dynamiques » de Guild Wars 2).

### Ce que chaque île apporte

- **Une tranche de niveaux** (par exemple niveaux 1 à 10 pour la Préhistoire).
- **Des compétences d'époque** : 4 à 6 compétences uniques, utilisables par toutes les classes (voir la section 6).
- **Des récompenses d'époque** : armes, tenues, compagnons, montures dans le style de l'époque.
- **Une réputation** auprès du peuple de l'époque, qui débloque des récompenses.
- **Un « taux de stabilité »** de l'époque, partagé par tout le serveur : plus les joueurs réussissent d'events, plus l'époque est stable (et plus le hub se soigne).

### Taille indicative

- Une île = **3 à 5 zones** reliées entre elles, plus **1 donjon de groupe** (5 joueurs) en fin de parcours.
- Durée de jeu visée pour une première découverte : **6 à 10 heures**.

---

## 5. Île n°1 : la Préhistoire

### Cadre historique

- **Quand :** il y a environ **17 000 ans**, en pleine **dernière période glaciaire** (Paléolithique supérieur).
- **Où :** une île inspirée de l'Europe de l'Ouest de l'époque (paysages proches de la Dordogne et des Pyrénées glaciaires, mais en version « île »).
- **Qui :** des chasseurs-cueilleurs *Homo sapiens*, nomades, qui vivent en clans. Ils peignent les parois des grottes (comme à Lascaux), taillent la pierre, chassent le renne et le mammouth.
- **Faune :** mammouths laineux, rhinocéros laineux, rennes, chevaux sauvages, aurochs, ours des cavernes, lions des cavernes, loups.

> **Note :** on reste crédible sans être un documentaire. Pas de dinosaures (ils ont disparu 66 millions d'années plus tôt) : c'est un choix volontaire pour respecter l'esprit « vraie histoire ».

### Le moment clé à protéger

**[Proposition]** La fracture de la Préhistoire menace **deux naissances** :
1. **La naissance de l'art** : le clan du Bison doit peindre la Grande Grotte, première trace d'une mémoire collective. Si ces peintures n'existent jamais, l'humanité perd « l'idée » de raconter son histoire.
2. **L'amitié entre l'homme et le loup** : un jeune chasseur est en train d'apprivoiser une louve. Si ce lien est rompu, le chien n'existera jamais.

Dans le hub, cela se voit : **les chiens ont disparu des rues** et **les fresques du musée sont vides**.

### Le peuple : le clan du Bison

**[Proposition]** Personnages principaux :

| Personnage | Rôle |
|---|---|
| **Aïna**, chamane et peintre du clan | Donne la quête principale. Elle « voit » les failles en rêve. |
| **Toran**, chef des chasseurs | Méfiant envers le joueur au début, allié fiable à la fin. |
| **Kéo**, jeune chasseur | Il essaie d'apprivoiser une louve, **Grise**. |
| **La Vieille Mère** | Gardienne des récits, donne des quêtes secondaires sur les traditions. |
| **Agent Lenoir** (Vigie) | Agent sur place, sert de contact radio et explique les règles au joueur. |

Les habitants ne comprennent pas d'où vient le joueur : pour eux, c'est un **« Venu-du-Brouillard »**. Une compétence de traduction de la Vigie permet de leur parler.

### Les zones

| Zone | Niveaux | Description |
|---|---|---|
| **1. La Côte Gelée** | 1-3 | Zone d'arrivée. Plage de galets, glace, falaises. Le portail de la Vigie y est installé. Tutoriel du combat. |
| **2. La Steppe des Mammouths** | 3-6 | Grande plaine herbeuse et froide, troupeaux de mammouths et de rennes. Le camp d'été du clan du Bison s'y trouve. |
| **3. La Forêt des Bouleaux** | 5-8 | Forêt clairsemée, rivière, territoire des loups. Les failles y sont nombreuses. |
| **4. Les Falaises Peintes** | 7-10 | Falaises calcaires et entrées de grottes. Abri d'hiver du clan. |
| **5. La Grande Grotte** (donjon) | 10 | Donjon à 5 joueurs dans les profondeurs, où se trouve la fracture majeure. |

### La quête principale : « Ce que les murs se rappellent »

| Chapitre | Titre | Résumé | Gameplay |
|---|---|---|---|
| 1 | **Arrivée dans le froid** | Le joueur traverse le portail et arrive sur la Côte Gelée. L'agent Lenoir est blessé. Le joueur doit le soigner et sécuriser le portail contre des fracturés. | Tutoriel : déplacement, caméra, ciblage, premières compétences. |
| 2 | **Le Venu-du-Brouillard** | Le joueur rencontre une partie de chasse du clan du Bison. Toran se méfie. Il faut prouver sa valeur en aidant à une chasse au renne. | Combat en groupe avec des alliés non-joueurs, première récompense d'époque. |
| 3 | **Le rêve d'Aïna** | La chamane a rêvé de « lumières qui mangent les images ». Elle demande au joueur de récolter des pigments (ocre, charbon, manganèse) pour une peinture rituelle. | Récolte, exploration de la steppe, combats contre des animaux. |
| 4 | **La louve grise** | Kéo a disparu dans la forêt en suivant sa louve. Le joueur le retrouve encerclé par des loups fracturés. Grise est contaminée. | Pistage (suivre des traces au sol), combat, choix : soigner Grise (plus difficile) ou la laisser fuir. *Les deux choix permettent de continuer.* |
| 5 | **L'objet impossible** | En fermant une faille, le joueur trouve un objet qui ne peut pas exister à cette époque (**[Proposition]** une montre à gousset brisée). Lenoir est troublé : quelqu'un d'autre voyage dans le temps. | Enquête : examiner l'objet, retourner au QG de la Vigie dans le hub (première visite guidée du hub). |
| 6 | **L'hiver qui vient trop tôt** | Une tempête anormale (provoquée par la fracture) pousse le clan vers les Falaises Peintes. Le joueur escorte les familles. | Escorte, défense de camp, event scénarisé. |
| 7 | **Les murs vides** | Dans la grotte, les peintures commencent à s'effacer d'elles-mêmes. Aïna comprend que la source est au fond de la Grande Grotte. | Préparation : recruter un groupe, réunir l'équipement. |
| 8 | **Ce que les murs se rappellent** | Donjon de la Grande Grotte. Le groupe affronte la fracture majeure : **l'Ours Sans Mémoire**, un ours des cavernes géant fusionné avec la faille. Après la victoire, Aïna peint la fresque, avec le joueur dedans. | Donjon à 5, boss final. Cinématique de fin. Dans le hub, les fresques du musée réapparaissent et les chiens reviennent dans les rues. |

### Les quêtes secondaires (exemples)

| Quête | Donneur | Résumé | Récompense |
|---|---|---|---|
| **Le premier collier** | La Vieille Mère | Rapporter des dents de renard et des coquillages pour faire un collier de cérémonie. | Bijou cosmétique « Collier du clan ». |
| **La flûte en os** | Un musicien du clan | Retrouver les morceaux d'une flûte en os de vautour volée par un fracturé. | Emote « Jouer de la flûte ». |
| **Le feu qui ne prend pas** | Une jeune gardienne du feu | Les failles empêchent le feu de prendre. Trouver de la pyrite et de l'amadou, et protéger le foyer. | Compétence d'époque « Feu des ancêtres ». |
| **Les traces du lion** | Toran | Pister un lion des cavernes qui menace le camp. | Tenue en fourrure de lion. |
| **La main sur la paroi** | Aïna | Laisser l'empreinte de sa main sur la paroi de la grotte (comme les vraies mains négatives préhistoriques). | Titre « Celui qui a laissé sa trace » + son empreinte visible par les autres joueurs. |
| **La lance perdue** | Un chasseur blessé | Retrouver un propulseur (arme de jet préhistorique) dans un marais. | Arme d'époque « Propulseur sculpté ». |
| **Les enfants et les étoiles** | Des enfants du clan | Aller observer les étoiles avec eux depuis une colline la nuit (quête calme, sans combat). | Ambiance, petite histoire sur les constellations, expérience. |
| **L'intrus moderne** | L'agent Lenoir | Retrouver et détruire trois objets modernes semés par les fractures (canette, téléphone, lunettes). | Points de réputation Vigie, indice sur les Effaceurs. |

### Les quêtes d'events (événements publics)

Ces événements arrivent régulièrement dans le monde, sans prévenir (avec une annonce à l'écran pour les joueurs proches). Tous les joueurs présents participent et sont récompensés selon leur contribution.

| Event | Zone | Déroulement | Fréquence indicative |
|---|---|---|---|
| **La Grande Migration** | Steppe des Mammouths | Un troupeau de mammouths traverse la steppe. Des fracturés tentent de le faire paniquer. Les joueurs protègent le troupeau sur tout son trajet. | Toutes les 2 heures |
| **La Faille s'ouvre** | Forêt des Bouleaux | Une grande faille apparaît et fait sortir des vagues d'ennemis, puis un mini-boss. Les joueurs doivent la refermer avant la fin du chrono. | Toutes les 45 minutes |
| **La Tempête blanche** | Toute l'île | Une tempête de neige réduit la visibilité. Il faut allumer des feux pour survivre et protéger les campements. | 1 à 2 fois par jour |
| **La Chasse au rhinocéros** | Steppe | Un rhinocéros laineux géant (élite) apparaît. Il faut un groupe pour le vaincre. | Toutes les 3 heures |
| **La Nuit des loups** | Forêt | La nuit, des meutes de loups fracturés attaquent. Bonus si un joueur a sauvé Grise dans la quête principale. | Chaque nuit du jeu |

### Les récompenses de la Préhistoire

| Type | Récompense |
|---|---|
| **Compétences d'époque** | Feu des ancêtres, Cri du clan, Pistage, Peinture de guerre, Lancer au propulseur, Appel de la meute *(voir section 6)* |
| **Compagnon** | **Un louveteau** (cosmétique, il suit le joueur). Récompense phare : c'est l'ancêtre du chien. |
| **Monture** | **[Proposition]** Un cheval de Przewalski (le cheval sauvage de l'époque), obtenu avec une réputation élevée. Le mammouth serait une récompense très rare. |
| **Tenues** | Fourrures, peintures corporelles, colliers de dents et de coquillages. |
| **Armes** | Lance à pointe de silex, propulseur, massue, couteau en obsidienne (avec un éclat de « technologie Vigie » pour rester efficaces). |
| **Musée** | Objets exposés dans le hub : statuette de « Vénus », flûte en os, lampe à graisse, propulseur sculpté. |

---

## 6. Classes et compétences

### Le principe : une classe + des compétences d'époque

L'idée centrale (inspirée de Guild Wars) : **chaque joueur compose sa propre barre de compétences**, avec un nombre de places limité. Il ne peut pas tout prendre, il doit choisir.

- **La classe** (choisie à la création du personnage) décide du **rôle** du joueur (tank, soigneur, dégâts) et donne ses **compétences de base**.
- **Les compétences d'époque** (gagnées sur chaque île) sont **utilisables par toutes les classes**. Elles permettent de personnaliser son personnage et de créer des combinaisons originales.

### La barre de compétences

**[Proposition]** La barre compte **8 emplacements** :

| Emplacements | Contenu |
|---|---|
| 1 à 5 | **Compétences de classe** (à choisir parmi toutes celles qu'on a apprises dans sa classe) |
| 6 et 7 | **Compétences d'époque** (n'importe quelle époque déjà visitée) |
| 8 | **Compétence ultime** (puissante, longue à recharger, de classe ou d'époque) |

Hors combat, on peut changer librement de compétences (près d'un **feu de camp** ou d'une **balise de la Vigie**). En combat, la barre est figée. Cela oblige à préparer sa stratégie avant un donjon, comme dans Guild Wars.

### Les classes de départ

**[Proposition]** Quatre classes au lancement, qui couvrent les trois rôles classiques. Toutes sont des « spécialités » de la Vigie, avec un équipement moderne adapté au voyage temporel.

| Classe | Rôle | Arme | Ressource | Style |
|---|---|---|---|---|
| **Rempart** | Tank (encaisse les coups, protège le groupe) | Bouclier + arme d'une main | **Endurance** (se remplit en recevant des coups) | Robuste, attire l'attention des ennemis, protège ses alliés. |
| **Lame** | Dégâts au corps à corps | Deux armes ou arme à deux mains | **Élan** (monte en enchaînant les attaques) | Rapide, mobile, gros dégâts sur une cible. |
| **Traqueur** | Dégâts à distance | Arc, fusil léger ou armes de jet | **Concentration** (se remplit lentement, les tirs la consomment) | Garde ses distances, pose des pièges. |
| **Tisseur** | Soigneur / soutien | Bâton ou appareil « chrono » | **Flux** (de l'énergie temporelle) | Soigne, protège, ralentit ou accélère le temps localement. |

> **Pourquoi seulement 4 ?** Chaque classe demande beaucoup de travail (animations, compétences, équilibrage). Mieux vaut 4 classes solides que 8 classes bancales. D'autres pourront arriver avec de nouvelles îles.

### Exemples de compétences de classe

| Classe | Compétence | Effet |
|---|---|---|
| Rempart | **Provocation** | Force l'ennemi ciblé à attaquer le Rempart. |
| Rempart | **Mur de bouclier** | Réduit fortement les dégâts reçus pendant 6 secondes. |
| Lame | **Taille rapide** | Attaque rapide qui génère de l'Élan. |
| Lame | **Exécution** | Gros dégâts sur une cible à moins de 20 % de vie. |
| Traqueur | **Tir visé** | Tir puissant avec un temps de préparation. |
| Traqueur | **Piège à collet** | Immobilise le premier ennemi qui marche dessus. |
| Tisseur | **Fil de vie** | Soigne un allié. |
| Tisseur | **Retour en arrière** | Remet la vie d'un allié au niveau d'il y a 5 secondes. |

### Les compétences d'époque de la Préhistoire

| Compétence | Effet | Combinaison intéressante |
|---|---|---|
| **Feu des ancêtres** | Allume un feu au sol : brûle les ennemis, réchauffe et soigne lentement les alliés autour. | Un Rempart peut tenir les ennemis dans le feu. |
| **Cri du clan** | Augmente les dégâts du groupe pendant 10 secondes. | Excellent en donjon, pour toutes les classes. |
| **Pistage** | Révèle les ennemis cachés et les points faibles de la cible (plus de coups critiques). | Puissant pour un Traqueur. |
| **Peinture de guerre** | Le joueur se couvre d'ocre : réduit les dégâts reçus pendant 8 secondes. | Donne une survie supplémentaire à une Lame ou un Tisseur. |
| **Lancer au propulseur** | Lance une sagaie à longue distance, qui ralentit la cible. | Donne une attaque à distance aux classes de corps à corps. |
| **Appel de la meute** *(ultime)* | Invoque deux loups qui combattent aux côtés du joueur pendant 20 secondes. | Disponible seulement après la fin de la quête principale. |

### Création du personnage

- Personnages humains réalistes, créés avec **MakeHuman** comme base (corps, visages, morphologies).
- **[Proposition]** Réglages proposés au joueur : sexe, morphologie, visage (préréglages + curseurs), peau, coiffure, couleur des cheveux et des yeux.
- Origine du personnage : **[Proposition]** choix d'une ville d'origine purement narrative (une ligne de dialogue change selon le choix), sans effet sur les statistiques.

---

## 7. Combat

### Le principe : ciblage classique, façon WoW

- **Cibler :** clic sur un ennemi, ou touche **Tab** pour passer d'un ennemi à l'autre.
- **Attaquer :** les compétences sont sur la barre (touches **1 à 8**). L'auto-attaque se lance quand on engage un ennemi.
- **Se déplacer :** touches **Z Q S D** (clavier français) ou **W A S D**, caméra à la souris (clic droit maintenu).
- La plupart des compétences **touchent automatiquement** la cible si elle est à portée et visible. Pas besoin de viser précisément : c'est le choix des compétences et du bon moment qui compte.

### Les règles de base

| Règle | Détail |
|---|---|
| **Temps de recharge global** | Après une compétence, une courte pause (environ 1 seconde) avant la suivante. Cela évite de tout lancer d'un coup et rend le combat lisible. |
| **Temps d'incantation** | Certaines compétences demandent quelques secondes de préparation ; bouger ou être interrompu les annule. |
| **Temps de recharge** | Chaque compétence a son propre délai avant de pouvoir être réutilisée. |
| **Menace (« aggro »)** | Les ennemis attaquent celui qui les dérange le plus. Le Rempart génère beaucoup de menace pour protéger les autres. |
| **Contrôles** | Étourdir, ralentir, immobiliser, interrompre. Avec un temps de résistance pour éviter de bloquer un ennemi indéfiniment. |
| **Esquive** | **[Proposition]** Une roulade d'esquive (touche dédiée, consomme une petite jauge) pour éviter les attaques puissantes signalées au sol. Ajoute un peu de dynamisme sans sortir du système de ciblage. |

### Les attaques signalées

Les ennemis importants préparent des attaques puissantes **visibles au sol** (zones colorées). Exemple : l'Ours Sans Mémoire frappe le sol et une zone rouge apparaît une seconde avant l'impact. Les joueurs doivent sortir de la zone. Cela rend les combats de boss intéressants même avec un système de ciblage simple.

### La mort

- Quand un personnage tombe à 0 point de vie, il est **« désynchronisé »** : il devient une silhouette translucide.
- Un allié peut le **relever** (compétence ou action de quelques secondes hors combat).
- Sinon, il réapparaît à la **balise de la Vigie** la plus proche, avec une petite pénalité temporaire (**[Proposition]** -10 % de statistiques pendant 2 minutes), sans perte d'objets ni d'expérience.

### Les combats de groupe

- **Groupe :** jusqu'à 5 joueurs (1 Rempart, 1 Tisseur, 3 dégâts pour un donjon classique).
- **Raid :** plus tard, jusqu'à 20 joueurs.
- **Events publics :** pas de groupe nécessaire, tout le monde contribue.

---

## 8. Progression

Le joueur progresse sur plusieurs axes en parallèle, pour toujours avoir un objectif.

### 1. Le niveau

- **[Proposition]** Chaque île couvre environ 10 niveaux : Préhistoire 1-10, deuxième île 10-20, etc.
- L'expérience vient des quêtes (surtout), des events, des ennemis et des découvertes de lieux.
- Monter de niveau augmente les statistiques et débloque de nouvelles compétences de classe.

### 2. Les compétences

- **Compétences de classe :** débloquées par les niveaux et achetées auprès des entraîneurs du QG.
- **Compétences d'époque :** gagnées par les quêtes et la réputation de chaque île.
- Objectif à long terme : **collectionner** toutes les compétences et créer ses propres combinaisons.

### 3. L'équipement

- Emplacements : tête, torse, mains, jambes, pieds, arme principale, arme secondaire, 2 bijoux, 1 relique d'époque.
- Rareté : **commun** (blanc), **raffiné** (vert), **rare** (bleu), **épique** (violet), **historique** (orange, objets uniques liés à des personnages ou événements réels).
- **Apparence séparée des statistiques :** le joueur peut porter la tenue d'une époque avec les statistiques d'une autre (**garde-robe**). Très important pour un jeu où chacun veut montrer ses tenues d'époque.

### 4. La réputation par époque

- Chaque peuple (clan du Bison, Égyptiens, etc.) a une jauge de réputation : *Méfiant → Neutre → Accueilli → Honoré → Membre du clan*.
- Chaque palier débloque des récompenses : tenues, compétences, compagnons, montures.

### 5. La stabilité de l'époque (progression collective)

- Une jauge **partagée par tout le serveur** pour chaque île.
- Elle monte quand les joueurs réussissent des events et ferment des failles, et descend lentement avec le temps.
- Paliers : bonus d'expérience pour tous, nouveaux marchands, et le **hub qui se transforme**.

### 6. Les collections

- **Le Musée** (objets historiques), **les compagnons**, **les montures**, **les titres**, **les tenues**.
- Ce sont des objectifs pour les joueurs qui aiment tout compléter, sans impact sur la puissance.

### 7. Le modèle économique

**[Proposition]** Jeu à **achat unique ou gratuit**, sans abonnement (comme Guild Wars), avec éventuellement une boutique **uniquement cosmétique**. Aucun avantage de puissance à vendre. À décider plus tard (voir questions ouvertes).

---

## 9. Direction artistique

### Le style : réaliste

C'est un choix assumé. Il implique :
- des **textures photoréalistes** (Poly Haven fournit gratuitement des textures et des objets scannés dans le monde réel, parfaits pour la nature préhistorique : rochers, herbes, troncs, sols) ;
- des **personnages humains réalistes** (MakeHuman pour la base, Blender pour les vêtements et ajustements) ;
- des **animations réalistes** (Mixamo fournit gratuitement des animations capturées sur de vrais acteurs : marche, course, attaques, morts) ;
- des **éclairages travaillés** : Godot 4.7 sait gérer lumière globale, brouillard volumétrique et ombres de qualité.

### Contraintes à connaître

| Contrainte | Comment on la gère |
|---|---|
| Le réaliste demande beaucoup de ressources 3D | On s'appuie au maximum sur les bibliothèques gratuites (Poly Haven, Fab, Mixamo) et on crée seulement ce qui manque. |
| Un MMO affiche beaucoup de personnages à l'écran | Plusieurs niveaux de détail par modèle (le modèle se simplifie quand il s'éloigne), limites de joueurs affichés, réglages graphiques. |
| Les animaux préhistoriques sont rares dans les bibliothèques | On cherche d'abord sur Fab et Sketchfab (modèles gratuits avec licence compatible), sinon on adapte des animaux actuels (éléphant → mammouth, ours → ours des cavernes). |
| Les licences | On note la licence de chaque ressource utilisée dans un fichier `docs/CREDITS.md` (obligatoire pour certaines). |

### Palette par lieu

- **Hub (Hikari Bay) :** nuit, néons bleus et roses, reflets sur la pluie, verdure.
- **Préhistoire :** blancs et bleus froids (glace), ocres et bruns (steppe, peintures), orange chaud des feux de camp.
- **Fractures :** toujours la même signature visuelle sur toutes les îles : **éclats cristallins violets-cyan**, distorsion de l'image, sons « numériques » qui grésillent. Le joueur doit reconnaître une fracture au premier coup d'œil.

---

## 10. Architecture technique

Cette section explique comment le jeu fonctionnera « sous le capot ». Elle est écrite pour être comprise sans connaissances en programmation.

### Vue d'ensemble

Un MMO, c'est **deux programmes** :
1. **Le client** : le jeu installé sur le PC du joueur. Il affiche le monde, joue les sons, lit le clavier et la souris.
2. **Le serveur** : un programme qui tourne en permanence sur une machine distante. C'est lui qui **décide de tout** (qui touche qui, combien de dégâts, quel objet tombe). Le client ne fait qu'afficher ce que le serveur lui dit.

> **Pourquoi le serveur décide de tout ?** Pour empêcher la triche. Si le client décidait des dégâts, un tricheur pourrait modifier son jeu pour tuer tout en un coup.

### Les choix techniques

| Élément | Choix | Pourquoi |
|---|---|---|
| **Moteur du jeu (client)** | Godot 4.7 | Gratuit, open source, déjà installé, bon rendu 3D. |
| **Serveur de jeu** | Godot 4.7 en mode « serveur » (sans affichage) | Le même projet Godot sert au client et au serveur : on écrit les règles une seule fois. Godot sait se lancer sans fenêtre (« headless »). |
| **Comptes, amis, discussion, guildes** | **Nakama** (open source, gratuit, à héberger soi-même) | Fournit tout de suite les comptes joueurs, la connexion, le chat, les amis, les groupes et le stockage, déjà prévus pour des milliers de joueurs. Évite de tout réinventer. |
| **Base de données** (sauvegarde des personnages) | PostgreSQL (gratuit), utilisé par Nakama | Fiable, très répandu. |
| **Langage de programmation** | GDScript (langage de Godot) | Simple à lire, très bien intégré à Godot. |
| **Communication réseau** | ENet (intégré à Godot) entre client et serveur de jeu | Rapide, adapté aux jeux en temps réel. |

### Comment on monte en charge (plusieurs serveurs)

Un seul serveur ne peut pas accueillir des milliers de joueurs dans le même monde. L'architecture prévoit dès le départ de **découper** le monde :

```
                    ┌───────────────────────────┐
   Joueurs  ─────►  │  Nakama (comptes, chat,   │
                    │  amis, guildes, sauvegarde)│
                    └─────────────┬─────────────┘
                                  │ « Va sur tel serveur »
            ┌─────────────────────┼─────────────────────┐
            ▼                     ▼                     ▼
   ┌────────────────┐   ┌────────────────┐   ┌────────────────┐
   │ Serveur Hub    │   │ Serveur        │   │ Serveur        │
   │ (copie 1, 2…)  │   │ Préhistoire    │   │ Donjon         │
   │                │   │ (copie 1, 2…)  │   │ (1 par groupe) │
   └────────────────┘   └────────────────┘   └────────────────┘
```

1. **Un serveur par zone :** le hub, chaque île et chaque donjon tournent sur des serveurs de jeu séparés. Quand un joueur prend un portail, il change de serveur (avec un écran de chargement, comme dans Guild Wars).
2. **Plusieurs copies d'une même zone :** si trop de joueurs sont au même endroit, on lance une **deuxième copie** de la zone (on parle de « canaux » ou « couches »). Les amis et les membres d'un groupe sont automatiquement placés dans la même copie.
3. **Un serveur par groupe pour les donjons :** chaque groupe a son donjon privé (une « instance »).
4. **Ajouter des machines :** pour accueillir plus de joueurs, on ajoute simplement des machines qui lancent plus de copies. Rien à réécrire.

**Objectif première version :** un serveur hub + un serveur Préhistoire + les donjons, pour **quelques dizaines de joueurs**, le tout sur une seule machine.

### Hébergement gratuit

| Étape | Où | Coût |
|---|---|---|
| Développement et tests | Le PC de Gaël (serveur lancé en local) | 0 € |
| Premiers tests avec des amis | **[Proposition]** Offre gratuite permanente d'**Oracle Cloud** (« Always Free » : une machine de 4 cœurs et 24 Go de mémoire, suffisante pour des dizaines de joueurs) | 0 € |
| Ouverture plus large | Hébergement payant à prévoir le moment venu (non nécessaire avant d'avoir beaucoup de joueurs) | À décider |

> **Point d'attention :** l'hébergement est le seul poste qui pourrait devenir payant quand le jeu grandira. Tout le reste reste gratuit.

### Organisation du dépôt GitHub

**[Proposition]**

```
SickWorld/
├── docs/            Documents de conception (ce fichier, crédits, etc.)
├── game/            Le projet Godot (client + serveur de jeu)
│   ├── assets/      Modèles 3D, textures, sons, animations
│   ├── scenes/      Les zones, personnages, interfaces
│   ├── scripts/     Le code
│   └── data/        Les données de jeu (compétences, quêtes, objets)
├── server/          Configuration de Nakama et de la base de données
└── tools/           Petits outils (import de modèles, etc.)
```

**Gros fichiers :** les modèles 3D et textures réalistes sont lourds. On utilisera **Git LFS** (gratuit jusqu'à une certaine limite sur GitHub) pour les stocker correctement. À mettre en place au moment d'ajouter les premières ressources.

### Données de jeu séparées du code

Les quêtes, compétences, objets et ennemis seront décrits dans des **fichiers de données** lisibles (un fichier par quête, par exemple), et non directement dans le code. Avantage : Gaël pourra **modifier un texte de quête, des dégâts ou une récompense sans toucher au code**.

---

## 11. Plan du prototype

Objectif : avancer **par petites étapes jouables**. Chaque étape produit quelque chose qu'on peut lancer et tester.

| Étape | Objectif | Résultat visible | Qui fait quoi |
|---|---|---|---|
| **0. Fondations** | Créer le projet Godot, l'organisation du dépôt, la méthode de travail. | Le projet s'ouvre dans Godot sur le PC de Gaël. | Claude prépare le projet ; Gaël l'ouvre et vérifie. |
| **1. Un personnage qui bouge** | Personnage MakeHuman animé avec Mixamo, caméra 3e personne, terrain de test. | On se promène sur une colline avec herbes et rochers (Poly Haven). | Gaël exporte un personnage MakeHuman et des animations Mixamo (avec un guide pas à pas) ; Claude programme le contrôle et la caméra. |
| **2. Le combat en solo** | Ciblage Tab, barre de 8 compétences, un ennemi (loup), points de vie, mort, réapparition. | On combat des loups. | Claude programme ; Gaël teste et règle les valeurs (dégâts, vitesse). |
| **3. Le multijoueur** | Serveur de jeu Godot : plusieurs joueurs se voient et combattent ensemble. | 2 ou 3 personnes jouent ensemble sur le PC de Gaël ou en réseau local. | Claude programme ; Gaël lance le serveur et teste avec un ami. |
| **4. Comptes et sauvegarde** | Installation de Nakama : créer un compte, se connecter, retrouver son personnage. | On se reconnecte et on retrouve son personnage là où on l'a laissé. | Claude prépare ; Gaël suit un guide d'installation. |
| **5. Tranche verticale de la Préhistoire** | Côte Gelée + début de la Steppe, chapitres 1 à 3 de la quête principale, 2 quêtes secondaires, 1 event (La Faille s'ouvre), 2 classes jouables (Rempart et Traqueur). | Une vraie petite partie de 30 à 60 minutes. | Travail commun : Gaël sur les décors, textes et choix ; Claude sur le code et l'intégration. |
| **6. Le hub minimal** | Le QG de la Vigie et une rue de Hikari Bay, portail vers la Préhistoire, changement de serveur. | On part du hub et on voyage vers l'île. | Travail commun. |
| **7. Test en ligne** | Serveur hébergé gratuitement (Oracle Cloud), test avec quelques dizaines de joueurs. | Des amis jouent depuis chez eux. | Claude prépare le déploiement ; Gaël crée le compte d'hébergement. |

**Ensuite :** compléter la Préhistoire (zones 3 à 5, donjon), ajouter les 2 autres classes, puis attaquer la deuxième île.

> **Conseil :** la tentation, dans un MMO, est de tout vouloir en même temps. La règle d'or : **ne pas passer à l'étape suivante tant que l'étape en cours n'est pas amusante à jouer**.

---

## 12. Questions ouvertes pour Gaël

Les réponses à ces questions permettront de compléter le document. Pas besoin de tout trancher maintenant : les questions **en gras** sont les plus utiles pour démarrer le prototype.

### Univers et scénario

1. **Le nom de l'organisation secrète : « la Vigie » te convient-il, ou as-tu une autre idée ?**
2. **Le nom de la ville hub : « Hikari Bay » te convient-il ? Est-ce une ville imaginaire ou une vraie ville (Tokyo, Singapour) ?**
3. Les ennemis humains derrière les fractures, « les Effaceurs » : l'idée te plaît-elle ? Préfères-tu une cause plus mystérieuse (une entité, une maladie du temps) ?
4. Le joueur doit-il parfois faire des **choix moraux** qui changent un peu l'histoire (comme la louve Grise), ou préfères-tu une histoire linéaire ?
5. La liste des époques (section 2) te convient-elle ? Y a-t-il une époque que tu veux absolument, ou que tu veux éviter ?
6. Ton : plutôt **sérieux**, plutôt **avec de l'humour**, ou un mélange (comme The Secret World) ?

### Préhistoire

7. **Les deux « moments clés » (naissance de l'art et amitié homme-loup) te plaisent-ils ?**
8. Le boss final « l'Ours Sans Mémoire » te convient-il ?
9. Faut-il un mammouth comme monture (très rare), ou le garder comme animal à protéger uniquement ?

### Gameplay

10. **Les 4 classes (Rempart, Lame, Traqueur, Tisseur) te conviennent-elles ? Leurs noms ?**
11. La barre de 8 compétences (5 de classe, 2 d'époque, 1 ultime) te semble-t-elle bien ?
12. Veux-tu une **roulade d'esquive** en plus du ciblage classique, ou rester 100 % façon WoW ?
13. Veux-tu du **combat entre joueurs** (JcJ) ? Si oui : seulement dans l'arène, ou aussi dans le monde ?
14. Veux-tu un système d'**artisanat** (fabriquer ses objets) dès le début, ou plus tard ?
15. Un joueur pourra-t-il changer de classe, ou avoir une **classe secondaire** (comme dans Guild Wars) ?

### Technique et organisation

16. **Combien de temps par semaine comptes-tu consacrer au projet ?** (Cela aide à planifier les étapes.)
17. **Es-tu d'accord pour la répartition proposée** (toi sur les décors, textes et choix ; Claude sur le code) ?
18. Le jeu sera-t-il en **français uniquement**, ou aussi en anglais (dès le début ou plus tard) ?
19. Modèle économique envisagé : gratuit, achat unique, boutique cosmétique ? (Pas urgent.)
20. As-tu déjà des **amis prêts à tester** le multijoueur ?

---

## 13. Glossaire

| Mot | Signification |
|---|---|
| **MMORPG** | Jeu de rôle en ligne massivement multijoueur : des centaines ou milliers de joueurs dans le même monde. |
| **Hub** | Lieu central et sûr où les joueurs se retrouvent entre deux aventures. |
| **Instance** | Copie privée d'une zone, réservée à un groupe (ex. : un donjon). |
| **Donjon** | Zone difficile, faite pour un groupe de joueurs, avec un boss à la fin. |
| **Boss** | Ennemi principal, plus fort que les autres. |
| **Tank** | Joueur qui encaisse les coups et attire les ennemis sur lui. |
| **Soigneur / soutien** | Joueur qui soigne et protège les autres. |
| **Dégâts (DPS)** | Joueur dont le rôle est d'abattre les ennemis. |
| **Aggro / menace** | Mesure qui décide quel joueur un ennemi attaque. |
| **Temps de recharge** | Délai avant de pouvoir réutiliser une compétence. |
| **Event** | Événement public qui se déclenche dans le monde et auquel tous les joueurs proches participent. |
| **Serveur headless** | Version du jeu qui tourne sans image ni son, juste pour faire fonctionner les règles du monde. |
| **Nakama** | Logiciel gratuit qui gère les comptes, le chat, les amis et les sauvegardes d'un jeu en ligne. |
| **Git LFS** | Extension de Git pour stocker les gros fichiers (modèles 3D, textures). |
| **Tranche verticale** | Petit morceau du jeu, mais complet et fini, pour vérifier que tout fonctionne ensemble. |
