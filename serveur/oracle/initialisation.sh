#!/bin/bash
# SickWorld : script d'initialisation à coller dans Oracle Cloud, au moment de
# créer la machine (Options avancées > Gestion > Script d'initialisation).
# Il télécharge le projet et lance l'installation complète du serveur
# (10 à 20 minutes). Suivi : /var/log/sickworld-installation.log
apt-get update -y && apt-get install -y git
rm -rf /tmp/sickworld-installation
git clone --depth 1 https://github.com/macgama/SickWorld.git /tmp/sickworld-installation
bash /tmp/sickworld-installation/serveur/oracle/installer.sh 2>&1 | tee -a /var/log/sickworld-installation.log
