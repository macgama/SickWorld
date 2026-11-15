# L'Arène JcJ (duels et 2 contre 2)

L'**Arène de la baie**, au sud-est de Hikari Bay (au bout du front de mer, sur la plateforme posée sur l'eau), est ouverte : on peut y affronter d'autres agents, en **duel** (1 contre 1) ou en **escarmouche** (2 contre 2).

On ne risque rien : à la fin de chaque combat, tout le monde est soigné, **sans** la pénalité de désynchronisation, et ramené là où il était.

## Trouver un adversaire

- **Défier un joueur précis** : clique sur lui pour le cibler, puis sur **Défier en duel** (sous son cadre, en haut). Ou tape `/duel Nom` dans la discussion. Il voit **Accepter / Refuser** (30 secondes pour répondre).
  - Si tu es en **groupe de 2** et lui aussi (dans un autre groupe), le défi devient un **2 contre 2** : ton groupe contre le sien.
- **La file d'attente** : touche **H** (ou `/arene`, ou **F** devant la borne d'inscription à l'entrée de l'Arène). Choisis *Duel (1 contre 1)* ou *Escarmouche (2 contre 2)*. Dès qu'une autre équipe attend dans la même file, le combat commence.
  - Pour le 2 contre 2, forme d'abord un groupe de 2 (`/inviter Nom`) : tout le groupe s'inscrit d'un coup.
- Une seule rencontre à la fois dans l'Arène : les suivantes attendent leur tour (un défi accepté passe avant la file).

## Le combat

1. Les combattants sont amenés sur le terrain, face à face, soignés et figés.
2. Compte à rebours **3… 2… 1…** puis **COMBAT !**
3. Une équipe gagne quand tous ses adversaires sont **désynchronisés**, ou **sortis du terrain** (fuir par l'entrée = abandon), ou **déconnectés**.
4. Au bout de **3 minutes**, l'équipe qui a gardé le plus de vie (en %) gagne. À égalité : match nul.
5. **VICTOIRE**, **DÉFAITE** ou **ÉGALITÉ** s'affiche, puis chacun retourne à sa place.

Le bandeau en haut de l'écran montre qui se bat et le temps restant ; le **grand écran** au-dessus des tribunes aussi. DJ Volt annonce chaque combat et chaque vainqueur à toute la ville.

Les **spectateurs** ne peuvent ni frapper ni soigner les combattants, et les combattants ne peuvent pas les toucher. En 2 contre 2, on peut soigner et protéger son coéquipier comme d'habitude. Les loups du Traqueur repartent au début et à la fin du combat.

## Le classement

La fenêtre de l'Arène (H) montre les 10 meilleurs agents du serveur : victoires, défaites, et le détail duels / 2 contre 2. Il est gardé par le serveur (fichier `arene.cfg` dans ses données).

## Régler l'Arène sans coder

Tout est dans `game/data/arene.json` :

| Réglage | Ce qu'il change | Par défaut |
|---|---|---|
| `compte_a_rebours` | durée du compte à rebours (secondes) | 5 |
| `duree_max_combat` | durée maximale d'un combat, avant la victoire aux points | 180 |
| `duree_resultat` | temps d'affichage du résultat avant le retour | 4 |
| `duree_defi` | temps pour répondre à un défi | 30 |
| `ecart_depart` | distance entre le centre et chaque équipe au départ (mètres) | 9 |
| `marge_sortie` | au-delà du bord du terrain + cette marge, on abandonne (mètres) | 1.5 |

## Pour tester

- Sans réseau (rapide) : `godot --headless --path game -s res://tests/test_arene.gd`
- Un vrai duel entre deux programmes (deux terminaux) :
  - `godot --headless --path game -s res://tests/test_arene_reseau.gd -- --role=chef --nom=Alice --port=7810`
  - `godot --headless --path game -s res://tests/test_arene_reseau.gd -- --role=membre --nom=Bob --port=7810`

## Pas encore fait

- Récompenses (titres, cosmétiques) et cote de classement à la WoW : à relier à la progression du personnage.
- Classement commun à plusieurs serveurs (via Nakama).
- Plusieurs arènes en même temps (instances, comme les donjons).
