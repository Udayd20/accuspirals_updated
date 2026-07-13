#!/usr/bin/env bash
# Generates a self-signed TLS certificate for LAN use.
# Usage:  ./gen-cert.sh              (localhost only)
#         ./gen-cert.sh 192.168.1.50 (also valid for that LAN IP — use YOUR machine's IP)
set -e
IP="${1:-}"
SAN="DNS:localhost,IP:127.0.0.1"
[ -n "$IP" ] && SAN="$SAN,IP:$IP"
mkdir -p certs
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout certs/server.key -out certs/server.crt -days 825 \
  -subj "/CN=accuspirals.local" -addext "subjectAltName=$SAN"
chmod 600 certs/server.key
echo
echo "✔ Cert created in backend/certs/ (valid for: $SAN)"
echo "  Restart the backend (npm run start:dev) to serve over HTTPS."
echo "  Other machines open:  https://<this-machine-ip>:3000/"
echo "  (Self-signed, so browsers show a one-time 'not secure' warning you accept.)"
