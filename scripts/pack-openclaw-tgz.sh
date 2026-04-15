#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCE_DIR="$WORKSPACE_DIR/openclaw"
OUTPUT_DIR="$WORKSPACE_DIR"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "[pack-openclaw] Package source directory not found: $SOURCE_DIR"
  exit 1
fi

cd "$SOURCE_DIR"

log() {
  echo "[pack-openclaw] $*"
}

log_success() {
  local green reset
  green="$(printf '\033[0;32m')"
  reset="$(printf '\033[0m')"
  echo "${green}[pack-openclaw] $*${reset}"
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

ensure_apt_available() {
  if ! has_cmd apt-get; then
    log "apt-get not found; cannot auto-install dependencies."
    log "Please install the following tools on Debian/Ubuntu and retry:"
    log "  sudo apt-get update -y"
    log "  sudo apt-get install -y curl ca-certificates gnupg"
    log "  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -"
    log "  sudo apt-get install -y nodejs"
    log "  sudo npm install -g corepack"
    log "  corepack enable && corepack prepare pnpm@latest --activate"
    exit 1
  fi
}

ensure_node_22() {
  if has_cmd node; then
    local major
    major="$(node -p "process.versions.node.split('.')[0]")"
    if [[ "$major" -ge 22 ]]; then
      log "Node.js requirement satisfied: $(node -v)"
      return
    fi
    log "Node.js version too old: $(node -v), upgrading to 22.x"
  else
    log "Node.js not found, installing 22.x"
  fi

  ensure_apt_available
  if [[ "${EUID}" -ne 0 ]] && ! has_cmd sudo; then
    log "Root/sudo is required to install Node.js, but sudo is unavailable."
    exit 1
  fi

  local run
  if [[ "${EUID}" -eq 0 ]]; then
    run=""
  else
    run="sudo"
  fi

  $run apt-get update -y
  $run apt-get install -y ca-certificates curl gnupg
  curl -fsSL https://deb.nodesource.com/setup_22.x | $run -E bash -
  $run apt-get install -y nodejs
  log "Node.js installation completed: $(node -v)"
}

ensure_npm() {
  if has_cmd npm; then
    log "npm is available: $(npm -v)"
    return
  fi
  log "npm is missing, reinstalling via Node.js setup"
  ensure_node_22
  if ! has_cmd npm; then
    log "npm is still unavailable; please verify Node.js installation manually."
    exit 1
  fi
}

ensure_pnpm() {
  if has_cmd pnpm; then
    log "pnpm is available: $(pnpm -v)"
    return
  fi

  if ! has_cmd corepack; then
    log "corepack is missing, installing via npm"
    npm install -g corepack
  fi

  corepack enable
  corepack prepare pnpm@latest --activate

  if ! has_cmd pnpm; then
    log "pnpm installation failed; please check manually."
    exit 1
  fi
  log "pnpm installation completed: $(pnpm -v)"
}

install_dependencies() {
  if [[ ! -d node_modules ]]; then
    log "node_modules not found, installing dependencies"
    pnpm install
    return
  fi

  log "node_modules already exists, skipping dependency install"
}

expected_tarball_name() {
  if ! has_cmd node; then
    return 1
  fi
  node -e 'const p=require("./package.json");const n=String(p.name||"package").replace(/^@/,"").replace(/\//g,"-");const v=String(p.version||"0.0.0");console.log(`${n}-${v}.tgz`);'
}

resolve_tarball_path() {
  local expected
  expected="$(expected_tarball_name || true)"

  if [[ -n "$expected" && -f "$SOURCE_DIR/$expected" ]]; then
    echo "$SOURCE_DIR/$expected"
    return 0
  fi

  local candidates=("$SOURCE_DIR"/*.tgz)
  if [[ ${#candidates[@]} -eq 0 || ! -f "${candidates[0]}" ]]; then
    return 1
  fi

  ls -t "$SOURCE_DIR"/*.tgz | sed -n '1p'
}

pack_tgz_once() {
  log "Start packing openclaw (.tgz)"
  npm pack
}

finalize_tarball() {
  local tarball_path tarball target
  tarball_path="$(resolve_tarball_path || true)"
  if [[ -z "$tarball_path" || ! -f "$tarball_path" ]]; then
    log "No .tgz file found after packing; aborting."
    exit 1
  fi

  tarball="$(basename "$tarball_path")"
  target="$OUTPUT_DIR/$tarball"
  mv -f "$tarball_path" "$target"
  log_success "Packing completed: $target"
}

main() {
  log "Checking and preparing build environment"
  ensure_node_22
  ensure_npm
  ensure_pnpm
  install_dependencies

  log "Environment is ready, running npm pack"
  pack_tgz_once
  finalize_tarball
}

main "$@"
