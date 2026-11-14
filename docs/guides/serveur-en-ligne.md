# Mettre le serveur SickWorld en ligne (Oracle Cloud, gratuit)

Ce guide allume **le serveur officiel de SickWorld** sur une machine gratuite d'Oracle Cloud, allumée 24 h/24. Ensuite, n'importe qui peut cliquer sur **Multijoueur > Rejoindre le serveur officiel** depuis son PC, et les comptes en ligne fonctionnent partout.

Ce que tu as à faire : créer le compte Oracle (partie A), créer la machine en collant un script (partie B), ouvrir trois « portes » (partie C), puis m'envoyer l'adresse IP (partie D). **Tout le reste s'installe tout seul.** Compte environ 30 minutes, plus le temps qu'Oracle valide le compte.

> **Le coût : 0 €.** Oracle offre pour toujours (« Always Free ») une machine de 4 processeurs et 24 Go de mémoire. Ils demandent une **carte bancaire uniquement pour vérifier ton identité** : ils font une petite autorisation (environ 1 €) qui est annulée tout de suite. Tant que ton compte reste en « Free Tier » (offre gratuite), **Oracle ne peut rien te facturer** : pour payer quoi que ce soit, il faudrait que tu passes toi-même ton compte en payant (« Upgrade »). Ne clique jamais sur « Upgrade » sans m'en parler.

---

## A. Créer le compte Oracle Cloud (15 min)

1. Va sur **https://www.oracle.com/fr/cloud/free/** et clique sur **Commencer gratuitement** (*Start for free*).
2. Remplis : **Pays** = France, ton prénom, ton nom, ton adresse e-mail. Oracle t'envoie un e-mail : clique sur le lien **Vérifier l'e-mail**.
3. Choisis un **mot de passe** (garde-le pour toi, je n'en ai pas besoin).
4. **Nom du compte cloud** (*Cloud Account Name*) : ce que tu veux, par exemple `sickworld` suivi de quelques chiffres. Note-le : il sert à se connecter.
5. **Région d'origine** (*Home Region*) : choisis **France Central (Paris)**. ⚠️ Ce choix est **définitif** : c'est là que la machine sera installée (Paris = rapide pour des joueurs en France).
6. Adresse postale et numéro de téléphone.
7. **Carte bancaire** : saisis une vraie carte (les cartes prépayées ou « virtuelles » sont souvent refusées). Rappel : aucune somme n'est prélevée.
8. Accepte les conditions et clique sur **Démarrer ma version d'évaluation gratuite** (*Start my free trial*).
9. Attends l'e-mail **« Your account is ready »** (quelques minutes, parfois jusqu'à une heure). Tu peux alors te connecter sur **https://cloud.oracle.com** avec le nom du compte cloud, ton e-mail et ton mot de passe.

> Les 30 premiers jours, Oracle ajoute un crédit d'essai de 300 $ : on ne s'en sert pas. À la fin de l'essai, la machine gratuite continue de tourner.

---

## B. Créer la machine du serveur (10 min)

1. Une fois connecté, clique sur le menu **☰** (en haut à gauche) > **Compute** (*Calcul*) > **Instances**, puis sur le bouton **Create instance** (*Créer une instance*).
2. **Name** (*Nom*) : `sickworld-serveur`.
3. **Image and shape** (*Image et forme*) :
   - **Image** : clique sur **Change image** (*Modifier l'image*) > **Ubuntu** > coche **Canonical Ubuntu 24.04** (pas la version « Minimal »), puis **Select image**.
   - **Shape** : clique sur **Change shape** (*Modifier la forme*) > **Ampere** > coche **VM.Standard.A1.Flex**. Règle **4 OCPU** et **24 Go** de mémoire. Une étiquette **Always Free-eligible** (*Eligible à Toujours gratuit*) doit s'afficher. Clique sur **Select shape**.
4. **Networking** (*Réseau*) : laisse les choix proposés (**Create new virtual cloud network** et **Create new public subnet**). Vérifie que **Automatically assign public IPv4 address** est bien **activé**.
5. **Add SSH keys** (*Ajouter des clés SSH*) : laisse **Generate a key pair for me** et clique sur **Download private key** (*Télécharger la clé privée*), puis sur **Download public key**. Range les deux fichiers dans `Documents\SickWorld_serveur\oracle\` sur ton PC. **Ne les partage avec personne** : c'est la clé de la machine (je m'en servirai depuis ton PC si je dois réparer le serveur).
6. **Boot volume** (*Volume d'initialisation*) : ne change rien.
7. Tout en bas de la première étape (*Basic information*), ouvre **Show advanced options** (*Afficher les options avancées*) > onglet **Management** (*Gestion*) > **Initialization script** (*Script d'initialisation*) > choisis **Paste cloud-init script** (*Coller le script cloud-init*), et colle **exactement** ce texte :

   ```bash
   #!/bin/bash
   apt-get update -y && apt-get install -y git
   rm -rf /tmp/sickworld-installation
   git clone --depth 1 https://github.com/macgama/SickWorld.git /tmp/sickworld-installation
   bash /tmp/sickworld-installation/serveur/oracle/installer.sh 2>&1 | tee -a /var/log/sickworld-installation.log
   ```

   (Le même texte est dans le dossier du jeu : `serveur\oracle\initialisation.sh`, à ouvrir avec le Bloc-notes.)
8. Passe les étapes suivantes sans rien changer et clique sur **Create** (*Créer*).
9. La machine passe en **Provisioning** (orange) puis **Running** (vert) en 1 à 2 minutes. Elle s'installe ensuite toute seule pendant **15 à 20 minutes** (téléchargement du jeu, de Godot, du serveur de comptes…). Tu peux fermer la page.

### Si Oracle affiche « Out of capacity » (*Capacité insuffisante*)

C'est fréquent : les machines gratuites sont très demandées. Dans ce cas :
- réessaie un peu plus tard (tôt le matin ou tard le soir, ça passe mieux) ;
- ou baisse à **2 OCPU / 12 Go** à l'étape 3 (ça suffit largement pour commencer) ;
- ou, dans **Placement**, essaie un autre **Availability domain** s'il y en a plusieurs.

Préviens-moi si ça bloque après plusieurs essais : on trouvera une autre solution (il ne faut **pas** passer le compte en payant pour ça sans en parler).

---

## C. Ouvrir les portes du réseau Oracle (5 min)

Par sécurité, Oracle bloque tout ce qui arrive de l'extérieur. Il faut autoriser le jeu (port **7777**) et les comptes (ports **80** et **443**). La machine, elle, ouvre ses propres portes toute seule.

1. Sur la page de ta machine (**Compute > Instances > sickworld-serveur**), cherche **Primary VNIC** (*Carte d'interface réseau principale*) et clique sur le lien du **Subnet** (*Sous-réseau*), qui commence par `subnet-`.
2. Ouvre l'onglet **Security** (*Sécurité*) ou la liste **Security Lists**, puis clique sur **Default Security List for vcn-…**.
3. Onglet **Security rules** (*Règles de sécurité*) > **Ingress rules** (*Règles entrantes*) > **Add Ingress Rules** (*Ajouter des règles entrantes*).
4. Première règle (le jeu) :
   - **Source CIDR** : `0.0.0.0/0`
   - **IP Protocol** : **UDP**
   - **Destination Port Range** : `7777`
   - **Description** : `SickWorld jeu`
5. Clique sur **+ Another Ingress Rule** (*Autre règle entrante*) pour la deuxième (les comptes) :
   - **Source CIDR** : `0.0.0.0/0`
   - **IP Protocol** : **TCP**
   - **Destination Port Range** : `80,443`
   - **Description** : `SickWorld comptes`
6. Clique sur **Add Ingress Rules**. Tu dois voir tes deux nouvelles lignes à côté de celle du port 22 (déjà là).

---

## D. M'envoyer l'adresse de la machine

Sur la page de ta machine, recopie l'**adresse IP publique** (*Public IP address*), par exemple `141.145.200.12`, et envoie-la-moi dans le fil du projet. Je m'occupe du reste :

1. je vérifie que l'installation est terminée : la page `https://141-145-200-12.sslip.io/etat.json` (avec ton adresse, les points remplacés par des tirets) affiche `"jeu": "active"` et `"comptes": "active"` ;
2. je fais un vrai test à plusieurs joueurs depuis ton PC ;
3. j'inscris l'adresse dans le jeu (`game/data/serveur_officiel.json`) et je mets le jeu à jour sur ton PC.

Le bouton **Multijoueur > Rejoindre le serveur officiel** apparaît alors dans le menu, et le panneau **Compte** propose le bouton **Officiel** pour créer ton compte en ligne.

---

## Comment ça marche, en bref

- **Le serveur de jeu** (Godot sans écran) fait tourner la ville d'Hikari Bay et décide de tout ce qui compte (vie, dégâts, inventaire). Les joueurs s'y connectent sur le port **7777**.
- **Le serveur de comptes** (Nakama + base PostgreSQL) garde les comptes et les sauvegardes. Il est joignable en **HTTPS** (connexion chiffrée : les mots de passe ne circulent jamais en clair), grâce à une adresse gratuite `<ip>.sslip.io` et à un certificat Let's Encrypt obtenu automatiquement.
- **Mises à jour automatiques** : toutes les 5 minutes, le serveur regarde si la branche `main` de GitHub a changé. Si oui, et **seulement si personne n'est connecté**, il télécharge la nouvelle version et redémarre. Tu n'as rien à faire : chaque modification fusionnée arrive toute seule sur le serveur.
- **Sécurité** : les mots de passe internes (base de données, console d'administration, clés de session) sont tirés au hasard sur la machine elle-même, dans `/opt/sickworld/secrets.env`. Ils ne sont jamais sur GitHub. La console d'administration de Nakama n'est pas ouverte sur Internet.
- **Version de Godot** : le serveur utilise la même que ton PC (`serveur/oracle/versions.env`). Le jour où tu changes de version de Godot, dis-le-moi.

### Pour les curieux (connexion à la machine)

Depuis PowerShell sur ton PC :

```powershell
ssh -i "$env:USERPROFILE\Documents\SickWorld_serveur\oracle\ssh-key-XXXX.key" ubuntu@141.145.200.12
sudo sickworld-etat
```

`sickworld-etat` résume tout : services allumés, version installée, joueurs connectés. Le journal de l'installation est dans `/var/log/sickworld-installation.log`.

### Bon à savoir

- **Inactivité** : Oracle peut récupérer une machine gratuite qui ne fait presque rien pendant 7 jours d'affilée. Si ça arrive, il suffit de refaire la partie B (même script, même résultat) et de me donner la nouvelle adresse. Pour l'éviter complètement, il faudrait passer le compte en « Pay As You Go » (toujours gratuit dans les limites « Always Free », mais avec une carte enregistrée pour payer ce qui les dépasserait) : on en reparlera quand il y aura de vrais joueurs.
- **Ce qui est en ligne pour l'instant** : la ville d'Hikari Bay, à plusieurs. Le voyage en groupe vers les îles (Préhistoire…) n'est pas encore fait : les portails restent fermés en multijoueur.
