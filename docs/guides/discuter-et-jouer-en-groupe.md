# Discuter et jouer en groupe

Comme dans World of Warcraft : une fenêtre de discussion en bas à gauche, des groupes de 5 joueurs avec leurs barres de vie, le butin partagé, et des donjons où chaque groupe a sa propre copie.

## La discussion (chat)

- **Entrée** : ouvrir la zone de texte. **Entrée** à nouveau : envoyer. **Échap** : annuler.
- Taper **/** ouvre aussi la discussion, directement sur une commande.
- Clic sur le nom de quelqu'un dans la discussion : lui chuchoter un message.

| Canal | Commande | Qui le reçoit | Couleur |
|---|---|---|---|
| Dire | `/d` | les joueurs à moins de 40 m. Une **bulle** apparaît au-dessus de ta tête | blanc |
| Zone | `/z` | les joueurs du même quartier (Place Hikari, QG de la Vigie…) | saumon |
| Général | `/1` | tout le serveur | doré |
| Groupe | `/gr` | ton groupe | bleu |
| Guilde | `/gu` | ta guilde (fondée chez le registraire de la Maison des guildes) | vert |
| Chuchoter | `/w Nom message` | une seule personne ; `/r message` répond au dernier qui t'a chuchoté | rose |

Le canal reste choisi pour les messages suivants (tape `/gr` une fois, puis écris normalement). `/aide` affiche toutes les commandes.

Le serveur vérifie tout : 200 lettres au plus par message, et pas plus de 6 messages en 8 secondes (anti-spam).

## Les groupes

- **Inviter** : clique sur un autre joueur pour le cibler, puis sur **Inviter dans le groupe** (sous son cadre en haut). Ou tape `/inviter Nom`.
- L'invité voit **Accepter / Refuser** en haut de l'écran.
- Jusqu'à **5 joueurs**. Le chef a une étoile ★. Seul le chef invite.
- Les **cadres du groupe** sont à gauche de l'écran : nom, classe, vie de chacun.
  - **Clic** sur un cadre : cibler ce membre (pratique pour le soigner avec le Tisseur).
  - **Clic droit** : chuchoter, nommer chef, exclure (ces deux derniers seulement pour le chef).
- **Quitter le groupe** : bouton sous les cadres, ou `/quitter`. `/chef Nom` et `/exclure Nom` existent aussi.
- Un membre déconnecté reste dans le groupe 5 minutes (son cadre devient gris).

**Butin partagé** : quand un ennemi meurt, chaque membre du groupe à moins de 60 m reçoit **son propre** sac de butin, même s'il n'a pas frappé. Personne ne vole le butin des autres.

## Entrer en donjon avec son groupe

1. Formez votre groupe en ville (Hikari Bay).
2. Le chef appuie sur **K** (ou le bouton **Donjons**) et choisit le donjon, pour l'instant **la Grande Grotte**.
3. Tout le groupe voit un fondu au noir et arrive ensemble dans le donjon.

Chaque groupe a **sa propre copie** du donjon : vous ne croisez pas les autres groupes. Le donjon suit l'avancée du **chef** dans l'histoire.

Pour revenir : bouton **Quitter le donjon** sous les cadres du groupe (ou ressortir par l'entrée de la grotte). On revient au QG de la Vigie, toujours en groupe.

Les donjons se font en multijoueur (Héberger ou Rejoindre). En solo, on y va comme avant, par le portail et l'histoire de l'île.

## Essayer tout seul avec deux fenêtres

1. Dans Godot : **Débogage > Personnaliser les instances lancées…**, coche **Activer plusieurs instances**, mets **2**.
2. **F5**. Fenêtre 1 : **Multijoueur > Héberger une partie**. Fenêtre 2 : **Rejoindre** avec `127.0.0.1` (attends quelques secondes que le serveur démarre).
3. Dans la fenêtre 1, appuie sur Entrée et écris « bonjour » : la bulle apparaît dans les deux fenêtres.
4. Clique sur l'autre personnage, puis sur **Inviter dans le groupe**, et accepte dans l'autre fenêtre.
5. Appuie sur **K** et entre dans la Grande Grotte : les deux personnages y arrivent ensemble.

Les deux fenêtres utilisent le même personnage enregistré : le serveur ne laisse jamais deux joueurs porter le même nom, donc le second s'appelle « Nom 2 ».

## Comment ça marche (pour plus tard)

- La discussion et les groupes sont gérés par le **serveur de jeu** (fichier `scripts/autoload/social.gd`). Les joueurs envoient des demandes, le serveur décide.
- Un donjon est un **deuxième serveur de jeu**, sans fenêtre, que le serveur de la ville lance lui-même sur le port suivant (7778, 7779… jusqu'à 7797, donc 20 groupes en même temps). Il s'éteint tout seul 30 secondes après le départ du groupe. C'est aussi ce qui permettra plus tard de répartir les joueurs sur plusieurs machines.
- « Héberger » lance maintenant ce même genre de serveur en arrière-plan : l'hôte peut donc partir en donjon sans couper la ville pour les autres.
- Les donjons proposés et la taille des groupes se règlent dans `game/data/donjons.json`.
- Limites actuelles : dans un donjon, le canal Général et les chuchotements ne touchent que les joueurs du donjon (pas ceux restés en ville). Les guildes restent enregistrées sur ton PC (inviter des membres dans une guilde viendra plus tard, avec Nakama).
- Tests : `game/tests/test_groupe_local.gd` (sans réseau) et `game/tests/test_social.gd` (deux joueurs, voir l'en-tête du fichier).
