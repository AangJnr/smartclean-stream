#!/bin/bash
set -e

### ─────────────── USER‑EDITABLE SECTION ───────────────
PROJECT_DIR="$HOME/smartclean-stream"
REPO_URL="https://github.com/aangjnr/smartclean-stream.git"
NGROK_AUTHTOKEN="5188TJ1YjNSmeJUFAVH8d_56Z2SKuTkopBRMCMtYGCK"  # <<< required
LOCAL_PORT=8888                                 # MediaMTX HLS port
### ─────────────────────────────────────────────────────

echo "▶ Updating system & installing dependencies..."
export DEBIAN_FRONTEND=noninteractive

sudo apt update
sudo apt install -y curl git docker.io docker-compose unzip

echo "▶ Adding user '$USER' to docker group..."
sudo usermod -aG docker "$USER" || true

# Auto-reload groups without logout
if ! groups | grep -q "\bdocker\b"; then
  echo "⚠️  Docker group not active. Run: newgrp docker"
fi

# Create project directory if missing
if [ ! -d "$PROJECT_DIR" ]; then
  echo "▶ Cloning project..."
  git clone https://github.com/aangjnr/smartclean-stream.git "$PROJECT_DIR"
  cd "$PROJECT_DIR"
else
  cd "$PROJECT_DIR"
  git pull

  echo "▶ Using existing project directory"
fi


echo "▶ Checking ngrok..."
if ! command -v ngrok &> /dev/null; then
  echo "▶ Installing ngrok..."
  curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
    | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
  echo "deb https://ngrok-agent.s3.amazonaws.com buster main" \
    | sudo tee /etc/apt/sources.list.d/ngrok.list
  sudo apt update && sudo apt install -y ngrok
fi

# Add token only if config missing
if [ ! -f "$HOME/.config/ngrok/ngrok.yml" ]; then
  echo "▶ Adding ngrok authtoken..."
  ngrok config add-authtoken "$NGROK_AUTHTOKEN"
fi

# Symlink ngrok if not visible to systemd
if [[ -x "/usr/local/bin/ngrok" && ! -e "/usr/bin/ngrok" ]]; then
  echo "▶ Symlinking ngrok..."
  sudo ln -s /usr/local/bin/ngrok /usr/bin/ngrok
fi

# Detect real ngrok binary
NGROK_BIN=$(command -v ngrok)
if [ -z "$NGROK_BIN" ]; then
  echo "❌ ngrok not found in path."
  exit 1
fi
echo "✅ ngrok found at $NGROK_BIN"

# Create or update systemd service
NGUSER=$(logname)
echo "▶ Writing ngrok-stream.service..."

sudo tee /etc/systemd/system/ngrok-stream.service >/dev/null <<EOF
[Unit]
Description=ngrok SmartClean HLS Tunnel
After=network-online.target docker.service
Requires=docker.service

[Service]
User=$NGUSER
ExecStart=$NGROK_BIN http $LOCAL_PORT --log stdout
Restart=on-failure
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[Install]
WantedBy=multi-user.target
EOF

echo "▶ Reloading systemd & enabling ngrok service..."
sudo systemctl daemon-reload
sudo systemctl enable ngrok-stream
sudo systemctl restart ngrok-stream

echo "▶ Starting stream stack..."
chmod +x init.sh
./init.sh

# Wait for ngrok
echo "▶ Waiting for ngrok tunnel to be ready..."
for i in {1..10}; do
  PUBLIC_URL=$(curl -s http://localhost:4040/api/tunnels | grep -Eo "https://[a-z0-9]+\.ngrok\.io" | head -n1)
  [ -n "$PUBLIC_URL" ] && break
  sleep 2
done

if [ -n "$PUBLIC_URL" ]; then
  echo "✅ HLS stream is public at:"
  echo "👉  $PUBLIC_URL/cam/index.m3u8"
else
  echo "❌ ngrok tunnel could not be detected. Run:"
  echo "   sudo journalctl -u ngrok-stream -f"
fi