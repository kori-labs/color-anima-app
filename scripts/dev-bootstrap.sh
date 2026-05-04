#!/usr/bin/env bash
#
# One-step kernel staging for local development.
#
# 1) Fetch + decrypt + verify kernel binary into .local-core/
#    (delegates to scripts/fetch-core-binary.sh — no key handling here).
# 2) Run scripts/verify-core-binary-intake.sh to confirm intake contract.
# 3) Print COLOR_ANIMA_KERNEL_PATH export snippet for sourcing.
# 4) Optional --build: runs swift build --target ColorAnima with env set.
#
# Usage: scripts/dev-bootstrap.sh [--build] [--force] [-h|--help]

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
cd "$REPO_ROOT"

XCFRAMEWORK=".local-core/ColorAnimaKernel.xcframework"
XCFRAMEWORK_ABS="$REPO_ROOT/$XCFRAMEWORK"
STAGED_VERSION_FILE="$REPO_ROOT/.local-core/.staged-version"
METADATA_FILE="$REPO_ROOT/CoreBinary.env"
DO_BUILD=false
DO_FORCE=false

log() {
  printf '==> %s\n' "$*" >&2
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage: scripts/dev-bootstrap.sh [OPTIONS]

Options:
  --build    Run swift build --target ColorAnima after staging.
  --force    Re-fetch kernel even if already staged.
  -h|--help  Print this message and exit.

Environment (consumed by scripts/fetch-core-binary.sh):
  COLOR_ANIMA_KERNEL_DECRYPTION_KEY  Decryption key for the release asset.
                                      If unset, the fetch script tries macOS
                                      Keychain service color-anima-kernel-release-key,
                                      account kori-labs/color-anima.
  GH_TOKEN                            GitHub token for release download.

Output:
  .local-core/ColorAnimaKernel.xcframework

See AGENTS.md -> Kernel binary intake for full setup instructions.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build)  DO_BUILD=true;  shift ;;
    --force)  DO_FORCE=true;  shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'error: unknown option: %s\n' "$1" >&2; printf 'Run with -h for usage.\n' >&2; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Step 1: stage kernel if missing, stale, or --force
# Stale = staged version mismatches CoreBinary.env's COLOR_ANIMA_KERNEL_VERSION.
# ---------------------------------------------------------------------------
expected_version=""
if [[ -f "$METADATA_FILE" ]]; then
  expected_version="$(awk -F= '/^COLOR_ANIMA_KERNEL_VERSION=/{print $2}' "$METADATA_FILE")"
fi

needs_fetch=true
if [[ -d "$XCFRAMEWORK_ABS" ]] && [[ "$DO_FORCE" != "true" ]]; then
  staged_version=""
  [[ -f "$STAGED_VERSION_FILE" ]] && staged_version="$(cat "$STAGED_VERSION_FILE" 2>/dev/null || true)"
  if [[ -n "$expected_version" ]] && [[ "$staged_version" != "$expected_version" ]]; then
    log "kernel staged at $staged_version but CoreBinary.env expects $expected_version — refetching"
  else
    log "kernel already staged at $XCFRAMEWORK (version $staged_version; --force to refetch)"
    needs_fetch=false
  fi
fi

if [[ "$needs_fetch" == "true" ]]; then
  log "staging kernel binary..."
  if ! "$SCRIPT_DIR/fetch-core-binary.sh"; then
    die "fetch failed; check COLOR_ANIMA_KERNEL_DECRYPTION_KEY env or Keychain entry color-anima-kernel-release-key / kori-labs/color-anima — see AGENTS.md -> Kernel binary intake"
  fi
  if [[ -n "$expected_version" ]]; then
    printf '%s' "$expected_version" > "$STAGED_VERSION_FILE"
  fi
fi

# ---------------------------------------------------------------------------
# Step 2: verify intake contract
# ---------------------------------------------------------------------------
log "verifying intake..."
if ! COLOR_ANIMA_KERNEL_PATH="$XCFRAMEWORK" "$SCRIPT_DIR/verify-core-binary-intake.sh"; then
  die "intake verification failed; run scripts/fetch-core-binary.sh manually and check output"
fi

# ---------------------------------------------------------------------------
# Step 3: emit export hint
# ---------------------------------------------------------------------------
printf '\nKernel ready. To build with kernel active:\n'
printf '  export COLOR_ANIMA_KERNEL_PATH="%s"\n' "$XCFRAMEWORK"
printf '  swift build --target ColorAnima\n\n'

# ---------------------------------------------------------------------------
# Step 4: optional build
# ---------------------------------------------------------------------------
if [[ "$DO_BUILD" == "true" ]]; then
  log "running swift build --target ColorAnima..."
  COLOR_ANIMA_KERNEL_PATH="$XCFRAMEWORK" swift build --target ColorAnima
  log "build complete"
fi
