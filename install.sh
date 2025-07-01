#!/bin/bash
# One-command installer for a fresh Raspberry Pi (Debian-based)
# Usage: curl -sSL https://raw.githubusercontent.com/aangjnr/smartclean-stream/main/install.sh | bash
#!/bin/bash
set -e

PROJECT_DIR="$HOME/smartclean-stream"
REPO_URL="https://github.com/aangjnr/smartclean-stream.git"
DOMAIN="stream.smartclean.link"         # set once here

echo "▶ Updating system..."
sudo apt update && sudo apt full-upgrade -y

echo "▶ Installing Docker..."
curl -fsSL https://get.docker.com | sh

echo "▶ Installing Git, Curl, Docker Compose..."
sudo apt install -y git curl docker-compose

echo "▶ Adding user to docker group..."
sudo usermod -aG docker $USER

# ------------------------------------------------------------------
# **Refresh group membership for current script** (no logout needed)
echo "▶ Refreshing group membership..."
newgrp docker <<'EOF'
set -e

PROJECT_DIR="$HOME/smartclean-stream"
REPO_URL="https://github.com/aangjnr/smartclean-stream.git"

if [ ! -d "$PROJECT_DIR" ]; then
  echo "▶ Cloning repo..."
  git clone "$REPO_URL" "$PROJECT_DIR"
else
  echo "▶ Pulling latest changes..."
  cd "$PROJECT_DIR"
  git pull
fi

cd "$PROJECT_DIR"

# Pass domain down to init.sh via environment
export STREAM_DOMAIN="stream.smartclean.link"

./init.sh --skip-cert-check
EOF
# ------------------------------------------------------------------

echo "✅ All done!  If you open a new terminal you’ll have docker access automatically."