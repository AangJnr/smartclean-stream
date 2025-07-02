#!/bin/bash
set -e

### ─────────────── USER‑EDITABLE SECTION ───────────────
PROJECT_DIR="$HOME/smartclean-stream"
REPO_URL="https://github.com/aangjnr/smartclean-stream.git"
NGROK_AUTHTOKEN="5188TJ1YjNSmeJUFAVH8d_56Z2SKuTkopBRMCMtYGCK"  # <<< required
LOCAL_PORT=8080                      # NGINX serves HLS on 8080
### ───────────────────────────────────

export DEBIAN_FRONTEND=noninteractive

echo "▶ Updating system & installing dependencies..."
sudo apt update
sudo apt install -y curl git docker.io docker-compose unzip

echo "▶ Adding '$USER' to docker group..."
sudo usermod -aG docker "$USER" || true
if ! groups | grep -q "\bdocker\b"; then
  echo "⚠️  Docker group not active in this shell. Run 'newgrp docker' and re‑run the script, or just reboot later."
fi

echo "▶ Cloning / updating project repo…"
if [ ! -d "$PROJECT_DIR" ]; then
  git clone "$REPO_URL" "$PROJECT_DIR"
  cd "$PROJECT_DIR"
else
  cd "$PROJECT_DIR"
  git pull
fi

echo "▶ Installing ngrok (if missing)…"
if ! command -v ngrok >/dev/null; then
  curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
    | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
  echo "deb https://ngrok-agent.s3.amazonaws.com buster main" \
    | sudo tee /etc/apt/sources.list.d/ngrok.list
  sudo apt update && sudo apt install -y ngrok
fi

echo "▶ Configuring ngrok authtoken…"
ngrok config add-authtoken "$NGROK_AUTHTOKEN"

# Ensure systemd can find ngrok
if [[ -x "/usr/local/bin/ngrok" && ! -e "/usr/bin/ngrok" ]]; then
  echo "▶ Symlinking ngrok to /usr/bin"
  sudo ln -s /usr/local/bin/ngrok /usr/bin/ngrok
fi

NGROK_BIN=$(command -v ngrok)
if [ -z "$NGROK_BIN" ]; then
  echo "❌ ngrok binary not found. Aborting."
  exit 1
fi

echo "▶ Writing /etc/systemd/system/ngrok-stream.service"
sudo tee /etc/systemd/system/ngrok-stream.service >/dev/null <<EOF
[Unit]
Description=Ngrok SmartClean HLS Tunnel
After=network-online.target docker.service
Requires=docker.service

[Service]
User=$(logname)
ExecStart=${NGROK_BIN} http ${LOCAL_PORT} --log stdout
Restart=on-failure
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[Install]
WantedBy=multi-user.target
EOF

echo "▶ Enabling and (re)starting ngrok-stream.service"
sudo systemctl daemon-reload
sudo systemctl enable ngrok-stream
sudo systemctl restart ngrok-stream

echo "▶ Generating initial placeholder playlist…"
docker compose run --rm -T placeholder

echo "▶ Starting full Docker stack…"
chmod +x init.sh
./init.sh                 # runs: docker compose up -d

echo "▶ Waiting for ngrok tunnel (max 20s)…"
for i in {1..10}; do
  PUBLIC_URL=$(curl -s http://localhost:4040/api/tunnels | grep -Eo 'https://[a-z0-9.-]+\.ngrok\.io' | head -n1)
  [ -n "$PUBLIC_URL" ] && break
  sleep 2
done

if [ -n "$PUBLIC_URL" ]; then
  echo ""
  echo "✅ Public HLS stream ready!"
  echo "👉  ${PUBLIC_URL}/cam/index.m3u8"
  echo ""
else
  echo "❌ ngrok tunnel not detected."
  echo "   Check with:  sudo journalctl -u ngrok-stream -f"
fi