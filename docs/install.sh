#!/usr/bin/env bash
# Citadel Standalone CLI & Autocompletion Installer
# Usage: curl -fsSL https://citadel.kartikarora.me/install.sh | bash

set -euo pipefail

REPO="kartikarora/citadel"
INSTALL_DIR="${HOME}/.local/bin"
ZFUNC_DIR="${HOME}/.zfunc"
FISH_COMP_DIR="${HOME}/.config/fish/completions"
BASH_COMP_DIR="${HOME}/.bash_completion.d"

echo "🏰 Installing Citadel CLI..."

# Check OS
OS="$(uname -s)"
ARCH="$(uname -m)"

if [ "$OS" != "Darwin" ]; then
    echo "❌ Error: Citadel is currently built natively for macOS (Darwin)."
    exit 1
fi

if [ "$ARCH" != "arm64" ] && [ "$ARCH" != "aarch64" ]; then
    echo "⚠️  Note: Citadel is optimized for Apple Silicon (arm64). Installing compatible binary..."
fi

mkdir -p "${INSTALL_DIR}"

# Determine latest release version
echo "==> Resolving latest Citadel release..."
RELEASE_TAG=$(curl -sSL "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || echo "0.1.0")
if [ -z "${RELEASE_TAG}" ]; then
    RELEASE_TAG="0.1.0"
fi
CLEAN_VERSION="${RELEASE_TAG#v}"

TARBALL_URL="https://github.com/${REPO}/releases/download/${RELEASE_TAG}/citadel-${CLEAN_VERSION}-macOS-arm64.tar.gz"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "${TEMP_DIR}"' EXIT

echo "==> Downloading Citadel CLI (${CLEAN_VERSION})..."
if curl -fsSL "${TARBALL_URL}" -o "${TEMP_DIR}/citadel.tar.gz"; then
    tar -xzf "${TEMP_DIR}/citadel.tar.gz" -C "${TEMP_DIR}"
    cp -f "${TEMP_DIR}/citadel" "${INSTALL_DIR}/citadel"
    cp -f "${TEMP_DIR}/ctdl" "${INSTALL_DIR}/ctdl"
    chmod +x "${INSTALL_DIR}/citadel" "${INSTALL_DIR}/ctdl"
else
    echo "==> Fetching from bundled application or release assets..."
    # Fallback to direct binaries if tarball not yet published
    curl -fsSL "https://raw.githubusercontent.com/${REPO}/${RELEASE_TAG}/scripts/install.sh" -o "${TEMP_DIR}/fallback.sh" 2>/dev/null || true
    echo "❌ Could not download release archive from ${TARBALL_URL}."
    echo "Please visit https://citadel.kartikarora.me to download the DMG or build from source."
    exit 1
fi

# Ensure ~/.local/bin is in PATH
CURRENT_SHELL="$(basename "${SHELL:-zsh}")"
RC_FILE="${HOME}/.zshrc"
if [ "${CURRENT_SHELL}" = "bash" ]; then
    RC_FILE="${HOME}/.bashrc"
fi

if ! echo "${PATH}" | tr ':' '\n' | grep -qx "${INSTALL_DIR}"; then
    if [ -f "${RC_FILE}" ]; then
        if ! grep -q 'export PATH=.*\.local/bin' "${RC_FILE}"; then
            echo '' >> "${RC_FILE}"
            echo '# Citadel Local Binaries' >> "${RC_FILE}"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${RC_FILE}"
            echo "==> Added ${INSTALL_DIR} to ${RC_FILE}"
        fi
    fi
fi

# Generate & Install Shell Autocompletions
echo "==> Configuring shell autocompletions..."

# 1. ZSH Autocompletion
if [ -x "${INSTALL_DIR}/citadel" ]; then
    mkdir -p "${ZFUNC_DIR}"
    "${INSTALL_DIR}/citadel" --generate-completion-script zsh > "${ZFUNC_DIR}/_citadel" 2>/dev/null || true
    "${INSTALL_DIR}/ctdl" --generate-completion-script zsh > "${ZFUNC_DIR}/_ctdl" 2>/dev/null || true
    
    ZSHRC="${HOME}/.zshrc"
    if [ -f "${ZSHRC}" ]; then
        if ! grep -q '\.zfunc' "${ZSHRC}"; then
            cat << 'EOF' >> "${ZSHRC}"

# Citadel CLI Autocompletions
if [ -d "$HOME/.zfunc" ]; then
    fpath=("$HOME/.zfunc" $fpath)
    autoload -Uz compinit && compinit -C
fi
EOF
        fi
    fi
fi

# 2. Fish Autocompletion
if [ -d "${HOME}/.config/fish" ] || [ "${CURRENT_SHELL}" = "fish" ]; then
    mkdir -p "${FISH_COMP_DIR}"
    "${INSTALL_DIR}/citadel" --generate-completion-script fish > "${FISH_COMP_DIR}/citadel.fish" 2>/dev/null || true
    "${INSTALL_DIR}/ctdl" --generate-completion-script fish > "${FISH_COMP_DIR}/ctdl.fish" 2>/dev/null || true
fi

# 3. Bash Autocompletion
mkdir -p "${BASH_COMP_DIR}"
"${INSTALL_DIR}/citadel" --generate-completion-script bash > "${BASH_COMP_DIR}/citadel.bash" 2>/dev/null || true
"${INSTALL_DIR}/ctdl" --generate-completion-script bash > "${BASH_COMP_DIR}/ctdl.bash" 2>/dev/null || true

echo "✅ Citadel CLI installed successfully into ${INSTALL_DIR}!"
echo "   - citadel (primary command)"
echo "   - ctdl    (shorthand alias)"
echo ""
echo "💡 To start managing your AI skills immediately:"
echo "   citadel init"
echo ""
echo "🚀 Want the native macOS desktop frontend too? Simply run:"
echo "   citadel app --install"
