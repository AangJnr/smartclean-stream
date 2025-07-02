#!/bin/bash
set -e
set -x  # ← show all commands being executed

echo "▶ Starting placeholder..."
mkdir -p ./stream/cam
chmod -R 777 ./stream

docker compose run --rm -T placeholder

echo "▶ Starting full stack..."
docker compose up -d --remove-orphans
