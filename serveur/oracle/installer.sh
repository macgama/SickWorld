#!/bin/bash
# =============================================================================
# SickWorld : installation du serveur en ligne (Oracle Cloud, Ubuntu 24.04).
#
# Installe et allume tout seul :
#   - le serveur de jeu (Godot sans écran, port 7777 UDP) : la ville d'Hikari Bay ;
#   - le serveur de comptes (Nakama + PostgreSQL), joignable en HTTPS (ports 80/443)
#     grâce à Caddy et à une adresse gratuite <ip>.sslip.io ;
#   - la mise à jour automatique depuis la branche main de GitHub (toutes les 5 min,
#     seulement quand personne n'est connecté).
#
# Lancé automatiquement par initialisation.sh à la création de la machine.
# On peut le relancer sans risque (il ne refait que ce qui manque) :
#   sudo bash /opt/sickworld/depot/serveur/oracle/installer.sh
# =============================================================================
set -euo pipefail

RACINE=/opt/sickworld
DEPOT="$RACINE/depot"
URL_DEPOT="${SICKWORLD_DEPOT:-https://github.com/macgama/SickWorld.git}"
BRANCHE="${SICKWORLD_BRANCHE:-main}"
ICI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DEBIAN_FRONTEND=noninteractive

etape() { echo; echo "=== [SickWorld] $* ($(date '+%H:%M:%S'))"; }

if [ "$(id -u)" -ne 0 ]; then
	echo "À lancer en administrateur : sudo bash $0"
	exit 1
fi

# shellcheck source=versions.env
source "$ICI/versions.env"

case "$(uname -m)" in
	aarch64 | arm64) ARCH_GODOT=linux.arm64; ARCH_NAKAMA=linux-arm64 ;;
	x86_64 | amd64) ARCH_GODOT=linux.x86_64; ARCH_NAKAMA=linux-amd64 ;;
	*) echo "Processeur non pris en charge : $(uname -m)"; exit 1 ;;
esac

etape "1/9 Logiciels du système"
apt-get update -y
apt-get install -y git git-lfs curl unzip ca-certificates postgresql caddy \
	iptables-persistent netfilter-persistent openssl sudo
git lfs install --system

etape "2/9 Mémoire d'appoint (petites machines)"
MEMOIRE_MO=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
if [ "$MEMOIRE_MO" -lt 3500 ] && [ ! -f /swapfile ] && [ -z "${SICKWORLD_TEST:-}" ]; then
	fallocate -l 3G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
	echo "/swapfile none swap sw 0 0" >> /etc/fstab
	echo "Fichier d'échange de 3 Go ajouté (machine de $MEMOIRE_MO Mo)."
else
	echo "Mémoire : $MEMOIRE_MO Mo, rien à faire."
fi

etape "3/9 Utilisateur et dossiers"
id sickworld >/dev/null 2>&1 || useradd --system --create-home --home-dir "$RACINE" --shell /usr/sbin/nologin sickworld
mkdir -p "$RACINE"/{godot,nakama,nakama-donnees,statut,public}
chown sickworld:sickworld "$RACINE" "$RACINE"/{nakama-donnees,statut}
chmod 755 "$RACINE" "$RACINE/public"

etape "4/9 Mots de passe et clés (créés une seule fois, propres à ce serveur)"
SECRETS="$RACINE/secrets.env"
if [ ! -f "$SECRETS" ]; then
	alea() { openssl rand -hex 24; }
	cat > "$SECRETS" <<EOS
# Généré par installer.sh le $(date '+%d/%m/%Y'). Ne jamais publier ce fichier.
MDP_BASE=$(alea)
CLE_SESSION=$(alea)
CLE_RENOUVELLEMENT=$(alea)
MDP_CONSOLE=$(alea)
EOS
fi
chown root:sickworld "$SECRETS"
chmod 640 "$SECRETS"
# shellcheck disable=SC1090
source "$SECRETS"

etape "5/9 Projet SickWorld (GitHub, branche $BRANCHE, avec les fichiers lourds LFS)"
if [ ! -d "$DEPOT/.git" ]; then
	sudo -u sickworld git clone --branch "$BRANCHE" "$URL_DEPOT" "$DEPOT"
fi
sudo -u sickworld git -C "$DEPOT" lfs pull

etape "6/9 Godot $GODOT_VERSION ($ARCH_GODOT)"
GODOT="$RACINE/godot/godot-$GODOT_VERSION"
if [ ! -x "$GODOT" ]; then
	TMP=$(mktemp -d)
	curl -fsSL -o "$TMP/godot.zip" \
		"https://github.com/godotengine/godot-builds/releases/download/$GODOT_VERSION-stable/Godot_v$GODOT_VERSION-stable_$ARCH_GODOT.zip"
	unzip -q "$TMP/godot.zip" -d "$TMP"
	mv "$TMP/Godot_v$GODOT_VERSION-stable_$ARCH_GODOT" "$GODOT"
	chmod 755 "$GODOT"
	rm -rf "$TMP"
fi
ln -sf "$GODOT" "$RACINE/godot/godot"
echo "Préparation des fichiers du jeu (import Godot, quelques minutes)…"
sudo -u sickworld HOME="$RACINE" "$RACINE/godot/godot" --headless --path "$DEPOT/game" --import >/dev/null 2>&1 || true

etape "7/9 Serveur de comptes : PostgreSQL + Nakama $NAKAMA_VERSION"
systemctl enable --now postgresql
sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='nakama'" | grep -q 1 ||
	sudo -u postgres psql -c "CREATE USER nakama WITH PASSWORD '$MDP_BASE'"
sudo -u postgres psql -c "ALTER USER nakama WITH PASSWORD '$MDP_BASE'" >/dev/null
sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='nakama'" | grep -q 1 ||
	sudo -u postgres createdb -O nakama nakama
NAKAMA="$RACINE/nakama/nakama-$NAKAMA_VERSION"
if [ ! -x "$NAKAMA" ]; then
	TMP=$(mktemp -d)
	curl -fsSL "https://github.com/heroiclabs/nakama/releases/download/v$NAKAMA_VERSION/nakama-$NAKAMA_VERSION-$ARCH_NAKAMA.tar.gz" |
		tar xz -C "$TMP" 2>/dev/null
	mv "$TMP/nakama" "$NAKAMA"
	chmod 755 "$NAKAMA"
	rm -rf "$TMP"
fi
ln -sf "$NAKAMA" "$RACINE/nakama/nakama"
# Réglages : ceux du dépôt (serveur/nakama/config.yml) + les clés propres à ce serveur.
# Nakama n'écoute que sur la machine elle-même : Caddy le présente en HTTPS.
CONFIG="$RACINE/nakama.yml"
sed -e "s|^data_dir:.*|data_dir: \"$RACINE/nakama-donnees/\"|" \
	-e "s|^\(\s*encryption_key:\).*|\1 \"$CLE_SESSION\"|" \
	-e "s|^\(\s*refresh_encryption_key:\).*|\1 \"$CLE_RENOUVELLEMENT\"|" \
	-e "s|^\(\s*password:\).*|\1 \"$MDP_CONSOLE\"|" \
	-e "s|^\(\s*port: 7350\).*|\1\n  address: \"127.0.0.1\"|" \
	-e "s|^\(\s*port: 7351\).*|\1\n  address: \"127.0.0.1\"|" \
	"$DEPOT/serveur/nakama/config.yml" > "$CONFIG"
cat >> "$CONFIG" <<EOC

database:
  address:
    - "nakama:$MDP_BASE@127.0.0.1:5432/nakama"
EOC
chown root:sickworld "$CONFIG"
chmod 640 "$CONFIG"

etape "8/9 Services (allumage automatique, redémarrage en cas de panne)"
cat > /etc/systemd/system/sickworld-comptes.service <<EOU
[Unit]
Description=SickWorld - serveur de comptes (Nakama)
After=network-online.target postgresql.service
Wants=network-online.target
Requires=postgresql.service

[Service]
User=sickworld
WorkingDirectory=$RACINE
EnvironmentFile=$SECRETS
ExecStartPre=$RACINE/nakama/nakama migrate up --database.address nakama:\${MDP_BASE}@127.0.0.1:5432/nakama
ExecStart=$RACINE/nakama/nakama --config $CONFIG
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOU
cat > /etc/systemd/system/sickworld-jeu.service <<EOU
[Unit]
Description=SickWorld - serveur de jeu (Godot sans écran, port 7777 UDP)
After=network-online.target
Wants=network-online.target

[Service]
User=sickworld
Environment=HOME=$RACINE
WorkingDirectory=$DEPOT
ExecStart=$RACINE/godot/godot --headless --max-fps 30 --path $DEPOT/game -- --serveur --port=7777 --statut=$RACINE/statut/jeu.json
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOU
cat > /etc/systemd/system/sickworld-maj.service <<EOU
[Unit]
Description=SickWorld - mise à jour depuis GitHub et état public

[Service]
Type=oneshot
ExecStart=/bin/bash $DEPOT/serveur/oracle/mettre_a_jour.sh
EOU
cat > /etc/systemd/system/sickworld-maj.timer <<EOU
[Unit]
Description=SickWorld - mise à jour toutes les 5 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOU
ln -sf "$DEPOT/serveur/oracle/etat.sh" /usr/local/bin/sickworld-etat
chmod 755 "$DEPOT/serveur/oracle/"*.sh

# Adresse publique : <ip-avec-des-tirets>.sslip.io (gratuit, sans inscription),
# pour que Caddy obtienne un certificat HTTPS Let's Encrypt.
IP_PUBLIQUE="${SICKWORLD_IP:-$(curl -fsS --max-time 10 https://api.ipify.org || curl -fsS --max-time 10 https://ifconfig.me || echo "")}"
if [ -n "${SICKWORLD_HOTE:-}" ]; then
	HOTE="$SICKWORLD_HOTE"
elif [ -n "$IP_PUBLIQUE" ]; then
	HOTE="${IP_PUBLIQUE//./-}.sslip.io"
else
	HOTE=""
fi
if [ -n "$HOTE" ]; then
	cat > /etc/caddy/Caddyfile <<EOC
# Généré par installer.sh (SickWorld).
$HOTE {
	handle /etat.json {
		root * $RACINE/public
		file_server
	}
	handle {
		reverse_proxy 127.0.0.1:7350
	}
}
EOC
fi
cat > "$RACINE/adresses.env" <<EOA
IP_PUBLIQUE=$IP_PUBLIQUE
HOTE=$HOTE
BRANCHE=$BRANCHE
EOA

etape "9/9 Pare-feu de la machine (7777 UDP pour le jeu, 80/443 TCP pour les comptes)"
ouvrir() {
	local proto=$1 port=$2
	if ! iptables -C INPUT -p "$proto" --dport "$port" -j ACCEPT 2>/dev/null; then
		# Les images Ubuntu d'Oracle finissent par une règle « tout refuser » :
		# on ajoute nos règles juste avant elle.
		local ligne
		ligne=$(iptables -L INPUT --line-numbers -n | awk '$2=="REJECT" {print $1; exit}')
		if [ -n "$ligne" ]; then
			iptables -I INPUT "$ligne" -p "$proto" --dport "$port" -j ACCEPT
		else
			iptables -A INPUT -p "$proto" --dport "$port" -j ACCEPT
		fi
	fi
}
# Le serveur se parle à lui-même (Nakama <-> PostgreSQL, Caddy -> Nakama).
iptables -C INPUT -i lo -j ACCEPT 2>/dev/null || iptables -I INPUT 1 -i lo -j ACCEPT
ouvrir udp 7777
ouvrir tcp 80
ouvrir tcp 443
netfilter-persistent save >/dev/null 2>&1 || true

systemctl daemon-reload
systemctl enable sickworld-comptes sickworld-jeu sickworld-maj.timer caddy >/dev/null 2>&1
systemctl restart sickworld-comptes sickworld-jeu caddy
systemctl start sickworld-maj.timer
sleep 3
bash "$DEPOT/serveur/oracle/mettre_a_jour.sh" --etat-seulement || true

etape "Terminé"
echo "Serveur de jeu      : $IP_PUBLIQUE port 7777 (UDP)"
echo "Serveur de comptes  : https://$HOTE"
echo "État public         : https://$HOTE/etat.json"
echo "Console Nakama      : tunnel SSH vers 127.0.0.1:7351 (admin / MDP_CONSOLE dans $SECRETS)"
echo "Pour tout vérifier  : sudo sickworld-etat"
