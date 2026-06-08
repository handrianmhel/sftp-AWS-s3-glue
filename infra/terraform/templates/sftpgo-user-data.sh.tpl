#!/bin/bash
set -euo pipefail
exec > /var/log/sftpgo-user-data.log 2>&1

BUCKET="${bucket_name}"
REGION="${aws_region}"
SFTPGO_VERSION="${sftpgo_version}"
ADMIN_USER="${sftp_admin_username}"
PREFIXES_JSON='${prefixes_json}'

echo "SFTPGo bootstrap starting (version $SFTPGO_VERSION)"

dnf install -y wget jq

RPM_URL="https://github.com/drakkan/sftpgo/releases/download/v$${SFTPGO_VERSION}/sftpgo-$${SFTPGO_VERSION}-1.x86_64.rpm"
wget -q -O /tmp/sftpgo.rpm "$RPM_URL"
dnf install -y /tmp/sftpgo.rpm

install -d -m 0750 -o sftpgo -g sftpgo /var/lib/sftpgo /var/lib/sftpgo/tmp /var/lib/sftpgo/data/upload /etc/sftpgo

cat > /etc/sftpgo/sftpgo.json <<'SFTPGOCFG'
${sftpgo_config}
SFTPGOCFG

chown sftpgo:sftpgo /etc/sftpgo/sftpgo.json

if [[ ! -f /var/lib/sftpgo/sftpgo.db ]]; then
  sftpgo initprovider -c /etc/sftpgo/sftpgo.json
  chown sftpgo:sftpgo /var/lib/sftpgo/sftpgo.db
fi

ADMIN_PASS="$(openssl rand -base64 18)"
install -d -m 0755 /etc/systemd/system/sftpgo.service.d
cat > /etc/systemd/system/sftpgo.service.d/default-admin.conf <<EOF
[Service]
Environment="SFTPGO_DEFAULT_ADMIN_USERNAME=$ADMIN_USER"
Environment="SFTPGO_DEFAULT_ADMIN_PASSWORD=$ADMIN_PASS"
EOF
systemctl daemon-reload

# SFTPGo binds SFTP on port 22; Amazon Linux sshd uses the same port. Admin access is via SSM.
systemctl stop sshd
systemctl disable sshd

systemctl enable sftpgo
systemctl restart sftpgo

for i in $(seq 1 60); do
  if curl -sf http://127.0.0.1:8080/healthz >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

CREDS_FILE="/root/sftpgo-setup-credentials.txt"
{
  echo "SFTPGo admin (tunnel 127.0.0.1:8080 or open port 8080 from allowed CIDR):"
  echo "  username: $ADMIN_USER"
  echo "  password: $ADMIN_PASS"
} > "$CREDS_FILE"
chmod 600 "$CREDS_FILE"

TOKEN="$(curl -s -u "$ADMIN_USER:$ADMIN_PASS" "http://127.0.0.1:8080/api/v2/token" | jq -r '.access_token // empty')"
if [[ -z "$TOKEN" ]]; then
  echo "WARN: no API token; create folders/users in admin UI."
  exit 0
fi

AUTH="Authorization: Bearer $TOKEN"

while IFS= read -r entry; do
  name="$(echo "$entry" | jq -r '.name')"
  prefix="$(echo "$entry" | jq -r '.prefix')"
  payload="$(jq -n \
    --arg name "$name" \
    --arg bucket "$BUCKET" \
    --arg region "$REGION" \
    --arg prefix "$prefix" \
    '{name:$name,filesystem:{provider:1,s3config:{bucket:$bucket,region:$region,key_prefix:$prefix}}}')"
  curl -s -H "$AUTH" -H "Content-Type: application/json" \
    -d "$payload" "http://127.0.0.1:8080/api/v2/folders" >/dev/null || true
done < <(echo "$PREFIXES_JSON" | jq -c '.[]')

FIRST_PREFIX="$(echo "$PREFIXES_JSON" | jq -r '.[0].prefix')"
FIRST_NAME="$(echo "$PREFIXES_JSON" | jq -r '.[0].name')"
USER_PASS="$(openssl rand -base64 16)"
VF_JSON="$(echo "$PREFIXES_JSON" | jq --arg fn "$FIRST_NAME" '[.[] | select(.name != $fn) | {name:.name, virtual_path: ("/" + .name)}]')"

USER_PAYLOAD="$(jq -n \
  --arg user "upload" \
  --arg pass "$USER_PASS" \
  --arg bucket "$BUCKET" \
  --arg region "$REGION" \
  --arg prefix "$FIRST_PREFIX" \
  --argjson vfs "$VF_JSON" \
  '{
    status: 1,
    username: $user,
    password: $pass,
    permissions: {"/": ["*"]},
    home_dir: "/var/lib/sftpgo/data/upload",
    filesystem: {provider: 1, s3config: {bucket: $bucket, region: $region, key_prefix: $prefix}},
    virtual_folders: $vfs
  }')"

curl -s -H "$AUTH" -H "Content-Type: application/json" \
  -d "$USER_PAYLOAD" "http://127.0.0.1:8080/api/v2/users" >/dev/null || true

{
  echo ""
  echo "SFTP upload user (add SSH public key in admin UI; change password):"
  echo "  username: upload"
  echo "  password: $USER_PASS"
  echo "  home S3 prefix: $FIRST_PREFIX"
} >> "$CREDS_FILE"

echo "SFTPGo bootstrap complete. Credentials: $CREDS_FILE"
