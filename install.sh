#!/bin/bash
# One-command installer for a fresh Raspberry Pi (Debian-based)
# Usage: curl -sSL https://raw.githubusercontent.com/aangjnr/smartclean-stream/main/install.sh | bash
#!/bin/bash
set -e

PROJECT_DIR="$HOME/smartclean-stream"

echo "▶ Updating system..."
sudo apt update && sudo apt full-upgrade -y

echo "▶ Installing Docker (official)..."
curl -fsSL https://get.docker.com | sh

echo "▶ Adding user to Docker group..."
sudo usermod -aG docker $USER

echo "▶ Installing Git, Curl, Docker Compose..."
sudo apt install -y git curl docker-compose

if [ ! -d "$PROJECT_DIR" ]; then
  echo "▶ Cloning repo..."
  git clone https://github.com/aangjnr/smartclean-stream.git "$PROJECT_DIR"
else
  echo "▶ Repo exists. Pulling latest changes..."
  cd "$PROJECT_DIR"
  git pull
fi

cd "$PROJECT_DIR"
./init.sh
