#!/usr/bin/env bash
# Abilita l'accesso SSH al portatile robot-x551cap SOLO dalla LAN di casa,
# con la chiave pubblica del PC di Carlo. Da eseguire sul portatile come
# utente `robot` (chiede la password di sudo una volta).
#
#   bash scripts/setup-ssh-lan.sh           # installa sshd, registra la chiave, apre la 22 in LAN
#   bash scripts/setup-ssh-lan.sh --harden  # SOLO dopo aver verificato il login con chiave:
#                                           # disabilita l'autenticazione a password
#
# Niente port-forward sul router e niente ingress nel tunnel Cloudflare:
# la porta 22 resta raggiungibile solo da 192.168.1.0/24.
set -euo pipefail

PUBKEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE4p6Cpbe8sLQtst9WrI5a1I3o2IBYFiN0/nJcbBoFCF carlo-pc -> robot-x551cap'
LAN_CIDR='192.168.1.0/24'
HARDEN_CONF='/etc/ssh/sshd_config.d/60-lan-keys-only.conf'

log() { printf '[setup-ssh] %s\n' "$*"; }

if [[ "$(id -u)" -eq 0 ]]; then
  echo "Eseguilo come utente normale (robot), non come root: usa sudo solo dove serve." >&2
  exit 1
fi

if [[ "${1:-}" == "--harden" ]]; then
  log "Disabilito l'autenticazione a password (restano solo le chiavi)."
  sudo install -d -m 755 /etc/ssh/sshd_config.d
  sudo tee "$HARDEN_CONF" >/dev/null <<'EOF'
# Generato da scripts/setup-ssh-lan.sh: accesso solo con chiave.
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
EOF
  sudo sshd -t
  sudo systemctl reload ssh 2>/dev/null || sudo systemctl reload sshd
  log "Fatto: da ora ssh accetta solo chiavi. Config: $HARDEN_CONF"
  exit 0
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "Questo script presume una distro Debian/Ubuntu (apt-get non trovato)." >&2
  exit 1
fi

if ! dpkg -s openssh-server >/dev/null 2>&1; then
  log "Installo openssh-server."
  sudo apt-get update -qq
  sudo apt-get install -y openssh-server
else
  log "openssh-server gia' installato."
fi

log "Abilito e avvio il servizio ssh."
sudo systemctl enable --now ssh 2>/dev/null || sudo systemctl enable --now sshd

log "Registro la chiave pubblica del PC di Carlo in ~/.ssh/authorized_keys."
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
touch "$HOME/.ssh/authorized_keys"
chmod 600 "$HOME/.ssh/authorized_keys"
if grep -qF "$PUBKEY" "$HOME/.ssh/authorized_keys"; then
  log "Chiave gia' presente, non la duplico."
else
  printf '%s\n' "$PUBKEY" >> "$HOME/.ssh/authorized_keys"
  log "Chiave aggiunta."
fi

if command -v ufw >/dev/null 2>&1 && sudo ufw status 2>/dev/null | grep -q '^Status: active'; then
  log "ufw attivo: apro la 22 solo da $LAN_CIDR."
  sudo ufw allow from "$LAN_CIDR" to any port 22 proto tcp
else
  log "ufw non attivo: non lo accendo (per non bloccare cloudflared/runner), nessuna regola da aggiungere."
fi

log "Stato servizio:"
systemctl is-active ssh 2>/dev/null || systemctl is-active sshd || true
ip -4 -o addr show scope global | awk '{print "  IP LAN: " $4}'

log "FATTO. Dal PC di Carlo ora funziona: ssh robot"
log "Dopo la verifica, rilancia con --harden per disabilitare le password."
