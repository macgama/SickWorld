# Jouer à plusieurs

Depuis l'étape 3, le jeu s'ouvre sur un **menu** :

- **Jouer seul** : comme avant, tout se passe sur ton PC.
- **Héberger une partie** : ton PC devient le serveur ET tu joues dessus. Tes amis te rejoignent.
- **Rejoindre** : tu te connectes à la partie de quelqu'un d'autre en tapant son adresse.

Il faut d'abord avoir créé son personnage (voir [Créer son personnage](creer-son-personnage.md)). Son nom s'affiche au-dessus de lui chez les autres joueurs, qui voient aussi son apparence et son arme.

## 1. Essayer tout seul avec deux fenêtres (le plus simple)

1. Dans Godot, menu **Débogage > Personnaliser les instances lancées…** (*Debug > Customize Run Instances…*).
2. Coche **Activer plusieurs instances** et mets **2**. Valide.
3. Appuie sur **F5** : deux fenêtres du jeu s'ouvrent.
4. Dans la première, clique sur **Héberger une partie**. Windows peut demander d'autoriser Godot dans le pare-feu : clique sur **Autoriser**.
5. Dans la seconde, laisse l'adresse `127.0.0.1` (qui veut dire « ce PC ») et clique sur **Rejoindre**.
6. Tu vois tes deux personnages (ils se ressemblent, car les deux fenêtres lisent le même personnage enregistré sur ton PC). Attaquez ensemble un loup : il s'en prend à celui qui lui fait le plus de dégâts.

Pour revenir à une seule fenêtre, remets **1** dans le même menu.

## 2. Jouer avec quelqu'un chez toi (même box Internet)

1. Sur ton PC, trouve ton adresse : touche Windows, tape `cmd`, Entrée, puis tape `ipconfig` et Entrée. Note la ligne **Adresse IPv4** (par exemple `192.168.1.20`).
2. Sur ton PC : **Héberger une partie**.
3. Sur l'autre PC (qui doit avoir Godot et le projet, en attendant qu'on fabrique un vrai fichier d'installation) : tape ton adresse et clique sur **Rejoindre**.

## 3. Jouer avec des amis par Internet (serveur officiel)

Le serveur officiel tourne chez Oracle Cloud (gratuit), allumé en permanence : voir [Mettre le serveur en ligne](serveur-en-ligne.md). Une fois installé, chacun clique simplement sur **Multijoueur > Rejoindre le serveur officiel**.

Pour vérifier qu'il répond sans ouvrir le jeu (dans le dossier du projet) :
`godot --headless --path game -s res://tests/test_en_ligne.gd -- --officiel --nom=Testeur`

## Ce qui se passe « sous le capot »

- Le **serveur** décide de tout ce qui compte : la vie, les dégâts, les loups, les temps de recharge. Quand tu appuies sur une touche de compétence, ton jeu envoie une **demande** au serveur, qui vérifie la portée, l'Élan, la recharge… avant d'appliquer l'effet. Un tricheur ne peut donc pas frapper un loup à 50 mètres.
- Chaque joueur envoie sa **position** 20 fois par seconde. Pour l'instant le serveur la croit sur parole ; on ajoutera une vérification de la vitesse avant les tests publics.
- Un **serveur dédié** (sans fenêtre, sans joueur) peut aussi tourner en arrière-plan : c'est ce qu'on installera sur Oracle Cloud. Commande : `godot --headless --path game -- --serveur --port=7777`.
