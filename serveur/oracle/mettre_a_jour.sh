#!/bin/bash
# SickWorld : mise à jour automatique du serveur (lancée toutes les 5 minutes).
# - publie l'état du serveur sur https://<adresse>/etat.json ;
# - si la branche main a changé sur GitHub ET que personne n'est connecté,
#   télécharge la nouvelle version et redémarre le serveur de jeu.
# Options : --etat-seulement (pas de mise à jour), --forcer (même avec des joueurs).
set -uo pipefail
RACINE=/opt/sickworld
DEPOT="$RACINE/depot"
# Branche suivie : celle choisie à l'installation (main normalement).
# shellcheck disable=SC1091
source "$RACINE/adresses.env" 2>/dev/null
BRANCHE="${SICKWORLD_BRANCHE:-${BRANCHE:-main}}"
git_() { sudo -u sickworld git -C "$DEPOT" "$@"; }

joueurs() {
	if systemctl is-active --quiet sickworld-jeu && [ -f "$RACINE/statut/jeu.json" ]; then
		grep -o '"joueurs":[0-9]*' "$RACINE/statut/jeu.json" | cut -d: -f2
	else
		echo 0
	fi
}

publier_etat() {
	local actif_jeu actif_comptes
	actif_jeu=$(systemctl is-active sickworld-jeu 2>/dev/null)
	actif_comptes=$(systemctl is-active sickworld-comptes 2>/dev/null)
	cat > "$RACINE/public/etat.json.tmp" <<EOJ
{
	"jeu": "$actif_jeu",
	"comptes": "$actif_comptes",
	"joueurs": $(joueurs),
	"version": "$(git_ log -1 --format='%h %cd' --date=format:'%d/%m %H:%M' 2>/dev/null)",
	"verifie": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
}
EOJ
	chmod 644 "$RACINE/public/etat.json.tmp"
	mv "$RACINE/public/etat.json.tmp" "$RACINE/public/etat.json"
}

if [ "${1:-}" = "--etat-seulement" ]; then
	publier_etat
	exit 0
fi

git_ fetch --quiet origin "$BRANCHE" || { publier_etat; exit 0; }
AVANT=$(git_ rev-parse HEAD)
APRES=$(git_ rev-parse "origin/$BRANCHE")
if [ "$AVANT" = "$APRES" ]; then
	publier_etat
	exit 0
fi
if [ "$(joueurs)" -gt 0 ] && [ "${1:-}" != "--forcer" ]; then
	echo "Nouvelle version disponible, mise à jour reportée : $(joueurs) joueur(s) connecté(s)."
	publier_etat
	exit 0
fi

echo "Mise à jour ${AVANT:0:7} -> ${APRES:0:7}"
git_ reset --hard --quiet "origin/$BRANCHE"
git_ lfs pull
if git_ diff --quiet "$AVANT" "$APRES" -- serveur/; then
	sudo -u sickworld HOME="$RACINE" "$RACINE/godot/godot" --headless --path "$DEPOT/game" --import >/dev/null 2>&1 || true
	systemctl restart sickworld-jeu
else
	# Les scripts ou réglages du serveur ont changé : on relance l'installation complète.
	bash "$DEPOT/serveur/oracle/installer.sh"
fi
publier_etat
