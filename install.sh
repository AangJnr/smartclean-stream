#!/bin/bash
set -e

### ─────────────── USER‑EDITABLE SECTION ───────────────
PROJECT_DIR="$HOME/smartclean-stream"
REPO_URL="https://github.com/aangjnr/smartclean-stream.git"
NGROK_AUTHTOKEN="5188TJ1YjNSmeJUFAVH8d_56Z2SKuTkopBRMCMtYGCK"  # <<< required
LOCAL_PORT=8888                                 # MediaMTX HLS port
### ─────────────────────────────────────────────────────

if [[ "$NGROK_AUTHTOKEN" == "PASTE_YOUR_NGROK_TOKEN_HERE" ]]; then
  echo "❌  Please edit install.sh and set NGROK_AUTHTOKEN."
  exit 1
fi

echo "▶ Updating system..."
sudo apt update && sudo apt full-upgrade -y

echo "▶ Installing Docker & Docker Compose..."
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
sudo apt install -y git curl docker-compose

echo "▶ Cloning or updating repo..."
if [ ! -d "$PROJECT_DIR" ]; then
  git clone "$REPO_URL" "$PROJECT_DIR"
else
  cd "$PROJECT_DIR"
  git pull
fi

echo "▶ Re‑entering group 'docker' without logout…"
newgrp docker <<'EOS'
set -e
cd "$HOME/smartclean-stream"
./init.sh --skip-cert
EOS

echo "▶ Running init.sh (skip cert)..."
cd "$PROJECT_DIR"
./init.sh --skip-cert

echo "▶ Installing ngrok..."
curl -fsSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
  | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo "deb https://ngrok-agent.s3.amazonaws.com buster main" \
  | sudo tee /etc/apt/sources.list.d/ngrok.list
sudo apt update && sudo apt install -y ngrok

echo "▶ Configuring ngrok authtoken..."
ngrok config add-authtoken "$NGROK_AUTHTOKEN"

echo "▶ Creating systemd service for ngrok tunnel..."
SERVICE_FILE="/etc/systemd/system/ngrok-stream.service"
sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=ngrok SmartClean HLS tunnel
After=network-online.target docker.service
Requires=docker.service

[Service]
ExecStart=/usr/bin/ngrok http $LOCAL_PORT --log stdout
Restart=on-failure
User=$USER
Environment=NGROK_AUTHTOKEN=$NGROK_AUTHTOKEN

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable ngrok-stream
sudo systemctl start ngrok-stream

echo "✅ Installation complete!"
echo "⏳ Waiting 5 sec for ngrok to establish tunnel..."
sleep 5
PUBLIC_URL=$(curl -s http://localhost:4040/api/tunnels | grep -Eo 'https://[0-9a-z]+\.ngrok.io')
echo "🌐 Public HLS URL: ${PUBLIC_URL}/cam/index.m3u8"
echo "Embed that in your frontend player."
