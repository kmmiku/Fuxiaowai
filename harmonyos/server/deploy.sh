#!/usr/bin/env bash
set -euo pipefail
test "$(id -u)" = 0 || { echo 'Run as root'; exit 1; }
test -s /etc/fxw-share.env || { echo 'Create /etc/fxw-share.env from fxw.env.example first'; exit 1; }
id fxw >/dev/null 2>&1 || useradd --system --home /var/lib/fxw --shell /usr/sbin/nologin fxw
install -d -o fxw -g fxw -m 700 /var/lib/fxw
install -d -m 755 /opt/fxw-service
cp -R server.js dashboard.html release.html site /opt/fxw-service/
chown -R root:root /opt/fxw-service
chown -R fxw:fxw /var/lib/fxw
chmod 600 /etc/fxw-share.env
install -m 644 fxw-share.service /etc/systemd/system/fxw-share.service
systemctl daemon-reload
systemctl enable --now fxw-share
systemctl restart fxw-share
curl --fail --silent http://127.0.0.1:8080/healthz
