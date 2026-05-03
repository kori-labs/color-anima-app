#!/usr/bin/env bash
# verify-window-present.sh — confirm the app launched with a visible window
# Usage: ./verify-window-present.sh "$APP_NAME" "$APP_PID"
# Exit 0 = pass, Exit 1 = fail

set -euo pipefail

APP_NAME="${1:-Color Anima}"
APP_PID="${2:?APP_PID required}"

PASS=0
FAIL=0
MAX_ATTEMPTS=10
RETRY_DELAY=0.5

pass() { echo "[PASS] $*"; ((PASS++)) || true; }
fail() { echo "[FAIL] $*"; ((FAIL++)) || true; }
skip() { echo "[SKIP] $*"; }

is_accessibility_error() {
    echo "$1" | grep -qi "not allowed\|not authorized\|1002\|access for assistive"
}

# Check 1: process is running
if kill -0 "$APP_PID" 2>/dev/null; then
    pass "Process $APP_PID is running"
else
    fail "Process $APP_PID is not running"
    exit 1
fi

# Check 2: app has at least one window.
# Do not use `tell application ... to count windows` because SwiftUI apps can
# return 0 even when a real AX window exists.
WINDOW_QUERY=""
WINDOW_EXIT=0
WINDOW_COUNT=""

for (( attempt=1; attempt<=MAX_ATTEMPTS; attempt++ )); do
    WINDOW_EXIT=0
    WINDOW_QUERY=$(osascript -e "
tell application \"System Events\"
    tell (first process whose unix id is $APP_PID)
        count windows
    end tell
end tell
" 2>&1) || WINDOW_EXIT=$?

    if is_accessibility_error "$WINDOW_QUERY"; then
        skip "Accessibility not available — cannot verify window presence"
        echo ""
        echo "Results: $PASS passed, $FAIL failed"
        exit 0
    fi

    if (( WINDOW_EXIT == 0 )) && [[ "$WINDOW_QUERY" =~ ^[0-9]+$ ]] && (( WINDOW_QUERY >= 1 )); then
        WINDOW_COUNT="$WINDOW_QUERY"
        break
    fi

    sleep "$RETRY_DELAY"
done

if [[ -n "$WINDOW_COUNT" ]]; then
    pass "App has $WINDOW_COUNT window(s)"
else
    fail "App has no AX windows after ${MAX_ATTEMPTS} attempts (last result: $WINDOW_QUERY)"
    exit 1
fi

# Check 3: window has nonzero size via System Events.
GEOMETRY_QUERY=""
GEOMETRY_EXIT=0
GEOMETRY_RESULT=""

for (( attempt=1; attempt<=MAX_ATTEMPTS; attempt++ )); do
    GEOMETRY_EXIT=0
    GEOMETRY_QUERY=$(osascript -e "
tell application \"System Events\"
    tell (first process whose unix id is $APP_PID)
        tell first window
            set p to position
            set s to size
            return (item 1 of p as text) & \",\" & (item 2 of p as text) & \",\" & (item 1 of s as text) & \",\" & (item 2 of s as text)
        end tell
    end tell
end tell
" 2>&1) || GEOMETRY_EXIT=$?

    if is_accessibility_error "$GEOMETRY_QUERY"; then
        skip "Accessibility not available — cannot verify window geometry"
        echo ""
        echo "Results: $PASS passed, $FAIL failed"
        exit 0
    fi

    if (( GEOMETRY_EXIT == 0 )) && [[ "$GEOMETRY_QUERY" =~ ^-?[0-9]+,-?[0-9]+,[0-9]+,[0-9]+$ ]]; then
        GEOMETRY_RESULT="$GEOMETRY_QUERY"
        break
    fi

    sleep "$RETRY_DELAY"
done

if [[ -z "$GEOMETRY_RESULT" ]]; then
    fail "Could not retrieve window geometry after ${MAX_ATTEMPTS} attempts (last result: $GEOMETRY_QUERY)"
    exit 1
fi

IFS=',' read -r W_LEFT W_TOP W_WIDTH W_HEIGHT <<< "$GEOMETRY_RESULT"
if (( W_WIDTH > 0 && W_HEIGHT > 0 )); then
    pass "Window has nonzero size (x=$W_LEFT, y=$W_TOP, width=$W_WIDTH, height=$W_HEIGHT)"
else
    fail "Window has zero or invalid size (x=$W_LEFT, y=$W_TOP, width=$W_WIDTH, height=$W_HEIGHT)"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
(( FAIL == 0 ))
