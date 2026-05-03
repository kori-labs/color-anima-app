#!/usr/bin/env bash
#
# Download and decrypt the maintainer ColorAnimaKernel release asset into
# .local-core/ so Package.swift can consume it through COLOR_ANIMA_KERNEL_PATH.

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
cd "$REPO_ROOT"

METADATA_FILE="CoreBinary.env"
LOCAL_ASSET_FILE=""
OUTPUT_DIR="$REPO_ROOT/.local-core"
KEYCHAIN_SERVICE="color-anima-kernel-release-key"
KEYCHAIN_ACCOUNT="kori-labs/color-anima"

usage() {
  cat <<'USAGE'
Usage: scripts/fetch-core-binary.sh [--metadata CoreBinary.env] [--asset-file PATH]

Environment:
  COLOR_ANIMA_KERNEL_DECRYPTION_KEY  Required to decrypt the release asset.
                                      If unset, the script tries macOS Keychain
                                      service color-anima-kernel-release-key.
  GH_TOKEN                            GitHub token for release download. CI uses
                                      the app repo GITHUB_TOKEN because the
                                      encrypted asset is mirrored to this repo.

Output:
  .local-core/ColorAnimaKernel.xcframework

--asset-file skips GitHub download and uses an existing encrypted asset. It is
intended for maintainer pre-upload verification.
USAGE
}

log() {
  printf '==> %s\n' "$*" >&2
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || die "required tool '$1' not found on PATH"
}

load_decryption_key() {
  if [[ -n "${COLOR_ANIMA_KERNEL_DECRYPTION_KEY:-}" ]]; then
    return
  fi
  if command -v security >/dev/null 2>&1; then
    local key
    if key="$(security find-generic-password -a "$KEYCHAIN_ACCOUNT" -s "$KEYCHAIN_SERVICE" -w 2>/dev/null)"; then
      export COLOR_ANIMA_KERNEL_DECRYPTION_KEY="$key"
      log "loaded decryption key from macOS Keychain"
      return
    fi
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --metadata)
      METADATA_FILE="${2:-}"
      shift 2
      ;;
    --asset-file)
      LOCAL_ASSET_FILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

for tool in openssl shasum unzip; do
  require_tool "$tool"
done
if [[ -z "$LOCAL_ASSET_FILE" ]]; then
  require_tool gh
fi

[[ -f "$METADATA_FILE" ]] || die "metadata file not found: $METADATA_FILE"
if [[ -n "$LOCAL_ASSET_FILE" && ! -f "$LOCAL_ASSET_FILE" ]]; then
  die "local encrypted asset not found: $LOCAL_ASSET_FILE"
fi
load_decryption_key
: "${COLOR_ANIMA_KERNEL_DECRYPTION_KEY:?COLOR_ANIMA_KERNEL_DECRYPTION_KEY is required or store it in macOS Keychain service color-anima-kernel-release-key}"

if [[ -z "${GH_TOKEN:-}" ]]; then
  log "GH_TOKEN not set; falling back to existing gh authentication"
fi

if grep -Ev '^(#.*|$|COLOR_ANIMA_KERNEL_[A-Z0-9_]+=[A-Za-z0-9._/:=-]+)$' "$METADATA_FILE" >/tmp/color-anima-core-metadata.invalid; then
  cat /tmp/color-anima-core-metadata.invalid >&2
  die "metadata contains unsupported lines"
fi

set -a
# shellcheck source=/dev/null
source "$METADATA_FILE"
set +a

: "${COLOR_ANIMA_KERNEL_VERSION:?missing COLOR_ANIMA_KERNEL_VERSION}"
: "${COLOR_ANIMA_KERNEL_REPOSITORY:?missing COLOR_ANIMA_KERNEL_REPOSITORY}"
: "${COLOR_ANIMA_KERNEL_RELEASE_TAG:?missing COLOR_ANIMA_KERNEL_RELEASE_TAG}"
: "${COLOR_ANIMA_KERNEL_ENCRYPTED_ASSET:?missing COLOR_ANIMA_KERNEL_ENCRYPTED_ASSET}"
: "${COLOR_ANIMA_KERNEL_ZIP_SHA256:?missing COLOR_ANIMA_KERNEL_ZIP_SHA256}"
: "${COLOR_ANIMA_KERNEL_ENCRYPTED_SHA256:?missing COLOR_ANIMA_KERNEL_ENCRYPTED_SHA256}"
: "${COLOR_ANIMA_KERNEL_XCFRAMEWORK:?missing COLOR_ANIMA_KERNEL_XCFRAMEWORK}"

case "$COLOR_ANIMA_KERNEL_ZIP_SHA256" in
  replace-*|"" ) die "metadata has placeholder plaintext checksum" ;;
esac
case "$COLOR_ANIMA_KERNEL_ENCRYPTED_SHA256" in
  replace-*|"" ) die "metadata has placeholder encrypted checksum" ;;
esac

DOWNLOAD_DIR="$OUTPUT_DIR/downloads/$COLOR_ANIMA_KERNEL_RELEASE_TAG"
UNPACK_DIR="$OUTPUT_DIR/unpacked-$COLOR_ANIMA_KERNEL_RELEASE_TAG"
ENC_PATH="$DOWNLOAD_DIR/$COLOR_ANIMA_KERNEL_ENCRYPTED_ASSET"
ZIP_PATH="$DOWNLOAD_DIR/${COLOR_ANIMA_KERNEL_ENCRYPTED_ASSET%.enc}"
FINAL_XCFRAMEWORK="$OUTPUT_DIR/$COLOR_ANIMA_KERNEL_XCFRAMEWORK"

rm -rf "$DOWNLOAD_DIR" "$UNPACK_DIR"
mkdir -p "$DOWNLOAD_DIR" "$UNPACK_DIR"

if [[ -n "$LOCAL_ASSET_FILE" ]]; then
  log "copy local encrypted core asset"
  cp "$LOCAL_ASSET_FILE" "$ENC_PATH"
else
  log "download encrypted core asset $COLOR_ANIMA_KERNEL_REPOSITORY $COLOR_ANIMA_KERNEL_RELEASE_TAG"
  gh release download "$COLOR_ANIMA_KERNEL_RELEASE_TAG" \
    --repo "$COLOR_ANIMA_KERNEL_REPOSITORY" \
    --pattern "$COLOR_ANIMA_KERNEL_ENCRYPTED_ASSET" \
    --dir "$DOWNLOAD_DIR" \
    --clobber
fi

[[ -f "$ENC_PATH" ]] || die "downloaded asset missing: $ENC_PATH"

DOWNLOADED_ENC_SHA="$(shasum -a 256 "$ENC_PATH" | awk '{print $1}')"
if [[ "$DOWNLOADED_ENC_SHA" != "$COLOR_ANIMA_KERNEL_ENCRYPTED_SHA256" ]]; then
  die "encrypted checksum mismatch: got $DOWNLOADED_ENC_SHA expected $COLOR_ANIMA_KERNEL_ENCRYPTED_SHA256"
fi

log "decrypt core asset"
openssl enc -d -aes-256-cbc -pbkdf2 \
  -in "$ENC_PATH" \
  -out "$ZIP_PATH" \
  -pass env:COLOR_ANIMA_KERNEL_DECRYPTION_KEY

DOWNLOADED_ZIP_SHA="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
if [[ "$DOWNLOADED_ZIP_SHA" != "$COLOR_ANIMA_KERNEL_ZIP_SHA256" ]]; then
  die "plaintext checksum mismatch: got $DOWNLOADED_ZIP_SHA expected $COLOR_ANIMA_KERNEL_ZIP_SHA256"
fi

log "unpack XCFramework"
unzip -q "$ZIP_PATH" -d "$UNPACK_DIR"
[[ -d "$UNPACK_DIR/$COLOR_ANIMA_KERNEL_XCFRAMEWORK" ]] || die "XCFramework missing after unzip"
rm -rf "$FINAL_XCFRAMEWORK"
mv "$UNPACK_DIR/$COLOR_ANIMA_KERNEL_XCFRAMEWORK" "$FINAL_XCFRAMEWORK"
rm -rf "$UNPACK_DIR"

cat <<EOF

Fetched ColorAnimaKernel

  version: $COLOR_ANIMA_KERNEL_VERSION
  path:    .local-core/$COLOR_ANIMA_KERNEL_XCFRAMEWORK
  sha256:  $DOWNLOADED_ZIP_SHA

Use:
  COLOR_ANIMA_KERNEL_PATH=".local-core/$COLOR_ANIMA_KERNEL_XCFRAMEWORK" swift build

EOF
