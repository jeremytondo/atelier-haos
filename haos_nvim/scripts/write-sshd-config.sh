#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <config-path> <authorized-keys-path> <log-level>" >&2
  exit 1
fi

config_path="$1"
authorized_keys_path="$2"
log_level="$3"

cat >"${config_path}" <<EOF
Port 2222
ListenAddress 0.0.0.0
Protocol 2
AddressFamily any
HostKey /data/ssh/ssh_host_ed25519_key
HostKey /data/ssh/ssh_host_rsa_key
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
UsePAM no
PubkeyAuthentication yes
AuthorizedKeysFile ${authorized_keys_path}
AllowUsers atelier
AllowAgentForwarding no
AllowTcpForwarding no
GatewayPorts no
X11Forwarding no
PermitTunnel no
PermitUserEnvironment no
PrintMotd no
TCPKeepAlive yes
ClientAliveInterval 180
ClientAliveCountMax 2
LoginGraceTime 30
MaxAuthTries 3
StrictModes yes
PidFile /run/sshd.pid
LogLevel ${log_level}
Subsystem sftp internal-sftp
EOF

chmod 0600 "${config_path}"
chown root:root "${config_path}"
