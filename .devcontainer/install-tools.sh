#!/bin/bash
set -e

# ---- バージョン定義 ----
TERRAFORM_VERSION="1.10.5"
TERRAGRUNT_VERSION="0.72.3"
TFLINT_VERSION="0.61.0"
AWS_VAULT_VERSION="7.2.0"
# ------------------------

# PulseAudio client (for voice input from macOS host)
echo "[0/12] Installing PulseAudio client..."
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
echo "[0/12] PulseAudio client installed."

# Claude Code
echo "[1/12] Installing Claude Code..."
curl -fsSL https://claude.ai/install.sh | bash
echo "[1/12] Claude Code installed."

# deploy-on-aws plugin (awslabs/agent-plugins)
echo "[2/12] Installing deploy-on-aws plugin..."
claude plugin marketplace add awslabs/agent-plugins
claude plugin install deploy-on-aws@agent-plugins-for-aws --scope user
echo "[2/12] deploy-on-aws plugin installed."

# bubblewrap (required for Codex sandbox)
echo "[3/12] Installing bubblewrap (Codex sandbox dependency)..."
sudo apt-get install -y -qq bubblewrap
echo "[3/12] bubblewrap installed."

# codex (OpenAI Codex CLI)
echo "[4/12] Installing OpenAI Codex CLI..."
npm i -g @openai/codex
echo "[4/12] OpenAI Codex CLI installed."

# uv (Python package manager)
echo "[5/12] Installing uv (Python package manager)..."
curl -LsSf https://astral.sh/uv/install.sh | sh
# Make uv available system-wide
sudo ln -sf "$HOME/.local/bin/uv" /usr/local/bin/uv
sudo ln -sf "$HOME/.local/bin/uvx" /usr/local/bin/uvx
echo "[5/12] uv installed."

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
echo "[6/12] Installing aws-vault..."
sudo curl -fsSL -o /usr/local/bin/aws-vault \
  "https://github.com/99designs/aws-vault/releases/download/v${AWS_VAULT_VERSION}/aws-vault-${VAULT_ARCH}"
sudo chmod +x /usr/local/bin/aws-vault
echo "[6/12] aws-vault installed."

# AWS SSM Session Manager Plugin
echo "[7/12] Installing AWS SSM Session Manager Plugin..."
curl -fsSL "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/${SSM_ARCH}/session-manager-plugin.deb" \
  -o /tmp/session-manager-plugin.deb
sudo dpkg -i /tmp/session-manager-plugin.deb
rm /tmp/session-manager-plugin.deb
echo "[7/12] AWS SSM Session Manager Plugin installed."

# Draw.io MCP
echo "[8/12] Installing Draw.io MCP..."
npm i -g @drawio/mcp
echo "[8/12] Draw.io MCP installed."

# Serena config
echo "[9/12] Setting up Serena config..."
mkdir -p "$HOME/.serena"
cp .devcontainer/serena_config.yml "$HOME/.serena/serena_config.yml"
echo "[9/12] Serena config created."

# AWS CDK CLI
echo "[10/12] Installing AWS CDK CLI..."
npm i -g aws-cdk
echo "[10/12] AWS CDK CLI installed."

# IaC tools (Terraform / tflint / Terragrunt)
echo "[11/12] Installing IaC tools (Terraform, tflint, Terragrunt)..."

# Terraform
curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip" \
  -o /tmp/terraform.zip
sudo unzip -o /tmp/terraform.zip -d /usr/local/bin/
rm /tmp/terraform.zip

# tflint
curl -fsSL "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_${ARCH}.zip" \
  -o /tmp/tflint.zip
sudo unzip -o /tmp/tflint.zip -d /usr/local/bin/
rm /tmp/tflint.zip

# Terragrunt
sudo curl -L -o /usr/local/bin/terragrunt \
  "https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_${ARCH}"
sudo chmod +x /usr/local/bin/terragrunt

echo "[11/12] IaC tools installed."

# terraform-ls (required for Serena Terraform symbol support)
echo "[12/12] Installing terraform-ls..."
TFLSVER=$(curl -s https://api.github.com/repos/hashicorp/terraform-ls/releases/latest | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
curl -fsSL "https://releases.hashicorp.com/terraform-ls/${TFLSVER}/terraform-ls_${TFLSVER}_linux_${ARCH}.zip" \
  -o /tmp/terraform-ls.zip
sudo unzip -o /tmp/terraform-ls.zip -d /usr/local/bin/ terraform-ls
rm /tmp/terraform-ls.zip
echo "[12/12] terraform-ls installed."

# Shell aliases
grep -qxF "alias c='claude'" "$HOME/.bashrc" || echo "alias c='claude'" >> "$HOME/.bashrc"

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
echo "AWS CDK:     $(cdk --version 2>&1 || echo 'not found')"
echo "Terraform:   $(terraform --version 2>&1 | head -1 || echo 'not found')"
echo "tflint:      $(tflint --version 2>&1 | head -1 || echo 'not found')"
echo "Terragrunt:  $(terragrunt --version 2>&1 | head -1 || echo 'not found')"
echo "terraform-ls: $(terraform-ls version 2>&1 | head -1 || echo 'not found')"
echo "=========================="
