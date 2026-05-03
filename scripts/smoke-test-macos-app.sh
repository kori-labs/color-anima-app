#!/usr/bin/env bash
set -Eeuo pipefail

# Packaged-app smoke test orchestrator.
# Builds the .app bundle, launches it, runs smoke checks, and terminates.
#
# Usage: ./scripts/smoke-test-macos-app.sh [--skip-build] [--configuration debug|release]
#
# Requires: macOS with display session (for app launch and AppleScript checks)

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
SMOKE_DIR="$SCRIPT_DIR/smoke"

CONFIGURATION="debug"  # debug is faster for smoke checks
SKIP_BUILD=false
APP_BUNDLE_PATH=""
APP_NAME="Color Anima"
PRODUCT_NAME="ColorAnima"
LAUNCH_TIMEOUT=10
SMOKE_RESULTS_DIR="$REPO_ROOT/reports/smoke"

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------

log_info() {
    printf '[INFO]  %s\n' "$*"
}

log_warn() {
    printf '[WARN]  %s\n' "$*" >&2
}

log_error() {
    printf '[ERROR] %s\n' "$*" >&2
}

die() {
    log_error "$*"
    exit 1
}

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------

usage() {
    cat <<'EOF'
Usage: ./scripts/smoke-test-macos-app.sh [options]

Run packaged-app smoke checks against a built .app bundle.

Options:
  --skip-build                    Skip the build step (use existing bundle)
  --configuration debug|release   Build configuration (default: debug)
  --app-path PATH                 Path to a pre-built .app bundle (implies --skip-build)
  -h, --help                      Show this help text
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            --configuration)
                CONFIGURATION="$2"
                shift 2
                ;;
            --app-path)
                APP_BUNDLE_PATH="$2"
                SKIP_BUILD=true
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

# ---------------------------------------------------------------------------
# Build phase
# ---------------------------------------------------------------------------

run_build() {
    if [[ "$SKIP_BUILD" == true ]]; then
        log_info "Skipping build (--skip-build)"
        return 0
    fi

    log_info "Building .app bundle (configuration: $CONFIGURATION)"
    "$REPO_ROOT/scripts/build-macos-app.sh" \
        --configuration "$CONFIGURATION" \
        --skip-sign
}

# ---------------------------------------------------------------------------
# Resolve app path
# ---------------------------------------------------------------------------

resolve_app_path() {
    if [[ -z "$APP_BUNDLE_PATH" ]]; then
        APP_BUNDLE_PATH="$REPO_ROOT/dist/$APP_NAME.app"
    fi
    log_info "App bundle path: $APP_BUNDLE_PATH"
}

# ---------------------------------------------------------------------------
# Pre-launch checks
# ---------------------------------------------------------------------------

pre_launch_checks() {
    [[ -d "$APP_BUNDLE_PATH" ]] || die "App bundle not found: $APP_BUNDLE_PATH"

    if pgrep -x "$PRODUCT_NAME" >/dev/null 2>&1; then
        die "App is already running. Terminate it before running smoke tests."
    fi

    mkdir -p "$SMOKE_RESULTS_DIR"
    log_info "Smoke results directory: $SMOKE_RESULTS_DIR"
}

# ---------------------------------------------------------------------------
# Launch and wait
# ---------------------------------------------------------------------------

APP_PID=""

launch_app() {
    log_info "Launching $APP_NAME"
    open -a "$APP_BUNDLE_PATH"

    local elapsed=0
    while [[ $elapsed -lt $LAUNCH_TIMEOUT ]]; do
        local matching_pids
        matching_pids=$(pgrep -x "$PRODUCT_NAME" 2>/dev/null || true)
        if [[ -n "$matching_pids" ]]; then
            local pid_count
            pid_count=$(echo "$matching_pids" | wc -l | tr -d ' ')
            if [[ "$pid_count" -gt 1 ]]; then
                die "Multiple running processes matched $PRODUCT_NAME: $(echo "$matching_pids" | tr '\n' ' ')"
            fi
            APP_PID="$matching_pids"
            log_info "App launched with PID $APP_PID (after ${elapsed}s)"
            return 0
        fi
        sleep 1
        (( elapsed++ )) || true
    done

    die "App did not start within ${LAUNCH_TIMEOUT}s"
}

# ---------------------------------------------------------------------------
# Teardown
# ---------------------------------------------------------------------------

teardown_app() {
    log_info "Terminating $APP_NAME"

    # Graceful quit via AppleScript
    osascript -e "tell application \"$APP_NAME\" to quit" 2>/dev/null || true

    local elapsed=0
    while [[ $elapsed -lt 5 ]]; do
        if ! pgrep -x "$PRODUCT_NAME" >/dev/null 2>&1; then
            log_info "App terminated cleanly"
            return 0
        fi
        sleep 1
        (( elapsed++ )) || true
    done

    log_warn "App did not quit within 5s — force-killing"
    pkill -9 -x "$PRODUCT_NAME" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Run smoke checks
# ---------------------------------------------------------------------------

SMOKE_PASS=()
SMOKE_FAIL=()

run_smoke_checks() {
    if [[ ! -d "$SMOKE_DIR" ]]; then
        log_warn "Smoke directory not found: $SMOKE_DIR — skipping per-check scripts"
        return 0
    fi

    local found_any=false

    for check_script in "$SMOKE_DIR"/verify-*.sh; do
        # Guard against empty glob expansion
        [[ -e "$check_script" ]] || continue
        found_any=true

        local check_name
        check_name="$(basename -- "$check_script" .sh)"

        if [[ ! -x "$check_script" ]]; then
            log_warn "Check script is not executable — skipping: $check_script"
            SMOKE_FAIL+=("$check_name (not executable)")
            continue
        fi

        local log_file="$SMOKE_RESULTS_DIR/${check_name}.log"
        log_info "Running check: $check_name"

        if "$check_script" "$APP_NAME" "$APP_PID" >"$log_file" 2>&1; then
            log_info "  PASS: $check_name"
            SMOKE_PASS+=("$check_name")
        else
            local exit_code=$?
            log_warn "  FAIL: $check_name (exit $exit_code) — see $log_file"
            SMOKE_FAIL+=("$check_name")
        fi
    done

    if [[ "$found_any" == false ]]; then
        log_warn "No verify-*.sh scripts found in $SMOKE_DIR"
    fi
}

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

write_report() {
    local report_file="$SMOKE_RESULTS_DIR/smoke-results.txt"
    local total=$(( ${#SMOKE_PASS[@]} + ${#SMOKE_FAIL[@]} ))

    {
        printf 'Smoke test results\n'
        printf 'App:           %s\n' "$APP_NAME"
        printf 'Bundle:        %s\n' "$APP_BUNDLE_PATH"
        printf 'Configuration: %s\n' "$CONFIGURATION"
        printf 'Date:          %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        printf '\n'
        printf 'Passed: %d / %d\n' "${#SMOKE_PASS[@]}" "$total"
        printf 'Failed: %d / %d\n' "${#SMOKE_FAIL[@]}" "$total"
        printf '\n'

        if [[ ${#SMOKE_PASS[@]} -gt 0 ]]; then
            printf 'PASSED:\n'
            for name in "${SMOKE_PASS[@]}"; do
                printf '  + %s\n' "$name"
            done
        fi

        if [[ ${#SMOKE_FAIL[@]} -gt 0 ]]; then
            printf '\nFAILED:\n'
            for name in "${SMOKE_FAIL[@]}"; do
                printf '  - %s\n' "$name"
            done
        fi
    } | tee "$report_file"

    log_info "Results written to $report_file"
}

# ---------------------------------------------------------------------------
# Cleanup trap
# ---------------------------------------------------------------------------

cleanup() {
    local exit_code=$?
    # Always attempt to terminate the app even if a step failed
    if pgrep -x "$PRODUCT_NAME" >/dev/null 2>&1; then
        log_warn "Cleanup trap: terminating $APP_NAME"
        teardown_app
    fi
    exit "$exit_code"
}

trap cleanup EXIT INT TERM

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    parse_args "$@"

    run_build
    resolve_app_path
    pre_launch_checks
    launch_app
    run_smoke_checks
    teardown_app
    # Disable trap teardown now that we've already quit cleanly
    trap - EXIT

    write_report

    if [[ ${#SMOKE_FAIL[@]} -gt 0 ]]; then
        log_error "Smoke tests FAILED (${#SMOKE_FAIL[@]} failure(s))"
        exit 1
    fi

    log_info "All smoke checks passed"
    exit 0
}

main "$@"
