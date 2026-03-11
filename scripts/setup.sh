#!/usr/bin/env bash
#
# ByteHide Shield iOS — One-liner setup
#
# Usage:
#   bash <(curl -sL https://raw.githubusercontent.com/bytehide/shield-ios/main/scripts/setup.sh)
#
# What it does:
#   1. Installs shield-ios CLI (if not present)
#   2. Installs xcodeproj Ruby gem (if not present)
#   3. Runs setup-xcode.rb to configure your Xcode project
#
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/bytehide/shield-ios/main/scripts"

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${CYAN}[info]${NC}  $*"; }
success() { echo -e "${GREEN}[ok]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[warn]${NC}  $*"; }
error()   { echo -e "${RED}[error]${NC} $*"; exit 1; }

# ── Banner ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   ByteHide Shield iOS — Setup        ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════╝${NC}"
echo ""

# ── Check we're in an Xcode project directory ───────────────────────────────
XCODEPROJ=$(find . -maxdepth 1 -name "*.xcodeproj" -print -quit 2>/dev/null)
if [ -z "$XCODEPROJ" ]; then
  error "No .xcodeproj found in current directory. Run this from your Xcode project root."
fi
success "Found project: ${XCODEPROJ}"

# ── 1. Install shield-ios CLI ───────────────────────────────────────────────
info "Checking shield-ios CLI..."

if command -v shield-ios &>/dev/null; then
  success "shield-ios already installed ($(shield-ios --version 2>/dev/null || echo 'unknown version'))"
else
  warn "shield-ios not found. Installing..."

  if command -v brew &>/dev/null; then
    info "Installing via Homebrew..."
    brew install bytehide/tap/shield-ios && success "shield-ios installed via Homebrew" || true
  fi

  # Fallback / alternative: pip
  if ! command -v shield-ios &>/dev/null; then
    if command -v pip3 &>/dev/null; then
      info "Installing via pip3..."
      pip3 install bytehide-shield-ios
    elif command -v pip &>/dev/null; then
      info "Installing via pip..."
      pip install bytehide-shield-ios
    else
      error "Cannot install shield-ios: neither brew nor pip found.\nInstall manually: pip install bytehide-shield-ios"
    fi
  fi

  # Verify
  if command -v shield-ios &>/dev/null; then
    success "shield-ios installed successfully"
  else
    error "shield-ios installation failed. Install manually: pip install bytehide-shield-ios"
  fi
fi

# ── 2. Install xcodeproj gem ────────────────────────────────────────────────
info "Checking xcodeproj Ruby gem..."

if gem list -i xcodeproj &>/dev/null; then
  success "xcodeproj gem already installed"
else
  warn "xcodeproj gem not found. Installing..."
  gem install xcodeproj || sudo gem install xcodeproj || error "Failed to install xcodeproj gem"
  success "xcodeproj gem installed"
fi

# ── 3. Run setup-xcode.rb ──────────────────────────────────────────────────
info "Running Xcode project setup..."
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_RB="${SCRIPT_DIR}/setup-xcode.rb"

if [ -f "$LOCAL_RB" ]; then
  ruby "$LOCAL_RB"
else
  info "Downloading setup-xcode.rb..."
  TEMP_RB="$(mktemp /tmp/setup-xcode-XXXXXX.rb)"
  curl -sL "${REPO_RAW}/setup-xcode.rb" -o "$TEMP_RB"
  ruby "$TEMP_RB"
  rm -f "$TEMP_RB"
fi
