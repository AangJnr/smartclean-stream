#!/usr/bin/env bash
#
# Watches Docker “start” events and posts the latest ngrok tunnel JSON
# to a Webhook each time the stack (re)starts.

set -euo pipefail

WEBHOOK_URL="https://updatestreamurl-lwghhtnp6q-uc.a.run.app"      # <‑‑ replace with your webhook
NGROK_API="http://localhost:4040/api/tunnels"
PROJECT="smartclean-stream"

echo "📡 Docker‑Watcher for $PROJECT started …"

# Wait until ngrok’s local API is reachable (boot safety)
until curl -sf "$NGROK_API" >/dev/null; do
  echo "⏳ Waiting for ngrok API …"
  sleep 2
done

# Function: fetch tunnels + send
send_tunnel () {
  json=$(curl -sf "$NGROK_API")
  echo "🔄  Posting tunnel JSON to webhook"
  curl -s -X POST -H "Content-Type: application/json" \
       -d "$json" "$WEBHOOK_URL" || echo "⚠️ Webhook post failed"
}

# Send once on startup
send_tunnel

# Listen only for “container start” events (any service)
docker events --filter 'event=start' --format '{{json .}}' |
while read -r line; do
  echo "🚀 Docker event: $line"
  # Optional: filter by container name (e.g., nginx-hls) with jq or grep
  send_tunnel
done
