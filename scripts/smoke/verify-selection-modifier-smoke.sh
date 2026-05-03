#!/usr/bin/env bash
# verify-selection-modifier-smoke.sh — confirm the app handles selection modifier
# key combinations without crashing
# Usage: ./verify-selection-modifier-smoke.sh "$APP_NAME" "$APP_PID"
# Exit 0 = pass, Exit 1 = fail
#
# Tests Shift and Command modifier interactions used for multi-selection
# in the frame strip and canvas. Without a loaded project these are no-ops,
# but the smoke test verifies the app stays alive after each event.

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

send_modified_key() {
    local desc="$1"
    local script="$2"
    local exit_code=0
    local result
    result=$(osascript -e "$script" 2>&1) || exit_code=$?
    if echo "$result" | grep -qi "not allowed\|not authorized\|1002\|access for assistive"; then
        skip "Accessibility not available — cannot send: $desc"
        return 0
    fi
    if (( exit_code != 0 )); then
        echo "[WARN] Modifier key event returned non-zero for $desc: $result"
    fi
}

# Bring app to front
osascript -e "tell application \"$APP_NAME\" to activate" 2>/dev/null || true
sleep 0.5

# --- Shift modifier tests (frame strip range selection) ---

# Shift+Right arrow — extend frame selection rightward
send_modified_key "Shift+Right" \
    'tell application "System Events" to key code 124 using shift down'
sleep 0.3
alive "Shift+Right arrow"

# Shift+Left arrow — extend frame selection leftward
send_modified_key "Shift+Left" \
    'tell application "System Events" to key code 123 using shift down'
sleep 0.3
alive "Shift+Left arrow"

# --- Command modifier tests (non-contiguous selection) ---

# Command+Right arrow
send_modified_key "Command+Right" \
    'tell application "System Events" to key code 124 using command down'
sleep 0.3
alive "Command+Right arrow"

# Command+Left arrow
send_modified_key "Command+Left" \
    'tell application "System Events" to key code 123 using command down'
sleep 0.3
alive "Command+Left arrow"

# --- Combined modifier test ---

# Command+Shift+Right — combined modifier
send_modified_key "Command+Shift+Right" \
    'tell application "System Events" to key code 124 using {command down, shift down}'
sleep 0.3
alive "Command+Shift+Right arrow"

# --- Click-based modifier tests ---

# Shift+Click in the center of the window
CLICK_EXIT=0
CLICK_RESULT=$(osascript -e "
tell application \"System Events\"
    tell (first process whose unix id is $APP_PID)
        set w to first window
        set p to position of w
        set s to size of w
        set cx to (item 1 of p) + ((item 1 of s) / 2)
        set cy to (item 2 of p) + ((item 2 of s) / 2)
    end tell
    -- Shift+Click
    click at {cx, cy} with shift down
    delay 0.2
    -- Command+Click
    click at {cx, cy} with command down
end tell
return \"modifier-clicks-sent\"
" 2>&1) || CLICK_EXIT=$?

if echo "$CLICK_RESULT" | grep -qi "not allowed\|not authorized\|1002\|access for assistive"; then
    skip "Accessibility not available — cannot send modifier clicks"
else
    if (( CLICK_EXIT != 0 )); then
        echo "[WARN] Modifier click returned non-zero: $CLICK_RESULT"
    fi
    sleep 0.3
    alive "Shift+Click and Command+Click"
fi

if $SKIPPED; then
    echo ""
    echo "[INFO] Some events were skipped due to missing accessibility permissions."
    echo "[INFO] Grant access in System Preferences > Privacy & Security > Accessibility."
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
(( FAIL == 0 ))
