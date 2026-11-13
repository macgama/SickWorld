# Crédits

## Personnages

- **Modèles humains : MakeHuman Community 1.x** (http://www.makehumancommunity.org/).
  Les personnages exportés de MakeHuman, avec ses assets système (corps, peaux,
  yeux, sourcils, cils, cheveux, vêtements, chaussures), sont sous licence **CC0**
  (domaine public). Utilisation libre, y compris commerciale.
  Fichiers : `game/assets/personnages/homme/` et `game/assets/personnages/femme/`.
  Script de fabrication : `tools/personnages/creer_personnage.py`.
- **Squelette et animations : Mixamo** (https://www.mixamo.com), service d'Adobe.
  Le squelette (auto-rigging) et les animations sont utilisables gratuitement dans
  des jeux, y compris commerciaux, selon les conditions d'utilisation d'Adobe/Mixamo.
  Les fichiers d'animation Mixamo ne doivent pas être redistribués seuls (hors du jeu).
  Animations utilisées : Breathing Idle, Running, Unarmed Walk Back, Left Strafe,
  Right Strafe, Jump (Jump In Place), Falling Idle, Sprinting Forward Roll,
  Punching, Hit Reaction, Dying.

## Hub Hikari Bay

- **Textures et modèles 3D : Poly Haven** (https://polyhaven.com), licence **CC0**
  (domaine public). Fichiers : `game/assets/hub/textures/` et `game/assets/hub/modeles/`
  (un dossier par ressource, au nom de son identifiant Poly Haven).
  Script de téléchargement : `tools/hub/telecharger_polyhaven.ps1`.
- **Police des enseignes : Noto Sans JP** (Google / Adobe), licence **SIL Open Font
  License 1.1** (texte dans `game/assets/polices/OFL.txt`). Version réduite aux
  caractères utiles : `game/assets/polices/NotoSansJP-Bold-hub.ttf`
  (script : `tools/hub/police_enseignes.py`).

## Île de la Préhistoire

- **Textures, modèles 3D et ciels (HDRI) : Poly Haven** (https://polyhaven.com),
  licence **CC0** (domaine public). Fichiers : `game/assets/prehistoire/textures/`,
  `game/assets/prehistoire/modeles/` et `game/assets/prehistoire/ciel/`
  (un dossier ou fichier par ressource, au nom de son identifiant Poly Haven).
  Script de téléchargement : `tools/prehistoire/telecharger_polyhaven.ps1`.
- **Steppe des Mammouths** (même source, CC0) : textures `withered_grass`,
  `brown_mud_02`, `brown_leather` ; modèles `grass_medium_02`, `grass_bermuda_01`,
  `wild_rooibos_bush`, `searsia_lucida`.

## Son et musique

Tous les sons sont dans `game/audio/`. Ils ont été convertis en Ogg Vorbis,
coupés et mis au même volume par `tools/audio/preparer_sons.py` (la liste exacte des
fichiers d'origine est dans ce script).

- **Oculus Audio Pack 01** — bruitages (pas sur 6 surfaces, coups, élans, voix des
  agents, pluie en ville, forêt, vent, train, sons d'interface, jingles de quête).
  Crédit obligatoire, licence **CC BY 4.0** :
  > "Oculus Audio Pack 01" by Oculus VR, LLC (https://developers.meta.com/vr/downloads/package/oculus-audio-pack-1/),
  > licensed under CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/). Files renamed to the UCS
  > naming convention; OGG previews transcoded from the original WAVs. Sons recoupés et normalisés pour SickWorld.

  Source utilisée : dépôt https://github.com/facebookincubator/Meta-open-sound (`corpora/oculus-audio-pack`).
- **Musiques : HoliznaCC0** (https://opengameart.org/users/holizna), licence **CC0**.
  Albums « Title Screens », « Lo-Fi And Chill », « Chill Beats », « Relaxing Instrumentals »,
  « Quiet Village » et « Caves » : `musique/menu_*` (Beginning 6, Beginning 4),
  `musique/hub_*` (City In The Rearview, Night Driving, Foggy Headed, Ramen, Pretty Little Lies),
  `musique/prehistoire_*` (Quiet Village 1 à 4), `musique/grotte_*` (Cave 1, 4, 5).
  Copies prises dans https://github.com/seyedpouramir/alvana-audio (CC0).
- **Ambiances et bruitages Freesound en CC0** (domaine public), réunis par
  https://github.com/Asion001/mangarr-sounds :
  ville la nuit (vonfleisch, n° 270881), café/foule (priesjensen, 482990), vagues (Noted451, 531015),
  vent arctique (cobratronik, 117136), vent d'hiver (klangfabrik, 117513), vent à la fenêtre
  (audible-edge, 69512 — ralenti pour la grotte), rivière (jackthemurray, 433589), feu de camp
  (moxobna, 62487), tonnerre (netaj 193170, lennyboy 244053), klaxons (15HPanska_Ruttner_Jan 461679,
  keweldog 182474), oiseaux (swiftoid 182507 et 182502), chouette (Breviceps 465697),
  impact de flèche (205938). Pages : https://freesound.org/s/<numéro>/
- **Kenney** (https://kenney.nl), licence **CC0** : UI Audio (clics, survols ;
  dépôt https://github.com/Calinou/kenney-ui-audio), Impact Sounds et RPG Audio (coup de lame, taille).
- **Cris de bêtes provisoires** : sons « creature » CC0 d'OpenGameArt (bibliothèque alvana-audio),
  plus aboiements Oculus ralentis pour les loups.
- **Hurlements de loups lointains et gouttes d'eau de la grotte** : fabriqués par synthèse
  dans `tools/audio/preparer_sons.py` (aucune licence à respecter).

## Moteur

- **Godot Engine 4.7** (https://godotengine.org), licence MIT.
