#!/usr/bin/env bash
set -euo pipefail

# build-design-studio-app.sh — package ColorAnimaDesignStudio as a macOS .app bundle.
#
# Usage:
#   ./scripts/build-design-studio-app.sh [options]
#
# Options:
#   --output PATH    Destination .app path (default: ~/Desktop/Color Anima Design Studio.app)
#   --release        Build with release configuration (default: debug)
#   --skip-sign      Skip ad-hoc code signing
#   --open           Open the bundle after build
#   -h, --help       Show this help text
#
# The script mirrors the structure of scripts/build-macos-app.sh but targets
# the ColorAnimaDesignStudio developer tool instead of the main ColorAnima app.
#
# ca-design shortcut (install in ~/.zshrc — not done by this script):
#   ca-design() { sh "$(git rev-parse --show-toplevel)/scripts/build-design-studio-app.sh" "$@" }

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"

APP_NAME="Color Anima Design Studio"
PRODUCT_NAME="ColorAnimaDesignStudio"
BUNDLE_IDENTIFIER="com.colorAnima.designStudio"
MINIMUM_SYSTEM_VERSION="14.0"
CONFIGURATION="debug"
OUTPUT_PATH="$HOME/Desktop/${APP_NAME}.app"
SIGN_APP=true
OPEN_AFTER_BUILD=false

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

log_info()  { printf '[INFO] %s\n' "$*"; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }
die()       { log_error "$*"; exit 1; }

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------

usage() {
    cat <<'EOF'
Usage: ./scripts/build-design-studio-app.sh [options]

Package ColorAnimaDesignStudio as a macOS .app bundle (developer tool).

Options:
  --output PATH    Destination .app path (default: ~/Desktop/Color Anima Design Studio.app)
  --release        Build with release configuration (default: debug)
  --skip-sign      Skip ad-hoc code signing
  --open           Open the bundle after build
  -h, --help       Show this help text
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --output)
                OUTPUT_PATH="$2"
                shift 2
                ;;
            --release)
                CONFIGURATION="release"
                shift
                ;;
            --skip-sign)
                SIGN_APP=false
                shift
                ;;
            --open)
                OPEN_AFTER_BUILD=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                usage >&2
                die "Unknown option: $1"
                ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

build_product() {
    log_info "Building $PRODUCT_NAME ($CONFIGURATION)"
    (
        cd "$REPO_ROOT"
        swift build -c "$CONFIGURATION" --product "$PRODUCT_NAME"
    )
}

resolve_binary_path() {
    local bin_dir
    bin_dir="$(
        cd "$REPO_ROOT"
        swift build -c "$CONFIGURATION" --product "$PRODUCT_NAME" --show-bin-path | tail -n 1
    )"
    [[ -n "$bin_dir" ]] || die "Unable to resolve SwiftPM binary directory"
    BINARY_PATH="$bin_dir/$PRODUCT_NAME"
    [[ -x "$BINARY_PATH" ]] || die "Built executable not found: $BINARY_PATH"
}

# ---------------------------------------------------------------------------
# Bundle layout
# ---------------------------------------------------------------------------

create_bundle_layout() {
    APP_BUNDLE_PATH="$OUTPUT_PATH"
    CONTENTS_DIR="$APP_BUNDLE_PATH/Contents"
    MACOS_DIR="$CONTENTS_DIR/MacOS"
    RESOURCES_DIR="$CONTENTS_DIR/Resources"

    rm -rf -- "$APP_BUNDLE_PATH"
    mkdir -p -- "$MACOS_DIR" "$RESOURCES_DIR"
}

copy_executable() {
    cp "$BINARY_PATH" "$MACOS_DIR/$PRODUCT_NAME"
    chmod 755 "$MACOS_DIR/$PRODUCT_NAME"
}

copy_resource_bundles() {
    local bin_dir
    bin_dir="$(dirname -- "$BINARY_PATH")"

    # The TokenManifest module ships tokens.json as a SwiftPM resource bundle.
    # The auto-generated bundle name follows the SwiftPM convention:
    #   <PackageName>_<TargetName>.bundle
    local bundle_name="ColorAnima_ColorAnimaDesignStudioTokenManifest.bundle"
    local bundle_src="$bin_dir/$bundle_name"

    if [[ -d "$bundle_src" ]]; then
        log_info "Copying resource bundle: $bundle_name"
        cp -R "$bundle_src" "$RESOURCES_DIR/$bundle_name"
    else
        log_info "Resource bundle not found at $bundle_src — skipping (tokens loaded from binary)"
    fi
}

write_info_plist() {
    local bundle_version
    bundle_version="$(date '+%Y%m%d%H%M%S')"

    cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$PRODUCT_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_IDENTIFIER</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>$bundle_version</string>
    <key>LSMinimumSystemVersion</key>
    <string>$MINIMUM_SYSTEM_VERSION</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF
}

sign_bundle() {
    if [[ "$SIGN_APP" != true ]]; then
        log_info "Skipping code signing"
        return 0
    fi
    require_command codesign
    log_info "Applying ad-hoc code signature"
    codesign --force --deep --sign - "$APP_BUNDLE_PATH"
}

open_bundle_if_requested() {
    if [[ "$OPEN_AFTER_BUILD" == true ]]; then
        log_info "Opening app bundle"
        open "$APP_BUNDLE_PATH"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    parse_args "$@"
    require_command swift

    build_product
    resolve_binary_path
    create_bundle_layout
    copy_executable
    copy_resource_bundles
    write_info_plist
    sign_bundle
    open_bundle_if_requested

    log_info "Created app bundle: $APP_BUNDLE_PATH"
}

main "$@"
