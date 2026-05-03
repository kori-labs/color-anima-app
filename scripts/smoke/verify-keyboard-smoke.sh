#!/usr/bin/env bash
# verify-keyboard-smoke.sh — confirm the app handles keyboard events without crashing
# Usage: ./verify-keyboard-smoke.sh "$APP_NAME" "$APP_PID"
# Exit 0 = pass, Exit 1 = fail
#
# Note: Without a loaded project, navigation shortcuts are no-ops (guarded by
# hasActiveCut). This test only verifies the app stays alive after the events.

set -euo pipefail

APP_NAME="${1:-Color Anima}"
APP_PID="${2:?APP_PID required}"

PASS=0
FAIL=0
SKIPPED=false

pass() { echo "[PASS] $*"; ((PASS++)) || true; }
fail() { echo "[FAIL] $*"; ((FAIL++)) || true; }
skip() { echo "[SKIP] $*"; SKIPPED=true; }

alive() {
    if kill -0 "$APP_PID" 2>/dev/null; then
        pass "Process $APP_PID still alive after $1"
    else
        fail "Process $APP_PID crashed after $1"
    fi
}

send_key() {
    local desc="$1"
    local script="$2"
    local exit_code=0
    local result
    # Capture exit code explicitly — set -e must not kill the script here.
    result=$(osascript -e "$script" 2>&1) || exit_code=$?
    if echo "$result" | grep -qi "not allowed\|not authorized\|1002\|access for assistive"; then
        skip "Accessibility not available — cannot send key event for: $desc"
        return 0
    fi
    if (( exit_code != 0 )); then
        # Non-accessibility errors are warnings, not hard failures
        echo "[WARN] Key event returned non-zero for $desc: $result"
    fi
}

# Step 1: bring app to front
osascript -e "tell application \"$APP_NAME\" to activate" 2>/dev/null || true
sleep 0.5

# Step 2: Left arrow (keycode 123)
send_key "Left arrow" 'tell application "System Events" to key code 123'
sleep 0.5
alive "Left arrow"

# Step 3: Right arrow (keycode 124)
send_key "Right arrow" 'tell application "System Events" to key code 124'
sleep 0.5
alive "Right arrow"

# Step 4: Space (keycode 49)
send_key "Space" 'tell application "System Events" to key code 49'
sleep 0.5
alive "Space"

# Step 5: Command+A (select all)
send_key "Command+A" 'tell application "System Events" to keystroke "a" using command down'
sleep 0.2
alive "Command+A"

if $SKIPPED; then
    echo ""
    echo "[INFO] Some key events were skipped due to missing accessibility permissions."
    echo "[INFO] Grant access in System Preferences > Privacy & Security > Accessibility."
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
(( FAIL == 0 ))
