#!/bin/bash
set -e

# PulseAudio client (for voice input from macOS host)
echo "[0/7] Installing PulseAudio client..."
sudo apt-get update -qq && sudo apt-get install -y -qq pulseaudio-utils libsox-fmt-pulse libasound2-plugins
# Route ALSA through PulseAudio so sox uses PulseAudio by default
cat <<'ASOUNDRC' > "$HOME/.asoundrc"
pcm.!default {
    type pulse
}
ctl.!default {
    type pulse
}
ASOUNDRC
echo "[0/7] PulseAudio client installed."

# Claude Code
echo "[1/7] Installing Claude Code..."
curl -fsSL https://claude.ai/install.sh | bash
echo "[1/7] Claude Code installed."

# codex (OpenAI Codex CLI)
echo "[2/7] Installing OpenAI Codex CLI..."
npm i -g @openai/codex
echo "[2/7] OpenAI Codex CLI installed."

# uv (Python package manager)
echo "[3/7] Installing uv (Python package manager)..."
curl -LsSf https://astral.sh/uv/install.sh | sh
# Make uv available system-wide
sudo ln -sf "$HOME/.local/bin/uv" /usr/local/bin/uv
sudo ln -sf "$HOME/.local/bin/uvx" /usr/local/bin/uvx
echo "[3/7] uv installed."

# Detect architecture
ARCH=$(dpkg --print-architecture)
if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
  VAULT_ARCH="linux-arm64"
  SSM_ARCH="ubuntu_arm64"
else
  VAULT_ARCH="linux-amd64"
  SSM_ARCH="ubuntu_64bit"
fi

# aws-vault
echo "[4/7] Installing aws-vault..."
sudo curl -L -o /usr/local/bin/aws-vault \
  "https://github.com/99designs/aws-vault/releases/latest/download/aws-vault-${VAULT_ARCH}"
sudo chmod +x /usr/local/bin/aws-vault
echo "[4/7] aws-vault installed."

# AWS SSM Session Manager Plugin
echo "[5/7] Installing AWS SSM Session Manager Plugin..."
curl -fsSL "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/${SSM_ARCH}/session-manager-plugin.deb" \
  -o /tmp/session-manager-plugin.deb
sudo dpkg -i /tmp/session-manager-plugin.deb
rm /tmp/session-manager-plugin.deb
echo "[5/7] AWS SSM Session Manager Plugin installed."

# Draw.io MCP
echo "[6/7] Installing Draw.io MCP..."
npm i -g @drawio/mcp
echo "[6/7] Draw.io MCP installed."

# Serena config
echo "[7/7] Setting up Serena config..."
mkdir -p "$HOME/.serena"
cp .devcontainer/serena_config.yml "$HOME/.serena/serena_config.yml"
echo "[6/6] Serena config created."

# Shell aliases
echo "alias c='claude --allow-dangerously-skip-permissions'" >> "$HOME/.bashrc"

echo "All tools installed successfully."

# Version check
echo ""
echo "=== Installed versions ==="
echo "Claude Code: $(claude --version 2>&1 || echo 'not found')"
echo "Codex:       $(codex --version 2>&1 || echo 'not found')"
echo "uv:          $(uv --version 2>&1 || echo 'not found')"
echo "aws-vault:   $(aws-vault --version 2>&1 || echo 'not found')"
echo "SSM Plugin:  $(session-manager-plugin --version 2>&1 || echo 'not found')"
echo "Draw.io MCP: $(npm ls -g @drawio/mcp --depth=0 2>/dev/null | grep @drawio/mcp || echo 'installed')"
echo "Docker CLI:  $(docker --version 2>&1 || echo 'not found')"
echo "docker compose: $(docker compose version 2>&1 || echo 'not found')"
echo "=========================="
