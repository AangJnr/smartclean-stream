#!/bin/bash
set -e

### ─────────────── USER‑EDITABLE SECTION ───────────────
PROJECT_DIR="$HOME/smartclean-stream"
REPO_URL="https://github.com/aangjnr/smartclean-stream.git"
NGROK_AUTHTOKEN="5188TJ1YjNSmeJUFAVH8d_56Z2SKuTkopBRMCMtYGCK"  # <<< required
LOCAL_PORT=8888                                 # MediaMTX HLS port
### ─────────────────────────────────────────────────────

if [[ "$NGROK_AUTHTOKEN" == "PASTE_YOUR_NGROK_TOKEN_HERE" ]]; then
  echo "❌  Edit install.sh and set NGROK_AUTHTOKEN before running."
  exit 1
fi

echo "▶ System update..."
sudo apt update && sudo apt full-upgrade -y

echo "▶ Installing Docker..."
curl -fsSL https://get.docker.com | sh

echo "▶ Installing Git, Curl, Docker Compose..."
sudo apt install -y git curl docker-compose

echo "▶ Adding user to docker group..."
sudo usermod -aG docker $USER

# ── Jump into a sub‑shell that already has docker group privileges ──
echo "▶ Re-entering shell with docker group privileges (newgrp)..."
newgrp docker <<EOF
set -e

# Clone or pull repo
if [ ! -d "$PROJECT_DIR" ]; then
  git clone "$REPO_URL" "$PROJECT_DIR"
else
  cd "$PROJECT_DIR"
  git pull
fi
cd "$PROJECT_DIR"

# Run init (skip certbot)
./init.sh --skip-cert

# ----- ngrok setup -----
curl -fsSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | \
  sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | \
  sudo tee /etc/apt/sources.list.d/ngrok.list
sudo apt update && sudo apt install -y ngrok
ngrok config add-authtoken "$NGROK_AUTHTOKEN"

sudo bash -c 'cat > /etc/systemd/system/ngrok-stream.service' <<SYSTEMD
[Unit]
Description=ngrok SmartClean HLS tunnel
After=network-online.target docker.service
Requires=docker.service

[Service]
ExecStart=/usr/bin/ngrok http ${LOCAL_PORT} --log stdout
Restart=on-failure
User=$USER

[Install]
WantedBy=multi-user.target
SYSTEMD

sudo systemctl daemon-reload
sudo systemctl enable ngrok-stream
sudo systemctl start ngrok-stream

sleep 5
PUBLIC_URL=\$(curl -s http://localhost:4040/api/tunnels | grep -Eo "https://[0-9a-z]+\\.ngrok\\.io" | head -n1)
echo "✅ Public HLS URL: \${PUBLIC_URL}/cam/index.m3u8"
EOF