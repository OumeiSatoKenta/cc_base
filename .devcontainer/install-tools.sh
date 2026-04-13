#!/bin/bash
set -e

# ---- バージョン定義 ----
TERRAFORM_VERSION="1.10.5"
TERRAGRUNT_VERSION="0.72.3"
# ------------------------

# PulseAudio client (for voice input from macOS host)
echo "[0/11] Installing PulseAudio client..."
sudo apt-get update -qq && sudo apt-get install -y -qq pulseaudio-utils libsox-fmt-pulse libasound2-plugins unzip
# Route ALSA through PulseAudio so sox uses PulseAudio by default
cat <<'ASOUNDRC' > "$HOME/.asoundrc"
pcm.!default {
    type pulse
}
ctl.!default {
    type pulse
}
ASOUNDRC
echo "[0/11] PulseAudio client installed."

# Claude Code
echo "[1/11] Installing Claude Code..."
curl -fsSL https://claude.ai/install.sh | bash
echo "[1/11] Claude Code installed."

# deploy-on-aws plugin (awslabs/agent-plugins)
echo "[2/11] Installing deploy-on-aws plugin..."
claude plugin marketplace add awslabs/agent-plugins
claude plugin install deploy-on-aws@agent-plugins-for-aws --scope user
echo "[2/11] deploy-on-aws plugin installed."

# bubblewrap (required for Codex sandbox)
echo "[3/11] Installing bubblewrap (Codex sandbox dependency)..."
sudo apt-get install -y -qq bubblewrap
echo "[3/11] bubblewrap installed."

# codex (OpenAI Codex CLI)
echo "[4/11] Installing OpenAI Codex CLI..."
npm i -g @openai/codex
echo "[4/11] OpenAI Codex CLI installed."

# uv (Python package manager)
echo "[5/11] Installing uv (Python package manager)..."
curl -LsSf https://astral.sh/uv/install.sh | sh
# Make uv available system-wide
sudo ln -sf "$HOME/.local/bin/uv" /usr/local/bin/uv
sudo ln -sf "$HOME/.local/bin/uvx" /usr/local/bin/uvx
echo "[5/11] uv installed."

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
echo "[6/11] Installing aws-vault..."
sudo curl -L -o /usr/local/bin/aws-vault \
  "https://github.com/99designs/aws-vault/releases/latest/download/aws-vault-${VAULT_ARCH}"
sudo chmod +x /usr/local/bin/aws-vault
echo "[6/11] aws-vault installed."

# AWS SSM Session Manager Plugin
echo "[7/11] Installing AWS SSM Session Manager Plugin..."
curl -fsSL "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/${SSM_ARCH}/session-manager-plugin.deb" \
  -o /tmp/session-manager-plugin.deb
sudo dpkg -i /tmp/session-manager-plugin.deb
rm /tmp/session-manager-plugin.deb
echo "[7/11] AWS SSM Session Manager Plugin installed."

# Draw.io MCP
echo "[8/11] Installing Draw.io MCP..."
npm i -g @drawio/mcp
echo "[8/11] Draw.io MCP installed."

# Serena config
echo "[9/11] Setting up Serena config..."
mkdir -p "$HOME/.serena"
cp .devcontainer/serena_config.yml "$HOME/.serena/serena_config.yml"
echo "[9/11] Serena config created."

# IaC tools (Terraform / tflint / Terragrunt)
echo "[10/11] Installing IaC tools (Terraform, tflint, Terragrunt)..."

# Terraform
curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip" \
  -o /tmp/terraform.zip
sudo unzip -o /tmp/terraform.zip -d /usr/local/bin/
rm /tmp/terraform.zip

# tflint
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# Terragrunt
sudo curl -L -o /usr/local/bin/terragrunt \
  "https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_${ARCH}"
sudo chmod +x /usr/local/bin/terragrunt

echo "[10/11] IaC tools installed."

# terraform-ls (required for Serena Terraform symbol support)
echo "[11/11] Installing terraform-ls..."
TFLSVER=$(curl -s https://api.github.com/repos/hashicorp/terraform-ls/releases/latest | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
curl -fsSL "https://releases.hashicorp.com/terraform-ls/${TFLSVER}/terraform-ls_${TFLSVER}_linux_${ARCH}.zip" \
  -o /tmp/terraform-ls.zip
sudo unzip -o /tmp/terraform-ls.zip -d /usr/local/bin/ terraform-ls
rm /tmp/terraform-ls.zip
echo "[11/11] terraform-ls installed."

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
echo "Terraform:   $(terraform --version 2>&1 | head -1 || echo 'not found')"
echo "tflint:      $(tflint --version 2>&1 | head -1 || echo 'not found')"
echo "Terragrunt:  $(terragrunt --version 2>&1 | head -1 || echo 'not found')"
echo "terraform-ls: $(terraform-ls version 2>&1 | head -1 || echo 'not found')"
echo "=========================="
