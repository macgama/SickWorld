# Ouvrir et tester le projet dans Godot

Ce guide explique comment lancer le prototype sur ton PC. Compte 5 minutes la première fois.

## 1. Récupérer la dernière version avec GitHub Desktop

1. Ouvre **GitHub Desktop**.
2. En haut à gauche, vérifie que le dépôt sélectionné est **SickWorld**.
   - S'il n'apparaît pas : *File > Clone repository…*, onglet *GitHub.com*, choisis `macgama/SickWorld`, puis *Clone*.
3. Clique sur **Fetch origin** (en haut à droite).
4. Clique sur **Current branch** (en haut au milieu) et choisis la branche indiquée dans la demande de fusion (par exemple `prototype/etape-1-personnage`).
   - Une fois la demande de fusion acceptée sur GitHub, il suffira de rester sur la branche `main` et de cliquer sur **Pull origin**.

## 2. Ouvrir le projet dans Godot (une seule fois)

1. Lance **Godot 4.7**.
2. Dans le gestionnaire de projets, clique sur **Importer**.
3. Va dans le dossier du dépôt SickWorld (par défaut `Documents\GitHub\SickWorld`), ouvre le sous-dossier **game** et choisis le fichier **project.godot**.
4. Clique sur **Importer et éditer**. La première ouverture prend quelques secondes.

Les fois suivantes, le projet SickWorld apparaît directement dans la liste : double-clique dessus.

## 3. Jouer

- Appuie sur **F5** (ou le bouton ▶ en haut à droite). Une fenêtre de jeu s'ouvre.
- Le terrain est fabriqué au lancement : il peut y avoir 2 à 5 secondes d'écran gris au démarrage, c'est normal.
- Pour quitter : ferme la fenêtre ou appuie sur **F8** dans Godot.

### Les contrôles

| Touche | Action |
|---|---|
| **Z / S** | Avancer / reculer |
| **Q / D** | Tourner à gauche / à droite |
| **A / E** | Pas de côté |
| **Clic droit maintenu** + souris | Orienter le personnage et la caméra (Q/D font alors des pas de côté) |
| **Clic gauche maintenu** + souris | Tourner la caméra autour du personnage |
| **Clic gauche + clic droit** | Avancer |
| **Molette** | Zoomer / dézoomer |
| **Espace** | Sauter |
| **Maj** | Roulade d'esquive (consomme l'endurance, la barre jaune en bas) |
| **F1** | Cacher / afficher l'aide |

Sur un clavier anglais, ce sont W A S D au lieu de Z Q S D : le jeu s'adapte tout seul.

## 4. Régler les valeurs toi-même (sans coder)

Tu peux changer les vitesses, le saut, la caméra… directement dans Godot :

1. Dans le panneau **Scène** (à gauche), ouvre `scenes/monde/colline_de_test.tscn` (double-clic dans le panneau *Système de fichiers* en bas à gauche).
2. Clique sur le nœud **Joueur**.
3. Dans l'**Inspecteur** (à droite), tu vois les groupes *Déplacement*, *Esquive*… Passe la souris sur un nom pour lire son explication.
4. Change une valeur, puis **F5** pour essayer.

De la même façon :
- le nœud **CameraRig** (dans Joueur, clique sur l'icône « film » pour afficher ses enfants, ou ouvre `scenes/joueur/joueur.tscn`) règle la distance, la sensibilité de la souris…
- le nœud **CollineDeTest** (tout en haut) règle la colline : change la **Graine** pour obtenir un autre paysage, la quantité d'herbe et de rochers. Le bouton **Régénérer le terrain** met l'aperçu à jour.

Si une valeur te plaît, dis-le-moi (ou enregistre avec **Ctrl+S** et envoie la modification avec GitHub Desktop : *Commit* puis *Push origin*).

## 5. Si quelque chose ne va pas

- **Le jeu rame :** sur le nœud *CollineDeTest*, baisse *Nombre Brins Herbe* (par exemple à 100000).
- **Un message rouge apparaît dans le panneau « Sortie » en bas :** fais une capture d'écran et envoie-la-moi.
