#!/bin/bash
set -e

### ─────────────── USER‑EDITABLE SECTION ───────────────
PROJECT_DIR="$HOME/smartclean-stream"
REPO_URL="https://github.com/aangjnr/smartclean-stream.git"
NGROK_AUTHTOKEN="5188TJ1YjNSmeJUFAVH8d_56Z2SKuTkopBRMCMtYGCK"  # <<< required
LOCAL_PORT=8888                      # NGINX serves HLS on 8080
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

if [ ! -d "$PROJECT_DIR" ]; then
  echo "▶ Cloning project repo…"
  git clone "$REPO_URL" "$PROJECT_DIR"
  cd "$PROJECT_DIR"
else
  echo "▶ Updating project repo…"
  cd "$PROJECT_DIR"
  git stash
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

echo "▶ Writing $HOME/.ngrok2/ngrok.yml"
mkdir -p "$HOME/.ngrok2"

sudo tee "$HOME/.ngrok2/ngrok.yml" > /dev/null <<EOF
authtoken: $NGROK_AUTHTOKEN
region: eu

tunnels:
  stream:
    proto: http
    addr: 8888
  ssh:
    proto: tcp
    addr: 22
EOF

echo "▶ Writing /etc/systemd/system/ngrok-stream.service"
sudo tee /etc/systemd/system/ngrok-stream.service >/dev/null <<EOF
[Unit]
Description=Ngrok SmartClean HLS Tunnel plus ssh
After=network-online.target docker.service
Requires=docker.service

[Service]
User=$(logname)
ExecStart=${NGROK_BIN} start --all --config $HOME/.ngrok2/ngrok.yml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF


echo "▶ Writing /etc/systemd/system/docker-watcher.service"
sudo tee /etc/systemd/system/docker-watcher.service >/dev/null <<EOF
[Unit]
Description=Docker‑Watcher — notify webhook with ngrok tunnel
After=network-online.target docker.service
Requires=docker.service

[Service]
ExecStart=$HOME/smartclean-stream/docker-watcher.sh
Restart=always
RestartSec=3
User=$(logname)

[Install]
WantedBy=multi-user.target
EOF



echo "▶ Enabling and (re)starting ngrok-stream.service"
sudo systemctl daemon-reload
sudo systemctl enable ngrok-stream
sudo systemctl enable --now docker-watcher

sudo systemctl restart ngrok-stream



echo "▶ Starting full Docker stack…"
chmod +x init.sh
chmod +x generate-placeholder.sh
chmod +x docker-watcher.sh


./init.sh                 # runs: docker compose up -d

sleep 10
curl -s http://localhost:4040/api/tunnels


##--domain=stallion-engaged-steadily.ngrok-free.app