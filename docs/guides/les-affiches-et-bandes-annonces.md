# Les affiches et les bandes-annonces

Depuis le 18/11/2026, chaque grande activité a son **affiche** : une fiche illustrée qui
donne envie d'y aller, avec une **bande-annonce** d'environ 25 secondes.

![Affiche de la Chine des Han](../images/affiche-chine.jpg)

## Où les voir

| Où | Quand |
|---|---|
| QG de la Vigie, salle des portails | en entrant dans un portail : l'affiche de l'époque, puis « Voyager » |
| QG, mur est de la salle des portails | le **mur des époques** fait défiler les îles ; **F** devant ouvre l'affiche montrée |
| Arène (borne d'inscription) | la première fois ; ensuite la borne ouvre directement l'inscription |
| Arène, mur extérieur près de l'entrée | un écran géant ; **F** devant ouvre l'affiche |
| Maison des guildes (façade, liège « Recrutement », tableau des contrats) | l'affiche des guildes et le tableau de recrutement |
| Fenêtre Donjons (touche K) | bouton « ▶ Présentation » à côté de chaque donjon |

## Ce que montre une affiche

- une grande image du jeu qui bouge doucement, le titre, l'époque et une phrase d'accroche ;
- **Ta prochaine étape** : le chapitre où tu en es (ou « Nouvelle époque », « Histoire terminée ») et ton niveau ;
- **L'aventure** (zones, donjon, boss) et **À gagner** (panoplies de l'Arsenal, montures… lues dans les données du jeu) ;
- les boutons : **Bande-annonce (B)**, **Plus tard (Échap)** et le gros bouton (**Voyager**, **S'inscrire**… avec **Entrée**).

Pendant la bande-annonce : **Espace** ou **Échap** pour passer, **Entrée** à la fin pour y aller.

## Changer les textes et les images

Tout est dans `game/data/affiches.json` :

- `titre`, `epoque`, `accroche`, `points`, `recompenses`, `bouton` : les textes ;
- `images` : les grandes images (dans `game/images/affiches/`) ; `source` dit quelle vue de quel script de capture l'a faite ;
- `bande_annonce` : les plans. `image` = numéro dans `images` (0 = la première), `duree` en secondes,
  `de` / `a` = `[x, y, zoom]` : le cadrage au début et à la fin du plan, `titre` / `sous_titre` / `texte`.

Pour refaire toutes les images (après une passe graphique, par exemple) :

```
godot --path game -s res://tests/capture_affiches.gd
```

(ou seulement certaines zones : `-- rheingau,rhin`). Le script lance chaque `tests/capture_<zone>.gd` et range les images.
