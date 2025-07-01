#!/bin/bash
set -e

### ─────────────── USER‑EDITABLE SECTION ───────────────
PROJECT_DIR="$HOME/smartclean-stream"
REPO_URL="https://github.com/aangjnr/smartclean-stream.git"
NGROK_AUTHTOKEN="5188TJ1YjNSmeJUFAVH8d_56Z2SKuTkopBRMCMtYGCK"  # <<< required
LOCAL_PORT=8888                                 # MediaMTX HLS port
### ─────────────────────────────────────────────────────

if [[ "$NGROK_AUTHTOKEN" == "PASTE_YOUR_NGROK_TOKEN_HERE" ]]; then
  echo "❌  Please edit install.sh and set NGROK_AUTHTOKEN before running."
  exit 1
fi

echo "▶ Updating system..."
export DEBIAN_FRONTEND=noninteractive
sudo apt update && sudo apt full-upgrade -y

echo "▶ Installing Docker..."
curl -fsSL https://get.docker.com | sh

echo "▶ Installing Git, Curl, Docker Compose..."
sudo apt install -y git curl docker-compose

echo "▶ Adding user to docker group..."
sudo usermod -aG docker $USER

# ── Re-enter shell with Docker permissions ──
echo "▶ Re-entering group 'docker' shell via newgrp…"
newgrp docker <<EOF
set -e

echo "▶ Cloning or updating repo…"
if [ ! -d "$PROJECT_DIR" ]; then
  git clone "$REPO_URL" "$PROJECT_DIR"
else
  cd "$PROJECT_DIR"
  git pull
fi
cd "$PROJECT_DIR"

echo "▶ Starting full stack (MediaMTX + NGINX)…"
./init.sh --skip-cert

echo "▶ Installing ngrok…"
curl -fsSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
  | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo "deb https://ngrok-agent.s3.amazonaws.com buster main" \
  | sudo tee /etc/apt/sources.list.d/ngrok.list
sudo apt update && sudo apt install -y ngrok
ngrok config add-authtoken "$NGROK_AUTHTOKEN"

# Detect ngrok binary location
NGROK_BIN=$(command -v ngrok 2>/dev/null || true)
[ -z "$NGROK_BIN" ] && [ -x "/usr/local/bin/ngrok" ] && NGROK_BIN="/usr/local/bin/ngrok"
[ -z "$NGROK_BIN" ] && { echo "❌  ngrok not found."; exit 1; }
echo "▶ ngrok found at ${NGROK_BIN}"

echo "▶ Creating systemd service for ngrok tunnel…"
NGUSER=$(logname)    # actual login user (pi)
sudo bash -c "cat > /etc/systemd/system/ngrok-stream.service" <<SYSTEMD
[Unit]
Description=ngrok SmartClean HLS tunnel
After=network-online.target docker.service
Requires=docker.service

[Service]
User=${NGUSER}
ExecStart=${NGROK_BIN} http ${LOCAL_PORT} --log stdout
Restart=on-failure

[Install]
WantedBy=multi-user.target
SYSTEMD

sudo systemctl daemon-reload
sudo systemctl enable ngrok-stream
sudo systemctl restart ngrok-stream

echo "▶ Waiting for tunnel…"
for i in {1..10}; do
  PUBLIC_URL=$(curl -s --max-time 2 http://localhost:4040/api/tunnels \
    | grep -Eo 'https://[0-9a-z]+\.ngrok\.io' | head -n1) && break
  sleep 2
done

if [[ -n "$PUBLIC_URL" ]]; then
  echo "✅ Public HLS URL:"
  echo "👉  ${PUBLIC_URL}/cam/index.m3u8"
else
  echo "❌ ngrok tunnel not detected. Check logs:"
  echo "   sudo journalctl -u ngrok-stream -f"
fi

EOF