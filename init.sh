#!/bin/bash
set -e

mkdir -p stream

echo "▶ Starting full stack..."

docker-compose down
docker-compose up -d

echo "✅ Full stack started."