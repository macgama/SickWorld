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

## Des combats équilibrés, quel que soit le niveau

Pendant un combat d'Arène, **tout le monde se bat comme s'il était niveau 20**, avec le **même équipement standard**. L'équipement porté, les talents et le repas du Chef Goro ne comptent pas : un agent niveau 1 qui vient d'arriver a exactement la même vie et les mêmes dégâts qu'un agent niveau 20 couvert d'objets historiques. Seuls comptent **la classe** et **la façon de jouer**.

À la fin du combat, chacun retrouve ses vraies statistiques. Le bandeau du compte à rebours le rappelle : *« Combat équilibré : niveau 20 et même équipement pour tous »*.

## Les récompenses

Chaque combat qui compte rapporte :

- des **Médailles de l'arène** : 3 pour une victoire, 2 pour une égalité, 1 pour une défaite (30 au plus par jour). Elles s'échangent auprès de la championne **Akane « l'Éclair » Shiba**, au bord du terrain (parle-lui, sa boutique s'ouvre) : Écharpe des supporters, Pantalon de combat de la baie, Dague d'entraînement, éclats de fracture, insignes de la Vigie ;
- de la **cote** : tout le monde commence à **1 500**. Une victoire la fait monter, une défaite la fait baisser. Battre plus fort que soi rapporte beaucoup, battre plus faible rapporte peu (calcul *Elo*, comme aux échecs). En 2 contre 2, on compare la cote moyenne des deux équipes. Les 10 premiers combats comptent davantage, pour trouver vite sa place.

À la fin du combat, sous **VICTOIRE !** ou **DÉFAITE**, s'affichent la nouvelle cote (par exemple *Cote 1 524 (+24)*), les médailles et les objets gagnés.

### Les paliers : objets et titres

| Palier | Objet (donné une seule fois, dans les sacs) | Titre |
|---|---|---|
| 1 victoire | — | Baptême de l'arène |
| 25 victoires | — | Habitué de l'arène |
| 100 victoires | — | Vétéran de l'arène |
| Cote 1 600 | Bandeau de l'Espoir (tête, raffiné) | Espoir de la baie |
| Cote 1 750 | Veste de combat de la baie (torse, rare) | Combattant de la baie |
| Cote 1 900 | Gants de l'Étoile (mains, épique) | Étoile de l'arène |
| Cote 2 100 | Lame de la Légende (arme, historique) | Légende de la baie |
| Top 10 du classement | Insigne des Dix (bijou, épique) | Grand nom de l'arène |
| 1re place du classement | Trophée de la baie (relique, historique) | Champion de la baie |

C'est la **meilleure cote atteinte** qui compte : un titre ou un objet gagné ne se perd jamais. Les titres se choisissent dans la fenêtre **Talents et titres** (touche N). Si les sacs sont pleins, l'objet attend la fin du combat suivant.

### Le classement

La fenêtre de l'Arène (H) montre **ta cote**, ton rang, tes médailles du jour et la **prochaine récompense**, puis les 10 meilleurs agents du serveur, **triés par cote**. Il faut **10 combats** pour avoir un rang (avant, on apparaît en bas de la liste avec un tiret). Le classement est gardé par le serveur (fichier `arene.cfg` dans ses données).

### Contre les combats arrangés

Au-delà de **3 combats par jour contre le même adversaire** (ou la même équipe), les combats suivants sont *amicaux* : ni cote, ni victoire, ni médailles. On peut toujours s'entraîner autant qu'on veut.

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
| `equilibrage` → `actif` | `false` pour que chacun garde ses vraies statistiques | true |
| `equilibrage` → `niveau_reference` | le niveau de tout le monde pendant un combat | 20 |
| `equilibrage` → `equipement_standard` | les statistiques de l'équipement standard (vie, % de dégâts, de réduction, de critique) | 150 PV, +25 %, 3 %, 5 % |
| `recompenses` → `cote_depart` | la cote de départ | 1500 |
| `recompenses` → `k` / `k_debutant` | combien de points de cote sont en jeu par combat (après / pendant les 10 premiers) | 32 / 48 |
| `recompenses` → `combats_pour_etre_classe` | combats à faire pour avoir un rang | 10 |
| `recompenses` → `combats_par_jour_meme_adversaire` | combats qui comptent par jour contre le même adversaire | 3 |
| `recompenses` → `medailles` | médailles par victoire / égalité / défaite, et plafond par jour | 3 / 2 / 1, 30 |
| `recompenses` → `paliers` | les objets donnés à une cote (`cote`) ou une place (`rang`) | voir le tableau plus haut |

Les titres sont dans `game/data/progression.json` (conditions `arene_victoires`, `arene_cote`, `arene_rang`), les objets dans `game/data/objets.json`, et les échanges d'Akane dans `game/data/artisanat.json` (artisan `arene`).

## Pour tester

- Sans réseau (rapide) : `godot --headless --path game -s res://tests/test_arene.gd`
- Récompenses et équilibrage : `godot --headless --path game -s res://tests/test_arene_recompenses.gd`
- Un vrai duel entre deux programmes (deux terminaux) :
  - `godot --headless --path game -s res://tests/test_arene_reseau.gd -- --role=chef --nom=Alice --port=7810`
  - `godot --headless --path game -s res://tests/test_arene_reseau.gd -- --role=membre --nom=Bob --port=7810`

## Pas encore fait

- Des saisons (remise à zéro de la cote tous les 3 mois, avec des récompenses de fin de saison).
- Des talents choisis spécialement pour l'Arène (pour l'instant, les talents sont ignorés pendant un combat).
- Classement commun à plusieurs serveurs (via Nakama).
- Plusieurs arènes en même temps (instances, comme les donjons).
