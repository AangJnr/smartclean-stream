#!/bin/bash
set -e
set -x  # ← show all commands being executed

echo "▶ Starting placeholder..."
mkdir -p ./stream/cam
chmod -R 777 ./stream


echo "▶ Generating thumbnail-based HLS..."
./generate-placeholder.sh

echo "▶ Starting full stack..."
docker compose up -d --remove-orphans
