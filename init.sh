#!/bin/bash
set -e

echo "▶ Starting placeholder..."
docker compose run --rm -T placeholder

echo "▶ Starting full stack..."
docker compose up -d
