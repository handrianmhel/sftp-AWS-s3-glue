#!/bin/bash
set -euo pipefail

dnf install -y openssh-server
systemctl enable sshd

useradd -m -s /sbin/nologin ${sftp_username} || true
mkdir -p ${incoming_path}
chown ${sftp_username}:${sftp_username} ${incoming_path}
chmod 755 ${incoming_path}

install -d -m 700 -o ${sftp_username} -g ${sftp_username} /home/${sftp_username}/.ssh

grep -q "Match User ${sftp_username}" /etc/ssh/sshd_config || cat >> /etc/ssh/sshd_config <<EOF
Match User ${sftp_username}
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
EOF

systemctl restart sshd
