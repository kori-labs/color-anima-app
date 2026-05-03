#!/usr/bin/env bash
set -Eeuo pipefail

# Production release build script.
# Extends build-macos-app.sh with Developer ID signing, notarization, DMG packaging,
# and verification. For local/development builds, use scripts/build-macos-app.sh instead.
#
# Required GitHub Secrets (when running in CI):
#   DEVELOPER_ID_APPLICATION   — Developer ID Application certificate identity
#                                e.g. "Developer ID Application: Team Name (XXXXXXXXXX)"
#   NOTARIZATION_APPLE_ID      — Apple ID used for notarization
#   NOTARIZATION_PASSWORD      — App-specific password for notarization
#   NOTARIZATION_TEAM_ID       — Apple Developer Team ID

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"

# ── Defaults inherited from build-macos-app.sh ────────────────────────────────
APP_NAME="Color Anima"
PRODUCT_NAME="ColorAnima"
CONFIGURATION="release"
OUTPUT_DIR="$REPO_ROOT/dist"
BUNDLE_IDENTIFIER="com.coloranima.app"
SHORT_VERSION="${APP_VERSION:-0.1.0}"
BUNDLE_VERSION="${BUILD_NUMBER:-$(date '+%Y%m%d%H%M%S')}"
MINIMUM_SYSTEM_VERSION="14.0"
ICON_PATH=""

# ── Release-specific options ──────────────────────────────────────────────────
SIGN_IDENTITY="-"
NOTARIZE=false
NOTARIZATION_APPLE_ID="${NOTARIZATION_APPLE_ID:-}"
NOTARIZATION_PASSWORD="${NOTARIZATION_PASSWORD:-}"
NOTARIZATION_TEAM_ID="${NOTARIZATION_TEAM_ID:-}"
CREATE_DMG=false
DMG_OUTPUT=""

usage() {
    cat <<'EOF'
Usage: ./scripts/release-macos-app.sh [options]

Build, sign, notarize, and package the macOS app as a DMG for distribution.
Delegates the core app bundle build to scripts/build-macos-app.sh.

Build options (forwarded to build-macos-app.sh):
  --app-name NAME                 App bundle name (default: "Color Anima")
  --product NAME                  SwiftPM executable product (default: "ColorAnima")
  --configuration CONFIG          Build configuration: debug|release (default: release)
  --output-dir PATH               Output directory for the .app bundle (default: ./dist)
  --bundle-id ID                  CFBundleIdentifier (default: com.coloranima.app)
  --version VERSION               CFBundleShortVersionString (default: APP_VERSION or 0.1.0)
  --build-number NUMBER           CFBundleVersion (default: BUILD_NUMBER or current timestamp)
  --minimum-system-version VER    LSMinimumSystemVersion (default: 14.0)
  --icon PATH                     Optional .icns file to copy into the bundle

Release options:
  --sign-identity IDENTITY        Developer ID identity for codesign (default: ad-hoc "-")
  --notarize                      Submit to Apple notary service and staple
  --notarization-apple-id ID      Apple ID for notarization (or set NOTARIZATION_APPLE_ID)
  --notarization-password PASS    App-specific password (or set NOTARIZATION_PASSWORD)
  --notarization-team-id TEAM     Apple Developer Team ID (or set NOTARIZATION_TEAM_ID)
  --create-dmg                    Package the signed .app as a DMG
  --dmg-output PATH               DMG output path (default: <output-dir>/<app-name>-<version>.dmg)
  -h, --help                      Show this help text

Environment:
  APP_VERSION                     Default short version when --version is not passed
  BUILD_NUMBER                    Default build number when --build-number is not passed
  NOTARIZATION_APPLE_ID           Notarization Apple ID (overridden by --notarization-apple-id)
  NOTARIZATION_PASSWORD           App-specific password (overridden by --notarization-password)
  NOTARIZATION_TEAM_ID            Developer Team ID (overridden by --notarization-team-id)
EOF
}

log_info() {
    printf '[INFO] %s\n' "$*"
}

log_error() {
    printf '[ERROR] %s\n' "$*" >&2
}

die() {
    log_error "$*"
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --app-name)
                APP_NAME="$2"
                shift 2
                ;;
            --product)
                PRODUCT_NAME="$2"
                shift 2
                ;;
            --configuration)
                CONFIGURATION="$2"
                shift 2
                ;;
            --output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --bundle-id)
                BUNDLE_IDENTIFIER="$2"
                shift 2
                ;;
            --version)
                SHORT_VERSION="$2"
                shift 2
                ;;
            --build-number)
                BUNDLE_VERSION="$2"
                shift 2
                ;;
            --minimum-system-version)
                MINIMUM_SYSTEM_VERSION="$2"
                shift 2
                ;;
            --icon)
                ICON_PATH="$2"
                shift 2
                ;;
            --sign-identity)
                SIGN_IDENTITY="$2"
                shift 2
                ;;
            --notarize)
                NOTARIZE=true
                shift
                ;;
            --notarization-apple-id)
                NOTARIZATION_APPLE_ID="$2"
                shift 2
                ;;
            --notarization-password)
                NOTARIZATION_PASSWORD="$2"
                shift 2
                ;;
            --notarization-team-id)
                NOTARIZATION_TEAM_ID="$2"
                shift 2
                ;;
            --create-dmg)
                CREATE_DMG=true
                shift
                ;;
            --dmg-output)
                DMG_OUTPUT="$2"
                shift 2
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

validate_notarization_inputs() {
    if [[ "$NOTARIZE" != true ]]; then
        return 0
    fi

    [[ -n "$NOTARIZATION_APPLE_ID" ]] \
        || die "Notarization requires --notarization-apple-id or NOTARIZATION_APPLE_ID"
    [[ -n "$NOTARIZATION_PASSWORD" ]] \
        || die "Notarization requires --notarization-password or NOTARIZATION_PASSWORD"
    [[ -n "$NOTARIZATION_TEAM_ID" ]] \
        || die "Notarization requires --notarization-team-id or NOTARIZATION_TEAM_ID"
    [[ "$CREATE_DMG" == true ]] \
        || die "Notarization requires --create-dmg (notarytool submits the DMG)"
    [[ "$SIGN_IDENTITY" != "-" ]] \
        || die "Notarization requires a Developer ID identity via --sign-identity (ad-hoc is not accepted by Apple)"
}

# ── Step 1: Build the .app bundle ─────────────────────────────────────────────

build_app() {
    log_info "Building app bundle via build-macos-app.sh"

    local build_args=(
        --app-name "$APP_NAME"
        --product "$PRODUCT_NAME"
        --configuration "$CONFIGURATION"
        --output-dir "$OUTPUT_DIR"
        --bundle-id "$BUNDLE_IDENTIFIER"
        --version "$SHORT_VERSION"
        --build-number "$BUNDLE_VERSION"
        --minimum-system-version "$MINIMUM_SYSTEM_VERSION"
        --skip-sign
    )

    if [[ -n "$ICON_PATH" ]]; then
        build_args+=(--icon "$ICON_PATH")
    fi

    "$SCRIPT_DIR/build-macos-app.sh" "${build_args[@]}"

    APP_BUNDLE_PATH="$OUTPUT_DIR/$APP_NAME.app"
    [[ -d "$APP_BUNDLE_PATH" ]] || die "Expected app bundle not found after build: $APP_BUNDLE_PATH"
    log_info "App bundle ready: $APP_BUNDLE_PATH"
}

# ── Step 2: Developer ID signing ──────────────────────────────────────────────

sign_app() {
    require_command codesign

    if [[ "$SIGN_IDENTITY" == "-" ]]; then
        log_info "Applying ad-hoc code signature (no Developer ID provided)"
        codesign --force --deep --sign - "$APP_BUNDLE_PATH"
    else
        log_info "Signing with Developer ID: $SIGN_IDENTITY"
        # --options runtime enables the hardened runtime, required for notarization.
        codesign \
            --force \
            --deep \
            --options runtime \
            --sign "$SIGN_IDENTITY" \
            "$APP_BUNDLE_PATH"
    fi
}

# ── Step 3: Create DMG ────────────────────────────────────────────────────────

create_dmg() {
    if [[ "$CREATE_DMG" != true ]]; then
        return 0
    fi

    require_command hdiutil

    if [[ -z "$DMG_OUTPUT" ]]; then
        DMG_OUTPUT="$OUTPUT_DIR/${APP_NAME// /-}-${SHORT_VERSION}.dmg"
    fi

    log_info "Creating DMG: $DMG_OUTPUT"
    rm -f -- "$DMG_OUTPUT"
    hdiutil create \
        -volname "$APP_NAME" \
        -srcfolder "$APP_BUNDLE_PATH" \
        -ov \
        -format UDZO \
        "$DMG_OUTPUT"

    [[ -f "$DMG_OUTPUT" ]] || die "DMG not found after hdiutil create: $DMG_OUTPUT"
    log_info "DMG created: $DMG_OUTPUT"
}

# ── Step 4: Notarize DMG ──────────────────────────────────────────────────────

notarize_dmg() {
    if [[ "$NOTARIZE" != true ]]; then
        return 0
    fi

    require_command xcrun

    log_info "Submitting DMG to Apple notary service: $DMG_OUTPUT"
    xcrun notarytool submit \
        "$DMG_OUTPUT" \
        --apple-id "$NOTARIZATION_APPLE_ID" \
        --password "$NOTARIZATION_PASSWORD" \
        --team-id "$NOTARIZATION_TEAM_ID" \
        --wait
}

# ── Step 5: Staple ────────────────────────────────────────────────────────────

staple_dmg() {
    if [[ "$NOTARIZE" != true ]]; then
        return 0
    fi

    require_command xcrun

    log_info "Stapling notarization ticket: $DMG_OUTPUT"
    xcrun stapler staple "$DMG_OUTPUT"
}

# ── Step 6: Verify ────────────────────────────────────────────────────────────

verify_signing() {
    require_command codesign

    log_info "Verifying code signature on app bundle"
    codesign --verify --deep --strict "$APP_BUNDLE_PATH"
    log_info "Code signature verified"
}

verify_notarization() {
    if [[ "$NOTARIZE" != true ]]; then
        return 0
    fi

    require_command spctl

    log_info "Verifying notarization (Gatekeeper assessment)"
    spctl --assess --type open --context context:primary-signature "$DMG_OUTPUT"
    log_info "Notarization verified"
}

main() {
    parse_args "$@"
    validate_notarization_inputs

    require_command swift
    mkdir -p -- "$OUTPUT_DIR"

    # Step 1: build
    build_app

    # Step 2: sign
    sign_app

    # Step 3: DMG
    create_dmg

    # Step 4: notarize
    notarize_dmg

    # Step 5: staple
    staple_dmg

    # Step 6: verify
    verify_signing
    verify_notarization

    if [[ "$CREATE_DMG" == true ]]; then
        log_info "Release artifact ready: $DMG_OUTPUT"
    else
        log_info "Release artifact ready: $APP_BUNDLE_PATH"
    fi
}

main "$@"
