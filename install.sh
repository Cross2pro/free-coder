#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

REPO="${FREE_CODE_REPO:-paoloanzn/free-code}"
VERSION="${FREE_CODE_VERSION:-latest}"
INSTALL_ROOT="${FREE_CODE_HOME:-$HOME/.free-code}"
BIN_DIR="${FREE_CODE_BIN_DIR:-$HOME/.local/bin}"
SOURCE_DIR="$INSTALL_ROOT/src"
BUN_MIN_VERSION="1.3.11"

info()  { printf "${CYAN}[*]${RESET} %s\n" "$*"; }
ok()    { printf "${GREEN}[+]${RESET} %s\n" "$*"; }
warn()  { printf "${YELLOW}[!]${RESET} %s\n" "$*"; }
fail()  { printf "${RED}[x]${RESET} %s\n" "$*"; exit 1; }

header() {
  echo ""
  printf "${BOLD}${CYAN}"
  cat << 'ART'
   ___                            _
  / _|_ __ ___  ___        ___ __| | ___
 | |_| '__/ _ \/ _ \_____ / __/ _` |/ _ \
 |  _| | |  __/  __/_____| (_| (_| |  __/
 |_| |_|  \___|\___|      \___\__,_|\___|

ART
  printf "${RESET}"
  printf "${DIM}  Prebuilt installer for free-code${RESET}\n"
  echo ""
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "Missing required command: $1"
  fi
}

download_file() {
  local url="$1"
  local out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$out"
    return
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -qO "$out" "$url"
    return
  fi
  fail "curl or wget is required to download release artifacts."
}

detect_platform() {
  case "$(uname -s)" in
    Darwin) OS="macos" ;;
    Linux) OS="linux" ;;
    *) fail "Unsupported OS: $(uname -s). Use install.ps1 on Windows." ;;
  esac

  case "$(uname -m)" in
    x86_64|amd64) ARCH="x64" ;;
    arm64|aarch64) ARCH="arm64" ;;
    *) fail "Unsupported architecture: $(uname -m)" ;;
  esac

  LIBC=""
  if [ "$OS" = "linux" ]; then
    if command -v ldd >/dev/null 2>&1 && ldd --version 2>&1 | grep -qi musl; then
      LIBC="musl"
    elif [ -e /lib/ld-musl-x86_64.so.1 ] || [ -e /lib/ld-musl-aarch64.so.1 ] || [ -e /usr/bin/ldd ] && /usr/bin/ldd --version 2>&1 | grep -qi musl; then
      LIBC="musl"
    else
      LIBC="glibc"
    fi
  fi

  if [ "$OS" = "linux" ] && [ "$LIBC" = "musl" ]; then
    ASSET_NAME="free-code-linux-${ARCH}-musl.tar.gz"
  elif [ "$OS" = "linux" ]; then
    ASSET_NAME="free-code-linux-${ARCH}.tar.gz"
  else
    ASSET_NAME="free-code-macos-${ARCH}.tar.gz"
  fi

  ok "Platform: $OS/$ARCH${LIBC:+ ($LIBC)}"
}

release_url() {
  if [ "$VERSION" = "latest" ]; then
    printf 'https://github.com/%s/releases/latest/download/%s' "$REPO" "$ASSET_NAME"
  else
    printf 'https://github.com/%s/releases/download/%s/%s' "$REPO" "$VERSION" "$ASSET_NAME"
  fi
}

install_from_release() {
  local tmp_dir archive url extracted_dir
  tmp_dir="$(mktemp -d)"
  archive="$tmp_dir/$ASSET_NAME"
  url="$(release_url)"

  info "Downloading prebuilt package..."
  if ! download_file "$url" "$archive"; then
    rm -rf "$tmp_dir"
    return 1
  fi

  extracted_dir="$tmp_dir/extract"
  mkdir -p "$extracted_dir"
  tar -xzf "$archive" -C "$extracted_dir"

  mkdir -p "$INSTALL_ROOT/bin" "$BIN_DIR"
  install -m 755 "$extracted_dir/free-code/free-code" "$INSTALL_ROOT/bin/free-code"
  ln -sf "$INSTALL_ROOT/bin/free-code" "$BIN_DIR/free-code"

  rm -rf "$tmp_dir"
  ok "Installed prebuilt binary to $INSTALL_ROOT/bin/free-code"
  return 0
}

version_gte() {
  [ "$(printf '%s\n' "$1" "$2" | sort -V | head -1)" = "$2" ]
}

install_bun() {
  info "Installing Bun for source fallback..."
  curl -fsSL https://bun.sh/install | bash
  export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
  export PATH="$BUN_INSTALL/bin:$PATH"
  command -v bun >/dev/null 2>&1 || fail "Bun install completed but bun is not on PATH."
}

ensure_bun() {
  if command -v bun >/dev/null 2>&1; then
    local ver
    ver="$(bun --version 2>/dev/null || echo "0.0.0")"
    if version_gte "$ver" "$BUN_MIN_VERSION"; then
      ok "bun: v${ver}"
      return
    fi
    warn "bun v${ver} is too old. Upgrading..."
  fi
  install_bun
}

install_from_source() {
  need_cmd git
  ensure_bun

  if [ -d "$SOURCE_DIR/.git" ]; then
    info "Updating existing source checkout..."
    git -C "$SOURCE_DIR" pull --ff-only origin main || warn "git pull failed, using existing source"
  else
    info "Cloning source repository..."
    mkdir -p "$INSTALL_ROOT"
    git clone --depth 1 "https://github.com/$REPO.git" "$SOURCE_DIR"
  fi

  info "Building from source..."
  (
    cd "$SOURCE_DIR"
    bun install --frozen-lockfile 2>/dev/null || bun install
    bun run build:dev:full
  )

  mkdir -p "$INSTALL_ROOT/bin" "$BIN_DIR"
  install -m 755 "$SOURCE_DIR/cli-dev" "$INSTALL_ROOT/bin/free-code"
  ln -sf "$INSTALL_ROOT/bin/free-code" "$BIN_DIR/free-code"
  ok "Installed source-built binary to $INSTALL_ROOT/bin/free-code"
}

final_notes() {
  if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
    warn "$BIN_DIR is not on your PATH."
    printf "${BOLD}Add this to your shell profile:${RESET}\n"
    printf "  export PATH=\"%s:\$PATH\"\n" "$BIN_DIR"
  fi

  echo ""
  printf "${GREEN}${BOLD}  Installation complete!${RESET}\n"
  echo ""
  printf "  ${BOLD}Run it:${RESET}\n"
  printf "    ${CYAN}free-code${RESET}\n"
  printf "    ${CYAN}free-code -p \"your prompt\"${RESET}\n"
  echo ""
  printf "  ${BOLD}Set your API key:${RESET}\n"
  printf "    ${CYAN}export ANTHROPIC_API_KEY=\"sk-ant-...\"${RESET}\n"
  echo ""
  printf "  ${DIM}Install root: $INSTALL_ROOT${RESET}\n"
  printf "  ${DIM}Link:         $BIN_DIR/free-code${RESET}\n"
  echo ""
}

header
detect_platform

if install_from_release; then
  final_notes
  exit 0
fi

warn "Prebuilt package was unavailable. Falling back to source build."
install_from_source
final_notes
