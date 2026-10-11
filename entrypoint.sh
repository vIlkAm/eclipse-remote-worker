#!/bin/sh
# Starts the worker's SSH door. The only way in is the one public key given
# at start; there is no password, forwarding, tunnel or terminal.
set -eu

# A key pasted from a chat or a web form may carry spaces, quotes or a line end.
KEY="$(printf '%s' "${ECLIPSE_WORKER_KEY:-}" | tr -d '\r\n' | sed 's/^[[:space:]"'"'"']*//; s/[[:space:]"'"'"']*$//')"
PORT="${ECLIPSE_WORKER_PORT:-22}"
ROOT="${ECLIPSE_WORKER_ROOT:-/workspace/eclipse-worker}"

case "$KEY" in
  "ssh-ed25519 "*) ;;
  *) echo "eclipse-worker: set ECLIPSE_WORKER_KEY to the ssh-ed25519 public key you were given" >&2; exit 64 ;;
esac
case "$PORT" in
  *[!0-9]*|"") echo "eclipse-worker: invalid ECLIPSE_WORKER_PORT" >&2; exit 64 ;;
esac

mkdir -p "$ROOT/jobs" "$ROOT/store" "$ROOT/.host" /run/sshd /root/.ssh
chmod 700 "$ROOT" "$ROOT/.host" /root/.ssh
# Kept with the worker folder so a restarted worker keeps the pinned identity.
[ -f "$ROOT/.host/ssh_host_ed25519_key" ] || \
  ssh-keygen -q -t ed25519 -N "" -C eclipse-worker -f "$ROOT/.host/ssh_host_ed25519_key"
chmod 600 "$ROOT/.host/ssh_host_ed25519_key"

printf 'restrict %s\n' "$KEY" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Sessions do not inherit the container environment; jobs need the card's.
{
  echo "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  for name in NVIDIA_VISIBLE_DEVICES NVIDIA_DRIVER_CAPABILITIES LD_LIBRARY_PATH; do
    eval "value=\${$name:-}"
    [ -z "$value" ] || echo "$name=$value"
  done
} > /etc/environment

cat > /etc/ssh/sshd_config <<CONFIG
Port $PORT
HostKey $ROOT/.host/ssh_host_ed25519_key
PermitRootLogin prohibit-password
AllowUsers root
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
UsePAM yes
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
PermitTunnel no
PermitTTY no
PermitUserEnvironment no
ClientAliveInterval 10
ClientAliveCountMax 3
MaxSessions 64
MaxStartups 30:50:100
LogLevel INFO
CONFIG

# Footage does not stay here: inputs unused for an hour and job folders left by
# a broken connection are removed even if the other side never returns.
(
  while sleep 600; do
    find "$ROOT/store" -mindepth 1 -maxdepth 1 -name 'f-*' -mmin +60 -exec rm -rf {} + 2>/dev/null || true
    find "$ROOT/jobs" -mindepth 1 -maxdepth 1 -mmin +1440 -exec rm -rf {} + 2>/dev/null || true
  done
) &

echo "eclipse-worker: $(cat /etc/eclipse-worker-image) listening on port $PORT"
echo "eclipse-worker: host key $(ssh-keygen -l -f "$ROOT/.host/ssh_host_ed25519_key.pub" | cut -d' ' -f2)"
echo "eclipse-worker: host key line: $(cut -d' ' -f1,2 "$ROOT/.host/ssh_host_ed25519_key.pub")"
exec /usr/sbin/sshd -D -e
