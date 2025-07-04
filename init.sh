#!/bin/bash
set -e
set -x  # ← show all commands being executed

echo "▶ Starting placeholder..."
mkdir -p ./stream/cam
chmod -R 777 ./stream

# Copy index.html from project root to ./stream/
cp -f ./index.html ./stream/index.html
echo "✅ index.html copied to ./stream/"


echo "▶ Generating thumbnail-based HLS..."
./generate-placeholder.sh

echo "▶ Starting full stack..."
docker compose up -d --remove-orphans
