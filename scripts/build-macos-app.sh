#!/usr/bin/env bash
set -Eeuo pipefail

# Local development build script.
# For production releases with Developer ID signing and notarization,
# use scripts/release-macos-app.sh instead.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"

APP_NAME="Color Anima"
PRODUCT_NAME="ColorAnima"
CONFIGURATION="release"
OUTPUT_DIR="$REPO_ROOT/dist"
BUNDLE_IDENTIFIER="com.coloranima.app"
SHORT_VERSION="${APP_VERSION:-0.1.0}"
BUNDLE_VERSION="${BUILD_NUMBER:-$(date '+%Y%m%d%H%M%S')}"
MINIMUM_SYSTEM_VERSION="14.0"
ICON_PATH=""
OPEN_AFTER_BUILD=false
SIGN_APP=true

usage() {
    cat <<'EOF'
Usage: ./scripts/build-macos-app.sh [options]

Build the SwiftPM executable and package it as a macOS .app bundle.

Options:
  --app-name NAME                 App bundle name (default: "Color Anima")
  --product NAME                  SwiftPM executable product (default: "ColorAnima")
  --configuration CONFIG          Build configuration: debug|release (default: release)
  --output-dir PATH               Output directory for the .app bundle (default: ./dist)
  --bundle-id ID                  CFBundleIdentifier (default: com.coloranima.app)
  --version VERSION               CFBundleShortVersionString (default: APP_VERSION or 0.1.0)
  --build-number NUMBER           CFBundleVersion (default: BUILD_NUMBER or current timestamp)
  --minimum-system-version VER    LSMinimumSystemVersion (default: 14.0)
  --icon PATH                     Optional .icns file to copy into the bundle
  --open                          Open the packaged app after build
  --skip-sign                     Skip ad-hoc code signing
  -h, --help                      Show this help text

Environment:
  APP_VERSION                     Default short version when --version is not passed
  BUILD_NUMBER                    Default build number when --build-number is not passed
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

validate_configuration() {
    case "$CONFIGURATION" in
        debug|release) ;;
        *)
            die "Unsupported configuration: $CONFIGURATION (expected: debug or release)"
            ;;
    esac
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
            --open)
                OPEN_AFTER_BUILD=true
                shift
                ;;
            --skip-sign)
                SIGN_APP=false
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

create_bundle_layout() {
    APP_BUNDLE_PATH="$OUTPUT_DIR/$APP_NAME.app"
    CONTENTS_DIR="$APP_BUNDLE_PATH/Contents"
    MACOS_DIR="$CONTENTS_DIR/MacOS"
    RESOURCES_DIR="$CONTENTS_DIR/Resources"
    INFO_PLIST_PATH="$CONTENTS_DIR/Info.plist"

    rm -rf -- "$APP_BUNDLE_PATH"
    mkdir -p -- "$MACOS_DIR" "$RESOURCES_DIR"
}

copy_executable() {
    cp "$BINARY_PATH" "$MACOS_DIR/$PRODUCT_NAME"
    chmod 755 "$MACOS_DIR/$PRODUCT_NAME"
}

find_runtime_dylib() {
    local dylib_name="$1"
    local binary_dir

    binary_dir="$(dirname -- "$BINARY_PATH")"

    if [[ -f "$binary_dir/$dylib_name" ]]; then
        printf '%s\n' "$binary_dir/$dylib_name"
        return 0
    fi

    if [[ -n "${COLOR_ANIMA_KERNEL_PATH:-}" && -d "${COLOR_ANIMA_KERNEL_PATH:-}" ]]; then
        local found
        found="$(find "$COLOR_ANIMA_KERNEL_PATH" -name "$dylib_name" -type f -print -quit)"
        if [[ -n "$found" ]]; then
            printf '%s\n' "$found"
            return 0
        fi
    fi

    return 1
}

copy_runtime_dylibs() {
    require_command otool

    local linked_dylibs
    linked_dylibs="$(
        otool -L "$BINARY_PATH" \
            | awk 'index($1, "@rpath/") == 1 && $1 ~ /\.dylib$/ { print $1 }' \
            | sort -u
    )"

    if [[ -z "$linked_dylibs" ]]; then
        return 0
    fi

    while IFS= read -r dylib_ref; do
        [[ -n "$dylib_ref" ]] || continue

        local dylib_name
        local source_path
        dylib_name="$(basename -- "$dylib_ref")"

        source_path="$(find_runtime_dylib "$dylib_name")" \
            || die "Linked runtime dylib not found for bundle copy: $dylib_name"

        log_info "Copying runtime dylib: $dylib_name"
        cp "$source_path" "$MACOS_DIR/$dylib_name"
        chmod 755 "$MACOS_DIR/$dylib_name"
    done <<< "$linked_dylibs"
}

copy_local_fonts_if_present() {
    local fonts_src="$REPO_ROOT/.local-fonts/Geist/static"
    if [[ ! -d "$fonts_src" ]]; then
        BUNDLE_HAS_FONTS=false
        return 0
    fi

    local fonts_dst="$RESOURCES_DIR/Fonts"
    mkdir -p -- "$fonts_dst"

    local copied=0
    shopt -s nullglob
    for f in "$fonts_src"/*.ttf "$fonts_src"/*.otf; do
        cp "$f" "$fonts_dst/"
        copied=$((copied + 1))
    done
    shopt -u nullglob

    if [[ $copied -gt 0 ]]; then
        log_info "Copied $copied font file(s) into Resources/Fonts"
        BUNDLE_HAS_FONTS=true
    else
        BUNDLE_HAS_FONTS=false
    fi
}

copy_icon_if_present() {
    if [[ -z "$ICON_PATH" ]]; then
        ICON_BASENAME=""
        return 0
    fi

    [[ -f "$ICON_PATH" ]] || die "Icon file not found: $ICON_PATH"
    [[ "$ICON_PATH" == *.icns ]] || die "Icon must be a .icns file: $ICON_PATH"

    ICON_BASENAME="$(basename -- "$ICON_PATH")"
    cp "$ICON_PATH" "$RESOURCES_DIR/$ICON_BASENAME"
}

write_info_plist() {
    local icon_block=""
    if [[ -n "${ICON_BASENAME:-}" ]]; then
        icon_block="    <key>CFBundleIconFile</key>
    <string>$ICON_BASENAME</string>"
    fi

    local fonts_block=""
    if [[ "${BUNDLE_HAS_FONTS:-false}" == true ]]; then
        fonts_block="    <key>ATSApplicationFontsPath</key>
    <string>Fonts</string>"
    fi

    cat > "$INFO_PLIST_PATH" <<EOF
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
    <string>$SHORT_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUNDLE_VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>$MINIMUM_SYSTEM_VERSION</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
$icon_block
$fonts_block
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

main() {
    parse_args "$@"
    require_command swift
    validate_configuration
    mkdir -p -- "$OUTPUT_DIR"

    build_product
    resolve_binary_path
    create_bundle_layout
    copy_icon_if_present
    copy_local_fonts_if_present
    copy_executable
    copy_runtime_dylibs
    write_info_plist
    sign_bundle
    open_bundle_if_requested

    log_info "Created app bundle: $APP_BUNDLE_PATH"
}

main "$@"
