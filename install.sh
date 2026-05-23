#!/usr/bin/env bash
#
# Cheesyboy installer — https://cheesyboy.dev/install.sh
#
# Run:
#   bash <(curl -fsSL https://cheesyboy.dev/install.sh)
#
# What this does:
#   1. Preflight (macOS, Node ≥ 18, npm, Claude Code CLI)
#   2. npm install -g @selucas12/cheesy
#   3. Hand off to `cheesy init` (Telegram + LemonSqueezy license)
#   4. Print a Complete footer
#
# This script is curl|bash-safe: stdin is the curl pipe, so all interactive
# prompts read from /dev/tty. Re-run any time; it detects an existing install
# and offers reinstall / init-only / cancel.

set -eu

# ── Colors ──────────────────────────────────────────────────────
# Using $'...' so the escape sequences resolve at definition time.
ORANGE=$'\033[38;5;208m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
WHITE=$'\033[97m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

# ── Output helpers ──────────────────────────────────────────────
section() {
  # Orange header line: ──── Title ─────────────…
  printf '\n%s──── %s ─────────────────────────────────────%s\n' \
    "$ORANGE" "$1" "$RESET"
}
ok()    { printf '  %s✓%s %s\n' "$GREEN"  "$RESET" "$1"; }
info()  { printf '  %sℹ%s %s\n' "$ORANGE" "$RESET" "$1"; }
warn()  { printf '  %s⚠%s %s\n' "$YELLOW" "$RESET" "$1"; }
err()   { printf '  %s✗%s %s\n' "$RED"    "$RESET" "$1" >&2; }
hint()  { printf '    %s%s%s\n' "$DIM"    "$1"     "$RESET"; }

# ── Signal handling ─────────────────────────────────────────────
on_interrupt() {
  printf '\n\n  %sInstallation cancelled.%s See you next time.\n\n' \
    "$YELLOW" "$RESET"
  exit 130
}
trap on_interrupt INT

# ── Tty check ───────────────────────────────────────────────────
# When invoked via `bash <(curl …)`, stdin is the curl pipe. We need a
# real tty to prompt the user and to hand off to `cheesy init`.
ensure_tty() {
  if [ ! -e /dev/tty ]; then
    err "/dev/tty unavailable — this installer needs an interactive terminal."
    hint "Don't run inside a non-interactive container or CI job."
    exit 1
  fi
}

# ── ASCII mascot ────────────────────────────────────────────────
# Chunky 14-row sitting tabby. Orange body, white chest/belly.
# Block characters only (█▄░ + space) so any monospace font renders cleanly.
cat_logo() {
  local O="$ORANGE" W="$WHITE" R="$RESET"
  printf '\n'
  printf '       %s▄██▄       ▄██▄%s\n'                "$O" "$R"
  printf '      %s██████     ██████%s\n'                "$O" "$R"
  printf '     %s██████████████████████%s\n'            "$O" "$R"
  printf '    %s██████████████████████████%s\n'         "$O" "$R"
  printf '   %s██████████████████████████████%s\n'      "$O" "$R"
  printf '   %s████  ██████████████████  ████%s\n'      "$O" "$R"
  printf '   %s██████████████████████████████%s\n'      "$O" "$R"
  printf '   %s████████████  ██  ████████████%s\n'      "$O" "$R"
  printf '    %s██████████████████████████%s\n'         "$O" "$R"
  printf '     %s████%s░░░░░░░░░░░░░░░░░░%s████%s\n'    "$O" "$W" "$O" "$R"
  printf '      %s██%s░░░░░░░░░░░░░░░░░░░░%s██%s\n'     "$O" "$W" "$O" "$R"
  printf '      %s██%s░░░░░░░░░░░░░░░░░░░░%s██%s\n'     "$O" "$W" "$O" "$R"
  printf '       %s████%s░░░░░░░░░░░░░░%s████%s\n'      "$O" "$W" "$O" "$R"
  printf '      %s██████%s          %s██████%s\n'       "$O" "$DIM" "$O" "$R"
  printf '\n'
}

# ── Existing install detection ──────────────────────────────────
MODE=fresh   # fresh | reinstall | init-only
check_existing() {
  local has_cli="" has_env=""
  command -v cheesy >/dev/null 2>&1 && has_cli=yes
  [ -f "$HOME/.ccgram/.env" ] && has_env=yes

  if [ -z "$has_cli" ] && [ -z "$has_env" ]; then
    return 0
  fi

  if [ -n "$has_cli" ]; then
    local cli_path version
    cli_path=$(command -v cheesy)
    version=$(cheesy --version 2>/dev/null || echo "unknown")
    info "Cheesyboy is already installed at $cli_path (v$version)"
  else
    info "Cheesyboy config exists at ~/.ccgram/.env (CLI not on PATH)"
  fi

  echo
  echo "    1. Reinstall (overwrites)"
  echo "    2. Just run init again (keep current install)"
  echo "    3. Cancel"
  echo
  printf '    %sChoice [3]:%s ' "$ORANGE" "$RESET"
  local choice=""
  read -r choice < /dev/tty || choice=3
  choice="${choice:-3}"

  case "$choice" in
    1) MODE=reinstall ;;
    2) MODE=init-only ;;
    *) printf '\n  Cancelled.\n\n'; exit 0 ;;
  esac
}

# ── Preflight ───────────────────────────────────────────────────
preflight() {
  section "Preflight"

  # macOS only — friendly off-ramps for Linux/Windows.
  case "$(uname -s)" in
    Darwin)
      ok "macOS"
      ;;
    Linux)
      warn "Linux support is on the roadmap."
      hint "Track at https://cheesyboy.dev for updates."
      exit 0
      ;;
    *)
      err "Windows is not supported."
      hint "Cheesyboy needs Claude Code on macOS."
      exit 1
      ;;
  esac

  # Node ≥ 18
  if ! command -v node >/dev/null 2>&1; then
    err "Node not found."
    hint "Install Node 18+ from https://nodejs.org and rerun."
    exit 1
  fi
  local node_v node_major
  node_v=$(node -v | sed 's/^v//')
  node_major="${node_v%%.*}"
  if [ "$node_major" -lt 18 ]; then
    err "Node v$node_v is too old."
    hint "Install Node 18+ from https://nodejs.org and rerun."
    exit 1
  fi
  ok "Node 18+ (v$node_v)"

  # npm
  if ! command -v npm >/dev/null 2>&1; then
    err "npm not found."
    hint "Install Node from https://nodejs.org and rerun."
    exit 1
  fi
  ok "npm available"

  # Claude Code CLI
  if ! command -v claude >/dev/null 2>&1; then
    err "Claude Code CLI not found."
    hint "Install Claude Code from https://claude.com/claude-code first, then rerun."
    exit 1
  fi
  ok "Claude Code CLI found"
}

# ── Install ─────────────────────────────────────────────────────
install_cli() {
  section "Install"
  info "Installing @selucas12/cheesy via npm…"
  echo

  # Stream npm output to the user — they should see progress.
  # `< /dev/null` so npm doesn't try to read from the curl pipe.
  if ! npm install -g @selucas12/cheesy </dev/null; then
    echo
    err "npm install failed."
    hint "If you saw EACCES errors, your npm prefix needs to be writable without sudo."
    hint "See: https://docs.npmjs.com/resolving-eacces-permissions-errors"
    exit 1
  fi

  # Refresh the shell's command cache so the just-installed binary resolves.
  hash -r 2>/dev/null || true

  local installed_v
  installed_v=$(cheesy --version 2>/dev/null || echo "?")
  echo
  ok "Installed cheesy CLI (v$installed_v)"
}

# ── Setup handoff ───────────────────────────────────────────────
run_init() {
  section "Setup"
  printf "  Running %scheesy init%s — you'll be asked for your bot token,\n" \
    "$BOLD" "$RESET"
  printf '  chat ID, and license key.\n\n'

  # Hand stdin to the real tty so the wizard's prompts work even though
  # install.sh's own stdin is the curl pipe.
  if ! cheesy init < /dev/tty; then
    local code=$?
    echo
    warn "cheesy init exited with code $code."
    hint "Re-run cheesy init any time to finish setup."
    exit "$code"
  fi
}

# ── Complete ────────────────────────────────────────────────────
print_complete() {
  section "Complete"
  ok "Cheesyboy is installed."
  printf '  Open Telegram and message your bot to verify.\n'
  printf '  %sNeed help? https://cheesyboy.dev/help%s\n\n' "$DIM" "$RESET"
}

# ── Main ────────────────────────────────────────────────────────
main() {
  ensure_tty

  cat_logo
  printf '  %s%sCheesyboy installer%s\n' "$BOLD" "$ORANGE" "$RESET"
  printf '  %sControl Claude Code from Telegram%s\n' "$DIM" "$RESET"
  echo

  check_existing
  preflight

  case "$MODE" in
    init-only)
      section "Install"
      info "Skipping npm install — existing install kept."
      ;;
    *)
      install_cli
      ;;
  esac

  run_init
  print_complete
}

main "$@"
