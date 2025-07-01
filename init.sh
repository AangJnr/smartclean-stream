#!/bin/bash
set -e

SKIP_CERT=false
if [[ "$1" == "--skip-cert" ]]; then
  SKIP_CERT=true
fi

echo "▶ Starting SmartClean Stream bootstrap"
cd "$(dirname "$0")"

mkdir -p logs/mediamtx logs/nginx certbot/{conf,www}

if [ "$SKIP_CERT" = false ]; then
  echo "▶ Starting temporary NGINX for certbot..."
  docker-compose up -d nginx
  sleep 5

  echo "▶ Requesting TLS cert..."
  docker-compose run --rm certbot certonly \
    --webroot -w /var/www/certbot \
    --email demo@smartclean.se \
    -d stream.smartclean.link \
    --agree-tos --non-interactive
fi

echo "▶ Starting full stack..."
docker-compose down
docker-compose up -d

echo "✅ All done! Stream URL: https://stream.smartclean.link/cam/index.m3u8"