#!/bin/bash
# SickWorld : résumé de l'état du serveur.  Commande : sudo sickworld-etat
RACINE=/opt/sickworld
# shellcheck disable=SC1091
source "$RACINE/adresses.env" 2>/dev/null
echo "Serveur SickWorld"
echo "  Jeu (port 7777 UDP)     : $(systemctl is-active sickworld-jeu)"
echo "  Comptes (Nakama)        : $(systemctl is-active sickworld-comptes)"
echo "  HTTPS (Caddy)           : $(systemctl is-active caddy)"
echo "  Mises à jour auto       : $(systemctl is-active sickworld-maj.timer)"
echo "  Version                 : $(sudo -u sickworld git -C "$RACINE/depot" log -1 --format='%h « %s » (%cd)' --date=format:'%d/%m %H:%M')"
echo "  Joueurs connectés       : $(cat "$RACINE/statut/jeu.json" 2>/dev/null || echo '?')"
echo "  Adresse du jeu          : ${IP_PUBLIQUE:-?}"
echo "  Adresse des comptes     : https://${HOTE:-?}"
printf "  Comptes en HTTPS        : "
curl -fsS --max-time 10 "https://${HOTE}/healthcheck" >/dev/null 2>&1 && echo "OK" || echo "pas encore (certificat en cours ?)"
echo
echo "Derniers messages du serveur de jeu :"
journalctl -u sickworld-jeu -n 8 --no-pager -o cat 2>/dev/null | grep -v "^\s*$" | tail -8
